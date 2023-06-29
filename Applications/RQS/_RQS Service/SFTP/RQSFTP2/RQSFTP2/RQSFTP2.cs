using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using ABCRQSUtils;

namespace RQSFTP2
{
    class RQSFTP2
    {
        private Exception                  m_exception;
        private Dictionary<string, string> m_args;
        private FTPBase                    m_ftp;

        public Exception GetException { get { return m_exception;}}
        public bool      IsError      { get { return (m_exception != null); } }
        public string    Status       { get { return m_ftp.Status; } }

        public RQSFTP2(Dictionary<string, string> args)
        {
		    AppConfigurationSettings	cnfg;
			FTPSetting		            setting			= null;
			string			            reportName;
 			string			            dataSource		= null;


            try
            {
                m_args = args;
				args.TryGetValue("TNSNAME", out dataSource);

				cnfg = AppConfigurationSettings.getConfigurationSection(dataSource);

				if (!args.TryGetValue("REPORT_NAME", out reportName))
				{
                    reportName = "Reports";
				}

                setting = cnfg.FTPSettings[reportName];

                switch (setting.protocol.ToLower())
                {
                    case "sftp":
                    case "scp":
                        m_ftp = new FTPSSH(dataSource, reportName);
                        break;

                    case "ssl":
                    default:
                        m_ftp = new FTPSSL(dataSource, reportName);
                        break;
                }

                // get exception if one is thrown
                m_exception = m_ftp.GetException;
            }

            catch(Exception ex)
            {
                m_exception = ex;
            }
        }


        public bool UploadFile(string filename, byte[] fileContents)
        {
			string			create			= null;
			byte[]			buffer			= new byte[100];

            try
            {
                if (fileContents == null) fileContents = new byte[0];
                
                // make sure that no errors happened up stream processing
                if (!IsError)
                {
                    if (m_args.TryGetValue("CREATE_DIRECTORY", out create))
                    {
                        if (create == "Y") m_ftp.CreateDirectory();
                    }

                    // upload file
                    if (!m_ftp.UploadFile(filename, fileContents))
                    {
                        m_exception = m_ftp.ConnectionData(null);
                    }
                }
			}
            
            catch (Exception ex)
            {
                m_exception = m_ftp.ConnectionData(ex);
			}

            finally
            {
            }

            return (m_exception == null);
        }

        public bool UploadFile(string filename)
        {
            string create = null;

            try
            {
                // make sure that no errors happened up stream processing
                if (!IsError)
                {
                    if (m_args.TryGetValue("CREATE_DIRECTORY", out create))
                    {
                        if (create == "Y") m_ftp.CreateDirectory();
                    }

                    // upload file
                    if (!m_ftp.UploadFile(filename))
                    {
                        m_exception = m_ftp.GetException;
                    }
                }
            }

            catch (Exception ex)
            {
                m_exception = m_ftp.ConnectionData(ex);
            }

            finally
            {
            }

            return (m_exception == null);
        }

        public string GetDirList()
        {
            string directory;
            string list;

            if (!m_args.TryGetValue("DIRECTORY", out directory))
            {
                directory = m_ftp.Destination;
            }

            list = m_ftp.GetDirList(directory);

            if (m_ftp.IsError) m_exception = m_ftp.GetException;

            return list;
        }


    }
}
