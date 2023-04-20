CREATE OR REPLACE PACKAGE BODY ABCREPORTS.RQS_EMAIL AS
-- ****************************************************************************
-- File:        RQS_EMAIL.pkb  
-- Author:      Timothy J. Lord
--
-- $Rev: 208 $  
-- $Date: 2019-01-16 14:19:44 -0800 (Wed, 16 Jan 2019) $
-- Last Changed By:  $Author: tlord $
--
-- Description: RPT_EMAIL package specifications   
--
-- Functions:    stmt_to_csv()
--
-- History:
-------------------------------------------------------------------------------
--    Date         Ticket     Comment
-- 05/22/2014 TJL    1924   Original file created
-- 02/24/2015 TJL           Changes made for new processing
-- 06/15/2015 TJL   7518    Added logging emails sent to RQS_EMAIL_LOG table
-- 10/12/2017 TJL           Change test for development database from ABCDEV2 to
--                          ABCDEV
-- 01/14/2019 TJL   17103   Added Sandbox to define where RQS emails come from.
-- ****************************************************************************
  gc_Newline constant char(2) := chr(13)||chr(10);
  MAILER_ID constant varchar2(256) := 'Mailer by Oracle UTL_SMTP';

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
                    p_mimeType     IN varchar2 default 'text/html') IS

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
                    p_cc           VARCHAR2,
                    p_bcc          VARCHAR2,  
                    p_subject      IN varchar2,
                    p_body         IN varchar2,
                    p_mimeType     IN varchar2 default 'text/html') IS        

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


PROCEDURE SendEmail(p_fromAddress  VARCHAR2,
                    p_toAddress    VARCHAR2,
                    p_subject      VARCHAR2,
                    p_body         VARCHAR2,
                    p_file_name    VARCHAR2,
                    p_clob         CLOB,
                    p_encoding     VARCHAR2 DEFAULT 'text/plain', 
                    p_mimeType     VARCHAR2 DEFAULT 'text/html') IS
    BEGIN
        SendEmail(p_fromAddress,
                  p_toAddress,
                  NULL,
                  NULL,  
                  p_subject,    
                  p_body,
                  p_file_name,
                  p_clob,
                  p_encoding,       
                  p_mimeType);   
    
    END SendEmail;



PROCEDURE SendEmail(p_fromAddress  VARCHAR2,
                    p_toAddress    VARCHAR2,
                    p_cc           VARCHAR2,
                    p_bcc          VARCHAR2,  
                    p_subject      VARCHAR2,
                    p_body         VARCHAR2,
                    p_file_name    VARCHAR2,
                    p_clob         CLOB,
                    p_encoding     VARCHAR2 DEFAULT 'text/plain', 
                    p_mimeType     VARCHAR2 DEFAULT 'text/html') IS

    CURSOR      cur_rcpt(p_to IN VARCHAR2) IS
                     SELECT REGEXP_SUBSTR (p_to, '[^;]+', 1, LEVEL) TXT 
                       FROM DUAL
                    CONNECT BY REGEXP_SUBSTR (p_to, '[^;]+', 1, LEVEL) IS NOT NULL;

    lv_to                    VARCHAR2(4000) := rqs_utils.get_ctrl_value(p_name => 'EMAIL_REDIRECT');
    l_conn                   utl_smtp.connection;
    lv_host                  VARCHAR2(512);-- := '134.186.202.119';
    v_len                    INTEGER;
    v_index                  INTEGER;
    v_file_type              VARCHAR2(50);
    v_body                   VARCHAR2(32000) := p_body;
    v_subject                VARCHAR2(300)   := p_subject;
    l_rcpt                   t_recp;
    l_cc                     t_recp;
    l_bcc                    t_recp;
    lv_db                    VARCHAR2(40);
    
    ln_retry            NUMBER          := 0;

    BEGIN
        -- check if test or development
        SELECT UPPER(sys_context('USERENV', 'instance_name')) INTO lv_db FROM DUAL;
        -- 01/14/2019 TJL   17103   Added testing for Sandbox 
        IF (lv_db IN ('ABCDEV', 'ABCTEST', 'ABCSB')) THEN
            v_subject := '(' || 
                            CASE lv_db
                                    WHEN 'ABCDEV'  THEN 'Development'
                                    WHEN 'ABCTEST' THEN 'Test'
                                    ELSE                'Sandbox'
                            END
                      || ') '
                      || v_subject;
            v_body := '*** Please ignore this email. Email generated by ' || 
                            CASE lv_db
                                    WHEN 'ABCDEV'  THEN 'Development'
                                    WHEN 'ABCTEST' THEN 'Test'
                                    ELSE                'Sandbox'
                            END
                      || ' system. ***'
                      || CASE p_mimeType
                              WHEN 'text/html' THEN '<br/><br/>'
                              ELSE                  CHR(13) || CHR(10) || CHR(13) || CHR(10)
                      END
                   || v_body;
        END IF;
        
        IF (p_file_name IS NOT NULL) THEN
             SELECT CASE LOWER(REGEXP_SUBSTR(p_file_name, '\.[^\.]*$'))
                        WHEN 'doc'  THEN 'application/msword'
                        WHEN 'docx' THEN 'application/msword'
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
        
        IF (lv_to IS NULL) THEN
            OPEN cur_rcpt(p_toAddress);
            FETCH cur_rcpt BULK COLLECT INTO l_rcpt LIMIT 30;
            CLOSE cur_rcpt;
        ELSE
            OPEN cur_rcpt(lv_to);
            FETCH cur_rcpt BULK COLLECT INTO l_rcpt LIMIT 30;
            CLOSE cur_rcpt;
        END IF;
        
        IF (p_cc IS NOT NULL) THEN
            OPEN cur_rcpt(p_cc);
            FETCH cur_rcpt BULK COLLECT INTO l_cc LIMIT 30;
            CLOSE cur_rcpt;
        END IF;
        
        IF (p_bcc IS NOT NULL) THEN
            OPEN cur_rcpt(p_bcc);
            FETCH cur_rcpt BULK COLLECT INTO l_bcc LIMIT 30;
            CLOSE cur_rcpt;
        END IF;
        
        SELECT Value
          INTO lv_host
          FROM api.constants
         WHERE Name = 'SMTPSERVER';

        WHILE (ln_retry < 3)
        LOOP
            BEGIN 
                l_conn := utl_smtp.open_connection(lv_host, 25);
                UTL_SMTP.HELO(l_conn, lv_host);
                    
                utl_smtp.mail(l_conn, p_fromAddress);
                -- loop through the to address list
                FOR inx IN 1..l_rcpt.COUNT
                LOOP
                    utl_smtp.rcpt(l_conn, l_rcpt(inx));
                END LOOP;

                IF (p_cc IS NOT NULL) THEN
                    FOR inx IN 1..l_cc.COUNT
                    LOOP
                        utl_smtp.rcpt(l_conn, l_cc(inx));
                    END LOOP;
                END IF;

                IF (p_bcc IS NOT NULL) THEN
                    FOR inx IN 1..l_bcc.COUNT
                    LOOP
                        utl_smtp.rcpt(l_conn, l_bcc(inx));
                    END LOOP;
                END IF;
                            
                utl_smtp.open_data(l_conn);
                
                utl_smtp.write_data(l_conn, 'From: '    || p_fromAddress  || UTL_TCP.CRLF);
                utl_smtp.write_data(l_conn, 'To: '      || p_toAddress  || UTL_TCP.CRLF);
                IF (p_cc IS NOT NULL) THEN
                    utl_smtp.write_data(l_conn, 'Cc: '  || p_cc  || UTL_TCP.CRLF);
                END IF;
                IF (p_bcc IS NOT NULL) THEN
                    utl_smtp.write_data(l_conn, 'Bcc: ' || p_bcc  || UTL_TCP.CRLF);
                END IF;
                utl_smtp.write_data(l_conn, 'Subject: ' || v_subject      || UTL_TCP.CRLF);
                
                utl_smtp.write_data(l_conn, 'Content-Type: ' || MULTIPART_MIME_TYPE || UTL_TCP.CRLF);

                utl_smtp.write_data(l_conn, UTL_TCP.CRLF);     
                utl_smtp.write_data(l_conn, FIRST_BOUNDARY);
                utl_smtp.write_data(l_conn, 'Content-Type: ' || p_mimeType);
                utl_smtp.write_data(l_conn, UTL_TCP.CRLF || UTL_TCP.CRLF);     
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
                
                BEGIN
                    -- log sending of email 
                    INSERT INTO report_email_log (to_addr, from_addr, subject, body)
                    VALUES (p_toAddress, p_fromAddress, v_subject, substr(v_body,1,3900));
                    COMMIT; 

                EXCEPTION 
                    WHEN OTHERS THEN
                        RQS_UTILS.log(p_log_type         => 'E',
                                      p_job_id           => NULL,
                                      p_seq              => NULL,
                                      p_source           => 'EMAIL',
                                      p_msg              => SQLERRM,
                                      p_additional_data  => lv_host || ' TO: ' || p_toAddress,
                                      p_error_trace      => dbms_utility.format_error_backtrace);
                END;

                RQS_UTILS.log(p_log_type         => 'T',
                              p_job_id           => NULL,
                              p_seq              => NULL,
                              p_source           => 'EMAIL',
                              p_msg              => 'Email Sent: ' || v_subject,
                              p_additional_data  => lv_host || ' TO: ' || p_toAddress,
                              p_error_trace      => NULL);
                
                EXIT; -- exit loop on successful email being sent
                
            EXCEPTION 
                WHEN OTHERS THEN
                    IF (ln_retry = 0) THEN
                        RQS_UTILS.log(p_log_type         => 'E',
                                      p_job_id           => NULL,
                                      p_seq              => NULL,
                                      p_source           => 'EMAIL',
                                      p_msg              => SQLERRM,
                                      p_additional_data  => lv_host || ' TO: ' || p_toAddress,
                                      p_error_trace      => dbms_utility.format_error_backtrace);
                    END IF;
                    
                    ln_retry := ln_retry + 1;                              
            END;
            
        END LOOP; 
           
    EXCEPTION 
        WHEN OTHERS THEN
            RQS_UTILS.log(p_log_type         => 'E',
                          p_job_id           => NULL,
                          p_seq              => NULL,
                          p_source           => 'EMAIL',
                          p_msg              => SQLERRM,
                          p_additional_data  => lv_host || ' TO: ' || p_toAddress,
                          p_error_trace      => dbms_utility.format_error_backtrace);
    END SendEmail;


PROCEDURE SendEmail(p_fromAddress  VARCHAR2,
                    p_toAddress    VARCHAR2,
                    p_subject      VARCHAR2,
                    p_body         VARCHAR2,
                    p_file_name    VARCHAR2,
                    p_blob         BLOB,
                    p_mimeType     VARCHAR2 DEFAULT 'text/html') IS
    BEGIN
        SendEmail(p_fromAddress,
                  p_toAddress,
                  NULL,
                  NULL,  
                  p_subject,
                  p_body,
                  p_file_name,
                  p_blob,
                  p_mimeType);
    END SendEmail;
    
PROCEDURE SendEmail(p_fromAddress  VARCHAR2,
                    p_toAddress    VARCHAR2,
                    p_cc           VARCHAR2,
                    p_bcc          VARCHAR2,  
                    p_subject      VARCHAR2,
                    p_body         VARCHAR2,
                    p_file_name    VARCHAR2,
                    p_blob         BLOB,
                    p_mimeType     VARCHAR2 DEFAULT 'text/html') IS
                                             
    l_raw          RAW(32767);
    l_length       PLS_INTEGER;
    l_loops        PLS_INTEGER;
    l_pos          PLS_INTEGER;
    l_encoded_raw  RAW(32767);
    l_encoded_vc2  VARCHAR2(32767);
    l_size         PLS_INTEGER;
    l_clob         CLOB;
  
    BEGIN
        DBMS_LOB.CREATETEMPORARY(l_clob, TRUE, dbms_lob.CALL);

        l_size := 12288;
        l_length := DBMS_LOB.getLength(p_blob);

        IF l_length > l_size THEN
            l_loops := ROUND((l_length/l_size)+0.5);
        ELSE
            l_loops := 1;
        END IF;

        l_pos := 1;

        FOR i IN 1..l_loops LOOP
            DBMS_LOB.READ(p_blob, l_size, l_pos, l_raw);
            l_encoded_raw := UTL_ENCODE.base64_encode(l_raw);
            l_encoded_vc2 := UTL_RAW.cast_to_varchar2(l_encoded_raw);
            DBMS_LOB.writeAppend ( l_clob, LENGTH(l_encoded_vc2), l_encoded_vc2);
            l_pos := l_pos + l_size;
        END LOOP;

        DBMS_LOB.writeAppend(l_clob,1,CHR(10));

        SendEmail(p_fromAddress,
                  p_toAddress,
                  p_cc,
                  p_bcc,  
                  p_subject,
                  p_body,
                  p_file_name,
                  l_clob,
                  'base64', 
                  p_mimeType);

    EXCEPTION 
        WHEN OTHERS THEN
                        RQS_UTILS.log(p_log_type         => 'E',
                                      p_job_id           => NULL,
                                      p_seq              => NULL,
                                      p_source           => 'EMAIL',
                                      p_msg              => SQLERRM,
                                      p_additional_data  => ' TO: ' || p_toAddress,
                                      p_error_trace      => dbms_utility.format_error_backtrace);
    END SendEmail;


END RQS_EMAIL;
/


CREATE OR REPLACE PUBLIC SYNONYM RQS_EMAIL FOR ABCREPORTS.RQS_EMAIL;


GRANT EXECUTE ON ABCREPORTS.RQS_EMAIL TO ABCREPORTS_ROLE;
