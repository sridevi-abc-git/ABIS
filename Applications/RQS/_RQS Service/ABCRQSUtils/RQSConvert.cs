/****************************************************************************
	File:		RQSConvert.cs
	Author:		Timothy J. Lord

	Description:

    $Rev: 51 $  
    $Date: 2018-09-01 12:02:56 -0700 (Sat, 01 Sep 2018) $
    Last Changed By:  $Author: TLord $

*****************************************************************************
	09/13/2015			Initial File Created
 03/04/2016  TJL  9131  Removed unused code and renamed class variables
*****************************************************************************/
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

using System.IO;
using System.Xml;
using System.Xml.Xsl;
using System.Configuration;
using Oracle.DataAccess.Client;
using Oracle.DataAccess.Types;
using Microsoft.Office.Interop.Word;
using Word = Microsoft.Office.Interop.Word;

namespace ABCRQSUtils
{
	public class RQSConvert
	{
		Dictionary<string, string> 		m_parameters;
		private ABCException			m_e				= null;

		public ABCException err { get { return m_e; } }

		public RQSConvert (Dictionary<string, string> parameters)
		{
			this.m_parameters = parameters;
		}

		public byte[] Process(object reportData)
		{
			string			raw_data_type;
			byte[]			data			= null;

			if (reportData is OracleDataReader)
			{
				// get raw data type
				raw_data_type = ((OracleDataReader) reportData).GetString(((OracleDataReader) reportData).GetOrdinal("DATA_FORMAT"));
				m_parameters["INPUT_TYPE"] = raw_data_type;
			}
			else
			{
				m_parameters.TryGetValue("INPUT_TYPE", out raw_data_type);
			}

			switch (raw_data_type)
			{
				case "CSV":
					ProcessCSV processCSV = new ProcessCSV(m_parameters);
					data = processCSV.Process(reportData, out m_e);
					break;

				case "XML":
					ProcessXML processXML = new ProcessXML(m_parameters);
					data = processXML.Process(reportData, out m_e);
					break;

				case "TEXT":
					data = ProcessText(reportData);
					break;

				case "FIX":
					data = new ProcessFixed(m_parameters).Process(reportData, out m_e);
					break;

				default:
					// log not supported input
					m_e = new ABCException(m_parameters["SEQ"], ABCException.MessageType.ERROR, "Unsupported data type (" + raw_data_type + ")");
					break;
			}

			return data;
		}

		protected byte[] ProcessText(object reportData)
		{
            // get raw data from reportData
            if (reportData is OracleDataReader)
            {
                reportData = ((OracleDataReader)reportData).GetOracleBlob(((OracleDataReader)reportData).GetOrdinal("REPORT_DATA"));
            }

            return (byte[])reportData;
//            throw new NotImplementedException();
		}

	}
}
