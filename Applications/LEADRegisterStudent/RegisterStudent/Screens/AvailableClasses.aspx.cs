using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;
using System.Web.UI;
using System.Web.UI.WebControls;

using Oracle.DataAccess.Client;
using Oracle.DataAccess.Types;

namespace RegisterStudent.Screens
{
	public partial class AvailableClasses : System.Web.UI.Page
	{
		protected void Page_Load(object sender, EventArgs e)
		{
			if (!IsPostBack)
			{			
				BuildClassList();
			}

			if (Request.Url.AbsoluteUri.ToLower().IndexOf("/register") > 0)
			{
				btnexit.PostBackUrl = Request.Url.AbsoluteUri.Substring(0, Request.Url.AbsoluteUri.ToLower().IndexOf("/register") + 1);
			}
			else
			{
				btnexit.PostBackUrl = "~/";
			}

		}

		protected void BuildClassList()
		{
			OracleCommand		cmd;
			OracleConnection	conn   = null;
			string				connectionString = Master.ConnectionString;
			OracleParameter		cursor = new OracleParameter("p_data", OracleDbType.RefCursor, System.Data.ParameterDirection.Output);
			OracleDataReader	reader = null;
			int					retry  = 0;

			try
			{
				msg.InnerText = "";
                AppCode.AppLog.Write(new Exception("BuildClassList START"), AppCode.AppLog.MessageType.TRACE, connectionString);

				// call tl package to delete record
				//connectionString = Master.ConnectionString; // System.Configuration.ConfigurationManager.ConnectionStrings["LEAD"].ConnectionString;
				conn = new OracleConnection(connectionString); // Util.Decrypt(connectionString));
				cmd = new OracleCommand("ABC.TL_ClassList", conn);
				cmd.CommandType = System.Data.CommandType.StoredProcedure;

				// add parameters
				cmd.Parameters.Add(new OracleParameter("p_objectid", OracleDbType.Int32, 0, null, System.Data.ParameterDirection.Input));
				cmd.Parameters.Add(new OracleParameter("p_district", OracleDbType.Int32, 0, null, System.Data.ParameterDirection.Input));
				cmd.Parameters.Add(new OracleParameter("p_startdate", OracleDbType.Date, 0, DateTime.Now, System.Data.ParameterDirection.Input));
				cmd.Parameters.Add(new OracleParameter("p_enddate", OracleDbType.Date, 0, null, System.Data.ParameterDirection.Input));
				cmd.Parameters.Add(cursor);

                AppCode.AppLog.Write(new Exception("OPEN " + connectionString), AppCode.AppLog.MessageType.TRACE, connectionString);

                // allow three tries to open connection to database
				while ((retry < 3) && (conn.State != System.Data.ConnectionState.Open))
				{
					try
					{
                        AppCode.AppLog.Write(new Exception("OPEN: " + retry.ToString()), AppCode.AppLog.MessageType.TRACE, connectionString);
						conn.Open();
                        AppCode.AppLog.Write(new Exception("OPEN After: " + retry.ToString()), AppCode.AppLog.MessageType.TRACE, connectionString);
					}

					catch (Exception ex)
					{
						if (retry == 0) AppCode.AppLog.Write(ex, AppCode.AppLog.MessageType.ERROR, connectionString);
					}

					finally
					{
						if (conn.State != System.Data.ConnectionState.Open)
						{
							retry++;

							// wait one second before trying again
							System.Threading.Thread.Sleep(1000);
						}
					}
				}

                AppCode.AppLog.Write(new Exception("AFTER: " + retry.ToString()), AppCode.AppLog.MessageType.TRACE, connectionString);

				if (conn.State == System.Data.ConnectionState.Open)
				{
					cmd.ExecuteNonQuery();

					if (((Oracle.DataAccess.Types.OracleRefCursor)(cursor.Value)).IsNull)
					{
						msg.InnerText = "Error retrieving available class list. Please try again later.";
						msg.Style["color"] = "red";
					}
					else
					{
						reader = ((OracleRefCursor)cursor.Value).GetDataReader();
						classes.DataSource = reader;
						classes.DataBind();

						reader.Close();
						reader = null;
					}

					conn.Close();

				}
				else
				{
					msg.InnerText = "Error retrieving available class list. Please try again later.";
					msg.Style["color"] = "red";
                    AppCode.AppLog.Write(new Exception(msg.InnerText), AppCode.AppLog.MessageType.TRACE, connectionString);

				}
			}

			catch (OracleException ex)
			{
				msg.InnerText = "Error retrieving available class list. Please try again later.";
				msg.Style["color"] = "red";

				AppCode.AppLog.Write(ex, AppCode.AppLog.MessageType.ERROR, connectionString);
			}

			catch (Exception ex)
			{
				msg.InnerText = "Error retrieving available class list. Please try again later.";
				msg.Style["color"] = "red";

				AppCode.AppLog.Write(ex, AppCode.AppLog.MessageType.ERROR, connectionString);
			}

			finally
			{
				if (conn != null)
				{
					if (conn.State == System.Data.ConnectionState.Open) conn.Close();
                    AppCode.AppLog.Write(new Exception("BuildClassList END"), AppCode.AppLog.MessageType.TRACE, connectionString);

				}
			}

		}

		protected void classes_RowDataBound(object sender, GridViewRowEventArgs e)
		{
			GridViewRow row = e.Row;

			if (e.Row.RowType == DataControlRowType.DataRow)
			{
				System.Data.Common.DbDataRecord rec		 = (System.Data.Common.DbDataRecord)e.Row.DataItem;
				bool							full     = (rec.GetString(rec.GetOrdinal("classfull")) == "Y");
				bool							canceled = (rec.GetString(rec.GetOrdinal("classcancelled")) == "Y");
				Label							status	 = (Label)e.Row.Cells[1].FindControl("status");
				bool							alt		 = (e.Row.RowIndex % 2 == 1);
				string							color;

				color = (canceled) ? (alt ? "color:rgba(99, 0, 0, 0.84); background-color:#ffd0d0;" : "color:rgba(99, 0, 0, 0.84); background-color:#fff0f0;") :
							(full) ? (alt ? "color:#0d11b1;background-color:#d0d0ff;" : "color:#0d11b1;background-color:#f0f0ff;") : 
								     (alt ? "background-color:#d0d0d0" : "background-color:#f0f0f0");
				e.Row.Attributes.Add("style", color);
				row.Cells[3].Text = row.Cells[3].Text.Replace("\n", "<br/>");

				if (!canceled)
				{
					if (full) status.Text = "Class Full";
					((Button)e.Row.Cells[0].FindControl("select")).Style["cursor"] = "pointer";
				}
				else
				{
					status.Text = "Cancelled";
					((Button)e.Row.Cells[0].FindControl("select")).Enabled = false;
				}
			}
		}

		protected void classes_RowCommand(object sender, GridViewCommandEventArgs e)
		{
			Response.Redirect("~/Screens/StudentInformation.aspx?class=" + e.CommandArgument.ToString(), true);
		}

	}
}

//	e.Row.Attributes.Add("onmouseover", "this.originalstyle=this.style.backgroundColor;this.style.backgroundColor='#FF9955';");
//	e.Row.Attributes.Add("style", "cursor:pointer;");
//	e.Row.Attributes.Add("onmouseout", "this.style.backgroundColor=this.originalstyle;");
//	//e.Row.Attributes["objectid"] = objectid.ToString();
// e.Row.Attributes["onclick"] = Page.ClientScript.GetPostBackClientHyperlink(classes, "Select$" + e.Row.RowIndex.ToString());
// e.Row.Attributes.Add("onclick", Page.ClientScript.GetPostBackEventReference(classes, "Select$" + e.Row.RowIndex.ToString()));
