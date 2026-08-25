using OpenAI.Chat;
using System;
using System.Collections.Generic;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;
using System.Threading;
using System.Threading.Tasks;

namespace SmartDataExtractorSample
{
    /// <summary>
    /// Result of a single key-value detection. <see cref="Value"/> holds the raw
    /// text returned by the AI for the value side; downstream code can later
    /// quote-wrap it, classify it, etc.
    /// </summary>
    public sealed class ExtractedKeyValue
    {
        public string Key { get; set; } = string.Empty;
        public string Value { get; set; } = string.Empty;
    }

    /// <summary>
    /// Lightweight adapter around <see cref="OpenAIClientFactory"/> that takes the
    /// raw JSON produced by Syncfusion SmartDataExtractor (pages, lines, word
    /// boxes) and asks the OpenAI chat model to identify "label : value" pairs
    /// such as "Policy Number : POL-12345678" or
    /// "Address : 25 Lake View Road Chennai".
    ///
    /// Pinned to C# 7.3 (no raw string literals, no file-scoped namespaces,
    /// no nullable annotations, no 'using' declarations) so the legacy
    /// Roslyn code provider that ships with .NET 4.7.2 WebForms can compile it.
    /// </summary>
    public sealed class AIKeyValueExtractor
    {
        private readonly OpenAIClientFactory _clientFactory;
        private readonly Action<string, Exception> _log; // null-safe logger

        private const string SystemPromptText =
            "You are a precise document-extraction agent.\n" +
            "\n" +
            "The user will give you a structural dump of the content that an OCR\n" +
            "pipeline recovered from a PDF - typically an insurance claim form,\n" +
            "invoice, manifest, statement, or similar business document.\n" +
            "\n" +
            "The dump contains FOUR sections per page, in this order:\n" +
            "  1. PLAIN LINES - free-format lines of text recovered from a top-level\n" +
            "     \"lines\" / \"Lines\" array on the page (if the producer exposed\n" +
            "     one). Each entry is rendered as one prompt line.\n" +
            "  2. TABLES - one block per detected table. Within each table the\n" +
            "     cells are emitted as:\n" +
            "        [r=ROW, c=COL] <cell text>\n" +
            "     where ROW and COL are zero-based grid positions and the cell\n" +
            "     text is the raw OCR text of that cell.\n" +
            "  3. FORM FIELDS - detected form field/checkbox regions.\n" +
            "  4. PLAIN TEXT - a fallback dump of every leaf string anywhere in\n" +
            "     the page whose JSON property is named text / Text / value /\n" +
            "     Value - AND that did NOT already appear in sections 1-3.\n" +
            "     This is where inline pairs of the form\n" +
            "        <Label> : <Value>\n" +
            "     or\n" +
            "        <Label>\\n<Value>\n" +
            "     live when the producer did NOT structure them as table cells.\n" +
            "\n" +
            "Your job: identify every label/value pair that appears anywhere in\n" +
            "the dump and return them as a flat JSON list.\n" +
            "\n" +
            "Rules:\n" +
            "  1. A pair has the shape\n" +
            "          <Label or field name> <separator> <Value>\n" +
            "     The separator may be \":\", \"-\", \"=\", a hard line break, OR the\n" +
            "     ADJACENT GRID POSITIONS in a table (label in column C, value\n" +
            "     in column C+1 of the same row).\n" +
            "  2. PLAIN TEXT is the most common source of inline pairs. The\n" +
            "     producer did NOT mark them as table cells - they show up as one\n" +
            "     line of the form \"Policy Number: POL-12345678\". Detect these\n" +
            "     FIRST, because the cell / form layering is unreliable on its\n" +
            "     own.\n" +
            "  3. Two-column tables are the second most common source. For a\n" +
            "     table row like\n" +
            "        [r=4, c=1] Generator's Name and Mailing Address   " +
            "[r=4, c=2] WHITTIER, CA 90601\n" +
            "     you emit ONE pair:\n" +
            "        key   = \"Generator's Name and Mailing Address\"\n" +
            "        value = \"WHITTIER, CA 90601\"\n" +
            "  4. A label may also be a single cell whose row contains only one\n" +
            "     textual cell followed in the grid by an empty cell on the SAME\n" +
            "     row - read the next non-empty cell to the right as the value.\n" +
            "  5. If a row spans only one column and that cell contains both a\n" +
            "     heading and the body (e.g. a multi-line certification block),\n" +
            "     still try to split it: first non-empty line is the label, the\n" +
            "     rest is the value.\n" +
            "  6. Strip surrounding whitespace and trailing periods on the value.\n" +
            "  7. Preserve the value EXACTLY as written - never invent, never\n" +
            "     translate, never summarise.\n" +
            "  8. If a label appears more than once, keep the FIRST occurrence.\n" +
            "  9. Skip items where the value is empty or trivially repeats the\n" +
            "     label.\n" +
            " 10. Do NOT include decorative text, page numbers, headers/footers\n" +
            "     that do not look like a field label, or \"Page 1 of 2\" rows.\n" +
            " 11. Output MUST be a single JSON object of the shape\n" +
            "        {\"pairs\":[{\"key\":\"...\",\"value\":\"...\"},...]}\n" +
            "     with NO markdown fences, NO commentary, NO trailing commas.\n" +
            " 12. If you cannot find any pairs, return {\"pairs\":[]}.\n";

        public AIKeyValueExtractor(OpenAIClientFactory clientFactory, Action<string, Exception> log = null)
        {
            if (clientFactory == null) throw new ArgumentNullException(nameof(clientFactory));
            _clientFactory = clientFactory;
            _log = log;
        }

        /// <summary>
        /// Extract every "&lt;label&gt;: &lt;value&gt;" pair from the OCR JSON.
        /// </summary>
        /// <param name="ocrJsonText">
        /// Raw JSON returned by Syncfusion DataExtractor.ExtractDataAsJson.
        /// Typically looks like
        ///   {"pages":[{"pageNumber":1,"lines":[{"text":"..."}...]}, ...]}
        /// Anything string-shaped is accepted; the model just sees text.
        /// </param>
        public async Task<IReadOnlyList<ExtractedKeyValue>> ExtractAsync(
            string ocrJsonText,
            CancellationToken cancellationToken = default)
        {
            if (string.IsNullOrWhiteSpace(ocrJsonText))
            {
                return Array.Empty<ExtractedKeyValue>();
            }

            // Flatten the Syncfusion JSON into a plain-text "page / line" view so the
            // model sees what a human reader would see. Keep the structure loose so we
            // do not silently lose content if Syncfusion changes its JSON shape.
            string flattened = FlattenForPrompt(ocrJsonText);
            if (string.IsNullOrWhiteSpace(flattened))
            {
                return Array.Empty<ExtractedKeyValue>();
            }

            // Hard cap the prompt - keep within ~12k tokens of body text.
            const int MaxChars = 40000;
            if (flattened.Length > MaxChars)
            {
                flattened = flattened.Substring(0, MaxChars) + "\n... [truncated]";
            }

            try
            {
                var raw = await CallModelAsync(flattened, cancellationToken).ConfigureAwait(false);
                return ParsePairs(raw);
            }
            catch (OperationCanceledException)
            {
                throw;
            }
            catch (Exception ex)
            {
                SafeLog(ex, "AI key-value extractor failed; returning empty list.");
                return Array.Empty<ExtractedKeyValue>();
            }
        }

        // ---- internals ------------------------------------------------------------------

        private async Task<string> CallModelAsync(string flattenedText, CancellationToken ct)
        {
            var messages = new List<ChatMessage>
            {
                new SystemChatMessage(SystemPromptText),
                new UserChatMessage(
                    "OCR text begins below. Extract every label/value pair and reply with " +
                    "the JSON object described in the system prompt.\n\n---\n" + flattenedText)
            };

            var completion = await _clientFactory.ChatClient
                .CompleteChatAsync(messages, cancellationToken: ct)
                .ConfigureAwait(false);

            if (completion == null || completion.Value == null ||
                completion.Value.Content == null || completion.Value.Content.Count == 0)
            {
                return null;
            }
            return completion.Value.Content[0].Text;
        }

        /// <summary>
        /// Convert Syncfusion DataExtractor JSON into a flat, human-readable text
        /// dump we can hand to the AI. We deliberately do NOT bind to a rigid schema
        /// because Syncfusion ships the JSON as untyped key/value trees; the AI does
        /// the real structuring. If Syncfusion returns empty/null we still produce
        /// something the model can see.
        ///
        /// The produced dump has three recognisable sections per page so the AI can
        /// navigate the document structure (and pick key/value pairs out of table
        /// cells, not just free-flowing text):
        ///
        ///   === PAGE &lt;n&gt; LINES ===
        ///   ...
        ///   === PAGE &lt;n&gt; TABLES ===
        ///   --- table &lt;i&gt; ---
        ///   [r=0, c=1] &lt;cell text&gt;
        ///   ...
        ///   --- end table ---
        ///   === PAGE &lt;n&gt; FORM FIELDS ===
        ///   ...
        /// </summary>
        private static string FlattenForPrompt(string ocrJsonText)
        {
            try
            {
                using (var doc = JsonDocument.Parse(ocrJsonText))
                {
                    var sb = new StringBuilder();
                    WriteNode(doc.RootElement, sb, 0);
                    if (sb.Length == 0)
                    {
                        // The JSON was valid but had no extractable text/tables.
                        // Make sure the AI gets SOMETHING so it can answer
                        // {"pairs":[]} rather than 500 due to an empty prompt.
                        return "(document produced no extractable text)";
                    }
                    return sb.ToString();
                }
            }
            catch (JsonException)
            {
                // Not JSON - just send the raw text; the AI still copes.
                return ocrJsonText;
            }
        }

        private static void WriteNode(JsonElement element, StringBuilder sb, int depth)
        {
            if (depth > 12) return; // protect against runaway recursion
            if (element.ValueKind != JsonValueKind.Object) return;

            // ---- Document is a Syncfusion "smartextractor" payload: -----------------
            //   root
            //     pages[]
            //       pageNumber
            //       lines[] / words[]         (free-format text)
            //       pageObjects[]             (tables; each = bounds + rows[] + cells[])
            //       formObjects[]             (text fields, checkboxes)
            //
            // Detect by the presence of either a "pages" child or a top-level
            // "lines"/"pageObjects" wrapper we can route on.
            JsonElement pages;
            if (TryGetAnyProperty(element, "Pages", "pages", out pages) &&
                pages.ValueKind == JsonValueKind.Array)
            {
                WritePages(pages, sb);
                return;
            }

            // Generic fall-through: emit text/value properties we find directly so
            // a misnamed top-level still produces something readable.
            WriteGenericObject(element, sb);
        }

        private static void WritePages(JsonElement pages, StringBuilder sb)
        {
            int pageIndex = 0;
            foreach (var page in pages.EnumerateArray())
            {
                if (page.ValueKind != JsonValueKind.Object) { pageIndex++; continue; }

                int pageNumber = ReadPageNumber(page, pageIndex + 1);

                bool wroteHeader = false;

                // Shared across the three structured writers + the free-text
                // scan so that the same string is never emitted twice. Cell
                // text leaked into the PLAIN TEXT fallback would just
                // duplicate work we already did for the table section.
                var emittedStrings = new HashSet<string>(StringComparer.Ordinal);

                // ---- 1. free-format lines / words ----
                int linesEmitted = 0;
                linesEmitted += WritePlainLines(page, sb, emittedStrings);

                if (linesEmitted > 0)
                {
                    wroteHeader = true;
                }

                // ---- 2. tables (pageObjects[].rows[].cells[].content.text) ----
                int tablesEmitted = WriteTables(page, sb, emittedStrings);

                // ---- 3. form objects (boxes / checkboxes) ----
                int formsEmitted = WriteFormObjects(page, sb, emittedStrings);

                // ---- 4. fallback: walk the whole page and pick up any
                //         inline "Label: Value" line that the producer did
                //         not put inside a recognised shape. This is the
                //         case the original (pre-table-aware) implementation
                //         handled via "any property named text/value".
                int plainEmitted = WritePlainTextFromPage(page, pageNumber, sb, emittedStrings);
                if (plainEmitted > 0)
                {
                    wroteHeader = true;
                }

                if (wroteHeader || tablesEmitted > 0 || formsEmitted > 0)
                {
                    // emit a trailing blank line between pages for the AI's readability
                    sb.Append('\n');
                }

                pageIndex++;
            }
        }

        // Returns the number of lines emitted so the caller can decide whether to
        // emit a section header.
        private static int WritePlainLines(JsonElement page, StringBuilder sb, HashSet<string> emittedStrings)
        {
            int emitted = 0;
            // pages may carry a top-level "lines" / "Lines" array OR objects
            // may put it inside a wrapper - accept both spellings.
            JsonElement? lines = null;
            if ((page.TryGetProperty("lines", out var l1) || page.TryGetProperty("Lines", out l1)) &&
                l1.ValueKind == JsonValueKind.Array)
            {
                lines = l1;
            }

            if (lines.HasValue)
            {
                int pageNumber = ReadPageNumber(page, 0);
                if (pageNumber > 0)
                {
                    sb.Append("=== PAGE ").Append(pageNumber).Append(" LINES ===\n");
                }
                else
                {
                    sb.Append("=== PAGE LINES ===\n");
                }

                foreach (var line in lines.Value.EnumerateArray())
                {
                    if (line.ValueKind == JsonValueKind.String)
                    {
                        if (TryEmitFreeText(line.GetString(), sb, emittedStrings)) emitted++;
                    }
                    else if (line.ValueKind == JsonValueKind.Object)
                    {
                        // nested line: { text: "..." } or { value: "..." }
                        foreach (var p in line.EnumerateObject())
                        {
                            if (p.Value.ValueKind == JsonValueKind.String &&
                                (string.Equals(p.Name, "text", StringComparison.OrdinalIgnoreCase) ||
                                 string.Equals(p.Name, "value", StringComparison.OrdinalIgnoreCase)))
                            {
                                if (TryEmitFreeText(p.Value.GetString(), sb, emittedStrings)) emitted++;
                            }
                        }
                    }
                }
            }

            return emitted;
        }

        /// <summary>
        /// Push <paramref name="raw"/> into the prompt body unless it is
        /// null / whitespace, and unless we already wrote the EXACT same
        /// normalised string into another section. Returns true iff the
        /// string was actually appended.
        /// </summary>
        private static bool TryEmitFreeText(string raw, StringBuilder sb, HashSet<string> emittedStrings)
        {
            if (string.IsNullOrWhiteSpace(raw)) return false;
            var normalised = CollapseWhitespace(raw).Trim();
            if (normalised.Length == 0) return false;
            // De-dupe by the normalized form so the same logical line from
            // table cell + free text + form field won't repeat. The user
            // prompt has a 40 KB budget; duplicating every cell three times
            // was a real problem before this was added.
            if (!emittedStrings.Add(normalised)) return false;
            sb.Append(normalised).Append('\n');
            return true;
        }

        private static string CollapseWhitespace(string s)
        {
            if (string.IsNullOrEmpty(s)) return s;
            var sb = new StringBuilder(s.Length);
            bool prevWasSpace = false;
            foreach (var c in s)
            {
                if (c == ' ' || c == '\t' || c == '\r' || c == '\n')
                {
                    if (!prevWasSpace) sb.Append(' ');
                    prevWasSpace = true;
                }
                else
                {
                    sb.Append(c);
                    prevWasSpace = false;
                }
            }
            return sb.ToString();
        }

        // Returns the number of tables emitted.
        private static int WriteTables(JsonElement page, StringBuilder sb, HashSet<string> emittedStrings)
        {
            int emitted = 0;

            JsonElement pageObjects;
            if ((!page.TryGetProperty("PageObjects", out pageObjects) &&
                 !page.TryGetProperty("pageObjects", out pageObjects)) ||
                pageObjects.ValueKind != JsonValueKind.Array)
            {
                return 0;
            }

            int pageNumber = ReadPageNumber(page, 0);

            bool headerWritten = false;

            int tableIndex = 0;
            foreach (var po in pageObjects.EnumerateArray())
            {
                if (po.ValueKind != JsonValueKind.Object) continue;

                // Identify a table - we accept either Type=="Table" (the
                // canonical Syncfusion shape) or any object that simply has a
                // "Rows" array - some printed exports omit the Type. Syncfusion
                // emits property names in PascalCase ("Type", "Rows"), so we
                // try both spellings.
                bool looksLikeTable = false;
                JsonElement tp = default;
                if ((po.TryGetProperty("Type", out tp) || po.TryGetProperty("type", out tp)) &&
                    tp.ValueKind == JsonValueKind.String &&
                    string.Equals(tp.GetString(), "Table", StringComparison.OrdinalIgnoreCase))
                {
                    looksLikeTable = true;
                }
                else
                {
                    JsonElement rowsHint = default;
                    if ((po.TryGetProperty("Rows", out rowsHint) || po.TryGetProperty("rows", out rowsHint)) &&
                        rowsHint.ValueKind == JsonValueKind.Array)
                    {
                        looksLikeTable = true;
                    }
                }

                if (!looksLikeTable) continue;

                if (!headerWritten)
                {
                    sb.Append("=== PAGE ").Append(pageNumber).Append(" TABLES ===\n");
                    headerWritten = true;
                }

                JsonElement rows;
                if ((!po.TryGetProperty("Rows", out rows) && !po.TryGetProperty("rows", out rows)) ||
                    rows.ValueKind != JsonValueKind.Array)
                {
                    tableIndex++;
                    continue;
                }

                sb.Append("--- table ").Append(tableIndex).Append(" ---\n");

                int rowIndex = 0;
                foreach (var row in rows.EnumerateArray())
                {
                    if (row.ValueKind != JsonValueKind.Object) { rowIndex++; continue; }
                    if ((!row.TryGetProperty("cells", out var cells) && !row.TryGetProperty("Cells", out cells)) ||
                        cells.ValueKind != JsonValueKind.Array)
                    {
                        rowIndex++;
                        continue;
                    }

                    int colIndex = 0;
                    foreach (var cell in cells.EnumerateArray())
                    {
                        if (cell.ValueKind != JsonValueKind.Object) { colIndex++; continue; }

                        // Honour RowSpan/ColSpan derived absolute positions so the
                        // AI can reason about columns. Syncfusion already exposes a
                        // RowStart/ColStart on each cell that puts it in grid
                        // coordinates; emit those directly so the prompt reads
                        //   [r=2, c=4] <text>
                        // Try the camelCase and the PascalCase variants - both are
                        // seen in the wild depending on which Syncfusion build
                        // produced the JSON.
                        int r = rowIndex;
                        int c = colIndex;
                        if ((cell.TryGetProperty("RowStart", out var rs) || cell.TryGetProperty("rowStart", out rs)) &&
                            rs.ValueKind == JsonValueKind.Number && rs.TryGetInt32(out var rsI))
                        {
                            r = rsI;
                        }
                        if ((cell.TryGetProperty("ColStart", out var cs) || cell.TryGetProperty("colStart", out cs)) &&
                            cs.ValueKind == JsonValueKind.Number && cs.TryGetInt32(out var csI))
                        {
                            c = csI;
                        }

                        string text = ReadCellText(cell);
                        if (string.IsNullOrWhiteSpace(text))
                        {
                            colIndex++;
                            continue;
                        }

                        // Replace any embedded newlines with single spaces so each
                        // grid cell renders as one prompt line. The AI still sees
                        // the multi-line content, just not split across grid rows.
                        text = text.Replace('\n', ' ').Replace('\r', ' ').Trim();

                        // Claim the cell text so the PLAIN TEXT fallback
                        // doesn't re-emit the same string - some Syncfusion
                        // variants include both a plain-text "lines" section
                        // AND a table-as-pageObjects, in which case every cell
                        // would otherwise appear twice.
                        var normalised = CollapseWhitespace(text);
                        emittedStrings.Add(normalised);

                        sb.Append("[r=").Append(r).Append(", c=").Append(c).Append("] ");
                        sb.Append(text);
                        sb.Append('\n');

                        colIndex++;
                    }

                    rowIndex++;
                }

                sb.Append("--- end table ---\n");
                emitted++;
                tableIndex++;
            }

            return emitted;
        }

        private static int WriteFormObjects(JsonElement page, StringBuilder sb, HashSet<string> emittedStrings)
        {
            int emitted = 0;
            JsonElement formObjects;
            if ((!page.TryGetProperty("FormObjects", out formObjects) &&
                 !page.TryGetProperty("formObjects", out formObjects)) ||
                formObjects.ValueKind != JsonValueKind.Array)
            {
                return 0;
            }

            int pageNumber = ReadPageNumber(page, 0);

            sb.Append("=== PAGE ").Append(pageNumber).Append(" FORM FIELDS ===\n");

            foreach (var fo in formObjects.EnumerateArray())
            {
                if (fo.ValueKind != JsonValueKind.Object) continue;

                int type = -1;
                // Syncfusion typically emits PascalCase ("Type") but we also
                // tolerate a lowercase variant from other producers.
                if ((fo.TryGetProperty("Type", out var tp) || fo.TryGetProperty("type", out tp)) &&
                    tp.ValueKind == JsonValueKind.Number && tp.TryGetInt32(out var tpI))
                {
                    type = tpI;
                }

                float confidence = 0f;
                if ((fo.TryGetProperty("Confidence", out var cf) || fo.TryGetProperty("confidence", out cf)) &&
                    cf.ValueKind == JsonValueKind.Number && cf.TryGetSingle(out var cfF))
                {
                    confidence = cfF;
                }

                string label;
                switch (type)
                {
                    case 0: label = "text-field"; break;
                    case 1: label = "checkbox"; break;
                    case 2: label = "radio"; break;
                    default: label = "form-object"; break;
                }

                sb.Append("- ").Append(label)
                  .Append(" @ x=").Append(SafeFloatPreferred(fo, "X", "x"))
                  .Append(" y=").Append(SafeFloatPreferred(fo, "Y", "y"))
                  .Append(" w=").Append(SafeFloatPreferred(fo, "Width", "Width"))
                  .Append(" h=").Append(SafeFloatPreferred(fo, "Height", "height"))
                  .Append(" confidence=").Append(confidence.ToString("0.00", System.Globalization.CultureInfo.InvariantCulture))
                  .Append('\n');
                emitted++;
            }
            return emitted;
        }

        /// <summary>
        /// Section 4 of the prompt body: a flat pass over every leaf string
        /// on the page whose JSON property name is text / Text / value /
        /// Value, AFTER the structured writers have run. The shared dedupe
        /// set ensures cells already emitted by the TABLES section are not
        /// emitted a second time here - so the only lines this section
        /// produces are genuine inline pairs the producer did NOT structure
        /// as table cells (e.g. <c>{text:"Policy Number: POL-12345678"}</c>
        /// sitting loose at any level of the page tree).
        /// </summary>
        private static int WritePlainTextFromPage(JsonElement page, int pageNumber, StringBuilder sb, HashSet<string> emittedStrings)
        {
            // Build into a temporary buffer so we know the offset of the
            // first line. Only at the end do we know whether anything was
            // actually emitted (TryEmitFreeText can drop duplicates) - and
            // we only want to write the section header if there's content.
            var temp = new StringBuilder();
            foreach (var prop in page.EnumerateObject())
            {
                WalkForText(prop.Value, temp, emittedStrings);
            }
            int emitted = CountLineEmissions(temp);

            if (emitted > 0)
            {
                if (pageNumber > 0)
                {
                    sb.Append("=== PAGE ").Append(pageNumber).Append(" PLAIN TEXT ===\n");
                }
                else
                {
                    sb.Append("=== PAGE PLAIN TEXT ===\n");
                }
                sb.Append(temp);
            }
            return emitted;
        }

        /// <summary>
        /// Number of prompt lines emitted into <paramref name="sb"/> via
        /// TryEmitFreeText since construction - equals the number of '\n'
        /// characters in the buffer (TryEmitFreeText always appends exactly
        /// one trailing newline). Used by WritePlainTextFromPage to decide
        /// whether the section header should be emitted.
        /// </summary>
        private static int CountLineEmissions(StringBuilder sb)
        {
            int count = 0;
            for (int i = 0; i < sb.Length; i++)
            {
                if (sb[i] == '\n') count++;
            }
            return count;
        }

        /// <summary>
        /// Recursive helper that emits any leaf string whose property name is
        /// text / Text / value / Value. Each emission is de-duped against
        /// <paramref name="emittedStrings"/>.
        /// </summary>
        private static int WalkForText(JsonElement element, StringBuilder sb, HashSet<string> emittedStrings)
        {
            int emitted = 0;
            switch (element.ValueKind)
            {
                case JsonValueKind.String:
                    // A bare string at this level came from a parent
                    // that we already passed through TryEmitFreeText's
                    // sibling code; if we're here it's because we recursed
                    // directly into a string without inspecting the
                    // property name. Never the less: if it's interesting
                    // content, push it.
                    if (TryEmitFreeText(element.GetString(), sb, emittedStrings)) emitted++;
                    break;
                case JsonValueKind.Object:
                    foreach (var p in element.EnumerateObject())
                    {
                        // Only emit when the property name carries the
                        // semantic of "textual content". Otherwise (bounds,
                        // pageNumber, confidence, etc.) walk past it.
                        bool isLeafText =
                            string.Equals(p.Name, "text", StringComparison.OrdinalIgnoreCase) ||
                            string.Equals(p.Name, "value", StringComparison.OrdinalIgnoreCase);
                        if (isLeafText && p.Value.ValueKind == JsonValueKind.String)
                        {
                            if (TryEmitFreeText(p.Value.GetString(), sb, emittedStrings)) emitted++;
                        }
                        else if (p.Value.ValueKind == JsonValueKind.Object ||
                                 p.Value.ValueKind == JsonValueKind.Array)
                        {
                            emitted += WalkForText(p.Value, sb, emittedStrings);
                        }
                    }
                    break;
                case JsonValueKind.Array:
                    foreach (var item in element.EnumerateArray())
                    {
                        emitted += WalkForText(item, sb, emittedStrings);
                    }
                    break;
            }
            return emitted;
        }

        private static string SafeFloat(JsonElement obj, string name)
        {
            if (obj.TryGetProperty(name, out var v) && v.ValueKind == JsonValueKind.Number && v.TryGetDouble(out var d))
            {
                return d.ToString("0.##", System.Globalization.CultureInfo.InvariantCulture);
            }
            return "?";
        }

        /// <summary>
        /// Convenience: pick the first property name that exists (case-sensitive
        /// per JSON rules) and serialise its number. Syncfusion emits PascalCase
        /// property names on formObjects; other producers may use camelCase.
        /// </summary>
        private static string SafeFloatPreferred(JsonElement obj, string preferred, string fallback)
        {
            if (obj.TryGetProperty(preferred, out var v) && v.ValueKind == JsonValueKind.Number && v.TryGetDouble(out var d))
            {
                return d.ToString("0.##", System.Globalization.CultureInfo.InvariantCulture);
            }
            if (obj.TryGetProperty(fallback, out v) && v.ValueKind == JsonValueKind.Number && v.TryGetDouble(out d))
            {
                return d.ToString("0.##", System.Globalization.CultureInfo.InvariantCulture);
            }
            return "?";
        }

        /// <summary>
        /// Pull the cell content text out of a table cell. Syncfusion nests
        /// the actual text two levels deep: <c>content.text</c>.
        /// We deliberately drop cells whose text is empty so they don't pollute
        /// the prompt - the empty grid slots are still implied by their absence.
        /// </summary>
        private static string ReadCellText(JsonElement cell)
        {
            JsonElement content;
            if (!TryGetAnyProperty(cell, "Content", "content", out content) ||
                content.ValueKind != JsonValueKind.Object)
            {
                return string.Empty;
            }

            JsonElement text;
            if (!TryGetAnyProperty(content, "Text", "text", out text) ||
                text.ValueKind != JsonValueKind.String)
            {
                return string.Empty;
            }

            return text.GetString() ?? string.Empty;
        }

        /// <summary>
        /// JSON property names are case-sensitive but Syncfusion has shipped
        /// multiple casings (PascalCase "PageNumber" / camelCase "pageNumber"
        /// / locale-dependent variants). Try the supplied candidates in order
        /// and return the first that exists, regardless of value kind.
        /// </summary>
        private static bool TryGetAnyProperty(JsonElement obj, string first, string second, out JsonElement value)
        {
            if (obj.TryGetProperty(first, out value)) return true;
            if (!string.Equals(first, second, StringComparison.Ordinal) &&
                obj.TryGetProperty(second, out value))
            {
                return true;
            }
            value = default;
            return false;
        }

        /// <summary>
        /// Read the page number off a page object, accepting both the canonical
        /// Syncfusion "PageNumber" and the lower-camelCase variant. Defaults
        /// to <paramref name="fallback"/> if neither is present.
        /// </summary>
        private static int ReadPageNumber(JsonElement page, int fallback)
        {
            JsonElement pn;
            if (TryGetAnyProperty(page, "PageNumber", "pageNumber", out pn) &&
                pn.ValueKind == JsonValueKind.Number && pn.TryGetInt32(out var n))
            {
                return n;
            }
            return fallback;
        }

        private static void WriteGenericObject(JsonElement element, StringBuilder sb)
        {
            foreach (var prop in element.EnumerateObject())
            {
                if (prop.Value.ValueKind == JsonValueKind.String &&
                    (string.Equals(prop.Name, "text", StringComparison.OrdinalIgnoreCase) ||
                     string.Equals(prop.Name, "value", StringComparison.OrdinalIgnoreCase)))
                {
                    var s = prop.Value.GetString();
                    if (!string.IsNullOrWhiteSpace(s))
                    {
                        sb.Append(s.Trim()).Append('\n');
                    }
                }
                else if (prop.Value.ValueKind == JsonValueKind.Object)
                {
                    WriteGenericObject(prop.Value, sb);
                }
                else if (prop.Value.ValueKind == JsonValueKind.Array)
                {
                    foreach (var item in prop.Value.EnumerateArray())
                    {
                        if (item.ValueKind == JsonValueKind.String &&
                            (string.Equals(prop.Name, "text", StringComparison.OrdinalIgnoreCase) ||
                             string.Equals(prop.Name, "value", StringComparison.OrdinalIgnoreCase)))
                        {
                            var s = item.GetString();
                            if (!string.IsNullOrWhiteSpace(s))
                            {
                                sb.Append(s.Trim()).Append('\n');
                            }
                        }
                        else if (item.ValueKind == JsonValueKind.Object)
                        {
                            WriteGenericObject(item, sb);
                        }
                    }
                }
            }
        }

        private static IReadOnlyList<ExtractedKeyValue> ParsePairs(string modelResponse)
        {
            if (string.IsNullOrWhiteSpace(modelResponse))
            {
                return Array.Empty<ExtractedKeyValue>();
            }

            // Tolerate accidental markdown fences the model may have added.
            var trimmed = modelResponse.Trim();
            if (trimmed.StartsWith("```", StringComparison.Ordinal))
            {
                var nl = trimmed.IndexOf('\n');
                if (nl > 0) trimmed = trimmed.Substring(nl + 1);
                if (trimmed.EndsWith("```", StringComparison.Ordinal))
                {
                    trimmed = trimmed.Substring(0, trimmed.Length - 3).TrimEnd();
                }
            }

            JsonDocument doc;
            try
            {
                doc = JsonDocument.Parse(trimmed);
            }
            catch (JsonException)
            {
                return Array.Empty<ExtractedKeyValue>();
            }

            using (doc)
            {
                if (!doc.RootElement.TryGetProperty("pairs", out var pairs) ||
                    pairs.ValueKind != JsonValueKind.Array)
                {
                    return Array.Empty<ExtractedKeyValue>();
                }

                var seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
                var result = new List<ExtractedKeyValue>();
                foreach (var entry in pairs.EnumerateArray())
                {
                    if (entry.ValueKind != JsonValueKind.Object) continue;

                    var key = entry.TryGetProperty("key", out var k) && k.ValueKind == JsonValueKind.String
                        ? k.GetString()
                        : null;
                    var value = entry.TryGetProperty("value", out var v) && v.ValueKind == JsonValueKind.String
                        ? v.GetString()
                        : null;

                    if (string.IsNullOrWhiteSpace(key) || string.IsNullOrWhiteSpace(value)) continue;

                    var cleanedKey = CleanKey(key);
                    var cleanedValue = CleanValue(value);

                    if (string.IsNullOrWhiteSpace(cleanedKey) || string.IsNullOrWhiteSpace(cleanedValue)) continue;
                    if (!seen.Add(cleanedKey)) continue; // discard duplicates, keep first

                    result.Add(new ExtractedKeyValue { Key = cleanedKey, Value = cleanedValue });
                }
                return result;
            }
        }

        private static string CleanKey(string raw)
        {
            if (raw == null) return string.Empty;
            // Trim and drop any trailing separator characters the model may have left in.
            return Regex.Replace(raw.Trim(), @"[\s:;\-\u2013\u2014]+$", string.Empty).Trim();
        }

        private static string CleanValue(string raw)
        {
            if (raw == null) return string.Empty;
            var s = raw.Trim();
            // Quote-strip the AI sometimes leaves dangling.
            s = s.Trim('"', '\u201c', '\u201d', '\'');
            // Strip a trailing period that often comes from "Address: 25 Lake View Rd."
            s = Regex.Replace(s, @"\s*\.\s*$", string.Empty);
            return s.Trim();
        }

        private void SafeLog(Exception ex, string message)
        {
            try
            {
                if (_log != null)
                {
                    _log(message, ex);
                }
            }
            catch
            {
                // never let logging tear down the happy path
            }
        }
    }
}