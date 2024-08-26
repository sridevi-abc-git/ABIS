CREATE OR REPLACE PROCEDURE BIZMOD_API.newfeejob(
    a_objectid     api.pkg_definition.udt_id,
    a_asofdate     DATE)
AS
    -- ****************************************************************************
    -- File:        BIZMOD_API.NEWFEEJOB.PRC
    -- Author:      Timothy J. Lord
    --
    -- Purpose :
    --
    -- History:
    -------------------------------------------------------------------------------
    --          Date           Ticket     Comment
    --   1.2  07/01/2024 TJL  BIZ-15812  Initial Procedure Created
    --   2.0  08/14/2014 TJL  BIZ-16069  Added URL info and status packet
    --                                   Reference BIZ-15319
    -- ****************************************************************************
    t_url         constant varchar2(1000) := '/api/licensing/internal/license-applications/<<applicationId>>';
    t_method      constant varchar2(10) := 'PATCH';
    t_status      constant VARCHAR2(50) := 'FEE';
    t_urlinfo     VARCHAR2(10000);
    t_process     constant VARCHAR2(32) := 'NEWFEEJOB';
    t_body         json_object_t := json_object_t();
    t_response     json_object_t;
    t_applicationid NUMBER;
    t_sqlerrm      VARCHAR2(4000);
    t_trace        VARCHAR2(4000);
    t_info         VARCHAR2(4000);
    t_results      CLOB;
BEGIN
    BEGIN
        
        t_applicationid := api.pkg_columnquery.VALUE(a_objectid, 'LSPId');
       t_urlinfo := REPLACE(t_url, '<<applicationId>>', t_applicationid);

        t_body.put('status', t_status);
        t_body.put('objectId', a_objectid);
        t_body.put('licenseNumber', api.pkg_columnquery.value(a_objectid, 'ExternalFileNum'));
        
        t_results :=
            bizmod_api.utl_licenseinfo.calllsp(
                a_urlinfo   => t_urlinfo,
                a_method    => t_method,
                a_content   => t_body.to_clob);
        t_response := json_object_t.parse(t_results);
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
                 || 'j_Application: '
                 || a_objectid
                 || CHR(13)
                 || CASE
                        WHEN t_results IS NOT NULL
                          OR t_sqlerrm IS NOT NULL
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

        UPDATE bizmod_api.license_app_t a
           set a.newfee = null
         where a.jobid = a_objectid;
    COMMIT;
END;
/


GRANT EXECUTE ON BIZMOD_API.NEWFEEJOB TO POSSEDBA;

GRANT EXECUTE ON BIZMOD_API.NEWFEEJOB TO POSSEEXTENSIONS;
