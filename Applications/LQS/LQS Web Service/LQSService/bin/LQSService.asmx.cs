using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;
using System.Web.Services;

namespace LQSService
{
    /// <summary>
    /// Summary description for LQS
    /// </summary>
    [WebService(Namespace = "http://lqs.abc.ca.gov/")]
    [WebServiceBinding(ConformsTo = WsiProfiles.BasicProfile1_1)]
    [System.ComponentModel.ToolboxItem(false)]
    // To allow this Web Service to be called from script, using ASP.NET AJAX, uncomment the following line. 
    // [System.Web.Script.Services.ScriptService]
    public class LQS : System.Web.Services.WebService 
    {
        string m_conn = System.Configuration.ConfigurationManager.AppSettings["connection"];

        [WebMethod]
        public string DatabaseAvailable()
        {

            Process process = new Process(m_conn, false);
            return process.DatabaseAvailable();
        }

        [WebMethod]
        public string Init()
        {
            Process process = new Process(m_conn, false);
            return process.Init();
        }

        [WebMethod]
        public string LicenseRequest(string param)
        {
            Process process = new Process(m_conn, false);
            return process.LicenseRequest(param);
        }

    }
}
