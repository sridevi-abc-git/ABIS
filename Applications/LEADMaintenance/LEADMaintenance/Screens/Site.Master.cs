using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;
using System.Web.UI;
using System.Web.UI.WebControls;

using System.Configuration;
//using System.Security.Cryptography;
using System.Text;
using System.IO;

using Oracle.DataAccess.Client;
using Oracle.DataAccess.Types;


namespace LEADMaintenance.Screens
{
	public partial class Site : System.Web.UI.MasterPage
	{
        //static readonly string      PasswordHash = "P@@Sw0rd";
        //static readonly string      SaltKey      = "S@LT&KEY";
        //static readonly string      VIKey        = "@1B2c3D4e5F6g7H8";

		private		     AppSettingsSection				m_appSettings;
		private			 string							m_tnsname;
		private readonly Dictionary<string, string>		m_source		= new Dictionary<string, string> 
																					{ 
																						{ "leadmaintenancedev1.abc.ca.gov",  "abcdev"},
																						{ "leadmaintenancetest1.abc.ca.gov", "abctest"},
																						{ "leadmaintenance.abc.ca.gov",     "abcprod"},
																						{ "leadmaintenance1.abc.ca.gov",     "abcprod"},
																						{ "leadmaintenancesb1.abc.ca.gov",   "abcsb"}
																					};
		public string Tnsname { get { return m_tnsname; } }

		protected void Page_Load(object sender, EventArgs e)
		{
			homelink.PostBackUrl = "~/";

			//if (!m_source.TryGetValue(Request.Url.Host.ToLower(), out m_tnsname)) m_tnsname =  "abcdev";
            m_tnsname = System.Configuration.ConfigurationManager.AppSettings["tnsname"];
			LoadConfiguration();

			if (!IsPostBack)
			{
				this.ViewState["connectionstring"] = Session["connectionstring"];
				if (Request.Url.LocalPath.IndexOf("/default.aspx") == -1)
				{
					if (Session["connectionstring"] == null) Response.Redirect("~/default.aspx", false);
				}

			}
			else
			{
				Session["connectionstring"] = this.ViewState["connectionstring"];
			}
		}

		public string AppSetting(string key)
		{

			return key;
		}

		protected void LoadConfiguration()
		{
			ExeConfigurationFileMap		configMap = new ExeConfigurationFileMap();
			string						path	  = AppDomain.CurrentDomain.BaseDirectory;
			Configuration				config;

			configMap.ExeConfigFilename = path + @"\" + m_tnsname + ".config";
			config = ConfigurationManager.OpenMappedExeConfiguration(configMap, ConfigurationUserLevel.None);
			m_appSettings = (System.Configuration.AppSettingsSection) config.GetSection("appSettings");

		}

		public string CreateConnectionString(string userid, string pswd)
		{
			string		connectionString;

			connectionString = "User Id=" + userid + ";Password=" + pswd + ";Data Source=" + m_tnsname;
            //this.ViewState["connectionstring"] = Encrypt(connectionString);
            this.ViewState["connectionstring"] = connectionString;
			Session["connectionstring"]        = this.ViewState["connectionstring"];

			return connectionString;  

		}

		public string ConnectionString
		{
			get
			{
				string connectionString = (this.ViewState["connectionstring"] != null ?  this.ViewState["connectionstring"].ToString() : "");
                return connectionString;
                //return (string)(connectionString != null ? Decrypt(connectionString) : "");
			}
		}

		public static bool OpenConnection(OracleConnection conn)
		{
			int					retry  = 0;

			// allow three tries to open connection to database
			while ((retry < 3) && (conn.State != System.Data.ConnectionState.Open))
			{
				try
				{
					conn.Open();
					break;
				}

				catch (Exception ex)
				{
					if (retry == 0) Utils.AppLog.Write(ex, Utils.AppLog.MessageType.ERROR);
				}

				finally
				{
					if (conn.State != System.Data.ConnectionState.Open)
					{
						retry++;

						// wait one second before trying again
						System.Threading.Thread.Sleep(1000);
					}
				}
			}

			return (conn.State == System.Data.ConnectionState.Open);
		}


		/// <summary>
		/// Encrype encrypes a text string and returns enrypted string in Base 64 format.
		/// </summary>
		/// <param name="text">ASCII text to encrypt</param>
		/// <returns>Encrypted text in Base64 format</returns>
        //public static string Encrypt(string text)
        //{
        //    byte[] plainTextBytes = Encoding.UTF8.GetBytes(text);

        //    byte[] keyBytes = new Rfc2898DeriveBytes(PasswordHash, Encoding.ASCII.GetBytes(SaltKey)).GetBytes(256 / 8);
        //    var symmetricKey = new RijndaelManaged() { Mode = CipherMode.CBC, Padding = PaddingMode.Zeros };
        //    var encryptor = symmetricKey.CreateEncryptor(keyBytes, Encoding.ASCII.GetBytes(VIKey));

        //    byte[] cipherTextBytes;

        //    using (var memoryStream = new MemoryStream())
        //    {
        //        using (var cryptoStream = new CryptoStream(memoryStream, encryptor, CryptoStreamMode.Write))
        //        {
        //            cryptoStream.Write(plainTextBytes, 0, plainTextBytes.Length);
        //            cryptoStream.FlushFinalBlock();
        //            cipherTextBytes = memoryStream.ToArray();
        //            cryptoStream.Close();
        //        }
        //        memoryStream.Close();
        //    }
        //    return Convert.ToBase64String(cipherTextBytes);
        //}

		/// <summary>
		/// Decrypt decrypts text which was encrypted by the Encrypt text function
		/// </summary>
		/// <param name="encryptedText">Base 64 encrypted text</param>
		/// <returns>Returns the uncrypted text.</returns>
        //public static string Decrypt(string encryptedText)
        //{
        //    if (encryptedText == null) return null;
        //    byte[] cipherTextBytes = Convert.FromBase64String(encryptedText);
        //    byte[] keyBytes = new Rfc2898DeriveBytes(PasswordHash, Encoding.ASCII.GetBytes(SaltKey)).GetBytes(256 / 8);
        //    var symmetricKey = new RijndaelManaged() { Mode = CipherMode.CBC, Padding = PaddingMode.None };

        //    var decryptor = symmetricKey.CreateDecryptor(keyBytes, Encoding.ASCII.GetBytes(VIKey));
        //    var memoryStream = new MemoryStream(cipherTextBytes);
        //    var cryptoStream = new CryptoStream(memoryStream, decryptor, CryptoStreamMode.Read);
        //    byte[] plainTextBytes = new byte[cipherTextBytes.Length];

        //    int decryptedByteCount = cryptoStream.Read(plainTextBytes, 0, plainTextBytes.Length);
        //    memoryStream.Close();
        //    cryptoStream.Close();
        //    return Encoding.UTF8.GetString(plainTextBytes, 0, decryptedByteCount).TrimEnd("\0".ToCharArray());
        //}



	}
}