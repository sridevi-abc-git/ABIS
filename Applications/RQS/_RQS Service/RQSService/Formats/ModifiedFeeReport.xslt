<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet version="1.0"
				xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
				xmlns:msxsl="urn:schemas-microsoft-com:xslt"
				exclude-result-prefixes="msxsl"
>
	<xsl:output method="html"
				indent="yes"/>

	<xsl:template match="/ROOT">
		<xsl:call-template name="tbl_data">
		</xsl:call-template>
	</xsl:template>

	<xsl:template name="tbl_data">
		<table style="width: 6.5in; font-size: 8pt;">
			<xsl:call-template name="tbl_header"></xsl:call-template>
			<tbody>
				<xsl:for-each select="DATA">
					<xsl:sort select="PRIMARYLICENSE"/>
					<xsl:call-template name="rec">
						<xsl:with-param name="P_LICENSEINFO"
										select="." >
						</xsl:with-param>
					</xsl:call-template>
				</xsl:for-each>
			</tbody>
		</table>

	</xsl:template>

	<xsl:template name="tbl_header">
		<thead>
			<tr>
				<th colspan="6" style="font-size:1.5em; text-align:center;">
					<xsl:value-of select='/ROOT/@REPORT_NAME' />
				</th>
			</tr>	
			<tr style="padding-bottom:1em;">
				<th colspan="6" style="text-align:center;margin:0;">
					<xsl:value-of select="/ROOT/@REPORT_START_DATE"/> - <xsl:value-of select="/ROOT/@REPORT_END_DATE"/>					
				</th>
			</tr>
			<tr>
				<th style="vertical-align:bottom; border-bottom: 1px solid black; width: 15%;">File Number</th>
				<th style="vertical-align:bottom; border-bottom: 1px solid black; width: 10%;">Status</th>
				<th style="vertical-align:bottom; border-bottom: 1px solid black; width: 10%;">Outcome</th>
				<th style="vertical-align:bottom; border-bottom: 1px solid black; width: 10%;">Created Date</th>
				<th style="vertical-align:bottom; border-bottom: 1px solid black; width: 10%;">Created By</th>
				<th style="vertical-align:bottom; border-bottom: 1px solid black; width: 20%"><xsl:text disable-output-escaping='yes'> </xsl:text></th>
				<th style="vertical-align:bottom; border-bottom: 1px solid black; width: 10%; text-align:right;">Amount</th>
				<th style="vertical-align:bottom; border-bottom: 1px solid black; width: 10%; text-align:right;">Tax Amount</th>
			</tr>
		</thead>
	</xsl:template>

	<xsl:template name="rec">
		<xsl:param name="P_LICENSEINFO"
				   select="DATA"></xsl:param>
		<tr style="padding: 0; margin: 0">
			<td style="vertical-align:top;">
				<xsl:value-of select='$P_LICENSEINFO/EXTERNALFILENUM' />
			</td>
			<td style="vertical-align:top;">
				<xsl:value-of select='$P_LICENSEINFO/JOBSTATUS' />
			</td>
			<td style="vertical-align:top;">
				<xsl:value-of select='$P_LICENSEINFO/OUTCOME' />
			</td>
			<td style="vertical-align:top;">
				<xsl:value-of select='$P_LICENSEINFO/PROCESS_CREATED_DATE' />
			</td>
			<td style="vertical-align:top;">
				<xsl:value-of select='$P_LICENSEINFO/PROCESS_CREATED_BY' />
			</td>
			<td><xsl:text disable-output-escaping='yes'> </xsl:text></td>
			<td style="vertical-align:top;text-align: right;">
				<xsl:value-of select='$P_LICENSEINFO/AMOUNT' />
			</td>
			<td style="vertical-align:top;text-align: right;">
				<xsl:value-of select='$P_LICENSEINFO/TAXAMOUNT' />
			</td>
		</tr>	
		<tr style="margin-bottom:.5em;">
			<td colspan='8' style="width:90%; padding-left: 1em; border-bottom:1px solid #F0F0F0;">
				<xsl:value-of select="substring-before($P_LICENSEINFO/DESCRIPTION, '&#xd;')" />
				<br/>
				<xsl:value-of select="substring-after($P_LICENSEINFO/DESCRIPTION, '&#xa;')" />
			</td>
		</tr>
	</xsl:template>

</xsl:stylesheet>


