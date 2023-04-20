CREATE OR REPLACE PACKAGE ABCREPORTS.f_utils
AS
    /******************************************************************************
       NAME:       F_UTILS
       PURPOSE:

       REVISIONS:
       Ver        Date        Author           Description
       ---------  ----------  ---------------  ------------------------------------
       1.0        7/23/2021      tlord       1. Created this package.
    ******************************************************************************/
    PROCEDURE get_revenue(a_startdate    IN DATE,
                                 a_enddate      IN DATE);

END f_utils;
/
