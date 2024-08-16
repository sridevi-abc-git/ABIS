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
	public partial class UnregisterStudent : System.Web.UI.Page
	{

		protected void Page_Load(object sender, EventArgs e)
		{
			int?		objectid	= null;

			if (!IsPostBack)
			{
				if (Request.QueryString["value"] != null)
				{
					objectid = Convert.ToInt32(Request.QueryString["value"]);
				}

				if (objectid != null)
				{
					GetStudent(objectid);
				}
			}

			// setup exit link
			if (Request.Url.AbsoluteUri.ToLower().IndexOf("/register") > 0)
			{
				btnexit.PostBackUrl = Request.Url.AbsoluteUri.Substring(0, Request.Url.AbsoluteUri.ToLower().IndexOf("/register") + 1);
				btncancel.PostBackUrl = Request.Url.AbsoluteUri.Substring(0, Request.Url.AbsoluteUri.ToLower().IndexOf("/register") + 1);
			}
			else
			{
				btnexit.PostBackUrl   = "~/";
				btncancel.PostBackUrl = "~/";
			}
		}

		protected void GetStudent(int? objectid)
		{
			OracleCommand		cmd;
			OracleConnection	conn				= null;
			OracleParameter		cursor				= new OracleParameter("p_data", OracleDbType.RefCursor, System.Data.ParameterDirection.Output);
			OracleDataReader	reader				= null;

			try
			{
				conn = new OracleConnection(Master.ConnectionString);
				cmd = new OracleCommand("ABC.TL_STUDENTINFO", conn);
				cmd.CommandType = System.Data.CommandType.StoredProcedure;

				// add parameters
				cmd.Parameters.Add(new OracleParameter("p_objectid", OracleDbType.Int32, 0, objectid, System.Data.ParameterDirection.Input));
				cmd.Parameters.Add(cursor);

				if (OpenConnection(conn))
				{
					cmd.ExecuteNonQuery();

					reader = ((OracleRefCursor)cursor.Value).GetDataReader();
					if (reader.Read())
					{
						lbName.Visible = true;
						txtName.Text = reader.GetString(reader.GetOrdinal("STUDENTNAME"));
						txtEmailAddress.Text = reader.GetString(reader.GetOrdinal("EMAILADDRESS"));
						txtConfirmationNumber.Text = reader.GetDecimal(reader.GetOrdinal("CONFIRMATIONNUMBER")).ToString();
					}
					else
					{
						litMessage.Text = "You are currently not register for the selected class.";
						msgresults.Visible = true;
						request.Visible = false;
					}
					reader.Close();
					reader = null;


					conn.Close();
				}
				else
				{
					litMessage.Text = "Unable to retrieve your student information.  Please try again later.";
//					litMessage.Style["color"] = "red";
				}
			}

			catch (OracleException ex)
			{
				AppCode.AppLog.Write(ex, AppCode.AppLog.MessageType.ERROR, conn.ConnectionString);
				litMessage.Text = "Unable to retrieve your student information.  Please try again later.";
//				msg.Style["color"] = "red";
			}

			catch (Exception ex)
			{
				AppCode.AppLog.Write(ex, AppCode.AppLog.MessageType.ERROR, conn.ConnectionString);
				litMessage.Text = "Unable to retrieve your student information.  Please try again later.";
//				msg.Style["color"] = "red";
			}

			finally
			{
				if (conn != null)
				{
					if (conn.State == System.Data.ConnectionState.Open) conn.Close();
				}
			}

		}

		protected void RemoveStudent(int? objectid, int? confirmationNumber, string emailAddress)
		{
			OracleCommand		cmd;
			OracleConnection	conn				 = null;
			string				connectionString	 = Master.ConnectionString;
			OracleParameter		resultCode			 = new OracleParameter("p_code", OracleDbType.Int32, System.Data.ParameterDirection.Output);
			OracleParameter		results				 = new OracleParameter("p_message", OracleDbType.Varchar2, 8000, null, System.Data.ParameterDirection.Output);
			int					retry				 = 0;

			try
			{
				// call tl package to delete record
				//connectionString = Master.ConnectionString; //System.Configuration.ConfigurationManager.ConnectionStrings["LEAD"].ConnectionString;
				conn = new OracleConnection(connectionString); // Util.Decrypt(connectionString));
				cmd = new OracleCommand("ABC.TL_StudentUpdate", conn);
				cmd.CommandType = System.Data.CommandType.StoredProcedure;

				// add parameters
				cmd.Parameters.Add(new OracleParameter("p_classobjectid", OracleDbType.Int32, 0, null, System.Data.ParameterDirection.Input));
				cmd.Parameters.Add(new OracleParameter("p_studentobjectid", OracleDbType.Int32, 0, objectid, System.Data.ParameterDirection.Input));
				cmd.Parameters.Add(new OracleParameter("p_name", OracleDbType.Varchar2, 0, null, System.Data.ParameterDirection.Input));
				cmd.Parameters.Add(new OracleParameter("p_emailaddress", OracleDbType.Varchar2, emailAddress.Length, emailAddress, System.Data.ParameterDirection.Input));
				cmd.Parameters.Add(new OracleParameter("p_phonenumber", OracleDbType.Varchar2, 0, null, System.Data.ParameterDirection.Input));
				cmd.Parameters.Add(new OracleParameter("p_passfail", OracleDbType.Varchar2, 0, null, System.Data.ParameterDirection.Input));
				cmd.Parameters.Add(new OracleParameter("p_webaddress", OracleDbType.Varchar2, 0, null, System.Data.ParameterDirection.Input));
				cmd.Parameters.Add(new OracleParameter("a_confirmation", OracleDbType.Int32, confirmationNumber, System.Data.ParameterDirection.Input));
				cmd.Parameters.Add(new OracleParameter("p_delete", OracleDbType.Varchar2, 1, "Y", System.Data.ParameterDirection.Input));
				cmd.Parameters.Add(new OracleParameter("p_deleteappl", OracleDbType.Varchar2, 50, "Unregister Student", System.Data.ParameterDirection.Input));
				cmd.Parameters.Add(new OracleParameter("p_mgrname", OracleDbType.Varchar2, 0, null, System.Data.ParameterDirection.Input));
				cmd.Parameters.Add(new OracleParameter("p_mgremailaddress", OracleDbType.Varchar2, 0, null, System.Data.ParameterDirection.Input));
				cmd.Parameters.Add(new OracleParameter("p_mgrphonenumber", OracleDbType.Varchar2, 0, null, System.Data.ParameterDirection.Input));
				cmd.Parameters.Add(new OracleParameter("p_student", OracleDbType.RefCursor, System.Data.ParameterDirection.Output));
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
						System.Threading.Thread.Sleep(1000);
					}
				}

				if (conn.State == System.Data.ConnectionState.Open)
				{
					cmd.ExecuteNonQuery();

					conn.Close();

					// check for message
					if (((INullable)results.Value).IsNull)
					{
						// show complete screen
						litMessage.Text = "You have successfully unregistered from your class.";
						msgresults.Visible = true;
						request.Visible = false;
					}
					else
					{
						// get results.
						int error = 0;

						if (!((INullable)resultCode.Value).IsNull)
						{
							error = Convert.ToInt32(((Oracle.DataAccess.Types.OracleDecimal)(resultCode.Value)).Value);
						}

						Exception		ex = new Exception(results.Value.ToString());

						if (objectid != null) ex.Data["Objectid"] = objectid;
						ex.Data["Address"] = emailAddress;
						if (confirmationNumber != null) ex.Data["Confirmation"] = confirmationNumber.ToString();

						switch (error)
						{
							case 0:
								break;

							case 2:	// email validation failed
							case 3:
								litMessage.Text = results.Value.ToString();
								msgresults.Visible = false;
								request.Visible = true;
								AppCode.AppLog.Write(ex, AppCode.AppLog.MessageType.TRACE, connectionString);
								break;

							default:
								litMessage.Text = "Unregistered from class.";
								AppCode.AppLog.Write(ex, AppCode.AppLog.MessageType.ERROR, connectionString);
								msgresults.Visible = true;
								request.Visible = false;
								break;
						}



					}
				}
			}

			catch (OracleException ex)
			{
				if (objectid != null) ex.Data["Objectid"] = objectid;
				ex.Data["Address"] = emailAddress;
			    if (confirmationNumber != null)	ex.Data["Confirmation"] = confirmationNumber.ToString();

				litMessage.Text = "Error in unregistering from class. Please try again later. ";
				AppCode.AppLog.Write(ex, AppCode.AppLog.MessageType.ERROR, connectionString);
			}

			catch (Exception ex)
			{
				if (objectid != null) ex.Data["Objectid"] = objectid;
				ex.Data["Address"] = emailAddress;
				if (confirmationNumber != null) ex.Data["Confirmation"] = confirmationNumber.ToString();

				litMessage.Text = "Error in unregistering from class. Please try again later.";
				AppCode.AppLog.Write(ex, AppCode.AppLog.MessageType.ERROR, connectionString);
			}

			finally
			{
				if (conn != null)
				{
					if (conn.State == System.Data.ConnectionState.Open) conn.Close();
				}
			}
		}

		protected void unregister_Click(object sender, EventArgs e)
		{
			int		confirmationNumber;
			string	emailAddress;

			int.TryParse(txtConfirmationNumber.Text, out  confirmationNumber);

			if (txtEmailAddress.Text.Length > 0)
			{
				emailAddress = txtEmailAddress.Text;
				RemoveStudent(null, (confirmationNumber == 0 ? null : (Nullable<int>)confirmationNumber), emailAddress);
			}
			else
			{
				// add message that email address must be provided
				litMessage.Text = "Please enter your email address";
			}
		}

		public static bool OpenConnection(OracleConnection conn)
		{
			int					retry  = 0;

			// allow three tries to open connection to database
			while ((retry < 3) && (conn.State != System.Data.ConnectionState.Open))
			{
				try
				{
					conn.Open();
					break;
				}

				catch (Exception ex)
				{
					if (retry == 0) AppCode.AppLog.Write(ex, AppCode.AppLog.MessageType.ERROR, conn.ConnectionString);
				}

				finally
				{
					if (conn.State != System.Data.ConnectionState.Open && retry < 2)
					{
						retry++;

						// wait one second before trying again
						System.Threading.Thread.Sleep(1000);
					}
				}
			}

			return (conn.State == System.Data.ConnectionState.Open);
		}

	}
}