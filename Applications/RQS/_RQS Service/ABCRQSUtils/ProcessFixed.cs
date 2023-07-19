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
using Microsoft.VisualBasic.FileIO;

using System.Web.Script.Serialization;
using System.Text.RegularExpressions;


namespace ABCRQSUtils
{
	class ProcessFixed
	{
		Dictionary<string, string>	parameters;

		public ProcessFixed(Dictionary<string, string> parameters)
		{
			this.parameters = parameters;
		}

		public byte[] Process(object reportData, out ABCException e)
		{
			byte[]			data		= null;
			string			outputType;
			string			rawData;

			e = null;
			// process raw report data by output type
			if (reportData is OracleDataReader)
			{
				// get raw data type
				rawData = ((OracleDataReader)reportData).GetString(((OracleDataReader)reportData).GetOrdinal("DATA_FORMAT"));
				parameters["INPUT_TYPE"] = rawData;
			}
			else
			{
				parameters.TryGetValue("INPUT_TYPE", out rawData);
			}

			parameters.TryGetValue("OUTPUT_TYPE", out outputType);
			switch (outputType)
			{
				case "PDF":
				case "WORD":
					throw new NotImplementedException();
					//data = (reportData is OracleDataReader) ?
					//			CSVtoPDF((OracleDataReader)reportData, parameters, out e) :
					//			CSVtoPDF((string)reportData, parameters, out e);
					//break;

				case "HTML":
				case "TEXT":
					throw new NotImplementedException();
					//strOutput = (reportData is OracleDataReader) ?
					//			CSVtoHTML((OracleDataReader)reportData, parameters, out e) :
					//			CSVtoHTML((string)reportData, parameters, out e);

					// convert string to byte
					//if (strOutput != null) data = Encoding.UTF8.GetBytes(strOutput);
					//break;

				case "EXCEL":
					data = new ProcessCSV(parameters).Process(reportData, out e);
					break;

				case "CSV":
					data = (reportData is OracleDataReader) ?
								FixtoCSV((OracleDataReader)reportData, parameters, out e) :
								FixtoCSV((byte[])reportData, parameters, out e);
					break;
					
				case "FIX":
					// get raw data from reportData
					if (reportData is OracleDataReader)
					{
						reportData = ((OracleDataReader)reportData).GetOracleBlob(((OracleDataReader)reportData).GetOrdinal("REPORT_DATA"));
					}

					data = (byte[])reportData;
					break;

				case "XML":
					throw new NotImplementedException();
					//break;

				default:
					throw new NotImplementedException();
					//break;

			}

			return data;
		}

		public byte[] FixtoCSV(OracleDataReader reader, Dictionary<string, string> args, out ABCException e)
		{
			byte[] data= reader.GetOracleBlob(reader.GetOrdinal("REPORT_DATA")).Value;

			return FixtoCSV(data, args, out e);
		}

		public byte[] FixtoCSV(byte[] fixData, Dictionary<string, string> args, out ABCException e)
		{
			Dictionary<string, Dictionary<string, Dictionary<string, string>>>	configInfo		= null;
			JavaScriptSerializer												jss				= new JavaScriptSerializer();
			Dictionary<string, Dictionary<string, string>>						columnsDef		= null;
			Dictionary<string, Dictionary<string, string>>						headingDef;
			Stream																fixStream		= new MemoryStream(fixData);
			TextFieldParser														reader			= null;
			List<int>															widths			= new List<int>();
			string																configFile;
			string[]															items;
			StringBuilder														csvData			= new StringBuilder();
			int																	column			= 0;

			e = null;

			if (args.TryGetValue("FIX", out configFile))
			{
				configFile = Util.MapPath(@"~\Formats\", configFile);
				if (File.Exists(configFile))
				{
					configInfo = jss.Deserialize<Dictionary<string, Dictionary<string, Dictionary<string, string>>>>(File.ReadAllText(configFile));
				}
			}

			if (configInfo.TryGetValue("COLUMNS", out columnsDef))
			{
				string		pos;

				// build postion array
				foreach (KeyValuePair<string, Dictionary<string, string>> item in columnsDef)
				{
					if (item.Value.TryGetValue("WIDTH", out pos))
					{
						widths.Add(Convert.ToInt32(pos));
					}
				}
			}

			// add headings to csv output file if configured
			if (configInfo.TryGetValue("HEADINGS", out headingDef))
			{
				foreach (KeyValuePair<string, Dictionary<string, string>> columnInfo in headingDef)
				{
					foreach (KeyValuePair<string, string> format in columnInfo.Value)
					{
						switch (format.Key)
						{
							case "TEXT":
								if (column++ != 0) csvData.Append(",");
								csvData.Append("\"" + format.Value + "\"");
								break;
						}
					}
				}
				csvData.Append("\r\n");
			}

			reader = new TextFieldParser(fixStream);
			reader.TextFieldType = FieldType.FixedWidth;
			reader.SetFieldWidths(widths.ToArray());

			while ((items = reader.ReadFields()) != null)
			{
				csvData.Append("\"" + String.Join("\",\"", items) + "\"\r\n"); 
			}

			return Encoding.ASCII.GetBytes(csvData.ToString());
		}

	}
}
