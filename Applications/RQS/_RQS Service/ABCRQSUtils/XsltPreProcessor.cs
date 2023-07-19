/****************************************************************************
	File:		XsltPreProcessor.cs
	Author:		Timothy J. Lord

	Description:

    $Rev: 51 $  
    $Date: 2018-09-01 12:02:56 -0700 (Sat, 01 Sep 2018) $
    Last Changed By:  $Author: TLord $

*****************************************************************************
	09/13/2015			Initial File Created
****************************************************************************/

using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

using System.IO;
using System.Xml;
using System.Configuration;
using System.Text.RegularExpressions;

namespace ABCRQSUtils
{
	/// <summary>
	/// 
	/// </summary>
	//public enum StringData
	//{
	//	Empty,
	//	FileName,
	//	Data
	//}

    public class XsltPreProcessor
    {
		public  ABCException				e				= null;
		private Dictionary<string, string>	m_args;
		private string						xsltFileName	{ get; set; }
		public bool							isError			{ get { return (e != null); } }


		/// <summary>
		/// 
		/// </summary>
		/// <param name="doc"></param>
		public XsltPreProcessor(ref XmlDocument doc, Dictionary<string, string> args)
		{
			XmlProcessingInstruction	inst;

			try
			{
				m_args = args;

				// check for preprocess instruction to xlst stylesheet
				inst = (XmlProcessingInstruction) doc.SelectSingleNode("processing-instruction('xml-stylesheet')");

				// check if xslt stylesheet
				if (inst != null)
				{
					xsltFileName = System.Text.RegularExpressions.Regex.Match(inst.Value, "href=\"([^\"]*)\"").Groups[1].Value;
				}
				else
				{
					xsltFileName = args["XML"];
				}
			}

			catch (Exception ex)
			{
				e = new ABCException(null, ex);
			}
		}


		/// <summary>
		/// 
		/// </summary>
		/// <returns></returns>
		public XmlReader Reader()
		{
			 AppConfigurationSettings cnfg;
			XmlReader		reader			= null;
			XmlNode			css;
			XmlDocument		doc				= new XmlDocument();
			string			fileName;
			string			tnsname		= null;

			try
			{
				// make sure no error in initialization
				if (e != null) return reader;

				m_args.TryGetValue("TNSNAME", out tnsname);
				cnfg = AppConfigurationSettings.getConfigurationSection(tnsname);

				// get list of css links that need to be embed into the xls style sheet
				doc.Load(xsltFileName);
				foreach (XmlNode node in doc.SelectNodes("//link[@rel='stylesheet']"))
				{
					try
					{
						// build path to css link file
						fileName = Util.MapPath(cnfg.AppSettings["xsltpreprocessor"].location, node.Attributes["href"].Value);

						// read file
						if (System.IO.File.Exists(fileName))
						{
							// create node
							css = doc.CreateElement("style");
							css.Attributes.Append(doc.CreateAttribute("type")).Value = "text/css";
							css.InnerText = System.IO.File.ReadAllText(fileName);

							// replace current node with new node
							node.ParentNode.ReplaceChild(css, node);
						}
					}
				
					catch (Exception ex)
					{
						e = new ABCException(null, ex);
					}
				}

				// create reader to return xlst process data
				reader = XmlReader.Create(new System.IO.StringReader(doc.OuterXml));

				// check to see if to save xslt processed
				if (cnfg.AppSettings["xsltpreprocessor"].save == "save")
				{
					fileName = Util.MapPath(cnfg.AppSettings["xsltpreprocessor"].temp, xsltFileName);
					System.IO.File.WriteAllText(fileName, doc.OuterXml);
				}
			}

			catch (Exception ex)
			{
				e = new ABCException(null, ex);
			}

			finally
			{

			}

			return reader;
		}


	
	}

}
