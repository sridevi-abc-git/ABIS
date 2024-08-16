using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

using System.ComponentModel;
using System.Configuration;
using System.ServiceProcess;
using Oracle.DataAccess.Client;
using Oracle.DataAccess.Types;

namespace LEADMonitor
{
	class LEADProcMonitor
	{
		private Configuration					m_config;
		private AppSettingsSection				m_appSettings;
		private ServiceController				m_controller;
		private bool							m_check			  = true;
		private AutoResetEvent					m_waitHandle;
		private System.Diagnostics.EventLog		m_eventLog;
		private int								m_currentLogKey   = 0;
		private Int32							m_previousLogKey  = 0;

		public LEADProcMonitor(string dataSource, System.Diagnostics.EventLog eventLog, bool trace)
		{
			ExeConfigurationFileMap configMap = new ExeConfigurationFileMap();
			string					path	  = AppDomain.CurrentDomain.BaseDirectory;
			string					service;

			configMap.ExeConfigFilename = path + @"\" + dataSource + ".config";
			m_config = ConfigurationManager.OpenMappedExeConfiguration(configMap, ConfigurationUserLevel.None);
			m_appSettings = (System.Configuration.AppSettingsSection)m_config.GetSection("appSettings");
			
			service = m_appSettings.Settings["service"].Value;

			m_controller = new ServiceController(service);
			m_waitHandle = new AutoResetEvent(false);
			m_eventLog = eventLog;
		}

		public void start(object sender, DoWorkEventArgs e)
		{
			int		waitTime;

			if (!int.TryParse(m_appSettings.Settings["wait-time"].Value, out waitTime)) waitTime = 15;
			waitTime *= 60000; // set wait to minutes

			Console.WriteLine("Checking Started.  Check interval " + (waitTime / 60000).ToString("##0.00") + " Minutes");
			AppLog.Write(new Exception("Checking Started.  Check interval " + (waitTime / 60000).ToString("##0.00") + " Minutes"), 
						 AppLog.MessageType.INFORMATIONAL, 
						 m_eventLog, 
						 m_config);

			while (m_check)
			{
				try
				{
					{
						Console.WriteLine("Calling Service Check");
						AppLog.Write(new Exception("Calling Service Check"), 
									 AppLog.MessageType.TRACE, 
									 m_eventLog, 
									 m_config);
						Check();
						CheckForErrors();
						m_waitHandle.WaitOne(waitTime);
					}

				}

				catch (Exception ex)
				{
					AppLog.Write(ex, AppLog.MessageType.ERROR, m_eventLog, m_config);
					Console.WriteLine(ex.Message);
					m_waitHandle.WaitOne(waitTime);

				}
			}

			AppLog.Write(new Exception("Lead Monitor Service Stopping"),
						 AppLog.MessageType.INFORMATIONAL,
						 m_eventLog,
						 m_config);

		}

		public void Stop()
		{
			m_check = false;
			m_waitHandle.Set();
		}

		protected void Check()
		{
			OracleCommand		cmd;
			OracleConnection	conn				 = null;
			string				connectionString;
			OracleParameter		logKey				 = new OracleParameter("p_schedulelogkey", OracleDbType.Int32, System.Data.ParameterDirection.Output);
			OracleParameter		resultCode			 = new OracleParameter("p_code", OracleDbType.Int32, System.Data.ParameterDirection.Output);
			OracleParameter		results				 = new OracleParameter("p_message", OracleDbType.Varchar2, 8000, null, System.Data.ParameterDirection.Output);
			int					retry				 = 0;
			int					limit;
			int?				scheduleKey			 = null;

			try
			{
				Console.WriteLine("Checking Service");
				AppLog.Write(new Exception("Checking Service"),
							 AppLog.MessageType.TRACE,
							 m_eventLog,
							 m_config);
				if (!int.TryParse(m_appSettings.Settings["time-out"].Value, out limit)) limit = 15;

				connectionString = Environment.GetEnvironmentVariable("connection", EnvironmentVariableTarget.Process);
				conn = new OracleConnection(connectionString);
				cmd = new OracleCommand("ABC.TL_LEADCHECK", conn);
				cmd.CommandType = System.Data.CommandType.StoredProcedure;

				// add parameters
				cmd.Parameters.Add(new OracleParameter("p_limit", OracleDbType.Int32, 0, limit, System.Data.ParameterDirection.Input));
				cmd.Parameters.Add(logKey);
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
						if (retry == 0) AppLog.Write(ex, AppLog.MessageType.ERROR, m_eventLog, m_config);
					}

					finally
					{
						if (conn.State != System.Data.ConnectionState.Open)
						{
							retry++;

							// wait one second before trying again
							System.Threading.Thread.Sleep(100);
						}
					}
				}

				if (conn.State == System.Data.ConnectionState.Open)
				{
					cmd.ExecuteNonQuery();

					conn.Close();
					Console.WriteLine("Check Completed");

					// check for message
					if (((INullable) results.Value).IsNull)
					{
						m_previousLogKey = m_currentLogKey;
						m_currentLogKey = Convert.ToInt32(((Oracle.DataAccess.Types.OracleDecimal)(logKey.Value)).Value);

						// no error
						if (!((INullable) resultCode.Value).IsNull)
						{
							Exception		ex;

							scheduleKey = Convert.ToInt32(((Oracle.DataAccess.Types.OracleDecimal)(resultCode.Value)).Value);

							StopService();
//							RescheduleProcess(scheduleKey);
							if (StartService())
							{
								ex = new Exception("Lead Process Service was restarted");
								AppLog.Write(ex, AppLog.MessageType.ERROR, m_eventLog, m_config);
								Console.WriteLine(ex.Message);
							}
						}
					}
					else
					{
						Exception		ex = new Exception(results.Value.ToString());

						AppLog.Write(ex, AppLog.MessageType.ERROR, m_eventLog, m_config);
					}
				}

				AppLog.Write(new Exception("Checking Service Complete. Logkey Current - Previous : " + m_currentLogKey.ToString() + " - " + m_previousLogKey.ToString()),
							 AppLog.MessageType.TRACE,
							 m_eventLog,
							 m_config);

			}

			catch (OracleException ex)
			{
				AppLog.Write(ex, AppLog.MessageType.ERROR, m_eventLog, m_config);
			}

			catch (Exception ex)
			{
				AppLog.Write(ex, AppLog.MessageType.ERROR, m_eventLog, m_config);
			}

			finally
			{
				if (conn != null)
				{
					if (conn.State == System.Data.ConnectionState.Open) conn.Close();
				}
			}
		}
	

		protected void CheckForErrors()
		{
			OracleCommand		cmd;
			OracleConnection	conn   = null;
			string				connectionString;
			OracleParameter		cursor = new OracleParameter("p_errorlist", OracleDbType.RefCursor, System.Data.ParameterDirection.Output);
			OracleDataReader	reader = null;
			int					retry  = 0;
			int					scheduleKey;
			string				errorText;
			string				studentName;
			string				emailAddress;
			int					cnt		= 0;

			try
			{
				if (m_previousLogKey == 0) m_previousLogKey = m_currentLogKey; 

				AppLog.Write(new Exception("Checking for Errors. Logkey Current - Previous : " + m_currentLogKey.ToString() + " - " + m_previousLogKey.ToString()),
							 AppLog.MessageType.TRACE,
							 m_eventLog,
							 m_config);

				connectionString = Environment.GetEnvironmentVariable("connection", EnvironmentVariableTarget.Process); 
				conn = new OracleConnection(connectionString); // Util.Decrypt(connectionString));
				cmd = new OracleCommand("ABC.TL_CERTERRORCHECK", conn);
				cmd.CommandType = System.Data.CommandType.StoredProcedure;

				// add parameters
				cmd.Parameters.Add(new OracleParameter("p_schedulelogkey", OracleDbType.Int32, 0, m_previousLogKey, System.Data.ParameterDirection.Input));
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
						if (retry == 0) AppLog.Write(ex, AppLog.MessageType.ERROR, m_eventLog, m_config);
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

					if (!((Oracle.DataAccess.Types.OracleRefCursor)(cursor.Value)).IsNull)
					{
						reader = ((OracleRefCursor)cursor.Value).GetDataReader();
						while (reader.Read())
						{
							cnt++;
							scheduleKey   = Convert.ToInt32(reader.GetDecimal(reader.GetOrdinal("SCHEDULEKEY")));
							errorText     = reader.GetValue(reader.GetOrdinal("ERRORTEXT")).ToString();
							studentName   = reader.GetString(reader.GetOrdinal("STUDENTNAME"));
							emailAddress  = reader.GetString(reader.GetOrdinal("EMAILADDRESS"));

							if (RescheduleProcess(scheduleKey))
							{
								AppLog.Write(new Exception("Rescheduled: " + scheduleKey + "\nName: " + studentName +
														   "\nEmail: " + emailAddress), 
											 AppLog.MessageType.ERROR, 
											 m_eventLog, 
											 m_config);
							}
						}

						AppLog.Write(new Exception("Checking for errors, proceess completed. Count: " + cnt.ToString()),
									 AppLog.MessageType.TRACE,
									 m_eventLog,
									 m_config);

						reader.Close();
						reader = null;
					}
					else
					AppLog.Write(new Exception("Checking for Errors cursor null"),
								 AppLog.MessageType.TRACE,
								 m_eventLog,
								 m_config);

					conn.Close();

				}
			}

			catch (OracleException ex)
			{
				AppLog.Write(ex, AppLog.MessageType.ERROR, m_eventLog, m_config);
			}

			catch (Exception ex)
			{
				AppLog.Write(ex, AppLog.MessageType.ERROR, m_eventLog, m_config);
			}

			finally
			{
				if (conn != null)
				{
					if (conn.State == System.Data.ConnectionState.Open) conn.Close();
				}
			}

		}

		protected bool RescheduleProcess(int? scheduleKey)
		{
			OracleCommand		cmd;
			OracleConnection	conn				 = null;
			string				connectionString;
			OracleParameter		resultCode			 = new OracleParameter("p_code", OracleDbType.Int32, System.Data.ParameterDirection.Output);
			OracleParameter		results				 = new OracleParameter("p_message", OracleDbType.Varchar2, 8000, null, System.Data.ParameterDirection.Output);
			int					retry				 = 0;
			bool				rescheduled          = false;

			try
			{
				connectionString = Environment.GetEnvironmentVariable("connection", EnvironmentVariableTarget.Process); 
				conn = new OracleConnection(connectionString);
				cmd = new OracleCommand("ABC.TL_RESCHEDULE", conn);
				cmd.CommandType = System.Data.CommandType.StoredProcedure;

				// add parameters
				cmd.Parameters.Add(new OracleParameter("p_schedulekey", OracleDbType.Int32, 0, scheduleKey, System.Data.ParameterDirection.Input));
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
						if (retry == 0) AppLog.Write(ex, AppLog.MessageType.ERROR, m_eventLog, m_config);
					}

					finally
					{
						if (conn.State != System.Data.ConnectionState.Open)
						{
							retry++;

							// wait one second before trying again
							System.Threading.Thread.Sleep(100);
						}
					}
				}

				if (conn.State == System.Data.ConnectionState.Open)
				{
					cmd.ExecuteNonQuery();

					conn.Close();
					rescheduled = true;

					// check for message
					if (((INullable) results.Value).IsNull)
					{
						// no error
						//AppLog.Write(new Exception("Process " + scheduleKey + " Rescheduled"), 
						//			 AppLog.MessageType.INFORMATIONAL, m_eventLog, m_config);
					}
					else
					{
						AppLog.Write(new Exception(results.Value.ToString()), AppLog.MessageType.ERROR, m_eventLog, m_config);
					}
				}
			}

			catch (OracleException ex)
			{
				AppLog.Write(ex, AppLog.MessageType.ERROR, m_eventLog, m_config);
			}

			catch (Exception ex)
			{
				AppLog.Write(ex, AppLog.MessageType.ERROR, m_eventLog, m_config);
			}

			finally
			{
				if (conn != null)
				{
					if (conn.State == System.Data.ConnectionState.Open) conn.Close();
				}
			}

			return rescheduled;
		}

		protected void StopService()
		{

			try
			{
				Console.WriteLine("Stopping Service");

				if ((m_controller.Status.Equals(ServiceControllerStatus.Running)) || (m_controller.Status.Equals(ServiceControllerStatus.StartPending)))
				{
					m_controller.Stop();
				}
				m_controller.WaitForStatus(ServiceControllerStatus.Stopped);

				AppLog.Write(new Exception("Service " + m_controller.ServiceName + " Stopped"),
							 AppLog.MessageType.INFORMATIONAL, m_eventLog, m_config);

			}
			catch (Exception ex)
			{
				AppLog.Write(ex, AppLog.MessageType.ERROR, m_eventLog, m_config);
				Console.WriteLine(ex.Message);
			}

		}

		protected bool StartService()
		{
			bool	started = false;

			try
			{
				Console.WriteLine("Starting Service");

				m_controller.Start();
				m_controller.WaitForStatus(ServiceControllerStatus.Running);

				AppLog.Write(new Exception("Service " + m_controller.ServiceName + " Restarted"),
							 AppLog.MessageType.INFORMATIONAL, m_eventLog, m_config);
				started = true;
			}
			catch (Exception ex)
			{
				AppLog.Write(ex, AppLog.MessageType.ERROR, m_eventLog, m_config);
				Console.WriteLine(ex.Message);
			}

			return started;
		}
	}
}
