//*****************************************************************************
//	File:		FmtReports.cs
//	Author:		Timothy J. Lord
//
//	Description:
//
// $Rev: 51 $  
// $Date: 2018-09-01 12:02:56 -0700 (Sat, 01 Sep 2018) $
// Last Changed By:  $$Author: TLord $
//
//*****************************************************************************
//	03/04/2016	TJL  9131 - Added retries to for retrieving data.
//	03/15/2016	TJL	 9217 - renamed output type extension of EXCEL to xlsx
//*****************************************************************************
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

using System.Web.Script.Serialization;
using System.Xml;
using Oracle.DataAccess.Client;
using Oracle.DataAccess.Types;

using System.Diagnostics;
using System.IO;
using System.ComponentModel;

using ABCRQSUtils;
using System.Reflection;
using System.ServiceModel.Activation;
using System.Configuration;

namespace RQS.Controllers
{
	public class FmtReports : ABCRQSUtils.OraBase
	{
		enum inx { ASSEMBLY, CLASS, METHOD };

		BackgroundWorker	worker = new BackgroundWorker();
		RptParameters		m_parameters;
		ABCException		m_ex			 = null;

		public static string Format(string tnsname, string data)
		{
			ABCRQSUtils.AppConfigurationSettings	cnfg		  = ABCRQSUtils.AppConfigurationSettings.getConfigurationSection(tnsname);
			string									message		  = null;
			FmtReports								report		  = null;
			ABCException							e;
			RptParameters							rptParameters = new RptParameters();

			try
			{
				rptParameters.Add("CONNECTION", cnfg.AppSettings["connection"].value); 
				rptParameters.Add("SEQ", data);
				rptParameters.Add("TNSNAME", tnsname);

				report = new FmtReports(rptParameters);

                report.UpdateStatus(report.m_parameters["SEQ"], "W", null, "P", data);

				report.worker.DoWork += new DoWorkEventHandler(report.process);
				report.worker.RunWorkerCompleted += new RunWorkerCompletedEventHandler(report.ProcessCompleted);
				report.worker.RunWorkerAsync();

                message = "Formating thread started";
			}

			catch (Exception ex)
			{
				e = new ABCException(report.m_parameters["SEQ"], ex);

				// get formatted message from exception
				message = e.Message;
                Console.WriteLine("Format Error: " + e.Message + " : " + e.StackTrace);
			}

			return message;
		}


		//******************************************************************
		//	Main processing methods for formating reports
		//******************************************************************
		protected FmtReports(RptParameters	parameters) : base(parameters["CONNECTION"], false)
		{
			this.m_parameters = parameters;
		}

		protected void process(object sender, DoWorkEventArgs e)
		{
			string				seq				= m_parameters.value("SEQ");
			string				method;
			byte[]				data			= null;
			byte[]				reportData		= null;
			byte[]				rawdata			= null;
			bool				saved;
			RQSConvert			convert;
			string				reportFormats;
			string[]			reportFormat;
			int					exportSeq		= 0;
			string				dataFormat		= null;

			new ABCException(seq, ABCException.MessageType.TRACE, "Formating Report Started", "FmtReports.process");

			// update status that process has started
			UpdateStatus(seq, "W", null, "P", null);

			// get report data
			Retrieve(seq, out rawdata, out dataFormat);
			method			= m_parameters.value("METHOD"); ;
			reportFormats   = m_parameters.value("OUTPUT_TYPE");
			reportFormat    = reportFormats.Split(',');
			if (m_ex == null)
			{
				foreach (string outputType in reportFormat)
				{
					// encrement export seq
					exportSeq++;

					// update output type for each report formats
					m_parameters.value("OUTPUT_TYPE", outputType);
					m_parameters["INPUT_TYPE"] = dataFormat;

					// check for special handler for selected report
					if (method == null)
					{
						// process selected format to generate the report in
						convert = new RQSConvert(m_parameters);
						data = convert.Process(rawdata);

						// check for error in convertsion
						if (convert.err != null) m_ex = convert.err;
					}
					else
					{
						// call process for special handling of data
						data = CallMethod(method, rawdata, out m_ex);
					}

					if (data != null)
					{
						// check if export of report is required
						if (m_parameters.value("EXPORT") == "FTP")
						{
							data = FTP(seq, data, exportSeq);
						}

						// save report data for only first report
						if (reportData == null) reportData = data;
					}

					// check if email notification is required (note or attached)
					if (m_parameters.value("REPORT_WAIT") != "Y")
					{
						if ((m_parameters.value("SOURCE") == "WEB") || ((m_parameters.value("SOURCE") == "AUTO") && (m_ex == null)))
						new ABCException(seq, ABCException.MessageType.TRACE, "Sending email notification: ", "FmtReports.process");
						EmailNotification(data, outputType, (data == null));
					}

					if (m_ex != null) break;
				}

				if ((reportData == null ? 0 : reportData.Length) > 0)
				{
					new ABCException(seq, ABCException.MessageType.TRACE, "Saving report data: size " + reportData.Length.ToString(), "FmtReports.process");
					saved = Save(seq, reportData);
					if (saved) new ABCException(seq, ABCException.MessageType.TRACE, "Saving data completed", "FmtReports.process");
				}
			}
			else
			{
				// check if email notification is required (note or attached)
				if ((m_parameters.value("REPORT_WAIT") != "Y") && (m_parameters.value("SOURCE") == "WEB"))
				{
					new ABCException(seq, ABCException.MessageType.TRACE, "Sending email notification: ", "FmtReports.process");
					EmailNotification(null, null, true);
				}
			}

			e.Result = "Completed";
		}

  		protected byte[] CallMethod(string methodName, byte[] rawdata, out ABCException e)
		{
			string[]					requestInfo;
			MethodInfo					method;
			Assembly					asm;
			Type						t_class;
			object						value;
			byte[]						data			= null; ;

			e = null;

			try
			{
				requestInfo = methodName.Split(';');

				asm = Assembly.Load(requestInfo[(int)inx.ASSEMBLY]);
				if (asm == null)
				{
					e = new ABCException(m_parameters["SEQ"], ABCException.MessageType.ERROR, "Assembly " + requestInfo[(int)inx.ASSEMBLY] + " not found");
					return data;
				}

				t_class = asm.GetType(requestInfo[(int)inx.ASSEMBLY] + "." + requestInfo[(int)inx.CLASS]);
				if (t_class != null)
				{
					method = t_class.GetMethod(requestInfo[(int)inx.METHOD], BindingFlags.Public | BindingFlags.Static | BindingFlags.Instance);
					if (method != null)
					{
						object obj = method.IsStatic ? null : Activator.CreateInstance(t_class);
						value = method.Invoke(obj, new object[] { m_parameters, rawdata });

						if (value is byte[]) data = (byte[])value;
						if (value is ABCException) e = (ABCException)value;
					}
					else
					{
						e = new ABCException(m_parameters["SEQ"], "Selected method not supported: " + requestInfo[(int)inx.METHOD]);
					}
				}
				else
				{
					e = new ABCException(m_parameters["SEQ"], "Selected class not supported: " + requestInfo[(int)inx.CLASS]);
				}
			}

			catch (Exception ex)
			{
				e = new ABCException(m_parameters["SEQ"], ex);
			}

			return data;
		}

		protected byte[] FTP(string seq, byte[] data, int exportSeq)
		{
            RQSFTP2         ftp2;
			RptParameters	exportParameters	= RetrieveParameters(m_parameters.value("REPORT_NUMBER"), "FTP", exportSeq);

            try
			{
				if (exportParameters.value("REPORT_NAME") == null)
				{
					// update export parameters with report name
					exportParameters.value("REPORT_NAME", m_parameters.value("REPORT_NAME"));
				}

				// update status to doing ftp
				UpdateStatus(seq, "F", null, "P", null);

                ftp2 = new RQSFTP2(exportParameters);
                if (!ftp2.IsError) ftp2.ZipFileName = exportParameters.value("ZIP");
                if (ftp2.IsError) m_ex = new ABCException(seq, ftp2.GetException);

				// ftp file 
                if (m_ex == null) 
                    if (ftp2.UploadFile(data, exportParameters.value("FILE_NAME")))
                    {
				        UpdateFtpLog(seq, ftp2.URL, exportSeq, "C", ftp2.Status, null);
                    }
                    else
                    {
                        UpdateFtpLog(seq, ftp2.URL, exportSeq, "E", ftp2.Status, ftp2.Status);
                        m_ex = new ABCException(seq, ftp2.Status, e: ftp2.GetException);
                    }
			}

			catch (Exception ex)
			{
				m_ex = new ABCException(m_parameters["SEQ"], ex);
			}

			return data;
		}

		protected void EmailNotification (byte[] data, string reportFormat, bool error)
		{
			RptParameters	emailParameters = m_parameters;
			string			from;
			string			to = m_parameters.value("EMAIL_TO");			
			string			cc;			
			string			bcc;			
			string			subject;		
			string			body;		
			string			fileName = m_parameters.value("EMAIL_FILENAME");
			string			encoding;
			string			mimeType;
			bool			attach;
			string[]		tos;

			try
			{
				// check if email notification is not to be sent
				if (m_parameters.value("EMAIL_NOTIFICATION") == "NO") return;

				// add extensions to email address if required
				// retrieve email parameters
				emailParameters = RetrieveEmailParameters(m_parameters.value("REPORT_NUMBER"), m_parameters.value("OFFICEOBJECTID"));
				if (emailParameters == null) return;

				to = (to == null) ? emailParameters.value("EMAIL_TO") : to;
				from = emailParameters.value("EMAIL_FROM");
				cc = emailParameters.value("EMAIL_CC");
				bcc = emailParameters.value("EMAIL_BCC");
				subject = emailParameters.value((error ? "EMAIL_SUBJECT_ERROR" : "EMAIL_SUBJECT"));
				body = emailParameters.value((error ? "EMAIL_BODY_ERROR" : "EMAIL_BODY"));
				fileName = (fileName != null) ? fileName : emailParameters.value("EMAIL_FILENAME");
				encoding = emailParameters.value("EMAIL_ENCODING");
				mimeType = emailParameters.value("EMAIL_MIMETYPE");
				attach = ((m_parameters.value("ATTACH_REPORT") == "Y") || (emailParameters.value("ATTACH_REPORT") == "Y"));

				if (to == null) return;
				if (mimeType == null) mimeType = "text/html";

				tos = to.Split(';');
				for (var inx = 0; inx < tos.Length; inx++)
				{
					if (tos[inx].IndexOf('@') > 0) continue;
					tos[inx] += "@abc.ca.gov";
				}
				to = string.Join(";", tos);

				m_cmd.CommandText = "rqs_email.sendemail";
				m_cmd.Parameters.Add(new OracleParameter("p_fromAddress", OracleDbType.Varchar2, from.Length, from,
															System.Data.ParameterDirection.Input));
				m_cmd.Parameters.Add(new OracleParameter("p_toAddress", OracleDbType.Varchar2, to.Length, to,
															System.Data.ParameterDirection.Input));
				m_cmd.Parameters.Add(new OracleParameter("p_cc", OracleDbType.Varchar2, (cc == null ? 0 : cc.Length), cc,
															System.Data.ParameterDirection.Input));
				m_cmd.Parameters.Add(new OracleParameter("p_bcc", OracleDbType.Varchar2, (bcc == null ? 0 : bcc.Length), bcc,
															System.Data.ParameterDirection.Input));
				m_cmd.Parameters.Add(new OracleParameter("p_subject", OracleDbType.Varchar2, subject.Length, subject,
															System.Data.ParameterDirection.Input));
				m_cmd.Parameters.Add(new OracleParameter("p_body", OracleDbType.Varchar2, body.Length, body,
															System.Data.ParameterDirection.Input));

				if (attach && (data != null))
				{
					if (reportFormat.ToUpper() == "EXCEL") reportFormat = "xlsx";
					fileName += "." + reportFormat;

					m_cmd.Parameters.Add(new OracleParameter("p_file_name", OracleDbType.Varchar2, fileName.Length, fileName,
																System.Data.ParameterDirection.Input));
					m_cmd.Parameters.Add(new OracleParameter("p_blob", OracleDbType.Blob, data.Length, data,
														System.Data.ParameterDirection.Input));
				}

				if (mimeType != null) m_cmd.Parameters.Add(new OracleParameter("p_mimeType", OracleDbType.Varchar2, mimeType.Length, mimeType,
														   System.Data.ParameterDirection.Input));

				Open();
				m_cmd.ExecuteNonQuery();
			}

			catch (Exception ex)
			{
				new ABCException(m_parameters.value("SEQ"), ex);
			}

			finally { Close(); }

		}

		protected RptParameters RetrieveParameters(string reportNumber, string parameterType, int exportSeq)
		{
			OracleDataReader reader = null;
			RptParameters	 reportParameters = null;

			try
			{
				m_cmd.CommandText = "RQS_REPORTS.get_parameters";
				m_cmd.Parameters.Add(new OracleParameter("p_report_number", OracleDbType.Int32, 0, Convert.ToInt32(reportNumber),
														  System.Data.ParameterDirection.Input));
				m_cmd.Parameters.Add(new OracleParameter("p_parameter_type", OracleDbType.Varchar2, parameterType.Length, parameterType,
														  System.Data.ParameterDirection.Input));
				m_cmd.Parameters.Add(new OracleParameter("p_export_seq", OracleDbType.Int32, 0, Convert.ToInt32(exportSeq),
														  System.Data.ParameterDirection.Input));
				m_cmd.Parameters.Add(base.m_cursor);
				m_cmd.Parameters.Add(base.m_statusMsg);

				Open();
				m_cmd.ExecuteNonQuery();

				// check for error
				if (((INullable)m_statusMsg.Value).IsNull)
				{
					if (((Oracle.DataAccess.Types.OracleRefCursor)(m_cursor.Value)).IsNull)
					{
						m_ex = new ABCException(m_parameters.value("SEQ"), ABCException.MessageType.ERROR, "No data read from database", "FmtReports.RetrieveParameters()");
					}
					else
					{
						reader = ((OracleRefCursor)base.m_cursor.Value).GetDataReader();
						reportParameters = new RptParameters(reader);
						reader.Close();
						reader = null;
					}
				}
				else
				{
					m_ex = new ABCException(m_parameters.value("SEQ"), m_statusMsg.Value.ToString(), "FmtReports.RetrieveParameters()");
				}
			}

			catch (Exception ex)
			{
				m_ex = new ABCException(m_parameters.value("SEQ"), ex);
			}

			finally { Close(); }
			
			return reportParameters;
		}

		protected RptParameters RetrieveEmailParameters(string reportNumber, string officeobjectid)
		{
			OracleParameter	 data				= new OracleParameter("p_report_process", OracleDbType.Varchar2, 32000, null,
																	   System.Data.ParameterDirection.Output);
			RptParameters	 reportParameters	= null;
			string			 reportProcess		= m_parameters.value("SOURCE");

			try
			{
				m_cmd.CommandText = "RQS_REPORTS.get_emailparameters";
				m_cmd.Parameters.Add(new OracleParameter("p_seq", OracleDbType.Int32, 0, Convert.ToInt32(m_parameters.value("SEQ")),
														  System.Data.ParameterDirection.Input));
				m_cmd.Parameters.Add(new OracleParameter("p_report_process", OracleDbType.Varchar2, reportProcess.Length, reportProcess,
														  System.Data.ParameterDirection.Input));
				m_cmd.Parameters.Add(new OracleParameter("p_report_number", OracleDbType.Int32, 0, Convert.ToInt32(reportNumber),
														  System.Data.ParameterDirection.Input));
				m_cmd.Parameters.Add(new OracleParameter("p_officeobjectid", OracleDbType.Int32, 0, Convert.ToInt32(officeobjectid),
														  System.Data.ParameterDirection.Input));
				m_cmd.Parameters.Add(data);
				m_cmd.Parameters.Add(base.m_statusMsg);

				Open();
				m_cmd.ExecuteNonQuery();

				// check for error
				if (((INullable)m_statusMsg.Value).IsNull)
				{
					reportParameters = new RptParameters(data.Value.ToString());
				}
				else
				{
					m_ex = new ABCException(m_parameters.value("SEQ"), m_statusMsg.Value.ToString(), "FmtReports.RetrieveEmailParameters()");
				}
			}

			catch (Exception ex)
			{
				m_ex = new ABCException(m_parameters.value("SEQ"), ex);
			}

			finally { Close(); }

			return reportParameters;
		}


		protected void Retrieve(string seq, out byte[] rawdata, out string dataFormat)
		{
			OracleDataReader reader = null;
			ABCException	 e      = null;

			rawdata = null;
			dataFormat = null;

			for (int cnt = 0; cnt < 2; cnt++ )
			{
				try
				{
					m_cmd.Parameters.Clear();
					m_cmd.CommandText = "RQS_REPORTS.get_unformated_report";
					m_cmd.Parameters.Add(new OracleParameter("p_seq", OracleDbType.Int32, 0, Convert.ToInt32(seq),
															  System.Data.ParameterDirection.Input));
					m_cmd.Parameters.Add(base.m_cursor);
					m_cmd.Parameters.Add(base.m_statusMsg);

					Open();
					m_cmd.ExecuteNonQuery();

					// check for error
					if (((INullable) m_statusMsg.Value).IsNull)
					{
						if (((Oracle.DataAccess.Types.OracleRefCursor)(m_cursor.Value)).IsNull)
						{
							e = new ABCException(m_parameters.value("SEQ"), ABCException.MessageType.ERROR, "Data Cursor not returned", "FmtReports.Retrieve()");
							if (cnt != 0) m_ex = e;
						}
						else
						{
							reader = ((OracleRefCursor)base.m_cursor.Value).GetDataReader();
							if (reader.Read())
							{
								new ABCException(seq, ABCException.MessageType.TRACE, "Get Raw Data ", "FmtReports.Retrieve");

								rawdata = reader.GetOracleBlob(reader.GetOrdinal("REPORT_DATA")).Value;

								dataFormat = reader.GetString(reader.GetOrdinal("DATA_FORMAT"));
								m_parameters.loadXML(reader.GetString(reader.GetOrdinal("REPORT_PARAMETERS")));

								reader.Close();
								new ABCException(seq, ABCException.MessageType.TRACE, "Reading Data Finished: size " + rawdata.Length.ToString(), "FmtReports.Retrieve");
							}
							else
							{
								reader.Close();
								reader = null;

								e = new ABCException(m_parameters.value("SEQ"), ABCException.MessageType.ERROR, "No data read from database", "FmtReports.Retrieve()");
								if (cnt != 0) m_ex = e;
								
							}
						}
					}
					else
					{
						e = new ABCException(m_parameters.value("SEQ"), ABCException.MessageType.ERROR, m_statusMsg.Value.ToString(), "FmtReports.Retrieve()");
						if (cnt != 0) m_ex = e;
					}

					// exit loop when data is received
					if (reader != null) break;
				}

				catch (Exception ex)
				{
					e = new ABCException(m_parameters.value("SEQ"), ex);
					if (cnt != 0) m_ex = e;
				}

				finally { Close(); }
			}
		}

		protected bool Save(string seq, byte[] data)
		{
			string	dataFormat = m_parameters.value("OUTPUT_TYPE");

			try
			{
				m_cmd.CommandText = "RQS_REPORTS.save_report";
				m_cmd.Parameters.Add(new OracleParameter("p_seq", OracleDbType.Int32, 0, Convert.ToInt32(seq),
															System.Data.ParameterDirection.Input));
				m_cmd.Parameters.Add(new OracleParameter("p_data_format", OracleDbType.Varchar2, dataFormat.Length, dataFormat,
															System.Data.ParameterDirection.Input));
				m_cmd.Parameters.Add(new OracleParameter("p_report_data", OracleDbType.Blob, data.Length, data,
															System.Data.ParameterDirection.Input));
				m_cmd.Parameters.Add(m_statusMsg);

				Open();
				m_cmd.ExecuteNonQuery();

				// check for errors
				if (!((INullable) m_statusMsg.Value).IsNull)
				{
					m_ex = new ABCException(m_parameters.value("SEQ"), m_statusMsg.Value.ToString());
				}
			}

			catch (Exception ex)
			{
				m_ex = new ABCException(m_parameters.value("SEQ"), ex);
			}

			finally { Close(); }

			return (m_ex == null);
		}


		protected void UpdateStatus(string seq, string step, string ora_status, string web_status, string message)
		{

			try
			{
				m_cmd.CommandText = "RQS_REPORTS.upd_status";
				m_cmd.Parameters.Add(new OracleParameter("p_seq", OracleDbType.Int32, 0, Convert.ToInt32(seq),
															System.Data.ParameterDirection.Input));
				m_cmd.Parameters.Add(new OracleParameter("p_step", OracleDbType.Varchar2, 1, step,
															System.Data.ParameterDirection.Input));
				m_cmd.Parameters.Add(new OracleParameter("p_ora_status", OracleDbType.Varchar2, 1, ora_status,
															System.Data.ParameterDirection.Input));
				m_cmd.Parameters.Add(new OracleParameter("p_web_status", OracleDbType.Varchar2, 1, web_status,
															System.Data.ParameterDirection.Input));
				m_cmd.Parameters.Add(new OracleParameter("p_message", OracleDbType.Varchar2, (message == null)? 1: message.Length, message,
															System.Data.ParameterDirection.Input));

				Open();
				m_cmd.ExecuteNonQuery();
			}

			catch (Exception) { }
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
				UpdateStatus(m_parameters.value("SEQ"), "E", null, "E", msg);
				new ABCException(m_parameters.value("SEQ"), ABCException.MessageType.TRACE, "Process Completed with Error", "FmtReports.ProcessCompleted()");
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
				UpdateStatus(m_parameters.value("SEQ"), "E", null, "E", "*** CANCELED ***");
				new ABCException(m_parameters.value("SEQ"), ABCException.MessageType.TRACE, "Process Canceled", "FmtReports.ProcessCompleted()");
			}
			else    // Finally, handle the case where the operation succeeded.
			{
				if (this.m_ex == null)
				{
					// call update status that report formating has completed
					UpdateStatus(m_parameters.value("SEQ"), "C", null, "C", null);
					new ABCException(m_parameters.value("SEQ"), ABCException.MessageType.TRACE, "Process Completed", "FmtReports.ProcessCompleted()");
				}
				else
				{
					UpdateStatus(m_parameters.value("SEQ"), "E", null, "E", m_ex.FormatedMessage(ABCException.FormatMsg.TEXT));
					new ABCException(m_parameters.value("SEQ"), ABCException.MessageType.TRACE, "Process Completed with Error", "FmtReports.ProcessCompleted()");
				}
			}
		}

	}	
}
