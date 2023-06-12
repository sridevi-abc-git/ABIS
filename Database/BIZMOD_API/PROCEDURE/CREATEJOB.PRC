CREATE OR REPLACE PROCEDURE createjob(a_procedure    VARCHAR2,
                                      a_description  VARCHAR2,
                                      a_argument1    VARCHAR2)
IS
    -- ****************************************************************************
    -- File:        CREATEJOB.PRC
    -- Author:      Timothy J. Lord
    --
    -- Purpose :
    --
    -- History:
    -------------------------------------------------------------------------------
    --    Date           Ticket     Comment
    --  05/31/2023 TJL            Initial Procedure Created
    -- ****************************************************************************
    t_arguments    VARCHAR2(4000);
    t_schedulekey  api.pkg_definition.udt_id;
    a_scheduleddate DATE := SYSDATE;
BEGIN
    --set up arguments for scheduler
    scheduler.pkg_scheduler.addargument(t_arguments,
                                        'procedure',
                                        'BIZMOD_API.' || a_procedure);
    scheduler.pkg_scheduler.addargument(t_arguments, 'EffectiveUser', 'ABC');

    scheduler.pkg_scheduler.addargument(t_arguments, 'arg1', a_argument1);
    scheduler.pkg_scheduler.addargument(t_arguments, 'arg2', SYSDATE);

    --schedule item to be handled by the process server
    t_schedulekey :=
        scheduler.pkg_scheduler.scheduleitem(
            a_scheduleddate,
            2,
            'nc_0011_ExecuteProcedureAsPosseUser',
            t_arguments,
            'E-Services ' || a_description,
            1); --serverkey

    api.pkg_logicaltransactionupdate.endtransaction;
    COMMIT;
EXCEPTION
    WHEN OTHERS
    THEN
        api.pkg_errors.clear();
        api.pkg_errors.setargvalue('Custom Procedure',
                                   'bizmod_api.' || a_procedure);
        api.pkg_errors.raiseerror(
            -20000,
            'ScheduleProcedure Error raised: ' || SQLERRM);
END;
/
