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

//using Microsoft.Office.Interop.Word;
//using Word = Microsoft.Office.Interop.Word;

//using Microsoft.VisualBasic.FileIO;
using Microsoft.Office.Interop.Excel;
using Excel = Microsoft.Office.Interop.Excel;
using System.Web.Script.Serialization;
using System.Text.RegularExpressions;

namespace ABCRQSUtils
{
	class ProcessCSV
	{
		Dictionary<string, string>	parameters;

		public ProcessCSV(Dictionary<string, string> parameters)
		{
			this.parameters = parameters;
		}

		public byte[] Process(object reportData, out ABCException e)
		{
			byte[]			data		= null;
			string			outputType;
            string          enhanced;

			e = null;
			// process raw report data by output type
			parameters.TryGetValue("OUTPUT_TYPE", out outputType);
			switch (outputType)
			{
				case "PDF":
				case "WORD":
				case "HTML":
					// convert csv to xml
					data = (reportData is OracleDataReader) ?
								CSVtoXML((OracleDataReader)reportData, parameters, out e) :
								CSVtoXML((byte[])reportData, parameters, out e);

					if (e == null)
					{
						parameters["INPUT_TYPE"] = "XML";

						// call the xml to pdf process class
						data = (new ProcessXML(parameters)).Process(data, out e);
					}
					break;

				//case "TEXT":
					//strOutput = (reportData is OracleDataReader) ?
					//			CSVtoHTML((OracleDataReader)reportData, parameters, out e) :
					//			CSVtoHTML((string)reportData, parameters, out e);

					// convert string to byte
					//if (strOutput != null) data = Encoding.UTF8.GetBytes(strOutput);
				//	break;

				case "EXCEL":
                    if (!parameters.TryGetValue("ENHANCED", out enhanced)) enhanced = "N";
                    if (enhanced == "N")
					    data = (reportData is OracleDataReader) ?
								    CSVtoEXCEL((OracleDataReader)reportData, parameters, out e) :
								    CSVtoEXCEL((byte[])reportData, parameters, out e);
                    else
                        data = (reportData is OracleDataReader) ?
                                    CSVtoEXCEL2((OracleDataReader)reportData, parameters, out e) :
                                    CSVtoEXCEL2((byte[])reportData, parameters, out e);
					break;


                case "CSV":
					// get raw data from reportData
//					rawData = ((OracleDataReader)reportData).GetString(((OracleDataReader)reportData).GetOrdinal("REPORT_DATA"));
//					data = Encoding.UTF8.GetBytes(rawData);
					data = (byte[]) reportData;
					break;

				case "XML":
					data = (reportData is OracleDataReader) ?
								CSVtoXML((OracleDataReader)reportData, parameters, out e) :
								CSVtoXML((byte[])reportData, parameters, out e);
					break;
				default:
					e = new ABCException(parameters["SEQ"], ABCException.MessageType.ERROR, "Unsupported output type (" + outputType + ")", "ProcessCSV");
					break;

			}

			return data;
		}

		public byte[] CSVtoEXCEL(OracleDataReader reader, Dictionary<string, string> args, out ABCException e)
		{
			byte[] csvData= reader.GetOracleBlob(reader.GetOrdinal("REPORT_DATA")).Value;

			return CSVtoEXCEL(csvData, args, out e);
		}

		public byte[] CSVtoEXCEL(byte[] csvData, Dictionary<string, string> args, out ABCException e)
		{
			Dictionary<string, Dictionary<string, Dictionary<string, string>>>	configInfo		= null;
			Dictionary<string, Dictionary<string, string>>						columnsDef		= null;
            JavaScriptSerializer												jss				= new JavaScriptSerializer();

			Application		xlApp			= null;
			Workbook		xlWorkBook		= null;
			Worksheet		xlWorkSheet		= null;
			QueryTable		tbl				= null;
			string			path            = null;
            string          sheetName      = null;
			string			configFile;
			bool			containsHeadings	= false;
			byte[]			data			= null;
			string			tmp;
			string			inputDataType	= "CSV";
			Int32			freezeRows		= 1;
			Range			range;

            System.Diagnostics.EventLog eventLog = new System.Diagnostics.EventLog();

            eventLog.Source = ConfigurationManager.AppSettings["log source"];
            eventLog.Log = ConfigurationManager.AppSettings["log"];

            eventLog.WriteEntry("starting excel formatting", System.Diagnostics.EventLogEntryType.Information, 11);
			e = null;

            try
            {
				//****************************************************************************
				// Get configuration info Initialze Excel
				//****************************************************************************
				if (!args.TryGetValue("INPUT_TYPE", out inputDataType))
				{
					inputDataType = "CSV";
				}

				if (args.TryGetValue(inputDataType, out configFile))
				{
					configFile = Util.MapPath(@"~\Formats\", configFile);
					if (File.Exists(configFile))
					{
						configInfo = jss.Deserialize<Dictionary<string, Dictionary<string, Dictionary<string, string>>>>(File.ReadAllText(configFile));
					}
				}

				if (args.TryGetValue("HEADING_ROW", out tmp)) containsHeadings = tmp == "Y"? true: false;

                // get sheet name for tab
                args.TryGetValue("SHEETNAME", out sheetName);

                xlApp = new Application();
                    xlApp.Visible	= false;
                    xlWorkBook		= xlApp.Workbooks.Add(XlWBATemplate.xlWBATWorksheet);
                    xlWorkSheet		= xlWorkBook.Worksheets[1];
                    xlWorkSheet.Select();

                if (sheetName != null) xlWorkSheet.Name = sheetName;

				//****************************************************************************
				// Process CSV or FIXED to excel
				//****************************************************************************
				// create path and save data to temp file for excel to import
				path = Util.MapPath("~/Temp/", parameters["SEQ"] + ".txt");

				if (csvData == null)
				{
					File.WriteAllText(path, "".PadRight(10));
				}
				else
				{
					if (csvData.Length == 0)
					{
						File.WriteAllText(path, "".PadRight(10));
					}
					else
					{
						// save data to file
						File.WriteAllBytes(path, csvData);
					}
				}

				tbl = xlWorkSheet.QueryTables.Add("TEXT;" + path, xlWorkSheet.get_Range("A1"));
				
				if (inputDataType == "FIX")
				{
					if (configInfo.TryGetValue("COLUMNS", out columnsDef))
					{
						List<int>	widths = new List<int>();
						string		pos;

						// build postion array
						foreach (KeyValuePair<string, Dictionary<string, string>> item in columnsDef)
						{
							if (item.Value.TryGetValue("WIDTH", out pos))
							{
								widths.Add(Convert.ToInt32(pos));
							}
						}

						tbl.TextFileParseType = XlTextParsingType.xlFixedWidth;
						tbl.TextFileFixedColumnWidths = widths.ToArray();
					}
				}
				else
				{
					tbl.TextFileParseType = XlTextParsingType.xlDelimited;
					tbl.TextFileCommaDelimiter = true;
				}

				tbl.Refresh();
				File.Delete(path);

				if (configInfo != null)
				{
					// format columns
					FormatHeadingColumns(xlWorkSheet,
									     //columnNames,
									     configInfo,
									     containsHeadings);
					freezeRows += 1;

					if (configInfo.TryGetValue("HEADER", out columnsDef))
					{
						FormatHeader(xlWorkSheet,
									 columnsDef,
									 args,
									 containsHeadings);
						freezeRows += 1;
					}
				}

				if (freezeRows > 1)
				{
					// freeze headings
					range = (Range)xlWorkSheet.Rows[freezeRows];
					range.Select();
					xlApp.ActiveWindow.FreezePanes = true;
				}

				path = Util.MapPath("~/Temp/", parameters["SEQ"] + ".xlsx");
                eventLog.WriteEntry("Save As: " + path, System.Diagnostics.EventLogEntryType.Information, 12);

				xlApp.DisplayAlerts = false;
                xlWorkBook.SaveAs(path, XlFileFormat.xlWorkbookDefault, Type.Missing, Type.Missing, true, false, XlSaveAsAccessMode.xlNoChange, XlSaveConflictResolution.xlLocalSessionChanges, Type.Missing, Type.Missing);
				xlWorkBook.Close();

				new ABCException(parameters["SEQ"], ABCException.MessageType.TRACE, "Completed ", "ProcessCSV.CSVtoEXCEL");

				data = File.ReadAllBytes(path);
				File.Delete(path);
			}

            catch (Exception ex)
            {
                eventLog.WriteEntry(ex.Message + " \n" + ex.StackTrace + "\n" + path, System.Diagnostics.EventLogEntryType.Error, 12);
                Console.WriteLine(ex.Message);
                Console.WriteLine(ex.StackTrace);
                ex.Data["PATH"] = path;
				e = new ABCException(parameters["SEQ"] + "::" + path, ex);
            }

			finally
			{
				if (xlApp != null)
				{
					xlApp.DisplayAlerts = false;
					xlApp.Quit();
					System.Runtime.InteropServices.Marshal.ReleaseComObject(xlApp);
					xlApp = null;
				}
			}

			return data;
        }


		private void FormatHeader(Worksheet xlWorkSheet,
								  Dictionary<string, Dictionary<string, string>> columnsDef,
								  Dictionary<string, string> args, 
								  bool containsHeadings)
		{

			// add header row
			xlWorkSheet.Rows[1].Insert();

			foreach (KeyValuePair<string, Dictionary<string, string>> headerItem in columnsDef)
			{
				Range	range;
				string	columnNumberStart;
				string	columnNumberEnd;
				string  value;

				if (!headerItem.Value.TryGetValue("START", out columnNumberStart)) columnNumberStart = "1";
				headerItem.Value.TryGetValue("END", out columnNumberEnd);

				if (columnNumberEnd == null)
				{
					range = (Range)xlWorkSheet.Cells[1, Convert.ToInt32(columnNumberStart)];
				}
				else
				{
					range = (Range)xlWorkSheet.Range[xlWorkSheet.Cells[1, Convert.ToInt32(columnNumberStart)],
													 xlWorkSheet.Cells[1, Convert.ToInt32(columnNumberEnd)]];
					range.Merge();
				}
				
				// add value and see if replacement tag is available
				if (!headerItem.Value.TryGetValue("TEXT", out value)) continue;  // missing data
				if (value.IndexOf("<<") > -1)
				{
					MatchCollection tags = Regex.Matches(value, "(<<)(?<tags>.*?)(>>)");
					foreach(Match match in tags)
					{
						string tag = match.Groups["tags"].Value;
						string item;

						// get value for tag from arguments
						if (args.TryGetValue(tag, out item))
						{
							value = Regex.Replace(value, "<<" + tag + ">>", item);
						}
					}
				}
				
				range.Value = value;

				foreach (KeyValuePair<string, string> format in headerItem.Value)
				{
					switch (format.Key)
					{
						case "FORMAT":
							range.NumberFormat = format.Value;
							break;

						case "JUSTIFIED":
							range.HorizontalAlignment = (format.Value == "CENTER") ? Excel.XlHAlign.xlHAlignCenter :
														format.Value == "RIGHT" ? Excel.XlHAlign.xlHAlignRight : Excel.XlHAlign.xlHAlignLeft;
							break;
					}
				}
			}
		}


		private void FormatHeadingColumns(Worksheet xlWorkSheet,
										 // List<string> columnNames,
										  Dictionary<string, Dictionary<string, Dictionary<string, string>>> configInfo,
										  bool containsHeadings)
		{
			Dictionary<string, Dictionary<string, string>> headingDef;
			Dictionary<string, Dictionary<string, string>> columnsDef;
			int column = 1;

			if (configInfo.TryGetValue("HEADINGS", out headingDef))
			{
				// check if heading row need to be added
				if (!containsHeadings) xlWorkSheet.Rows[1].Insert();

				foreach (KeyValuePair<string, Dictionary<string, string>> columnInfo in headingDef)
				{
					int columnNumber = (columnInfo.Value.ContainsKey("COLUMN_NUMBER")) ? Convert.ToInt32(columnInfo.Value["COLUMN_NUMBER"]) : column++;
					Range	range    = (Range)xlWorkSheet.Cells[1, columnNumber];

					if (!columnInfo.Value.ContainsKey("LENGTH"))
					{
						// setup default behavior for column when length is not specified
						range.WrapText = false;
						range.Columns.AutoFit();
					}

					foreach (KeyValuePair<string, string> format in columnInfo.Value)
					{
						switch (format.Key)
						{
							case "TEXT":
								if (!containsHeadings) xlWorkSheet.Cells[1, columnNumber].Value = format.Value;
								break;

							case "FORMAT":
								range.EntireColumn.NumberFormat = format.Value;
								break;

							case "LENGTH":
								int length;
								range.EntireColumn.WrapText = true;

								length = Convert.ToInt32(format.Value);
								range.EntireColumn.ColumnWidth = (length < 256) ? length : 255;
								break;

							case "JUSTIFIED":
								range.HorizontalAlignment = (format.Value == "CENTER") ? Excel.XlHAlign.xlHAlignCenter :
															format.Value == "RIGHT" ? Excel.XlHAlign.xlHAlignRight : Excel.XlHAlign.xlHAlignLeft;
								break;
						}
					}
				}
			}

			if (configInfo.TryGetValue("COLUMNS", out columnsDef))
			{
				column = 1;

				foreach (KeyValuePair<string, Dictionary<string, string>> columnInfo in columnsDef)
				{
					int columnNumber = (columnInfo.Value.ContainsKey("COLUMN_NUMBER")) ? Convert.ToInt32(columnInfo.Value["COLUMN_NUMBER"]) : column++;
					Range	range    = (Range)xlWorkSheet.Range[xlWorkSheet.Cells[2, columnNumber],
																xlWorkSheet.Cells[xlWorkSheet.UsedRange.Rows.Count, columnNumber]];

					foreach (KeyValuePair<string, string> format in columnInfo.Value)
					{
						switch (format.Key)
						{
							case "FORMAT":
								range.NumberFormat = format.Value;
								break;

							case "JUSTIFIED":
								range.HorizontalAlignment = (format.Value == "CENTER") ? Excel.XlHAlign.xlHAlignCenter :
															format.Value == "RIGHT" ? Excel.XlHAlign.xlHAlignRight : Excel.XlHAlign.xlHAlignLeft;
								break;
						}
					}
				}
			}
		}


		//***************************************************************************************************
		//
		//***************************************************************************************************
        public byte[] CSVtoEXCEL2(OracleDataReader reader, Dictionary<string, string> args, out ABCException e)
        {
            byte[] csvData = reader.GetOracleBlob(reader.GetOrdinal("REPORT_DATA")).Value;

            return CSVtoEXCEL2(csvData, args, out e);
        }

        public byte[] CSVtoEXCEL2(byte[] csvData, Dictionary<string, string> args, out ABCException e)
        {
            Dictionary<string, Dictionary<string, Dictionary<string, string>>> configInfo = null;
            Dictionary<string, Dictionary<string, string>> columnsDef = null;
            JavaScriptSerializer jss = new JavaScriptSerializer();

            Application xlApp = null;
            Workbook xlWorkBook = null;
            Worksheet xlWorkSheet = null;
            QueryTable tbl = null;
            string path = null;
            string sheetName = null;
            string configFile;
            bool containsHeadings = false;
            byte[] data = null;
            string tmp;
            string inputDataType = "CSV";
            Int32 freezeRows = 1;
            Range range;

            System.Diagnostics.EventLog eventLog = new System.Diagnostics.EventLog();

            eventLog.Source = ConfigurationManager.AppSettings["log source"];
            eventLog.Log = ConfigurationManager.AppSettings["log"];

            eventLog.WriteEntry("starting excel formatting", System.Diagnostics.EventLogEntryType.Information, 11);
            e = null;

            try
            {
                //****************************************************************************
                // Get configuration info Initialze Excel
                //****************************************************************************
                if (!args.TryGetValue("INPUT_TYPE", out inputDataType))
                {
                    inputDataType = "CSV";
                }

                if (args.TryGetValue(inputDataType, out configFile))
                {
                    configFile = Util.MapPath(@"~\Formats\", configFile);
                    if (File.Exists(configFile))
                    {
                        configInfo = jss.Deserialize<Dictionary<string, Dictionary<string, Dictionary<string, string>>>>(File.ReadAllText(configFile));
                    }
                }

                if (args.TryGetValue("HEADING_ROW", out tmp)) containsHeadings = tmp == "Y" ? true : false;

                // get sheet name for tab
                args.TryGetValue("SHEETNAME", out sheetName);

                xlApp = new Application();
                xlApp.Visible = false;
                xlWorkBook = xlApp.Workbooks.Add(XlWBATemplate.xlWBATWorksheet);
                xlWorkSheet = xlWorkBook.Worksheets[1];
                xlWorkSheet.Select();

                if (sheetName != null) xlWorkSheet.Name = sheetName;

                //****************************************************************************
                // Process CSV or FIXED to excel
                //****************************************************************************
                // create path and save data to temp file for excel to import
                path = Util.MapPath("~/Temp/", parameters["SEQ"] + ".txt");

                if (csvData == null)
                {
                    File.WriteAllText(path, "".PadRight(10));
                }
                else
                {
                    if (csvData.Length == 0)
                    {
                        File.WriteAllText(path, "".PadRight(10));
                    }
                    else
                    {
                        // save data to file
                        File.WriteAllBytes(path, csvData);
                    }
                }

                tbl = xlWorkSheet.QueryTables.Add("TEXT;" + path, xlWorkSheet.get_Range("A1"));

                if (inputDataType == "FIX")
                {
                    if (configInfo.TryGetValue("COLUMNS", out columnsDef))
                    {
                        List<int> widths = new List<int>();
                        string pos;

                        // build postion array
                        foreach (KeyValuePair<string, Dictionary<string, string>> item in columnsDef)
                        {
                            if (item.Value.TryGetValue("WIDTH", out pos))
                            {
                                widths.Add(Convert.ToInt32(pos));
                            }
                        }

                        tbl.TextFileParseType = XlTextParsingType.xlFixedWidth;
                        tbl.TextFileFixedColumnWidths = widths.ToArray();
                    }
                }
                else
                {
                    tbl.TextFileParseType = XlTextParsingType.xlDelimited;
                    tbl.TextFileCommaDelimiter = true;
                }

                tbl.Refresh();
                File.Delete(path);

                if (configInfo != null)
                {
                    // format columns
                    FormatHeadingColumns2(xlWorkSheet,
                        //columnNames,
                                         configInfo,
                                         containsHeadings);
                    freezeRows += 1;

                    if (configInfo.TryGetValue("HEADER", out columnsDef))
                    {
                        FormatHeader2(xlWorkSheet,
                                     columnsDef,
                                     args,
                                     containsHeadings);
                        freezeRows += 1;
                    }
                }

                if (freezeRows > 1)
                {
                    // freeze headings
                    range = (Range)xlWorkSheet.Rows[freezeRows];
                    range.Select();
                    xlApp.ActiveWindow.FreezePanes = true;
                }

                path = Util.MapPath("~/Temp/", parameters["SEQ"] + ".xlsx");
                eventLog.WriteEntry("Save As: " + path, System.Diagnostics.EventLogEntryType.Information, 12);

                xlApp.DisplayAlerts = false;
                xlWorkBook.SaveAs(path, XlFileFormat.xlWorkbookDefault, Type.Missing, Type.Missing, true, false, XlSaveAsAccessMode.xlNoChange, XlSaveConflictResolution.xlLocalSessionChanges, Type.Missing, Type.Missing);
                xlWorkBook.Close();

                new ABCException(parameters["SEQ"], ABCException.MessageType.TRACE, "Completed ", "ProcessCSV.CSVtoEXCEL");

                data = File.ReadAllBytes(path);
                File.Delete(path);
            }

            catch (Exception ex)
            {
                eventLog.WriteEntry(ex.Message + " \n" + ex.StackTrace + "\n" + path, System.Diagnostics.EventLogEntryType.Error, 12);
                Console.WriteLine(ex.Message);
                Console.WriteLine(ex.StackTrace);
                ex.Data["PATH"] = path;
                e = new ABCException(parameters["SEQ"] + "::" + path, ex);
            }

            finally
            {
                if (xlApp != null)
                {
                    xlApp.DisplayAlerts = false;
                    xlApp.Quit();
                    System.Runtime.InteropServices.Marshal.ReleaseComObject(xlApp);
                    xlApp = null;
                }
            }

            return data;
        }


        private void FormatHeader2(Worksheet xlWorkSheet,
                                  Dictionary<string, Dictionary<string, string>> columnsDef,
                                  Dictionary<string, string> args,
                                  bool containsHeadings)
        {

            // add header row
            xlWorkSheet.Rows[1].Insert();

            foreach (KeyValuePair<string, Dictionary<string, string>> headerItem in columnsDef)
            {
                Range range;
                string columnNumberStart;
                string columnNumberEnd;
                string value;

                if (!headerItem.Value.TryGetValue("START", out columnNumberStart)) columnNumberStart = "1";
                headerItem.Value.TryGetValue("END", out columnNumberEnd);

                if (columnNumberEnd == null)
                {
                    range = (Range)xlWorkSheet.Cells[1, Convert.ToInt32(columnNumberStart)];
                }
                else
                {
                    range = (Range)xlWorkSheet.Range[xlWorkSheet.Cells[1, Convert.ToInt32(columnNumberStart)],
                                                     xlWorkSheet.Cells[1, Convert.ToInt32(columnNumberEnd)]];
                    range.Merge();
                }

                // add value and see if replacement tag is available
                if (!headerItem.Value.TryGetValue("TEXT", out value)) continue;  // missing data
                if (value.IndexOf("<<") > -1)
                {
                    MatchCollection tags = Regex.Matches(value, "(<<)(?<tags>.*?)(>>)");
                    foreach (Match match in tags)
                    {
                        string tag = match.Groups["tags"].Value;
                        string item;

                        // get value for tag from arguments
                        if (args.TryGetValue(tag, out item))
                        {
                            value = Regex.Replace(value, "<<" + tag + ">>", item);
                        }
                    }
                }

                range.Value = value;

                foreach (KeyValuePair<string, string> format in headerItem.Value)
                {
                    switch (format.Key)
                    {
                        case "FORMAT":
                            range.NumberFormat = format.Value;
                            break;

                        case "JUSTIFIED":
                            range.HorizontalAlignment = (format.Value == "CENTER") ? Excel.XlHAlign.xlHAlignCenter :
                                                        format.Value == "RIGHT" ? Excel.XlHAlign.xlHAlignRight : Excel.XlHAlign.xlHAlignLeft;
                            break;
                    }
                }
            }
        }


        private void FormatHeadingColumns2(Worksheet xlWorkSheet,
            // List<string> columnNames,
                                          Dictionary<string, Dictionary<string, Dictionary<string, string>>> configInfo,
                                          bool containsHeadings)
        {
            Dictionary<string, Dictionary<string, string>> headingDef;
            Dictionary<string, Dictionary<string, string>> columnsDef;
            int column = 1;

            if (configInfo.TryGetValue("HEADINGS", out headingDef))
            {
                // check if heading row need to be added
                if (!containsHeadings) xlWorkSheet.Rows[1].Insert();

                foreach (KeyValuePair<string, Dictionary<string, string>> columnInfo in headingDef)
                {
                    int columnNumber = (columnInfo.Value.ContainsKey("COLUMN_NUMBER")) ? Convert.ToInt32(columnInfo.Value["COLUMN_NUMBER"]) : column++;
                    Range range = (Range)xlWorkSheet.Cells[1, columnNumber];

                    if (!columnInfo.Value.ContainsKey("LENGTH"))
                    {
                        // setup default behavior for column when length is not specified
                        range.WrapText = false;
                        range.Columns.AutoFit();
                    }

                    foreach (KeyValuePair<string, string> format in columnInfo.Value)
                    {
                        switch (format.Key)
                        {
                            case "TEXT":
                                if (!containsHeadings) xlWorkSheet.Cells[1, columnNumber].Value = format.Value;
                                break;

                            case "FORMAT":
                                range.EntireColumn.NumberFormat = format.Value;
                                break;

                            case "LENGTH":
                                int length;
                                range.EntireColumn.WrapText = true;

                                length = Convert.ToInt32(format.Value);
                                range.EntireColumn.ColumnWidth = (length < 256) ? length : 255;
                                break;

                            case "JUSTIFIED":
                                range.HorizontalAlignment = (format.Value == "CENTER") ? Excel.XlHAlign.xlHAlignCenter :
                                                            format.Value == "RIGHT" ? Excel.XlHAlign.xlHAlignRight : Excel.XlHAlign.xlHAlignLeft;
                                break;
                        }
                    }
                }
            }

            if (configInfo.TryGetValue("COLUMNS", out columnsDef))
            {
                column = 1;

                foreach (KeyValuePair<string, Dictionary<string, string>> columnInfo in columnsDef)
                {
                    int columnNumber = (columnInfo.Value.ContainsKey("COLUMN_NUMBER")) ? Convert.ToInt32(columnInfo.Value["COLUMN_NUMBER"]) : column++;
                    Range range = (Range)xlWorkSheet.Range[xlWorkSheet.Cells[2, columnNumber],
                                                                xlWorkSheet.Cells[xlWorkSheet.UsedRange.Rows.Count, columnNumber]];

                    foreach (KeyValuePair<string, string> format in columnInfo.Value)
                    {
                        switch (format.Key)
                        {
                            case "FORMAT":
                                range.NumberFormat = format.Value;
                                break;

                            case "JUSTIFIED":
                                range.HorizontalAlignment = (format.Value == "CENTER") ? Excel.XlHAlign.xlHAlignCenter :
                                                            format.Value == "RIGHT" ? Excel.XlHAlign.xlHAlignRight : Excel.XlHAlign.xlHAlignLeft;
                                break;
                        }
                    }
                }
            }
        }


        //***************************************************************************************************
        //
        //***************************************************************************************************
        public byte[] CSVtoXML(OracleDataReader reader, Dictionary<string, string> args, out ABCException e)
		{
			byte[] csvData= reader.GetOracleBlob(reader.GetOrdinal("REPORT_DATA")).Value;

			return CSVtoXML(csvData, args, out e);
		}

		public byte[] CSVtoXML(byte[] csvData, Dictionary<string, string> args, out ABCException e)
		{
			Dictionary<string, Dictionary<string, Dictionary<string, string>>>	configInfo		= null;
			Dictionary<string, Dictionary<string, string>>						columnsDef		= null;
            JavaScriptSerializer												jss				= new JavaScriptSerializer();

			string			configFile;
			bool			containsHeadings	= false;
			byte[]			data				= null;
            Stream			csvStream			= new MemoryStream(csvData);
            TextFieldParser reader				= null;
            string[]		items;
			string			tmp;
			string			inputDataType		= "CSV";
			string[]		columnNames			= null;		
			XmlDocument		doc					= new XmlDocument();
			XmlNode			root;
			XmlNode			xmlRow;

			e = null;

			//****************************************************************************
			// Initialze
			//****************************************************************************
            try
            {
				if (!args.TryGetValue("INPUT_TYPE", out inputDataType))
				{
					inputDataType = "CSV";
				}

				if (args.TryGetValue(inputDataType, out configFile))
				{
					configFile = Util.MapPath(@"~\Formats\", configFile);
					if (File.Exists(configFile))
					{
						configInfo = jss.Deserialize<Dictionary<string, Dictionary<string, Dictionary<string, string>>>>(File.ReadAllText(configFile));
					}
				}

				if (args.TryGetValue("HEADING_ROW", out tmp)) containsHeadings = tmp == "Y"? true: false;

           }

            catch (Exception ex)
            {
				e = new ABCException(parameters["SEQ"], ex);
            }

			if (e != null) return null;

			//****************************************************************************
			// Process CSV to xml
			//****************************************************************************
			try
            {
                reader = new TextFieldParser(csvStream);

				if (configInfo.TryGetValue("COLUMNS", out columnsDef))
				{
					List<int>	widths = new List<int>();
					string		pos;

					columnNames = new string[columnsDef.Count];

					// build postion array
					foreach (KeyValuePair<string, Dictionary<string, string>> item in columnsDef)
					{
						// add to column list
						if (item.Value.TryGetValue("COLUMN_NUMBER", out pos))
						{
							columnNames[Convert.ToInt32(pos) - 1] = item.Key;
						}

						if (inputDataType == "FIX")
						{
							if (item.Value.TryGetValue("WIDTH", out pos))
							{
								widths.Add(Convert.ToInt32(pos));
							}
						}
					}

					if (inputDataType == "FIX")
					{
						reader.TextFieldType = FieldType.FixedWidth;
						reader.SetFieldWidths(widths.ToArray());
					}
				}
				

				if (inputDataType != "FIX")
				{
					reader.Delimiters = new string[] { @"," };
					reader.HasFieldsEnclosedInQuotes = true;
				}

				root = doc.AppendChild(doc.CreateElement("ROOT"));

                // loop through each record
				while ((items = reader.ReadFields()) != null)
				{
					int column = 0;
					xmlRow = root.AppendChild(doc.CreateElement("ROW"));

					foreach (string val in items)
					{
						xmlRow.AppendChild(doc.CreateElement(columnNames[column++])).InnerText = val;
					}
				}

				data = Encoding.UTF8.GetBytes(doc.OuterXml);
			}

            catch (Exception ex)
            {
				e = new ABCException(parameters["SEQ"], ex);
            }

			finally
			{
                if (reader != null) reader.Close();
			}

			return data;
        }

	}

}
