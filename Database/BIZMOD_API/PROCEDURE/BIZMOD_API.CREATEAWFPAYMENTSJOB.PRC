CREATE OR REPLACE PROCEDURE BIZMOD_API.createawfpaymentsjob(
    a_makepayments IN NUMBER,
    a_asofdate     IN DATE)
IS
    -- ****************************************************************************
    -- File:        BIZMOD_API.CREATEAWFPAYMENTSJOB.PRC
    -- Author:      Timothy J. Lord
    --
    -- Purpose: Create AWF Payment Batch for AWF payments made
    --
    -- a_makepayment    1 - Create AWF Payment Batch with payments
    --                  0 - Create AWF Payment Batch with Zero amount payments
    --
    -- History:
    -------------------------------------------------------------------------------
    --              Date          Ticket      Comment
    --   1.0     01/16/2024  TJL BIZ-14091  Process created from e_payment.createawfpayments
    --                                          function.
    --   2.0     02/06/2024  TJL BIZ-14393  Change how AWF records are selected
    -- ************************************************************************
    TYPE awf_rec IS RECORD(seq NUMBER,
                           licensenumber VARCHAR2(10),
                           licensetypecode VARCHAR2(3),
                           paymentamount NUMBER,
                           gallonage NUMBER,
                           confirmationnumber VARCHAR2(60),
                           rowkey ROWID);

    TYPE awf_tbl IS TABLE OF awf_rec;

    t_awf          awf_tbl;

    t_paymentbatchdefid api.pkg_definition.udt_id;
    t_paymentbatchobjectid api.pkg_definition.udt_id;
    t_batchpaymententrydefid api.pkg_definition.udt_id;
    t_batchpaymententryobjectid api.pkg_definition.udt_id;
    t_batchpaymentverifyobjectid api.pkg_definition.udt_id;
    t_additionalitemdefid api.pkg_definition.udt_id;
    t_additionalitemobjectid api.pkg_definition.udt_id;
    t_endpointid   api.pkg_definition.udt_id;
    t_relid        api.pkg_definition.udt_id;

    t_totalfees    NUMBER;
    t_checkcount   NUMBER;
    t_receiptnumber NUMBER;
    t_batchid      VARCHAR2(30);
    t_licensetypecode VARCHAR2(3);
    t_licensenumber VARCHAR2(10);
    t_sequenceid   api.pkg_definition.udt_id;
    t_info         VARCHAR2(4000 BYTE);
    t_paymenttype  VARCHAR2(25)
        := CASE a_makepayments WHEN 0 THEN 'Check' ELSE 'Credit Card' END;
    t_sqlerrm      VARCHAR2(4000);
    t_backtrace    VARCHAR2(4000);
    t_to           VARCHAR2(4000);
    t_from         VARCHAR2(4000);
    t_cc           VARCHAR2(4000);
    t_bcc          VARCHAR2(4000);
BEGIN
    api.pkg_logicaltransactionupdate.resettransaction;
    ROLLBACK;

    BEGIN
        WHILE t_paymenttype IS NOT NULL
        LOOP
            -- 02/06/2024  TJL BIZ-14393
            IF (a_makepayments = 1)
            THEN
                SELECT (SELECT seq
                          FROM bizmod_api.e_payments_t p
                         WHERE p.description = 'AWF'
                           AND pp.licensenumber = p.licensenumber
                           AND pp.confirmationnumber = p.confirmationid
                           AND pp.paymenttype = 'Primary')
                           seq,
                       a.licensenumber,
                       a.licensetypecode,
                       NVL(pp.paymentamount, 0)
                           paymentamount,
                       a.gallonage261
                           gallonage,
                       pp.confirmationnumber
                           confirmationnumber,
                       a.ROWID
                           rowkey
                  BULK COLLECT INTO t_awf
                  FROM bizmod_api.e_payments_processed_t  pp
                       JOIN bizmod_api.e_payments_t p
                           ON (pp.confirmationnumber = p.confirmationid)
                       JOIN bizmod_api.awf_t a
                           ON (a.licensenumber = p.licensenumber)
                 WHERE a.paymentbatch IS NULL
                   AND pp.paymentmedium IS NOT NULL
                   AND pp.paymenttype = 'Primary'
                   AND p.description = 'AWF'
                   AND CASE pp.paymentmedium
                           WHEN 'E-Check' THEN 'ECheck'
                           ELSE pp.paymentmedium
                       END =
                       t_paymenttype;
            ELSE
                SELECT NULL               seq,
                       a.licensenumber,
                       a.licensetypecode,
                       0                  paymentamount,
                       a.gallonage261     gallonage,
                       NULL               confirmationnumber,
                       a.ROWID            rowkey
                  BULK COLLECT INTO t_awf
                  FROM bizmod_api.awf_t a
                 WHERE a.awffeeamount <= 0
                   AND a.paymentbatch IS NULL
                   AND a.submitteddate IS NOT NULL;
            END IF;
            --            DBMS_OUTPUT.put_line(t_loop || '  to process ' || t_awf.COUNT);

            IF (t_awf.COUNT > 0)
            THEN
                -- *****************************************************************
                -- Initialize batch variables at begining of each batch loop
                -- *****************************************************************
                --                t_feeamount := 0;
                t_totalfees := 0;
                t_checkcount := 0;
                t_batchid :=
                    'A'
                    || TO_CHAR(SYSDATE, 'MMDDHHMI')
                    || TO_CHAR(
                           MOD(api.pkg_sequenceupdate.nextvalue(313038), 100),
                           'FM00')
                    || '-'
                    || TO_CHAR(SYSDATE, 'YY');

                SELECT MAX(TO_NUMBER(attributevalue)) + 1
                  INTO t_receiptnumber
                  FROM possedata.objectcolumndata
                 WHERE columndefid = 317628;

                -- *****************************************************************
                -- Create payment batch
                -- *****************************************************************
                t_paymentbatchdefid :=
                    api.pkg_configquery.objectdefidforname('j_PaymentBatch');
                t_paymentbatchobjectid :=
                    api.pkg_objectupdate.new(t_paymentbatchdefid);

                -- Payment Batch Type
                api.pkg_columnupdate.setvalue(t_paymentbatchobjectid,
                                              'PaymentBatchType',
                                              'ADDITIONAL WINE FEES (AWF)');
                api.pkg_columnupdate.setvalue(t_paymentbatchobjectid,
                                              'BatchId',
                                              t_batchid);
                api.pkg_columnupdate.setvalue(t_paymentbatchobjectid,
                                              'Multiple',
                                              'N');
                api.pkg_columnupdate.setvalue(t_paymentbatchobjectid,
                                              'PaymentType',
                                              t_paymenttype);

                api.pkg_logicaltransactionupdate.endtransaction;
                COMMIT;

                -- *********************************************************************
                -- process all licenses
                -- *********************************************************************
                FOR inx IN 1 .. t_awf.COUNT
                LOOP
                    t_totalfees := t_totalfees + t_awf(inx).paymentamount; --t_feeamount;
                    t_checkcount := t_checkcount + 1;

                    -- *****************************************************************
                    -- Build batch payment entry record
                    -- *****************************************************************
                    t_batchpaymententrydefid :=
                        api.pkg_configquery.objectdefidforname(
                            'o_BatchPaymentEntry');
                    t_batchpaymententryobjectid :=
                        api.pkg_objectupdate.new(t_batchpaymententrydefid);

                    api.pkg_logicaltransactionupdate.endtransaction;
                    COMMIT;

                    -- *****************************************************************
                    -- add batch payment entry to payment batch job
                    -- *****************************************************************
                    t_endpointid :=
                        api.pkg_configquery.endpointidforname(
                            'j_PaymentBatch',
                            'BatchPaymentEntry');
                    t_relid :=
                        api.pkg_relationshipupdate.new(
                            t_endpointid,
                            t_paymentbatchobjectid,
                            t_batchpaymententryobjectid);

                    api.pkg_columnupdate.setvalue(
                        t_batchpaymententryobjectid,
                        'PaymentNumber',
                        t_receiptnumber + t_checkcount);
                    api.pkg_columnupdate.setvalue(
                        t_batchpaymententryobjectid,
                        'CheckAmount',
                        t_awf(inx).paymentamount);

                    -- 09/12/2023 TJL  BIZ-12752 added code
                    --      tmp_jobid entry will be deleted on oracle commit.
                    INSERT INTO abc.tmp_jobid j(objectid)
                         VALUES (t_batchpaymententryobjectid);

                    -- end BIZ-12752

                    -- add license and payment amount information
                    api.pkg_columnupdate.setvalue(
                        t_batchpaymententryobjectid,
                        'LicenseNum',
                        t_awf(inx).licensenumber);
                    api.pkg_columnupdate.setvalue(
                        t_batchpaymententryobjectid,
                        'LicenseTypeCode',
                        t_awf(inx).licensetypecode);
                    api.pkg_columnupdate.setvalue(
                        t_batchpaymententryobjectid,
                        'Gallonage',
                        t_awf(inx).gallonage);
                    api.pkg_columnupdate.setvalue(
                        t_batchpaymententryobjectid,
                        'ConfirmationNumber',
                        t_awf(inx).confirmationnumber);

                    api.pkg_logicaltransactionupdate.endtransaction;
                    COMMIT;
                END LOOP;

                api.pkg_columnupdate.setvalue(t_paymentbatchobjectid,
                                              'batchDate',
                                              TRUNC(SYSDATE));
                api.pkg_columnupdate.setvalue(t_paymentbatchobjectid,
                                              'CheckCount',
                                              t_checkcount);
                api.pkg_columnupdate.setvalue(t_paymentbatchobjectid,
                                              'BatchAmount',
                                              t_totalfees);

                api.pkg_columnupdate.setvalue(t_paymentbatchobjectid,
                                              'PaymentNumberFrom',
                                              t_receiptnumber + 1);
                api.pkg_columnupdate.setvalue(t_paymentbatchobjectid,
                                              'PaymentNumberTo',
                                              t_receiptnumber + t_checkcount);
                api.pkg_columnupdate.setvalue(t_paymentbatchobjectid,
                                              'Penalty',
                                              'Timely');

                api.pkg_logicaltransactionupdate.endtransaction;
                COMMIT;

                IF (a_makepayments = 0)
                THEN
                    -- complete the batch for refunds and no change AWF's
                    api.pkg_columnupdate.setvalue(t_paymentbatchobjectid,
                                                  'CompleteEntryProcess',
                                                  'Y');

                    api.pkg_logicaltransactionupdate.endtransaction;
                    COMMIT;
                END IF;

                -- batch verify process
                FOR v
                    IN (SELECT r.toobjectid
                          FROM api.relationships r
                         WHERE r.endpointid =
                               api.pkg_configquery.endpointidforname(
                                   'j_PaymentBatch',
                                   'BatchPaymentEntry')
                           AND r.fromobjectid = t_paymentbatchobjectid)
                LOOP
                    -- *****************************************************************
                    -- Build batch payment entry record
                    -- *****************************************************************
                    BEGIN
                        t_batchpaymententrydefid :=
                            api.pkg_configquery.objectdefidforname(
                                'o_BatchPaymentEntry');
                        t_batchpaymentverifyobjectid :=
                            api.pkg_objectupdate.new(
                                t_batchpaymententrydefid);

                        api.pkg_logicaltransactionupdate.endtransaction;
                        COMMIT;
                    END;

                    api.pkg_logicaltransactionupdate.endtransaction;
                    COMMIT;
                    -- *****************************************************************
                    -- add batch payment entry to payment batch job
                    -- *****************************************************************
                    t_endpointid :=
                        api.pkg_configquery.endpointidforname(
                            'j_PaymentBatch',
                            'BatchPaymentEntryVerify');
                    t_relid :=
                        api.pkg_relationshipupdate.new(
                            t_endpointid,
                            t_paymentbatchobjectid,
                            t_batchpaymentverifyobjectid);

                    api.pkg_columnupdate.setvalue(
                        t_batchpaymentverifyobjectid,
                        'CheckAmount',
                        api.pkg_columnquery.VALUE(v.toobjectid,
                                                  'CheckAmount'));
                    api.pkg_columnupdate.setvalue(
                        t_batchpaymentverifyobjectid,
                        'PaymentNumber',
                        api.pkg_columnquery.VALUE(v.toobjectid,
                                                  'PaymentNumber'));

                    -- 09/12/2023 TJL  BIZ-12752 added code
                    --      tmp_jobid entry will be deleted on oracle commit.
                    INSERT INTO abc.tmp_jobid j(objectid)
                         VALUES (t_batchpaymententryobjectid);

                    -- end BIZ-12752

                    -- add license and payment amount information
                    api.pkg_columnupdate.setvalue(
                        t_batchpaymentverifyobjectid,
                        'LicenseNum',
                        api.pkg_columnquery.VALUE(v.toobjectid, 'LicenseNum'));
                    api.pkg_columnupdate.setvalue(
                        t_batchpaymentverifyobjectid,
                        'LicenseTypeCode',
                        api.pkg_columnquery.VALUE(v.toobjectid,
                                                  'LicenseTypeCode'));

                    api.pkg_logicaltransactionupdate.endtransaction;
                    COMMIT;
                END LOOP;

                api.pkg_columnupdate.setvalue(t_paymentbatchobjectid,
                                              'BatchIdVerify',
                                              t_batchid);
                api.pkg_columnupdate.setvalue(t_paymentbatchobjectid,
                                              'CheckCountValidation',
                                              t_checkcount);
                api.pkg_columnupdate.setvalue(t_paymentbatchobjectid,
                                              'BatchAmountValidation',
                                              t_totalfees);

                api.pkg_columnupdate.setvalue(t_paymentbatchobjectid,
                                              'PaymentNumberFromVerify',
                                              t_receiptnumber + 1);
                api.pkg_columnupdate.setvalue(t_paymentbatchobjectid,
                                              'PaymentNumberToVerify',
                                              t_receiptnumber + t_checkcount);
                api.pkg_columnupdate.setvalue(t_paymentbatchobjectid,
                                              'Penalty',
                                              'Timely');

                IF (a_makepayments = 0)
                THEN
                    api.pkg_columnupdate.setvalue(t_paymentbatchobjectid,
                                                  'CompleteVerifyProcess',
                                                  'Y');
                    DBMS_OUTPUT.put_line('Batch verify completed');

                    api.pkg_logicaltransactionupdate.endtransaction;
                    COMMIT;
                END IF;

                -- update tables
                FOR inx IN 1 .. t_awf.COUNT
                LOOP
                    IF t_awf(inx).seq IS NOT NULL
                    THEN
                        UPDATE bizmod_api.e_payments_t p
                           SET p.paymentobjectid = t_paymentbatchobjectid
                         WHERE p.seq = t_awf(inx).seq;
                    END IF;

                    UPDATE bizmod_api.awf_t t
                       SET t.completed =
                               CASE a_makepayments
                                   WHEN 0
                                   THEN
                                       CASE t.awffeeamount
                                           WHEN 0 THEN 'Y'
                                           ELSE NULL
                                       END
                                   ELSE
                                       NULL
                               END,
                           t.paymentbatch = t_paymentbatchobjectid,
                           t.paymentbatchdate = SYSDATE
                     WHERE t.ROWID = t_awf(inx).rowkey;
                END LOOP;

                api.pkg_logicaltransactionupdate.endtransaction;
                COMMIT;

                t_info :=
                    t_info
                    || 'AWF Payment Batch: '
                    || api.pkg_columnquery.VALUE(t_paymentbatchobjectid,
                                                 'ExternalFileNum')
                    || CHR(13)
                    || 'Batch Type: '
                    || CASE a_makepayments
                           WHEN 1 THEN 'First Data AWF Payment Batch'
                           ELSE 'AWF no payment required Payment Batch'
                       END
                    || CHR(13)
                    || 'Payment Type: '
                    || t_paymenttype
                    || CHR(13)
                    || 'Number of Payments: '
                    || t_checkcount
                    || CHR(13)
                    || 'Total Payment Amount: '
                    || TO_CHAR(t_totalfees, 'fm99G999D00')
                    || CASE
                           WHEN t_sqlerrm IS NOT NULL
                           THEN
                               CHR(13)
                               || 'ERROR'
                               || CHR(13)
                               || t_sqlerrm
                               || CHR(13)
                               || t_backtrace
                           ELSE
                               NULL
                       END
                    || CHR(13)
                    || CHR(13);
            ELSE
                t_info :=
                    t_info
                    || 'No AWF Payment Batch created'
                    || CHR(13)
                    || 'Type: '
                    || CASE a_makepayments
                           WHEN 1 THEN 'First Data AWF Payment Batch'
                           ELSE 'AWF no payment required Payment Batch'
                       END
                    || CHR(13)
                    || 'Payment Type: '
                    || t_paymenttype
                    || CHR(13)
                    || CHR(13);
            END IF;

            t_paymenttype :=
                CASE t_paymenttype
                    WHEN 'Credit Card' THEN 'ECheck'
                    ELSE NULL
                END;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            t_sqlerrm := SUBSTR(SQLERRM, 1, 3990);
            t_backtrace :=
                SUBSTR(DBMS_UTILITY.format_error_backtrace, 1, 3990);

            api.pkg_logicaltransactionupdate.resettransaction;
            ROLLBACK;
    END;


    INSERT INTO bizmod_api.e_process_log_t(seq,
                                           processjob,
                                           info,
                                           errmsg,
                                           bktrace)
         VALUES (0,
                 'CREATEAWFPAYMENTSJOB',
                 t_info,
                 t_sqlerrm,
                 t_backtrace);
    COMMIT;
    
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
            p_subject   => 'Create AWF Payment Batch Job Completed',
            p_body      => t_info,
            p_mimetype  => 'text/plain');
    END IF;
END;
/


GRANT EXECUTE ON BIZMOD_API.CREATEAWFPAYMENTSJOB TO ABC;

GRANT EXECUTE ON BIZMOD_API.CREATEAWFPAYMENTSJOB TO POSSEEXTENSIONS;
