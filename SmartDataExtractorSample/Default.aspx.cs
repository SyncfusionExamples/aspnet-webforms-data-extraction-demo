using System;
using System.IO;
using System.Web.UI;

namespace SmartDataExtractorSample
{
    // Code-behind intentionally left as a thin Page. The full pipeline now lives in
    // SmartDataExtract.ashx, which accepts the PDF bytes that the EJ2 viewer is
    // currently displaying. Keeping the Page class empty avoids duplicate WebMethod
    // bindings with the handler-side implementation.
    public partial class _Default : Page
    {
        protected void Page_Load(object sender, EventArgs e)
        {

        }
    }
}