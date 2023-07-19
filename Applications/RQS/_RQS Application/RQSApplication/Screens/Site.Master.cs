
using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;
using System.Web.UI;
using System.Web.UI.WebControls;

using System.Configuration;
using System.Text;
using System.Reflection;

namespace RQS.Screens
{
    public partial class Site : System.Web.UI.MasterPage
    {
        private String m_cnfgName;

        public ABCRQSUtils.AppConfigurationSettings cnfg
        {
            get
            {
                return ABCRQSUtils.AppConfigurationSettings.getConfigurationSection(m_cnfgName);
            }
        }

        protected void Page_Init(object sender, EventArgs e)
        {
            if (Request.Url.Host.Contains("."))
            {
                m_cnfgName = Request.Url.Host.Substring(0, Request.Url.Host.IndexOf("."));
            }
            else
            {
                m_cnfgName = (Request.Url.Host.ToLower() == "localhost" ? System.Environment.MachineName : Request.Url.Host);
            }
        }

        protected void Page_Load(object sender, EventArgs e)
        {
			string key = Request.Url.Authority.ToLower();
            string[] items;
            DateTime curr;
            string query;
            byte[] decodedInfo;

            try
            {
                if (!IsPostBack)
                {
					Environment.SetEnvironmentVariable("DATA_SOURCE", null, EnvironmentVariableTarget.Process);

					hdnService.Value     = Request.Url.Scheme + "://" + HttpContext.Current.Request.Url.Authority + "/WebService.svc/Request";
					hdnUserService.Value = Request.Url.Scheme + "://" + HttpContext.Current.Request.Url.Authority + "/WebService.svc/User";
					hdnTnsname.Value     = cnfg.AppSettings["tnsname"].value;
                    
                    ltrVersion.Text = "Version: " + Assembly.GetAssembly(typeof(Site)).GetName().Version; 

                    // -----------------------------------------------------------------------------------------
                    // check if user is logged in
                    // -----------------------------------------------------------------------------------------
                    if (Request.Url.LocalPath.ToLower() != "/default.aspx")
                    {
                        // decode query string
                        decodedInfo = Convert.FromBase64String(Request.Url.Query.Substring(1));
                        query = Encoding.UTF8.GetString(decodedInfo);

                        curr = new DateTime(Convert.ToInt32(query.Substring(6, 4)),
                                            Convert.ToInt32(query.Substring(0, 2)),
                                            Convert.ToInt32(query.Substring(3, 2)),
                                            Convert.ToInt32(query.Substring(11, 2)),
                                            Convert.ToInt32(query.Substring(14, 2)),
                                            0);

                        TimeSpan timeDiff = DateTime.Now - curr;
                        if (timeDiff.TotalSeconds > 180)
                        {
                            // out of time go to login page
                            //                            Response.Redirect("/default.aspx", true);
                        }

                        // save user id in screen
                        items = query.Split('|');
                        hdnUser.Value = items[1];
                    }
                }
            }

            catch (Exception ex)
            {
                ltrError.Text = Common.ProcessErrors.ProcessException(ex, Request.Url.Host.ToLower() + " Config File: " + m_cnfgName + " Page load error");
                pnlMainContent.Visible = false;
                pnlError.Visible = true;
            }

        }
    }
}