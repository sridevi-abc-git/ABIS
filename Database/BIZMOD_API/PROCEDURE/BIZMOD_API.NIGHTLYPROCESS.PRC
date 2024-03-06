CREATE OR REPLACE PROCEDURE BIZMOD_API.nightlyprocess
IS
    -- ****************************************************************************
    -- File:        BIZMOD_API.NIGHTLYPROCESS.PRC
    -- Author:      Timothy J. Lord
    --
    -- Purpose :
    --
    -- History:
    -------------------------------------------------------------------------------
    --              Date           Ticket     Comment
    --          05/31/2023  TJL             Initial Procedure Created
    --   2.0    08/01/2023  TJL             Corrected bug in updating AWF completed flag
    --   3.0    01/11/2024  TJL             Added call to create AWF payment batches for zero
    --                                        amount due. Added updating new process log.
    --                                      Corrected bug in updating AWF fee object id.
    --   4.0    03/06/2024  TJL  BIZ-14725  Added getting AWF Payment Batch and updating payment
    --                                        record with payment batch job id when missing
    -- ****************************************************************************
    t_refunded     VARCHAR2(1);
    t_feetransfer  NUMBER;
    t_paymenttransfer NUMBER;
    t_awfbatch     NUMBER;

    t_body         VARCHAR2(32000);
    t_to           VARCHAR2(4000);
    t_from         VARCHAR2(4000);
    t_cc           VARCHAR2(4000);
    t_bcc          VARCHAR2(4000);
    t_rowcount     NUMBER;

    t_error        VARCHAR2(32000);
    t_sqlerrm      VARCHAR2(4000);
    t_trace        VARCHAR2(4000);
    t_payment      NUMBER;
    t_paymentbatch NUMBER;
    t_seq          NUMBER := bizmod_api.e_payment_seq.NEXTVAL();
    t_errorcnt     NUMBER := 0;
BEGIN
    -- ********************************************************************
    t_body := 'E-Service Nightly Job Completed' || CHR(10) || CHR(13);

    -- ********************************************************************
    -- ************************************************************
    -- Process any AWF reports that have 0 amount due or a refund
    -- ************************************************************
    BEGIN
        bizmod_api.createjob(a_procedure => 'CREATEAWFPAYMENTSJOB',
                             a_description => 'Create AWF Payment Batch',
                             a_argument1 => '0');

        -- ********************************************************************
        -- ************************************************************
        -- Check for payments being removed from original transmittal and
        --   updating payment record with new transmittal batch id or
        --   NULL if not assigned to another transmittal batch
        -- ************************************************************
        UPDATE bizmod_api.e_payments_t p
           SET p.transmittalbatch =
                   (SELECT rn.fromobjectid
                      FROM api.relationships rn
                     WHERE rn.endpointid =
                           api.pkg_configquery.endpointidforname(
                               'j_Transmittal',
                               'Payment')
                       AND rn.toobjectid = p.paymentobjectid)
         WHERE p.paymentobjectid IN
                   (SELECT DISTINCT p.paymentobjectid
                      FROM bizmod_api.e_payments_t p
                     WHERE p.transmittalbatch IS NOT NULL
                       AND p.issued IS NULL
                       AND NOT EXISTS
                               (SELECT 1
                                  FROM api.relationships rn
                                 WHERE rn.endpointid =
                                       api.pkg_configquery.endpointidforname(
                                           'j_Transmittal',
                                           'Payment')
                                   AND rn.fromobjectid = p.transmittalbatch
                                   AND rn.toobjectid = p.paymentobjectid));

        -- ************************************************************
        -- Update payment record for payments manually added to transmittal
        --    batch.
        -- ************************************************************
        UPDATE bizmod_api.e_payments_t p
           SET p.transmittalbatch =
                   (SELECT rn.fromobjectid
                      FROM api.relationships rn
                     WHERE rn.endpointid =
                           api.pkg_configquery.endpointidforname(
                               'j_Transmittal',
                               'Payment')
                       AND rn.toobjectid = p.paymentobjectid)
         WHERE p.paymentobjectid IN (SELECT DISTINCT p.paymentobjectid
                                       FROM bizmod_api.e_payments_t p
                                      WHERE p.transmittalbatch IS NULL)
           AND EXISTS
                   (SELECT 1
                      FROM api.relationships rn
                     WHERE rn.endpointid =
                           api.pkg_configquery.endpointidforname(
                               'j_Transmittal',
                               'Payment')
                       AND rn.toobjectid = p.paymentobjectid);

        -- ************************************************************
        --  Update transmittal completion date for transmittal manually completed
        -- ************************************************************
        UPDATE bizmod_api.e_payments_t p
           SET p.transmittalbatchdate =
                   api.pkg_columnquery.datevalue(p.transmittalbatch,
                                                 'CompletedDate')
         WHERE p.transmittalbatch IS NOT NULL
           AND p.transmittalbatchdate IS NULL;

        COMMIT;

        -- ************************************************************
        --  Get Deposit batch information for deposit batches that are
        --    manually created for completed transmittal batches.
        -- ************************************************************
        UPDATE bizmod_api.e_payments_t p
           SET (p.depositbatchid, p.depositbatchdate, p.depositstatus) =
                   (SELECT DISTINCT
                           r.toobjectid,
                           api.pkg_columnquery.datevalue(r.toobjectid,
                                                         'CreatedDate'),
                           api.pkg_columnquery.VALUE(r.toobjectid,
                                                     'StatusName')
                      FROM api.relationships r
                     WHERE r.endpointid =
                           api.pkg_configquery.endpointidforname(
                               'j_transmittal',
                               'Deposit')
                       AND r.fromobjectid = p.transmittalbatch)
         WHERE p.depositstatus IS NULL
           AND p.transmittalbatchdate IS NOT NULL;


        -- ************************************************************
        --  Update Deposit status of deposits completed
        -- ************************************************************
        UPDATE bizmod_api.e_payments_t p
           SET p.depositstatus =
                   api.pkg_columnquery.VALUE(p.depositbatchid, 'StatusName')
         WHERE NVL(p.depositstatus, 'X') = 'PREPAR';

        IF (SQL%ROWCOUNT > 0)
        THEN
            t_body :=
                t_body
                || 'Updating E-Services Payment Deposit Status'
                || CHR(10)
                || CHR(13);
        END IF;

        COMMIT;

        -- ********************************************************************
        --  Check for License Issued
        -- ********************************************************************
        t_rowcount := 0;

        FOR lts
            IN (SELECT api.pkg_columnquery.numericvalue(p.feeobjid, 'JobId')
                           jobid,
                       p.licensetypecode,
                       ltc.color,
                       TRUNC(
                           api.pkg_columnquery.datevalue(p.feeobjid,
                                                         'TransactionDate'))
                           transactiondate,
                       p.depositbatchdate
                  FROM bizmod_api.e_payments_t  p
                       JOIN query.o_licensetypecategory ltc
                           ON (ltc.licensetypecode = p.licensetypecode)
                 WHERE p.issued IS NULL
                   AND p.depositstatus = 'DEP')
        LOOP
            -- look if license has been issued for this renewal activity
            FOR b
                IN (SELECT *
                      FROM (SELECT /*+ materialize */
                                   api.pkg_columnquery.datevalue(
                                       x.licensebatchjobid,
                                       'completeddate')        completeddate,
                                   api.pkg_columnquery.VALUE(
                                       x.licensebatchjobid,
                                       'color')                color,
                                   api.pkg_columnquery.VALUE(
                                       x.licensebatchjobid,
                                       'BatchType')            batchtype,
                                   api.pkg_columnquery.VALUE(
                                       x.licensebatchjobid,
                                       'StatusDescription')    statusdescription
                              FROM sitespecific.licbatchlictype_xref_t x
                             WHERE x.licensetypejobid = lts.jobid) b
                     WHERE b.batchtype = 'PRODUCE LICENSES'
                       AND b.completeddate >= lts.depositbatchdate
                       AND b.color = lts.color
                       AND b.statusdescription = 'Complete')
            LOOP
                UPDATE bizmod_api.e_payments_t p
                   SET p.issued = 'Y'
                 WHERE api.pkg_columnquery.numericvalue(p.feeobjid, 'JobId') =
                       lts.jobid
                   AND p.licensetypecode = lts.licensetypecode
                   LOG ERRORS INTO bizmod_api.err$_e_payments_t
                           ('UPDATE')
                           REJECT LIMIT UNLIMITED;

                t_rowcount := t_rowcount + SQL%ROWCOUNT;

                COMMIT;
            END LOOP;
        END LOOP;

        IF (t_rowcount > 0)
        THEN
            t_body :=
                t_body
                || 'Licenses Issued by Produce Licenses Batches: '
                || t_rowcount
                || CHR(10)
                || CHR(13);
        END IF;

        -- ********************************************************************
        --  Update awf fee id and fee object id after payments have been completed
        -- ********************************************************************
        UPDATE bizmod_api.awf_t a
           SET (a.completed, a.awffeeid) =
                   (SELECT CASE
                               WHEN f.feeid IS NOT NULL THEN 'Y'
                               ELSE a.completed
                           END,
                           f.feeid
                      FROM api.fees f
                     WHERE f.jobid = a.licensetypejobid
                       AND f.transactiondate > a.createddate
                       AND f.description LIKE '%AWF%'
                       AND ROWNUM = 1)
         WHERE a.awffeeid IS NULL
           AND ((a.awffeeamount = 0
             AND a.paymentbatch IS NOT NULL)
             OR (NVL(a.completed, 'N') = 'N'
             AND a.awffeeamount > 0
             AND EXISTS
                     (SELECT 1
                        FROM bizmod_api.e_payments_t p
                       WHERE p.licensenumber = a.licensenumber
                         AND p.createddate >= a.submitteddate
                         AND p.description LIKE '%AWF%'))
            AND EXISTS
                    (SELECT 1
                       FROM api.fees f
                      WHERE f.jobid = a.licensetypejobid
                        AND f.transactiondate > a.submitteddate
                        AND f.description LIKE '%AWF%'));

        IF (SQL%ROWCOUNT > 0)
        THEN
            t_body := t_body || 'AWF Processed: ' || SQL%ROWCOUNT || CHR(13);
        END IF;

        COMMIT;

        -- ********************************************************************
        --  03/06/2024  TJL  BIZ-14725
        --  Update AWF payment batch when missing from payment table
        -- ********************************************************************
        FOR rec IN (SELECT p.feeobjid, p.seq
                      FROM bizmod_api.e_payments_t p
                     WHERE p.feeobjid IS NOT NULL
                       AND NVL(p.paymentobjectid, 0) = 0
                       AND p.description LIKE '%AWF%')
        LOOP
            BEGIN
                t_payment := NULL;

                SELECT api.pkg_simplesearch.objectbyindex(
                           'o_Payment',
                           'Paymentid',
                           api.pkg_columnquery.VALUE(reo.objectid,
                                                     'PaymentId'))
                  INTO t_payment
                  FROM api.registeredexternalobjects reo
                 WHERE reo.objectdefid =
                       api.pkg_configquery.objectdefidforname(
                           'o_PaymentTransactions')
                   AND reo.linkvalue =
                       (SELECT TO_CHAR(transactionid)
                          FROM api.feetransactions t
                         WHERE feeid =
                               api.pkg_columnquery.numericvalue(rec.feeobjid,
                                                                'FeeId'));

                SELECT r.toobjectid
                  INTO t_paymentbatch
                  FROM api.relationships r
                 WHERE r.endpointid =
                       api.pkg_configquery.endpointidforname('o_Payment',
                                                             'PaymentBatch')
                   AND r.fromobjectid = t_payment;

                UPDATE bizmod_api.e_payments_t p
                   SET p.paymentobjectid = t_paymentbatch,
                       p.processdate = SYSDATE,
                       p.processid = t_seq
                 WHERE seq = rec.seq;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    UPDATE bizmod_api.e_payments_t p
                       SET p.paymentobjectid = 0,
                           p.processdate = SYSDATE,
                           p.processid = t_seq
                     WHERE seq = rec.seq;

                    t_errorcnt := t_errorcnt + 1;
            END;

            COMMIT;
        END LOOP;

        FOR rec IN (SELECT a.awffeeid feeid, ROWID seq
                      FROM bizmod_api.awf_t a
                     WHERE a.awffeeid IS NOT NULL
                       AND a.paymentbatch IS NULL)
        LOOP
            BEGIN
                t_payment := NULL;

                SELECT api.pkg_simplesearch.objectbyindex(
                           'o_Payment',
                           'Paymentid',
                           api.pkg_columnquery.VALUE(reo.objectid,
                                                     'PaymentId'))
                  INTO t_payment
                  FROM api.registeredexternalobjects reo
                 WHERE reo.objectdefid =
                       api.pkg_configquery.objectdefidforname(
                           'o_PaymentTransactions')
                   AND reo.linkvalue = (SELECT TO_CHAR(transactionid)
                                          FROM api.feetransactions t
                                         WHERE feeid = rec.feeid);

                SELECT r.toobjectid
                  INTO t_paymentbatch
                  FROM api.relationships r
                 WHERE r.endpointid =
                       api.pkg_configquery.endpointidforname('o_Payment',
                                                             'PaymentBatch')
                   AND r.fromobjectid = t_payment;

                UPDATE bizmod_api.awf_t a
                   SET a.paymentbatch = t_paymentbatch,
                       a.paymentbatchdate =
                           api.pkg_columnquery.datevalue(t_paymentbatch,
                                                         'CreatedDate')
                 WHERE ROWID = rec.seq;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    UPDATE bizmod_api.awf_t a
                       SET a.paymentbatch = 0, a.paymentbatchdate = SYSDATE
                     WHERE ROWID = rec.seq;

                    t_errorcnt := t_errorcnt + 1;
            END;

            COMMIT;
        END LOOP;

        IF (t_errorcnt > 0)
        THEN
            t_error :=
                t_error
                || CHR(13)
                || 'AWF Process Errors: '
                || t_errorcnt
                || CHR(13);
        END IF;

        -- ********************************************************************
        --  check to see if AWF Refund has been completed
        -- ********************************************************************
        UPDATE bizmod_api.awf_t a
           SET a.awffeeid =
                   (SELECT f.feeid
                      FROM api.fees f
                     WHERE f.jobid = a.licensetypejobid
                       AND f.transactiondate > a.createddate
                       AND f.description LIKE '%AWF%'
                       AND ROWNUM = 1)
         WHERE a.awffeeid IS NULL
           AND a.awffeeamount < 0;

        COMMIT;

        FOR rec IN (SELECT a.renfeeid, a.renfeeobjid, ROWID id
                      FROM bizmod_api.awf_t a
                     WHERE a.awffeeamount < 0
                       AND NVL(a.completed, 'N') != 'Y')
        LOOP
              -- check if awf was refunded
              SELECT CASE
                         WHEN SUM(
                                  CASE
                                      WHEN api.pkg_columnquery.VALUE(
                                               reo.objectid,
                                               'RefundBatchId')
                                               IS NOT NULL
                                      THEN
                                          1
                                      ELSE
                                          0
                                  END) >
                              0
                         THEN
                             'Y'
                         ELSE
                             NULL
                     END
                INTO t_refunded
                FROM api.paymenttransactions pt
                     JOIN api.feetransactions ft
                         ON pt.transactionid = ft.transactionid
                     JOIN api.registeredexternalobjects reo
                         ON (reo.linkvalue = TO_CHAR(pt.paymentid)
                         AND reo.objectdefid =
                             api.pkg_configquery.objectdefidforname(
                                 'o_Payment'))
               WHERE ft.feeid = rec.renfeeid
            GROUP BY ft.feeid;

            IF (NVL(t_refunded, 'N') = 'Y')
            THEN
                UPDATE bizmod_api.awf_t a
                   SET a.completed = t_refunded
                 WHERE a.ROWID = rec.id;
            END IF;
        END LOOP;

        COMMIT;

        UPDATE bizmod_api.e_payments_t p
           SET p.feeobjid =
                   (SELECT reo.objectid     feeobjid
                      FROM bizmod_api.awf_t  a
                           JOIN api.registeredexternalobjects reo
                               ON (reo.linkvalue = TO_CHAR(a.awffeeid)
                               AND reo.objectdefid =
                                   api.pkg_configquery.objectdefidforname(
                                       'o_Fee'))
                     WHERE a.awffeeid IS NOT NULL
                       AND p.licensenumber = a.licensenumber
                       AND p.licensetypecode = a.licensetypecode)
         WHERE p.feeobjid IS NULL
           AND p.description LIKE 'AWF';

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            t_sqlerrm := SQLERRM;
            t_trace := DBMS_UTILITY.format_error_backtrace;

            t_error :=
                t_error
                || CHR(13)
                || 'Nightly Processing ERROR'
                || CHR(13)
                || t_sqlerrm
                || CHR(13)
                || t_trace;
    END;

    -- Generate email of completion of first data processing
    SELECT pto,
           pfrom,
           pcc,
           pbcc
      INTO t_to,
           t_from,
           t_cc,
           t_bcc
      FROM (SELECT m.parametername, m.parametervalue
              FROM abc.email_parameters m
             WHERE app = 'EPAYMENT')
           PIVOT (MAX(parametervalue)
                 FOR parametername
                 IN ('TO' pto, 'FROM' pfrom, 'CC' pcc, 'BCC' pbcc));

    IF (t_from IS NOT NULL)
    THEN
        sitespecific.pkg_tlemail.sendemail(
            p_fromaddress => t_from,
            p_toaddress => t_to,
            p_cc        => t_cc,
            p_bcc       => t_bcc,
            p_subject   =>
                'Nightly Job Completed '
                || CASE
                       WHEN t_error IS NOT NULL THEN 'with errors'
                       ELSE NULL
                   END,
            p_body      => t_body || CHR(13) || t_error,
            p_mimetype  => 'text/plain');
    END IF;

    INSERT INTO bizmod_api.e_process_log_t(seq,
                                           processjob,
                                           info,
                                           errmsg,
                                           bktrace)
         VALUES (0,
                 'NIGHTLYPROCESS',
                 t_body,
                 t_sqlerrm,
                 t_trace);

    COMMIT;
END nightlyprocess;
/


GRANT EXECUTE ON BIZMOD_API.NIGHTLYPROCESS TO ABC;

GRANT EXECUTE ON BIZMOD_API.NIGHTLYPROCESS TO POSSEEXTENSIONS;
