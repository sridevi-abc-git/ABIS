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
    --   4.2.0  02/04/2025 TJL  BIZ-17356  Added handling of the return value from CALLLSP and call
    --                                       to lsplogin
    --   4.2.1  02/13/2026 TJL  BIZ-17356  Limit string length for info value
    --   4.2.2  02/14/2025 TJL  BIZ-17356  Change how lsp response for error is handled.
    --   5.0.0  03/05/2025 TJL  BIZ-17503  Corrected bug in logging errors from CALLLSP
    --   6.0.0  04/22/2025 TJL  BIZ-18056  Added saving new fees to e_fees_t table
    --   7.0.0  05/21/2025 TJL  BIZ-18387  Change Merge for new column added to e_fees_t table
    --   8.0.0  06/18/2025 TJL  BIZ-18689  Change Merge for new column added to e_fees_t table
    -- ****************************************************************************
    t_url         constant varchar2(1000) := '/api/licensing/internal/license-applications/';
    t_method      constant varchar2(10) := 'PATCH';
    t_status      constant VARCHAR2(50) := 'FEES_DUE';
    t_urlinfo     VARCHAR2(10000);
    t_process     constant VARCHAR2(32) := 'NEWFEEJOB';
    t_body         json_object_t := json_object_t();
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
        t_urlinfo := REPLACE(t_url, '<<applicationId>>', t_applicationid);

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

        UPDATE bizmod_api.license_app_t a
           set a.newfee = null
         where a.jobid = a_objectid;

        --   6.0.0  04/22/2025 TJL  BIZ-18056
        MERGE INTO bizmod_api.e_fees_t f
             USING (SELECT t_applicationid lspid,
                           f.jobid,
                           f.description,
                           (SELECT reo.objectid
                              FROM api.registeredexternalobjects reo
                             WHERE (reo.linkvalue = TO_CHAR(f.feeid)
                                AND reo.objectdefid =
                                    api.pkg_configquery.objectdefidforname('o_Fee')))
                               feeobjid,
                           f.amount
                      FROM api.fees f where f.jobid = a_objectid
                           ) a
                ON (f.feeobjid = a.feeobjid)
        WHEN NOT MATCHED
        THEN
            INSERT VALUES (a.lspid,
                           a.jobid,
                           a.description,
                           a.feeobjid,
                           a.amount,
                           NULL,
                           NULL,
                           SYSDATE);

    COMMIT;
END;
/


GRANT EXECUTE ON BIZMOD_API.NEWFEEJOB TO POSSEDBA;

GRANT EXECUTE ON BIZMOD_API.NEWFEEJOB TO POSSEEXTENSIONS;
