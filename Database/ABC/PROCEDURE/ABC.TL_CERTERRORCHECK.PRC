CREATE OR REPLACE PROCEDURE ABC.tl_certerrorcheck(
    p_schedulelogkey IN   NUMBER,
    p_errorlist       OUT SYS_REFCURSOR)
IS
    -- ****************************************************************************
    -- File:        TL_CERTERRORCHECK.PRC
    -- Author:      Timothy J. Lord
    --
    -- $Rev: 3103 $
    -- $Date: 2016-10-28 07:45:38 -0700 (Fri, 28 Oct 2016) $
    -- Last Changed By:  $Author: tlord $
    --
    -- Description:
    --
    --
    -- History:
    -------------------------------------------------------------------------------
    --    Date                  Comment
    -- 10/23/2016 TJL 10789  Added DISTINCT to query to bring only one record per
    --                       schedule id
    -- 10/28/2016 TJL 10789  Added filter to filter out certificates already rescheduled
    -- ****************************************************************************

BEGIN
    OPEN p_errorlist FOR
        SELECT DISTINCT s.schedulekey,
                        NVL(sl.errortext, 'unknown') errortext,
                        s.studentname,
                        s.emailaddress
          FROM query.o_tl_studentregistration  s
               JOIN scheduler.sysschedule ss
                   ON (s.schedulekey = ss.schedulekey)
               JOIN scheduler.sysschedulelog sl
                   ON (s.schedulekey = sl.schedulekey)
               LEFT OUTER JOIN query.r_studentregistrationprintlead x
                   ON x.studentregistration = s.objectid
               LEFT OUTER JOIN extension.emails e
                   ON e.relatedobjectid = x.printleadcertificate
         WHERE sl.schedulelogkey = (SELECT MAX(schedulelogkey)
                                      FROM scheduler.sysschedulelog sl2
                                     WHERE sl2.schedulekey = s.schedulekey)
           AND ss.status != 1
           AND ((e.emailid IS NULL
             AND sl.status = 4)
             OR sl.processstatus < 0);
EXCEPTION
    WHEN OTHERS THEN
        -- Consider logging the error and then re-raise
        RAISE;
END;
/


GRANT EXECUTE ON ABC.TL_CERTERRORCHECK TO PSERVERSYS;
