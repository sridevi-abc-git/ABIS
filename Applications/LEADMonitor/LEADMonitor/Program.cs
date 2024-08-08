using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

using System.Configuration;
using System.Configuration.Install;
using System.ServiceProcess;
using System.Reflection;
using System.ComponentModel;

namespace LEADMonitor
{
	class Program
	{

		static void Main(string[] args)
		{
			if (System.Environment.UserInteractive)
			{
				ExeConfigurationFileMap		configMap = new ExeConfigurationFileMap();
				string						path	  = AppDomain.CurrentDomain.BaseDirectory;
				Configuration				config;
				AppSettingsSection			appSettings;
				ConnectionStringsSection	connSettings;

				configMap.ExeConfigFilename = path + @"\" + args[1] + ".config";
				config = ConfigurationManager.OpenMappedExeConfiguration(configMap, ConfigurationUserLevel.None);
				appSettings = (System.Configuration.AppSettingsSection) config.GetSection("appSettings");

				connSettings = (System.Configuration.ConnectionStringsSection)config.GetSection("connectionStrings");

				// check to make sure argument(s) passed
				if (args.Length > 0)
				{
					switch (args[0].ToLower())
					{
						case "-i":
							if (args.Length > 1)
							{
								Environment.SetEnvironmentVariable("DATA_SOURCE", args[1], EnvironmentVariableTarget.Machine);
								ManagedInstallerClass.InstallHelper(new string[] { Assembly.GetExecutingAssembly().Location });

								string		log    = appSettings.Settings["log"].Value;
								string		source = appSettings.Settings["log source"].Value;

								if (!System.Diagnostics.EventLog.SourceExists(source))
								{
									System.Diagnostics.EventLog.CreateEventSource(source, log);
								}
							}
							else
							{
								Console.WriteLine("\nPlease enter the data source (TNSNAMES) name for this service");
								Console.Read();
							}
							break;

						case "-u":
							if (args.Length > 1)
							{
								Environment.SetEnvironmentVariable("DATA_SOURCE", null, EnvironmentVariableTarget.Machine);
								ManagedInstallerClass.InstallHelper(new string[] { "/u", Assembly.GetExecutingAssembly().Location });
							}
							else
							{
								Console.WriteLine("\nPlease enter the data source (TNSNAMES) name for this service");
								Console.Read();
							}
							break;

						case "-r":
						default:
							BackgroundWorker					m_worker = new BackgroundWorker();

							Environment.SetEnvironmentVariable("DATA_SOURCE", args[1], EnvironmentVariableTarget.Process);
							Console.WriteLine("Lead Monitor Starting (TNSNAME: " + args[1] + ")");

							LEADProcMonitor						m_monitor;

							Environment.SetEnvironmentVariable("CONNECTION",
																GetConnectionString(appSettings, args[1]),
																EnvironmentVariableTarget.Process);

							m_monitor = new LEADProcMonitor(args[1], GetEventLog(appSettings), true);
							m_worker.DoWork += new DoWorkEventHandler(m_monitor.start);
							m_worker.RunWorkerAsync();

							Console.Read();

							break;
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

		static public System.Diagnostics.EventLog GetEventLog(AppSettingsSection appSettings)
		{
			System.Diagnostics.EventLog			eventLog = new System.Diagnostics.EventLog();

			eventLog.Source = appSettings.Settings["log source"].Value;
			eventLog.Log = appSettings.Settings["log"].Value;

			return eventLog;
		}


		static public AppSettingsSection GetAppSettings(string dataSource)
		{
			ExeConfigurationFileMap		configMap = new ExeConfigurationFileMap();
			string						path	  = AppDomain.CurrentDomain.BaseDirectory;
			Configuration				config;
			AppSettingsSection			appSettings;

			configMap.ExeConfigFilename = path + @"\" + dataSource + ".config";
			config = ConfigurationManager.OpenMappedExeConfiguration(configMap, ConfigurationUserLevel.None);
			appSettings = (System.Configuration.AppSettingsSection)config.GetSection("appSettings");

			return appSettings;

		}


		static public string GetConnectionString(AppSettingsSection settings, string dataSource)
		{
			string connectionString;

			connectionString = "User Id=" + settings.Settings["user id"].Value
							 + ";Password=" + (settings.Settings["password"] == null ? dataSource : settings.Settings["password"].Value)
							 + ";Data Source=" + dataSource;
			return connectionString;
		}
	}
}
