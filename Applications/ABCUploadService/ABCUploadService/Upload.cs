using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
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
    class Upload
    {
        EventLog                             m_event = Program.GetEventLog();
        bool                                 m_trace = (System.Configuration.ConfigurationManager.AppSettings["trace"] == "Y" ? true : false);

        [PermissionSet(SecurityAction.Demand, Name = "FullTrust")]
        public Upload()
        {
            FileSystemWatcher   watcher = new FileSystemWatcher();

            // get configuration information
            watcher.Path = System.Configuration.ConfigurationManager.AppSettings["path"]; // path;

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

            m_event.WriteEntry(watcher.Path + "\n" + watcher.Filter, EventLogEntryType.Information, 0);
            Console.WriteLine(watcher.Path);
            Console.WriteLine(watcher.Filter);

            UploadCSV.StartUp(watcher.Path, watcher.Filter);
        }
    }
}

