using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

using System.Text.RegularExpressions;
using System.IO;
using System.Security.Permissions;
using System.Net;
using System.Diagnostics;
using Oracle.DataAccess.Client;
using Oracle.DataAccess.Types;
using Microsoft.VisualBasic.FileIO;
using System.Web.Script.Serialization;

namespace ABCUploadService
{
    class UploadCSV
    {
        static EventLog m_event = Program.GetEventLog();
        static bool m_trace = (System.Configuration.ConfigurationManager.AppSettings["trace"] == "Y" ? true : false);

        static public void OnChanged(object source, FileSystemEventArgs e)
        {
            UploadCSV.Upload(e.FullPath);
        }

        static public void StartUp(string pPath, string pFilter)
        {
            DirectoryInfo d = new DirectoryInfo(pPath); //Assuming Test is your Folder

            FileInfo[] Files = d.GetFiles(pFilter); //Getting Text files

            foreach (FileInfo file in Files)
            {
                Upload(file.FullName);
            }
        }

        static public void Upload(string pFile)
        {
            byte[] data;
            string connectionString = System.Configuration.ConfigurationManager.AppSettings["connection"];
            int count;
            int retry = 3;

            if (!File.Exists(pFile)) return;
            if (m_trace)
            {
                m_event.WriteEntry("File to Upload: " + pFile, EventLogEntryType.Information, 1);
                Console.WriteLine("File to Upload: " + pFile);
            }

            OracleConnection conn = new OracleConnection(connectionString); ;
            OracleCommand cmd = conn.CreateCommand();

            try
            {
                System.Threading.Thread.Sleep(5000);

                data = File.ReadAllBytes(pFile);
                while (conn.State == System.Data.ConnectionState.Closed && retry > 0)
                {
                    try
                    {
                        conn.Open();
                    }
 
                    catch (OracleException oe)
                    {
                        retry--;

                        string msg = "Error: " + oe.Message + "  \n"
                                     + "Stack: " + oe.StackTrace;

                        m_event.WriteEntry(msg, EventLogEntryType.Error, 2);
                        Console.WriteLine(msg);
                        Console.WriteLine(cmd.CommandText);
                        System.Threading.Thread.Sleep(30000);
                    }
                }

                if (conn.State == System.Data.ConnectionState.Open)
                {
                    // upload file data
                    cmd.CommandType = System.Data.CommandType.StoredProcedure;
                    cmd.CommandText = @"BIZMOD_API.ESERVICES";
                    cmd.Parameters.Add("Return_Value", OracleDbType.Clob, System.Data.ParameterDirection.ReturnValue);

                    cmd.Parameters.Add("a_packet", OracleDbType.Clob).Value = "{\"PACKET_TYPE\":\"UPLOADFIRSTDATA\",\"FILE_NAME\":\"" + Path.GetFileName(pFile) + "\"}";
                    cmd.Parameters.Add("a_filedata", OracleDbType.Blob).Value = data;
                    count = cmd.ExecuteNonQuery();

                    conn.Close();
                    File.Delete(pFile);
                }
            }

            catch (Exception ex)
            {
                string msg = "Error: " + ex.Message + "  \n"
                             + "Stack: " + ex.StackTrace;

                m_event.WriteEntry(msg, EventLogEntryType.Error, 2);
                Console.WriteLine(msg);
                Console.WriteLine(cmd.CommandText);
            }
        }
    }
}
