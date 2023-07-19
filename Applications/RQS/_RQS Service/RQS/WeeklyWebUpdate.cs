//*****************************************************************************
//	File:		WeeklyWebUpdates.cs
//	Author:		Timothy J. Lord
//
//	Description:
//
// $Rev: 51 $  
// $Date: 2018-09-01 12:02:56 -0700 (Sat, 01 Sep 2018) $
// Last Changed By:  $$Author: TLord $
//
//*****************************************************************************
//	09/16/2016	TJL  7213 - Initial class created.
//*****************************************************************************
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

using System.Web.Script.Serialization;
using Oracle.DataAccess.Client;
using Oracle.DataAccess.Types;

using System.Diagnostics;
using System.IO;
using System.ComponentModel;

using ABCRQSUtils;
using System.Reflection;
using System.ServiceModel.Activation;
using System.Configuration;

using System.Security.Cryptography.X509Certificates;
using System.Net.Security;
using System.Xml;
using System.Xml.Xsl;

namespace RQS.Controllers
{
	class WeeklyWebUpdate : ABCRQSUtils.OraBase
	{
		enum m_desc { DATE, DESCRIPTION, HREF, REPORT_NAME };

		BackgroundWorker	worker			 = new BackgroundWorker();
		RptParameters		m_parameters;
		ABCException		m_ex			 = null;

		public static string Update(string tnsname, string data)
		{
			ABCRQSUtils.AppConfigurationSettings	cnfg		  = ABCRQSUtils.AppConfigurationSettings.getConfigurationSection(tnsname);
			string									message		  = null;
			WeeklyWebUpdate							weeklyUpdate  = null;
			ABCException							e;
			RptParameters							rptParameters = new RptParameters(data);

			try
			{
				rptParameters.Add("CONNECTION", cnfg.AppSettings["connection"].value);
				rptParameters.Add("TNSNAME", tnsname);

				weeklyUpdate = new WeeklyWebUpdate(rptParameters);
				weeklyUpdate.UpdateStatus(rptParameters["JOB_ID"], rptParameters["FINALIZE_ID"], "W", data);

				weeklyUpdate.worker.DoWork += new DoWorkEventHandler(weeklyUpdate.process);
				weeklyUpdate.worker.RunWorkerCompleted += new RunWorkerCompletedEventHandler(weeklyUpdate.ProcessCompleted);
				weeklyUpdate.worker.RunWorkerAsync();

				message = "Formating thread started";
			}

			catch (Exception ex)
			{
				e = new ABCException(weeklyUpdate.m_parameters["SEQ"], ex);

				// get formatted message from exception
				message = e.Message;
			}

			return message;
		}

		//******************************************************************
		//	Main processing methods for formating reports
		//******************************************************************
		protected WeeklyWebUpdate(RptParameters parameters)
			: base(parameters["CONNECTION"])
		{
			this.m_parameters = parameters;
		}

		protected void process(object sender, DoWorkEventArgs e)
		{

			ProcessActions(out m_ex);


		}

		// Actions Filed and Finalized
		protected bool ProcessActions(out ABCException e)
		{
			SortedDictionary<string, string[]>	tbl			= new SortedDictionary<string, string[]>();
			RQSFTP2								ftp         = new RQSFTP2(m_parameters);
			XmlDocument							doc			= new XmlDocument();
			ProcessXML							proc		= new ABCRQSUtils.ProcessXML(m_parameters);
			XmlNode								root;
			XmlNode								xmlRow;

			string								data;
			string[]							recs;
			int									daysBack			= 0;
			string								html;
			string								directory	= m_parameters.value("DIRECTORY");
			string								path        = "../reports/";
			string								year             = null;

            e = null;

            data = ftp.GetDirList();

			// create sorted table based on date of file
            if (!ftp.IsError)
			{
				recs = data.Split(new char[] { '\n', '\r' }, StringSplitOptions.RemoveEmptyEntries);
				char[]  delimiter = new char[] { '_', '.' };

				foreach (string rec in recs)
				{
					string[]	item		= rec.Split(delimiter);
					string		name		= item[0];
					string[]	desc		= new string[Enum.GetNames(typeof(m_desc)).Length];
					DateTime	reportDate	= DateTime.Parse(item[1]);
					string		format		= "MM/dd/yyyy";

					daysBack = ((int)reportDate.DayOfWeek * -1) - 1;
					if (year == null) year = reportDate.AddDays(daysBack - 1).ToString("yyyy");

					desc[(int)m_desc.HREF] = directory + "\\" + rec;
					desc[(int) m_desc.DATE] = reportDate.AddDays(daysBack - 1).ToString("MMMM dd, yyyy");

					if (name.Contains("Filed"))
					{
						desc[(int) m_desc.REPORT_NAME] = "FILED";
						desc[(int) m_desc.DESCRIPTION] = "Filed Legal Proceedings from " + reportDate.AddDays(daysBack - 6).ToString(format) +
								  " to " + reportDate.AddDays(daysBack).ToString(format);
						tbl.Add(item[1] + "a", desc);
					}
					else
					{
						desc[(int) m_desc.REPORT_NAME] = "FINALIZED";
						desc[(int) m_desc.DESCRIPTION] = "Finalized Legal Proceedings  from " + reportDate.AddDays(daysBack - 6).ToString(format) +
								  " to " + reportDate.AddDays(daysBack).ToString(format);
						tbl.Add(item[1] + "b", desc);
					}

				}

				// build xml from sorted table
				var reverseSort = tbl.OrderByDescending(kvp => kvp.Key);

				root = doc.AppendChild(doc.CreateElement("ROOT"));

				foreach (var items in reverseSort)
				{
					string[] item = items.Value;

					xmlRow = root.AppendChild(doc.CreateElement(item[(int) m_desc.REPORT_NAME]));

					xmlRow.AppendChild(doc.CreateElement("DESCRIPTION")).InnerText = item[(int) m_desc.DESCRIPTION];
					xmlRow.AppendChild(doc.CreateElement("HREF")).InnerText = item[(int) m_desc.HREF];
					xmlRow.AppendChild(doc.CreateElement("DATE")).InnerText = item[(int) m_desc.DATE];
				}

				// create HTML
				m_parameters["CREATE_DATE"] = DateTime.Now.ToString("MM/dd/yyyy hh:mm tt");
				m_parameters["ARCHIVE_YEAR"] = year;

				html = proc.XMLtoHTML(Encoding.UTF8.GetBytes(doc.OuterXml), m_parameters, out e);

				// upload HTML
				if (e == null)
				{
                    ftp.UploadFile(Encoding.ASCII.GetBytes(html), m_parameters["FILE_NAME"]);
					UpdateFtpLog(m_parameters.value("FINALIZE_ID"), ftp.URL, 0, (!ftp.IsError ? "C" : "E"), ftp.Status, (e == null ? null : e.Message));
				}
			}

			tbl.Clear();
			doc = new XmlDocument();

			m_parameters.value("DIRECTORY", "");
            data = ftp.GetDirList();

            // create sorted table based on date of file
            if (!ftp.IsError)
			{
				recs = data.Split(new char[] { '\n', '\r' }, StringSplitOptions.RemoveEmptyEntries);
				char[]  delimiter = new char[] { '.' };

				foreach (string rec in recs)
				{
					string[]	item		= rec.Split(delimiter);
					string		name		= item[0];
					string[]	desc		= new string[3];

					if (name.Contains("Actions") && name.Length == 11 && item.Length == 2)
					{
						// check if item already exists
						if (!tbl.ContainsKey(name))
						{
							desc[0] = "Year " + name.Substring(7, 4) + " Archived Reports";
							desc[1] = path + rec;
							tbl.Add(name, desc);
						}
					}
				}

				// build xml from sorted table
				var reverseSort = tbl.OrderByDescending(kvp => kvp.Key);

				root = doc.AppendChild(doc.CreateElement("ROOT"));

				foreach (var items in reverseSort)
				{
					string[] item = items.Value;

					xmlRow = root.AppendChild(doc.CreateElement("ITEM"));

					xmlRow.AppendChild(doc.CreateElement("DESCRIPTION")).InnerText = item[0];
					xmlRow.AppendChild(doc.CreateElement("HREF")).InnerText = item[1];
				}

				// create HTML
				m_parameters["XML"] = "WeeklyArchiveHL.xslt";
				m_parameters["FILE_NAME"] = "HL_Archives.html";
				html = proc.XMLtoHTML(Encoding.UTF8.GetBytes(doc.OuterXml), m_parameters, out e);

				// upload HTML
				if (e == null)
				{
                    ftp.UploadFile(Encoding.ASCII.GetBytes(html), m_parameters["FILE_NAME"]);
                    UpdateFtpLog(m_parameters.value("FINALIZE_ID"), ftp.URL, 0, (!ftp.IsError ? "C" : "E"), ftp.Status, (e == null ? null : e.Message));
                }
			}
			return true;
		}


        //protected bool GetDirList(string directory, string id, out string statusDescription, out ABCException e)
        //{
        //    Dictionary<string, string>			args	= new Dictionary<string, string>();
        //    RQSFTP								ftp		= new RQSFTP();
        //    string								list;
        //    bool								results = false;

        //    results = ftp.GetDirList(m_parameters, out list, out statusDescription, out e);

        //    return results;
        //}

		protected void UpdateStatus(string jobId, string finalizeId, string status, string msg)
		{

			try
			{
				m_cmd.CommandText = "RQS_REPORTS.upd_status";
				m_cmd.Parameters.Add(new OracleParameter("p_job_id", OracleDbType.Int32, 0, Convert.ToInt32(jobId),
															System.Data.ParameterDirection.Input));
				m_cmd.Parameters.Add(new OracleParameter("p_finalize_id", OracleDbType.Int32, 0, Convert.ToInt32(finalizeId),
															System.Data.ParameterDirection.Input));
				m_cmd.Parameters.Add(new OracleParameter("p_status", OracleDbType.Varchar2, 1, status,
															System.Data.ParameterDirection.Input));
				m_cmd.Parameters.Add(new OracleParameter("p_msg", OracleDbType.Varchar2, (msg == null) ? 1 : msg.Length, msg,
															System.Data.ParameterDirection.Input));
				Open();
				m_cmd.ExecuteNonQuery();
			}

			catch (Exception ex) 
			{
				string  a = ex.Message;
			}
			finally { Close(); }

		}

		protected void UpdateFtpLog(string seq, string url, int exportId, string statusInd, string response, string message)
		{
			try
			{
				m_cmd.CommandText = "RQS_REPORTS.upd_export_log";
				m_cmd.Parameters.Add(new OracleParameter("p_job_id", OracleDbType.Int32, 0, Convert.ToInt32(m_parameters.value("JOB_ID")),
															System.Data.ParameterDirection.Input));
				m_cmd.Parameters.Add(new OracleParameter("p_seq", OracleDbType.Int32, 0, Convert.ToInt32(seq),
															System.Data.ParameterDirection.Input));
				m_cmd.Parameters.Add(new OracleParameter("p_url", OracleDbType.Varchar2, url.Length, url,
															System.Data.ParameterDirection.Input));
				m_cmd.Parameters.Add(new OracleParameter("p_export_id", OracleDbType.Int32, 0, exportId,
															System.Data.ParameterDirection.Input));
				m_cmd.Parameters.Add(new OracleParameter("p_status_ind", OracleDbType.Varchar2, 1, statusInd,
															System.Data.ParameterDirection.Input));
				m_cmd.Parameters.Add(new OracleParameter("p_response", OracleDbType.Varchar2, response.Length, response,
															System.Data.ParameterDirection.Input));
				m_cmd.Parameters.Add(new OracleParameter("p_error_msg", OracleDbType.Varchar2, (message == null) ? 1 : message.Length, message,
															System.Data.ParameterDirection.Input));

				Open();
				m_cmd.ExecuteNonQuery();
			}

			catch (Exception) { }
			finally { Close(); }

		}



		protected void ProcessCompleted(object sender, RunWorkerCompletedEventArgs e)
		{
			if (e.Error != null)
			{
				base.Close();
				string msg;

				msg = e.Error.Message + "  Stack Trace: "
						+ e.Error.StackTrace;

				// update status with retry
				UpdateStatus(m_parameters.value("JOB_ID"), m_parameters.value("FINALIZE_ID"), "E", msg);
				new ABCException(m_parameters.value("JOB_ID"), ABCException.MessageType.TRACE, "Process Completed with Error", "WeeklyWebUpdate.ProcessCompleted()");
			}
			else if (e.Cancelled)
			{
				// Next, handle the case where the user canceled  
				// the operation. 
				// Note that due to a race condition in  
				// the DoWork event handler, the Cancelled 
				// flag may not have been set, even though 
				// CancelAsync was called.
				//resultLabel.Text = "Canceled";
				//ABCWebUtils.DBLog.LogInformation("T", m_info["REPORT"], "ProcessCompleted", null, "Thread Cancelled");
				UpdateStatus(m_parameters.value("JOB_ID"), m_parameters.value("FINALIZE_ID"), "E", "*** CANCELED ***");
				new ABCException(m_parameters.value("SEQ"), ABCException.MessageType.TRACE, "Process Canceled", "WeeklyWebUpdate.ProcessCompleted()");
			}
			else    // Finally, handle the case where the operation succeeded.
			{
				if (this.m_ex == null)
				{
					// call update status that report formating has completed
					UpdateStatus(m_parameters.value("JOB_ID"), m_parameters.value("FINALIZE_ID"), "C", null);
					new ABCException(m_parameters.value("SEQ"), ABCException.MessageType.TRACE, "Process Completed", "WeeklyWebUpdate.ProcessCompleted()");
				}
				else
				{
					UpdateStatus(m_parameters.value("JOB_ID"), m_parameters.value("FINALIZE_ID"), "E", m_ex.FormatedMessage(ABCException.FormatMsg.TEXT));
					new ABCException(m_parameters.value("SEQ"), ABCException.MessageType.TRACE, "Process Completed with Error", "WeeklyWebUpdate.ProcessCompleted()");
				}
			}
		}

	
	}
}
