using System;
using System.Collections.Generic;
using System.Collections;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

using System.IO;
using System.Security.Cryptography;
using ABCRQSUtils;
using System.Configuration;
using System.Net;


namespace ABCRQSUtils
{
    public class FTPSSL : FTPBase
    {
        private FtpWebRequest m_request = null;

        public FTPSSL(Hashtable config) : base(config) { }

        public FTPSSL(FTPSetting setting) : base(setting)
        {

        }

        protected void Connect(string filename)
        {
            string          url;

            try
            {
                url = m_host + (m_port != 0 ? ":" + m_port.ToString() : "") + "/" + m_destination + filename;
                m_request = (FtpWebRequest)WebRequest.Create("ftp://" + url);

                if (m_protocol.ToUpper() == "SSL")
                {
                    m_request.EnableSsl = true;
                    System.Net.ServicePointManager.ServerCertificateValidationCallback += (sender, certificate, chain, sslPolicyErrors) => true;
                    m_request.Proxy = null;
                }

                m_request.Credentials = new NetworkCredential(m_user, m_pass);
                m_request.KeepAlive = false;
            }
            
            catch (Exception ex)
            {
                m_exception = ex;
            }

        }

        protected override void Connect()
        {
            Connect(null);
        }

        public override void CreateDirectory(string path)
        {
			Stream			requestStream	= null;
			FtpWebResponse	response		= null;
   			byte[]			buffer			= new byte[10000];
            int             retry           = 0;

            try
            {
                do
                {
                    try
                    {
                        m_exception = null;
 
                        Connect(path);
                        if (!IsError)
                        {
                            m_request.Method = WebRequestMethods.Ftp.ListDirectory;
                            response = (FtpWebResponse)m_request.GetResponse();
                            requestStream = response.GetResponseStream();

                            if (requestStream.Read(buffer, 0, buffer.Length) == 0)
                            {
                                if (requestStream != null) requestStream.Close();
                                if (response != null) response.Close();

                                response = null;
                                requestStream = null;

                                Connect(path);
                                if (!IsError)
                                {
                                    m_request.Method = WebRequestMethods.Ftp.MakeDirectory;

                                    response = (FtpWebResponse)m_request.GetResponse();
                                    requestStream = response.GetResponseStream(); 
                                }
                            }

                            if (requestStream != null) requestStream.Close();
                            if (response != null) response.Close();
                        }
                    }

                    catch (Exception ex)
                    {
                        m_exception = ex;
                        if (requestStream != null) requestStream.Close();
                        if (response != null) response.Close();

                        response = null;
                        requestStream = null;

                        if (retry > 2) throw ex;
                        retry++;
                    }

                } while (IsError);
            }

            catch (Exception ex)
            {
                m_exception = ex;
            }
        }

        public override bool UploadFile(string sourceFileName)
        {
            Stream requestStream    = null; 
            FtpWebResponse response = null;
            string uploadFilename   = sourceFileName;
            byte[] fileContents     = null;

            try
            {
                if (ZipFileName != null) uploadFilename = Zip(sourceFileName);
                if (!IsError)  // make sure no error from the zipping of file
                {
                    UploadedFileName = Path.GetFileName(uploadFilename);
                    fileContents = File.ReadAllBytes(uploadFilename);

                    uploadFilename = uploadFilename.Replace('/', '\\');
                    Connect(UploadedFileName);
                }

                if (!IsError)  // check for error on connection
                {
                    m_request.Method = WebRequestMethods.Ftp.UploadFile;
                    m_request.ContentLength = fileContents.Length;

                    requestStream = m_request.GetRequestStream();
                    requestStream.Write(fileContents, 0, fileContents.Length);
                    requestStream.Close();

                    response = (FtpWebResponse)m_request.GetResponse();
                    Status = response.StatusDescription;
                    response.Close();

                    // remove file
                    File.Delete(uploadFilename);
                }
            }

            catch (Exception ex)
            {
                m_exception = ex;
            }

            return (m_exception == null);
        }

        public override bool UploadFile(byte[] fileContents, string sourceFileName)
        {
            Stream requestStream = null;
            FtpWebResponse response = null;
            string uploadFile = sourceFileName;
            int retry = 0;

            try
            {
                if (ZipFileName != null)
                {
                    uploadFile = Zip(fileContents, sourceFileName);

                    // get zip file content to upload
                    fileContents = File.ReadAllBytes(uploadFile);

                    UploadedFileName = Path.GetFileName(uploadFile);
                }
                else
                {
                    UploadedFileName = sourceFileName;
                }

                if (!IsError)  // make sure no error from the zipping of file
                {
                    do
                    {
                        try 
                        {
                            m_exception = null;

                            Connect(UploadedFileName);
                       

                            if (!IsError)  // check for error on connection
                            {
                                m_request.Method = WebRequestMethods.Ftp.UploadFile;
                                m_request.ContentLength = fileContents.Length;
                                //m_request.UsePassive = false;

                                requestStream = m_request.GetRequestStream();
                                requestStream.Write(fileContents, 0, fileContents.Length);
                                requestStream.Close();

                                response = (FtpWebResponse)m_request.GetResponse();
                                Status = response.StatusDescription;
                                response.Close();
                            }

                            retry++;
                        }

                        catch (Exception ex)
                        {
                            m_exception = ex;
                            if (retry > 2) throw ex;
                            retry++;
                        }

                    } while (IsError);
                }
            }

            catch (Exception ex)
            {
                m_exception = ex;
            }

            return (m_exception == null);
        }


        public override string GetDirList(string directory)
        {
            Stream requestStream = null;
            FtpWebResponse response = null;
            byte[] buffer = new byte[1000000];
            string oldDirectory = m_destination;
            string list = null;

            try
            {
                m_destination = directory;
                Connect();

                m_request.Method = WebRequestMethods.Ftp.ListDirectory;

                response = (FtpWebResponse) m_request.GetResponse();
                requestStream = response.GetResponseStream();

                requestStream.Read(buffer, 0, buffer.Length);
                list = Encoding.ASCII.GetString(buffer).TrimEnd('\0');
            }

            catch (Exception ex)
            {
                m_exception = ConnectionData(ex);
            }

            finally
            {
                m_destination = oldDirectory;
                if (requestStream != null) requestStream.Close();
                if (response != null) response.Close();
            }
            return list;
        }

    }
}
