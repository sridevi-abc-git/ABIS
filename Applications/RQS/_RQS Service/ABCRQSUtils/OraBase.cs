//*******************************************************************************************
//    File:         OraBase.cs         
//    Author:       Timothy J. Lord
//    
//    Description:  
//    		 
//    Methods:     
//
//    $Rev: 51 $
//    $Author: TLord $
//*******************************************************************************************
//  History:
//     Date  Developer Trackit    Comment
//----------------------------------------------------------------------------------
//  09/22/2015  TJL       Initial File Created
//*******************************************************************************************
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

using System.Configuration;
using Oracle.DataAccess.Client;
using Oracle.DataAccess.Types;

using System.IO;

namespace ABCRQSUtils
{
	public class OraBase : IDisposable
	{
		private bool               m_disposed = false;
		protected OracleConnection m_conn;
		protected OracleCommand    m_cmd;
		protected OracleParameter  m_cursor = new OracleParameter("p_data", OracleDbType.RefCursor, System.Data.ParameterDirection.Output);
		protected OracleParameter  m_retCode = new OracleParameter("p_return_code", OracleDbType.Int32, System.Data.ParameterDirection.Output);
		protected OracleParameter  m_statusMsg = new OracleParameter("p_status_msg", OracleDbType.Varchar2, 4000, null, System.Data.ParameterDirection.Output);

		public OraBase() 
		{
			try
			{
				m_conn = new OracleConnection();
				m_cmd = m_conn.CreateCommand();
				m_cmd.CommandType = System.Data.CommandType.StoredProcedure;
			}

			catch (Exception ex)
			{
				throw ex;
			}
		}

		public OraBase(string connString, bool encripted = false)
		{
			string connectionString;

			try
			{
				connectionString = (encripted) ? Util.Decrypt(connString) : connString;

				m_conn = new OracleConnection(connectionString);
				m_cmd = m_conn.CreateCommand();
				m_cmd.CommandType = System.Data.CommandType.StoredProcedure;
			}

			catch (Exception ex)
			{
				throw ex;
			}
		}

		public ABCException Open()
		{
			ABCException	e		= null;
			Int32			retry	= 0;

			try
			{
				// allow three tries to open connection to database
				while ((retry < 3) && (m_conn.State != System.Data.ConnectionState.Open))
				{
					try
					{
						m_conn.Open();
						break;
					}

					catch (OracleException ex)
					{
						switch (ex.Number)
						{
							case 1017: // invalid user id and password 
								e = new ABCException(null, "Invalid User / Password: Access Denied");
								retry = 2;
								break;

							case 12154:
								e = new ABCException(null, "Invalid TNSNAME entry");
								e.Data["DataSource"] = m_conn.DataSource;
								retry = 2;
								break;

							case 12535: // tns timout error
							case 12170:
								if (retry == 2) e = new ABCException(null, ex);
								break;

							default:
								if (retry == 2) e = new ABCException(null, ex);
								break;

						}
					}

//					catch (Exception ex)
//					{
//						if (retry == 2)
//						{
//							e = ABCException.Create(ex);
//						}
////						ex.Data["Data Source"] = m_conn.DataSource;
//////						ex.Data["Site"] = info["SITE"];
////						ex.Data["Retry"] = Convert.ToString(retry++);

//					}

					finally
					{
						retry++;

						// wait one second before trying again
						if (e == null) System.Threading.Thread.Sleep(1000);
					}
				}
			}

			catch (Exception ex)
			{
				e = new ABCException(null, ex);
//				ex.Data["Data Source"] = m_conn.DataSource;
////				ex.Data["Site"] = info["SITE"];
//				ex.Data["Failure"] = "No connection made";
			}

			return e;
		}

		public ABCException Open(string connectionString)
		{
			ABCException	e = null;

			try
			{
				if (m_conn.State == System.Data.ConnectionState.Closed)
				{
					m_conn.ConnectionString = Util.Decrypt(connectionString);
					e = Open();
				}

			}

			catch (Exception ex)
			{
				e = new ABCException(null, ex);
			}

			return e;
		}

		public void Close()
		{
			if (m_cmd != null)
			{
				foreach (OracleParameter p in m_cmd.Parameters)
				{
					if (p.Value is IDisposable) ((IDisposable)p.Value).Dispose();
					p.Dispose();
				}
				m_cmd.Parameters.Clear();
			}

			if (m_conn.State == System.Data.ConnectionState.Open) m_conn.Close();

		}

        public void Dispose()
        {
            Dispose(true);
            GC.SuppressFinalize(this);
        }

        protected virtual void Dispose(bool disposing)
        {
            if (!this.m_disposed)
            {
                if (disposing)
                {
                    if (m_cmd != null)
                    {
                        foreach (OracleParameter p in m_cmd.Parameters)
                        {
                            if (p.Value is IDisposable) ((IDisposable)p.Value).Dispose();
                            p.Dispose();
                        }

                        m_cmd.Dispose();
                        m_cmd = null;
                    }

                    if (m_conn.State == System.Data.ConnectionState.Open) m_conn.Close();

                    m_conn.Dispose();
                }
                m_disposed = true;
            }
        }

        ~OraBase()
        {
            Dispose(false);
        }
    }

}
