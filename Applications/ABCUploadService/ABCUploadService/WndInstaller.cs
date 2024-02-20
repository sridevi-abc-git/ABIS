using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Configuration.Install;
using System.Linq;
using System.ServiceProcess;
using System.Text;
using Microsoft.Win32;

namespace ABCUploadService
{
    [RunInstallerAttribute(true)]
    public class WndInstaller : Installer
    {
        public WndInstaller()
        {
            string environment = System.Configuration.ConfigurationManager.AppSettings["environment"];
            ServiceProcessInstaller processInstaller = new ServiceProcessInstaller();
            ServiceInstaller serviceInstaller = new ServiceInstaller();

            //set the privileges
            processInstaller.Account = ServiceAccount.LocalSystem;
            serviceInstaller.DisplayName = "ABC Upload Service (" + environment + ")";
            serviceInstaller.StartType = ServiceStartMode.Automatic;

            //must be the same as what was set in Program's constructor
            serviceInstaller.ServiceName = "ABCUploadService_" + environment;

            this.Installers.Add(processInstaller);
            this.Installers.Add(serviceInstaller);
        }

    }
}
