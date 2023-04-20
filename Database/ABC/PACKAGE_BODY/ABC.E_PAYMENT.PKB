CREATE OR REPLACE PACKAGE BODY ABC.e_payment
AS
    -- **************************************************************************
    -- File:        E_PAYMENT.PKB
    -- Author:      Timothy J.Lord
    --
    -- Description:
    --
    --
    -- History:
    -----------------------------------------------------------------------------
    --    Date                  Comment
    -- 04/29/2021 TJL       Package Created
    -- 10/12/2021 TJL       In Processpayment added updates for when a payment
    --                       is deleted from transmittal and added manually adde
    --                       to another transmittal.
    -- **************************************************************************

    PROCEDURE createpenaltyfee(a_jobid        IN api.pkg_definition.udt_id,
                               a_feeobjid     IN api.pkg_definition.udt_id,
                               a_description  IN VARCHAR2)
    IS
        t_relid               NUMBER;
        t_adjustid            NUMBER;
        t_feetransobjid       NUMBER;

        t_feeid               NUMBER;
        t_ismaster            VARCHAR2(1);
        t_secondarycount      NUMBER;
        t_masterlt            VARCHAR2(2);
        t_feescheduleid       NUMBER;
        t_feeschedulepenid    NUMBER;
        t_originalfeeamount   NUMBER;
        t_feepenamount        NUMBER := 0;
        t_feependescription   VARCHAR2(20);

        t_adjustedamount      NUMBER;
        t_totalowing          NUMBER;
        t_loop                NUMBER;
        t_primarysecondary    VARCHAR2(1);
    BEGIN
        api.pkg_logicaltransactionupdate.resettransaction;
        ROLLBACK;

        -- get current relationship to current fee schedule and dynamic details
        SELECT r.relationshipid,
               api.pkg_columnquery.VALUE(r.relationshipid, 'IsMaster'),
               api.pkg_columnquery.numericvalue(r.relationshipid, 'SecondaryCount'),
               api.pkg_columnquery.VALUE(r.relationshipid, 'MasterLT'),
                 api.pkg_columnquery.numericvalue(r.fromobjectid, 'Amount')
               + api.pkg_columnquery.numericvalue(r.fromobjectid, 'AdjustedAmount'),
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
         WHERE r.endpointid = api.pkg_configquery.endpointidforname('o_Fee', 'LicenseFeeSchedule')
           AND r.fromobjectid = a_feeobjid;

        DBMS_OUTPUT.put_line(   'master: '
                             || t_ismaster
                             || '  sec count: '
                             || t_secondarycount
                             || '  masterlt: '
                             || t_masterlt);

        t_loop             :=
            CASE
                WHEN t_ismaster = 'Y'
                 AND t_secondarycount > 0 THEN
                    2
                ELSE
                    1
            END;

        LOOP
            SELECT CASE
                       WHEN t_loop = 2 THEN
                           'P'
                       WHEN t_loop = 1
                        AND t_secondarycount = 0 THEN
                           CASE WHEN MAX(r.toobjectid) IS NULL THEN 'P' ELSE 'B' END
                       WHEN t_loop = 1
                        AND t_secondarycount > 0 THEN
                           'S'
                   END
              INTO t_primarysecondary
              FROM api.relationships r
             WHERE r.endpointid = api.pkg_configquery.endpointidforname('j_LicenseType', 'MasterLicenseType')
               AND r.fromobjectid = a_jobid;

            -- get new fee schedule id to penalty and amount and penalty description
            SELECT   CASE t_primarysecondary
                         WHEN 'P' THEN fs.primaryamount
                         WHEN 'S' THEN (fs.secondaryamount * t_secondarycount)
                         WHEN 'B' THEN fs.branchamount
                     END
                   + t_feepenamount,
                      fs.licensetypecode
                   || ' - '
                   || fs.description,
                   fs.objectid
              INTO t_feepenamount, t_feependescription, t_feeschedulepenid
              FROM sitespecific.feeschedule_t fs
                   JOIN sitespecific.feeschedule_t fs2
                   ON (NVL(fs.licensetypecode, 'x') = NVL(fs2.licensetypecode, 'x')
                   AND NVL(fs.otherfeecode, 'x') = NVL(fs2.otherfeecode, 'x')
                   AND NVL(fs.gallonagerange, 'x') = NVL(fs2.gallonagerange, 'x')
                   AND NVL(fs.populationrange, 'x') = NVL(fs2.populationrange, 'x')
                   AND NVL(fs.numberofmonthslicensed, 'x') = NVL(fs2.numberofmonthslicensed, 'x')
                   AND NVL(fs.feetier, 'x') = NVL(fs2.feetier, 'x')
                   AND fs2.objectid = t_feescheduleid)
             WHERE fs.feeactivity = REGEXP_SUBSTR(a_description,
                                                  '[^ ]+',
                                                  1,
                                                  3)
               AND fs.effectivedate =
                   (SELECT MAX(fs2.effectivedate)
                      FROM sitespecific.feeschedule_t fs2
                     WHERE NVL(fs2.licensetypecode, '0') = NVL(fs.licensetypecode, '0')
                       AND fs2.feeactivity = fs.feeactivity
                       AND NVL(fs2.gallonagerange, 'x') = NVL(fs.gallonagerange, 'x')
                       AND NVL(fs2.populationrange, 'x') = NVL(fs.populationrange, 'x')
                       AND NVL(fs2.numberofmonthslicensed, 'x') = NVL(fs.numberofmonthslicensed, 'x')
                       AND NVL(fs2.feetier, 'x') = NVL(fs.feetier, 'x')
                       AND NVL(fs2.otherfeecode, 'x') = NVL(fs.otherfeecode, 'x'));

            t_loop   := t_loop - 1;
            EXIT WHEN t_loop < 1;
        END LOOP;

        t_adjustedamount   := (t_feepenamount - t_originalfeeamount);

        DBMS_OUTPUT.put_line(   'adj: '
                             || t_adjustedamount
                             || '  penamt: '
                             || t_feepenamount
                             || '  ttl: '
                             || t_totalowing
                             || '  desc: '
                             || t_feependescription
                             || '  PS: '
                             || t_primarysecondary);


        -- add penality record
        t_adjustid         :=
            api.pkg_feeupdate.adjust(api.pkg_columnquery.numericvalue(a_feeobjid, 'FeeId'),  --t_feeid,
                                     t_adjustedamount,  --ROUND(t_pfeeamount - t_originalamount),
                                     t_feependescription,  --t_description,
                                     SYSDATE);
        t_feetransobjid    := api.pkg_objectupdate.registerexternalobject('o_FeeTransactions', t_adjustid);

        -- remove old fee schedule id
        api.pkg_relationshipupdate.remove(t_relid);

        -- add new relationship to new fee schedule                (endpointid, fromobjectid, toobjectid)
        t_relid            :=
            api.pkg_relationshipupdate.new(api.pkg_configquery.endpointidforname('o_fee', 'LicenseFeeSchedule'),
                                           a_feeobjid,
                                           t_feeschedulepenid);


        api.pkg_columnupdate.setvalue(t_relid, 'IsMaster', t_ismaster);
        api.pkg_columnupdate.setvalue(t_relid, 'MasterLT', t_masterlt);
        api.pkg_columnupdate.setvalue(t_relid, 'secondarycount', t_secondarycount);


        /*
                -- set license type  to
                    final rev. pending (50%)
                    Auto Revoke (100%)

            -- secondary relationship
        j_LicenseType Relationship (76) Secondary License Type Category:License Type Category
          Final Rev.Pending (50%)
          Auto Revoke   (100%)
        */

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
        t_amountpaid              NUMBER;
        t_amountleft              NUMBER := a_payamount;
        t_feecount                NUMBER := 0;

        t_paymentprocessid        api.pkg_definition.udt_id;
        t_paymentobjectid         api.pkg_definition.udt_id := 0;
        t_processid               api.pkg_definition.udt_id;
        t_processdefid            api.pkg_definition.udt_id;
        t_relationshipid          api.pkg_definition.udt_id;
        t_jobid                   api.pkg_definition.udt_id;
        lst                       api.udt_objectlist;
        t_rel                     NUMBER;

        t_receiptnumber           VARCHAR2(40);
        t_sequenceid              api.pkg_definition.udt_id;
        t_paymentmethodobjectid   api.pkg_definition.udt_id;
        t_description             VARCHAR2(20);
        t_feeobjid                api.pkg_definition.udt_id;
    BEGIN
        api.pkg_logicaltransactionupdate.resettransaction;
        ROLLBACK;

        -- From License number get first license type job for creating proposed payment job
        --  and generate any required penalties
        WITH
            ltobjid
            AS
                (SELECT objectid,
                        api.pkg_columnquery.VALUE(objectid, 'LicenseTypeCode')          licensetypecode,
                        api.pkg_columnquery.VALUE(objectid, 'SecondaryLicenseTypeCode') secondarylicensetypecode
                   FROM TABLE(
                            CAST(
                                api.pkg_simplesearch.castableobjectsbyindex(
                                    a_objectdefname => 'j_licensetype',
                                    a_columnname => 'dup_LicenseExternalFileNum',
                                    a_value     => a_licensenumber) AS api.udt_objectlist)) o)
        SELECT lt.objectid
          INTO t_jobid
          FROM bizmod_api.e_payments_t p
               JOIN ltobjid lt
               ON ((lt.licensetypecode = p.licensetypecode
                 OR lt.secondarylicensetypecode = p.licensetypecode))
         WHERE p.licensenumber = a_licensenumber
           AND p.confirmationid = a_payeereference
           AND p.paymentobjectid IS NULL
           AND ROWNUM = 1;

        /*************************************************************************************
        -- add penalty fees if needed
        FOR rec IN (SELECT p.feeobjid, p.description
                      FROM bizmod_api.e_payments_t p
                     WHERE p.licensenumber = a_licensenumber
                       AND p.confirmationid = a_payeereference
                       AND p.paymentobjectid IS NULL)
        LOOP
            -- check if penalty fee needs to be created
            IF (rec.description != api.pkg_columnquery.VALUE(rec.feeobjid, 'Description')) THEN
                createpenaltyfee(a_jobid => t_jobid, a_feeobjid => rec.feeobjid, a_description => rec.description);
            END IF;

        END LOOP;
        *******************************************************************************************/

        -- *****************************************************************************************
        -- Create Proposed Payment Job
        -- *****************************************************************************************
        INSERT INTO abc.tmp_jobid(objectid)
             VALUES (t_jobid);

        -- create payment process
        t_paymentprocessid   :=
            api.pkg_jobupdate.new(api.pkg_configquery.objectdefidforname('j_ProposedPayment'),
                                  'ProposedPayment',
                                  NULL,
                                  t_jobid);
        DBMS_OUTPUT.put_line(   'jobid : '
                             || t_jobid
                             || '  Proposed Payment: '
                             || t_paymentprocessid);

        api.pkg_logicaltransactionupdate.endtransaction;
        COMMIT;

        -- *****************************************************************************************
        -- Add any additional fees for selected license not found on current license type
        -- *****************************************************************************************
        SELECT api.udt_object(reo.objectid)
          BULK COLLECT INTO lst
          FROM TABLE(
                   CAST(
                       api.pkg_simplesearch.castableobjectsbyindex(a_objectdefname => 'j_licensetype',
                                                                   a_columnname => 'dup_LicenseExternalFileNum',
                                                                   a_value     => a_licensenumber) AS api.udt_objectlist))
               o
               JOIN api.fees f
               ON (f.jobid = o.objectid)
               JOIN api.registeredexternalobjects reo
               ON (reo.objectdefid = api.pkg_configquery.objectdefidforname('o_fee')
               AND reo.linkvalue = TO_CHAR(f.feeid))
               JOIN bizmod_api.e_payments_t p
               ON reo.objectid = p.feeobjid
              AND paidamount + amount + adjustedamount > 0;

        DBMS_OUTPUT.put_line(   'fees to pay: '
                             || lst.COUNT);

        FOR rec IN (SELECT f.objectid feeobjid
                      FROM (SELECT r.toobjectid feeobjid
                              FROM api.relationships r
                             WHERE r.endpointid = api.pkg_configquery.endpointidforname('j_ProposedPayment', 'Fee')
                               AND r.fromobjectid = t_paymentprocessid) y
                           RIGHT OUTER JOIN TABLE(lst) f
                           ON f.objectid = NVL(y.feeobjid, f.objectid)
                     WHERE y.feeobjid IS NULL)
        LOOP
            -- add new relationship                (endpointid, fromobjectid, toobjectid)
            t_rel   :=
                api.pkg_relationshipupdate.new(api.pkg_configquery.endpointidforname('j_ProposedPayment', 'Fee'),
                                               t_paymentprocessid,
                                               rec.feeobjid);

            api.pkg_logicaltransactionupdate.endtransaction;
            COMMIT;
            DBMS_OUTPUT.put_line('Adding');
        END LOOP;

        -- *****************************************************************************************
        -- Validate fees that are to be paid are in Proposed Payment List
        -- *****************************************************************************************
        -- This result set only returns records not found in the proposed payment list to pay
        FOR rec
            IN (WITH
                    pp
                    AS
                        (SELECT  /*+ materialize */
                                api.pkg_columnquery.VALUE(fsch.toobjectid, 'LicenseTypeCode')         licensetypecode,
                                api.pkg_columnquery.VALUE(fsch.fromobjectid, 'DescriptionForDisplay') description
                           FROM api.relationships r
                                JOIN api.relationships fsch
                                ON fsch.endpointid =
                                   api.pkg_configquery.endpointidforname('o_Fee', 'LicenseFeeSchedule')
                               AND fsch.fromobjectid = r.toobjectid
                          WHERE r.endpointid = api.pkg_configquery.endpointidforname('j_ProposedPayment', 'Fee')
                            AND r.fromobjectid = t_paymentprocessid)
                SELECT p.ROWID rid,
                       p.amountpaid,
                       pp.licensetypecode,
                       pp.description
                  FROM bizmod_api.e_payments_t p
                       LEFT OUTER JOIN pp
                       ON (pp.licensetypecode = p.licensetypecode
                       AND pp.description = p.description)
                 WHERE p.licensenumber = a_licensenumber
                   AND p.confirmationid = a_payeereference
                   AND pp.licensetypecode IS NULL
                   AND p.paymentobjectid IS NULL)
        LOOP
            -- validate that this payment record is one that is suppose to be paid
            --   but no payment record found.
            IF (INSTR(a_licensetypecodes, rec.licensetypecode) > 0) THEN
                -- indicate non payment on payment record
                UPDATE bizmod_api.e_payments_t p
                   SET p.paymentobjectid   = 0
                 WHERE p.ROWID = rec.rid;

                DBMS_OUTPUT.put_line(   'Removing record: '
                                     || a_licensenumber
                                     || ' x '
                                     || rec.licensetypecode
                                     || ' x '
                                     || rec.description);
            END IF;
        END LOOP;

        -- *****************************************************************************************
        -- Remove any fees not selected to be paid from the proposed payment list
        -- *****************************************************************************************
        FOR rec
            IN (SELECT r.relationshipid
                  FROM api.relationships r
                 WHERE r.endpointid = api.pkg_configquery.endpointidforname('j_ProposedPayment', 'Fee')
                   AND r.fromobjectid = t_paymentprocessid
                   AND INSTR(a_licensetypecodes,
                             SUBSTR(api.pkg_columnquery.VALUE(r.toobjectid, 'Description'), 1, 2)) =
                       0
                   AND NOT EXISTS
                           (SELECT 1
                              FROM bizmod_api.e_payments_t p
                             WHERE p.feeobjid = r.toobjectid))
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
         WHERE r.endpointid = api.pkg_configquery.endpointidforname('j_ProposedPayment', 'Fee')
           AND r.fromobjectid = t_paymentprocessid;

        DBMS_OUTPUT.put_line(   'fee count: '
                             || t_feecount);

        IF (t_feecount > 0) THEN
            -- remove default Payment Method
            SELECT r.relationshipid
              INTO t_rel
              FROM api.relationships r
             WHERE r.endpointid = api.pkg_configquery.endpointidforname('j_ProposedPayment', 'PaymentMethod')
               AND r.fromobjectid = t_paymentprocessid;

            api.pkg_relationshipupdate.remove(t_rel);

            -- add Credit Card or E-Check payment method relationship to Proposed Payment job
            -- add new relationship                (endpointid, fromobjectid, toobjectid)
            SELECT pm.objectid
              INTO t_paymentmethodobjectid
              FROM query.o_paymentmethod pm
             WHERE pm.description = UPPER(a_paymentmethod)
                OR pm.code = UPPER(a_paymentmethod);

            t_rel             :=
                api.pkg_relationshipupdate.new(
                    api.pkg_configquery.endpointidforname('j_ProposedPayment', 'PaymentMethod'),
                    t_paymentprocessid,
                    t_paymentmethodobjectid);
            api.pkg_columnupdate.setvalue(t_paymentprocessid, 'PayeeReference', a_payeereference);
            api.pkg_columnupdate.setvalue(t_paymentprocessid, 'TotalPayment', t_amountleft);
            api.pkg_columnupdate.setvalue(t_paymentprocessid, 'PayeeName', a_payeename);
            api.pkg_columnupdate.setvalue(t_paymentprocessid, 'PaymentDate', a_paymentdate);

            api.pkg_columnupdate.setvalue(t_paymentprocessid, 'ProcessPaymentFlag', 'Y');

            FOR rec
                IN (SELECT r.toobjectid feeobjid, r.relationshipid, fsch.toobjectid feescheduleobjectid
                      FROM api.relationships r
                           JOIN api.relationships fsch
                           ON fsch.endpointid = api.pkg_configquery.endpointidforname('o_Fee', 'LicenseFeeSchedule')
                          AND fsch.fromobjectid = r.toobjectid
                     WHERE r.endpointid = api.pkg_configquery.endpointidforname('j_ProposedPayment', 'Fee')
                       AND r.fromobjectid = t_paymentprocessid)
            LOOP
                BEGIN
                    SELECT amountpaid
                      INTO t_amountpaid
                      FROM bizmod_api.e_payments_t p
                     WHERE p.licensenumber = a_licensenumber
                       AND p.licensetypecode = api.pkg_columnquery.VALUE(rec.feescheduleobjectid, 'LicenseTypeCode')
                       AND p.paymentobjectid IS NULL
                       AND p.confirmationid = a_payeereference
                       AND REGEXP_SUBSTR(p.description,
                                         '[^ ]+',
                                         1,
                                         3) = api.pkg_columnquery.VALUE(rec.feescheduleobjectid, 'FeeActivity');
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        t_amountpaid   := 0;
                        DBMS_OUTPUT.put_line(
                               'Not Found '
                            || '  fee schedule: '
                            || api.pkg_columnquery.VALUE(rec.feescheduleobjectid, 'FeeActivity')
                            || ' lt: '
                            || api.pkg_columnquery.VALUE(rec.feescheduleobjectid, 'LicenseTypeCode'));
                END;

                CASE
                    WHEN (t_amountleft <= t_amountpaid) THEN  -- under payments
                        api.pkg_columnupdate.setvalue(rec.relationshipid, 'AmountToPay', t_amountleft);
                        t_amountleft   := 0;
                    WHEN (t_amountleft > t_amountpaid
                      AND t_feecount = 1) THEN  -- Over Payment
                        api.pkg_columnupdate.setvalue(rec.relationshipid, 'AmountToPay', t_amountleft);
                        api.pkg_columnupdate.setvalue(rec.relationshipid, 'OVR', 'Y');
                    ELSE  -- normal payment
                        api.pkg_columnupdate.setvalue(rec.relationshipid, 'AmountToPay', t_amountpaid);
                        t_amountleft   := t_amountleft - t_amountpaid;
                END CASE;

                t_feecount   := t_feecount - 1;
            END LOOP;

            api.pkg_logicaltransactionupdate.endtransaction;
            COMMIT;

            -- create receipt payment process
            t_processdefid    := api.pkg_configquery.objectdefidforname('p_ReceiptPayments');
            t_processid       :=
                api.pkg_processupdate.new(a_job       => t_jobid,
                                          a_processtype => t_processdefid,
                                          a_description => 'Receipt Payments',
                                          a_scheduledstartdate => SYSDATE,
                                          a_scheduledenddate => SYSDATE,
                                          a_actualstartdate => SYSDATE);

            SELECT s.sequenceid
              INTO t_sequenceid
              FROM api.sequences s
             WHERE s.description = 'Receipt Number';

            t_receiptnumber   := api.pkg_utils.generateexternalfilenum('[0000000]', t_sequenceid);
            api.pkg_columnupdate.setvalue(t_processid, 'ReceiptNumber', t_receiptnumber);
            api.pkg_columnupdate.setvalue(t_processid, 'Outcome', 'Receipt');

            api.pkg_logicaltransactionupdate.endtransaction;
            COMMIT;

            SELECT r.toobjectid
              INTO t_paymentobjectid
              FROM api.relationships r
             WHERE r.endpointid = api.pkg_configquery.endpointidforname('j_ProposedPayment', 'Payment')
               AND r.fromobjectid = t_paymentprocessid;
        ELSE
            -- remove perpose payment job (no fees to pay)
            api.pkg_jobupdate.remove(t_paymentprocessid);
            api.pkg_logicaltransactionupdate.endtransaction;
            COMMIT;

            a_sqlerrm   := 'No Fee Records found for payment';
        END IF;

        -- return payment object id
        RETURN t_paymentobjectid;
    EXCEPTION
        WHEN OTHERS THEN
            a_sqlerrm     := SUBSTR(SQLERRM, 1, 3990);
            a_backtrace   := SUBSTR(DBMS_UTILITY.format_error_backtrace, 1, 3990);

            DBMS_OUTPUT.put_line(   a_sqlerrm
                                 || '  '
                                 || a_backtrace);
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
    FUNCTION createtransmittal(a_paymentobjectlist IN api.udt_objectlist,
                               a_paymentmethod IN    VARCHAR2,
                               a_sqlerrm         OUT VARCHAR2,
                               a_backtrace       OUT VARCHAR2)
        RETURN NUMBER
    IS
        t_transmittaldefid      api.pkg_definition.udt_id;
        t_transmittalobjectid   api.pkg_definition.udt_id;

        t_processid             api.pkg_definition.udt_id;

        t_paymentamount         NUMBER := 0;
        t_paymentcount          NUMBER := 0;
        t_cashiereddate         DATE := SYSDATE;
        t_count                 NUMBER;
    BEGIN
        api.pkg_logicaltransactionupdate.resettransaction;
        ROLLBACK;

        -- *****************************************************************
        -- Create Transmittal job
        -- *****************************************************************
        t_transmittaldefid      := api.pkg_configquery.objectdefidforname('j_Transmittal');
        t_transmittalobjectid   := api.pkg_objectupdate.new(t_transmittaldefid);

        api.pkg_columnupdate.setvalue(t_transmittalobjectid, 'TransmittalType', a_paymentmethod);
        api.pkg_columnupdate.setvalue(t_transmittalobjectid, 'PaymentCount', 1);
        api.pkg_columnupdate.setvalue(t_transmittalobjectid, 'PaymentTotalAmount', 1);
        api.pkg_columnupdate.setvalue(t_transmittalobjectid, 'GetReceiptedPayments', 'Y');

        api.pkg_logicaltransactionupdate.endtransaction;
        COMMIT;

        -- *****************************************************************
        -- Removed unwanted receipted payments
        -- *****************************************************************
        FOR rec IN (SELECT rn.relationshipid
                      FROM api.relationships rn
                     WHERE rn.endpointid = api.pkg_configquery.endpointidforname('j_Transmittal', 'Payment')
                       AND rn.fromobjectid = t_transmittalobjectid
                       AND rn.toobjectid NOT IN (SELECT objectid FROM TABLE(a_paymentobjectlist)))
        LOOP
            api.pkg_relationshipupdate.remove(rec.relationshipid);
        END LOOP;

        SELECT COUNT(1)
          INTO t_count
          FROM api.relationships r
         WHERE r.endpointid = api.pkg_configquery.endpointidforname('j_Transmittal', 'Payment')
           AND r.fromobjectid = t_transmittalobjectid;

        IF (t_count > 0) THEN
            SELECT SUM(api.pkg_columnquery.numericvalue(toobjectid, 'PaymentAmount')), COUNT(1)
              INTO t_paymentamount, t_paymentcount
              FROM api.relationships r
             WHERE r.endpointid = api.pkg_configquery.endpointidforname('j_Transmittal', 'Payment')
               AND r.fromobjectid = t_transmittalobjectid;

            IF (t_paymentcount = 0) THEN
                -- remove transmittal object
                api.pkg_objectupdate.remove(t_transmittalobjectid);

                api.pkg_logicaltransactionupdate.endtransaction;
                COMMIT;

                t_transmittalobjectid   := 0;
            ELSE
                -- *********************************************************************
                -- Update transmittal information
                -- *********************************************************************
                api.pkg_columnupdate.setvalue(t_transmittalobjectid, 'PaymentCount', t_paymentcount);
                api.pkg_columnupdate.setvalue(t_transmittalobjectid, 'PaymentTotalAmount', t_paymentamount);

                api.pkg_logicaltransactionupdate.endtransaction;
                COMMIT;

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
            /* Remove the cashering of transmittal from request of Accounting
            -- *****************************************************************
            -- Casher the transmittal
            -- *****************************************************************
            api.pkg_logicaltransactionupdate.starttransaction;

            api.pkg_columnupdate.setvalue(t_transmittalobjectid, 'CashieredDate', t_cashiereddate);
            api.pkg_columnupdate.setvalue(t_transmittalobjectid, 'PaymentCountCashier', t_paymentcount);
            api.pkg_columnupdate.setvalue(t_transmittalobjectid, 'BatchTotal', t_paymentamount);

            api.pkg_logicaltransactionupdate.endtransaction;
            COMMIT;

            -- *****************************************************************
            -- Find and process Cashier Transmittal
            -- *****************************************************************
            -- get processes
            SELECT processid
              INTO t_processid
              FROM api.processes p
             WHERE p.jobid = t_transmittalobjectid
               AND p.processtypeid = api.pkg_objectdefquery.idforname('p_CashierTransmittal');

            -- set outcome to Complete (process will complete when COMMIT is executed.
            api.pkg_logicaltransactionupdate.starttransaction;
            api.pkg_columnupdate.setvalue(t_processid, 'Outcome', 'Cashiered');
            api.pkg_logicaltransactionupdate.endtransaction;
            COMMIT;
            */
            END IF;
        ELSE
            api.pkg_objectupdate.remove(t_transmittalobjectid);
            api.pkg_logicaltransactionupdate.endtransaction;
            COMMIT;

            t_transmittalobjectid   := 0;
        END IF;

        RETURN t_transmittalobjectid;
    EXCEPTION
        WHEN OTHERS THEN
            a_sqlerrm     := SUBSTR(SQLERRM, 1, 3990);
            a_backtrace   := SUBSTR(DBMS_UTILITY.format_error_backtrace, 1, 3990);

            api.pkg_logicaltransactionupdate.resettransaction;
            ROLLBACK;

            RETURN -1;
    END createtransmittal;


    -- ************************************************************************
    --  FUNCTION:       createdeposit
    --
    --  PARAMETERS:
    --      a_TransmittalType       Check, Credit
    -- ************************************************************************
    FUNCTION createdeposit(a_objectlist   IN     api.udt_objectlist,
                           a_paymentmethod IN    VARCHAR2,
                           a_depositdate  IN     DATE DEFAULT SYSDATE,
                           a_sqlerrm         OUT VARCHAR2,
                           a_backtrace       OUT VARCHAR2)
        RETURN NUMBER
    IS
        t_depositdefid           api.pkg_definition.udt_id;
        t_depositobjectid        api.pkg_definition.udt_id;
        t_processid              api.pkg_definition.udt_id;

        t_paymentamount          NUMBER := 0;
        t_paymentcount           NUMBER := 0;
        t_count                  NUMBER;

        t_endpointtransmittal    api.pkg_definition.udt_id
                                     := api.pkg_configquery.endpointidforname('j_deposit', 'Transmittal');
        t_endpointpaymentbatch   api.pkg_definition.udt_id
                                     := api.pkg_configquery.endpointidforname('j_deposit', 'PaymentBatch');
    BEGIN
        -- *****************************************************************
        -- Create Deposit Job
        -- *****************************************************************
        api.pkg_logicaltransactionupdate.resettransaction;
        ROLLBACK;

        t_depositdefid      := api.pkg_configquery.objectdefidforname('j_Deposit');
        t_depositobjectid   := api.pkg_objectupdate.new(t_depositdefid);

        api.pkg_columnupdate.setvalue(t_depositobjectid, 'DepositType', a_paymentmethod);
        api.pkg_columnupdate.setvalue(t_depositobjectid, 'DepositNumber', TO_CHAR(SYSDATE, 'YYMMDDHH24MISS'));
        api.pkg_columnupdate.setvalue(t_depositobjectid, 'DepositDate', NVL(a_depositdate, SYSDATE));
        api.pkg_columnupdate.setvalue(t_depositobjectid, 'DepositAmount', 1);
        api.pkg_columnupdate.setvalue(t_depositobjectid, 'CheckCount', 1);
        api.pkg_columnupdate.setvalue(t_depositobjectid, 'AccountNumber', '1111');

        api.pkg_logicaltransactionupdate.endtransaction;
        COMMIT;

        SELECT COUNT(1)
          INTO t_count
          FROM api.relationships rn
         WHERE rn.fromobjectid = t_depositobjectid
           AND rn.endpointid IN
                   (api.pkg_configquery.endpointidforname('j_deposit', 'Transmittal'),
                    api.pkg_configquery.endpointidforname('j_deposit', 'PaymentBatch'));

        -- *****************************************************************
        -- Removed unwanted transmittals
        -- *****************************************************************
        FOR rec
            IN (SELECT relationshipid, rn.toobjectid transmittal
                  FROM api.relationships rn
                 WHERE rn.endpointid IN
                           (api.pkg_configquery.endpointidforname('j_deposit', 'Transmittal'),
                            api.pkg_configquery.endpointidforname('j_deposit', 'PaymentBatch'))
                   AND rn.fromobjectid = t_depositobjectid
                   AND rn.toobjectid NOT IN (SELECT objectid FROM TABLE(a_objectlist)))
        LOOP
            api.pkg_relationshipupdate.remove(rec.relationshipid);

            api.pkg_logicaltransactionupdate.endtransaction;
            COMMIT;
            DBMS_OUTPUT.put_line(   'Removing transmittal: '
                                 || rec.transmittal);
        END LOOP;

        SELECT COUNT(1)
          INTO t_count
          FROM api.relationships rn
         WHERE rn.fromobjectid = t_depositobjectid
           AND rn.endpointid IN
                   (api.pkg_configquery.endpointidforname('j_deposit', 'Transmittal'),
                    api.pkg_configquery.endpointidforname('j_deposit', 'PaymentBatch'));

        IF (t_count > 0) THEN
            SELECT SUM(
                       CASE
                           WHEN r.endpointid = t_endpointtransmittal THEN
                               api.pkg_columnquery.numericvalue(r.toobjectid, 'PaymentTotalAmount')
                           ELSE
                               api.pkg_columnquery.numericvalue(r.toobjectid, 'BatchAmount')
                       END),
                   SUM(
                       CASE
                           WHEN r.endpointid = t_endpointtransmittal THEN
                               api.pkg_columnquery.numericvalue(r.toobjectid, 'PaymentCount')
                           ELSE
                               api.pkg_columnquery.numericvalue(r.toobjectid, 'CheckCount')
                       END)
              INTO t_paymentamount, t_paymentcount
              FROM api.relationships r
             WHERE r.fromobjectid = t_depositobjectid
               AND r.endpointid IN (t_endpointtransmittal, t_endpointpaymentbatch);

            IF (t_paymentcount = 0) THEN
                -- remove transmittal object
                api.pkg_objectupdate.remove(t_depositobjectid);

                api.pkg_logicaltransactionupdate.endtransaction;
                COMMIT;
                t_depositobjectid   := NULL;
            ELSE
                api.pkg_columnupdate.setvalue(t_depositobjectid, 'DepositAmount', t_paymentamount);
                api.pkg_columnupdate.setvalue(t_depositobjectid, 'CheckCount', t_paymentcount);

                api.pkg_logicaltransactionupdate.endtransaction;
                COMMIT;

                -- *****************************************************************
                -- Find and process Prepare Deposit
                -- *****************************************************************
                -- get processes
                SELECT processid
                  INTO t_processid
                  FROM api.processes p
                 WHERE p.jobid = t_depositobjectid
                   AND p.processtypeid = api.pkg_objectdefquery.idforname('p_PrepareDeposit');
            --                api.pkg_logicaltransactionupdate.starttransaction;
            --                api.pkg_columnupdate.setvalue(t_processid, 'Outcome', 'Deposit');
            --                api.pkg_logicaltransactionupdate.endtransaction;
            --                COMMIT;
            END IF;
        ELSE
            api.pkg_objectupdate.remove(t_depositobjectid);
            api.pkg_logicaltransactionupdate.endtransaction;
            COMMIT;
            t_depositobjectid   := NULL;
        END IF;

        RETURN t_depositobjectid;
    EXCEPTION
        WHEN OTHERS THEN
            a_sqlerrm     := SUBSTR(SQLERRM, 1, 3990);
            a_backtrace   := SUBSTR(DBMS_UTILITY.format_error_backtrace, 1, 3990);

            api.pkg_logicaltransactionupdate.resettransaction;
            ROLLBACK;

            --            IF (t_depositobjectid IS NOT NULL) THEN
            --                api.pkg_objectupdate.remove(t_depositobjectid);
            --
            --                api.pkg_logicaltransactionupdate.endtransaction;
            --                COMMIT;
            --                t_depositobjectid   := NULL;
            --            END IF;

            RETURN -1;
    END createdeposit;

    PROCEDURE checkissued
    IS
        t_count1   NUMBER := 0;
    BEGIN
        FOR lts IN (SELECT api.pkg_columnquery.numericvalue(p.feeobjid, 'JobId')               jobid,
                           p.licensetypecode,
                           ltc.color,
                           TRUNC(api.pkg_columnquery.datevalue(p.feeobjid, 'TransactionDate')) transactiondate
                      FROM bizmod_api.e_payments_t p
                           JOIN query.o_licensetypecategory ltc
                           ON (ltc.licensetypecode = p.licensetypecode)
                     WHERE p.issued IS NULL)
        LOOP
            -- look if license has been issued for this renewal activity
            FOR b
                IN (SELECT *
                      FROM (SELECT  /*+ materialize */
                                   api.pkg_columnquery.datevalue(x.licensebatchjobid, 'completeddate')
                                       completeddate,
                                   api.pkg_columnquery.VALUE(x.licensebatchjobid, 'color')
                                       color,
                                   api.pkg_columnquery.VALUE(x.licensebatchjobid, 'BatchType')
                                       batchtype,
                                   api.pkg_columnquery.VALUE(x.licensebatchjobid, 'StatusDescription')
                                       statusdescription
                              FROM sitespecific.licbatchlictype_xref_t x
                             WHERE x.licensetypejobid = lts.jobid) b
                     WHERE b.batchtype = 'PRODUCE LICENSES'
                       AND TRUNC(b.completeddate) >= TRUNC(lts.transactiondate)
                       AND b.color = lts.color
                       AND b.statusdescription = 'Complete')
            LOOP
                UPDATE bizmod_api.e_payments_t p
                   SET p.issued   = 'Y'
                 WHERE api.pkg_columnquery.numericvalue(p.feeobjid, 'JobId') = lts.jobid
                   AND p.licensetypecode = lts.licensetypecode
                   LOG ERRORS INTO bizmod_api.err$_e_payments_t
                           ('UPDATE')
                           REJECT LIMIT UNLIMITED;

                t_count1   := t_count1 + SQL%ROWCOUNT;
                COMMIT;
            END LOOP;
        END LOOP;
    END checkissued;


    PROCEDURE processpayments(a_paymentdate IN DATE DEFAULT SYSDATE - 1, a_paymentonly IN VARCHAR2 DEFAULT 'N')
    IS
        CURSOR cur_paymentobjectid(p_paymentmethod IN VARCHAR2)
        IS
            (SELECT api.udt_object(p.paymentobjectid) paymentobjectid
               FROM (SELECT DISTINCT p2.paymentobjectid
                       FROM bizmod_api.e_payments_t p2
                      WHERE p2.paymentmethod = p_paymentmethod
                        AND NVL(p2.paymentobjectid, 0) > 0
                        AND p2.transmittalbatch IS NULL) p);

        CURSOR t_transmittal(p_paymentmethod IN VARCHAR2)
        IS
            (SELECT api.udt_object(transmittalbatch) objectid
               FROM (SELECT DISTINCT p2.transmittalbatch
                       FROM bizmod_api.e_payments_t p2
                      WHERE p2.paymentmethod = p_paymentmethod
                        AND NVL(p2.transmittalbatch, 0) > 0
                        AND p2.depositbatchid IS NULL) p);
        t_crlf               VARCHAR2(20)
                                 :=    CHR(13)
                                    || CHR(10);  --'<br>';
        t_tab                VARCHAR2(20) := CHR(9);  --'&emsp;';
        t_processid          NUMBER := abc.e_payment_seq.NEXTVAL();
        t_processdate        DATE := SYSDATE;
        t_sqlerrm            VARCHAR2(4000);
        t_backtrace          VARCHAR2(4000);
        t_id                 api.pkg_definition.udt_id;
        t_licensecount       NUMBER := 0;
        t_transmittalcount   NUMBER := 0;
        t_depositcount       NUMBER := 0;
        t_errors             VARCHAR2(1);
        t_depositdate        DATE := SYSDATE;

        t_objectlist         api.udt_objectlist;
        t_amountpaid         NUMBER;
        t_paymentmethod      VARCHAR2(4000);
        t_returnvalue        NUMBER;
        t_report             VARCHAR2(4000)
                                 :=    t_crlf
                                    || 'Process Report '
                                    || t_crlf;
        t_first              BOOLEAN := TRUE;
        t_to                 VARCHAR2(4000);
        t_from               VARCHAR2(512);
        t_cc                 VARCHAR2(4000);
        t_bcc                VARCHAR2(4000);
    BEGIN
        -- ********************************************************************
        FOR rec IN (  SELECT paymentmethod,
                             licensenumber,
                             confirmationid,
                             payeename,
                             datepaid,
                             SUM(amountpaid)                                                     payamount,
                             LISTAGG(licensetypecode, ',') WITHIN GROUP (ORDER BY licensetypecode) licensetypecodes
                        FROM bizmod_api.e_payments_t p
                       WHERE p.paymentobjectid IS NULL
                         AND TRUNC(p.datepaid) <= TRUNC(a_paymentdate)
                    GROUP BY paymentmethod,
                             licensenumber,
                             confirmationid,
                             payeename,
                             datepaid)
        LOOP
            DBMS_OUTPUT.put_line(   'lic#: '
                                 || rec.licensenumber
                                 || '  amount: '
                                 || rec.payamount);
            t_id             :=
                payfees(a_paymentmethod => rec.paymentmethod,
                        a_licensenumber => rec.licensenumber,
                        a_licensetypecodes => rec.licensetypecodes,
                        a_payamount => rec.payamount,
                        a_payeereference => rec.confirmationid,
                        a_payeename => rec.payeename,
                        a_paymentdate => rec.datepaid,
                        a_sqlerrm   => t_sqlerrm,
                        a_backtrace => t_backtrace);

            UPDATE bizmod_api.e_payments_t p
               SET p.paymentobjectid   = CASE WHEN p.paymentobjectid IS NULL THEN t_id ELSE p.paymentobjectid END,
                   p.processid         = t_processid,
                   p.processdate       = t_processdate
             WHERE p.licensenumber = rec.licensenumber
               AND p.confirmationid = rec.confirmationid
               AND NVL(p.paymentobjectid, 0) = 0;

            t_licensecount   := t_licensecount + 1;

            IF (t_sqlerrm IS NOT NULL) THEN
                INSERT INTO bizmod_api.err$_e_payments_t ep(ep.ora_err_mesg$,
                                                            ep.backtrace,
                                                            ep.licensenumber,
                                                            ep.seq)
                     VALUES (t_sqlerrm,
                             t_backtrace,
                             rec.licensenumber,
                             t_processid);

                t_errors   := 'Y';
            END IF;

            COMMIT;
        END LOOP;

        IF (a_paymentonly = 'N') THEN
            -- ********************************************************************
            -- ************************************************************
            -- 10/12/2021 TJL   Update added
            -- Check for payments being removed from original transmittal and
            --   updating payment record with new transmittal batch id or
            --   NULL if not assigned to another transmittal batch
            -- ************************************************************
            UPDATE bizmod_api.e_payments_t p
               SET p.transmittalbatch   =
                       (SELECT rn.fromobjectid
                          FROM api.relationships rn
                         WHERE rn.endpointid = api.pkg_configquery.endpointidforname('j_Transmittal', 'Payment')
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
                                           api.pkg_configquery.endpointidforname('j_Transmittal', 'Payment')
                                       AND rn.fromobjectid = p.transmittalbatch
                                       AND rn.toobjectid = p.paymentobjectid));

            -- ************************************************************
            -- 10/12/2021 TJL   Update added
            -- Update payment record for payments manually added to transmittal
            --    batch.
            -- ************************************************************
            UPDATE bizmod_api.e_payments_t p
               SET p.transmittalbatch   =
                       (SELECT rn.fromobjectid
                          FROM api.relationships rn
                         WHERE rn.endpointid = api.pkg_configquery.endpointidforname('j_Transmittal', 'Payment')
                           AND rn.toobjectid = p.paymentobjectid)
             WHERE p.paymentobjectid IN (SELECT DISTINCT p.paymentobjectid
                                           FROM bizmod_api.e_payments_t p
                                          WHERE p.transmittalbatch IS NULL)
               AND EXISTS
                       (SELECT 1
                          FROM api.relationships rn
                         WHERE rn.endpointid = api.pkg_configquery.endpointidforname('j_Transmittal', 'Payment')
                           AND rn.toobjectid = p.paymentobjectid);

            -- ************************************************************
            --  Update transmittal completion date for transmittal manually completed
            -- ************************************************************
            UPDATE bizmod_api.e_payments_t p
               SET p.transmittalbatchdate   = api.pkg_columnquery.datevalue(p.transmittalbatch, 'CompletedDate')
             WHERE p.transmittalbatch IS NOT NULL
               AND p.transmittalbatchdate IS NULL;

            COMMIT;

            -- ************************************************************
            --  Create Transmittals
            -- ************************************************************
            -- loop through different payment methods
            FOR pm IN (SELECT DISTINCT p.paymentmethod
                         FROM bizmod_api.e_payments_t p
                        WHERE p.transmittalbatch IS NULL)
            LOOP
                OPEN cur_paymentobjectid(pm.paymentmethod);

                LOOP
                    FETCH cur_paymentobjectid BULK COLLECT INTO t_objectlist LIMIT gc_transmittallimit;

                    EXIT WHEN t_objectlist.COUNT = 0;

                    t_transmittalcount   := t_transmittalcount + 1;
                    DBMS_OUTPUT.put_line(   'Transmittal Payments: '
                                         || t_objectlist.COUNT
                                         || '  Type: '
                                         || pm.paymentmethod);

                    -- create transmital for this block of payments
                    t_returnvalue        :=
                        createtransmittal(a_paymentobjectlist => t_objectlist,
                                          a_paymentmethod => pm.paymentmethod,
                                          a_sqlerrm   => t_sqlerrm,
                                          a_backtrace => t_backtrace);

                    FOR pm
                        IN (SELECT r.toobjectid transmittalobjectid, t.objectid paymentobjectid
                              FROM TABLE(t_objectlist) t
                                   LEFT OUTER JOIN api.relationships r
                                   ON r.endpointid =
                                      api.pkg_configquery.endpointidforname('o_Payment', 'Transmittal')
                                  AND r.fromobjectid = t.objectid)
                    LOOP
                        UPDATE bizmod_api.e_payments_t p
                           SET p.transmittalbatch   = NVL(pm.transmittalobjectid, -1),
                               p.transmittalbatchdate   =
                                   api.pkg_columnquery.datevalue(pm.transmittalobjectid, 'CompletedDate')
                         WHERE p.paymentobjectid = pm.paymentobjectid;

                        IF (t_sqlerrm IS NOT NULL) THEN
                            INSERT INTO bizmod_api.err$_e_payments_t ep(ep.ora_err_mesg$,
                                                                        ep.backtrace,
                                                                        ep.transmittalbatch,
                                                                        ep.seq)
                                 VALUES (t_sqlerrm,
                                         t_backtrace,
                                         -1,
                                         t_processid);

                            t_errors   := 'Y';
                        END IF;
                    END LOOP;

                    COMMIT;
                END LOOP;

                CLOSE cur_paymentobjectid;
            END LOOP;


            -- ************************************************************
            --  Get Deposit batch information for deposit batches that are
            --    manually created for completed transmittal batches.
            -- ************************************************************
            UPDATE bizmod_api.e_payments_t p
               SET (p.depositbatchid, p.depositbatchdate, p.depositstatus)   =
                       (SELECT DISTINCT
                               r.toobjectid,
                               api.pkg_columnquery.datevalue(r.toobjectid, 'CreatedDate'),
                               api.pkg_columnquery.VALUE(r.toobjectid, 'StatusName')
                          FROM api.relationships r
                         WHERE r.endpointid = api.pkg_configquery.endpointidforname('j_transmittal', 'Deposit')
                           AND r.fromobjectid = p.transmittalbatch)
             WHERE p.depositstatus IS NULL
               AND p.transmittalbatchdate IS NOT NULL;


            -- ************************************************************
            --  Update Deposit status of deposits completed
            -- ************************************************************
            UPDATE bizmod_api.e_payments_t p
               SET p.depositstatus   = api.pkg_columnquery.VALUE(p.depositbatchid, 'StatusName')
             WHERE NVL(p.depositstatus, 'X') = 'PREPAR';

            COMMIT;

            /*  Removed creating deposits by request from Accounting
            -- ************************************************************
            --  Create Deposits
            -- ************************************************************
            FOR pm IN (SELECT DISTINCT p.paymentmethod
                         FROM bizmod_api.e_payments_t p
                        WHERE p.transmittalbatch IS NOT NULL)
            LOOP
                OPEN t_transmittal(pm.paymentmethod);

                LOOP
                    FETCH t_transmittal BULK COLLECT INTO t_objectlist LIMIT gc_depositlimit;

                    EXIT WHEN t_objectlist.COUNT = 0;
                    t_depositcount   := t_depositcount + 1;

                    -- create deposit for this block of transmittals
                    t_returnvalue    :=
                        createdeposit(a_objectlist => t_objectlist,
                                      a_paymentmethod => pm.paymentmethod,
                                      a_depositdate => t_depositdate,
                                      a_sqlerrm   => t_sqlerrm,
                                      a_backtrace => t_backtrace);

                    FOR tm IN (SELECT r.toobjectid depositobjectid, t.objectid transmittalobjectid
                                 FROM TABLE(t_objectlist) t
                                      LEFT OUTER JOIN api.relationships r
                                      ON r.endpointid = api.pkg_configquery.endpointidforname('j_transmittal', 'Deposit')
                                     AND r.fromobjectid = t.objectid)
                    LOOP
                        UPDATE bizmod_api.e_payments_t p
                           SET p.depositbatchid     = NVL(tm.depositobjectid, -1),
                               p.depositbatchdate   = api.pkg_columnquery.datevalue(tm.depositobjectid, 'CreatedDate'),
                               p.depositstatus      = api.pkg_columnquery.VALUE(tm.depositobjectid, 'StatusName')
                         WHERE p.transmittalbatch = tm.transmittalobjectid;

                        IF (t_sqlerrm IS NOT NULL) THEN
                            INSERT INTO bizmod_api.err$_e_payments_t ep(ep.ora_err_mesg$,
                                                                        ep.backtrace,
                                                                        ep.depositbatchid,
                                                                        ep.seq)
                                 VALUES (t_sqlerrm,
                                         t_backtrace,
                                         -1,
                                         t_processid);

                            t_errors   := 'Y';
                        END IF;
                    END LOOP;

                    COMMIT;
                END LOOP;


                CLOSE t_transmittal;
            END LOOP;
            */

            -- ********************************************************************
            --  Check for License Issued
            -- ********************************************************************
            checkissued;

            -- ********************************************************************
            -- Log processed information
            -- ********************************************************************
            INSERT INTO abc.e_process_log_t l(l.processid,
                                              l.processdate,
                                              l.licensespaid,
                                              l.transmittals,
                                              l.deposits,
                                              l.processerrors)
                 VALUES (t_processid,
                         t_processdate,
                         t_licensecount,
                         t_transmittalcount,
                         t_depositcount,
                         t_errors);

            COMMIT;

            DBMS_OUTPUT.put_line(   'Licenses Processed: '
                                 || t_licensecount
                                 || '  process id '
                                 || t_processid);

            -- ********************************************************************
            -- Send email status information
            -- ********************************************************************

            SELECT SUM(p.amountpaid)
              INTO t_amountpaid
              FROM bizmod_api.e_payments_t p
             WHERE p.processid = t_processid
               AND p.paymentobjectid > 0;

            -- create results
            t_report   :=
                   t_report
                || t_crlf
                || 'Process Results for Process Id: '
                || t_tab
                || t_processid;
            t_report   :=
                   t_report
                || t_crlf
                || 'Licenses Paid:      '
                || t_tab
                || t_licensecount
                || t_tab
                || TO_CHAR(t_amountpaid, '999,999,990.00');
            t_report   :=
                   t_report
                || t_crlf
                || 'Transmittal Batches:'
                || t_tab
                || t_transmittalcount;
            t_report   :=
                   t_report
                || t_crlf
                || 'Deposit Batches:    '
                || t_tab
                || t_depositcount;
            t_report   :=
                   t_report
                || t_crlf
                || 'Processing Errors:  '
                || t_tab
                || CASE NVL(t_errors, 'N') WHEN 'N' THEN 'No' ELSE 'Yes' END;
            t_report   :=
                   t_report
                || t_crlf;

            FOR rec
                IN (  SELECT DISTINCT
                             line,
                             rectype,
                             CASE rectype WHEN 'Deposit' THEN info.depositbatchid ELSE NULL END
                                 depositbatchid,
                             CASE rectype WHEN 'Transmittal' THEN info.transmittalbatch ELSE NULL END
                                 transmittalbatch,
                             (SELECT COUNT(DISTINCT p.paymentobjectid)
                                FROM bizmod_api.e_payments_t p
                               WHERE p.depositbatchid =
                                     CASE rectype WHEN 'Deposit' THEN info.depositbatchid ELSE NULL END
                                  OR p.transmittalbatch =
                                     CASE rectype WHEN 'Transmittal' THEN info.transmittalbatch ELSE NULL END)
                                 payments,
                             (SELECT SUM(p.amountpaid)
                                FROM bizmod_api.e_payments_t p
                               WHERE p.depositbatchid =
                                     CASE rectype WHEN 'Deposit' THEN info.depositbatchid ELSE NULL END
                                  OR p.transmittalbatch =
                                     CASE rectype WHEN 'Transmittal' THEN info.transmittalbatch ELSE NULL END)
                                 amountpaid
                        FROM (WITH
                                  lst
                                  AS
                                      (  SELECT  /*+ materialize */
                                                DISTINCT
                                                p.depositbatchid,
                                                p.transmittalbatch,
                                                LAG(p.transmittalbatch, 1, NULL)
                                                    OVER(PARTITION BY p.depositbatchid ORDER BY p.transmittalbatch)
                                                    previd
                                           FROM bizmod_api.e_payments_t p
                                          WHERE p.processid = t_processid
                                            AND p.depositbatchid IS NOT NULL
                                       ORDER BY p.depositbatchid, previd NULLS FIRST, p.transmittalbatch)
                              SELECT ROWNUM line, l.*
                                FROM (SELECT DISTINCT 'Deposit' rectype, lst.depositbatchid, lst.transmittalbatch
                                        FROM lst
                                       WHERE previd IS NULL
                                      UNION ALL
                                      SELECT DISTINCT 'Transmittal' rectype, lst.depositbatchid, lst.transmittalbatch
                                        FROM lst
                                      ORDER BY depositbatchid, rectype, transmittalbatch) l) info
                             JOIN bizmod_api.e_payments_t p
                             ON p.depositbatchid = info.depositbatchid
                            AND p.transmittalbatch = info.transmittalbatch
                    ORDER BY line)
            LOOP
                IF (t_first) THEN
                    t_report   :=
                           t_report
                        || t_crlf
                        || t_tab
                        || t_tab
                        || t_tab
                        || 'Batch Number  Payments'
                        || t_tab
                        || '    Batch Total'
                        || t_crlf;
                    t_first   := FALSE;
                ELSE
                    IF (rec.rectype = 'Deposit') THEN
                        t_report   :=
                               t_report
                            || t_crlf;
                    END IF;
                END IF;

                t_report   :=
                       t_report
                    || CASE rec.rectype
                           WHEN 'Deposit' THEN
                                  'Deposit Batch'
                               || t_tab
                               || t_tab
                               || TO_CHAR(rec.depositbatchid, '99999999990')
                           ELSE
                               CASE rec.rectype
                                   WHEN 'Transmittal' THEN
                                          t_tab
                                       || 'Transmittal'
                                       || t_tab
                                       || TO_CHAR(rec.transmittalbatch, '99999999990')
                                   ELSE
                                       NULL
                               END
                       END
                    || LPAD(rec.payments, 21, ' ')
                    || '          '
                    || TO_CHAR(rec.amountpaid, '999,999,990.00')
                    || t_crlf;
            END LOOP;

            DBMS_OUTPUT.put_line(t_report);

            -- Get email address information
            FOR rec IN (SELECT ep.parametername, ep.parametervalue
                          FROM abc.email_parameters ep
                         WHERE ep.app = 'EPAYMENT')
            LOOP
                CASE rec.parametername
                    WHEN 'TO' THEN
                        t_to   := rec.parametervalue;
                    WHEN 'FROM' THEN
                        t_from   := rec.parametervalue;
                    WHEN 'CC' THEN
                        t_cc   := rec.parametervalue;
                    WHEN 'BCC' THEN
                        t_bcc   := rec.parametervalue;
                    ELSE
                        NULL;
                END CASE;
            END LOOP;

            IF (t_from IS NOT NULL) THEN
                sitespecific.pkg_tlemail.sendemail(p_fromaddress => t_from,
                                                   p_toaddress => t_to,
                                                   p_cc        => t_cc,
                                                   p_bcc       => t_bcc,
                                                   p_subject   => 'ePayments Daily Completed Process Reports',
                                                   p_body      => t_report,
                                                   p_mimetype  => 'text/plain');
            END IF;
        END IF;
    END processpayments;
END;
/
