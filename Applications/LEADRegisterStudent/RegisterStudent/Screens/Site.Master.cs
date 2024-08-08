using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;
using System.Web.UI;
using System.Web.UI.WebControls;

namespace RegisterStudent.Screens
{
	public partial class Site : System.Web.UI.MasterPage
	{
		private			 string							m_tnsname;
		private			 string							m_connectionString;
		private readonly Dictionary<string, string>		m_source		= new Dictionary<string, string> 
																					{ 
																						//{ "traceleadpublicdev",  "abcdev2"},
																						//{ "traceleadpublictest", "abctest"},
																						//{ "traceleadpublic",     "abcprod"}
																						{ "/traceleadpublicdev1/register",   "abcdev"},
																						{ "/traceleadpublictest1/register",  "abctest"},
																						{ "/traceleadpublic/register",      "abcprod"},
																						{ "/traceleadpublicdevsb/register", "abcsb"}
																					};
		public string Tnsname { get { return m_tnsname; } }
		public string ConnectionString 
		{ 
			get
			{
				if (m_connectionString == null)
				{
//					if (!m_source.TryGetValue(Request.Url.Authority.ToLower(), out m_tnsname)) m_tnsname = "abcdev2";
                    //AppCode.AppLog.Write(new Exception("URL: " + 
                    //Request.Url.AbsolutePath.Substring(0, Request.Url.AbsolutePath.ToLower().IndexOf("/screens"))), AppCode.AppLog.MessageType.TRACE, "");
                    //if (!m_source.TryGetValue(Request.Url.AbsolutePath.Substring(0, Request.Url.AbsolutePath.ToLower().IndexOf("/screens")).ToLower(), out m_tnsname)) m_tnsname = "abcdev";
                    m_connectionString = System.Configuration.ConfigurationManager.ConnectionStrings["LEAD"].ConnectionString; // +";Data Source=" + m_tnsname;

				}
				return m_connectionString;
			}
		}

		protected void Page_Load(object sender, EventArgs e)
		{
//			hostname.Text = Request.Url.AbsolutePath.Substring(0, Request.Url.AbsolutePath.ToLower().IndexOf("/screens")).ToLower() + " - " + m_connectionString;
			if (Request.Url.AbsoluteUri.ToLower().IndexOf("/register") > 0)
			{
				homelink.PostBackUrl = Request.Url.AbsoluteUri.Substring(0, Request.Url.AbsoluteUri.ToLower().IndexOf("/register") + 1);
			}
			else
			{
				homelink.PostBackUrl = "~/";
			}
		}
	}
}