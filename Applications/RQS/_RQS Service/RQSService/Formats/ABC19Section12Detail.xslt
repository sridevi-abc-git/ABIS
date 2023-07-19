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
					.td1		{ width:  .5in; text-align: right; }
					.td2		{ width: 2.0in; }
					.td3		{ width:  .8in; }
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

				<xsl:for-each select="LICENSEINFO[not(@TYPE = (preceding-sibling::*/@TYPE))]">
						<xsl:variable name="sectiontype"
									  select="@TYPE"></xsl:variable>
							<xsl:call-template name="tbl_data">
								<xsl:with-param name="P_LICENSEINFO"
												select="/*/LICENSEINFO[@TYPE=$sectiontype]" />
								<xsl:with-param name="P_CAPTION"
												select='@DESCRIPTION' />
							</xsl:call-template>
					</xsl:for-each>
				
			</body>
		</html>
	</xsl:template>

	<xsl:template name="page_heading">
		<xsl:param name="P_CAPTION"
				   select="*"></xsl:param>
		<table>
			<tbody>
				<tr>
					<td style="width:25%; border:none; font-size: 1.5em;">
						Report For <xsl:value-of select='/ROOT/@REPORT_DATE' />
					</td>
					<td style="width:50%; text-align: center; border:none; font-size: 1.5em;">
						<xsl:value-of select='/ROOT/@REPORT_NAME'/>
					</td>
					<td style="width:24%; border:none; font-size: 1.5em;"></td>
				</tr>
			</tbody>
		</table>
	</xsl:template>

	<xsl:template name="tbl_data">
		<xsl:param name="P_LICENSEINFO"
				   select="LICENSEINFO"></xsl:param>
		<xsl:param name="P_CAPTION"
				   select="*"></xsl:param>
		<br/><br/>
		<table>
			<caption>
				<xsl:value-of select='$P_CAPTION'/>
			</caption>
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
				<th>Investigation Type</th>
				<th>Created Date</th>
				<th>Completed Date</th>
			</tr>
		</thead>
	</xsl:template>

	<xsl:template name="rec">
		<xsl:param name="P_LICENSEINFO"
				   select="LICENSEINFO"></xsl:param>
		<tr>
			<td class="td1">
				<xsl:value-of select='$P_LICENSEINFO/LICENSENUMBER' />
			</td>
			<td class="td2">
				<xsl:value-of select='$P_LICENSEINFO/PRIMARYLICENSEE' />
			</td>
			<td class="td3">
				<xsl:value-of select='$P_LICENSEINFO/INVESTIGATIONNUMBER' />
			</td>
			<td class="td4">
				<xsl:value-of select='$P_LICENSEINFO/INVESTIGATIONTYPE' />
			</td>
			<td class="td5">
				<xsl:value-of select='$P_LICENSEINFO/CREATEDDATE' />
			</td>
			<td class="td6">
				<xsl:value-of select='$P_LICENSEINFO/COMPLETEDDATE' />
			</td>
		</tr>
	</xsl:template>

</xsl:stylesheet>
