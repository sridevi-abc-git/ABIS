<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:msxsl="urn:schemas-microsoft-com:xslt" exclude-result-prefixes="msxsl"
>
  <xsl:output method="html" indent="yes"/>

  <xsl:param  name="HEADING" ></xsl:param >
  <xsl:param  name="CREATE_DATE"></xsl:param >

  <xsl:template match="/ROOT">
	  <xsl:text disable-output-escaping="yes">&lt;!DOCTYPE html&gt;</xsl:text>
	  <html  xmlns="http://www.w3.org/1999/xhtml">
		  <head>
			  <style type="text/css">
				  body   { font-size: 7pt; }
				  table { width: 100%;  }
				  caption { font-size: 2em; border-bottom: 1px solid black; padding-bottom: 10px;}
				  th			{ vertical-align: bottom; border-bottom: 1px solid #000000; padding-top:5px; }

				  td			{ vertical-align: top; padding: 3px 5px 2px 5px; margin: 0; }
				  tbody		{ padding-bottom: 2em; }
				  .td3		{ width:  0.6in; text-align: right; }
				  .td4		{ width:  2.0in; }
				  .td5		{ width:  1.1in; }
				  .td6		{ width:   .7in; text-align: center; }
				  .td7		{ width:   .3in; }
				  .td8		{ width:   .4in; text-align: center; }

				  .td9		{ width:   .7in; text-align: center; }
				  .td10		{ width:  1.0in; }
				  .td11		{ width:   .7in; }
				  .td12		{ width:   .5in; }
				  .td13		{ width:   .5in; }

			  </style>
			  <title>
				  <xsl:value-of select='/ROOT/@REPORT_NAME' />
			  </title>
		  </head>
		  <body>
			  <xsl:call-template name="page_heading"  ></xsl:call-template>

			  <xsl:for-each select="OFFICE">
				  <table style="width:100%; font-size:1.5em;">
					  <tr>
						  <td style="padding: 2em 0 0em 0; width:60%">
							  Agency <xsl:value-of select="@OFFICENAME"/>
						  </td>
						  <td style="padding: 2em 0 0em 0;"> NCIC No. <xsl:value-of select="@ORINUMBER"/></td>
					  </tr>
						  </table>
				  
					  <table class="">
						  <xsl:call-template name="rpt-heading"/>
						  <tbody>
							  <xsl:for-each select="DATA">
								  <xsl:call-template name="rpt-data"/>
							  </xsl:for-each>
						  </tbody>
					  </table>
				  </xsl:for-each>
		  </body>
	  </html>
  </xsl:template>

	<xsl:template name="page_heading">
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

  <!-- ******************************************************************** -->
  <!--     Template layout                       -->
  <!-- ******************************************************************** -->
  <xsl:template name="rpt-heading">
	  <thead>
		  <tr>
			  <th style="border-bottom: 1px solid #000000; padding-top:5px;" >ABC REPORT NUMBER</th>
			  <th style="border-bottom: 1px solid #000000; padding-top:5px;" >NAME</th>
			  <th style="border-bottom: 1px solid #000000; padding-top:5px;" >RACE</th>
			  <th style="border-bottom: 1px solid #000000; padding-top:5px;" >BIRTHDATE</th>
			  <th style="border-bottom: 1px solid #000000; padding-top:5px;" >Juvenile</th>
			  <th style="border-bottom: 1px solid #000000; padding-top:5px;" >SEX</th>
			  <th style="border-bottom: 1px solid #000000; padding-top:5px;" >DATE ARREST</th>
			  <th style="border-bottom: 1px solid #000000; padding-top:5px;" >LEVEL</th>
			  <th style="border-bottom: 1px solid #000000; padding-top:5px;">CHARGES</th>
			  <th style="border-bottom: 1px solid #000000; padding-top:5px;">STATUS</th>
			  <th style="border-bottom: 1px solid #000000; padding-top:5px;">ARRESTING INVESTIGATOR/BADGE</th>
        </tr>
      </thead>
  </xsl:template>

  <!-- ******************************************************************** -->
  <!--     Template layout                       -->
  <!-- ******************************************************************** -->
  <xsl:template name="rpt-data">
	  <tr>
		  <td class="td3"
			  style="border-bottom: 1px solid #E0E0E0; ">
			  <xsl:value-of select="ABCREPORTNUM"/>
		  </td>
		  <td class="td4"
			  style="border-bottom: 1px solid #E0E0E0; ">
			  <xsl:value-of select="FORMATTEDNAME"/>
		  </td>
		  <td class="td5"
			  style="border-bottom: 1px solid #E0E0E0; ">
			  <xsl:value-of select="RACE"/>
		  </td>
		  <td class="td6"
			  style="border-bottom: 1px solid #E0E0E0; ">
			  <xsl:value-of select="BIRTHDATE"/>
		  </td>
		  <td class="td7"
			  style="border-bottom: 1px solid #E0E0E0; ">
			  <xsl:value-of select="JUVENILE"/>
		  </td>
		  <td class="td8"
			  style="border-bottom: 1px solid #E0E0E0; ">
			  <xsl:value-of select="GENDER"/>
		  </td>
		  <td class="td9" style="border-bottom: 1px solid #E0E0E0; ">
			  <xsl:value-of select="ARRESTDATE"/> 
		  </td>
		  <td class="td10" style="border-bottom: 1px solid #E0E0E0; padding-top: 0px;">
          <xsl:value-of select="VIOLATIONLEVEL"/>
        </td>
		  <td class="td11" style="border-bottom: 1px solid #E0E0E0; padding-top: 0px; ">
          <xsl:value-of disable-output-escaping="yes" select="CHARGES"/>
        </td>
		  <td class="td12" style="border-bottom: 1px solid #E0E0E0; padding-top: 0px; ">
          <xsl:value-of select="VIOLATIONSTATUS"/>
        </td>
		  <td class="td13" style="border-bottom: 1px solid #E0E0E0; padding-top: 0px; ">
          <xsl:value-of select="ARRESTINGINVESTIGATOR"/>
        </td>

      </tr>
  </xsl:template>

  <!-- ******************************************************************** -->
  <!--     Template layout                       -->
  <!-- ******************************************************************** -->
  <xsl:template name="rpt-footer">

  </xsl:template>
  
</xsl:stylesheet>
