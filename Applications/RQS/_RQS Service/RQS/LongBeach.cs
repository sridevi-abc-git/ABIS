using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Oracle.DataAccess.Client;
using Oracle.DataAccess.Types;

namespace RQS.Controllers
{
	class LongBeach : ABCRQSUtils.OraBase
	{
		public object FormatData(ref Dictionary<string, string> parameters, byte[] rawdata)
		{
			ABCRQSUtils.ABCException		e			= null;
			ABCRQSUtils.RQSFTP				ftp			= new ABCRQSUtils.RQSFTP();
			string[]						data;
			string[]						separator	= { "<BR>" };
			string							tempDir	    = null;
			string							tmpFile		= null;
			string							fileName;
			byte[]							ftpData		= null;
			Dictionary<string, string>		args		= new Dictionary<string, string>();
//			string							statusDescription;

			try
			{
				// parse data
				data = Encoding.UTF8.GetString(rawdata).Split(separator, StringSplitOptions.RemoveEmptyEntries);

				// create temp directory
				tempDir = ABCRQSUtils.Util.MapPath("~/Temp/", parameters["REPORT_NAME"] + parameters["SEQ"]); // + DateTime.Now.ToString(@"yyyyMMddHHmmss"));
				System.IO.Directory.CreateDirectory(tempDir);

				// save report data in report files
				for (Int32 inx = 0; inx < data.Length; inx += 2)
				{
					fileName = tempDir + "/" + data[inx] + ".lst";
					System.IO.File.WriteAllLines(fileName, new string[] { data[inx + 1] });
				}

				// create zip file
				tmpFile = tempDir + ".zip";
				System.IO.Compression.ZipFile.CreateFromDirectory(tempDir, tmpFile);

				// retrieve zip data
				ftpData = System.IO.File.ReadAllBytes(tmpFile);

				// upload data 
				//args["REPORT_NAME"] = parameters["REPORT_NAME"];
				//args["FILE_NAME"] = parameters["FILE_NAME"] + DateTime.Now.ToString(@"yyyyMMddHHmmss") + ".zip";

				//ftp.UploadFile(ftpData, args, out statusDescription, out e);

				//m_conn.ConnectionString = parameters["CONNECTION"];
				//m_conn.Open();

				//UpdateFtpLog(parameters["SEQ"], "1", (e == null ? "C": "E"), statusDescription, (e == null ? null: e.Message));
			}

			catch (Exception ex)
			{
				e = new ABCRQSUtils.ABCException(parameters["SEQ"], ex);
			}

			finally
			{
				// remove working directory
				if (tmpFile != null) System.IO.File.Delete(tmpFile);
				if (tempDir != null) System.IO.Directory.Delete(tempDir, true);
			}

			return (e == null)? (object) ftpData : (object)e ;

		}

		//protected void UpdateFtpLog(string seq, string exportId, string statusInd, string response, string message)
		//{

		//	m_cmd.CommandText = "RQS_REPORTS.upd_export_log";
		//	m_cmd.Parameters.Add(new OracleParameter("p_seq", OracleDbType.Int32, 0, Convert.ToInt32(seq),
		//												System.Data.ParameterDirection.Input));
		//	m_cmd.Parameters.Add(new OracleParameter("p_export_id", OracleDbType.Int32, 0, exportId,
		//												System.Data.ParameterDirection.Input));
		//	m_cmd.Parameters.Add(new OracleParameter("p_status_ind", OracleDbType.Varchar2, 1, statusInd,
		//												System.Data.ParameterDirection.Input));
		//	m_cmd.Parameters.Add(new OracleParameter("p_response", OracleDbType.Varchar2, response.Length, response,
		//												System.Data.ParameterDirection.Input));
		//	m_cmd.Parameters.Add(new OracleParameter("p_error_msg", OracleDbType.Varchar2, (message == null) ? 1 : message.Length, message,
		//												System.Data.ParameterDirection.Input));

		//	Open();
		//	m_cmd.ExecuteNonQuery();
		//	Close();

		//}

	
	}


}
