CREATE OR REPLACE PACKAGE BODY ABC.PKG_PRICE_POSTINGS AS
-- ****************************************************************************
-- File:        PKG_PRICE_POSTINGS.pkb        
-- Author:      Ning Wong
--
-- Description:    
--
-- 
-- History:
-------------------------------------------------------------------------------
--    Date                      Comment
-- 05/28/2021 NW            Price Posting Licensees data export
--
-- ****************************************************************************

------------------------
PROCEDURE LOAD_LICENSEES -- Insert Master Licensees into reporting table ABC.PP_LICENSEES
------------------------
IS
BEGIN

	DELETE FROM ABC.PP_LICENSEES;
	COMMIT;

	INSERT INTO ABC.PP_LICENSEES (
	 PRIMARYLICENSEE,                
	 EMAIL,              
	 LICENSETYPE,                 
	 PREM_ADDRESS,               
	 PREM_CITY,                
	 PREM_STATE,                 
	 PREM_ZIP,                 
	 PREM_COUNTRY,               
	 MAIL_ADDRESS,               
	 MAIL_CITY,                
	 MAIL_STATE,                 
	 MAIL_ZIP,                 
	 MAIL_COUNTRY,               
	 STATUSDATE,                        
	 PROCESSDATE                        
	)

	WITH LT AS ( 
		SELECT
			LT.LICENSENUMBER 
		, LT.STATUSDATECORRAL STATUSDATE
		, L.ThisLicenseIsP12AMaster
		, L.P12MASTERLICENSENO
		, L.ThisLicenseIsP12Master
		, L.P12AMasterLicenseNo

		-- Factor the master license for grouping 
		, CASE
			WHEN L.ThisLicenseIsP12Master ='Y' OR L.ThisLicenseIsP12aMaster ='Y' THEN LT.LICENSENUMBER
			WHEN L.ThisLicenseIsP12Master ='N' AND L.P12MasterLicenseNo IS NOT NULL THEN P12MasterLicenseNo
			WHEN L.ThisLicenseIsP12aMaster ='N' AND L.P12aMasterLicenseNo IS NOT NULL THEN SUBSTR(L.P12aMasterLicenseNo,1,6)
			WHEN L.ThisLicenseIsP12Master ='N' OR L.ThisLicenseIsP12aMaster ='N' THEN LT.LICENSENUMBER
			END MasterLicense
	 
		, LT.LICENSETYPECODE LICENSETYPE
		, LT.STATUSNAME
		
		FROM MART.LICENSETYPE LT
		JOIN MART.LICENSE L ON L.EXTERNALFILENUM = LT.LICENSENUMBER

		WHERE LT.LICENSETYPECODE IN ('01','23','26','75','17','10')
		AND LT.STATUSNAME IN ('ACTIVE','REVPEN','SLMSHD','SUSPEN','R64B','SUREND')
	) -- END WITH LT

	, LICENSEES AS ( 
		SELECT DISTINCT
			L.JOBID
		, LT.MASTERLICENSE
		, REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(TRIM(L.PRIMARYLICENSEE),CHR(13)),CHR(10)),','),'.'),'/',' '),'  ',' ') PRIMARYLICENSEE
		, LT.LICENSETYPE
		, TO_DATE(TO_CHAR(LT.STATUSDATE,'MM/DD/YYYY'),'MM/DD/YYYY') STATUSDATE
		, ML.JOBOBJECTID MAILID
		, E.EMAILADDRESS EMAIL

		FROM LT
		JOIN MART.LICENSE L ON L.EXTERNALFILENUM=LT.MASTERLICENSE
		-- Mailing Address
		LEFT JOIN MART.BUSINESSMAILINGLOCATIONS ML ON ML.JOBOBJECTID = L.JOBID
		LEFT JOIN MART.ADDRESS MA ON MA.OBJECTID = ML.ADDRESSOBJECTID
		-- Email
		LEFT JOIN QUERY.R_EMAILSLICENSE R ON R.LICENSEJOBID=L.JOBID
		LEFT JOIN QUERY.O_EMAILS E ON E.OBJECTID = R.EMAILOBJECTID AND E.EMAILTYPE = 'Beer Price Posting Email'
		
		ORDER BY PRIMARYLICENSEE 
	) -- WITH LICENSEES

	-- Distinct PRIMARY LICENSEE, LICENSETYPE
	, G1 AS (
			SELECT
				PRIMARYLICENSEE
			, LICENSETYPE
			, MIN(MASTERLICENSE ) MASTERLICENSE
			, MAX(STATUSDATE) STATUSDATE    
			, MAX(EMAIL) EMAIL
			, MAX(MAILID) MAILID
			FROM LICENSEES
			GROUP BY PRIMARYLICENSEE, LICENSETYPE 
			ORDER BY PRIMARYLICENSEE, LICENSETYPE
		)
	 
	SELECT DISTINCT
		G1.PRIMARYLICENSEE
	, G1.EMAIL
	, G1.LICENSETYPE
	, A.ADDRESSLINE1|| ' ' ||A.ADDRESSLINE2 PREM_ADDRESS
	, NVL(A.CACITY, A.USACITY) PREM_CITY
	, A.USASTATECODE PREM_STATE
	, A.ZIPCODE PREM_ZIP
	, A.COUNTRY
	, MA.ADDRESSLINE1|| ' ' ||MA.ADDRESSLINE2 MAIL_ADDRESS
	, NVL(MA.CACITY, MA.USACITY) MAIL_CITY
	, MA.USASTATECODE MAIL_STATE
	, MA.ZIPCODE MAIL_ZIP
	, MA.COUNTRY
	, G1.STATUSDATE
	, SYSDATE PROCESSDATE
	FROM G1 
	JOIN LICENSEES L ON L.MASTERLICENSE=G1.MASTERLICENSE

	LEFT JOIN MART.BUSINESSLOCATIONS BL ON BL.JOBOBJECTID = L.JOBID
	LEFT JOIN MART.ADDRESS A ON A.OBJECTID = BL.ADDRESSOBJECTID
		
	LEFT JOIN MART.BUSINESSMAILINGLOCATIONS ML ON ML.JOBOBJECTID = L.MAILID
	LEFT JOIN MART.ADDRESS MA ON MA.OBJECTID = ML.ADDRESSOBJECTID

	ORDER BY PRIMARYLICENSEE, LICENSETYPE;
	COMMIT;

	UPDATE ABC.PP_LICENSEES SET PREM_COUNTRY='UNITED STATES' WHERE PREM_COUNTRY='UNITED STATES OF AMERICA';
	UPDATE ABC.PP_LICENSEES SET MAIL_COUNTRY='UNITED STATES' WHERE MAIL_COUNTRY='UNITED STATES OF AMERICA';
	COMMIT;

END LOAD_LICENSEES;


--------------------------------------------------------------------------------------
PROCEDURE GET_LICENSEES (               -- Get Licensee list that have updated status  	
--------------------------------------------------------------------------------------
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

END GET_LICENSEES;

-- Email Licensee list 
-------------------------------------------------------
PROCEDURE SEND_EMAIL (
-------------------------------------------------------
  p_to          IN VARCHAR2,    -- Send email to
  p_from        IN VARCHAR2,    -- email from   
  p_subject     IN VARCHAR2,    --  
  p_text_msg    IN VARCHAR2 DEFAULT NULL,
  p_attach_name IN VARCHAR2 DEFAULT NULL,  -- Attachment name
  p_attach_mime IN VARCHAR2 DEFAULT NULL,   
  p_attach_clob IN CLOB     DEFAULT NULL   -- The body of the attachment stored in a blob
)

IS
  
  l_mail_conn   UTL_SMTP.connection;
  l_smtp_host   VARCHAR2(30);
  l_smtp_port   NUMBER := 25;
  l_boundary    VARCHAR2(50) := '----=*#abc1234321cba#*=';
  l_step        PLS_INTEGER  := 12000; -- make sure you set a multiple of 3 not higher than 24573

BEGIN

  SELECT VALUE INTO l_smtp_host
  FROM API.constants
  WHERE name = 'SMTPSERVER';
  
  l_mail_conn := UTL_SMTP.open_connection(l_smtp_host, l_smtp_port);
  UTL_SMTP.helo(l_mail_conn, l_smtp_host);
  UTL_SMTP.mail(l_mail_conn, p_from);
  UTL_SMTP.rcpt(l_mail_conn, p_to);

  UTL_SMTP.open_data(l_mail_conn);
  
  UTL_SMTP.write_data(l_mail_conn, 'Date: ' || TO_CHAR(SYSDATE, 'DD-MON-YYYY HH24:MI:SS') || UTL_TCP.crlf);
  UTL_SMTP.write_data(l_mail_conn, 'To: ' || p_to || UTL_TCP.crlf);
  UTL_SMTP.write_data(l_mail_conn, 'From: ' || p_from || UTL_TCP.crlf);
  UTL_SMTP.write_data(l_mail_conn, 'Subject: ' || p_subject || UTL_TCP.crlf);
  UTL_SMTP.write_data(l_mail_conn, 'Reply-To: ' || p_from || UTL_TCP.crlf);
  UTL_SMTP.write_data(l_mail_conn, 'MIME-Version: 1.0' || UTL_TCP.crlf);
  UTL_SMTP.write_data(l_mail_conn, 'Content-Type: multipart/mixed; boundary="' || l_boundary || '"' || UTL_TCP.crlf || UTL_TCP.crlf);
  
  IF p_text_msg IS NOT NULL THEN
    UTL_SMTP.write_data(l_mail_conn, '--' || l_boundary || UTL_TCP.crlf);
    UTL_SMTP.write_data(l_mail_conn, 'Content-Type: text/plain; charset="iso-8859-1"' || UTL_TCP.crlf || UTL_TCP.crlf);

    UTL_SMTP.write_data(l_mail_conn, p_text_msg);
    UTL_SMTP.write_data(l_mail_conn, UTL_TCP.crlf || UTL_TCP.crlf);
  END IF;

  IF p_attach_name IS NOT NULL THEN
    UTL_SMTP.write_data(l_mail_conn, '--' || l_boundary || UTL_TCP.crlf);
    UTL_SMTP.write_data(l_mail_conn, 'Content-Type: ' || p_attach_mime || '; name="' || p_attach_name || '"' || UTL_TCP.crlf);
    UTL_SMTP.write_data(l_mail_conn, 'Content-Disposition: attachment; filename="' || p_attach_name || '"' || UTL_TCP.crlf || UTL_TCP.crlf);
 
    FOR i IN 0 .. TRUNC((DBMS_LOB.getlength(p_attach_clob) - 1 )/l_step) LOOP
      UTL_SMTP.write_data(l_mail_conn, DBMS_LOB.substr(p_attach_clob, l_step, i * l_step + 1));
    END LOOP;

    UTL_SMTP.write_data(l_mail_conn, UTL_TCP.crlf || UTL_TCP.crlf);
  END IF;
  
  UTL_SMTP.write_data(l_mail_conn, '--' || l_boundary || '--' || UTL_TCP.crlf);
  UTL_SMTP.close_data(l_mail_conn);
  UTL_SMTP.quit(l_mail_conn);

END SEND_EMAIL;

---------------------------------------------------------
PROCEDURE LICENSEES_JOB
---------------------------------------------------------
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
--    'Ning.Wong@abc.ca.gov' 
  );
BEGIN  -- PP_LICENSEES_JOB

  -- RUN ON WEEK DAYS ONLY --
  IF TO_CHAR(SYSDATE,'D') IN (1,7) THEN -- 1=Sunday, 7=Saturday
    RETURN;
  END IF;
  
  DBMS_OUTPUT.PUT_LINE('Loading report table...');
  LOAD_LICENSEES;   -- Load reporting table ABC.PP_LICENSEES with Master Licensees

  DBMS_OUTPUT.PUT_LINE('Getting licensees...');
  -- Get formatted Master Licenses
  GET_LICENSEES (
    l_attachment,
    l_count,
    l_err_msg
  );

-- Email Licensee List
  DBMS_OUTPUT.PUT_LINE('Emailing Licensees...');

  l_subject := 'PP Licensees for ' || l_created_date || ' - ' || TO_CHAR(l_count);
  l_message := TO_CHAR(l_count) || ' licensees for ' || l_created_date;
  l_attach_name := 'Licenses-' || TO_CHAR( SYSDATE, 'YYYY-MM-DD' ) ||'.csv';

  FOR i IN 1..ARRAY.COUNT LOOP
    DBMS_OUTPUT.PUT_LINE(ARRAY(I));

    SEND_EMAIL(
      ARRAY(i),       -- Email list
      l_from,       
      l_subject,             
      l_message,    
      l_attach_name,        
      'text/plain',      
      l_attachment      -- Attachment is a CLOB 
    );
  END LOOP;
  
END LICENSEES_JOB;

END PKG_PRICE_POSTINGS;

/*
SET SERVEROUTPUT ON
EXEC PKG_PRICE_POSTINGS.LICENSEES_JOB;
*/
/
