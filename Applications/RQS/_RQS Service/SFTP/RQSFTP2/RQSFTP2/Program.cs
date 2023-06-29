using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace RQSFTP2
{
    class Program
    {
        static void Main(string[] args)
        {
            //Renci.SshNet.SftpClient sftpClient;



            //sftpClient = new Renci.SshNet.SftpClient("165.235.134.50", 2222, "abc_license_in_test", "s!$=$pL]FH4N3scn");

            //sftpClient.Connect();
            //sftpClient.ChangeDirectory("/from ABC/");

            RQSFTP2 ftp;
            Dictionary<string, string> parameters = new Dictionary<string, string>();

            parameters["TNSNAME"] = "ftp";
            parameters["REPORT_NAME"] = "CDTFA";
            //parameters["REPORT_NAME"] = "TEST";
            parameters["FILE_NAME"] = "test.txt";

            ftp = new RQSFTP2(parameters);


            //            FTPBase ftp;
            byte[] info = ASCIIEncoding.UTF8.GetBytes("This is a test");
            string file = ABCRQSUtils.Util.MapPath("~/", "test_ssh.txt");
            System.IO.File.WriteAllBytes(file, info);

            //using (var fileStream = new System.IO.FileStream(file, System.IO.FileMode.Open))
            //{
            //    sftpClient.BufferSize = 4 * 1024;
            //    sftpClient.UploadFile(fileStream, System.IO.Path.GetFileName(file));
            //}

            //IEnumerable<Renci.SshNet.Sftp.SftpFile> data = sftpClient.ListDirectory(".");
//            Renci.SshNet.Sftp.SftpFile data2 = sftpClient.ListDirectory(".");

//            //ftp = new FTPSSH("ftp", "CDTFA");
//            //ftp.ZipFile = "TEXT";

//            //ftp.Connect();
//            //ftp.CreateDirectory();

            string list = ftp.GetDirList();

            ftp.UploadFile(file, info);

            string list2 = ftp.GetDirList();

        }
    }
}
