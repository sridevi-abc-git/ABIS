<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet version="1.0"
				xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
				xmlns:msxsl="urn:schemas-microsoft-com:xslt"
				exclude-result-prefixes="msxsl"
>
	<xsl:output method="html"
				indent="yes"/>

	<xsl:template match="/ROOT">
		<xsl:text disable-output-escaping="yes">&lt;!DOCTYPE html&gt;</xsl:text>
		<html  xmlns="http://www.w3.org/1999/xhtml">
			<head>
				<style type="text/css">
					body   { font-size: 8pt; }
					table { font-size: 1em;}
					caption { font-size: 2em; border-bottom: 1px solid black; padding-bottom: 10px;}
					
					td { vertical-align: top; padding: 0px 5px 0px 5px; margin: 0 }
					tbody		{ padding-bottom: 2em; }
					.td1		{ width:  .5in; text-align: right; }
					.td2		{ width: 2.5in; }
					.td3		{ width:  .7in; text-align: center; }
					.td4		{ width:  .7in; text-align: center; }
					.td5		{ width:  .8in; }
					.td6		{ width: 1.6in; }
					.td7		{ width:  .7in; text-align: center; }
					
					@page             { margin-left:.25in; margin-right:.25in; margin-top:0.5in; margin-bottom:0.5in; }

					@media screen and (min-width: 900px)
					{
						<!--td		{ color: #800000; }-->
						body	{ font-size: 10pt; width:7.5in; margin:auto }
					}
					
					@media screen and (max-width: 899px)
					{
						<!--td		{ color: blue; }-->
						body	{ font-size: 10pt; width:7.5in; margin: auto }
					}
					
					@media print
					{
						<!--td { color: green }-->
						body	{ width: 7.5in; }
					}
					
				</style>
				<title>
					<xsl:value-of select='/ROOT/@REPORT_NAME' />
				</title>
			</head>

			<body>
					<xsl:for-each select="LICENSEINFO[not(@TYPE = (preceding-sibling::*/@TYPE))]">
						<xsl:variable name="sectiontype" select="@TYPE"></xsl:variable>
							<table>
								<caption>
									<xsl:value-of select="@DESCRIPTION"/>
								</caption>
								
								<thead>
									<xsl:call-template name="tbl_header"  ></xsl:call-template>
								</thead>
								<tbody>
								<xsl:call-template name="tbl_data">
									<xsl:with-param name="P_LICENSEINFO"
													select="/*/LICENSEINFO[@TYPE=$sectiontype]" />
									<xsl:with-param name="P_CAPTION"
													select='@DESCRIPTION' />
								</xsl:call-template>
								</tbody>
								<tfoot>
									<tr>
										<td style='height:2em;'> </td>
									
									</tr>
								</tfoot>
							</table>
					</xsl:for-each>
			</body>
		</html>
	</xsl:template>

	<xsl:template name="tbl_header">
			<tr>
				<th>License Number</th>
				<th>Licensee</th>
				<th>Created Date</th>
				<!--<th>Application Completed</th>-->
				<th>Status</th>
				<th>Office</th>
				<th>Completed Date</th>
			</tr>
	</xsl:template>

	<xsl:template name="tbl_data">
		<xsl:param name="P_LICENSEINFO"
				   select="LICENSEINFO"></xsl:param>
		<xsl:param name="P_CAPTION"
				   select="*"></xsl:param>
			<xsl:for-each select="$P_LICENSEINFO">
				<xsl:call-template name="rec" >
					<xsl:with-param name="P_LICENSEINFO"
									select=".">
					</xsl:with-param>
				</xsl:call-template>
			</xsl:for-each>
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
				<xsl:value-of select='$P_LICENSEINFO/CREATEDDATE' />
			</td>
			<!--<td class="td4">
				<xsl:value-of select='$P_LICENSEINFO/ENTERAPPLICATIONCOMPLETEDDATE' />
			</td>-->
			<td class="td5">
				<xsl:value-of select='$P_LICENSEINFO/STATUSNAME' />
			</td>
			<td class="td6">
				<xsl:value-of select='$P_LICENSEINFO/BASEFILEOFFICENAME' />
			</td>
			<td class="td7">
				<xsl:value-of select='$P_LICENSEINFO/DATECOMPLETED' />
			</td>
		</tr>
	</xsl:template>

</xsl:stylesheet>

