CREATE OR REPLACE PROCEDURE bizmod_api.feenotificationjob(
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
    -- ****************************************************************************
    t_url CONSTANT VARCHAR2(1000)
                       := '/api/licensing/internal/license-applications/' ;
    t_method CONSTANT VARCHAR2(10) := 'PATCH';
    t_process CONSTANT VARCHAR2(32) := 'FEENOTIFICATIONJOB';
    t_body         json_object_t := json_object_t();
    t_status       VARCHAR2(50);
    t_applicationid NUMBER;
    t_sqlerrm      VARCHAR2(4000);
    t_trace        VARCHAR2(4000);
    t_value        CLOB;
    t_body_value   CLOB;
    t_results      json_object_t;
    t_token        VARCHAR2(1000);
    t_results_text VARCHAR2(32767);
BEGIN
    BEGIN
        t_applicationid := api.pkg_columnquery.VALUE(a_jobid, 'LSPId');
        t_status :=
            UPPER(
                NVL(api.pkg_columnquery.VALUE(a_objectid, 'ModifyType'),
                    'FEES_DUE'));

        IF (api.pkg_columnquery.VALUE(a_jobid, 'StatusName') NOT IN
                ('VOID',
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
                    a_content   => t_body);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            t_sqlerrm := SQLERRM;
            t_results.put('status', SQLCODE);
            t_results.put(
                'ora-error',
                SQLERRM || CHR(10) || DBMS_UTILITY.format_error_backtrace);
    END;

    t_results_text := t_results.TO_CLOB;
    t_body_value := t_body.TO_CLOB;

    IF (t_results.get_number('status') != 200
    AND t_sqlerrm IS NULL)
    THEN
        t_sqlerrm :=
            CASE
                WHEN t_results.get_type('lspresponse') = 'OBJECT'
                THEN
                    t_results.get_object('lspresponse').TO_CLOB || CHR(13)
                WHEN t_results.has('lspresponse')
                THEN
                    t_results.get_clob('lspresponse')
                ELSE
                    t_results.TO_CLOB
            END;
    END IF;

    IF (t_results.get_number('status') !=
        bizmod_api.utl_licenseinfo.gc_request_fail
     OR a_retry)
    THEN
        INSERT INTO bizmod_api.e_process_log_t(seq,
                                               processjob,
                                               info,
                                               errmsg,
                                               bktrace,
                                               packet)
                 VALUES (
                            0,
                            t_process,
                            SUBSTR(
                                'Application Id: '
                                || t_applicationid
                                || CHR(13)
                                || 'License Number: '
                                || api.pkg_columnquery.VALUE(a_jobid,
                                                             'LICENSENUMBER')
                                || CHR(13)
                                || 'j_Application: '
                                || a_jobid
                                || CHR(13)
                                || 'Notification Type: '
                                || t_status
                                || CHR(13)
                                || t_results_text,
                                1,
                                3999),
                            SUBSTR(t_sqlerrm, 1, 4000),
                            t_trace,
                            t_value);

        COMMIT;
    ELSE
        bizmod_api.utl_licenseinfo.createjob(
            a_procedure => t_process,
            a_application_id => api.pkg_columnquery.VALUE(a_jobid, 'LSPId'),
            a_parameters => bizmod_api.job_prameters_tbl(a_objectid,
                                                         a_asofdate,
                                                         a_jobid,
                                                         'TRUE'));
        COMMIT;
    END IF;
END;
/


GRANT EXECUTE ON bizmod_api.feenotificationjob TO posseextensions;