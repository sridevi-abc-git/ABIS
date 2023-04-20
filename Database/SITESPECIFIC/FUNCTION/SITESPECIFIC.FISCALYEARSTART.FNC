CREATE OR REPLACE FUNCTION SITESPECIFIC.fiscalyearstart(a_date DATE)
    RETURN DATE
IS
    -- **************************************************************************
    -- File:        FISCALYEARSTART.FNC
    -- Author:      CX
    --
    -- $Rev$
    -- $Date$
    -- Last Changed By:  $Author$
    --
    -- Description:
    --
    --
    -- History:
    -----------------------------------------------------------------------------
    --    Date                  Comment
    -- 08/20/2018 TJL         Initial Check-in
    -- **************************************************************************
    t_startdate   DATE;
BEGIN
    WITH
        fiscalyear
        AS
            (SELECT DECODE(TRUNC((SUBSTR(yearmonth, 5, 2) - 1) / 6),
                           1, SUBSTR(yearmonth, 1, 4) + 1,
                           SUBSTR(yearmonth, 1, 4))
                        fiscalyear
               FROM (SELECT TO_CHAR(TRUNC(TO_DATE(a_date, 'DD-MON-YYYY')),
                                    'YYYYMM')
                                yearmonth
                       FROM DUAL))
    SELECT TO_DATE(('01-JUL-') || (fiscalyear - 1)) startdate
      INTO t_startdate
      FROM fiscalyear;

    RETURN (t_startdate);
END fiscalyearstart;
/


GRANT EXECUTE, DEBUG ON SITESPECIFIC.FISCALYEARSTART TO POSSEEXTENSIONS;
