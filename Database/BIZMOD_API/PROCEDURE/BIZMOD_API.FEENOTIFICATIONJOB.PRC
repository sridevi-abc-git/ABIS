CREATE OR REPLACE PROCEDURE BIZMOD_API.FEENOTIFICATIONJOB(
    a_objectid     api.pkg_definition.udt_id,
    a_asofdate     DATE,
    a_jobid        api.pkg_definition.udt_id)
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
    -- ****************************************************************************
    t_url         constant varchar2(1000) := '/api/licensing/internal/license-applications/';
    t_method      constant varchar2(10) := 'PATCH';
    t_process     constant VARCHAR2(32) := 'FEENOTIFICATIONJOB';
    t_body         json_object_t := json_object_t();
    t_status      constant VARCHAR2(50);
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
        t_applicationid := api.pkg_columnquery.VALUE(a_objectid, 'LSPId');
        t_status := UPPER(nvl(api.pkg_columnquery.value(p.processid, 'ModifyType'), 'FEES_DUE'));
        
        t_body.put('status', t_status);
        t_body.put('objectId', a_objectid);
        t_body.put('licenseNumber', api.pkg_columnquery.value(a_objectid, 'LICENSENUMBER'));

        t_results := bizmod_api.utl_licenseinfo.lsplogin;

        IF (t_results.get_number('status') = 200)
        THEN
            t_token :=
                t_results.get_object('lspresponse').get_string('token');

            t_results :=
                bizmod_api.utl_licenseinfo.calllsp(a_urlinfo   => t_url || t_applicationid,
                                                   a_method    => t_method,
                                                   a_content   => t_body,
                                                   a_token     => t_token);

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
            CASE WHEN t_results.get_type('lspresponse') = 'OBJECT'
                THEN
                    t_results.get_object('lspresponse').TO_CLOB || CHR(13)
                WHEN t_results.has('lspresponse')
                then
                     t_results.get_clob('lspresponse')
                ELSE
                    t_results.TO_CLOB
            END;
    END IF;

    INSERT INTO bizmod_api.e_process_log_t(seq,
                                           processjob,
                                           info,
                                           errmsg,
                                           bktrace,
                                           packet)
             VALUES (
                 0,
                 t_process,
                 substr('Application Id: '
                 || t_applicationid
                 || CHR(13)
                 || 'License Number: '
                 || api.pkg_columnquery.VALUE(a_objectid, 'LICENSENUMBER')
                 || CHR(13)
                 || 'j_Application: '
                 || a_objectid
                 || CHR(13)
                 || t_results_text, 1, 3999),
                 substr(t_sqlerrm,1,4000),
                 t_trace,
                 t_value);

    COMMIT;
END;
/
