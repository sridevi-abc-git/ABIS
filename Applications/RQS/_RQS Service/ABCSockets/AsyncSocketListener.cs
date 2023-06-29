using System;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Threading;
using System.ComponentModel;

using System.Configuration;
using Oracle.DataAccess.Client;
using Oracle.DataAccess.Types;

namespace ABCSockets
{
	public class AsyncSocketListener
	{
		private IPHostEntry							m_ipHostInfo;
		private ManualResetEvent					m_allDone	= new ManualResetEvent(false);
		private bool								m_listen	= true;
		private int									m_port      = 0;
		private System.Diagnostics.EventLog			m_eventLog;
		private string								m_dataSource;
		private bool								m_trace;

		public bool IsListening { get {return m_listen;}}
		public AsyncSocketListener(string dataSource, System.Diagnostics.EventLog eventLog, bool trace)
		{
			m_eventLog   = eventLog;
			m_dataSource = dataSource;
			m_trace      = trace;

			// get port number from database
//			GetSocketInfo(dataSource);
			m_ipHostInfo = Dns.GetHostEntry(Dns.GetHostName());

			//if (m_port != 0)
			//{
			//	m_eventLog.WriteEntry("Async Socket Listiner Initialized: " +
			//						   m_ipHostInfo.HostName +
			//						  "  IP: " + m_ipHostInfo.AddressList[0] +
			//						  "  Port: " + m_port +
			//						  "\nData Source: " + m_dataSource);

			//	Console.WriteLine("Async Socket Listiner Initialized:" +
			//						  "\n\tHost:\t\t" + m_ipHostInfo.HostName +
			//						  "\n\tIP:\t\t" + m_ipHostInfo.AddressList[0] +
			//						  "\n\tPort:\t\t" + m_port +
			//						  "\n\tData Source:\t" + m_dataSource + "\n");
			//}
			//else
			//{
			//	m_eventLog.WriteEntry("Service port informations is unavailable.");
			//	Console.WriteLine("Service port informations is unavailable.");
			//}
		}


		public void start(object sender, DoWorkEventArgs e)
		{
			m_eventLog.WriteEntry("Start configuration. (" + m_dataSource + ")");
			Console.WriteLine("Start configuration. (" + m_dataSource + ")");

			while (m_port == 0 && m_listen)
			{
				if (m_listen)  // check if service is being terminated (not listen)
				{
					GetSocketInfo(m_dataSource);

					if (m_port != 0)
					{
						m_eventLog.WriteEntry("Async Socket Listiner Initialized: " +
											   m_ipHostInfo.HostName +
											  "  IP: " + m_ipHostInfo.AddressList[0] +
											  "  Port: " + m_port +
											  "\nData Source: " + m_dataSource);

						Console.WriteLine("Async Socket Listiner Initialized:" +
											  "\n\tHost:\t\t" + m_ipHostInfo.HostName +
											  "\n\tIP:\t\t" + m_ipHostInfo.AddressList[0] +
											  "\n\tPort:\t\t" + m_port +
											  "\n\tData Source:\t" + m_dataSource + "\n");
					}
					else
					{
						m_eventLog.WriteEntry("Service port informations is unavailable. (" + m_dataSource + ")");
						Console.WriteLine("Service port informations is unavailable. (" + m_dataSource + ")");

						m_allDone.WaitOne(1000 * 60 * 2); // wait 2 minutes before retrying

					}

					//{
					//	m_eventLog.WriteEntry("Service port informations is unavailable.");
					//	Console.WriteLine("Service port informations is unavailable.");
					//}
				}
			}

			if (m_port != 0) Start();
		}

		public void Stop()
		{
			m_listen = false;
			m_allDone.Set();
		}

		public void Start()
		{
			IPAddress ipAddress		= null;

			// Data buffer for incoming data.
			byte[] bytes = new Byte[1024];

			// Establish the local endpoint for the socket.
			for (int i = 0; i <= m_ipHostInfo.AddressList.Length - 1; i++)
			{
				Console.WriteLine("IP: " + m_ipHostInfo.AddressList[i].ToString());
				if (m_ipHostInfo.AddressList[i].IsIPv6LinkLocal == false &&
					m_ipHostInfo.AddressList[i].ToString().Length > 6 &&
					m_ipHostInfo.AddressList[i].ToString().Length < 16)
				{
					ipAddress = m_ipHostInfo.AddressList[i];
					break;
				}
			}
 
//			IPAddress ipAddress = m_ipHostInfo.AddressList[0];
			IPEndPoint localEndPoint = new IPEndPoint(ipAddress, m_port);

			// Create a TCP/IP socket.
			Socket listener = new Socket(AddressFamily.InterNetwork,
				SocketType.Stream, ProtocolType.Tcp);

			// Bind the socket to the local endpoint and listen for incoming connections.
			try
			{
				listener.Bind(localEndPoint);
				listener.Listen(100);

				m_eventLog.WriteEntry("Listening on: " + localEndPoint.Address);

				while (m_listen)
				{
					// Set the event to nonsignaled state.
					m_allDone.Reset();

					// Start an asynchronous socket to listen for connections.
					Console.WriteLine("\nWaiting for a connection...");
					listener.BeginAccept(
						new AsyncCallback(AcceptCallback),
						listener);

					// Wait until a connection is made before continuing.
					m_allDone.WaitOne();
				}

			}
			catch (Exception e)
			{
				Console.WriteLine(e.ToString());
			}

			Console.WriteLine("\nPress ENTER to continue...");
			Console.Read();

		}

		public void AcceptCallback(IAsyncResult ar)
		{
			int		retry = 0;

			// Signal the main thread to continue.
			m_allDone.Set();

			// Get the socket that handles the client request.
			Socket listener = (Socket)ar.AsyncState;
			Socket handler = listener.EndAccept(ar);

			// Create the state object.
			StateObject state = new StateObject();
			state.workSocket = handler;

			while (handler.Available == 0 && retry++ < 3) System.Threading.Thread.Sleep(100);  
			if (m_trace) m_eventLog.WriteEntry("Request Received Data Length: " + handler.Available, System.Diagnostics.EventLogEntryType.Information, 2);
			if (handler.Available > 0)
			{ 
				handler.BeginReceive(state.buffer, 0, StateObject.BufferSize, 0,
									 new AsyncCallback(ReadCallback), state);
			}
		}

		public void ReadCallback(IAsyncResult ar)
		{
			String content = String.Empty;

			// Retrieve the state object and the handler socket
			// from the asynchronous state object.
			StateObject state = (StateObject)ar.AsyncState;
			Socket handler = state.workSocket;

			// Read data from the client socket. 
			int bytesRead = handler.EndReceive(ar);

			if (bytesRead > 0)
			{
				// There  might be more data, so store the data received so far.
				state.sb.Append(Encoding.ASCII.GetString(
					state.buffer, 0, bytesRead));

				content = state.sb.ToString();
				if (m_trace) m_eventLog.WriteEntry(content, System.Diagnostics.EventLogEntryType.Information, 3);
				Send(handler, Process.Request(m_dataSource, content));
			}
		}

		public void Send(Socket handler, String data)
		{
			if (m_trace) m_eventLog.WriteEntry(data, System.Diagnostics.EventLogEntryType.Information, 4);

			// Convert the string data to byte data using ASCII encoding.
			byte[] byteData = Encoding.ASCII.GetBytes(data);
            Console.WriteLine("Sending Data");
			Console.WriteLine(data);

			// Begin sending the data to the remote device.
			handler.BeginSend(byteData, 0, byteData.Length, 0,
				new AsyncCallback(SendCallback), handler);
		}

		private void SendCallback(IAsyncResult ar)
		{
			try
			{
				// Retrieve the socket from the state object.
				Socket handler = (Socket)ar.AsyncState;

				// Complete sending the data to the remote device.
				int bytesSent = handler.EndSend(ar);
				Console.WriteLine("Sent {0} bytes to client.", bytesSent);

				handler.Shutdown(SocketShutdown.Both);
				handler.Close();

			}
			catch (Exception e)
			{
				Console.WriteLine(e.ToString());
			}
		}


		protected void GetSocketInfo(string dataSource)
		{
			ABCRQSUtils.AppConfigurationSettings	cnfg;
			OracleCommand							cmd;
			OracleConnection						conn			 = null;
			string									connectionString;
			OracleParameter							port			 = new OracleParameter("p_data", OracleDbType.Int32, System.Data.ParameterDirection.Output);
			Int32									retry			 = 0;

			try
			{
                cnfg = ABCRQSUtils.AppConfigurationSettings.getConfigurationSection(dataSource);
                connectionString = cnfg.AppSettings["connection"].value;

				conn = new OracleConnection(connectionString);
				cmd = new OracleCommand("ABCREPORTS.RQS_UTILS.GetSocketInfo", conn);
				cmd.CommandType = System.Data.CommandType.StoredProcedure;

				// add parameters
				cmd.Parameters.Add(port);

				// allow three tries to open connection to database
				while ((retry < 3) && (conn.State != System.Data.ConnectionState.Open))
				{
					try
					{
						conn.Open();
					}

					catch (Exception ex)
					{
						if (retry == 0) m_eventLog.WriteEntry(ABCRQSUtils.ABCException.FormatedMessage(ex), System.Diagnostics.EventLogEntryType.Error, 3);
					}

					finally
					{
						retry++;

						// wait one second before trying again
						System.Threading.Thread.Sleep(1000);
					}
				}

				if (conn.State == System.Data.ConnectionState.Open)
				{
					cmd.ExecuteNonQuery();
					conn.Close();

					if (((INullable)port.Value).IsNull)
					{
						m_eventLog.WriteEntry("Missing Port configuration in database (" + dataSource + ")", System.Diagnostics.EventLogEntryType.Error, 1);
					}
					else
					{
						m_port = Convert.ToInt32(((Oracle.DataAccess.Types.OracleDecimal) (port.Value)).Value);
					}
				}
				else
				{
					m_eventLog.WriteEntry("Unable to get port information (" + dataSource + ")", System.Diagnostics.EventLogEntryType.Error, 3);
				}
			}

			catch (OracleException ex)
			{
				string msg = ABCRQSUtils.ABCException.FormatedMessage(ex);
				m_eventLog.WriteEntry(msg, System.Diagnostics.EventLogEntryType.Error, 1);
			}

			catch (Exception ex)
			{
				string msg = ABCRQSUtils.ABCException.FormatedMessage(ex);
				m_eventLog.WriteEntry(msg, System.Diagnostics.EventLogEntryType.Error, 1);
			}

			finally
			{
				if (conn.State == System.Data.ConnectionState.Open)	conn.Close();
			}

		}
			

	}
}
