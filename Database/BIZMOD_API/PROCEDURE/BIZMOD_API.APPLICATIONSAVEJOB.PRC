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
    -- ****************************************************************************
    t_url CONSTANT VARCHAR2(1000)
        := '/api/licensing/internal/license-applications/<<applicationId>>' ;
    t_method CONSTANT VARCHAR2(10) := 'PATCH';
    t_urlinfo      VARCHAR2(10000);
    t_response     json_object_t;
    t_body         json_object_t := json_object_t();
    t_applicationid VARCHAR2(40);
    t_process      VARCHAR2(32) := 'APPLICATIONSAVEJOB';
    t_sqlerrm      VARCHAR2(32000);
    t_trace        VARCHAR2(4000);
    t_status       VARCHAR2(40);
    t_value        CLOB;
    t_results      CLOB;
BEGIN
    BEGIN
        t_applicationid := api.pkg_columnquery.VALUE(a_jobid, 'LSPId');


        IF (a_status IS NOT NULL)
        THEN
            t_status := a_status;
        ELSE
            t_status :=
                CASE UPPER(api.pkg_columnquery.VALUE(a_jobid, 'StatusName'))
                    WHEN 'NEW' THEN 'POSTED'
                    ELSE api.pkg_columnquery.VALUE(a_jobid, 'StatusName')
                END;
        END IF;

        IF (t_status IS NOT NULL)
        THEN
            t_urlinfo := REPLACE(t_url, '<<applicationId>>', t_applicationid);

            t_body.put('status', t_status);
            t_body.put('objectId', a_jobid);
            t_body.put('licenseNumber', to_number(api.pkg_columnquery.VALUE(a_jobid, 'LICENSENUMBER')));

            t_results :=
                bizmod_api.utl_licenseinfo.calllsp(
                    a_urlinfo   => t_urlinfo,
                    a_method    => t_method,
                    a_content   => t_body.TO_CLOB);

            IF (t_results IS NOT NULL)
            THEN
                t_response := json_object_t.parse(t_results);
            END IF;
            
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            t_sqlerrm := SQLERRM;
            t_trace := DBMS_UTILITY.format_error_backtrace;
    END;

    IF (t_sqlerrm IS NULL AND t_results IS NOT NULL)
    THEN
        t_sqlerrm :=
            CASE
                WHEN t_response.has('LSPRESPONSE')
                THEN
                    t_response.get_string('LSPRESPONSE')
                WHEN t_response.has('ORA-ERROR')
                THEN
                    t_response.get_string('ORA-ERROR')
                ELSE
                    NULL
            END;
    END IF;

    t_value := t_body.TO_CLOB;

    INSERT INTO bizmod_api.e_process_log_t(seq,
                                           processjob,
                                           info,
                                           errmsg,
                                           bktrace,
                                           packet)
             VALUES (
                        0,
                        t_process,
                        'Application Id: '
                        || t_applicationid
                        || CHR(13)
                        || 'Status: '
                        || t_status
                        || CHR(13)
                        || 'License Number: '
                        || api.pkg_columnquery.VALUE(a_jobid, 'LICENSENUMBER')
                        || CHR(13)
                        || 'j_Application: '
                        || a_jobid
                        || CHR(13)
                        || CASE
                               WHEN t_results IS NOT NULL
                               THEN
                                   CHR(13)
                                   || 'Call LSP Information: '
                                   || json_query(t_results, '$' RETURNING CLOB PRETTY)
                                   || CHR(13)
                               ELSE
                                   NULL
                           END,
                        substr(t_sqlerrm,1,4000),
                        t_trace,
                        t_value);

    -- 12/02/2024 TJL  BIZ-16697 
    UPdate bizmod_api.license_app_t la
       set la.statusname = t_status
     where la.jobid = a_jobid;
     
    COMMIT;
END;
/


GRANT EXECUTE ON BIZMOD_API.APPLICATIONSAVEJOB TO POSSEEXTENSIONS;
