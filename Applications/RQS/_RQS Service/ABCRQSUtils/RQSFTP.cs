using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

using System.Configuration;
using System.Net;
using System.IO;

namespace ABCRQSUtils
{
	public class RQSFTP
	{
		public RQSFTP() { }

		public bool UploadFile(byte[] fileContents, Dictionary<string, string> args, out string url, out string statusDescription, out ABCException e)
		{
			bool	directoryCreated;

			return UploadFile(fileContents, args, out url, out statusDescription, out directoryCreated, out e);
		}

		public bool UploadFile(byte[] fileContents, Dictionary<string, string> args, out string url, out string statusDescription, out bool directoryCreated, out ABCException e)
		{
		    AppConfigurationSettings	cnfg;

			FtpWebRequest	request			= null;
			Stream			requestStream	= null;
			FtpWebResponse	response		= null;
			FTPSetting		setting			= null;
			string			reportName;
			string			user			= null;
			string			password;
			string			file			= null;
			string			seq				= "unknown";
			bool			ssl				= false;
			string			dataSource		= null;
			int				retry			= 0;
			string			create			= null;
			string			path			= null;
			byte[]			buffer			= new byte[100];

			e				  = null;
			url				  = "unknown";
			user			  = "unknown";
			statusDescription = "none";
			directoryCreated  = false;

            try
            {
				args.TryGetValue("TNSNAME", out dataSource);
				cnfg = AppConfigurationSettings.getConfigurationSection(dataSource);
                if (cnfg == null)
                {
				    args.TryGetValue("CNFG", out dataSource);
				    cnfg = AppConfigurationSettings.getConfigurationSection(dataSource);
                }

                if (cnfg == null)
                {
					e = new ABCException(seq, "Cannot find configuration file: " + dataSource);
					return false;
                }

				if (!args.TryGetValue("SEQ", out seq)) seq = "unknown";
				if (!args.TryGetValue("REPORT_NAME", out reportName))
				{
					e = new ABCException(seq, "Report Name Missing : RQSFTP.UploadFile()");
					return false;
				}

				if(!args.TryGetValue("FILE_NAME", out file))
				{
					e = new ABCException(seq, "Destination File Name Missing : RQSFTP.UploadFile()");
					return false;
				}

				if (!args.TryGetValue("CREATE_DIRECTORY", out create)) create = "N";

				setting = cnfg.FTPSettings[reportName];
				if (setting == null) setting = cnfg.FTPSettings["Reports"];

				// get upload information from configuration file
				url		 = setting.url;
                user     = setting.user;
                password = setting.password;

				path = (url + file).Substring(0, (url+file).LastIndexOf('/'));

				if (setting.ssl.Length > 0)
				{
					ssl = (setting.ssl.Substring(0, 1).ToUpper() == "Y" ||
						   setting.ssl.Substring(0, 1).ToUpper() == "T" || 
						   setting.ssl.Substring(0, 1) == "1");
				}

				// upload file
                if (fileContents == null)
                {
                    fileContents = new byte[0];
                }

				do
				{
					try
					{
						if (create == "Y")
						{
							// check if directory exists
							request = (FtpWebRequest)WebRequest.Create("ftp://" + path);
							request.Credentials = new NetworkCredential(user, password);

							if (ssl)
							{
								request.EnableSsl = true;
								System.Net.ServicePointManager.ServerCertificateValidationCallback += (sender, certificate, chain, sslPolicyErrors) => true;
								request.Proxy = null;
							}

							request.Method = WebRequestMethods.Ftp.ListDirectory;
							response = (FtpWebResponse)request.GetResponse();
							requestStream = response.GetResponseStream();

							if (requestStream.Read(buffer, 0, buffer.Length) == 0)
							{
								if (requestStream != null) requestStream.Close();
								if (response != null) response.Close();

								// create directory
								request = (FtpWebRequest)WebRequest.Create("ftp://" + path);
								request.Credentials = new NetworkCredential(user, password);

								if (ssl)
								{
									request.EnableSsl = true;
									System.Net.ServicePointManager.ServerCertificateValidationCallback += (sender, certificate, chain, sslPolicyErrors) => true;
									request.Proxy = null;
								}

								request.Method = WebRequestMethods.Ftp.MakeDirectory;

								response = (FtpWebResponse)request.GetResponse();
								requestStream = response.GetResponseStream();
								directoryCreated = true;
							}

							if (requestStream != null) requestStream.Close();
							if (response != null) response.Close();
						}

						// upload file
						request = (FtpWebRequest)WebRequest.Create("ftp://" + url + file);
						
						if (ssl)
						{
							request.EnableSsl = true;
							System.Net.ServicePointManager.ServerCertificateValidationCallback += (sender, certificate, chain, sslPolicyErrors) => true;
							request.Proxy = null;
						}

						request.Credentials = new NetworkCredential(user, password);

						request.Method = WebRequestMethods.Ftp.UploadFile;
						request.ContentLength = fileContents.Length;

						requestStream = request.GetRequestStream();
						requestStream.Write(fileContents, 0, fileContents.Length);
						requestStream.Close();

						response = (FtpWebResponse)request.GetResponse();
						statusDescription = response.StatusDescription;
						response.Close();

						retry = 3;
						e = null;
					}

					catch (Exception ex)
					{
						if (retry == 0)
						{
							e = new ABCException(seq, ex);
							e.Data["Host"] = url;
							e.Data["User"] = user;
							e.Data["File"] = file;
							e.Data["Configuration"] = dataSource;
						}
					}

					retry++;
				}
				while (retry < 3);
			}
            
            catch (Exception ex)
            {
				e = new ABCException(seq, ex);
				e.Data["Host"] = url;
				e.Data["User"] = user;
				e.Data["File"] = file;
				e.Data["Configuration"] = dataSource;
			}

            finally
            {
				if (requestStream != null) requestStream.Close();
				if (response != null) response.Close();
				url += file;
            }

            return (e == null);
        }

		public bool GetDirList(Dictionary<string, string> args, out string list, out string statusDescription, out ABCException e)
		{
		    AppConfigurationSettings	cnfg;
			FtpWebRequest				request			= null;
			Stream						requestStream	= null;
			FtpWebResponse				response		= null;
			FTPSetting					setting			= null;
			//string						reportName;
			string						encrypted;
			string						user			= null;
			string						password;
			//string						file			= null;
			string[]					temp;
			bool						ssl				= false;
			string						dataSource		= null;
			int							retry			= 0;
			byte[]						buffer			= new byte[1000000];
			string						directory;
			string						url;
			string						id;

			e				  = null;
			list			  = null;
			user			  = "unknown";
			statusDescription = "none";

			args.TryGetValue("TNSNAME", out dataSource);
			cnfg = AppConfigurationSettings.getConfigurationSection(dataSource);

			if (!args.TryGetValue("DIRECTORY", out directory))
			{
				e = new ABCException(null, "Directory Name Missing : RQSFTP.GetDirList()");
				return false;
			}

			if (!args.TryGetValue("ID", out id))
			{
				e = new ABCException(null, "ID : RQSFTP.GetDirList()");
				return false;
			}

			setting = cnfg.FTPSettings[id];
			if (setting == null) setting = cnfg.FTPSettings["Reports"];

			// get upload information from configuration file
			encrypted = setting.encrypted;
			url		  = setting.url;

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

			try
			{
				do
				{
					try
					{

						request = (FtpWebRequest)WebRequest.Create("ftp://" + setting.url + directory);
//						request = (FtpWebRequest)WebRequest.Create("ftp://100.64.92.18:21/reports/actions2016");	 //("ftp://67.157.98.26:21/");

						if (ssl)
						{
							request.EnableSsl = true;
							System.Net.ServicePointManager.ServerCertificateValidationCallback += (sender, certificate, chain, sslPolicyErrors) => true;
							request.Proxy = null;
						}

						request.Credentials = new NetworkCredential(user, password);
						request.Method = WebRequestMethods.Ftp.ListDirectory;

						response = (FtpWebResponse)request.GetResponse();
						requestStream = response.GetResponseStream();

						requestStream.Read(buffer, 0, buffer.Length);
						list = Encoding.ASCII.GetString(buffer).TrimEnd('\0');

						retry = 3;
						e = null;
					}

					catch (Exception ex)
					{
						if (retry == 0)
						{
							e = new ABCException(null, ex);
							e.Data["Host"] = url;
							e.Data["User"] = user;
							e.Data["Directory"] = directory;
							e.Data["Configuration"] = dataSource;
						}
					}

					retry++;
				}
				while (retry < 3);
			}
            
            catch (Exception ex)
            {
				e = new ABCException(null, ex);
				e.Data["Host"] = url;
				e.Data["User"] = user;
				e.Data["Directory"] = directory;
				e.Data["Configuration"] = dataSource;
			}

            finally
            {
				if (requestStream != null) requestStream.Close();
				if (response != null) response.Close();
				url += directory;
            }
            return (e == null);
		}
	}
}
