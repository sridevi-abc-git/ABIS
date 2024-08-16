using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;
using System.Web.UI;
using System.Web.UI.WebControls;

using Oracle.DataAccess.Client;
using Oracle.DataAccess.Types;

namespace LEADMaintenance.Screens
{
	public partial class StudentSearch : System.Web.UI.Page
	{
		protected void Page_Load(object sender, EventArgs e)
		{

		}

		protected void search_Click(object sender, EventArgs e)
		{
			OracleCommand		cmd;
			OracleConnection	conn   = null;
			OracleParameter		cursor = new OracleParameter("a_studentdata", OracleDbType.RefCursor, System.Data.ParameterDirection.Output);
			OracleDataReader	reader = null;
			object				confirmationnbr = null;
			Int32				temp;
			try
			{
				if (confirmationnumber.Text.Length > 0)
				{
					if (!Int32.TryParse(confirmationnumber.Text, out temp))
					{
						msg.InnerText = "Please enter a numeric for the confirmation number";
						msg.Style["color"] = "red";

						return;
					}
					else
					{
						confirmationnbr = temp;
					}
				}

				msg.InnerText = "";
				// call tl package to delete record
				string cn = Master.ConnectionString;

				conn = new OracleConnection(cn); //Master.ConnectionString);
				cmd = new OracleCommand("ABC.tl_studentsearch", conn);
				cmd.CommandType = System.Data.CommandType.StoredProcedure;

				// add parameters
				cmd.Parameters.Add(new OracleParameter("a_studentname", OracleDbType.Varchar2, studentname.Text.Length,
														(studentname.Text.Length > 0 ? (object)studentname.Text : null),
														System.Data.ParameterDirection.Input));
				cmd.Parameters.Add(new OracleParameter("a_emailaddress", OracleDbType.Varchar2, emailaddress.Text.Length,
														(emailaddress.Text.Length > 0 ? (object)emailaddress.Text : null),
														System.Data.ParameterDirection.Input));
				cmd.Parameters.Add(new OracleParameter("a_confirmationnumber", OracleDbType.Int32, 0,
														(confirmationnumber.Text.Length > 0 ? confirmationnbr : null),
														System.Data.ParameterDirection.Input));
				cmd.Parameters.Add(new OracleParameter("a_phonenumber", OracleDbType.Varchar2, phonenumber.Text.Length,
														(phonenumber.Text.Length > 0 ? (object) phonenumber.Text : null),
														System.Data.ParameterDirection.Input));
				cmd.Parameters.Add(cursor);

				if (Screens.Site.OpenConnection(conn))
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
						if (reader.HasRows)
						{
							students.DataSource = reader;
							students.DataBind();

							searchinput.Visible = false;
							searchresults.Visible = true;
						}
						else
						{
							msg.InnerText = "No student found for search ceritia.";
							msg.Style["color"] = "red";
						}

						reader.Close();
						reader = null;

					}

					conn.Close();

				}
				else
				{
					msg.InnerText = "Error retrieving student list. Please try again later.";
					msg.Style["color"] = "red";
				}
			}

			catch (OracleException ex)
			{
				msg.InnerText = "Error retrieving student list. Please try again later.";
				msg.Style["color"] = "red";

				Utils.AppLog.Write(ex, Utils.AppLog.MessageType.ERROR);
			}

			catch (Exception ex)
			{
				msg.InnerText = "Error retrieving student list. Please try again later.";
				msg.Style["color"] = "red";

				Utils.AppLog.Write(ex, Utils.AppLog.MessageType.ERROR);
			}

			finally
			{
				if (conn != null)
				{
					if (conn.State == System.Data.ConnectionState.Open) conn.Close();
				}
			}


		}

		protected void students_RowCommand(object sender, GridViewCommandEventArgs e)
		{
			Response.Redirect("~/Screens/StudentInfo.aspx?student=" + e.CommandArgument.ToString(), true);

		}

		protected void students_RowDataBound(object sender, GridViewRowEventArgs e)
		{

		}
	}
}