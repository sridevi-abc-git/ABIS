using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;
using System.Web.UI;
using System.Web.UI.WebControls;

using ABCRQSUtils;
using System.DirectoryServices.AccountManagement;
using System.Web.Script.Serialization;


namespace RQS
{
    public partial class Default : System.Web.UI.Page
    {
// ************************************************************
// Removed AD authentication from RQS Use only DB login
// ************************************************************
        //protected void Page_Load(object sender, EventArgs e)
        //{
            //Dictionary<string, string>  parameters;
            //RQS.Common.User             u;
            //string                      connection;
            //string                      results     = null;
            //string                      data;
            //string                      adUserId;

            //try
            //{
            //    if (!IsPostBack && System.Web.HttpContext.Current != null)
            //    {

                    //if (System.Web.HttpContext.Current.User.Identity.IsAuthenticated)
                    //{
                    //parameters = HttpContext.Current.Request.QueryString.Keys.Cast<string>()
                    //                                .ToDictionary(k => k, v => HttpContext.Current.Request.QueryString[v]);

                    //    adUserId = System.Web.HttpContext.Current.User.Identity.Name; // userName;

                    //    if (parameters.Count == 0)
                    //    {
                    //        data = "{\"USER\":\"" + adUserId.Substring(adUserId.IndexOf("\\") + 1) + "\"}";

                    //        connection = Master.cnfg.AppSettings["connection"].value;

                    //        u = new Common.User(connection);
                    //        results = u.UserInfo(data);
                    //        hdnResults.Value = results;
                    //    }
                    //    else
                    //    {
                            //if (parameters.ContainsKey("login"))
                            //{
                            //    if (parameters["login"] == "db")
                            //    {
                            //        hdnResults.Value = "{\"db\":\"logon\"}";
                            //    }
                            //}
                //        }
                //    }
        //        }
        //    }

        //    catch (Exception ex)
        //    {
        //        lbinfo.Text += ex.Message + " *** " + ex.StackTrace;
        //    }
        //}
    }
}
