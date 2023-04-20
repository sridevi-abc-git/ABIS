CREATE OR REPLACE PACKAGE BODY SITESPECIFIC.PKG_TLEMAIL AS
-- ****************************************************************************
-- File:        PKG_TLEMAI.pkb  
-- Author:      Timothy J. Lord
--
-- $Rev: 2510 $  
-- $Date: 2016-03-20 15:50:16 -0700 (Sun, 20 Mar 2016) $
-- Last Changed By:  $Author: tlord $
--
-- Description: PKG_TLEMAI package specifications   
--
-- Functions:    stmt_to_csv()
--
-- History:
-------------------------------------------------------------------------------
--    Date         Ticket     Comment
-- 05/22/2014 TJL   1924  Original file created
-- 03/17/2016 TJL   9242  Added test for not sending email with no to address 
-- 10/26/2022 Pk    Changed DB name to ABISP1 in line  IF (UPPER(lv_db_name) != 'ABCPROD') THEN
-- ****************************************************************************
  gc_Newline constant char(2) := chr(13)||chr(10);

  BOUNDARY constant varchar2(256) := '-----7D81B75CCC90D2974F7A1CBD';
  FIRST_BOUNDARY constant varchar2(256) := '--' || BOUNDARY || gc_NewLine;
  LAST_BOUNDARY constant varchar2(256) := '--' || BOUNDARY || '--' || gc_NewLine;

  MULTIPART_MIME_TYPE constant varchar2(256) := 'multipart/mixed; boundary="'||
                                                  BOUNDARY || '"';

    TYPE        t_recp    IS TABLE OF VARCHAR(512);

PROCEDURE SendEmail(p_fromAddress  IN varchar2,
                    p_toAddress    IN varchar2,
                    p_subject      IN varchar2,
                    p_body         IN varchar2,
                    p_mimeType     IN varchar2 default 'text/plain') IS

    BEGIN
        SendEmail(p_fromAddress,
                  p_toAddress,
                  NULL,
                  NULL,  
                  p_subject,    
                  p_body,
                  NULL,
                  NULL,
                  NULL,       
                  p_mimeType);   
    
    END SendEmail;

PROCEDURE SendEmail(p_fromAddress  IN varchar2,
                    p_toAddress    IN varchar2,
                    p_cc           IN VARCHAR2,
                    p_bcc          IN VARCHAR2,  
                    p_subject      IN varchar2,
                    p_body         IN varchar2,
                    p_mimeType     IN varchar2 default 'text/plain') IS       

    BEGIN
        SendEmail(p_fromAddress,
                  p_toAddress,
                  p_cc,
                  p_bcc,  
                  p_subject,    
                  p_body,
                  NULL,
                  NULL,
                  NULL,       
                  p_mimeType);   
    
    END SendEmail;

PROCEDURE SendEmail(p_fromAddress  IN VARCHAR2,
                    p_toAddress    IN VARCHAR2,
                    p_cc           IN VARCHAR2,
                    p_bcc          IN VARCHAR2,  
                    p_subject      IN VARCHAR2,
                    p_body         IN VARCHAR2,
                    p_file_name    IN VARCHAR2,
                    p_clob         IN CLOB,
                    p_encoding     VARCHAR2 DEFAULT 'text/plain', 
                    p_mimeType     VARCHAR2 DEFAULT 'text/plain') IS

    CURSOR      cur_rcpt(p_to IN VARCHAR2) IS
                     SELECT REGEXP_SUBSTR (p_to, '[^;]+', 1, LEVEL) TXT 
                       FROM DUAL
                    CONNECT BY REGEXP_SUBSTR (p_to, '[^;]+', 1, LEVEL) IS NOT NULL;

    l_conn                   utl_smtp.connection;
    lv_host                  VARCHAR2(512);-- := '134.186.202.119';
    v_len                    INTEGER;
    v_index                  INTEGER;
    v_file_type              VARCHAR2(50);
    v_body                   VARCHAR2(32000) := p_body;
    lv_db_name               VARCHAR2(100);
    l_rcpt                   t_recp;
        
    BEGIN
        IF (p_toAddress IS NULL) THEN RETURN; END IF;
        
        IF (p_file_name IS NOT NULL) THEN
             SELECT CASE LOWER(REGEXP_SUBSTR(p_file_name, '\.[^\.]*$'))
                        WHEN 'doc'  THEN 'application/msword'
                        WHEN 'xls'  THEN 'application/excel'
                        WHEN 'xlsx' THEN 'application/excel'
                        WHEN 'pdf'  THEN 'application/pdf'
                        WHEN 'zip'  THEN 'application/zip'
                        WHEN 'bmp'  THEN 'image/bmp'
                        WHEN 'jpg'  THEN 'image/jpg'
                        WHEN 'jpeg' THEN 'image/jpg'
                        WHEN 'gif'  THEN 'image/gif'
                        WHEN 'htm'  THEN 'text/html'
                        WHEN 'html' THEN 'text/html'
                        WHEN 'txt'  THEN 'text/plain'
                        WHEN 'log'  THEN 'text/plain'
                        WHEN 'csv'  THEN 'text/plain'
                        WHEN 'text' THEN 'text/plain'
                        ELSE             'text/plain'
                    END CASE  
              INTO v_file_type
              FROM DUAL;
        ELSE
            v_file_type := p_mimetype;
        END IF;

        OPEN cur_rcpt(p_toAddress || ';' || p_cc || ';' || p_bcc);
        FETCH cur_rcpt BULK COLLECT INTO l_rcpt LIMIT 30;
        CLOSE cur_rcpt;

        SELECT Value
          INTO lv_host
          FROM api.constants
         WHERE Name = 'SMTPSERVER';

        select sys_context('userenv','instance_name') INTO lv_db_name from dual;
        IF (UPPER(lv_db_name) != 'ABISP1') THEN -- Changed DB name to ABISP1 by pawan on 10/26/2022
            v_body := '*** This is a test sent from: ' || lv_db_name || ' *** '
                   || UTL_TCP.CRLF || UTL_TCP.CRLF || v_body;
        END IF;
                        
        l_conn := utl_smtp.open_connection(lv_host, 25);
        UTL_SMTP.HELO(l_conn, lv_host);
            
        utl_smtp.mail(l_conn, p_fromAddress);
        -- loop through the to address list
        FOR inx IN 1..l_rcpt.COUNT
        LOOP
            utl_smtp.rcpt(l_conn, l_rcpt(inx));
        END LOOP;
            
        utl_smtp.open_data(l_conn);
        utl_smtp.write_data(l_conn, 'From: '    || p_fromAddress  || UTL_TCP.CRLF);
        utl_smtp.write_data(l_conn, 'To: '    || p_toAddress  || UTL_TCP.CRLF);
        utl_smtp.write_data(l_conn, 'Cc: '    || p_cc  || UTL_TCP.CRLF);
        utl_smtp.write_data(l_conn, 'Subject: ' || p_subject      || UTL_TCP.CRLF);
        
        utl_smtp.write_data(l_conn, 'Content-Type: ' || MULTIPART_MIME_TYPE || UTL_TCP.CRLF);

        utl_smtp.write_data(l_conn, UTL_TCP.CRLF);     
        utl_smtp.write_data(l_conn, FIRST_BOUNDARY);
        utl_smtp.write_data(l_conn, 'Content-Type: ' || p_mimeType || UTL_TCP.CRLF);
        utl_smtp.write_data(l_conn, UTL_TCP.CRLF);     
        utl_smtp.write_data(l_conn, v_body || UTL_TCP.CRLF);
        utl_smtp.write_data(l_conn, UTL_TCP.CRLF);

        IF (p_clob IS NOT NULL AND p_file_name IS NOT NULL) THEN
            utl_smtp.write_data(l_conn, FIRST_BOUNDARY);
            utl_smtp.write_data(l_conn, 'Content-Type: ' || v_file_type || UTL_TCP.CRLF);

            -- Set up attachment header
            utl_smtp.write_data(l_conn, 'Content-Disposition: attachment; filename="'
                                         || p_file_name
                                         || '"'|| UTL_TCP.CRLF);
                                         
            utl_smtp.write_data(l_conn, 'Content-Transfer-Encoding: '|| p_encoding || UTL_TCP.CRLF);
            utl_smtp.write_data(l_conn, UTL_TCP.CRLF);

            -- Write attachment contents
            v_len := DBMS_LOB.getlength(p_clob);
            v_index := 1;

            WHILE v_index <= v_len
            LOOP
                utl_smtp.write_data(l_conn, DBMS_LOB.SUBSTR(p_clob, 32000, v_index));
                v_index := v_index + 32000;
            END LOOP;

            -- End attachment
            utl_smtp.write_data(l_conn, UTL_TCP.CRLF);
        END IF;

        utl_smtp.write_data(l_conn, LAST_BOUNDARY);
            
        utl_smtp.close_data(l_conn);
        utl_smtp.quit(l_conn);
    END SendEmail;


END PKG_TLEMAIL;
/


GRANT EXECUTE, DEBUG ON SITESPECIFIC.PKG_TLEMAIL TO ABC;

GRANT EXECUTE ON SITESPECIFIC.PKG_TLEMAIL TO ABCLQS;

GRANT EXECUTE ON SITESPECIFIC.PKG_TLEMAIL TO ABCREPORTS_ROLE;

GRANT EXECUTE ON SITESPECIFIC.PKG_TLEMAIL TO BIZMOD_API;

GRANT EXECUTE ON SITESPECIFIC.PKG_TLEMAIL TO POSSEEXTENSIONS;
