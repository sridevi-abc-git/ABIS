CREATE OR REPLACE PROCEDURE ABCLQS.LQS_LICENSE
( p_parameters  IN XMLTYPE 
, p_data        OUT BLOB
, p_message     OUT VARCHAR )

IS

  l_license   MART.APPLICATION.EXTERNALFILENUM%TYPE;   
  l_xmlclob   CLOB;
  l_xml_pi    XMLTYPE;
  
BEGIN

  SELECT TRIM(EXTRACTVALUE(p_parameters, '//LICENSE')) INTO l_license FROM DUAL;

  WITH DBA AS
  (
    SELECT 
      LD.LICENSEJOBID JOBID
    , DBA.ACTIVEDBA BUSINESS_NAME
    FROM MART.LICENSEDBA LD 
    JOIN MART.DBANAMES DBA ON DBA.OBJECTID = LD.DBAOBJECTID AND DBA.PRIMARYDBA = 'Y' and DBA.ACTIVE = 'Y'
  )
  , LIC_APP AS 
  ( 
    SELECT 
      JOBID
    , L.ExternalFileNum LICENSE_NUMBER
    , L.StatusName
    , L.BaseFileOfficeId 
    , PrimaryLicensee
    FROM mart.license L 
    WHERE L.ExternalFileNum = l_license
--    WHERE L.ExternalFileNum = '470774' 
--    WHERE L.ExternalFileNum = '4' 
    UNION 
    SELECT  
      OBJECTID JOBID 
    , ap.LICENSENUMBER LICENSE_NUMBER
    , ap.STATUSNAME
    , ap.BASEFILEOFFICEID
    , PrimaryLicensee
    FROM mart.application AP 
    WHERE ap.LicenseExists = 'N' 
      and ap.STATUSNAME in ('PEND', 'ISSUPD', 'DENIED', 'WTHDRN') 
      and ap.LICENSENUMBER = l_license     
--      and ap.LICENSENUMBER = '4'      
  )  -- WITH LIC_APP 
  SELECT 
    XMLELEMENT("LICENSE"
    , XMLFOREST(LA.JOBID
      , LA.LICENSE_NUMBER
      , LA.PRIMARYLICENSEE PRIMARY_OWNER
      , O.OFFICE ABC_OFFICE
      , DBA.BUSINESS_NAME
      , A.ADDRESSLINE1|| ' ' ||A.ADDRESSLINE2 ADDRESS
      , NVL(A.CACITY, A.USACITY) CITY
      , A.USASTATECODE STATE
      , C.COUNTYNAME COUNTY
      , A.ZIPCODE ZIP_CODE
      , TO_CHAR (A.CENSUSTRACT, '0000.00') CENSUS_TRACT

--      , ( GetLicenseeInfo(LA.JOBID)) LICENSEE_INFO
--      , ( GetLicenseTypes(LA.JOBID)) LICENSE_TYPES
      , ( GET_OPERATING_CONDITIONS(LA.JOBID))  OPERATING_RESTRICTIONS
--      , ( GetCurrentDisciplanaryActions(LA.JOBID)) CURRENT_DISCIPLANARY_ACTION
--      , ( GetDisciplanaryHistory(LA.JOBID)) DISCIPLANARY_HISTORY
--      , ( GetHolds(LA.JOBID)) HOLD_INFO
--      , ( GetEscrow(LA.JOBID)) ESCROW
      )
    ).GETCLOBVAL()
  INTO l_xmlclob
  FROM LIC_APP LA
  LEFT JOIN MART.OFFICE O ON O.OBJECTID=LA.BASEFILEOFFICEID
  LEFT JOIN DBA ON DBA.JOBID = LA.JOBID 
  
  LEFT JOIN MART.BUSINESSLOCATIONS BL ON BL.JOBOBJECTID = LA.JOBID
  LEFT JOIN MART.ADDRESS A ON A.OBJECTID = BL.ADDRESSOBJECTID
  LEFT JOIN MART.CACOUNTY C ON C.COUNTYCODE=A.COUNTYCODE;

  SELECT XMLPI(NAME "xml-stylesheet", 'href="../Formats/License.xslt" type="text/xsl"') INTO l_xml_pi FROM DUAL;  
  p_data := clob2blob ( l_xml_pi.GETCLOBVAL()  || l_xmlclob ); 
  p_message := NULL;

--  dbms_output.put_line(l_license);

  EXCEPTION
  WHEN NO_DATA_FOUND THEN 
--    p_message := 'The License Query System has not found any information based on the criteria you have entered. Please go back and try again.'; 
    p_message := 'No records found for license number: ' || l_license;

  WHEN TOO_MANY_ROWS THEN 
    p_message := 'LQS Data Error - Too many rows returned for license number: ' || l_license; 
   
  WHEN OTHERS THEN 
    p_message := 'Error in LQS_LICENSE.'; 

END;
/
