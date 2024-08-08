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

namespace LEADMaintenance.Utils
{
	public class AppLog
	{
		public enum MessageType { ERROR, WARNING, TRACE, INFORMATIONAL }

		BackgroundWorker			m_worker	= new BackgroundWorker();
		Semaphore					m_sem;
		Exception					m_e;
		MessageType					m_type;
		bool						m_email;

		static public void Write(Exception e, MessageType type)
		{
			AppLog						logWorker;
			string						logging;
			bool						log			= false;

			try
			{
				// check to see if logging is enabled
				logging = System.Configuration.ConfigurationManager.AppSettings["loggingtype"];
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

					logWorker.Process(null, null);
					//logWorker.m_worker.DoWork += new DoWorkEventHandler(logWorker.Process);
					//logWorker.m_worker.RunWorkerCompleted += new RunWorkerCompletedEventHandler(logWorker.ProcessCompleted);
					//logWorker.m_worker.RunWorkerAsync();
				}
			}

			catch (Exception)
			{ }
		}


		public AppLog(Exception ex, MessageType type)
		{
			// create semaphore for sequencing
			m_sem = new Semaphore(1, 1, System.Configuration.ConfigurationManager.AppSettings["semaphore"]);
			m_e = ex;
			m_type = type;
			m_email = (System.Configuration.ConfigurationManager.AppSettings["email"] == "Y");
		}

		public void Process(object sender, DoWorkEventArgs ev)
		{
			FileWrite();
		}

		protected void FileWrite()
		{
			System.IO.FileStream		fs = null;
			string					    buffer = "";
			string						logFile;

			try
			{
				logFile = System.Web.Hosting.HostingEnvironment.MapPath("~/Logging/") + DateTime.Now.ToString(@"yyMMdd") + ".txt";

				buffer = AddHeading(m_e);
				if (m_type == MessageType.ERROR && m_email) SendEmail(buffer);

				// wait if another thread is logging
				m_sem.WaitOne();

				fs = System.IO.File.Open(logFile, System.IO.FileMode.Append);
				fs.Write(System.Text.Encoding.ASCII.GetBytes(buffer), 0, buffer.Length);
			}

			catch (Exception)
			{ }

			finally
			{
				if (fs != null) fs.Close();
				m_sem.Release();

			}
		}



		protected void ProcessCompleted(object sender, RunWorkerCompletedEventArgs e)
		{
			if (e.Error != null)
			{
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

			}
			else    // Finally, handle the case where the operation succeeded.
			{

			}

			// release sequence lock
			m_sem.Release();
		}


		private string FormatLine(string key, string value)
		{
			string line		= null;
			string temp;

			if (value == null) return "";
			if (value.Length <= 80)
			{
				line = (key + ":").PadRight(20).Substring(0, 20) + "  " + value + "\r\n";
			}
			else
			{
				int		index = 0;

				temp = value.Trim();

				line = (key + ":").PadRight(20).Substring(0, 20) + " ";
				while (temp.Length > 0)
				{
					if (index > 0) line += "".PadRight(25);

					// look for break point in value
					index = (temp.Length > 80) ? temp.IndexOf(' ', 70) : -1;
					if (index == -1)
					{
						index = (temp.Length > 80) ? 80 : temp.Length;
					}

					if (index > 80) index = 80;
					line += temp.Substring(0, index) + "\r\n";
					temp = (temp.Length > 80) ? temp.Substring(index + 1) : "";
				}
			}

			return line;
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

			string				fromAddress = System.Configuration.ConfigurationManager.AppSettings["from"];
			string				toAddress   = System.Configuration.ConfigurationManager.AppSettings["to"];
			string				subject     = "Lead Student Registration Error";
			string				body		= buffer;

			try
			{
				// call tl package to delete record
				connectionString = System.Configuration.ConfigurationManager.ConnectionStrings["LEAD"].ConnectionString;
				conn = new OracleConnection(connectionString); // Util.Decrypt(connectionString));
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
						if (retry == 0) AppLog.Write(ex, AppLog.MessageType.ERROR);
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