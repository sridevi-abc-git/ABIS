CREATE OR REPLACE PACKAGE BODY SITESPECIFIC.pkg_apibreaks
IS
    -- **************************************************************************
    -- File:        PKG_APIBREAKS.pkb
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
    -- 08/16/2018 TJL         Initial Check-in
    -- **************************************************************************

    ----------------------------------------------------------------------------------------------------
    --  MaintainDuplicateDetails() -- PUBLIC
    --  API break calling Maintain Dups from package code not from stage config
    ----------------------------------------------------------------------------------------------------

    PROCEDURE maintainduplicatedetails(a_objectid NUMBER)
    IS
    BEGIN
        toolbox.pkg_copy.maintainduplicatedetails(a_objectid, SYSDATE);
    END;


    ----------------------------------------------------------------------------------------------------
    --  GetScheduledStatus() -- PUBLIC
    --  Given a schedule key, return the textual status of the scheduled item
    ----------------------------------------------------------------------------------------------------
    FUNCTION getscheduledstatus(a_schedulekey NUMBER)
        RETURN VARCHAR2
    IS
        t_status   VARCHAR2(100);
    BEGIN
        -- Get the status of the scheduled item
        -- Since there is no table containing the scheduled status, we have to hardcode it
        -- To check for failed items, we have to look at the most recent row in the log table
        WITH
            LOG
            AS
                (SELECT schedulekey, processstatus, schedulelogkey
                   FROM scheduler.sysschedulelog)
        SELECT DECODE(sched.status,
                      1, 'Scheduled',
                      2, 'Disabled',
                      3, 'Processing',
                      4, DECODE(processstatus, -1, 'Failed', 'Complete'))
          INTO t_status
          FROM scheduler.sysschedule  sched
               LEFT OUTER JOIN LOG LOG ON LOG.schedulekey = sched.schedulekey
         WHERE sched.schedulekey = a_schedulekey
           AND (LOG.schedulelogkey = (SELECT MAX(schedulelogkey)
                                        FROM LOG
                                       WHERE schedulekey = sched.schedulekey)
             OR LOG.schedulelogkey IS NULL);

        RETURN t_status;
    END;
END pkg_apibreaks;
/
