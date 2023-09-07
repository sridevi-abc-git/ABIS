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
    BEGIN
        api.pkg_logicaltransactionupdate.resettransaction;
        ROLLBACK;

        -- From License number get first license type job for creating proposed payment job
        --  and generate any required penalties
        WITH
            ltobjid
            AS
                (SELECT objectid,
                        api.pkg_columnquery.VALUE(objectid,
                                                  'LicenseTypeCode')
                            licensetypecode,
                        api.pkg_columnquery.VALUE(objectid,
                                                  'SecondaryLicenseTypeCode')
                            secondarylicensetypecode
                   FROM TABLE(
                            CAST(
                                api.pkg_simplesearch.castableobjectsbyindex(
                                    a_objectdefname => 'j_licensetype',
                                    a_columnname =>
                                        'dup_LicenseExternalFileNum',
                                    a_value     => a_licensenumber)
                                    AS api.udt_objectlist)) o)
        SELECT lt.objectid
          INTO t_jobid
          FROM bizmod_api.e_payments_t  p
               JOIN ltobjid lt
                   ON ((lt.licensetypecode = p.licensetypecode
                     OR lt.secondarylicensetypecode = p.licensetypecode))
         WHERE p.licensenumber = a_licensenumber
           AND p.confirmationid = a_payeereference
           AND p.paymentobjectid IS NULL
           AND ROWNUM = 1;

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
                api.pkg_configquery.objectdefidforname('j_ProposedPayment'),
                'ProposedPayment',
                NULL,
                t_jobid);

        api.pkg_logicaltransactionupdate.endtransaction;
        COMMIT;

        -- *****************************************************************************************
        -- Add any additional fees for selected license not found on current license type
        -- *****************************************************************************************
        SELECT api.udt_object(reo.objectid)
          BULK COLLECT INTO lst
          FROM TABLE(
                   CAST(
                       api.pkg_simplesearch.castableobjectsbyindex(
                           a_objectdefname => 'j_licensetype',
                           a_columnname => 'dup_LicenseExternalFileNum',
                           a_value     => a_licensenumber)
                           AS api.udt_objectlist)) o
               JOIN api.fees f ON (f.jobid = o.objectid)
               JOIN api.registeredexternalobjects reo
                   ON (reo.objectdefid =
                       api.pkg_configquery.objectdefidforname('o_fee')
                   AND reo.linkvalue = TO_CHAR(f.feeid))
               JOIN bizmod_api.e_payments_t p
                   ON reo.objectid = p.feeobjid
                  AND paidamount + amount + adjustedamount > 0;

        FOR rec
            IN (SELECT f.objectid     feeobjid
                  FROM (SELECT r.toobjectid     feeobjid
                          FROM api.relationships r
                         WHERE r.endpointid =
                               api.pkg_configquery.endpointidforname(
                                   'j_ProposedPayment',
                                   'Fee')
                           AND r.fromobjectid = t_paymentprocessid) y
                       RIGHT OUTER JOIN TABLE(lst) f
                           ON f.objectid = NVL(y.feeobjid, f.objectid)
                 WHERE y.feeobjid IS NULL)
        LOOP
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
        END LOOP;

        -- *****************************************************************************************
        -- Validate fees that are to be paid are in Proposed Payment List
        -- *****************************************************************************************
        -- This result set only returns records not found in the proposed payment list to pay

        FOR rec
            IN (SELECT p.ROWID     rid
                  FROM bizmod_api.e_payments_t p
                 WHERE NVL(p.feeobjid, 0) NOT IN
                           (SELECT r.toobjectid
                              FROM api.relationships r
                             WHERE r.endpointid =
                                   api.pkg_configquery.endpointidforname(
                                       'j_ProposedPayment',
                                       'Fee')
                               AND r.fromobjectid = t_paymentprocessid)
                   AND p.confirmationid = a_payeereference)
        LOOP
            -- indicate non payment on payment record
            UPDATE bizmod_api.e_payments_t p
               SET p.paymentobjectid = 0
             WHERE p.ROWID = rec.rid;
        END LOOP;

        -- *****************************************************************************************
        -- Remove any fees not selected to be paid from the proposed payment list
        -- *****************************************************************************************
        FOR rec
            IN (SELECT r.relationshipid
                  FROM api.relationships  r
                       LEFT OUTER JOIN bizmod_api.e_payments_t p
                           ON (r.toobjectid = NVL(p.feeobjid, 0))
                 WHERE r.endpointid =
                       api.pkg_configquery.endpointidforname(
                           'j_ProposedPayment',
                           'Fee')
                   AND r.fromobjectid = t_paymentprocessid
                   AND (p.feeobjid IS NULL
                     OR p.paymentobjectid IS NOT NULL))
        LOOP
            api.pkg_relationshipupdate.remove(rec.relationshipid);
            api.pkg_logicaltransactionupdate.endtransaction;
            COMMIT;
        END LOOP;

        -- *****************************************************************************************
        -- Pay the fees
        -- *****************************************************************************************
        -- get number of fee records to pay
        SELECT COUNT(r.toobjectid)
          INTO t_feecount
          FROM api.relationships r
         WHERE r.endpointid =
               api.pkg_configquery.endpointidforname('j_ProposedPayment',
                                                     'Fee')
           AND r.fromobjectid = t_paymentprocessid;

        IF (t_feecount > 0)
        THEN
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
                BEGIN
                    SELECT amountpaid
                      INTO t_amountpaid
                      FROM bizmod_api.e_payments_t p
                     WHERE p.licensenumber = a_licensenumber
                       AND p.licensetypecode =
                           api.pkg_columnquery.VALUE(rec.feescheduleobjectid,
                                                     'LicenseTypeCode')
                       AND p.paymentobjectid IS NULL
                       AND p.confirmationid = a_payeereference
                       AND REGEXP_SUBSTR(p.description,
                                         '[^ ]+',
                                         1,
                                         3) =
                           api.pkg_columnquery.VALUE(rec.feescheduleobjectid,
                                                     'FeeActivity');
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        t_amountpaid := 0;
                        DBMS_OUTPUT.put_line(
                            'Not Found '
                            || '  fee schedule: '
                            || api.pkg_columnquery.VALUE(
                                   rec.feescheduleobjectid,
                                   'FeeActivity')
                            || ' lt: '
                            || api.pkg_columnquery.VALUE(
                                   rec.feescheduleobjectid,
                                   'LicenseTypeCode'));
                END;

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

            SELECT r.toobjectid
              INTO t_paymentobjectid
              FROM api.relationships r
             WHERE r.endpointid =
                   api.pkg_configquery.endpointidforname('j_ProposedPayment',
                                                         'Payment')
               AND r.fromobjectid = t_paymentprocessid;
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

    -- ************************************************************************
    --  FUNCTION:       createtransmittal
    --
    --  PARAMETERS:
    --      a_TransmittalType       Check, Credit
    -- ************************************************************************
    FUNCTION createtransmittal
        RETURN api.udt_objectlist
    IS
        --        t_transmittal  api.pkg_definition.udt_id;
        t_objectlist   api.udt_objectlist;
        t_sqlerrm      VARCHAR2(4000);
        t_backtrace    VARCHAR2(4000);
        t_seq          NUMBER := bizmod_api.e_payment_seq.NEXTVAL();
        t_processid    api.pkg_definition.udt_id;

        t_transmittaldefid api.pkg_definition.udt_id;
        t_transmittals api.udt_objectlist := api.udt_objectlist();
        t_transmittalobjectid api.pkg_definition.udt_id;
        t_rel          api.pkg_definition.udt_id;

        t_paymentamount NUMBER := 0;
        t_paymentcount NUMBER := 0;
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
                           'o_Payment') p;

            IF (t_objectlist.COUNT > 0)
            THEN
                BEGIN
                    -- *****************************************************************
                    -- Create Transmittal job
                    -- *****************************************************************
                    -- check for last opened transmital not completed
                    DBMS_OUTPUT.put_line('new transmittal');

                    t_transmittaldefid :=
                        api.pkg_configquery.objectdefidforname(
                            'j_Transmittal');
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
                               api.pkg_columnquery.numericvalue(
                                   toobjectid,
                                   'PaymentAmount')),
                           COUNT(1)
                      INTO t_paymentamount, t_paymentcount
                      FROM api.relationships r
                     WHERE r.endpointid =
                           api.pkg_configquery.endpointidforname(
                               'j_Transmittal',
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
                   AND p.processtypeid = api.pkg_objectdefquery.idforname('p_PrepareTransmittal');

                -- set outcome to Complete (process will complete when COMMIT is executed.
                api.pkg_logicaltransactionupdate.starttransaction;
                api.pkg_columnupdate.setvalue(t_processid, 'Outcome', 'Sent to HQ');
                api.pkg_logicaltransactionupdate.endtransaction;
                COMMIT;
                -- end BIZ-12648
                    
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        t_sqlerrm := SUBSTR(SQLERRM, 1, 3990);
                        t_backtrace :=
                            SUBSTR(DBMS_UTILITY.format_error_backtrace,
                                   1,
                                   3990);

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
                       SET p.transmittalbatch =
                               NVL(pm.transmittalobjectid, -1),
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

        RETURN t_transmittals;
    END createtransmittal;

    PROCEDURE createawfpayments
    IS
        TYPE awf_rec IS RECORD(seq NUMBER,
                               licensenumber VARCHAR2(10),
                               licensetypecode VARCHAR2(3),
                               paymentamount NUMBER,
                               gallonage NUMBER,
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

        t_feeamount    NUMBER;
        t_totalfees    NUMBER;
        t_checkcount   NUMBER;
        t_receiptnumber NUMBER;
        t_batchid      VARCHAR2(30);
        t_licensetypecode VARCHAR2(3);
        t_licensenumber VARCHAR2(10);
        t_sequenceid   api.pkg_definition.udt_id;
        t_cnt          NUMBER;
        t_loop         NUMBER := 2;
        t_limit        NUMBER := 200;
    BEGIN
        api.pkg_logicaltransactionupdate.resettransaction;
        ROLLBACK;

        WHILE (t_loop > 0)
        LOOP
            SELECT (SELECT seq
                      FROM bizmod_api.e_payments_t p
                     WHERE pp.licensenumber = p.licensenumber
                       AND pp.confirmationnumber = p.confirmationid
                       AND pp.paymenttype = 'Primary')    seq,
                   a.licensenumber,
                   a.licensetypecode,
                   NVL(pp.paymentamount, 0)               paymentamount,
                   a.gallonage261                         gallonage,
                   a.ROWID                                rowkey
              BULK COLLECT INTO t_awf
              FROM bizmod_api.awf_t  a
                   LEFT OUTER JOIN bizmod_api.e_payments_processed_t pp
                       ON (a.licensenumber = pp.licensenumber)
             WHERE a.completed IS NULL
               AND a.paymentbatch IS NULL
               AND a.submitteddate IS NOT NULL
               AND ((t_loop = 2
                 AND a.awffeeamount <= 0) -- AWF batch for no change and refund
                 OR (t_loop = 1
                 AND a.awffeeamount > 0 -- AWF batch for payments
                 AND EXISTS
                         (SELECT 1
                            FROM bizmod_api.e_payments_t p
                           WHERE pp.licensenumber = p.licensenumber
                             AND pp.confirmationnumber = p.confirmationid
                             AND pp.paymenttype = 'Primary'
                             AND p.paymentobjectid IS NULL)));

            DBMS_OUTPUT.put_line(t_loop || '  to process ' || t_awf.COUNT);

            IF (t_awf.COUNT > 0)
            THEN
                -- *****************************************************************
                -- Initialize batch variables at begining of each batch loop
                -- *****************************************************************
                t_feeamount := 0;
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
                    BEGIN
                        t_batchpaymententrydefid :=
                            api.pkg_configquery.objectdefidforname(
                                'o_BatchPaymentEntry');
                        t_batchpaymententryobjectid :=
                            api.pkg_objectupdate.new(
                                t_batchpaymententrydefid);

                        api.pkg_logicaltransactionupdate.endtransaction;
                        COMMIT;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            api.pkg_logicaltransactionupdate.resettransaction;
                            ROLLBACK;
                            DBMS_OUTPUT.put_line(
                                'ERROR: '
                                || t_licensetypecode
                                || ' - '
                                || t_licensenumber
                                || ' - '
                                || t_feeamount);

                            CONTINUE;
                    END;

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

                IF (t_loop = 2)
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

                IF (t_loop = 2)
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
                               CASE t_loop
                                   WHEN 2
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
            END IF;

            t_loop := t_loop - 1;
        END LOOP;
    END;
END;
/


GRANT EXECUTE ON BIZMOD_API.E_PAYMENT TO ABC;

GRANT EXECUTE ON BIZMOD_API.E_PAYMENT TO POSSEEXTENSIONS;
