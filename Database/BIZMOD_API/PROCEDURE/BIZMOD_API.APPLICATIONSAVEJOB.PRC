CREATE OR REPLACE PROCEDURE BIZMOD_API.applicationsavejob(
    a_objectid     api.pkg_definition.udt_id,
    a_asofdate     DATE,
    a_jobid        api.pkg_definition.udt_id)
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
    --   1.3  07/01/2024 TJL  BIZ-15808  Initial Procedure Created
    -- ****************************************************************************
    t_url         constant varchar2(1000) := '/api/licensing/internal/licenseapp/applications/<<applicationId>>?status=<<status>>';
    t_method      constant varchar2(10) := 'PATCH';
    t_urlinfo     VARCHAR2(10000);
    t_response     json_object_t;
    t_applicationid VARCHAR2(40);
    t_process      VARCHAR2(32) := 'APPLICATIONSAVEJOB';
    t_sqlerrm      VARCHAR2(4000);
    t_trace        VARCHAR2(4000);
    t_status       VARCHAR2(40);
    t_info         VARCHAR2(4000);
    t_results      CLOB;
BEGIN
    BEGIN
        t_applicationid := api.pkg_columnquery.VALUE(a_jobid, 'LSPId');

        t_status := case api.pkg_columnquery.VALUE(a_jobid, 'StatusName') 
                      when 'NEW' then 'PEND'
                      
                      else api.pkg_columnquery.VALUE(a_jobid, 'StatusName')
                    end;

        IF (t_status IS NOT NULL)
        THEN

       t_urlinfo := REPLACE(REPLACE(t_url, '<<applicationId>>', t_applicationid), '<<status>>', t_status);

        t_results :=
            bizmod_api.utl_licenseinfo.calllsp(
                a_urlinfo   => t_urlinfo,
                a_method    => t_method);

            t_response := json_object_t.parse(t_results);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            t_sqlerrm := SQLERRM;
            t_trace := DBMS_UTILITY.format_error_backtrace;
    END;

    IF (t_sqlerrm IS NULL)
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

    INSERT INTO bizmod_api.e_process_log_t(seq,
                                           processjob,
                                           info,
                                           errmsg,
                                           bktrace)
             VALUES (
                 0,
                 t_process,
                 'Application Id: '
                 || t_applicationid
                 || CHR(13)
                 || 'Status: '
                 || t_status
                 || CHR(13)
                 || 'j_Application: '
                 || a_jobid
                 || CHR(13)
                 || CASE
                        WHEN t_results IS NOT NULL or t_sqlerrm is not null
                        THEN
                            'Info: '
                            || t_info
                            || CHR(13)
                            || 'LSP Response: '
                            || t_results
                        ELSE
                            NULL
                    END,
                 t_sqlerrm,
                 t_trace);

    COMMIT;
END;
/


GRANT EXECUTE ON BIZMOD_API.APPLICATIONSAVEJOB TO POSSEEXTENSIONS;
