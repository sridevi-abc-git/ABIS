CREATE OR REPLACE PACKAGE BODY ABCLQS.LQS_STREAMS AS
-- ****************************************************************************
-- File:        LQS_STREAMS.pkb  
-- Author:      Ning Wong    
--
-- $Rev:  $  
-- $Date: $
-- Last Changed By:  $Author: nwong $
--
-- Description: License Count Reports (Formerly Yearly)       
--	
--  
--	
-- Date Created.....10/10/2019
-- Main procedure...LQS.Main
--	
-- Category		rpttype	Reports
		
-- ---------- -------	-------
-- Licensing  24		  SV
--					  25      Fixed Width
-- LQS_ADHOC  
-- LQS_ADHOC  6			  AdHoc by License Type
--					  7			  AdHoc for Active On-Sale Retail licenses 
--					  8 		  AdHoc for Off Sale retail licenses
--					  9			  AdHoc for Active Retail Licenses 
--					  10		  AdHoc for Non-Retail licenses

-- History:
-------------------------------------------------------------------------------
-- Date            Comment
-- 11/12/2019 NW   Refactored added as-of date parameter so this can be run daily
-- 12/10/2019 NW   Refactored LQS Adhoc Reports
-- 12/26/2019 NW   WO 20114 - Added field headers to ommitted fields 
--                            i.e. Fee Codes, Dup Counts, District Code, and all Mail Address fields
-- 02/10/2020 NW   WO 20734 -- LT 74 is considered Off-Sale for purposes of Public website
-- 03/09/2020 NW   WO 20734 -- LT 74 is considered Off-Sale for purposes of Public website
-- 05/22/2020 NW   WO          Re-add Fee Codes, Dup Counts, District Code    
-- 07/03/2020 NW   WO 22015 -- Column G and H in Daily Data Export are reversed
-- ****************************************************************************

---------------------------------------------------
PROCEDURE LICENSES_CSV (   -- LQS report 24  
---------------------------------------------------
  p_parameters IN  XMLTYPE,
  p_reportdata OUT BLOB,
  p_message    OUT VARCHAR
)
---------------------------------------------------	

IS

  cur_recs SYS_REFCURSOR;
  l_clob clob;

BEGIN
	DBMS_LOB.CREATETEMPORARY(L_CLOB,TRUE);
	FOR c1 IN ( 
	  SELECT 
	  'License Type,File Number,Lic or App,Type Status,Type Orig Iss Date,Expir Date,Fee Codes,Dup Counts,Master Ind,Term in # of Months,'
	  || 'Geo Code,District,Primary Name,Prem Addr 1, Prem Addr 2,Prem City, Prem State,Prem Zip,DBA Name,' 
	  || 'Mail Addr 1,Mail Addr 2,Mail City,Mail State,Mail Zip,Prem County,Prem Census Tract #' || CHR(10) CSV_LINE
	  FROM DUAL

	  UNION ALL

	  SELECT
		'"' ||
		substr(nvl(d.license_type_code,' '),1,2)  || '","' ||
		substr(to_char(nvl(d.licenseno,0),'09999999'),2,8) || '","' ||
		substr(nvl(d.App_or_Lic ,' '),1,3)  || '","' ||
		substr(nvl(d.Type_status_code,' '),1,8) || '","' ||
		nvl(to_char(d.Type_original_issue_date),' ') || '","' || 
		nvl(to_char(d.Next_issue_date),' ') || '","' ||
		-- '" ,"' ||       -- fee codes   
		-- '" ,"' ||       -- duplicate_count
	  substr(nvl(d.Fee_code,' '),1,8) || '","' ||                                          -- wo 22015
	  substr (nvl(to_char(nvl(d.Duplicate_count,''),'000'), '   '),2,3) || '","' ||
		substr(nvl(d.Master_ind,' '),1,1) || '","' ||
		substr(nvl(d.Term,' '),1,2) || '","' ||
		substr(nvl(d.premgeocode,' '),1,4) || '","' ||
		--'" ,"' ||  -- dist/office code
	  substr (nvl(to_char(nvl(d.officenumber,''),'00'), '  '),2,2)  || '","' ||
		replace(replace(translate(substr(nvl(d.PrimaryLicensee,' '),1,50),',',' '),CHR(13),''),CHR(10),'') || '","' ||
		translate(substr(nvl(d.premaddressline1,' '),1,50),',',' ') || '","' || 
		translate(substr(nvl(d.premaddressline2,' '),1,50),',',' ') || '","' ||
		translate(substr(nvl(d.premcity,' '),1,25),',',' ') || '","' ||
		substr(nvl(d.premstate,' '),1,2) || '","' ||
		substr(nvl(d.premzip,' '),1,10) || '","' ||
		translate(substr(nvl(d.PrimaryDBA,' '),1,50),',',' ') || '","' ||

		-- remove mailing address per privacy concerns from our Legal Dept
		-- put them back otherwise we will get sued
		translate(substr(nvl(d.mailaddressline1,' '),1,50),',',' ') || '","' ||
		translate(substr(nvl(d.mailaddressline2,' '),1,50),',',' ') || '","' ||
		translate(substr(nvl(d.mailcity,' '),1,25),',',' ') || '","' ||
		substr(nvl(d.mailstate,' '),1,2) || '","' ||
		substr(nvl(d.mailzip,' '),1,10) || '","' ||

/*
		'" ,"' ||  -- mailaddressline1
		'" ,"' ||  -- mailaddressline2
		'" ,"' ||  -- mailcity
		'" ,"' ||  -- mailstate
		'" ,"' ||  -- mailzip
*/
		translate(substr(nvl(d.PremCountyName,' '),1,16),',',' ') || '","' ||
		substr(nvl(d.PremCensusTract,' '),1,7) || '"' || CHR(10)
		CSV_LINE
	  -- FROM ABC.RAWDATAEXTRACT_TYPE D
	  FROM ABCLQS.All_Licenses D
	  WHERE license_type_code not between '30' and '39' 
	  AND (UPPER (Type_status_code) in ('ACTIVE', 'SLMSHD', 'SUSPEN', 'REVPEN', 'SUREND', 'R64B', 'PEND','ISSUPD') )
	)  -- END c1
	LOOP
	  DBMS_LOB.WRITEAPPEND(l_clob, LENGTH(C1.CSV_LINE), C1.CSV_LINE);    
	END LOOP;
	p_reportdata := ABCLQS.clob2blob(l_clob);

EXCEPTION
WHEN NO_DATA_FOUND THEN 
  p_message := 'No records found for LICENSES_CSV.';

WHEN TOO_MANY_ROWS THEN 
  p_message := 'LQS Data Error - Too many rows returned for LICENSES_CSV.' ; 

WHEN OTHERS THEN 
  p_message := 'Error in LICENSES_CSV.'; 

END LICENSES_CSV;  -- LQS report 23
	

---------------------------------------------------
PROCEDURE LICENSES_Fixed_Width ( -- LQS report 25
---------------------------------------------------	
  p_parameters IN  XMLTYPE,
  p_reportdata OUT BLOB,
  p_message    OUT VARCHAR
)
IS
  cur_recs SYS_REFCURSOR;
  l_clob clob;

BEGIN
  DBMS_LOB.CREATETEMPORARY(L_CLOB,TRUE);
  FOR c1 IN (
    SELECT  
    rpad(substr(nvl(d.license_type_code,' '),1,2),2,' ') ||
    substr(to_char(nvl(d.licenseno,0),'09999999'),2,8) ||
    rpad(substr(nvl(d.App_or_Lic ,' '),1,3),3,' ')||
    rpad(substr(nvl(d.Type_status_code,' '),1,8),8,' ') ||
    rpad(nvl(to_char(d.Type_original_issue_date),' '),11,' ') ||
    rpad(nvl(to_char(d.Next_issue_date),' '),11,' ') ||
--    rpad(' ',8) || -- fee code
--    rpad(' ',3) || -- duplicate count
		rpad(substr(nvl(d.Fee_code,' '),1,8),8,' ')||
		rpad(substr (nvl(to_char(nvl(d.Duplicate_count,''),'000'), '   '),2,3),3,' ') ||
    rpad(substr(nvl(d.Master_ind,' '),1,1),1,' ')||
    rpad(substr(nvl(d.Term,' '),1,2),2,' ')||
    rpad(substr(nvl(d.premgeocode,' '),1,4),4,' ') ||
    rpad(substr (nvl(to_char(nvl(d.officenumber,''),'00'), '  '),2,2),2,' ') ||
    rpad(translate(substr(nvl(d.PrimaryLicensee,' '),1,50),',',' '),50,' ') ||
    rpad(translate(substr(nvl(d.premaddressline1,' '),1,50),',',' '),50,' ') ||
    rpad(translate(substr(nvl(d.premaddressline2,' '),1,50),',',' '),50,' ') ||
    rpad(translate(substr(nvl(d.premcity,' '),1,25),',',' '),25,' ') ||
    rpad(substr(nvl(d.premstate,' '),1,2),2,' ') ||
    rpad(substr(nvl(d.premzip,' '),1,10),10,' ') ||
    rpad(translate(substr(nvl(d.PrimaryDBA,' '),1,50),',',' '),50,' ') ||

    rpad(' ',50) || -- rpad(translate(substr(nvl(d.mailaddressline1,' '),1,50),',',' '),50,' ') ||
    rpad(' ',50) || -- rpad(translate(substr(nvl(d.mailaddressline2,' '),1,50),',',' '),50,' ') ||
    rpad(' ',25) || -- rpad(translate(substr(nvl(d.mailcity,' '),1,25),',',' '),25,' ') ||
    rpad(' ',2)  || -- rpad(substr(nvl(d.mailstate,' '),1,2),2,' ') ||
    rpad(' ',10) || -- rpad(substr(nvl(d.mailzip,' '),1,10),10,' ') ||

    rpad(translate(substr(nvl(d.PremCountyName,' '),1,16),',',' '),16,' ') ||
    rpad(substr(nvl(d.PremCensusTract,' '),1,7),7,' ') || CHR(10) 
    rec_line
--    from ABC.RAWDATAEXTRACT_TYPE d
    FROM ABCLQS.All_Licenses D
    WHERE d.license_type_code not between '30' and '39' 
    and (UPPER (d.Type_status_code) in ('ACTIVE', 'SLMSHD', 'SUSPEN', 'REVPEN', 'SUREND', 'R64B', 'PEND','ISSUPD'))
    ORDER BY LICENSENO
  )  -- END C1
  LOOP
    DBMS_LOB.WRITEAPPEND(l_clob, LENGTH(C1.rec_line), C1.rec_line);    
  END LOOP;
  p_reportdata := ABCLQS.clob2blob(l_clob);

EXCEPTION
WHEN NO_DATA_FOUND THEN 
  p_message := 'No records found for LICENSES_Fixed_Width.';

WHEN TOO_MANY_ROWS THEN 
  p_message := 'LQS Data Error - Too many rows returned for LICENSES_Fixed_Width.'; 
 
WHEN OTHERS THEN 
  p_message := 'Error in LICENSES_Fixed_Width.'; 

END LICENSES_Fixed_Width;

---------------------------------------------------
PROCEDURE LQS_Adhoc  -- LQS_REPORTS 6,7,8,9,10 
---------------------------------------------------	
(
  p_parameters IN  XMLTYPE,
  p_reportdata OUT BLOB,
  p_message    OUT VARCHAR
)
IS

  CURSOR cur_parameters(p_data IN XMLTYPE) IS
  SELECT 
    rpttype
  , city
  , license_type
  , county
  , census_tract
  , zipcode
  , Statewide
  FROM XMLTable('/*/REQUEST' 
    PASSING p_data
    COLUMNS
    rpttype      	varchar2(10)    PATH 'RPTTYPE',
    city          VARCHAR2(4000)  PATH 'CITY',
    license_type  varchar2(10) 	  PATH 'LICENSETYPE',
    county			  VARCHAR2(4000)  PATH 'COUNTY',
    census_tract	varchar2(10)   	PATH 'CENSUS',
    zipcode			  varchar2(10)		PATH 'ZIPCODE',
    statewide		  varchar2(10) 		PATH 'STATEWIDE'
  );                              

  rec_parameters      cur_parameters%ROWTYPE;

  cur_recs        	SYS_REFCURSOR;
  lxml_pi         	XMLTYPE;
  retval          	XMLTYPE := xmltype('<ROOT></ROOT>');
  ctx             	dbms_xmlgen.ctxHandle;

BEGIN
 
  OPEN cur_parameters(p_parameters);
  FETCH cur_parameters INTO rec_parameters;
  CLOSE cur_parameters;

  OPEN cur_recs FOR 
--  SELECT                                                      -- WO   20966 Duplicates when adding secondary and temporary LTs
    SELECT DISTINCT                                              
    LPAD(LT.LicenseNumber,6) LICENSE_NUM
  , LTC.LicenseTypeCode LICENSE_TYPE_CODE
  , LT.StatusName TYPE_STATUS_CODE
  , TO_CHAR(LT.LicenseCreatedDate,'mm/dd/yyyy') ORIG_ISS_DATE
  , TO_CHAR(LT.ExpirationDate,'mm/dd/yyyy') EXPIR_DATE
  , TO_CHAR(LT.LicenseCreatedDate, 'YYYYMMDD') ORIG_ISS_DATE_SORT
  , TO_CHAR(LT.ExpirationDate, 'YYYYMMDD') EXPIR_DATE_SORT
  , LT.PrimaryLicensee PRIMARY_OWNER
  , LT.LicenseGeoCode GEO_CODE
  , REGEXP_REPLACE (LT.PremAddress1stOf2Lines, '[[:cntrl:]]', '')  PREM_ADDR
  , REGEXP_REPLACE (LT.PremAddress2ndOf2Lines, '[[:cntrl:]]', '')  PREM_CSZ
  , LT.PremAddressCountyCode COUNTY
  , LT.LicenseUSCity CITY
  , TO_CHAR (LT.LicenseCensusTract, '0000.00') CENSUS_TRACT
  , LT.LicenseZipCode ZIP
  , REGEXP_REPLACE (LT.PRIMARYDBA, '[[:cntrl:]]', '') DBA
  , LT.TransferredTo TRANSFER_TO
  , LT.TransferredFrom TRANSFER_FROM
  , LT.LicenseJobId LICENSE_EID 
  FROM MART.LicenseType LT  --92990
  JOIN MART.primaryandsecondarylicencetype R ON lt.objectid = r.licensetypeobjectid  --108,510
  JOIN MART.licensetypecategory LTC ON r.licensecetypecategoryobjectid = LTC.objectid

  WHERE LT.StatusName IN ('ACTIVE', 'R64B','REVPEN', 'SLMSHD', 'SUREND', 'SUSPEN')
  -- License Type Parameter 
  AND
    CASE 

    -- Specific License Type
    WHEN rec_parameters.rpttype = 6 AND LTC.LicenseTypeCode = rec_parameters.license_type THEN 1

    -- Active On-Sale Retail License Types
--  WHEN rec_parameters.rpttype = 7 AND LTC.LicenseTypeCode > '39' and LTC.LicenseTypeCode != '85' THEN 1
    WHEN rec_parameters.rpttype = 7 AND LTC.LicenseTypeCode > '39' and LTC.LicenseTypeCode NOT IN ('74','85') THEN 1   -- WO 20734

    -- Active Off-Sale Retail License Types
    WHEN rec_parameters.rpttype = 8 AND LTC.LicenseTypeCode IN ('20','21','85') THEN 1

    -- Active Retail License Types
    WHEN rec_parameters.rpttype = 9 AND 
--          ( (LTC.LicenseTypeCode>'39' AND LTC.LicenseTypeCode != '85') OR LTC.LicenseTypeCode IN ('20','21','85') ) THEN 1
          ( (LTC.LicenseTypeCode>'39' AND LTC.LicenseTypeCode NOT IN ('74','85')) OR LTC.LicenseTypeCode IN ('20','21','85') ) THEN 1

    -- Active Non-Retail License Types
    WHEN rec_parameters.rpttype = 10 AND ( 
      LTC.LicenseTypeCode = '74' OR
      ( LTC.LicenseTypeCode < '39' AND LTC.LicenseTypeCode NOT IN ('20','21','85') ) 
    ) THEN 1

    ELSE 0
    END = 1
    
  AND
    CASE

    -- City 
    WHEN rec_parameters.city IS NOT NULL AND LT.LicenseUSCity IN 
      ( SELECT REGEXP_SUBSTR(rec_parameters.city,'[^,]+', 1, LEVEL) City FROM DUAL
        CONNECT BY REGEXP_SUBSTR(rec_parameters.city, '[^,]+', 1, LEVEL) IS NOT NULL) THEN 1    

    -- County Only
    WHEN rec_parameters.county IS NOT NULL AND rec_parameters.census_tract IS NULL 
     AND LT.PremAddressCountyCode = rec_parameters.county THEN 1

    -- CensusTract Only
    WHEN rec_parameters.census_tract IS NOT NULL 
     AND rec_parameters.county IS NULL 
     AND TO_CHAR(LicenseCensusTract,'9999.99') = TO_CHAR(rec_parameters.census_Tract,'9999.99') 
    THEN 1 

    -- CensusTract and County
    WHEN rec_parameters.county IS NOT NULL 
     AND rec_parameters.census_tract IS NOT NULL 
     AND LT.PremAddressCountyCode = rec_parameters.county 
     AND TO_CHAR(LicenseCensusTract,'9999.99') = TO_CHAR(rec_parameters.census_Tract,'9999.99') 
    THEN 1 

    -- ZipCode
    WHEN rec_parameters.zipcode IS NOT NULL AND LT.LicenseZipCode = rec_parameters.zipcode THEN 1

    -- Statewide
    WHEN rec_parameters.city         IS NULL 
     AND rec_parameters.county       IS NULL 
     AND rec_parameters.census_tract IS NULL 
     AND rec_parameters.zipcode      IS NULL 
    THEN 1
    ELSE 0
    END = 1 
  ;
  
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
  END IF;
  DBMS_OUTPUT.PUT_LINE('Done LQS_SEARCH....');

EXCEPTION
WHEN NO_DATA_FOUND THEN
  NULL;
WHEN OTHERS THEN
  p_message := SQLERRM || ' --- ' || dbms_utility.format_error_backtrace ;

END LQS_Adhoc;

-------------------------------------
END LQS_STREAMS;  -- PACKAGE BODY
-------------------------------------
/
