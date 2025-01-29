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
    --   1.2    07/01/2024 TJL  BIZ-15812  Initial Procedure Created
    --   2.0.1  08/14/2014 TJL  BIZ-16069  Added URL info and status packet
    --                                      Reference BIZ-15319
    --   3.0.0  09/12/2014 TJL  BIZ-16077  Added logging email info
    --   4.0.2  11/07/2024 TJL  BIZ-16535  Bug in handling NULLs in return value from
    --                                       call to CALLLSP function.
    --   4.1.1  01/29/2025 TJL  BIZ-17289  Corrected parsing bug of CALLLSP return value
    -- ****************************************************************************
    t_url         constant varchar2(1000) := '/api/licensing/internal/license-applications/<<applicationId>>';
    t_method      constant varchar2(10) := 'PATCH';
    t_status      constant VARCHAR2(50) := 'FEES_DUE';
    t_urlinfo     VARCHAR2(10000);
    t_process     constant VARCHAR2(32) := 'NEWFEEJOB';
    t_body         json_object_t := json_object_t();
    t_response     json_object_t;
    t_applicationid NUMBER;
    t_sqlerrm      VARCHAR2(4000);
    t_trace        VARCHAR2(4000);
    t_value        CLOB;
    t_results      CLOB;
BEGIN
    BEGIN
        
        t_applicationid := api.pkg_columnquery.VALUE(a_objectid, 'LSPId');
       t_urlinfo := REPLACE(t_url, '<<applicationId>>', t_applicationid);

        t_body.put('status', t_status);
        t_body.put('objectId', a_objectid);
        t_body.put('licenseNumber', api.pkg_columnquery.value(a_objectid, 'LICENSENUMBER'));
        
        t_results :=
            bizmod_api.utl_licenseinfo.calllsp(
                a_urlinfo   => t_urlinfo,
                a_method    => t_method,
                a_content   => t_body.to_clob);
        IF (t_results IS NOT NULL)
        THEN
            t_response := json_object_t.parse(t_results);
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
                    t_response.get_object('LSPRESPONSE').to_string --   4.1.0  01/29/2025 TJL
                WHEN t_response.has('ORA-ERROR')
                THEN
                    t_response.get_string('ORA-ERROR')
                ELSE
                    NULL
            END;
    END IF;
    t_value := t_body.to_clob;
    
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
                 || 'License Number: '
                 || api.pkg_columnquery.VALUE(a_objectid, 'LICENSENUMBER')
                 || CHR(13)
                 || 'j_Application: '
                 || a_objectid
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

        UPDATE bizmod_api.license_app_t a
           set a.newfee = null
         where a.jobid = a_objectid;
    COMMIT;
END;
/


GRANT EXECUTE ON BIZMOD_API.NEWFEEJOB TO POSSEDBA;

GRANT EXECUTE ON BIZMOD_API.NEWFEEJOB TO POSSEEXTENSIONS;
