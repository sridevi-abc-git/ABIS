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
using ABCSockets;
using System.Configuration;
using Microsoft.Win32;
using System.Management;
using System.Management.Instrumentation;

namespace RQSService
{
	class ServiceMonitor : ServiceBase
	{
		[DllImport("advapi32.dll", SetLastError = true)]
		private static extern bool SetServiceStatus(IntPtr handle, ref ABCSockets.ServiceStatus serviceStatus);

		private ABCSockets.AsyncSocketListener		m_listener	= null;
		private BackgroundWorker					m_worker	= new BackgroundWorker();
		private System.Diagnostics.EventLog			m_eventLog;
		private bool								m_trace;
		private string								m_name;

		public ServiceMonitor()
		{
			int							processId;

			m_eventLog           = new System.Diagnostics.EventLog();
			m_eventLog.Source    = ConfigurationManager.AppSettings["log source"];
			m_eventLog.Log       = ConfigurationManager.AppSettings["log"];
			m_trace              = (ConfigurationManager.AppSettings["trace"] == "Y");
			CanPauseAndContinue  = true;
			AutoLog              = false;

			processId	= System.Diagnostics.Process.GetCurrentProcess().Id;
			m_eventLog.WriteEntry("Process " + processId.ToString() + " created");
		}

		protected override void OnStart(string[] args)
		{
			ServiceStatus							serviceStatus = new ServiceStatus();
			RegistryKey								key;
			string									tnsname;
			bool									running		  = true;

			try 
			{
				int processId = System.Diagnostics.Process.GetCurrentProcess().Id;

				ManagementObjectSearcher searcher = new ManagementObjectSearcher("SELECT * FROM Win32_Service where ProcessId = " + processId);
				ManagementObjectCollection collection = searcher.Get();
				m_name = (string)collection.Cast<ManagementBaseObject>().First()["Name"];
				
				key = Registry.LocalMachine.OpenSubKey(@"SYSTEM\CurrentControlSet\Services\" + m_name);
				tnsname = (string) key.GetValue("TNSNAME");
				Environment.SetEnvironmentVariable("TNSNAME", tnsname, EnvironmentVariableTarget.Process);

				m_eventLog.WriteEntry("Service starting: " + m_name + " (" + processId.ToString() + ") : TNSNAME - " + tnsname);

				serviceStatus.dwCurrentState = ServiceState.SERVICE_START_PENDING;
				serviceStatus.dwWaitHint = 100000;
				SetServiceStatus(this.ServiceHandle, ref serviceStatus);

				m_listener = new ABCSockets.AsyncSocketListener(tnsname, m_eventLog, m_trace);
				m_worker.DoWork += new DoWorkEventHandler(m_listener.start);
				m_worker.RunWorkerAsync();
			}

			catch (Exception ex)
			{
				string msg = ABCRQSUtils.ABCException.FormatedMessage(ex);
				m_eventLog.WriteEntry(msg, System.Diagnostics.EventLogEntryType.Error, 5);

				running = false;
				throw ex;
			}

			finally
			{
				if (running)
				{
					// Update the service state to Running.
					serviceStatus.dwCurrentState = ServiceState.SERVICE_RUNNING;
				}
				else
				{
					serviceStatus.dwCurrentState = ServiceState.SERVICE_STOPPED;
				}

				SetServiceStatus(this.ServiceHandle, ref serviceStatus);
			}
		}

		protected override void OnStop()
		{
			ServiceStatus serviceStatus = new ServiceStatus();
			serviceStatus.dwCurrentState = ServiceState.SERVICE_STOP_PENDING;
			serviceStatus.dwWaitHint = 10000;
			SetServiceStatus(this.ServiceHandle, ref serviceStatus);

			if (m_listener != null)
			{ 
				if (m_listener.IsListening) m_listener.Stop();
			}
				
			// Update the service state to Running.
			serviceStatus.dwCurrentState = ServiceState.SERVICE_STOPPED;
			SetServiceStatus(this.ServiceHandle, ref serviceStatus);

			m_eventLog.WriteEntry("Service " + m_name + " Stopped.");
		}

		protected override void OnContinue()
		{
			// TODO: Add code here to perform any tear-down necessary to stop your service.
		}

		protected override void OnPause()
		{
			// TODO: Add code here to perform any tear-down necessary to stop your service.
			
		}
	}
}
