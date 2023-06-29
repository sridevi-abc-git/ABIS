using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

using System.Reflection;

namespace ABCSockets
{
	class Process
	{
		enum inx { ASSEMBLY, CLASS, METHOD, DATA };

		public static string Request(string dataSource, string request)
		{
			//RQS.Controllers.FmtReports		rqs;

			object value = "not processed";
			string[] requestInfo;
			MethodInfo method;
			Assembly asm;
			Type t_class;

			try
			{
                Console.WriteLine("Source: " + dataSource);
                Console.WriteLine("Request: " + request);

				System.Diagnostics.Trace.WriteLine("Service Called");

				requestInfo = request.Split(';');

				asm = Assembly.LoadFile(AppDomain.CurrentDomain.BaseDirectory + requestInfo[(int)inx.ASSEMBLY] + ".dll");

				if (asm == null)
				{
					return "assembly not loaded: " + requestInfo[(int)inx.ASSEMBLY];
				}

				t_class = asm.GetType(requestInfo[(int)inx.ASSEMBLY] + "." + requestInfo[(int)inx.CLASS]);

				if (t_class != null)
				{
					method = t_class.GetMethod(requestInfo[(int)inx.METHOD], BindingFlags.Public | BindingFlags.Static | BindingFlags.Instance);
					if (method != null)
					{
						object obj = method.IsStatic ? null : Activator.CreateInstance(t_class);
						value = method.Invoke(obj, new object[] {dataSource, requestInfo[(int)inx.DATA] });
					}
					else
					{
						value = "Selected method not supported: " + requestInfo[(int)inx.METHOD];
					}
				}
				else
				{
					value = "Selected class not supported: " + requestInfo[(int)inx.CLASS];
				}
			}

			catch (Exception ex)
			{
				value = ex.Message;
                Console.WriteLine(ex.Message + " : " + ex.StackTrace);
//				value = "Error processing request" + new ABCRQSUtils.ABCException(null, ex).FormatedMessage(); //ABCWebUtils.ProcessErrors.ProcessException(ex, "Error processing request");
			}

			return (string) value;
		}

	}
}
