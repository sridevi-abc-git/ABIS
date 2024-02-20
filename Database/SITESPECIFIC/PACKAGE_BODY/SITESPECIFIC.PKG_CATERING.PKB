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
        t_cnt          NUMBER := 0;
        t_sqlerrm      VARCHAR2(4000);
        t_trace        VARCHAR2(4000);
    BEGIN
        a_scheduleddate :=
            CASE api.pkg_columnquery.VALUE(a_objectid, 'OutCome')
                WHEN 'Approved' THEN -- add 2 minute delay to when job is to run to allow abc-218 to be generated
                                     SYSDATE + ((1 / 24 / 60) * 2)
                ELSE SYSDATE
            END;

        -- check to see if this application has already been secheuled. This process can be called twice
        --  when application is approved
        SELECT COUNT(s.object)
          INTO t_cnt
          FROM scheduler.sysschedule s
         WHERE s.description =
               'E-Services Catering Notify LSP Job ' || a_objectid
           AND TRUNC(s.scheduledate) >= TRUNC(SYSDATE)
           AND status IN (1, 3);

        IF (t_cnt = 0)
        THEN
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
                    'E-Services Catering Notify LSP Job ' || a_objectid,
                    1); --serverkey
        END IF;
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
                 VALUES (0,
                         'CATERINGNOTIFYLSP',
                         'Application Id: ' || a_objectid,
                         t_sqlerrm,
                         t_trace);
    END;
END;
/
