<%@ Page Language="C#" AutoEventWireup="true" %>
<!DOCTYPE html>
<html lang="en">
<head runat="server">
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Smart Data Extractor</title>
    <link runat="server" href="~/favicon.ico" rel="shortcut icon" type="image/x-icon" />
    <style type="text/css">
        html, body {
            width: 100%;
            height: 100%;
            margin: 0;
            overflow: hidden;
            background: #f4f6fa;
        }
        .sde-embed {
            display: block;
            width: 100%;
            height: 100%;
            border: 0;
        }
    </style>
</head>
<body>
    <iframe class="sde-embed" src="<%= ResolveUrl("~/Default.aspx") %>" title="Smart Data Extractor"></iframe>
</body>
</html>