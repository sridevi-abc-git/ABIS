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
            UploadCSV.Save(e.FullPath);
        }

        static public void Save(string pFile)
        {
            JavaScriptSerializer js = new JavaScriptSerializer();

            string json = File.ReadAllText(AppDomain.CurrentDomain.BaseDirectory + @"\" + System.Configuration.ConfigurationManager.AppSettings["configuration"]);
            Dictionary<string, Dictionary<string, string>[]> configuration = js.Deserialize<Dictionary<string, Dictionary<string, string>[]>>(json);

            string stmt = configuration["Table"][0]["Insert"];

            Dictionary<string, string>[] columns = configuration["Fields"];
            TextFieldParser reader = null;
            byte[] data;
            Stream csvStream;
            string[] items;

            string columnData = "";
            string columnName = "";
            string sql;

            string connectionString = System.Configuration.ConfigurationManager.AppSettings["connection"];
            int totalRows = 0;
            int rowsUpdated = 0;
            int count;

            if (!File.Exists(pFile)) return;
            if (m_trace) m_event.WriteEntry("File to Upload: " + pFile, EventLogEntryType.Information, 1);

            OracleConnection conn = new OracleConnection(connectionString); ;
            OracleCommand cmd = conn.CreateCommand();

            try
            {
                cmd.CommandType = System.Data.CommandType.Text;

                System.Threading.Thread.Sleep(5000);

                data = File.ReadAllBytes(pFile);
                File.Delete(pFile);

                csvStream = new MemoryStream(data);

                reader = new TextFieldParser(csvStream);
                reader.Delimiters = new string[] { @"," };
                reader.HasFieldsEnclosedInQuotes = true;

                // do not process header row of CSV
                items = reader.ReadFields();

                conn.Open();


                while ((items = reader.ReadFields()) != null)
                {
                    columnData = "";
                    columnName = "";
                    totalRows++;

                    foreach (Dictionary<string, string> column in columns)
                    {
                        int columnNumber = Convert.ToInt16(column["ColumnNumber"]) - 1;
                        string columntype = column["ColumnType"];
                        DateTime dt;

                        string value = items[columnNumber];

                        if (value.Length == 0) continue;

                        if (column.ContainsKey("regexp_substr"))
                        {
                            Match match = Regex.Match(value, column["regexp_substr"]);
                            value = (match.Success ? match.Groups[1].Value : value);
                        }

                        if (column.ContainsKey("regexp_replace"))
                        {
                            value = Regex.Replace(value, column["regexp_replace"], "");
                        }

                        switch (column["ColumnType"])
                        {
                            case "Double":
                                value = Convert.ToDouble(value).ToString();
                                break;

                            case "DateTime":
                                dt = DateTime.Parse(value);
                                value = "to_date('" + dt.ToString("yyyy-MM-dd HH:mm:ss") + "','yyyy-mm-dd HH24:mi:ss')";
                                break;

                            default:
                                value = "'" + value + "'";
                                break;
                        }

                        columnData += (columnData.Length > 0 ? "," + value : value);
                        columnName += (columnName.Length > 0 ? "," + column["ColumnName"] : column["ColumnName"]);

                    }

                    sql = stmt.Replace("<fields>", columnName).Replace("<values>", columnData);
                    cmd.CommandText = sql;
                    count = cmd.ExecuteNonQuery();

                    rowsUpdated += count;

                }

                // create job to process uploaded data
                cmd.CommandType = System.Data.CommandType.StoredProcedure;
                cmd.CommandText = @"Bizmod_api.createjob";
                cmd.Parameters.Add("a_procedure", OracleDbType.Varchar2).Value = "PROCESSPAYMENTS";
                cmd.Parameters.Add("a_description", OracleDbType.Varchar2).Value = "Process Payments";    
                count = cmd.ExecuteNonQuery();

                conn.Close();

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
