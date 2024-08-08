using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;
using System.Web.UI;
using System.Web.UI.WebControls;

namespace RegisterStudent.Screens
{
	public partial class Information : System.Web.UI.Page
	{
		protected void Page_Load(object sender, EventArgs e)
		{
			if (Request.Url.AbsoluteUri.ToLower().IndexOf("/register") > 0)
			{
				btnexit.PostBackUrl = Request.Url.AbsoluteUri.Substring(0, Request.Url.AbsoluteUri.ToLower().IndexOf("/register") + 1);
			}
			else
			{
				btnexit.PostBackUrl = "~/";
			}

			AppCode.AppLog.Write(new Exception("PostBackUrl: " + btnexit.PostBackUrl), AppCode.AppLog.MessageType.TRACE, Master.ConnectionString);
		}
	}
}