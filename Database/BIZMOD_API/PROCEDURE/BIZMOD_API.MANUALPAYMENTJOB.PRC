CREATE OR REPLACE PROCEDURE BIZMOD_API.manualpaymentjob(
    a_objectid     api.pkg_definition.udt_id,
    a_asofdate     DATE,
    a_jobid        api.pkg_definition.udt_id,
    a_retry        BOOLEAN DEFAULT FALSE)
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
    --   3.0.0  09/16/2025 TJL  BIZ-19266  Change on how manual payment information is
    --                                       retrieved from ABIS.
    --   4.0.0  11/24/2025 TJL  BIZ-19701  Added support to retry job job on timeout error
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
    t_results_text VARCHAR2(32767);
    t_element      json_element_t;
    t_errors       VARCHAR2(32767);
    t_body         CLOB;
BEGIN
    -- check for any manual payments made in abis
    SELECT json_arrayagg(reo.objectid)     body
      INTO t_body
      FROM api.relationships  p
           JOIN api.paymenttransactions pt
               ON (pt.paymentid =
                   api.pkg_columnquery.numericvalue(p.toobjectid,
                                                    'PaymentId'))
           JOIN api.feetransactions f ON (f.transactionid = pt.transactionid) -- in (10971819,10971820))
           JOIN api.registeredexternalobjects reo
               ON (reo.objectdefid =
                   api.pkg_configquery.objectdefidforname('o_fee')
               AND reo.linkvalue = TO_CHAR(f.feeid))
     WHERE (p.endpointid =
            api.pkg_configquery.endpointidforname('p_ReceiptPayments',
                                                  'Payment')
        AND p.fromobjectid = a_objectid
        -- 08/07/2025 TJL  BIZ-19030
        AND NOT EXISTS
                (SELECT p.feeobjid
                   FROM bizmod_api.e_payments_t p
                  WHERE p.feeobjid = reo.objectid));

    t_sqlerrm := NULL;

    BEGIN
        t_applicationid := api.pkg_columnquery.VALUE(a_jobid, 'LSPId');
        t_urlinfo := REPLACE(t_url, '<<applicationId>>', t_applicationid);

        t_element := json_array_t.parse(t_body);

        t_results :=
            bizmod_api.utl_licenseinfo.notify_lsp(a_urlinfo   => t_urlinfo,
                                                  a_method    => t_method,
                                                  a_content   => t_element);
    EXCEPTION
        WHEN OTHERS
        THEN
            t_sqlerrm := SQLERRM;
            t_results.put('status', SQLCODE);
            t_results.put(
                'ora-error',
                SQLERRM || CHR(10) || DBMS_UTILITY.format_error_backtrace);
    END;

    IF (t_results.get_number('status') != 200
    AND t_sqlerrm IS NULL)
    THEN
        t_results_text :=
            t_results_text
            || api.pkg_columnquery.VALUE(a_jobid, 'LicenseNumber')
            || CHR(9)
            || RPAD(t_applicationid, 10, ' ')
            || CHR(9)
            || a_jobid
            || CHR(9)
            || t_results.get_number('status')
            || CHR(9)
            || t_body
            || CHR(13);
        t_errors :=
            t_errors
            || api.pkg_columnquery.VALUE(a_jobid, 'LicenseNumber')
            || CHR(9)
            || RPAD(t_applicationid, 10, ' ')
            || CHR(9)
            || a_jobid
            || CHR(9)
            || t_results.get_number('status')
            || CHR(9)
            || CASE
                   WHEN t_results.get_type('lspresponse') = 'OBJECT'
                   THEN
                       t_results.get_object('lspresponse').TO_CLOB
                   WHEN t_results.has('lspresponse')
                   THEN
                       t_results.get_clob('lspresponse')
                   ELSE
                       t_results.TO_CLOB
               END
            || CHR(13);
    ELSE
        t_results_text :=
            t_results_text
            || RPAD(t_applicationid, 10, ' ')
            || CHR(9)
            || a_jobid
            || CHR(9)
            || t_results.get_number('status')
            || CHR(9)
            || t_body
            || CHR(13);
    END IF;

    IF (t_results.get_number('status') !=
        bizmod_api.utl_licenseinfo.gc_request_fail
     OR a_retry)
    THEN
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
                         SUBSTR(t_results_text, 1, 4000),
                         SUBSTR(t_errors, 1, 4000),
                         t_trace,
                         t_value);

            COMMIT;
        END IF;
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


GRANT EXECUTE ON BIZMOD_API.MANUALPAYMENTJOB TO POSSEEXTENSIONS;
