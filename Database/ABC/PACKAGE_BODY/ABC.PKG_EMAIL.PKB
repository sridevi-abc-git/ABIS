CREATE OR REPLACE PACKAGE BODY ABC.pkg_EMAIL  AS
/******************************************************************************
   NAME:       EMAIL
   PURPOSE:

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0        1/30/2020      pkaur       1. Created this package body.
******************************************************************************/
PROCEDURE createEmail (a_OBJECTID       IN OUT NUMBER,
                       a_EMAILADDRESS          VARCHAR2,
                       a_EMAILTYPE             VARCHAR2,
                       a_CREATEDDATE           DATE DEFAULT SYSDATE,
                       a_CREATEDBY             VARCHAR2  DEFAULT USER)
IS
    t_objid   NUMBER (9);
BEGIN
    INSERT INTO abc.email_t (objectid, 
                            emailaddress, 
                            emailtype, 
                            createddate,
                            createdby)
         VALUES (a_objectid, 
                 a_emailaddress, 
                 a_emailtype, 
                 a_createddate, 
                 a_createdby);
END createEmail;

PROCEDURE modifyEmail (a_OBJECTID       IN OUT NUMBER,
                       a_EMAILADDRESS          VARCHAR2,
                       a_EMAILTYPE             VARCHAR2,
                       a_CREATEDDATE           DATE  DEFAULT SYSDATE,
                       a_CREATEDBY             VARCHAR2 DEFAULT USER)
IS
    t_objid   NUMBER (9);
BEGIN
 UPDATE abc.email_t t 
    SET  emailaddress   = a_emailaddress, 
         emailtype      = a_emailtype,
         createddate    = a_createddate,
         createdby      = a_createdby
 where t.objectid = a_objectid;
 
END modifyEmail;

END pkg_EMAIL;
/
