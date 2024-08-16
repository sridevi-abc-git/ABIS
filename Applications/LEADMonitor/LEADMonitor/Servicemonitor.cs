using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Data;
using System.Diagnostics;
using System.Linq;
using System.ServiceProcess;
using System.Text;
using System.Threading.Tasks;

using System.Runtime.InteropServices;
using System.Configuration;

namespace LEADMonitor
{
	class ServiceMonitor : ServiceBase
	{
		[DllImport("advapi32.dll", SetLastError = true)]
		private static extern bool SetServiceStatus(IntPtr handle, ref ServiceStatus serviceStatus);

		private BackgroundWorker					m_worker = new BackgroundWorker();
		private System.Diagnostics.EventLog			m_eventLog;
		private bool								m_trace;
		private LEADProcMonitor						m_monitor;
		
		public ServiceMonitor()
		{
			AutoLog = false;
		}

		protected override void OnStart(string[] args)
		{
			ServiceStatus serviceStatus = new ServiceStatus();
			AppSettingsSection			appSettings;
			string						dataSource;

			try
			{
				dataSource  = Environment.GetEnvironmentVariable("DATA_SOURCE", EnvironmentVariableTarget.Machine);
				appSettings = Program.GetAppSettings(dataSource);
				m_eventLog  = Program.GetEventLog(appSettings);
				m_trace     = (appSettings.Settings["trace"].Value == "Y");

				Environment.SetEnvironmentVariable("CONNECTION",
													Program.GetConnectionString(appSettings, dataSource),
													EnvironmentVariableTarget.Process);

				m_eventLog.WriteEntry("Service starting: " + dataSource);

				Environment.SetEnvironmentVariable("DATA_SOURCE", dataSource, EnvironmentVariableTarget.Process);

				serviceStatus.dwCurrentState = ServiceState.SERVICE_START_PENDING;
				serviceStatus.dwWaitHint = 100000;
				SetServiceStatus(this.ServiceHandle, ref serviceStatus);

				m_monitor = new LEADProcMonitor(dataSource, m_eventLog, m_trace);
				m_worker.DoWork += new DoWorkEventHandler(m_monitor.start);
				m_worker.RunWorkerAsync();

				// Update the service state to Running.
				serviceStatus.dwCurrentState = ServiceState.SERVICE_RUNNING;
				SetServiceStatus(this.ServiceHandle, ref serviceStatus);
			}

			catch (Exception ex)
			{
				string msg = AppLog.FormatedMessage(ex);
				m_eventLog.WriteEntry(msg, System.Diagnostics.EventLogEntryType.Error, 1);

				serviceStatus.dwCurrentState = ServiceState.SERVICE_STOPPED;
				SetServiceStatus(this.ServiceHandle, ref serviceStatus);
			}
		}

		protected override void OnStop()
		{
			ServiceStatus serviceStatus = new ServiceStatus();
			serviceStatus.dwCurrentState = ServiceState.SERVICE_STOP_PENDING;
			serviceStatus.dwWaitHint = 10000;
			SetServiceStatus(this.ServiceHandle, ref serviceStatus);

			m_monitor.Stop();

			// Update the service state to Running.
			serviceStatus.dwCurrentState = ServiceState.SERVICE_STOPPED;
			SetServiceStatus(this.ServiceHandle, ref serviceStatus);

			m_eventLog.WriteEntry("Stopped.");

		}
	}
}
