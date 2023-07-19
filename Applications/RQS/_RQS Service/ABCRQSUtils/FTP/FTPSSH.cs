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

using Renci.SshNet
;

namespace ABCRQSUtils
{
    class FTPSSH : FTPBase
    {
        SftpClient m_sshCp;

        public FTPSSH(Hashtable config)
            : base(config)
        {

        }

        public FTPSSH(FTPSetting setting) : base(setting)
        {

        }

        protected override void Connect()
        {
            try
            {
                m_sshCp = new SftpClient(m_host, (m_port == 0 ? 22 : m_port), m_user, m_pass);
                m_sshCp.Connect();
            }

            catch (Exception ex)
            {
                m_exception = ex;
            }
        }

        public override void CreateDirectory(string path)
        {
            try
            {
                Connect();
                m_destination = path;

                m_sshCp.CreateDirectory(m_destination);
            }

            catch (Exception) { }
        }

        public override bool UploadFile(string sourceFileName)
        {
            try
            {
                UploadFile(File.ReadAllBytes(sourceFileName), sourceFileName); 
            }

            catch (Exception ex)
            {
                m_exception = ex;
            }

            return (m_exception == null);
        }


        public override bool UploadFile(byte[] fileContents, string sourceFileName)
        {
            string fileName = Util.MapPath("~/Temp/", sourceFileName);
            string uploadFilename = null;
            Stream stream;

            try
            {
                if (ZipFileName != null)
                {
                    uploadFilename = Zip(fileContents, sourceFileName);

                    uploadFilename = uploadFilename.Replace('/', '\\');
                    stream = new FileStream(uploadFilename, FileMode.Open);
                }
                else
                {
                    stream = new MemoryStream(fileContents);
                    uploadFilename = sourceFileName;
                }

                if (!IsError)
                {
                    Connect();
                }

                if (!IsError)
                {
                    UploadedFileName = Path.GetFileName(uploadFilename);
                    m_sshCp.ChangeDirectory(m_destination);

                    m_sshCp.BufferSize = 4 * 1024;
                    m_sshCp.UploadFile(stream, UploadedFileName);
                    Status = "File Uploaded: " + UploadedFileName;
                    stream.Close();

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


        public override string GetDirList(string directory)
        {
            string list = "";

            try
            {
                Connect();
                IEnumerable<Renci.SshNet.Sftp.SftpFile> data = m_sshCp.ListDirectory(directory);

                foreach (Renci.SshNet.Sftp.SftpFile item in data)
                {
                    if (item.Name == "." || item.Name == "..") continue;
                    list += item.Name + "\r\n";
                }
            }

            catch (Exception ex)
            {
                m_exception = ex;
                list = null;
            }

            return list;
        }

    }
}
