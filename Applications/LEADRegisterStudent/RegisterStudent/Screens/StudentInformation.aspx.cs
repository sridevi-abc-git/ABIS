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
	public partial class StudentInformation : System.Web.UI.Page
	{
		public class CaptchaResponse
		{
			public string success { get; set; }
		}

		protected void Page_Load(object sender, EventArgs e)
		{
			if (!IsPostBack)
			{ 
				classobjectid.Value = Request.QueryString["class"]; // "82184932";
				GetClassInfo(Convert.ToInt32(classobjectid.Value));
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

		void GetClassInfo(int objectid)
		{
			OracleCommand		cmd;
			OracleConnection	conn				= null;
			string				connectionString	= Master.ConnectionString;
			OracleParameter		cursor				= new OracleParameter("p_data", OracleDbType.RefCursor, System.Data.ParameterDirection.Output);
			OracleDataReader	reader				= null;
			int					retry				= 0;
			try
			{
				// call tl package to delete record
				connectionString = Master.ConnectionString; //System.Configuration.ConfigurationManager.ConnectionStrings["LEAD"].ConnectionString;
				conn = new OracleConnection(connectionString); // Util.Decrypt(connectionString));
				cmd = new OracleCommand("ABC.TL_ClassList", conn);
				cmd.CommandType = System.Data.CommandType.StoredProcedure;

				// add parameters
				cmd.Parameters.Add(new OracleParameter("p_objectid", OracleDbType.Int32, 0, objectid, System.Data.ParameterDirection.Input));
				cmd.Parameters.Add(new OracleParameter("p_district", OracleDbType.Int32, 0, null, System.Data.ParameterDirection.Input));
				cmd.Parameters.Add(new OracleParameter("p_startdate", OracleDbType.Date, 0, null, System.Data.ParameterDirection.Input));
				cmd.Parameters.Add(new OracleParameter("p_enddate", OracleDbType.Date, 0, null, System.Data.ParameterDirection.Input));
				cmd.Parameters.Add(cursor);

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

					if (((Oracle.DataAccess.Types.OracleRefCursor)(cursor.Value)).IsNull)
					{
						AppCode.AppLog.Write(new Exception("Class information not returned (" + objectid + ")"), AppCode.AppLog.MessageType.ERROR, connectionString);
						msg.InnerText = "Unable to retrieve class information.  Please use the Back button and reselect the class.";
						msg.Style["color"] = "red";
					}
					else
					{
						reader = ((OracleRefCursor)cursor.Value).GetDataReader();
						if (reader.Read())
						{
							classtimeexpression.Text = reader.GetString(reader.GetOrdinal("CLASSTIMEEXPRESSION"));
							location.Text = reader.GetString(reader.GetOrdinal("LOCATION")).Replace("\n", "<br/>");
							spotsavailable.Text = reader.GetValue(reader.GetOrdinal("SPOTSAVAILABLE")).ToString(); 

							if (reader.GetString(reader.GetOrdinal("CLASSFULL")) == "Y")
							{
								title.InnerText = "Standby List Registration for Class";
								standbymessage.Visible = true;
							}
							else
							{
								title.InnerText = "Student Registration";
								standbymessage.Visible = false;
							}
						}
						reader.Close();
						reader = null;
					}

					conn.Close();
				}
				else
				{
					msg.InnerText = "Unable to retrieve class information.  Please use the Back button and reselect the class.";
					msg.Style["color"] = "red";
				}
			}

			catch (OracleException ex)
			{
				AppCode.AppLog.Write(ex, AppCode.AppLog.MessageType.ERROR, connectionString);
				msg.InnerText = "Unable to retrieve class information.  Please use the Back button and reselect the class.";
				msg.Style["color"] = "red";
			}

			catch (Exception ex)
			{
				AppCode.AppLog.Write(ex, AppCode.AppLog.MessageType.ERROR, connectionString);
				msg.InnerText = "Unable to retrieve class information.  Please use the Back button and reselect the class.";
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

		protected void submit_Click(object sender, EventArgs e)
		{
			OracleCommand		cmd;
			OracleConnection	conn				 = null;
			string				connectionString     = Master.ConnectionString; 
			string				name				 = "";
			OracleParameter		resultCode			 = new OracleParameter("p_code", OracleDbType.Int32, System.Data.ParameterDirection.Output);
			OracleParameter		results				 = new OracleParameter("p_message", OracleDbType.Varchar2, 8000, null, System.Data.ParameterDirection.Output);
			Int32?				error				 = null;
			string				website;
			Int32				retry				 = 0;

			try
			{
				// validate chaptch first before submitting
				if (!CaptchValidate())
				{
					msg.InnerText = "CAPTCHA Validation Failed.";
					msg.Style["color"] = "#620000";

					return;
				}
				name = firstName.Text + " " + lastName.Text;
				website = Request.Url.AbsoluteUri.Substring(0, Request.Url.AbsoluteUri.LastIndexOf("/"));

				// call tl package to delete record
				//connectionString = Master.ConnectionString; //System.Configuration.ConfigurationManager.ConnectionStrings["LEAD"].ConnectionString;
				conn = new OracleConnection(connectionString); // Util.Decrypt(connectionString));
				cmd = new OracleCommand("ABC.TL_StudentUpdate", conn);
				cmd.CommandType = System.Data.CommandType.StoredProcedure;

				// add parameters
				cmd.Parameters.Add(new OracleParameter("p_classobjectid", OracleDbType.Int32, 0, Convert.ToInt32(classobjectid.Value), System.Data.ParameterDirection.Input));
				cmd.Parameters.Add(new OracleParameter("p_studentobjectid", OracleDbType.Int32, 0, null, System.Data.ParameterDirection.Input));
				cmd.Parameters.Add(new OracleParameter("p_name", OracleDbType.Varchar2, name.Length, name, System.Data.ParameterDirection.Input));
				cmd.Parameters.Add(new OracleParameter("p_emailaddress", OracleDbType.Varchar2, email.Value.Length, email.Value, System.Data.ParameterDirection.Input));
				cmd.Parameters.Add(new OracleParameter("p_phonenumber", OracleDbType.Varchar2, cellPhone.Value.Length, cellPhone.Value, System.Data.ParameterDirection.Input));
				cmd.Parameters.Add(new OracleParameter("p_passfail", OracleDbType.Varchar2, 0, null, System.Data.ParameterDirection.Input));
				cmd.Parameters.Add(new OracleParameter("p_webaddress", OracleDbType.Varchar2, website.Length, website, System.Data.ParameterDirection.Input));
				cmd.Parameters.Add(new OracleParameter("a_confirmation", OracleDbType.Int32, System.Data.ParameterDirection.Input));
				cmd.Parameters.Add(new OracleParameter("p_delete", OracleDbType.Varchar2, 0, null, System.Data.ParameterDirection.Input));
				cmd.Parameters.Add(new OracleParameter("p_deleteappl", OracleDbType.Varchar2, 0, null, System.Data.ParameterDirection.Input));
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
						if (conn.State != System.Data.ConnectionState.Open)
						{
							retry++;

							// wait one second before trying again
							System.Threading.Thread.Sleep(1000);
						}
					}
				}

				if (conn.State == System.Data.ConnectionState.Open)
				{
					cmd.ExecuteNonQuery();

					conn.Close();

					// get results.
					if (!((INullable)resultCode.Value).IsNull)
					{
						error = Convert.ToInt32(((Oracle.DataAccess.Types.OracleDecimal)(resultCode.Value)).Value);
					}

					if (((INullable)results.Value).IsNull)
					{
						msg.InnerText = "Unknown error";
					}
					else
					{
						msg.InnerText = results.Value.ToString();

						Exception ex2 = new Exception(msg.InnerText);

						ex2.Data["Class"] = classobjectid.Value;
						ex2.Data["Name"] = name;
						ex2.Data["Email"] = email.Value;

						switch (error)
						{
							case 0:
								msg.Style["color"] = "#4040ff;";
								break;

							case 1:	// duplicate email address found
								AppCode.AppLog.Write(ex2, AppCode.AppLog.MessageType.TRACE, connectionString);
								msg.Style["color"] = "#620000";
								break;

							default:
								AppCode.AppLog.Write(ex2, AppCode.AppLog.MessageType.ERROR, connectionString);
								msg.Style["color"] = "#620000";
								break;
						}

					}

				}

			}

			catch (OracleException ex)
			{
				ex.Data["Class"] = classobjectid.Value;
				ex.Data["Name"] = name;
				ex.Data["Email"] = email.Value;

				AppCode.AppLog.Write(ex, AppCode.AppLog.MessageType.ERROR, connectionString);
				msg.InnerText = "Error in processing you registration.";
				msg.Style["color"] = "red";
			}

			catch (Exception ex)
			{
				ex.Data["Class"] = classobjectid.Value;
				ex.Data["Name"] = name;
				ex.Data["Email"] = email.Value;

				AppCode.AppLog.Write(ex, AppCode.AppLog.MessageType.ERROR, connectionString);
				msg.InnerText = "Error in processing you registration.";
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

		public bool CaptchValidate()
		{
			string Response = Request["g-recaptcha-response"];//Getting Response String Append to Post Method
			bool Valid = false;

			//Request to Google Server
			System.Net.HttpWebRequest req = (System.Net.HttpWebRequest) System.Net.WebRequest.Create
											("https://www.google.com/recaptcha/api/siteverify?secret=" +
											 System.Configuration.ConfigurationManager.AppSettings["SecretKey"] + 
											 "&response=" + Response);
			try
			{
				//Google recaptcha Response
				using (System.Net.WebResponse wResponse = req.GetResponse())
				{

					using (System.IO.StreamReader readStream = new System.IO.StreamReader(wResponse.GetResponseStream()))
					{
						string jsonResponse = readStream.ReadToEnd();

						System.Web.Script.Serialization.JavaScriptSerializer js = new System.Web.Script.Serialization.JavaScriptSerializer();
						CaptchaResponse data = js.Deserialize<CaptchaResponse>(jsonResponse);// Deserialize Json

						Valid = Convert.ToBoolean(data.success);
					}
				}

				return (HttpContext.Current.IsDebuggingEnabled) ? true: Valid;
			}
			catch (Exception ex)
			{
				throw ex;
			}
		}

	}
}