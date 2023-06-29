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
          .td1		{ width: 2.00in; }
          .td2		{ width: 0.70in; text-align: right; }
          .td3		{ width: 0.70in; text-align: right; }
          .td4		{ width: 2.25in; }
          .td5		{ width:  .60in; text-align: center; }
          .td6		{ width:  .70in; }


        </style>
        <title>
          <xsl:value-of select='/ROOT/@REPORT_NAME' />
        </title>
      </head>
      <body>
        <xsl:call-template name="page_heading"  ></xsl:call-template>

        <xsl:call-template name="tbl_data">
          <xsl:with-param name="P_ACCUSATIONS"
                  select="ACCUSATIONS" />
        </xsl:call-template>
      </body>
    </html>
  </xsl:template>

  <xsl:template name="page_heading">
    <table>
      <tbody>
        <tr>
          <td style="width:35%; border:none; font-size: 1.3em;">
            Report For <xsl:value-of select='/ROOT/@REPORT_DATE' />
          </td>
          <td style="width:30%; text-align: center; border:none; font-size: 1.3em;">
            <xsl:value-of select='/ROOT/@REPORT_NAME'/>
          </td>
          <td style="width:34%; border:none; font-size: 1.3em;"></td>
        </tr>
      </tbody>
    </table>
  </xsl:template>

  <xsl:template name="tbl_data">
    <xsl:param name="P_ACCUSATIONS" select="ACCUSATIONS"></xsl:param>
    <table>
      <xsl:call-template name="tbl_header"  ></xsl:call-template>
      <tbody>
        <xsl:for-each select="$P_ACCUSATIONS">
          <xsl:call-template name="rec" >
            <xsl:with-param name="P_ACCUSATIONS"
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
        <th>District Office</th>
        <th>Regristration Number</th>
        <th>License Number</th>
        <th>Primary Licensee</th>
        <th>Created Date</th>
        <th>Registered Date</th>
        <th>Accusation Status</th>
      </tr>
    </thead>
  </xsl:template>

  <xsl:template name="rec">
    <xsl:param name="P_ACCUSATIONS"
				   select="ACCUSATIONS"></xsl:param>

    <tr class="rec">
      <td class="td1">
        <xsl:value-of select='$P_ACCUSATIONS/OFFICENAME' />
      </td>
      <td class="td2">
        <xsl:element name="a">
          <xsl:attribute name="href">
            <xsl:value-of disable-output-escaping="yes" select="translate(@URL, '|', '&amp;')"/>
          </xsl:attribute>
          <xsl:value-of select='$P_ACCUSATIONS/REGNUMBER' />
        </xsl:element>
      </td>
      <td class="td3">
        <xsl:element name="a">
          <xsl:attribute name="href">
            <xsl:value-of disable-output-escaping="yes" select="translate(@LICENSEJOBID, '|', '&amp;')"/>
          </xsl:attribute>
          <xsl:value-of select='$P_ACCUSATIONS/LICENSENUMBER' />
        </xsl:element>
      </td>
      <td class="td4">
        <!--<xsl:element name="div">-->
          <xsl:value-of disable-output-escaping="yes" select="translate($P_ACCUSATIONS/PRIMARYLICENSEE, '&amp;&amp;', '&amp;')" />
        <!--</xsl:element>-->
       </td>
       <td class="td5">
        <xsl:value-of select='$P_ACCUSATIONS/CREATEDDATE' />
      </td>
      <td class="td5">
        <xsl:value-of select='$P_ACCUSATIONS/REGISTEREDDATE' />
      </td>
      <td class="td6">
        <xsl:value-of select='$P_ACCUSATIONS/STATUSNAME' />
      </td>
    </tr>
  </xsl:template>

</xsl:stylesheet>
