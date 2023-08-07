CREATE OR REPLACE PROCEDURE BIZMOD_API.nightlyprocess
IS
    -- ****************************************************************************
    -- File:        NIGHTLYPROCESS.PRC
    -- Author:      Timothy J. Lord
    --
    -- Purpose :
    --
    -- History:
    -------------------------------------------------------------------------------
    --              Date           Ticket     Comment
    --          05/31/2023  TJL             Initial Procedure Created
    --   2.0    08/01/2023  TJL             Corrected bug in updating AWF completed flag
    -- ****************************************************************************
    t_refunded     VARCHAR2(1);
    t_feetransfer  NUMBER;
    t_paymenttransfer NUMBER;

    t_body         VARCHAR2(32000);
    t_to           VARCHAR2(4000);
    t_from         VARCHAR2(4000);
    t_cc           VARCHAR2(4000);
    t_bcc          VARCHAR2(4000);
    t_rowcount     NUMBER;
BEGIN
    -- ********************************************************************
    t_body := 'E-Service Nightly Job Completed' || CHR(10) || CHR(13);

    BEGIN
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
                       and ROWNUM = 1)
         WHERE a.awffeeid IS NULL
           AND ((a.awffeeamount = 0)
                 OR (a.awffeeamount > 0
                    AND 
                     a.paymentbatch is not null)
                );

        IF (SQL%ROWCOUNT > 0)
        THEN
            t_body :=
                t_body
                || 'AWF Processed (None Refunded): '
                || SQL%ROWCOUNT
                || CHR(13);
        END IF;

        COMMIT;
        
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
                       and ROWNUM = 1)
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

        t_body := t_body || 'AWF Refunds to Process:' || CHR(13);

        FOR rec
            IN (SELECT a.licensenumber, a.paymentbatchdate, a.awffeeamount
                  FROM bizmod_api.awf_t a
                 WHERE a.awffeeamount < 0
                   AND NVL(a.completed, 'N') != 'Y')
        LOOP
            t_body :=
                t_body
                || CHR(9)
                || rec.licensenumber
                || CHR(9)
                || CHR(9)
                || TO_CHAR(rec.paymentbatchdate, 'MM/DD/YYYY')
                || CHR(9)
                || LPAD(TO_CHAR(rec.awffeeamount, 'fm99G999D00'), 10, ' ')
                || CHR(13);
        END LOOP;

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

        -- ********************************************************************
        -- Log processed information
        -- ********************************************************************
        --        INSERT INTO bizmod_api.e_process_log_t l(l.processid,
        --                                                 l.processdate,
        --                                                 l.licensespaid,
        --                                                 l.transmittals,
        --                                                 l.deposits,
        --                                                 l.processerrors)
        --             VALUES (t_processid,
        --                     t_processdate,
        --                     t_licensecount,
        --                     t_transmittalcount,
        --                     t_depositcount,
        --                     t_errors);

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            t_body :=
                t_body
                || CHR(13)
                || SQLERRM
                || CHR(13)
                || DBMS_UTILITY.format_error_backtrace;
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
            p_subject   => 'Nightly Job Completed',
            p_body      => t_body,
            p_mimetype  => 'text/plain');
    END IF;
END nightlyprocess;
/


GRANT EXECUTE ON BIZMOD_API.NIGHTLYPROCESS TO ABC;

GRANT EXECUTE ON BIZMOD_API.NIGHTLYPROCESS TO POSSEEXTENSIONS;
