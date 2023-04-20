CREATE OR REPLACE PACKAGE BODY ABCLQS.LQS_Alcohol_To_Go
AS
    -- **************************************************************************
    -- File:        LQS_COCTAILS.PKB
    -- Author:      Ning Wong
    --
    -- Description: API for the Coctails To Go project
    --
    --
    -- History:
    -----------------------------------------------------------------------------
    --    Date                  Comment
    -- 12/06/2021 Created
    -- 01/05/2021 KP Removed type 87
    -- 01/05/2021 NW Version 2 to fix Netsparker finds
    -- **************************************************************************

-----------------------------
PROCEDURE Alcohol_To_Go(
-----------------------------
	a_parameters IN XMLTYPE, 
	a_reportdata OUT BLOB, 
	a_message OUT VARCHAR
)
IS
	t_validLicense VARCHAR2(1) := 'N'; 

BEGIN
	CASE
		WHEN a_parameters.EXISTSNODE('/ROOT/REQUEST') = 1 THEN
			GET_LICENSE(
				a_parameters => a_parameters,
				a_reportdata => a_reportdata,
				a_message    => a_message
			);
		WHEN a_parameters.EXISTSNODE('/ROOT/UPDATE') = 1 THEN
			UPDATE_LICENSE(
				a_parameters => a_parameters,
				a_reportdata => a_reportdata,
				a_message    => a_message
			);
		ELSE
			a_message := 'Invalid Parameter Node';
	END CASE;
END Alcohol_To_Go;

-----------------------------
PROCEDURE GET_LICENSE(
-----------------------------
	a_parameters IN XMLTYPE, 
	a_reportdata OUT BLOB, 
	a_message OUT VARCHAR
)
IS

	l_xmlclob       CLOB;
	l_xml           XMLTYPE;
	l_LicenseNumber VARCHAR2(10);

  l_valid_license       NUMBER(1) :=0;  -- count of valid license number
	l_valid_licenseTypes  NUMBER :=0;   	-- count of eligible license types
  l_received NUMBER := 0;     					-- count of log entries recieved  

  l_message VARCHAR2(100);  -- error message
  l_alcoholtogo_noi LICENSE.ALCOHOLTOGO_NOi%TYPE;

	
BEGIN

  SELECT 
		TRIM(EXTRACTVALUE(a_parameters, '/ROOT/REQUEST/LICENSE')) 
	INTO l_licensenumber 
	FROM DUAL;

  -- Check for valid license
  SELECT COUNT(1) count INTO l_valid_license 
  FROM ABCLQS.LICENSE
  WHERE licenseNumber = l_licenseNumber;

  -- Check for valid license types
  SELECT COUNT(1) INTO l_valid_licenseTypes
  FROM ALL_LICENSES
  WHERE licenseNO = l_licenseNumber
  AND LICENSE_TYPE_CODE IN ('01','02','23','41','47','49','59','62','74','75') -- KP Removed type 87
  AND TYPE_STATUS_CODE IN ('ACTIVE','R64B','REVPEN','SLMSRV','SUREND','SUSPEN');
  
  -- Check to see if LOI was received in the log or in ABIS
	SELECT COUNT(1) COUNT
	INTO l_received
	FROM LICENSE L
	LEFT JOIN ALCOHOL_NOI_LOG A ON A.LICENSENUMBER = L.LICENSENUMBER
	WHERE L.LICENSENUMBER=l_licenseNumber
		AND (A.ALCOHOLTOGO_NOI ='Y' OR L.ALCOHOLTOGO_NOI='Y');

  IF l_valid_license = 0 THEN
    l_message:='Invalid license number.';
  ELSIF l_valid_licenseTypes = 0 THEN
    l_message:= 'License does not have any eligible license types.';
  ELSIF l_received > 0 THEN  
    l_message := 'Letter of Intent has been previously received.';
  END IF;
  
  IF l_message IS NOT NULL THEN   
    SELECT 
			XMLELEMENT(
				"ROOT", 
				XMLELEMENT(
					"RESULT", 
					XMLELEMENT(
						"MESSAGE", 
						l_message
					)
				)
			) 
			INTO l_xml
		FROM DUAL;  

  ELSE -- Create error message
    WITH LICENSES AS (
        SELECT 
          L.LICENSENUMBER, L.LICENSEE, L.STATUSNAME
        , L.ALCOHOLTOGO_NOI
        , L.ALCOHOLTOGO_NOI_RECEIVED
        FROM LICENSE L
    )
    SELECT 
      XMLELEMENT(
        "ROOT",
        XMLELEMENT(
          "RESULT",
          XMLFOREST(
            L.LICENSENUMBER,
            L.LICENSEE,
            L.ALCOHOLTOGO_NOI,
            NVL(TO_CHAR(ALCOHOLTOGO_NOI_RECEIVED,'MM/DD/YYYY') ,' ') ALCOHOLTOGO_NOI_RECEIVED,
           ( GET_LICENSE_TYPES(L.LICENSENUMBER)) LICENSETYPES 
          )
        )
      )
    INTO l_xml
    FROM LICENSES L
    WHERE L.LicenseNumber=l_licensenumber;

  END IF;
  a_reportdata := lqs.clob2blob ( l_xml.GETCLOBVAL() ); 
  a_message := NULL;

EXCEPTION
  WHEN NO_DATA_FOUND THEN
    BEGIN
      a_message:= 'License '|| l_licensenumber || ' not found';
      DBMS_OUTPUT.PUT_LINE(a_message);
    END;

END GET_LICENSE;


----------------------------
FUNCTION GET_LICENSE_TYPES( 
----------------------------
  p_LicenseNumber VARCHAR2
)
RETURN XMLTYPE IS
  l_xml XMLTYPE;

BEGIN

  SELECT 
    XMLAGG(
      XMLELEMENT(
        "LICENSETYPE",
        XMLFOREST(  
          LT.LICENSE_TYPE_CODE LICENSETYPECODE,
          UPPER(C.LICENSETYPENAME) LICENSETYPENAME,
          CASE 
            WHEN type_status_code IN ('ACTIVE','R64B','REVPEN','SLMSRV','SUREND','SUSPEN') 
            THEN 'Y' 
            ELSE 'N' 
          END ELIGIBILITY,
          TO_CHAR(TO_DATE(NEXT_ISSUE_DATE),'MM/DD/YYYY') EXPIRATIONDATE
        )
      )
    ) LICENSE_TYPES
  
  INTO l_xml   
  FROM ALL_LICENSES LT 
  JOIN LICENSETYPECATEGORY C ON C.LICENSETYPECODE=LT.LICENSE_TYPE_CODE
  WHERE LT.LICENSENO = p_LicenseNumber
    AND LICENSE_TYPE_CODE IN ('01','02','23','41','47','49','59','62','74','75') 
    -- AND	TYPE_STATUS_CODE IN ('ACTIVE','R64B','REVPEN','SLMSRV','SUREND','SUSPEN') 
  ORDER BY LT.LICENSE_TYPE_CODE;

RETURN l_xml;
END GET_LICENSE_TYPES;

--------------------------
PROCEDURE UPDATE_LICENSE(
--------------------------
	a_parameters IN XMLTYPE, 
	a_reportdata OUT BLOB, 
	a_message OUT VARCHAR
)
IS
  l_licenseNumber VARCHAR2(30); 
  l_AlcoholNOI VARCHAR2(1);
  l_AlcoholNOI_Effective VARCHAR2(10);
  l_Name VARCHAR2(100);
  l_Email VARCHAR2(200);    

--  l_received NUMBER(9);
 
  l_jobid NUMBER :=0;   -- ABIS objectid
  l_noi   VARCHAR2(1);  -- Alcohol Notice Of Intent flag in ABIS     
  l_received VARCHAR2(1);      -- Received 

BEGIN
	DBMS_OUTPUT.PUT_LINE('Update');

  SELECT 
		TRIM(EXTRACTVALUE(a_parameters,'/ROOT/UPDATE/LICENSE')),
		TRIM(EXTRACTVALUE(a_parameters,'/ROOT/UPDATE/ALCOHOLNOI')),
		TRIM(EXTRACTVALUE(a_parameters,'/ROOT/UPDATE/ALCOHOLNOI_EFFECTIVE')),
		TRIM(EXTRACTVALUE(a_parameters,'/ROOT/UPDATE/NAME')),
		TRIM(EXTRACTVALUE(a_parameters,'/ROOT/UPDATE/EMAIL'))
	INTO 
    l_licensenumber	, 
    l_AlcoholNOI, 
    l_AlcoholNOI_Effective,
    l_name,
    l_email
	FROM DUAL;

/*
	SELECT COUNT(1) COUNT
	INTO l_received
	FROM LICENSE L
	LEFT JOIN ALCOHOL_NOI_LOG A ON A.LICENSENUMBER = L.LICENSENUMBER
	WHERE L.LICENSENUMBER=l_licenseNumber
		AND (A.ALCOHOLTOGO_NOI ='Y' OR L.ALCOHOLTOGO_NOI='Y');
*/		
  -- Check to see if LOI was received in the log or in ABIS
  BEGIN
    DBMS_OUTPUT.PUT_LINE('The fun begins');
    SELECT 
      L.JOBID
    , L.ALCOHOLTOGO_NOI
    , A.ALCOHOLTOGO_NOI RECEIVED
    INTO 
      l_jobid
    , l_noi
    , l_received
    FROM LICENSE L
    LEFT JOIN ALCOHOL_NOI_LOG A ON A.LICENSENUMBER = L.LICENSENUMBER
    WHERE L.LICENSENUMBER =  l_licenseNumber
    AND L.LICENSENUMBER IN (
      SELECT LT.LICENSENO 
      FROM ALL_LICENSES LT 
      WHERE LT.LICENSENO=L.LICENSENUMBER 
        AND LT.TYPE_STATUS_CODE IN ('ACTIVE','R64B','REVPEN','SLMSRV','SUREND','SUSPEN')
    );
    DBMS_OUTPUT.PUT_LINE('l_jobid: '|| l_jobid);
    DBMS_OUTPUT.PUT_LINE('l_noi: ' || l_noi);
    DBMS_OUTPUT.PUT_LINE('l_received: ' || l_received);

  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      l_jobid := 0;
      DBMS_OUTPUT.PUT_LINE('No data found.');
  END;		

  IF l_jobid = 0 THEN
    DBMS_OUTPUT.PUT_LINE('You need a jobId.');
  ELSIF l_noi = 'Y' THEN 
    DBMS_OUTPUT.PUT_LINE('ABIS LOI was already flagged');
  ELSIF l_received ='Y' THEN
    DBMS_OUTPUT.PUT_LINE('LOI has already been received.');
  ELSE
    BEGIN
      INSERT INTO ABCLQS.ALCOHOL_NOI_LOG (
        OBJECTID,
        LICENSENUMBER,          
        ALCOHOLTOGO_NOI,           
        ALCOHOLTOGO_NOI_RECEIVED,  
        NAME,
        EMAIL
      )
      SELECT 
        ALCOHOL_NOI_LOG_SEQ.NEXTVAL,
        TRIM(EXTRACTVALUE(a_parameters,'/ROOT/UPDATE/LICENSE')),
        TRIM(EXTRACTVALUE(a_parameters,'/ROOT/UPDATE/ALCOHOLNOI')),
        SYSDATE,
        TRIM(EXTRACTVALUE(a_parameters,'/ROOT/UPDATE/NAME')),
        TRIM(EXTRACTVALUE(a_parameters,'/ROOT/UPDATE/EMAIL'))
      FROM DUAL;
      COMMIT;
    END;
  END IF;

END UPDATE_LICENSE;

END LQS_Alcohol_To_Go;
/
