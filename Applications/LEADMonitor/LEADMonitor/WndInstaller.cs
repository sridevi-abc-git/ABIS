using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Configuration.Install;
using System.Linq;
using System.ServiceProcess;
using System.Text;


namespace LEADMonitor
{
	[RunInstaller(true)]
	public class WndInstaller : Installer
	{
        public WndInstaller()
        {
            var processInstaller = new ServiceProcessInstaller();
            var serviceInstaller = new ServiceInstaller();
			var dataSource		 = Environment.GetEnvironmentVariable("DATA_SOURCE", EnvironmentVariableTarget.Machine);

            //set the privileges
            processInstaller.Account	 = ServiceAccount.User;
			processInstaller.Username    = ".\\abis_printer";
			processInstaller.Password    = "R00tb33r!";
			serviceInstaller.DisplayName = "ABC LEAD Process Monitor (" + dataSource + ")";
            serviceInstaller.StartType	 = ServiceStartMode.Manual;

            //must be the same as what was set in Program's constructor
			serviceInstaller.ServiceName = "LEADMonitor" + dataSource;
			
            this.Installers.Add(processInstaller);
            this.Installers.Add(serviceInstaller);
        }
	}
}
