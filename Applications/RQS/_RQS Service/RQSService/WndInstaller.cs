using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Configuration.Install;
using System.Linq;
using System.ServiceProcess;
using System.Text;
using Microsoft.Win32;


namespace RQSService
{
	[RunInstaller(true)]
	public class WndInstaller : Installer
	{
		string m_tnsname;

        public WndInstaller()
        {
			ServiceProcessInstaller processInstaller = new ServiceProcessInstaller();
			ServiceInstaller		serviceInstaller = new ServiceInstaller();
			String[]				arguments		 = Environment.GetCommandLineArgs();

			m_tnsname = arguments[2];

			serviceInstaller.AfterInstall += new InstallEventHandler(AfterInstallEventHandler);

            //set the privileges
			processInstaller.Account = ServiceAccount.LocalSystem; //  .LocalSystem;  // .User; // .LocalService;
            //processInstaller.Username = ".\\RQSSERVICE";
            //processInstaller.Password = "RQSSrvc@1";

			serviceInstaller.DisplayName = "ABC RQS ProcSrvr (" + m_tnsname + ")";
            serviceInstaller.StartType	 = ServiceStartMode.Automatic;

            //must be the same as what was set in Program's constructor
			serviceInstaller.ServiceName = "RQSProcSrvr" + m_tnsname;

            this.Installers.Add(processInstaller);
            this.Installers.Add(serviceInstaller);
        }

		private void AfterInstallEventHandler(object sender, InstallEventArgs e)
		{
			ServiceInstaller		serviceInstaller = (ServiceInstaller)sender;
			RegistryKey				key;

			key = Registry.LocalMachine.OpenSubKey(@"SYSTEM\CurrentControlSet\Services\" + serviceInstaller.ServiceName, true);
			if (key != null)
			{
				key.SetValue("TNSNAME", m_tnsname, RegistryValueKind.String);
				key.Close();
			}
		}

	}
}


// HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services
// (string)Registry.LocalMachine.GetValue(@"SOFTWARE\MyApplication\AppPath",
// "Installed", null);