CREATE OR REPLACE PROCEDURE BIZMOD_API.manualpaymentjob(
    a_objectid     api.pkg_definition.udt_id,
    a_asofdate     DATE,
    a_jobid        api.pkg_definition.udt_id)
AS
    -- ****************************************************************************
    -- File:        BIZMOD_API.MANUALPAYMENTJOB.PRC
    -- Author:      Timothy J. Lord
    --
    -- Purpose :
    --
    -- History:
    -------------------------------------------------------------------------------
    --          Date           Ticket        Comment
    --   1.3    07/17/2025 TJL  BIZ-18875  Initial Procedure Created
    --   2.0.0  08/07/2025 TJL  BIZ-19030  Add check to make sure that LSP Payment
    --                                       is not sent as a manual payment notification.
    -------------------------------------------------------------------------------

        t_url CONSTANT VARCHAR2(1000)
            := '/api/licensing/internal/license-applications/<<applicationId>>/fees' ;
        t_method CONSTANT VARCHAR2(10) := 'PUT';
        t_urlinfo      VARCHAR2(10000);
        t_process CONSTANT VARCHAR2(32) := 'MANUALPAYMENTJOB';
        t_applicationid NUMBER;
        t_sqlerrm      VARCHAR2(32767);
        t_trace        VARCHAR2(4000);
        t_value        CLOB;
        t_results      json_object_t;
        t_token        VARCHAR2(1000);
        t_results_text VARCHAR2(32767);
        t_element      json_element_t;
        t_errors       VARCHAR2(32767);
    BEGIN
        t_results := bizmod_api.utl_licenseinfo.lsplogin;

        IF (t_results.get_number('status') = 200)
        THEN
            t_token :=
                t_results.get_object('lspresponse').get_string('token');
        END IF;
        -- check for any manual payments made in abis
        -- 05/14/2025  TJL  BIZ-18387
        IF (t_token IS NOT NULL)
        THEN
            FOR j
                IN (  SELECT f.lspid, f.jobid, json_arrayagg(f.feeobjid) body
                        FROM bizmod_api.e_fees_t f
                       WHERE f.paiddate IS NULL
                         AND f.jobid = a_jobid
                         AND api.pkg_columnquery.VALUE(f.feeobjid,
                                                       'Paidamount') <
                             0
                         -- 08/07/2025 TJL  BIZ-19030
                         AND NOT EXISTS(select f.feeobjid
                                          from bizmod_api.e_payments_t p
                                         where p.feeobjid = f.feeobjid
                                       )
                    GROUP BY f.lspid, f.jobid)
            LOOP
                t_sqlerrm := NULL;

                BEGIN
                    t_applicationid :=
                        api.pkg_columnquery.VALUE(j.jobid, 'LSPId');
                    t_urlinfo :=
                        REPLACE(t_url, '<<applicationId>>', t_applicationid);

                    t_element := json_array_t.parse(j.body);

                    t_results :=
                        bizmod_api.utl_licenseinfo.calllsp(
                            a_urlinfo   => t_urlinfo,
                            a_method    => t_method,
                            a_content   => t_element,
                            a_token     => t_token);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        t_sqlerrm := SQLERRM;
                        t_results.put('status', SQLCODE);
                        t_results.put(
                            'ora-error',
                            SQLERRM
                            || CHR(10)
                            || DBMS_UTILITY.format_error_backtrace);
                END;

                IF (t_results.get_number('status') != 200
                AND t_sqlerrm IS NULL)
                THEN
                    t_results_text :=
                        t_results_text
                        || api.pkg_columnquery.VALUE(j.jobid, 'LicenseNumber')
                        || chr(9)
                        || rpad(j.lspid, 10, ' ')
                        || chr(9)
                        || j.jobid
                        || CHR(9)
                        || t_results.get_number('status')
                        || CHR(9)
                        || j.body
                        || CHR(13);
                    t_errors :=
                        t_errors
                        || api.pkg_columnquery.VALUE(j.jobid, 'LicenseNumber')
                        || chr(9)
                        || rpad(j.lspid, 10, ' ')
                        || chr(9)
                        || j.jobid
                        || CHR(9)
                        || t_results.get_number('status')
                        || CHR(9)
                        || CASE WHEN t_results.get_type('lspresponse') = 'OBJECT'
                                THEN
                                    t_results.get_object('lspresponse').TO_CLOB
                                WHEN t_results.has('lspresponse')
                                then
                                     t_results.get_clob('lspresponse')
                                ELSE
                                    t_results.TO_CLOB
                                END
                                   || CHR(13);
                else
                    t_results_text :=
                        t_results_text
                        || rpad(j.lspid, 10, ' ')
                        || chr(9)
                        || j.jobid
                        || CHR(9)
                        || t_results.get_number('status')
                        || CHR(9)
                        || j.body
                        || CHR(13);

                END IF;
                -- get the fees that were paid to update fees table
                UPDATE bizmod_api.e_fees_t f
                   SET f.paiddate = SYSDATE, f.manualpayment = 'Y'
                 WHERE f.feeobjid IN
                           (SELECT f.feeobjid
                              FROM JSON_TABLE(j.body,
                                              '$[*]'
                                              COLUMNS(feeobjid PATH '$')) f);

                COMMIT;
            END LOOP;
        ELSE
            NULL;
        END IF;

        IF (t_results_text IS NOT NULL)
        THEN
            INSERT INTO bizmod_api.e_process_log_t(seq,
                                                   processjob,
                                                   info,
                                                   errmsg,
                                                   bktrace,
                                                   packet)
                 VALUES (0,
                         t_process,
                         SUBSTR(SUBSTR(t_results_text, 1, 4000), 1, 3999),
                         SUBSTR(t_errors, 1, 4000),
                         t_trace,
                         t_value);
            COMMIT;
        END IF;
    END;
/


GRANT EXECUTE ON BIZMOD_API.MANUALPAYMENTJOB TO POSSEEXTENSIONS;
