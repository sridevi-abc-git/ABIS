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
	public partial class ClassRoster : System.Web.UI.Page
	{
		bool		m_error = false;
		bool		m_refresh = false;

		protected void Page_Load(object sender, EventArgs e)
		{
			if (IsPostBack)
			{
				BuildRoster((DataTable)ViewState["ClassRoster"]);
			}
			else
			{
				addStudentPanel.Visible = false;
			}

			msg.InnerText = "";
		}

		protected void Page_LoadComplete(object sender, EventArgs e)
		{
			if (!IsPostBack)
			{
				classobjectid.Value = Request.QueryString["class"]; 
				GetClassInfo(Convert.ToInt32(classobjectid.Value));
				if (!m_error) GetClassRoster(Convert.ToInt32(classobjectid.Value));
			}
		}


		void GetClassInfo(int objectid)
		{
			OracleCommand		cmd;
			OracleConnection	conn				= null;
			OracleParameter		cursor				= new OracleParameter("p_data", OracleDbType.RefCursor, System.Data.ParameterDirection.Output);
			OracleDataReader	reader				= null;

			try
			{
				msg.InnerText = "";

				// call tl package to delete record
				conn = new OracleConnection(Master.ConnectionString);
				cmd = new OracleCommand("ABC.TL_ClassList", conn);
				cmd.CommandType = System.Data.CommandType.StoredProcedure;

				// add parameters
				cmd.Parameters.Add(new OracleParameter("p_objectid", OracleDbType.Int32, 0, objectid, System.Data.ParameterDirection.Input));
				cmd.Parameters.Add(new OracleParameter("p_district", OracleDbType.Int32, 0, null, System.Data.ParameterDirection.Input));
				cmd.Parameters.Add(new OracleParameter("p_startdate", OracleDbType.Date, 0, null, System.Data.ParameterDirection.Input));
				cmd.Parameters.Add(new OracleParameter("p_enddate", OracleDbType.Date, 0, null, System.Data.ParameterDirection.Input));
				cmd.Parameters.Add(cursor);

				if (Screens.Site.OpenConnection(conn))
				{
					cmd.ExecuteNonQuery();

					if (((Oracle.DataAccess.Types.OracleRefCursor)(cursor.Value)).IsNull)
					{
						Utils.AppLog.Write(new Exception("Class information not returned (" + objectid + ")"), Utils.AppLog.MessageType.ERROR);
						msg.InnerText = "Unable to retrieve class information";
						msg.Style["color"] = "red";
					}
					else
					{
						reader = ((OracleRefCursor)cursor.Value).GetDataReader();
						if (reader.Read())
						{
							classtimeexpression.Text = reader.GetString(reader.GetOrdinal("CLASSTIMEEXPRESSION"));
							district.Text = reader.GetString(reader.GetOrdinal("DISTRICT"));
							location.Text = reader.GetString(reader.GetOrdinal("LOCATION")).Replace("\n", "<br/>");
							studentsregistered.Text = reader.GetDecimal(reader.GetOrdinal("STUDENTSREGISTERED")).ToString();
							if (!reader.IsDBNull(reader.GetOrdinal("STUDENTSATTENDED"))) 
							{ 
								studentsattended.Text = reader.GetDecimal(reader.GetOrdinal("STUDENTSATTENDED")).ToString();
							}
							classsize.Text = reader.GetDecimal(reader.GetOrdinal("CLASSSIZE")).ToString();
						}
						reader.Close();
						reader = null;
					}

					conn.Close();
				}
				else
				{
					msg.InnerText = "Unable to retrieve class information.";
					msg.Style["color"] = "red";
				}
			}

			catch (OracleException ex)
			{
				Utils.AppLog.Write(ex, Utils.AppLog.MessageType.ERROR);
				msg.InnerText = "Unable to retrieve class information.";
				msg.Style["color"] = "red";
			}

			catch (Exception ex)
			{
				Utils.AppLog.Write(ex, Utils.AppLog.MessageType.ERROR);
				msg.InnerText = "Unable to retrieve class information.";
				msg.Style["color"] = "red";
			}

			finally
			{
				if (conn != null)
				{
					if (conn.State == System.Data.ConnectionState.Open) conn.Close();
				}

				m_error = (msg.InnerText.Length > 0);
				if (m_error)
				{
					rosterTable.Visible = false;
					buttons.Visible = false;
				}
			}

		}

		void GetClassRoster(int objectid)
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

				// call tl package to delete record
				conn = new OracleConnection(Master.ConnectionString);
				cmd = new OracleCommand("ABC.TL_STUDENTROSTER", conn);
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

						ViewState["ClassRoster"] = tb;

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
					msg.InnerText = "Unable to retrieve class roster information.  Please use the Back button and reselect the class.";
					msg.Style["color"] = "red";
				}
			}

			catch (OracleException ex)
			{
				Utils.AppLog.Write(ex, Utils.AppLog.MessageType.ERROR);
				msg.InnerText = "Unable to retrieve class roster information.  Please use the Back button and reselect the class.";
				msg.Style["color"] = "red";
			}

			catch (Exception ex)
			{
				Utils.AppLog.Write(ex, Utils.AppLog.MessageType.ERROR);
				msg.InnerText = "Unable to retrieve class roster information.  Please use the Back button and reselect the class.";
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
			ListItem			lstItem;

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

			rosterinfo.Controls.Clear();

			if (dt.Rows.Count == 0)
			{
				rosterTable.Visible = false;
				buttons.Visible = false;
				msg.InnerText = "No students found for selected class.";
				msg.Style["color"] = "red";
				return;
			}

			rosterTable.Visible = true;
			buttons.Visible = true;

			foreach (DataRow dr in dt.Rows)
			{
				studentName = dr["STUDENTNAME"].ToString();
				confirmationNumber = dr["CONFIRMATIONNUMBER"].ToString();
				emailAddress = dr["EMAILADDRESS"].ToString();
				phoneNumber = dr["PHONENUMBER"].ToString();
				processDate = dr["PROCESSDATE"].ToString();
				isCompleteRegistration = dr["ISCOMPLETEREGISTRATION"].ToString().ToUpper();
				processStatus = dr["PROCESSSTATUS"];
				passFail = dr["PASSFAIL"].ToString().ToUpper();
				value = dr["STATUS"].ToString();
				status = "";

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
				cell.Text = (isCompleteRegistration == "Y" ? "": "N");
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
				textBox.ID = "STUDENTNAME_" + rowNumber.ToString();
				textBox.Attributes.Add("default", studentName);
				textBox.Width = 150;
				Page.ClientScript.RegisterStartupScript(this.GetType(), textBox.ClientID,
					"jQuery('#" + textBox.ClientID + "').validation('add', {validator: '^[ -~]+$', required: true, message: " +
																		  "{REQUIRED: 'Please enter students name.'}});",
						true);
				cell.Controls.Add(textBox);

				textBox = new TextBox();
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
				Page.ClientScript.RegisterStartupScript(this.GetType(), "email" + rowNumber.ToString(),
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

				lstItem = new ListItem("Pass", "Pass");
				radioBtnList.Items.Add(lstItem);

				lstItem = new ListItem("Fail", "Fail");
				radioBtnList.Items.Add(lstItem);

				lstItem = new ListItem("NoShow", "NoShow");
				radioBtnList.Items.Add(lstItem);
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

				// ------------------------------------------------
				cell = new TableCell();
				checkBox = new CheckBox();
				checkBox.ClientIDMode = System.Web.UI.ClientIDMode.Static;
				checkBox.ID = "DELETE_" + rowNumber.ToString();
				cell.Controls.Add(checkBox);
				row.Cells.Add(cell);

				// add to table body
				rosterinfo.Controls.Add(row);

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
				status = "";

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

				row = (TableRow)rosterinfo.FindControl("ROW_" + rowNumber.ToString());

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
				lbl.Text = processDate;

				// ------------------------------------------------
				lbl = (Label)row.FindControl("STATUS_" + rowNumber.ToString());
				lbl.Text = status;

				// ------------------------------------------------
				checkBox = (CheckBox)row.FindControl("RESEND_" + rowNumber.ToString()); ;
				checkBox.Enabled = (passFail != "NOSHOW" && status != "Pending" && status != "Processing");
				checkBox.Visible = (isCompleteRegistration == "Y");
				checkBox.Checked = false;

				// ------------------------------------------------
				checkBox = (CheckBox)row.FindControl("DELETE_" + rowNumber.ToString()); ;
				checkBox.Checked = false;
				checkBox.Visible = (processDate.Length == 0);
				rowNumber++;
			}

		}

		protected void submit_Click(object sender, EventArgs e)
		{
			ControlCollection	rows = rosterinfo.Controls;
			TextBox				studentName;
			TextBox				emailAddress;
			TextBox				phoneNumber;
			CheckBox			checkBox;
			CheckBox			delete;
			RadioButtonList		radioBtnList;
			int					studentObjectid;
			int					rowNumber			= 0;
			string				errMsg				= null;
			bool				noUpdate			= true;

			OracleCommand		upd;
			OracleCommand		issue;
			OracleConnection	conn				 = null;
			OracleParameter     studentObjectidParm  = new OracleParameter("p_studentobjectid", OracleDbType.Int32, System.Data.ParameterDirection.Input);
			OracleParameter     studentNameParm		 = new OracleParameter("p_name", OracleDbType.Varchar2, System.Data.ParameterDirection.Input);
			OracleParameter     emailAddressParm	 = new OracleParameter("p_emailaddress", OracleDbType.Varchar2, System.Data.ParameterDirection.Input);
			OracleParameter		phoneParm			 = new OracleParameter("p_phonenumber", OracleDbType.Varchar2, System.Data.ParameterDirection.Input);
			OracleParameter     passFailParm		 = new OracleParameter("p_passfail", OracleDbType.Varchar2, System.Data.ParameterDirection.Input);
			OracleParameter     deleteParm			 = new OracleParameter("p_delete", OracleDbType.Varchar2, System.Data.ParameterDirection.Input);
			OracleParameter     deleteApplParm		 = new OracleParameter("p_deleteappl", OracleDbType.Varchar2, 0, null, System.Data.ParameterDirection.Input);
			OracleParameter     mgrNameParm			 = new OracleParameter("p_mgrname", OracleDbType.Varchar2, 0, null, System.Data.ParameterDirection.Input);
			OracleParameter     mgrEmailAddressParm	 = new OracleParameter("p_mgremailaddress", OracleDbType.Varchar2, 0, null, System.Data.ParameterDirection.Input);
			OracleParameter		mgrPhoneNumberParm	 = new OracleParameter("p_mgrphonenumber", OracleDbType.Varchar2, 0, null, System.Data.ParameterDirection.Input);
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
				upd.Parameters.Add(new OracleParameter("p_classobjectid", OracleDbType.Int32, 0, Convert.ToInt32(classobjectid.Value), System.Data.ParameterDirection.Input));
				upd.Parameters.Add(studentObjectidParm);
				upd.Parameters.Add(studentNameParm);
				upd.Parameters.Add(emailAddressParm);
				upd.Parameters.Add(phoneParm);
				upd.Parameters.Add(passFailParm);
				upd.Parameters.Add(new OracleParameter("p_webaddress", OracleDbType.Varchar2, 0, null, System.Data.ParameterDirection.Input));
				upd.Parameters.Add(new OracleParameter("a_confirmation", OracleDbType.Int32, 0, null, System.Data.ParameterDirection.Input));
				upd.Parameters.Add(deleteParm);
				upd.Parameters.Add(deleteApplParm);
				upd.Parameters.Add(mgrNameParm);
				upd.Parameters.Add(mgrEmailAddressParm);
				upd.Parameters.Add(mgrPhoneNumberParm);
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
					delete = (CheckBox)row.FindControl("DELETE_" + rowNumber.ToString());
					studentObjectid = Convert.ToInt32(((TableRow)row).Attributes["STUDENTOBJECTID"]);

					if ((studentName.Text != studentName.Attributes["default"]) ||
						(emailAddress.Text != emailAddress.Attributes["default"]) ||
						(radioBtnList.SelectedValue.ToUpper() != radioBtnList.Attributes["default"]) ||
						(phoneNumber.Text != phoneNumber.Attributes["default"]) ||
						(delete.Checked))
					{
						noUpdate = false;

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

						deleteParm.Size = 1;
						if (delete.Checked)
						{
							deleteParm.Value = "Y";
							deleteApplParm.Value = "Maintenance Roster";
							deleteApplParm.Size = deleteApplParm.Value.ToString().Length;
						}
						else
						{
							deleteParm.Value = "N";
						}

						if (Screens.Site.OpenConnection(conn))
						{
							upd.ExecuteNonQuery();

							// check for error
							if (!((INullable)resultCode.Value).IsNull)
							{
								if (((Oracle.DataAccess.Types.OracleDecimal)(resultCode.Value)).Value == 1)
								{
									errMsg += "Student cannot be deleted after certificate has been issued.";
								}
							}

							if (!((INullable)results.Value).IsNull)
							{
								errMsg += studentName.Text + "  err: " + results.Value.ToString();
								break;
							}
						}
					}

					// check if certificate should be sent
					if (checkBox.Checked)
					{
						noUpdate = false;

						// issue certificate
						studentObjectidParm2.Value = studentObjectid;
						passFailParm2.Value = radioBtnList.SelectedValue;
						if (Screens.Site.OpenConnection(conn))
						{
							issue.ExecuteNonQuery();

							// check for error
							if (!((INullable)results2.Value).IsNull)
							{
								errMsg += studentName.Text + "  err: " + results.Value.ToString();
								break;
							}
						}

					}

					rowNumber++;
				}


				if (conn.State == ConnectionState.Open) conn.Close();

				refresh_Click(sender, e);

				if (errMsg != null)
				{
					Utils.AppLog.Write(new Exception(errMsg), Utils.AppLog.MessageType.ERROR);
					msg.InnerText += errMsg;
					msg.Style["color"] = "red";
				}
				else
				{
					if (!noUpdate)
					{
						msg.InnerText = "Request Accepted.";
						msg.Style["color"] = "#4040ff";
					}
				}

			}

			catch (Exception ex)
			{
				Utils.AppLog.Write(ex, Utils.AppLog.MessageType.ERROR);
				msg.InnerText = "Unable to update students information and or send certificates.";
				msg.Style["color"] = "red";

			}
		}

		protected void refresh_Click(object sender, EventArgs e)
		{
			m_refresh = true;
			GetClassInfo(Convert.ToInt32(classobjectid.Value));
			if (!m_error) GetClassRoster(Convert.ToInt32(classobjectid.Value));
			addStudentPanel.Visible = false;
			roster.Visible = true;


		}

		protected void addSubmit_Click(object sender, EventArgs e)
		{
			OracleCommand		cmd;
			OracleConnection	conn				= null;
			string				name;
			OracleParameter		resultCode			 = new OracleParameter("p_code", OracleDbType.Int32, System.Data.ParameterDirection.Output);
			OracleParameter		results				 = new OracleParameter("p_message", OracleDbType.Varchar2, 8000, null, System.Data.ParameterDirection.Output);
			Int32?				error				 = null;

			try
			{
				name = firstName.Text + " " + lastName.Text;

				// call tl package to delete record
				conn = new OracleConnection(Master.ConnectionString); // Util.Decrypt(connectionString));
				cmd = new OracleCommand("ABC.TL_StudentUpdate", conn);
				cmd.CommandType = System.Data.CommandType.StoredProcedure;

				// add parameters
				cmd.Parameters.Add(new OracleParameter("p_classobjectid", OracleDbType.Int32, 0, Convert.ToInt32(classobjectid.Value), System.Data.ParameterDirection.Input));
				cmd.Parameters.Add(new OracleParameter("p_studentobjectid", OracleDbType.Int32, 0, null, System.Data.ParameterDirection.Input));
				cmd.Parameters.Add(new OracleParameter("p_name", OracleDbType.Varchar2, name.Length, name, System.Data.ParameterDirection.Input));
				cmd.Parameters.Add(new OracleParameter("p_emailaddress", OracleDbType.Varchar2, email.Text.Length, email.Text, System.Data.ParameterDirection.Input));
				cmd.Parameters.Add(new OracleParameter("p_phonenumber", OracleDbType.Varchar2, cellPhone.Text.Length, cellPhone.Text, System.Data.ParameterDirection.Input));
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
						if (error == 0) error = null;
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
					//refresh_Click(sender, e);
					//addStudentPanel.Visible = false;
				}
				else
				{
					roster.Visible = false;
					addStudentPanel.Visible = true;
				}
			}

			catch (OracleException ex)
			{
				Utils.AppLog.Write(ex, Utils.AppLog.MessageType.ERROR);
				msg.InnerText = "Error in processing you registration.";
				msg.Style["color"] = "red";
			}

			catch (Exception ex)
			{
				Utils.AppLog.Write(ex, Utils.AppLog.MessageType.ERROR);
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

		protected void addStudent_Click(object sender, EventArgs e)
		{
			addStudentPanel.Visible = true;
			roster.Visible = false;

			firstName.Text = ""; 
			lastName.Text = "";
			cellPhone.Text = "";
			email.Text = "";
			reemail.Text = "";
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