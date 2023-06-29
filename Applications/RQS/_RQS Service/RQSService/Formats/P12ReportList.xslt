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
		<table style="width: 7.0in; margin: auto; font-size: 8pt;">
			<xsl:call-template name="tbl_header"></xsl:call-template>
			<tbody>
				<xsl:for-each select="DATA">
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
				<th colspan="4"
					style="font-size:0.8em; text-align:right; padding-right:2em; font-weight:normal">
					 Licensees Processed: <xsl:value-of select="/ROOT/@RECORD_CNT"/>
				</th>
			</tr>
			<tr style="padding-bottom:1em;">
				<th colspan="4"
					style="font-size:1.5em; text-align:center;">
					<xsl:value-of select="/ROOT/@REPORT_NAME"/>
				</th>
			</tr>
			<tr style="border-bottom: 2px solid black;">
				<th style="vertical-align:bottom; border-bottom: 1px solid black; text-align:left; padding-left:2em; width:3.6in;">Entity</th>
				<th style="vertical-align:bottom; border-bottom: 1px solid black; text-align:left; padding-left:1em; width:.9in;">District</th>
				<th style="vertical-align:bottom; border-bottom: 1px solid black; text-align:left; padding-left:1.5em; width:1.5in;">TYPE</th>
				<th style="vertical-align:bottom; border-bottom: 1px solid black; width:1in;">Base File #</th>
			</tr>
		</thead>
	</xsl:template>

	<xsl:template name="rec">
		<xsl:param name="P_LICENSEINFO"
				   select="DATA"></xsl:param>
		<tr style="padding: 0em 0; margin: 0; border-bottom: 1px solid #e0e0e0;">
			<td style="vertical-align:top; page-break-inside: avoid; border-bottom: 1px solid #e0e0e0;">
				<xsl:value-of select='$P_LICENSEINFO/PRIMARYLICENSE' />
			</td>
			<td style="vertical-align:top; page-break-inside: avoid; text-align:right; padding-right: 3em; border-bottom: 1px solid #e0e0e0;">
				<xsl:value-of select='$P_LICENSEINFO/BASEFILEOFFICECODECORRAL' />
			</td>
			<td style="vertical-align:top; page-break-inside: avoid; border-bottom: 1px solid #e0e0e0; padding-left: 1em;">
				<xsl:call-template name="split">
					<xsl:with-param name="pText"
									select="$P_LICENSEINFO/PRIMARYSLTCODESANDSTATUS"/>
					<xsl:with-param name="pFirst"
									select="1"/>
				</xsl:call-template>
			</td>
			<td style="vertical-align:top; text-align:right; padding-right: 1em; border-bottom: 1px solid #e0e0e0;">
				<xsl:value-of select='$P_LICENSEINFO/P12MASTERLICENSENO' />
			</td>
		</tr>
	</xsl:template>

	<xsl:template name="split">
		<xsl:param name="pText"
				   select="."/>
		<xsl:param name="pFirst"
				   select="."/>
		<xsl:if test="string-length($pText)">
			<xsl:if test="$pFirst=0">
				<br/>
			</xsl:if>
			<xsl:variable name="vToken"
						  select="substring-before(concat($pText,','), ',')"/>
			<xsl:value-of select="$vToken"/>

			<xsl:call-template name="split">
				<xsl:with-param name="pText"
								select="substring-after($pText, ',')"/>
				<xsl:with-param name="pFirst"
								select="0"/>
			</xsl:call-template>
		</xsl:if>
	</xsl:template>

</xsl:stylesheet>


