using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.IO;
using System.Security.Permissions;
using System.Net;
//using ABCRQSUtils;
using System.Diagnostics;
using Oracle.DataAccess.Client;
using Oracle.DataAccess.Types;
using Microsoft.VisualBasic.FileIO;
using System.Web.Script.Serialization;

namespace ABCUploadService
{
    class Upload
    {
        EventLog                             m_event = Program.GetEventLog();
        bool                                 m_trace = (System.Configuration.ConfigurationManager.AppSettings["trace"] == "Y" ? true : false);

        [PermissionSet(SecurityAction.Demand, Name = "FullTrust")]
        public Upload()
        {
            string              path    = MapPath("~/Upload", null);
            FileSystemWatcher   watcher = new FileSystemWatcher();

            // get configuration information
            watcher.Path = path;

            /* Watch for changes in LastAccess and LastWrite times, and
               the renaming of files or directories. */
            watcher.NotifyFilter = NotifyFilters.LastAccess | NotifyFilters.LastWrite
                                 | NotifyFilters.FileName | NotifyFilters.DirectoryName;
            // Only watch text files.
            watcher.Filter = System.Configuration.ConfigurationManager.AppSettings["filter"]; 

            // Add event handlers.
            watcher.Created += new FileSystemEventHandler(UploadCSV.OnChanged);
            watcher.Changed += new FileSystemEventHandler(UploadCSV.OnChanged);

            // Begin watching.
            watcher.EnableRaisingEvents = true;

            m_event.WriteEntry(path + "\n" + watcher.Filter, EventLogEntryType.Information, 0);
            Console.WriteLine(path);
            Console.WriteLine(watcher.Filter);

        }

        public static string MapPath(string location, string fileName)
        {
            string file = null;

            // remove any path information from the file name
            if (location == null) location = System.IO.Path.GetDirectoryName(fileName);

            // check if consol or web application
            if (System.Web.Hosting.HostingEnvironment.MapPath("~/") == null)
            {
                location = location.Replace("~", "");
                if (location[0] == '/' || location[0] == '\\') location = location.Substring(1);
                file = AppDomain.CurrentDomain.BaseDirectory + location;
            }
            else
            {
                // remove any path information from the file name
                file = System.Web.Hosting.HostingEnvironment.MapPath(location);
            }

            file += System.IO.Path.GetFileName(fileName);

            return file;
        }

    
    }
}

