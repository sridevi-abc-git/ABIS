CREATE OR REPLACE PACKAGE ABCREPORTS.RQS_EMAIL AS
-- ****************************************************************************
-- File:        rqs_email.pks  
-- Author:      Timothy J. Lord
--
-- $Rev: 2290 $  
-- $Date: 2016-01-06 10:24:08 -0800 (Wed, 06 Jan 2016) $
-- Last Changed By:  $Author: tlord $
--
-- Description: RQS_EMAIL package specifications   
--
-- 
-- History:
-------------------------------------------------------------------------------
--    Date            Comment
-- 05/22/2014 TJL  Initial File created  
-- ****************************************************************************

PROCEDURE SendEmail(p_fromAddress  IN varchar2,
                    p_toAddress    IN varchar2,
                    p_subject      IN varchar2,
                    p_body         IN varchar2,
                    p_mimeType     IN varchar2 default 'text/html');        

PROCEDURE SendEmail(p_fromAddress  IN varchar2,
                    p_toAddress    IN varchar2,
                    p_cc           VARCHAR2,
                    p_bcc          VARCHAR2,  
                    p_subject      IN varchar2,
                    p_body         IN varchar2,
                    p_mimeType     IN varchar2 default 'text/html');        

PROCEDURE SendEmail(p_fromAddress  VARCHAR2,
                    p_toAddress    VARCHAR2,
                    p_cc           VARCHAR2,
                    p_bcc          VARCHAR2,  
                    p_subject      VARCHAR2,
                    p_body         VARCHAR2,
                    p_file_name    VARCHAR2,
                    p_clob         CLOB,
                    p_encoding     VARCHAR2 DEFAULT 'text/plain', 
                    p_mimeType     VARCHAR2 DEFAULT 'text/html');
                    
PROCEDURE SendEmail(p_fromAddress  VARCHAR2,
                    p_toAddress    VARCHAR2,
                    p_subject      VARCHAR2,
                    p_body         VARCHAR2,
                    p_file_name    VARCHAR2,
                    p_clob         CLOB,
                    p_encoding     VARCHAR2 DEFAULT 'text/plain', 
                    p_mimeType     VARCHAR2 DEFAULT 'text/html');

PROCEDURE SendEmail(p_fromAddress  VARCHAR2,
                    p_toAddress    VARCHAR2,
                    p_subject      VARCHAR2,
                    p_body         VARCHAR2,
                    p_file_name    VARCHAR2,
                    p_blob         BLOB,
                    p_mimeType     VARCHAR2 DEFAULT 'text/html');
                    
PROCEDURE SendEmail(p_fromAddress  VARCHAR2,
                    p_toAddress    VARCHAR2,
                    p_cc           VARCHAR2,
                    p_bcc          VARCHAR2,  
                    p_subject      VARCHAR2,
                    p_body         VARCHAR2,
                    p_file_name    VARCHAR2,
                    p_blob         BLOB,
                    p_mimeType     VARCHAR2 DEFAULT 'text/html');
                    

                                                                                             
END RQS_EMAIL;
/


CREATE OR REPLACE PUBLIC SYNONYM RQS_EMAIL FOR ABCREPORTS.RQS_EMAIL;


GRANT EXECUTE ON ABCREPORTS.RQS_EMAIL TO ABCREPORTS_ROLE;
