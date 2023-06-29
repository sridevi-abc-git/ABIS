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
          body   { font-size: 8pt; font-family: "courier new" }
          table { width: 3.0in }
          caption { font-size: 2em; border-bottom: 1px solid black; padding-bottom: 10px; }
          th			{ vertical-align: bottom; border-bottom: 1px solid #000000; padding-top:5px; }

          td			{ vertical-align: top; padding: 0px 5px 0px 5px; margin: 0; border:none; }
          tbody		{ padding-bottom: 2em; }
          .td1		{ width:  .25in; text-align: right; padding:0px 1px 0px 1px; }
          .td2		{ width:  .75in; }
          .td3		{ width: 1.25in; text-align: right; padding:0px 1px 0px 1px; }
          .td4		{ width:  .50in; text-align: right; padding:0px 1px 0px 1px; }
          .td5		{ width: 1.50in; text-align: right; padding:0px 1px 0px 1px; }

          .td1t		{ width:  .25in; border:none; padding:0px; text-align: left; }
          .td2t		{ width: 2.50in; border:none; padding:0px; }
          .td3t		{ width: 1.25in; border:none; padding:0px; text-align: right; }
          .td1t1	{ width:  .25in; border:none; padding:0px; text-align: left; font-weight: bold;}
          .td1t3	{ width:  .25in; border:none; padding:0px; text-align: right; font-weight: bold; padding-right: 1em}
          .td3t3	{ width: 1.25in; border:none; padding:0px; text-align: right; border-top: 1px solid #000000;font-weight: bold;}

        </style>
				<title>
					<xsl:value-of select='/ROOT/@REPORT_NAME' />
				</title>
			</head>
			<body>

			<xsl:call-template name="page_heading"  ></xsl:call-template>
        
        <tbody>
        <xsl:call-template name="totals">
          <xsl:with-param name="P_DETAILS"
                  select="/ROOT/TOTALS" />
        </xsl:call-template>

        <xsl:call-template name="pagebreak"></xsl:call-template>  
				<xsl:call-template name="page_heading"  ></xsl:call-template>
          
       <xsl:call-template name="tbl_data">
          <xsl:with-param name="P_DETAILS"
                  select="/ROOT/DETAILS" />
          <xsl:with-param name="P_CAPTION"
                  select='@DESCRIPTION' />
        </xsl:call-template>


        </tbody>
				
			</body>
		</html>
	</xsl:template>

  <xsl:template name='pagebreak'>
    <xsl:text disable-output-escaping='yes'> </xsl:text>
    <div style='page-break-before: always;padding-top: 20px;visibility:hidden;display:none;'>x
      <!--<xsl:text disable-output-escaping='no'>x </xsl:text>-->
    </div>
    <xsl:text disable-output-escaping='no'> </xsl:text>
  </xsl:template>

  <xsl:template name="page_heading">
    <xsl:param name="P_CAPTION"
				   select="*"></xsl:param>
    <table>
      <tbody>
        <tr style="page-break-after: always;">
          <td style="text-align: center; border:none; font-size: 1.5em; font-weight: bold;">
            <xsl:value-of select='/ROOT/@REPORT_NAME'/>
          </td>
        </tr>
        <tr>
          <td style="text-align: center; border:none; font-size: 1em; padding-top: 0px; padding-bottom: 10px">
            From Entry Date <xsl:value-of select='/ROOT/@REPORT_DATE' />
          </td>
        </tr>
      </tbody>
    </table>
  </xsl:template>

  <xsl:template name='totals'>
    <xsl:param name='P_TOTALS' select='TOTALS'></xsl:param>
    <table style="width: 4in;">
      <tbody>

        <tr>
          <td class="td1t1" colspan="2">
            <xsl:text>TO GENERAL FUND</xsl:text>
          </td>
          <td class="td3t"></td>
        </tr>
        <tr>
          <td class="td1t">1.</td>
          <td class="td2t">
            <xsl:text>General Fund</xsl:text>
            <!--<xsl:value-of select="substring(concat('General Fund', '..................................................'),1, 40)"/>-->
          </td>
          <td class="td3t">
            <xsl:value-of select='format-number($P_TOTALS/GENERALFUND, "###,###,##0.00")' /> 
          </td>
        </tr>
        <tr>
          <td class="td1t3" colspan="2">
            <xsl:text>Total General Fund</xsl:text>
          </td>
          <td class="td3t3">
            <xsl:value-of select='format-number($P_TOTALS/GENERALFUND, "###,###,##0.00")' />
          </td>
        </tr>

        <tr>
          <td class="td1t1" colspan="2" style="padding-top: 10px">
            <xsl:text>TO ABC FUND</xsl:text>
          </td>
          <td class="td3t"></td>
        </tr>
        <tr>
          <td class="td1t">2.</td>
          <td class="td2t">
            <xsl:text>ABC Funds</xsl:text>
          </td>
          <td class="td3t">
            <xsl:value-of select='format-number($P_TOTALS/ABCFUNDS, "###,###,##0.00")' />
          </td>
        </tr>
        <tr>
          <td class="td1t3" colspan="2">
            <xsl:text>Total ABC Fund</xsl:text>
          </td>
          <td class="td3t3">
            <xsl:value-of select='format-number($P_TOTALS/ABCFUNDS, "###,###,##0.00")' />
          </td>
        </tr>

        <tr>
          <td class="td1t1" colspan="2" style="padding-top: 10px">
            <xsl:text>TO APPEALS BOARD</xsl:text>
          </td>
          <td class="td3t"></td>
        </tr>
        <tr>
          <td class="td1t">3.</td>
          <td class="td2t">
            <xsl:text>AB Fees</xsl:text>
          </td>
          <td class="td3t">
            <xsl:value-of select='format-number($P_TOTALS/AB_SURCHARGE, "###,###,##0.00")' />
          </td>
        </tr>
        <tr>
          <td class="td1t3" colspan="2">
            <xsl:text>Total Appeals Fund</xsl:text>
          </td>
          <td class="td3t3">
            <xsl:value-of select='format-number($P_TOTALS/AB_SURCHARGE, "###,###,##0.00")' />
          </td>
        </tr>

        <tr>
          <td class="td1t1" colspan="2" style="padding-top: 10px">
            <xsl:text>TO MOTOR VEHICLE ACCOUNT</xsl:text>
          </td>
          <td class="td3t"></td>
        </tr>
        <tr>
          <td class="td1t">4.</td>
          <td class="td2t">
            <xsl:text>DMV Fees</xsl:text>
          </td>
          <td class="td3t">
            <xsl:value-of select='format-number($P_TOTALS/DMV_SURCHARGE_AMT, "###,###,##0.00")' />
          </td>
        </tr>
        <tr>
          <td class="td1t3" colspan="2">
            <xsl:text>Total Motor Vehicle Account</xsl:text>
          </td>
          <td class="td3t3">
            <xsl:value-of select='format-number($P_TOTALS/DMV_SURCHARGE_AMT, "###,###,##0.00")' />
          </td>
        </tr>

        <tr>
          <td class="td1t" style="padding-top: 10px">5.</td>
          <td class="td2t">
            <xsl:text>Dishonored Check Charges</xsl:text>
          </td>
          <td class="td3t">
            <xsl:value-of select='format-number($P_TOTALS/DISHONOREDCHARGE, "###,###,##0.00")' />
          </td>
        </tr>

        <tr>
          <td class="td1t1" colspan="2" style="padding-top: 10px">
            <xsl:text>TO FINGERPRINT FEES</xsl:text>
          </td>
          <td class="td3t"></td>
        </tr>
        <tr>
          <td class="td1t">6.</td>
          <td class="td2t">
            <xsl:text>Fingerprint Fees</xsl:text>
          </td>
          <td class="td3t">
            <xsl:value-of select='format-number($P_TOTALS/FINGERPRINT, "###,###,##0.00")' />
          </td>
        </tr>
        <tr>
          <td class="td1t">7.</td>
          <td class="td2t">
            <xsl:text>RBS Fingerprint Fees</xsl:text>
          </td>
          <td class="td3t">
            <xsl:value-of select='format-number($P_TOTALS/RBSFP, "###,###,##0.00")' />
          </td>
        </tr>
        <tr>
          <td class="td1t3" colspan="2">
            <xsl:text>Total Fingerprint Fees</xsl:text>
          </td>
          <td class="td3t3">
            <xsl:value-of select='format-number($P_TOTALS/FINGERPRINTTOTAL, "###,###,##0.00")' />
          </td>
        </tr>

        <tr>
        <td class="td1t" style="padding-top: 10px">8.</td>
        <td class="td2t">
          <xsl:text>RBS Fees</xsl:text>
        </td>
        <td class="td3t">
          <xsl:value-of select='format-number($P_TOTALS/RBSCC, "###,###,##0.00")' />
        </td>
        </tr>

        <tr>
        <td class="td1t">9.</td>
        <td class="td2t">
          <xsl:text>Other Miscellaneous Fees</xsl:text>
        </td>
        <td class="td3t">
          <xsl:value-of select='format-number($P_TOTALS/MISCFEES, "###,###,##0.00")' />
        </td>
        </tr>


        <tr>
          <td class="td1t3" colspan="2" style="padding-top: 10px">
            <xsl:text>GRAND TOTAL REVENU ALLOCATED</xsl:text>
          </td>
          <td class="td3t3">
            <xsl:value-of select='format-number($P_TOTALS/GRANDTOTAL, "###,###,##0.00")' />
          </td>
        </tr>
        
      </tbody>
    </table>
  </xsl:template>

	<xsl:template name="tbl_data">
		<xsl:param name="P_DETAILS"
				   select="DETAIL"></xsl:param>
		<xsl:param name="P_CAPTION"
				   select="*"></xsl:param>
		<table>
			<caption>
				<xsl:value-of select='$P_CAPTION'/>
			</caption>
			<xsl:call-template name="tbl_header"  ></xsl:call-template>
			<tbody>
				<xsl:for-each select="$P_DETAILS/DETAIL">
					<xsl:call-template name="rec" >
						<xsl:with-param name="P_DETAIL"
										select=".">
						</xsl:with-param>
					</xsl:call-template>
				</xsl:for-each>

        <tr>
          <td class="td1t3" colspan="3" style="padding-top: 5px">
            <xsl:text>Grand Total:</xsl:text>
          </td>
          <td class="td3t3" style="border-bottom: 1px solid #000000;">
            <xsl:value-of select='format-number(/ROOT/TOTALS/GRANDTOTAL, "###,###,##0.00")' />
          </td>
        </tr>

      </tbody>
		</table>
	</xsl:template>

	<xsl:template name="tbl_header">
		<thead>
			<tr>
				<th>License Type</th>
				<th>Discription</th>
				<!--<th>Earned Amt</th>-->
				<th>Count</th>
				<th>Sub-Total</th>
			</tr>
		</thead>
	</xsl:template>

	<xsl:template name="rec">
		<xsl:param name="P_DETAIL"
				   select="."></xsl:param>
		<tr>
			<td class="td1">
				<xsl:value-of select='$P_DETAIL/LICENSETYPE' />
			</td>
			<td class="td2">
				<xsl:value-of select='$P_DETAIL/DESCRIPTION' />
			</td>
			<!--<td class="td3">
				<xsl:value-of select='format-number($P_DETAIL/EARNEDAMOUNT, "###,###,##0.00")' />
			</td>-->
			<td class="td4">
				<xsl:value-of select='format-number($P_DETAIL/CNT, "#0")' />
			</td>
			<td class="td5">
				<xsl:value-of select='format-number($P_DETAIL/AMOUNTSUB, "###,###,##0.00")' />
			</td>
			<!--<td class="td6">
        <xsl:text >this is a test</xsl:text> 
			</td>-->
		</tr>
	</xsl:template>

</xsl:stylesheet>
