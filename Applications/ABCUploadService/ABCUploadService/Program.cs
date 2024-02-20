using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

using System.Configuration;
using System.Configuration.Install;
using System.ServiceProcess;
using System.Reflection;

using System.Management;


namespace ABCUploadService
{
    class Program
    {
        static void Main(string[] args)
        {
            if (System.Environment.UserInteractive)
            {
                // check to make sure argument(s) passed
                if (args.Length > 0)
                {
                    switch (args[0].ToLower())
                    {
                        case "-i":
                               ManagedInstallerClass.InstallHelper(new string[] { Assembly.GetExecutingAssembly().Location });

                                string log = ConfigurationManager.AppSettings["log"];
                                string source = ConfigurationManager.AppSettings["log source"];

                                if (!System.Diagnostics.EventLog.SourceExists(source))
                                {
                                    System.Diagnostics.EventLog.CreateEventSource(source, log);
                                }
                            break;

                        case "-u":
                                ManagedInstallerClass.InstallHelper(new string[] { "/u", Assembly.GetExecutingAssembly().Location });
                            break;

                        case "-r":
                        default:
                                    Upload upd = new Upload(); 

                                    Console.WriteLine("Press \'q\' to quit.");
                                    while (Console.Read() != 'q') ;
                            break;
                    }
                }
                else
                {
                    Console.WriteLine("Please enter command line argument(s)");
                    Console.WriteLine("\tTo Install Enter:         ABCUploadService -i");
                    Console.WriteLine("\tTo Uninstall Enter:       ABCUploadService -U");
                    Console.WriteLine("\tTo Run as console Enter:  ABCUploadService -r");

                    Console.WriteLine("\nPress ENTER to continue...");
                    Console.Read();
                }
            }
            else
            {
                ServiceBase[] ServicesToRun;

                ServicesToRun = new ServiceBase[] 
				{ 
					new ServiceMonitor() 
				};

                ServiceBase.Run(ServicesToRun);
            }
        }

   
        static public System.Diagnostics.EventLog GetEventLog()
        {
            System.Diagnostics.EventLog eventLog = new System.Diagnostics.EventLog();

            eventLog.Source = ConfigurationManager.AppSettings["log source"];
            eventLog.Log = ConfigurationManager.AppSettings["log"];

            return eventLog;
        }
    }
}
