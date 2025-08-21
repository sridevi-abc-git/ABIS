CREATE OR REPLACE PROCEDURE BIZMOD_API.applicationsavejob(
    a_objectid     api.pkg_definition.udt_id,
    a_asofdate     DATE,
    a_jobid        api.pkg_definition.udt_id,
    a_status       VARCHAR2 DEFAULT NULL)
AS
    -- ****************************************************************************
    -- File:        BIZMOD_API.APPLICATIONSAVEJOB.PRC
    -- Author:      Timothy J. Lord
    --
    -- Purpose :
    --
    -- History:
    -------------------------------------------------------------------------------
    --          Date           Ticket     Comment
    --   1.3    07/01/2024 TJL  BIZ-15808  Initial Procedure Created
    --   2.0    08/14/2024 TJL  BIZ-16073  Added URL info and status packet
    --                                       Reference BIZ-15319
    --   3.0.0  09/12/2024 TJL  BIZ-16077  Added logging email info
    --   4.0.0  10/09/2024 TJL  BIZ-16249  Correct ABIS 'NEW' status to return POSTED
    --   5.0    10/09/2024 BN   BIZ-16432  Modified License number to 6 digit
    --   6.0.1  11/07/2024 TJL  BIZ-16535  Bug in handling NULLs in return value from
    --                                       call to CALLLSP function.
    --   6.1.0  12/02/2024 TJL  BIZ-16697  Added updating Status Name field in bizmod_api.license_app_t
    --   6.2.0  01/28/2025 TJL             Added license number to the email notification.
    --   6.2.1  01/29/2025
    --   6.3.0  02/03/2025 TJL  BIZ-17356  Added handling of the return value from CALLLSP and call
    --                                       to lsplogin
    --   6.3.1  02/13/2026 TJL  BIZ-17356  Limit string length for info value
    --   6.3.2  02/14/2025 TJL  BIZ-17356  Change how lsp response for error is handled.
    --   7.0.0  03/05/2025 TJL  BIZ-17503  Corrected bug in logging errors from CALLLSP
    --   8.0.0  07/22/2025 TJL  BIZ-18902  Corrected bug in parsing lspresponse
    -- ****************************************************************************
    t_url CONSTANT VARCHAR2(1000)
                       := '/api/licensing/internal/license-applications/' ;
    t_method CONSTANT VARCHAR2(10) := 'PATCH';
    t_body         json_object_t := json_object_t();
    t_applicationid VARCHAR2(40);
    t_process      VARCHAR2(32) := 'APPLICATIONSAVEJOB';
    t_sqlerrm      VARCHAR2(32000);
    t_trace        VARCHAR2(4000);
    t_status       VARCHAR2(40) := a_status;
    t_body_value   CLOB;
    t_results      json_object_t;
    t_token        VARCHAR2(1000);
    t_results_text VARCHAR2(32767);
BEGIN
    BEGIN
        t_applicationid := api.pkg_columnquery.VALUE(a_jobid, 'LSPId');

        IF (t_status IS NULL)
        THEN
            t_status :=
                CASE UPPER(api.pkg_columnquery.VALUE(a_jobid, 'StatusName'))
                    WHEN 'NEW' THEN 'POSTED'
                    ELSE api.pkg_columnquery.VALUE(a_jobid, 'StatusName')
                END;
        END IF;

        t_body.put('status', t_status);
        t_body.put('objectId', a_jobid);
        t_body.put(
            'licenseNumber',
            TO_NUMBER(api.pkg_columnquery.VALUE(a_jobid, 'LICENSENUMBER')));

        t_results := bizmod_api.utl_licenseinfo.lsplogin;

        IF (t_results.get_number('status') = 200)
        THEN
            t_token :=
                t_results.get_object('lspresponse').get_string('token');

            t_results :=
                bizmod_api.utl_licenseinfo.calllsp(
                    a_urlinfo   => t_url || t_applicationid,
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
                        SUBSTR(
                            'Application Id: '
                            || t_applicationid
                            || CHR(13)
                            || 'Status: '
                            || t_status
                            || CHR(13)
                            || 'License Number: '
                            || api.pkg_columnquery.VALUE(a_jobid,
                                                         'LICENSENUMBER')
                            || CHR(13)
                            || 'j_Application: '
                            || a_jobid
                            || CHR(13)
                            || 'Results: '
                            || CHR(9)
                            || t_results_text,
                            1,
                            3999),
                        SUBSTR(t_sqlerrm, 1, 4000),
                        t_trace,
                        t_body_value);

    UPDATE bizmod_api.license_app_t la
       SET la.statusname = t_status
     WHERE la.jobid = a_jobid;

    COMMIT;
END;
/


GRANT EXECUTE ON BIZMOD_API.APPLICATIONSAVEJOB TO POSSEEXTENSIONS;
