using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

using System.Web.Script.Serialization;
using System.Xml;

namespace RQS.Common
{
	class RptParameters : Dictionary<string, string>
	{
		public RptParameters() : base() {}

		public RptParameters(string parameters) :
			base(new JavaScriptSerializer().Deserialize<Dictionary<string, string>>((string)parameters))
		{}

		public RptParameters(Oracle.DataAccess.Client.OracleDataReader reader) : base()
		{
			int	valuePos = reader.GetOrdinal("PARAMETER_VALUE");
			int namePos  = reader.GetOrdinal("PARAMETER_NAME");

			while (reader.Read())
			{
				// check if null parameter
				if (reader.IsDBNull(valuePos) || reader.IsDBNull(namePos)) continue;

				base[reader.GetString(reader.GetOrdinal("PARAMETER_NAME"))] = reader.GetString(reader.GetOrdinal("PARAMETER_VALUE"));
			}
		}

		public string value(string name)
		{
			string item;

			base.TryGetValue(name, out item);
			return item;
		}

		public void value(string name, string value)
		{
			base[name] = value;
		}

		public string getXML()
		{
			XmlDocument			doc = new XmlDocument();
			XmlNode				root;

			root = doc.AppendChild(doc.CreateElement("ROOT"));

			foreach (var item in this)
			{
				root.AppendChild(doc.CreateElement(item.Key)).InnerText = item.Value;
			}

			return doc.OuterXml;
		}

	}
}
