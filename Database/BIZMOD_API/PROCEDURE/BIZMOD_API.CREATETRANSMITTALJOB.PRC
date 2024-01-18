CREATE OR REPLACE PROCEDURE BIZMOD_API.createtransmittaljob(
    a_seq          IN NUMBER,
    a_asofdate     IN DATE)
IS
    -- ****************************************************************************
    -- File:        BIZMOD_API.CREATETRANSMITTALJOB.PRC
    -- Author:      Timothy J. Lord
    --
    -- Purpose: Create transmittals for payments made
    --
    -- History:
    -------------------------------------------------------------------------------
    --              Date          Ticket      Comment
    --   1.0     01/16/2024  TJL BIZ-14091  Process created from e_payment.createtransmittal
    --                                          function.
    -- ************************************************************************
    t_transmittal  api.pkg_definition.udt_id;
    t_objectlist   api.udt_objectlist;
    t_sqlerrm      VARCHAR2(4000);
    t_backtrace    VARCHAR2(4000);
    t_seq          NUMBER := bizmod_api.e_payment_seq.NEXTVAL();
    t_processid    api.pkg_definition.udt_id;

    t_transmittaldefid api.pkg_definition.udt_id;
    t_transmittals api.udt_objectlist := api.udt_objectlist();
    t_transmittalobjectid api.pkg_definition.udt_id;
    t_rel          api.pkg_definition.udt_id;
    t_info         VARCHAR2(4000);
    t_paymentamount NUMBER := 0;
    t_paymentcount NUMBER := 0;
    t_to           VARCHAR2(4000);
    t_from         VARCHAR2(4000);
    t_cc           VARCHAR2(4000);
    t_bcc          VARCHAR2(4000);
BEGIN
    api.pkg_logicaltransactionupdate.resettransaction;
    ROLLBACK;

    FOR pm IN (SELECT DISTINCT p.paymentmethod
                 FROM bizmod_api.e_payments_t p
                WHERE p.transmittalbatch IS NULL)
    LOOP
        t_paymentamount := 0;
        t_paymentcount := 0;

        -- ************************************************************
        --  Create a list of payment for this transmittal
        -- ************************************************************
        SELECT api.udt_object(p.paymentobjectid)     paymentobjectid
          BULK COLLECT INTO t_objectlist
          FROM (SELECT DISTINCT p2.paymentobjectid
                  FROM bizmod_api.e_payments_t  p2
                       JOIN bizmod_api.e_payments_processed_t fd
                           ON (p2.confirmationid = fd.confirmationnumber)
                 WHERE NVL(p2.paymentobjectid, 0) > 0
                   AND p2.paymentmethod = pm.paymentmethod
                   AND p2.transmittalbatch IS NULL
                   AND api.pkg_columnquery.VALUE(p2.paymentobjectid,
                                                 'Objectdefname') =
                       'o_Payment') p
               LEFT OUTER JOIN api.relationships rn
                   ON rn.endpointid =
                      api.pkg_configquery.endpointidforname('j_Transmittal',
                                                            'Payment')
                  AND rn.toobjectid = p.paymentobjectid
         WHERE rn.fromobjectid IS NULL;

        IF (t_objectlist.COUNT > 0)
        THEN
            BEGIN
                -- *****************************************************************
                -- Create Transmittal job
                -- *****************************************************************
                -- check for last opened transmital not completed
                DBMS_OUTPUT.put_line('new transmittal');

                t_transmittaldefid :=
                    api.pkg_configquery.objectdefidforname('j_Transmittal');
                t_transmittalobjectid :=
                    api.pkg_objectupdate.new(t_transmittaldefid);
                t_transmittals.EXTEND(1);
                t_transmittals(t_transmittals.COUNT) :=
                    api.udt_object(t_transmittalobjectid);

                api.pkg_columnupdate.setvalue(t_transmittalobjectid,
                                              'TransmittalType',
                                              pm.paymentmethod);
                api.pkg_columnupdate.setvalue(t_transmittalobjectid,
                                              'PaymentCount',
                                              1);
                api.pkg_columnupdate.setvalue(t_transmittalobjectid,
                                              'PaymentTotalAmount',
                                              1);

                api.pkg_logicaltransactionupdate.endtransaction;
                COMMIT;

                -- ******************************************************************
                --  Add Payments to transmittal
                -- ******************************************************************
                FOR rec IN (SELECT objectid FROM TABLE(t_objectlist))
                LOOP
                    DBMS_OUTPUT.put_line('Pay ID: ' || rec.objectid);
                    -- add new relationship (endpointid, fromobjectid, toobjectid)
                    t_rel :=
                        api.pkg_relationshipupdate.new(
                            api.pkg_configquery.endpointidforname(
                                'j_Transmittal',
                                'Payment'),
                            t_transmittalobjectid,
                            rec.objectid);
                END LOOP;

                SELECT SUM(
                           api.pkg_columnquery.numericvalue(toobjectid,
                                                            'PaymentAmount')),
                       COUNT(1)
                  INTO t_paymentamount, t_paymentcount
                  FROM api.relationships r
                 WHERE r.endpointid =
                       api.pkg_configquery.endpointidforname('j_Transmittal',
                                                             'Payment')
                   AND r.fromobjectid = t_transmittalobjectid;

                -- *********************************************************************
                -- Update transmittal information
                -- *********************************************************************
                api.pkg_columnupdate.setvalue(t_transmittalobjectid,
                                              'PaymentCount',
                                              t_paymentcount);
                api.pkg_columnupdate.setvalue(t_transmittalobjectid,
                                              'PaymentTotalAmount',
                                              t_paymentamount);

                api.pkg_logicaltransactionupdate.endtransaction;
                COMMIT;

                -- 09/06/2023 TJL BIZ-12648  Added
                -- *****************************************************************
                -- Find and process Prepare Transmittal
                -- *****************************************************************
                -- get processes
                SELECT processid
                  INTO t_processid
                  FROM api.processes p
                 WHERE p.jobid = t_transmittalobjectid
                   AND p.processtypeid =
                       api.pkg_objectdefquery.idforname(
                           'p_PrepareTransmittal');

                -- set outcome to Complete (process will complete when COMMIT is executed.
                api.pkg_logicaltransactionupdate.starttransaction;
                api.pkg_columnupdate.setvalue(t_processid,
                                              'Outcome',
                                              'Sent to HQ');
                api.pkg_logicaltransactionupdate.endtransaction;
                COMMIT;
            -- end BIZ-12648

            -- *****************************************************************
            -- Casher the transmittal
            -- *****************************************************************
            api.pkg_logicaltransactionupdate.starttransaction;

            api.pkg_columnupdate.setvalue(t_transmittalobjectid,
                                          'CashieredDate',
                                          SYSDATE);
            api.pkg_columnupdate.setvalue(t_transmittalobjectid,
                                          'PaymentCountCashier',
                                          t_paymentcount);
            api.pkg_columnupdate.setvalue(t_transmittalobjectid,
                                          'BatchTotal',
                                          t_paymentamount);

            api.pkg_logicaltransactionupdate.endtransaction;
            COMMIT;

            EXCEPTION
                WHEN OTHERS
                THEN
                    t_sqlerrm := SUBSTR(SQLERRM, 1, 3990);
                    t_backtrace :=
                        SUBSTR(DBMS_UTILITY.format_error_backtrace, 1, 3990);

                    api.pkg_logicaltransactionupdate.resettransaction;
                    ROLLBACK;
                    DBMS_OUTPUT.put_line(t_sqlerrm);
            END;

            FOR pm
                IN (SELECT r.toobjectid     transmittalobjectid,
                           t.objectid       paymentobjectid
                      FROM TABLE(t_objectlist)  t
                           LEFT OUTER JOIN api.relationships r
                               ON r.endpointid =
                                  api.pkg_configquery.endpointidforname(
                                      'o_Payment',
                                      'Transmittal')
                              AND r.fromobjectid = t.objectid)
            LOOP
                UPDATE bizmod_api.e_payments_t p
                   SET p.transmittalbatch = NVL(pm.transmittalobjectid, -1),
                       p.transmittalbatchdate =
                           api.pkg_columnquery.datevalue(
                               pm.transmittalobjectid,
                               'CompletedDate')
                 WHERE p.paymentobjectid = pm.paymentobjectid;

                IF (t_sqlerrm IS NOT NULL)
                THEN
                    INSERT INTO bizmod_api.err$_e_payments_t ep(
                                    ep.ora_err_mesg$,
                                    ep.backtrace,
                                    ep.transmittalbatch,
                                    ep.seq)
                         VALUES (t_sqlerrm,
                                 t_backtrace,
                                 -1,
                                 t_seq);
                END IF;
            END LOOP;

            COMMIT;
        END IF;
    END LOOP;

    IF (t_transmittals.COUNT > 0)
    THEN
        FOR rec IN (SELECT objectid FROM TABLE(t_transmittals))
        LOOP
            t_info :=
                t_info
                || 'File Number: '
                || CHR(9)
                || RPAD(
                       api.pkg_columnquery.VALUE(rec.objectid,
                                                 'externalfilenum'),
                       10,
                       ' ')
                || CHR(13) || CHR(9)
                || RPAD(
                       api.pkg_columnquery.VALUE(rec.objectid,
                                                 'TransmittalType'),
                       15,
                       ' ')
                || CHR(13) || CHR(9)
                || 'Payment Count: '
                || LPAD(
                       api.pkg_columnquery.VALUE(rec.objectid,
                                                 'PaymentCount'),
                       4,
                       ' ')
                || CHR(13) || CHR(9)
                || 'Payment Total Amt: '
                || LPAD(
                       TO_CHAR(
                           api.pkg_columnquery.VALUE(rec.objectid,
                                                     'PaymentTotalAmount'),
                           'fm99G999D00'),
                       10,
                       ' ')
                || CHR(13);
        END LOOP;
    ELSE
        t_info := 'No Transmittal Batches Produced';
    END IF;

    INSERT INTO bizmod_api.e_process_log_t(seq,
                                           processjob,
                                           info,
                                           errmsg,
                                           bktrace)
         VALUES (0,
                 'CREATETRANSMITTALJOB',
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
            p_subject   => 'Transmittal Job Completed',
            p_body      => t_info,
            p_mimetype  => 'text/plain');
    END IF;
END createtransmittaljob;
/


GRANT EXECUTE ON BIZMOD_API.CREATETRANSMITTALJOB TO POSSEEXTENSIONS;
