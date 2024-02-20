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

namespace RQSService
{
	class Program
	{
		static ABCSockets.AsyncSocketListener		m_listener;

		static void Main(string[] args)
		{
			string				path		= ABCRQSUtils.Util.MapPath(@"~\Temp\", null);


			// check if temp directory exists
			if (!System.IO.Directory.Exists(path)) System.IO.Directory.CreateDirectory(path);

			if (System.Environment.UserInteractive)
			{
				//ManagementObjectSearcher searcher = new ManagementObjectSearcher("SELECT * FROM Win32_Service where ProcessId = " + 7856);
				//ManagementObjectCollection collection = searcher.Get();
				//var serviceName = (string)collection.Cast<ManagementBaseObject>().First()["Name"];
				
				// check to make sure argument(s) passed
				if (args.Length > 0)
				{
                    try
                    {
					    switch (args[0].ToLower())
					    {
						    case "-i":
								    ManagedInstallerClass.InstallHelper(new string[] { Assembly.GetExecutingAssembly().Location });

								    string		log    = ConfigurationManager.AppSettings["log"];
								    string		source = ConfigurationManager.AppSettings["log source"];

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
							    ABCRQSUtils.AppConfigurationSettings	cnfg;

                                //Environment.SetEnvironmentVariable("TNSNAME", args[1], EnvironmentVariableTarget.Process);
							    cnfg = ABCRQSUtils.AppConfigurationSettings.getConfigurationSection();

							    if (cnfg != null)
							    {
								    if (cnfg.AppSettings["connection"] != null)
								    {
									    m_listener = new ABCSockets.AsyncSocketListener(GetEventLog(), (ConfigurationManager.AppSettings["trace"] == "Y"));
									    m_listener.start(null, null);
								    }
								    else
								    {
									    Console.WriteLine("Connection string missing from configuration file");

									    Console.WriteLine("\nPress ENTER to continue...");
									    Console.Read();

								    }
							    }
							    else
							    {
								    Console.WriteLine("Configuration file not loaded ");

								    Console.WriteLine("\nPress ENTER to continue...");
								    Console.Read();
							    }
							    break;
					    }

                    }

                    catch (Exception ex)
                    {
                        Console.WriteLine("Configuration file failed to load ");
                        Console.WriteLine(ex.Message);
                        Console.WriteLine(ex.StackTrace);

                        GetEventLog().WriteEntry(ex.Message + "\n\r" + ex.StackTrace, System.Diagnostics.EventLogEntryType.Error);
                    }

				}
				else
				{
					Console.WriteLine("Please enter command line argument(s)");

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

		static System.Diagnostics.EventLog GetEventLog()
		{
			System.Diagnostics.EventLog			eventLog = new System.Diagnostics.EventLog();

			eventLog.Source = ConfigurationManager.AppSettings["log source"]; 
			eventLog.Log    = ConfigurationManager.AppSettings["log"];

			return eventLog;
		}

	}
}
