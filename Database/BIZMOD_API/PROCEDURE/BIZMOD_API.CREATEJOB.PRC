CREATE OR REPLACE PROCEDURE BIZMOD_API.createjob(a_procedure    IN VARCHAR2,
                                                 a_description  IN VARCHAR2,
                                                 a_argument1    IN VARCHAR2 DEFAULT '0',
                                                 a_argument2    IN DATE DEFAULT SYSDATE)
IS
    -- ****************************************************************************
    -- File:        BIZMOD_API.CREATEJOB.PRC
    -- Author:      Timothy J. Lord
    --
    -- Purpose :
    --
    -- History:
    -------------------------------------------------------------------------------
    --          Date           Ticket     Comment
    --        05/31/2023 TJL            Initial Procedure Created
    --   2.0  07/01/2024 TJL  BIZ-15444  Added second argument to scheduled date
    -- ****************************************************************************
    t_arguments    VARCHAR2(4000);
    t_schedulekey  api.pkg_definition.udt_id;
BEGIN
    --set up arguments for scheduler
    scheduler.pkg_scheduler.addargument(t_arguments,
                                        'procedure',
                                        'BIZMOD_API.' || a_procedure);
    scheduler.pkg_scheduler.addargument(t_arguments, 'EffectiveUser', 'ABC');

    scheduler.pkg_scheduler.addargument(t_arguments, 'arg1', NVL(a_argument1, '0'));
    scheduler.pkg_scheduler.addargument(t_arguments, 'arg2', a_argument2);

    --schedule item to be handled by the process server
    t_schedulekey :=
        scheduler.pkg_scheduler.scheduleitem(
            a_argument2,
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
