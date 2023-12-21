CREATE OR REPLACE PROCEDURE BIZMOD_API.processpayments(
    a_processid    api.pkg_definition.udt_id,
    a_asofdate     DATE)
IS
    -- ****************************************************************************
    -- File:        PROCESSPAYMENTS.PRC
    -- Author:      Timothy J. Lord
    --
    -- Purpose :
    --
    -- History:
    -------------------------------------------------------------------------------
    --    Date           Ticket     Comment
    --  05/31/2023 TJL            Initial Procedure Created
    --  12/20/2023 TJL            Added Logging
    -- ****************************************************************************
    t_paid         VARCHAR2(32000);
    t_body         VARCHAR2(32000);
    t_error        VARCHAR2(4000);
    t_paidcount    NUMBER := 0;
    t_results      CLOB;
    t_transmittal  api.udt_objectlist;
    t_msg          VARCHAR2(4000);
    t_seq          NUMBER;
    t_to           VARCHAR2(4000);
    t_from         VARCHAR2(4000);
    t_cc           VARCHAR2(4000);
    t_bcc          VARCHAR2(4000);
BEGIN
    -- check if any payment need to be made (AWF excluded)
--    FOR rec IN (  SELECT DISTINCT fd.licensenumber,
--                                  fd.paymentamount,
--                                  fd.confirmationnumber,
--                                  fd.paymenttimestamp,
--                                  fd.paymentmedium,
--                                  fd.fullname,
--                                  p.seq,
--                                  p.paymentobjectid,
--                                  p.description,
--                                  fd.ROWID     key
--                    FROM bizmod_api.e_payments_processed_t fd
--                         LEFT OUTER JOIN bizmod_api.e_payments_t p
--                             ON (fd.licensenumber = p.licensenumber
--                             AND fd.confirmationnumber = p.confirmationid)
--                   WHERE fd.abispayment = 'N'
--                     AND p.transmittalbatch IS NULL
--                     AND p.paymentobjectid IS NULL
--                     AND fd.confirmationnumber != NVL(p.confirmationid, '0')
--                     AND NVL(p.description, 'z') NOT LIKE '%AWF%'
--                ORDER BY fd.licensenumber DESC)
--    LOOP
--        IF (rec.seq IS NULL)
--        THEN
--            t_results :=
--                bizmod_api.eservices(
--                    '{"PACKET_TYPE":"REQUESTFEES","DATA":{"LICENSENUMBER":"'
--                    || rec.licensenumber
--                    || '"}}');
--
--            IF (json_value(t_results, '$.DATA.MSG') IS NULL
--            AND json_value(t_results, '$.DATA.TOTALAMOUNTDUE') >=
--                rec.paymentamount)
--            THEN
--                t_seq := bizmod_api.bizmod_api_s.NEXTVAL;
--
--                -- generate payment record
--                FOR paidfees
--                    IN (SELECT *
--                          FROM JSON_TABLE(
--                                   t_results,
--                                   '$.DATA.FEES[*]'
--                                   COLUMNS(
--                                       licensetypecode VARCHAR2(3)
--                                           PATH '$.LICENSETYPECODE',
--                                       feeobjid NUMBER PATH '$.FEEOBJID',
--                                       description VARCHAR2(20)
--                                           PATH '$.DESCRIPTION',
--                                       amountdue NUMBER PATH '$.AMOUNTDUE')))
--                LOOP
--                    INSERT INTO /*+ IGNORE_ROW_ON_DUPKEY_INDEX(e_payments_t, e_payments_t_pk) */
--                                bizmod_api.e_payments_t(seq,
--                                                        paymentmethod,
--                                                        licensenumber,
--                                                        licensetypecode,
--                                                        feeobjid,
--                                                        description,
--                                                        payeename,
--                                                        confirmationid,
--                                                        datepaid,
--                                                        amountpaid)
--                         VALUES (t_seq,
--                                 rec.paymentmedium, --paymentmethod,
--                                 rec.licensenumber,
--                                 paidfees.licensetypecode,
--                                 paidfees.feeobjid,
--                                 paidfees.description,
--                                 rec.fullname, --payeename,
--                                 rec.confirmationnumber, --confirmationid,
--                                 rec.paymenttimestamp, -- datepaid
--                                 paidfees.amountdue)
--                            LOG ERRORS INTO bizmod_api.err$_e_payments_t
--                                    ('INSERT')
--                                    REJECT LIMIT UNLIMITED;
--                END LOOP;
--
--                COMMIT;
--
--                -- create payment
--                e_payment.makepayment(a_licensenumber => rec.licensenumber,
--                                      a_asofdate  => SYSDATE,
--                                      a_error     => t_error);
--                t_paid :=
--                    t_paid
--                    || LPAD(rec.licensenumber, 6, ' ')
--                    || CHR(9)
--                    || CHR(9)
--                    || CASE WHEN t_error IS NULL THEN 'Paid' ELSE 'Error' END
--                    || CHR(13);
--
--                UPDATE bizmod_api.e_payments_processed_t pp
--                   SET pp.abispayment =
--                           CASE WHEN t_error IS NULL THEN 'P' ELSE 'E' END
--                 WHERE pp.ROWID = rec.key;
--
--                IF (t_error IS NOT NULL)
--                THEN
--                    INSERT INTO bizmod_api.err$_e_payments_processed_t pp(
--                                    ora_err_mesg$,
--                                    licensenumber,
--                                    confirmationnumber)
--                             VALUES (t_error,
--                                     rec.licensenumber,
--                                     rec.confirmationnumber);
--                END IF;
--
--                COMMIT;
--            ELSE
--                t_paid :=
--                    t_paid
--                    || LPAD(rec.licensenumber, 6, ' ')
--                    || CHR(9)
--                    || CHR(9)
--                    || 'Not Processed'
--                    || CHR(9)
--                    || '('
--                    || json_value(t_results, '$.DATA.MSG')
--                    || ')'
--                    || CHR(13);
--
--                UPDATE bizmod_api.e_payments_processed_t pp
--                   SET pp.abispayment = 'E'
--                 WHERE pp.ROWID = rec.key;
--
--                INSERT INTO bizmod_api.err$_e_payments_processed_t pp(
--                                ora_err_mesg$,
--                                licensenumber,
--                                confirmationnumber)
--                         VALUES (json_value(t_results, '$.DATA.MSG'),
--                                 rec.licensenumber,
--                                 rec.confirmationnumber);
--
--                COMMIT;
--            END IF;
--        ELSE
--            IF (rec.paymentobjectid IS NULL)
--            THEN
--                -- create payment
--                e_payment.makepayment(a_licensenumber => rec.licensenumber,
--                                      a_asofdate  => SYSDATE,
--                                      a_error     => t_error);
--                t_paid :=
--                    t_paid
--                    || LPAD(rec.licensenumber, 6, ' ')
--                    || CHR(9)
--                    || CHR(9)
--                    || CASE WHEN t_error IS NULL THEN 'Paid' ELSE 'Error' END
--                    || CHR(13);
--            ELSE
--                t_paid :=
--                    t_paid
--                    || LPAD(rec.licensenumber, 6, ' ')
--                    || CHR(9)
--                    || CHR(9)
--                    || 'Duplicate Payment'
--                    || CHR(13);
--            END IF;
--        END IF;
--    END LOOP;

    -- Call transmittal job to create a transmittal batch from first data processing
    t_transmittal := e_payment.createtransmittal;

    -- process any AWF payments that need to be made
    bizmod_api.e_payment.createawfpayments;

--    t_body := 'Process Cleared Payments Job Completed' || CHR(10) || CHR(13);
    t_body := 'Payments Processed' || CHR(13);

    IF (t_transmittal.COUNT > 0)
    THEN
        t_body :=
            t_body
            || 'Transmittal Batch(es): '
            || CHR(13);

        FOR rec IN (SELECT objectid FROM TABLE(t_transmittal))
        LOOP
            t_body :=
                t_body
                || CHR(9)
                || api.pkg_columnquery.VALUE(rec.objectid, 'externalfilenum')
                || CHR(13);
        END LOOP;
    END IF;

--    t_body := t_body || 'AWF Refunds to Process:' || CHR(13);
--
--    FOR rec IN (SELECT a.licensenumber,
--                       a.paymentbatchdate,
--                       a.paymentbatch,
--                       a.awffeeamount
--                  FROM bizmod_api.awf_t a
--                 WHERE a.awffeeamount < 0
--                   AND NVL(a.completed, 'N') != 'Y')
--    LOOP
--        t_body :=
--            t_body
--            || CHR(9)
--            || rec.licensenumber
--            || CHR(9)
--            || CHR(9)
--            || TO_CHAR(rec.paymentbatchdate, 'MM/DD/YYYY')
--            || CHR(9)
--            || rec.paymentbatch
--            || CHR(9)
--            || LPAD(TO_CHAR(rec.awffeeamount, 'fm99G999D00'), 10, ' ')
--            || CHR(13);
--    END LOOP;

    IF (t_paid IS NOT NULL)
    THEN
        t_body :=
            t_body
            || CHR(13)
            || CHR(13)
            || 'Missing Payments'
            || CHR(13)
            || t_paid;
    END IF;

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
            p_subject   => 'Cleared Payment Job Completed',
            p_body      => t_body,
            p_mimetype  => 'text/plain');
    END IF;
END;
/


GRANT EXECUTE ON BIZMOD_API.PROCESSPAYMENTS TO ABC;

GRANT EXECUTE ON BIZMOD_API.PROCESSPAYMENTS TO POSSEDBA;

GRANT EXECUTE ON BIZMOD_API.PROCESSPAYMENTS TO POSSEEXTENSIONS;
