CREATE OR REPLACE PROCEDURE ABC.PP_GET_LICENSEES      
/*--------------------------------------------------------------------------
PROC   : ABC.PP_GET_LICENSEES
AUTHOR : Ning Wong
DATE   : 5/25/2021  
DESCR  : Query to create the Master Licensees list that have updated change status


7/7/2002 - NW OBFUSCATED

---------------------------------------------------------------------------*/
(	
  p_clob    OUT CLOB,                   -- the report data
  p_count   OUT NUMBER,                 -- count of licensees                  
  p_message OUT VARCHAR                 -- message returned       
)

IS

BEGIN

  p_count := -1;  -- subtract 1 for the header row

	DBMS_LOB.CREATETEMPORARY(
    p_clob,
    TRUE
  );

	FOR c1 IN ( 
    WITH LE AS (
      SELECT 
        1 ROWORDER
      , 'Licensee Name,Email,License Type,Premises Address,Premises City,Premises State,Premises Country,Premises Zip Code,Mailing Address,Mailing City,Mailing State,Mailing Country,Mailing Zip Code' || CHR(10) AS CSV_LINE
      FROM DUAL
      UNION
      SELECT DISTINCT 
        2 ROWORDER
      , '"'||REPLACE(REPLACE(TRIM(L.PRIMARYLICENSEE), CHR(10),''),CHR(13),'') || '","' ||
        TRIM(L.EMAIL)           || '","' || 
--        RPAD('',1)               || '","' ||   -- Blank out email 
        TRIM(L.LICENSETYPE)     || '","' || 
        TRIM(L.PREM_ADDRESS)    || '","' ||
        TRIM(L.PREM_CITY)       || '","' ||
        TRIM(L.PREM_STATE)      || '","' ||
        TRIM(L.PREM_COUNTRY)    || '","' ||	        
        TRIM(L.PREM_ZIP)        || '","' ||

        TRIM(L.MAIL_ADDRESS)    || '","' ||
        TRIM(L.MAIL_CITY)       || '","' ||
        TRIM(L.MAIL_STATE)      || '","' ||
        TRIM(L.MAIL_COUNTRY)    || '","' ||	   
        TRIM(L.MAIL_ZIP)        ||'"'|| CHR(10)
        AS CSV_LINE      
      FROM ABC.PP_LICENSEES L

      WHERE STATUSDATE >= TRUNC(
        CASE TO_CHAR(SYSDATE,'D')
          WHEN '1' THEN SYSDATE - 2 -- SUNDAY  
          WHEN '2' THEN SYSDATE - 3 -- MONDAY
          ELSE SYSDATE - 1
        END
      )
--  WHERE STATUSDATE='16-APR-2021'

    )
    SELECT CSV_LINE
    FROM LE
    ORDER BY ROWORDER, CSV_LINE
	)  -- END c1
	LOOP
	  DBMS_LOB.WRITEAPPEND(P_clob, LENGTH(C1.CSV_LINE), C1.CSV_LINE);
	  p_count := p_count + 1;    
	END LOOP;
  DBMS_OUTPUT.PUT_LINE( 'Licensee Count: ' || p_count);

EXCEPTION
  WHEN NO_DATA_FOUND THEN 
    p_message := 'No records found for GET_LICENSEES.';
    p_count := 0;

  WHEN TOO_MANY_ROWS THEN 
    p_message := 'LQS Data Error - Too many rows returned for GET_LICENSEES.' ; 

  WHEN OTHERS THEN 
    p_message := 'Error in GET_LICENSEES.'; 

END;  -- LQS report 23
/
