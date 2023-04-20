CREATE OR REPLACE PACKAGE SITESPECIFIC.pkg_sysschedule
IS
    -- **************************************************************************
    -- File:        PKG_SYSSCHEDULE.PKS
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

    -- Purpose : sysschedule functions

    SUBTYPE udt_id IS api.pkg_definition.udt_id;

    /*
    ScheduleProcess - used in conjunction with the new process server functionality to direct a particular scheculed process
      to a specific printer.
      - ScheduleProcess is the name of a column that can be evaluated to a boolean
        The boolean indicates whether to schedule the process or not. Prepending
        a ! to the column name reverses the column value. Providing a null or a 'Y'
        to this argument will ALWAYS schedule the process.
      - ScheduledProcessName is the view name of the process that needs to be scheduled.
      - Outcome is the outcome of the scheduled process. If a null value is given,
        the outcome will not be set.
    These last three arguments can be passed in as a semi-colon de-limited list to indicate that more than one process is to
    be created.
      - Server Key is the key of the Process Server for which this is to be schedule.  The Default is 1.
    */

    PROCEDURE scheduleprocess(
        a_objectid      udt_id,
        a_asofdate      DATE,
        a_scheduleprocess VARCHAR2,
        a_scheduledprocessname VARCHAR2,
        a_scheduledoutcome api.pkg_definition.udt_outcome,
        a_serverkey     NUMBER DEFAULT 1,
        a_scheduleddate DATE DEFAULT NULL);



    /*----------------------------------------------------------------------------------------------------------------*
     * ScheduleProcedure - used to schedule a one-time procedure on the Process Server
     *----------------------------------------------------------------------------------------------------------------*/

    PROCEDURE scheduleprocedure(a_objectid      udt_id,
                                a_asofdate      DATE,
                                a_procedurename VARCHAR2,
                                a_proceduredescription VARCHAR2,
                                a_runas         VARCHAR2,
                                a_serverkey     NUMBER,
                                a_scheduleddate DATE DEFAULT NULL);


    /*----------------------------------------------------------------------------------------------------------------*
     * Procedure ScheduleLicenseBatchProcess()
     * Specifically coded for a specific scenario. NOT GENERIC!!!
     *----------------------------------------------------------------------------------------------------------------*/
    PROCEDURE schedulelicensebatchprocess(
        a_objectid      udt_id,
        a_asofdate      DATE,
        a_scheduleddate DATE DEFAULT SYSDATE,
        a_jobid         udt_id,
        a_outcome       VARCHAR2);
END pkg_sysschedule;
/
