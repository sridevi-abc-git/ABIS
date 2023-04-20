CREATE OR REPLACE PROCEDURE ABC.tl_leadcheck(p_limit        IN     NUMBER,
                                             p_schedulelogkey   OUT NUMBER,
                                             p_message         OUT VARCHAR2,
                                             p_code            OUT NUMBER)
IS
    -- **************************************************************************
    -- File:        TL_LEADCHECK.PRC
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
    -- 08/21/2018 TJL         Initial Check-in
    -- **************************************************************************

BEGIN
    -- get last log entry
    SELECT MAX(schedulelogkey)
      INTO p_schedulelogkey
      FROM scheduler.sysschedulelog
     WHERE assignedserverkey = 2;

    BEGIN
        SELECT schedulekey
          INTO p_code
          FROM scheduler.sysschedule sch
         WHERE assignedserverkey = 2
           AND status = 3
           AND ((SYSDATE - NVL(processdate, SYSDATE)) * 24 * 60) > p_limit;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            p_code      := NULL;
            p_message   := NULL;
    END;

    IF (p_code IS NULL) THEN
        BEGIN
            SELECT schedulekey
              INTO p_code
              FROM scheduler.sysschedule sch
             WHERE assignedserverkey = 2
               AND schedulekey IN (SELECT MIN(schedulekey)
                                     FROM scheduler.sysschedule sch
                                    WHERE assignedserverkey = 2
                                      AND status = 1)
               AND ((SYSDATE - (scheduledate + (1 / 24))) * 24 * 60) >
                   p_limit * 2;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                p_code      := NULL;
                p_message   := NULL;
        END;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        p_message   :=
               'LEAD Check: '
            || SQLERRM
            || ' :: '
            || dbms_utility.format_error_backtrace;
END;
/


GRANT EXECUTE ON ABC.TL_LEADCHECK TO POSSEEXTENSIONS;

GRANT EXECUTE ON ABC.TL_LEADCHECK TO PROCSRVRAPP;

GRANT EXECUTE ON ABC.TL_LEADCHECK TO PSERVERSYS;
