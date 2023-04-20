CREATE OR REPLACE PACKAGE BODY ABCLQS.LQS_LICENSE_COUNTS AS
-- ****************************************************************************
-- File:        LQS_LICENSE_COUNTS.pkb  
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
--	Date Created.....10/10/2019
--	Main procedure...LQS.Main
--	
--	Category		   rpttype	Reports
--	-------------- -------	-------
--	License Counts 20			  Wholesale By County
--					       21       State Totals
--					       22       Retail by County
--                 23       Retail by Geocode 
-- History:
-------------------------------------------------------------------------------
-- Date                     Comment
-- 10/10/2019 NW   Yearly   Refactored for ADA compliance, added as-of date parameter
-- ****************************************************************************


----------------------------------------------------
PROCEDURE WHOLESALE_BY_COUNTY (   -- LQS report 20  
----------------------------------------------------
	p_parameters IN  XMLTYPE, 
	p_reportdata OUT BLOB, 
	p_message    OUT VARCHAR
)

IS
  l_asof          VARCHAR2(10);
  l_asof_dt       DATE;
  cur_recs        SYS_REFCURSOR;
  retval          XMLTYPE := xmltype('<ROOT></ROOT>');
  ctx             dbms_xmlgen.ctxHandle;

BEGIN

  SELECT TRIM(REPLACE(EXTRACTVALUE(p_parameters, '//ASOF'), '%20', '')) INTO l_asof FROM DUAL;
  l_asof_dt := TO_DATE(l_asof,'MM/DD/YYYY');
  DBMS_OUTPUT.PUT_LINE('WHOLESALE_BY_COUNTY ASOF ' || l_asof_dt);

  OPEN cur_recs FOR
  SELECT * FROM (         -- LicenseTypes
    SELECT 
      UPPER(LT.AREA) AREA
    , LTC.LICENSETYPECODE LICENSETYPE
    FROM MART.LICENSETYPE LT
    JOIN MART.PRIMARYANDSECONDARYLICENCETYPE R ON R.LICENSETYPEOBJECTID = LT.OBJECTID
    JOIN MART.LICENSETYPECATEGORY LTC ON R.LICENSECETYPECATEGORYOBJECTID = LTC.OBJECTID
    JOIN EXTENSION.JOBSTATUSCHANGE J ON LT.OBJECTID = J.JOBID
    WHERE LT.RETAILTYPE IS NULL
    AND R.PRIMARY IS NOT NULL
    AND J.STATUSNAME IN ('ACTIVE','SUREND','SUSPEN','R64B','SLMSHD','REVPEN')
    AND J.EFFECTIVESTARTDATE = ( 
      SELECT MAX(JO.EFFECTIVESTARTDATE)
      FROM EXTENSION.JOBSTATUSCHANGE JO
      WHERE JO.JOBID = J.JOBID
      AND JO.EFFECTIVESTARTDATE < l_asof_dt 
    )
  )
  PIVOT (
    COUNT(1) 
    FOR LICENSETYPE IN (
      '01','02','03','04','05','06','07','08',
      '10','13','14','15','16','17','18','19',
      '22','23','24','25','26','27','28','29',
      '74','79',
      '82','84'
    )
  )
  ORDER BY AREA;

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
	  p_message := 'No records found for Wholesale By County Report.';

	WHEN TOO_MANY_ROWS THEN 
	  p_message := 'LQS Data Error - Too many rows returned for Wholesale By County Report.' ; 
	   
	WHEN OTHERS THEN 
	  p_message := 'Other Error in Wholesale By County.'; 

    
END Wholesale_By_County; 

---------------------------------------------------
PROCEDURE STATE_TOTALS (    -- LQS report 21
---------------------------------------------------
	p_parameters IN  XMLTYPE, 
	p_reportdata OUT BLOB, 
	p_message    OUT VARCHAR
)
IS
  cur_recs        SYS_REFCURSOR;
  l_asof          VARCHAR2(10);
  l_asof_dt       DATE;
  retval          XMLTYPE := xmltype('<ROOT></ROOT>');
  ctx             dbms_xmlgen.ctxHandle;

BEGIN
  SELECT TRIM(REPLACE(EXTRACTVALUE(p_parameters, '//ASOF'), '%20', '')) INTO l_asof FROM DUAL;
  l_asof_dt := TO_DATE(l_asof,'MM/DD/YYYY');
  DBMS_OUTPUT.PUT_LINE('State Totals Count Report asof: ' || l_asof_dt);
	
  OPEN cur_recs FOR
  WITH LT AS ( 
    SELECT
      CASE LTC.RetailType 
      WHEN 'On-Sale' THEN  'ON-SALE LICENSES'
      ELSE 'WHOLESALE AND OFF-SALE LICENSES'
      END RetailType
        
    , 'TYPE ' || LTC.LicenseTypeCode LicenseType
    , LTC.LicenseTypeName 
    , LTC.ObjectId COUNT  -- Display the count 
    , LTC.ObjectId TOTAL  -- Total for the grand total

    FROM MART.LicenseType LT
    JOIN MART.PrimaryAndSecondaryLicenceType R ON R.LicenseTypeObjectId = LT.ObjectId
    JOIN MART.LicenseTypeCategory LTC ON LTC.objectid =  R.licensecetypecategoryobjectid 
    JOIN EXTENSION.JobStatusChange J ON LT.objectid = J.jobid
     AND J.StatusName IN ('ACTIVE','SUREND','SUSPEN','R64B','SLMSHD','REVPEN')
     AND J.effectivestartdate = ( 
      SELECT MAX(JO.effectivestartdate)
      FROM EXTENSION.Jobstatuschange jo
    WHERE JO.Effectivestartdate < l_asof_dt
  --  WHERE JO.Effectivestartdate < '30-jun-2019'
        AND JO.Jobid = J.jobid
    )
    WHERE R.primary IS NOT NULL

    UNION ALL

    SELECT
      CASE LTC2.RetailType 
      WHEN 'On-Sale' THEN  'ON-SALE LICENSES'
      ELSE 'WHOLESALE AND OFF-SALE LICENSES'
      END RetailType  

    , 'TYPE ' || LTC2.LicenseTypeCode LicenseType
    , '* ' || LTC2.LicenseTypeName LICENSETYPENAME
    , LTC2.OBJECTID COUNT
    , NULL TOTAL
    FROM MART.LICENSETYPE LT2 --primary
    JOIN MART.PRIMARYANDSECONDARYLICENCETYPE X ON X.LICENSETYPEOBJECTID = LT2.OBJECTID 
    JOIN SITESPECIFIC.SLTSTATUSCHANGE_T SC ON SC.RELATIONSHIPID = X.RELATIONSHIPID
      AND SC.STATUSNAME IN ('ACTIVE','SUREND','SUSPEN','R64B','SLSMSHD','REVPEN')
      AND SC.EFFECTIVESTARTDATE = ( 
        SELECT MAX(SC2.EFFECTIVESTARTDATE)
        FROM SITESPECIFIC.SLTSTATUSCHANGE_T SC2
        WHERE SC2.RELATIONSHIPID = X.RELATIONSHIPID
          AND sc2.effectivestartdate < l_asof_dt
--          AND SC2.EFFECTIVESTARTDATE < '30-jun-2019'
      )
    JOIN MART.LICENSETYPECATEGORY LTC2 ON LTC2.OBJECTID = X.LICENSECETYPECATEGORYOBJECTID
    JOIN MART.LICENSETYPECATEGORYREL PLT ON PLT.LICENSETYPEOBJECTID = LT2.OBJECTID
    WHERE X.PRIMARY IS NULL --secondary lt's only.
  ) -- END WITH LicenseTypes
  SELECT 
    RetailType 
  , LicenseType 
  , LicenseTypeName
  , COUNT(COUNT) COUNT
  , COUNT(TOTAL) TOTAL
  FROM LT
  GROUP BY 
    RetailType
  , LicenseType
  , LicenseTypeName
  ORDER BY 
    RetailType DESC
  , LicenseType;

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
	  p_message := 'No records found for STATE TOTALS Report.';

	WHEN TOO_MANY_ROWS THEN 
	  p_message := 'LQS Data Error - Too many rows returned for STATE_TOTALS Report.' ; 
	   
	WHEN OTHERS THEN 
	  p_message := 'Error in STATE_TOTALS.'; 

END STATE_TOTALS;
  
---------------------------------------------------
PROCEDURE RETAIL_BY_COUNTY (   -- LQS report 22
---------------------------------------------------
  p_parameters IN  XMLTYPE, 
  p_reportdata OUT BLOB, 
  p_message    OUT VARCHAR
)
IS
  l_asof          VARCHAR2(10);
  l_asof_dt       DATE;
  cur_recs        SYS_REFCURSOR;
  l_district      VARCHAR2(3);
  retval          XMLTYPE := xmltype('<ROOT></ROOT>');
  ctx             dbms_xmlgen.ctxHandle;

BEGIN

  SELECT TRIM(REPLACE(EXTRACTVALUE(p_parameters, '//ASOF'), '%20', '')) INTO l_asof FROM DUAL;
  l_asof_dt := TO_DATE(l_asof,'MM/DD/YYYY');
  DBMS_OUTPUT.PUT_LINE('Retail by County Asof: ' || l_asof_dt);
	
  OPEN cur_recs FOR
  SELECT * FROM (
    SELECT 
      lt.area AREA
    , to_char(ltc.LicenseTypeCode) LICENSETYPE
    FROM mart.licensetype lt
    JOIN mart.primaryandsecondarylicencetype r on r.LICENSETYPEOBJECTID = lt.ObjectId
    JOIN mart.licensetypecategory ltc on r.LICENSECETYPECATEGORYOBJECTID = ltc.ObjectId
    JOIN extension.jobstatuschange j on lt.ObjectId = j.jobid
    WHERE lt.RetailType IS NOT NULL
       AND r.primary is not null
       AND j.StatusName in ('ACTIVE','SUREND','SUSPEN','R64B','SLMSHD','REVPEN')
       AND j.effectivestartdate = (
        SELECT MAX(JO.effectivestartdate)
        FROM extension.jobstatuschange jo
        WHERE jo.effectivestartdate < l_asof_dt
      -- WHERE jo.effectivestartdate < ('30-JUN-2020')
          AND jo.jobid = j.jobid
       )

    UNION ALL

    SELECT 
      lt2.Area AREA
    , TO_CHAR(ltc2.LicenseTypeCode) || '*' LICENSETYPE 
    FROM mart.licensetype lt2
    JOIN mart.primaryandsecondarylicencetype x on x.LICENSETYPEOBJECTID = lt2.objectid 
    JOIN sitespecific.sltstatuschange_t sc on sc.relationshipid = x.RELATIONSHIPID
    JOIN mart.licensetypecategory ltc2 on ltc2.ObjectId = x.LICENSECETYPECATEGORYOBJECTID
    JOIN mart.licensetypecategoryrel plt on plt.LICENSETYPEOBJECTID = lt2.ObjectId
    WHERE x.primary is null --secondary lt's only.
    AND ltc2.RetailType is not null
    AND ltc2.LicenseTypeCode in (47, 48, 57)
    AND sc.statusname in ('ACTIVE','SUREND','SUSPEN','R64B','SLSMSHD','REVPEN')
    AND sc.effectivestartdate = (
      SELECT MAX(SC2.effectivestartdate)
      FROM sitespecific.sltstatuschange_t sc2
      WHERE sc2.relationshipid = x.relationshipid
        AND sc2.effectivestartdate < l_asof_dt
        -- AND sc2.effectivestartdate < '30-JUN-2020'
      )
  ) 
  PIVOT (
    COUNT(1)
    FOR LICENSETYPE IN (
      '20','21',
      '40','41','42','43','44','45','47','47*','48','48*','49',
      '50','51','52','53','54','55','56','57','57*','59',
      '60','61','62','63','64','67','69',
      '70','71','72','75','76','78',
      '80','83','85','86','87'
    )
  )  
  ORDER BY AREA;

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
	  p_message := 'No records found for Retail By County Report.';

	WHEN TOO_MANY_ROWS THEN 
	  p_message := 'LQS Data Error - Too many rows returned for Retail By County Report.' ; 
	   
	WHEN OTHERS THEN 
	  p_message := 'Error in Retail By County Licenses.'; 

END RETAIL_BY_COUNTY;  -- LQS report 21

---------------------------------------------------
PROCEDURE RETAIL_BY_GEOCODE (  -- LQS report 23
---------------------------------------------------
  p_parameters IN  XMLTYPE, 
  p_reportdata OUT BLOB, 
  p_message    OUT VARCHAR
)
IS

  l_asof          VARCHAR2(10);
  l_asof_dt       DATE;
  cur_recs        SYS_REFCURSOR;
  l_district      VARCHAR2(3);
  retval          XMLTYPE := xmltype('<ROOT></ROOT>');
  ctx             dbms_xmlgen.ctxHandle;

BEGIN

  SELECT TRIM(REPLACE(EXTRACTVALUE(p_parameters, '//ASOF'), '%20', '')) INTO l_asof FROM DUAL;
  l_asof_dt := TO_DATE(l_asof,'MM/DD/YYYY');
  DBMS_OUTPUT.PUT_LINE('Retail by Geocode AsOf: ' || l_asof_dt);
	
  OPEN cur_recs FOR
  SELECT * FROM (
    SELECT 
      LT.LicenseGeoCode GEOCODE
    , UPPER(lt.GeocodeArea) AREA
    , TO_CHAR(ltc.LicenseTypeCode) LICENSETYPE
    FROM mart.licensetype lt
    JOIN mart.primaryandsecondarylicencetype r on r.LICENSETYPEOBJECTID = lt.ObjectId
    JOIN mart.licensetypecategory ltc on r.LICENSECETYPECATEGORYOBJECTID = ltc.ObjectId
    JOIN extension.jobstatuschange j on lt.ObjectId = j.jobid
    WHERE lt.RetailType IS NOT NULL
      and r.primary is not null --primary LT's only
      and j.StatusName in ('ACTIVE','SUREND','SUSPEN','R64B','SLMSHD','REVPEN')
      and j.effectivestartdate = (
        SELECT MAX(jo.effectivestartdate)
        FROM extension.jobstatuschange JO
        WHERE jo.effectivestartdate < l_asof_dt
--        WHERE jo.effectivestartdate < '30-JUN-2020' --a_Report_Date
          AND jo.jobid = j.jobid
      )

    UNION ALL

    SELECT 
      UPPER(lt2.GeocodeArea)
    , LT2.LicenseGeoCode
    , TO_CHAR(ltc2.LicenseTypeCode) || '*' LICENSETYPE
    FROM mart.licensetype lt2
    JOIN mart.primaryandsecondarylicencetype x on x.LICENSETYPEOBJECTID = lt2.objectid 
    JOIN sitespecific.sltstatuschange_t sc on sc.relationshipid = x.RELATIONSHIPID
    JOIN mart.licensetypecategory ltc2 on ltc2.ObjectId = x.LICENSECETYPECATEGORYOBJECTID
    JOIN mart.licensetypecategoryrel plt on plt.LICENSETYPEOBJECTID = lt2.ObjectId
    WHERE x.primary is null --secondary lt's only.
      AND ltc2.RetailType is not null
      AND ltc2.LicenseTypeCode IN (
        47,48, 
        57
      )
      AND sc.statusname in ('ACTIVE','SUREND','SUSPEN','R64B','SLSMSHD','REVPEN')
      AND sc.effectivestartdate = (
        SELECT MAX(sc2.effectivestartdate)
        FROM sitespecific.sltstatuschange_t sc2
        WHERE sc2.relationshipid = x.relationshipid
        AND sc2.effectivestartdate < l_asof_dt
    --  AND sc2.effectivestartdate < '30-JUN-2020'
      )
  )
  PIVOT (
    COUNT(1)
    FOR LICENSETYPE IN ( 
      '20','21',
      '40','41','42','43','44','45','47','47*','48','48*','49',
      '50','51','52','53','54','55','56','57','57*','59',
      '60','61','62','63','64','67','69',
      '70','71','72','75','76','78',
      '80','83','85','86','87'
    )
  )   
  ORDER BY GEOCODE, AREA;
  
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
	  p_message := 'No records found for Retail By Geocode Report.';

	WHEN TOO_MANY_ROWS THEN 
	  p_message := 'LQS Data Error - Too many Retail By Geocode Licenses Report.' ; 
	   
	WHEN OTHERS THEN 
	  p_message := 'Error in Retail By Geocode Report.'; 

	END RETAIL_BY_GEOCODE;  -- LQS report 19

END LQS_LICENSE_COUNTS;
/
