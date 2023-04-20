CREATE OR REPLACE PACKAGE BODY ABCLQS.LQS_LICENSING_REPORTS AS
-- ****************************************************************************
-- File:        LQS_LICENSING_REPORTS.pkb  
-- Author:      Ning Wong    
--
-- $Rev:  $  
-- $Date: $
-- Last Changed By:  $Author: nwong $
--
-- Description:    
--	Refactor the Finalized and Filed Legal Proceeding Reports for ADA Compliance, Responsive Design, and Printablility
--  
--	
--	Date Created.....08/28/2019
--	Main procedure...LQS.Main
--	
--	Category		rpttype	  Reports
--	--------		---------	-------
--	Daily Reports	16			Finalized Legal Proceedings
--					      17			Filed Legal Proceedings
--					      18			Monthly Surrendered Licenses Report 
--                19      Licensed_Importers  
--                26      Finalized_Legal_Date_List 
-- History:
-------------------------------------------------------------------------------
-- Date                     Comment
-- 08/28/2019 NW   18927    Created
-- 09/26/2019 NW            Added Monthly Surrendered Licenses  
-- 10/01/2019 NW            Added Licensed Importers Report
-- 11/21/2019 NW            Added Finalized_Legal_Date_List for drop down
-- 07/07/2021 NW   23772    Added mailing address to Surrender Report
-- ****************************************************************************

---------------------------------------------------
	PROCEDURE Finalized_Legal_Proceed  -- LQS report 17 Proceedings
---------------------------------------------------	
	( p_parameters IN  XMLTYPE
	, p_reportdata OUT BLOB
	, p_message    OUT VARCHAR)
	IS
	
	l_Week_Ending          VARCHAR2(10);
  l_Week_Ending_dt       DATE;
	
	BEGIN

  SELECT TRIM(REPLACE(EXTRACTVALUE(p_parameters, '//WEEK_ENDING'), '%20', '')) INTO l_Week_Ending FROM DUAL;
  IF l_Week_Ending IS NOT NULL THEN
    l_Week_Ending_dt := TO_DATE(l_Week_Ending,'MM/DD/YYYY');
  ELSE
    SELECT MAX(ENDDATE) INTO l_Week_Ending_dt FROM LQS_REPORTS_DATA WHERE REPORT_NUMBER = 102;
  END IF;

  DBMS_OUTPUT.PUT_LINE('Week Ending: ' || l_Week_Ending);
  DBMS_OUTPUT.PUT_LINE('converted: ' || l_Week_Ending_dt);
    
  SELECT REPORT_DATA INTO  p_reportdata
  FROM LQS_REPORTS_DATA
  WHERE REPORT_NUMBER = 102  --  Legal Actions Finalized
  AND CREATEDDATE = 
  ( SELECT MAX(CREATEDDATE) 
    FROM LQS_REPORTS_DATA 
    WHERE REPORT_NUMBER = 102
      AND ENDDATE = l_Week_Ending_dt
  );
    
  EXCEPTION
  WHEN NO_DATA_FOUND THEN 
    p_message := 'No records found for Finalized Legal Proceedings Report.';

  WHEN TOO_MANY_ROWS THEN 
    p_message := 'LQS Data Error - Too many rows returned for Finalized Legal Proceedings Report.' ; 
   
  WHEN OTHERS THEN 
    p_message := 'Error in FINALIZED_LEGAL_PROCEED.'; 
    
	END Finalized_Legal_Proceed; 

---------------------------------------------------
	PROCEDURE Filed_Legal_Proceed  -- LQS report 16
---------------------------------------------------
	( p_parameters IN  XMLTYPE
	, p_reportdata OUT BLOB
	, p_message    OUT VARCHAR)
	IS
	
	l_Week_Ending          VARCHAR2(10);
  l_Week_Ending_dt       DATE;
	
	BEGIN

  SELECT TRIM(REPLACE(EXTRACTVALUE(p_parameters, '//WEEK_ENDING'), '%20', '')) INTO l_Week_Ending FROM DUAL;

  IF l_Week_Ending IS NOT NULL THEN
    l_Week_Ending_dt := TO_DATE(l_Week_Ending,'MM/DD/YYYY');
  ELSE
    SELECT MAX(ENDDATE) INTO l_Week_Ending_dt FROM LQS_REPORTS_DATA WHERE REPORT_NUMBER = 102;
  END IF;

  DBMS_OUTPUT.PUT_LINE('Week Ending: ' || l_Week_Ending);
  DBMS_OUTPUT.PUT_LINE('converted: ' || l_Week_Ending_dt);

  SELECT REPORT_DATA BIG_BLOB INTO p_reportdata
	FROM LQS_REPORTS_DATA
	WHERE REPORT_NUMBER = 101  --  Legal Actions Filed
	AND CREATEDDATE = 
	( SELECT MAX(CREATEDDATE) 
	  FROM LQS_REPORTS_DATA 
	  WHERE REPORT_NUMBER = 101
      AND ENDDATE = l_Week_Ending_dt
  );

  EXCEPTION
	WHEN NO_DATA_FOUND THEN 
	  p_message := 'No records found for Filed Legal Proceedings Report.';

	WHEN TOO_MANY_ROWS THEN 
	  p_message := 'LQS Data Error - Too many rows returned for Filed Legal Proceedings Report.' ; 
	   
	WHEN OTHERS THEN 
	  p_message := 'Error in FILED_LEGAL_PROCEED.'; 

	END Filed_Legal_Proceed;
  
---------------------------------------------------
	PROCEDURE Surrendered_Licenses  -- LQS report 18
---------------------------------------------------
	( p_parameters IN  XMLTYPE
	, p_reportdata OUT BLOB
	, p_message    OUT VARCHAR)
	IS

  cur_recs        SYS_REFCURSOR;
  l_district      VARCHAR2(3);
  retval          XMLTYPE := xmltype('<ROOT></ROOT>');
  ctx             dbms_xmlgen.ctxHandle;

	BEGIN
	
  SELECT TRIM(REPLACE(EXTRACTVALUE(p_parameters, '//DISTRICT'), '%20', '')) INTO l_district FROM DUAL;
  
  OPEN cur_recs FOR 
  SELECT DISTINCT 
    O.OFFICENAME DISTRICT
  , LTC.LICENSETYPECODE LICENSE_TYPE_CODE
    
  , LT.LICENSENUMBER FILE_NUMBER
  , NVL2(R.LICENSETYPECOUNT, 'N', 'Y') MI  -- MASTER_INDICATOR
  , NVL(R.LICENSETYPECOUNT,0) DUP_COUNT

  , LT.STATUSNAME CURRENT_STATUS
  , TO_CHAR (NVL (R.EFFECTIVEDATE, LT.STATUSDATECORRAL),'DD-MON-YYYY') STATUS_DATE
  , LT.LICENSEGEOCODE GEO_CODE
  , LT.BASEFILEOFFICECODE DISTRICT_CODE

  , LT.PRIMARYLICENSEE PRIMARY_NAME
  , LT.PREMADDRESS1STOF2LINES PREM_ADDR_1 
  , LT.PREMADDRESS2NDOF2LINES PREM_ADDR_2
  , 'DBA: '||LT.PRIMARYDBA DBA_NAME

  , REGEXP_REPLACE (lt.MailAddress1stOf2Lines, '[[:cntrl:]]', '')  mail_addr,  -- lt.PremAddress1stOf2Lines prem_addr, 
    REGEXP_REPLACE (lt.MailAddress2ndOf2Lines, '[[:cntrl:]]', '')  mail_csz    -- lt.PremAddress2ndOf2Lines prem_csz, 


  FROM MART.LICENSETYPE LT 
  JOIN MART.PRIMARYANDSECONDARYLICENCETYPE R ON LT.OBJECTID = R.LICENSETYPEOBJECTID
  JOIN MART.LICENSETYPECATEGORY LTC ON R.LICENSECETYPECATEGORYOBJECTID = LTC.OBJECTID
  JOIN MART.OFFICE O ON O.OFFICECODE=LT.BASEFILEOFFICECODE
  WHERE (LTC.LICENSETYPECODE IN ('20','21') OR LTC.LICENSETYPECODE BETWEEN '40' AND '80')
   AND LT.STATUSNAME = 'SUREND'
   AND LT.BASEFILEOFFICECODE LIKE NVL( l_district, '%'  )
  ORDER BY LT.BASEFILEOFFICECODE, LT.LICENSEGEOCODE DESC;
  
  ctx := dbms_xmlgen.newContext (cur_recs);
  dbms_xmlgen.setRowTag (ctx, 'RESULT');
  dbms_xmlgen.setRowSetTag (ctx, 'ROOT');
  dbms_xmlgen.setPrettyPrinting (ctx, false);

  retval := dbms_xmlgen.getXMLType (ctx);

  dbms_xmlgen.closeContext (ctx);

  IF (retval IS NOT NULL) THEN 
    p_reportdata := clob2blob(retval.GETCLOBVAL());
      
  ELSE
    p_message := 'no data returned';
  END IF;
  	
  EXCEPTION
	WHEN NO_DATA_FOUND THEN 
	  p_message := 'No records found for Surrendered Licenses Report.';

	WHEN TOO_MANY_ROWS THEN 
	  p_message := 'LQS Data Error - Too many rows returned for Surrendered Licenses Report.' ; 
	   
	WHEN OTHERS THEN 
	  p_message := 'Error in Surrendered_Licenses.'; 

	END Surrendered_Licenses;  -- LQS report 18


---------------------------------------------------
	PROCEDURE Licensed_Importers  -- LQS report 19
---------------------------------------------------
  ( p_parameters IN  XMLTYPE
  , p_reportdata OUT BLOB
  , p_message    OUT VARCHAR)
  IS

  cur_recs        SYS_REFCURSOR;
  l_county_code   VARCHAR2(3);
  retval          XMLTYPE := xmltype('<ROOT></ROOT>');
  ctx             dbms_xmlgen.ctxHandle;

  BEGIN

  SELECT TRIM(REPLACE(EXTRACTVALUE(p_parameters, '//COUNTY'), '%20', '')) INTO l_county_code FROM DUAL;
  
--  dbms_output.put_line('county_code : '||l_county_code);
 
  OPEN cur_recs FOR 
	WITH LICENSETYPES AS 
	( SELECT
	  	C.COUNTYNAME COUNTY_NAME
	  , LT.LICENSENUMBER FILE_NUM
	  , LTC.LICENSETYPECODE LIC_TYPES
	 
	  ,	LT.PRIMARYLICENSEE PRIMARY_LICENSEE
	  ,	LT.PREMADDRESS1STOF2LINES PREM_STREET_ADDRESS_1
	  , LT.PREMADDRESS2NDOF2LINES PREM_STREET_ADDRESS_2
	  , LT.PRIMARYDBA DBA
	  ,	LT.MAILADDRESS1STOF2LINES MAILING_ADDRESS_1
	  , LT.MAILADDRESS2NDOF2LINES MAILING_ADDRESS_2
	  FROM MART.LICENSETYPE LT 
	  JOIN MART.PRIMARYANDSECONDARYLICENCETYPE R ON LT.OBJECTID = R.LICENSETYPEOBJECTID 
	  JOIN MART.LICENSETYPECATEGORY LTC ON R.LICENSECETYPECATEGORYOBJECTID = LTC.OBJECTID
		AND LTC.LICENSETYPECODE IN ('09', '10', '11', '12', '13', '14', '15', '19')
	  JOIN MART.CACOUNTY C ON C.COUNTYCODE=LT.PREMADDRESSCOUNTYCODE
	  WHERE UPPER(NVL(R.STATUS, LT.STATUSDESCRIPTION)) IN ('ACTIVE')
	  AND LT.PREMADDRESSCOUNTYCODE LIKE NVL( l_county_code||'%', '%'  )
	  ORDER BY C.countyname, LT.primarylicensee
	)
	, LT AS
	( SELECT DISTINCT FILE_NUM, LIC_TYPES FROM LICENSETYPES )

	SELECT 
	  COUNTY_NAME
	, FILE_NUM
	,(SELECT XMLAGG(XMLELEMENT("LICENSETYPE", LIC_TYPES))  
		  FROM LT WHERE LT.FILE_NUM= L.FILE_NUM) LIC_TYPES
	,	PRIMARY_LICENSEE
	,	PREM_STREET_ADDRESS_1
	, PREM_STREET_ADDRESS_2
	, DBA
	,	MAILING_ADDRESS_1
	, MAILING_ADDRESS_2
	FROM LICENSETYPES L
	;
  
  ctx := dbms_xmlgen.newContext (cur_recs);
  dbms_xmlgen.setRowTag (ctx, 'RESULT');
  dbms_xmlgen.setRowSetTag (ctx, 'ROOT');
  dbms_xmlgen.setPrettyPrinting (ctx, false);

  retval := dbms_xmlgen.getXMLType (ctx);

  dbms_xmlgen.closeContext (ctx);

  IF (retval IS NOT NULL) THEN 
    p_reportdata := clob2blob(retval.GETCLOBVAL());
      
  ELSE
    p_message := 'No data returned';
  END IF;
  
  EXCEPTION
	WHEN NO_DATA_FOUND THEN 
	  p_message := 'No records found for Surrendered Licenses Report.';

	WHEN TOO_MANY_ROWS THEN 
	  p_message := 'LQS Data Error - Too many rows returned for Surrendered Licenses Report.' ; 
	   
	WHEN OTHERS THEN 
	  p_message := 'Error in Surrendered_Licenses.'; 

	END Licensed_Importers;  -- LQS report 19

	--------------------------------------------------------
	PROCEDURE Finalized_Legal_Date_List  -- LQS report 26 
	--------------------------------------------------------
	( p_parameters IN  XMLTYPE
	, p_reportdata OUT BLOB
	, p_message    OUT VARCHAR)
	IS

  cur_recs        SYS_REFCURSOR;
  retval          XMLTYPE := xmltype('<ROOT></ROOT>');
  ctx             dbms_xmlgen.ctxHandle;
	
  BEGIN

  OPEN cur_recs FOR 
  SELECT TO_CHAR(ENDDATE,'MM/DD/YYYY') WEEK_ENDING  
  FROM LQS_REPORTS_DATA
  WHERE REPORT_NAME ='Legal Actions Filed'
  GROUP BY ENDDATE
  ORDER BY ENDDATE DESC;

  ctx := dbms_xmlgen.newContext (cur_recs);
  dbms_xmlgen.setRowTag (ctx, 'RESULT');
  dbms_xmlgen.setRowSetTag (ctx, 'ROOT');
  dbms_xmlgen.setPrettyPrinting (ctx, false);

  retval := dbms_xmlgen.getXMLType(ctx);
  
  dbms_xmlgen.closeContext (ctx);

  IF (retval IS NOT NULL) THEN 
    p_reportdata := clob2blob(retval.GETCLOBVAL());
      
  ELSE
    p_message := 'no data returned';
  END IF;

  EXCEPTION
	WHEN NO_DATA_FOUND THEN 
	  p_message := 'No records found for Surrendered Licenses Report.';

	WHEN TOO_MANY_ROWS THEN 
	  p_message := 'LQS Data Error - Too many rows returned for Surrendered Licenses Report.' ; 
	   
	WHEN OTHERS THEN 
	  p_message := 'Error in Surrendered_Licenses.'; 

  END Finalized_Legal_Date_List; -- LQS report 26 

END LQS_LICENSING_REPORTS;
/
