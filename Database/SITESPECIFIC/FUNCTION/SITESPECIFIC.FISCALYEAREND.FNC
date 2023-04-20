CREATE OR REPLACE FUNCTION SITESPECIFIC.fiscalyearend(a_date DATE)
    RETURN DATE
IS
    -- **************************************************************************
    -- File:        FISCALYEAREND.FNC
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
    t_enddate   DATE;
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
    SELECT TO_DATE(('30-JUN-') || fiscalyear) enddate
      INTO t_enddate
      FROM fiscalyear;

    RETURN (t_enddate);
END fiscalyearend;
/
