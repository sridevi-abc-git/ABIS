CREATE OR REPLACE PACKAGE ABC.pkg_EMAIL AS
/******************************************************************************
   NAME:       EMAIL
   PURPOSE:

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0        1/30/2020      pkaur       1. Created this package.
******************************************************************************/

PROCEDURE createEmail (a_OBJECTID       IN OUT NUMBER,
                       a_EMAILADDRESS          VARCHAR2,
                       a_EMAILTYPE             VARCHAR2,
                        a_CREATEDDATE           DATE DEFAULT SYSDATE,
                       a_CREATEDBY             VARCHAR2  DEFAULT USER);
PROCEDURE modifyEmail (a_OBJECTID       IN OUT NUMBER,
                       a_EMAILADDRESS          VARCHAR2,
                       a_EMAILTYPE             VARCHAR2,
                        a_CREATEDDATE           DATE DEFAULT SYSDATE,
                       a_CREATEDBY             VARCHAR2  DEFAULT USER);

END pkg_EMAIL;
/
