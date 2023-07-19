//*******************************************************************************************
//    File:         ProcessErrors.cs         
//    Author:       Timothy J. Lord
//    
//    Description:  ProcessErrors class is used to format exceptions/messages into a standard
//                  message box that can be displayed on a web page
//    		 
//    Methods:      ProcessErrors.ProcessMessage(string)
//                  ProcessErrors.ProcessException(Exception, string)
//                  ProcessErrors.ProcessException(Exception, HtmlTextWriter)
//                  ProcessErrors.ProcessException(HtmlTextWriter, string, string)
//
//    $Rev: 51 $   $Date: 2018-09-01 12:02:56 -0700 (Sat, 01 Sep 2018) $
//    $Author: TLord $
//*******************************************************************************************
//  History:
//     Date  Developer   Comment
//----------------------------------------------------------------------------------
//  02/10/2014  TJL      Initial File Created
//*******************************************************************************************
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

using System.Web;
using System.Web.UI;

namespace RQS.Common
{
    public class ProcessErrors
    {
        const string ERRMSG = "width: 100%; text-align:center; color:#7f2222; display: block;";
        const string ERRLINE = "width: 100%; padding-top: 10px; text-align: left; display: block;";
        const string ERRLEFT = "width: 100px; text-align:left; color:#003399; display: inline-block; vertical-align:top;";
        const string ERRRIGHT = "width: 750px; text-align: left; padding-left: 20px; text-indent: -20px; display: inline-block;";

        static public string ProcessMessage(string msg)
        {
            return ProcessException(null, msg);
        }

        /// <summary>
        /// This ProcessException function is a static function to process thrown exceptions and return
        /// the exception(s) in an HTML format.  It will log all errors passed to it.  It will also look
        /// at the debug flag to see what information will sent back to the client screen.
        /// </summary>
        /// <param name="e">exception class to process</param>
        /// <param name="msg">a default message to be displayed on the client</param>
        /// <returns>HTML Formated error message generated from the exception passed to the function</returns>
        static public string ProcessException(Exception e, string msg)
        {
            string results = null;
            System.IO.StringWriter sw = new System.IO.StringWriter();
            System.Web.UI.HtmlTextWriter ht = new System.Web.UI.HtmlTextWriter(sw);

            try
            {
                // build div wrapper around errors
                ht.AddAttribute("style", ERRMSG);
                ht.RenderBeginTag(HtmlTextWriterTag.Div);

                // add message
                ht.AddAttribute("style", ERRLINE);
                ht.RenderBeginTag(HtmlTextWriterTag.Div);
                ht.Write(msg);
                ht.RenderEndTag();

                // if debuging then process exceptions
                if (HttpContext.Current.IsDebuggingEnabled)
                {
                    results = ProcessException(e, ht);
                }

                results = sw.ToString();
            }

            catch (Exception ex)
            {
                results = "ERROR: " + e.Message + "\r\n"
                        + "Processing failure error: " + ex.Message;
            }

            return results;
        }

        /// <summary>
        /// This ProcessException() is called to process one exception class at a time. If their is an 
        /// inner exception this function will call itself with the inner exception for processing.  After 
        /// the inner exception is processed it will then process the current exception. 
        /// </summary>
        /// <param name="e">exception for processing</param>
        /// <param name="ht">HTML Writer for writing the exception information with.</param>
        /// <returns>IF an exception is thrown in the processing of the exception a message string will
        /// be returned</returns>
        static public string ProcessException(Exception e, HtmlTextWriter ht)
        {
            string results = null;

            try
            {
                if (e == null) return results;

                // check if inner exception
                if (e.InnerException != null) results = ProcessException(e.InnerException, ht);

                // was any errors in processing exceptions
                if (results == null)
                {
                    // process exception values
                    ht.RenderBeginTag(HtmlTextWriterTag.Hr);
                    ht.RenderEndTag();

                    // message line
                    ProcessException(ht, "Message:", e.Message);
                    ProcessException(ht, "Source:", e.Source);
                    ProcessException(ht, "Stack trace:", e.StackTrace);

                    foreach (string key in e.Data.Keys)
                    {
                        if (e.Data[key] == null) continue;
                        ProcessException(ht, key + ":", (string)e.Data[key]);
                    }

                    ht.AddAttribute("style", ERRLINE);
                    ht.RenderBeginTag(HtmlTextWriterTag.Div);
                    ht.RenderEndTag();
                }
            }

            catch (Exception ex)
            {
                results = "ERROR: " + e.Message + "\r\n"
                        + "Processing failure error: " + ex.Message;
            }

            return results;
        }

        /// <summary>
        /// This ProcessException is called to produce a single display line of HTML code for the
        /// data that was contained in the exception
        /// </summary>
        /// <param name="e">HTML Writer for writing the exception information with.</param>
        /// <param name="ht">Text to be displayed on the left side of the line</param>
        /// <param name="data">Text information about the exception to be displayed</param>
        static public void ProcessException(HtmlTextWriter ht, string header, string data)
        {
            string[] lines;

            // do not write line if no data to write
            if (data == null) return;

            // put in header line
            ht.AddAttribute("style", ERRLINE);
            ht.RenderBeginTag(HtmlTextWriterTag.Div);
            ht.AddAttribute("style", ERRLEFT);
            ht.RenderBeginTag(HtmlTextWriterTag.Div);
            ht.Write(header);
            ht.RenderEndTag();
            ht.AddAttribute("style", ERRRIGHT);
            ht.RenderBeginTag(HtmlTextWriterTag.Div);

            lines = data.Replace("\r", string.Empty).Split('\n');

            foreach (string line in lines)
            {
                ht.RenderBeginTag(HtmlTextWriterTag.Div);
                ht.Write(line);
                ht.RenderEndTag();
            }

            ht.RenderEndTag();
            ht.RenderEndTag();
        }
    }
}
