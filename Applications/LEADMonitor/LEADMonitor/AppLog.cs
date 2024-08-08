using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;

using System.Threading;
using System.Threading.Tasks;

using System.Diagnostics;
using System.IO;
using System.ComponentModel;

using Oracle.DataAccess.Client;
using Oracle.DataAccess.Types;
using System.Configuration;

namespace LEADMonitor
{
	public class AppLog
	{
		public enum	MessageType	{ ERROR, WARNING, TRACE, INFORMATIONAL }

		private Configuration		m_config;
		AppSettingsSection			m_appSettings;
		Exception					m_e;
		MessageType					m_type;
		bool						m_email;
		EventLog					m_eventLog;

		static public void Write(Exception e, MessageType type, EventLog eventLog, Configuration config)
		{
			AppLog						logWorker;
			string						logging;
			bool						log			= false;

			try
			{
				AppSettingsSection			appSettings;

				// check to see if logging is enabled
				appSettings = (System.Configuration.AppSettingsSection) config.GetSection("appSettings");

				logging = appSettings.Settings["loggingtype"].Value;
				if (logging != null)
				{
					switch (logging.ToUpper())
					{
						case "E":
							log = (type == MessageType.ERROR);
							break;

						case "W":
							log = ((type == MessageType.ERROR) ||
								   (type == MessageType.WARNING));
							break;

						case "I":
							log = ((type == MessageType.ERROR) ||
								   (type == MessageType.WARNING) ||
								   (type == MessageType.INFORMATIONAL));
							break;

						case "T":
							log = true;
							break;

						default:
							log = false;
							break;
					}
				}

				if (log)
				{
					// create thread to perform the logging
					logWorker = new AppLog(e, type);
					logWorker.m_config		= config;
					logWorker.m_eventLog	= eventLog;
					logWorker.m_appSettings = appSettings;
					logWorker.Write();
				}
			}

			catch (Exception) 
			{  }
		}


		public AppLog(Exception ex, MessageType type)
		{
			m_e			= ex;
			m_type		= type;
		}

		protected void Write()
		{
			string					    buffer = "";

			try
			{
				m_email		= (m_appSettings.Settings["email"].Value == "Y");
				buffer = AddHeading(m_e);
				if (m_type == MessageType.ERROR && m_email) SendEmail(buffer);

				switch (m_type)
				{
					case MessageType.ERROR: m_eventLog.WriteEntry(buffer, EventLogEntryType.Error); break;
					case MessageType.WARNING: m_eventLog.WriteEntry(buffer, EventLogEntryType.Warning); break;
					case MessageType.INFORMATIONAL: m_eventLog.WriteEntry(buffer, EventLogEntryType.Information); break;
					case MessageType.TRACE: m_eventLog.WriteEntry(buffer, EventLogEntryType.Information); break;
				}
			}

			catch (Exception)
			{ }

			finally
			{
			}
		}

		private string AddHeading(Exception e)
		{
			string			exceptionMessage = FormatedMessage(e);
			string			header;
			string[]		message;

			// split message up for text wrapping and line breaks.
			message = exceptionMessage.Split("\r\n".ToCharArray(), StringSplitOptions.RemoveEmptyEntries);

			// formate message line with wrapping
			for (Int32 inx = 0; inx < message.Length; inx++)
			{
				header = ((inx == 0) ? DateTime.Now.ToString("dd HH:mm:ss") + " " + m_type : "");
				message[inx] = header.PadRight(24).Substring(0, 24) + message[inx];
			}

			return String.Join("\r\n", message) + "\r\n\r\n"; // buffer;
		}


		public static string FormatedMessage(Exception e)
		{
			string msg = null;

			if (e.InnerException != null)
			{
				msg += FormatedMessage(e.InnerException);
				msg += "".PadRight(105, '-') + "\r\n";
			}

			msg += FormatAttribute("Message", e.Message);
			msg += FormatAttribute("Source", e.Source);
			msg += FormatAttribute("StackTrace", e.StackTrace);

			foreach (string key in e.Data.Keys)
			{
				msg += FormatAttribute(key, e.Data[key].ToString());
			}

			if (e.TargetSite != null)
			{
				msg += FormatAttribute("Method", e.TargetSite.Name);
			}

			return msg;
		}

		public static string FormatAttribute(string key, string value)
		{
			string		line		= null;
			string		temp;
			int			lineLength	= 104;
			string[]	values;

			if (value == null) return "";
			if (value.Length <= 100)
			{
				line = (key + ":").PadRight(20).Substring(0, 20) + " " + value + "\r\n";
			}
			else
			{
				int		index;

				line = (key + ":").PadRight(20).Substring(0, 20) + " ";
				values = value.Split("\r\n".ToCharArray(), StringSplitOptions.RemoveEmptyEntries);

				for (Int32 inx = 0; inx < values.Length; inx++)
				{
					index = 0;
					temp = values[inx].Trim();
					
					if (inx > 0)
					{
						line += "".PadRight(21);
						lineLength = 104;
					}

					while (temp.Length > 0)
					{
						if (index > 0)
						{
							line += "".PadRight(25);
							lineLength = 100;
						}

						// look for break point in value
						index = (temp.Length > lineLength) ? temp.IndexOf(' ', lineLength - 10) : -1;
						if (index == -1)
						{
							index = (temp.Length > lineLength) ? lineLength : temp.Length;
						}

						if (index > lineLength) index = lineLength;
						line += temp.Substring(0, index) + "\r\n";
						temp = (temp.Length > lineLength) ? temp.Substring(index).TrimStart() : "";
					}
				}
			}

			return line;
		}

		protected void SendEmail(string buffer)
		{
			OracleCommand		cmd;
			OracleConnection	conn   = null;
			string				connectionString;
			OracleParameter		cursor = new OracleParameter("p_data", OracleDbType.RefCursor, System.Data.ParameterDirection.Output);
			int					retry  = 0;

			string				fromAddress = m_appSettings.Settings["from"].Value;
			string				toAddress   = m_appSettings.Settings["to"].Value;
			string				subject     = "LEAD Monitor Error";
			string				body		= buffer;

			try
			{
				// call tl package to delete record
				connectionString = Environment.GetEnvironmentVariable("connection", EnvironmentVariableTarget.Process);
				conn = new OracleConnection(connectionString); 
				cmd = new OracleCommand("SITESPECIFIC.PKG_TLEMAIL.SendEmail", conn);
				cmd.CommandType = System.Data.CommandType.StoredProcedure;

				// add parameters
				cmd.Parameters.Add(new OracleParameter("p_fromAddress", OracleDbType.Varchar2, fromAddress.Length, fromAddress, System.Data.ParameterDirection.Input));
				cmd.Parameters.Add(new OracleParameter("p_toAddress", OracleDbType.Varchar2, toAddress.Length, toAddress, System.Data.ParameterDirection.Input));
				cmd.Parameters.Add(new OracleParameter("p_subject", OracleDbType.Varchar2, subject.Length, subject, System.Data.ParameterDirection.Input));
				cmd.Parameters.Add(new OracleParameter("p_body", OracleDbType.Varchar2, body.Length, body, System.Data.ParameterDirection.Input));

				// allow three tries to open connection to database
				while ((retry < 3) && (conn.State != System.Data.ConnectionState.Open))
				{
					try
					{
						conn.Open();
					}

					catch (Exception ex)
					{
						if (retry == 0) AppLog.Write(ex, AppLog.MessageType.WARNING, m_eventLog, m_config);
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

				}
			}

			catch (Exception)
			{
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