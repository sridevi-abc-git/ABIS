using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;
using System.Web.UI;
using System.Web.UI.WebControls;
using Oracle.DataAccess.Client;
using System.Configuration;
using Oracle.DataAccess.Types;

namespace LEADMaintenance
{
	public partial class _default : System.Web.UI.Page
	{
		private string m_datasource;

		public Boolean IsError { get; set; }
		public string Message { get; set; }

		protected void Page_Load(object sender, EventArgs e)
		{
			


			if (!IsPostBack)
			{
				this.Visible = true;
				userid.Focus();
			}

			try
			{
				m_datasource = Master.Tnsname;
			}

			catch (Exception)
			{
				
			}

		}

		protected void signin_click(object sender, EventArgs e)
		{

			if (validate())
			{
				Response.Redirect("~/Screens/Main.aspx", true);
			}
		}

		protected bool validate()
		{
			OracleConnection	conn;
			OracleCommand		cmd;
			OracleParameter		statusMsg;
			string				connectionString;

			try
			{
				connectionString = Master.CreateConnectionString(userid.Text, pswd.Text);

				conn = new OracleConnection(connectionString);
				cmd = conn.CreateCommand();

				statusMsg = new OracleParameter("p_status_msg", OracleDbType.Varchar2, 8000, null, System.Data.ParameterDirection.Output);

				cmd.CommandType = System.Data.CommandType.StoredProcedure;
				cmd.CommandText = "sitespecific.tl_validateuser";

				cmd.Parameters.Add(new OracleParameter("a_authenticationname", OracleDbType.Varchar2,
													   userid.Text.Length, userid.Text.ToLower(),
														System.Data.ParameterDirection.Input));
				cmd.Parameters.Add(statusMsg);

				cmd.Connection.Open();
				cmd.ExecuteNonQuery();

				// check for error
				if (((INullable)statusMsg.Value).IsNull)
				{

					this.Visible = false;

					// save connection string for other db calls
					pswd.Text = "";
				}
				else
				{
					error_message.Text = statusMsg.Value.ToString();
					IsError = true;
					err_msg.Style["display"] = "block";
				}
			}

			catch (OracleException ex)
			{
				switch (ex.Number)
				{
					case 1017:
						error_message.Text = ex.Message.Substring(ex.Message.IndexOf(':') + 2);
						break;

					case 6550:
						if (HttpContext.Current.IsDebuggingEnabled)
						{
							error_message.Text = ex.Message.ToString();
						}
						else
						{
							error_message.Text = ex.Number.ToString() + " - User not allowed";
						}
						break;

					default:
						if (HttpContext.Current.IsDebuggingEnabled)
						{
							error_message.Text = ex.Message.ToString() + " (" + m_datasource + ")";
						}
						else
						{
							error_message.Text = ex.Number.ToString() + " - Error processing request" + " (" + m_datasource + ")";
						}
						break;
				}

				IsError = true;
				err_msg.Style["display"] = "block";
			}

			catch (Exception ex)
			{
				if (HttpContext.Current.IsDebuggingEnabled)
				{
                    error_message.Text = ex.Message + " - (" + m_datasource + ")";
				}
				else
				{
                    error_message.Text = "Error processing request" + " - (" + m_datasource + ")";
					error_message.Text = ex.Message;
				}

				IsError = true;
				err_msg.Style["display"] = "block";

			}

			finally
			{

			}

			return !IsError;
		}
	}
}