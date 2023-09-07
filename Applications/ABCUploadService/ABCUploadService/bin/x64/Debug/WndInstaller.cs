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
            ServiceProcessInstaller processInstaller = new ServiceProcessInstaller();
            ServiceInstaller serviceInstaller = new ServiceInstaller();
            String[] arguments = Environment.GetCommandLineArgs();

            //serviceInstaller.AfterInstall += new InstallEventHandler(AfterInstallEventHandler);

            //set the privileges
            processInstaller.Account = ServiceAccount.LocalSystem;
            serviceInstaller.DisplayName = "ABC Upload Service";
            serviceInstaller.StartType = ServiceStartMode.Automatic;

            //must be the same as what was set in Program's constructor
            serviceInstaller.ServiceName = "ABCUploadService";

            this.Installers.Add(processInstaller);
            this.Installers.Add(serviceInstaller);
        }

        //private void AfterInstallEventHandler(object sender, InstallEventArgs e)
        //{
        //    ServiceInstaller serviceInstaller = (ServiceInstaller)sender;
        //    RegistryKey key;

        //    key = Registry.LocalMachine.OpenSubKey(@"SYSTEM\CurrentControlSet\Services\" + serviceInstaller.ServiceName, true);
        //    if (key != null)
        //    {
        //        key.SetValue("configname", m_config, RegistryValueKind.String);
        //        key.Close();
        //    }
        //}

    }
}
