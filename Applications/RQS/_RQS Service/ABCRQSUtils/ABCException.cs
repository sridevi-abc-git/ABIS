/****************************************************************************
	File:		ABCException.cs
	Author:		Timothy J. Lord

	Description:

    $Rev: 430 $  
    $Date: 2020-04-28 07:26:12 -0700 (Tue, 28 Apr 2020) $
    Last Changed By:  $Author: TLord $

*****************************************************************************
	09/13/2015			Initial File Created
****************************************************************************/

using System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

using System.Runtime.Serialization;
using System.Runtime.Serialization.Formatters.Binary;
using System.Reflection;


namespace ABCRQSUtils
{
	[Serializable()]
	public class ABCException
	{
		public enum	MessageType	{ ERROR, WARNING, TRACE, INFORMATIONAL }
		public enum FormatMsg	{ TEXT, HTML }

		public string						Sequence		{ get; set; }
		public MessageType					MsgType			{ get; set; }
		public int?							Number			{ get; set; }
		public Boolean						IsError			{ get; set; }
		public ABCException					InnerException  { get; set; }
		public string						Message			{ get; set; }
		public string						Source			{ get; set; }
		public string						StackTrace		{ get; set; }
		public MethodBase					TargetSite		{ get; set; }
		public Dictionary<string, string>	Data			{ get; set; }

		protected void initialize(string sequence,
								  MessageType msgType, 
								  int? number, 
								  string message, 
								  string source, 
								  string stackTrace, 
								  IDictionaryEnumerator data,
								  MethodBase targetSite,
								  object innerException,
								  bool recursive = false)
		{
			if (innerException != null)
			{
				if (innerException is ABCException)
				{
					this.InnerException = (ABCException)innerException;
				}
				else
				{
					this.InnerException = new ABCException(sequence, innerException, true);
				}
			}

			this.Sequence = sequence;
			this.MsgType = msgType;
			this.IsError = (msgType == MessageType.ERROR);
			this.Number = number;
			this.Message = message;
			this.Source = source;
			this.StackTrace = stackTrace;
			this.TargetSite = targetSite;

			Data = new Dictionary<string, string>();
			if (data != null)
			{
				while (data.MoveNext())
				{
                    if ((string) data.Key != null)
                    {
                        object val = data.Value;

					    Data.Add((string) data.Key, (string) (val != null? val.ToString():" "));

                    }
				}
			}

			if (!recursive)
			{
				// log exception
				ABCLog.Log(this);
			}
		}

		public ABCException()
		{ }

		protected ABCException(string sequence, object innerException, bool recursive = false)
		{
			Exception	e	   = null;
			int?		number = null;

			if (innerException is Oracle.DataAccess.Client.OracleException)
			{
				number = ((Oracle.DataAccess.Client.OracleException)innerException).Number;
			}
			if (innerException is Exception)
			{
				e = (Exception)innerException;
			}

			if (e == null)
			{
				e = new Exception("Not Exception Object: " + (innerException == null ? "null" : innerException.GetType().ToString()));
			}

			initialize(sequence, MessageType.ERROR, number, e.Message, e.Source, e.StackTrace, e.Data.GetEnumerator(), e.TargetSite, e.InnerException, recursive);
		}

		public ABCException(string sequence, Exception e)
		{
			int?		number = null;

			if (e is Oracle.DataAccess.Client.OracleException)
			{
				number = ((Oracle.DataAccess.Client.OracleException)e).Number;
			}

			if (e == null)
			{
				e = new Exception("Not Exception Object: null");
			}

			initialize(sequence, MessageType.ERROR, number, e.Message, e.Source, e.StackTrace, e.Data.GetEnumerator(), e.TargetSite, e.InnerException);
		}

		public ABCException(string sequence, 
							int? number, 
							string message, 
							string source, 
							Exception e = null)
		{
			initialize(sequence, MessageType.ERROR, number, message, source, null, null, null, e);
		}

		public ABCException(string sequence, 
							string message, 
							string source = null, 
							Exception e = null)
		{
			initialize(sequence, MessageType.ERROR, null, message, source, null, null, null, e);
		}

		public ABCException(string sequence, 
							MessageType msgType, 
							string message, 
							string source = null)
		{
			initialize(sequence, msgType, null, message, source, null, null, null, null);
		}

		public string FormatedMessage(FormatMsg fmt = FormatMsg.TEXT)
		{
			return FormatedMessage(this, fmt);
		}

		protected string FormatedMessage(ABCException e, FormatMsg fmt)
		{
			string msg = null;

			if (e.InnerException != null)
			{
				msg += FormatedMessage(e.InnerException, fmt);
				msg += "".PadRight(105, '-') + "\r\n";
			}

			msg += FormatLine("Message", e.Message);
			msg += FormatLine("Source", e.Source);
			msg += FormatLine("StackTrace", e.StackTrace);

			foreach (var key in e.Data.Keys)
			{
				msg += FormatLine(key, e.Data[key]);
			}

			if (this.TargetSite != null)
			{
				msg += FormatLine("Method", e.TargetSite.Name);
			}

			return msg;
		}

		private string FormatLine(string key, string value)
		{
			string	line		= null;
			string	temp;
			int		lineLength	= 84;

			if (value == null) return "";
			if (value.Length <= 80)
			{
				line = (key + ":").PadRight(20).Substring(0, 20) + " " + value + "\r\n";
			}
			else
			{
				int		index = 0;

				temp = value.Trim();
				
				line = (key + ":").PadRight(20).Substring(0, 20) + " ";
				while (temp.Length > 0)
				{
					if (index > 0)
					{
						line += "".PadRight(25);
						lineLength = 80;
					}

					// look for break point in value
					index = (temp.Length > lineLength) ? temp.IndexOf(' ', lineLength - 10) : -1;
					if (index == -1)
					{
						index = (temp.Length > lineLength) ? lineLength : temp.Length;
					}

					if (index > lineLength) index = lineLength;
					line += temp.Substring(0, index) + "\r\n";
					temp = (temp.Length > lineLength) ? temp.Substring(index).TrimStart() : "";
				}
			}

			return line;
		}


		protected ABCException(SerializationInfo info, StreamingContext context)
		{ }

		public static string FormatedMessage(Exception e)
		{
			string msg = null;

			if (e.InnerException != null)
			{
				msg += FormatedMessage(e.InnerException);
				msg += "".PadRight(105, '-') + "\r\n";
			}

			msg += FormatAttribute("Message", e.Message);
			msg += FormatAttribute("Source", e.Source);
			msg += FormatAttribute("StackTrace", e.StackTrace);

			foreach (string key in e.Data.Keys)
			{
				msg += FormatAttribute(key, e.Data[key].ToString());
			}

			if (e.TargetSite != null)
			{
				msg += FormatAttribute("Method", e.TargetSite.Name);
			}

			return msg;
		}

		public static string FormatAttribute(string key, string value)
		{
			string	line		= null;
			string	temp;
			int		lineLength	= 84;

			if (value == null) return "";
			if (value.Length <= 80)
			{
				line = (key + ":").PadRight(20).Substring(0, 20) + " " + value + "\r\n";
			}
			else
			{
				int		index = 0;

				temp = value.Trim();

				line = (key + ":").PadRight(20).Substring(0, 20) + " ";
				while (temp.Length > 0)
				{
					if (index > 0)
					{
						line += "".PadRight(25);
						lineLength = 80;
					}

					// look for break point in value
					index = (temp.Length > lineLength) ? temp.IndexOf(' ', lineLength - 10) : -1;
					if (index == -1)
					{
						index = (temp.Length > lineLength) ? lineLength : temp.Length;
					}

					if (index > lineLength) index = lineLength;
					line += temp.Substring(0, index) + "\r\n";
					temp = (temp.Length > lineLength) ? temp.Substring(index).TrimStart() : "";
				}
			}

			return line;
		}

	}

}
