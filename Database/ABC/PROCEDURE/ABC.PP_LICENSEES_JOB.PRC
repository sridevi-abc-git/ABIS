CREATE OR REPLACE PROCEDURE ABC.PP_LICENSEES_JOB
/*--------------------------------------------------------------------------------
PROC: PROCEDURE ABC.PP_LICENSEES_JOB
DESC: Create the Licensee list that have updated status and email to an email list
AUTHOR : Ning Wong
DATE   : 5/25/2021

TEST SCRIPT: EXEC ABC.PP_LICENSEES_JOB;  
---------------------------------------------------------------------------------*/

IS 
  l_created_date  VARCHAR2(10) := TO_CHAR(SYSDATE,'MM/DD/YYYY');
  l_from          VARCHAR2(40) := 'ABIS';
  l_subject       VARCHAR2(80);
  l_message       VARCHAR2(80);
  l_attach_name   VARCHAR2(80);
  l_attachment    CLOB;
  l_count         NUMBER;
  l_err_msg       VARCHAR2(200);
  
  TYPE l_email_list IS VARRAY(5) OF VARCHAR2(80);
  ARRAY l_email_list := l_email_list(
    'pps@abc.ca.gov'                -- Mailbox for Price Posting System       
  --  'Ning.Wong@abc.ca.gov'
  );
BEGIN  -- PP_LICENSEES_JOB

  -- RUN ON WEEK DAYS ONLY --
  IF TO_CHAR(SYSDATE,'D') IN (1,7) THEN -- 1=Sunday, 7=Saturday
    RETURN;
  END IF;
  
  DBMS_OUTPUT.PUT_LINE('Loading report table...');
  ABC.PP_LICENSEES_LOAD;   -- Load reporting table ABC.PP_LICENSEES with Master Licensees

  DBMS_OUTPUT.PUT_LINE('Getting licensees...');
  ABC.PP_GET_LICENSEES (
    l_attachment,
    l_count,
    l_err_msg
  );

  DBMS_OUTPUT.PUT_LINE('Emailing Licensees...');

  l_subject := 'PP Licensees for ' || l_created_date || ' - ' || TO_CHAR(l_count);
  l_message := TO_CHAR(l_count) || ' licensees for ' || l_created_date;
  l_attach_name := 'Licenses-' || TO_CHAR( SYSDATE, 'YYYY-MM-DD' ) ||'.csv';

  DBMS_OUTPUT.PUT_LINE(l_message);

  FOR i IN 1..ARRAY.COUNT LOOP
    DBMS_OUTPUT.PUT_LINE(ARRAY(I));

    ABC.PP_EMAIL(
      ARRAY(i),       -- Email list
      l_from,       
      l_subject,             
      l_message,    
      l_attach_name,        
      'text/plain',      
      l_attachment      -- Attachment is a CLOB 
    );
  END LOOP;
  
END;  -- PP_LICENSEES_JOB
/
