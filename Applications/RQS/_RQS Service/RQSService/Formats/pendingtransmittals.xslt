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
					table { width: 100% }
					caption { font-size: 2em; border-bottom: 1px solid black; padding-bottom: 10px;}
					th			{ vertical-align: bottom; border-bottom: 1px solid #000000; padding-top:5px; }

					td			{ vertical-align: top; padding: 7px 5px 2px 5px; margin: 0; border-bottom: 1px solid #d0d0d0; }
					tbody		{ padding-bottom: 2em; }
					.td1		{ width:  .5in; text-align: right; }
					.td2		{ width:  .5in; text-align: right; }
					.td3		{ width:  .7in; text-align: center; }
					.td4		{ width:  .5in; text-align: center; }
					.td5		{ width:  .7in; text-align: right; }
					.td6		{ width:  1.0in; }
					.td7		{ width:  .7in; text-align: center; }
					.td8		{ width:  .7in; }
					.td9		{ width: 2.0in; }
					.td10		{ width:  .8in; text-align: right; }
					.td11		{ width:  .5in; text-align: right; }

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
					body	{ width: 10.5in; }
					}

				</style>
				<title>
					<xsl:value-of select='/ROOT/@REPORT_NAME' />
				</title>
			</head>
			<body>
				<div style="margin: 10px auto; padding:10px 10px; background-color:white;">
					<table class="">
						<caption>Pending Transmittals</caption>
						<xsl:call-template name="rpt-heading"/>
						<tbody>
							<xsl:for-each select="ROW">
								<xsl:call-template name="rpt-data"/>
							</xsl:for-each>
						</tbody>
					</table>
				</div>
				
			</body>
		</html>
		</xsl:template>

	<!-- ******************************************************************** -->
	<!--     Template layout                       -->
	<!-- ******************************************************************** -->
	<xsl:template name="rpt-heading">
		<thead>
			<tr>
				<th>ID</th>
				<th>Payment Id</th>
				<th>Payment Date Stored</th>
				<th>Cabin Income Indicator</th>
				<th>Payment Amount</th>
				<th>Payment Method Codes</th>
				<th>Receipt Number</th>
				<th>Date Completed</th>
				<th>Office</th>
				<th>Registration Number</th>
				<th>Days Prior</th>
			</tr>
		</thead>
	</xsl:template>

	<!-- ******************************************************************** -->
	<!--     Template layout                       -->
	<!-- ******************************************************************** -->
	<xsl:template name="rpt-data">
		<tr>
			<td class="td1">
				<xsl:value-of select="OBJECTID"/>
			</td>
			<td class="td2">
				<xsl:value-of select="PAYMENTID"/>
			</td>
			<td class="td3">
				<xsl:value-of select="PAYMENTDATESTORED"/>
			</td>
			<td class="td4">
				<xsl:value-of select="CABININCOMEIND"/>
			</td>
			<td class="td5">
				<xsl:value-of select="PAYMENTAMOUNT"/>
			</td>
			<td class="td6">
				<xsl:value-of select="PAYMENTMETHODCODE"/>
			</td>
			<td class="td7">
				<xsl:value-of select="RECEIPTNUMBER"/>
			</td>
			<td class="td8">
				<xsl:value-of select="DATECOMPLETED"/>
			</td>
			<td class="td9">
				<xsl:value-of select="OFFICE"/>
			</td>
			<td class="td10">
				<xsl:value-of select="LICENSENUMBER"/>
			</td>
			<td class="td11">
				<xsl:value-of select="DAYSPRIOR"/>
			</td>

		</tr>
	</xsl:template>

	<!-- ******************************************************************** -->
	<!--     Template layout                       -->
	<!-- ******************************************************************** -->
	<xsl:template name="rpt-footer">

	</xsl:template>


</xsl:stylesheet>
