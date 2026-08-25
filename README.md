# Smart Data Extraction Demo in ASP.NET WebForms

ASP.NET Web Forms demo showcasing end-to-end data extraction from scanned PDF documents using the **[Syncfusion Smart Data Extraction](https://www.syncfusion.com/document-sdk/net-smart-data-extraction-library)** library. The app extracts structured key/value data from uploaded or scanned PDFs, lets users review and edit the results in the browser, and exports the final data as JSON for seamless .NET integration.

---

## What it does

1. **Loads** a PDF into the browser through the **[Syncfusion PDF Viewer](https://www.syncfusion.com/pdf-viewer-sdk)**.
2. **Ships** the PDF bytes (as a base64 payload) to a server-side HTTP handler.
3. **Runs OCR + extraction** on the server using `Syncfusion.SmartDataExtractor.DataExtractor`, which returns a structured JSON envelope containing pages, lines, word boxes, tables and form fields.
4. **Detects label/value pairs** by sending the structured OCR text to an OpenAI chat model. The model is asked to identify "Label : Value" relationships such as `Policy Number : POL-12345678`.
5. **Renders** the detected pairs in an editable grid so the user can review, correct, and add rows.
6. **Exports** the final reviewed set as JSON, ready for any downstream .NET service to consume.

If the AI step is not configured, the UI still works — only the raw OCR JSON is returned and the key/value list is empty.

---

## How the extraction pipeline works

```
Browser (EJ2 PDF Viewer)
       |  base64 PDF
       v
Server: HTTP handler
       |
       +-- Syncfusion.SmartDataExtractor.DataExtractor  -->  OCR JSON (pages, lines, tables, form fields)
       |
       +-- AI key/value extractor
              |   truncates + structures the OCR body
              v
           OpenAI Chat Completions
              |   returns label/value pairs
              v
       JSON envelope { pairsCount, pairs[], ocrJson, aiError }
       |
       v
Editable review grid --> "Export JSON"
```

## AI configure & licensing

All runtime secrets and the Syncfusion license are read from the `<appSettings>` section of `Web.config`. Update the three placeholder values before running the app.

Open `Web.config` and replace the placeholders:

```xml
<appSettings>
  <!-- OpenAI: required for the AI key/value detection step.
       If either value is left blank, the handler skips the AI call and
       only the raw OCR JSON is returned to the browser. -->
  <add key="OpenAI.ApiKey" value="YOUR_OPENAI_API_KEY" />
  <add key="OpenAI.Model"  value="YOUR_Model_Name" />

  <!-- Syncfusion: required to remove the Syncfusion evaluation banner
       and unlock the commercial EJ2 / SmartDataExtractor features. -->
  <add key="Syncfusion.LicenseKey" value="YOUR_SYNCFUSION_LICENSE_KEY" />
</appSettings>
```

| Setting | What it is |
| --- | --- |
| `OpenAI.ApiKey` | Your OpenAI API key, used server-side only. |
| `OpenAI.Model`  | The chat-completions model name (e.g. `YOUR_Model_Name`). |
| `Syncfusion.LicenseKey` | Your Syncfusion license key from the Customer Portal; removes the evaluation banner. |
