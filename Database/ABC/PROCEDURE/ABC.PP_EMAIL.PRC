CREATE OR REPLACE PROCEDURE ABC.PP_EMAIL 
/*-------------------------------------------
PROG   : ABC.PP_MAIL 
AUTHOR : Ning Wong
DATE   : 5/25/2021  
DESC   : Send email 
---------------------------------------------*/
( 
  p_to          IN VARCHAR2,
  p_from        IN VARCHAR2,
  p_subject     IN VARCHAR2,
  p_text_msg    IN VARCHAR2 DEFAULT NULL,
  p_attach_name IN VARCHAR2 DEFAULT NULL,
  p_attach_mime IN VARCHAR2 DEFAULT NULL,
  p_attach_clob IN CLOB     DEFAULT NULL   
)

AS

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

END;
/
