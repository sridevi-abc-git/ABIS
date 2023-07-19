<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet version="1.0"
				xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
				xmlns:msxsl="urn:schemas-microsoft-com:xslt"
				exclude-result-prefixes="msxsl"
>
	<xsl:output method="html" indent="yes"/>

	<xsl:template match="/ROOT">
		<xsl:text disable-output-escaping="yes">&lt;!DOCTYPE html&gt;</xsl:text>
		<html  xmlns="http://www.w3.org/1999/xhtml">
		<head>
			<style type="text/css">
				body   { font-size: 8pt; }
				table { width: 100% }
				caption { font-size: 2em; border-bottom: 1px solid black; padding-bottom: 10px; }
				th			{ vertical-align: bottom; border-bottom: 1px solid #000000; padding-top:5px; }

				td			{ vertical-align: top; padding: 7px 5px 2px 5px; margin: 0; border-bottom: 1px solid #d0d0d0; }
				tbody		{ padding-bottom: 2em; }
				.td1		{ width:  1.0in; text-align: right; }
				.td2		{ width: 2.0in; }
				.td3		{ width: 1.3in; }
				.td4		{ width: 1.5in; }
				.td5		{ width:  .7in; text-align: center; }
				.td6		{ width:  .7in; text-align: center; }


			</style>
			<title>
				<xsl:value-of select='/ROOT/@REPORT_NAME' />
			</title>
		</head>
		<body>
			<xsl:call-template name="page_heading"  ></xsl:call-template>
			
			<xsl:call-template name="tbl_data">
				<xsl:with-param name="P_LICENSEINFO"
								select="LICENSEINFO[@TYPE='PendBeg']" />
				<xsl:with-param name="P_CAPTION"
								select='"Pending Beginning"' />
			</xsl:call-template>
			
			<p>
				<xsl:call-template name="tbl_data">
					<xsl:with-param name="P_LICENSEINFO"
									select="LICENSEINFO[@TYPE='Received']" />
					<xsl:with-param name="P_CAPTION" 
									select='"Received"' />
				</xsl:call-template>
				<br/><br/>
			</p>
			<p>
				<br/>
				<br/>

					<xsl:call-template name="tbl_data">
						<xsl:with-param name="P_LICENSEINFO"
										select="LICENSEINFO[@TYPE='Completed']" />
						<xsl:with-param name="P_CAPTION"
										select='"Completed"' />
					</xsl:call-template>
			</p>
		</body>
		</html>
	</xsl:template>

	<xsl:template name="page_heading">
		<table>
			<tbody>
				<tr>
					<td style="width:25%; border:none; font-size: 1.5em;">Report For <xsl:value-of select='/ROOT/@REPORT_DATE' /></td>
					<td style="width:50%; text-align: center; border:none; font-size: 1.5em;"><xsl:value-of select='/ROOT/@REPORT_NAME'/></td>
					<td style="width:24%; border:none; font-size: 1.5em;"></td>
				</tr>
			</tbody>
		</table>
		<!--<div id="print-heading" style="width:100%">
			<div style="width:100%; font-size:9pt;">
				<div style="width:33%; Display:inline-block; text-align:left;">
					</div>
				<div style="width:33%; Display:inline-block; text-align:center;"></div>
				<div style="width:33%; Display:inline-block; text-align:right; ">Report Taken <xsl:value-of select='/ROOT/@REPORT_TAKEN' /></div>
			</div>
		</div>-->
	</xsl:template>


	<xsl:template name="tbl_data">
		<xsl:param name="P_LICENSEINFO" select="LICENSEINFO"></xsl:param>
		<xsl:param name="P_CAPTION" select="*"></xsl:param>
		
		<!--<xsl:call-template name="page_heading"  ></xsl:call-template>-->
		
		<table>
			<caption><xsl:value-of select='$P_CAPTION'/></caption>
			<xsl:call-template name="tbl_header"  ></xsl:call-template>
			<tbody>
				<xsl:for-each select="$P_LICENSEINFO">
					<xsl:call-template name="rec" >
						<xsl:with-param name="P_LICENSEINFO"
										select=".">
						</xsl:with-param>
					</xsl:call-template>
				</xsl:for-each>
			</tbody>
		</table>
	</xsl:template>
	
	<xsl:template name="tbl_header">
		<thead>
			<tr>
				<th>License Number</th>
				<th>Licensee</th>
				<th>Investigation Number</th>
				<th>Created Date</th>
				<th>Completed Date</th>
			</tr>
		</thead>
	</xsl:template>
	
	<xsl:template name="rec">
		<xsl:param name="P_LICENSEINFO"
				   select="LICENSEINFO"></xsl:param>
		<tr class="rec">
			<td class="td1">
				<xsl:value-of select='$P_LICENSEINFO/LICENSENUMBER' />
			</td>
			<td class="td2">
				<xsl:value-of select='$P_LICENSEINFO/PRIMARYLICENSEE' />
			</td>
			<td class="td3">
				<xsl:value-of select='$P_LICENSEINFO/EXTERNALFILENUM' />
			</td>
			<td class="td5">
				<xsl:value-of select='$P_LICENSEINFO/ASSIGN_CREATE_DATE' />
			</td>
			<td class="td6">
				<xsl:value-of select='$P_LICENSEINFO/CLOSE_INV_COMPLETED_DATE' />
			</td>
		</tr>
	</xsl:template>

</xsl:stylesheet>
