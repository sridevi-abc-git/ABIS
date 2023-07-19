using System;
using System.Collections.Generic;
using System.Linq;
using System.Runtime.Serialization;
using System.ServiceModel;
using System.Text;

using RQS.Common;
using System.ServiceModel.Activation;
using System.Web.Script.Serialization;
using System.Reflection;

namespace RQS
{
	// NOTE: You can use the "Rename" command on the "Refactor" menu to change the class name "WebService" in code, svc and config file together.
	// NOTE: In order to launch WCF Test Client for testing this service, please select WebService.svc or WebService.svc.cs at the Solution Explorer and start debugging.
	[AspNetCompatibilityRequirements(RequirementsMode = AspNetCompatibilityRequirementsMode.Required)]
	public class WebService : IWebService
	{
		public string User(string request, string data)
		{
			JavaScriptSerializer		serializer = new JavaScriptSerializer();
			Dictionary<string, string>	err		   = new Dictionary<string, string>(); ;
			User						user       = new User();
			Type						t_class	   = user.GetType();
			MethodInfo					method;
			string						value;

			try
			{
				method = t_class.GetMethod(request, BindingFlags.Public | BindingFlags.Static | BindingFlags.Instance);
				if (method != null)
				{
					object obj = method.IsStatic ? null : Activator.CreateInstance(t_class);
					value = (string)method.Invoke(obj, new object[] { data });
				}
				else
				{
					err = new Dictionary<string, string>();
					err["err"] = "Selected method not supported: " + request;
					value = serializer.Serialize(err);
				}
			}

			catch (Exception ex)
			{
				err = new Dictionary<string, string>();
				err["err"] = ABCRQSUtils.ABCException.FormatedMessage(ex);
				value = serializer.Serialize(err);
			}

			return value; 
		}

		public string Request(string request, string data)
		{
            JavaScriptSerializer		serializer = new JavaScriptSerializer();
			Dictionary<string, string>	err		   = new Dictionary<string, string>(); ;
			OraReports					rpt		   = new OraReports();
			Type						t_class	   = rpt.GetType();
			MethodInfo					method;
			string						value;

			try
			{
				method = t_class.GetMethod(request, BindingFlags.Public | BindingFlags.Static | BindingFlags.Instance);
				if (method != null)
				{
					object obj = method.IsStatic ? null : Activator.CreateInstance(t_class);
					value = (string) method.Invoke(obj, new object[] { data });
				}
				else
				{
					err = new Dictionary<string, string>();
					err["err"] = "Selected method not supported: " + request;
					value = serializer.Serialize(err);
				}
			}

			catch (Exception ex)
			{
				err = new Dictionary<string, string>();
				err["err"] = ABCRQSUtils.ABCException.FormatedMessage(ex);
				value = serializer.Serialize(err);
			}

			return value; 

		}
	}
}
