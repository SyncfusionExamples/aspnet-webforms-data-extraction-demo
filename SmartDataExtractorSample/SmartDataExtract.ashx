// filepath: SmartDataExtractorSample/SmartDataExtract.ashx
<%@ WebHandler Language="C#" Class="SmartDataExtractorSample.SmartDataExtract" %>

using Syncfusion.SmartDataExtractor;
using System;
using System.Collections.Generic;
using System.Configuration;
using System.IO;
using System.Text;
using System.Web;

namespace SmartDataExtractorSample
{
    /// <summary>
    /// Receives the PDF bytes loaded into the EJ2 PDF Viewer as a base64 payload,
    /// runs the Syncfusion SmartDataExtractor (OCR + extraction) pipeline against
    /// that stream, asks the OpenAI chat model to identify label/value pairs, and
    /// returns the combined envelope to the browser.
    /// </summary>
    public class SmartDataExtract : IHttpHandler
    {
        public bool IsReusable { get { return false; } }

        public void ProcessRequest(HttpContext context)
        {
            try
            {
                ProcessRequestCore(context);
            }
            catch (HttpException hex)
            {
                // Already-shaped HTTP errors (400/415/etc.) flow back to the client
                // with their original status code via Application's normal pipeline.
                LogIfPossible(context, hex);
                WriteJsonError(context, hex.GetHttpCode(), hex.Message);
                throw;
            }
            catch (Exception ex)
            {
                // OCR / Syncfusion / IO errors land here. Instead of letting IIS render
                // a generic "HTTP 500 from extract handler.", we surface the real message
                // back to the browser AND log the full stack to App_Data for diagnosis.
                LogIfPossible(context, ex);
                try
                {
                    var sb = new StringBuilder("Handler error: ");
                    sb.Append(ex.GetType().FullName ?? "Exception");
                    sb.Append(": ");
                    sb.Append(ex.Message);
                    var inner = ex.InnerException;
                    int safety = 0;
                    while (inner != null && safety++ < 5)
                    {
                        sb.Append(" -> ");
                        sb.Append(inner.GetType().FullName);
                        sb.Append(": ");
                        sb.Append(inner.Message);
                        inner = inner.InnerException;
                    }
                    WriteJsonError(context, 500, sb.ToString());
                }
                catch (Exception writeEx)
                {
                    // If WriteJsonError fails, still try to return something useful
                    try
                    {
                        context.Response.ContentType = "application/json; charset=utf-8";
                        context.Response.StatusCode = 500;
                        context.Response.Write("{\"error\":\"Internal server error. Check application logs.\"}");
                    }
                    catch { /* Really nothing we can do */ }
                }
            }
        }

        private static void ProcessRequestCore(HttpContext context)
        {
            string pdfBase64 = null;

            // Accept either a JSON payload from the fetch() client, or a plain
            // application/x-www-form-urlencoded fallback for diagnostics.
            string contentType = context.Request.ContentType ?? string.Empty;
            if (contentType.IndexOf("application/json", StringComparison.OrdinalIgnoreCase) >= 0)
            {
                using (var reader = new StreamReader(context.Request.InputStream, context.Request.ContentEncoding))
                {
                    string raw = reader.ReadToEnd();
                    // Light-weight parsing so we don't need a JSON serializer at the handler level.
                    var match = System.Text.RegularExpressions.Regex.Match(
                        raw,
                        "\"pdfBase64\"\\s*:\\s*\"(?<v>[^\"]*)\"",
                        System.Text.RegularExpressions.RegexOptions.IgnoreCase);
                    if (!match.Success)
                    {
                        throw new HttpException(400, "pdfBase64 payload missing from JSON body.");
                    }
                    pdfBase64 = match.Groups["v"].Value;
                }
            }
            else
            {
                pdfBase64 = context.Request.Form["pdfBase64"] ?? context.Request.QueryString["pdfBase64"];
            }

            if (string.IsNullOrEmpty(pdfBase64))
            {
                throw new HttpException(400, "pdfBase64 payload is required.");
            }

            byte[] pdfBytes;
            try
            {
                pdfBytes = Convert.FromBase64String(pdfBase64);
            }
            catch (FormatException ex)
            {
                throw new HttpException(400, "pdfBase64 is not a valid base64 string: " + ex.Message, ex);
            }

            if (pdfBytes.Length == 0)
            {
                throw new HttpException(400, "Decoded PDF payload is empty.");
            }

            string json;
            try
            {
                using (var stream = new MemoryStream(pdfBytes, writable: false))
                {
                    var extractor = new DataExtractor();
                    json = extractor.ExtractDataAsJson(stream);
                }
            }
            catch (Exception ex)
            {
                throw new HttpException(500, "SmartDataExtractor error: " + ex.GetType().Name + ": " + ex.Message, ex);
            }

            // Ask the AI to extract label/value pairs (e.g. "Policy Number : POL-12345678").
            // On any failure we keep the page rendering working - we just return no pairs
            // and surface the raw OCR JSON the browser can still inspect / fall back to.
            List<ExtractedKeyValue> pairs;
            string aiError = null;
            try
            {
                pairs = ExtractPairsWithAi(json, context);
            }
            catch (Exception aiEx)
            {
                pairs = new List<ExtractedKeyValue>();
                aiError = aiEx.Message;
                LogIfPossible(context, aiEx);
            }

            // Build the combined envelope the browser consumes.
            var sb = new StringBuilder();
            sb.Append('{');
            sb.Append("\"pairsCount\":").Append(pairs.Count);
            sb.Append(",\"aiError\":").Append(JsonStringOrNull(aiError));
            sb.Append(",\"pairs\":[");
            for (int i = 0; i < pairs.Count; i++)
            {
                if (i > 0) sb.Append(',');
                sb.Append("{\"key\":").Append(JsonStringOrNull(pairs[i].Key));
                sb.Append(",\"value\":").Append(JsonStringOrNull(pairs[i].Value));
                sb.Append('}');
            }
            sb.Append("],\"ocrJson\":").Append(JsonStringOrNull(json));
            sb.Append('}');

            context.Response.ContentType = "application/json; charset=utf-8";
            context.Response.Cache.SetCacheability(HttpCacheability.NoCache);
            context.Response.Write(sb.ToString());
        }

        /// <summary>
        /// Reads the OpenAI ApiKey + Model from <c>Web.config</c> <c>&lt;appSettings&gt;</c>,
        /// hands the OCR JSON to <see cref="AIKeyValueExtractor"/> and returns the
        /// detected label/value pairs. If the app settings are missing the AI step
        /// is skipped (returns an empty list) so the UI still renders the raw OCR JSON.
        /// </summary>
        private static List<ExtractedKeyValue> ExtractPairsWithAi(string ocrJson, HttpContext context)
        {
            string apiKey = ConfigurationManager.AppSettings["OpenAI.ApiKey"];
            string model = ConfigurationManager.AppSettings["OpenAI.Model"];

            if (string.IsNullOrWhiteSpace(apiKey) || string.IsNullOrWhiteSpace(model))
            {
                // Not configured on this machine - silent skip. The Status line in the UI
                // will explain that AI key/value detection is unavailable and only the
                // raw OCR JSON is shown below.
                return new List<ExtractedKeyValue>();
            }

            Action<string, Exception> logger = (msg, ex) =>
            {
                try
                {
                    LogIfPossible(context, ex ?? new Exception(msg));
                }
                catch
                {
                    // never let logging tear down the happy path
                }
            };

            // Pull the synchronous result out of the AI extractor. We are inside a
            // classic using block (NOT a C# 8 "using declaration") so the legacy
            // Roslyn code-behind compiler that ships with this WebForms project
            // (C# 7.3) can compile it.
            using (var factory = new OpenAIClientFactory(apiKey, model))
            {
                var extractor = new AIKeyValueExtractor(factory, logger);

                // Sync over async: ashx handlers are simpler when they don't await.
                var task = extractor.ExtractAsync(ocrJson);
                task.Wait();
                var result = task.Result;
                if (result == null) return new List<ExtractedKeyValue>();

                var list = new List<ExtractedKeyValue>(result.Count);
                foreach (var kv in result)
                {
                    if (kv == null) continue;
                    if (string.IsNullOrWhiteSpace(kv.Key) || string.IsNullOrWhiteSpace(kv.Value)) continue;
                    list.Add(new ExtractedKeyValue { Key = kv.Key, Value = kv.Value });
                }
                return list;
            }
        }

        /// <summary>
        /// Minimal JSON string escaper - keeps the handler free of a serializer
        /// dependency. Returns <c>null</c> as JSON <c>null</c>.
        /// </summary>
        private static string JsonStringOrNull(string value)
        {
            if (value == null) return "null";
            var sb = new StringBuilder(value.Length + 2);
            sb.Append('"');
            foreach (char c in value)
            {
                switch (c)
                {
                    case '"': sb.Append("\\\""); break;
                    case '\\': sb.Append("\\\\"); break;
                    case '\r': sb.Append("\\r"); break;
                    case '\n': sb.Append("\\n"); break;
                    case '\t': sb.Append("\\t"); break;
                    case '\b': sb.Append("\\b"); break;
                    case '\f': sb.Append("\\f"); break;
                    default:
                        if (c < 0x20) sb.Append("\\u").Append(((int)c).ToString("x4"));
                        else sb.Append(c);
                        break;
                }
            }
            sb.Append('"');
            return sb.ToString();
        }

        /// <summary>
        /// Writes a JSON error payload directly to the response so the browser can
        /// show the real exception text instead of an opaque "HTTP 500".
        /// </summary>
        private static void WriteJsonError(HttpContext context, int statusCode, string message)
        {
            try
            {
                // Try to clear response, but don't fail if headers already sent
                try { context.Response.Clear(); }
                catch { /* Headers may have already been sent */ }

                context.Response.StatusCode = statusCode;
                context.Response.ContentType = "application/json; charset=utf-8";
                context.Response.Cache.SetCacheability(HttpCacheability.NoCache);
                
                // Minimal hand-rolled JSON so we don't depend on a serializer at the handler level.
                string safe = (message ?? string.Empty).Replace("\\", "\\\\").Replace("\"", "\\\"").Replace("\r", " ").Replace("\n", " ");
                context.Response.Write("{\"error\":\"" + safe + "\"}");
            }
            catch (Exception writeEx)
            {
                // Last resort: try to write plain text error
                try
                {
                    context.Response.ContentType = "text/plain";
                    context.Response.Write("Handler error (JSON write failed): " + (message ?? "Unknown") + " | Inner: " + (writeEx.Message ?? "Unknown"));
                }
                catch { /* Give up */ }
            }
        }

        /// <summary>
        /// Best-effort diagnostic log to App_Data. Anything that throws here is swallowed
        /// because we never want logging to mask the original error.
        /// </summary>
        private static void LogIfPossible(HttpContext context, Exception ex)
        {
            try
            {
                string dir = context.Server.MapPath("~/App_Data");
                string path = Path.Combine(dir, "HandlerErrors.log");
                var sb = new StringBuilder();
                sb.Append(DateTime.UtcNow.ToString("o"));
                sb.Append("\t");
                sb.Append(ex.GetType().FullName);
                sb.Append(": ");
                sb.Append(ex.Message);
                sb.AppendLine();
                sb.AppendLine(ex.StackTrace ?? "(no stack)");
                File.AppendAllText(path, sb.ToString(), Encoding.UTF8);
            }
            catch
            {
                // ignore
            }
        }
    }
}