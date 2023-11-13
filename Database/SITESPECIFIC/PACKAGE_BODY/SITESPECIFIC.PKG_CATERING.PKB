CREATE OR REPLACE PACKAGE BODY SITESPECIFIC.pkg_catering
AS
    -- **************************************************************************
    -- File:        PSITESPECIFIC.PKG_CATERING.PKB
    -- Author:      Timothy J. Lord
    --
    -- History:
    -----------------------------------------------------------------------------
    --    Ver:     Date                       Comment
    --     1.0   11/01/2023  TJL BIZ-12802  Initial Package Created
    -- **************************************************************************
    PROCEDURE cateringnotifylsp(a_objectid     api.pkg_definition.udt_id,
                                a_asofdate     DATE)
    IS
        t_arguments    VARCHAR2(4000);
        t_schedulekey  api.pkg_definition.udt_id;
        a_scheduleddate DATE := SYSDATE;
        t_sqlerrm      VARCHAR2(4000);
        t_trace        VARCHAR2(4000);
    BEGIN
        --set up arguments for scheduler
        scheduler.pkg_scheduler.addargument(
            t_arguments,
            'procedure',
            'BIZMOD_API.CATERINGNOTIFYLSPJOB');
        scheduler.pkg_scheduler.addargument(t_arguments,
                                            'EffectiveUser',
                                            'ABC');

        scheduler.pkg_scheduler.addargument(t_arguments,
                                            'arg1',
                                            NVL(a_objectid, '0'));
        scheduler.pkg_scheduler.addargument(t_arguments, 'arg2', SYSDATE);

        --schedule item to be handled by the process server
        t_schedulekey :=
            scheduler.pkg_scheduler.scheduleitem(
                a_scheduleddate,
                2,
                'nc_0011_ExecuteProcedureAsPosseUser',
                t_arguments,
                'E-Services Catering Notify LSP Job',
                1); --serverkey

    EXCEPTION
        WHEN OTHERS
        THEN
            t_sqlerrm := SQLERRM;
            t_trace := DBMS_UTILITY.format_error_backtrace;

            INSERT INTO bizmod_api.e_process_log_t(seq,
                                                   processjob,
                                                   info,
                                                   errmsg,
                                                   bktrace)
                     VALUES (
                         0,
                         'CATERINGNOTIFYLSP',
                         'Application Id: ' || a_objectid,
                         t_sqlerrm,
                         t_trace);
    END;
END;
/
