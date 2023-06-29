<?xml version="1.0" encoding="utf-8"?>
<!--
*******************************************************************************	
	File:		WorkloadSummary.xslt
	Author:		Timothy J. Lord

	Description:	Layout form for Workload Summary Report.

    $Rev: 430 $  
    $Date: 2020-04-28 07:26:12 -0700 (Tue, 28 Apr 2020) $
    Last Changed By:  $Author: TLord $

*****************************************************************************

*****************************************************************************
-->
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:msxsl="urn:schemas-microsoft-com:xslt" exclude-result-prefixes="msxsl"
>
  <xsl:output method="html" indent="yes" encoding="us-ascii"/>
  <xsl:key name="groups" match="SECTION_3/OFFICE" use="@DIVISION"/>
  <xsl:key name="applicationpart2" match="SECTION_4/OFFICE/DIVISION" use="."/>
  <xsl:key name="assignments" match="SECTION_5/OFFICE/DIVISION" use="."/>
  <xsl:key name="arrests" match="SECTION_6/OFFICE/DIVISION" use="."/>
  <xsl:key name="accusations" match="SECTION_7/OFFICE/DIVISION" use="."/>
  <xsl:key name="misc" match="SECTION_9/OFFICE/DIVISION" use="."/>

  <xsl:template match="WORKLOAD">
    <xsl:text disable-output-escaping="yes">&lt;!DOCTYPE html&gt;</xsl:text>
    <html  xmlns="http://www.w3.org/1999/xhtml" lang="en">
      <head>
        <meta http-equiv="Content-Type" content="text/html; charset=utf-8"/>
        <style type="text/css">
          body			      { font-size: 8.0pt; width: 10in; margin: auto; }

          @media screen
          {
          body			    { background-color: #E0E0E0; }
          .padding      { padding-bottom:  5em; }
          }

          @mdeia print
          {
          body			     { color: #FF0000; }
          }

          th              { border: 1px solid #b0b0b0; text-align: center; }
          td              { border: 1px solid #b0b0b0; padding-right: 5px; padding-left: 5px; }
          h1, h2          { font-size: 1.3em; }
          h1, h2          { text-align: center; padding: 0px; margin:0px; }
          h3              { text-align: center; }

          .th-none        { background-color: #FFFFFF; }
          .td-none        { color: inherit; }

          #section-3,
          #section-5,
          #section-7,
          #section-9              { width: 9in; margin-left: .5in; }

          #section-1,
          #section-2,
          #section-4,
          #section-6              { margin-left: .5in; }

          #section-1 th,
          #section-3 th,
          #section-4 th,
          #section-5 th,
          #section-6 th,
          #section-7 th,
          #section-9 th           { font-size: 0.75em; }

          #section-1 th           { border: none; border-bottom: 1px solid #a0a0a0;}
          #section-1 td           { text-align: right; vertical-align: bottom; border: none; border-bottom: 1px solid #e0e0e0; padding:2px 5px }
          #section-1 .td-lic      { text-align: left; background-color: #fcd5b4; }
          #section-1 .td-enf      { text-align: left; background-color: #c5d9f1; }

          #section-2              { width: 4.5in; }
          #section-2 th           { border: none; border-bottom: 1px solid #a0a0a0;}
          #section-2 td           { text-align: right; vertical-align: bottom; border: none; border-bottom: 1px solid #e0e0e0; padding:2px 5px }
          #section-2 .td-rev      { text-align: left; background-color: #ffff00; }
          #section-2 .td-dec      { text-align: left; background-color: #ccc0da; }

          #section-3 th         { background-color: #fcd5b4; }
          #section-3 td         { text-align: right; width:  .45in; }

          #section-4 th         { background-color: #fcd5b4; }
          #section-4 td         { text-align: right; width:  1.0in; }

          #section-5 td         { text-align: right; }
          #section-5 .th-1      { background-color: #fcd5b4; }
          #section-5 .th-2      { background-color: #c5d9f1; }

          #section-6 th         { background-color: #c5d9f1; }
          #section-6 td         { text-align: right; width:  .6in; }

          #section-7 th         { background-color: #c5d9f1; }
          #section-7 td         { text-align: right; width:  .6in; }

          #section-9 th         { background-color: #fcd5b4; }
          #section-9 td         { text-align: right; width: 1.3in; }

          #section-3 .th-none,
          #section-4 .th-none,
          #section-5 .th-none,
          #section-6 .th-none,
          #section-7 .th-none,
          #section-9 .th-none        { background-color: inherit; }

          #section-3 .th-nd,
          #section-4 .th-nd,
          #section-5 .th-nd,
          #section-6 .th-nd,
          #section-7 .th-nd,
          #section-9 .th-nd          { background-color: #92d050; }

          #section-3 .th-sd,
          #section-4 .th-sd,
          #section-5 .th-sd,
          #section-6 .th-sd,
          #section-7 .th-sd,
          #section-9 .th-sd          { background-color: #fa5e34; }


          .td-nd          { color: #925050; }
          .td-sd          { color: #fa5e34; }

          @media screen
          {
          #section-1 th,
          #section-2 th         { border-bottom: 1px solid #b0b0b0; }
          #section-1 td,
          #section-2 td         { border-bottom: 1px solid #b0b0b0; }
          }

        </style>
        <title>
          <xsl:value-of select='/ROOT/@REPORT_NAME' />
        </title>
      </head>
      <body>
        <p style='margin-bottom: 1em;'>
          <h1>DEPARTMENTAL WORKLOAD SUMMARY</h1>
          <h2>
            <xsl:value-of select='REPORTDATES'/>
          </h2>
        </p>

        <xsl:apply-templates select="SECTION_1"/>

        <div class='padding' style="page-break-before: always" >
          <xsl:apply-templates select="SECTION_2"/>
        </div>

        <div class='padding' style="page-break-before: always" >
          <xsl:apply-templates select="SECTION_3"/>
        </div>

        <div class='padding' style="page-break-before: always" >
          <xsl:apply-templates select="SECTION_4"/>
        </div>

        <div class='padding' style="page-break-before: always" >
          <xsl:apply-templates select="SECTION_5"/>
        </div>

        <div class='padding' style="page-break-before: always" >
          <xsl:apply-templates select="SECTION_6"/>
        </div>

        <div class='padding' style="page-break-before: always" >
          <xsl:apply-templates select="SECTION_7">
            <xsl:with-param name="PART" select="'1'" />
            <xsl:with-param name="ID" select="'PART 1'"/>
          </xsl:apply-templates>
        </div>

        <div class='padding' style="page-break-before: always" >
          <xsl:apply-templates select="SECTION_7">
            <xsl:with-param name="PART" select="'2'" />
            <xsl:with-param name="ID" select="'PART 2'"/>
          </xsl:apply-templates>
        </div>

        <div class='padding' style="page-break-before: always" >
          <xsl:apply-templates select="SECTION_9"/>
        </div>

      </body>
    </html>
  </xsl:template>


  <!-- ********************************************************************************** -->
  <!--   MULTI-PERIOD STATS COMPARISON                                                    -->
  <!-- ********************************************************************************** -->
  <xsl:template match="SECTION_1">
    <p>
      <h3>
        <xsl:value-of select="@HEADING"/>
      </h3>
    </p>
    <table id="section-1" style="border-collapse: collapse;">
      <!--   Headings for section report   -->
      <thead>
        <tr>
          <th>
            <xsl:text disable-output-escaping="yes">&amp;</xsl:text>nbsp;
          </th>
          <th>
            <xsl:text disable-output-escaping="yes">&amp;</xsl:text>nbsp;
          </th>
          <th>
            Actual Figures<br/><xsl:value-of select="SECTION_1_1/@DATES"/><br/><xsl:value-of select="SECTION_1_1/@MONTHS"/> MONTH
          </th>
          <th>
            Actual Figures<br/><xsl:value-of select="SECTION_1_2/@DATES"/><br/><xsl:value-of select="SECTION_1_2/@MONTHS"/> MONTH
          </th>
          <th>
            Actual Figures<br/><xsl:value-of select="SECTION_1_3/@DATES"/><br/><xsl:value-of select="SECTION_1_3/@MONTHS"/> MONTH
          </th>
        </tr>
      </thead>

      <tbody>
        <tr style="font-weight: bold;">
          <td class="td-lic">I.</td>
          <td colspan="4" class="td-lic">LICENSING</td>
        </tr>
        <tr>
          <td style="width:  .2in">
            <xsl:text disable-output-escaping="yes">&amp;</xsl:text>nbsp;
          </td>
          <td style="width: 3.3in; text-align:left;">Permanent License Applications Received</td>
          <td style="width: 1.4in">
            <xsl:value-of select="SECTION_1_1/APPLICATIONSRECEIVED"/>
          </td>
          <td style="width: 1.4in">
            <xsl:value-of select="SECTION_1_2/APPLICATIONSRECEIVED"/>
          </td>
          <td style="width: 1.4in">
            <xsl:value-of select="SECTION_1_3/APPLICATIONSRECEIVED"/>
          </td>
        </tr>
        <tr>
          <td>
            <xsl:text disable-output-escaping="yes">&amp;</xsl:text>nbsp;
          </td>
          <td style="text-align:left">Priority License Applications Received</td>
          <td>
            <xsl:value-of select="SECTION_1_1/PDAPPLICATIONSRECEIVED"/>
          </td>
          <td>
            <xsl:value-of select="SECTION_1_2/PDAPPLICATIONSRECEIVED"/>
          </td>
          <td>
            <xsl:value-of select="SECTION_1_3/PDAPPLICATIONSRECEIVED"/>
          </td>
        </tr>
        <tr>
          <td>
            <xsl:text disable-output-escaping="yes">&amp;</xsl:text>nbsp;
          </td>
          <td style="text-align:left">Applications Protested</td>
          <td>
            <xsl:value-of select="SECTION_1_1/APPLICATIONSPROTESTED"/>
          </td>
          <td>
            <xsl:value-of select="SECTION_1_2/APPLICATIONSPROTESTED"/>
          </td>
          <td>
            <xsl:value-of select="SECTION_1_3/APPLICATIONSPROTESTED"/>
          </td>
        </tr>
        <tr>
          <td>
            <xsl:text disable-output-escaping="yes">&amp;</xsl:text>nbsp;
          </td>
          <td style="text-align:left">Number of Protests Letters Received</td>
          <td>
            <xsl:value-of select="SECTION_1_1/PROTESTSREC"/>
          </td>
          <td>
            <xsl:value-of select="SECTION_1_2/PROTESTSREC"/>
          </td>
          <td>
            <xsl:value-of select="SECTION_1_3/PROTESTSREC"/>
          </td>
        </tr>
        <tr>
          <td style="text-align: right; padding-right:.0em;">*</td>
          <td style="text-align:left">Applications Registered (Protest/Petition)</td>
          <td>
            <xsl:value-of select="SECTION_1_1/PROPETTOTAL"/>
          </td>
          <td>
            <xsl:value-of select="SECTION_1_2/PROPETTOTAL"/>
          </td>
          <td>
            <xsl:value-of select="SECTION_1_3/PROPETTOTAL"/>
          </td>
        </tr>
        <tr>
          <td style="text-align: right; padding-right:.0em;">*</td>
          <td style="text-align:left;">Number of Enforcement Hearings Held</td>
          <td>
            <xsl:value-of select="SECTION_1_1/PROCESSHEARING"/>
          </td>
          <td>
            <xsl:value-of select="SECTION_1_2/PROCESSHEARING"/>
          </td>
          <td>
            <xsl:value-of select="SECTION_1_3/PROCESSHEARING"/>
          </td>
        </tr>
        <tr>
          <td>
            <xsl:text disable-output-escaping="yes">&amp;</xsl:text>nbsp;
          </td>
          <td style="text-align:left">Applications Withdrawn</td>
          <td>
            <xsl:value-of select="SECTION_1_1/WITHDRAWN"/>
          </td>
          <td>
            <xsl:value-of select="SECTION_1_2/WITHDRAWN"/>
          </td>
          <td>
            <xsl:value-of select="SECTION_1_3/WITHDRAWN"/>
          </td>
        </tr>
        <tr>
          <td>
            <xsl:text disable-output-escaping="yes">&amp;</xsl:text>nbsp;
          </td>
          <td style="text-align:left">Applications Recommended for Denial</td>
          <td>
            <xsl:value-of select="SECTION_1_1/APPRECOMMENDDENIAL"/>
          </td>
          <td>
            <xsl:value-of select="SECTION_1_2/APPRECOMMENDDENIAL"/>
          </td>
          <td>
            <xsl:value-of select="SECTION_1_3/APPRECOMMENDDENIAL"/>
          </td>
        </tr>
        <tr>
          <td>
            <xsl:text disable-output-escaping="yes">&amp;</xsl:text>nbsp;
          </td>
          <td style="text-align:left">Applications Recommended for Approval</td>
          <td>
            <xsl:value-of select="SECTION_1_1/APPRECOMMENDAPPROVAL"/>
          </td>
          <td>
            <xsl:value-of select="SECTION_1_2/APPRECOMMENDAPPROVAL"/>
          </td>
          <td>
            <xsl:value-of select="SECTION_1_3/APPRECOMMENDAPPROVAL"/>
          </td>
        </tr>
        <tr>
          <td>
            <xsl:text disable-output-escaping="yes">&amp;</xsl:text>nbsp;
          </td>
          <td style="text-align:left">Permanent Licenses Issued</td>
          <td>
            <xsl:value-of select="SECTION_1_1/PERMANENTLICISSUED"/>
          </td>
          <td>
            <xsl:value-of select="SECTION_1_2/PERMANENTLICISSUED"/>
          </td>
          <td>
            <xsl:value-of select="SECTION_1_3/PERMANENTLICISSUED"/>
          </td>
        </tr>
        <tr>
          <td>
            <xsl:text disable-output-escaping="yes">&amp;</xsl:text>nbsp;
          </td>
          <td style="text-align:left">Special Daily and Catering Authorizations</td>
          <td>
            <xsl:value-of select="SECTION_1_1/DAILYLICENSES"/>
          </td>
          <td>
            <xsl:value-of select="SECTION_1_2/DAILYLICENSES"/>
          </td>
          <td>
            <xsl:value-of select="SECTION_1_3/DAILYLICENSES"/>
          </td>
        </tr>
        <tr>
          <td>
            <xsl:text disable-output-escaping="yes">&amp;</xsl:text>nbsp;
          </td>
          <td style="text-align:left">Active Permanent Licenses as of Report End Date</td>
          <td>
            <xsl:value-of select="SECTION_1_1/ACTIVELICENSES"/>
          </td>
          <td>
            <xsl:value-of select="SECTION_1_2/ACTIVELICENSES"/>
          </td>
          <td>
            <xsl:value-of select="SECTION_1_3/ACTIVELICENSES"/>
          </td>
        </tr>
        <tr>
          <td colspan="5" style="height:1em; border: none;">
            <xsl:text disable-output-escaping="yes">&amp;</xsl:text>nbsp;
          </td>
        </tr>
        <tr style="font-weight: bold;">
          <td class="td-enf" style="">II.</td>
          <td colspan="4" class="td-enf">ENFORCEMENT</td>
        </tr>
        <tr>
          <td>
            <xsl:text disable-output-escaping="yes">&amp;</xsl:text>nbsp;
          </td>
          <td style="text-align:left">Total Number of Investigations (ABC-61) Completed</td>
          <td>
            <xsl:value-of select="SECTION_1_1/COMPLAINTINVESTIGATIONS + SECTION_1_1/ADMININVESTIGATIONS + SECTION_1_1/TRACEINVESTIGATIONS + SECTION_1_1/POLICEREPORTINV"/>
          </td>
          <td>
            <xsl:value-of select="SECTION_1_2/COMPLAINTINVESTIGATIONS + SECTION_1_2/ADMININVESTIGATIONS + SECTION_1_2/TRACEINVESTIGATIONS + SECTION_1_2/POLICEREPORTINV"/>
          </td>
          <td>
            <xsl:value-of select="SECTION_1_3/COMPLAINTINVESTIGATIONS + SECTION_1_3/ADMININVESTIGATIONS + SECTION_1_3/TRACEINVESTIGATIONS + SECTION_1_3/POLICEREPORTINV"/>
          </td>
        </tr>
        <tr>
          <td>
            <xsl:text disable-output-escaping="yes">&amp;</xsl:text>nbsp;
          </td>
          <td style="text-align:left; text-indent: 3em;">Complaint Investigation Assignments Completed</td>
          <td>
            <xsl:value-of select="SECTION_1_1/COMPLAINTINVESTIGATIONS"/>
          </td>
          <td>
            <xsl:value-of select="SECTION_1_2/COMPLAINTINVESTIGATIONS"/>
          </td>
          <td>
            <xsl:value-of select="SECTION_1_3/COMPLAINTINVESTIGATIONS"/>
          </td>
        </tr>
        <tr>
          <td>
            <xsl:text disable-output-escaping="yes">&amp;</xsl:text>nbsp;
          </td>
          <td style="text-align:left; text-indent: 3em;">Administrative Assignments Completed</td>
          <td>
            <xsl:value-of select="SECTION_1_1/ADMININVESTIGATIONS"/>
          </td>
          <td>
            <xsl:value-of select="SECTION_1_2/ADMININVESTIGATIONS"/>
          </td>
          <td>
            <xsl:value-of select="SECTION_1_3/ADMININVESTIGATIONS"/>
          </td>
        </tr>
        <tr>
          <td>
            <xsl:text disable-output-escaping="yes">&amp;</xsl:text>nbsp;
          </td>
          <td style="text-align:left; text-indent: 3em;">TRACE Assignments Completed</td>
          <td>
            <xsl:value-of select="SECTION_1_1/TRACEINVESTIGATIONS"/>
          </td>
          <td>
            <xsl:value-of select="SECTION_1_2/TRACEINVESTIGATIONS"/>
          </td>
          <td>
            <xsl:value-of select="SECTION_1_3/TRACEINVESTIGATIONS"/>
          </td>
        </tr>
        <tr>
          <td>
            <xsl:text disable-output-escaping="yes">&amp;</xsl:text>nbsp;
          </td>
          <td style="text-align:left; text-indent: 3em;">Police Reports Assigned for Investigation (ABC-61)</td>
          <td>
            <xsl:value-of select="SECTION_1_1/POLICEREPORTINV"/>
          </td>
          <td>
            <xsl:value-of select="SECTION_1_2/POLICEREPORTINV"/>
          </td>
          <td>
            <xsl:value-of select="SECTION_1_3/POLICEREPORTINV"/>
          </td>
        </tr>
        <tr>
          <td>
            <xsl:text disable-output-escaping="yes">&amp;</xsl:text>nbsp;
          </td>
          <td style="text-align:left;">Accusations Registered </td>
          <td>
            <xsl:value-of select="SECTION_1_1/ACCUSATIONSREG"/>
          </td>
          <td>
            <xsl:value-of select="SECTION_1_2/ACCUSATIONSREG"/>
          </td>
          <td>
            <xsl:value-of select="SECTION_1_3/ACCUSATIONSREG"/>
          </td>
        </tr>
        <tr>
          <td>
            <xsl:text disable-output-escaping="yes">&amp;</xsl:text>nbsp;
          </td>
          <td colspan="4" style="text-align: left">Violation Counts Filed by Source </td>
        </tr>
        <tr>
          <td>
            <xsl:text disable-output-escaping="yes">&amp;</xsl:text>nbsp;
          </td>
          <td style="text-align:left; text-indent: 3em;">Total Violation Counts Filed</td>
          <td>
            <xsl:value-of select="SECTION_1_1/ABCVIOLATIONS + SECTION_1_1/BACKTRACKVIOLATIONS"/>
          </td>
          <td>
            <xsl:value-of select="SECTION_1_2/ABCVIOLATIONS + SECTION_1_2/BACKTRACKVIOLATIONS"/>
          </td>
          <td>
            <xsl:value-of select="SECTION_1_3/ABCVIOLATIONS + SECTION_1_3/BACKTRACKVIOLATIONS"/>
          </td>
        </tr>
        <tr>
          <td>
            <xsl:text disable-output-escaping="yes">&amp;</xsl:text>nbsp;
          </td>
          <td style="text-align:left; text-indent: 3em;">Violation Counts from ABC Investigations</td>
          <td>
            <xsl:value-of select="SECTION_1_1/ABCVIOLATIONS"/>
          </td>
          <td>
            <xsl:value-of select="SECTION_1_2/ABCVIOLATIONS"/>
          </td>
          <td>
            <xsl:value-of select="SECTION_1_3/ABCVIOLATIONS"/>
          </td>
        </tr>
        <tr>
          <td>
            <xsl:text disable-output-escaping="yes">&amp;</xsl:text>nbsp;
          </td>
          <td style="text-align:left; text-indent: 3em;">Violation Counts from Backtrack Investigations</td>
          <td>
            <xsl:value-of select="SECTION_1_1/BACKTRACKVIOLATIONS"/>
          </td>
          <td>
            <xsl:value-of select="SECTION_1_2/BACKTRACKVIOLATIONS"/>
          </td>
          <td>
            <xsl:value-of select="SECTION_1_3/BACKTRACKVIOLATIONS"/>
          </td>
        </tr>
        <tr>
          <td>
            <xsl:text disable-output-escaping="yes">&amp;</xsl:text>nbsp;
          </td>
          <td colspan="4" style="text-align: left">Disposition of Accusations </td>
        </tr>
        <tr>
          <td>
            <xsl:text disable-output-escaping="yes">&amp;</xsl:text>nbsp;
          </td>
          <td style="text-align:left; text-indent: 3em;">Stipulation and Waiver</td>
          <td>
            <xsl:value-of select="SECTION_1_1/SWRECEIVED"/>
          </td>
          <td>
            <xsl:value-of select="SECTION_1_2/SWRECEIVED"/>
          </td>
          <td>
            <xsl:value-of select="SECTION_1_3/SWRECEIVED"/>
          </td>
        </tr>
        <tr>
          <td>
            <xsl:text disable-output-escaping="yes">&amp;</xsl:text>nbsp;
          </td>
          <td style="text-align:left; text-indent: 3em;">Dismissed Accusations</td>
          <td>
            <xsl:value-of select="SECTION_1_1/DISMISSED"/>
          </td>
          <td>
            <xsl:value-of select="SECTION_1_2/DISMISSED"/>
          </td>
          <td>
            <xsl:value-of select="SECTION_1_3/DISMISSED"/>
          </td>
        </tr>
        <tr>
          <td>
            <xsl:text disable-output-escaping="yes">&amp;</xsl:text>nbsp;
          </td>
          <td style="text-align:left; text-indent: 2.5em;">* Number of Licensing Hearings Held</td>
          <td>
            <xsl:value-of select="SECTION_1_1/PROCESSHEARINGHELD"/>
          </td>
          <td>
            <xsl:value-of select="SECTION_1_2/PROCESSHEARINGHELD"/>
          </td>
          <td>
            <xsl:value-of select="SECTION_1_3/PROCESSHEARINGHELD"/>
          </td>
        </tr>
        <tr>
          <td>
            <xsl:text disable-output-escaping="yes">&amp;</xsl:text>nbsp;
          </td>
          <td style="text-align:left; text-indent: 3em;">Penalties Imposed as a Result of a Hearing</td>
          <td>
            <xsl:value-of select="SECTION_1_1/PENALTIES"/>
          </td>
          <td>
            <xsl:value-of select="SECTION_1_2/PENALTIES"/>
          </td>
          <td>
            <xsl:value-of select="SECTION_1_3/PENALTIES"/>
          </td>
        </tr>
        <tr>
          <td>
            <xsl:text disable-output-escaping="yes">&amp;</xsl:text>nbsp;
          </td>
          <td style="text-align:left; text-indent: 3em;">Accusations Sustained After Hearing</td>
          <td>
            <xsl:value-of select="SECTION_1_1/ACCSUSTAINED"/>
          </td>
          <td>
            <xsl:value-of select="SECTION_1_2/ACCSUSTAINED"/>
          </td>
          <td>
            <xsl:value-of select="SECTION_1_3/ACCSUSTAINED"/>
          </td>
        </tr>
        <tr>
          <td colspan="5" style="height:1em;; border: none">
            <xsl:text disable-output-escaping="yes">&amp;</xsl:text>nbsp;
          </td>
        </tr>
      </tbody>
    </table>
  </xsl:template>


  <!-- ********************************************************************************** -->
  <!--   REVENUE MISCELLANEOUS STATUS                                                     -->
  <!-- ********************************************************************************** -->
  <xsl:template match="SECTION_2">
    <table id="section-2" style="border-collapse: collapse;">
      <!--   Headings for section report   -->
      <tbody>
        <tr style="font-weight: bold;">
          <td class="td-rev">III.</td>
          <td colspan="2" class="td-rev">REVENUE</td>
        </tr>
        <tr>
          <td style="width:  .2in">
            <xsl:text disable-output-escaping="yes">&amp;</xsl:text>nbsp;
          </td>
          <td style="width: 6.0in; text-align:left;">Renewals</td>
          <td style="width: 2.5in">
            <xsl:value-of select='format-number(RENEWALSANNUALS, "$###,##0")'/>
          </td>
        </tr>
        <tr>
          <td style="width:  .2in">
            <xsl:text disable-output-escaping="yes">&amp;</xsl:text>nbsp;
          </td>
          <td style="text-align:left;">Original Fees</td>
          <td>
            <xsl:value-of select='format-number(ORIGINALFEES, "$###,##0")'/>
          </td>
        </tr>
        <tr>
          <td style="width:  .2in">
            <xsl:text disable-output-escaping="yes">&amp;</xsl:text>nbsp;
          </td>
          <td style="text-align:left;">Transfers</td>
          <td>
            <xsl:value-of select='format-number(TRANSFER, "$###,##0")'/>
          </td>
        </tr>
        <tr>
          <td style="width:  .2in">
            <xsl:text disable-output-escaping="yes">&amp;</xsl:text>nbsp;
          </td>
          <td style="text-align:left;">Daily Licenses</td>
          <td>
            <xsl:value-of select='format-number(DAILYLICENSES, "$###,##0")'/>
          </td>
        </tr>
        <tr>
          <td style="width:  .2in">
            <xsl:text disable-output-escaping="yes">&amp;</xsl:text>nbsp;
          </td>
          <td style="text-align:left;">Catering Permits</td>
          <td>
            <xsl:value-of select='format-number(CATEVENTPERMITS, "$###,##0")'/>
          </td>
        </tr>
        <tr>
          <td style="width:  .2in">
            <xsl:text disable-output-escaping="yes">&amp;</xsl:text>nbsp;
          </td>
          <td style="text-align:left; text-indent: 3em;">Caterer's Authorization</td>
          <td>
            <xsl:value-of select='format-number(CATEVENTAUTH, "$###,##0")'/>
          </td>
        </tr>
        <tr>
          <td style="width:  .2in">
            <xsl:text disable-output-escaping="yes">&amp;</xsl:text>nbsp;
          </td>
          <td style="text-align:left;">Other</td>
          <td>
            <xsl:value-of select='format-number(OTHER, "$###,##0")'/>
          </td>
        </tr>
        <tr>
          <td style="width:  .2in">
            <xsl:text disable-output-escaping="yes">&amp;</xsl:text>nbsp;
          </td>
          <td>Total Licensing Revenue</td>
          <td>
            <xsl:value-of select='format-number(TOTAL, "$###,##0")'/>
          </td>
        </tr>

        <tr>
          <td style="width:  .2in">
            <xsl:text disable-output-escaping="yes">&amp;</xsl:text>nbsp;
          </td>
          <td colspan="2" style="text-align: left;">Offers in Compromise Accepted:</td>
        </tr>
        <tr>
          <td>
            <xsl:text disable-output-escaping="yes">&amp;</xsl:text>nbsp;
          </td>
          <td style="text-align:left; text-indent: 3em;">Amount</td>
          <td>
            <xsl:value-of select='format-number(POICACCEPTED, "$###,##0")'/>
          </td>
        </tr>
        <tr>
          <td>
            <xsl:text disable-output-escaping="yes">&amp;</xsl:text>nbsp;
          </td>
          <td style="text-align:left; text-indent: 3em;">Number</td>
          <td>
            <xsl:value-of select='POICCOUNT'/>
          </td>
        </tr>
        <tr>
          <td colspan="3" style="height:1em;; border: none">
            <xsl:text disable-output-escaping="yes">&amp;</xsl:text>nbsp;
          </td>
        </tr>
        <tr style="font-weight: bold;">
          <td class="td-dec">IV.</td>
          <td colspan="2" class="td-dec" style="text-align: left;">DECISIONS</td>
        </tr>
        <tr>
          <td>
            <xsl:text disable-output-escaping="yes">&amp;</xsl:text>nbsp;
          </td>
          <td style="text-align: left">Proposed Decisions Adopted</td>
          <td>
            <xsl:value-of select='PRODECADOPT'/>
          </td>
        </tr>
        <tr>
          <td>
            <xsl:text disable-output-escaping="yes">&amp;</xsl:text>nbsp;
          </td>
          <td style="text-align: left">Proposed Decisions Rejected Under Section 11517(c)</td>
          <td>
            <xsl:value-of select='PRODECREJECT'/>
          </td>
        </tr>
        <tr>
          <td>
            <xsl:text disable-output-escaping="yes">&amp;</xsl:text>nbsp;
          </td>
          <td style="text-align: left;">Suspensions</td>
          <td>
            <xsl:value-of select='SUSPENSIONS'/>
          </td>
        </tr>
        <tr>
          <td>
            <xsl:text disable-output-escaping="yes">&amp;</xsl:text>nbsp;
          </td>
          <td style="text-align: left">Revocations Including Those Stayed</td>
          <td>
            <xsl:value-of select='REVOCATIONS'/>
          </td>
        </tr>

        <tr>
          <td>
            <xsl:text disable-output-escaping="yes">&amp;</xsl:text>nbsp;
          </td>
          <td style="text-align: left; padding-top: 1.5em;">APPEALS FILED TO APPEALS BOARD</td>
          <td>
            <xsl:value-of select='APPEALSFILED'/>
          </td>
        </tr>

        <tr>
          <td style="text-align: right; padding-top:1.5em;padding-right:.0em;">*</td>
          <td style="text-align: left; padding-top:1.5em;">COURT ACTIONS FILED/PENDING</td>
          <td>
            <xsl:value-of select='ACTIONSFILEDPENDING'/>
          </td>
        </tr>

        <tr>
          <td>
            <xsl:text disable-output-escaping="yes">&amp;</xsl:text>nbsp;
          </td>
          <td style="text-align: left; padding-top:1.5em;">Stip and Waiver Received after ATTY Assignment</td>
          <td>
            <xsl:value-of select='SWATTY'/>
          </td>
        </tr>
        <tr>
          <td colspan="3" style="text-align:left;padding-top:2em;border: none; ">
            * Due to the automation of this category, data prior to August 01, 2018 will not be reflected in this total.
          </td>
        </tr>
      </tbody>
    </table>
  </xsl:template>


  <!-- ********************************************************************************** -->
  <!--   Template layout Application and Licensing Investigations Report Layout Part 1    -->
  <!-- ********************************************************************************** -->
  <xsl:template name='SECTION_3_HD'>
    <xsl:param name="PART"></xsl:param>
    <xsl:param name="CLASS"></xsl:param>

    <thead>
      <tr>
        <th rowspan="3">
          <xsl:attribute name="class">
            <xsl:value-of select="$CLASS"/>
          </xsl:attribute>
          <xsl:value-of select="@DIVISION"/>
        </th>
        <xsl:if test="$PART='1'">
          <th rowspan="3" style="vertical-align: bottom;" >
            TOTAL<br/>APPLICATIONS<br/>REC'D(211'S)
          </th>
        </xsl:if>
        <th colspan="8">APPLICATION INVESTIGATIONS (220'S)</th>
      </tr>
      <tr>
        <xsl:choose>
          <xsl:when test="$PART='1'">
            <th colspan="8">Originals</th>
          </xsl:when>
          <xsl:otherwise>
            <th colspan="8">Transfers</th>
          </xsl:otherwise>
        </xsl:choose>
      </tr>
      <tr>
        <th>RECEIVED</th>
        <th>COMP'D</th>
        <th>APPROVED</th>
        <th>DENIED</th>
        <th>WITHDRAWN</th>
        <th>VOIDED</th>
        <th>NO CREDIT WD</th>
        <th>PENDING</th>
      </tr>
    </thead>
  </xsl:template>

  <xsl:template match="SECTION_3">
    <p>
      <h3>
        <xsl:value-of select="@HEADING"/>
      </h3>
    </p>
    <table id="section-3" style="border-collapse: collapse;">
      <!--   Section details called for each division group   -->
      <xsl:apply-templates select="OFFICE[generate-id(.) = generate-id(key('groups', @DIVISION)[1])]">
        <xsl:sort select="@DIVISION"/>
        <xsl:with-param name="PART" select="'1'" />
      </xsl:apply-templates>
      <!--   Section totals   -->
      <tr>
        <td>STATEWIDE TOTALS</td>
        <td>
          <xsl:value-of select="sum(OFFICE/RECEIVED)"/>
        </td>
        <td>
          <xsl:value-of select="sum(OFFICE/ORIGINAL/RECEIVED)"/>
        </td>
        <td>
          <xsl:value-of select="sum(OFFICE/ORIGINAL/COMPLETED)"/>
        </td>
        <td>
          <xsl:value-of select="sum(OFFICE/ORIGINAL/APPROVED)"/>
        </td>
        <td>
          <xsl:value-of select="sum(OFFICE/ORIGINAL/DENIED)"/>
        </td>
        <td>
          <xsl:value-of select="sum(OFFICE/ORIGINAL/WITHDRAWN)"/>
        </td>
        <td>
          <xsl:value-of select="sum(OFFICE/ORIGINAL/VOIDED)"/>
        </td>
        <td>
          <xsl:value-of select="sum(OFFICE/ORIGINAL/NOCRDWDRN)"/>
        </td>
        <td>
          <xsl:value-of select="sum(OFFICE/ORIGINAL/PENDEND)"/>
        </td>
      </tr>
    </table>

    <p class='padding' style="page-break-before: always">
      <h3>
        <xsl:value-of select="@HEADING"/>
      </h3>
    </p>

    <!--PER TO PER Heading Section-->
    <table id="section-3" style="border-collapse: collapse;">
      <!--   Section details called for each division group   -->
      <xsl:apply-templates select="OFFICE[generate-id(.) = generate-id(key('groups', @DIVISION)[1])]">
        <xsl:sort select="@DIVISION"/>
        <xsl:with-param name="PART" select="'2'" />
      </xsl:apply-templates>
      <!--   Section totals   -->
      <tr>
        <td>STATEWIDE TOTALS</td>
        <td>
          <xsl:value-of select="sum(OFFICE/PERTOPER/RECEIVED)"/>
        </td>
        <td>
          <xsl:value-of select="sum(OFFICE/PERTOPER/COMPLETED)"/>
        </td>
        <td>
          <xsl:value-of select="sum(OFFICE/PERTOPER/APPROVED)"/>
        </td>
        <td>
          <xsl:value-of select="sum(OFFICE/PERTOPER/DENIED)"/>
        </td>
        <td>
          <xsl:value-of select="sum(OFFICE/PERTOPER/WITHDRAWN)"/>
        </td>
        <td>
          <xsl:value-of select="sum(OFFICE/PERTOPER/VOIDED)"/>
        </td>
        <td>
          <xsl:value-of select="sum(OFFICE/PERTOPER/NOCRDWDRN)"/>
        </td>
        <td>
          <xsl:value-of select="sum(OFFICE/PERTOPER/PENDEND)"/>
        </td>
      </tr>
    </table>

  </xsl:template>

  <!--   Section 3 part 1 details   -->
  <xsl:template match="SECTION_3/OFFICE">
    <xsl:param name="PART"></xsl:param>
    <xsl:variable name="currentGroup" select="."/>

    <xsl:for-each select="key('groups', @DIVISION)">
      <xsl:sort select="@OFFICENAME"/>

      <xsl:if test="position() = 1">
        <xsl:variable name="CLASS">

          <xsl:choose>
            <xsl:when test="substring(@DIVISION, 1, 1) = 'N'">
              <xsl:text>th-nd</xsl:text>
            </xsl:when>
            <xsl:when test="substring(@DIVISION, 1, 1) = 'S'">
              <xsl:text>th-sd</xsl:text>
            </xsl:when>
            <xsl:otherwise>
              <xsl:text>th-none</xsl:text>
            </xsl:otherwise>
          </xsl:choose>
        </xsl:variable>
        <xsl:call-template name="SECTION_3_HD">
          <xsl:with-param name="CLASS" select="$CLASS"></xsl:with-param>
          <xsl:with-param name="PART" select="$PART"></xsl:with-param>
        </xsl:call-template>
      </xsl:if>
      
 
        <xsl:choose>
          <xsl:when test="$PART='1'">
            <xsl:if test ="RECEIVED + ORIGINAL/RECEIVED + ORIGINAL/COMPLETED + ORIGINAL/APPROVED + ORIGINAL/DENIED + ORIGINAL/WITHDRAWN + ORIGINAL/VOIDED + ORIGINAL/NOCRDWDRN + ORIGINAL/PENDEND != 0">
     <tr>
        <td style="text-align: left; width: 1.5in;">
          <xsl:attribute name="class">
            <xsl:choose>
              <xsl:when test="substring(@DIVISION, 1, 1) = 'N'">
                <xsl:text>td-nd</xsl:text>
              </xsl:when>
              <xsl:when test="substring(@DIVISION, 1, 1) = 'S'">
                <xsl:text>td-sd</xsl:text>
              </xsl:when>
              <xsl:otherwise>
                <xsl:text>td-none</xsl:text>
              </xsl:otherwise>
            </xsl:choose>
          </xsl:attribute>
          <xsl:value-of select='@OFFICENAME'/>
        </td>
            <td>
              <xsl:value-of select='RECEIVED'/>
            </td>
            <td>
              <xsl:value-of select='ORIGINAL/RECEIVED'/>
            </td>
            <td>
              <xsl:value-of select='ORIGINAL/COMPLETED'/>
            </td>
            <td>
              <xsl:value-of select='ORIGINAL/APPROVED'/>
            </td>
            <td>
              <xsl:value-of select='ORIGINAL/DENIED'/>
            </td>
            <td>
              <xsl:value-of select='ORIGINAL/WITHDRAWN'/>
            </td>
            <td>
              <xsl:value-of select='ORIGINAL/VOIDED'/>
            </td>
            <td>
              <xsl:value-of select='ORIGINAL/NOCRDWDRN'/>
            </td>
            <td>
              <xsl:value-of select='ORIGINAL/PENDEND'/>
            </td>
          </tr>
              </xsl:if>
          </xsl:when>

          <xsl:when test="$PART='2'">
            <xsl:if test="PERTOPER/RECEIVED + PERTOPER/COMPLETED + PERTOPER/APPROVED + PERTOPER/DENIED + PERTOPER/WITHDRAWN + PERTOPER/VOIDED + PERTOPER/NOCRDWDRN + PERTOPER/PENDEND != 0">
            <tr>

              <td style="text-align: left; width: 1.5in;">
                <xsl:attribute name="class">
                  <xsl:choose>
                    <xsl:when test="substring(@DIVISION, 1, 1) = 'N'">
                      <xsl:text>td-nd</xsl:text>
                    </xsl:when>
                    <xsl:when test="substring(@DIVISION, 1, 1) = 'S'">
                      <xsl:text>td-sd</xsl:text>
                    </xsl:when>
                    <xsl:otherwise>
                      <xsl:text>td-none</xsl:text>
                    </xsl:otherwise>
                  </xsl:choose>
                </xsl:attribute>
                <xsl:value-of select='@OFFICENAME'/>
              </td>
              <td>
                <xsl:value-of select='PERTOPER/RECEIVED'/>
              </td>
              <td>
                <xsl:value-of select='PERTOPER/COMPLETED'/>
              </td>
              <td>
                <xsl:value-of select='PERTOPER/APPROVED'/>
              </td>
              <td>
                <xsl:value-of select='PERTOPER/DENIED'/>
              </td>
              <td>
                <xsl:value-of select='PERTOPER/WITHDRAWN'/>
              </td>
              <td>
                <xsl:value-of select='PERTOPER/VOIDED'/>
              </td>
              <td>
                <xsl:value-of select='PERTOPER/NOCRDWDRN'/>
              </td>
              <td>
                <xsl:value-of select='PERTOPER/PENDEND'/>
              </td>
            </tr>
            </xsl:if>
          </xsl:when>
        </xsl:choose>
   
    </xsl:for-each>

    <!--   Group totals   -->
    <xsl:choose>
      <xsl:when test="$PART='1'">
        <tr>
          <td>
            <xsl:value-of select="@DIVISION"/> TOTALS
          </td>
          <td>
            <xsl:value-of select="sum(key('groups', @DIVISION)/RECEIVED)"/>
          </td>
          <td>
            <xsl:value-of select="sum(key('groups', @DIVISION)/ORIGINAL/RECEIVED)"/>
          </td>
          <td>
            <xsl:value-of select="sum(key('groups', @DIVISION)/ORIGINAL/COMPLETED)"/>
          </td>
          <td>
            <xsl:value-of select="sum(key('groups', @DIVISION)/ORIGINAL/APPROVED)"/>
          </td>
          <td>
            <xsl:value-of select="sum(key('groups', @DIVISION)/ORIGINAL/DENIED)"/>
          </td>
          <td>
            <xsl:value-of select="sum(key('groups', @DIVISION)/ORIGINAL/WITHDRAWN)"/>
          </td>
          <td>
            <xsl:value-of select="sum(key('groups', @DIVISION)/ORIGINAL/VOIDED)"/>
          </td>
          <td>
            <xsl:value-of select="sum(key('groups', @DIVISION)/ORIGINAL/NOCRDWDRN)"/>
          </td>
          <td>
            <xsl:value-of select="sum(key('groups', @DIVISION)/ORIGINAL/PENDEND)"/>
          </td>
        </tr>
        <tr>
          <td colspan="10" style="border:none;">
            <xsl:text disable-output-escaping="yes">&amp;</xsl:text>nbsp;
          </td>
        </tr>
      </xsl:when>

      <xsl:when test="$PART='2'">
        <tr>
          <td>
            <xsl:value-of select="@DIVISION"/> TOTALS
          </td>
          <td>
            <xsl:value-of select="sum(key('groups', @DIVISION)/PERTOPER/RECEIVED)"/>
          </td>
          <td>
            <xsl:value-of select="sum(key('groups', @DIVISION)/PERTOPER/COMPLETED)"/>
          </td>
          <td>
            <xsl:value-of select="sum(key('groups', @DIVISION)/PERTOPER/APPROVED)"/>
          </td>
          <td>
            <xsl:value-of select="sum(key('groups', @DIVISION)/PERTOPER/DENIED)"/>
          </td>
          <td>
            <xsl:value-of select="sum(key('groups', @DIVISION)/PERTOPER/WITHDRAWN)"/>
          </td>
          <td>
            <xsl:value-of select="sum(key('groups', @DIVISION)/PERTOPER/VOIDED)"/>
          </td>
          <td>
            <xsl:value-of select="sum(key('groups', @DIVISION)/PERTOPER/NOCRDWDRN)"/>
          </td>
          <td>
            <xsl:value-of select="sum(key('groups', @DIVISION)/PERTOPER/PENDEND)"/>
          </td>
        </tr>
        <!--  Add row space between groups  -->
        <tr>
          <td colspan="9" style="border:none;">
            <xsl:text disable-output-escaping="yes">&amp;</xsl:text>nbsp;
          </td>
        </tr>
      </xsl:when>
    </xsl:choose>

  </xsl:template>

  <!-- ********************************************************************************** -->
  <!--   Template layout Application and Licensing Investigations Report Layout Part 2    -->
  <!-- ********************************************************************************** -->
  <xsl:template name='SECTION_4_HD'>
    <xsl:param name="CLASS"></xsl:param>
    <thead>
      <tr>
        <th rowspan="2">
          <xsl:attribute name="class">
            <xsl:value-of select="$CLASS"/>
          </xsl:attribute>
          <xsl:value-of select="../DIVISION"/>
        </th>
        <th rowspan="2">
          PRIORITY RECEIVED
        </th>
        <th rowspan="2">
          PROTESTED APPLICATIONS
        </th>
        <th colspan="3">
          TOTAL APPLICATIONS REGISTERED
        </th>
      </tr>
      <tr>
        <th>PROTESTS</th>
        <th>PETITION</th>
        <th>PETITION / PROTESTS</th>
      </tr>
    </thead>
  </xsl:template>

  <xsl:template match="SECTION_4">
    <p>
      <h3>
        <xsl:value-of select="@HEADING"/>
      </h3>
    </p>
    <table id="section-4" style="border-collapse: collapse;">
      <tbody>
        <!--   Section details called for each division group   -->
        <xsl:apply-templates select="OFFICE/DIVISION[generate-id() = generate-id(key('applicationpart2', .)[1])]">
          <xsl:sort select="../DIVISION"/>
        </xsl:apply-templates>

        <!--   Section totals   -->
        <tr>
          <td>STATEWIDE TOTALS</td>
          <td>
            <xsl:value-of select="sum(OFFICE/PRIORITYRECD)"/>
          </td>
          <td>
            <xsl:value-of select="sum(OFFICE/PROAPPS)"/>
          </td>
          <td>
            <xsl:text> * </xsl:text>
            <xsl:value-of select="sum(OFFICE/REGPRO)"/>
          </td>
          <td>
            <xsl:text> * </xsl:text>
            <xsl:value-of select="sum(OFFICE/REGPET)"/>
          </td>
          <td>
            <xsl:text> * </xsl:text>
            <xsl:value-of select="sum(OFFICE/TOTALPETPRO)"/>
          </td>
        </tr>
      </tbody>
    </table>
  </xsl:template>

  <!--   Section 4 details   -->
  <xsl:template match="SECTION_4/OFFICE/DIVISION">
    <xsl:variable name="currentGroup" select="."/>
    <xsl:for-each select="key('applicationpart2', $currentGroup)">
      <xsl:sort select="../OFFICENAME"/>
      <xsl:if test="position() = 1">
        <xsl:variable name="CLASS">

          <xsl:choose>
            <xsl:when test="substring(../DIVISION, 1, 1) = 'N'">
              <xsl:text>th-nd</xsl:text>
            </xsl:when>
            <xsl:when test="substring(../DIVISION, 1, 1) = 'S'">
              <xsl:text>th-sd</xsl:text>
            </xsl:when>
            <xsl:otherwise>
              <xsl:text>th-none</xsl:text>
            </xsl:otherwise>
          </xsl:choose>
        </xsl:variable>
        <xsl:call-template name="SECTION_4_HD">
          <xsl:with-param name="CLASS" select="$CLASS"></xsl:with-param>
        </xsl:call-template>
      </xsl:if>
      <xsl:if test="../PRIORITYRECD + ../PROAPPS + ../REGPRO + ../REGPET + ../TOTALPETPRO != 0">
      <tr>
        <td style="text-align: left; width: 1.5in;">
          <xsl:attribute name="class">
            <xsl:choose>
              <xsl:when test="substring(../DIVISION, 1, 1) = 'N'">
                <xsl:text>td-nd</xsl:text>
              </xsl:when>
              <xsl:when test="substring(../DIVISION, 1, 1) = 'S'">
                <xsl:text>td-sd</xsl:text>
              </xsl:when>
              <xsl:otherwise>
                <xsl:text>td-none</xsl:text>
              </xsl:otherwise>
            </xsl:choose>
          </xsl:attribute>
          <xsl:value-of select='../OFFICENAME'/>
        </td>
        <td>
          <xsl:value-of select='../PRIORITYRECD'/>
        </td>
        <td>
          <xsl:choose>
            <xsl:when test="number(../PROAPPS)">
              <xsl:value-of select="../PROAPPS" />
            </xsl:when>
            <xsl:otherwise>
              <xsl:value-of select="0" />
            </xsl:otherwise>
          </xsl:choose>
        </td>
        <td>
          <xsl:value-of select='../REGPRO'/>
        </td>
        <td>
          <xsl:value-of select='../REGPET'/>
        </td>
        <td>
          <xsl:value-of select='../TOTALPETPRO'/>
        </td>
      </tr>
      </xsl:if>
    </xsl:for-each>

    <!--   Group totals   -->
    <tr>
      <td>
        <xsl:value-of select="$currentGroup"/> TOTALS
      </td>
      <td>
        <xsl:value-of select="sum(key('applicationpart2', .)/../PRIORITYRECD)"/>
      </td>
      <td>
        <xsl:value-of select="sum(key('applicationpart2', .)/../PROAPPS)"/>
      </td>
      <td>
        <xsl:text> * </xsl:text>
        <xsl:value-of select="sum(key('applicationpart2', .)/../REGPRO)"/>
      </td>
      <td>
        <xsl:text> * </xsl:text>
        <xsl:value-of select="sum(key('applicationpart2', .)/../REGPET)"/>
      </td>
      <td>
        <xsl:text> * </xsl:text>
        <xsl:value-of select="sum(key('applicationpart2', .)/../TOTALPETPRO)"/>
      </td>
    </tr>

    <!--  Add row space between groups  -->
    <tr>
      <td colspan="6" style="border: none;">
        <xsl:text disable-output-escaping="yes">&amp;</xsl:text>nbsp;
      </td>
    </tr>
  </xsl:template>

  <!-- ********************************************************************************** -->
  <!--   ASSIGNMENTS (ABC-61)                                                             -->
  <!-- ********************************************************************************** -->
  <xsl:template name='SECTION_5_HD'>
    <xsl:param name="CLASS"></xsl:param>
    <thead>
      <tr>
        <th rowspan="2">
          <xsl:attribute name="class">
            <xsl:value-of select="$CLASS"/>
          </xsl:attribute>
          <xsl:value-of select="../DIVISION"/>
        </th>
        <th colspan="3" class="th-1">
          LICENSING<br/>ASSIGNMENTS (ABC-61)
        </th>
        <th colspan="3" class="th-2">
          COMPLAINT INVESTIGATION<br/>ASSIGNMENTS (ABC-61)
        </th>
        <th colspan="3" class="th-2">
          ADMINISTRATION<br/>ASSIGNMENTS (ABC-61)
        </th>
        <th colspan="3" class="th-2">
          POLICE REPORTS ASSIGNED FOR <br/>INVESTIGATION (ABC-61)
        </th>
        <th colspan="3" class="th-2">
          TRACE<br/>ASSIGNMENTS (ABC-61)
        </th>
      </tr>
      <tr>
        <th>REC'D</th>
        <th>COMP'D</th>
        <th>PEND'G</th>
        <th>REC'D</th>
        <th>COMP'D</th>
        <th>PEND'G</th>
        <th>REC'D</th>
        <th>COMP'D</th>
        <th>PEND'G</th>
        <th>REC'D</th>
        <th>COMP'D</th>
        <th>PEND'G</th>
        <th>REC'D</th>
        <th>COMP'D</th>
        <th>PEND'G</th>
      </tr>
    </thead>
  </xsl:template>

  <xsl:template match="SECTION_5">
    <p>
      <h3>
        <xsl:value-of select="@HEADING"/>
      </h3>
    </p>
    <table id="section-5" style="border-collapse: collapse;">
      <tbody>
        <!--   Section details called for each division group   -->
        <xsl:apply-templates select="OFFICE/DIVISION[generate-id() = generate-id(key('assignments', .)[1])]">
          <xsl:sort select="../DIVISION"/>
        </xsl:apply-templates>

        <!--   Section totals   -->
        <tr>
          <td>STATEWIDE TOTALS</td>
          <td>
            <xsl:value-of select="sum(OFFICE/LICENSINGRECEIVED)"/>
          </td>
          <td>
            <xsl:value-of select="sum(OFFICE/LICENSINGCOMPLETED)"/>
          </td>
          <td>
            <xsl:value-of select="sum(OFFICE/LICENSINGPENDINGENDING)"/>
          </td>
          <td>
            <xsl:value-of select="sum(OFFICE/INVESTIGATIONRECEIVED)"/>
          </td>
          <td>
            <xsl:value-of select="sum(OFFICE/INVESTIGATIONCOMPLETED)"/>
          </td>
          <td>
            <xsl:value-of select="sum(OFFICE/INVESTIGATIONPENDINGENDING)"/>
          </td>
          <td>
            <xsl:value-of select="sum(OFFICE/ADMINISTRATIVERECEIVED)"/>
          </td>
          <td>
            <xsl:value-of select="sum(OFFICE/ADMINISTRATIVECOMPLETED)"/>
          </td>
          <td>
            <xsl:value-of select="sum(OFFICE/ADMINISTRATIVEPENDINGENDING)"/>
          </td>
          <td>
            <xsl:value-of select="sum(OFFICE/POLICEREPORTRECEIVED)"/>
          </td>
          <td>
            <xsl:value-of select="sum(OFFICE/POLICEREPORTCOMPLETED)"/>
          </td>
          <td>
            <xsl:value-of select="sum(OFFICE/POLICEREPORTPENDINGENDING)"/>
          </td>
          <td>
            <xsl:value-of select="sum(OFFICE/TRACERECEIVED)"/>
          </td>
          <td>
            <xsl:value-of select="sum(OFFICE/TRACECOMPLETED)"/>
          </td>
          <td>
            <xsl:value-of select="sum(OFFICE/TRACEPENDINGENDING)"/>
          </td>
        </tr>
      </tbody>
    </table>
  </xsl:template>

  <!--   Section 5 details   -->
  <xsl:template match="SECTION_5/OFFICE/DIVISION">
    <xsl:variable name="currentGroup" select="."/>
    <xsl:for-each select="key('assignments', $currentGroup)">
      <xsl:sort select="../OFFICENAME"/>
      <xsl:if test="position() = 1">
        <xsl:variable name="CLASS">

          <xsl:choose>
            <xsl:when test="substring(../DIVISION, 1, 1) = 'N'">
              <xsl:text>th-nd</xsl:text>
            </xsl:when>
            <xsl:when test="substring(../DIVISION, 1, 1) = 'S'">
              <xsl:text>th-sd</xsl:text>
            </xsl:when>
            <xsl:otherwise>
              <xsl:text>th-none</xsl:text>
            </xsl:otherwise>
          </xsl:choose>
        </xsl:variable>
        <xsl:call-template name="SECTION_5_HD">
          <xsl:with-param name="CLASS" select="$CLASS"></xsl:with-param>
        </xsl:call-template>
      </xsl:if>
      <xsl:if test ="../LICENSINGRECEIVED + ../LICENSINGCOMPLETED + ../INVESTIGATIONCOMPLETED + ../INVESTIGATIONPENDINGENDING + ../ADMINISTRATIVERECEIVED + ../ADMINISTRATIVECOMPLETED + ../ADMINISTRATIVEPENDINGENDING + ../POLICEREPORTRECEIVED + ../POLICEREPORTCOMPLETED + ../POLICEREPORTPENDINGENDING + ../TRACERECEIVED + ../TRACECOMPLETED + ../TRACEPENDINGENDING != 0 ">
        <tr>
          <td style="text-align: left; width: 1.5in;">
            <xsl:attribute name="class">
              <xsl:choose>
                <xsl:when test="substring(../DIVISION, 1, 1) = 'N'">
                  <xsl:text>td-nd</xsl:text>
                </xsl:when>
                <xsl:when test="substring(../DIVISION, 1, 1) = 'S'">
                  <xsl:text>td-sd</xsl:text>
                </xsl:when>
                <xsl:otherwise>
                  <xsl:text>td-none</xsl:text>
                </xsl:otherwise>
              </xsl:choose>
            </xsl:attribute>
            <xsl:value-of select='../OFFICENAME'/>
          </td>
          <td>
            <xsl:value-of select='../LICENSINGRECEIVED'/>
          </td>
          <td>
            <xsl:value-of select='../LICENSINGCOMPLETED'/>
          </td>
          <td>
            <xsl:value-of select='../LICENSINGPENDINGENDING'/>
          </td>
          <td>
            <xsl:value-of select='../INVESTIGATIONRECEIVED'/>
          </td>
          <td>
            <xsl:value-of select='../INVESTIGATIONCOMPLETED'/>
          </td>
          <td>
            <xsl:value-of select='../INVESTIGATIONPENDINGENDING'/>
          </td>
          <td>
            <xsl:value-of select='../ADMINISTRATIVERECEIVED'/>
          </td>
          <td>
            <xsl:value-of select='../ADMINISTRATIVECOMPLETED'/>
          </td>
          <td>
            <xsl:value-of select='../ADMINISTRATIVEPENDINGENDING'/>
          </td>
          <td>
            <xsl:value-of select='../POLICEREPORTRECEIVED'/>
          </td>
          <td>
            <xsl:value-of select='../POLICEREPORTCOMPLETED'/>
          </td>
          <td>
            <xsl:value-of select='../POLICEREPORTPENDINGENDING'/>
          </td>
          <td>
            <xsl:value-of select='../TRACERECEIVED'/>
          </td>
          <td>
            <xsl:value-of select='../TRACECOMPLETED'/>
          </td>
          <td>
            <xsl:value-of select='../TRACEPENDINGENDING'/>
          </td>
        </tr>
      </xsl:if>

    </xsl:for-each>

    <!--   Group totals   -->
    <tr>
      <td>
        <xsl:value-of select="$currentGroup"/> TOTALS
      </td>
      <td>
        <xsl:value-of select="sum(key('assignments', .)/../LICENSINGRECEIVED)"/>
      </td>
      <td>
        <xsl:value-of select="sum(key('assignments', .)/../LICENSINGCOMPLETED)"/>
      </td>
      <td>
        <xsl:value-of select="sum(key('assignments', .)/../LICENSINGPENDINGENDING)"/>
      </td>
      <td>
        <xsl:value-of select="sum(key('assignments', .)/../INVESTIGATIONRECEIVED)"/>
      </td>
      <td>
        <xsl:value-of select="sum(key('assignments', .)/../INVESTIGATIONCOMPLETED)"/>
      </td>
      <td>
        <xsl:value-of select="sum(key('assignments', .)/../INVESTIGATIONPENDINGENDING)"/>
      </td>
      <td>
        <xsl:value-of select="sum(key('assignments', .)/../ADMINISTRATIVERECEIVED)"/>
      </td>
      <td>
        <xsl:value-of select="sum(key('assignments', .)/../ADMINISTRATIVECOMPLETED)"/>
      </td>
      <td>
        <xsl:value-of select="sum(key('assignments', .)/../ADMINISTRATIVEPENDINGENDING)"/>
      </td>
      <td>
        <xsl:value-of select="sum(key('assignments', .)/../POLICEREPORTRECEIVED)"/>
      </td>
      <td>
        <xsl:value-of select="sum(key('assignments', .)/../POLICEREPORTCOMPLETED)"/>
      </td>
      <td>
        <xsl:value-of select="sum(key('assignments', .)/../POLICEREPORTPENDINGENDING)"/>
      </td>
      <td>
        <xsl:value-of select="sum(key('assignments', .)/../TRACERECEIVED)"/>
      </td>
      <td>
        <xsl:value-of select="sum(key('assignments', .)/../TRACECOMPLETED)"/>
      </td>
      <td>
        <xsl:value-of select="sum(key('assignments', .)/../TRACEPENDINGENDING)"/>
      </td>
    </tr>

    <!--  Add row space between groups  -->
    <tr>
      <td colspan="16" style="border: none;">
        <xsl:text disable-output-escaping="yes">&amp;</xsl:text>nbsp;
      </td>
    </tr>
  </xsl:template>


  <!-- ********************************************************************************** -->
  <!--   ARRESTS                                                                          -->
  <!-- ********************************************************************************** -->
  <xsl:template name='SECTION_6_HD'>
    <xsl:param name="CLASS"></xsl:param>
    <thead>
      <tr>
        <th rowspan="3">
          <xsl:attribute name="class">
            <xsl:value-of select="$CLASS"/>
          </xsl:attribute>
          <xsl:text disable-output-escaping="yes">&amp;</xsl:text>nbsp;
          <xsl:value-of select="../DIVISION"/>
        </th>
        <th rowspan="2" colspan="2">
          PREMISES VISITED
        </th>
        <th colspan="6">
          ARRESTS/CITATIONS
        </th>
        <th rowspan="3">
          TOTAL WARNING <br/> LTRS SENT
        </th>
      </tr>
      <tr>
        <th colspan="2">MINORS</th>
        <th colspan="2">OTHERS</th>
        <th colspan="2">TOTAL</th>
      </tr>
      <tr>
        <th>LICENSING</th>
        <th>ENFORCEMENT</th>
        <th>ABC</th>
        <th>JT</th>
        <th>ABC</th>
        <th>JT</th>
        <th>ABC</th>
        <th>JT</th>
      </tr>
    </thead>
  </xsl:template>

  <xsl:template match="SECTION_6">
    <p>
      <h3>
        <xsl:value-of select="@HEADING"/>
      </h3>
    </p>
    <table id="section-6" style="border-collapse: collapse;">
      <tbody>
        <!--   Section details called for each division group   -->
        <xsl:apply-templates select="OFFICE/DIVISION[generate-id() = generate-id(key('arrests', .)[1])]">
          <xsl:sort select="../DIVISION"/>
        </xsl:apply-templates>

        <!--   Section totals   -->
        <tr>
          <td>STATEWIDE TOTALS</td>
          <td>
            <xsl:value-of select="sum(OFFICE/PREMISESVISITEDLICENSING)"/>
          </td>
          <td>
            <xsl:value-of select="sum(OFFICE/PREMISESVISITEDENFORCEMENT)"/>
          </td>
          <td>
            <xsl:value-of select="sum(OFFICE/MINORABC)"/>
          </td>
          <td>
            <xsl:value-of select="sum(OFFICE/MINORJOINT)"/>
          </td>
          <td>
            <xsl:value-of select="sum(OFFICE/OTHERABC)"/>
          </td>
          <td>
            <xsl:value-of select="sum(OFFICE/OTHERJOINT)"/>
          </td>
          <td>
            <xsl:value-of select="sum(OFFICE/MINORABC) + sum(OFFICE/OTHERABC)"/>
          </td>
          <td>
            <xsl:value-of select="sum(OFFICE/MINORJOINT) + sum(OFFICE/OTHERJOINT)"/>
          </td>
          <td>
            <xsl:value-of select="sum(OFFICE/WARNINGLETTERSSENT)"/>
          </td>
        </tr>
      </tbody>
    </table>
  </xsl:template>

  <xsl:template match="SECTION_6/OFFICE/DIVISION">
    <xsl:variable name="currentGroup" select="."/>
    <xsl:for-each select="key('arrests', $currentGroup)">
      <xsl:sort select="../OFFICENAME"/>
      <xsl:if test="position() = 1">
        <xsl:variable name="CLASS">

          <xsl:choose>
            <xsl:when test="substring(../DIVISION, 1, 1) = 'N'">
              <xsl:text>th-nd</xsl:text>
            </xsl:when>
            <xsl:when test="substring(../DIVISION, 1, 1) = 'S'">
              <xsl:text>th-sd</xsl:text>
            </xsl:when>
            <xsl:otherwise>
              <xsl:text>th-none</xsl:text>
            </xsl:otherwise>
          </xsl:choose>
        </xsl:variable>
        <xsl:call-template name="SECTION_6_HD">
          <xsl:with-param name="CLASS" select="$CLASS"></xsl:with-param>
        </xsl:call-template>
      </xsl:if>
        <xsl:if test="../PREMISESVISITEDLICENSING + ../PREMISESVISITEDENFORCEMENT + ../MINORABC + ../MINORJOINT + ../OTHERABC + ../OTHERJOINT + ../WARNINGLETTERSSENT != 0">
      <tr>
        <td style="text-align: left; width: 1.5in;">
          <xsl:attribute name="class">
            <xsl:choose>
              <xsl:when test="substring(../DIVISION, 1, 1) = 'N'">
                <xsl:text>td-nd</xsl:text>
              </xsl:when>
              <xsl:when test="substring(../DIVISION, 1, 1) = 'S'">
                <xsl:text>td-sd</xsl:text>
              </xsl:when>
              <xsl:otherwise>
                <xsl:text>td-none</xsl:text>
              </xsl:otherwise>
            </xsl:choose>
          </xsl:attribute>
          <xsl:value-of select='../OFFICENAME'/>
        </td>
        <td style="width: .85in;">
          <xsl:value-of select='../PREMISESVISITEDLICENSING'/>
        </td>
        <td style="width: .85in;">
          <xsl:value-of select='../PREMISESVISITEDENFORCEMENT'/>
        </td>
        <td>
          <xsl:value-of select='../MINORABC'/>
        </td>
        <td>
          <xsl:value-of select='../MINORJOINT'/>
        </td>
        <td>
          <xsl:value-of select='../OTHERABC'/>
        </td>
        <td>
          <xsl:value-of select='../OTHERJOINT'/>
        </td>
        <td>
          <xsl:value-of select='../MINORABC + ../OTHERABC'/>
        </td>
        <td>
          <xsl:value-of select='../MINORJOINT + ../OTHERJOINT'/>
        </td>
        <td style="width: .75in">
          <xsl:value-of select='../WARNINGLETTERSSENT'/>
        </td>
     </tr>
         </xsl:if>
    </xsl:for-each>

    <!--   Group totals   -->
    <tr>
      <td>
        <xsl:value-of select="$currentGroup"/> TOTALS
      </td>
      <td>
        <xsl:value-of select="sum(key('arrests', .)/../PREMISESVISITEDLICENSING)"/>
      </td>
      <td>
        <xsl:value-of select="sum(key('arrests', .)/../PREMISESVISITEDENFORCEMENT)"/>
      </td>
      <td>
        <xsl:value-of select="sum(key('arrests', .)/../MINORABC)"/>
      </td>
      <td>
        <xsl:value-of select="sum(key('arrests', .)/../MINORJOINT)"/>
      </td>
      <td>
        <xsl:value-of select="sum(key('arrests', .)/../OTHERABC)"/>
      </td>
      <td>
        <xsl:value-of select="sum(key('arrests', .)/../OTHERJOINT)"/>
      </td>
      <td>
        <xsl:value-of select="sum(key('arrests', .)/../MINORABC) + sum(key('arrests', .)/../OTHERABC)"/>
      </td>
      <td>
        <xsl:value-of select="sum(key('arrests', .)/../MINORJOINT) + sum(key('arrests', .)/../OTHERJOINT)"/>
      </td>
      <td>
        <xsl:value-of select="sum(key('arrests', .)/../WARNINGLETTERSSENT)"/>
      </td>
    </tr>

    <!--  Add row space between groups  -->
    <tr>
      <td colspan="10" style="border: none;">
        <xsl:text disable-output-escaping="yes">&amp;</xsl:text>nbsp;
      </td>
    </tr>
  </xsl:template>

  <!-- ********************************************************************************** -->
  <!--   ACCUSATIONS PART 1 & 2                                                           -->
  <!-- ********************************************************************************** -->
  <xsl:template name="SECTION_7_HD">
    <xsl:param name="PART"></xsl:param>
    <xsl:param name="CLASS"></xsl:param>
    <thead>
      <tr>
        <xsl:choose>
          <xsl:when test="$PART='1'">
            <th rowspan="2">
              <xsl:attribute name="class">
                <xsl:value-of select="$CLASS"/>
              </xsl:attribute>
              <xsl:value-of select="../DIVISION"/>
            </th>
            <th rowspan="2">
              TOTAL ACCUSATIONS REGISTERED
            </th>
            <th colspan="2">
              MINOR VIOLATIONS
            </th>
            <th colspan="2">
              MINOR DECOY
            </th>
            <th colspan="2">
              OBVIOUSLY INTOXICATED
            </th>
            <th colspan="2">
              DRUGS
            </th>
            <th colspan="2">
              DISORDERLY PREMISES
            </th>
            <th colspan="2">
              RETAIL OPERATING STANDARDS
            </th>
            <th colspan="2">
              WEAPONS VIOLATIONS
            </th>
            <th colspan="2">
              STOLEN PROPERTY
            </th>
          </xsl:when>
          <xsl:otherwise>
            <th rowspan="2">
              <xsl:attribute name="class">
                <xsl:value-of select="$CLASS"/>
              </xsl:attribute>
              <xsl:value-of select="../DIVISION"/>
            </th>
            <th colspan="2">
              GAMBLING
            </th>
            <th colspan="2">
              SOLICITING DRINKS
            </th>
            <th colspan="2">
              AFTER HOURS
            </th>
            <th colspan="2">
              BUSINESS PRACTICES
            </th>
            <th colspan="2">
              MORAL TURPITUDE
            </th>
            <th colspan="2">
              PROSTITUTION
            </th>
            <th colspan="2">
              VIOLATION OF CONDITIONS
            </th>
            <th colspan="2">
              OTHER
            </th>
            <th colspan="2">
              TOTAL VIOLATIONS
            </th>
          </xsl:otherwise>
        </xsl:choose>
      </tr>
      <tr>
        <th>ABC</th>
        <th>BT</th>
        <th>ABC</th>
        <th>BT</th>
        <th>ABC</th>
        <th>BT</th>
        <th>ABC</th>
        <th>BT</th>
        <th>ABC</th>
        <th>BT</th>
        <th>ABC</th>
        <th>BT</th>
        <th>ABC</th>
        <th>BT</th>
        <th>ABC</th>
        <th>BT</th>
        <xsl:if test="$PART='2'">
          <th>ABC</th>
          <th>BT</th>
        </xsl:if>
      </tr>
    </thead>
  </xsl:template>

  <xsl:template match="SECTION_7">
    <xsl:param name="PART"></xsl:param>
    <xsl:param name="ID"></xsl:param>
    <p>
      <h3>
        <xsl:value-of select="@HEADING"/> - <xsl:value-of select="$ID"/>
      </h3>
    </p>

    <xsl:choose>
      <xsl:when test="$PART='1'">
        <table id="section-7" style="border-collapse: collapse;">
          <tbody>
            <!--   Section details called for each division group   -->
            <xsl:apply-templates select="OFFICE/DIVISION[generate-id() = generate-id(key('accusations', .)[1])]">
              <xsl:with-param name="PART" select="$PART" />
              <xsl:sort select="../DIVISION"/>
            </xsl:apply-templates>

            <!--   Section totals   -->
            <tr>
              <td>STATEWIDE TOTALS</td>
              <td>
                <xsl:value-of select="sum(OFFICE/TOTLREG)"/>
              </td>
              <td>
                <xsl:value-of select="sum(OFFICE/ABCMINOR)"/>
              </td>
              <td>
                <xsl:value-of select="sum(OFFICE/BTMINOR)"/>
              </td>
              <td>
                <xsl:value-of select="sum(OFFICE/ABCDECOY)"/>
              </td>
              <td>
                <xsl:value-of select="sum(OFFICE/BTDECOY)"/>
              </td>
              <td>
                <xsl:value-of select="sum(OFFICE/ABCOBVINTOXICATED)"/>
              </td>
              <td>
                <xsl:value-of select="sum(OFFICE/BTOBVINTOXICATED)"/>
              </td>
              <td>
                <xsl:value-of select="sum(OFFICE/ABCDRUGS)"/>
              </td>
              <td>
                <xsl:value-of select="sum(OFFICE/BTDRUGS)"/>
              </td>
              <td>
                <xsl:value-of select="sum(OFFICE/ABCDISORDERLYPREM)"/>
              </td>
              <td>
                <xsl:value-of select="sum(OFFICE/BTDISORDERLYPREM)"/>
              </td>
              <td>
                <xsl:value-of select="sum(OFFICE/ABCROSTF)"/>
              </td>
              <td>
                <xsl:value-of select="sum(OFFICE/BTROSTF)"/>
              </td>
              <td>
                <xsl:value-of select="sum(OFFICE/ABCWEAPONSVIOLATIONS)"/>
              </td>
              <td>
                <xsl:value-of select="sum(OFFICE/BTWEAPONSVIOLATIONS)"/>
              </td>
              <td>
                <xsl:value-of select="sum(OFFICE/ABCSTOLENPROPERTY)"/>
              </td>
              <td>
                <xsl:value-of select="sum(OFFICE/BTSTOLENPROPERTY)"/>
              </td>
            </tr>
          </tbody>
        </table>
      </xsl:when>
      <xsl:when test="$PART='2'">
        <table id="section-7" style="border-collapse: collapse;">
          <tbody>
            <!--   Section details called for each division group   -->
            <xsl:apply-templates select="OFFICE/DIVISION[generate-id() = generate-id(key('accusations', .)[1])]">
              <xsl:with-param name="PART" select="$PART" />
              <xsl:sort select="../DIVISION"/>
            </xsl:apply-templates>

            <!--   Section totals   -->
            <tr>
              <td>STATEWIDE TOTALS</td>
              <td>
                <xsl:value-of select="sum(OFFICE/ABCGAMBLING)"/>
              </td>
              <td>
                <xsl:value-of select="sum(OFFICE/BTGAMBLING)"/>
              </td>
              <td>
                <xsl:value-of select="sum(OFFICE/ABCSOLICITINGDRINKS)"/>
              </td>
              <td>
                <xsl:value-of select="sum(OFFICE/BTSOLICITINGDRINKS)"/>
              </td>
              <td>
                <xsl:value-of select="sum(OFFICE/ABCAFTERHOURS)"/>
              </td>
              <td>
                <xsl:value-of select="sum(OFFICE/BTAFTERHOURS)"/>
              </td>
              <td>
                <xsl:value-of select="sum(OFFICE/ABCBP)"/>
              </td>
              <td>
                <xsl:value-of select="sum(OFFICE/BTBP)"/>
              </td>
              <td>
                <xsl:value-of select="sum(OFFICE/ABCMORALTURPITUDE)"/>
              </td>
              <td>
                <xsl:value-of select="sum(OFFICE/BTMORALTURPITUDE)"/>
              </td>
              <td>
                <xsl:value-of select="sum(OFFICE/ABCPROSTITUTION)"/>
              </td>
              <td>
                <xsl:value-of select="sum(OFFICE/BTPROSTITUTION)"/>
              </td>
              <td>
                <xsl:value-of select="sum(OFFICE/ABCVIOLATIONCONDITIONS)"/>
              </td>
              <td>
                <xsl:value-of select="sum(OFFICE/BTVIOLATIONCONDITIONS)"/>
              </td>
              <td>
                <xsl:value-of select="sum(OFFICE/ABCOTHER)"/>
              </td>
              <td>
                <xsl:value-of select="sum(OFFICE/BTOTHER)"/>
              </td>
              <td>
                <xsl:value-of select="sum(OFFICE/ABC)"/>
              </td>
              <td>
                <xsl:value-of select="sum(OFFICE/BT)"/>
              </td>
            </tr>
          </tbody>
        </table>
      </xsl:when>
    </xsl:choose>
  </xsl:template>

  <!--   Section 7 details   -->
  <xsl:template match="SECTION_7/OFFICE/DIVISION">
    <xsl:param name="PART"></xsl:param>
    <xsl:variable name="currentGroup" select="."/>
    <xsl:choose>
      <xsl:when test="$PART='1'">

        <xsl:for-each select="key('accusations', $currentGroup)">
          <xsl:sort select="../OFFICENAME"/>
          <xsl:if test="position() = 1">
            <xsl:variable name="CLASS">
              <xsl:choose>
                <xsl:when test="substring(../DIVISION, 1, 1) = 'N'">
                  <xsl:text>th-nd</xsl:text>
                </xsl:when>
                <xsl:when test="substring(../DIVISION, 1, 1) = 'S'">
                  <xsl:text>th-sd</xsl:text>
                </xsl:when>
                <xsl:otherwise>
                  <xsl:text>th-none</xsl:text>
                </xsl:otherwise>
              </xsl:choose>
            </xsl:variable>
            <xsl:call-template name="SECTION_7_HD">
              <xsl:with-param name="CLASS" select="$CLASS"></xsl:with-param>
              <xsl:with-param name="PART" select="$PART"></xsl:with-param>
            </xsl:call-template>
          </xsl:if>

          <xsl:if test="../TOTLREG != 0">
          <tr>
            <td style="text-align: left; width: 1.5in;">
              <xsl:attribute name="class">
                <xsl:choose>
                  <xsl:when test="substring(../DIVISION, 1, 1) = 'N'">
                    <xsl:text>td-nd</xsl:text>
                  </xsl:when>
                  <xsl:when test="substring(../DIVISION, 1, 1) = 'S'">
                    <xsl:text>td-sd</xsl:text>
                  </xsl:when>
                  <xsl:otherwise>
                    <xsl:text>td-none</xsl:text>
                  </xsl:otherwise>
                </xsl:choose>
              </xsl:attribute>
              <xsl:value-of select='../OFFICENAME'/>
            </td>
            <td>
              <xsl:value-of select='../TOTLREG'/>
              <!--<xsl:value-of select='../ABC + ../BT'/>-->
            </td>
            <td>
              <xsl:value-of select='../ABCMINOR'/>
            </td>
            <td>
              <xsl:value-of select='../BTMINOR'/>
            </td>
            <td>
              <xsl:value-of select='../ABCDECOY'/>
            </td>
            <td>
              <xsl:value-of select='../BTDECOY'/>
            </td>
            <td>
              <xsl:value-of select='../ABCOBVINTOXICATED'/>
            </td>
            <td>
              <xsl:value-of select='../BTOBVINTOXICATED'/>
            </td>
            <td>
              <xsl:value-of select='../ABCDRUGS'/>
            </td>
            <td>
              <xsl:value-of select='../BTDRUGS'/>
            </td>
            <td>
              <xsl:value-of select='../ABCDISORDERLYPREM'/>
            </td>
            <td>
              <xsl:value-of select='../BTDISORDERLYPREM'/>
            </td>
            <td>
              <xsl:value-of select='../ABCROSTF'/>
            </td>
            <td>
              <xsl:value-of select='../BTROSTF'/>
            </td>
            <td>
              <xsl:value-of select='../ABCWEAPONSVIOLATIONS'/>
            </td>
            <td>
              <xsl:value-of select='../BTWEAPONSVIOLATIONS'/>
            </td>
            <td>
              <xsl:value-of select='../ABCSTOLENPROPERTY'/>
            </td>
            <td>
              <xsl:value-of select='../BTSTOLENPROPERTY'/>
            </td>
          </tr>
          </xsl:if>
        </xsl:for-each>

        <!--   Group totals   -->
        <tr>
          <td>
            <xsl:value-of select="$currentGroup"/> TOTALS
          </td>
          <td>
            <xsl:value-of select="sum(key('accusations', .)/../TOTLREG)"/>
            <!--<xsl:value-of select="sum(key('accusations', .)/../ABC) + sum(key('accusations', .)/../BT)"/>-->
          </td>
          <td>
            <xsl:value-of select="sum(key('accusations', .)/../ABCMINOR)"/>
          </td>
          <td>
            <xsl:value-of select="sum(key('accusations', .)/../BTMINOR)"/>
          </td>
          <td>
            <xsl:value-of select="sum(key('accusations', .)/../ABCDECOY)"/>
          </td>
          <td>
            <xsl:value-of select="sum(key('accusations', .)/../BTDECOY)"/>
          </td>
          <td>
            <xsl:value-of select="sum(key('accusations', .)/../ABCOBVINTOXICATED)"/>
          </td>
          <td>
            <xsl:value-of select="sum(key('accusations', .)/../BTOBVINTOXICATED)"/>
          </td>
          <td>
            <xsl:value-of select="sum(key('accusations', .)/../ABCDRUGS)"/>
          </td>
          <td>
            <xsl:value-of select="sum(key('accusations', .)/../BTDRUGS)"/>
          </td>
          <td>
            <xsl:value-of select="sum(key('accusations', .)/../ABCDISORDERLYPREM)"/>
          </td>
          <td>
            <xsl:value-of select="sum(key('accusations', .)/../BTDISORDERLYPREM)"/>
          </td>
          <td>
            <xsl:value-of select="sum(key('accusations', .)/../ABCROSTF)"/>
          </td>
          <td>
            <xsl:value-of select="sum(key('accusations', .)/../BTROSTF)"/>
          </td>
          <td>
            <xsl:value-of select="sum(key('accusations', .)/../ABCWEAPONSVIOLATIONS)"/>
          </td>
          <td>
            <xsl:value-of select="sum(key('accusations', .)/../BTWEAPONSVIOLATIONS)"/>
          </td>
          <td>
            <xsl:value-of select="sum(key('accusations', .)/../ABCSTOLENPROPERTY)"/>
          </td>
          <td>
            <xsl:value-of select="sum(key('accusations', .)/../BTSTOLENPROPERTY)"/>
          </td>
        </tr>
        <!--  Add row space between groups  -->
        <tr>
          <td colspan="14" style="border: none;">
            <xsl:text disable-output-escaping="yes">&amp;</xsl:text>nbsp;
          </td>
        </tr>

      </xsl:when>
      <xsl:when test="$PART='2'">
        <xsl:for-each select="key('accusations', $currentGroup)">
          <xsl:sort select="../OFFICENAME"/>
          <xsl:if test="position() = 1">
            <xsl:variable name="CLASS">
              <xsl:choose>
                <xsl:when test="substring(../DIVISION, 1, 1) = 'N'">
                  <xsl:text>th-nd</xsl:text>
                </xsl:when>
                <xsl:when test="substring(../DIVISION, 1, 1) = 'S'">
                  <xsl:text>th-sd</xsl:text>
                </xsl:when>
                <xsl:otherwise>
                  <xsl:text>th-none</xsl:text>
                </xsl:otherwise>
              </xsl:choose>
            </xsl:variable>
            <xsl:call-template name="SECTION_7_HD">
              <xsl:with-param name="CLASS" select="$CLASS"></xsl:with-param>
              <xsl:with-param name="PART" select="$PART"></xsl:with-param>
            </xsl:call-template>
          </xsl:if>
          <xsl:if test="../TOTLREG != 0">
          <tr>
            <td style="text-align: left; width: 1.5in;">
              <xsl:attribute name="class">
                <xsl:choose>
                  <xsl:when test="substring(../DIVISION, 1, 1) = 'N'">
                    <xsl:text>td-nd</xsl:text>
                  </xsl:when>
                  <xsl:when test="substring(../DIVISION, 1, 1) = 'S'">
                    <xsl:text>td-sd</xsl:text>
                  </xsl:when>
                  <xsl:otherwise>
                    <xsl:text>td-none</xsl:text>
                  </xsl:otherwise>
                </xsl:choose>
              </xsl:attribute>
              <xsl:value-of select='../OFFICENAME'/>
            </td>
            <td>
              <xsl:value-of select='../ABCGAMBLING'/>
            </td>
            <td>
              <xsl:value-of select='../BTGAMBLING'/>
            </td>
            <td>
              <xsl:value-of select='../ABCSOLICITINGDRINKS'/>
            </td>
            <td>
              <xsl:value-of select='../BTSOLICITINGDRINKS'/>
            </td>
            <td>
              <xsl:value-of select='../ABCAFTERHOURS'/>
            </td>
            <td>
              <xsl:value-of select='../BTAFTERHOURS'/>
            </td>
            <td>
              <xsl:value-of select='../ABCBP'/>
            </td>
            <td>
              <xsl:value-of select='../BTBP'/>
            </td>
            <td>
              <xsl:value-of select='../ABCMORALTURPITUDE'/>
            </td>
            <td>
              <xsl:value-of select='../BTMORALTURPITUDE'/>
            </td>
            <td>
              <xsl:value-of select='../ABCPROSTITUTION'/>
            </td>
            <td>
              <xsl:value-of select='../BTPROSTITUTION'/>
            </td>
            <td>
              <xsl:value-of select='../ABCVIOLATIONCONDITIONS'/>
            </td>
            <td>
              <xsl:value-of select='../BTVIOLATIONCONDITIONS'/>
            </td>
            <td>
              <xsl:value-of select='../ABCOTHER'/>
            </td>
            <td>
              <xsl:value-of select='../BTOTHER'/>
            </td>
            <td>
              <xsl:value-of select='../ABC'/>
            </td>
            <td>
              <xsl:value-of select='../BT'/>
            </td>
          </tr>
          </xsl:if>
        </xsl:for-each>

        <!--   Group totals   -->
        <tr>
          <td>
            <xsl:value-of select="$currentGroup"/> TOTALS
          </td>
          <td>
            <xsl:value-of select="sum(key('accusations', .)/../ABCGAMBLING)"/>
          </td>
          <td>
            <xsl:value-of select="sum(key('accusations', .)/../BTGAMBLING)"/>
          </td>
          <td>
            <xsl:value-of select="sum(key('accusations', .)/../ABCSOLICITINGDRINKS)"/>
          </td>
          <td>
            <xsl:value-of select="sum(key('accusations', .)/../BTSOLICITINGDRINKS)"/>
          </td>
          <td>
            <xsl:value-of select="sum(key('accusations', .)/../ABCAFTERHOURS)"/>
          </td>
          <td>
            <xsl:value-of select="sum(key('accusations', .)/../BTAFTERHOURS)"/>
          </td>
          <td>
            <xsl:value-of select="sum(key('accusations', .)/../ABCBP)"/>
          </td>
          <td>
            <xsl:value-of select="sum(key('accusations', .)/../BTBP)"/>
          </td>
          <td>
            <xsl:value-of select="sum(key('accusations', .)/../ABCMORALTURPITUDE)"/>
          </td>
          <td>
            <xsl:value-of select="sum(key('accusations', .)/../BTMORALTURPITUDE)"/>
          </td>
          <td>
            <xsl:value-of select="sum(key('accusations', .)/../ABCPROSTITUTION)"/>
          </td>
          <td>
            <xsl:value-of select="sum(key('accusations', .)/../BTPROSTITUTION)"/>
          </td>
          <td>
            <xsl:value-of select="sum(key('accusations', .)/../ABCVIOLATIONCONDITIONS)"/>
          </td>
          <td>
            <xsl:value-of select="sum(key('accusations', .)/../BTVIOLATIONCONDITIONS)"/>
          </td>
          <td>
            <xsl:value-of select="sum(key('accusations', .)/../ABCOTHER)"/>
          </td>
          <td>
            <xsl:value-of select="sum(key('accusations', .)/../BTOTHER)"/>
          </td>
          <td>
            <xsl:value-of select="sum(key('accusations', .)/../ABC)"/>
          </td>
          <td>
            <xsl:value-of select="sum(key('accusations', .)/../BT)"/>
          </td>
        </tr>

        <!--  Add row space between groups  -->
        <tr>
          <td colspan="15" style="border: none;">
            <xsl:text disable-output-escaping="yes">&amp;</xsl:text>nbsp;
          </td>
        </tr>
      </xsl:when>
    </xsl:choose>

  </xsl:template>



  <!-- ********************************************************************************** -->
  <!--   MISCELLANEOUS                                                                    -->
  <!-- ********************************************************************************** -->
  <xsl:template name="SECTION_9_HD">
    <xsl:param name="CLASS"></xsl:param>
    <thead>
      <tr>
        <th>
          <xsl:attribute name="class">
            <xsl:value-of select="$CLASS"/>
          </xsl:attribute>
          <xsl:value-of select="../DIVISION"/>
        </th>
        <th>
          TEMP/INTR'M<br/>RET PERMIT
        </th>
        <th>
          SPEC DAILY<br/>TEMP BEER/WINE
        </th>
        <th>
          DAILY ON-SALE<br/>GENERAL
        </th>
        <th>
          CATERING<br/>AUTH
        </th>
      </tr>
    </thead>
  </xsl:template>


  <xsl:template match="SECTION_9">
    <p>
      <h3>
        <xsl:value-of select="@HEADING"/>
      </h3>
    </p>
    <table id="section-9" style="border-collapse: collapse;">
      <tbody>
        <!--   Section details called for each division group   -->
        <xsl:apply-templates select="OFFICE/DIVISION[generate-id() = generate-id(key('misc', .)[1])]">
          <xsl:sort select="../DIVISION"/>
        </xsl:apply-templates>

        <!--   Section totals   -->
        <tr>
          <td>STATEWIDE TOTALS</td>
          <td>
            <xsl:value-of select="sum(OFFICE/PERMIT)"/>
          </td>
          <td>
            <xsl:value-of select="sum(OFFICE/TEMPBERRWINE)"/>
          </td>
          <td>
            <xsl:value-of select="sum(OFFICE/GENERAL)"/>
          </td>
          <td>
            <xsl:value-of select="sum(OFFICE/CATERING)"/>
          </td>
        </tr>
      </tbody>
    </table>
  </xsl:template>

  <xsl:template match="SECTION_9/OFFICE/DIVISION">
    <xsl:variable name="currentGroup" select="."/>
    <xsl:for-each select="key('misc', $currentGroup)">
      <xsl:sort select="../OFFICENAME"/>
      <xsl:if test="position() = 1">
        <xsl:variable name="CLASS">
          <xsl:choose>
            <xsl:when test="substring(../DIVISION, 1, 1) = 'N'">
              <xsl:text>th-nd</xsl:text>
            </xsl:when>
            <xsl:when test="substring(../DIVISION, 1, 1) = 'S'">
              <xsl:text>th-sd</xsl:text>
            </xsl:when>
            <xsl:otherwise>
              <xsl:text>th-none</xsl:text>
            </xsl:otherwise>
          </xsl:choose>
        </xsl:variable>
        <xsl:call-template name="SECTION_9_HD">
          <xsl:with-param name="CLASS" select="$CLASS"></xsl:with-param>
        </xsl:call-template>
      </xsl:if>
      <xsl:if test="../PERMIT + ../TEMPBERRWINE + ../GENERAL + ../CATERING != 0">
      <tr>
        <td style="text-align: left; width: 2in;">
          <xsl:attribute name="class">
            <xsl:choose>
              <xsl:when test="substring(../DIVISION, 1, 1) = 'N'">
                <xsl:text>td-nd</xsl:text>
              </xsl:when>
              <xsl:when test="substring(../DIVISION, 1, 1) = 'S'">
                <xsl:text>td-sd</xsl:text>
              </xsl:when>
              <xsl:otherwise>
                <xsl:text>td-none</xsl:text>
              </xsl:otherwise>
            </xsl:choose>
          </xsl:attribute>
          <xsl:value-of select='../OFFICENAME'/>
        </td>
        <td>
          <xsl:value-of select='../PERMIT'/>
        </td>
        <td>
          <xsl:value-of select='../TEMPBERRWINE'/>
        </td>
        <td>
          <xsl:value-of select='../GENERAL'/>
        </td>
        <td>
          <xsl:value-of select='../CATERING'/>
        </td>
      </tr>
      </xsl:if>
    </xsl:for-each>

    <!--   Group totals   -->
    <tr>
      <td>
        <xsl:value-of select="$currentGroup"/> TOTALS
      </td>
      <td>
        <xsl:value-of select="sum(key('misc', .)/../PERMIT)"/>
      </td>
      <td>
        <xsl:value-of select="sum(key('misc', .)/../TEMPBERRWINE)"/>
      </td>
      <td>
        <xsl:value-of select="sum(key('misc', .)/../GENERAL)"/>
      </td>
      <td>
        <xsl:value-of select="sum(key('misc', .)/../CATERING)"/>
      </td>
    </tr>

    <!--  Add row space between groups  -->
    <tr>
      <td colspan="5" style="border: none;">
        <xsl:text disable-output-escaping="yes">&amp;</xsl:text>nbsp;
      </td>
    </tr>
  </xsl:template>
</xsl:stylesheet>
