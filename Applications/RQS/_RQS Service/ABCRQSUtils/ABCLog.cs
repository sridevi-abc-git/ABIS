using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

using System.Diagnostics;
using System.IO;
using System.ComponentModel;

using System.ServiceModel.Activation;
using Oracle.DataAccess.Client;
using Oracle.DataAccess.Types;


namespace ABCRQSUtils
{
	public class ABCLog
	{
		BackgroundWorker			m_worker	= new BackgroundWorker();
		Semaphore					m_sem;
		ABCException				m_e;
		AppConfigurationSettings	m_cnfg		= AppConfigurationSettings.getConfigurationSection();

		static public void Log(ABCException e)
		{
			ABCLog						logWorker;
			AppConfigurationSettings	cnfg		= AppConfigurationSettings.getConfigurationSection();
			string						logging;
			string[]					temp;
			bool						log			= false;

			try
			{
				// check to see if logging is enabled
				logging = cnfg.AppSettings["loggingtype"].value;
				if (logging != null)
				{
					temp = logging.Split(':');
					switch (temp[0].ToUpper())
					{
						case "E":
							log = (e.MsgType == ABCException.MessageType.ERROR);
							break;

						case "W":
							log = ((e.MsgType == ABCException.MessageType.ERROR) ||
								   (e.MsgType == ABCException.MessageType.WARNING));
							break;

						case "I":
							log = ((e.MsgType == ABCException.MessageType.ERROR) ||
								   (e.MsgType == ABCException.MessageType.WARNING) ||
								   (e.MsgType == ABCException.MessageType.INFORMATIONAL));
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
					logWorker = new ABCLog(e);

					logWorker.m_worker.DoWork += new DoWorkEventHandler(logWorker.Process);
					logWorker.m_worker.RunWorkerCompleted += new RunWorkerCompletedEventHandler(logWorker.ProcessCompleted);
					logWorker.m_worker.RunWorkerAsync();
				}
			}

			catch (Exception) { }
		}


		public ABCLog(ABCException ex)
		{
			// create semaphore for sequencing
			m_sem = new Semaphore(1, 1, m_cnfg.AppSettings["semaphore"].value);
			m_e = ex;
		}


		public void Process(object sender, DoWorkEventArgs ev)
		{
			string[]	logTypes;
			string[]	temp;

			temp = m_cnfg.AppSettings["loggingtype"].value.Split(':');

			// wait if another thread is logging
			m_sem.WaitOne();

			logTypes = temp[1].Split(',');
			foreach (string value in logTypes)
			{
				switch (value)
				{
					case "D": DBLog(); break;
					case "F": FileWrite(); break;
				}
			}

		}

		protected void DBLog()
		{
			OracleConnection	conn;
			OracleCommand		cmd;
			string				connectionString;

			connectionString = m_cnfg.AppSettings["loggingconnection"].value;
			if (connectionString == null) return;

			conn = new OracleConnection(connectionString);
			cmd = conn.CreateCommand();

			cmd.CommandText = "ABCREPORTS.RQS_UTILS.LOG";
			cmd.CommandType = System.Data.CommandType.StoredProcedure;
			conn.Open();
			DBLog(cmd, m_e);
			conn.Close();
		}
	
		protected void DBLog(OracleCommand cmd, ABCException e)
		{
			
			string				messageType		= "U";
			string				data			= null;

			if (e.InnerException != null) DBLog(cmd, e.InnerException);

			try
			{
				// process other data from exception
				foreach (var key in e.Data.Keys)
				{
					data += FormatLine(key, e.Data[key]);
				}

				// process message type
				switch (e.MsgType)
				{
					case ABCException.MessageType.ERROR: messageType = "E"; break;
					case ABCException.MessageType.INFORMATIONAL: messageType = "I"; break;
					case ABCException.MessageType.TRACE: messageType = "T"; break;
					case ABCException.MessageType.WARNING: messageType = "W"; break;
				}

				cmd.Parameters.Clear();
				cmd.Parameters.Add(new OracleParameter("p_log_type", OracleDbType.Varchar2,
														 messageType.Length, messageType,
														 System.Data.ParameterDirection.Input));

				cmd.Parameters.Add(new OracleParameter("p_job_id", OracleDbType.Varchar2,
														 0, null,
														 System.Data.ParameterDirection.Input));

				cmd.Parameters.Add(new OracleParameter("p_seq", OracleDbType.Varchar2,
														 e.Sequence.Length, e.Sequence,
														 System.Data.ParameterDirection.Input));
				cmd.Parameters.Add(new OracleParameter("p_source", OracleDbType.Varchar2,
														 (e.Source == null ? 0 : e.Source.Length), e.Source,
														 System.Data.ParameterDirection.Input));
				cmd.Parameters.Add(new OracleParameter("p_msg", OracleDbType.Varchar2,
														 (e.Message == null ? 0 : e.Message.Length), e.Message,
														 System.Data.ParameterDirection.Input));
				cmd.Parameters.Add(new OracleParameter("p_additional_data", OracleDbType.Varchar2,
														 (data == null ? 0 : data.Length), data,
														 System.Data.ParameterDirection.Input));
				cmd.Parameters.Add(new OracleParameter("p_error_trace", OracleDbType.Varchar2,
														 (e.StackTrace == null ? 0 : e.StackTrace.Length), e.StackTrace,
														 System.Data.ParameterDirection.Input));
				cmd.ExecuteNonQuery();
			}

			catch (Exception) {}

			finally
			{
			}

		}

		private void FileWrite()
		{
			System.IO.FileStream		fs = null;
			string					    buffer = "";
			string						logFile;

			try
			{
				logFile = Util.MapPath("~/Logging/",  DateTime.Now.ToString(@"yyMMdd") + ".txt");

				fs = System.IO.File.Open(logFile, System.IO.FileMode.Append);
				buffer = AddHeading(m_e);
				fs.Write(Encoding.ASCII.GetBytes(buffer), 0, buffer.Length);
			}

			catch (Exception) { }

			finally
			{
				if (fs != null) fs.Close();
				//_FilePool.Release();
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


		private string AddHeading(ABCException e)
		{
			string			exceptionMessage = e.FormatedMessage(ABCException.FormatMsg.TEXT);
			string			header;
			string			sequence		 = (e.Sequence == null ? "#".PadRight(10) : e.Sequence.PadRight(10));
			string[]		message;
			string			messageType		 = null;

			switch (e.MsgType)
			{
				case ABCException.MessageType.ERROR: messageType = "E"; break;
				case ABCException.MessageType.INFORMATIONAL: messageType = "I"; break;
				case ABCException.MessageType.TRACE: messageType = "T"; break;
				case ABCException.MessageType.WARNING: messageType = "W"; break;
			}

			// split message up for text wrapping and line breaks.
			message = exceptionMessage.Split("\r\n".ToCharArray(), StringSplitOptions.RemoveEmptyEntries);

			// formate message line with wrapping
			for (Int32 inx = 0; inx < message.Length; inx++)
			{
				header = ((inx == 0) ? DateTime.Now.ToString("dd HH:mm:ss") + " " + sequence + messageType : "");
				message[inx] = header.PadRight(24).Substring(0, 24) + message[inx];
			}

			return String.Join("\r\n", message) + "\r\n\r\n"; // buffer;
		}
	}

	
}
