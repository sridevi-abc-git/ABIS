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

namespace ABCRQSUtils
{
    /// <summary>
    /// a warpper class for RQS FTP process
    /// </summary>
    public abstract class FTPBase
    {
        protected Exception m_exception = null;
        protected string    m_host;
        protected string    m_user;
        protected string    m_pass;
        protected int       m_port;
        protected string    m_protocol;
        protected string    m_identityFile;
        protected string    m_destination;

        public bool   IsError           { get { return (m_exception != null); } }
        public string ZipFileName       { get; set; }
        public string UploadedFileName  { get; set; }
        public string Status            { get; set; }
        public string Host              { get { return m_host; } }
        public string User              { get { return m_user; } }
        public string Port              { get { return m_port.ToString(); } }
        public string Protocol          { get { return m_protocol; } }
        public string Destination       { get { return m_destination; } }
        public string URL               { get { return m_host + (m_port > 0 ? ":" + m_port.ToString() : "") + m_destination.Replace('\\', '/') + UploadedFileName; } }

        public Exception GetException
        {
            get
            {
                if (m_exception != null)
                {
                    m_exception.Data["Host"]        = m_host;
                    m_exception.Data["User"]        = m_user;
                    m_exception.Data["Port"]        = m_port;
                    m_exception.Data["Protocol"]    = m_protocol;
                    m_exception.Data["Identy File"] = m_identityFile;
                    m_exception.Data["Destination"] = m_destination;
                    m_exception.Data["URL"]         = URL;
                }

                return m_exception;
            }
        }

        public Exception ConnectionData(Exception ex)
        {
            if (ex == null) ex = new Exception();

            ex.Data["Host"] = m_host;
            ex.Data["User"] = m_user;
            ex.Data["Port"] = m_port;
            ex.Data["Protocol"] = m_protocol;
            ex.Data["Identy File"] = m_identityFile;
            ex.Data["Destination"] = m_destination;
            ex.Data["URL"] = URL;

            return ex;
        }

        /// <summary>
        /// 
        /// </summary>
        /// <param name="config"></param>
        protected FTPBase(Hashtable config)
        {
            this.m_host =         (string) config["host"];
            this.m_user =         (string) config["user"];
            this.m_pass =         (string) config["password"];
            this.m_port =         (int)    config["port"];
            this.m_protocol =     (string) config["protocol"];
            this.m_identityFile = (string) config["identityfile"];
            this.m_destination  = (string) config["destination"];
            
        }

        /// <summary>
        /// 
        /// </summary>
        /// <param name="configuration"></param>
        /// <param name="configurationId"></param>
        protected FTPBase(FTPSetting setting)
        {
            string                   encrypted;
            string[]                 temp;

            try
            {
                // check if password and user id are encrypted
                encrypted = setting.encrypted;
                if (encrypted.Length > 0)
                {
                    temp = Util.Decrypt(encrypted).Split(new string[] { "||" }, StringSplitOptions.None);
                    this.m_user = temp[0];
                    this.m_pass = temp[1];
                }

                // load configurations
                this.m_host =         setting.host.Length == 0 ? setting.url : setting.host;
                this.m_user =         setting.user.Length == 0 ? m_user : setting.user;
                this.m_pass =         setting.password.Length == 0 ? m_pass : setting.password;
                this.m_port =         setting.port;
                this.m_protocol =     setting.protocol;
                this.m_identityFile = setting.identityfile;
                this.m_destination  = setting.destination;
            }

            catch (Exception ex)
            {
                m_exception = ex;
            }
        }

        /// <summary>
        /// 
        /// </summary>
        protected virtual void Connect()
        {
        }

        public virtual void CreateDirectory(string path)
        {
        }

        public virtual bool UploadFile(string fileName)
        {
            return false;
        }

        public virtual bool UploadFile(byte[] fileContents, string fileName)
        {
            return false;
        }

        /// <summary>
        /// Get last exception thrown
        /// </summary>
        //public string error
        //{
        //    get
        //    { return error; }
        //}

        /// <summary>
        /// 
        /// </summary>
        /// <param name="data">Raw data to be zipped up</param>
        /// <param name="sourceFile"></param>
        /// <returns>Returns zip file name or null on exception thrown</returns>
        protected string Zip(string sourceFileName)
        {
            byte[] data;
            string ZipFileName  = null;
            try
            {
                data = File.ReadAllBytes(sourceFileName);
                ZipFileName = Zip(data, sourceFileName);
            }
            catch (Exception ex)
            {
                m_exception = ex;
                ZipFileName = null;
            }

            return ZipFileName;
        }

        /// <summary>
        /// 
        /// </summary>
        /// <param name="sourceFile">file name with full path of file to be zipped</param>
        /// <param name="zipFile">name of zip file</param>
        /// <returns>Returns zip file name or null on exception thrown</returns>
        //protected string Zip(string sourceFile)
        //{
        //    return Zip(new string[] { sourceFile });
        //}

        /// <summary>
        /// 
        /// </summary>
        /// <param name="sourceFile">Full path with File name(s) to be zipped</param>
        /// <param name="zipFile">name of zip file</param>
        /// <returns>Returns zip file name or null on exception thrown</returns>
        protected string Zip(byte[] data, string sourceFileName)
        {
            string zipDirectory = null;
            string tempDir = null;
            string tempFileName = "\\" + Path.GetFileName(sourceFileName);
            int position;

            try
            {
                // create temp directory from zip file name
                position = ZipFileName.ToLower().IndexOf(".zip");
                zipDirectory = (position > 0) ? ZipFileName.Substring(0, position) : ZipFileName;

                // create temp directory
                tempDir = Util.MapPath("~/Temp/", zipDirectory);
                if (Directory.Exists(tempDir)) Directory.Delete(tempDir, true);
                Directory.CreateDirectory(tempDir);

                // move files to temp directory to be zipped
                File.WriteAllBytes(tempDir + tempFileName, data);

                // create zip file
                tempFileName = tempDir.Replace('/', '\\') + ".zip";
                if (File.Exists(tempFileName)) File.Delete(tempFileName);

                System.IO.Compression.ZipFile.CreateFromDirectory(tempDir, tempFileName);

                // remove temp directory
                Directory.Delete(tempDir, true);
            }

            catch (Exception ex)
            {
                m_exception = ex;
                tempFileName = null;
            }

            return tempFileName;
        }

        //protected string Zip(byte[] data, string[] sourceFile)
        //{
        //    string zipDirectory = null;
        //    string tempDir = null;
        //    string tempFile = null;
        //    int position;

        //    try
        //    {
        //        // create temp directory from zip file name
        //        position = ZipFileName.ToLower().IndexOf(".zip");
        //        zipDirectory = ( position > 0) ? ZipFileName.Substring(0, position): ZipFileName;

        //        // create temp directory
        //        tempDir = Util.MapPath("~/Temp/", zipDirectory);
        //        if (Directory.Exists(tempDir)) Directory.Delete(tempDir, true);
        //        Directory.CreateDirectory(tempDir);

        //        // move files to temp directory to be zipped
        //        foreach (string filename in sourceFile)
        //        {
        //            string tempFilename = filename.Replace('/', '\\');
        //            File.Move(filename, tempDir + tempFilename.Substring(tempFilename.LastIndexOf("\\")));
        //        }

        //        // create zip file
        //        tempFile = tempDir.Replace('/', '\\') + ".zip";
        //        if (File.Exists(tempFile)) File.Delete(tempFile);

        //        System.IO.Compression.ZipFile.CreateFromDirectory(tempDir, tempFile);

        //        // remove temp directory
        //        Directory.Delete(tempDir, true);
        //    }

        //    catch (Exception ex)
        //    {
        //        m_exception = ex;
        //        tempFile = null;
        //    }

        //    return tempFile;
        //}

        /// <summary>
        /// Builds the path to the location of the file
        /// </summary>
        /// <param name="location">Name of the directory where files are located</param>
        /// <param name="fileName">Name of the file to Map to</param>
        /// <returns>Returns full path and filename to the a file</returns>
        //public static string MapPath(string location, string fileName)
        //{
        //    string file = null;

        //    // remove any path information from the file name
        //    if (location == null) location = System.IO.Path.GetDirectoryName(fileName);

        //    // check if consol or web application
        //    if (System.Web.Hosting.HostingEnvironment.MapPath("~/") == null)
        //    {
        //        location = location.Replace("~", "");
        //        if (location[0] == '/' || location[0] == '\\') location = location.Substring(1);
        //        file = AppDomain.CurrentDomain.BaseDirectory + location;
        //    }
        //    else
        //    {
        //        // remove any path information from the file name
        //        file = System.Web.Hosting.HostingEnvironment.MapPath(location);
        //    }

        //    file += System.IO.Path.GetFileName(fileName);

        //    return file;
        //}

        public virtual string GetDirList(string directory) { return null; }

    }
}
