//*****************************************************************************
//	File:		Controllers\User.cs
//	Author:		Timothy J. Lord
//
//	Description:
//
// $Rev: 51 $  
// $Date: 2018-09-01 12:02:56 -0700 (Sat, 01 Sep 2018) $
// Last Changed By:  $Author: TLord $
//
//*****************************************************************************
//	04/16/2015	  6197 - Initial file created.
//*****************************************************************************
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

using Oracle.DataAccess.Client;
using Oracle.DataAccess.Types;
using System.Web.Script.Serialization;
using System.Xml;

namespace RQS.Common
{
	class User : ABCRQSUtils.OraBase
	{
        public User() : base() {}
        public User(string connectionString) : base(connectionString) {}

		public string UserInfo(string data)
		{
			OracleParameter						results;
			JavaScriptSerializer                jss = new JavaScriptSerializer();
			Dictionary<string, string>          info = new Dictionary<string, string>();
			RptParameters						parameters;
			string								connection = null;
			string								user;
			ABCRQSUtils.ABCException			e;

			results	   = new OracleParameter("p_data", OracleDbType.Varchar2, 4000, null, System.Data.ParameterDirection.Output);
			parameters = new RptParameters(data);
			user       = parameters.value("USER");

            if (base.m_conn.ConnectionString.Length == 0)
            {
                connection = ABCRQSUtils.Util.Encrypt("user id=" + user +
                                                      ";password=" + parameters.value("PASSWORD") +
                                                      ";data source=" + parameters.value("TNSNAME"));
            }
            else
            {
                connection = ABCRQSUtils.Util.Encrypt(m_conn.ConnectionString);
            }

			// check if user is still active and get unique id for user id
			m_cmd.CommandText = "rqs_utils.userinfo";
			m_cmd.Parameters.Add(new OracleParameter("p_user_id", OracleDbType.Varchar2, user.Length, user,
														System.Data.ParameterDirection.Input));
			m_cmd.Parameters.Add(new OracleParameter("p_connection", OracleDbType.Varchar2, connection.Length, connection,
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

		public string Search(string data)
		{
            List<Dictionary<string, string>> recs = new List<Dictionary<string, string>>();
            Dictionary<string, string> info = new Dictionary<string, string>();
            Dictionary<string, string> rec;
            OracleParameter cursor = new OracleParameter("p_data", OracleDbType.RefCursor, System.Data.ParameterDirection.Output);
            OracleDataReader reader;
			RptParameters						parameters = null;
			string								connection;
			string								xmlData;

            try
            {
				parameters = new RptParameters(data);
				connection = parameters.value("CONNECTION");
				xmlData = parameters.getXML();

				m_cmd.CommandText = "rqs_utils.search";
				m_cmd.Parameters.Add(new OracleParameter("p_search", OracleDbType.XmlType, xmlData.Length, xmlData,
                                                          System.Data.ParameterDirection.Input));
                m_cmd.Parameters.Add(cursor);
                m_cmd.Parameters.Add(m_statusMsg);

				Open(connection);
                m_cmd.ExecuteNonQuery();

				if (((INullable)m_statusMsg.Value).IsNull)
				{
					reader = ((OracleRefCursor)cursor.Value).GetDataReader();
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

					info["data"] = (new JavaScriptSerializer()).Serialize(recs);
				}
				else
				{
					info["err"] = m_statusMsg.Value.ToString();
				}
			}

            catch (Exception ex)
            {
				//ABCWebUtils.DBLog.LogInformation("E", null, "Controllers.User", null, null, ex);

				info["err"] = new ABCRQSUtils.ABCException(parameters.value("SEQ"), ex).FormatedMessage() //ABCWebUtils.ProcessErrors.ProcessException(ex, "Error getting report list: " + ex.Message +
							+ " system: " + System.Web.HttpContext.Current.ApplicationInstance.Request.Url.Host.ToLower();
            }

            return (new JavaScriptSerializer()).Serialize(info); ;
        }

		public string AvailableReports(string data)
		{
			List<Dictionary<string, string>> recs = new List<Dictionary<string, string>>();
			Dictionary<string, string> info = new Dictionary<string, string>();
			Dictionary<string, string> rec;
			OracleParameter cursor = new OracleParameter("p_data", OracleDbType.RefCursor, System.Data.ParameterDirection.Output);
			OracleDataReader reader;
			RptParameters						parameters;

			try
			{
				parameters = new RptParameters(data);
				m_cmd.Parameters.Clear();

				m_cmd.CommandText = "rqs_utils.available_reports";
				m_cmd.Parameters.Add(new OracleParameter("p_userobjectid", OracleDbType.Int32, 0, Convert.ToInt32(parameters.value("USEROBJECTID")),
														  System.Data.ParameterDirection.Input));
				m_cmd.Parameters.Add(cursor);
				m_cmd.Parameters.Add(m_statusMsg);

				Open(parameters.value("CONNECTION"));
				m_cmd.ExecuteNonQuery();

				reader = ((OracleRefCursor)cursor.Value).GetDataReader();
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

				info["data"] = (new JavaScriptSerializer()).Serialize(recs);
			}

			catch (Exception ex)
			{
				//ABCWebUtils.DBLog.LogInformation("E", null, "Controllers.User", null, null, ex);

				info["err"] = new ABCRQSUtils.ABCException(null, ex).FormatedMessage() // ABCWebUtils.ProcessErrors.ProcessException(ex, "Error getting report list: " + ex.Message +
							+ " system: " + System.Web.HttpContext.Current.ApplicationInstance.Request.Url.Host.ToLower();
			}

			return (new JavaScriptSerializer()).Serialize(info); ;
		}

		public string Update(string data)
		{
			Dictionary<string, string> info = new Dictionary<string, string>();
			RptParameters						parameters;
			string reportList;

			try
			{
				parameters = new RptParameters(data);
				reportList = parameters.value("REPORTS");
				m_cmd.Parameters.Clear();

				m_cmd.CommandText = "rqs_utils.upduser";
				m_cmd.Parameters.Add(new OracleParameter("p_user_id", OracleDbType.Int32, 0, Convert.ToInt32(parameters.value("USEROBJECTID")),
														  System.Data.ParameterDirection.Input));
				m_cmd.Parameters.Add(new OracleParameter("p_user_role", OracleDbType.Varchar2, 1, parameters.value("USER_ROLE"),
														  System.Data.ParameterDirection.Input));
				m_cmd.Parameters.Add(new OracleParameter("p_report_list", OracleDbType.XmlType, reportList.Length, reportList,
														  System.Data.ParameterDirection.Input));
				m_cmd.Parameters.Add(m_statusMsg);
				m_cmd.Parameters.Add(m_retCode);

				Open(parameters.value("CONNECTION"));
				m_cmd.ExecuteNonQuery();

				if (((INullable)m_retCode.Value).IsNull)
				{
					info["msg"] = m_statusMsg.Value.ToString();
				}
				else
				{
					info["err"] = m_statusMsg.Value.ToString();
				}
				 
			}

			catch (Exception ex)
			{
				//ABCWebUtils.DBLog.LogInformation("E", null, "Controllers.User", null, null, ex);

				info["err"] = new ABCRQSUtils.ABCException(null, ex).FormatedMessage() //ABCWebUtils.ProcessErrors.ProcessException(ex, "Error getting report list: " + ex.Message +
							+ " system: " + System.Web.HttpContext.Current.ApplicationInstance.Request.Url.Host.ToLower();
			}

			return (new JavaScriptSerializer()).Serialize(info); ;
		}

		public string RequestLogs(string data)
		{
			List<Dictionary<string, string>> recs = new List<Dictionary<string, string>>();
			Dictionary<string, string> info = new Dictionary<string, string>();
			Dictionary<string, string> rec;
			OracleParameter cursor = new OracleParameter("p_data", OracleDbType.RefCursor, System.Data.ParameterDirection.Output);
			OracleDataReader reader;

			try
			{
				if (data.Length == 0) data = "na";

				m_cmd.CommandText = "ABCREPORTS.rqs_user.request_logs";
				m_cmd.Parameters.Add(new OracleParameter("p_search", OracleDbType.XmlType, data.Length, data,
														  System.Data.ParameterDirection.Input));
				m_cmd.Parameters.Add(cursor);
				m_cmd.Parameters.Add(m_statusMsg);

				m_cmd.ExecuteNonQuery();


				if (((INullable)m_statusMsg.Value).IsNull)
				{
					reader = ((OracleRefCursor)cursor.Value).GetDataReader();
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

					info["data"] = (new JavaScriptSerializer()).Serialize(recs);
				}
				else
				{
					info["err"] = m_statusMsg.Value.ToString();
				}
			}

			catch (Exception ex)
			{
				//ABCWebUtils.DBLog.LogInformation("E", null, "Controllers.User", null, null, ex);

				info["err"] = new ABCRQSUtils.ABCException(null, ex).FormatedMessage() //ABCWebUtils.ProcessErrors.ProcessException(ex, "Error getting request logs: " + ex.Message +
							+ " system: " + System.Web.HttpContext.Current.ApplicationInstance.Request.Url.Host.ToLower();
			}

			return (new JavaScriptSerializer()).Serialize(info); ;
		}

		
	}
}
