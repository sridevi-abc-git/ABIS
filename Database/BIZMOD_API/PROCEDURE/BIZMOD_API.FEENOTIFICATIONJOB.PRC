CREATE OR REPLACE PROCEDURE BIZMOD_API.feenotificationjob(
    a_objectid     api.pkg_definition.udt_id,
    a_asofdate     DATE,
    a_jobid        api.pkg_definition.udt_id,
    a_retry        BOOLEAN DEFAULT FALSE)
AS
    -- ****************************************************************************
    -- File:        BIZMOD_API.FEENOTIFICATIONJOB.PRC
    -- Author:      Timothy J. Lord
    --
    -- Purpose :
    --
    -- History:
    -------------------------------------------------------------------------------
    --              Date           Ticket     Comment
    --   1.0.0    09/16/2025 TJL  BIZ-19212  Initial Procedure Created
    --   2.0.0    11/03/2025 TJL  BIZ-19554  Added test for non-active licenses so
    --                                         only active licenses will be notified.
    --   3.0.0    11/24/2025 TJL  BIZ-19701  Added support to retry job job on timeout error
    --   4.0.0    03/09/2026 TJL  BIZ-20213  Added enhance logging
    -- ****************************************************************************
    t_url CONSTANT VARCHAR2(1000)
                       := '/api/licensing/internal/license-applications/' ;
    t_method CONSTANT VARCHAR2(10) := 'PATCH';
    t_process CONSTANT VARCHAR2(32) := 'FEENOTIFICATIONJOB';
    t_body         json_object_t := json_object_t();
    t_status       VARCHAR2(50);
    t_applicationid NUMBER;
    t_seq          NUMBER;
    t_errid        NUMBER;
    t_sqlerrm      VARCHAR2(4000);
    t_body_value   CLOB;
    t_results      json_object_t;
    t_results_text VARCHAR2(32767);
    t_retry        VARCHAR2(1) := CASE WHEN a_retry THEN 'Y' ELSE 'N' END;
    t_status_code  NUMBER;
BEGIN
    t_applicationid := api.pkg_columnquery.VALUE(a_jobid, 'LSPId');
    t_status :=
        UPPER(
            NVL(api.pkg_columnquery.VALUE(a_objectid, 'ModifyType'),
                'FEES_DUE'));

    IF (api.pkg_columnquery.VALUE(a_jobid, 'StatusName') NOT IN ('VOID',
                                                                 'ISSUED',
                                                                 'WITHDRAWN',
                                                                 'DENIED'))
    THEN
        t_body.put('status', t_status);
        t_body.put('objectId', a_jobid);
        t_body.put('licenseNumber',
                   api.pkg_columnquery.VALUE(a_jobid, 'LICENSENUMBER'));

        t_results :=
            bizmod_api.utl_licenseinfo.notify_lsp(
                a_urlinfo   => t_url || t_applicationid,
                a_method    => t_method,
                a_licensenumber =>
                    api.pkg_columnquery.VALUE(a_jobid, 'LICENSENUMBER'),
                a_objectid  => a_jobid,
                a_applicationid => t_applicationid,
                a_process   => t_process,
                a_content   => t_body);
    END IF;

    t_results_text := t_results.TO_CLOB;
    t_body_value := t_body.TO_CLOB;

    t_seq := NVL(t_results.get_number('seq'), 0);
    t_errid := t_results.get_number('errid');
    t_status_code := t_results.get_number('status_code');

    IF (t_status_code != 200
    AND t_status_code > 0)
    THEN
        t_sqlerrm := t_results.get_clob('lspresponse');
        INSERT INTO bizmod_api.e_errors_t e(e.licensenumber,
                                            e.objectid,
                                            e.applicationid,
                                            e.process,
                                            e.errcode,
                                            e.errm)
             VALUES (api.pkg_columnquery.VALUE(a_jobid, 'LICENSENUMBER'),
                     a_jobid,
                     t_applicationid,
                     t_process,
                     t_status_code,
                     t_sqlerrm)
          RETURNING errid
               INTO t_errid;

        UPDATE bizmod_api.eservices_log_t l
           SET l.errid = t_errid
         WHERE l.seq = t_seq;

        COMMIT;
    END IF;

    IF (t_status_code != bizmod_api.utl_licenseinfo.gc_request_fail
     OR a_retry)
    THEN
        INSERT INTO bizmod_api.e_process_log_t pl(pl.seq,
                                                  pl.licensenumber,
                                                  pl.objectid,
                                                  pl.applicationid,
                                                  pl.processjob,
                                                  pl.errid,
                                                  pl.info,
                                                  pl.packet)
                 VALUES (
                            t_seq,
                            api.pkg_columnquery.VALUE(a_jobid,
                                                      'LICENSENUMBER'),
                            a_jobid,
                            t_applicationid,
                            t_process,
                            t_errid,
                            SUBSTR(
                                'Status: '
                                || t_status
                                || CHR(13)
                                || 'Return Code: '
                                || t_status_code
                                || CHR(13)
                                || 'Retried: '
                                || CASE t_retry
                                       WHEN 'Y' THEN 'TRUE'
                                       ELSE 'FALSE'
                                   END
                                || CHR(13)
                                || t_results_text,
                                1,
                                3999),
                            t_body_value);

        COMMIT;
    ELSE
        bizmod_api.utl_licenseinfo.createjob(
            a_procedure => t_process,
            a_application_id => api.pkg_columnquery.VALUE(a_jobid, 'LSPId'),
            a_parameters => bizmod_api.job_prameters_tbl(a_objectid,
                                                         SYSTIMESTAMP,
                                                         a_jobid,
                                                         'TRUE'));
        COMMIT;
    END IF;
END;
/


GRANT EXECUTE ON BIZMOD_API.FEENOTIFICATIONJOB TO POSSEEXTENSIONS;
