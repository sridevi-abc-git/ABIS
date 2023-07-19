<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
				xmlns:msxsl="urn:schemas-microsoft-com:xslt" exclude-result-prefixes="msxsl"
>
  <xsl:output method="html" indent="yes"/>
  <xsl:param  name="HEADING" >1</xsl:param >
  <xsl:param  name="CREATE_DATE">2</xsl:param >
  <xsl:param name="DISTRICT_FLG" select="/ABC19/OFFICE/@DISTRICT_FLG"></xsl:param>



<xsl:template match="/ROOT/*">
	<html>
		<head></head>
		<body style="font-family:'Courier New';font-size:10pt;">
			
	<div style="page-break-after: always; width:7.5in; height:9.5; border:1px solid gray;">

		<xsl:call-template name="page_heading" />

		<xsl:call-template name="tmpl_license_info" />

		<xsl:call-template name="tmpl_address" />

		<xsl:call-template name="tmpl_actions" />

		<xsl:call-template name="tmpl_license_types">
            <xsl:with-param name="LicenseTypes" select="/*/LicenseTypes" />
        </xsl:call-template>

		<xsl:call-template name="tmpl_charges">
            <xsl:with-param name="Charges" select="/*/Charges" />
        </xsl:call-template>

        <xsl:call-template name="tmpl_proceedings">
            <xsl:with-param name="Proceedings" select="/*/Proceedings" />
        </xsl:call-template>
	</div>
		</body>
	</html>	
</xsl:template>

	
<xsl:template name="page_heading">
	<header style="text-align:center; font-size:10pt;">
		<div>
			California Department of Alcoholic Beverage Control
		</div>
		<div>
			<xsl:value-of select='/ROOT/@REPORT_NAME' /> from <xsl:value-of select='/ROOT/@START_DATE' /> to <xsl:value-of select='/ROOT/@END_DATE' /> by File Number
		</div>
	</header>
</xsl:template>	

<!-- ******************************************************************** -->
<!--     Template layout for License section of report                    -->
<!-- ******************************************************************** -->
<xsl:template name="tmpl_license_info">
	<div style="margin-bottom:.2in;">
		<table>
			<tbody>
				<tr>
					<td class="label">File #:</td>
					<td><xsl:value-of select='LicenseNumber' /></td>
				</tr>
				<tr>
					<td class="label">Status:</td>
					<td><xsl:value-of select='Status' /> <xsl:value-of select='StatusDate' /></td>
				</tr>
				<tr>
					<td class="label">Licensee:</td>
					<td><xsl:value-of select='Licensee' /></td>
				</tr>
				<tr>
					<td class="label" style="padding-right: 1em;">Business Name:</td>
					<td><xsl:value-of select='DBA' /></td>
				</tr>
			</tbody>
		</table>
	</div>
</xsl:template>	
	
<!-- ******************************************************************** -->
<!--     Template layout for addresses section of report                  -->
<!-- ******************************************************************** -->
<xsl:template name="tmpl_address">
	<div style="margin-bottom: .2in;">
		<table style="width:100%;">
			<tbody>
				<tr>
					<td class="label" style="width: 17%;">Premise Address:</td>
					<td style="width: 34%; valign:bottom;"><xsl:value-of select='PremAddressLine1' />
											<xsl:value-of select='PremAddressLine2' />
					</td>
					<td class="label" style="width: 17%;">Mailing Address:</td>
					<td style="valign:bottom;"><xsl:value-of select='MailingAddressLine1' /> 
						<xsl:value-of select='MailingAddressLine2' />
					</td>
				</tr>
				<tr>
					<td></td>
					<td><xsl:value-of select='PremAddressUsCity' />, 
						<xsl:value-of select='PremAddressState' />  
						<xsl:value-of select='PremAddressZipCode' />
					</td>
					<td></td>
					<td><xsl:value-of select='MailingAddressCity' />, 
						<xsl:value-of select='MailingAddressState' /> 
						<xsl:value-of select='MailingAddressZipCode' />
					</td>
				</tr>
			</tbody>
		</table>
		<div>
			<div class="label" style="display: inline-block;">Geo Code:</div>
			<div style="display: inline-block;"><xsl:value-of select='GeoCode' /></div>
			<div class="label" style="display: inline-block; padding-left: 2em;">Census Tract:</div>
			<div style="display: inline-block;"><xsl:value-of select='CensusTract' /></div>
		</div>
	</div>
</xsl:template>	


<!-- ******************************************************************** -->
<!--     Template layout for Licenses section of report                   -->
<!-- ******************************************************************** -->
<xsl:template name="tmpl_actions">
	<div style="margin-bottom: .2in;">
		<table style="width: 100%;">
			<tbody>
				<tr>
					<td class="label" style="width: 10%;">District:</td>
					<td class="info" style="width: 35%;"><xsl:value-of select='District' /></td>
					<td style="width: 10%;"></td>
					<td></td>
				</tr>
				<tr>
					<td class="label">Action:</td>
					<td class="info"><xsl:value-of select='Action' /></td>
					<td class="label">Cleared:</td>
					<td class="info"><xsl:value-of select='Cleared' /></td>
				</tr>
				<tr>
					<td class="label">REG #:</td>
					<td class="info"><xsl:value-of select='RegNumber' /></td>
					<td class="label">Date:</td>
					<td class="info"><xsl:value-of select='ClearedDate' /></td>
				</tr>
				<tr>
					<td class="label">Date:</td>
					<td class="info"><xsl:value-of select='RegDate' /></td>
					<td class="label">Received:</td>
					<td class="info"><xsl:value-of select='RecvdDate' /></td>
				</tr>
				<tr>
					<td class="label">Case:</td>
					<td class="info"><xsl:value-of select='Case' /></td>
					<td class="label">Agency</td>
					<td class="info"><xsl:value-of select='Agency' /></td>
				</tr>
			</tbody>
		</table>
	</div>
</xsl:template>	


<!-- ******************************************************************** -->
<!--     Template layout for Licenses section of report                   -->
<!-- ******************************************************************** -->
<xsl:template name="tmpl_license_types">
	<xsl:param name="LicenseTypes"></xsl:param>
	<div style="margin-bottom: .2in;">
		<header>
			Licenses
		</header>
		<table style="width: 70%; text-align: center;">
			<thead>
				<tr>
					<th style="width: 5%;">Type</th>
					<th style="width: 5%;">MI</th>
					<th style="width: 15%;">Staus</th>
					<th style="width: 15%;">Date</th>
					<th style="width: 15%;">Expires</th>
					<th style="width: 7%;">Dups</th>
					<th style="width: 8%;">Term</th>
				</tr>
			</thead>
			<tbody>
				<xsl:for-each select="LicenseTypes">
					<tr>
						<td><xsl:value-of select='./LicenseType' /></td>
						<td><xsl:value-of select='./MI' /></td>
						<td><xsl:value-of select='./Status' /></td>
						<td><xsl:value-of select='./Date' /></td>
						<td><xsl:value-of select='./Expires' /></td>
						<td><xsl:value-of select='./Dups' /></td>
						<td><xsl:value-of select='./Term' /></td>
					</tr>
				</xsl:for-each>
			</tbody>
		</table>
	</div>
</xsl:template>	


<!-- ******************************************************************** -->
<!--     Template layout for charges section of report                    -->
<!-- ******************************************************************** -->
<xsl:template name="tmpl_charges">
	<xsl:param name="Charges"></xsl:param>
	<div style="margin-bottom: .2in;">
		<header>Charges</header>
		<xsl:for-each select="Charges">
			<div class="info">
				<xsl:value-of select='./Description' />
			</div>
		</xsl:for-each>
	</div>
</xsl:template>	


<!-- ******************************************************************** -->
<!--     Template layout for proceeding section of report                 -->
<!-- ******************************************************************** -->
<xsl:template name="tmpl_proceedings">
	<xsl:param name="Proceedings"></xsl:param>
		<div style="margin-bottom: .2in;">
			<header>Proceedings</header>
			<table style="width: 100%; text-align: center;">
				<thead>
					<tr>
						<th style="width: 15%; text-align: left; text-indent: 1em;">Type</th>
						<th style="width: 15%;">Proceeding Date</th>
						<th style="width: 15%;">Status</th>
						<th style="width: 15%;">Status Date</th>
						<th style="text-align: left; text-indent:1em;">Decision</th>
						<th style="width: 10%;">Amount</th>
					</tr>
				</thead>
				
				<tbody>
					<!--loop through records-->
					<xsl:for-each select="Proceedings">
						<tr>
							<td style="text-align: left;"><xsl:value-of select='./ProceedingType' /></td>
							<td><xsl:value-of select='./ProceedingDate' /></td>
							<td><xsl:value-of select='./Status' /></td>
							<td><xsl:value-of select='./StatusDate' /></td>
							<td style="text-align:left;"><xsl:value-of select='./Decision' /></td>
							<td style="text-align:right;"><xsl:value-of select='./POICAmount' /></td>
						</tr>
					</xsl:for-each>
				</tbody>
			</table>
		</div>
</xsl:template>	


</xsl:stylesheet>
