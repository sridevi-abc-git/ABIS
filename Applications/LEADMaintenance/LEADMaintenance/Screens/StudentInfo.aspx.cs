using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;
using System.Web.UI;
using System.Web.UI.WebControls;

using Oracle.DataAccess.Client;
using Oracle.DataAccess.Types;
using System.Data;


namespace LEADMaintenance.Screens
{
	public partial class StudentInfo : System.Web.UI.Page
	{
		bool		m_refresh = false;

		protected void Page_Load(object sender, EventArgs e)
		{
			if (IsPostBack)
			{
				DataTable dt = (DataTable) ViewState["StudentData"];

				BuildRoster(dt);
			}
		}
		protected void Page_LoadComplete(object sender, EventArgs e)
		{
			if (!IsPostBack)
			{
				studentobjectid.Value = Request.QueryString["student"];
				GetStudentInfo(Convert.ToInt32(studentobjectid.Value));
			}
		}

		void GetStudentInfo(int objectid)
		{
			OracleCommand		cmd;
			OracleConnection	conn				= null;
			OracleParameter		cursor				= new OracleParameter("p_data", OracleDbType.RefCursor, System.Data.ParameterDirection.Output);
			OracleDataReader	reader				= null;
			DataTable			tb					= new DataTable();
			bool				pending				= false;

			try
			{
				msg.InnerText = "";

				conn = new OracleConnection(Master.ConnectionString);
				cmd = new OracleCommand("ABC.TL_STUDENTINFO", conn);
				cmd.CommandType = System.Data.CommandType.StoredProcedure;

				// add parameters
				cmd.Parameters.Add(new OracleParameter("p_objectid", OracleDbType.Int32, 0, objectid, System.Data.ParameterDirection.Input));
				cmd.Parameters.Add(cursor);

				if (Screens.Site.OpenConnection(conn))
				{
					cmd.ExecuteNonQuery();

					if (((Oracle.DataAccess.Types.OracleRefCursor)(cursor.Value)).IsNull)
					{
						Utils.AppLog.Write(new Exception("Class roster information not returned (" + objectid + ")"), Utils.AppLog.MessageType.ERROR);
						msg.InnerText = "Unable to retrieve class roster information.  Please use the Back button and reselect the class.";
						msg.Style["color"] = "red";
					}
					else
					{
						reader = ((OracleRefCursor)cursor.Value).GetDataReader();
						tb.Load(reader);
						tb.AcceptChanges();

						if (!IsPostBack || m_refresh) BuildRoster(tb);
						FillRoster(tb);

						ViewState["StudentData"] = tb;

						reader.Close();
						reader = null;

						// check if any items are pending
						foreach (DataRow dr in tb.Rows)
						{
							pending |= (dr["STATUS"].ToString() != "4" && dr["STATUS"] != System.DBNull.Value);
						}

						refresh.Enabled = pending;
						if (autorefresh.Checked && pending)
						{
							Page.ClientScript.RegisterStartupScript(this.GetType(), "autorefresh",
									"setTimeout(function(){ document.getElementById('" + refresh.ClientID + "').click();}, 10000);",
									true);
						}
					}

					conn.Close();
				}
				else
				{
					msg.InnerText = "Unable to retrieve student information.  Please use the Back button and reselect the class.";
					msg.Style["color"] = "red";
				}
			}

			catch (OracleException ex)
			{
				Utils.AppLog.Write(ex, Utils.AppLog.MessageType.ERROR);
				msg.InnerText = "Unable to retrieve student information.  Please use the Back button and reselect the class.";
				msg.Style["color"] = "red";
			}

			catch (Exception ex)
			{
				Utils.AppLog.Write(ex, Utils.AppLog.MessageType.ERROR);
				msg.InnerText = "Unable to retrieve student information.  Please use the Back button and reselect the class.";
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

		protected void BuildRoster(DataTable dt)
		{
			TableRow			row;
			TextBox				textBox;
			Label				lbl;
			CheckBox			checkBox;
			Button				btn;
			TableCell			cell;
			RadioButtonList		radioBtnList;

			string				studentName;
			string				confirmationNumber;
			string				emailAddress;
			string				phoneNumber;
			string				processDate;
			string				status = "";
			object				processStatus;
			string				isCompleteRegistration;
			string				passFail;
			string				value;
			int					rowNumber = 0;

			studentinfo.Controls.Clear();

			if (dt.Rows.Count == 0)
			{
				rosterTable.Visible = false;
				buttons.Visible = false;
				msg.InnerText = "No students found for selected class.";
				return;
			}

			foreach (DataRow dr in dt.Rows)
			{
				studentName				= dr["STUDENTNAME"].ToString();
				confirmationNumber		= dr["CONFIRMATIONNUMBER"].ToString();
				emailAddress			= dr["EMAILADDRESS"].ToString();
				phoneNumber				= dr["PHONENUMBER"].ToString();
				processDate				= dr["PROCESSDATE"].ToString();
				isCompleteRegistration	= dr["ISCOMPLETEREGISTRATION"].ToString().ToUpper();
				processStatus			= dr["PROCESSSTATUS"];
				passFail				= dr["PASSFAIL"].ToString().ToUpper();
				value					= dr["STATUS"].ToString();
				status					= "";

				if (isCompleteRegistration == "Y" &&
					passFail == "PASS" &&
					value.Length > 0)
				{
					status = value == "1" ? "Pending" :
							 value == "3" ? "Processing" :
							 value != "2" && processStatus.ToString() == "0" ? "Certificate Issued" : "Failed";
				}

				// create row
				row = new TableRow();
				row.ID = "ROW_" + rowNumber.ToString();
				row.ClientIDMode = System.Web.UI.ClientIDMode.Static;
				row.Attributes.Add("STUDENTOBJECTID", dr["OBJECTID"].ToString());

				// ------------------------------------------------
				cell = new TableCell();
				cell.Text = (isCompleteRegistration == "Y" ? "" : "N");
				row.Cells.Add(cell);

				// ------------------------------------------------
				cell = new TableCell();
				cell.Text = (dr["ISSTANDBY"].ToString() == "Y" ? "Y" : "");
				row.Cells.Add(cell);

				// ------------------------------------------------
				cell = new TableCell();
				cell.ID = "CONFIRMATIONNUMBER_" + rowNumber.ToString();
				cell.Text = confirmationNumber;
				row.Cells.Add(cell);

				// ------------------------------------------------
				cell = new TableCell();
				textBox = new TextBox();
				textBox.ClientIDMode = System.Web.UI.ClientIDMode.Static;
				textBox.ID = "STUDENTNAME_" + rowNumber.ToString();
				textBox.Attributes.Add("default", studentName);
				textBox.Width = 150;
				Page.ClientScript.RegisterStartupScript(this.GetType(), textBox.ClientID,
					"jQuery('#" + textBox.ClientID + "').validation('add', {validator: '^[ -~]+$', required: true, message: " +
																		  "{REQUIRED: 'Please enter students name.'}});",
						true);
				cell.Controls.Add(textBox);

				textBox = new TextBox();
				textBox.ClientIDMode = System.Web.UI.ClientIDMode.Static;
				textBox.ID = "PHONENUMBER_" + rowNumber.ToString();
				textBox.Attributes.Add("default", phoneNumber);
				textBox.Width = 120;
				textBox.Attributes.Add("placeholder", "Phone Number");
				textBox.Style["margin-top"] = "5px";
				Page.ClientScript.RegisterStartupScript(this.GetType(), textBox.ClientID,
					"jQuery('#" + textBox.ClientID + "').validation('add', {validator: VAL_PHONE, required: false, message: " +
																		  "{INVALID: 'Invalid phone number entered.'}});",
						true);
				cell.Controls.Add(textBox);

				if (isCompleteRegistration != "Y")
				{
					btn = new Button();
					btn.Text = "Complete Registration";
					btn.Style["margin"] = "5px 0 2px 0";
					btn.CommandArgument = dr["OBJECTID"].ToString();
					btn.Click += CompleteRegistration_Click;
					btn.OnClientClick = " $('#modal').modal(); document.body.style.cursor='wait';";
					cell.Controls.Add(btn);
				}

				lbl = new Label();
				lbl.ID = "STATUS_" + rowNumber.ToString();
				lbl.Width = 150;
				lbl.Style["padding-top"] = "5px";
				cell.Controls.Add(lbl);
				row.Cells.Add(cell);

				// ------------------------------------------------
				cell = new TableCell();
				textBox = new TextBox();
				textBox.ClientIDMode = System.Web.UI.ClientIDMode.Static;
				textBox.ID = "EMAILADDRESS_" + rowNumber.ToString();
				textBox.Attributes.Add("default", emailAddress);
				textBox.Width = 200;
				cell.Controls.Add(textBox);
				Page.ClientScript.RegisterStartupScript(this.GetType(), textBox.ClientID,
					"jQuery('#" + textBox.ClientID + "').validation('add', {validator: VAL_EMAIL, required: true, message: " +
																		  "{REQUIRED: 'Please enter valid email address.'," +
																		   "INVALID: 'Invalid email address entered.'}});",
						true);

				lbl = new Label();
				lbl.Width = 200;
				lbl.Text = " ";
				lbl.Style["padding-top"] = "5px";
				cell.Controls.Add(lbl);
				row.Cells.Add(cell);

				lbl = new Label();
				lbl.ID = "PROCESSDATE_" + rowNumber.ToString();
				lbl.Width = 200;
				lbl.Style["padding-top"] = "15px";
				cell.Controls.Add(lbl);
				row.Cells.Add(cell);

				// ------------------------------------------------
				cell = new TableCell();
				radioBtnList = new RadioButtonList();
				radioBtnList.ClientIDMode = System.Web.UI.ClientIDMode.Static;
				radioBtnList.ID = "BTNLIST_" + rowNumber.ToString();
				radioBtnList.Attributes.Add("default", passFail);

				radioBtnList.Items.Add(new ListItem("Pass", "Pass"));
				radioBtnList.Items.Add(new ListItem("Fail", "Fail"));
				radioBtnList.Items.Add(new ListItem("NoShow", "NoShow"));

				cell.Controls.Add(radioBtnList);
				row.Cells.Add(cell);

				// ------------------------------------------------
				cell = new TableCell();
				checkBox = new CheckBox();
				checkBox.ClientIDMode = System.Web.UI.ClientIDMode.Static;
				checkBox.ID = "RESEND_" + rowNumber.ToString();
				cell.Controls.Add(checkBox);
				row.Cells.Add(cell);

				if (isCompleteRegistration == "Y")
				{
					radioBtnList.Attributes.Add("onclick",
												"PassFailChange('" + radioBtnList.ClientID + "', '" + checkBox.ClientID + "')");
				}

				// add to table body
				studentinfo.Controls.Add(row);

				rowNumber++;
			}

		}

		protected void FillRoster(DataTable dt)
		{
			TableRow			row;
			TextBox				textBox;
			Label				lbl;
			CheckBox			checkBox;
			RadioButtonList		radioBtnList;

			string				studentName;
			string				emailAddress;
			string				phoneNumber;
			string				processDate;
			string				status;
			object				processStatus;
			string				isCompleteRegistration;
			string				passFail;
			string				value;
			object				emailid;
			int					rowNumber = 0;

			foreach (DataRow dr in dt.Rows)
			{
				studentName				= dr["STUDENTNAME"].ToString();
				emailAddress			= dr["EMAILADDRESS"].ToString();
				phoneNumber				= dr["PHONENUMBER"].ToString();
				processDate				= dr["PROCESSDATE"].ToString();
				isCompleteRegistration	= dr["ISCOMPLETEREGISTRATION"].ToString().ToUpper();
				processStatus			= dr["PROCESSSTATUS"];
				passFail				= dr["PASSFAIL"].ToString().ToUpper();
				value					= dr["STATUS"].ToString();
				emailid					= dr["EMAILID"];
				status					= "";

				// only one row is expected for this fill
				classtimeexpression.Text = dr["CLASSTIMEEXPRESSION"].ToString();
				district.Text = dr["DISTRICT"].ToString();
				location.Text = dr["LOCATION"].ToString().Replace("\n", "<br/>");

				if (isCompleteRegistration == "Y" &&
					passFail == "PASS" &&
					value.Length > 0)
				{
					status = value == "1" ? "Pending" :
							 value == "3" ? "Processing" :
							 value != "2" && processStatus.ToString() == "0" ? "Certificate Issued" : "Failed";
					if (emailid == null && value == "4") status = "Certificate Not Sent";
				}
				else
				{
					if (processDate.Length > 0)
					{
						status = "Certificate Issued";
					}
				}

				row = (TableRow)studentinfo.FindControl("ROW_" + rowNumber.ToString());

				// ------------------------------------------------
				textBox = (TextBox)row.FindControl("STUDENTNAME_" + rowNumber.ToString());
				textBox.Text = studentName;
				textBox.Enabled = (isCompleteRegistration == "Y");

				// ------------------------------------------------
				textBox = (TextBox)row.FindControl("EMAILADDRESS_" + rowNumber.ToString());
				textBox.Text = emailAddress;
				textBox.Enabled = (isCompleteRegistration == "Y");

				// ------------------------------------------------
				textBox = (TextBox)row.FindControl("PHONENUMBER_" + rowNumber.ToString());
				textBox.Text = phoneNumber;
				textBox.Enabled = (isCompleteRegistration == "Y");

				// ------------------------------------------------
				radioBtnList = (RadioButtonList)row.FindControl("BTNLIST_" + rowNumber.ToString());
				foreach (ListItem item in radioBtnList.Items)
				{
					item.Selected = (item.Value.ToUpper() == passFail);
				}
				radioBtnList.Visible = (isCompleteRegistration == "Y");

				// ------------------------------------------------
				lbl = (Label)row.FindControl("PROCESSDATE_" + rowNumber.ToString());
				lbl.Text = passFail == "PASS" ? processDate : "";

				// ------------------------------------------------
				lbl = (Label)row.FindControl("STATUS_" + rowNumber.ToString());
				lbl.Text = status;

				// ------------------------------------------------
				checkBox = (CheckBox)row.FindControl("RESEND_" + rowNumber.ToString()); ;
				checkBox.Enabled = (passFail != "NOSHOW" && status != "Pending" && status != "Processing");
				checkBox.Visible = (isCompleteRegistration == "Y");
				checkBox.Checked = false;
				rowNumber++;
			}

		}

		protected void submit_Click(object sender, EventArgs e)
		{
			ControlCollection	rows = studentinfo.Controls;
			TextBox				studentName;
			TextBox				emailAddress;
			TextBox				phoneNumber;
			CheckBox			checkBox;
			RadioButtonList		radioBtnList;
			int					studentObjectid;
			int					rowNumber			= 0;

			OracleCommand		upd;
			OracleCommand		issue;
			OracleConnection	conn				 = null;
			OracleParameter     studentObjectidParm  = new OracleParameter("p_studentobjectid", OracleDbType.Int32, System.Data.ParameterDirection.Input);
			OracleParameter     studentNameParm		 = new OracleParameter("p_name", OracleDbType.Varchar2, System.Data.ParameterDirection.Input);
			OracleParameter     emailAddressParm	 = new OracleParameter("p_emailaddress", OracleDbType.Varchar2, System.Data.ParameterDirection.Input);
			OracleParameter		phoneParm			 = new OracleParameter("p_phonenumber", OracleDbType.Varchar2, System.Data.ParameterDirection.Input);
			OracleParameter     passFailParm		 = new OracleParameter("p_passfail", OracleDbType.Varchar2, System.Data.ParameterDirection.Input);
			OracleParameter		resultCode			 = new OracleParameter("p_code", OracleDbType.Int32, System.Data.ParameterDirection.Output);
			OracleParameter		results				 = new OracleParameter("p_message", OracleDbType.Varchar2, 8000, null, System.Data.ParameterDirection.Output);

			OracleParameter     studentObjectidParm2 = new OracleParameter("p_studentobjectid", OracleDbType.Int32, System.Data.ParameterDirection.Input);
			OracleParameter     passFailParm2		 = new OracleParameter("p_passfail", OracleDbType.Varchar2, System.Data.ParameterDirection.Input);
			OracleParameter		resultCode2			 = new OracleParameter("p_code", OracleDbType.Int32, System.Data.ParameterDirection.Output);
			OracleParameter		results2			 = new OracleParameter("p_message", OracleDbType.Varchar2, 8000, null, System.Data.ParameterDirection.Output);

			try
			{
				// call tl package to update record
				conn = new OracleConnection(Master.ConnectionString); // Util.Decrypt(connectionString));
				upd = new OracleCommand("ABC.TL_StudentUpdate", conn);
				upd.CommandType = System.Data.CommandType.StoredProcedure;

				// add parameters
				upd.Parameters.Add(new OracleParameter("p_classobjectid", OracleDbType.Int32, 0, null, System.Data.ParameterDirection.Input));
				upd.Parameters.Add(studentObjectidParm);
				upd.Parameters.Add(studentNameParm);
				upd.Parameters.Add(emailAddressParm);
				upd.Parameters.Add(phoneParm);
				upd.Parameters.Add(passFailParm);
				upd.Parameters.Add(new OracleParameter("p_webaddress", OracleDbType.Varchar2, 0, null, System.Data.ParameterDirection.Input));
				upd.Parameters.Add(new OracleParameter("a_confirmation", OracleDbType.Int32, 0, null, System.Data.ParameterDirection.Input));
				upd.Parameters.Add(new OracleParameter("p_delete", OracleDbType.Varchar2, 0, null, System.Data.ParameterDirection.Input));
				upd.Parameters.Add(new OracleParameter("p_deleteappl", OracleDbType.Varchar2, 0, null, System.Data.ParameterDirection.Input));
				upd.Parameters.Add(new OracleParameter("p_mgrname", OracleDbType.Varchar2, 0, null, System.Data.ParameterDirection.Input));
				upd.Parameters.Add(new OracleParameter("p_mgremailaddress", OracleDbType.Varchar2, 0, null, System.Data.ParameterDirection.Input));
				upd.Parameters.Add(new OracleParameter("p_mgrphonenumber", OracleDbType.Varchar2, 0, null, System.Data.ParameterDirection.Input));
				upd.Parameters.Add(new OracleParameter("p_student", OracleDbType.RefCursor, System.Data.ParameterDirection.Output));
				upd.Parameters.Add(results);
				upd.Parameters.Add(resultCode);

				issue = new OracleCommand("ABC.TL_IssueCertificate", conn);
				issue.CommandType = System.Data.CommandType.StoredProcedure;

				issue.Parameters.Add(studentObjectidParm2);
				issue.Parameters.Add(passFailParm2);
				issue.Parameters.Add(results2);
				issue.Parameters.Add(resultCode2);

				// check for any rows which were changed
				foreach (Control row in rows)
				{
					// check for change in student information
					studentName = (TextBox)row.FindControl("STUDENTNAME_" + rowNumber.ToString());
					emailAddress = (TextBox)row.FindControl("EMAILADDRESS_" + rowNumber.ToString());
					phoneNumber = (TextBox)row.FindControl("PHONENUMBER_" + rowNumber.ToString());
					radioBtnList = (RadioButtonList)row.FindControl("BTNLIST_" + rowNumber.ToString());
					checkBox = (CheckBox)row.FindControl("resend_" + rowNumber.ToString());
					studentObjectid = Convert.ToInt32(((TableRow)row).Attributes["STUDENTOBJECTID"]);

					if ((studentName.Text != studentName.Attributes["default"]) ||
						(emailAddress.Text != emailAddress.Attributes["default"]) ||
						(radioBtnList.SelectedValue.ToUpper() != radioBtnList.Attributes["default"]) ||
						(phoneNumber.Text != phoneNumber.Attributes["default"]))
					{
						// update student record
						studentObjectidParm.Value = studentObjectid;

						studentNameParm.Value = studentName.Text;
						studentNameParm.Size = studentName.Text.Length;

						emailAddressParm.Value = emailAddress.Text;
						emailAddressParm.Size = emailAddress.Text.Length;

						phoneParm.Value = phoneNumber.Text;
						phoneParm.Size = phoneNumber.Text.Length;

						passFailParm.Value = radioBtnList.SelectedValue;
						passFailParm.Size = radioBtnList.SelectedValue.Length;


						if (Screens.Site.OpenConnection(conn))
						{
							upd.ExecuteNonQuery();

							// check for error
						}
					}

					// check if certificate should be sent
					if (checkBox.Checked)
					{
						// issue certificate
						studentObjectidParm2.Value = studentObjectid;
						passFailParm2.Value = radioBtnList.SelectedValue;
						if (Screens.Site.OpenConnection(conn))
						{
							issue.ExecuteNonQuery();

							// check for error
						}

					}

					rowNumber++;
				}

				if (conn.State == ConnectionState.Open) conn.Close();

				GetStudentInfo(Convert.ToInt32(studentobjectid.Value));

			}

			catch (Exception ex)
			{
				Utils.AppLog.Write(ex, Utils.AppLog.MessageType.ERROR);
				msg.InnerText = "Unable to update student information or send email.";
				msg.Style["color"] = "red";
			}
		}

		protected void refresh_Click(object sender, EventArgs e)
		{
			m_refresh = true;
			GetStudentInfo(Convert.ToInt32(studentobjectid.Value));
		}

		protected void CompleteRegistration_Click(object sender, EventArgs e)
		{
			Button				btn = (Button)sender;
			string				objectid = btn.CommandArgument;
			OracleCommand		cmd;
			OracleConnection	conn				= null;
			OracleParameter		resultCode			 = new OracleParameter("p_code", OracleDbType.Int32, System.Data.ParameterDirection.Output);
			OracleParameter		results				 = new OracleParameter("p_message", OracleDbType.Varchar2, 8000, null, System.Data.ParameterDirection.Output);
			Int32?				error				 = null;

			try
			{
				// call tl package to delete record
				conn = new OracleConnection(Master.ConnectionString); // Util.Decrypt(connectionString));
				cmd = new OracleCommand("ABC.TL_StudentUpdate", conn);
				cmd.CommandType = System.Data.CommandType.StoredProcedure;

				// add parameters
				cmd.Parameters.Add(new OracleParameter("p_classobjectid", OracleDbType.Int32, 0, null, System.Data.ParameterDirection.Input));
				cmd.Parameters.Add(new OracleParameter("p_studentobjectid", OracleDbType.Int32, 0, Convert.ToInt32(objectid), System.Data.ParameterDirection.Input));
				cmd.Parameters.Add(new OracleParameter("p_name", OracleDbType.Varchar2, 0, null, System.Data.ParameterDirection.Input));
				cmd.Parameters.Add(new OracleParameter("p_emailaddress", OracleDbType.Varchar2, 0, null, System.Data.ParameterDirection.Input));
				cmd.Parameters.Add(new OracleParameter("p_phonenumber", OracleDbType.Varchar2, 0, null, System.Data.ParameterDirection.Input));
				cmd.Parameters.Add(new OracleParameter("p_passfail", OracleDbType.Varchar2, 0, null, System.Data.ParameterDirection.Input));
				cmd.Parameters.Add(new OracleParameter("p_webaddress", OracleDbType.Varchar2, 0, null, System.Data.ParameterDirection.Input));
				cmd.Parameters.Add(new OracleParameter("a_confirmation", OracleDbType.Int32, System.Data.ParameterDirection.Input));
				cmd.Parameters.Add(new OracleParameter("p_delete", OracleDbType.Varchar2, 0, null, System.Data.ParameterDirection.Input));
				cmd.Parameters.Add(new OracleParameter("p_deleteappl", OracleDbType.Varchar2, 0, null, System.Data.ParameterDirection.Input));
				cmd.Parameters.Add(new OracleParameter("p_mgrname", OracleDbType.Varchar2, 0, null, System.Data.ParameterDirection.Input));
				cmd.Parameters.Add(new OracleParameter("p_mgremailaddress", OracleDbType.Varchar2, 0, null, System.Data.ParameterDirection.Input));
				cmd.Parameters.Add(new OracleParameter("p_mgrphonenumber", OracleDbType.Varchar2, 0, null, System.Data.ParameterDirection.Input));
				cmd.Parameters.Add(new OracleParameter("p_student", OracleDbType.RefCursor, System.Data.ParameterDirection.Output));
				cmd.Parameters.Add(results);
				cmd.Parameters.Add(resultCode);

				if (Screens.Site.OpenConnection(conn))
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
						if (error == null)
						{
							msg.Style["color"] = "#4040ff;";
						}
						else
						{
							msg.Style["color"] = "#620000";
						}

					}
				}

				if (error == null)
				{
					refresh_Click(sender, e);
				}
				else
				{
				}
			}

			catch (OracleException ex)
			{
				Utils.AppLog.Write(ex, Utils.AppLog.MessageType.ERROR);
				msg.InnerText = "Error in processing registration.";
				msg.Style["color"] = "red";
			}

			catch (Exception ex)
			{
				Utils.AppLog.Write(ex, Utils.AppLog.MessageType.ERROR);
				msg.InnerText = "Error in processing registration.";
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