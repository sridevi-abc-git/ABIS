CREATE OR REPLACE FUNCTION ABCLQS.GetCurrentDisciplanaryActions
( p_JobId INTEGER )
RETURN XMLTYPE IS
  l_XML XMLTYPE;

BEGIN

SELECT 
  XMLAGG( XMLELEMENT("REG_NUMBER", A.REGNUMBER))
INTO l_XML
FROM MART.ACCUSATION A
LEFT JOIN MART.LICENSE L ON L.JOBID=A.LICENSEJOBID
WHERE A.LICENSEJOBID =  p_JobId   
  AND A.STATUSNAME NOT IN ('CLOSED', 'DISMSD') 
  AND REGNUMBER IS NOT NULL  
ORDER BY A.REGNUMBER;

RETURN l_XML;
END GetCurrentDisciplanaryActions;


----------------------------------------------------------------------
-- Test Script
----------------------------------------------------------------------
/
