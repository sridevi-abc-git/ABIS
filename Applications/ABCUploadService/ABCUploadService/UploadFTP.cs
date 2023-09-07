using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.IO;
using System.Security.Permissions;
using System.Net;
using ABCRQSUtils;
using System.Diagnostics;

namespace ABCUploadService
{
    class UploadFTP
    {
        ABCRQSUtils.AppConfigurationSettings m_cnfg;
        EventLog                             m_event = Program.GetEventLog();
        bool                                 m_trace = (System.Configuration.ConfigurationManager.AppSettings["trace"] == "Y" ? true : false);

        [PermissionSet(SecurityAction.Demand, Name = "FullTrust")]
        public UploadFTP(string config)
        {
            string              path    = ABCRQSUtils.Util.MapPath("~/Upload", null);
            FileSystemWatcher   watcher = new FileSystemWatcher();

            // get configuration information
            m_cnfg = ABCRQSUtils.AppConfigurationSettings.getConfigurationSection(config);
            watcher.Path = path;

            /* Watch for changes in LastAccess and LastWrite times, and
               the renaming of files or directories. */
            watcher.NotifyFilter = NotifyFilters.LastAccess | NotifyFilters.LastWrite
                                 | NotifyFilters.FileName | NotifyFilters.DirectoryName;
            // Only watch text files.
            watcher.Filter = m_cnfg.AppSettings["filter"].value; 

            // Add event handlers.
            watcher.Created += new FileSystemEventHandler(OnChanged);
            watcher.Changed += new FileSystemEventHandler(OnChanged);

            // Begin watching.
            watcher.EnableRaisingEvents = true;

            m_event.WriteEntry(path + "\n" + watcher.Filter, EventLogEntryType.Information, 0);
            Console.WriteLine(path);
            Console.WriteLine(watcher.Filter);

        }

        // Define the event handlers.
        private void OnChanged(object source, FileSystemEventArgs e)
        {
			FtpWebRequest	request			= null;
			Stream			requestStream	= null;
			FtpWebResponse	response		= null;
			FTPSetting		setting			= null;
			//string			reportName;
			string			encrypted;
			string			user			= null;
			string			password;
            //string			file			= null;
			string[]		temp;
			//string			seq				= "unknown";
			bool			ssl				= false;
			//string			dataSource		= null;
			int				retry			= 0;
			//string			create			= null;
			string			path			= null;
			byte[]			buffer			= new byte[100];
            byte[]          data;
			string          url             = null;
			string          statusDescription = "none";

            try
            {
                m_event.WriteEntry("Tripped", EventLogEntryType.Information, 1);
                Console.WriteLine("Tripped");

				setting = m_cnfg.FTPSettings[e.Name];
				if (setting == null)
                {
                    Console.WriteLine("Invalid File to Transfer: " + e.Name);
                    if (m_trace) m_event.WriteEntry("Invalid File to Transfer: " + e.Name, EventLogEntryType.Information, 10);
                    return;
                }

                if (!File.Exists(e.FullPath)) return;
                if (m_trace) m_event.WriteEntry("File to Transfer: " + e.Name, EventLogEntryType.Information, 1);

                System.Threading.Thread.Sleep(1000); // delay 1 second for coping to complete

                data = File.ReadAllBytes(e.FullPath);
                
				// get upload information from configuration file
				encrypted	= setting.encrypted;
				url			= setting.url;

				path = (url + e.Name).Substring(0, (url + e.Name).LastIndexOf('/'));

				if (setting.ssl.Length > 0)
				{
					ssl = (setting.ssl.Substring(0, 1).ToUpper() == "Y" ||
						   setting.ssl.Substring(0, 1).ToUpper() == "T" || 
						   setting.ssl.Substring(0, 1) == "1");
				}

				// decrypt user id and password
				temp = Util.Decrypt(encrypted).Split(new string[] { "||" }, StringSplitOptions.None);
				user = temp[0];
				password = temp[1];

				do
				{
					try
					{

						// upload file
						request = (FtpWebRequest)WebRequest.Create("ftp://" + url + e.Name);
						
						if (ssl)
						{
							request.EnableSsl = true;
							System.Net.ServicePointManager.ServerCertificateValidationCallback += (sender, certificate, chain, sslPolicyErrors) => true;
							request.Proxy = null;
						}

						request.Credentials = new NetworkCredential(user, password);

						request.Method = WebRequestMethods.Ftp.UploadFile;
						request.ContentLength = data.Length;

						requestStream = request.GetRequestStream();
						requestStream.Write(data, 0, data.Length);
						requestStream.Close();

						response = (FtpWebResponse)request.GetResponse();
						statusDescription = response.StatusDescription;
						response.Close();


                        if (m_trace) m_event.WriteEntry("File Uploaded: " + e.Name + " \t" + statusDescription, EventLogEntryType.Information, 9);

                        // remove file if no error
                        File.Delete(e.FullPath);
                        if (m_trace) m_event.WriteEntry("File Delete: " + e.Name, EventLogEntryType.Information, 10);
                        Console.WriteLine("File Uploaded: " + e.Name);
						retry = 3;
					}

					catch (Exception ex)
					{
						if (retry == 0)
						{
                            string value = "Host: "  + url + "  \n"
                                         + "User: "  + user + "  \n"
                                         + "File: "  + e.Name + "  \n"
                                         + "Error: " + ex.Message + "  \n"
                                         + "Stack: " + ex.StackTrace;

                            m_event.WriteEntry(value, EventLogEntryType.Error, 1);
                            Console.WriteLine(value);
						}
					}

					retry++;
				}
				while (retry < 3);

			}
            
            catch (Exception ex)
            {
                string value = "Host: " + url + "  \n"
                             + "User: " + user + "  \n"
                             + "File: " + e.Name + "  \n"
                             + "Error: " + ex.Message + "  \n"
                             + "Stack: " + ex.StackTrace;

                m_event.WriteEntry(value, EventLogEntryType.Error, 2);
                Console.WriteLine(value);
            }

            finally
            {
				if (requestStream != null) requestStream.Close();
				if (response != null) response.Close();
            }

            return;
        
        }
    }
}
