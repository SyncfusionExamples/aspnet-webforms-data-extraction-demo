<%@ Page Title="" Language="C#" MasterPageFile="~/Site.Master" AutoEventWireup="true" CodeBehind="Default.aspx.cs" Inherits="SmartDataExtractorSample._Default" %>

<asp:Content ID="BodyContent" ContentPlaceHolderID="MainContent" runat="server">

    <style type="text/css">
        /* Make the page fill the viewport without page-level scroll. */
        html, body { height: 100%; margin: 0; padding: 0; overflow: hidden; }
        main { flex: 1 1 auto; min-height: 0; display: flex; flex-direction: column; }
        .sde-layout {
            flex: 1 1 auto;
            min-height: 0;
            display: flex;
            gap: 16px;
            align-items: stretch;
        }
        .sde-panel {
            border: 1px solid #e2e6ee;
            border-radius: 10px;
            padding: 0;
            background: #ffffff;
            box-shadow: 0 1px 3px rgba(16, 24, 40, 0.06),
                        0 1px 2px rgba(16, 24, 40, 0.04);
            overflow: hidden;
            position: relative;
            min-height: 0;
            display: flex;
            flex-direction: column;
        }
        .sde-left {
            flex: 1 1 50%;
            min-height: 0;
            display: flex;
            flex-direction: column;
        }
        .sde-right {
            flex: 1 1 50%;
            display: flex;
            flex-direction: column;
            min-height: 0;
            padding: 16px;
            box-sizing: border-box;
        }
        #pdfviewer_container {
            width: 100%;
            flex: 1 1 auto;
            min-height: 0;
        }
        .sde-actions {
            margin-top: 12px;
            display: flex;
            gap: 12px;
            align-items: center;
        }
        .sde-right .sde-actions {
            justify-content: flex-end;
        }
        .sde-footer {
            flex: 0 0 auto;
            margin-top: 10px;
            display: flex;
            gap: 16px;
            align-items: center;
            justify-content: space-between;
            padding: 0 8px;
            box-sizing: border-box;
        }
        .sde-footer-left {
            flex: 0 0 auto;
        }
        .sde-footer-right {
            flex: 0 0 auto;
            display: flex;
            gap: 12px;
            align-items: center;
        }
        .sde-note {
            color: #555;
            font-size: 13px;
        }
        .sde-right-title {
            font-weight: 600;
            font-size: 15px;
            margin: 0 0 6px 0;
            color: #1f2a44;
        }
        .sde-pairs {
            margin-top: 8px;
            border: 1px solid #e2e6ee;
            border-radius: 6px;
            background: #fff;
            flex: 1 1 auto;
            min-height: 0;
            overflow: auto;
            display: flex;
            flex-direction: column;
        }
        .sde-pair-table {
            display: block;
            flex: 1 1 auto;
            overflow: auto;
            min-height: 0;
        }
        .sde-pair-row {
            display: grid;
            grid-template-columns: minmax(110px, 30%) 1fr 90px;
            border-bottom: 1px solid #eee;
            font-size: 13px;
            align-items: stretch;
        }
        .sde-pair-row:last-child {
            border-bottom: 0;
        }
        .sde-pair-key {
            padding: 6px 8px;
            background: #f4f6fa;
            font-weight: 600;
            color: #234;
            border-right: 1px solid #eee;
            word-break: break-word;
        }
        .sde-pair-value {
            padding: 6px 8px;
            color: #112;
            word-break: break-word;
        }
        .sde-pair-value input.sde-inline-input,
        .sde-pair-key input.sde-inline-input {
            width: 100%;
            box-sizing: border-box;
            padding: 4px 6px;
            font-size: 13px;
            border: 1px solid #66f;
            border-radius: 3px;
            outline: none;
            background: #fff;
        }
        .sde-pair-action {
            padding: 6px 8px;
            text-align: right;
            border-left: 1px solid #eee;
            background: #fafbfc;
        }
        .sde-pair-action button {
            border: 1px solid #dfe5ee;
            background: #fff;
            color: #243149;
            border-radius: 8px;
            cursor: pointer;
            padding: 7px 12px;
            font-size: 12px;
            min-width: 64px;
            transition: all 0.15s ease;
        }
        .sde-pair-header {
            display: grid;
            grid-template-columns: minmax(110px, 30%) 1fr 90px;
            border-bottom: 1px solid #e5ebf3;
            background: #f7f9fc;
            flex: 0 0 auto;
            width: 100%;
            box-sizing: border-box;
            align-self: stretch;
        }
        .sde-pair-header > div {
            text-align: left;
            font-size: 12px;
            text-transform: uppercase;
            letter-spacing: 0.08em;
            color: #65748b;
            padding: 6px 8px;
        }
        .sde-pair-header > div + div {
            border-left: 1px solid #e5ebf3;
        }
        .sde-pair-header > div:last-child {
            text-align: right;
        }
        .sde-pair-empty,
        .sde-pair-skipped {
            padding: 10px;
            color: #777;
            font-style: italic;
            font-size: 13px;
        }
        .sde-pair-skipped {
            color: #946a00;
            background: #fff8e1;
        }
        .sde-right-bottom {
            flex: 0 0 auto;
            margin-top: 14px;
            padding-top: 4px;
            display: flex;
            justify-content: flex-end;
            gap: 10px;
        }
        .sde-add-row {
            display: grid;
            grid-template-columns: minmax(110px, 30%) 1fr auto;
            border-top: 1px solid #eee;
            background: #fafbfc;
        }
        .sde-add-row input.sde-inline-input {
            width: 100%;
            box-sizing: border-box;
            padding: 4px 6px;
            font-size: 13px;
            border: 1px solid #66f;
            border-radius: 3px;
            outline: none;
        }
        .sde-new-item-add,
        .sde-new-item-cancel {
            border: 1px solid #dfe5ee;
            background: #fff;
            color: #243149;
            border-radius: 8px;
            cursor: pointer;
            padding: 7px 12px;
            font-size: 12px;
            min-width: 64px;
            transition: all 0.15s ease;
            display: inline-block;
        }
        .sde-add-row .sde-pair-action {
            display: flex;
            flex-wrap: nowrap;
            flex-direction: row;
            justify-content: flex-end;
            align-items: center;
            gap: 6px;
        }

        /* Run OCR and Extract button - match the live-examples "run-buttons" styling.
           Scoped to #btnRunOcr so no other items in the page are affected. */
        #btnRunOcr {
            vertical-align: middle;
            justify-content: center;
            align-items: center;
            height: 30px;
            margin: 0 0 0 425px;
            display: inline-flex;
            box-shadow: none;
            border-radius: 6px;
            padding: 0 14px;
            font-size: 13px;
            font-weight: 400;
            font-family: 'Roboto', Arial, sans-serif;
            cursor: pointer;
            transition: all 0.2s ease;
            gap: 6px;
            background: #0057ff;
            border: 2px solid #0057ff;
            color: #ffffff;
            transform: scale(1.05);
        }
        #btnRunOcr:hover:not(:disabled) {
            background: #0046cc;
            border-color: #0046cc;
            box-shadow: 0 6px 16px rgba(0, 87, 255, 0.45);
            transform: scale(1.08);
        }
        #btnRunOcr:active:not(:disabled) {
            transform: scale(0.98);
        }
        #btnRunOcr:disabled {
            opacity: 0.5;
            cursor: not-allowed;
            background: #f5f5f5;
            border-color: #d1d5db;
            color: #79747e;
        }
        #btnRunOcr.running,
        #btnRunOcr.running:disabled {
            background: #0057ff !important;
            border-color: #0057ff !important;
            color: #ffffff !important;
            opacity: 1 !important;
            box-shadow: 0 4px 12px rgba(0, 87, 255, 0.35);
            transform: scale(1.05);
            animation: sdeRunBtnPop 0.35s ease-out,
                       sdeRunPulseGlow 1.4s ease-out 0.35s 3;
        }
        #btnRunOcr svg {
            opacity: 1 !important;
        }

        /* Same primary-button UI design as #btnRunOcr, applied to
           #btnAddNewItem and #btnExport. Pulse animation intentionally omitted
           because these buttons do not have a long-running state. */
        #btnAddNewItem,
        #btnExport {
            vertical-align: middle;
            justify-content: center;
            align-items: center;
            height: 30px;
            width: 150px;
            margin: 0;
            display: inline-flex;
            box-sizing: border-box;
            box-shadow: none;
            border-radius: 6px;
            padding: 0 14px;
            font-size: 13px;
            font-weight: 400;
            font-family: 'Roboto', Arial, sans-serif;
            cursor: pointer;
            transition: all 0.2s ease;
            gap: 6px;
            background: #0057ff;
            border: 2px solid #0057ff;
            color: #ffffff;
            transform: scale(1.05);
        }
        #btnAddNewItem:hover:not(:disabled),
        #btnExport:hover:not(:disabled) {
            background: #0046cc;
            border-color: #0046cc;
            box-shadow: 0 6px 16px rgba(0, 87, 255, 0.45);
            transform: scale(1.08);
        }
        #btnAddNewItem:active:not(:disabled),
        #btnExport:active:not(:disabled) {
            transform: scale(0.98);
        }
        #btnAddNewItem:disabled,
        #btnExport:disabled {
            opacity: 0.5;
            cursor: not-allowed;
            background: #f5f5f5;
            border-color: #d1d5db;
            color: #79747e;
        }
        #btnAddNewItem svg,
        #btnExport svg {
            width: 14px;
            height: 14px;
            flex: 0 0 14px;
            opacity: 1 !important;
        }
        @keyframes sdeRunBtnPop {
            0% {
                transform: scale(1);
                box-shadow: 0 0 0 rgba(0, 87, 255, 0);
            }
            60% {
                transform: scale(1.08);
                box-shadow: 0 0 0 8px rgba(0, 87, 255, 0);
            }
            100% {
                transform: scale(1.05);
                box-shadow: 0 4px 12px rgba(0, 87, 255, 0.35);
            }
        }
        @keyframes sdeRunPulseGlow {
            0% {
                box-shadow: 0 4px 12px rgba(0, 87, 255, 0.35),
                            0 0 0 0 rgba(0, 87, 255, 0.6);
            }
            70% {
                box-shadow: 0 4px 12px rgba(0, 87, 255, 0.35),
                            0 0 0 14px rgba(0, 87, 255, 0);
            }
            100% {
                box-shadow: 0 4px 12px rgba(0, 87, 255, 0.35),
                            0 0 0 0 rgba(0, 87, 255, 0);
            }
        }
            </style>

    <main>
        <div class="sde-layout">
            <!-- LEFT: Syncfusion PDF Viewer container -->
            <section class="sde-panel sde-left" aria-label="PDF Viewer">
                <div id="pdfviewer_container"></div>
            </section>

            <!-- RIGHT: Extracted key/value pairs -->
            <section class="sde-panel sde-right" aria-label="Extracted Key/Value Pairs">
                <div class="sde-right-title">Extracted Data</div>
                <div class="sde-note" id="sdePairsStatus">Click <strong>Run OCR and Extract</strong> to detect label/value pairs (e.g. <em>Policy Number : POL-12345678</em>)</div>
                <div class="sde-pairs" id="sdePairsList" aria-live="polite">
                    <div class="sde-pair-header">
                        <div>Key</div>
                        <div>Value</div>
                        <div>Action</div>
                    </div>
                    <div class="sde-pair-empty">No result yet.</div>
                </div>
                <div class="sde-right-bottom">
                    <button id="btnAddNewItem" type="button">
                        <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">
                            <path d="M12 5V19M5 12H19" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" />
                        </svg>
                        <span style="white-space: nowrap;">Add new item</span>
                    </button>
                </div>
            </section>
        </div>

        <!-- Bottom action bar -->
        <div class="sde-footer">
            <div class="sde-footer-left">
                <button id="btnRunOcr" type="button" style="margin-left:550px; vertical-align:middle;">
                    <svg width="12" height="12" viewBox="0 0 24 24" fill="currentColor" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">
                        <path d="M8 5V19L19 12L8 5Z" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" />
                    </svg>
                    <span>Run OCR and Extract</span>
                </button>
            </div>
            <div class="sde-footer-right">
                <button id="btnExport" type="button">
                    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">
                        <path d="M12 2V14M12 14L7 9M12 14L17 9M4 20H20" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" />
                    </svg>
                    <span style="white-space: nowrap;">Export Data</span>
                </button>
            </div>
        </div>
    </main>

    <script type="text/javascript">
        // Registering Syncfusion license key
        ej.base.registerLicense('<%= System.Configuration.ConfigurationManager.AppSettings["Syncfusion.LicenseKey"] %>');
        // Server-side injected values (URLs, defaults, etc.)
        window.SDE_DEFAULT_PDF_URL = '<%= ResolveUrl("~/Default_Input/Input.pdf") %>';
        window.SDE_EXTRACT_ENDPOINT = '<%= ResolveUrl("~/SmartDataExtract.ashx") %>';

        // Convert a Blob into a base64 data URI (async, returns a Promise).
        function sdeBlobToDataUri(blob) {
            return new Promise(function (resolve, reject) {
                var reader = new FileReader();
                reader.onloadend = function () { resolve(reader.result); };
                reader.onerror = reject;
                reader.readAsDataURL(blob);
            });
        }

        // Fetch the default PDF as a data URI so the EJ2 viewer can load it
        // without a serviceUrl. Falls back to the HTTP URL if XHR fails.
        function sdeLoadDefaultPdfAsDataUri(url) {
            return fetch(url, { credentials: 'same-origin' })
                .then(function (r) {
                    if (!r.ok) { throw new Error('HTTP ' + r.status); }
                    return r.blob();
                })
                .then(sdeBlobToDataUri);
        }

        // Initialize Syncfusion EJ2 PDF Viewer on the left container
        document.addEventListener('DOMContentLoaded', function () {
            if (typeof ej === 'undefined' || !ej.pdfviewer || !ej.pdfviewer.PdfViewer) {
                console.warn('Syncfusion PDF Viewer script not loaded yet.');
                return;
            }

            var pdfUrl = window.SDE_DEFAULT_PDF_URL || 'Default_Input/Input.pdf';

            // Try to fetch and embed as base64; if that fails, use the URL directly.
            sdeLoadDefaultPdfAsDataUri(pdfUrl)
                .catch(function (err) {
                    console.warn('SDE: falling back to URL load. Reason:', err);
                    return pdfUrl; // pass the URL through to the viewer
                })
                .then(function (documentPath) {
                    // Remember the bytes the viewer is loading so we can stream them back
                    // to the server when the user clicks "Run OCR and Extract".
                    // documentPath is either a base64 data URI or a remote URL.
                    window.SDE_LOADED_DOCUMENT_URI = documentPath;

                    if (!documentPath.startsWith && String(documentPath).indexOf('data:') !== 0 &&
                        typeof documentPath === 'string' && documentPath.indexOf('http') !== 0) {
                        // neither data uri nor http(s) url -> treat as site-relative URL
                    }

                    var viewer = new ej.pdfviewer.PdfViewer({
                        documentPath: documentPath,
                        serviceUrl: '', // Set your Web API service URL here if using server-backed viewer
                        enableToolbar: true,
                        enableAnnotation: false,
                        enableAnnotationToolbar: false,
                        enablePageOrganizer: false,
                        enableTextSelection: false,
                        enableFormFields: false,
                        enableBookmark: false,
                        enableDownload: false,
                        enablePrint: false,
                        enableSearch: false,
                        toolbarSettings: {
                            showTooltip: true,
                            toolbarItems: [
                                'OpenOption',
                                'PageNavigationTool',
                                'MagnificationTool'
                            ]
                        }
                    });

                    // When the viewer reports that it has finished loading the document,
                    // snapshot the bytes so the extraction step can use the exact same stream.
                    viewer.documentLoad = function (args) {
                        try {
                            if (viewer.exportAsObject) {
                                window.SDE_LOADED_PDF_INFO = viewer.exportAsObject();
                            }
                            // IMPORTANT: resolve the promise WITH the bytes so that downstream
                            // consumers (sdeExtractLoadedPdf) actually receive the Uint8Array.
                            // Use the viewer's current document path at the moment extraction is requested.
                            window.SDE_DOCUMENT_BYTES = sdeDocumentPathToBytes(documentPath)
                                .then(function (bytes) {
                                    window.SDE_LOADED_PDF_BYTES = bytes;
                                    return bytes;
                                });

                            // After the *first* document has loaded we want subsequent loads
                            // (e.g. user picked a new file via the Open menu) to wipe the
                            // previously extracted key/value table. The first load itself
                            // already shows the empty state, so skip the reset there.
                            if (window.SDE_HAS_INITIAL_LOAD === true) {
                                try {
                                    // Wait until the new bytes are actually available, then
                                    // clear the right-side panel. This guarantees the next
                                    // "Run OCR and Extract" click reads the fresh stream.
                                    window.SDE_DOCUMENT_BYTES.then(function () {
                                        sdeResetExtractionPanel();
                                    }, function () {
                                        sdeResetExtractionPanel();
                                    });
                                } catch (ex) {
                                    console.warn('SDE: failed to reset key/value panel for new load.', ex);
                                    sdeResetExtractionPanel();
                                }
                            } else {
                                window.SDE_HAS_INITIAL_LOAD = true;
                            }
                        } catch (ex) {
                            console.warn('SDE: documentLoad hook failed.', ex);
                        }
                    };

                    viewer.appendTo('#pdfviewer_container');
                    window.SDE_PDF_VIEWER = viewer;
                });
        });

        // Reset the right-side key/value panel back to its initial empty state.
        // Used when the user picks a different PDF in the viewer: stale extracted
        // pairs would otherwise linger until the next "Run OCR and Extract".
        function sdeResetExtractionPanel() {
            try {
                var list = document.getElementById('sdePairsList');
                var status = document.getElementById('sdePairsStatus');

                if (list) {
                    list.innerHTML = '';
                    var hdr = document.createElement('div');
                    hdr.className = 'sde-pair-header';
                    var hk = document.createElement('div'); hk.textContent = 'Key';
                    var hv = document.createElement('div'); hv.textContent = 'Value';
                    var ha = document.createElement('div'); ha.textContent = 'Action';
                    hdr.appendChild(hk); hdr.appendChild(hv); hdr.appendChild(ha);
                    list.appendChild(hdr);

                    var empty = document.createElement('div');
                    empty.className = 'sde-pair-empty';
                    empty.textContent = 'No result yet.';
                    list.appendChild(empty);
                }

                if (status) {
                    status.textContent = 'Click Run OCR and Extract to detect label/value pairs (e.g. Policy Number : POL-12345678)';
                    // Strip any inline color the busy/error path may have stamped on it.
                    status.style.color = '';
                    status.style.removeProperty('color');
                }

                // Drop the in-memory extracted pairs so a click on "Export Data" with
                // no fresh extraction is treated as "nothing to export".
                window.SDE_CURRENT_PAIRS = [];

                // Drop any cached byte handles. sdeRefreshLoadedDocumentBytes() in
                // the click handler will rebuild them from the live viewer state.
                window.SDE_LOADED_PDF_BYTES = null;
                window.SDE_DOCUMENT_BYTES = null;
            } catch (ex) {
                console.warn('SDE: sdeResetExtractionPanel failed.', ex);
            }
        }

        // Convert the viewer's documentPath (data URI, http(s) URL, or site-relative URL)
        // into a Uint8Array we can hand back to the server.
        function sdeDocumentPathToBytes(documentPath) {
            return new Promise(function (resolve, reject) {
                if (!documentPath) { reject(new Error('No document loaded in viewer.')); return; }
                if (typeof documentPath === 'string' && documentPath.indexOf('data:') === 0) {
                    try {
                        var commaIdx = documentPath.indexOf(',');
                        var meta = documentPath.substring(5, commaIdx); // e.g. "application/pdf;base64"
                        var bin = documentPath.substring(commaIdx + 1);
                        if (meta.indexOf('base64') !== -1) {
                            var raw = atob(bin);
                            var arr = new Uint8Array(raw.length);
                            for (var i = 0; i < raw.length; i++) { arr[i] = raw.charCodeAt(i); }
                            resolve(arr);
                            return;
                        }
                        // url-encoded data URI
                        var decoded = decodeURIComponent(bin);
                        var bytes = new Uint8Array(decoded.length);
                        for (var j = 0; j < decoded.length; j++) { bytes[j] = decoded.charCodeAt(j); }
                        resolve(bytes);
                    } catch (ex) { reject(ex); }
                    return;
                }

                // Otherwise fetch the URL and turn the blob into bytes.
                fetch(documentPath, { credentials: 'same-origin' })
                    .then(function (r) {
                        if (!r.ok) { throw new Error('HTTP ' + r.status); }
                        return r.arrayBuffer();
                    })
                    .then(function (buf) { resolve(new Uint8Array(buf)); })
                    .catch(reject);
            });
        }

        // Encode a Uint8Array as a base64 string (works for arbitrary byte values).
        function sdeBytesToBase64(bytes) {
            var CHUNK = 0x8000;
            var binary = '';
            for (var i = 0; i < bytes.length; i += CHUNK) {
                binary += String.fromCharCode.apply(null, bytes.subarray(i, i + CHUNK));
            }
            return btoa(binary);
        }

        // Post the PDF bytes that the EJ2 viewer currently displays to the server,
        // run the Syncfusion SmartDataExtractor pipeline, and return the JSON text.
        function sdeExtractLoadedPdf() {
            var p = window.SDE_DOCUMENT_BYTES;
            if (!(p && typeof p.then === 'function')) {
                return Promise.reject(new Error('PDF document is still loading in the viewer. Please wait a moment and try again.'));
            }
            return p.then(function (bytes) {
                if (!bytes || !(bytes.length > 0)) {
                    // The viewer finished loading, but the bytes we captured are empty.
                    // This typically means the EJ2 viewer was given a URL it cannot fetch
                    // (CORS, 404, or it stripped the data URI). Surface a clear hint.
                    throw new Error('Loaded PDF buffer is empty. The viewer could not retrieve the source PDF. Verify that Default_Input/Input.pdf is reachable from the browser and re-open the page.');
                }
                return fetch(window.SDE_EXTRACT_ENDPOINT, {
                    method: 'POST',
                    credentials: 'same-origin',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ pdfBase64: sdeBytesToBase64(bytes) })
                }).then(function (resp) {
                    // Always read the body so we can surface server-side error messages.
                    return resp.text().then(function (body) {
                        if (!resp.ok) {
                            // Try to surface the JSON {error: "..."} payload our handler emits.
                            var detail = body;
                            try {
                                var parsed = JSON.parse(body);
                                if (parsed && parsed.error) { detail = parsed.error; }
                            } catch (e) { /* not JSON, use raw body */ }
                            throw new Error('HTTP ' + resp.status + ' from extract handler: ' + detail);
                        }
                        return body;
                    });
                });
            });
        }

        // Re-read the currently loaded viewer document and refresh the byte cache.
        // This avoids reusing stale bytes when the user opens a new PDF.
        function sdeRefreshLoadedDocumentBytes() {
            var viewer = window.SDE_PDF_VIEWER;
            if (!viewer) {
                return Promise.reject(new Error('PDF viewer is not initialized.'));
            }

            var currentPath = null;
            try {
                if (viewer.fileByteArray && viewer.fileByteArray.length > 0) {
                    var liveBytes = viewer.fileByteArray instanceof Uint8Array
                        ? viewer.fileByteArray
                        : new Uint8Array(viewer.fileByteArray);
                    window.SDE_LOADED_PDF_BYTES = liveBytes;
                    window.SDE_DOCUMENT_BYTES = Promise.resolve(liveBytes);
                    return Promise.resolve(liveBytes);
                }

                currentPath = viewer.documentPath || viewer.currentDocumentPath || window.SDE_LOADED_DOCUMENT_URI;
                if (!currentPath && viewer.exportAsObject) {
                    var snapshot = viewer.exportAsObject();
                    if (snapshot) {
                        currentPath = snapshot.documentPath || snapshot.document || snapshot.url;
                    }
                }
            } catch (ex) {
                currentPath = window.SDE_LOADED_DOCUMENT_URI;
            }

            if (!currentPath) {
                return Promise.reject(new Error('Unable to determine the currently loaded PDF in the viewer.'));
            }

            window.SDE_LOADED_DOCUMENT_URI = currentPath;
            if (typeof currentPath === 'string' && currentPath.indexOf('data:application/pdf;base64,') === 0) {
                var base64 = currentPath.substring('data:application/pdf;base64,'.length);
                var raw = atob(base64);
                var data = new Uint8Array(raw.length);
                for (var i = 0; i < raw.length; i++) { data[i] = raw.charCodeAt(i); }
                window.SDE_LOADED_PDF_BYTES = data;
                window.SDE_DOCUMENT_BYTES = Promise.resolve(data);
                return Promise.resolve(data);
            }

            return sdeDocumentPathToBytes(currentPath).then(function (bytes) {
                window.SDE_LOADED_PDF_BYTES = bytes;
                window.SDE_DOCUMENT_BYTES = Promise.resolve(bytes);
                return bytes;
            });
        }

        // Run OCR + extract against the server-side Syncfusion SmartDataExtractor
        // pipeline using the PDF stream currently loaded in the EJ2 viewer, and
        // render the resulting key/value pairs in the right-side panel.
        (function () {
            var btn = document.getElementById('btnRunOcr');
            if (!btn) { return; }

            function sdeBuildListHeader(list) {
                if (!list || list.querySelector('.sde-pair-header')) { return; }
                var hdr = document.createElement('div');
                hdr.className = 'sde-pair-header';
                var k = document.createElement('div');
                k.textContent = 'Key';
                var v = document.createElement('div');
                v.textContent = 'Value';
                var a = document.createElement('div');
                a.textContent = 'Action';
                hdr.appendChild(k);
                hdr.appendChild(v);
                hdr.appendChild(a);
                list.appendChild(hdr);
            }

            function setBusy(busy) {
                btn.disabled = !!busy;
                if (busy) {
                    btn.classList.add('running');
                    btn.setAttribute('data-label', btn.innerHTML);
                    btn.innerHTML =
                        '<svg width="12" height="12" viewBox="0 0 24 24" fill="currentColor" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">' +
                        '<path d="M8 5V19L19 12L8 5Z" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" />' +
                        '</svg>' +
                        '<span>Running…</span>';
                } else {
                    btn.classList.remove('running');
                    var previous = btn.getAttribute('data-label');
                    if (previous) {
                        btn.innerHTML = previous;
                        btn.removeAttribute('data-label');
                    }
                }
                var status = document.getElementById('sdePairsStatus');
                var list = document.getElementById('sdePairsList');
                if (busy) {
                    if (status) { status.textContent = 'Running OCR and extraction on the loaded PDF…'; }
                    if (list) {
                        list.innerHTML = '';
                        var busyRow = document.createElement('div');
                        busyRow.className = 'sde-pair-empty';
                        busyRow.textContent = 'Analyzing document and extracting key-value pairs...';
                        list.appendChild(busyRow);
                    }
                }
            }

            function showError(msg) {
                var status = document.getElementById('sdePairsStatus');
                var list = document.getElementById('sdePairsList');
                if (status) {
                    status.textContent = 'Error: ' + msg;
                    status.style.color = '#b00020';
                }
                if (list) {
                    list.innerHTML = '';
                    var empty = document.createElement('div');
                    empty.className = 'sde-pair-skipped';
                    empty.textContent = 'Extraction failed. ' + msg;
                    list.appendChild(empty);
                }
            }

            function renderPairsTable(list, pairs) {
                list.innerHTML = '';
                sdeBuildListHeader(list);
                window.SDE_CURRENT_PAIRS = pairs.slice();

                if (!pairs.length) {
                    var empty = document.createElement('div');
                    empty.className = 'sde-pair-empty';
                    empty.textContent = 'No key/value pairs detected.';
                    list.appendChild(empty);
                    return;
                }

                for (var i = 0; i < pairs.length; i++) {
                    (function () {
                        var entry = pairs[i];
                        if (!entry || !entry.key) return;

                        var row = document.createElement('div');
                        row.className = 'sde-pair-row';

                        var k = document.createElement('div');
                        k.className = 'sde-pair-key';
                        k.textContent = entry.key;

                        var v = document.createElement('div');
                        v.className = 'sde-pair-value';
                        v.textContent = (entry.value == null || entry.value === '') ? '—' : entry.value;

                        var a = document.createElement('div');
                        a.className = 'sde-pair-action';

                        var actionBtn = document.createElement('button');
                        actionBtn.type = 'button';
                        actionBtn.textContent = 'Edit';

                        var originalKey = (entry.key == null) ? '' : String(entry.key);
                        var original = (entry.value == null) ? '' : String(entry.value);
                        var currentKeyInput = null;
                        var currentValueInput = null;

                        function setDisplay(keyText, valueText) {
                            k.textContent = (keyText == null || keyText === '') ? '—' : keyText;
                            v.textContent = (valueText == null || valueText === '') ? '—' : valueText;
                        }

                        function syncExportSnapshot(nextKey, nextValue) {
                            try {
                                var snap = window.SDE_CURRENT_PAIRS;
                                if (!snap) { return; }
                                for (var j = 0; j < snap.length; j++) {
                                    var p = snap[j];
                                    if (p && p.key === originalKey) {
                                        snap[j] = { key: nextKey, value: nextValue };
                                        break;
                                    }
                                }
                            } catch (e) { }
                        }

                        function enterEdit() {
                            row.setAttribute('data-editing', '1');
                            k.textContent = '';
                            v.textContent = '';

                            var keyInput = document.createElement('input');
                            keyInput.type = 'text';
                            keyInput.className = 'sde-inline-input';
                            keyInput.value = originalKey;
                            k.appendChild(keyInput);

                            var valueInput = document.createElement('input');
                            valueInput.type = 'text';
                            valueInput.className = 'sde-inline-input';
                            valueInput.value = original;
                            v.appendChild(valueInput);

                            currentKeyInput = keyInput;
                            currentValueInput = valueInput;
                            actionBtn.textContent = 'Save';
                            try { valueInput.focus(); valueInput.select(); } catch (e) { }
                        }

                        function exitEdit(commit) {
                            var nextValue = currentValueInput ? currentValueInput.value : original;
                            var nextKey = currentKeyInput ? currentKeyInput.value : originalKey;

                            if (currentKeyInput && currentKeyInput.parentNode) {
                                currentKeyInput.parentNode.removeChild(currentKeyInput);
                            }
                            if (currentValueInput && currentValueInput.parentNode) {
                                currentValueInput.parentNode.removeChild(currentValueInput);
                            }
                            currentKeyInput = null;
                            currentValueInput = null;

                            if (commit) {
                                var trimmedKey = (nextKey || '').toString().trim();
                                if (!trimmedKey) {
                                    // Preserve the previous behavior: keep editing on empty key.
                                    var keyInput = document.createElement('input');
                                    keyInput.type = 'text';
                                    keyInput.className = 'sde-inline-input';
                                    keyInput.value = nextKey;
                                    k.appendChild(keyInput);
                                    var valueInput = document.createElement('input');
                                    valueInput.type = 'text';
                                    valueInput.className = 'sde-inline-input';
                                    valueInput.value = nextValue;
                                    v.appendChild(valueInput);
                                    currentKeyInput = keyInput;
                                    currentValueInput = valueInput;
                                    try { keyInput.focus(); } catch (e) { }
                                    return;
                                }
                                entry.key = trimmedKey;
                                entry.value = nextValue;
                                originalKey = trimmedKey;
                                original = nextValue;
                                syncExportSnapshot(trimmedKey, nextValue);
                            }

                            setDisplay(originalKey, commit ? nextValue : original);
                            row.removeAttribute('data-editing');
                            actionBtn.textContent = 'Edit';
                        }

                        actionBtn.addEventListener('click', function () {
                            if (row.getAttribute('data-editing') === '1') {
                                exitEdit(true);
                            } else {
                                enterEdit();
                            }
                        });

                        row.addEventListener('keydown', function (ev) {
                            if (row.getAttribute('data-editing') !== '1') { return; }
                            if (ev.key === 'Enter') {
                                ev.preventDefault();
                                exitEdit(true);
                            } else if (ev.key === 'Escape') {
                                ev.preventDefault();
                                exitEdit(false);
                            }
                        });

                        a.appendChild(actionBtn);
                        row.appendChild(k);
                        row.appendChild(v);
                        row.appendChild(a);
                        list.appendChild(row);
                    })();
                }
            }

            function renderNewRowEditor() {
                var list = document.getElementById('sdePairsList');
                var status = document.getElementById('sdePairsStatus');
                if (!list || !status) { return; }

                var existing = list.querySelector('.sde-add-row[data-new-item="1"]');
                if (existing) { return; }

                var row = document.createElement('div');
                row.className = 'sde-add-row';
                row.setAttribute('data-new-item', '1');

                var keyCell = document.createElement('div');
                keyCell.className = 'sde-pair-key';
                var keyInput = document.createElement('input');
                keyInput.type = 'text';
                keyInput.className = 'sde-inline-input';
                keyInput.placeholder = 'Key';
                keyCell.appendChild(keyInput);

                var valueCell = document.createElement('div');
                valueCell.className = 'sde-pair-value';
                var valueInput = document.createElement('input');
                valueInput.type = 'text';
                valueInput.className = 'sde-inline-input';
                valueInput.placeholder = 'Value';
                valueCell.appendChild(valueInput);

                var actionCell = document.createElement('div');
                actionCell.className = 'sde-pair-action';
                actionCell.innerHTML = '<button type="button" class="sde-new-item-add">Add</button> <button type="button" class="sde-new-item-cancel">Cancel</button>';

                function removeEditor() {
                    if (row.parentNode) { row.parentNode.removeChild(row); }
                    status.style.color = '#555';
                    status.textContent = 'Add new item cancelled.';
                }

                function commitEditor() {
                    var key = keyInput.value.trim();
                    var value = valueInput.value;
                    if (!key) {
                        status.style.color = '#b00020';
                        status.textContent = 'Key is required.';
                        try { keyInput.focus(); } catch (e) { }
                        return;
                    }
                    var pairs = window.SDE_CURRENT_PAIRS || [];
                    pairs.push({ key: key, value: value });
                    window.SDE_CURRENT_PAIRS = pairs;
                    renderPairsTable(list, pairs);
                    status.style.color = '#555';
                    status.textContent = 'Added 1 new item.';
                }

                actionCell.querySelector('.sde-new-item-add').addEventListener('click', commitEditor);
                actionCell.querySelector('.sde-new-item-cancel').addEventListener('click', removeEditor);

                row.appendChild(keyCell);
                row.appendChild(valueCell);
                row.appendChild(actionCell);
                list.appendChild(row);
                try { keyInput.focus(); } catch (e) { }
            }

            function renderExtractionSummary(jsonText) {
                var status = document.getElementById('sdePairsStatus');
                var list = document.getElementById('sdePairsList');
                if (!status || !list) { return; }

                var parsed = null;
                try { parsed = JSON.parse(jsonText); } catch (e) { parsed = null; }

                if (parsed && Array.isArray(parsed.pairs)) {
                    renderPairsTable(list, parsed.pairs);
                    if (parsed.aiError) {
                        status.textContent = 'Extraction finished, but the AI step failed: ' + parsed.aiError;
                    } else if (parsed.pairs.length > 0) {
                        status.textContent = 'AI detected ' + parsed.pairs.length + ' key/value pair(s).';
                    } else {
                        status.textContent = 'No key/value pairs detected.';
                    }
                    return;
                }

                var pageCount = null;
                var lineCount = null;
                if (parsed && parsed.pages && Array.isArray(parsed.pages)) {
                    pageCount = parsed.pages.length;
                    lineCount = parsed.pages.reduce(function (acc, p) {
                        return acc + ((p && Array.isArray(p.lines)) ? p.lines.length : 0);
                    }, 0);
                }

                if (pageCount != null) {
                    list.innerHTML = '';
                    sdeBuildListHeader(list);
                    var row = document.createElement('div');
                    row.className = 'sde-pair-row';
                    var k = document.createElement('div');
                    k.className = 'sde-pair-key';
                    k.textContent = 'Summary';
                    var v = document.createElement('div');
                    v.className = 'sde-pair-value';
                    v.textContent = pageCount + ' page(s)' + (lineCount != null ? ', ' + lineCount + ' line(s) extracted.' : '.');
                    var a = document.createElement('div');
                    a.className = 'sde-pair-action';
                    row.appendChild(k);
                    row.appendChild(v);
                    row.appendChild(a);
                    list.appendChild(row);
                    window.SDE_CURRENT_PAIRS = [];
                    status.textContent = 'Extraction succeeded: ' + pageCount + ' page(s), ' + lineCount + ' line(s).';
                } else {
                    status.textContent = 'Extraction returned non-standard JSON (shown below).';
                }
            }

            btn.addEventListener('click', function () {
                if (!window.SDE_EXTRACT_ENDPOINT) {
                    showError('Extract endpoint is not configured.');
                    return;
                }
                setBusy(true);

                sdeRefreshLoadedDocumentBytes()
                    .then(function () { return sdeExtractLoadedPdf(); })
                    .then(function (json) {
                        setBusy(false);
                        renderExtractionSummary(json);
                    })
                    .catch(function (err) {
                        setBusy(false);
                        var message = (err && err.get_message && err.get_message())
                            || (err && err.Message)
                            || (err && err.message)
                            || 'Unknown error calling the server.';
                        showError(message);
                    });
            });

            var addNewItemBtn = document.getElementById('btnAddNewItem');
            if (addNewItemBtn) {
                addNewItemBtn.addEventListener('click', function () {
                    renderNewRowEditor();
                });
            }
        })();

        // Export Data: download the latest AI-extracted key/value pairs as a .json file.
        (function () {
            var exportBtn = document.getElementById('btnExport');
            if (!exportBtn) { return; }

            function timestamp() {
                var d = new Date();
                function pad(n) { return n < 10 ? '0' + n : '' + n; }
                return d.getFullYear() + pad(d.getMonth() + 1) + pad(d.getDate())
                    + '_' + pad(d.getHours()) + pad(d.getMinutes()) + pad(d.getSeconds());
            }

            exportBtn.addEventListener('click', function () {
                var pairs = window.SDE_CURRENT_PAIRS;
                if (!pairs || !pairs.length) {
                    var status = document.getElementById('sdePairsStatus');
                    if (status) {
                        status.textContent = 'Nothing to export yet. Run OCR and Extract first.';
                        status.style.color = '#b00020';
                    }
                    return;
                }

                // Build the envelope that goes into the downloaded file.
                var payload = {
                    exportedAt: new Date().toISOString(),
                    pairsCount: pairs.length,
                    pairs: pairs.map(function (p) {
                        return { key: p.key, value: (p.value == null ? '' : String(p.value)) };
                    })
                };

                var json = JSON.stringify(payload, null, 2);
                var blob = new Blob([json], { type: 'application/json;charset=utf-8' });
                var url = URL.createObjectURL(blob);

                var a = document.createElement('a');
                a.href = url;
                a.download = 'Output.json';
                document.body.appendChild(a);
                a.click();
                document.body.removeChild(a);
                // Release the object URL on the next tick.
                setTimeout(function () { URL.revokeObjectURL(url); }, 0);
            });
        })();
    </script>

</asp:Content>
