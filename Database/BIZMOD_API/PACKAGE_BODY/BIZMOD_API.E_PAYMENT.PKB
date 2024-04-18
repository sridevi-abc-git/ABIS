CREATE OR REPLACE PACKAGE BODY BIZMOD_API.e_payment
AS
    -- **************************************************************************
    -- File:        BIZMOD_API.E_PAYMENT.PKB
    -- Author:      Timothy J.Lord
    --
    -- Description:
    --
    --
    -- History:
    -----------------------------------------------------------------------------
    --    Ver:     Date          Ticket          Comment
    --          03/24/2023 TJL              Package Created from ABC.E_PAYMENT package
    --     2.0  09/06/2023 TJL  BIZ-12648   Change transmittal status from Prepared to Cashiered
    --                                        after transmittal is created.
    --     2.1  09/12/2023 TJL  BIZ-12752   Added updating tmp_jobid table to prevent validation
    --                                        failure in sitespecific.pkg_accounting package when
    --                                        adding license number to AWF Payment Branch item.
    --     2.1  10/06/2023 TJL  BIZ-13129   Added filter to only select AWF payments from e_payments
    --                                        in createawfpayments procedure
    --     3.0  10/30/2023 TJL  TRK-33861   Corrected bug of incorrect payment amount being found
    --                                        AWF Payment Batches for zero payments (no fee due)
    --     3.0  12/07/2023 TJL              Correct bug in payfees that for certain license payments
    --                                        would fail with no data found.
    --     3.0  12/15/2023 TJL  BIZ-13929   Added additional logging to createtransmitta function
    --     3.0  12/20/2023 TJL              Fixed bug in payment process
    --     3.1  01/11/2024 TJL  BIZ-14091   Removed createtransmittal and createawfpayments
    --                                        functions from package body.
    --     4.0  02/29/2024 TJL  BIZ-14645   Added filter to getting licensetype for receipt payments
    --     5.0  04/09/2024 TJL  BIZ-15003   In payfees function changed how fees to be paid is validate
    --     5.1  04/18/2024 TJL  BIZ-15003   Corrected bug of receipting payments not paid by paid fees
    --                                        process
    -- **************************************************************************
    PROCEDURE makepayment(a_licensenumber    VARCHAR2,
                          a_asofdate         DATE,
                          a_error        OUT VARCHAR2)
    IS
        t_sqlerrm      VARCHAR2(4000);
        t_backtrace    VARCHAR2(4000);
        t_id           api.pkg_definition.udt_id;
        t_processid    NUMBER := bizmod_api.e_payment_seq.NEXTVAL();
        t_processdate  DATE := SYSDATE;
    BEGIN
        FOR rec
            IN (  SELECT paymentmethod,
                         licensenumber,
                         confirmationid,
                         payeename,
                         datepaid,
                         SUM(amountpaid)                                payamount,
                         LISTAGG(licensetypecode, ',')
                             WITHIN GROUP (ORDER BY licensetypecode)    licensetypecodes
                    FROM bizmod_api.e_payments_t p
                   WHERE p.paymentobjectid IS NULL
                     AND p.licensenumber = a_licensenumber
                GROUP BY paymentmethod,
                         licensenumber,
                         confirmationid,
                         payeename,
                         datepaid)
        LOOP
            t_id :=
                bizmod_api.e_payment.payfees(
                    a_paymentmethod => rec.paymentmethod,
                    a_licensenumber => rec.licensenumber,
                    a_licensetypecodes => rec.licensetypecodes,
                    a_payamount => rec.payamount,
                    a_payeereference => rec.confirmationid,
                    a_payeename => rec.payeename,
                    a_paymentdate => rec.datepaid,
                    a_sqlerrm   => t_sqlerrm,
                    a_backtrace => t_backtrace);

            UPDATE bizmod_api.e_payments_t p
               SET p.paymentobjectid =
                       CASE
                           WHEN p.paymentobjectid IS NULL THEN t_id
                           ELSE p.paymentobjectid
                       END,
                   p.processid = t_processid,
                   p.processdate = t_processdate
             WHERE p.licensenumber = rec.licensenumber
               AND p.confirmationid = rec.confirmationid
               AND NVL(p.paymentobjectid, 0) = 0;

            IF (t_sqlerrm IS NOT NULL)
            THEN
                INSERT INTO bizmod_api.err$_e_payments_t ep(ep.ora_err_mesg$,
                                                            ep.backtrace,
                                                            ep.licensenumber,
                                                            ep.seq)
                     VALUES (t_sqlerrm,
                             t_backtrace,
                             rec.licensenumber,
                             t_processid);

                a_error := t_sqlerrm;
            END IF;

            --        t_sqlerrm := SQLERRM;
            --        t_backtrace := DBMS_UTILITY.format_error_backtrace;

            INSERT INTO bizmod_api.e_process_log_t(seq,
                                                   processjob,
                                                   info,
                                                   errmsg,
                                                   bktrace)
                     VALUES (
                         0,
                         'MAKEPAYMENT',
                         'LicenseNumber: '
                         || rec.licensenumber
                         || CHR(13)
                         || 'Confirmation Id: '
                         || rec.confirmationid,
                         t_sqlerrm,
                         t_backtrace);

            COMMIT;
        END LOOP;
    END;

    PROCEDURE makepayment(a_licensenumber VARCHAR2, a_asofdate DATE)
    IS
        t_sqlerrm      VARCHAR2(4000);
    BEGIN
        makepayment(a_licensenumber, a_asofdate, t_sqlerrm);
    END;



    PROCEDURE createpenaltyfee(a_jobid        IN api.pkg_definition.udt_id,
                               a_feeobjid     IN api.pkg_definition.udt_id,
                               a_description  IN VARCHAR2)
    IS
        t_relid        NUMBER;
        t_adjustid     NUMBER;
        t_feetransobjid NUMBER;

        t_feeid        NUMBER;
        t_ismaster     VARCHAR2(1);
        t_secondarycount NUMBER;
        t_masterlt     VARCHAR2(2);
        t_feescheduleid NUMBER;
        t_feeschedulepenid NUMBER;
        t_originalfeeamount NUMBER;
        t_feepenamount NUMBER := 0;
        t_feependescription VARCHAR2(20);

        t_adjustedamount NUMBER;
        t_totalowing   NUMBER;
        t_loop         NUMBER;
        t_primarysecondary VARCHAR2(1);
        t_renewaldate  DATE;
    BEGIN
        api.pkg_logicaltransactionupdate.resettransaction;
        ROLLBACK;

        -- get current relationship to current fee schedule and dynamic details
        SELECT r.relationshipid,
               api.pkg_columnquery.VALUE(r.relationshipid, 'IsMaster'),
               api.pkg_columnquery.numericvalue(r.relationshipid,
                                                'SecondaryCount'),
               api.pkg_columnquery.VALUE(r.relationshipid, 'MasterLT'),
                 api.pkg_columnquery.numericvalue(r.fromobjectid, 'Amount')
               + api.pkg_columnquery.numericvalue(r.fromobjectid,
                                                  'AdjustedAmount'),
               api.pkg_columnquery.numericvalue(r.fromobjectid, 'TotalOwing'),
               r.toobjectid
          INTO t_relid,
               t_ismaster,
               t_secondarycount,
               t_masterlt,
               t_originalfeeamount,
               t_totalowing,
               t_feescheduleid
          FROM api.relationships r
         WHERE r.endpointid =
               api.pkg_configquery.endpointidforname('o_Fee',
                                                     'LicenseFeeSchedule')
           AND r.fromobjectid = a_feeobjid;

        DBMS_OUTPUT.put_line(
            'master: '
            || t_ismaster
            || '  sec count: '
            || t_secondarycount
            || '  masterlt: '
            || t_masterlt);

        t_loop :=
            CASE
                WHEN t_ismaster = 'Y'
                 AND t_secondarycount > 0
                THEN
                    2
                ELSE
                    1
            END;

        LOOP
            SELECT CASE
                       WHEN t_loop = 2
                       THEN
                           'P'
                       WHEN t_loop = 1
                        AND t_secondarycount = 0
                       THEN
                           CASE
                               WHEN MAX(r.toobjectid) IS NULL THEN 'P'
                               ELSE 'B'
                           END
                       WHEN t_loop = 1
                        AND t_secondarycount > 0
                       THEN
                           'S'
                   END
              INTO t_primarysecondary
              FROM api.relationships r
             WHERE r.endpointid =
                   api.pkg_configquery.endpointidforname('j_LicenseType',
                                                         'MasterLicenseType')
               AND r.fromobjectid = a_jobid;

            t_renewaldate :=
                api.pkg_columnquery.datevalue(a_jobid, 'RenewalDate');

            -- get new fee schedule id to penalty and amount and penalty description
            SELECT   CASE t_primarysecondary
                         WHEN 'P'
                         THEN
                             fs.primaryamount
                         WHEN 'S'
                         THEN
                             (fs.secondaryamount * t_secondarycount)
                         WHEN 'B'
                         THEN
                             fs.branchamount
                     END
                   + t_feepenamount,
                   fs.licensetypecode || ' - ' || fs.description,
                   fs.objectid
              INTO t_feepenamount, t_feependescription, t_feeschedulepenid
              FROM sitespecific.feeschedule_t  fs
                   JOIN sitespecific.feeschedule_t fs2
                       ON (NVL(fs.licensetypecode, 'x') =
                           NVL(fs2.licensetypecode, 'x')
                       AND NVL(fs.otherfeecode, 'x') =
                           NVL(fs2.otherfeecode, 'x')
                       AND NVL(fs.gallonagerange, 'x') =
                           NVL(fs2.gallonagerange, 'x')
                       AND NVL(fs.populationrange, 'x') =
                           NVL(fs2.populationrange, 'x')
                       AND NVL(fs.numberofmonthslicensed, 'x') =
                           NVL(fs2.numberofmonthslicensed, 'x')
                       AND NVL(fs.feetier, 'x') = NVL(fs2.feetier, 'x')
                       AND fs2.objectid = t_feescheduleid)
             WHERE fs.feeactivity = REGEXP_SUBSTR(a_description,
                                                  '[^ ]+',
                                                  1,
                                                  3)
               AND fs.effectivedate =
                   (SELECT MAX(fs2.effectivedate)
                      FROM sitespecific.feeschedule_t fs2
                     WHERE NVL(fs2.licensetypecode, '0') =
                           NVL(fs.licensetypecode, '0')
                       AND fs2.feeactivity = fs.feeactivity
                       AND NVL(fs2.gallonagerange, 'x') =
                           NVL(fs.gallonagerange, 'x')
                       AND NVL(fs2.populationrange, 'x') =
                           NVL(fs.populationrange, 'x')
                       AND NVL(fs2.numberofmonthslicensed, 'x') =
                           NVL(fs.numberofmonthslicensed, 'x')
                       AND NVL(fs2.feetier, 'x') = NVL(fs.feetier, 'x')
                       AND NVL(fs2.otherfeecode, 'x') =
                           NVL(fs.otherfeecode, 'x')
                       AND fs2.effectivedate <= t_renewaldate);

            t_loop := t_loop - 1;
            EXIT WHEN t_loop < 1;
        END LOOP;

        t_adjustedamount := (t_feepenamount - t_originalfeeamount);

        -- add penality record
        t_adjustid :=
            api.pkg_feeupdate.adjust(
                api.pkg_columnquery.numericvalue(a_feeobjid, 'FeeId'), --t_feeid,
                t_adjustedamount, --ROUND(t_pfeeamount - t_originalamount),
                t_feependescription, --t_description,
                SYSDATE);
        t_feetransobjid :=
            api.pkg_objectupdate.registerexternalobject('o_FeeTransactions',
                                                        t_adjustid);

        -- remove old fee schedule id
        api.pkg_relationshipupdate.remove(t_relid);

        -- add new relationship to new fee schedule                (endpointid, fromobjectid, toobjectid)
        t_relid :=
            api.pkg_relationshipupdate.new(
                api.pkg_configquery.endpointidforname('o_fee',
                                                      'LicenseFeeSchedule'),
                a_feeobjid,
                t_feeschedulepenid);


        api.pkg_columnupdate.setvalue(t_relid, 'IsMaster', t_ismaster);
        api.pkg_columnupdate.setvalue(t_relid, 'MasterLT', t_masterlt);
        api.pkg_columnupdate.setvalue(t_relid,
                                      'secondarycount',
                                      t_secondarycount);

        api.pkg_logicaltransactionupdate.endtransaction;
        COMMIT;
    END;


    /***************************************************************************
    * Payfees
    *   This script will create payment for fees that have not paid on a
    *   license.  It will add any fees that were created that were not created
    *   by test scripts.
    ***************************************************************************/
    FUNCTION payfees(a_paymentmethod IN    VARCHAR2,
                     a_licensenumber IN    VARCHAR2,
                     a_licensetypecodes IN VARCHAR2,
                     a_payamount    IN     NUMBER,
                     a_payeereference IN   VARCHAR2,
                     a_payeename    IN     VARCHAR2,
                     a_paymentdate  IN     DATE,
                     a_sqlerrm         OUT VARCHAR2,
                     a_backtrace       OUT VARCHAR2)
        RETURN NUMBER
    IS
        t_amountpaid   NUMBER;
        t_amountleft   NUMBER := a_payamount;
        t_feecount     NUMBER := 0;

        t_paymentprocessid api.pkg_definition.udt_id;
        t_paymentobjectid api.pkg_definition.udt_id := 0;
        t_processid    api.pkg_definition.udt_id;
        t_processdefid api.pkg_definition.udt_id;
        t_relationshipid api.pkg_definition.udt_id;
        t_jobid        api.pkg_definition.udt_id;
        lst            api.udt_objectlist;
        t_rel          NUMBER;

        t_receiptnumber VARCHAR2(40);
        t_sequenceid   api.pkg_definition.udt_id;
        t_paymentmethodobjectid api.pkg_definition.udt_id;
        t_description  VARCHAR2(20);
        t_feeobjid     api.pkg_definition.udt_id;
        t_match        BOOLEAN;
        t_totalpaid    NUMBER := 0;
    BEGIN
        api.pkg_logicaltransactionupdate.resettransaction;
        ROLLBACK;

        DBMS_OUTPUT.put_line(a_licensenumber || ' : ' || a_payeereference);

        -- From License number get first license type job for creating proposed payment job
        --  and generate any required penalties
        BEGIN
            SELECT api.pkg_columnquery.VALUE(p.feeobjid, 'jobid')     jobid
              INTO t_jobid
              FROM bizmod_api.e_payments_t p
             WHERE p.licensenumber = a_licensenumber
               AND p.paymentobjectid IS NULL
               AND ROWNUM = 1;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                NULL; -- do nothing
        END;

        IF (t_jobid IS NOT NULL)
        THEN
            --*************************************************************************************
            -- add penalty fees if needed
            FOR rec IN (SELECT p.feeobjid, p.description
                          FROM bizmod_api.e_payments_t p
                         WHERE p.licensenumber = a_licensenumber
                           AND p.confirmationid = a_payeereference
                           AND p.description LIKE '%REN%'
                           AND p.paymentobjectid IS NULL)
            LOOP
                -- check if penalty fee needs to be created
                IF (rec.description !=
                    api.pkg_columnquery.VALUE(rec.feeobjid, 'Description'))
                THEN
                    createpenaltyfee(a_jobid     => t_jobid,
                                     a_feeobjid  => rec.feeobjid,
                                     a_description => rec.description);
                END IF;
            END LOOP;

            --*************************************************************************************


            -- *****************************************************************************************
            -- Create Proposed Payment Job
            -- *****************************************************************************************
            INSERT INTO abc.tmp_jobid(objectid)
                 VALUES (t_jobid);

            -- create payment process
            t_paymentprocessid :=
                api.pkg_jobupdate.new(
                    api.pkg_configquery.objectdefidforname(
                        'j_ProposedPayment'),
                    'ProposedPayment',
                    NULL,
                    t_jobid);

            api.pkg_logicaltransactionupdate.endtransaction;
            COMMIT;
            DBMS_OUTPUT.put_line('proposed job ' || t_paymentprocessid);

            -- ****************************************************************************************
            -- Get payments from payment table and Fees that are available to pay for selected license
            --  Number.
            -- Remove any fees not to be paid from proposed payment job
            -- Add any fees to be paid not in proposed payment job (usually fees on another license type
            --   associated to selected license
            -- ****************************************************************************************
            FOR rec
                IN (WITH
                        feeids
                        AS
                            (SELECT p.feeobjid     feeobjid
                               FROM bizmod_api.e_payments_t p
                              WHERE p.licensenumber = a_licensenumber
                                AND paymentobjectid IS NULL
                             UNION
                             SELECT reo.objectid     feeobjid
                               FROM TABLE(
                                        CAST(
                                            api.pkg_simplesearch.castableobjectsbyindex(
                                                a_objectdefname =>
                                                    'j_licensetype',
                                                a_columnname =>
                                                    'dup_LicenseExternalFileNum',
                                                a_value     =>
                                                    a_licensenumber)
                                                AS api.udt_objectlist)) o
                                    JOIN api.fees f ON (f.jobid = o.objectid)
                                    JOIN api.registeredexternalobjects reo
                                        ON (reo.objectdefid =
                                            api.pkg_configquery.objectdefidforname(
                                                'o_fee')
                                        AND reo.linkvalue = TO_CHAR(f.feeid))
                              WHERE paidamount + amount + adjustedamount > 0)
                    SELECT f.feeobjid, p.seq, p.amountpaid
                      FROM feeids  f
                           LEFT JOIN bizmod_api.e_payments_t p
                               ON (f.feeobjid = NVL(p.feeobjid, 0)
                               AND INSTR(
                                       p.description,
                                       api.pkg_columnquery.VALUE(
                                           f.feeobjid,
                                           'feescheduletransactionfeeactiv')) >
                                   0))
            LOOP
                DBMS_OUTPUT.put_line('feeobjid 2: ' || rec.feeobjid);

                t_match := FALSE;
                t_relationshipid := NULL;

                -- loop thru perposed payment job looking for feeobjid matches
                FOR pp
                    IN (SELECT r.toobjectid feeobjid, r.relationshipid
                          FROM api.relationships r
                         WHERE r.endpointid =
                               api.pkg_configquery.endpointidforname(
                                   'j_ProposedPayment',
                                   'Fee')
                           AND r.fromobjectid = t_paymentprocessid)
                LOOP
                    DBMS_OUTPUT.put_line('feeobjid 3: ' || pp.feeobjid);

                    IF (rec.feeobjid = pp.feeobjid)
                    THEN
                        -- match found and exit loop on match found
                        t_match := TRUE;
                        t_relationshipid := pp.relationshipid;
                        EXIT WHEN t_match;
                    END IF;
                END LOOP;

                IF (t_match)
                THEN
                    -- match found, check if fee to pay is in payment table
                    IF (rec.seq IS NULL)
                    THEN
                        -- selected fee is not to be paid, remove from proposed payment job
                        api.pkg_relationshipupdate.remove(t_relationshipid);
                        api.pkg_logicaltransactionupdate.endtransaction;
                        COMMIT;

                        DBMS_OUTPUT.put_line(rec.feeobjid || '  DELETE');
                    ELSE
                        DBMS_OUTPUT.put_line(
                            rec.feeobjid || '  DO NOTHING (MATCH) ');
                        t_totalpaid := t_totalpaid + rec.amountpaid;
                    END IF;
                ELSE
                    IF (rec.seq IS NOT NULL)
                    THEN
                        -- check if payment has not already been paid
                        IF (  api.pkg_columnquery.numericvalue(rec.feeobjid,
                                                               'paidamount')
                            + api.pkg_columnquery.numericvalue(rec.feeobjid,
                                                               'amount')
                            + api.pkg_columnquery.numericvalue(
                                  rec.feeobjid,
                                  'adjustedamount') >
                            0)
                        THEN
                            DBMS_OUTPUT.put_line(rec.feeobjid || '  ADD');
                            t_totalpaid := t_totalpaid + rec.amountpaid;

                            -- added fee to be paid
                            -- add new relationship                (endpointid, fromobjectid, toobjectid)
                            t_rel :=
                                api.pkg_relationshipupdate.new(
                                    api.pkg_configquery.endpointidforname(
                                        'j_ProposedPayment',
                                        'Fee'),
                                    t_paymentprocessid,
                                    rec.feeobjid);

                            api.pkg_logicaltransactionupdate.endtransaction;
                            COMMIT;
                        ELSE
                            DBMS_OUTPUT.put_line(
                                rec.feeobjid || '  ALREADY PAID');

                            -- flag as error in payment
                            -- update payment table with 0 for no payment
                            -- indicate non payment on payment record
                            UPDATE bizmod_api.e_payments_t p
                               SET p.paymentobjectid = 0
                             WHERE p.feeobjid = rec.feeobjid;
                        END IF;
                    END IF;
                END IF;
            END LOOP;

            -- get number of fee records to pay
            SELECT COUNT(r.toobjectid)
              INTO t_feecount
              FROM api.relationships r
             WHERE r.endpointid =
                   api.pkg_configquery.endpointidforname('j_ProposedPayment',
                                                         'Fee')
               AND r.fromobjectid = t_paymentprocessid;
        END IF;

        IF (t_feecount > 0)
        THEN
            -- *****************************************************************************************
            -- Pay the fees
            -- *****************************************************************************************
            t_amountleft := t_totalpaid;

            -- remove default Payment Method
            SELECT r.relationshipid
              INTO t_rel
              FROM api.relationships r
             WHERE r.endpointid =
                   api.pkg_configquery.endpointidforname('j_ProposedPayment',
                                                         'PaymentMethod')
               AND r.fromobjectid = t_paymentprocessid;

            api.pkg_relationshipupdate.remove(t_rel);

            -- add Credit Card or E-Check payment method relationship to Proposed Payment job
            -- add new relationship                (endpointid, fromobjectid, toobjectid)
            SELECT pm.objectid
              INTO t_paymentmethodobjectid
              FROM query.o_paymentmethod pm
             WHERE pm.description = UPPER(a_paymentmethod)
                OR pm.code = UPPER(a_paymentmethod);

            t_rel :=
                api.pkg_relationshipupdate.new(
                    api.pkg_configquery.endpointidforname(
                        'j_ProposedPayment',
                        'PaymentMethod'),
                    t_paymentprocessid,
                    t_paymentmethodobjectid);
            api.pkg_columnupdate.setvalue(t_paymentprocessid,
                                          'PayeeReference',
                                          a_payeereference);
            api.pkg_columnupdate.setvalue(t_paymentprocessid,
                                          'TotalPayment',
                                          t_amountleft);
            api.pkg_columnupdate.setvalue(t_paymentprocessid,
                                          'PayeeName',
                                          a_payeename);
            api.pkg_columnupdate.setvalue(t_paymentprocessid,
                                          'PaymentDate',
                                          a_paymentdate);

            api.pkg_columnupdate.setvalue(t_paymentprocessid,
                                          'ProcessPaymentFlag',
                                          'Y');

            FOR rec
                IN (SELECT r.toobjectid        feeobjid,
                           r.relationshipid,
                           fsch.toobjectid     feescheduleobjectid
                      FROM api.relationships  r
                           JOIN api.relationships fsch
                               ON fsch.endpointid =
                                  api.pkg_configquery.endpointidforname(
                                      'o_Fee',
                                      'LicenseFeeSchedule')
                              AND fsch.fromobjectid = r.toobjectid
                     WHERE r.endpointid =
                           api.pkg_configquery.endpointidforname(
                               'j_ProposedPayment',
                               'Fee')
                       AND r.fromobjectid = t_paymentprocessid)
            LOOP
                DBMS_OUTPUT.put_line('feeobjid: ' || rec.feeobjid);

                SELECT amountpaid
                  INTO t_amountpaid
                  FROM bizmod_api.e_payments_t p
                 WHERE p.feeobjid = rec.feeobjid;

                CASE
                    WHEN (t_amountleft <= t_amountpaid)
                    THEN -- under payments
                        api.pkg_columnupdate.setvalue(rec.relationshipid,
                                                      'AmountToPay',
                                                      t_amountleft);
                        t_amountleft := 0;
                    WHEN (t_amountleft > t_amountpaid
                      AND t_feecount = 1)
                    THEN -- Over Payment
                        api.pkg_columnupdate.setvalue(rec.relationshipid,
                                                      'AmountToPay',
                                                      t_amountleft);
                        api.pkg_columnupdate.setvalue(rec.relationshipid,
                                                      'OVR',
                                                      'Y');
                    ELSE -- normal payment
                        api.pkg_columnupdate.setvalue(rec.relationshipid,
                                                      'AmountToPay',
                                                      t_amountpaid);
                        t_amountleft := t_amountleft - t_amountpaid;
                END CASE;

                t_feecount := t_feecount - 1;
            END LOOP;

            api.pkg_logicaltransactionupdate.endtransaction;
            COMMIT;

            SELECT r.toobjectid
              INTO t_paymentobjectid
              FROM api.relationships r
             WHERE r.endpointid =
                   api.pkg_configquery.endpointidforname('j_ProposedPayment',
                                                         'Payment')
               AND r.fromobjectid = t_paymentprocessid;

            -- create receipt payment process
            t_processdefid :=
                api.pkg_configquery.objectdefidforname('p_ReceiptPayments');
            t_processid :=
                api.pkg_processupdate.new(
                    a_job       => t_jobid,
                    a_processtype => t_processdefid,
                    a_description => 'Receipt Payments',
                    a_scheduledstartdate => SYSDATE,
                    a_scheduledenddate => SYSDATE,
                    a_actualstartdate => SYSDATE);

            -- remove payments not paid by this process
            FOR rec
                IN (SELECT r.*,
                           api.pkg_columnquery.VALUE(r.toobjectid,
                                                     'objectdefname')    nam
                      FROM api.relationships r
                     WHERE r.endpointid =
                           api.pkg_configquery.endpointidforname(
                               'p_ReceiptPayments',
                               'Payment')
                       AND r.fromobjectid = t_processid
                       AND r.toobjectid != t_paymentobjectid)
            LOOP
                api.pkg_relationshipupdate.remove(rec.relationshipid);
            END LOOP;

            SELECT s.sequenceid
              INTO t_sequenceid
              FROM api.sequences s
             WHERE s.description = 'Receipt Number';

            t_receiptnumber :=
                api.pkg_utils.generateexternalfilenum('[0000000]',
                                                      t_sequenceid);
            api.pkg_columnupdate.setvalue(t_processid,
                                          'ReceiptNumber',
                                          t_receiptnumber);

            api.pkg_columnupdate.setvalue(t_processid, 'Outcome', 'Receipt');

            api.pkg_logicaltransactionupdate.endtransaction;
            COMMIT;
        ELSE
            -- remove perpose payment job (no fees to pay)
            api.pkg_jobupdate.remove(t_paymentprocessid);
            api.pkg_logicaltransactionupdate.endtransaction;
            COMMIT;

            a_sqlerrm := 'No Fee Records found for payment';
        END IF;

        -- return payment object id
        RETURN t_paymentobjectid;
    EXCEPTION
        WHEN OTHERS
        THEN
            a_sqlerrm := SUBSTR(SQLERRM, 1, 3990);
            a_backtrace :=
                SUBSTR(DBMS_UTILITY.format_error_backtrace, 1, 3990);

            DBMS_OUTPUT.put_line(a_sqlerrm || '  ' || a_backtrace);
            api.pkg_logicaltransactionupdate.resettransaction;
            ROLLBACK;

            RETURN -1;
    END payfees;
END;
/


GRANT EXECUTE ON BIZMOD_API.E_PAYMENT TO ABC;

GRANT EXECUTE ON BIZMOD_API.E_PAYMENT TO POSSEEXTENSIONS;
