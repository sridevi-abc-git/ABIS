<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:msxsl="urn:schemas-microsoft-com:xslt" exclude-result-prefixes="msxsl"
>
    <xsl:output method="html"/>
	<xsl:param select="/ROOT/@REPORT_NAME" name="ReportName"></xsl:param >
	<xsl:template match="/">
		<html>
			<head>
				<style type="text/css">
					@page       { margin-left:.0in; margin-right:.25in; margin-top:0.5in; margin-bottom:0.5in; }

					table		{ width: 10.2in; font-family:'Courier New';font-size:8pt; margin:0; padding:0; border-collapse: collapse; border: none; }
					td			{ vertical-align: top; margin: 0; padding:1px 0px; }
					.row1-1		{ width:  1.2in; }
					.row1-2		{ width:  1.3in; }
					.row1-3		{ width:  1.4in; }
					.row1-4		{ width:  0.7in; }
					.row1-5		{ width:  5.6in; }

					.row2-1		{ width:  1.2in; }
					.row2-2		{ width:  1.2in; }
					.row2-3		{ width:  0.8in; }
					.row2-4		{ width:  1.2in; }
					.row2-5		{ width:  1.5in; }
					.row2-6		{ width:  1.5in; }
					.row2-7		{ width:  3.0in; }

					.row3-1		{ width:  3.8in; }
					.row3-2		{ width:  4.4in; }
					.row3-3		{ width:  1.1in; }
					.row3-4		{ width:  0.9in; text-align: right; }

					.row4-1		{ width:  3.8in; }
					.row4-2		{ width:  6.4in; }

					.row5-1		{ width:  1.2in; }
					.row5-2		{ width:  0.5in; }
					.row5-3		{ width:  0.5in; }
					.row5-4		{ width:  1.2in; }
					.row5-5		{ width:  1.3in; }
					.row5-6		{ width:  1.5in; }
					.row5-5		{ width:  1.2in; }
					.row5-6		{ width:  2.8in; }

					.row6-1		{ width:  0.8in; }
					.row6-2		{ width:  9.4in; }

					.row7-1		{ width:  1.0in; }
					.row7-2		{ width:  2.6in; }
					.row7-3		{ width:  0.9in; }
					.row7-4		{ width:  1.3in; }
					.row7-5		{ width:  0.8in; }
					.row7-6		{ width:  2.2in; }
					.row7-7		{ width:  1.4in; }

				</style>
			</head>
			<body style="font-family:'Courier New';font-size:8pt;">
				<table>
					<thead>
					<th style="text-align:center; font-weight: bold;padding-bottom: 20px;">
						<xsl:value-of select='/ROOT/@REPORT_NAME' />
						from <xsl:value-of select='/ROOT/@START_DATE' />
						to <xsl:value-of select='/ROOT/@END_DATE' /> by File Number
					</th>
					</thead>
					<tbody>
								<xsl:for-each select='/ROOT/LicenseInfo'>
						<tr>
							<td>
									<p style="margin: 0px; page-break-inside: avoid; ">
										<table style="page-break-inside: avoid; ">
											<tr>
												<td style="page-break-inside: avoid; ">
													<xsl:call-template name="tmpl_license_info" />
												</td>
											</tr>
										</table>
										<xsl:text disable-output-escaping="yes">&amp;</xsl:text>nbsp;
									</p>
							</td>
						</tr>
								</xsl:for-each>
					</tbody>
				</table>
				
			</body>
		</html>
	</xsl:template>

	<!-- ******************************************************************** -->
	<!--     Template layout for License section of report                    -->
	<!-- ******************************************************************** -->
	<xsl:template name="tmpl_license_info">
		<p style="margin-bottom:.0in;">
			<table>
				<tr>
					<td class="row1-1"><b>File #: </b><xsl:value-of select='LicenseNumber' /></td>
					<td class="row1-2"><b>Status: </b><xsl:value-of select='Status' /></td>
					<td class="row1-3"><b>Date: </b><xsl:value-of select='StatusDate' /></td>
					<td class="row1-4"><b>Dist: </b><xsl:value-of select='District' /></td>
					<td class="row1-5"><b>Action: </b><xsl:value-of select='Action' /></td>
				</tr>
			</table>

			<table>
				<tr>
					<td class="row2-1"><b>REG#: </b><xsl:value-of select='RegNumber' /></td>
					<td class="row2-2"><b>Date: </b><xsl:value-of select='RegDate' /></td>
					<td class="row2-3"><xsl:value-of select='Case' /></td>
					<td class="row2-4"><b>Cleared: </b><xsl:value-of select='Cleared' /></td>
					<td class="row2-5"><b>Date: </b><xsl:value-of select='ClearedDate' /></td>
					<td class="row2-6"><b>Recevd: </b><xsl:value-of select='RecvdDate' /></td>
				</tr>
			</table>

			<table>
				<tr>
					<td class="row3-1"><b>Name/Prem Addr: </b><xsl:value-of select='Licensee' /></td>
					<td class="row3-2"><xsl:value-of select="PremAddress"/></td>
					<td class="row3-3"><b>GeoCode:</b><xsl:value-of select="GeoCode"/></td>
					<td class="row3-4"><b>C.T:</b><xsl:value-of select="CensusTract"/></td>
				</tr>
			</table>

			<table>
				<tr>
					<td class="row4-1"><b>DBA<!--/Mail Addr-->:	</b><xsl:value-of select='DBA' /></td>
				</tr>
			</table>
			
			<!-- ******************************************************************** -->
			<!--      Licenses section of report                                      -->
			<!-- ******************************************************************** -->
			<table>
				<xsl:for-each select="LicenseTypes/LicenseType">
					<tr>
						<td class="row5-1">
							<xsl:if test="position() &gt; 1">
								<xsl:text disable-output-escaping="yes"> </xsl:text>
							</xsl:if>
							<xsl:if test="position()=1">
								<b><xsl:text disable-output-escaping="yes">License Types: </xsl:text></b>
							</xsl:if>
						</td>
						<td class="row5-2"><xsl:value-of select='./Type' /></td>
						<td class="row5-3"><b>MI: </b><xsl:value-of select='./MI' /></td>
						<td class="row5-4"><b>Staus: </b><xsl:value-of select='./Status' /></td>
						<td class="row5-5"><b>Date: </b><xsl:value-of select='./Date' /></td>
						<td class="row5-6"><b>Expires: </b><xsl:value-of select='./Expires' /></td>
						<td class="row5-7"><b>Dups: </b><xsl:value-of select='./Dups' /></td>
						<td class="row5-8"><b>Term: </b><xsl:value-of select='./Term' /></td>
					</tr>
				</xsl:for-each>
			</table>
			
			<!-- ******************************************************************** -->
			<!--     charges section of report                                        -->
			<!-- ******************************************************************** -->
			<table>
				<xsl:for-each select="./Charges/Descriptions">
					<tr>
						<td class="row6-1">
							<xsl:if test="position() &gt; 1">
								<xsl:text disable-output-escaping="yes"> </xsl:text>
							</xsl:if>
							<xsl:if test="position()=1">
								<b>
									<xsl:text disable-output-escaping="yes">Charges: </xsl:text>
								</b>
							</xsl:if>
						</td>
						<td class="row6-2">
							<xsl:value-of select='./Description' />
						</td>
					</tr>
				</xsl:for-each>
			</table>

			<!-- ******************************************************************** -->
			<!--     proceeding section of report                                     -->
			<!-- ******************************************************************** -->
			<table>
				<xsl:for-each select="./Proceedings/Proceeding">
					<tr>
						<td class="row7-1">
							<xsl:if test="position() &gt; 1">
								<xsl:text disable-output-escaping="yes">-  </xsl:text>
							</xsl:if>
							<xsl:if test="position()=1">
								<b>
									<xsl:text disable-output-escaping="yes">Proceedings: </xsl:text>
								</b>
							</xsl:if>
						</td>
						<td class="row7-2"><xsl:value-of select='./ProceedingType' /></td>
						<td class="row7-3"><xsl:value-of select='./ProceedingDate' /></td>
						<td class="row7-4"><b>Status: </b><xsl:value-of select='./Status' /></td>
						<td class="row7-5"><xsl:value-of select='./StatusDate' /></td>
						<td class="row7-6"><b>Decision: </b><xsl:value-of select='./Decision' /></td>
						<td class="row7-7">
							<xsl:if test="$ReportName='Legal Actions Finalized'">
								<b>POIC: </b>$<xsl:value-of select='./POICAmount' />
							</xsl:if>
						</td>
					</tr>
					<tr>
						<td><xsl:text disable-output-escaping="yes"> </xsl:text></td>
						<td colspan="6"><xsl:value-of select='./ProceedingsDetails' /></td>
					</tr>
				</xsl:for-each>
			</table>
		</p>
	</xsl:template>
</xsl:stylesheet>
