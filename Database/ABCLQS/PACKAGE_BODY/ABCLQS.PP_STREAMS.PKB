CREATE OR REPLACE PACKAGE BODY ABCLQS.PP_STREAMS AS
-- ****************************************************************************
-- File:        PP_STREAMS.pkb  
-- Author:      Ning Wong    
--
-- $Rev:  $  
-- $Date: $
-- Last Changed By:  $Author: nwong $
--
-- Description: Price Posting Extracts       
--	
--  
--	
-- Date Created.....02/27/2020
-- Main procedure...LQS.Main
--	
-- Category		rpttype	Reports
		
-- ---------- -------	-------
--					  27		  Price Posting Legal Entity CSV Extract
--					  28		  Price Posting Legal Entity CSV Extract

-- History:
-------------------------------------------------------------------------------
-- Date            Comment
-- 02/25/2020 NW   Add Price Posting Legal Entities CSV Extract report 27
-- ****************************************************************************

---------------------------------------------------
PROCEDURE LEGAL_ENTITY_CSV ( -- LQS report 27
---------------------------------------------------	
  p_parameters IN  XMLTYPE, 
  p_reportdata OUT BLOB, 
  p_message    OUT VARCHAR
)

IS
  cur_recs SYS_REFCURSOR;
  l_clob clob;

  l_Status_Date     VARCHAR2(10);
  l_Status_dt       DATE;
	
BEGIN

  SELECT TRIM(REPLACE(EXTRACTVALUE(p_parameters, '//STATUS_DATE'), '%20', '')) INTO l_Status_Date FROM DUAL;

  IF l_Status_Date IS NOT NULL THEN
    l_Status_dt := TO_DATE(l_Status_Date,'MM/DD/YYYY');
  ELSE
    SELECT MIN(STATUSDATE) INTO l_Status_dt FROM ABCLQS.PP_LEGAL_ENTITY;
  END IF;

  DBMS_OUTPUT.PUT_LINE('Status Date: ' || l_Status_dt);

	DBMS_LOB.CREATETEMPORARY(L_CLOB,TRUE);

	FOR C1 IN (
    WITH LE AS (
      SELECT 
        1 ROWORDER
      , 'LICENSEE,LICENSE_TYPE,PREM_ADDRESS,PREM_CITY,PREM_STATE,PREM_ZIP,MAIL_ADDRESS,MAIL_CITY,MAIL_STATE,MAIL_ZIP,EMAIL,STATUS_DATE' || CHR(10) AS CSV_LINE 
      FROM DUAL
      UNION
      SELECT DISTINCT 
        2 ROWORDER
      , '"'||REPLACE(REPLACE(TRIM(LE.PRIMARYLICENSEE), CHR(10),''),CHR(13),'') || '","' ||
        TRIM(LE.LICENSETYPE)     || '","' || 
        TRIM(LE.PREM_ADDRESS)    || '","' ||
        TRIM(LE.PREM_CITY)       || '","' ||
        TRIM(LE.PREM_STATE)      || '","' ||
        TRIM(LE.PREM_ZIP)        || '","' ||

        TRIM(LE.MAIL_ADDRESS)    || '","' ||
        TRIM(LE.MAIL_CITY)       || '","' ||
        TRIM(LE.MAIL_STATE)      || '","' ||
        TRIM(LE.MAIL_ZIP)        || '","' ||
        TRIM(LE.EMAIL)           || '","' || 
        TO_CHAR(STATUSDATE,'MM/DD/YYYY') ||'"'|| CHR(10)
        AS CSV_LINE      
      FROM ABCLQS.PP_LEGAL_ENTITY LE
      WHERE STATUSDATE >= l_Status_dt
--      and rownum < 3
      
    )
    SELECT CSV_LINE
    FROM LE
    ORDER BY ROWORDER, CSV_LINE
  )  -- END C1
	LOOP
	  DBMS_LOB.WRITEAPPEND(l_clob, LENGTH(C1.CSV_LINE), C1.CSV_LINE);    
	END LOOP;
	p_reportdata := ABCLQS.clob2blob(l_clob);

EXCEPTION
WHEN NO_DATA_FOUND THEN 
  p_message := 'No records found for PP_STREAMS.LEGAL_ENTITY_CSV.';

WHEN TOO_MANY_ROWS THEN 
  p_message := 'LQS Data Error - Too many rows returned for PP_STREAMS.LEGAL_ENTITY_CSV.' ; 

WHEN OTHERS THEN 
  p_message := 'Error in PP_STREAMS.LEGAL_ENTITY_CSV.'; 

----------------------------------------
END LEGAL_ENTITY_CSV;  -- LQS report 27
----------------------------------------

---------------------------------------------------
PROCEDURE LEGAL_ENTITY_XML -- LQS report 28
---------------------------------------------------
(	
  p_parameters IN  XMLTYPE, 
  p_reportdata OUT BLOB, 
  p_message    OUT VARCHAR
)

IS
  l_Status_Date VARCHAR2(10);
  l_Status_dt DATE;

  cur_recs SYS_REFCURSOR;
  ctx dbms_xmlgen.ctxHandle;
  retval  XMLTYPE := xmltype('<ROOT></ROOT>');
  lxml_pi XMLTYPE;
	
BEGIN
  SELECT TRIM(REPLACE(EXTRACTVALUE(p_parameters, '//STATUS_DATE'), '%20', '')) INTO l_Status_Date FROM DUAL;

  IF l_Status_Date IS NOT NULL THEN
    l_Status_dt := TO_DATE(l_Status_Date,'MM/DD/YYYY');
  ELSE
    SELECT MIN(STATUSDATE) INTO l_Status_dt FROM ABCLQS.PP_LEGAL_ENTITY;
  END IF;

  OPEN cur_recs FOR 
  SELECT DISTINCT 
    REPLACE(REPLACE(TRIM(LE.PRIMARYLICENSEE), CHR(10),''),CHR(13),'') PRIMARYLICENSEE,
    TRIM(LE.LICENSETYPE) LICENSETYPE, 
    TRIM(LE.PREM_ADDRESS) PREM_ADDRESS,
    TRIM(LE.PREM_CITY) PREM_CITY,
    TRIM(LE.PREM_STATE) PREM_STATE,
    TRIM(LE.PREM_ZIP) PREM_ZIP,

    TRIM(LE.MAIL_ADDRESS) MAIL_ADDRESS,
    TRIM(LE.MAIL_CITY) MAIL_CITY,
    TRIM(LE.MAIL_STATE) MAIL_STATE,
    TRIM(LE.MAIL_ZIP) MAIL_ZIP,
    TRIM(LE.EMAIL) EMAIL, 
    TO_CHAR(STATUSDATE,'MM/DD/YYYY') STATUSDATE
  FROM ABCLQS.PP_LEGAL_ENTITY LE
  WHERE STATUSDATE>=l_Status_dt
    and primarylicensee like '%&%' 
--  and rownum < 8
  ;

  ctx := dbms_xmlgen.newContext (cur_recs);
  dbms_xmlgen.setRowTag (ctx, 'RESULT');
  dbms_xmlgen.setRowSetTag (ctx, 'ROOT');
  dbms_xmlgen.setPrettyPrinting (ctx, false);

  retval := dbms_xmlgen.getXMLType (ctx);
  dbms_xmlgen.closeContext (ctx);

	SELECT XMLPI(NAME "xml-stylesheet", 'href="../Formats/LicenseList.xslt" type="text/xsl"') INTO lxml_pi FROM DUAL;

  IF (retval IS NOT NULL) THEN 
    p_reportdata := clob2blob(retval.GETCLOBVAL());
      
  ELSE
    p_message := 'no data returned';
  END IF;

EXCEPTION
WHEN NO_DATA_FOUND THEN 
  p_message := 'No records found for PP_STREAMS.LEGAL_ENTITY_CSV.';

WHEN TOO_MANY_ROWS THEN 
  p_message := 'LQS Data Error - Too many rows returned for PP_STREAMS.LEGAL_ENTITY_CSV.' ; 

WHEN OTHERS THEN 
  p_message := 'Error in PP_STREAMS.LEGAL_ENTITY_CSV.'; 

----------------------------------------
END LEGAL_ENTITY_XML;  -- LQS report 28
----------------------------------------

-------------------------------------
END PP_STREAMS;  -- PACKAGE BODY
-------------------------------------
/
