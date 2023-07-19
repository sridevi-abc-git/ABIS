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

using Microsoft.Office.Interop.Excel;
using Excel = Microsoft.Office.Interop.Excel;
using System.Web.Script.Serialization;
using System.Text.RegularExpressions;

namespace ABCRQSUtils
{
	public class ProcessXML
	{
		Dictionary<string, string>	parameters;

		public ProcessXML(Dictionary<string, string> parameters)
		{
			this.parameters = parameters;
		}

		ProcessXML() { }

		public byte[] Process(object reportData, out ABCException e)
		{
			byte[]			data		= null;
			string			outputType;
			string			strOutput;

			e = null;
			// process raw report data by output type
			parameters.TryGetValue("OUTPUT_TYPE", out outputType);
			switch (outputType)
			{
				case "PDF":
				case "WORD":
					data = (reportData is OracleDataReader) ?
								XMLtoPDF((OracleDataReader)reportData, parameters, out e) :
								XMLtoPDF((byte[])reportData, parameters, out e);
					break;

				case "HTML":
				case "TEXT":
					strOutput = (reportData is OracleDataReader) ?
								XMLtoHTML((OracleDataReader)reportData, parameters, out e) :
								XMLtoHTML((byte[])reportData, parameters, out e);

					// convert string to byte
					if (strOutput != null) data = Encoding.UTF8.GetBytes(strOutput);
					break;

				case "EXCEL":
				case "CSV":
					data = (reportData is OracleDataReader) ?
								XMLtoEXCEL((OracleDataReader)reportData, parameters, out e) :
								XMLtoEXCEL((byte[])reportData, parameters, out e);
					break;

				case "XML":
					// get raw data from reportData
					data = (byte[]) reportData;
					break;

				default:
					e = new ABCException(parameters["SEQ"], ABCException.MessageType.ERROR, "Unsupported output type (" + outputType + ")", "ProcessXML");
					break;
			}

			return data;
		}



		public string XMLtoHTML(OracleDataReader reader, Dictionary<string, string> args, out ABCException e)
		{
			byte[] xmlData= reader.GetOracleBlob(reader.GetOrdinal("REPORT_DATA")).Value;

			return XMLtoHTML(xmlData, args, out e);
		}

		public string XMLtoHTML(byte[] xmlData, Dictionary<string, string> args, out ABCException e)
		{
			AppConfigurationSettings	cnfg;
			XmlDocument					doc				 = new XmlDocument();
			string						HTMLData		 = null;
			XslCompiledTransform		transform		 = new XslCompiledTransform();
			XsltArgumentList			argList			 = new XsltArgumentList();
			XmlReader					reader			 = null;
			StringWriter				sw				 = new StringWriter();
			XsltPreProcessor			xslt;
			Stream						xmlStream		 = new MemoryStream(xmlData);
			string						currentDirectory = Directory.GetCurrentDirectory();
			string						workingDirectory;
			string						tnsname = null;
			StringBuilder				buff = new StringBuilder();

			e = null;

			try
			{
				args.TryGetValue("TNSNAME", out tnsname);
				cnfg = AppConfigurationSettings.getConfigurationSection(tnsname);

				// get current directory
				workingDirectory = Util.MapPath(cnfg.AppSettings["xsltpreprocessor"].location, null);
				Directory.SetCurrentDirectory(workingDirectory);

				// escape out non ascii characters
				foreach (byte ch in xmlData)
				{
					if (ch >= '\x20' && ch <= '\x7F')
                        switch (ch)
                        {
                            case 0x26:      //  &
                                buff.Append("&amp;");
                                break;

                            default:
						        buff.Append(Convert.ToChar(ch));
                                break;
                        }
					else 
						buff.AppendFormat("&#{0};", (int) ch);
				}

				// load xml document
				doc.LoadXml(buff.ToString());
				//doc.Load(xmlStream);

				xslt = new XsltPreProcessor(ref doc, args);
				if (xslt.isError)
				{
					e = xslt.e;
					return HTMLData;
				}

				// add any parameters to be used in report generation if needed
				if (args != null)
				{
					foreach (string key in args.Keys)
					{
						argList.AddParam(key, "", args[key]);
					}
				}

				reader = xslt.Reader();
                if (!xslt.isError && reader != null)
				{
					transform.Load(reader);
					transform.Transform(doc, argList, sw);
					HTMLData = sw.ToString();
				}
                else
                {
                    e = xslt.e;
                }
			}

			catch (Exception ex)
			{
				e = new ABCRQSUtils.ABCException("-1", ex);
			}

			finally
			{
				if (reader != null) reader.Close();
				sw.Close();
				Directory.SetCurrentDirectory(currentDirectory);
			}

			return HTMLData;

		}



		public byte[] XMLtoPDF(OracleDataReader reader, Dictionary<string, string> args, out ABCException e)
		{
			byte[] xmlData= reader.GetOracleBlob(reader.GetOrdinal("REPORT_DATA")).Value;

			return XMLtoPDF(xmlData, args, out e);
		}

		public byte[] XMLtoPDF(byte[] xmlData, Dictionary<string, string> args, out ABCException e)
		{
			object				doNotSaveChanges = Word.WdSaveOptions.wdDoNotSaveChanges;
			byte[]				data = null;
			string				html;
			Word.Application	word		= new Word.Application();
			Word.Document		doc			= null;
			Word.Range			range;
			Word.Section		wordSection;
			object				oMissing	= System.Reflection.Missing.Value;
			string				path		= Util.MapPath(@"~\Temp\", DateTime.Now.ToString(@"HHmmssFF") + ".html");
			string				orientation;

			try
			{
				html = XMLtoHTML(xmlData, args, out e);
				if (e != null) return null;

				//if (!args.TryGetValue("ORIENTATION", out orientation)) orientation = "PORTRAIT";

				// test for error on conversion to html

				System.IO.File.WriteAllText(path, html);

				doc = (Word.Document)word.Documents.GetType()
							.InvokeMember("Open",
										  System.Reflection.BindingFlags.InvokeMethod,
										  null,
										  word.Documents,
										  new Object[] { path, false, false });
				
				//doc.PageSetup.Orientation = (orientation == "LANDSCAPE" ? WdOrientation.wdOrientLandscape : 
				//														  WdOrientation.wdOrientPortrait);
				orientation = PageSetup(doc, args);

				wordSection = doc.Sections.First;
				
				// add header
				range = wordSection.Headers[Word.WdHeaderFooterIndex.wdHeaderFooterPrimary].Range;
				if (orientation == "LANDSCAPE")
				{
					range.Paragraphs.TabStops.ClearAll();
					range.Paragraphs.TabStops.Add((float)(4.5 * 72), WdTabAlignment.wdAlignTabCenter); // 72 points per inch
					range.Paragraphs.TabStops.Add(9 * 72, WdTabAlignment.wdAlignTabRight);
				}

				range.Font.Size = 8;
				range.Text = "\tCalifornia Department of Alcoholic Beverage Control"
						   + "\t" + DateTime.Now.ToString("MM/dd/yyyy hh:mm tt");

				//Add the footer details.
				range = wordSection.Footers[Microsoft.Office.Interop.Word.WdHeaderFooterIndex.wdHeaderFooterPrimary].Range;
				range.Font.Size = 8;

				object CurrentPage = Microsoft.Office.Interop.Word.WdFieldType.wdFieldPage;

				range.Fields.Add(range, ref CurrentPage, ref oMissing, ref oMissing);
				if (orientation == "LANDSCAPE")
				{
					range.Paragraphs.TabStops.ClearAll();
					range.Paragraphs.TabStops.Add((float)(4.5 * 72), WdTabAlignment.wdAlignTabCenter);
					range.Paragraphs.TabStops.Add(9 * 72, WdTabAlignment.wdAlignTabRight);
				}

				range.InsertBefore("\t\tPage: ");

				// save as PDF
				doc.GetType().InvokeMember("SaveAs",
										System.Reflection.BindingFlags.InvokeMethod,
										null,
										doc,
										new object[] { path + ".pdf", Word.WdSaveFormat.wdFormatPDF });

				((Microsoft.Office.Interop.Word._Document)doc).Close(ref doNotSaveChanges);

				// raw read pdf file into buffer to be saved in database
				data = System.IO.File.ReadAllBytes(path + ".pdf");

			}

			catch (Exception ex)
			{
				e = new ABCRQSUtils.ABCException(parameters["SEQ"], ex);
			}

			finally
			{

				try
				{
					// exit application
					//object missing = null;
					//if (doc != null)((Microsoft.Office.Interop.Word._Document)doc).Close(ref doNotSaveChanges, ref missing, ref missing);

					//word.GetType().InvokeMember("Quit", System.Reflection.BindingFlags.InvokeMethod, null, word, null);
					((Microsoft.Office.Interop.Word._Application)word).Quit(ref doNotSaveChanges);

					// make sure all working files a removed
					//					if ((flags & flag.Save) != flag.Save)
					{
						// give time for word to close before removing files
						System.Threading.Thread.Sleep(10);

						try
						{
							new ABCRQSUtils.ABCException(parameters["SEQ"], ABCException.MessageType.TRACE, "Deleting: " + path, "ProcessXML.XMLtoPDF");
							System.IO.File.Delete(path + ".pdf");
							System.IO.File.Delete(path);
//							System.IO.Directory.Delete(path.Substring(0, path.LastIndexOf('.')) + "_files", true);
						}

						catch (Exception ex) 
						{
							new ABCRQSUtils.ABCException(parameters["SEQ"], ex); // log error only
						}
					}
				}

				catch (Exception ex)
				{
					e = new ABCRQSUtils.ABCException(parameters["SEQ"], ex);
				}
			}

			return data;

		}


		protected string PageSetup(Word.Document doc, Dictionary<string, string> args)
		{
			string		margin;
			float		num;
			string		orientation;

			if (!args.TryGetValue("ORIENTATION", out orientation)) orientation = "PORTRAIT";
			doc.PageSetup.Orientation = (orientation == "LANDSCAPE" ? WdOrientation.wdOrientLandscape :
																	  WdOrientation.wdOrientPortrait);
	
			if (args.TryGetValue("LEFTMARGIN", out margin))
			{
				if (float.TryParse(margin, out num))
				{
					doc.PageSetup.LeftMargin = (float)(num * 72);
				}
			}

			if (args.TryGetValue("RIGHTMARGIN", out margin))
			{
				if (float.TryParse(margin, out num))
				{
					doc.PageSetup.RightMargin = (float)(num * 72);
				}
			}

			if (args.TryGetValue("TOPMARGIN", out margin))
			{
				if (float.TryParse(margin, out num))
				{
					doc.PageSetup.TopMargin = (float)(num * 72);
				}
			}

			if (args.TryGetValue("BOTTOMMARGIN", out margin))
			{
				if (float.TryParse(margin, out num))
				{
					doc.PageSetup.BottomMargin = (float)(num * 72);
				}
			}

			return orientation;
		}


		public byte[] XMLtoEXCEL(OracleDataReader reader, Dictionary<string, string> args, out ABCException e)
		{
			byte[] xmlData= reader.GetOracleBlob(reader.GetOrdinal("REPORT_DATA")).Value;

			return XMLtoEXCEL(xmlData, args, out e);
		}

		public byte[] XMLtoEXCEL(byte[] xmlString, Dictionary<string, string> args, out ABCException e)
		{
            Dictionary<string, Dictionary<string, Dictionary<string, string>>> configInfo = null;
            Dictionary<string, Dictionary<string, string>> columnsDef = null;
            JavaScriptSerializer jss = new JavaScriptSerializer();

            Excel.Application xlApp = null;
            Workbook xlWorkBook = null;
            Worksheet xlWorkSheet = null;
            QueryTable tbl = null;
            string path = null;
            string configFile;
            bool containsHeadings = false;
            byte[] data = null;
            string tmp;
            string inputDataType = "XML";
            Int32 freezeRows = 1;
            Excel.Range range;

            XmlDocument doc = new XmlDocument();
            XmlNodeList list = null;
            StringBuilder buff = new StringBuilder();

            e = null;

            try
            {
                //****************************************************************************
                // Get configuration info Initialze Excel
                //****************************************************************************
                if (!args.TryGetValue("INPUT_TYPE", out inputDataType))
                {
                    inputDataType = "XML";
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

                xlApp = new Excel.Application();
                xlApp.Visible = false;
                xlWorkBook = xlApp.Workbooks.Add(XlWBATemplate.xlWBATWorksheet);
                xlWorkSheet = xlWorkBook.Worksheets[1];
                xlWorkSheet.Select();

                //****************************************************************************
                // Process XML to excel
                //****************************************************************************
                // create path and save data to temp file for excel to import
                path = Util.MapPath("~/Temp/", parameters["SEQ"] + ".txt");

                // load xml document
                doc.LoadXml(Encoding.ASCII.GetString(xmlString));

                // find root node
                foreach (XmlNode root in doc.ChildNodes)
                {
                    if (root.NodeType == XmlNodeType.Element)
                    {
                        list = root.ChildNodes;
                        break;
                    }
                }

                if (list != null)
                {
                    // get column headings
                    if (!configInfo.TryGetValue("HEADINGS", out columnsDef))
                    {
                        foreach (XmlNode node in list[0].ChildNodes)
                        {
                            if (node != list[0].ChildNodes[0]) buff.Append(",");
                            buff.Append("\"" + node.Name + "\"");
                        }

                        buff.Append("\n");
                    }

                    foreach (XmlNode l in list)
                    {
                        foreach (XmlNode node in l.ChildNodes)
                        {
                            double num;

                            if (node != l.ChildNodes[0]) buff.Append(",");

                            if (double.TryParse(node.InnerText, out num))
                            {
                                buff.Append(node.InnerText);
                            }
                            else
                            {
                                buff.Append("\"" + node.InnerText + "\"");
                            }
                        }

                        buff.Append("\n");
                    }

                    data = Encoding.ASCII.GetBytes(buff.ToString());

                }

                if (data == null)
                {
                    File.WriteAllText(path, "".PadRight(10));
                }
                else
                {
                    if (data.Length == 0)
                    {
                        File.WriteAllText(path, "".PadRight(10));
                    }
                    else
                    {
                        // save data to file
                        File.WriteAllBytes(path, data);
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
                    range = (Excel.Range)xlWorkSheet.Rows[freezeRows];
                    range.Select();
                    xlApp.ActiveWindow.FreezePanes = true;
                }

                path = Util.MapPath("~/Temp/", parameters["SEQ"] + ".xlsx");
                //                eventLog.WriteEntry("Save As: " + path, System.Diagnostics.EventLogEntryType.Information, 12);

                xlApp.DisplayAlerts = false;
                xlWorkBook.SaveAs(path);
                xlWorkBook.Close();

                new ABCException(parameters["SEQ"], ABCException.MessageType.TRACE, "Completed ", "ProcessCSV.CSVtoEXCEL");

                data = File.ReadAllBytes(path);
                File.Delete(path);
            }

            catch (Exception ex)
            {
                ex.Data["PATH"] = path;
                e = new ABCException(parameters["SEQ"] + "::" + path, ex);
            }

            finally
            {
                if (xlApp != null)
                {
                    xlApp.DisplayAlerts = true;
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
                Excel.Range range;
                string columnNumberStart;
                string columnNumberEnd;
                string value;

                if (!headerItem.Value.TryGetValue("START", out columnNumberStart)) columnNumberStart = "1";
                headerItem.Value.TryGetValue("END", out columnNumberEnd);

                if (columnNumberEnd == null)
                {
                    range = (Excel.Range)xlWorkSheet.Cells[1, Convert.ToInt32(columnNumberStart)];
                }
                else
                {
                    range = (Excel.Range)xlWorkSheet.Range[xlWorkSheet.Cells[1, Convert.ToInt32(columnNumberStart)],
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
                    Excel.Range range = (Excel.Range)xlWorkSheet.Cells[1, columnNumber];

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
                    Excel.Range range = (Excel.Range)xlWorkSheet.Range[xlWorkSheet.Cells[2, columnNumber],
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


	}
}
