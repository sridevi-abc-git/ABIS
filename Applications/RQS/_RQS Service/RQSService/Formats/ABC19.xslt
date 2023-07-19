<?xml version="1.0" encoding="utf-8"?>
<!--
*******************************************************************************	
	File:		ABC19.xslt
	Author:		Timothy J. Lord

	Description:	Layout form for ABC 19 report.

    $Rev: 51 $  
    $Date: 2018-09-01 12:02:56 -0700 (Sat, 01 Sep 2018) $
    Last Changed By:  $Author: TLord $

*****************************************************************************
	07/16/2015	  7753 - Change verbiage for 5a header
	02/24/2016	  9059 - Change verbiage for column header in section 18
	11/07/2016	 10918 - Added displaying report dates for yearly reports
*****************************************************************************
-->	
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:msxsl="urn:schemas-microsoft-com:xslt" exclude-result-prefixes="msxsl"
>
  <xsl:output method="html" indent="yes"/>
  <xsl:param  name="HEADING" >1</xsl:param >
  <xsl:param  name="CREATE_DATE">2</xsl:param >
  <xsl:param name="DISTRICT_FLG" select="/ABC19/OFFICE/@DISTRICT_FLG"></xsl:param>
  
<xsl:template match="/ABC19">
		<xsl:text disable-output-escaping="yes">&lt;!DOCTYPE html&gt;</xsl:text>
	<html  xmlns="http://www.w3.org/1999/xhtml">
		<head>
			<style type="text/css">
				body			{ font-size: 8pt; }

				table			{ border-collapse: collapse; border: none; font-size: 0.75em; width:100%; padding:0; margin:0; page-break-inside: avoid }
				th,
				td				{ vertical-align: top; padding: 0.0em 0em; margin: 0; font-weight: normal; text-align: left; text-indent:0.3em; page-break-inside: avoid; }

				.th				{ border-bottom:1px solid #000000; bold; padding:0.2em 0.3em 0.3em 0.2em; }
				
				.th-1			{ border-right:1px solid #000000; font-weight: bold; padding:0.1em 0.3em 0.3em 0.6em; text-indent:-0.4em }
				.th-1-last		{ font-weight: bold; padding:0.1em 0.3em 0.3em 0.6em; text-indent:-0.4em }
				.td-1			{ border-right:1px solid #000000; text-align: center; padding: 0.2em 0.2em;  }
				.td-1-last		{ text-align: center; padding: 0.2em 0.2em;  }

				.th-2			{ border-bottom:1px solid #000000; text-align: center; min-height:2.3em; padding:0.3em 0em; font-weight: bold; }
				.td-2			{ border-right:1px solid #000000; border-bottom:1px solid #000000; padding: 0.2em 0.2em; }
				.td-2-right		{ border-right:1px solid #000000; border-bottom:1px solid #000000; text-align: right; padding-right:0.2em; }
				.td-2-last		{ border-bottom:1px solid #000000; text-align: right; padding: 0.2em 0.2em; }

				.border			{ border:1px solid #000000; }
				.border-2		{ border:1px solid #000000; padding:0.3em 0em; font-weight: bold; }
				.border-right	{ border-right:1px solid #000000; }
				.no-bottom		{ border-bottom-width: 0; }
				.no-top			{ border-top-width: 0; }

				.center			{ text-align: center; }
				.right			{ text-align: right: padding-right: 0.2em; }
			</style>
			<title>
				<xsl:value-of select='/ROOT/@REPORT_NAME' />
			</title>
		</head>
		<body>

			<p style="border-bottom-style:solid;padding-bottom:3px;border-bottom-width:1px;margin-bottom:0.2em;">
					ACTIVITY REPORT
			</p>
			<p>
				<table class="border" >
					<tbody>
						<tr>
							<td><xsl:call-template name="section1-5b"/></td>
						</tr>
					</tbody>
				</table>
				
			</p>
					<p style="padding-bottom: 0.1em; margin-bottom: 0.1em;">
						I. LICENSING APPLICATIONS AND INVESTIGATIONS
					</p>
					<p>
						<table class="border">
							<thead>
								<tr>
									<th class="border" style="width:25%;">6. COURTESY ABC-211s"</th>
									<th class="border" style="width:25%;">7. ABC-211s TAKEN FOR THIS OFFICE</th>
									<th class="border" style="width:30%;">8. ABC-220 REPORTS</th>
									<th class="border" style="width:8%;">9. Licensing Assignments ABC-61</th>
									<th class="border" style="width:7%;">10. Total ABC-211s Received</th>
								</tr>
							</thead>
							<tbody>
								<tr>
									<td class="border-right">
										<xsl:call-template name="section-6">
											<xsl:with-param name="COURTESTYABC211"
															select="//*/COURTESTYABC211" />
										</xsl:call-template>
									</td>
									<td class="border-right">
										<xsl:call-template name="section-7">
											<xsl:with-param name="TAKENABC211"
															select="//*/TAKENABC211" />
										</xsl:call-template>
									</td>
									<td class="border-right">
										<xsl:call-template name="section-8">
											<xsl:with-param name="ABC220"
															select="//*/ABC220" />
											<xsl:with-param name="COUNTABC211"
															select="//*/COUNTABC211"/>
										</xsl:call-template>
									</td>
									<td class="border-right">
										<xsl:call-template name="section-9">
											<xsl:with-param name="ABC220"
															select="//*/ABC220" />
											<xsl:with-param name="COUNTABC211"
															select="//*/COUNTABC211"/>
										</xsl:call-template>
									</td>
									<td class="border-right">
										<xsl:call-template name="section-10">
											<xsl:with-param name="ABC220"
															select="//*/ABC220" />
											<xsl:with-param name="COUNTABC211"
															select="//*/COUNTABC211"/>
										</xsl:call-template>
									</td>
								</tr>
							</tbody>
						</table>
					</p>
					<p style="padding-bottom: 0.1em; margin-bottom: 0.1em;">
						II. ENFORCEMENT/COMPLIANCE/DISCIPLINARY
					</p>
					<p>
						<table class="border">
							<thead>
								<tr>
									<th class="border-2" style="width:50%;">12. Assignments (ABC-61)</th>
									<th class="border-2" style="width:30%;">13. Arrests/Citations</th>
									<th></th>
								</tr>
							</thead>
							<tbody>
								<tr>
									<td class="border-right">
										<!--section 12-->
										<xsl:call-template name="section-12">
											<xsl:with-param name="ABC61"
															select="//*/ABC61" />
										</xsl:call-template>
									</td>
									<td class="border-right">
										<!--section 13-->
										<xsl:call-template name="section-13">
											<xsl:with-param name="ABC61"
															select="//*/ABC61" />
										</xsl:call-template>
									</td>
									<td class="border-right">
										<xsl:call-template name="section-14-15"/>
									</td>
								</tr>
							</tbody>
						</table>
					</p>

					<p style="padding-bottom: 0.1em; margin-bottom: 0.1em;">
						<xsl:text disable-output-escaping="yes">&amp;</xsl:text>nbsp;
					</p>
					<p style="page-break-inside: avoid;">
						 <!--style="page-break-before:always;">-->
						<table class="border">
							<thead>
								<tr>
									<th class="border-2" style="width:50%;">16. Minor Decoy Program - On Sale</th>
									<th class="border-2">17. Minor Decoy Program - Off Sale</th>
								</tr>
							</thead>
							<tbody>
								<tr>
									<td class="border-right">
										<!--section 16-->
										<xsl:call-template name="section-16"/>
									</td>
									<td class="border-right">
										<!--section 17-->
										<xsl:call-template name="section-17"/>
									</td>
								</tr>
							</tbody>
						</table>
					</p>

					<p style="padding-bottom: 0.1em; margin-bottom: 0.1em;">
						<xsl:text disable-output-escaping="yes">&amp;</xsl:text>nbsp;
					</p>
					<p style="page-break-inside: avoid;">
						<table class="border" style="margin-top: 1em;">
							<thead>
								<tr>
									<th class="border-2" style="width:50%;">18. Shoulder Tap Program</th>
									<th class="border-2">19. Task Forces, Special Events and IMPACT Program</th>
								</tr>
							</thead>
							<tbody>
								<tr>
									<td class="border-right">
										<!--section 18-->
										<xsl:call-template name="section-18"/>
									</td>
									<td class="border-right">
										<!--section 19-->
										<xsl:call-template name="section-19"/>
									</td>
								</tr>
							</tbody>
						</table>
					</p>
		</body>
	</html>
  </xsl:template>

  
  
  <!-- ******************************************************************** -->
  <!--     Template layout first line section 1 - 5b                        -->
  <!-- ******************************************************************** -->
  <xsl:template name="section1-5b">
		  
   <table>
      <thead>
        <tr>
          <th class="th-1" style="">1. DISTRICT OR BRANCH OFFICE</th>
          <th class="th-1" style="width: 10%;">
			<xsl:choose>
				<xsl:when test="/ABC19/MONTHYEAR !=''">
					2. MONTH AND YEAR					
				</xsl:when>
				<xsl:otherwise>
					2. REPORT FOR
				</xsl:otherwise>
			</xsl:choose>
		  </th>
          <th class="th-1" style="width: 15%;">3. PREMISES VISITED - LICENSING </th>
          <th class="th-1" style="width: 15%;">4. PREMISES VISITED - ENFORCEMENT</th>
          <th class="th-1" style="width: 15%;">5a. APPLICATION WAIT TIME IN DAYS</th>
          <th class="th-1-last" style="width: 15%;">5b. MAIL-INS AWAITING INPUT</th>
        </tr>
      </thead>
		
        <tbody>
            <tr>
                <td class="td-1"><xsl:value-of select="/ABC19/OFFICE"/></td>
                <td class="td-1">
					<xsl:choose>
						<xsl:when test="/ABC19/MONTHYEAR !=''">
							<xsl:value-of select="/ABC19/MONTHYEAR"/>					
						</xsl:when>
						<xsl:otherwise>
							<xsl:value-of select="/ABC19/REPORTDATES"/>
						</xsl:otherwise>
					</xsl:choose>
				</td>
                <td class="td-1"><xsl:value-of select="/ABC19/S3_5B/PREMISESVISITEDLICENSING"/></td>
                <td class="td-1"><xsl:value-of select="/ABC19/S3_5B/PREMISESVISITEDENFORCEMENT"/></td>
                <td class="td-1"><xsl:value-of select="/ABC19/S3_5B/APPOINTMENTWAITTIMEINDAYS"/></td>
                <td class="td-1-last"><xsl:value-of select="/ABC19/S3_5B/NUMBEROFMAILINSAWAITINGIN"/></td>
            </tr>
        </tbody>
    </table>
	  <!--</div>-->
   </xsl:template>

  <!-- ******************************************************************** -->
  <!--     Template layout first line section 6                            -->
  <!-- ******************************************************************** -->
  <xsl:template name="section-6">
    <xsl:param name="COURTESTYABC211"></xsl:param>
    <table>
      <thead>
        <tr>
          <th class="th-2">District Name</th>
          <th class="th-2">Number</th>
        </tr>
      </thead>
      <tbody>
          <!--loop through records-->
          <xsl:for-each select="$COURTESTYABC211">
            <tr>
                <td class="td-2"><xsl:value-of select='./BASEFILEOFFICENAME'/></td>
                <td class="td-2-last" style='text-align: right; padding-right:1em;'><xsl:value-of select='./COURTESYCOUNT'/></td>
            </tr>
          </xsl:for-each>
        </tbody>
    </table>
  </xsl:template>

  <!-- ******************************************************************** -->
  <!--     Template layout first line section 7                            -->
  <!-- ******************************************************************** -->
  <xsl:template name="section-7">
    <xsl:param name="TAKENABC211"></xsl:param>
    <table>
     <thead>
        <tr>
          <th class="th-2">District Name</th>
          <th class="th-2">Number</th>
        </tr>
      </thead>
        <tbody>
          <!--loop through records-->
          <xsl:for-each select="TAKENABC211">
            <tr>
				<td class="td-2"><xsl:value-of select='./BASEFILEOFFICE'/></td>
				<td class="td-2-last"><xsl:value-of select='./COURTESYCOUNT'/></td>
            </tr>
          </xsl:for-each>
        </tbody>
    </table>
  </xsl:template>      

  <!-- ******************************************************************** -->
  <!--     Template layout first line section 8                             -->
  <!-- ******************************************************************** -->
  <xsl:template name="section-8">
    <xsl:param name="ABC220"></xsl:param>
    <xsl:param name="COUNTABC211"></xsl:param>
    <table>
      <thead>
        <tr>
		  <th class="th-2" style="width: 45%; "><xsl:text disable-output-escaping="yes">&amp;</xsl:text>nbsp;</th>
          <th class="th-2" style="width: 19%; ">Original</th>
          <th class="th-2" style="width: 18%; ">Per to Per</th>
          <th class="th-2" style="width: 16%; ">Total</th>
          <!--<th style="width: 17%; "> </th>
          <th style="width: 15%; "> </th>
		  <th xmlns="http://www.w3.org/1999/xhtml"> </th>-->
        </tr>
      </thead>
        <tbody>
            <tr style="padding:0px; margin:0px;">
				<td class="td-2">a. Pending Beginning</td>
				<td class="td-2-right"><xsl:value-of select='$ABC220/PENDBEGORIGINAL'/></td>
				<td class="td-2-right"><xsl:value-of select='$ABC220/PENDBEGPERTOPER'/></td>
				<td class="td-2-last"><xsl:value-of select='$ABC220/PENDBEGTTL'/></td>
                <!--<td style=''>
                  <xsl:value-of select='$ABC220/PENDINGBEGINNING'/>
                </td>
              <td style="text-align: center;">
                <xsl:value-of select="$COUNTABC211"/>
              </td>-->
            </tr>
            <tr>
                <td class="td-2">b. Received</td>
                <td class="td-2-right"><xsl:value-of select='$ABC220/RECEIVEDORIGINAL'/></td>                 
                <td class="td-2-right"><xsl:value-of select='$ABC220/RECEIVEDPERTOPER'/></td>
				<td class="td-2-last"><xsl:value-of select='$ABC220/RECEIVEDTTL'/></td>
                <!--<td style=''>
                  <xsl:value-of select='$ABC220/RECEIVED'/>
                </td>
              <td style="">
				  <xsl:text disable-output-escaping="yes">&amp;</xsl:text>nbsp;
			  </td>-->
            </tr>
          <tr>
            <td class="td-2">c. Completed</td>
			  <td class="td-2-right"><xsl:value-of select='$ABC220/COMPLETEDORIGINAL'/></td>
			  <td class="td-2-right"><xsl:value-of select='$ABC220/COMPLETEDPERTOPER'/></td>
			  <td class="td-2-last"><xsl:value-of select='$ABC220/COMPLETEDTTL'/></td>
            <!--<td style=''>
              <xsl:value-of select='$ABC220/COMPLETED'/>
            </td>
            <td style="">
				<xsl:text disable-output-escaping="yes">&amp;</xsl:text>nbsp;
			</td>-->
          </tr>
            <tr>
                <td class="td-2">d. Approved</td>
                <td class="td-2-right"><xsl:value-of select='$ABC220/APPROVEDORIGINAL'/></td>
                <td class="td-2-right"><xsl:value-of select='$ABC220/APPROVEDPERTOPER'/></td>
				<td class="td-2-last"><xsl:value-of select='$ABC220/APPROVEDTTL'/></td>
                <!--<td style='background-color: #d0d0d0;'>
					<xsl:text disable-output-escaping="yes">&amp;</xsl:text>nbsp;
				</td>
              <td style="">
				  <xsl:text disable-output-escaping="yes">&amp;</xsl:text>nbsp;
			  </td>-->
            </tr>
            <tr>
                <td class="td-2">e. Denied</td>
                <td class="td-2-right"><xsl:value-of select='$ABC220/DENIEDORIGINAL'/></td>
                <td class="td-2-right"><xsl:value-of select='$ABC220/DENIEDPERTOPER'/></td>
				<td class="td-2-last"><xsl:value-of select='$ABC220/DENIEDTTL'/></td>
               <!--<td style='background-color: #d0d0d0;'>
				   <xsl:text disable-output-escaping="yes">&amp;</xsl:text>nbsp;
			   </td>
              <td style="">
				  <xsl:text disable-output-escaping="yes">&amp;</xsl:text>nbsp;
			  </td>-->
            </tr>
            <tr>
                <td class="td-2">f. Withdrawn</td>
                <td class="td-2-right"><xsl:value-of select='$ABC220/WITHDRAWNORIGINAL'/></td>
                <td class="td-2-right"><xsl:value-of select='$ABC220/WITHDRAWNPERTOPER'/></td>
				<td class="td-2-last"><xsl:value-of select='$ABC220/WITHDRAWNTTL'/></td>
                <!--<td style='background-color: #d0d0d0;'>
					<xsl:text disable-output-escaping="yes">&amp;</xsl:text>nbsp;
				</td>
              <td style="">
				  <xsl:text disable-output-escaping="yes">&amp;</xsl:text>nbsp;
			  </td>-->
            </tr>
            <tr>
                <td class="td-2">g. Voided</td>
                <td class="td-2-right"><xsl:value-of select='$ABC220/VOIDEDORIGINAL'/></td>
                <td class="td-2-right"><xsl:value-of select='$ABC220/VOIDEDPERTOPER'/></td>
				<td class="td-2-last"><xsl:value-of select='$ABC220/VOIDEDTTL'/></td>
                <!--<td style='background-color: #d0d0d0;'>
					<xsl:text disable-output-escaping="yes">&amp;</xsl:text>nbsp;
				</td>
              <td style="">
				  <xsl:text disable-output-escaping="yes">&amp;</xsl:text>nbsp;
			  </td>-->
            </tr>
            <tr>
                <td class="td-2">h. Pending Ending</td>
                <td class="td-2-right"><xsl:value-of select='$ABC220/PENDENDORIGINAL'/></td>
                <td class="td-2-right"><xsl:value-of select='$ABC220/PENDENDPERTOPER'/></td>
				<td class="td-2-last"><xsl:value-of select='$ABC220/PENDENDTTL'/></td>
                <!--<td>
                  <xsl:value-of select='$ABC220/ABC61TTL'/>
                </td>
              <td style=''>
				  <xsl:text disable-output-escaping="yes">&amp;</xsl:text>nbsp;
			  </td>-->
            </tr>
            
        </tbody>
    </table>
  </xsl:template>

	<!-- ******************************************************************** -->
	<!--     Template layout first line section 9                             -->
	<!-- ******************************************************************** -->
	<xsl:template name="section-9">
		<xsl:param name="ABC220"></xsl:param>
		<xsl:param name="COUNTABC211"></xsl:param>
		<table>
			<thead>
				<tr>
					<th class="th-2">
						<xsl:text disable-output-escaping="yes">&amp;</xsl:text>nbsp;<br/>
						<xsl:text disable-output-escaping="yes">&amp;</xsl:text>nbsp;
					</th>

				</tr>
			</thead>
			<tbody>
				<tr>
					<td class="td-2-last">
                  <xsl:value-of select='$ABC220/PENDINGBEGINNING'/>
                </td>
				</tr>
				<tr>
					<td  class="td-2-last">
                  <xsl:value-of select='$ABC220/RECEIVED'/>
                </td>
				</tr>
				<tr>
					<td class="td-2-last">
              <xsl:value-of select='$ABC220/COMPLETED'/>
            </td>
 				</tr>
				<tr>
					<td class="td-2-last" style='background-color: #d0d0d0;'>
					<xsl:text disable-output-escaping="yes">&amp;</xsl:text>nbsp;
				</td>
				</tr>
				<tr>
					<td class="td-2-last" style='background-color: #d0d0d0;'>
				   <xsl:text disable-output-escaping="yes">&amp;</xsl:text>nbsp;
			   </td>
 				</tr>
				<tr>
					<td class="td-2-last" style='background-color: #d0d0d0;'>
					<xsl:text disable-output-escaping="yes">&amp;</xsl:text>nbsp;
				</td>
				</tr>
				<tr>
					<td class="td-2-last" style='background-color: #d0d0d0;'>
					<xsl:text disable-output-escaping="yes">&amp;</xsl:text>nbsp;
				</td>
				</tr>
				<tr>
					<td class="td-2-last">
                  <xsl:value-of select='$ABC220/ABC61TTL'/>
                </td>
				</tr>

			</tbody>
		</table>
	</xsl:template>

	<!-- ******************************************************************** -->
	<!--     Template layout first line section 10                            -->
	<!-- ******************************************************************** -->
	<xsl:template name="section-10">
		<xsl:param name="ABC220"></xsl:param>
		<xsl:param name="COUNTABC211"></xsl:param>
		<table>
			<thead>
				<tr>
					<th><xsl:text disable-output-escaping="yes">&amp;</xsl:text>nbsp;</th>
				</tr>
			</thead>
			<tbody>
				<tr>
					<td style="text-align: center;">
						<xsl:value-of select="$COUNTABC211"/>
					</td>
				</tr>
			</tbody>
		</table>
	</xsl:template>



	<!-- ******************************************************************** -->
  <!--     Template layout first line section 12                            -->
  <!-- ******************************************************************** -->
  <xsl:template name="section-12">
    <xsl:param name="ABC61"></xsl:param>
    <table>
      <thead>
        <tr>
          <th class="th-2" style=""></th>
          <th class="th-2" style="width: 17%;">COMPLAINT INVEST-IGATIONS</th>
          <th class="th-2" style="width: 17%;">ADMINI-STRATIVE</th>
          <th class="th-2" style="width: 17%;">REPORT ASSIGNED FOR INVEST.</th>
          <th class="th-2" style="width: 15%;">TRACE</th>
        </tr>
      </thead>
        <tbody>
            <tr style="padding:0px; margin:0px;">
                <td class="td-2">a. Pending Beginning</td>
                <td class="td-2-right"><xsl:value-of select='$ABC61/PENDBEGCOMPLAINT'/></td>
                <td class="td-2-right"><xsl:value-of select='$ABC61/PENDBEGADMINISTRATION'/></td>
                <td class="td-2-right"><xsl:value-of select='$ABC61/PENDBEGPOLICEREPORT'/></td>
                <td class="td-2-last"><xsl:value-of select='$ABC61/PENDBEGTRACE'/></td>
            </tr>
            <tr>
                <td class="td-2">b. Received</td>
                <td class="td-2-right"><xsl:value-of select='$ABC61/RECEIVEDCOMPLAINT'/></td>
                <td class="td-2-right"><xsl:value-of select='$ABC61/RECEIVEDADMINISTRATION'/></td>
                <td class="td-2-right"><xsl:value-of select='$ABC61/RECEIVEDPOLICEREPORT'/></td>
                <td class="td-2-last"><xsl:value-of select='$ABC61/RECEIVEDTRACE'/></td>
            </tr>
            <tr>
                <td class="td-2">c. Completed</td>
                <td class="td-2-right"><xsl:value-of select='$ABC61/COMPLETEDCOMPLAINT'/></td>
                <td class="td-2-right"><xsl:value-of select='$ABC61/COMPLETEDADMINISTRATION'/></td>
                <td class="td-2-right"><xsl:value-of select='$ABC61/COMPLETEDPOLICEREPORT'/></td>
                <td class="td-2-last"><xsl:value-of select='$ABC61/COMPLETEDTRACE'/></td>
            </tr>
            <tr>
                <td class="td-2">d. Pending Ending</td>
                <td class="td-2-right"><xsl:value-of select='$ABC61/PENDENDCOMPLAINT'/></td>
                <td class="td-2-right"><xsl:value-of select='$ABC61/PENDENDADMINISTRATION'/></td>
                <td class="td-2-right"><xsl:value-of select='$ABC61/PENDENDPOLICEREPORT'/></td>
                <td class="td-2-last"><xsl:value-of select='$ABC61/PENDENDTRACE'/></td>
           </tr>
        </tbody>
    </table>
  </xsl:template>      

  
  <!-- ******************************************************************** -->
  <!--     Template layout first line section 13                        -->
  <!-- ******************************************************************** -->
  <xsl:template name="section-13">
    <xsl:param name="ABC61"></xsl:param>
    <table>
      <thead>
        <tr>
          <th class="th-2" style=""></th>
          <th class="th-2" style="width: 20%;">ABC</th>
          <th class="th-2" style="width: 17%;">JOINT</th>
        </tr>
      </thead>
        <tbody>
            <tr style="padding:0px; margin:0px;">
				<td class="td-2">a. MINORS</td>
				<td class="td-2-right"><xsl:value-of select='$ABC61/MINORABC'/></td>
				<td class="td-2-last"><xsl:value-of select='$ABC61/MINORJOINT'/></td>
            </tr>
            <tr>
                <td class="td-2">b. OTHER</td>
                <td class="td-2-right"><xsl:value-of select='$ABC61/OTHERABC'/></td>
				<td class="td-2-last"><xsl:value-of select='$ABC61/OTHERJOINT'/></td>
            </tr>
            <tr>
				<td class="td-2">c. TOTAL</td>
                <td class="td-2-right"><xsl:value-of select='$ABC61/TOTALABC'/></td>
				<td class="td-2-last"><xsl:value-of select='$ABC61/TOTALJOINT'/></td>
            </tr>
        </tbody>
    </table>
  </xsl:template>      
  
  
  <!-- ******************************************************************** -->
  <!--     Template layout first line section 14 & 15                       -->
  <!-- ******************************************************************** -->
  <xsl:template name="section-14-15">
    <table class="" style="height: 100%;">
      <tbody style="height: 100%;">
        <tr>
          <td class="font-small" style="font-weight: bold; padding-left:1em; text-indent:-0.7em; ">
              14. TOTAL POLICE REPORTS RECEIVED
              </td>
          </tr>
        <tr>
        <td style="height: 30px; text-align: center; vertical-align:middle;">
          <xsl:value-of select="/ABC19/S3_5B/POLICEREPORTSRECEIVED"/>
       </td>
        </tr>
          
        <tr>
          <td class="font-small" style="font-weight: bold; border-top:1px solid black; padding-left:1em; text-indent:-0.7em; ">
              15A. WARNING LETTERS SENT
          </td>
        </tr>
        <tr>
          <td style="height: 30px; text-align: center; vertical-align:middle;">
            <xsl:value-of select="/ABC19/S3_5B/WARNINGLETTERSSENT"/>
          </td>
        </tr>

        <tr>
          <td class="font-small" style="font-weight: bold; border-top:1px solid black; padding-left:1em; text-indent:-0.7em; ">
            15B. NOTICE OF VIOLATIONS ISSUED
          </td>
        </tr>
        <tr>
          <td style="height: 30px; text-align: center; vertical-align:middle;">
            <xsl:value-of select="/ABC19/S3_5B/NOTICEOFVIOLATIONS "/>
          </td>
        </tr>
      </tbody>
    </table>
  </xsl:template>      
  
  
  <!-- ******************************************************************** -->
  <!--     Template layout first line section 16                        -->
  <!-- ******************************************************************** -->
  <xsl:template name="section-16">
    <table>
      <thead>
        <tr>
          <th class="th-2" style="width: 18%;">OPERATION DATE</th>
          <th class="th-2">AGENCY NAME OR DISTRICT OFFICE</th>
          <th class="th-2" style="width: 15%;">NUMBER OF PREMISES CONTACTED</th>
          <th class="th-2" style="width: 15%;">NUMBER OF VIOLATION</th>
        </tr>
      </thead>
      <tbody>
        <!--loop through records-->
        <xsl:for-each select="/ABC19/MDP_ONSALE">
          <tr>
            <td class="td-2-right">
              <xsl:value-of select='OPERATIONDATE'/>
            </td>
            <td class="td-2">
              <xsl:value-of select='AGENCYDISTRICTOFFICEEVENTNAME'/>
            </td>
            <td class="td-2-right">
              <xsl:value-of select='NUMBEROFPREMISESCONTACTED'/>
            </td>
            <td class="td-2-last">
              <xsl:value-of select='NUMBEROFVIOLATIONS'/>
            </td>
          </tr>
        </xsl:for-each>
      </tbody>
    </table>
  </xsl:template>      
  
  
  <!-- ******************************************************************** -->
  <!--     Template layout first line section 17                        -->
  <!-- ******************************************************************** -->
  <xsl:template name="section-17">
    <table>
      <thead>
        <tr>
          <th class="th-2" style="width: 18%;">OPERATION DATE</th>
          <th class="th-2">AGENCY NAME OR DISTRICT OFFICE</th>
          <th class="th-2" style="width: 15%;">NUMBER OF PREMISES CONTACTED</th>
          <th class="th-2" style="width: 15%;">NUMBER OF VIOLATION</th>
        </tr>
      </thead>
      <tbody>
        <!--loop through records-->
        <xsl:for-each select="/ABC19/MDP_OFFSALE">
          <tr>
            <td class="td-2-right">
              <xsl:value-of select='OPERATIONDATE'/>
            </td>
            <td class="td-2">
              <xsl:value-of select='AGENCYDISTRICTOFFICEEVENTNAME'/>
            </td>
            <td class="td-2-right">
              <xsl:value-of select='NUMBEROFPREMISESCONTACTED'/>
            </td>
            <td class="td-2-last">
              <xsl:value-of select='NUMBEROFVIOLATIONS'/>
            </td>
          </tr>
        </xsl:for-each>
      </tbody>
    </table>
  </xsl:template>      
          

  <!-- ******************************************************************** -->
  <!--     Template layout first line section 18                        -->
  <!-- ******************************************************************** -->
  <xsl:template name="section-18">
    <table>
      <thead>
        <tr>
          <th class="th-2" style="width: 18%;">OPERATION DATE</th>
          <th class="th-2">AGENCY NAME OR DISTRICT OFFICE</th>
          <th class="th-2" style="width: 15%;">NUMBER OF PERSONS CONTACTED</th>
          <th class="th-2" style="width: 15%;">NUMBER OF ARRESTS</th>
        </tr>
      </thead>
      <tbody>
        <!--loop through records-->
        <xsl:for-each select="/ABC19/STP">
          <tr>
            <td class="td-2-right">
              <xsl:value-of select='OPERATIONDATE'/>
            </td>
            <td class="td-2">
              <xsl:value-of select='AGENCYDISTRICTOFFICEEVENTNAME'/>
            </td>
            <td class="td-2-right">
              <xsl:value-of select='NUMBEROFPERSONSCONTACTED'/>
            </td>
            <td class="td-2-last">
              <xsl:value-of select='NUMBEROFVIOLATIONS'/>
            </td>
          </tr>
        </xsl:for-each>
      </tbody>
    </table>
  </xsl:template>      
  
  
  <!-- ******************************************************************** -->
  <!--     Template layout first line section 19                        -->
  <!-- ******************************************************************** -->
  <xsl:template name="section-19">
    <table>
      <thead>
        <tr>
          <th class="th-2" style="width: 18%;">DATE</th>
          <th class="th-2">AGENCY NAME, DISTRICT OFFICE OR EVENT NAME</th>
          <th class="th-2" style="width: 15%;">TOTAL STAFF HOURS</th>
          <th class="th-2" style="width: 15%;">NUMBER OF ARRESTS</th>
        </tr>
      </thead>
      <tbody>
        <!--loop through records-->
        <xsl:for-each select="/ABC19/TF_SE_IM">
          <tr>
            <td class="td-2-right">
              <xsl:value-of select='OPERATIONDATE'/>
            </td>
            <td class="td-2">
              <xsl:value-of select='AGENCYDISTRICTOFFICEEVENTNAME'/>
            </td>
            <td class="td-2-right">
              <xsl:value-of select='TOTALSTAFFHOURS'/>
            </td>
            <td class="td-2-last">
              <xsl:value-of select='NUMBEROFARRESTS'/>
            </td>
          </tr>
        </xsl:for-each>
      </tbody>
    </table>
  </xsl:template>      
          
</xsl:stylesheet>
