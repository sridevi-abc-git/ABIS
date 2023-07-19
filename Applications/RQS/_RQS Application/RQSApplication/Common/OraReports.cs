//*****************************************************************************
//	File:		OraReports.cs
//	Author:		Timothy J. Lord
//
//	Description:
//
// $Rev: 51 $  
// $Date: 2018-09-01 12:02:56 -0700 (Sat, 01 Sep 2018) $
// Last Changed By:  $Author: TLord $
//
//*****************************************************************************
//	01/06/2015	TJL  5928 - Modified to handle LongBeach report extract.
//	05/06/2015	TJL	 7213 - Added support of zipping reports before FTP transfer
//*****************************************************************************
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;

using Oracle.DataAccess.Client;
using Oracle.DataAccess.Types;
using System.Web.Script.Serialization;
using System.Xml;

using System.Threading;
//using Word = Microsoft.Office.Interop.Word;
//using oWord = Microsoft.Office.Interop.Word;
using System.Reflection;
using ABCRQSUtils;

namespace RQS.Common
{
    public class OraReports : ABCRQSUtils.OraBase
    {
		protected byte[] m_raw;

        public OraReports() : base() {}
        public OraReports(string connectionString) : base(connectionString) {}
//		public OraReports(Dictionary<string, string> info, Boolean open = true) : base(info, open) { }

		public string GetControlParameter(string data)
		{
			OracleParameter						results;
			JavaScriptSerializer                jss = new JavaScriptSerializer();
			Dictionary<string, string>          info = new Dictionary<string, string>();
			RptParameters						parameters;
			string								connection;
			string								user;
			ABCRQSUtils.ABCException			e;

			results = new OracleParameter("p_data", OracleDbType.Varchar2, 32000, null, System.Data.ParameterDirection.Output);
			parameters = new RptParameters(data);
			user = parameters.value("USEROBJECTID");
			connection = parameters.value("CONNECTION");

			// check if user is still active and get unique id for user id
			m_cmd.CommandText = "rqs_reports.get_control_parameter";
			m_cmd.Parameters.Add(new OracleParameter("p_userobjectid", OracleDbType.Varchar2, user.Length, user,
														System.Data.ParameterDirection.Input));
			m_cmd.Parameters.Add(results);
			m_cmd.Parameters.Add(m_statusMsg);

			e = Open(connection);
			if (e == null)
			{
				m_cmd.ExecuteNonQuery();
				Close();

				// check for errors
				if (((INullable)m_statusMsg.Value).IsNull)
				{
					info["data"] = results.Value.ToString();
				}
				else
				{
					info["err"] = m_statusMsg.Value.ToString();
				}
			}
			else
			{
				info["err"] = e.FormatedMessage();
			}

			return jss.Serialize(info);
		}


		/// <summary>
		/// UserInfo method veries the userid through the connection string and return
		/// report lists the user has access to.
		/// </summary>
		/// <param name="loginId">User database (ABIS) login id</param>
		/// <param name="connectionString">Encrypted connection string</param>
		/// <returns>User information or error message in a JSON string</returns>
		//public string UserInfo(string loginId, string connectionString)
		//{
		//	JavaScriptSerializer                jss = new JavaScriptSerializer();
		//	List<Dictionary<string, string>>    recs = new List<Dictionary<string, string>>();
		//	Dictionary<string, string>          info = new Dictionary<string, string>();
		//	Dictionary<string, string>          rec;
		//	OracleDataReader                    reader;

		//	try
		//	{
		//		// check if user is still active and get unique id for user id
		//		m_cmd.CommandText = "ABCREPORTS.RQS_USER.info";
		//		m_cmd.Parameters.Add(new OracleParameter("p_user_id", OracleDbType.Varchar2, loginId.Length, loginId,
		//													System.Data.ParameterDirection.Input));
		//		m_cmd.Parameters.Add(m_cursor);
		//		m_cmd.Parameters.Add(m_statusMsg);

		//		m_cmd.ExecuteNonQuery();

		//		if (((INullable) m_statusMsg.Value).IsNull)
		//		{
		//			if (((Oracle.DataAccess.Types.OracleRefCursor)(m_cursor.Value)).IsNull)
		//			{
		//				info["err"] = "Failure to get User Information";
		//			}
		//			else
		//			{
		//				reader = ((OracleRefCursor)m_cursor.Value).GetDataReader();
		//				rec = new Dictionary<string, string>();

		//				if (reader.Read())
		//				{
		//					for (Int32 index = 0; index < reader.FieldCount; index++)
		//					{
		//						object value = reader.GetValue(index);
		//						rec[reader.GetName(index)] = (value == DBNull.Value) ? "" : reader.GetValue(index).ToString();
		//					}

		//					rec["CONNECTION"] = connectionString;
		//				}

		//				reader.Close();

		//				info["data"] = jss.Serialize(rec);
		//			}
		//		}
		//		else
		//		{
		//			info["err"] = m_statusMsg.Value.ToString();
		//		}

		//	}

		//	catch (Exception ex)
		//	{
		//		ex.Data["Data Source"] = m_dataSource;
		//		info["err"] = ABCWebUtils.ProcessErrors.ProcessException(ex, "Error validating User Id: " + ex.Message);
		//	}

		//	return jss.Serialize(info);
		//}


		/// <summary>
		/// 
		/// </summary>
		/// <param name="user_id"></param>
		/// <param name="access_list"></param>
		/// <returns></returns>
        public string OfficeList(Int32 user_id, string access_list)
        {
            JavaScriptSerializer jss = new JavaScriptSerializer();
            List<Dictionary<string, string>> recs = new List<Dictionary<string, string>>();
            Dictionary<string, string> info = new Dictionary<string, string>();
            Dictionary<string, string> rec;
            OracleDataReader reader;

            try
            {
                // check if user is still active and get unique id for user id
                m_cmd.Parameters.Clear();
                m_cmd.CommandText = "ABCREPORTS.RQS_UTILS.OFFICELIST";
                m_cmd.Parameters.Add(new OracleParameter("p_user_object_id", OracleDbType.Int32, 0, user_id,
                                                            System.Data.ParameterDirection.Input));
                m_cmd.Parameters.Add(m_cursor);
                m_cmd.Parameters.Add(m_statusMsg);

                m_cmd.ExecuteNonQuery();

                if (((INullable)m_statusMsg.Value).IsNull)
                {
                    if (((Oracle.DataAccess.Types.OracleRefCursor)(m_cursor.Value)).IsNull)
                    {
                        info["err"] = "Failure to get report defination.";
                    }
                    else
                    {
                        reader = ((OracleRefCursor)m_cursor.Value).GetDataReader();
                        while (reader.Read())
                        {
                            rec = new Dictionary<string, string>();

                            for (Int32 index = 0; index < reader.FieldCount; index++)
                            {
                                object value = reader.GetValue(index);
                                rec[reader.GetName(index)] = (value == DBNull.Value) ? "" : reader.GetValue(index).ToString();
                            }

                            recs.Add(rec);
                        }

                        reader.Close();

                        info["OFFICELIST"] = jss.Serialize(recs);
                    }
                }
                else
                {
                    info["err"] = m_statusMsg.Value.ToString();
                }

            }

            catch (Exception ex)
            {
				ex.Data["Data Source"] = m_conn.DataSource;
				info["err"] = new ABCRQSUtils.ABCException(null, ex).FormatedMessage(); //; ABCWebUtils.ProcessErrors.ProcessException(ex, "Error validating User Id: " + ex.Message);
            }

            return jss.Serialize(info);
        }


		/// <summary>
		/// 
		/// </summary>
		/// <param name="user_id"></param>
		/// <param name="access_list"></param>
		/// <returns></returns>
		//public string ReportDefs(Int32 user_id, string access_list)
		//{
		//	JavaScriptSerializer jss = new JavaScriptSerializer();
		//	List<Dictionary<string, string>> recs = new List<Dictionary<string, string>>();
		//	Dictionary<string, string> info = new Dictionary<string, string>();
		//	Dictionary<string, string> rec;
		//	OracleDataReader reader;

		//	try
		//	{

		//		m_cmd.Parameters.Clear();
		//		m_cmd.CommandText = "ABCREPORTS.rqs_reports.get_defs";
		//		m_cmd.Parameters.Add(new OracleParameter("p_user_id", OracleDbType.Int32, 0, user_id,
		//													System.Data.ParameterDirection.Input));
		//		m_cmd.Parameters.Add(m_cursor);
		//		m_cmd.Parameters.Add(m_statusMsg);

		//		m_cmd.ExecuteNonQuery();

		//		if (((INullable)m_statusMsg.Value).IsNull)
		//		{
		//			if (((Oracle.DataAccess.Types.OracleRefCursor)(m_cursor.Value)).IsNull)
		//			{
		//				info["err"] = "Failure to get report defination.";
		//			}
		//			else
		//			{
		//				reader = ((OracleRefCursor)m_cursor.Value).GetDataReader();
		//				while (reader.Read())
		//				{
		//					rec = new Dictionary<string, string>();

		//					for (Int32 index = 0; index < reader.FieldCount; index++)
		//					{
		//						object value = reader.GetValue(index);
		//						rec[reader.GetName(index)] = (value == DBNull.Value) ? "" : reader.GetValue(index).ToString();
		//					}

		//					recs.Add(rec);
		//				}

		//				reader.Close();

		//				info["REPORTS"] = jss.Serialize(recs);
		//			}
		//		}
		//		else
		//		{
		//			info["err"] = m_statusMsg.Value.ToString();
		//		}

		//	}

		//	catch (Exception ex)
		//	{
		//		ex.Data["Data Source"] = m_conn.DataSource;
		//		info["err"] = ABCWebUtils.ProcessErrors.ProcessException(ex, "Error validating User Id: " + ex.Message);
		//	}

		//	return jss.Serialize(info);
		//}


		/// <summary>
		/// 
		/// </summary>
		/// <param name="data"></param>
		/// <returns></returns>
        public virtual string Schedule(string data)
        {
			JavaScriptSerializer        jss			= new JavaScriptSerializer();
			Dictionary<string, string>	info		= new Dictionary<string, string>();
            OracleParameter				statusInd	= new OracleParameter("p_status_ind", OracleDbType.Varchar2, 1, null, System.Data.ParameterDirection.Output);
            OracleParameter				requestId	= new OracleParameter("p_request_id", OracleDbType.Varchar2, 15, null, System.Data.ParameterDirection.Output);
            Dictionary<string, string>	rec			= new Dictionary<string, string>();
			RptParameters				parameters  = null;
			ABCRQSUtils.ABCException	e;
			string						xml;

			try
			{
				parameters = new RptParameters(data);
				xml = parameters.getXML();

				m_cmd.CommandText = "RQS_SCHEDULE";
				m_cmd.Parameters.Add(new OracleParameter("p_parms", OracleDbType.XmlType, xml.Length, xml,
														  System.Data.ParameterDirection.Input));
				m_cmd.Parameters.Add(statusInd);
				m_cmd.Parameters.Add(requestId);
				m_cmd.Parameters.Add(m_statusMsg);

				e = Open(parameters.value("CONNECTION"));
				if (e == null)
				{
					m_cmd.ExecuteNonQuery();

					// check for errors
					// check status indicator
					switch (statusInd.Value.ToString())
					{
						case "E":
							// return error message
							info["err"] = m_statusMsg.Value.ToString();
							break;

						case "S":
							// return message
							info["msg"] = m_statusMsg.Value.ToString();
							break;

						default:
							// put parms id into a data wrapper
							info["data"] = requestId.Value.ToString();
							break;
					}
					Close();
				}
				else
				{
					info["err"] = e.FormatedMessage();
				}
			}

			catch (Exception ex)
			{
				info["err"] = new ABCRQSUtils.ABCException(parameters.value("SEQ"), ex).FormatedMessage() // ABCWebUtils.ProcessErrors.ProcessException(ex, "Error scheduling report(Status) " + ex.Message +
					        + " system: " + System.Web.HttpContext.Current.ApplicationInstance.Request.Url.Host.ToLower();
			}

			return jss.Serialize(info);

		}
		//		//if (m_conn.State == System.Data.ConnectionState.Closed) m_conn.Open();
		//		m_cmd.ExecuteNonQuery();

		//		// check status indicator
		//		switch (statusInd.Value.ToString())
		//		{
		//			case "E":
		//				// return error message
		//				info["err"] = m_statusMsg.Value.ToString();
		//				break;

		//			case "S":
		//				// return message
		//				info["msg"] = m_statusMsg.Value.ToString();
		//				break;

		//			default:
		//				// put parms id into a data wrapper
		//				info["data"] = requestId.Value.ToString();
		//				break;
		//		}
		//	}

		//	return (new JavaScriptSerializer()).Serialize(info);
		//}

		public string GetStatus(string data)
		{
			JavaScriptSerializer        jss			= new JavaScriptSerializer();
			Dictionary<string, string>	info		= new Dictionary<string, string>();
			OracleParameter				statusInfo	= new OracleParameter("p_data", OracleDbType.Varchar2, 8000, null, System.Data.ParameterDirection.Output);
			RptParameters				parameters  = null;
			ABCRQSUtils.ABCException	e;

			try
			{
				parameters = new RptParameters(data);

				m_cmd.CommandText = "RQS_REPORTS.get_status";
				m_cmd.Parameters.Add(new OracleParameter("p_job_id", OracleDbType.Int32, 0, Convert.ToInt32(parameters.value("JOB_ID")),
														  System.Data.ParameterDirection.Input));
				m_cmd.Parameters.Add(statusInfo);
				m_cmd.Parameters.Add(base.m_statusMsg);

				e = Open(parameters.value("CONNECTION"));
				if (e == null)
				{
					m_cmd.ExecuteNonQuery();

					// check for errors
					if (((INullable)m_statusMsg.Value).IsNull)
					{
						info["data"] = statusInfo.Value.ToString();
					}
					else
					{
						info["err"] = m_statusMsg.Value.ToString();
					}

					Close();
				}
				else
				{
					info["err"] = e.FormatedMessage();
				}
			}

			catch (Exception ex)
			{
				e = new ABCRQSUtils.ABCException(parameters.value("SEQ"), ex);
				info["err"] = e.FormatedMessage();
			}

			finally
			{

			}

			return jss.Serialize(info);
		}


		public virtual string CancelReports(string data)
		{
			Dictionary<string, string>	info = new Dictionary<string, string>();
			RptParameters				parameters;

			parameters = new RptParameters(data);

			m_cmd.CommandText = "rqs_reports.cancel_report";
			m_cmd.Parameters.Add(new OracleParameter("p_job_id", OracleDbType.Int32, 0, Convert.ToInt32(parameters.value("JOBID")),
														System.Data.ParameterDirection.Input));

			Open(parameters.value("CONNECTION"));
			m_cmd.ExecuteNonQuery();
			Close();
			info["msg"] = "Report(s) Canceled";
			return (new JavaScriptSerializer()).Serialize(info);
		}


		public string RetrieveReportList(string data)
		{
			JavaScriptSerializer        jss			= new JavaScriptSerializer();
			Dictionary<string, string>	info		= new Dictionary<string, string>();
			OracleParameter				listData	= new OracleParameter("p_data", OracleDbType.Clob, int.MaxValue, null, System.Data.ParameterDirection.Output);
			Dictionary<string, string>	rec			= new Dictionary<string, string>();
			RptParameters				parameters  = null;
			ABCRQSUtils.ABCException	e;
			string						xml;

			try
			{
				parameters = new RptParameters(data);
				xml = parameters.getXML();

				m_cmd.CommandText = "rqs_reports.get_report_list";
				m_cmd.Parameters.Add(new OracleParameter("p_parms", OracleDbType.XmlType, xml.Length, xml,
														  System.Data.ParameterDirection.Input));
				m_cmd.Parameters.Add(listData);
				m_cmd.Parameters.Add(m_statusMsg);

				e = Open(parameters.value("CONNECTION"));
				if (e == null)
				{
					m_cmd.ExecuteNonQuery();

					// check for errors
					if (((INullable)m_statusMsg.Value).IsNull)
					{
						info["data"] = ((Oracle.DataAccess.Types.OracleClob) listData.Value).Value;
					}
					else
					{
						info["err"] = m_statusMsg.Value.ToString();
					}
				}
				else
				{
					info["err"] = e.FormatedMessage();
				}

				Close();

			}


			catch (Exception ex)
			{
				e = new ABCRQSUtils.ABCException(parameters.value("SEQ"), ex);
				info["err"] = e.FormatedMessage();
			}

			return jss.Serialize(info);

		}


		public string RetrieveReport(string data)
		{
			JavaScriptSerializer        jss				= new JavaScriptSerializer();
			Dictionary<string, string>	info			= new Dictionary<string, string>();
			Dictionary<string, string>	reportInfo		= new Dictionary<string, string>();
            OracleParameter				reportData		= new OracleParameter("p_data", OracleDbType.Blob, int.MaxValue, null, System.Data.ParameterDirection.Output);
			OracleParameter				outParameters	= new OracleParameter("p_parameters", OracleDbType.Varchar2, 8000, null, System.Data.ParameterDirection.Output);
			OracleParameter				dataFormat		= new OracleParameter("p_data_format", OracleDbType.Varchar2, 200, null, System.Data.ParameterDirection.Output);
			RptParameters				parameters      = null;
			RptParameters				outInfo;
			ABCRQSUtils.ABCException	e;
			byte[]						reportDataInfo;
			ABCRQSUtils.RQSFTP			ftp;
			RptParameters				output;
			string						destinatonFileName = null;
			string						statusDescription;
			string						url;
            string                      cnfg = System.Web.HttpContext.Current.Request.Url.Host;

			try
			{
                if (cnfg.Contains("."))
                {
                    cnfg = cnfg.Substring(0, cnfg.IndexOf("."));
                }
                else
                {
                    cnfg = (cnfg.ToLower() == "localhost" ? System.Environment.MachineName : cnfg);
                }

				parameters = new RptParameters(data);

				new ABCException(parameters.value("SEQ"), ABCException.MessageType.TRACE, "Retrieving Report", "OraReports.RetrieveReport");

				m_cmd.CommandText = "RQS_REPORTS.get_report";
				m_cmd.Parameters.Add(new OracleParameter("p_seq", OracleDbType.Int32, 0, Convert.ToInt32(parameters.value("SEQ")),
														  System.Data.ParameterDirection.Input));
				m_cmd.Parameters.Add(reportData);
				m_cmd.Parameters.Add(outParameters);
				m_cmd.Parameters.Add(dataFormat);
				m_cmd.Parameters.Add(m_statusMsg);

				e = Open(parameters.value("CONNECTION"));
				if (e == null)
				{
					m_cmd.ExecuteNonQuery();

					// check for errors
					if (((INullable)m_statusMsg.Value).IsNull)
					{
						// get output parameters
						outInfo			= new RptParameters(outParameters.Value.ToString());
						outInfo["OUTPUT_TYPE"] = dataFormat.Value.ToString();
                        outInfo["TNSNAME"] = m_conn.DataSource;
                        outInfo["CNFG"] = cnfg;

						reportDataInfo	= ((Oracle.DataAccess.Types.OracleBlob)(reportData.Value)).Value;

						// check if file name passed else use report name
						destinatonFileName = outInfo.value("FILE_NAME");
						if (destinatonFileName == null)
						{
							destinatonFileName = outInfo.value("REPORT_NAME");
						}
						destinatonFileName += "." + parameters.value("SEQ");
						outInfo.value("SEQ", parameters.value("SEQ"));

						switch (outInfo.value("OUTPUT_TYPE"))
						{
							case "HTML": outInfo.value("FILE_NAME", destinatonFileName + ".html"); break;
							case "EXCEL": outInfo.value("FILE_NAME", destinatonFileName + ".xlsx"); break;
							case "PDF": outInfo.value("FILE_NAME", destinatonFileName + ".pdf"); break;
							default: outInfo.value("FILE_NAME", destinatonFileName); break;
						}

						switch (outInfo.value("OUTPUT_TYPE"))
						{
							case "RAW":
							case "HTML":
								// convert data to string
								reportInfo["output_type"] = dataFormat.Value.ToString();
								reportInfo["file"] = System.Text.Encoding.Default.GetString(reportDataInfo);
								jss.MaxJsonLength = Int32.MaxValue;
								info["data"] = jss.Serialize(reportInfo);
								break;

							case "EXCEL":
							case "PDF":
								//ABCRQSUtils.RQSConvert	cvrt	= new ABCRQSUtils.RQSConvert(outInfo);
								ftp		= new ABCRQSUtils.RQSFTP();

								if (!ftp.UploadFile(reportDataInfo, outInfo, out url, out statusDescription, out e))
								{
									// process as error
									info["err"] = "FTP: " + e.FormatedMessage();
								}
								else
								{
									reportInfo["output_type"] = outInfo.value("OUTPUT_TYPE");
									reportInfo["file"] = outInfo.value("REPORT_DIRECTORY") + outInfo.value("FILE_NAME");
									info["data"] = jss.Serialize(reportInfo);
								}

								break;

							case "FTP":
								ftp		= new ABCRQSUtils.RQSFTP();
								output	= new RptParameters();

								// add parameters required by ftp routine 
								output.value("REPORT_NAME", outInfo.value("FTP")); // needed to get ftp information from configuration file
								output.value("DESTINATION_FILENAME", outInfo.value("FILE_PATH") + outInfo.value("FILE_NAME"));

								if (!ftp.UploadFile(reportDataInfo, output, out url, out statusDescription, out e))
								{
									// process as error
									info["err"] = e.FormatedMessage();
								}
								else
								{
									reportInfo["output_type"] = "PDF";
									reportInfo["file"] = output.value("DESTINATION_FILENAME");
									info["data"] = jss.Serialize(reportInfo);
								}
								break;

							default:
								info["err"] = "Not supported output type: " + outInfo.value("OUTPUT_TYPE");
								break;
						}
					}
					else
					{
						info["err"] = m_statusMsg.Value.ToString();
					}

					Close();

				}
				else
				{
					info["err"] = "Open: " + e.FormatedMessage();
				}

				new ABCException(parameters.value("SEQ"), ABCException.MessageType.TRACE, "Retrieving Report Completed", "OraReports.RetrieveReport");
			}
			catch (Exception ex)
			{
				e = new ABCRQSUtils.ABCException(parameters.value("SEQ"), ex);
				info["err"] = ex.Message + " " + e.FormatedMessage();
			}

			return jss.Serialize(info);

		}


		//**********************************************************************************************************************
		//**********************************************************************************************************************
		//**********************************************************************************************************************
		//**********************************************************************************************************************
		//**********************************************************************************************************************


		/// <summary>
		/// 
		/// </summary>
		/// <param name="data"></param>
		/// <returns></returns>
		//public virtual string StatusCheck(string data)
		//{
		//	Dictionary<string, string> info = new Dictionary<string, string>();
		//	OracleParameter statusInd = new OracleParameter("p_status_ind", OracleDbType.Varchar2, 1, null, System.Data.ParameterDirection.Output);

		//	try
		//	{
		//		m_cmd.CommandText = "ABCREPORTS.RQS_STATUS";
		//		m_cmd.Parameters.Add(new OracleParameter("p_request_id", OracleDbType.Varchar2, data.Length, data,
		//												  System.Data.ParameterDirection.Input));
		//		m_cmd.Parameters.Add(statusInd);
		//		m_cmd.Parameters.Add(m_statusMsg);

		//		//if (m_conn.State == System.Data.ConnectionState.Closed) m_conn.Open();
		//		m_cmd.ExecuteNonQuery();

		//		// check status indicator for errors
		//		if (statusInd.Value.ToString() == "E")
		//		{
		//			// return error message
		//			info["err"] = m_statusMsg.Value.ToString();
		//		}
		//		else
		//		{
		//			// put parms id into a data wrapper
		//			info["data"] = statusInd.Value.ToString();
		//		}
		//	}

		//	catch (Exception ex)
		//	{
		//		info["err"] = ABCRQSUtils.ABCException.Create(ex).FormatedMessage //ABCWebUtils.ProcessErrors.ProcessException(ex, "Error getting report status(Status) " + ex.Message +
		//					+ " system: " + System.Web.HttpContext.Current.ApplicationInstance.Request.Url.Host.ToLower());
		//	}

		//	return (new JavaScriptSerializer()).Serialize(info);
		//}



		/// <summary>
		/// 
		/// </summary>
		/// <param name="data"></param>
		/// <returns></returns>
		//public virtual string ReportList(string data)
		//{
		//	List<Dictionary<string, string>> recs = new List<Dictionary<string, string>>();
		//	Dictionary<string, string> info = new Dictionary<string, string>();
		//	Dictionary<string, string> rec;
		//	OracleParameter cursor = new OracleParameter("p_data", OracleDbType.RefCursor, System.Data.ParameterDirection.Output);
		//	OracleDataReader reader;

		//	try
		//	{
		//		if (data.Length == 0) data = "na";

		//		m_cmd.CommandText = "ABCREPORTS.rqs_reports.get_list";
		//		m_cmd.Parameters.Add(new OracleParameter("p_parms", OracleDbType.XmlType, data.Length, data,
		//												  System.Data.ParameterDirection.Input));
		//		m_cmd.Parameters.Add(cursor);
		//		m_cmd.Parameters.Add(m_statusMsg);

		//		m_cmd.ExecuteNonQuery();

		//		reader = ((OracleRefCursor)cursor.Value).GetDataReader();
		//		while (reader.Read())
		//		{
		//			rec = new Dictionary<string, string>();

		//			for (Int32 index = 0; index < reader.FieldCount; index++)
		//			{
		//				object value = reader.GetValue(index);
		//				rec[reader.GetName(index)] = (value == DBNull.Value) ? "" : reader.GetValue(index).ToString();
		//			}

		//			recs.Add(rec);
		//		}

		//		reader.Close();

		//		info["data"] = (new JavaScriptSerializer()).Serialize(recs);
		//	}

		//	catch (Exception ex)
		//	{
		//		info["err"] = ABCRQSUtils.ABCException.Create(ex).FormatedMessage // ABCWebUtils.ProcessErrors.ProcessException(ex, "Error getting report list: " + ex.Message +
		//					+ " system: " + System.Web.HttpContext.Current.ApplicationInstance.Request.Url.Host.ToLower());
		//	}

		//	return (new JavaScriptSerializer()).Serialize(info); ;
		//}


//		public void FormatReport(Dictionary<string, string> request, out Exception e)
//		{
//			Dictionary<string, Dictionary<string, string>>	parms;
//			JavaScriptSerializer		jss      = new JavaScriptSerializer();
//			Dictionary<string, string>  info     = new Dictionary<string, string>();
//			OracleParameter             cursor   = new OracleParameter("p_data", OracleDbType.RefCursor, System.Data.ParameterDirection.Output);
//			Dictionary<string, string>  rec      = new Dictionary<string, string>();
//			OracleDataReader		    reader;
//			string					    request_id = null;
//			string						output_type = null;
//			string						fileName = null;
//			Int32						retry = 0;

//			e = null;

//			try
//			{
//				// open connection to database
//				m_conn.Open();

//				// make sure connection is open
//				if (m_conn.State != System.Data.ConnectionState.Open)
//				{
//					ABCWebUtils.DBLog.LogInformation("E", request["REPORT"], "FormatReport", "Connection", "Connection not open");
//					return;
//				}

//				ABCWebUtils.DBLog.LogInformation("T", request["REPORT"], "FormatReport", null, "Getting report data");
//				request_id = request["REPORT"];

//				//*********************************************************************************
//				// Retrieve raw report data and parameters to format the report
//				//*********************************************************************************
//				m_cmd.Parameters.Clear();		// make sure parameters are cleared for new request

//				m_cmd.CommandText = "ABCREPORTS.RQS_REPORTS.get_report_info";
//				m_cmd.Parameters.Add(new OracleParameter("p_request_id", OracleDbType.Varchar2, request_id.Length, request_id,
//														  System.Data.ParameterDirection.Input));
//				m_cmd.Parameters.Add(cursor);
//				m_cmd.Parameters.Add(m_statusMsg);

//				while (retry++ < 3 && rec.Count == 0)
//				{
//					m_cmd.ExecuteNonQuery();

//					reader = ((OracleRefCursor)cursor.Value).GetDataReader();
//					ABCWebUtils.DBLog.LogInformation("T", request["REPORT"], "FormatReport", null, "start of reading");

//					// Process report data returned from query
//					if (reader.Read())
//					{
//						for (Int32 index = 0; index < reader.FieldCount; index++)
//						{
//							//ABCWebUtils.DBLog.LogInformation("T", request["REPORT"], "FormatReport", null, "index: " + index.ToString());
//							object value = reader.GetValue(index);
//							rec[reader.GetName(index)] = (value == DBNull.Value) ? "" : value.ToString(); // reader.GetValue(index).ToString();
//						}


//					}

//					reader.Close();

//					// wait a second before trying again
//					if (rec.Count == 0) System.Threading.Thread.Sleep(1000);
//				}
//				m_conn.Close();

//				if (rec.Count > 0)
//				{
//					ABCWebUtils.DBLog.LogInformation("T", request["REPORT"], "FormatReport", null, "Processing Report Records");

//					//*********************************************************************************
//					// process retrieve output parameters
//					//*********************************************************************************
//					parms = jss.Deserialize<Dictionary<string, Dictionary<string, string>>>(rec["OUTPUT_PARAMETERS"]);

//					// output parameters stored under report id
//					foreach (var item in parms[rec["RPT_ID"]])
//					{
//						// do not replace any parameters already in record parameters
//						if (!rec.ContainsKey(item.Key)) rec.Add(item.Key, item.Value);
//					}

//					output_type = (rec.ContainsKey("OUTPUT_TYPE")) ? rec["OUTPUT_TYPE"] : "default";

//					// map page to format file if one is being used
//					if (rec.ContainsKey("FORMAT_FILE")) rec["FORMAT_FILE"] =
//						(System.Web.HttpContext.Current != null) ?
//							System.Web.HttpContext.Current.Server.MapPath("~/Formats/" + rec["FORMAT_FILE"]) :
//							System.Web.Hosting.HostingEnvironment.MapPath("~/Formats/" + rec["FORMAT_FILE"]);

//					//*********************************************************************************
//					// call selected routine to format the report
//					//*********************************************************************************
//					ABCWebUtils.DBLog.LogInformation("T", request["REPORT"], "FormatReport", null, "Formatting Report Data");
//					FormatData(ref rec, output_type, out fileName, out e);

//					if (e == null)
//					{
//						ABCWebUtils.DBLog.LogInformation("T", request["REPORT"], "FormatReport", null, "Saving Formated Report Data");

//						//*********************************************************************************
//						// add formated report data to rqs_report_data table
//						//*********************************************************************************
//						// open connection to database
//						m_conn.Open();
//						m_cmd.Parameters.Clear();		// make sure parameters are cleared for new request

//						m_cmd.CommandText = "ABCREPORTS.RQS_REPORTS.add_report";
//						m_cmd.Parameters.Add(new OracleParameter("p_request_id", OracleDbType.Varchar2, request_id.Length, request_id,
//														  System.Data.ParameterDirection.Input));
//						m_cmd.Parameters.Add(new OracleParameter("p_file_name", OracleDbType.Varchar2, (fileName == null ? 0 : fileName.Length), fileName,
//														  System.Data.ParameterDirection.Input));
//						m_cmd.Parameters.Add(new OracleParameter("p_data", OracleDbType.Blob, m_raw.Length, m_raw,
//														  System.Data.ParameterDirection.Input));
//						m_cmd.Parameters.Add(m_statusMsg);
//						m_cmd.ExecuteNonQuery();

//						m_conn.Close();

//						if (((INullable)m_statusMsg.Value).IsNull)
//						{
//							ABCWebUtils.DBLog.LogInformation("T", request["REPORT"], "FormatReport", null, "Report Completed");
//						}
//					}
//				}
//				else
//				{
//					ABCWebUtils.DBLog.LogInformation("E", request_id, "OraReports.FormatReport", "Error ", "No data returned for : " + request_id, e);
//				}
//			}

//			catch (Exception ex)
//			{
//				ex.Data["Failure"] = "Failure formatting report";
//				ex.Data["Function"] = "FormatReport";
//				ex.Data["RequestId"] = request_id;

//				e = ex;
//			}

//			return;
//		}

//		public virtual void FormatData(ref Dictionary<string, string> rec, string outputType, out string fileName,  out Exception e)
//		{
//			string		rptData;
//			Excel		excel;

//			e = null;
//			fileName = (rec.ContainsKey("FILE") ? rec["FILE"] : null);

//			//*********************************************************************************
//			// call selected routine to format the report
//			//*********************************************************************************
//			switch (outputType.ToLower())
//			{
//				case "html-print":
//				case "html":  // HTML formated output
//					rptData = ABCWebUtils.Translate.XMLtoHTML(ref rec, out e);
//					if ((rptData != null) && (e == null))
//					{
//						m_raw = Encoding.ASCII.GetBytes(rptData);
//					}
//					break;

//				case "excel":  // export as excell
//					fileName = "/Download/" + rec["REQUEST_ID"] + ".xlsx";

//					try
//					{
////						_pool.WaitOne(); 
//						excel = new Excel(rec["REQUEST_ID"]);
//						rptData = rec["RPT_RESULTS"];
//						m_raw = excel.CSVtoExcelData(ref rptData, rec, out e);
//						excel.Dispose();
//					}

//					catch (Exception ex) { e = ex; }
////					finally { _pool.Release(); }
//					break;

//				case "pdf":
//					m_raw = ABCWebUtils.Translate.XMLtoPDF(ref rec, out e);
//					break;

//				default:
//					if (rec.ContainsKey("RPT_RESULTS")) m_raw = Encoding.ASCII.GetBytes(rec["RPT_RESULTS"]);
//					break;
//			}

//			return;
//		}


		/// <summary>
		/// RetrieveReport Method retrieve report data 
		/// </summary>
		/// <param name="request">contains requested report id</param>
		/// <returns>JSON string with formatted/unformatted report data or an error message</returns>
//		public virtual Dictionary<string, string> RetrieveReport(Dictionary<string, string> request)
//		{
//			Dictionary<string, Dictionary<string, string>>	parms;
//			OracleParameter				parameters  = new OracleParameter("p_parameters", OracleDbType.Varchar2, 4000, 
//																		  null, System.Data.ParameterDirection.Output);
//			OracleParameter				data        = new OracleParameter("p_data", OracleDbType.Blob, 
//																		  System.Data.ParameterDirection.Output);
//			Dictionary<string, string>  info        = new Dictionary<string, string>();
//			Dictionary<string, string>  rec         = new Dictionary<string, string>();
//			Dictionary<string, string>  file        = new Dictionary<string, string>();
//			JavaScriptSerializer		jss		    = new JavaScriptSerializer();
//			string						output_type = null;
//			byte[]						rptData		= null;
//			string						request_id;
//			string						fileName;
//			Exception					e			= null;

//			try
//			{
//				request_id = request["REPORT"];

//				//*********************************************************************************
//				// Retrieve report data and parameters to output the report
//				//*********************************************************************************
//				m_cmd.Parameters.Clear();		// make sure parameters are cleared for new request

//				m_cmd.CommandText = "ABCREPORTS.RQS_REPORTS.get_report";
//				m_cmd.Parameters.Add(new OracleParameter("p_request_id", OracleDbType.Varchar2, request_id.Length, request_id,
//														  System.Data.ParameterDirection.Input));
//				m_cmd.Parameters.Add(data);
//				m_cmd.Parameters.Add(parameters);
//				m_cmd.Parameters.Add(m_statusMsg);

//				m_cmd.ExecuteNonQuery();

//				//*********************************************************************************
//				// process retrieve output parameters and get report data
//				//*********************************************************************************
//				if (((INullable)m_statusMsg.Value).IsNull)
//				{
//					parms = jss.Deserialize<Dictionary<string, Dictionary<string, string>>>(parameters.Value.ToString());

//					rec = parms[parms.Keys.ToList()[0]];
//					rec["SITE"] = request["SITE"];

//					output_type = (rec.ContainsKey("OUTPUT_TYPE")) ? rec["OUTPUT_TYPE"] : "default";
//					rptData = ((Oracle.DataAccess.Types.OracleBlob)(data.Value)).Value;
//				}

//				if (rptData != null)
//				{
//					//*********************************************************************************
//					// process report to be returned
//					//*********************************************************************************
//					switch (output_type.ToLower())
//					{
//						case "html-print":
//						case "html":  // HTML formated output
//							// convert byte array to string
//							file["file"] = System.Text.Encoding.Default.GetString(rptData);
//							break;

//						case "excel":  // excell
//							// ftp data to selected location
//							fileName = "/Download/" + request_id + ".xlsx";
//							if (ABCWebUtils.Support.UploadFile(rec["SITE"], fileName, rptData, out e))
//							{
//								file["file"] = fileName;
//							}

//							break;

//						default:
//							fileName = "/Download/" + request_id + ".pdf";
//							if (ABCWebUtils.Support.UploadFile(rec["SITE"], fileName, rptData, out e))
//							{
//								file["file"] = fileName;
//							}
//							// convert byte array to base 64 string
////							file["file"] = System.Convert.ToBase64String(rptData, 0, rptData.Length);
//							break;
//					}

//					if (e == null)
//					{
//						file["output_type"] = output_type;
//						jss.MaxJsonLength = Int32.MaxValue;
//						info["data"] = jss.Serialize(file);
//					}
//					else
//					{
//						info["err"] = ABCWebUtils.ProcessErrors.ProcessException(e, "Error Retrieve Report; " + e.Message);
//					}
//				}
//				else
//				{
//					if (((INullable)m_statusMsg.Value).IsNull)
//					{
//						info["err"] = "No Report Returned";
//					}
//					else
//					{
//						info["err"] = m_statusMsg.Value.ToString();
//					}
//				}
//			}

//			catch (Exception ex)
//			{
//				info = new Dictionary<string, string>();
//				info["err"] = ABCWebUtils.ProcessErrors.ProcessException(ex, "Error Retrieving Report; " + ex.Message);
//			}

//			return info; // jss.Serialize(info);
//		}

		//public virtual Boolean ExportReportDataFTP(Dictionary<string, string> request, out Exception e)
		//{
		//	Dictionary<string, Dictionary<string, string>>	parms;
		//	OracleParameter				parameters  = new OracleParameter("p_parameters", OracleDbType.Varchar2, 4000,
		//																  null, System.Data.ParameterDirection.Output);
		//	OracleParameter				fileName    = new OracleParameter("p_file_name", OracleDbType.Varchar2, 4000,
		//																  null, System.Data.ParameterDirection.Output);
		//	OracleParameter				data        = new OracleParameter("p_data", OracleDbType.Blob,
		//																  System.Data.ParameterDirection.Output);
		//	Dictionary<string, string>  info        = new Dictionary<string, string>();
		//	Dictionary<string, string>  rec         = new Dictionary<string, string>();
		//	Dictionary<string, string>  file        = new Dictionary<string, string>();
		//	JavaScriptSerializer		jss		    = new JavaScriptSerializer();
		//	byte[]						rptData		= null;
		//	string						request_id	= null;
		//	string						outFile		= null;

		//	e = null;

		//	try
		//	{
		//		request_id = request["REPORT"];

		//		//ABCWebUtils.ProcessErrors.LogMessage("ExportReportDataFTP", request_id, 3);

		//		//*********************************************************************************
		//		// Retrieve report data and parameters to output the report
		//		//*********************************************************************************
		//		m_cmd.Parameters.Clear();		// make sure parameters are cleared for new request

		//		m_cmd.CommandText = "ABCREPORTS.RQS_REPORTS.get_report_export";
		//		m_cmd.Parameters.Add(new OracleParameter("p_request_id", OracleDbType.Varchar2, request_id.Length, request_id,
		//												  System.Data.ParameterDirection.Input));
		//		m_cmd.Parameters.Add(data);
		//		m_cmd.Parameters.Add(parameters);
		//		m_cmd.Parameters.Add(fileName);
		//		m_cmd.Parameters.Add(m_statusMsg);
				
		//		m_cmd.ExecuteNonQuery();

		//		if (!((INullable)m_statusMsg.Value).IsNull)
		//		{
		//			throw new Exception("ExportReportDataFTP : Error Message -  (" + request_id + ") " + m_statusMsg.Value.ToString());
		//		}

		//		//*********************************************************************************
		//		// process retrieve output parameters and get report data
		//		//*********************************************************************************
		//		if (((INullable)parameters.Value).IsNull)
		//		{
		//			throw new Exception("ExportReportDataFTP: Report Parameters not returned(" + request_id + ")");
		//		}
				
		//		parms = jss.Deserialize<Dictionary<string, Dictionary<string, string>>>(parameters.Value.ToString());
		//		if (parms.Count == 0)
		//		{
		//			throw new Exception("ExportReportDataFTP: Report Parameters zero length(" + request_id + ")");
		//		}

		//		rec = parms[parms.Keys.ToList()[0]];
		//		rptData = ((Oracle.DataAccess.Types.OracleBlob)(data.Value)).Value;

		//		if (rptData.Length > 0)
		//		{
		//			// check to see if needs to be zipped before
		//			if (rec.ContainsKey("ZIP_DIRECTORY"))
		//			{
		//				rptData = ABCWebUtils.Support.ZipData(rec["ZIP_DIRECTORY"], rec["FILE"], rptData, out e);
		//				outFile = rec["ZIP_FILE"];
		//			}
		//			else
		//			{
		//				outFile = fileName.Value.ToString();
		//			}

		//			ABCWebUtils.DBLog.LogInformation("T", request_id, "ExportReportDataFTP", null, rec["SITE"] + " : " + outFile);
		//			ABCWebUtils.Support.UploadFile(rec["SITE"], outFile, rptData, out e);
		//		}
		//		else
		//		{
		//			if (((INullable)m_statusMsg.Value).IsNull)
		//			{
		//				e = new Exception("No Report Returned");
		//			}
		//			else
		//			{
		//				e = new Exception(m_statusMsg.Value.ToString());
		//			}

		//			ABCWebUtils.ProcessErrors.ProcessException(e, "ExportReportDataFTP", request_id, 1);
		//		}
		//	}

		//	catch (Exception ex)
		//	{
		//		e = ex;
		//		ABCWebUtils.ProcessErrors.ProcessException(e, "ExportReportDataFTP", request_id, 1);

		//	}

		//	return (e == null);
		//}



		//public virtual string StatusUpdate(string reportId, string status)
		//{
		//	Dictionary<string, string> info = new Dictionary<string, string>();

		//	try
		//	{
		//		m_cmd.CommandText = "ABCREPORTS.RQS_UTILS.status_update";
		//		m_cmd.Parameters.Add(new OracleParameter("p_report_id", OracleDbType.Varchar2, reportId.Length, reportId,
		//												  System.Data.ParameterDirection.Input));
		//		m_cmd.Parameters.Add(new OracleParameter("p_status", OracleDbType.Varchar2, 1, status,
		//												  System.Data.ParameterDirection.Input));
		//		m_cmd.Parameters.Add(m_retCode);
		//		m_cmd.Parameters.Add(m_statusMsg);

		//		m_cmd.ExecuteNonQuery();

		//		// check status indicator for errors
		//		if (!((INullable)m_retCode.Value).IsNull)
		//		{
		//			// return error message
		//			info["err"] = m_statusMsg.Value.ToString();
		//		}
		//		else
		//		{
		//			// return error message
		//			info["msg"] = m_statusMsg.Value.ToString();
		//		}
		//	}

		//	catch (Exception ex)
		//	{
		//		info["err"] = ABCWebUtils.ProcessErrors.ProcessException(ex, "Error finalizing report status(Status) " + ex.Message);
		//	}

		//	return (new JavaScriptSerializer()).Serialize(info); ;

		//}

		//public virtual string JobList(string user_id)
		//{
		//	List<Dictionary<string, string>> recs = new List<Dictionary<string, string>>();
		//	Dictionary<string, string> info = new Dictionary<string, string>();
		//	Dictionary<string, string> rec;
		//	OracleParameter cursor = new OracleParameter("p_data", OracleDbType.RefCursor, System.Data.ParameterDirection.Output);
		//	OracleDataReader reader;
		//	Int32 parms;

		//	try
		//	{
		//		parms = (user_id.Length == 0)? -1 : Convert.ToInt32(user_id);

		//		m_cmd.CommandText = "ABCREPORTS.rqs_utils.get_jobs";
		//		m_cmd.Parameters.Add(new OracleParameter("p_user_id", OracleDbType.Int32, 0, parms,
		//												  System.Data.ParameterDirection.Input));
		//		m_cmd.Parameters.Add(cursor);
		//		m_cmd.Parameters.Add(m_statusMsg);

		//		m_cmd.ExecuteNonQuery();

		//		reader = ((OracleRefCursor)cursor.Value).GetDataReader();
		//		while (reader.Read())
		//		{
		//			rec = new Dictionary<string, string>();

		//			for (Int32 index = 0; index < reader.FieldCount; index++)
		//			{
		//				object value = reader.GetValue(index);
		//				rec[reader.GetName(index)] = (value == DBNull.Value) ? "" : reader.GetValue(index).ToString();
		//			}

		//			recs.Add(rec);
		//		}

		//		reader.Close();

		//		info["data"] = (new JavaScriptSerializer()).Serialize(recs);
		//	}

		//	catch (Exception ex)
		//	{
		//		info["err"] = ABCWebUtils.ProcessErrors.ProcessException(ex, "Error getting job list: " + ex.Message +
		//			" system: " + System.Web.HttpContext.Current.ApplicationInstance.Request.Url.Host.ToLower());
		//	}

		//	return (new JavaScriptSerializer()).Serialize(info); ;
		//}


		//public virtual string UpdateJob(string jobName, string action)
		//{
		//	Dictionary<string, string> info = new Dictionary<string, string>();

		//	try
		//	{
		//		m_cmd.CommandText = "ABCREPORTS.RQS_UTILS.upd_job";
		//		m_cmd.Parameters.Add(new OracleParameter("p_job_id", OracleDbType.Varchar2, jobName.Length, jobName,
		//												  System.Data.ParameterDirection.Input));
		//		m_cmd.Parameters.Add(new OracleParameter("p_action", OracleDbType.Varchar2, 1, action,
		//												  System.Data.ParameterDirection.Input));
		//		m_cmd.Parameters.Add(m_retCode);
		//		m_cmd.Parameters.Add(m_statusMsg);

		//		m_cmd.ExecuteNonQuery();

		//		// check status indicator for errors
		//		if (!((INullable)m_retCode.Value).IsNull)
		//		{
		//			// return error message
		//			info["err"] = m_statusMsg.Value.ToString();
		//		}
		//		else
		//		{
		//			// return status message
		//			info["msg"] = m_statusMsg.Value.ToString();
		//		}
		//	}

		//	catch (Exception ex)
		//	{
		//		info["err"] = ABCWebUtils.ProcessErrors.ProcessException(ex, "Error in Job Update method(Status) " + ex.Message);
		//	}

		//	return (new JavaScriptSerializer()).Serialize(info); ;

		//}


		//public virtual string SendEmail(string fromAddr, string toAddr, string subject, string body, string fileName, byte[] data)
		//{
		//	string      msg = "OK";

		//	try
		//	{
		//		m_cmd.Parameters.Clear();

		//		m_cmd.CommandText = "ABCREPORTS.rqs_email.sendemail";
		//		m_cmd.Parameters.Add(new OracleParameter("p_fromAddress", OracleDbType.Varchar2, fromAddr.Length, fromAddr,
		//												  System.Data.ParameterDirection.Input));
		//		m_cmd.Parameters.Add(new OracleParameter("p_toAddress", OracleDbType.Varchar2, toAddr.Length, toAddr,
		//												  System.Data.ParameterDirection.Input));
		//		m_cmd.Parameters.Add(new OracleParameter("p_subject", OracleDbType.Varchar2, subject.Length, subject,
		//												  System.Data.ParameterDirection.Input));
		//		m_cmd.Parameters.Add(new OracleParameter("p_body", OracleDbType.Varchar2, body.Length, body,
		//												  System.Data.ParameterDirection.Input));
		//		m_cmd.Parameters.Add(new OracleParameter("p_file_name", OracleDbType.Varchar2, fileName.Length, fileName,
		//												  System.Data.ParameterDirection.Input));
		//		m_cmd.Parameters.Add(new OracleParameter("p_blob", OracleDbType.Blob, data.Length, data,
		//												  System.Data.ParameterDirection.Input));
		//		m_cmd.Parameters.Add(new OracleParameter("p_mimeType", OracleDbType.Varchar2, 30, "text/plain",
		//												  System.Data.ParameterDirection.Input));

		//		m_cmd.ExecuteNonQuery();


		//	}

		//	catch (Exception ex)
		//	{
		//		msg = ex.Message;
		//	}

		//	return msg;

		//}

    }
}

