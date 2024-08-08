using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;
using System.Web.UI;
using System.Web.UI.WebControls;

namespace LEADMaintenance.Screens
{
	public partial class SiteNav : System.Web.UI.MasterPage
	{
		protected void Page_Load(object sender, EventArgs e)
		{

		}

		public string ConnectionString
		{
			get
			{
				return Master.ConnectionString;

				//string connectionString = (this.ViewState["connectionstring"] != null ?  this.ViewState["connectionstring"].ToString() : "");
				//return ""; // (string)(connectionString != null ? Decrypt(connectionString) : "");
			}
		}


	}
}