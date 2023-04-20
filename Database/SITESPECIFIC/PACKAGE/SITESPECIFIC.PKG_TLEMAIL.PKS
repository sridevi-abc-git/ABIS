CREATE OR REPLACE PACKAGE SITESPECIFIC.PKG_TLEMAIL AS
-- ****************************************************************************
-- File:        PKG_TLEMAI.pks  
-- Author:      Timothy J. Lord
--
-- $Rev: 2510 $  
-- $Date: 2016-03-20 15:50:16 -0700 (Sun, 20 Mar 2016) $
-- Last Changed By:  $Author: tlord $
--
-- Description: PKG_TLEMAI package specifications   
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
                    p_mimeType     IN varchar2 default 'text/plain');        


PROCEDURE SendEmail(p_fromAddress  IN varchar2,
                    p_toAddress    IN varchar2,
                    p_cc           IN VARCHAR2,
                    p_bcc          IN VARCHAR2,  
                    p_subject      IN varchar2,
                    p_body         IN varchar2,
                    p_mimeType     IN varchar2 default 'text/plain');        


PROCEDURE SendEmail(p_fromAddress  IN VARCHAR2,
                    p_toAddress    IN VARCHAR2,
                    p_cc           IN VARCHAR2,
                    p_bcc          IN VARCHAR2,  
                    p_subject      IN VARCHAR2,
                    p_body         IN VARCHAR2,
                    p_file_name    IN VARCHAR2,
                    p_clob         IN CLOB,
                    p_encoding     IN VARCHAR2 DEFAULT 'text/plain', 
                    p_mimeType     IN VARCHAR2 DEFAULT 'text/plain');

END PKG_TLEMAIL;
/


GRANT EXECUTE, DEBUG ON SITESPECIFIC.PKG_TLEMAIL TO ABC;

GRANT EXECUTE ON SITESPECIFIC.PKG_TLEMAIL TO ABCLQS;

GRANT EXECUTE ON SITESPECIFIC.PKG_TLEMAIL TO ABCREPORTS_ROLE;

GRANT EXECUTE ON SITESPECIFIC.PKG_TLEMAIL TO BIZMOD_API;

GRANT EXECUTE ON SITESPECIFIC.PKG_TLEMAIL TO POSSEEXTENSIONS;
