CREATE OR REPLACE PACKAGE BODY ABCLQS.LQS_REPORTS AS
-- ****************************************************************************
-- File:        LQS_REPORTS.pkb  
-- Author:      Sheik Sulthan    
--
-- $Rev: 388 $  
-- $Date: 2019-12-13 10:34:02 -0800 (Fri, 13 Dec 2019) $
-- Last Changed By:  $Author: NWong $
--
-- Description:    
--	To tackle the LQS security vulnerability – code for fetching the right 
--  record for the various LQS search criteria is handled by backend.  
--	
--	Date Created.....6/1/2017
--	Main procedure...LQS_SEARCH
--	
--	Category		rpttype	Reports
--	--------		---------	-------
--	Daily Reports	1			Issued Licenses
--					      2			New Applications
--					      3			Status Changes
--			
--  Prior Daily Reports
--			
--					      5			Revocation Pending Report
--			
--	Ad-Hoc			  6			AdHoc by License Type
--					      7			AdHoc for Active On-Sale Retail licenses 
--					      8 		AdHoc for Off Sale retail licenses
--					      9			AdHoc for Active Retail Licenses 
--					      10		AdHoc for Non-Retail licenses
--					
--			
--	LQS				    12		License Number
--					      13		Business Address
--					      14 		License / Company NAME
--					      15 		Business Name
-- 
-- History:
-------------------------------------------------------------------------------
--    Date                      Comment
-- 09/01/2017 TJL   11670   Header for version tracking 
-- 04/03/2018 TJL   14855   Added columns to support text sorting of date columns
--                          in web pages.
-- 05/30/2018 SSu   15443   Added Distinct function to avoid too many rows error
-- 08/06/2018 TJL   15926   Removed mailing address from all queries
-- 10/11/2018 NW    15920   Duplicate row in Ad-hoc Address Query for 'SUNSET GAS'
-- 12/12/2019 NW            Searches containing '&' return entire data set  
-- 10/08/2020 NW            Reformatting Indentations
-- 10/09/2020 NW            Add Mailing Addresses
-- 04/27/2022 NW    28140   Split up Premises and Mailing address fields  
-- ****************************************************************************

-- Declare global variable to hold transaction status 
g_message  VARCHAR2(32000);

---------------------------------	
PROCEDURE LQS_SEARCH_DAILY (
---------------------------------	
  p_parameters IN  XMLTYPE,
  p_reportdata OUT BLOB,
  p_message    OUT VARCHAR
)
IS
BEGIN    
  DECLARE
  CURSOR cur_parameters(p_data IN XMLTYPE) IS
  SELECT 
    rpttype,
    report_date
  FROM XMLTable(
    '/*/REQUEST' PASSING p_data COLUMNS
    rpttype      NUMBER(2)     PATH 'RPTTYPE',
    report_date    VARCHAR2(10)  PATH 'RPTDATE'
  );                              

  rec_parameters  cur_parameters%ROWTYPE;
  cur_recs        SYS_REFCURSOR;
  lxml_pi         XMLTYPE;
  retval          XMLTYPE := xmltype('<ROOT></ROOT>');
  ctx             dbms_xmlgen.ctxHandle;

  p_rpttype       VARCHAR2(10);
  p_report_date   VARCHAR2(10);  		

  BEGIN
    DBMS_OUTPUT.PUT_LINE('Starting procedure LQS_SEARCH....');
    OPEN cur_parameters(p_parameters);
    FETCH cur_parameters INTO rec_parameters;
    CLOSE cur_parameters;

    p_rpttype 	:= rec_parameters.rpttype; 
    p_report_date 	:= rec_parameters.report_date;	

    BEGIN
    -- Report type 1 is for Daily - issued licenses (SubDlyIssRep.asp)
    IF p_rpttype in ( 1 )THEN
      DBMS_OUTPUT.PUT_LINE('p_rpttype.... '|| p_rpttype);
      DBMS_OUTPUT.PUT_LINE('p_rpttype.... '|| p_report_date);
      IF p_report_date IS NOT NULL THEN 

-- Report type 1 is for Daily - issued licenses (SubDlyIssRep.asp)
        OPEN cur_recs FOR 
        SELECT 
          lpad(lt.LicenseNumber,6) license_num, --lt.LicenseNumber license_num, 
          ltc.LicenseTypeCode license_type_code, 
          lt.StatusDescription type_status_code, 
          lt.LicenseGeoCode geo_code, 
          to_char(lt.IssueDate , 'MM/DD/YYYY') orig_iss_date,   
          to_char(lt.ExpirationDate , 'MM/DD/YYYY') expir_date,      
          lt.PrimaryLicensee primary_owner, 
          lt.IssueType issue_type, 
          REGEXP_REPLACE (lt.PremAddress1stOf2Lines, '[[:cntrl:]]', '')  prem_addr,  -- lt.PremAddress1stOf2Lines prem_addr, 
          REGEXP_REPLACE (lt.PremAddress2ndOf2Lines, '[[:cntrl:]]', '')  prem_csz,   -- lt.PremAddress2ndOf2Lines prem_csz, 
          lt.PremAddressCountyCode county, 
          lt.PremisesCity city, 
          lt.PremAddressZipCode zip, 
          REGEXP_REPLACE (lt.PRIMARYDBA, '[[:cntrl:]]', '') dba, -- lt.PrimaryDBA dba, 
          lt.LicenseJobId license_eid, 
          lt.TransferredTo transfer_to, 
          lt.TransferredFrom transfer_from, 
          lt.SecondaryLicenseTypeCount dup_count, 
          lt.District district_code, 
          lt.ConditionList conditions, 
          lt.EscrowCompanyName || ' ' || lt.EscrowAddress escrow,    
          -- 10/9/2020 NW Add Mail Address
          REGEXP_REPLACE (lt.MailAddress1stOf2Lines, '[[:cntrl:]]', '')  mail_addr,  -- lt.PremAddress1stOf2Lines prem_addr, 
          REGEXP_REPLACE (lt.MailAddress2ndOf2Lines, '[[:cntrl:]]', '')  mail_csz,   -- lt.PremAddress2ndOf2Lines prem_csz 

          MAIL.USACITY MAIL_CITY,                 -- 04/27/2022 NW Split Mailing fields    
          MAIL.USASTATECODE MAIL_STATE,
          MAIL.ZIPCODE MAIL_ZIP,
          'CA' premAddressState -- (We only license in California!)

        FROM mart.licensetype lt 
        JOIN mart.primaryandsecondarylicencetype r on lt.ObjectId = r.LICENSETYPEOBJECTID 
        JOIN mart.licensetypecategory ltc on r.LICENSECETYPECATEGORYOBJECTID = ltc.ObjectId 
        LEFT JOIN MART.BUSINESSMAILINGLOCATIONS M ON M.JOBOBJECTID=LT.LICENSEJOBID  -- 4/27/2022 add separate mailing address fields 
        LEFT JOIN MART.ADDRESS MAIL ON MAIL.OBJECTID = M.ADDRESSOBJECTID
        
        WHERE TO_CHAR(lt.IssueDate,'mm/dd/yyyy') = p_report_date 

        UNION ALL  	  

        SELECT 
          lpad(LicenseNumber,6) license_num, --lt.LicenseNumber license_num,  
          '30' license_type_code,  

          CASE  
          WHEN (trunc(TP.EFFECTIVETO))-(trunc(SYSDATE))-abs((trunc(TP.EFFECTIVETO))-(trunc(SYSDATE)))=0 THEN 'Issued-Temp.'
          ELSE 'Expired'
          END type_status_code,
          
          lt.LicenseGeoCode geo_code,  
          to_char(TP.EFFECTIVEFROM , 'MM/DD/YYYY') orig_iss_date,   
          to_char(TP.EFFECTIVETO , 'MM/DD/YYYY') expir_date,   
          lt.PrimaryLicensee primary_owner,  
          lt.IssueType issue_type,  
          REGEXP_REPLACE (lt.PremAddress1stOf2Lines, '[[:cntrl:]]', '')  prem_addr, -- lt.PremAddress1stOf2Lines prem_addr,  
          REGEXP_REPLACE (lt.PremAddress2ndOf2Lines, '[[:cntrl:]]', '')  prem_csz,  --lt.PremAddress2ndOf2Lines prem_csz,  
          lt.PremAddressCountyCode county,  
          lt.PremisesCity city,  
          lt.PremAddressZipCode zip,  
          REGEXP_REPLACE (lt.PRIMARYDBA, '[[:cntrl:]]', '') dba, -- lt.PrimaryDBA dba, 
          lt.LicenseJobId license_eid,  
          lt.TransferredTo transfer_to,  
          lt.TransferredFrom transfer_from,  
          null dup_count,  
          lt.District district_code,  
          lt.ConditionList conditions,  
          lt.EscrowCompanyName || ' ' || lt.EscrowAddress escrow,

          -- 10/9/2020 NW Add Mail Address
          REGEXP_REPLACE (lt.MailAddress1stOf2Lines, '[[:cntrl:]]', '')  mail_addr,  -- lt.PremAddress1stOf2Lines prem_addr, 
          REGEXP_REPLACE (lt.MailAddress2ndOf2Lines, '[[:cntrl:]]', '')  mail_csz,   -- lt.PremAddress2ndOf2Lines prem_csz, 

          MAIL.USACITY MAIL_CITY,                 -- 04/27/2022 NW Split Mailing fields    
          MAIL.USASTATECODE MAIL_STATE,
          MAIL.ZIPCODE MAIL_ZIP,
          'CA' premAddressState -- (We only license in California!)
          
        FROM mart.licensetype lt   
        JOIN MART.TEMPORARYPERMIT tp on TP.jobid = lt.licensejobid   

        LEFT JOIN MART.BUSINESSMAILINGLOCATIONS M ON M.JOBOBJECTID=LT.LICENSEJOBID  -- 4/27/2022 add separate mailing address fields 
        LEFT JOIN MART.ADDRESS MAIL ON MAIL.OBJECTID = M.ADDRESSOBJECTID
        
        WHERE TO_CHAR(TP.EFFECTIVEFROM,'mm/dd/yyyy') = p_report_date
         
        UNION ALL
             
        SELECT 
          lpad(LicenseNumber,6) license_num, --A.LICENSENUMBER license_num, 
          '30' license_type_code, 

          CASE
          WHEN (trunc(TP.EFFECTIVETO))-(trunc(SYSDATE))-abs((trunc(TP.EFFECTIVETO))-(trunc(SYSDATE))) = 0 THEN 'Issued-Temp.'
          ELSE 'Expired'
          END type_status_code, 

          A.APPLICATIONGEOCODE geo_code, 
          to_char(TP.EFFECTIVEFROM , 'MM/DD/YYYY') orig_iss_date,   
          to_char(TP.EFFECTIVETO , 'MM/DD/YYYY') expir_date,   
          A.PrimaryLicensee primary_owner,   
          A.IssueType issue_type, 
          
          REGEXP_REPLACE (A.PREMADDRESSLINE1, '[[:cntrl:]]', '') prem_addr, 
          REGEXP_REPLACE (A.PREMADDRESSLINE2, '[[:cntrl:]]', '') prem_csz,  

          A.PREMADDRESSCOUNTYCODE county, 
          A.PREMADDRESSCITY city, 
          A.PREMADDRESSZIPCODE zip, 
          REGEXP_REPLACE (A.PRIMARYDBA, '[[:cntrl:]]', '') dba, --A.PRIMARYDBA dba, 
          A.APPLICATIONOBJECTID license_eid, 
          null transfer_to, 
          A.TRANSFERFROMLTFILENUM transfer_from, 
          null dup_count, 
          A.BASEFILEOFFICECODE district_code, 
          a.ConditionList conditions, 
          a.EscrowCompanyName || ' ' || a.EscrowAddress escrow,
          
          REGEXP_REPLACE (A.MailingAddressLine1, '[[:cntrl:]]', '') mail_addr,                -- 10/9/2020 NW Add Mail Address 
          REGEXP_REPLACE (A.MailingAddressLine2, '[[:cntrl:]]', '') mail_csz,

          MAIL.USACITY MAIL_CITY,                 -- 04/27/2022 NW Split Mailing fields    
          MAIL.USASTATECODE MAIL_STATE,
          MAIL.ZIPCODE MAIL_ZIP,
          'CA' premAddressState -- (We only license in California!)

        FROM Mart.Applictype a  
        JOIN MART.TEMPORARYPERMIT tp on TP.jobid = A.APPLICATIONOBJECTID 

        LEFT JOIN MART.BUSINESSMAILINGLOCATIONS M ON M.JOBOBJECTID=a.APPLICATIONOBJECTID  -- 4/27/2022 add separate mailing address fields 
        LEFT JOIN MART.ADDRESS MAIL ON MAIL.OBJECTID = M.ADDRESSOBJECTID
        
        WHERE a.LicenseExists = 'N'  
          AND TO_CHAR(TP.EFFECTIVEFROM,'mm/dd/yyyy') = p_report_date ; 

      ELSE 
        g_message := 'Needs run date(p_report_date) for new Applications report'; 
      END IF;

    -- Report type 2 is for Daily -New Applications (SubDlyNuRep.asp)
    ELSIF p_rpttype = 2 THEN
      IF p_report_date IS NOT NULL THEN 

        OPEN cur_recs FOR 
        SELECT 
          lpad(a.LicenseNumber,6) license_num, --a.LicenseNumber license_num,
          ltc.LicenseTypeCode license_type_code, 
          a.ApplicationStatus type_status_code, 
          a.ApplicationGeoCode geo_code, 
          to_char(a.TransferredFromIssueDate,'MM/DD/YYYY') orig_iss_date, 
          to_char(a.TransferredFromExpirationDate,'MM/DD/YYYY') expir_date, 
          a.PrimaryLicensee primary_owner, 
          a.IssueType issue_type, 
          a.PremAddressLine1 prem_addr, 
          a.PremAddressLine2 prem_csz, 
          a.PremAddressCountyCode county, 
          a.PremAddressCity city, 
          a.PremAddressZipCode zip, 
          REGEXP_REPLACE (a.PRIMARYDBA, '[[:cntrl:]]', '') dba, -- a.PrimaryDBA dba, 
          a.ApplicationObjectId license_eid, 
          lpad(to_char(a.LicenseNumber),6,chr(32)) transfer_to, --a.LicenseNumber transfer_to, 
          a.TransferFrom transfer_from, 
          a.SecondaryCount dup_count, 
          a.BaseFileOfficeCode district_code, 
          a.ConditionList conditions, 
          a.EscrowCompanyName || ' ' || a.EscrowAddress escrow, 
          
          REGEXP_REPLACE (A.MailingAddressLine1, '[[:cntrl:]]', '') mail_addr,                -- 10/9/2020 NW Add Mail Address 
          REGEXP_REPLACE (A.MailingAddressLine2, '[[:cntrl:]]', '') mail_csz,

          MAIL.USACITY MAIL_CITY,                 -- 04/27/2022 NW Split Mailing fields    
          MAIL.USASTATECODE MAIL_STATE,
          MAIL.ZIPCODE MAIL_ZIP,
          'CA' premAddressState -- (We only license in California!)
          
        FROM MART.Applictype a 
        JOIN MART.PrimaryAndSecondaryAppLicType PSLT ON a.ObjectId = PSLT.PRIMLICTYPEOBJECTID 
        JOIN MART.licensetypecategory ltc ON PSLT.LICCATEGORYOBJECTID = ltc.ObjectId 

        LEFT JOIN MART.BUSINESSMAILINGLOCATIONS M ON M.JOBOBJECTID=a.APPLICATIONOBJECTID  -- 4/27/2022 add separate mailing address fields 
        LEFT JOIN MART.ADDRESS MAIL ON MAIL.OBJECTID = M.ADDRESSOBJECTID
        
        WHERE a.LicenseExists = 'N' 
          AND a.APPLICATIONSTATUS = 'PEND'
          AND TO_CHAR(a.STATUSDATECORRAL,'mm/dd/yyyy') = p_report_date ;

              ELSE
                g_message := 'Needs run date(p_report_date) for new Applications report';
              END IF;

-- Report type 3 is for Daily - Status Changes (SubDlyStatRep.asp)
    ELSIF p_rpttype = 3 THEN		
      IF 	p_report_date IS NOT NULL  THEN

        OPEN cur_recs FOR 
        SELECT 
          'LIC' App_or_Lic,
          lpad(lt.LicenseNumber,6) license_num, --lt.LicenseNumber license_num, 
          ltc.LicenseTypeCode license_type_code, 
          lt.StatusName type_status_code, 
          lt.LicenseGeoCode geo_code, 
          to_char(lt.IssueDate,'MM/DD/YYYY') orig_iss_date, 
          to_char(lt.ExpirationDate,'MM/DD/YYYY') expir_date, 
          lt.PrimaryLicensee primary_owner, 
          lt.IssueType issue_type, 
          REGEXP_REPLACE (lt.PremAddress1stOf2Lines, '[[:cntrl:]]', '')  prem_addr, --lt.PremAddress1stOf2Lines prem_addr, 
          REGEXP_REPLACE (lt.PremAddress2ndOf2Lines, '[[:cntrl:]]', '')  prem_csz, --lt.PremAddress2ndOf2Lines prem_csz, 
          lt.PremAddressCountyCode county, 
          lt.PremisesCity city, 
          lt.PremAddressZipCode zip, 
          REGEXP_REPLACE (lt.PRIMARYDBA, '[[:cntrl:]]', '') dba,  --lt.PrimaryDBA dba, 
          lt.FromStatus from_status, 
          lt.TransferredTo transfer_to, 
          lt.TransferredFrom transfer_from, 
          lt.SecondaryLicenseTypeCount dup_count, 
          lt.BaseFileOfficeCode district_code, 
          lt.ConditionList Conditions, 
          lt.EscrowCompanyName || ' ' || lt.EscrowAddress Escrow, 
          lt.LicenseJobId license_eid,
          -- 10/09/2020 NW Add Mailing Address
          REGEXP_REPLACE (LT.MailAddress1stOf2Lines, '[[:cntrl:]]', '')  mail_addr, --lt.PremAddress1stOf2Lines prem_addr, 
          REGEXP_REPLACE (LT.MailAddress2ndOf2Lines, '[[:cntrl:]]', '')  mail_csz,  --lt.PremAddress2ndOf2Lines prem_csz,
          
          MAIL.USACITY MAIL_CITY,                 -- 04/27/2022 NW Split Mailing fields    
          MAIL.USASTATECODE MAIL_STATE,
          MAIL.ZIPCODE MAIL_ZIP,
          'CA' premAddressState -- (We only license in California!)

        FROM mart.licensetype lt 
        JOIN mart.primaryandsecondarylicencetype r ON lt.ObjectId = r.LICENSETYPEOBJECTID 
        JOIN mart.licensetypecategory ltc ON r.LICENSECETYPECATEGORYOBJECTID = ltc.ObjectId 
        JOIN extension.jobstatuschange s ON s.jobid = lt.ObjectId 

        LEFT JOIN MART.BUSINESSMAILINGLOCATIONS M ON M.JOBOBJECTID=LT.LICENSEJOBID  -- 4/27/2022 add separate mailing address fields 
        LEFT JOIN MART.ADDRESS MAIL ON MAIL.OBJECTID = M.ADDRESSOBJECTID

        
        WHERE to_char(s.statusdate,'mm/dd/yyyy') = p_report_date 
        AND lt.StatusName <> lt.FromStatus  

        UNION ALL 

        SELECT  
          'APP' App_or_Lic, 
          lpad(LicenseNumber,6) license_num, --LicenseNumber license_num, 
          ltc.LicenseTypeCode license_type_code, 
          a.Status type_status_code, 
          a.ApplicationGeoCode geo_code, 
          null orig_iss_date, 
          null expir_date, 
          a.PrimaryLicensee primary_owner, 
          a.IssueType issue_type, 
          a.PREMADDRESSLINE1 prem_addr, 
          a.PREMADDRESSLINE2 prem_csz, 
          a.PremAddressCountyCode county, 
          a.PremAddressCity city, 
          a.PremAddressZipCode zip, 
          REGEXP_REPLACE (a.PRIMARYDBA, '[[:cntrl:]]', '') dba,   --a.PrimaryDBA dba, 
          a.FromStatus from_status, 
          null transfer_to, 
          a.TransferFrom transfer_from, 
          a.SecondaryCount dup_count, 
          a.BaseFileOfficeCode district_code, 
          a.ConditionList Conditions, 
          a.EscrowCompanyName || ' ' || a.EscrowAddress Escrow, 
          a.ApplicationObjectId as license_eid, 

          REGEXP_REPLACE (A.MailingAddressLine1, '[[:cntrl:]]', '') mail_addr,                -- 10/9/2020 NW Add Mail Address 
          REGEXP_REPLACE (A.MailingAddressLine2, '[[:cntrl:]]', '') mail_csz,
         
          MAIL.USACITY MAIL_CITY,                 -- 04/27/2022 NW Split Mailing fields    
          MAIL.USASTATECODE MAIL_STATE,
          MAIL.ZIPCODE MAIL_ZIP,
          'CA' premAddressState -- (We only license in California!)
          

        FROM Mart.Applictype a 
        JOIN mart.primaryandsecondaryapplictype pslt ON a.ObjectId = pslt.PRIMLICTYPEOBJECTID 
        JOIN mart.licensetypecategory ltc ON pslt.LICCATEGORYOBJECTID = ltc.ObjectId 
        JOIN extension.jobstatuschange s ON s.jobid = a.ObjectId  

        LEFT JOIN MART.BUSINESSMAILINGLOCATIONS M ON M.JOBOBJECTID=a.APPLICATIONOBJECTID  -- 4/27/2022 add separate mailing address fields 
        LEFT JOIN MART.ADDRESS MAIL ON MAIL.OBJECTID = M.ADDRESSOBJECTID

        where to_char(s.statusdate,'MM/DD/YYYY') =  p_report_date 
        AND a.status not in ('ISSUED','VOIDED') 
        AND a.Status <> a.FromStatus   ;

      ELSE 
      g_message := 'Needs run date(p_report_date) for new Status Changes report';
      END IF;
-- Report type 5 is for Revocation Pending Report (SubMthRevRep.asp)
-- Monthly
    ELSIF p_rpttype = 5 THEN
      OPEN cur_recs FOR 
      SELECT 
        lpad(lt.LicenseNumber,6) license_num, 
        ltc.LicenseTypeCode license_type_code, 
        lt.StatusDescription type_status_code,   
        to_char(lt.IssueDate,'MM/DD/YYYY') orig_iss_date, 
        to_char(lt.ExpirationDate,'MM/DD/YYYY') expir_date,   
        lt.PrimaryLicensee primary_owner, 
        REGEXP_REPLACE (lt.PremAddress1stOf2Lines, '[[:cntrl:]]', '')  prem_addr, -- lt.PremAddress1stOf2Lines prem_addr, 
        REGEXP_REPLACE (lt.PremAddress2ndOf2Lines, '[[:cntrl:]]', '')  prem_csz, -- lt.PremAddress2ndOf2Lines prem_csz,  
        REGEXP_REPLACE (lt.PRIMARYDBA, '[[:cntrl:]]', '') dba,   --lt.PrimaryDBA dba, 
        lt.LicenseJobId license_eid, 
        lt.BaseFileOfficeCode district_code, 
        lt.LicenseGeoCode geo_code, 
        '$'||(case when lt.AmountDue <0 then 0 else lt.AmountDue end) as amt_due 
      FROM mart.licensetype lt 
      JOIN mart.primaryandsecondarylicencetype r on lt.ObjectId = r.LICENSETYPEOBJECTID 
      JOIN mart.licensetypecategory ltc on r.LICENSECETYPECATEGORYOBJECTID = ltc.ObjectId 
      WHERE lt.StatusName = 'REVPEN' ;

    END IF;

  END;

  ctx := dbms_xmlgen.newContext (cur_recs);

  dbms_xmlgen.setRowTag (ctx, 'RESULT');
  dbms_xmlgen.setRowSetTag (ctx, 'ROOT');
  dbms_xmlgen.setPrettyPrinting (ctx, false);

  retval := dbms_xmlgen.getXMLType (ctx);
  dbms_xmlgen.closeContext (ctx);

  IF p_rpttype in (1,2,3) THEN 
    SELECT XMLPI(NAME "xml-stylesheet", 'href="../Formats/Daily.xslt" type="text/xsl"') INTO lxml_pi FROM DUAL;
  ELSIF p_rpttype = 5 THEN 
    SELECT XMLPI(NAME "xml-stylesheet", 'href="../Formats/Pending.xslt" type="text/xsl"') INTO lxml_pi FROM DUAL;
  END IF;

  IF (retval IS NOT NULL) THEN 
    p_reportdata := clob2blob(lxml_pi.GETCLOBVAL() || retval.GETCLOBVAL());


  ELSE
    p_message := 'no data returned';
  END IF;
  DBMS_OUTPUT.PUT_LINE('Done LQS_SEARCH....');
  EXCEPTION
  WHEN NO_DATA_FOUND THEN
    NULL;
  WHEN OTHERS THEN
    p_message := SQLERRM || ' --- ' || dbms_utility.format_error_backtrace ;

  END;

END LQS_SEARCH_DAILY;


-----------------------------------------	
	PROCEDURE LQS_SEARCH_ADHOC
-----------------------------------------	
  ( p_parameters IN  XMLTYPE,
    p_reportdata OUT BLOB,
    p_message    OUT VARCHAR )

	IS
    BEGIN    
        DECLARE
             CURSOR      cur_parameters(p_data IN XMLTYPE) IS
                            SELECT rpttype,
                                   city, 
								   license_type,
								   county,
								   census_tract,
								   zipcode,
								   Statewide
                            FROM XMLTable('/*/REQUEST'
                                    PASSING p_data
                                    COLUMNS
                                     rpttype      	varchar2(10)     	PATH 'RPTTYPE',
                                     city           VARCHAR2(4000)  	PATH 'CITY',
									 license_type   varchar2(10) 	  	PATH 'LICENSETYPE',
									 county			VARCHAR2(4000)  	PATH 'COUNTY',
									 census_tract	varchar2(10)   		PATH 'CENSUS',
									 zipcode			varchar2(10)		PATH 'ZIPCODE',
									 statewide		varchar2(10) 		PATH 'STATEWIDE'
                                     );                              
                                 
            rec_parameters      cur_parameters%ROWTYPE;
			
            -- xml_temp        	XMLTYPE;
            cur_recs        	SYS_REFCURSOR;
            lxml_pi         	XMLTYPE;
            retval          	XMLTYPE := xmltype('<ROOT></ROOT>');
            ctx             	dbms_xmlgen.ctxHandle;
            
        BEGIN

			DBMS_OUTPUT.PUT_LINE('Starting procedure LQS_SEARCH_ADHOC for rpt types 6,7,8,9 or 10');

			OPEN cur_parameters(p_parameters);
			FETCH cur_parameters INTO rec_parameters;
			CLOSE cur_parameters;
				
			IF 	rec_parameters.city IS NOT NULL  THEN 
				DBMS_OUTPUT.PUT_LINE('Starting procedure LQS_SEARCH_CITY....');

				
				DBMS_OUTPUT.PUT_LINE('cities....'||rec_parameters.city);
				DBMS_OUTPUT.PUT_LINE('LicenseType....'||rec_parameters.license_type);
				-- DBMS_OUTPUT.PUT_LINE('LicenseTypeCode....'||rec_parameters.license_type_code);
				-- For City
				OPEN cur_recs FOR SELECT lpad(LicenseNumber,6) license_num, 
											LicenseTypeCode license_type_code, 
											StatusName type_status_code, 
											TO_CHAR(LicenseCreatedDate,'mm/dd/yyyy') orig_iss_date, 
											TO_CHAR(ExpirationDate,'mm/dd/yyyy') expir_date, 
											to_char(LicenseCreatedDate, 'YYYYMMDD') orig_iss_date_sort,   
											to_char(ExpirationDate, 'YYYYMMDD') expir_date_sort,      
											PrimaryLicensee primary_owner, 
											LicenseGeoCode geo_code,
											REGEXP_REPLACE (PremAddress1stOf2Lines, '[[:cntrl:]]', '')  prem_addr, --PremAddress1stOf2Lines prem_addr, 
											REGEXP_REPLACE (PremAddress2ndOf2Lines, '[[:cntrl:]]', '')  prem_csz, --PremAddress2ndOf2Lines prem_csz,
											PremAddressCountyCode county, 
											LicenseUSCity city, 
											to_char (LicenseCensusTract, '0000.00') census_tract, 
											LicenseZipCode zip,
											REGEXP_REPLACE (PRIMARYDBA, '[[:cntrl:]]', '') dba,  PrimaryDBA dba, 
											TransferredTo transfer_to, 
											TransferredFrom transfer_from, 
											LicenseJobId license_eid 
											FROM MART.LicenseType,
											( select regexp_substr(rec_parameters.city,'[^,]+', 1, level) city from dual
													connect by regexp_substr(rec_parameters.city, '[^,]+', 1, level) is not null) c
											WHERE StatusName IN ('ACTIVE', 'R64B','REVPEN', 'SLMSHD', 'SUREND', 'SUSPEN')  
											AND UPPER(LICENSEUSCITY) IN c.city  
											AND CASE WHEN rec_parameters.rpttype = 6 AND LicenseTypeCode = rec_parameters.license_type 
													 THEN 1
													 WHEN rec_parameters.rpttype = 7 AND  LicenseTypeCode > '39' and LicenseTypeCode != '85'
													 THEN 1
													 WHEN rec_parameters.rpttype = 8 AND  LicenseTypeCode IN ('20','21','85')
													 THEN 1
													 WHEN rec_parameters.rpttype = 9 AND ( (LicenseTypeCode>'39' and LicenseTypeCode != '85') or LicenseTypeCode IN ('20','21','85') )
													 THEN 1
													 WHEN rec_parameters.rpttype = 10 AND ( LicenseTypeCode <'39' and LicenseTypeCode not in ('20','21','85') )
													 THEN 1
													 ELSE 0
												END = 1;
			-- For County
			ELSIF rec_parameters.county IS NOT NULL  and rec_parameters.census_tract IS NULL THEN 
				DBMS_OUTPUT.PUT_LINE('County...');
				OPEN cur_recs FOR SELECT lpad(LicenseNumber,6) license_num,
											LicenseTypeCode license_type_code, 
											StatusName type_status_code, 
											TO_CHAR(LicenseCreatedDate,'mm/dd/yyyy') orig_iss_date, 
											TO_CHAR(ExpirationDate,'mm/dd/yyyy') expir_date, 
											to_char(LicenseCreatedDate, 'YYYYMMDD') orig_iss_date_sort,   
											to_char(ExpirationDate, 'YYYYMMDD') expir_date_sort,      
											PrimaryLicensee primary_owner, 
											LicenseGeoCode geo_code,
											REGEXP_REPLACE (PremAddress1stOf2Lines, '[[:cntrl:]]', '')  prem_addr, --PremAddress1stOf2Lines prem_addr, 
											REGEXP_REPLACE (PremAddress2ndOf2Lines, '[[:cntrl:]]', '')  prem_csz, -- PremAddress2ndOf2Lines prem_csz,
											PremAddressCountyCode county, 
											LicenseUSCity city, 
											to_char (LicenseCensusTract, '0000.00') census_tract, 
											LicenseZipCode zip,
											REGEXP_REPLACE (PRIMARYDBA, '[[:cntrl:]]', '') dba, -- PrimaryDBA dba, 
											TransferredTo transfer_to, 
											TransferredFrom transfer_from, 
											LicenseJobId license_eid 
											FROM MART.LicenseType,
												( select regexp_substr(rec_parameters.county,'[^,]+', 1, level) county from dual
														connect by regexp_substr(rec_parameters.county, '[^,]+', 1, level) is not null) c
											WHERE StatusName IN ('ACTIVE', 'R64B','REVPEN', 'SLMSHD', 'SUREND', 'SUSPEN')  
											AND UPPER(PremAddressCountyCode) IN c.county  
											AND CASE WHEN rec_parameters.rpttype = 6 AND LicenseTypeCode = rec_parameters.license_type 
													 THEN 1
													 WHEN rec_parameters.rpttype = 7 AND  LicenseTypeCode > '39' and LicenseTypeCode != '85'
													 THEN 1
													 WHEN rec_parameters.rpttype = 8 AND  LicenseTypeCode IN ('20','21','85')
													 THEN 1
													 WHEN rec_parameters.rpttype = 9 AND ( (LicenseTypeCode>'39' and LicenseTypeCode != '85') or LicenseTypeCode IN ('20','21','85') )
													 THEN 1
													 WHEN rec_parameters.rpttype = 10 AND ( LicenseTypeCode <'39' and LicenseTypeCode not in ('20','21','85') )
													 THEN 1
													 ELSE 0
												END = 1;

			-- For Counties and Census Tract
			ELSIF rec_parameters.county IS NOT NULL  and rec_parameters.Census_Tract IS NOT NULL THEN 
				OPEN cur_recs FOR SELECT lpad(LicenseNumber,6) license_num,
											LicenseTypeCode license_type_code, 
											StatusName type_status_code, 
											TO_CHAR(LicenseCreatedDate,'mm/dd/yyyy') orig_iss_date, 
											TO_CHAR(ExpirationDate,'mm/dd/yyyy') expir_date, 
											to_char(LicenseCreatedDate, 'YYYYMMDD') orig_iss_date_sort,   
											to_char(ExpirationDate, 'YYYYMMDD') expir_date_sort,      
											PrimaryLicensee primary_owner, 
											LicenseGeoCode geo_code,
											REGEXP_REPLACE (PremAddress1stOf2Lines, '[[:cntrl:]]', '')  prem_addr, --PremAddress1stOf2Lines prem_addr, 
											REGEXP_REPLACE (PremAddress2ndOf2Lines, '[[:cntrl:]]', '')  prem_csz, -- PremAddress2ndOf2Lines prem_csz,
											PremAddressCountyCode county, 
											LicenseUSCity city, 
											to_char (LicenseCensusTract, '0000.00') census_tract, 
											LicenseZipCode zip,
											REGEXP_REPLACE (PRIMARYDBA, '[[:cntrl:]]', '') dba, --PrimaryDBA dba, 
											TransferredTo transfer_to, 
											TransferredFrom transfer_from, 
											LicenseJobId license_eid 
											FROM MART.LicenseType,
												( select regexp_substr(rec_parameters.county,'[^,]+', 1, level) county from dual
														connect by regexp_substr(rec_parameters.county, '[^,]+', 1, level) is not null) c
											WHERE StatusName IN ('ACTIVE', 'R64B','REVPEN', 'SLMSHD', 'SUREND', 'SUSPEN')  
											AND UPPER(PremAddressCountyCode) IN c.county  
											AND  TO_CHAR(LicenseCensusTract,'9999.99') = TO_CHAR(rec_parameters.census_Tract,'9999.99')
											AND CASE WHEN rec_parameters.rpttype = 6 AND LicenseTypeCode = rec_parameters.license_type 
													 THEN 1
													 WHEN rec_parameters.rpttype = 7 AND  LicenseTypeCode > '39' and LicenseTypeCode != '85'
													 THEN 1
													 WHEN rec_parameters.rpttype = 8 AND  LicenseTypeCode IN ('20','21','85')
													 THEN 1
													 WHEN rec_parameters.rpttype = 9 AND ( (LicenseTypeCode>'39' and LicenseTypeCode != '85') or LicenseTypeCode IN ('20','21','85') )
													 THEN 1
													 WHEN rec_parameters.rpttype = 10 AND ( LicenseTypeCode <'39' and LicenseTypeCode not in ('20','21','85') )
													 THEN 1
													 ELSE 0
												END = 1;

			-- For Census tract						
			ELSIF rec_parameters.county IS NULL  and rec_parameters.Census_Tract IS NOT NULL THEN 
				-- 
				OPEN cur_recs FOR SELECT lpad(LicenseNumber,6) license_num,
											LicenseTypeCode license_type_code, 
											StatusName type_status_code, 
											TO_CHAR(LicenseCreatedDate,'mm/dd/yyyy') orig_iss_date, 
											TO_CHAR(ExpirationDate,'mm/dd/yyyy') expir_date, 
											to_char(LicenseCreatedDate, 'YYYYMMDD') orig_iss_date_sort,   
											to_char(ExpirationDate, 'YYYYMMDD') expir_date_sort,      
											PrimaryLicensee primary_owner, 
											LicenseGeoCode geo_code,
											REGEXP_REPLACE (PremAddress1stOf2Lines, '[[:cntrl:]]', '')  prem_addr, --PremAddress1stOf2Lines prem_addr, 
											REGEXP_REPLACE (PremAddress2ndOf2Lines, '[[:cntrl:]]', '')  prem_csz, -- PremAddress2ndOf2Lines prem_csz,
											PremAddressCountyCode county, 
											LicenseUSCity city, 
											to_char (LicenseCensusTract, '0000.00') census_tract, 
											LicenseZipCode zip,
											REGEXP_REPLACE (PRIMARYDBA, '[[:cntrl:]]', '') dba, --PrimaryDBA dba, 
											TransferredTo transfer_to, 
											TransferredFrom transfer_from, 
											LicenseJobId license_eid 
											FROM MART.LicenseType
											WHERE StatusName IN ('ACTIVE', 'R64B','REVPEN', 'SLMSHD', 'SUREND', 'SUSPEN')  
											AND  TO_CHAR(LicenseCensusTract,'9999.99') = TO_CHAR(rec_parameters.census_Tract,'9999.99')
											AND CASE WHEN rec_parameters.rpttype = 6 AND LicenseTypeCode = rec_parameters.license_type 
													 THEN 1
													 WHEN rec_parameters.rpttype = 7 AND  LicenseTypeCode > '39' and LicenseTypeCode != '85'
													 THEN 1
													 WHEN rec_parameters.rpttype = 8 AND  LicenseTypeCode IN ('20','21','85')
													 THEN 1
													 WHEN rec_parameters.rpttype = 9 AND ( (LicenseTypeCode>'39' and LicenseTypeCode != '85') or LicenseTypeCode IN ('20','21','85') )
													 THEN 1
													 WHEN rec_parameters.rpttype = 10 AND ( LicenseTypeCode <'39' and LicenseTypeCode not in ('20','21','85') )
													 THEN 1
													 ELSE 0
												END = 1;
			
			-- Zip code
			ELSIF rec_parameters.zipcode IS NOT NULL THEN 
				OPEN cur_recs FOR SELECT lpad(LicenseNumber,6) license_num,
											LicenseTypeCode license_type_code, 
											StatusName type_status_code, 
											TO_CHAR(LicenseCreatedDate,'mm/dd/yyyy') orig_iss_date, 
											TO_CHAR(ExpirationDate,'mm/dd/yyyy') expir_date, 
											to_char(LicenseCreatedDate, 'YYYYMMDD') orig_iss_date_sort,   
											to_char(ExpirationDate, 'YYYYMMDD') expir_date_sort,      
											PrimaryLicensee primary_owner, 
											LicenseGeoCode geo_code,
											REGEXP_REPLACE (PremAddress1stOf2Lines, '[[:cntrl:]]', '')  prem_addr, -- PremAddress1stOf2Lines prem_addr, 
											REGEXP_REPLACE (PremAddress2ndOf2Lines, '[[:cntrl:]]', '')  prem_csz, -- PremAddress2ndOf2Lines prem_csz,
											PremAddressCountyCode county, 
											LicenseUSCity city, 
											to_char (LicenseCensusTract, '0000.00') census_tract, 
											LicenseZipCode zipcode,
											REGEXP_REPLACE (PRIMARYDBA, '[[:cntrl:]]', '') dba, --PrimaryDBA dba, 
											TransferredTo transfer_to, 
											TransferredFrom transfer_from, 
											LicenseJobId license_eid 
											FROM MART.LicenseType
											WHERE StatusName IN ('ACTIVE', 'R64B','REVPEN', 'SLMSHD', 'SUREND', 'SUSPEN')  
											AND  LicenseZipCode = rec_parameters.zipcode
											AND CASE WHEN rec_parameters.rpttype = 6 AND LicenseTypeCode = rec_parameters.license_type 
													 THEN 1
													 WHEN rec_parameters.rpttype = 7 AND  LicenseTypeCode > '39' and LicenseTypeCode != '85'
													 THEN 1
													 WHEN rec_parameters.rpttype = 8 AND  LicenseTypeCode IN ('20','21','85')
													 THEN 1
													 WHEN rec_parameters.rpttype = 9 AND ( (LicenseTypeCode>'39' and LicenseTypeCode != '85') or LicenseTypeCode IN ('20','21','85') )
													 THEN 1
													 WHEN rec_parameters.rpttype = 10 AND ( LicenseTypeCode <'39' and LicenseTypeCode not in ('20','21','85') )
													 THEN 1
													 ELSE 0
												END = 1;

			-- Statewide 
			ELSE --IF rec_parameters.Statewide IS NOT NULL THEN 
				OPEN cur_recs FOR SELECT lpad(LicenseNumber,6) license_num, 
											LicenseTypeCode license_type_code, 
											StatusName type_status_code, 
											TO_CHAR(LicenseCreatedDate,'mm/dd/yyyy') orig_iss_date, 
											TO_CHAR(ExpirationDate,'mm/dd/yyyy') expir_date, 
											to_char(LicenseCreatedDate, 'YYYYMMDD') orig_iss_date_sort,   
											to_char(ExpirationDate, 'YYYYMMDD') expir_date_sort,      
											PrimaryLicensee primary_owner, 
											LicenseGeoCode geo_code,
											REGEXP_REPLACE (PremAddress1stOf2Lines, '[[:cntrl:]]', '')  prem_addr, -- PremAddress1stOf2Lines prem_addr, 
											REGEXP_REPLACE (PremAddress2ndOf2Lines, '[[:cntrl:]]', '')  prem_csz, -- PremAddress2ndOf2Lines prem_csz,
											PremAddressCountyCode county, 
											LicenseUSCity city, 
											to_char (LicenseCensusTract, '0000.00') census_tract, 
											LicenseZipCode zip,
											REGEXP_REPLACE (PRIMARYDBA, '[[:cntrl:]]', '') dba,  --PrimaryDBA dba, 
											TransferredTo transfer_to, 
											TransferredFrom transfer_from, 
											LicenseJobId license_eid 
											FROM MART.LicenseType
											WHERE StatusName IN ('ACTIVE', 'R64B','REVPEN', 'SLMSHD', 'SUREND', 'SUSPEN')  
											AND CASE WHEN rec_parameters.rpttype = 6 AND LicenseTypeCode = rec_parameters.license_type 
													 THEN 1
													 WHEN rec_parameters.rpttype = 7 AND  LicenseTypeCode > '39' and LicenseTypeCode != '85'
													 THEN 1
													 WHEN rec_parameters.rpttype = 8 AND  LicenseTypeCode IN ('20','21','85')
													 THEN 1
													 WHEN rec_parameters.rpttype = 9 AND ( (LicenseTypeCode>'39' and LicenseTypeCode != '85') or LicenseTypeCode IN ('20','21','85') )
													 THEN 1
													 WHEN rec_parameters.rpttype = 10 AND ( LicenseTypeCode <'39' and LicenseTypeCode not in ('20','21','85') )
													 THEN 1
													 ELSE 0
												END = 1;
			--ELSE
			
				--g_message := 'Missing selection - You need to a city/county/census track/zip code ';
			END IF;


			  
			ctx := dbms_xmlgen.newContext (cur_recs);
				   
			dbms_xmlgen.setRowTag (ctx, 'RESULT');
			dbms_xmlgen.setRowSetTag (ctx, 'ROOT');
			dbms_xmlgen.setPrettyPrinting (ctx, false);
				   
			retval := dbms_xmlgen.getXMLType (ctx);
			dbms_xmlgen.closeContext (ctx);

			SELECT XMLPI(NAME "xml-stylesheet", 'href="../Formats/Adhoc.xslt" type="text/xsl"') INTO lxml_pi FROM DUAL;

			IF (retval IS NOT NULL) THEN 
				p_reportdata := clob2blob(lxml_pi.GETCLOBVAL() || retval.GETCLOBVAL());
			ELSE
				p_message := 'no data returned';
			end if;
			DBMS_OUTPUT.PUT_LINE('Done LQS_SEARCH....');

		END;
			
		EXCEPTION
			 WHEN NO_DATA_FOUND THEN
			   NULL;
			 WHEN OTHERS THEN
				p_message := SQLERRM || ' --- ' || dbms_utility.format_error_backtrace ;

    END LQS_SEARCH_ADHOC;
	
	-- LQS RptType 12, 13, 14, 15
	-- 12 – License Number
	-- 13 – Business Address
	-- 14 – Licensee / Company Name 
	-- 15 – Business Name

  -------------------------------------
	PROCEDURE LQS_BusAddr
  -------------------------------------
  ( p_parameters IN  XMLTYPE,
    p_reportdata OUT BLOB,
    p_message    OUT VARCHAR)
	IS
    BEGIN    
        DECLARE
             CURSOR      cur_parameters(p_data IN XMLTYPE) IS
                            SELECT rpttype,
								   upper(address) address,
								   city
                            FROM XMLTable('/*/REQUEST'
                                    PASSING p_data
                                    COLUMNS
                                     rpttype      NUMBER(2)     PATH 'RPTTYPE',
                                     address    VARCHAR2(50)  	PATH 'ADDRESS',
									 city		varchar2(50)	PATH 'CITY' 
                                     );                              
                                 
            rec_parameters      cur_parameters%ROWTYPE;
            -- xml_temp        XMLTYPE;
            cur_recs        SYS_REFCURSOR;
            lxml_pi         XMLTYPE;
            retval          XMLTYPE := xmltype('<ROOT></ROOT>');
            ctx             dbms_xmlgen.ctxHandle;

            p_rpttype     VARCHAR2(10);
            p_report_date   varchar2(10);  		
			v_AddrCnt number := 0;
			v_addresses_eid mart.address.ObjectId%Type;
			v_LicAddrCnt number;

            v_license xmltype;
			
        BEGIN
			DBMS_OUTPUT.PUT_LINE('Starting procedure LQS_BusAddr...');
            OPEN cur_parameters(p_parameters);
            FETCH cur_parameters INTO rec_parameters;
            CLOSE cur_parameters;
			
		
			BEGIN
			
				IF rec_parameters.rpttype in ( 13 ) THEN 
					DBMS_OUTPUT.PUT_LINE('Business Address = '|| rec_parameters.address);
					DBMS_OUTPUT.PUT_LINE('City.... '|| rec_parameters.city);
					-- LQSBrkdwn.asp starts here...
					begin
						-- Need to check the record count
						SELECT count(1)  into v_AddrCnt 
						FROM mart.address a 
  						where a.AddressLine1 like '%'||rec_parameters.address||'%' --(Select mart.CleanUp_String(rec_parameters.address||'%','WILD') from dual) 
 						and a.CACity = rec_parameters.city
 						and a.LicenseOrApplicationAddress = 'Y' ;
					exception when no_data_found then 
						v_AddrCnt := 0;
					end;
					DBMS_OUTPUT.PUT_LINE('v_AddrCnt = '|| v_AddrCnt);
					if v_AddrCnt = 0 then 
						p_message := 'no data returned';
					elsif v_AddrCnt = 1 then 

					-- check if there is more than one license at the premises
						SELECT a.ObjectId into v_addresses_eid
						FROM mart.address a  
						where a.AddressLine1 like '%'||rec_parameters.address||'%' --(Select mart.CleanUp_String(rec_parameters.address||'%','WILD') from dual) 
						and a.CACity = rec_parameters.City
 						and a.LicenseOrApplicationAddress = 'Y' ;
						
						-- check if more than one licenses/applications on the same address
						Select count(1) into v_LicAddrCnt 
						From ( 
								Select A.OBJECTID 
								From Mart.license l
								Join mart.businesslocations bl on BL.JOBOBJECTID = L.JOBID 
								Join mart.address a on BL.ADDRESSOBJECTID = A.OBJECTID
								where a.ObjectId = v_addresses_eid
								UNION ALL 
								Select A.OBJECTID 
								From MART.APPLICATION ap 
								Join mart.businesslocations bl on BL.JOBOBJECTID = AP.OBJECTID 
								Join mart.address a on BL.ADDRESSOBJECTID = A.OBJECTID 
								where a.ObjectId = v_addresses_eid
								and ap.LicenseExists = 'N' 
								) xx  ;
						-- More than one record was found to match your Business Address criteria		
						if 	v_LicAddrCnt > 1 then 

							-- re-route to LQSPREMLIST.asp from LQSBrkdwn.asp for a list of similar choices
							OPEN cur_recs FOR select rownum, name, dba, prem_addr, prem_csz, license_num,Status_Code
											from (
											
												Select distinct  rownum a, ap.primarylicensee name, 
													REGEXP_REPLACE (ap.PRIMARYDBA, '[[:cntrl:]]', '') dba,  --ap.PRIMARYDBA dba, 
													ap.APPLICATIONOBJECTID licenses_eid, lpad(ap.LicenseNumber,6) license_num, MART.GetLTCodesAndStatus(ap.ApplicationObjectId) Status_Code, x.prem_addr,x.prem_csz 
												from MART.APPLICTYPE ap  , mart.businesslocations l,
												 (Select distinct a.AddressLine1 prem_addr, a.CACity||','||USASTATECODE||' '||zipcode prem_csz, a.ObjectId addresses_eid  
												  from mart.address a
												  where a.AddressLine1 like '%'||rec_parameters.address||'%' --'13%'
												  and a.CACity = rec_parameters.City   -- 'SACRAMENTO'
												  and a.ObjectId in (select l.ADDRESSOBJECTID from mart.businesslocations l)    
												  ) x
												where ap.LicenseExists = 'N' 
												and ap.ApplicationStatus in ('PEND', 'ISSUPD', 'DENIED', 'WTHDRN') 
												and ap.ApplicationObjectID= l.JOBOBJECTID   
												and  l.ADDRESSOBJECTID =   x.addresses_eid	
											   
												UNION 							
												Select distinct rownum a, lt.primarylicensee name, 
														REGEXP_REPLACE (lt.PRIMARYDBA, '[[:cntrl:]]', '') dba, --PrimaryDBA dba,  --lt.primarydba dba, 
														lt.LICENSEJOBID licenses_eid, lpad(lt.LicenseNumber,6) license_num, MART.GetLTCodesAndStatus(lt.LicenseJobId) Status_Code,  x.prem_addr,x.prem_csz 
												from mart.licensetype lt, mart.businesslocations l ,  
														(Select distinct  a.AddressLine1 prem_addr, a.CACity||','||USASTATECODE||' '||zipcode prem_csz, a.ObjectId addresses_eid 
																	  from mart.address a
																	  where a.AddressLine1 like '%'||rec_parameters.address||'%' --'13%'
																	  and a.CACity = rec_parameters.City   --'SACRAMENTO'
																	  and a.ObjectId in (select l.ADDRESSOBJECTID from mart.businesslocations l)    
																	 ) x
												where lt.LicenseJobId =  l.JOBOBJECTID
												and  l.ADDRESSOBJECTID =   x.addresses_eid	

											);
 
							
							ctx := dbms_xmlgen.newContext (cur_recs);

							dbms_xmlgen.setRowTag (ctx, 'RESULT');
							dbms_xmlgen.setRowSetTag (ctx, 'ROOT');
							dbms_xmlgen.setPrettyPrinting (ctx, false);

							retval := dbms_xmlgen.getXMLType (ctx);
							dbms_xmlgen.closeContext (ctx);

							SELECT XMLPI(NAME "xml-stylesheet", 'href="../Formats/LicenseList.xslt" type="text/xsl"') INTO lxml_pi FROM DUAL;

							IF (retval IS NOT NULL) THEN 
							p_reportdata := clob2blob(lxml_pi.GETCLOBVAL() || retval.GETCLOBVAL());
							ELSE
							p_message := 'no data returned';
							end if;

						else -- in page LQSBrkdwn.asp
							-- get the license number and re-route to LQSDATA.asp
							for AddrDet in (SELECT distinct lt.LICENSENUMBER license -- lt.LICENSEJOBID licenses_eid 
											FROM  mart.licensetype lt 
											where lt.PremAddress1stOf2Lines like '%'||rec_parameters.address||'%'
											  and lt.PremisesCity =  rec_parameters.City  
											  and lt.PremisesState = 'CALIFORNIA' 
									 		UNION 
											SELECT distinct ap.LICENSENUMBER license --distinct AP.APPLICATIONOBJECTID licenses_eid 
											FROM  mart.APPLICTYPE ap 
											where ap.PREMADDRESSLINE1 like '%'||rec_parameters.address||'%'
											and ap.PREMADDRESSCITY = rec_parameters.City  
											and ap.LicenseExists = 'N' )
							loop
								DBMS_OUTPUT.PUT_LINE('call ning license detail_record_counter');
								DBMS_OUTPUT.PUT_LINE(addrdet.license);

								SELECT
									XMLELEMENT("ROOT"
									, XMLELEMENT("LICENSE",addrdet.license)  
									)
								  INTO v_license
								  FROM DUAL;

								LQS_DETAIL.LQS_LICENSE( v_license,
											p_reportdata,
											p_message);
							End loop;
							
						end if;

					elsif v_AddrCnt > 1 then 	
					    -- re-route to LQSPREMLIST.asp for a list of similar choices
						-- re-route to LQSPREMLIST.asp from LQSBrkdwn.asp for a list of similar choices
						
						OPEN cur_recs FOR select rownum, name, dba, prem_addr, prem_csz, license_num,Status_Code
											from (
											Select distinct  rownum a, ap.primarylicensee name, 
														REGEXP_REPLACE (ap.PRIMARYDBA, '[[:cntrl:]]', '') dba, --ap.PRIMARYDBA dba, 
														ap.APPLICATIONOBJECTID licenses_eid, lpad(ap.LicenseNumber,6) license_num, MART.GetLTCodesAndStatus(ap.ApplicationObjectId) Status_Code, x.prem_addr,x.prem_csz   
												from MART.APPLICTYPE ap  , mart.businesslocations l,
												(Select distinct a.AddressLine1 prem_addr, a.CACity||','||USASTATECODE||' '||zipcode prem_csz, a.ObjectId addresses_eid 
												from mart.address a
												where a.AddressLine1 like '%'||rec_parameters.address||'%' --'13%'
												and a.CACity = rec_parameters.City   -- 'SACRAMENTO'
												and a.ObjectId in (select l.ADDRESSOBJECTID from mart.businesslocations l)    
												) x
												where ap.LicenseExists = 'N' 
												and ap.ApplicationStatus in ('PEND', 'ISSUPD', 'DENIED', 'WTHDRN') 
												and ap.ApplicationObjectID= l.JOBOBJECTID   
												and  l.ADDRESSOBJECTID =   x.addresses_eid	
											   
												UNION 							
												Select distinct rownum a, lt.primarylicensee name, 
																REGEXP_REPLACE (lt.PRIMARYDBA, '[[:cntrl:]]', '') dba, --lt.primarydba dba, 
																lt.LICENSEJOBID licenses_eid, lpad(lt.LicenseNumber,6) license_num, MART.GetLTCodesAndStatus(lt.LicenseJobId) Status_Code, x.prem_addr,x.prem_csz 
												from mart.licensetype lt, mart.businesslocations l ,  
												(Select distinct a.AddressLine1 prem_addr, a.CACity||','||USASTATECODE||' '||zipcode prem_csz, a.ObjectId addresses_eid 
															  from mart.address a
															  where a.AddressLine1 like '%'||rec_parameters.address||'%' --'13%'
															  and a.CACity = rec_parameters.City   --'SACRAMENTO'
															  and a.ObjectId in (select l.ADDRESSOBJECTID from mart.businesslocations l)    
															 ) x
												where lt.LicenseJobId =  l.JOBOBJECTID
												and  l.ADDRESSOBJECTID =   x.addresses_eid	

											);
						
						ctx := dbms_xmlgen.newContext (cur_recs);

						dbms_xmlgen.setRowTag (ctx, 'RESULT');
						dbms_xmlgen.setRowSetTag (ctx, 'ROOT');
						dbms_xmlgen.setPrettyPrinting (ctx, false);

						retval := dbms_xmlgen.getXMLType (ctx);
						dbms_xmlgen.closeContext (ctx);

						SELECT XMLPI(NAME "xml-stylesheet", 'href="../Formats/LicenseList.xslt" type="text/xsl"') INTO lxml_pi FROM DUAL;

						IF (retval IS NOT NULL) THEN 
						p_reportdata := clob2blob(lxml_pi.GETCLOBVAL() || retval.GETCLOBVAL());
						ELSE
						p_message := 'no data returned';
						end if;
						
						
					end if;
					
					
					

					DBMS_OUTPUT.PUT_LINE('Done LQS report type 13....');
			
				-- Report type 13 logic ends here 
				
				
				-- Report type 12  is for License number (LQSDATA.asp)

				ELSIF rec_parameters.rpttype in ( 12 ) THEN
					DBMS_OUTPUT.PUT_LINE('RPTTYPE is 12 call Ning procedure');
					
				END IF;
			END;


			DBMS_OUTPUT.PUT_LINE('Done LQS_BusAddr....');
        EXCEPTION
             WHEN NO_DATA_FOUND THEN
               NULL;
             WHEN OTHERS THEN
                p_message := SQLERRM || ' --- ' || dbms_utility.format_error_backtrace ;

        END;
    
    END LQS_BusAddr;
	
	
	-- LQS RptType 
	-- 14 – Licensee / Company Name  
	-- Persons....LQSOwnrQuery.html > LQSBrkdwn.asp > LQSOwnrLst.asp 
	-- CASE "OWNR"

------------------------------------------
PROCEDURE LQS_LicenseeOrCompany
------------------------------------------
( p_parameters IN  XMLTYPE
, p_reportdata OUT BLOB
, p_message    OUT VARCHAR)
IS
  CURSOR cur_parameters(p_data IN XMLTYPE) IS
  SELECT 
    rpttype
  , upper(licensee) licensee
  , company
  FROM XMLTable( '/*/REQUEST' --'/*' 
  PASSING p_data COLUMNS
    rpttype   NUMBER(2)    PATH 'RPTTYPE'
  , licensee  VARCHAR2(50) PATH 'LICENSEE'
  , company		varchar2(50) PATH 'COMPANY' 
  );                              
 
  rec_parameters      cur_parameters%ROWTYPE;
  cur_recs        SYS_REFCURSOR;
  lxml_pi         XMLTYPE;
  retval          XMLTYPE := xmltype('<ROOT></ROOT>');
  ctx             dbms_xmlgen.ctxHandle;

  p_rpttype     VARCHAR2(10);
  p_report_date   varchar2(10);  		
  v_rec_cnt number := 0;
  v_addresses_eid mart.address.ObjectId%Type;
  v_LicAddrCnt number;

  v_license xmltype;
  v_licensee VARCHAR2(200);

BEGIN    

  DBMS_OUTPUT.PUT_LINE('Starting procedure LQS_LicenseeOrCompany...');
  OPEN cur_parameters(p_parameters);
  FETCH cur_parameters INTO rec_parameters;
  CLOSE cur_parameters;
			
  IF rec_parameters.rpttype in ( 14 ) THEN 

    rec_parameters.licensee := REPLACE(rec_parameters.licensee,'CHR(38)','&'); 
  
    DBMS_OUTPUT.PUT_LINE('Licensee Name = '|| rec_parameters.licensee);
    DBMS_OUTPUT.PUT_LINE('Company or Person .... '|| rec_parameters.company);
    -- LQSBrkdwn.asp starts here...

    -- PERSONS
    IF rec_parameters.company = 'N' THEN 
      BEGIN
        -- Need to check the record count
        Select count(DISTINCT p.ObjectID) into v_rec_cnt
        from mart.person p 
        join mart.personlegalentity r on p.ObjectId = r.PERSONOBJECTID
        where p.FormattedPersonName like '%'||rec_parameters.licensee||'%' --(Select mart.CleanUp_String( rec_parameters.licensee||'%','WILD') from dual) 
        order by p.FormattedPersonName;
      EXCEPTION WHEN NO_DATA_FOUND THEN 
        v_rec_cnt := 0;
      END;

      DBMS_OUTPUT.PUT_LINE('v_rec_cnt = '|| v_rec_cnt);
      IF v_rec_cnt = 0 then 
        p_message := 'No data returned';
      ELSIF v_rec_cnt = 1 THEN 
        -- in page LQSBrkdwn.asp
        -- get the license number and re-route to LQSDATA.asp
        FOR PersDet IN 
        ( SELECT 
          ( select DISTINCT licensenumber 
            FROM mart.license l
            , mart.licensetype lt --5/30 Sheik Added distinct function 
            WHERE l.jobid = lt.licensejobid and  l.jobid = le.LICENSEOBJECTID) license
				  FROM mart.person p  
          JOIN mart.personlegalentity r on p.ObjectId = r.PERSONOBJECTID  
          JOIN mart.legalentitylicense le on r.LEGALENTITYOBJECTID = le.LEGALENTITYOBJECTID
          WHERE p.FormattedPersonName like  '%'||rec_parameters.licensee||'%' 
        --(Select mart.CleanUp_String( rec_parameters.licensee||'%','WILD') from dual)
        UNION
          
        Select (select DISTINCT licensenumber from mart.application a  --5/30 Sheik Added distinct function
            where a.objectid =  AP.APPLICATIONJOBID) license
         from mart.person p
        join mart.personlegalentity r on p.ObjectId = r.PERSONOBJECTID
        join MART.LEGALENTITYAPPLICATION ap on r.LEGALENTITYOBJECTID = ap.LEGALENTITYOBJECTID 
        join mart.application a on ap.APPLICATIONJOBID = A.OBJECTID  
        where a.LicenseExists = 'N' 
        and p.FormattedPersonName like  '%'||rec_parameters.licensee||'%' 
        )
        --(Select mart.CleanUp_String( rec_parameters.licensee||'%','WILD') from dual) )
				LOOP

								DBMS_OUTPUT.PUT_LINE('call ning license detail_record_counter');
								DBMS_OUTPUT.PUT_LINE(PersDet.license);

								SELECT
									XMLELEMENT("ROOT"
									, XMLELEMENT("LICENSE",PersDet.license)  
									)
								  INTO v_license
								  FROM DUAL;

								LQS_DETAIL.LQS_LICENSE( v_license,
											p_reportdata,
											p_message);
							END LOOP;
								
						elsif v_rec_cnt > 1 then 	
							-- re-route to LQSPREMLIST.asp for a list of similar choices
							-- re-route to LQSPREMLIST.asp from LQSBrkdwn.asp for a list of similar choices
							
							OPEN cur_recs FOR 	Select distinct  p.FormattedPersonName Name,  
														REGEXP_REPLACE (lt.PRIMARYDBA, '[[:cntrl:]]', '') dba, --lt.primarydba dba, 
														l.JOBID licenses_eid, 
														lpad(l.ExternalFileNum,6) license_num, 
														MART.GetLTCodesAndStatus(L.JOBID) status_code, 
														l.PremAddressUSCity city ,
														(select distinct a.AddressLine1 prem_addr --, a.CACity||','||USASTATECODE||' '||zipcode prem_csz
														from mart.address a, mart.businesslocations bl
														where bl.ADDRESSOBJECTID =  a.ObjectId	
														and bl.JOBOBJECTID = lt.LicenseJobId) prem_addr,
														(select distinct a.CACity||','||USASTATECODE||' '||zipcode prem_csz
														from mart.address a, mart.businesslocations bl
														where bl.ADDRESSOBJECTID =  a.ObjectId	
														and bl.JOBOBJECTID = lt.LicenseJobId) prem_csz
												from mart.person p,
													  mart.personlegalentity r,
													  mart.legalentitylicense lel,
													  mart.license l,
													  mart.licensetype lt
												where p.ObjectId = r.PERSONOBJECTID 
												and lt.licensejobid = l.jobid 
												and lel.LICENSEOBJECTID = l.JOBID 
												and lel.LEGALENTITYOBJECTID = r.LEGALENTITYOBJECTID 
												and   p.FormattedPersonName like  '%'||rec_parameters.licensee||'%' --(Select mart.CleanUp_String( rec_parameters.licensee||'%','WILD') from dual) 
												union
												Select distinct p.FormattedPersonName Name, 
														REGEXP_REPLACE (at.PRIMARYDBA, '[[:cntrl:]]', '') dba, --at.PRIMARYDBA dba, 
														a.ObjectId licenses_eid, 
														lpad(a.LicenseNumber,6) license_num, 
														MART.GetLTCodesAndStatus(a.ObjectId) status_code, 
														a.PremUSCity city  ,
														(select distinct a.AddressLine1 prem_addr --, a.CACity||','||USASTATECODE||' '||zipcode prem_csz
														from mart.address a, mart.businesslocations bl
														where bl.ADDRESSOBJECTID =  a.ObjectId	
														and bl.JOBOBJECTID = at.ApplicationObjectID) prem_addr,
														(select distinct a.CACity||','||USASTATECODE||' '||zipcode 
														from mart.address a, mart.businesslocations bl
														where bl.ADDRESSOBJECTID =  a.ObjectId	
														and bl.JOBOBJECTID = at.ApplicationObjectID) prem_csz
												from mart.person p,  
													  mart.personlegalentity r,   
													  mart.legalentityapplication lea ,  
													  mart.application a   ,
													  mart.APPLICTYPE at
												where p.ObjectId = r.PERSONOBJECTID 
												and at.ApplicationObjectID = a.ObjectId 
												and lea.LEGALENTITYOBJECTID = r.LEGALENTITYOBJECTID 
												and LEA.APPLICATIONJOBID = A.OBJECTID 
												and   p.FormattedPersonName like  '%'||rec_parameters.licensee||'%' --(Select mart.CleanUp_String( rec_parameters.licensee||'%','WILD') from dual) 
												and a.LicenseExists = 'N';

							
							ctx := dbms_xmlgen.newContext (cur_recs);

							dbms_xmlgen.setRowTag (ctx, 'RESULT');
							dbms_xmlgen.setRowSetTag (ctx, 'ROOT');
							dbms_xmlgen.setPrettyPrinting (ctx, false);

							retval := dbms_xmlgen.getXMLType (ctx);
							dbms_xmlgen.closeContext (ctx);

							SELECT XMLPI(NAME "xml-stylesheet", 'href="../Formats/LicenseList.xslt" type="text/xsl"') INTO lxml_pi FROM DUAL;

							IF (retval IS NOT NULL) THEN 
							p_reportdata := clob2blob(lxml_pi.GETCLOBVAL() || retval.GETCLOBVAL());
							ELSE
							p_message := 'no data returned';
							end if;
							
							
						end if;
			

		-- COMPANIES
		ELSIF rec_parameters.company = 'Y' THEN 
						BEGIN
							-- Need to check the record count
							select count(1) into v_rec_cnt
							from 
							(Select distinct C.companyname companyname, 
							              l.JOBID licenses_eid,  
														lpad(l.ExternalFileNum,6) license_num, 
														MART.GetLTCodesAndStatus(L.JOBID) status_code, 
														l.PremAddressUSCity city 
												from mart.company C
												join MART.COMPANYLEGALENTITY RCL on C.OBJECTID = RCL.COMPANYOBJECTID
												join MART.LEGALENTITY le on LE.OBJECTID = RCL.LEGALENTITYOBJECTID 
												join MART.LICENSEE r on r.LEGALENTITYOBJECTID = LE.OBJECTID 
												join MART.LICENSE l on L.JOBID = R.LICENSEOBJECTID
												where C.companyname like '%'||rec_parameters.licensee||'%' --(Select mart.CleanUp_String( rec_parameters.licensee||'%','WILD') from dual) 
														
												union all 
												
												Select distinct p.companyname companyname,
														a.ObjectId licenses_eid,  
														a.LicenseNumber license_num, 
														MART.GetLTCodesAndStatus(a.ObjectId) status_code,
														a.PremUSCity city 
												from mart.company p 
												join mart.companylegalentity r on p.ObjectId = r.COMPANYOBJECTID 
												join MART.APPLICANT ap on AP.LEGALENTITYOBJECTID = R.LEGALENTITYOBJECTID 
												join mart.application a on AP.APPLICATIONOBJECTID = a.ObjectId 
												where p.companyname like '%'||rec_parameters.licensee||'%' --(Select mart.CleanUp_String( rec_parameters.licensee||'%','WILD') from dual) 
												and a.StatusName not in ('ISSUED') );		
						exception when no_data_found then 
							v_rec_cnt := 0;
						end;
						DBMS_OUTPUT.PUT_LINE('v_rec_cnt = '|| v_rec_cnt);
						if v_rec_cnt = 0 then 
							p_message := 'No data returned';
						elsif v_rec_cnt = 1 then 

							-- in page LQSBrkdwn.asp
							-- get the license number and re-route to LQSDATA.asp
							for CompDet in (Select distinct C.companyname companyname,
							              l.JOBID licenses_eid,  
														lpad(l.ExternalFileNum,6) license_num, 
														MART.GetLTCodesAndStatus(L.JOBID) status_code, 
														l.PremAddressUSCity city 
												from mart.company C
												join MART.COMPANYLEGALENTITY RCL on C.OBJECTID = RCL.COMPANYOBJECTID
												join MART.LEGALENTITY le on LE.OBJECTID = RCL.LEGALENTITYOBJECTID 
												join MART.LICENSEE r on r.LEGALENTITYOBJECTID = LE.OBJECTID 
												join MART.LICENSE l on L.JOBID = R.LICENSEOBJECTID
												where C.companyname like '%'||rec_parameters.licensee||'%' --(Select mart.CleanUp_String( rec_parameters.licensee||'%','WILD') from dual) 
														
												union -- all  -- WO 15920  remove the UNION ALL for distinct row set 
												
												Select distinct p.companyname companyname,
														a.ObjectId licenses_eid,   
														a.LicenseNumber license_num, 
														MART.GetLTCodesAndStatus(a.ObjectId) status_code,
														a.PremUSCity city 
												from mart.company p 
												join mart.companylegalentity r on p.ObjectId = r.COMPANYOBJECTID 
												join MART.APPLICANT ap on AP.LEGALENTITYOBJECTID = R.LEGALENTITYOBJECTID 
												join mart.application a on AP.APPLICATIONOBJECTID = a.ObjectId 
												where p.companyname like '%'||rec_parameters.licensee||'%' --(Select mart.CleanUp_String( rec_parameters.licensee||'%','WILD') from dual) 
												and a.StatusName not in ('ISSUED') )
							loop
								DBMS_OUTPUT.PUT_LINE('call ning license detail_record_counter');
								DBMS_OUTPUT.PUT_LINE(CompDet.license_num);

								SELECT
									XMLELEMENT("ROOT"
									, XMLELEMENT("LICENSE",CompDet.license_num)  
									)
								  INTO v_license
								  FROM DUAL;

								LQS_DETAIL.LQS_LICENSE( v_license,
											p_reportdata,
											p_message);
							End loop;
								
						elsif v_rec_cnt > 1 then 	
							-- re-route to LQSPREMLIST.asp for a list of similar choices
							-- re-route to LQSPREMLIST.asp from LQSBrkdwn.asp for a list of similar choices

							OPEN cur_recs FOR 	Select distinct  C.companyname name, 
														 REGEXP_REPLACE (lt.PRIMARYDBA, '[[:cntrl:]]', '') dba, --lt.primarydba dba,
														-- l.JOBID licenses_eid, -- WO 15920  If you remove this field from result set to fix dupe problem
														lpad(l.ExternalFileNum,6) license_num, 
														MART.GetLTCodesAndStatus(L.JOBID) status_code, 
														l.PremAddressUSCity city,
														(select distinct a.AddressLine1 prem_addr --, a.CACity||','||USASTATECODE||' '||zipcode prem_csz
														from mart.address a, mart.businesslocations bl
														where bl.ADDRESSOBJECTID =  a.ObjectId	
														and bl.JOBOBJECTID = lt.LicenseJobId) prem_addr,
														(select distinct a.CACity||','||USASTATECODE||' '||zipcode prem_csz
														from mart.address a, mart.businesslocations bl
														where bl.ADDRESSOBJECTID =  a.ObjectId	
														and bl.JOBOBJECTID = lt.LicenseJobId) prem_csz
												from mart.company C
												join MART.COMPANYLEGALENTITY RCL on C.OBJECTID = RCL.COMPANYOBJECTID
												join MART.LEGALENTITY le on LE.OBJECTID = RCL.LEGALENTITYOBJECTID 
												join MART.LICENSEE r on r.LEGALENTITYOBJECTID = LE.OBJECTID 
												join MART.LICENSE l on L.JOBID = R.LICENSEOBJECTID
												join mart.licensetype lt on lt.licensejobid = l.jobid 
												where C.companyname like  '%'||rec_parameters.licensee||'%' --(Select mart.CleanUp_String( rec_parameters.licensee||'%','WILD') from dual)
												union -- all -- WO 15920 use UNION vs UNION ALL to remove duplicate rows 
												Select distinct p.companyname name,
														-- (select distinct at.PRIMARYDBA from mart.APPLICTYPE at  where a.objectid =  at.APPLICATIONOBJECTID) dba, 
														 REGEXP_REPLACE (at.PRIMARYDBA, '[[:cntrl:]]', '') dba, --at.PRIMARYDBA dba,
														-- a.ObjectId licenses_eid,  -- WO 15920  If you remove this field from result set to fix dupe problem 
														lpad(a.LicenseNumber,6) license_num, 
														MART.GetLTCodesAndStatus(a.ObjectId) status_code,
														a.PremUSCity city ,
														(select distinct a.AddressLine1 prem_addr --, a.CACity||','||USASTATECODE||' '||zipcode prem_csz
														from mart.address a, mart.businesslocations bl
														where bl.ADDRESSOBJECTID =  a.ObjectId	
														and bl.JOBOBJECTID = at.ApplicationObjectID) prem_addr,
														(select distinct a.CACity||','||USASTATECODE||' '||zipcode 
														from mart.address a, mart.businesslocations bl
														where bl.ADDRESSOBJECTID =  a.ObjectId	
														and bl.JOBOBJECTID = at.ApplicationObjectID) prem_csz
												from mart.company p 
												join mart.companylegalentity r on p.ObjectId = r.COMPANYOBJECTID 
												join MART.APPLICANT ap on AP.LEGALENTITYOBJECTID = R.LEGALENTITYOBJECTID 
												join mart.application a on AP.APPLICATIONOBJECTID = a.ObjectId 
												join mart.APPLICTYPE at on at.ApplicationObjectID = a.ObjectId 
												where p.companyname like '%'||rec_parameters.licensee||'%' --(Select mart.CleanUp_String( rec_parameters.licensee||'%','WILD') from dual)
												and a.StatusName not in ('ISSUED');

							
							ctx := dbms_xmlgen.newContext (cur_recs);

							dbms_xmlgen.setRowTag (ctx, 'RESULT');
							dbms_xmlgen.setRowSetTag (ctx, 'ROOT');
							dbms_xmlgen.setPrettyPrinting (ctx, false);

							retval := dbms_xmlgen.getXMLType (ctx);
							dbms_xmlgen.closeContext (ctx);

							SELECT XMLPI(NAME "xml-stylesheet", 'href="../Formats/LicenseList.xslt" type="text/xsl"') INTO lxml_pi FROM DUAL;

							IF (retval IS NOT NULL) THEN 
							p_reportdata := clob2blob(lxml_pi.GETCLOBVAL() || retval.GETCLOBVAL());
							ELSE
							p_message := 'no data returned';
							end if;
							
							
						end if; --record count

    END IF; -- companies

  END IF; -- close rectype 14

		
	DBMS_OUTPUT.PUT_LINE('Done LQS report type 14....');
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    NULL;
  WHEN OTHERS THEN
    p_message := SQLERRM || ' --- ' || dbms_utility.format_error_backtrace ;
		
END LQS_LicenseeOrCompany;			
	
	-- LQS RptType 
	-- 15 – DBA 
	-- Persons....LQSDBAQuery.html > LQSBrkdwn.asp > LQSDBALst.asp   -- Option as DBA

------------------------	
PROCEDURE LQS_DBA
------------------------	
( p_parameters IN  XMLTYPE,
  p_reportdata OUT BLOB,
  p_message    OUT VARCHAR)
IS

  CURSOR cur_parameters(p_data IN XMLTYPE) IS
  SELECT rpttype,
  -- upper(REPLACE(dbaname,'&','\_') ) dbaname
  -- upper(REPLACE(dbaname,'&',chr(38)||'amp;')) dbaname
  -- upper(REPLACE(dbaname,'&','\&')) dbaname
  -- upper(REPLACE(dbaname,'&','&&')) dbaname
  -- upper(REPLACE(dbaname,'&',chr(38)||'amp'||chr(59))) dbaname
  -- REPLACE(dbaname,CHR(38),CHR(95)) dbaname
  UPPER(dbaname) dbaname
  FROM XMLTable( '/*/REQUEST' --'/*' 
    PASSING p_data
    COLUMNS
    rpttype    NUMBER(2)     	PATH 'RPTTYPE',
    dbaname    VARCHAR2(50)  	PATH 'DBANAME'
  );                              

  rec_parameters  cur_parameters%ROWTYPE;
  cur_recs        SYS_REFCURSOR;
  lxml_pi         XMLTYPE;
  retval          XMLTYPE := xmltype('<ROOT></ROOT>');
  ctx             dbms_xmlgen.ctxHandle;

  p_rpttype     VARCHAR2(10);
  p_report_date VARCHAR2(10);  		

  v_rec_cnt number := 0;
  v_addresses_eid mart.address.ObjectId%Type;
  v_LicAddrCnt number;

  v_license xmltype;

BEGIN    

  --Raise_Application_Error (-20343, 'Test');
  DBMS_OUTPUT.PUT_LINE('Starting procedure LQS_DBA...');
  OPEN cur_parameters(p_parameters);
  FETCH cur_parameters INTO rec_parameters;
  CLOSE cur_parameters;
  
  rec_parameters.dbaname := REPLACE(rec_parameters.dbaname,'CHR(38)','&'); 

  BEGIN
  
    IF rec_parameters.rpttype in ( 15 ) THEN 
      DBMS_OUTPUT.PUT_LINE('DBA = '|| rec_parameters.dbaname);

      BEGIN
        -- Need to check the record count
        Select count(distinct(licensenum) ) into v_rec_cnt
        from mart.dbanames 
        where ActiveDBA like '%'||rec_parameters.dbaname||'%' --(Select mart.CleanUp_String( rec_parameters.dbaname||'%','WILD') from dual) 
        and LicenseNum is not null;
      EXCEPTION WHEN NO_DATA_FOUND THEN 
        v_rec_cnt := 0;
      END;
      DBMS_OUTPUT.PUT_LINE('v_rec_cnt = '|| v_rec_cnt);
      
      IF v_rec_cnt = 0 then 
        p_message := 'No data returned';
      ELSIF v_rec_cnt = 1 THEN 

        -- in page LQSBrkdwn.asp
        -- get the license number and re-route to LQSDATA.asp
        for Det in (Select distinct lpad(lt.LICENSENUMBER,6) license_num --, lt.LICENSEJOBID licenses_eid, d.activeDBA dbaname,
                  -- MART.GetLTCodesAndStatus(lt.LicenseJobId) status_code, lt.PremisesCity city
              from mart.licensetype lt,  mart.dbanames d 
              where  lt.LicenseNumber = d.licensenum
              and d.activeDBA like '%'||rec_parameters.dbaname||'%' --(Select mart.CleanUp_String( rec_parameters.dbaname||'%','WILD') from dual)
              and d.licensenum is not null
              union  
              Select distinct lpad(AP.LICENSENUMBER,6) license_num --,AP.APPLICATIONOBJECTID licenses_eid,  d.activeDBA dbaname,
                  -- MART.GetLTCodesAndStatus(ap.ApplicationObjectId) status_code, AP.PREMADDRESSCITY city 
              from MART.APPLICTYPE ap , mart.dbanames d 
              where ap.ApplicationStatus in ('PEND', 'ISSUPD', 'DENIED', 'WTHDRN') 
              and AP.LICENSENUMBER  = d.licensenum  
              and d.activeDBA like '%'||rec_parameters.dbaname||'%' --(Select mart.CleanUp_String( rec_parameters.dbaname||'%','WILD') from dual)
              and d.licensenum is not null)

        loop
          DBMS_OUTPUT.PUT_LINE('call ning license detail_record_counter');
          DBMS_OUTPUT.PUT_LINE(Det.license_num);

          SELECT
            XMLELEMENT("ROOT"
            , XMLELEMENT("LICENSE",Det.license_num)  
            )
            INTO v_license
            FROM DUAL;

          LQS_DETAIL.LQS_LICENSE( v_license,
                p_reportdata,
                p_message);
        End loop;
          
      elsif v_rec_cnt > 1 then 	
        -- re-route to LQSPREMLIST.asp for a list of similar choices
        -- re-route to LQSPREMLIST.asp from LQSBrkdwn.asp for a list of similar choices
        
        OPEN cur_recs FOR 	Select distinct 
                      -- lt.LICENSEJOBID licenses_eid, -- WO 15920
                      primarylicensee name, lpad(lt.LICENSENUMBER,6) license_num, 
                      REGEXP_REPLACE (lt.PRIMARYDBA, '[[:cntrl:]]', '') dba, --lt.PRIMARYDBA dba,
                    MART.GetLTCodesAndStatus(lt.LicenseJobId) status_code, --lt.PremisesCity city, 
                    REGEXP_REPLACE (lt.PremAddress1stOf2Lines, '[[:cntrl:]]', '')  prem_addr, --lt.PREMADDRESS1STOF2LINES prem_addr,
                    REGEXP_REPLACE (lt.PremAddress2ndOf2Lines, '[[:cntrl:]]', '')  prem_csz --lt.PREMADDRESS2NDOF2LINES prem_csz
                  from mart.licensetype lt
                  where lt.primarydba like '%'||rec_parameters.dbaname||'%' --(Select mart.CleanUp_String( rec_parameters.dbaname||'%','WILD') from dual) -- 'JOE%'
                  union  
                  Select distinct 
                      --AP.APPLICATIONOBJECTID licenses_eid, -- WO 15920
                      ap.primarylicensee name, lpad(AP.LICENSENUMBER,6) license_num, 
                      REGEXP_REPLACE (PRIMARYDBA, '[[:cntrl:]]', '') dba, --PRIMARYDBA dba,
                      MART.GetLTCodesAndStatus(ap.ApplicationObjectId) status_code, --AP.PREMADDRESSCITY city ,
                      ap.PREMADDRESSLINE1 prem_addr,
                      ap.PREMADDRESSLINE2 prem_csz  -- WO 15920
                  from MART.APPLICTYPE ap 
                  where ap.ApplicationStatus in ('PEND', 'ISSUPD', 'DENIED', 'WTHDRN') 
                  and ap.primarydba like '%'||rec_parameters.dbaname||'%'; --(Select mart.CleanUp_String( rec_parameters.dbaname||'%','WILD') from dual); --'JOE'; 

        ctx := dbms_xmlgen.newContext (cur_recs);

        dbms_xmlgen.setRowTag (ctx, 'RESULT');
        dbms_xmlgen.setRowSetTag (ctx, 'ROOT');
        dbms_xmlgen.setPrettyPrinting (ctx, false);

        retval := dbms_xmlgen.getXMLType (ctx);
        dbms_xmlgen.closeContext (ctx);

        SELECT XMLPI(NAME "xml-stylesheet", 'href="../Formats/LicenseList.xslt" type="text/xsl"') INTO lxml_pi FROM DUAL;

        IF (retval IS NOT NULL) THEN 
        p_reportdata := clob2blob(lxml_pi.GETCLOBVAL() || retval.GETCLOBVAL());
        ELSE
        p_message := 'no data returned';
        end if;
        
        
      end if;

    END IF; -- CLOSE RECTYPE 15
  END;

  
  DBMS_OUTPUT.PUT_LINE('Done LQS report type 15....');
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    NULL;
  WHEN OTHERS THEN
    p_message := SQLERRM || ' --- ' || dbms_utility.format_error_backtrace ;

END LQS_DBA;			
		

-- Converts Clob to Blob
--------------------------------------------------	
FUNCTION clob2blob(p_clob IN CLOB) RETURN BLOB 
--------------------------------------------------
IS

  l_blob           BLOB;
  ln_pos          PLS_INTEGER     := 1;
  buffer          RAW( 32767 );
  ln_lob_len      PLS_INTEGER     := DBMS_LOB.getLength( p_clob );
  ln_len          NUMBER          := 32000;

BEGIN
--
  IF p_clob is null then
    return null;
  END IF;
-- 
  DBMS_LOB.createTemporary( l_blob, TRUE );
  DBMS_LOB.OPEN( l_blob, DBMS_LOB.LOB_ReadWrite );

  LOOP
    buffer := UTL_RAW.cast_to_raw( DBMS_LOB.SUBSTR( p_clob, ln_len, ln_pos ) );

    IF UTL_RAW.LENGTH( buffer ) > 0 THEN
      DBMS_LOB.writeAppend( l_blob, UTL_RAW.LENGTH( buffer ), buffer );
    END IF;

    ln_pos := ln_pos + ln_len;
    EXIT WHEN ln_pos > ln_lob_len;
  END LOOP;

  RETURN l_blob;
  
END clob2blob;

END LQS_REPORTS;
/
