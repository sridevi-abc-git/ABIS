CREATE OR REPLACE PACKAGE BODY SITESPECIFIC.pkg_sysschedule
IS
    -- **************************************************************************
    -- File:        PKG_SYSSCHEDULE.PKB
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

    FUNCTION splitstring(a_string VARCHAR2)
        RETURN api.pkg_definition.udt_stringlist
    IS
        t_stringlist   api.pkg_definition.udt_stringlist;
        t_pos          PLS_INTEGER;
        t_start        PLS_INTEGER := 1;
        t_string       VARCHAR2(4000);
    BEGIN
        t_string   := TRIM(a_string);
        t_pos      := NVL(INSTR(t_string, ';', LENGTH(t_string)), 0);

        IF t_pos = 0 THEN
            t_string   := t_string || ';';
            t_pos      := INSTR(t_string, ';');
        END IF;

        LOOP
            IF t_pos > 0 THEN
                t_stringlist(t_stringlist.COUNT + 1)   :=
                    SUBSTR(a_string, t_start, t_pos - 1);
                t_start   := t_pos + 1;
                t_pos     := INSTR(t_string, ';', t_start);
            ELSE
                EXIT;
            END IF;
        END LOOP;

        RETURN t_stringlist;
    END;

    /*----------------------------------------------------------------------------------------------------------------*
     * Procedure SCDScheduleProcess()
     *----------------------------------------------------------------------------------------------------------------*/
    PROCEDURE scheduleprocess(
        a_objectid      udt_id,
        a_asofdate      DATE,
        a_scheduleprocess VARCHAR2,
        a_scheduledprocessname VARCHAR2,
        a_scheduledoutcome api.pkg_definition.udt_outcome,
        a_serverkey     NUMBER,
        a_scheduleddate DATE DEFAULT NULL)
    IS
        t_arguments              VARCHAR2(4000);
        t_jobid                  udt_id;
        t_processtypeid          udt_id;
        t_schedulekey            udt_id;
        t_reverse                CHAR(1);
        t_conditioncolumnname    VARCHAR2(30);
        t_condition              CHAR(1);
        t_scheduleprocess        api.pkg_definition.udt_stringlist;
        t_scheduledprocessname   api.pkg_definition.udt_stringlist;
        t_scheduledoutcome       api.pkg_definition.udt_stringlist;
        t_scheduleddate          DATE
            := NVL(a_scheduleddate, (SYSDATE - (1 / 24)));
    BEGIN
        t_scheduleprocess        := splitstring(a_scheduleprocess);
        t_scheduledprocessname   := splitstring(a_scheduledprocessname);
        t_scheduledoutcome       := splitstring(a_scheduledoutcome);

        IF t_scheduleprocess.COUNT <> t_scheduledprocessname.COUNT
       AND t_scheduledprocessname.COUNT <> t_scheduledoutcome.COUNT
       AND t_scheduledprocessname.COUNT = 0 THEN
            api.pkg_errors.raiseerror(
                -20000,
                'Invalid arguments to sitespecific.sysschedule procedure.');
        END IF;

        FOR i IN 1 .. t_scheduleprocess.COUNT
        LOOP
            IF t_scheduleprocess(i) IS NULL THEN
                t_scheduleprocess(i)   := 'Y';
            END IF;

            IF SUBSTR(t_scheduleprocess(i), 1, 1) = '!' THEN
                t_reverse               := 'Y';
                t_conditioncolumnname   := SUBSTR(t_scheduleprocess(i), 2);
            ELSE
                t_reverse               := 'N';
                t_conditioncolumnname   := t_scheduleprocess(i);
            END IF;

            SELECT jobid,
                   NVL(
                       NVL(
                           api.pkg_columnquery.VALUE(processid,
                                                     t_conditioncolumnname),
                           api.pkg_columnquery.VALUE(jobid,
                                                     t_conditioncolumnname)),
                       'Y')
              INTO t_jobid, t_condition
              FROM api.processes
             WHERE processid = a_objectid;

            IF (t_condition = 'Y'
            AND t_reverse = 'N')
            OR (t_condition = 'N'
            AND t_reverse = 'Y') THEN
                t_processtypeid   :=
                    api.pkg_configquery.objectdefidforname(
                        t_scheduledprocessname(i));

                IF t_processtypeid IS NULL THEN
                    api.pkg_errors.setargvalue(
                        'Custom Procedure',
                        'sitespecific.pkg_SysSchedule.ScheduleProcess');
                    api.pkg_errors.raiseerror(
                        -20000,
                        'Process Name passed to procedure is not valid.');
                END IF;

                --set up arguments for scheduler
                scheduler.pkg_scheduler.addargument(t_arguments,
                                                    'JobId',
                                                    t_jobid);
                scheduler.pkg_scheduler.addargument(t_arguments,
                                                    'ProcessTypeId',
                                                    t_processtypeid);

                IF t_scheduledoutcome(i) IS NOT NULL THEN
                    scheduler.pkg_scheduler.addargument(
                        t_arguments,
                        'Outcome',
                        t_scheduledoutcome(i));
                    NULL;
                END IF;

                --set the scheduled start date to null so that the process server picks it up immediately
                scheduler.pkg_scheduler.addargument(t_arguments,
                                                    'AsOfDate',
                                                    t_scheduleddate /*sysdate-(1/24)*/
                                                                   );
                scheduler.pkg_scheduler.addargument(t_arguments,
                                                    'EffectiveUser',
                                                    'POSSESYS');

                --schedule item to be handled by the process server
                t_schedulekey   :=
                    scheduler.pkg_scheduler.scheduleitem(
                        t_scheduleddate                     /*sysdate-(1/24)*/
                                       ,
                        2,
                        'nvo_CreateProcess',
                        t_arguments,
                           'Create process of type '
                        || TO_CHAR(t_processtypeid)
                        || ' on job '
                        || TO_CHAR(t_jobid),
                        a_serverkey);
            END IF;
        END LOOP;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            api.pkg_errors.clear();
            api.pkg_errors.setargvalue(
                'Custom Procedure',
                'sitespecific.pkg_SysSchedule.ScheduleProcess');
            api.pkg_errors.raiseerror(
                -20000,
                'ScheduleProcess Error raised: Object Id passed to procedure is not a process.');
    END scheduleprocess;

    /*----------------------------------------------------------------------------------------------------------------*
     * Procedure ScheduleProcedure()
     * Specifically coded for a specific scenario. NOT GENERIC!!!
     *----------------------------------------------------------------------------------------------------------------*/
    PROCEDURE scheduleprocedure(a_objectid      udt_id,
                                a_asofdate      DATE,
                                a_procedurename VARCHAR2,
                                a_proceduredescription VARCHAR2,
                                a_runas         VARCHAR2,
                                a_serverkey     NUMBER,
                                a_scheduleddate DATE DEFAULT NULL)
    IS
        t_arguments     VARCHAR2(4000);
        t_jobid         udt_id;
        t_schedulekey   udt_id;
    BEGIN
        SELECT jobid
          INTO t_jobid
          FROM api.processes
         WHERE processid = a_objectid;

        --set up arguments for scheduler
        scheduler.pkg_scheduler.addargument(t_arguments,
                                            'procedure',
                                            a_procedurename);
        scheduler.pkg_scheduler.addargument(t_arguments,
                                            'EffectiveUser',
                                            a_runas);

        scheduler.pkg_scheduler.addargument(t_arguments, 'arg1', a_objectid);
        scheduler.pkg_scheduler.addargument(t_arguments, 'arg2', SYSDATE);
        scheduler.pkg_scheduler.addargument(t_arguments, 'arg3', t_jobid);

        --schedule item to be handled by the process server
        t_schedulekey   :=
            scheduler.pkg_scheduler.scheduleitem(
                a_scheduleddate,
                2,
                'nc_0011_ExecuteProcedureAsPosseUser',
                t_arguments,
                   'Execute Procedure: '
                || a_proceduredescription
                || ' on job '
                || TO_CHAR(t_jobid),
                a_serverkey);
    EXCEPTION
        WHEN OTHERS THEN
            api.pkg_errors.clear();
            api.pkg_errors.setargvalue(
                'Custom Procedure',
                'sitespecific.pkg_SysSchedule.ScheduleProcedure');
            api.pkg_errors.raiseerror(
                -20000,
                'ScheduleProcedure Error raised: ' || SQLERRM);
    END scheduleprocedure;

    /*----------------------------------------------------------------------------------------------------------------*
      * Procedure ScheduleLicenseBatchProcess()
      * Specifically coded for a specific scenario. NOT GENERIC!!!
      *----------------------------------------------------------------------------------------------------------------*/
    PROCEDURE schedulelicensebatchprocess(
        a_objectid      udt_id,
        a_asofdate      DATE,
        a_scheduleddate DATE DEFAULT SYSDATE,
        a_jobid         udt_id,
        a_outcome       VARCHAR2)
    IS
        t_arguments     VARCHAR2(4000);
        t_schedulekey   udt_id;
    BEGIN
        --set up arguments for scheduler
        scheduler.pkg_scheduler.addargument(t_arguments,
                                            'procedure',
                                            'api.pkg_processupdate.Complete');
        scheduler.pkg_scheduler.addargument(t_arguments,
                                            'EffectiveUser',
                                            'POSSESYS');

        scheduler.pkg_scheduler.addargument(t_arguments, 'arg1', a_objectid);
        scheduler.pkg_scheduler.addargument(t_arguments, 'arg2', a_outcome);

        --schedule item to be handled by the process server
        t_schedulekey   :=
            scheduler.pkg_scheduler.scheduleitem(
                a_scheduleddate,
                2,
                'nc_0011_ExecuteProcedureAsPosseUser',
                t_arguments,
                   'Complete process: '
                || a_objectid
                || ' on job '
                || a_jobid
                || ' with outcome '
                || a_outcome,
                1);
    EXCEPTION
        WHEN OTHERS THEN
            api.pkg_errors.clear();
            api.pkg_errors.setargvalue(
                'Custom Procedure',
                'sitespecific.pkg_SysSchedule.ScheduleLicenseBatchProcess');
            api.pkg_errors.raiseerror(
                -20000,
                'ScheduleLicenseBatchProcess Error raised: ' || SQLERRM);
    END schedulelicensebatchprocess;
END pkg_sysschedule;
/
