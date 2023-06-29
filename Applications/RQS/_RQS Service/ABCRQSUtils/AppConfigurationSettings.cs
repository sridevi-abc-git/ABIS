/****************************************************************************
	File:		RQSConfigurationSettings.cs
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

using System.Configuration;

namespace ABCRQSUtils
{
	public class AppConfigurationSettings : ConfigurationSection
	{
		[ConfigurationProperty("AppSettings")]
		public AppSettings AppSettings
		{
			get { return (AppSettings)this["AppSettings"]; }
		}

		[ConfigurationProperty("FTPSettings")]
		public FTPSettings FTPSettings
		{
			get { return (FTPSettings)this["FTPSettings"]; }
		}

		static public AppConfigurationSettings getConfigurationSection(string configFile = null)
		{
			Configuration				config;
			AppConfigurationSettings	settings;
			ExeConfigurationFileMap		configMap		= new ExeConfigurationFileMap();

			if (configFile == null) configFile = Environment.GetEnvironmentVariable("TNSNAME", EnvironmentVariableTarget.Process);

			configFile = (configFile == null)? ConfigurationManager.AppSettings["configuration"]: (configFile + ".config");

			if (configFile == null)
			{
				// use web configuration
				settings = (AppConfigurationSettings)ConfigurationManager.GetSection("AppConfigurationSettings");
			}
			else
			{
				// get configuration
				configMap.ExeConfigFilename = Util.MapPath("~/", configFile);

				config = ConfigurationManager.OpenMappedExeConfiguration(configMap, ConfigurationUserLevel.None);
				settings = (AppConfigurationSettings) config.GetSection("AppConfigurationSettings");
			}

			return settings;
		}
	}

	public class AppSettings : ConfigurationElementCollection
	{
		public override ConfigurationElementCollectionType CollectionType
		{
			get
			{
				return ConfigurationElementCollectionType.AddRemoveClearMap;
			}
		}

		protected override ConfigurationElement CreateNewElement()
		{
			return new AppSetting();
		}

		protected override Object GetElementKey(ConfigurationElement element)
		{
			return ((AppSetting)element).name;
		}

		public AppSetting this[int index]
		{
			get
			{
				return (AppSetting)BaseGet(index);
			}
			set
			{
				if (BaseGet(index) != null)
				{
					BaseRemoveAt(index);
				}
				BaseAdd(index, value);
			}
		}

		new public AppSetting this[string Name]
		{
			get
			{
				return (AppSetting)BaseGet(Name);
			}
		}

		public int IndexOf(AppSetting url)
		{
			return BaseIndexOf(url);
		}

		public void Add(AppSetting url)
		{
			BaseAdd(url);
		}
		protected override void BaseAdd(ConfigurationElement element)
		{
			BaseAdd(element, false);
		}

		public void Remove(AppSetting url)
		{
			if (BaseIndexOf(url) >= 0)
				BaseRemove(url.name);
		}

		public void RemoveAt(int index)
		{
			BaseRemoveAt(index);
		}

		public void Remove(string name)
		{
			BaseRemove(name);
		}

		public void Clear()
		{
			BaseClear();
		}

	}

	public class AppSetting : ConfigurationElement
	{
		[ConfigurationProperty("name", IsRequired = true, IsKey = true)]
		public string name
		{
			get
			{
				return (string)this["name"];
			}
			set
			{
				this["name"] = value;
			}
		}


		[ConfigurationProperty("value")]
		public string value
		{
			get
			{
				return (string)this["value"];
			}
			set
			{
				this["value"] = value;
			}
		}


		[ConfigurationProperty("location")]
		public string location
		{
			get { return (string)this["location"]; }
		}

		[ConfigurationProperty("save")]
		public string save
		{
			get
			{
				var value = ((string)this["save"]).Substring(0, 1).ToUpper();

				return ((value == "Y") || (value == "T") || (value == "1")) ? "save" : "NO";
			}
		}

		[ConfigurationProperty("temp")]
		public string temp
		{
			get { return (string)this["temp"]; }
		}
	}




	public class FTPSettings : ConfigurationElementCollection
	{
		public override ConfigurationElementCollectionType CollectionType
		{
			get
			{
				return ConfigurationElementCollectionType.AddRemoveClearMap;
			}
		}

		protected override ConfigurationElement CreateNewElement()
		{
			return new FTPSetting();
		}

		protected override Object GetElementKey(ConfigurationElement element)
		{
			return ((FTPSetting)element).report;
		}

		public FTPSetting this[int index]
		{
			get
			{
				return (FTPSetting)BaseGet(index);
			}
			set
			{
				if (BaseGet(index) != null)
				{
					BaseRemoveAt(index);
				}
				BaseAdd(index, value);
			}
		}

		new public FTPSetting this[string Name]
		{
			get
			{
				return (FTPSetting)BaseGet(Name);
			}
		}

		public int IndexOf(FTPSetting url)
		{
			return BaseIndexOf(url);
		}

		public void Add(FTPSetting url)
		{
			BaseAdd(url);
		}
		protected override void BaseAdd(ConfigurationElement element)
		{
			BaseAdd(element, false);
		}

		public void Remove(FTPSetting url)
		{
			if (BaseIndexOf(url) >= 0)
				BaseRemove(url.report);
		}

		public void RemoveAt(int index)
		{
			BaseRemoveAt(index);
		}

		public void Remove(string name)
		{
			BaseRemove(name);
		}

		public void Clear()
		{
			BaseClear();
		}

	}

	public class FTPSetting : ConfigurationElement
	{
		[ConfigurationProperty("report",	IsRequired = true, IsKey = true)]
		public string report
		{
			get
			{
				return (string)this["report"];
			}
			set
			{
				this["report"] = value;
			}
		}

        [ConfigurationProperty("host")]
        public string host
        {
            get
            {
                return (string)this["host"];
            }
            set
            {
                this["host"] = value;
            }
        }

        [ConfigurationProperty("url")] // Deprecated 
		public string url
		{
			get
			{
				return (string)this["url"];
			}
			set
			{
				this["url"] = value;
			}
		}

		[ConfigurationProperty("port")] //, DefaultValue = (int)0, IsRequired = false)]
		[IntegerValidator(MinValue = 0, MaxValue = 8080, ExcludeRange = false)]
		public int port
		{
			get
			{
				return (int)this["port"];
			}
			set
			{
				this["port"] = value;
			}
		}

		[ConfigurationProperty("user")]
		public string user
		{
			get
			{
				return (string) this["user"];
			}
			set
			{
				this["user"] = value;
			}
		}

		[ConfigurationProperty("password")]
		public string password
		{
			get
			{
				return (string) this["password"];
			}
			set
			{
				this["password"] = value;
			}
		}

		[ConfigurationProperty("encrypted")]
		public string encrypted
		{
			get
			{
				return (string) this["encrypted"];
			}
			set
			{
				this["encrypted"] = value;
			}
		}

        [ConfigurationProperty("ssl")] // Depricated
        public string ssl
        {
            get
            {
                return (string)this["ssl"];
            }
            set
            {
                this["ssl"] = value;
            }
        }

        [ConfigurationProperty("protocol")]
        public string protocol
		{
			get
			{
                return (string)this["protocol"];
			}
			set
			{
                this["protocol"] = value;
			}
		}

        [ConfigurationProperty("identityfile")]
        public string identityfile
        {
            get
            {
                return (string)this["identityfile"];
            }
            set
            {
                this["identityfile"] = value;
            }
        }

        [ConfigurationProperty("destination")]
        public string destination
        {
            get
            {
                return (string)this["destination"];
            }
            set
            {
                this["destination"] = value;
            }
        }
    }

}
