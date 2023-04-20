CREATE OR REPLACE PROCEDURE ABC.tl_reschedule(p_schedulekey  IN     NUMBER,
                                              p_message         OUT VARCHAR2,
                                              p_code            OUT NUMBER)
IS
    -- ****************************************************************************
    -- File:        TL_RESCHEDULE.PRC
    -- Author:      Timothy J. Lord
    --
    -- $Rev: 3097 $
    -- $Date: 2016-10-27 14:28:08 -0700 (Thu, 27 Oct 2016) $
    -- Last Changed By:  $Author: tlord $
    --
    -- Description:
    --
    --
    -- History:
    -------------------------------------------------------------------------------
    --    Date                  Comment
    -- 10/23/2016 TJL         Initial File Created
    -- ****************************************************************************

BEGIN
    UPDATE scheduler.sysschedule s
       SET s.status   = 1
     WHERE s.schedulekey = p_schedulekey;

    IF (SQL%ROWCOUNT = 0) THEN
        p_message   := 'No student found. Schedule Key: ' || p_schedulekey;
        p_code      := 1;
    END IF;

    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        p_message   :=
               'Re-schedule Certificate: '
            || SQLERRM
            || ' :: '
            || dbms_utility.format_error_backtrace;
        p_code   := -1;
END;
/


GRANT EXECUTE ON ABC.TL_RESCHEDULE TO POSSEEXTENSIONS;

GRANT EXECUTE ON ABC.TL_RESCHEDULE TO PSERVERSYS;
