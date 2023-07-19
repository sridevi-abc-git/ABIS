/****************************************************************************
	File:		Util.cs
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
using System.Security.Cryptography;

namespace ABCRQSUtils
{
	public class Util
	{
		static readonly string      PasswordHash = "P@@Sw0rd";
		static readonly string      SaltKey      = "S@LT&KEY";
		static readonly string      VIKey        = "@1B2c3D4e5F6g7H8";

		/// <summary>
		/// Encrype encrypes a text string and returns enrypted string in Base 64 format.
		/// </summary>
		/// <param name="text">ASCII text to encrypt</param>
		/// <returns>Encrypted text in Base64 format</returns>
		public static string Encrypt(string text)
		{
			byte[] plainTextBytes = Encoding.UTF8.GetBytes(text);

			byte[] keyBytes = new Rfc2898DeriveBytes(PasswordHash, Encoding.ASCII.GetBytes(SaltKey)).GetBytes(256 / 8);
			var symmetricKey = new RijndaelManaged() { Mode = CipherMode.CBC, Padding = PaddingMode.Zeros };
			var encryptor = symmetricKey.CreateEncryptor(keyBytes, Encoding.ASCII.GetBytes(VIKey));

			byte[] cipherTextBytes;

			using (var memoryStream = new MemoryStream())
			{
				using (var cryptoStream = new CryptoStream(memoryStream, encryptor, CryptoStreamMode.Write))
				{
					cryptoStream.Write(plainTextBytes, 0, plainTextBytes.Length);
					cryptoStream.FlushFinalBlock();
					cipherTextBytes = memoryStream.ToArray();
					cryptoStream.Close();
				}
				memoryStream.Close();
			}
			return Convert.ToBase64String(cipherTextBytes);
		}

		/// <summary>
		/// Decrypt decrypts text which was encrypted by the Encrypt text function
		/// </summary>
		/// <param name="encryptedText">Base 64 encrypted text</param>
		/// <returns>Returns the uncrypted text.</returns>
		public static string Decrypt(string encryptedText)
		{
			if (encryptedText == null) return null;
			byte[] cipherTextBytes = Convert.FromBase64String(encryptedText);
			byte[] keyBytes = new Rfc2898DeriveBytes(PasswordHash, Encoding.ASCII.GetBytes(SaltKey)).GetBytes(256 / 8);
			var symmetricKey = new RijndaelManaged() { Mode = CipherMode.CBC, Padding = PaddingMode.None };

			var decryptor = symmetricKey.CreateDecryptor(keyBytes, Encoding.ASCII.GetBytes(VIKey));
			var memoryStream = new MemoryStream(cipherTextBytes);
			var cryptoStream = new CryptoStream(memoryStream, decryptor, CryptoStreamMode.Read);
			byte[] plainTextBytes = new byte[cipherTextBytes.Length];

			int decryptedByteCount = cryptoStream.Read(plainTextBytes, 0, plainTextBytes.Length);
			memoryStream.Close();
			cryptoStream.Close();
			return Encoding.UTF8.GetString(plainTextBytes, 0, decryptedByteCount).TrimEnd("\0".ToCharArray());
		}



		/// <summary>
		/// Builds the path to the location of the file
		/// </summary>
		/// <param name="location">Name of the directory where files are located</param>
		/// <param name="fileName">Name of the file to Map to</param>
		/// <returns>Returns full path and filename to the a file</returns>
		public static string MapPath(string location, string fileName)
		{
			string		file = null;

			// remove any path information from the file name
			if (location == null) location = System.IO.Path.GetDirectoryName(fileName);

			// check if consol or web application
			if (System.Web.Hosting.HostingEnvironment.MapPath("~/") == null)
			{
				location = location.Replace("~", "");
				if (location[0] == '/' || location[0] == '\\') location = location.Substring(1);
				file = AppDomain.CurrentDomain.BaseDirectory + location;
			}
			else
			{
				// remove any path information from the file name
				file = System.Web.Hosting.HostingEnvironment.MapPath(location);
			}

			file += System.IO.Path.GetFileName(fileName);

			return file;
		}

		/// <summary>
		/// ZipData function will create a zip directory with the data and file names passed to this function.
		/// If the zipFileName is null then the directory name passed will be zipped and its data returned
		/// </summary>
		/// <param name="zipDirectory">Zip directory file name</param>
		/// <param name="zipFileName">Name of the file to be zipped</param>
		/// <param name="fileData">file data to be zipped</param>
		/// <param name="e"></param>
		/// <returns></returns>
		static public byte[] ZipDirectory(string zipDirectory, bool delete, out ABCException e)
		{
			byte[]			zipFileData = null;
			string			tempDir	    = null;
			string			tempFile		= null;

			e = null;

			try
			{

				// create temp directory
				tempDir = MapPath("~/Temp/", zipDirectory);

				// create zip file
				tempFile = tempDir + ".zip";
				System.IO.Compression.ZipFile.CreateFromDirectory(tempDir, tempFile);

				// retrieve zip data
				zipFileData = System.IO.File.ReadAllBytes(tempFile);
			}

			catch (Exception ex)
			{
				e = new ABCException(null, ex);
			}

			finally
			{
				if (delete)
				{
					if (tempFile != null) System.IO.File.Delete(tempFile);
					if (tempDir != null) System.IO.Directory.Delete(tempDir, true);
				}
			}

			return zipFileData;
		}




	}
}
