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
	public partial class ClassSearch : System.Web.UI.Page
	{
		protected void Page_LoadComplete(object sender, EventArgs e)
		{

			if (!IsPostBack)
			{
				GetDistricts();

				start_date.Text = new DateTime(DateTime.Now.Year, DateTime.Now.Month, 1).AddMonths(-1).ToString("MM/dd/yyyy");
				end_date.Text = new DateTime(DateTime.Now.Year, DateTime.Now.Month, 1).AddMonths(1).AddDays(-1).ToString("MM/dd/yyyy");
			}
		}

		protected void GetDistricts()
		{
			OracleCommand		cmd;
			OracleConnection	conn   = null;
			OracleParameter		cursor = new OracleParameter("p_data", OracleDbType.RefCursor, System.Data.ParameterDirection.Output);
			OracleDataReader	reader = null;
			ListItem			item   = new ListItem("All Districts", "");

			try
			{
				msg.InnerText = "";

				// call tl package to delete record
				string cn = Master.ConnectionString;

				conn = new OracleConnection(cn); //Master.ConnectionString);
				cmd = new OracleCommand("ABC.TL_DistrictList", conn);
				cmd.CommandType = System.Data.CommandType.StoredProcedure;

				// add parameters
				cmd.Parameters.Add(cursor);

				if (Screens.Site.OpenConnection(conn))
				{
					cmd.ExecuteNonQuery();

					if (((Oracle.DataAccess.Types.OracleRefCursor)(cursor.Value)).IsNull)
					{
						msg.InnerText = "Error retrieving District list. Please try again later.";
						msg.Style["color"] = "red";
					}
					else
					{
						reader = ((OracleRefCursor)cursor.Value).GetDataReader();
						DistrictList.Items.Clear();
						DistrictList.Items.Add(item);

						while(reader.Read())
						{
							item = new ListItem();
							
							item.Text  = reader.GetString(reader.GetOrdinal("OFFICE"));
							item.Value = reader.GetString(reader.GetOrdinal("OFFICE"));
							//item.Value = reader.GetDecimal(reader.GetOrdinal("OFFICEOBJECTID")).ToString();
							DistrictList.Items.Add(item);
						}

						classes.DataSource = reader;
						classes.DataBind();

						reader.Close();
						reader = null;
					}

					conn.Close();

				}
				else
				{
					msg.InnerText = "Error retrieving District list. Please try again later.";
					msg.Style["color"] = "red";
				}
			}

			catch (OracleException ex)
			{
				msg.InnerText = "Error retrieving District list. Please try again later.";
				msg.Style["color"] = "red";

				Utils.AppLog.Write(ex, Utils.AppLog.MessageType.ERROR);
			}

			catch (Exception ex)
			{
				msg.InnerText = "Error retrieving District list. Please try again later.";
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


		protected void BuildClassList()
		{
			OracleCommand		cmd;
			OracleConnection	conn   = null;
			OracleParameter		cursor = new OracleParameter("p_data", OracleDbType.RefCursor, System.Data.ParameterDirection.Output);
			OracleDataReader	reader = null;

			try
			{
				msg.InnerText = "";

				// call tl package to delete record
				string cn = Master.ConnectionString;

				conn = new OracleConnection(cn); //Master.ConnectionString);
				cmd = new OracleCommand("ABC.TL_ClassList", conn);
				cmd.CommandType = System.Data.CommandType.StoredProcedure;

				// add parameters
				cmd.Parameters.Add(new OracleParameter("p_objectid", OracleDbType.Int32, 0, null, System.Data.ParameterDirection.Input));
				cmd.Parameters.Add(new OracleParameter("p_district", OracleDbType.Varchar2, DistrictList.SelectedValue.Length,
														(DistrictList.SelectedValue.Length > 0 ? (object) DistrictList.SelectedValue : null),
														System.Data.ParameterDirection.Input));
				cmd.Parameters.Add(new OracleParameter("p_startdate", OracleDbType.Date, 0, 
														(start_date.Text.Length > 0? (object) Convert.ToDateTime(start_date.Text) : null), 
														 System.Data.ParameterDirection.Input));
				cmd.Parameters.Add(new OracleParameter("p_enddate", OracleDbType.Date, 0, 
														 (end_date.Text.Length > 0 ? (object) Convert.ToDateTime(end_date.Text) : null), 
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
							classes.DataSource = reader;
							classes.DataBind();

							searchinput.Visible = false;
							searchresults.Visible = true;
						}
						else
						{
							msg.InnerText = "No classes found for search ceritia.";
							msg.Style["color"] = "red";
						}

						reader.Close();
						reader = null;

					}

					conn.Close();

				}
				else
				{
					msg.InnerText = "Error retrieving available class list. Please try again later.";
					msg.Style["color"] = "red";
				}
			}

			catch (OracleException ex)
			{
				msg.InnerText = "Error retrieving available class list. Please try again later.";
				msg.Style["color"] = "red";

				Utils.AppLog.Write(ex, Utils.AppLog.MessageType.ERROR);
			}

			catch (Exception ex)
			{
				msg.InnerText = "Error retrieving available class list. Please try again later.";
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

		protected void classes_RowDataBound(object sender, GridViewRowEventArgs e)
		{
			GridViewRow row = e.Row;

			if (e.Row.RowType == DataControlRowType.DataRow)
			{
				System.Data.Common.DbDataRecord rec		 = (System.Data.Common.DbDataRecord)e.Row.DataItem;
				bool							full     = (rec.GetString(rec.GetOrdinal("classfull")) == "Y");
				bool							canceled = (rec.GetString(rec.GetOrdinal("classcancelled")) == "Y");
				Label							status	 = (Label)e.Row.Cells[1].FindControl("status");
				Button							btn      = (Button)e.Row.Cells[0].FindControl("select");
				bool							alt		 = (e.Row.RowIndex % 2 == 1);

				row.Cells[3].Text = row.Cells[3].Text.Replace("\n", "<br/>");

				((Button)e.Row.Cells[0].FindControl("select")).Style["cursor"] = "pointer";

				status.Text = (canceled)? "Canceled" : (full)? "Class Full" : "" ;
				if (canceled) btn.Visible = false;
			}
		}

		protected void classes_RowCommand(object sender, GridViewCommandEventArgs e)
		{
			Response.Redirect("~/Screens/ClassRoster.aspx?class=" + e.CommandArgument.ToString(), true);
		}

		protected void search_Click(object sender, EventArgs e)
		{
			BuildClassList();
		}

	}
}