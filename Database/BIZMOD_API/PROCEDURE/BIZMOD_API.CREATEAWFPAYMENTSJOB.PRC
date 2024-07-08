CREATE OR REPLACE PROCEDURE BIZMOD_API.createawfpaymentsjob(
    a_seq          IN NUMBER,
    a_asofdate     IN DATE)
IS
    -- ****************************************************************************
    -- File:        BIZMOD_API.CREATEAWFPAYMENTSJOB.PRC
    -- Author:      Timothy J. Lord
    --
    -- Purpose: Create AWF Payment Batch for AWF payments made
    --
    -- a_makepayment    # - Create AWF Payment Batch with payments
    --                  0 - Create AWF Payment Batch with Zero amount payments
    --
    -- History:
    -------------------------------------------------------------------------------
    --              Date          Ticket      Comment
    --   1.0     01/16/2024  TJL BIZ-14091  Process created from e_payment.createawfpayments
    --                                          function.
    --   2.0     02/06/2024  TJL BIZ-14393  Change how AWF records are selected
    --   3.0     02/13/2024  TJL BIZ-14393  Corrected bug in selecting payment records
    --   4.0     03/06/2024  TJL BIZ-14725  Added updating payment table with process sequence
    --                                        and date processed. Fixed bug payment batch not
    --                                        updating payment object id
    --   5.0     04/23/2024  TJL BIZ-15138  Corrected bug in duplicating AWF payment records
    --   6.0     05/21/2024  TJL BIZ-15523  Select how which payments are selected for AWF
    --                                         payment batch
    --   6.1.1   05/24/2024  TJL BIZ-15485  Changed email function called and when called
    --   7.0.3   06/18/2024  TJL BIZ-15691  Fixed bug in selecting records.
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
    t_receiptnumber api.pkg_definition.udt_sequencevalue;
    t_receiptlast  api.pkg_definition.udt_sequencevalue;
    t_batchid      VARCHAR2(30);
    t_licensetypecode VARCHAR2(3);
    t_licensenumber VARCHAR2(10);
    t_info         VARCHAR2(4000 BYTE);
    t_paymenttype  VARCHAR2(25)
        := CASE a_seq WHEN 0 THEN 'Check' ELSE 'Credit Card' END;
    t_sqlerrm      VARCHAR2(4000);
    t_backtrace    VARCHAR2(4000);
    t_filename     VARCHAR2(512);
    t_fd_paymentamount NUMBER := 0;
    t_fd_payment_count NUMBER := 0;
BEGIN
    api.pkg_logicaltransactionupdate.resettransaction;
    ROLLBACK;

    BEGIN --   6.0     05/21/2024  TJL
        IF (a_seq > 0)
        THEN
            WITH --  06/18/2024  TJL BIZ-15691
                fd
                AS
                    (SELECT fd.filename,
                            CASE fd.paymentmedium
                                WHEN 'Credit Card' THEN fd.paymentmedium
                                ELSE 'ECheck'
                            END    paymentmedium,
                            fd.paymentamount
                       FROM bizmod_api.first_data_t fd
                      WHERE fd.logseq = a_seq
                        AND fd.abispayment = 'Y'
                        AND fd.feeactivity LIKE '%AWF%')
              SELECT fd.filename,
                     fd.paymentmedium,
                     SUM(fd.paymentamount),
                     COUNT(1)
                INTO t_filename,
                     t_paymenttype,
                     t_fd_paymentamount,
                     t_fd_payment_count
                FROM fd
            GROUP BY fd.filename, fd.paymentmedium;

            SELECT p.seq,
                   a.licensenumber,
                   a.licensetypecode,
                   NVL(fd.paymentamount, 0)     paymentamount,
                   a.gallonage261               gallonage,
                   fd.confirmationnumber        confirmationnumber,
                   a.ROWID                      rowkey
              BULK COLLECT INTO t_awf
              FROM bizmod_api.first_data_t  fd
                   JOIN bizmod_api.e_payments_t p
                       ON (fd.confirmationnumber = p.confirmationid)
                   JOIN bizmod_api.awf_t a
                       ON (a.licensenumber = p.licensenumber
                       AND a.licensetypecode = p.licensetypecode) -- 04/23/2024  TJL BIZ-15138
             WHERE a.paymentbatch IS NULL
               AND fd.abispayment = 'Y'
               AND fd.feeactivity LIKE '%AWF%'
               AND fd.logseq = a_seq;
        ELSE
            -- 02/06/2024  TJL BIZ-14393
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

            t_fd_payment_count := t_awf.COUNT;
        END IF;

        IF (t_awf.COUNT > 0)
        THEN
            -- *****************************************************************
            -- Initialize batch variables at begining of each batch loop
            -- *****************************************************************
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
                    api.pkg_sequenceupdate.nextvalue(301439));
                api.pkg_columnupdate.setvalue(t_batchpaymententryobjectid,
                                              'CheckAmount',
                                              t_awf(inx).paymentamount);

                -- 09/12/2023 TJL  BIZ-12752 added code
                --      tmp_jobid entry will be deleted on oracle commit.
                INSERT INTO abc.tmp_jobid j(objectid)
                     VALUES (t_batchpaymententryobjectid);

                -- end BIZ-12752

                -- add license and payment amount information
                api.pkg_columnupdate.setvalue(t_batchpaymententryobjectid,
                                              'LicenseNum',
                                              t_awf(inx).licensenumber);
                api.pkg_columnupdate.setvalue(t_batchpaymententryobjectid,
                                              'LicenseTypeCode',
                                              t_awf(inx).licensetypecode);
                api.pkg_columnupdate.setvalue(t_batchpaymententryobjectid,
                                              'Gallonage',
                                              t_awf(inx).gallonage);
                api.pkg_columnupdate.setvalue(t_batchpaymententryobjectid,
                                              'ConfirmationNumber',
                                              t_awf(inx).confirmationnumber);

                api.pkg_logicaltransactionupdate.endtransaction;
                COMMIT;

                -- check if first record
                IF (t_receiptnumber IS NULL)
                THEN
                    t_receiptnumber :=
                        api.pkg_columnquery.VALUE(
                            t_batchpaymententryobjectid,
                            'PaymentNumber');
                END IF;

                t_receiptlast :=
                    api.pkg_columnquery.VALUE(t_batchpaymententryobjectid,
                                              'PaymentNumber');
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
                                          t_receiptnumber);
            api.pkg_columnupdate.setvalue(t_paymentbatchobjectid,
                                          'PaymentNumberTo',
                                          t_receiptlast);
            api.pkg_columnupdate.setvalue(t_paymentbatchobjectid,
                                          'Penalty',
                                          'Timely');

            api.pkg_logicaltransactionupdate.endtransaction;
            COMMIT;

            IF (a_seq = 0)
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
                        api.pkg_objectupdate.new(t_batchpaymententrydefid);

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
                    api.pkg_columnquery.VALUE(v.toobjectid, 'CheckAmount'));
                api.pkg_columnupdate.setvalue(
                    t_batchpaymentverifyobjectid,
                    'PaymentNumber',
                    api.pkg_columnquery.VALUE(v.toobjectid, 'PaymentNumber'));

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
                                          t_receiptnumber);
            api.pkg_columnupdate.setvalue(t_paymentbatchobjectid,
                                          'PaymentNumberToVerify',
                                          t_receiptlast);
            api.pkg_columnupdate.setvalue(t_paymentbatchobjectid,
                                          'Penalty',
                                          'Timely');

            IF (a_seq = 0)
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
                       SET p.paymentobjectid = t_paymentbatchobjectid,
                           p.processdate = SYSDATE,
                           p.processid = a_seq
                     WHERE p.seq = t_awf(inx).seq;
                END IF;

                UPDATE bizmod_api.awf_t t
                   SET t.completed =
                           CASE t.awffeeamount WHEN 0 THEN 'Y' ELSE NULL END,
                       t.paymentbatch = t_paymentbatchobjectid,
                       t.paymentbatchdate = SYSDATE
                 WHERE t.ROWID = t_awf(inx).rowkey;
            END LOOP;

            api.pkg_logicaltransactionupdate.endtransaction;
            COMMIT;

            t_info :=
                t_info
                || 'Seq: '
                || a_seq
                || CHR(13)
                || 'File: '
                || t_filename
                || CHR(13)
                || CHR(13)
                || 'AWF Payment Batch: '
                || api.pkg_columnquery.VALUE(t_paymentbatchobjectid,
                                             'ExternalFileNum')
                || CHR(13)
                || 'Batch Type: '
                || CASE a_seq
                       WHEN 0 THEN 'AWF no payment required' || CHR(13)
                       ELSE 'First Data AWF Payment Batch' || CHR(13)
                   END
                || CHR(13)
                || 'Payment Type: '
                || t_paymenttype
                || CHR(13)
                || 'Number of Payments: '
                || t_checkcount
                || CHR(9)
                || '(Expected: '
                || t_fd_payment_count
                || ')'
                || CHR(13)
                || 'Total Payment Amount: '
                || TO_CHAR(t_totalfees, 'fm9G999G999D00')
                || CHR(9)
                || '(Expected: '
                || TO_CHAR(t_fd_paymentamount, 'fm9G999G999D00')
                || ')'
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
                || 'Seq: '
                || a_seq
                || CHR(13)
                || 'File: '
                || t_filename
                || CHR(13)
                || 'Payment Method: '
                || t_paymenttype
                || CHR(13)
                || 'No record found for payment';
        END IF;
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
    IF (t_awf.COUNT > 0)
    THEN
        bizmod_api.utl_licenseinfo.sendemail(
            a_subject   => 'Create AWF Payment Batch Job Completed',
            a_body      => t_info);
    END IF;
END;
/


GRANT EXECUTE ON BIZMOD_API.CREATEAWFPAYMENTSJOB TO ABC;

GRANT EXECUTE ON BIZMOD_API.CREATEAWFPAYMENTSJOB TO POSSEEXTENSIONS;
