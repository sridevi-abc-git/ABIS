CREATE OR REPLACE PACKAGE BODY ABCREPORTS.NOI_ABIS_API 
    -- **************************************************************************
    -- File:        NOI_ABIS_API.PKB
    -- Author:      Ning Wong
    --
    -- Description: Scheduled jobs to update ABCREPORTS and ABIS
    --
    --  LOAD_LQS_LICENSE - Load ABCLQS.LICENSE table from ABIS
    --  UPDATE_ABIS_NOI  - Updates ABIS NOI fields from ABCREPORTS.ALCOHOL_NOI_LOG
    --
    -- History:
    -----------------------------------------------------------------------------
    --    Date                  Comment
    -- 12/06/2021 NW        	Initialization
		-- 01/03/2022 PW          Production fixes
    -- **************************************************************************
AS

---------------------------------------------------------------------
PROCEDURE LOAD_LQS_LICENSE IS -- Load ABCLQS.LICENSE table from ABIS
---------------------------------------------------------------------
BEGIN

  DELETE FROM ABCLQS.LICENSE;
  COMMIT; 

  INSERT INTO ABCLQS.LICENSE (
    JOBID ,
    LICENSENUMBER ,
    LICENSEE ,
    STATUSNAME ,
    ALCOHOLTOGO_NOI 
  , ALCOHOLTOGO_NOI_RECEIVED 
  )
  SELECT 
    L.JOBID
  , L.EXTERNALFILENUM
  , L.PRIMARYLICENSEE
  , L.STATUSNAME

  , API.PKG_COLUMNQUERY.VALUE(
      JOBID,
      'NOTICEOFINTENTRECEIVED'
    ) ALCOHOLTOGO_NOI

  , TO_DATE(
      SUBSTR(
        API.PKG_COLUMNQUERY.VALUE(
          JOBID,
          'EFFECTIVEDATEOFALCOHOLTOGO'
        ),1,10 ),'yyyy-MM-dd')  ALCOHOLTOGO_NOI_RECEIVED

  FROM MART.LICENSE L
  WHERE L.STATUSNAME NOT IN ('CANCEL');
  COMMIT;

  DELETE FROM ABCLQS.LICENSETYPECATEGORY;
  COMMIT;
  INSERT INTO ABCLQS.LICENSETYPECATEGORY
  SELECT LICENSETYPECODE, LICENSETYPENAME FROM MART.LICENSETYPECATEGORY;
  COMMIT;

END;

-----------------------------------------------------------------------------------------------------------------
PROCEDURE UPDATE_ABIS_NOI
-----------------------------------------------------------------------------------------------------------------  
-- Update ABIS query.j_license.NOTICEOFINTENTRECEIVED and EFFECTIVEDATEOFALCOHOLTOGO

IS
  l_errorMsg VARCHAR2(40);

BEGIN
  FOR C1 IN (
    SELECT
      A.OBJECTID
    , L.JOBID
    , A.LICENSENUMBER
    , A.ALCOHOLTOGO_NOI
    , A.NAME
    , A.EMAIL
    , A.ALCOHOLTOGO_NOI_RECEIVED           -- NW 1/5/2022  
    
    FROM ABCLQS.ALCOHOL_NOI_LOG A
    JOIN ABCLQS.LICENSE L ON L.LICENSENUMBER=A.LICENSENUMBER
    WHERE A.LOGGED IS NULL  -- NW 1/5/2022
    ORDER BY A.ALCOHOLTOGO_NOI_RECEIVED DESC
  )	
  LOOP
    BEGIN
      l_errorMsg := NULL;
      api.pkg_ColumnUpdate.SetValue( 
        C1.JOBID,   
        'NOTICEOFINTENTRECEIVED',   
        C1.ALCOHOLTOGO_NOI  
      );
      api.pkg_ColumnUpdate.SetValue( 
        C1.JOBID,   
        'EFFECTIVEDATEOFALCOHOLTOGO',   
        C1.ALCOHOLTOGO_NOI_RECEIVED  
      );
      api.pkg_logicaltransactionupdate.endtransaction;
      COMMIT;
    EXCEPTION
      WHEN OTHERS
      THEN
        DBMS_OUTPUT.PUT_LINE('ABIS Error');

        l_errorMsg:='Error updating ABIS objectid '|| C1.JOBID;
        api.pkg_logicaltransactionupdate.resettransaction;
        ROLLBACK;
    END;
    
    IF l_errorMsg IS NULL THEN
      UPDATE ABCLQS.ALCOHOL_NOI_LOG
      SET LOGGED=SYSDATE
      WHERE OBJECTID=C1.OBJECTID;
      COMMIT;
    ELSE 
      UPDATE ABCLQS.ALCOHOL_NOI_LOG
      SET ERROR_MSG=l_errorMsg
      WHERE OBJECTID=C1.OBJECTID;
      COMMIT;
      
    END IF;

  END LOOP;

--------------------
END UPDATE_ABIS_NOI;
--------------------

END NOI_ABIS_API ;

-- EXEC NOI_ABIS_API.LOAD_LQS_LICENSE;
-- EXEC NOI_ABIS_API.UPDATE_ABIS_NOI;
/
