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


namespace RQSFTP2
{
    public class FTPSSL : FTPBase
    {
        private FtpWebRequest m_request = null;

        public FTPSSL(Hashtable config) : base(config) { }

        public FTPSSL(string configuration, string configurationId) : base(configuration, configurationId)
        {

        }

        protected void Connect(string filename)
        {
            string          url;

            try
            {
                url = m_host + (m_port != 0 ? ":" + m_port.ToString() : "") + "/" + m_destination + filename;
                m_request = (FtpWebRequest)WebRequest.Create("ftp://" + url);

                if (m_protocol == "SSL")
                {
                    m_request.EnableSsl = true;
                    System.Net.ServicePointManager.ServerCertificateValidationCallback += (sender, certificate, chain, sslPolicyErrors) => true;
                    m_request.Proxy = null;
                }

                m_request.Credentials = new NetworkCredential(m_user, m_pass);
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

        public override void CreateDirectory()
        {
			Stream			requestStream	= null;
			FtpWebResponse	response		= null;
   			byte[]			buffer			= new byte[10000];

            try
            {
                Connect();
				m_request.Method = WebRequestMethods.Ftp.ListDirectory;
				response = (FtpWebResponse)m_request.GetResponse();
				requestStream = response.GetResponseStream();
            }

            catch (WebException)
            {
                // create directory
                Connect();
 				m_request.Method = WebRequestMethods.Ftp.MakeDirectory;
                    
				response = (FtpWebResponse)m_request.GetResponse();
                Status = response.StatusDescription;
                requestStream = response.GetResponseStream();

				if (requestStream != null) requestStream.Close();
				if (response != null) response.Close();
            }

            catch (Exception ex)
            {
                m_exception = ex;
            }
        }

        public override bool UploadFile(string filename)
        {
            Stream requestStream    = null;
            FtpWebResponse response = null;
            string uploadFilename   = filename;
            byte[] fileContents     = null;

            try
            {
                if (ZipFile != null) uploadFilename = Zip(filename, ZipFile);
                if (!IsError)  // make sure no error from the zipping of file
                {
                    fileContents = File.ReadAllBytes(uploadFilename);

                    uploadFilename = uploadFilename.Replace('/', '\\');
                    Connect(uploadFilename.Substring(uploadFilename.LastIndexOf('\\') + 1));
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

        public override bool UploadFile(string filename, byte[] fileContents)
        {
            Stream requestStream = null;
            FtpWebResponse response = null;
            string uploadFile = filename;

            try
            {
                if (ZipFile != null) uploadFile = Zip(fileContents, filename, ZipFile);
                if (!IsError)  // make sure no error from the zipping of file
                {
                    Connect(filename.Substring(filename.LastIndexOf('\\') + 1));
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
            }
            return list;
        }

    }
}
