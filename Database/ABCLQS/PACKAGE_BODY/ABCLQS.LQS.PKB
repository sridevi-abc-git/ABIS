CREATE OR REPLACE PACKAGE BODY ABCLQS.LQS AS
-- ****************************************************************************
-- File:        LQS.pkb          
-- Author:      Timothy J. Lord
--
-- $Rev: 419 $  
-- $Date: 2020-03-04 12:59:55 -0800 (Wed, 04 Mar 2020) $
-- Last Changed By:  $Author: NWong $
--
-- Description:    
--
-- 
-- History:
-------------------------------------------------------------------------------
--    Date                      Comment
-- 06/06/2017 TJL   11670   Initial package created
--            SS    11670   Call to reports added to MAIN 
-- 09/01/2017 TJL   11670   Header for version tracking
-- 08/28/2019 NW    18927   Added Finalized Legal Proceedings and Filed Legal Proceedings 
-- 09/25/2019 NW    18927   Added Montly Surrendered Licenses Report and Filed Legal Proceedings 
-- 09/25/2019 NW    18927   Added Licensed Importers 
-- 11/12/2019 NW            Added License Extracts Daily (formally known as weekly exports)
-- 11/20/2019 NW            Added Date List for Weekly Filed_Legal_Proceed reports
-- 12/10/2019 NW            Refactored LQS_REPORTS.LQS_DAILY_SEART to LQS_STREAMS.LQS_ADHOC
-- 02/25/2020 NW            Added PP_Legal_Entity_CSV to LQS_STREAMS.PKB 
-- 03/05/2020 NW            Added PP_Legal_Entity_XML to LQS_STREAMS.PKB
-- 02/22/2021 THL   24000   Added report type 29 to get covid relief fee information 
-- 12/23/2021 NW            Added report type 30 for Alcohol To Go project

-- *************************************************************************************************

------------------------  
FUNCTION clob2blob  -- Convert CLOB To BLOB
------------------------  
( p_clob IN CLOB) 
RETURN BLOB 

IS

  l_blob          BLOB            := NULL;
  ln_pos          PLS_INTEGER     := 1;
  buffer          RAW( 32767 );
  ln_lob_len      PLS_INTEGER;
  ln_len          NUMBER          := 32000;

BEGIN
  IF p_clob IS NOT NULL THEN
    ln_lob_len := DBMS_LOB.getlength( p_clob );
          
    DBMS_LOB.createtemporary( l_blob, TRUE );
    DBMS_LOB.open( l_blob, DBMS_LOB.lob_readwrite );

    LOOP
      buffer := UTL_RAW.cast_to_raw( DBMS_LOB.SUBSTR( p_clob, ln_len, ln_pos ) );

      IF UTL_RAW.LENGTH( buffer ) > 0 THEN
        DBMS_LOB.writeappend( l_blob, UTL_RAW.LENGTH( buffer ), buffer );
      END IF;

      ln_pos := ln_pos + ln_len;
      EXIT WHEN ln_pos > ln_lob_len;
    END LOOP;
  END IF;

  RETURN l_blob;
      
END clob2blob;
    
------------------------
PROCEDURE LISTS
------------------------
( p_parameter IN  NUMBER
, p_data      OUT SYS_REFCURSOR
, p_message   OUT VARCHAR )

IS
                    
BEGIN
  CASE p_parameter

  -- Cities
  WHEN 1 THEN
    OPEN p_data FOR
      SELECT c.cityname "DESCRIPTION", c.cityname "VALUE"
        FROM mart.cacity c
       ORDER BY c.cityname;

  -- License Types        
  WHEN 2 THEN
    OPEN p_data FOR
      SELECT ltc2.licensetypecode || '-' || ltc2.licensetypename "DESCRIPTION", ltc2.licensetypecode "VALUE"
        FROM (SELECT ltc.licensetypename licensetypename,
                     ltc.licensetypecode licensetypecode
                FROM mart.licensetypecategory ltc
           UNION ALL
              SELECT 'Temporary Retail Permit' licensetypename, '30' licensetypecode
                FROM DUAL) ltc2
       ORDER BY ltc2.licensetypecode;            
          
  -- Counties
  WHEN 3 THEN
    OPEN p_data FOR
      SELECT c.countyname "DESCRIPTION", c.countycode "VALUE"
        FROM mart.cacounty c
       WHERE c.active = 'Y'
       ORDER BY c.countyname;
                   
  -- Messages
  WHEN 4 THEN
    OPEN p_data FOR
      SELECT groupid "GROUP", TO_CHAR(startdate, 'MM/DD/YYYY') "DATE", TO_CHAR(seq) "SEQ", message "MESSAGE"
        FROM lqs_message
       WHERE TRUNC(SYSDATE) BETWEEN TRUNC(startdate) AND enddate
       ORDER By TRUNC(startdate), groupid, seq DESC;

  -- Messages 
  WHEN 5 THEN
    OPEN p_data FOR
      SELECT groupid "GROUP", TO_CHAR(startdate, 'MM/DD/YYYY') "DATE", TO_CHAR(seq) "SEQ", message "MESSAGE"
        FROM lqs_message
       WHERE TRUNC(SYSDATE) BETWEEN TRUNC(startdate) AND enddate
       ORDER By TRUNC(startdate), groupid, seq DESC;

  ELSE 
    p_message := 'Bad Parameter (' || p_parameter || ')';              

END CASE;   
           
EXCEPTION
 WHEN OTHERS THEN
    p_message := SQLERRM || ' --- ' || dbms_utility.format_error_backtrace || ' --- ';
END LISTS;                        

------------------------
PROCEDURE MAIN
------------------------
( p_parameters IN  XMLTYPE
, p_reportdata OUT BLOB
, p_message    OUT VARCHAR )

IS

	l_rpttype NUMBER;
	
BEGIN
	SELECT EXTRACTVALUE(p_parameters, '//RPTTYPE') INTO l_rpttype FROM DUAL;
	
	CASE

	-- Issued Licenses
	WHEN l_rpttype = 1 THEN  
		LQS_REPORTS.LQS_SEARCH_DAILY(p_parameters,p_reportdata,p_message);
		
	-- New Applications
	WHEN l_rpttype = 2 THEN  
		LQS_REPORTS.LQS_SEARCH_DAILY(p_parameters,p_reportdata,p_message);

	-- Status Changes
	WHEN l_rpttype = 3 THEN  
		LQS_REPORTS.LQS_SEARCH_DAILY(p_parameters,p_reportdata,p_message);

	-- Revocation Pending Report
	WHEN l_rpttype = 5 THEN  
		LQS_REPORTS.LQS_SEARCH_DAILY(p_parameters,p_reportdata,p_message);

	-- 6 is AdHoc License Type
	-- 7 is Active On-Sale Retail Licenses
	-- 8 is Active Off-Sale Retail Licenses
	-- 9 is Active Retail Licenses
	-- 10 is Active Non-Retail Licenses
	WHEN l_rpttype IN (6,7,8,9,10) THEN  
--    LQS_REPORTS.LQS_SEARCH_ADHOC(p_parameters,p_reportdata,p_message);
		LQS_STREAMS.LQS_ADHOC(p_parameters,p_reportdata,p_message);

	-- LQS License Detail
	WHEN l_rpttype IN (12) THEN 
		LQS_DETAIL.LQS_LICENSE(p_parameters,p_reportdata,p_message);

	-- Search By Business Address
	WHEN l_rpttype IN (13) THEN  
		LQS_REPORTS.LQS_BusAddr(p_parameters,p_reportdata,p_message);

	-- Search By Company/Licensee Name
	WHEN l_rpttype IN (14) THEN 
		LQS_REPORTS.LQS_LicenseeOrCompany(p_parameters,p_reportdata,p_message);

	-- Search By Business Name
	WHEN l_rpttype IN (15) THEN 
		LQS_REPORTS.LQS_dba(p_parameters,p_reportdata,p_message);
			
	-- Filed Legal Proceedings Report
	WHEN l_rpttype IN (16) THEN 
		LQS_LICENSING_REPORTS.FILED_LEGAL_PROCEED(p_parameters,p_reportdata,p_message);

	-- Finalized Legalized Proceedings Report
	WHEN l_rpttype IN (17) THEN 
		LQS_LICENSING_REPORTS.FINALIZED_LEGAL_PROCEED(p_parameters,p_reportdata,p_message);

	-- Surrendered Licenses (Monthly) Report
	WHEN l_rpttype IN (18) THEN 
		LQS_LICENSING_REPORTS.Surrendered_licenses(p_parameters,p_reportdata,p_message);

	-- Licensed Importers Report
	WHEN l_rpttype IN (19) THEN 
		LQS_LICENSING_REPORTS.Licensed_Importers(p_parameters,p_reportdata,p_message);

	-- WHOLESALE_BY_COUNTY Report
	WHEN l_rpttype IN (20) THEN 
		LQS_LICENSE_COUNTS.WHOLESALE_BY_COUNTY(p_parameters,p_reportdata,p_message);

	-- Statewide Counts Report
	WHEN l_rpttype IN (21) THEN 
		LQS_LICENSE_COUNTS.STATE_TOTALS(p_parameters,p_reportdata,p_message);

	-- CSV Export
	WHEN l_rpttype IN (24) THEN 
		LQS_STREAMS.LICENSES_CSV(p_parameters,p_reportdata,p_message);

	-- Fixed Width Export
	WHEN l_rpttype IN (25) THEN 
		LQS_STREAMS.LICENSES_Fixed_Width(p_parameters,p_reportdata,p_message);

	-- Weekly Date List for Leagal Proceedings Reports
	WHEN l_rpttype IN (26) THEN 
		LQS_LICENSING_REPORTS.Finalized_Legal_Date_List(p_parameters,p_reportdata,p_message);

  -- Price Posting Legal Entity CSV extract (PP_LEGAL_ENTITY_CSV)
	WHEN l_rpttype IN (27) THEN 
    PP_STREAMS.LEGAL_ENTITY_CSV (p_parameters,p_reportdata,p_message);

	WHEN l_rpttype IN (28) THEN 
    PP_STREAMS.LEGAL_ENTITY_XML (p_parameters,p_reportdata,p_message);

  WHEN l_rpttype IN (29) THEN
    abclqs.lqs_covid19.covid19(p_parameters,p_reportdata,p_message);

  WHEN l_rpttype IN (30) THEN
    ABCLQS.LQS_ALCOHOL_TO_GO.ALCOHOL_TO_GO(p_parameters,p_reportdata,p_message);
    
	ELSE p_message := 'Report not supported';
		
	END CASE;      
-------------
END MAIN;
-------------
 
END LQS;
/
