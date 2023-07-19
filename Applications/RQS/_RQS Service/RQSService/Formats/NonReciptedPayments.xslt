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
					table { width: 4.5in; margin:auto; font-size: 0.9em; }
					caption { font-size: 1.1em; border-bottom: 1px solid black; padding-bottom: 10px;}
					th			{ vertical-align: bottom; border-bottom: 1px solid #000000; padding-top:5px; }

					td			{ vertical-align: top; padding: 4px 5px 2px 5px; margin: 0; border-bottom: 1px solid #d0d0d0; }
					tbody		{ padding-bottom: 2em; }
					.td1		{ width: 2.5in; text-align: left; }
					.td2		{ width:  .5in; text-align: right; }
					.td3		{ width:  .7in; text-align: right; }
					.td4		{ width:  .5in; text-align: center; }
					@page       { margin-left:.25in; margin-right:.25in; margin-top:0.5in; margin-bottom:0.5in; }

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
					body	{ width: 10.5in; }
					}

				</style>
				<title>
					<xsl:value-of select='/ROOT/@REPORT_NAME' />
				</title>
			</head>
			<body>
				<div style="margin: 10px auto; padding:10px 10px; background-color:white;text-align:center;">
					<h2 style="font-size: 1.2em; text-align:center; width:95%">
						<xsl:value-of select='/ROOT/@REPORT_NAME' />
					</h2>
					<xsl:call-template name="Offices">
					</xsl:call-template>

					<!--<table class="">
						<caption>Pending Transmittals</caption>
						<xsl:call-template name="rpt-heading"/>
						<tbody>
							<xsl:for-each select="ROW">
								<xsl:call-template name="rpt-data"/>
							</xsl:for-each>
						</tbody>
					</table>-->
				</div>

			</body>
		</html>
	</xsl:template>

	<!-- ******************************************************************** -->
	<!--     Template layout                       -->
	<!-- ******************************************************************** -->
	<xsl:template name="Offices">

		<xsl:for-each select="/ROOT/OFFICE">
			<xsl:choose>
				<xsl:when test="count(PAYMENTS) &gt; 0" >
					<p style="padding-bottom: 0.1em; margin-bottom: 0.1em;">
						<xsl:text disable-output-escaping="yes">&amp;</xsl:text>nbsp;
					</p>
					<p>
						<table class="">
							<caption>
								<xsl:value-of select="@NAME"/>
							</caption>
							<xsl:call-template name="rpt-heading"/>
							<tbody>
								<xsl:for-each select="PAYMENTS">
									<xsl:call-template name="rpt-data"/>
								</xsl:for-each>
							</tbody>
						</table>
					</p>
				</xsl:when>
				<!--<xsl:otherwise>
					<p style="padding-bottom: 0.5em; margin-bottom: 0.5em;">
						<xsl:value-of select="@NAME"/>
					</p>
				</xsl:otherwise>-->
			</xsl:choose>
		</xsl:for-each>

	</xsl:template>
	
	<!-- ******************************************************************** -->
	<!--     Template layout                       -->
	<!-- ******************************************************************** -->
	<xsl:template name="rpt-heading">
		<thead>
			<tr>
				<th>Payee Name</th>
				<th>License Number</th>
				<th>Amount</th>
				<th>Payment Date</th>
			</tr>
		</thead>
	</xsl:template>

	<!-- ******************************************************************** -->
	<!--     Template layout                       -->
	<!-- ******************************************************************** -->
	<xsl:template name="rpt-data">
		<tr>
			<td class="td1">
				<xsl:value-of select="PAYEENAME"/>
			</td>
			<td class="td2">
				<xsl:value-of select="LICENSENUMBER"/>
			</td>
			<td class="td3">
				<xsl:value-of select="CHKAMOUNT"/>
			</td>
			<td class="td4">
				<xsl:value-of select="PAYMENTDATE"/>
			</td>

		</tr>
	</xsl:template>

	<!-- ******************************************************************** -->
	<!--     Template layout                       -->
	<!-- ******************************************************************** -->
	<xsl:template name="rpt-footer">

	</xsl:template>


</xsl:stylesheet>
