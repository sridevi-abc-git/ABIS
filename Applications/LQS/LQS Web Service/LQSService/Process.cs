using System;
using System.Collections.Generic;
using System.Linq;
using System.Runtime.Serialization;
using System.ServiceModel;
using System.ServiceModel.Activation;
using System.ServiceModel.Web;
using System.Text;
using System.Configuration;

using ABCRQSUtils;
using Oracle.DataAccess.Client;
using Oracle.DataAccess.Types;
using System.Web.Script.Serialization;
using System.Xml;
using System.IO;
using System.Diagnostics;

namespace LQSService
{
    public class Process : ABCRQSUtils.OraBase
    {
        public Process() { }

        public Process(string connString, bool encripted = true)
            : base(connString, encripted)
        { }

        //System.Diagnostics.EventLog m_event = GetEventLog();
        bool m_trace = (System.Configuration.ConfigurationManager.AppSettings["trace"] == "Y" ? true : false);

        public string DatabaseAvailable()
        {
            JavaScriptSerializer serializer = new JavaScriptSerializer();
            Dictionary<string, string> results = new Dictionary<string, string>(); 
            Dictionary<string, string> data = new Dictionary<string, string>(); 
            Dictionary<string, string> init = new Dictionary<string, string>(); 
            string infoFile = Util.MapPath(@"~/App_Data/", "_info.dat");

            try
            {
               // string conn = System.Configuration.ConfigurationManager.AppSettings["connection"];

                ABCException e = base.Open();
                //ABCException e = base.Open(conn);
                Close();

                data["available"] = (e == null) ? "Y" : "N";
                data["message"] = (e == null)? "Connected" : e.Message;

                // check if information file is over a day old
                if (File.Exists(infoFile))
                {
                    if (File.GetLastWriteTime(infoFile) < DateTime.Now.AddDays(-1).Date)
                    {
                        //m_event.WriteEntry("Cleanup: File Time " + File.GetLastWriteTime(infoFile).ToString()
                        //     + " Date: " + DateTime.Now.AddDays(-1).Date,
                        //EventLogEntryType.Information, 102);
                        Cleanup();
                        Init();
                    }
                }
                else
                {
                    Init();
                }

                // check for any messages to be displayed
                init = serializer.Deserialize<Dictionary<string, string>>(File.ReadAllText(infoFile));
                //data["message"] = init["MESSAGE"];

                results["data"] = serializer.Serialize(data);
            }

            catch (Exception ex)
            {
                results["err"] = "System Error: LQS is unavailable at this time." + ex.StackTrace + "\n" + ex.Message;

                // write error event to event log
                try
                {
                    //m_event.WriteEntry(ex.Message, EventLogEntryType.Error, 102);
                }

                catch (Exception ex2)
                {
                    results["err"] += " " + ex.Message + "  " + OperationContext.Current.EndpointDispatcher.EndpointAddress.Uri.Host +
                        //"event: " + m_event.Source + ":" + m_event.Log + " - " + 
                                      ex2.Message;
                }

            }

            return serializer.Serialize(results);
        }

        public string Init()
        {
            string data;
            string infoFile = Util.MapPath(@"~/App_data/", "_info.dat");
            JavaScriptSerializer serializer = new JavaScriptSerializer();
            Dictionary<string, string> results = new Dictionary<string, string>();
            ABCException e = null;

            try
            {
                // check if information file already created
                if (File.Exists(infoFile))
                {
                    results["initinfo"] = File.ReadAllText(infoFile);
                }
                else
                {
                    // retrieve init information from the database
                    data = RetriveInfo(out e);
                    if (e == null)
                    {
                        results["initinfo"] = data;
                        File.WriteAllText(infoFile, data);
                    }
                    else
                    {
                        results["err"] = e.Message;
                    }
                }
            }

            catch (Exception ex)
            {
                results["err"] = ex.Message; // "LQS is unavailable at this time.";
            }

            return serializer.Serialize(results);
        }


        public void Cleanup()
        {
            string path;
            System.IO.DirectoryInfo di;

            try
            {
                path = Util.MapPath(@"~\App_data\", null).Replace(@"\", "/");
                di = new DirectoryInfo(path);

                foreach (FileInfo file in di.GetFiles())
                {
                    file.Delete();
                }

                //if (m_trace) m_event.WriteEntry("Files Deleted", EventLogEntryType.Information, 2);
            }

            catch (Exception ex)
            {
                //m_event.WriteEntry(ex.Message, EventLogEntryType.Error, 3);

            }
        }

        public string RetriveInfo(out ABCException e)
        {
            List<String> dataName = new List<String>() { "", "CITY", "LICENSETYPE", "COUNTY", "MESSAGE" };
            //string conn;
            int index;
            string infoFile = Util.MapPath(@"~/App_Data", "info.dat");
            JavaScriptSerializer serializer = new JavaScriptSerializer();
            Dictionary<string, string> information = new Dictionary<string, string>();
            Dictionary<string, string> data;
            OracleDataReader reader = null;

            try
            {
                e = null;

                // retrieve init information from the database
                //conn = System.Configuration.ConfigurationManager.AppSettings["connection"];
                serializer.MaxJsonLength = Int32.MaxValue;

                m_cmd.CommandText = "LQS.LISTS";
                m_cmd.Parameters.Add(new OracleParameter("p_parameters", OracleDbType.Int32, System.Data.ParameterDirection.Input));
                m_cmd.Parameters.Add(base.m_cursor);
                m_cmd.Parameters.Add(base.m_statusMsg);

                e = base.Open();
                if (e == null)
                {
                    for (index = 1; index < 5; index++)
                    {
                        data = new Dictionary<string, string>();

                        m_cmd.Parameters[0].Value = index;
                        m_cmd.ExecuteNonQuery();

                        // process the results set
                        if (((INullable)m_statusMsg.Value).IsNull)
                        {
                            if (((Oracle.DataAccess.Types.OracleRefCursor)(m_cursor.Value)).IsNull)
                            {
                                //m_ex = new ABCException(m_parameters.value("SEQ"), ABCException.MessageType.ERROR, "No data read from database", "FmtReports.RetrieveParameters()");
                            }
                            else
                            {
                                reader = ((OracleRefCursor)base.m_cursor.Value).GetDataReader();

                                switch (index)
                                {
                                    case 1:
                                    case 2:
                                    case 3:
                                        int key = reader.GetOrdinal("DESCRIPTION");
                                        int value = reader.GetOrdinal("VALUE");

                                        while (reader.Read())
                                        {
                                            // check if null parameter
                                            if (reader.IsDBNull(key) || reader.IsDBNull(value)) continue;

                                            data[reader.GetString(key)] = reader.GetString(value);
                                        }

                                        reader.Close();
                                        reader = null;
                                        break;

                                    case 4:
                                        Dictionary<string, string> line;
                                        Dictionary<string, Dictionary<string, string>> group = null;
                                        int currGroup = 0;
                                        int groupValue = 0;
                                        int groupid = reader.GetOrdinal("GROUP");
                                        int date = reader.GetOrdinal("DATE");
                                        int seq = reader.GetOrdinal("SEQ");
                                        int message = reader.GetOrdinal("MESSAGE");

                                        while (reader.Read())
                                        {
                                            groupValue = reader.GetInt32(groupid);
                                            if (currGroup != groupValue)
                                            {
                                                if (group != null)
                                                {
                                                    data[currGroup.ToString()] = serializer.Serialize(group);
                                                }

                                                group = new Dictionary<string, Dictionary<string, string>>();
                                                currGroup = groupValue;
                                            }

                                            line = new Dictionary<string, string>();
                                            line["groupid"] = reader.GetInt32(groupid).ToString();
                                            line["date"] = reader.GetString(date);
                                            line["seq"] = reader.GetString(seq);
                                            line["message"] = reader.GetString(message);
                                            group[reader.GetString(seq)] = line;

                                        }

                                        data[currGroup.ToString()] = serializer.Serialize(group);

                                        reader.Close();
                                        reader = null;
                                        break;

                                }

                                // serialize process data
                                information[dataName[index]] = serializer.Serialize(data);
                            }
                        }
                    }
                }
            }

            catch (Exception ex)
            {
                e = new ABCException(ex.Message, null);
            }

            finally
            {
                m_conn.Close();
            }

            return serializer.Serialize(information);
        }


        public string LicenseRequest(string data)
        {
            byte[] rawData;
            OracleBlob blob;
            Dictionary<string, string> results = new Dictionary<string, string>();
            Dictionary<string, string> dataOut = new Dictionary<string, string>();
            JavaScriptSerializer serializer = new JavaScriptSerializer();
            OracleParameter output = new OracleParameter("p_reportdata", OracleDbType.Blob, System.Data.ParameterDirection.Output);
            ABCException e = null;
            XmlDocument doc = new XmlDocument();
            string info = "";
            string infoFile = Util.MapPath(@"~/App_data/", "_info.dat");

            try
            {
                serializer.MaxJsonLength = Int32.MaxValue;

                // check if information file is over a day old
                if (File.Exists(infoFile))
                {
                    if (File.GetLastWriteTime(infoFile) < DateTime.Now.AddDays(-1).Date)
                    {
                        //m_event.WriteEntry("Cleanup: File Time " + File.GetLastWriteTime(infoFile).ToString()
                        //                         + " Date: " + DateTime.Now.AddDays(-1).Date,
                        //                    EventLogEntryType.Information, 102);
                        Cleanup();
                        Init();
                    }
                }
                else
                {
                    Init();
                }

                //string conn = System.Configuration.ConfigurationManager.AppSettings["connection"];
                m_cmd.CommandText = "LQS.MAIN";
                m_cmd.Parameters.Add(new OracleParameter("p_parameters", OracleDbType.XmlType, data.Length, data, System.Data.ParameterDirection.Input));
                m_cmd.Parameters.Add(output);
                m_cmd.Parameters.Add(base.m_statusMsg);

                e = base.Open();
                if (e == null)
                {
                    m_cmd.ExecuteNonQuery();

                    // process the results set
                    if (((INullable)m_statusMsg.Value).IsNull)
                    {
                        // get xml from output parameter
                        blob = (OracleBlob)output.Value;
                        rawData = new byte[blob.Length];
                        blob.Read(rawData, 0, System.Convert.ToInt32(blob.Length));
                        info = System.Text.Encoding.Default.GetString(rawData);
                    }
                    else
                    {
                        results["err"] = m_statusMsg.Value.ToString();
                    }
                }
                else
                {
                    results["err"] = "LQS is unavailable at this time.";

                    // write error event to event log

                }

                Close();
            }

            catch (Exception ex)
            {
                results["err"] = ex.Message + "<br/>" + ex.StackTrace + "<br/>" + OperationContext.Current.EndpointDispatcher.EndpointAddress.Uri.Host; ; // "LQS is unavailable at this time.";

                // write error event to event log
                //m_event.WriteEntry(ex.Message, EventLogEntryType.Error, 4);

            }
            return (info.Length > 0) ? info : serializer.Serialize(results);
        }

        static public System.Diagnostics.EventLog GetEventLog()
        {
            System.Diagnostics.EventLog eventLog = new System.Diagnostics.EventLog();

            eventLog.Source = ConfigurationManager.AppSettings["log source"];
            eventLog.Log = ConfigurationManager.AppSettings["log"];

            return eventLog;
        }

    }
}

