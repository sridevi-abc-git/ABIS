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
	public partial class Confirmation : System.Web.UI.Page
	{
		protected void Page_Load(object sender, EventArgs e)
		{
			int		studentObject = Convert.ToInt32(Request.QueryString["value"]);

			if (confirmed(studentObject)) sendconfirmation(studentObject);

			if (Request.Url.AbsoluteUri.ToLower().IndexOf("/register") > 0)
			{
				btnexit.PostBackUrl = Request.Url.AbsoluteUri.Substring(0, Request.Url.AbsoluteUri.ToLower().IndexOf("/register") + 1);
			}
			else
			{
				btnexit.PostBackUrl = "~/";
			}

		}

		protected bool confirmed(int studentObjectId)
		{
			OracleCommand		cmd;
			OracleConnection	conn			 = null;
			OracleParameter		cursor			 = new OracleParameter("p_data", OracleDbType.RefCursor, System.Data.ParameterDirection.Output);
			OracleDataReader	reader			 = null;
			string				connectionString = Master.ConnectionString;
			bool				isStandby		 = false;
			int					retry			 = 0;
			string				website;
			bool				updated			 = false;
			OracleParameter		resultCode		 = new OracleParameter("p_code", OracleDbType.Int32, System.Data.ParameterDirection.Output);
			OracleParameter		results			 = new OracleParameter("p_message", OracleDbType.Varchar2, 8000, null, System.Data.ParameterDirection.Output);
			Exception			e;
	
			try
			{
				website = Request.Url.AbsoluteUri.Substring(0, Request.Url.AbsoluteUri.LastIndexOf("/"));

				// call tl package to delete record
				//connectionString = Master.ConnectionString; //System.Configuration.ConfigurationManager.ConnectionStrings["LEAD"].ConnectionString;
				conn = new OracleConnection(connectionString); // Util.Decrypt(connectionString));
				cmd = new OracleCommand("ABC.TL_StudentUpdate", conn);
				cmd.CommandType = System.Data.CommandType.StoredProcedure;

				// add parameters
				cmd.Parameters.Add(new OracleParameter("p_classobjectid", OracleDbType.Int32, 0, null, System.Data.ParameterDirection.Input));
				cmd.Parameters.Add(new OracleParameter("p_studentobjectid", OracleDbType.Int32, 0, studentObjectId, System.Data.ParameterDirection.Input));
				cmd.Parameters.Add(new OracleParameter("p_name", OracleDbType.Varchar2, 0, null, System.Data.ParameterDirection.Input));
				cmd.Parameters.Add(new OracleParameter("p_emailaddress", OracleDbType.Varchar2, 0, null, System.Data.ParameterDirection.Input));
				cmd.Parameters.Add(new OracleParameter("p_phonenumber", OracleDbType.Varchar2, 0, null, System.Data.ParameterDirection.Input));
				cmd.Parameters.Add(new OracleParameter("p_passfail", OracleDbType.Varchar2, 0, null, System.Data.ParameterDirection.Input));
				cmd.Parameters.Add(new OracleParameter("p_webaddress", OracleDbType.Varchar2, website.Length, website, System.Data.ParameterDirection.Input));
				cmd.Parameters.Add(new OracleParameter("p_confirmation", OracleDbType.Int32, System.Data.ParameterDirection.Input));
				cmd.Parameters.Add(new OracleParameter("p_delete", OracleDbType.Varchar2, 0, null, System.Data.ParameterDirection.Input));
				cmd.Parameters.Add(new OracleParameter("p_deleteappl", OracleDbType.Varchar2, 0, null, System.Data.ParameterDirection.Input));
				cmd.Parameters.Add(new OracleParameter("p_mgrname", OracleDbType.Varchar2, 0, null, System.Data.ParameterDirection.Input));
				cmd.Parameters.Add(new OracleParameter("p_mgremailaddress", OracleDbType.Varchar2, 0, null, System.Data.ParameterDirection.Input));
				cmd.Parameters.Add(new OracleParameter("p_mgrphonenumber", OracleDbType.Varchar2, 0, null, System.Data.ParameterDirection.Input));
				cmd.Parameters.Add(cursor);
				cmd.Parameters.Add(results);
				cmd.Parameters.Add(resultCode);

				// allow three tries to open connection to database
				while ((retry < 3) && (conn.State != System.Data.ConnectionState.Open))
				{
					try
					{
						conn.Open();
					}

					catch (Exception ex)
					{
						if (retry == 0) AppCode.AppLog.Write(ex, AppCode.AppLog.MessageType.ERROR, connectionString);
					}

					finally
					{
						retry++;

						// wait one second before trying again
						if (conn.State != System.Data.ConnectionState.Open) System.Threading.Thread.Sleep(1000);
					}
				}

				if (conn.State == System.Data.ConnectionState.Open)
				{
					cmd.ExecuteNonQuery();
					int error = Convert.ToInt32(((Oracle.DataAccess.Types.OracleDecimal)(resultCode.Value)).ToInt32());
					if (error != 0)
					{
						msg.Style["color"] = "red";
						msg.InnerText = ((((INullable)results.Value).IsNull) ? "Unkown error in confirmation" : results.Value.ToString());

                        if (error < 0)
                        {
						    e = new Exception((((INullable)results.Value).IsNull) ? "Unkown error in confirmation" 
																			      : "Objectid : " + studentObjectId.ToString() + 
																			        " confirmation Error - " + results.Value.ToString());
						    AppCode.AppLog.Write(e, (error == -4) ? AppCode.AppLog.MessageType.TRACE : AppCode.AppLog.MessageType.ERROR, connectionString);
                        }

						msg2.Style["display"] = "none";
						title.InnerText = "Class Registration Confirmation";
						standbymessage.Visible = false;
					}
					else
					{
						reader = ((OracleRefCursor)cursor.Value).GetDataReader();
						if (reader.Read())
						{
							classtimeexpression.Text = reader.GetString(reader.GetOrdinal("CLASSTIMEEXPRESSION"));
							location.Text = reader.GetString(reader.GetOrdinal("LOCATION")).Replace("\n", "<br/>");
							confirmationNumber.Text = reader.GetDecimal(reader.GetOrdinal("CONFIRMATIONNUMBER")).ToString();
							StudentName.Text = reader.GetString(reader.GetOrdinal("STUDENTNAME"));
							emailaddress.Text = reader.GetString(reader.GetOrdinal("EMAILADDRESS"));
							isStandby = (reader.GetString(reader.GetOrdinal("STUDENTNAME")) == "Y");

							if (reader.GetString(reader.GetOrdinal("ISSTANDBY")) == "Y")
							{
								title.InnerText = "Standby Registration Confirmation";
								standbymessage.Visible = true;
							}
							else
							{
								title.InnerText = "Class Registration Confirmation";
								standbymessage.Visible = false;
							}
						}
						reader.Close();
						reader = null;
						updated = true;
					}

					conn.Close();

					e = new Exception("Confirmation for: " + studentObjectId.ToString() + " " + StudentName.Text);
					AppCode.AppLog.Write(e, AppCode.AppLog.MessageType.TRACE, connectionString);

				}
				else
				{
					msg.InnerText = "Error in processing your confirmation. You may not receive you confirmation email. Please try again later.";
					msg.Style["color"] = "red";

					AppCode.AppLog.Write(new Exception("Failure to login"), AppCode.AppLog.MessageType.ERROR, connectionString);

				}
			}

			catch (OracleException ex)
			{
				ex.Data.Add("Objectid", studentObjectId.ToString());
				ex.Data.Add("Method", "confirmed");
				ex.Data.Add("Name", StudentName.Text);
				AppCode.AppLog.Write(ex, AppCode.AppLog.MessageType.ERROR, connectionString);

				msg.InnerText = "Error in processing your confirmation. You may not receive you confirmation email. Please try again later.";
				msg.Style["color"] = "red";
			}

			catch (Exception ex)
			{
				ex.Data.Add("Objectid", studentObjectId.ToString());
				ex.Data.Add("Method", "confirmed");
				ex.Data.Add("Name", StudentName.Text);
				AppCode.AppLog.Write(ex, AppCode.AppLog.MessageType.ERROR, connectionString);

				msg.InnerText = "Error in processing your confirmation. You may not receive you confirmation email. Please try again later.";
				msg.Style["color"] = "red";
			}

			finally
			{
				if (conn != null)
				{
					if (conn.State == System.Data.ConnectionState.Open) conn.Close();
				}
			}

			return updated;
		}

		protected void sendconfirmation(int studentObjectId)
		{
			OracleCommand		cmd;
			OracleConnection	conn			 = null;
			string				connectionString = Master.ConnectionString;
			int					retry			 = 0;

			try
			{
				conn = new OracleConnection(connectionString); // Util.Decrypt(connectionString));
				cmd = new OracleCommand("ABC.tl_sendconfirmationemail", conn);
				cmd.CommandType = System.Data.CommandType.StoredProcedure;

				// add parameters
				cmd.Parameters.Add(new OracleParameter("a_objectid", OracleDbType.Int32, 0, studentObjectId, System.Data.ParameterDirection.Input));
				cmd.Parameters.Add(new OracleParameter("a_asofdate", OracleDbType.Date, 0, null, System.Data.ParameterDirection.Input));
				cmd.Parameters.Add(new OracleParameter("a_fromaddresscolname", OracleDbType.Varchar2, 50, "FromEmailAddress", System.Data.ParameterDirection.Input));
				cmd.Parameters.Add(new OracleParameter("a_toaddresscolname", OracleDbType.Varchar2, 50, "EmailAddress", System.Data.ParameterDirection.Input));
				cmd.Parameters.Add(new OracleParameter("a_ccaddresscolname", OracleDbType.Varchar2, 0, null, System.Data.ParameterDirection.Input));
				cmd.Parameters.Add(new OracleParameter("a_bccaddresscolname", OracleDbType.Varchar2, 0, null, System.Data.ParameterDirection.Input));
				cmd.Parameters.Add(new OracleParameter("a_subjectcolname", OracleDbType.Varchar2, 50, "RegistrationEmailSubject", System.Data.ParameterDirection.Input));
				cmd.Parameters.Add(new OracleParameter("a_bodycolname", OracleDbType.Varchar2, 50, "RegistrationEmailBody", System.Data.ParameterDirection.Input));
				cmd.Parameters.Add(new OracleParameter("a_documentidcolname", OracleDbType.Varchar2, 0, null, System.Data.ParameterDirection.Input));
				cmd.Parameters.Add(new OracleParameter("a_documentendpointname", OracleDbType.Varchar2, 0, null, System.Data.ParameterDirection.Input));
				cmd.Parameters.Add(new OracleParameter("a_bodyishtml", OracleDbType.Varchar2, 1, "N", System.Data.ParameterDirection.Input));

				// allow three tries to open connection to database
				while ((retry < 3) && (conn.State != System.Data.ConnectionState.Open))
				{
					try
					{
						conn.Open();
					}

					catch (Exception ex)
					{
						if (retry == 0) AppCode.AppLog.Write(ex, AppCode.AppLog.MessageType.ERROR, connectionString);
					}

					finally
					{
						retry++;

						// wait one second before trying again
						if (conn.State != System.Data.ConnectionState.Open) System.Threading.Thread.Sleep(1000);
					}
				}

				if (conn.State == System.Data.ConnectionState.Open)
				{
					cmd.ExecuteNonQuery();
					conn.Close();

					AppCode.AppLog.Write(new Exception("Confirmation for: " + studentObjectId.ToString() + " " + StudentName.Text), 
														AppCode.AppLog.MessageType.TRACE, connectionString);
				}
				else
				{
					msg.InnerText = "Error Sending Confirmation Email.";
					msg.Style["color"] = "red";
					AppCode.AppLog.Write(new Exception("Failure to login"), AppCode.AppLog.MessageType.ERROR, connectionString);
				}
			}

			catch (OracleException ex)
			{
				ex.Data.Add("Objectid", studentObjectId.ToString());
				ex.Data.Add("Method", "sendconfirmation");
				ex.Data.Add("Name", StudentName.Text);
				AppCode.AppLog.Write(ex, AppCode.AppLog.MessageType.ERROR, connectionString);

				msg.InnerText = "Error in processing your confirmation. You may not receive you confirmation email. Please try again later.";
				msg.Style["color"] = "red";
			}

			catch (Exception ex)
			{
				ex.Data.Add("Objectid", studentObjectId.ToString());
				ex.Data.Add("Method", "sendconfirmation");
				ex.Data.Add("Name", StudentName.Text);
				AppCode.AppLog.Write(ex, AppCode.AppLog.MessageType.ERROR, connectionString);

				msg.InnerText = "Error in processing your confirmation. You may not receive you confirmation email. Please try again later.";
				msg.Style["color"] = "red";
			}

			finally
			{
				if (conn != null)
				{
					if (conn.State == System.Data.ConnectionState.Open) conn.Close();
				}
			}
		}

	}

	
}