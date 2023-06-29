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

namespace RQSFTP2
{
    class FTPSSH : FTPBase
    {
        SftpClient m_sshCp;

        public FTPSSH(Hashtable config) : base(config)
        {
            
        }

        public FTPSSH(string configuration, string configurationId) : base(configuration, configurationId)
        {

        }

        protected override void Connect()
        {
            try
            {
//                if (m_protocol.Equals("scp", StringComparison.OrdinalIgnoreCase))
////                    m_sshCp = new Scp(m_host, m_user);
//                else
                    m_sshCp = new SftpClient(m_host, (m_port == 0 ? 22 : m_port), m_user, m_pass);

                //if (m_pass.Length > 0) m_sshCp.Password = m_pass;
                //if (m_identityFile.Length > 0) m_sshCp.AddIdentityFile(m_identityFile);

                m_sshCp.Connect();
            }

            catch (Exception ex)
            {
                m_exception = ex;
            }
        }

        public override void CreateDirectory()
        {
            try
            {
                Connect();
                m_sshCp.CreateDirectory(m_destination);
//                m_sshCp.Close();
            }

            catch (Exception) {}
        }

        public override bool UploadFile(string filename)
        {
            string uploadFilename = filename;
            FileStream stream;

            try
            {
                if (ZipFile != null) uploadFilename = Zip(filename, ZipFile);

                uploadFilename = uploadFilename.Replace('/', '\\');
                stream = new FileStream(uploadFilename, FileMode.Open);

                Connect();
                m_sshCp.ChangeDirectory(m_destination);

                m_sshCp.BufferSize = 4 * 1024;
                m_sshCp.UploadFile(stream, Path.GetFileName(uploadFilename));

                stream.Close();

                //m_sshCp.Put(uploadFilename, m_destination + uploadFilename.Substring(uploadFilename.LastIndexOf('\\') + 1));
                //m_sshCp.Close();

                // remove file
                File.Delete(uploadFilename);
            }

            catch (Exception ex)
            {
                m_exception = ex;
            }

            return (m_exception == null);
        }


        public override bool UploadFile(string sourceFilename, byte[] fileContents)
        {
            string fileName = MapPath("~/Temp/", sourceFilename);

            try
            {
                File.WriteAllBytes(fileName, fileContents);
                UploadFile(fileName);
            }
            catch (Exception ex)
            {
                m_exception = ex;
            }

            return (m_exception == null);
        }


        public override string GetDirList(string directory)
        {
            //ArrayList   arrayList;
            string      list = "";

            try
            {
                Connect();
                IEnumerable<Renci.SshNet.Sftp.SftpFile> data = m_sshCp.ListDirectory(directory);
                //arrayList = ((Sftp)m_sshCp).GetFileList(directory);
                //m_sshCp.Close();

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
