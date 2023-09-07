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
using Microsoft.Win32;
using System.Management;
using System.Management.Instrumentation;


namespace ABCUploadService
{
        public enum ServiceState
        {
            SERVICE_STOPPED = 0x00000001,
            SERVICE_START_PENDING = 0x00000002,
            SERVICE_STOP_PENDING = 0x00000003,
            SERVICE_RUNNING = 0x00000004,
            SERVICE_CONTINUE_PENDING = 0x00000005,
            SERVICE_PAUSE_PENDING = 0x00000006,
            SERVICE_PAUSED = 0x00000007,
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct ServiceStatus
        {
            public long dwServiceType;
            public ServiceState dwCurrentState;
            public long dwControlsAccepted;
            public long dwWin32ExitCode;
            public long dwServiceSpecificExitCode;
            public long dwCheckPoint;
            public long dwWaitHint;
        };



    partial class ServiceMonitor : ServiceBase
    {
        [DllImport("advapi32.dll", SetLastError = true)]
        private static extern bool SetServiceStatus(IntPtr handle, ref ServiceStatus serviceStatus);

        private System.Diagnostics.EventLog m_eventLog;
        private string                      m_name;
        private Upload                      m_upload;
        private bool                        m_trace;

        public ServiceMonitor()
        {
            int processId;

            m_eventLog = new System.Diagnostics.EventLog();
            m_eventLog.Source = ConfigurationManager.AppSettings["log source"];
            m_eventLog.Log = ConfigurationManager.AppSettings["log"];
            m_trace = (ConfigurationManager.AppSettings["trace"] == "Y");
            CanPauseAndContinue = true;
            AutoLog = false;

            processId = System.Diagnostics.Process.GetCurrentProcess().Id;
            m_eventLog.WriteEntry("Process " + processId.ToString() + " created");
        }

        protected override void OnStart(string[] args)
        {
            // TODO: Add code here to start your service.
			ServiceStatus							serviceStatus = new ServiceStatus();
			RegistryKey								key;
			string									configname;
			bool									running		  = true;

			try 
			{
				int processId = System.Diagnostics.Process.GetCurrentProcess().Id;

				ManagementObjectSearcher searcher = new ManagementObjectSearcher("SELECT * FROM Win32_Service where ProcessId = " + processId);
				ManagementObjectCollection collection = searcher.Get();
				m_name = (string)collection.Cast<ManagementBaseObject>().First()["Name"];
				
				key = Registry.LocalMachine.OpenSubKey(@"SYSTEM\CurrentControlSet\Services\" + m_name);
                configname = (string)key.GetValue("configname");

                m_eventLog.WriteEntry("Service starting: " + m_name + " (" + processId.ToString() + ")");
                m_upload = new Upload();

				serviceStatus.dwCurrentState = ServiceState.SERVICE_START_PENDING;
				serviceStatus.dwWaitHint = 100000;
				SetServiceStatus(this.ServiceHandle, ref serviceStatus);
			}

			catch (Exception ex)
			{
				m_eventLog.WriteEntry(ex.Message + ' ' + ex.StackTrace, System.Diagnostics.EventLogEntryType.Error, 5);

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


            // Update the service state to Running.
            serviceStatus.dwCurrentState = ServiceState.SERVICE_STOPPED;
            SetServiceStatus(this.ServiceHandle, ref serviceStatus);

            m_eventLog.WriteEntry("Service " + m_name + " Stopped.");
        }
    }
}
