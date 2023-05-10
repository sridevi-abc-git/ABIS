CREATE OR REPLACE PACKAGE BODY SITESPECIFIC."PKG_FEES"
-- ****************************************************************************
-- File:        pkg_fees.pkb
-- Author:      TREVOR.HAMM
--
-- $Rev: 411 $
-- $Date: 2020-02-24 09:55:14 -0800 (Mon, 24 Feb 2020) $
-- Last Changed By:  $Author: TLord $
--
-- Purpose : Online fee payment
--
-- History:
-------------------------------------------------------------------------------
--    Date         Ticket     Comment
--  01/21/2007 TH           Initial Package Created
--  02/14/2018 NW  WO 14464 Per to Per Fees are not charged per room
--  02/27/2018 TJL WO 14321 Added code so Intercounry Transfer will create missing
--                            fee in procedure applicationfeecalc().
--  05/23/2018 TJL WO  8517 Change how expiration date is generated for seasonals in
--                            procedure createrenewalfees().
--                          Added code to prevent regression script from causing an
--                            error to be thrown in procedure initialize().
--                          Added code to createltpaymentstatus() for handling the
--                            processing of seasonal license types for earning the
--                            renewal fees.
--  06/26/2018 SS  WO 15567
--                    15604 ORI and ANN fees are missing when I am creating
--                            a Change Application --> Add Primary License Type
--  07/03/2018 TJL WO 15613 Modified procedure licensefeecalc to count number of
--                            pending secondaries instead of checking status field
--                            on the licensetypejobid.
--  10/09/2018 PK  WO 16219 Modified procedure licensefeecalc to revert back Tim's changes
--  12/06/2018 TJL WO 16775 Added NVL Check in getltfeeamount() for additional gallons
--                            get secondary amount
--  12/10/2018 TJL WO 16791 Added test for 0 - 3 months for License type 59 and 60
--         which do not have fees for 0-3 months. Type 59 and 60
--         will use 3-6 months fees schedule for 0 - 3 months.
--  12/11/2018 TJL WO 16777 Added ORI fee activity to be adjusted by ltcount in
--                            getltfeeamount procedure.
--  12/18/2018 TJL WO 16783 Added type code 62 to generate an ORI Fee in procedure
--                            applicationfeecalc
-- 12/20/2018 PK WO 16989  Added type code to make type 68 work when added as secondary on new LT 88
-- 01/08/2019 TJL WO 16435 changed how seasonal Ready to Issue date is created in createrenewalfees,
--                            also added updating Ready to Issue date in the
--                            dup relationship object in procedure processrecrievepayment
--  03/29/2019 TJL WO 17566 Adding Tiers for Catering and Event Authorization
--  04/01/2019 TJL WO 17620 Adding support for single application fee for multiple master
--                            license types.
--  04/15/2018 TJL WO 17497 SLOWNESS WHEN ISSUING STK/MBR TRANSFERS
--  05/21/2019 PK  WO 18109 IPTR Fee Change
--  05/24/2019 TJL WO 17565 check for transfer application adding another license type
-- 07/17/2019  PK  WO 18109 Change IPT/IPTR fee from being tied to a license type and to make it an Application fee. To make this change
--                          I made changes in stage to point process to create simple fee process so both create IPT and Create IPTR procdures are depricated as of today.
--  08/01/2019 TJL WO 18697   Change Issue Date from using 'EstimatedIssueDate' to
--                            'CopiesMailed' Date in applicationfeecalc procedure
--  09/17/2019 TJL WO 19066  Removed the test for license type code from the
--                             setting of the IsMaster flag in the Create Manual
--                             fee procedure. This allows the IsMaster flag be
--                             set on any fees not associated with a license type.
--  09/28/2019 SSu    Adding New License Type 99
--  11/18/2019 TJL WO 19788  Added corrections in applicationfeecalc for generating
--        DOR fees on Change Application and only processing
--        Pending license types.
--  12/30/2019 TJL WO 20134  In applicationfeecalc procedure,  added test for exchange
--                              only to not create DOR fee
--  02/20/2020 TJL WO 3838   Limited how far back to look for balance due amount
--                              on licensetypes being renewed.
--                              procedure processreceivepayment(a_jobid udt_id)
-- 02/24/2020 PK WO 20565     The licensees that paid timely prior to their expiration date
--                             to receive their renewal license prior to the expiration date.
--                             Changed ready to issue date logic to get paymentdateplus10 date
-- 05/29/2020 TJL WO 8924   Modified createrenewalfees procedure to charge penalties on fees that
--                           have been paid when all fees for a license renewal were NOT paid
-- 12/28/2020 TJL WO 23630  Added the transmittal relationship to payment object add for payment
--                            transfer.
-- 04/15/2021 TJL WO 24949  Added validation to paymentsvoid process to see if payment is in
--                            a payment batch
-- 06/01/2021 TJL WO 25342  paymentsvoid process, Back out to allow accounting to void payment
--                            after transmittal or Payment batch have been completed, added test
--                            if already deposited.
-- 08/05/2021 TJL WO 25899  Removed 10 day wait time for credit card transactions (processreceivepayment)
-- 01/21/2022 PK  WO 27037  LSP ABIS license renewal payment error with previous due fee line
--                          Added t_transactiondate and additional logic of date to bring total owing to PROCEDURE initialize
-- 12/28/2022 PK WO 30274   Added code to make type 68 work when added as secondary on new LT 90
-------------------------------------------------------------------------------

IS
    /*-------------------------------------------------------------------------
    * Initialize() - Public
    *------------------------------------------------------------------------*/
    PROCEDURE initialize(a_objectid udt_id, a_asofdate DATE, a_fromobjectid IN OUT udt_id)
    IS
        t_destendpointid         udt_id;
        t_destobjectdefid        udt_id;
        t_fee                    PLS_INTEGER;
        t_fees                   udt_idlist;
        t_fromendpointid         udt_id;
        t_fromobjectdefid        udt_id;
        t_relid                  udt_id;
        t_methodendpointid       NUMBER;
        t_bckid                  udt_id;
        t_fromobjectendpointid   udt_id;
        t_totalowing             VARCHAR2(18);
        t_transactiondate        DATE;
    BEGIN
        --Get Config id's
        IF a_fromobjectid IS NULL THEN
            -- *************************************************************************
            -- 08/05/2021 TJL WO 25899
            -- The following code block to prevent exceptions being thrown when
            -- creating propose payment object. Object id is not passed to this procedure.
            -- *************************************************************************
            BEGIN
                EXECUTE IMMEDIATE ' begin select objectid into :a from abc.tmp_jobid; delete abc.tmp_jobid; end;'
                    USING OUT a_fromobjectid;
            EXCEPTION
                WHEN OTHERS THEN
                    NULL;
            END;

            IF a_fromobjectid IS NULL THEN
                api.pkg_errors.raiseerror(-20001, 'a_FromObjectId must contain a valid ObjectId.');
            END IF;
        END IF;

        -- *************************************************************************

        BEGIN
            SELECT a.objectdefid
              INTO t_fromobjectdefid
              FROM api.objects a
             WHERE a.objectid = a_fromobjectid;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                api.pkg_errors.raiseerror(-20001,
                                             'Cannot determine ObjectDefId for From Object ['
                                          || a_fromobjectid
                                          || '].');
        END;

        BEGIN
            SELECT a.objectdefid
              INTO t_destobjectdefid
              FROM api.objects a
             WHERE a.objectid = a_objectid;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                api.pkg_errors.raiseerror(-20001,
                                             'Cannot determine ObjectDefId for Proposed Payment Job ['
                                          || a_objectid
                                          || '].');
        END;

        t_fromendpointid         := api.pkg_configquery.endpointidforname(t_fromobjectdefid, 'Fee');

        IF t_fromendpointid IS NULL THEN
            api.pkg_errors.raiseerror(-20001,
                                         'From object ['
                                      || a_fromobjectid
                                      || '] does not have a relationship named ''Fee''.');
        END IF;

        t_destendpointid         := api.pkg_configquery.endpointidforname(t_destobjectdefid, 'Fee');

        IF t_destendpointid IS NULL THEN
            api.pkg_errors.raiseerror(-20001,
                                         'Proposed Payment job ['
                                      || a_objectid
                                      || '] does not have a relationship named ''Fee''.');
        END IF;

        --Create a relationship to all the Fees on a_FromObjectId
        t_fees                   := api.pkg_objectquery.relatedobjects(a_fromobjectid, t_fromendpointid);

        FOR t_fee IN 1 .. t_fees.COUNT
        LOOP
            t_totalowing   := api.pkg_columnquery.VALUE(t_fees(t_fee), 'TotalOwing');
             t_transactiondate := api.pkg_columnquery.datevalue(t_fees(t_fee), 'TransactionDate'); -- Added by pawan -- 01/21/2022 PK  WO 27037

            IF t_totalowing > 0 and t_transactiondate >  LAST_DAY( ADD_MONTHS(SYSDATE , - 24 ) ) THEN  --added by -- 01/21/2022 PK  WO 27037
                --Create the relationship To the Fees that have balance grater than 0
                --Default the amount to pay to the amount owing on the fee if the amount to pay is greater than or equal to 0
                t_relid   := api.pkg_relationshipupdate.new(t_destendpointid, a_objectid, t_fees(t_fee));
                api.pkg_columnupdate.setvalue(t_relid, 'AmountToPay', t_totalowing);
            END IF;
        END LOOP;

        --This selects the ObjectId from the BCK Payment Method into the BCKId variable. This is NOT part of the Fees and Payments Component - this is ABC project specific.
        t_bckid                  := api.pkg_simplesearch.objectbyindex('o_PaymentMethod', 'Code', 'BCK');
        --This gets the Payment Method End Point Id. This is NOT part of the Fees and ' Component - this is ABC project specific.
        t_methodendpointid       := api.pkg_configquery.endpointidforname(t_destobjectdefid, 'PaymentMethod');
        --Create relationship to the Business Check Payment Method. This is NOT part of the Fees and Payments Component - this is ABC project specific.
        t_relid                  := api.pkg_relationshipupdate.new(t_methodendpointid, a_objectid, t_bckid);
        --Find the end point id for the job that the Proposed Payment came from. This is NOT part of the Fees and Payments Component - this is ABC project specific.
        t_fromobjectendpointid   := api.pkg_configquery.endpointidforname(t_fromobjectdefid, 'ProposedPayment');
        --Create relationship to the job that the proposed payment came from. This is NOT part of the Fees and Payments Component - this is ABC project specific.
        t_relid                  :=
            api.pkg_relationshipupdate.new(t_fromobjectendpointid, a_fromobjectid, a_objectid);
    END initialize;

    /*-------------------------------------------------------------------------
    --CreateRecPOICPaymentProcess() -- PRIVATE
    -------------------------------------------------------------------------*/
    PROCEDURE createrecpoicpaymentprocess(a_jobid udt_id, a_asofdate DATE, a_feeids udt_idlist)
    IS
        t_poicprocesstype     VARCHAR(25);
        t_poicprocessid       udt_id;
        t_totalpoicowing      NUMBER;
        t_sumtotalpoicowing   NUMBER;
    BEGIN
        t_poicprocesstype   := api.pkg_configquery.objectdefidforname('p_ReceivePOICPayment');

        FOR c IN 1 .. a_feeids.COUNT
        LOOP
            BEGIN
                -- RyanL: Changed the select clause to be a subselect for performance (PIP Task 8.5)
                SELECT (  f.amount
                        + NVL((SELECT SUM(amount)
                                 FROM api.feetransactions ft
                                WHERE ft.feeid = f.feeid),
                              0))
                           totalowing
                  INTO t_totalpoicowing
                  FROM api.fees f
                       JOIN sitespecific.feeschedule_t fs
                       ON fs.objectid = sitespecific.pkg_fees.getlicfeeschedulobjid(f.feeid)
                 WHERE f.feeid = a_feeids(c)
                   AND fs.feeactivity = 'POIC';

                IF t_sumtotalpoicowing IS NULL THEN
                    t_sumtotalpoicowing   := 0;
                END IF;

                t_sumtotalpoicowing   := t_totalpoicowing + t_sumtotalpoicowing;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    NULL;
            END;
        END LOOP;

        IF t_sumtotalpoicowing <= 0 THEN
            t_poicprocessid   :=
                api.pkg_processupdate.new(a_jobid,
                                          t_poicprocesstype,
                                          NULL,
                                          NULL,
                                          NULL,
                                          NULL);
            api.pkg_processupdate.complete(t_poicprocessid, 'Completed');
        ELSE
            NULL;
        END IF;
    END createrecpoicpaymentprocess;

    /*-------------------------------------------------------------------------
    * VoidPayment() - Public
    *------------------------------------------------------------------------*/
    PROCEDURE voidpayment(a_objectid      udt_id,
                          a_asofdate      DATE,
                          a_paymentid     udt_id,
                          a_isvoidedflag  VARCHAR2,
                          a_reasonforvoid VARCHAR2,
                          a_datevoided    DATE)
    IS
        t_newpaymentstatus      NUMBER;
        t_relid                 NUMBER;
        t_voidpaymentobjectid   NUMBER;
        t_batchid               udt_id;
        t_hqreceiptnum          VARCHAR2(8);
        t_earnedamount          NUMBER;
        t_paytransobjectdefid   udt_id := api.pkg_configquery.objectdefidforname('o_PaymentTransactions');
    BEGIN
        IF NVL(a_isvoidedflag, 'N') = 'N'
       AND a_reasonforvoid IS NOT NULL THEN
            --Void this payment
            api.pkg_paymentupdate.void(a_paymentid, a_datevoided);
            --Now 'freeze' data voided
            api.pkg_columnupdate.setvalue(a_objectid, 'DateVoided', a_datevoided - 1);
            api.pkg_columnupdate.setvalue(a_objectid, 'DateVoided', a_datevoided);
            -- Set income code to 'V'
            api.pkg_columnupdate.setvalue(a_objectid, 'CABINIncomeInd', 'V');

            -- Set income code to 'V' on payment transactions
            --and unearn the transaction if the transaction has already been earned --added by AP on 1/14/2010

            FOR c IN (SELECT reo.objectid
                        FROM api.paymenttransactions pt
                             JOIN api.registeredexternalobjects reo  --TAyers: PIP Task 8.5
                             ON reo.linkvalue = TO_CHAR(pt.transactionid)
                            AND reo.objectdefid = t_paytransobjectdefid
                       WHERE pt.paymentid = a_paymentid)
            LOOP
                api.pkg_columnupdate.setvalue(c.objectid, 'CABINAmtType', 'V');

                --if it has earned
                IF api.pkg_columnquery.VALUE(api.pkg_columnquery.numericvalue(c.objectid, 'PaymentStatusObjectId'),
                                             'Status') =
                   'EARNED' THEN
                    -- Get the amount to unearn
                    t_earnedamount   :=
                        -api.pkg_columnquery.VALUE(
                             api.pkg_columnquery.numericvalue(c.objectid, 'PaymentStatusObjectId'),
                             'EarnedAmount');
                    --unearn the transaction
                    t_newpaymentstatus   :=
                        api.pkg_objectupdate.new(api.pkg_configquery.objectdefidforname('o_PaymentStatus'));
                    t_relid   :=
                        api.pkg_relationshipupdate.new(
                            api.pkg_configquery.endpointidforname('o_PaymentStatus', 'PaymentTransactions'),
                            t_newpaymentstatus,
                            c.objectid);
                    api.pkg_columnupdate.setvalue(t_newpaymentstatus, 'Status', 'UNEARNED');
                    api.pkg_columnupdate.setvalue(t_newpaymentstatus, 'StatusDate', TRUNC(SYSDATE));
                    api.pkg_columnupdate.setvalue(t_newpaymentstatus, 'SystemGenerated', 'Y');
                    api.pkg_columnupdate.setvalue(t_newpaymentstatus, 'EarnedAmount', t_earnedamount);
                END IF;
            END LOOP;

            --If payment is in a payment batch void the payment batch entry objects
            BEGIN
                SELECT op.objectid, rpbp.paymentbatchjobid, op.hqreceiptlookup
                  INTO t_voidpaymentobjectid, t_batchid, t_hqreceiptnum
                  FROM query.o_payment op
                       JOIN query.r_paymentbatchpayment rpbp
                       ON rpbp.paymentobjectid = op.objectid
                 WHERE op.objectid = api.pkg_simplesearch.objectbyindex('o_Payment', 'PaymentId', a_paymentid);

                voidbatchentryobjects(t_voidpaymentobjectid,
                                      NULL,
                                      t_batchid,
                                      t_hqreceiptnum);
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    NULL;
            END;
        END IF;
    END voidpayment;

    ----------------------------------------------------------------------------------------------------
    -- PaymentsVoid()
    -- This will Void the payments related to the Void Payment process.
    ----------------------------------------------------------------------------------------------------
    PROCEDURE paymentsvoid(a_objectid NUMBER, a_asofdate DATE)
    IS
        a_paymentobjid          udt_id;
        t_transjobid            VARCHAR2(50);
        t_newpaymentstatus      NUMBER;
        t_relid                 NUMBER;
        t_voidpaymentobjectid   NUMBER;
        t_batchid               NUMBER;
        t_hqreceiptnum          VARCHAR2(8);
        t_earnedamount          NUMBER;
        t_useraccessgroup       VARCHAR2(4000);
        t_earnedon              VARCHAR2(100);
        t_paymentstatus         DATE;
        t_paytransobjectdefid   udt_id := api.pkg_configquery.objectdefidforname('o_PaymentTransactions');
    BEGIN
        SELECT concatlist(a.description)
          INTO t_useraccessgroup
          FROM api.accessgroupusers au
               JOIN api.accessgroups a
               ON a.accessgroupid = au.accessgroupid
         WHERE au.userid = api.pkg_securityquery.effectiveuserid;

        --Select Payments
        FOR c IN (SELECT p.paymentid, pvp.paymentobjectid
                    FROM query.r_paymentvoidpayment pvp
                         JOIN query.o_payment p
                         ON p.objectid = pvp.paymentobjectid
                   WHERE pvp.voidpaymentprocessid = a_objectid)
        LOOP
            BEGIN
                SELECT earnedon, paymentstatus
                  INTO t_earnedon, t_paymentstatus
                  FROM (  SELECT MIN(fs.earnedon)                                                earnedon,
                                 MAX(api.pkg_columnquery.datevalue(reo.objectid, 'PaymentStatus')) paymentstatus
                            FROM api.paymenttransactions pt
                                 JOIN api.feetransactions ft
                                 ON ft.transactionid = pt.transactionid
                                 JOIN api.fees f
                                 ON f.feeid = ft.feeid
                                 JOIN query.o_feeschedule fs
                                 ON fs.objectid = sitespecific.pkg_fees.getlicfeeschedulobjid(f.feeid),
                                 api.paymenttransactions pt2
                                 JOIN api.registeredexternalobjects reo  --TAyers: PIP Task 8.5
                                 ON reo.linkvalue = TO_CHAR(pt2.transactionid)
                                AND reo.objectdefid = t_paytransobjectdefid
                           WHERE pt.paymentid = c.paymentid
                             AND pt2.paymentid = c.paymentid
                        GROUP BY fs.earnedon
                        ORDER BY 1 DESC)
                 WHERE ROWNUM = 1;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    --misc fee
                    BEGIN
                        SELECT 'PAYMENT', paymentstatus
                          INTO t_earnedon, t_paymentstatus
                          FROM (SELECT MAX(api.pkg_columnquery.datevalue(reo.objectid, 'PaymentStatus'))
                                           paymentstatus
                                  FROM api.paymenttransactions pt
                                       JOIN api.registeredexternalobjects reo  --TAyers: PIP Task 8.5
                                       ON reo.linkvalue = TO_CHAR(pt.transactionid)
                                      AND reo.objectdefid = t_paytransobjectdefid
                                 WHERE pt.paymentid = c.paymentid)
                         WHERE ROWNUM = 1;
                    EXCEPTION
                        WHEN NO_DATA_FOUND THEN
                            t_earnedon        := NULL;
                            t_paymentstatus   := NULL;
                    END;
            END;

            -- 06/01/2021 TJL WO 25342 Back out to allow accounting to void payment after transmittal or
            --                          Payment batch have been completed, added test if already deposited.
            IF (t_paymentstatus IS NULL) THEN
                IF (t_useraccessgroup LIKE '%HQ Accounting%') THEN
                    IF (api.pkg_columnquery.datevalue(c.paymentobjectid, 'DepositedDate') IS NOT NULL) THEN
                        api.pkg_errors.raiseerror(-20000, 'Cannot void a payment that has been deposited');
                    END IF;
                ELSE
                    BEGIN
                        -- 04/15/2021 TJL WO 24949  Added checking to see if payment associated to a payment batch
                        SELECT MAX(batchid) batchid
                          INTO t_transjobid
                          FROM (SELECT api.pkg_columnquery.VALUE(tp.transmittaljobid, 'ExternalFileNum') batchid
                                  FROM query.r_transmittalpayment tp
                                 WHERE tp.paymentobjectid = c.paymentobjectid
                                UNION
                                SELECT api.pkg_columnquery.VALUE(c.paymentobjectid, 'BatchPaymentId') batchid
                                  FROM DUAL)
                         WHERE batchid IS NOT NULL;
                    EXCEPTION
                        WHEN NO_DATA_FOUND THEN
                            NULL;
                    END;
                END IF;

                IF t_transjobid IS NOT NULL THEN
                    api.pkg_errors.raiseerror(
                        -20000,
                           'Cannot void a payment that is related to a Transmittal or Payment Batch. Id: '
                        || t_transjobid);
                END IF;

                --Api.Void
                api.pkg_paymentupdate.void(c.paymentid, SYSDATE);
                -- Process the voiding payment
                pkg_fees.processnegativepayment(a_paymentid => c.paymentid);

                -- Set income code on Payment to 'V'
                api.pkg_columnupdate.setvalue(c.paymentobjectid, 'CABINIncomeInd', 'V');

                -- Set income code on the Payment Transactions to 'V'
                --and unearn the transaction if the transaction has already been earned --added by AP on 1/14/2010
                FOR x IN (SELECT reo.objectid
                            FROM api.paymenttransactions pt
                                 JOIN api.registeredexternalobjects reo  --TAyers: PIP Task 8.5
                                 ON reo.linkvalue = TO_CHAR(pt.transactionid)
                                AND reo.objectdefid = t_paytransobjectdefid
                           WHERE pt.paymentid = c.paymentid)
                LOOP
                    api.pkg_columnupdate.setvalue(x.objectid, 'CABINAmtType', 'V');

                    --if it has earned
                    IF api.pkg_columnquery.VALUE(
                           api.pkg_columnquery.numericvalue(x.objectid, 'PaymentStatusObjectId'),
                           'Status') =
                       'EARNED' THEN
                        -- Get the amount to unearn
                        t_earnedamount   :=
                            -api.pkg_columnquery.VALUE(
                                 api.pkg_columnquery.numericvalue(x.objectid, 'PaymentStatusObjectId'),
                                 'EarnedAmount');
                        --unearn the transaction
                        t_newpaymentstatus   :=
                            api.pkg_objectupdate.new(api.pkg_configquery.objectdefidforname('o_PaymentStatus'));
                        t_relid   :=
                            api.pkg_relationshipupdate.new(
                                api.pkg_configquery.endpointidforname('o_PaymentStatus', 'PaymentTransactions'),
                                t_newpaymentstatus,
                                x.objectid);
                        api.pkg_columnupdate.setvalue(t_newpaymentstatus, 'Status', 'UNEARNED');
                        api.pkg_columnupdate.setvalue(t_newpaymentstatus, 'StatusDate', TRUNC(SYSDATE));
                        api.pkg_columnupdate.setvalue(t_newpaymentstatus, 'SystemGenerated', 'Y');
                        api.pkg_columnupdate.setvalue(t_newpaymentstatus, 'EarnedAmount', t_earnedamount);
                    END IF;
                END LOOP;

                -- select objects to be registered
                FOR t IN (SELECT pt.voidedbytransactionid
                            FROM api.paymenttransactions pt
                           WHERE pt.paymentid = c.paymentid
                             AND pt.voidedbytransactionid IS NOT NULL)
                LOOP
                    --Register transactions as external Objects
                    a_paymentobjid   :=
                        api.pkg_objectupdate.registerexternalobject('o_FeeTransactions',
                                                                    t.voidedbytransactionid,
                                                                    SYSDATE);
                END LOOP;

                --If payment is in a payment batch void the payment batch entry objects
                BEGIN
                    SELECT op.objectid, rpbp.paymentbatchjobid, op.hqreceiptlookup
                      INTO t_voidpaymentobjectid, t_batchid, t_hqreceiptnum
                      FROM query.o_payment op
                           JOIN query.r_paymentbatchpayment rpbp
                           ON rpbp.paymentobjectid = op.objectid
                     WHERE op.objectid = c.paymentobjectid;

                    voidbatchentryobjects(t_voidpaymentobjectid,
                                          NULL,
                                          t_batchid,
                                          t_hqreceiptnum);
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        NULL;
                END;
            ELSE
                api.pkg_errors.raiseerror(-20000, 'This Payment has already been earned, and cannot be voided.');
            END IF;
        END LOOP;
    END paymentsvoid;

    ----------------------------------------------------------------------------------------------------
    -- VoidBatchEntryObjects()
    -- This will Void the Batch Entry Objects of payments that are related to Payment Batches.
    ----------------------------------------------------------------------------------------------------

    PROCEDURE voidbatchentryobjects(a_objectid      NUMBER,
                                    a_asofdate      DATE,
                                    a_batchid       NUMBER,
                                    a_hqreceiptnum  VARCHAR2)
    IS
        t_batchid                 udt_id;
        t_batchpaymentmultiple    VARCHAR2(1);
        t_batchpaymenttype        VARCHAR2(100);
        t_voidpaymentreceiptnum   VARCHAR2(8);
        t_batchentryobjid         udt_id;
        t_batchentryobjids        udt_idlist;
    BEGIN
        t_batchid                 := a_batchid;
        t_voidpaymentreceiptnum   := a_hqreceiptnum;

        SELECT qpb.multiple, qpb.paymentbatchtype
          INTO t_batchpaymentmultiple, t_batchpaymenttype
          FROM query.j_paymentbatch qpb
         WHERE qpb.objectid = t_batchid;

        IF t_batchpaymentmultiple = 'N'
       AND t_batchpaymenttype != 'P-12 RENEWALS' THEN
            SELECT b.objectid
              INTO t_batchentryobjid
              FROM query.o_payment p
                   JOIN query.r_paymentbatchpayment rpbp
                   ON rpbp.paymentobjectid = p.objectid
                   JOIN query.r_pbbatchpaymententry rpbe
                   ON rpbe.paymentbatchjobid = rpbp.paymentbatchjobid
                   JOIN query.o_batchpaymententry b
                   ON b.objectid = rpbe.batchobjectid
             WHERE (p.objectid = a_objectid
                AND b.paymentnumber = t_voidpaymentreceiptnum);

            api.pkg_columnupdate.setvalue(t_batchentryobjid, 'IsPaymentVoided', 'Y');
            api.pkg_columnupdate.setvalue(t_batchentryobjid, 'CheckAmount', 0);
        ELSIF t_batchpaymentmultiple = 'Y'
           OR t_batchpaymenttype = 'P-12 RENEWALS' THEN
            --void the additional itmes
            FOR x
                IN (  SELECT oai.objectid, b.objectid beobjectid
                        FROM query.o_payment p
                             JOIN api.paymenttransactions apt
                             ON apt.paymentid = p.paymentid
                             JOIN query.o_paymenttransactions qpt
                             ON qpt.objectid =
                                api.pkg_simplesearch.objectbyindex('o_PaymentTransactions',
                                                                   'TransactionId',
                                                                   apt.transactionid)
                             JOIN query.r_paymentbatchpayment rpbp
                             ON rpbp.paymentobjectid = p.objectid
                             JOIN query.r_pbbatchpaymententry rpbe
                             ON rpbe.paymentbatchjobid = rpbp.paymentbatchjobid
                             JOIN query.o_batchpaymententry b
                             ON b.objectid = rpbe.batchobjectid
                             JOIN query.r_batchpaymentradditionalitem rai
                             ON rai.batchentryobjectid = b.objectid
                             JOIN query.o_additionalitem oai
                             ON oai.objectid = rai.additionalitemobjectid
                       WHERE p.objectid = a_objectid
                         AND ((qpt.hqreceipt = b.paymentnumber
                           AND b.groupid = oai.groupid
                           AND oai.licensenum = qpt.licensenumber
                           AND oai.licensetypecode = qpt.licensetypecode)
                           OR (qpt.hqreceipt = b.paymentnumber
                           AND oai.licensenum = qpt.licensenumber
                           AND oai.licensetypecode = qpt.licensetypecode))
                    GROUP BY oai.objectid, b.objectid
                    ORDER BY b.objectid)
            LOOP
                api.pkg_columnupdate.setvalue(x.objectid, 'IsPaymentVoided', 'Y');
                api.pkg_columnupdate.setvalue(x.objectid, 'PaidAmount', 0);

                IF t_batchentryobjid != x.beobjectid
                OR t_batchentryobjid IS NULL THEN
                    t_batchentryobjids(t_batchentryobjids.COUNT + 1)   := x.beobjectid;
                    t_batchentryobjid                                  := x.beobjectid;
                END IF;
            END LOOP;

            -- loop thru the batch entry objects and set check amount to 0 and void the entry object
            FOR z IN 1 .. t_batchentryobjids.COUNT
            LOOP
                api.pkg_columnupdate.setvalue(t_batchentryobjids(z), 'IsPaymentVoided', 'Y');
                api.pkg_columnupdate.setvalue(t_batchentryobjids(z), 'CheckAmount', 0);
            END LOOP;
        ELSE
            NULL;
        END IF;
    END voidbatchentryobjects;

    /*-------------------------------------------------------------------------
    * AdjustFee() - Public
    *------------------------------------------------------------------------*/
    /*Procedure AdjustFee(a_ObjectId udt_Id,
    a_AsOfDate date,
    a_FeeId udt_Id,
    a_AdjustAmountBy number,
    a_AdjustmentReason varchar2,
    a_AdjustmentDate date) is
    t_TransactionId udt_Id;
    t_FeeTransactionObjId udt_Id;
    begin

    if a_AdjustAmountBy is not null and a_AdjustAmountBy <> 0 then

    if a_AdjustmentReason is null then
    api.pkg_errors.RaiseError(-20001,
    'Please enter a reason for this adjustment.');
    end if;
    t_TransactionId := api.pkg_FeeUpdate.Adjust(a_FeeId,
    a_AdjustAmountBy,
    a_AdjustmentReason,
    a_AdjustmentDate);

    -- Reglister the adjustment transaction object
    t_FeeTransactionObjId := api.pkg_ObjectUpdate.RegisterExternalObject('o_FeeTransactions',
    t_TransactionId);

    -- Reset the flags
    api.pkg_ColumnUpdate.RemoveValue(a_ObjectId, 'AdjustAmountBy');
    api.pkg_ColumnUpdate.RemoveValue(a_ObjectId, 'AdjustmentReason');
    api.pkg_ColumnUpdate.RemoveValue(a_ObjectId, 'AdjustmentDate');

    end if;

    end AdjustFee; */

    /*-------------------------------------------------------------------------
    * ProcessProposedPayment() - Public
    *------------------------------------------------------------------------*/
    PROCEDURE processproposedpayment(a_jobid         udt_id,
                                     a_asofdate      DATE,
                                     a_totalowing    NUMBER,
                                     a_totalpayment  NUMBER,
                                     a_receiptnumber VARCHAR2,
                                     a_payeereference VARCHAR2,
                                     a_paymentdate   DATE,
                                     a_cancelpaymentflag VARCHAR2,
                                     a_processpaymentflag VARCHAR2)
    IS
        t_amountstopay              api.pkg_definition.udt_numberlist;
        t_amountsum                 NUMBER;
        t_defaultofficeobjectid     udt_id;
        t_earnedamount              NUMBER;
        t_ecomflag                  BOOLEAN;
        t_feecount                  PLS_INTEGER;
        t_feeids                    udt_idlist;
        t_feejobtype                VARCHAR2(50);
        t_officedefid               udt_id;
        t_ovrfeeids                 udt_idlist;
        t_ovramountstopay           api.pkg_definition.udt_numberlist;
        t_paymentdefid              udt_id;
        t_paymentid                 udt_id;
        t_paymentmethod             VARCHAR2(100);
        t_paymentmethodid           udt_id;
        t_paymentobjectid           udt_id;
        t_paytransobjectid          udt_id;
        t_processpaymentdefid       udt_id;
        t_processpaymentid          udt_id;
        t_proposedpaymentdefid      udt_id;
        t_referencelabel            VARCHAR2(100);
        t_referencerequiredflag     BOOLEAN;
        t_relid                     udt_id;
        t_tempids                   udt_idlist;
        t_totalamountstopay         NUMBER;
        t_paymentstatusdefid        udt_id;
        t_paymentstatusendpointid   udt_id;
        t_paymentstatusobjectid     udt_id;
        t_paymentstatusrelid        udt_id;
        t_feescheduleobjectid       udt_id;
        t_feeobjectid               udt_id;
        t_receivepaymentdefid       udt_id;
        t_receivepaymentid          udt_id;
        t_transactionobjid          udt_id;
        t_feescheduleearnedon       VARCHAR(20);
        t_feeidsovr                 udt_idlist;
        t_payamountsovr             udt_numberlist;
        t_feeobjectdefid            udt_id := api.pkg_configquery.objectdefidforname('o_Fee');
        t_paytransobjectdefid       udt_id := api.pkg_configquery.objectdefidforname('o_PaymentTransactions');
    BEGIN
        IF a_cancelpaymentflag = 'Y' THEN
            /* Get DefId's */
            t_processpaymentdefid   := api.pkg_objectdefquery.idforname('p_ProcessPayment');

            IF t_processpaymentdefid IS NULL THEN
                api.pkg_errors.raiseerror(-20001, 'Cannot get the DefId for p_ProcessPayment.');
            END IF;

            /* Create and complete the Process Payment process */
            t_processpaymentid      :=
                api.pkg_processupdate.new(a_jobid,
                                          t_processpaymentdefid,
                                          'Manually cancelled by user.',
                                          SYSDATE,
                                          SYSDATE,
                                          SYSDATE);
            api.pkg_processupdate.complete(t_processpaymentid, 'Cancel', SYSDATE);

            /* Reset a_CancelPaymentFlag to stop recursion */
            api.pkg_columnupdate.setvalue(a_jobid, 'CancelPaymentFlag', 'N');
        ELSIF a_processpaymentflag = 'Y' THEN
            /* Get DefId's */
            t_processpaymentdefid     := api.pkg_objectdefquery.idforname('p_ProcessPayment');

            IF t_processpaymentdefid IS NULL THEN
                api.pkg_errors.raiseerror(-20001, 'Cannot get the DefId for p_ProcessPayment.');
            END IF;

            t_proposedpaymentdefid    := api.pkg_objectdefquery.idforname('j_ProposedPayment');

            IF t_proposedpaymentdefid IS NULL THEN
                api.pkg_errors.raiseerror(-20001, 'Cannot get the DefId for j_ProposedPayment.');
            END IF;

            t_paymentdefid            := api.pkg_objectdefquery.idforname('o_Payment');

            IF t_paymentdefid IS NULL THEN
                api.pkg_errors.raiseerror(-20001, 'Cannot get the DefId for o_Payment.');
            END IF;

            t_officedefid             := api.pkg_objectdefquery.idforname('o_Office');

            IF t_officedefid IS NULL THEN
                api.pkg_errors.raiseerror(-20001, 'Cannot get the DefId for o_Office.');
            END IF;

            /*Get Payment Method related info */
            t_tempids                 :=
                api.pkg_objectquery.relatedobjects(
                    a_jobid,
                    api.pkg_configquery.endpointidforname(t_proposedpaymentdefid, 'PaymentMethod'));

            IF t_tempids.COUNT != 1 THEN
                api.pkg_errors.raiseerror(-20001, 'Please choose a Payment Method.');
            END IF;

            t_paymentmethodid         := t_tempids(1);
            t_paymentmethod           := api.pkg_columnquery.VALUE(t_paymentmethodid, 'Name');
            t_referencelabel          := api.pkg_columnquery.VALUE(t_paymentmethodid, 'ReferenceLabel');
            t_referencerequiredflag   :=
                CASE
                    WHEN api.pkg_columnquery.VALUE(t_paymentmethodid, 'ReferenceRequiredFlag') = 'Y' THEN TRUE
                    ELSE FALSE
                END;
            t_ecomflag                :=
                CASE WHEN api.pkg_columnquery.VALUE(t_paymentmethodid, 'EComFlag') = 'Y' THEN TRUE ELSE FALSE END;

            /* Check for required data */
            IF a_totalpayment IS NULL
            OR a_totalpayment = 0 THEN
                api.pkg_errors.raiseerror(-20001, 'Please enter the Total Payment amount.');
            ELSIF a_totalpayment < 0 THEN
                api.pkg_errors.raiseerror(-20001, 'Total Payment amount must be positive.');
            END IF;

            /* Sum up the amounts to pay and make sure they're all valid */
            t_totalamountstopay       := 0;
            t_feecount                := 0;

            FOR c IN (SELECT api.pkg_columnquery.VALUE(b.toobjectid, 'FeeId')                  feeid,
                             api.pkg_columnquery.numericvalue(b.relationshipid, 'AmountToPay') amounttopay,
                             api.pkg_columnquery.numericvalue(b.toobjectid, 'TotalOwing')      totalowing,
                             api.pkg_columnquery.VALUE(b.relationshipid, 'OVR')                ovr
                        FROM api.relationshipdefs a
                             JOIN api.relationships b
                             ON b.fromobjectid = a_jobid
                            AND b.endpointid = a.fromendpointid
                       WHERE a.fromendpointname = 'Fee')
            LOOP
                -- if c.AmountToPay is null then
                -- api.pkg_errors.RaiseError(-20001, 'Please enter the amount to pay for each fee.');
                -- elsif c.AmountToPay < 0 then
                IF c.amounttopay < 0 THEN
                    api.pkg_errors.raiseerror(-20001, 'Each amount to pay must be positive.');
                END IF;

                IF c.amounttopay > 0 THEN
                    t_feecount            := t_feecount + 1;

                    IF c.ovr = 'Y'
                   AND c.amounttopay > c.totalowing THEN
                        t_feeidsovr(t_feeidsovr.COUNT + 1)           := c.feeid;
                        t_payamountsovr(t_payamountsovr.COUNT + 1)   := c.amounttopay;
                    END IF;

                    t_totalamountstopay   := t_totalamountstopay + c.amounttopay;
                END IF;
            END LOOP;

            IF a_totalpayment <> t_totalamountstopay THEN
                api.pkg_errors.raiseerror(-20001,
                                             'Total Amount to pay ('
                                          || TO_CHAR(a_totalpayment, 'FM$999,999,999,999,990.00')
                                          || ') must equal to the sum of all the individual amounts ('
                                          || TO_CHAR(t_totalamountstopay, 'FM$999,999,999,999,990.00')
                                          || ').');
            END IF;

            IF t_referencerequiredflag
           AND a_payeereference IS NULL THEN
                api.pkg_errors.raiseerror(-20001,
                                             'A Payment Method of '
                                          || t_paymentmethod
                                          || ' requires that you enter a '
                                          || t_referencelabel
                                          || '.');
            END IF;

            IF NOT t_ecomflag THEN
                /* Process Manual payment */
                /* if a_ReceiptNumber is null then
                api.pkg_errors.RaiseError(-20001, 'Please enter the Receipt Number from the POS receipt.');
                end if;
                */
                /* Pay the POSSE Fees */

                --Create Overpayment records (for separate, flagged PaymentTransactions)
                sitespecific.pkg_fees.calculateoverpayment(t_feeidsovr,
                                                           t_payamountsovr,
                                                           t_ovrfeeids,
                                                           t_ovramountstopay);

                --Get FeeIds and Amounts to apply.
                SELECT api.pkg_columnquery.VALUE(b.toobjectid, 'FeeId')           feeid,
                       api.pkg_columnquery.VALUE(b.relationshipid, 'AmountToPay') amounttopay
                  BULK COLLECT INTO t_feeids, t_amountstopay
                  FROM api.relationshipdefs a
                       JOIN api.relationships b
                       ON b.fromobjectid = a_jobid
                      AND b.endpointid = a.fromendpointid
                 WHERE a.fromendpointname = 'Fee'
                   AND api.pkg_columnquery.numericvalue(b.relationshipid, 'AmountToPay') > 0
                   AND (api.pkg_columnquery.VALUE(b.relationshipid, 'OVR') = 'N'
                     OR api.pkg_columnquery.numericvalue(b.toobjectid, 'TotalOwing') >=
                        api.pkg_columnquery.numericvalue(b.relationshipid, 'AmountToPay'));

                --Combine both the OVR and regular Feeids and Amounts to apply.
                FOR c_1 IN 1 .. t_feeidsovr.COUNT
                LOOP
                    t_feeids(t_feeids.COUNT + 1)               := t_feeidsovr(c_1);
                    t_amountstopay(t_amountstopay.COUNT + 1)   := t_payamountsovr(c_1);
                END LOOP;

                --Create Payments
                BEGIN
                    t_paymentid   := api.pkg_paymentupdate.new(a_paymentdate, t_feeids, t_amountstopay);
                    api.pkg_paymentupdate.modify(t_paymentid, a_payeereference, a_receiptnumber);
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        api.pkg_errors.raiseerror(-20001, 'Create payment could not find one of the fees.');
                END;

                /* A search from here won't do the dynamic registration, so register the new payment manually */
                t_paymentobjectid           := api.pkg_objectupdate.registerexternalobject('o_Payment', t_paymentid);

                -- Set the income code on the Payment to I
                api.pkg_columnupdate.setvalue(t_paymentobjectid, 'CABINIncomeInd', 'I');

                -- For each Payment Transaction for the Payment that was just created, register the external Payment Transaction and Fee Transaction
                FOR c IN (SELECT pt.transactionid
                            FROM api.paymenttransactions pt
                           WHERE pt.paymentid = t_paymentid)
                LOOP
                    t_paytransobjectid   :=
                        api.pkg_objectupdate.registerexternalobject('o_PaymentTransactions', c.transactionid);
                    t_transactionobjid   :=
                        api.pkg_objectupdate.registerexternalobject('o_FeeTransactions', c.transactionid);

                    -- Set the income code on the Payment Transaction to I
                    api.pkg_columnupdate.setvalue(t_paytransobjectid, 'CABINAmtType', 'I');
                END LOOP;

                /*for x in (select pt.TransactionId
                from api.PaymentTransactions pt
                where pt.PaymentId = t_PaymentId) loop
                t_PayTransObjectId := api.pkg_objectupdate.RegisterExternalObject('o_PaymentTransactions', x.TransactionId);
                end loop;*/

                --If Payment Transaction is overpayment, set flag to indicate it (used in Fees and Payments grid)
                sitespecific.pkg_fees.setpaymenttransactionflag(t_ovrfeeids, t_ovramountstopay, 'IsOverpayment');

                /* Update the Payment Method */
                t_relid                     :=
                    api.pkg_relationshipupdate.new(
                        api.pkg_configquery.endpointidforname(t_paymentdefid, 'PaymentMethod'),
                        t_paymentobjectid,
                        t_paymentmethodid);

                /* Create a relationship to the new payment object */
                t_relid                     :=
                    api.pkg_relationshipupdate.new(
                        api.pkg_configquery.endpointidforname(t_proposedpaymentdefid, 'Payment'),
                        a_jobid,
                        t_paymentobjectid);

                /*Create a relationship to the user's default office*/
                t_defaultofficeobjectid     :=
                    api.pkg_columnquery.VALUE(api.pkg_securityquery.effectiveuserid, 'DefaultOfficeObjectId');

                IF t_defaultofficeobjectid IS NULL THEN
                    api.pkg_errors.raiseerror(-20000, 'The User is not related to a Default Office.');
                END IF;

                t_relid                     :=
                    api.pkg_relationshipupdate.new(api.pkg_configquery.endpointidforname(t_officedefid, 'Payment'),
                                                   t_defaultofficeobjectid,
                                                   t_paymentobjectid);

                /* Create and complete the Process Payment process */
                t_processpaymentid          :=
                    api.pkg_processupdate.new(a_jobid,
                                              t_processpaymentdefid,
                                                 'Manual Payment for '
                                              || TO_CHAR(a_totalpayment, '$999,999,999,999,990.00')
                                              || ' processed.',
                                              SYSDATE,
                                              SYSDATE,
                                              SYSDATE);
                api.pkg_processupdate.complete(t_processpaymentid, 'Accepted - Manual', SYSDATE);

                -- Loop through the jobs the fees are on, and if any of them are License Types, create the Receive Payment process
                FOR c IN (SELECT UNIQUE (api.pkg_columnquery.VALUE(b.toobjectid, 'JobId')) feejobid
                            FROM api.relationshipdefs a
                                 JOIN api.relationships b
                                 ON b.fromobjectid = a_jobid
                                AND b.endpointid = a.fromendpointid
                                 JOIN query.o_fee fe
                                 ON fe.objectid = b.toobjectid  -- added to exclude CATA an EPA fee's -- it this was extending the 'Ready to Issue Date' -- by Gurpreet
                           WHERE a.fromendpointname = 'Fee'
                             AND api.pkg_columnquery.numericvalue(b.relationshipid, 'AmountToPay') > 0
                             AND SUBSTR(fe.description,
                                        (  INSTR(fe.description,
                                                 ' ',
                                                 1,
                                                 2)
                                         + 1)) NOT IN ('CATA', 'EPA')  -- added to exclude CATA an EPA fee's -- it this was extending the 'Ready to Issue Date'. - by Gurpreet
                                                                     )
                LOOP
                    t_feejobtype   := api.pkg_columnquery.VALUE(c.feejobid, 'ObjectDefName');

                    IF t_feejobtype = 'j_LicenseType' THEN
                        INSERT INTO processesdepositedpayments_t
                             VALUES (c.feejobid,
                                     t_paymentid,
                                     NULL,
                                     NULL,
                                     api.pkg_columnquery.VALUE(c.feejobid, 'LicenseTypeCode'),
                                     TRIM(SYSDATE));
                    END IF;
                END LOOP;

                /*Check the related Fee Schedule Record for each fee being paid. If the Earned On column is "Payment", then create a new Payment Status
                of "Earned" related to the payment transaction record for that fee.*/
                t_paymentstatusdefid        := api.pkg_configquery.objectdefidforname('o_PaymentStatus');
                t_paymentstatusendpointid   :=
                    api.pkg_configquery.endpointidforname('o_PaymentStatus', 'PaymentTransactions');

                --for each paymenttransaction loop
                -- RyanL: Changed the select clause to be a subselect for performance (PIP Task 8.5)
                FOR m IN (SELECT pt.transactionid,
                                 reo.objectid,
                                 ft.amount,
                                 (  f.amount
                                  + NVL((SELECT SUM(amount)
                                           FROM api.feetransactions
                                          WHERE feeid = f.feeid
                                            AND transactiontype = 'Adj'),
                                        0))
                                     feeamount,
                                 f.feeid
                            FROM api.paymenttransactions pt
                                 JOIN api.registeredexternalobjects reo  --TAyers: PIP Task 8.5
                                 ON reo.linkvalue = TO_CHAR(pt.transactionid)
                                AND reo.objectdefid = t_paytransobjectdefid
                                 JOIN api.feetransactions ft
                                 ON ft.transactionid = pt.transactionid
                                 JOIN api.fees f
                                 ON f.feeid = ft.feeid
                           WHERE pt.paymentid = t_paymentid
                             AND api.pkg_columnquery.VALUE(reo.objectid, 'IsOverpayment') = 'N')
                LOOP
                    --for each fee for each paymenttransaction select the fees that have a LicenseFeeSchedule
                    BEGIN
                        SELECT reo.objectid
                          INTO t_feeobjectid
                          FROM api.feetransactions ft
                               JOIN api.registeredexternalobjects reo  -- RyanL: PIP Task 8.5
                               ON reo.linkvalue = TO_CHAR(ft.feeid)
                              AND reo.objectdefid = t_feeobjectdefid
                         WHERE ft.transactionid = m.transactionid;

                        SELECT r.licensefeescheduleid, api.pkg_columnquery.VALUE(r.licensefeescheduleid, 'EarnedOn')
                          INTO t_feescheduleobjectid, t_feescheduleearnedon
                          FROM query.r_feelicensefeeschedule r
                         WHERE r.feeobjectid = t_feeobjectid;

                        -- Get the summed earned amounts for this transaction TODO - do we need this here?
                        SELECT  /*+ CARDINALITY (pt 1) */
                               NVL(
                                   ABS(
                                       SUM(api.pkg_columnquery.numericvalue(r.paymentstatusobjectid, 'EarnedAmount'))),
                                   0)
                          INTO t_earnedamount
                          FROM api.feetransactions ft
                               JOIN api.registeredexternalobjects reo  --TAyers: PIP Task 8.5
                               ON reo.linkvalue = TO_CHAR(ft.transactionid)
                              AND reo.objectdefid = t_paytransobjectdefid
                               JOIN query.r_paymentstatuspaymenttrans r
                               ON r.paymenttransactionobjectid = reo.objectid
                         WHERE ft.feeid = m.feeid;

                        --If that feeschedule.EarnedOn = Payment then create paymentstatus with value of Earned
                        IF t_feescheduleearnedon = 'PAYMENT'
                       AND t_earnedamount < m.feeamount THEN
                            IF t_earnedamount - m.amount > m.feeamount THEN
                                t_earnedamount   := -m.feeamount + t_earnedamount;
                            ELSE
                                t_earnedamount   := m.amount;
                            END IF;

                            t_paymentstatusobjectid   := api.pkg_objectupdate.new(t_paymentstatusdefid);
                            t_paymentstatusrelid      :=
                                api.pkg_relationshipupdate.new(t_paymentstatusendpointid,
                                                               t_paymentstatusobjectid,
                                                               m.objectid);
                            api.pkg_columnupdate.setvalue(t_paymentstatusobjectid, 'Status', 'EARNED');
                            api.pkg_columnupdate.setvalue(t_paymentstatusobjectid, 'StatusDate', TRUNC(SYSDATE));
                            api.pkg_columnupdate.setvalue(t_paymentstatusobjectid, 'SystemGenerated', 'Y');
                            api.pkg_columnupdate.setvalue(t_paymentstatusobjectid, 'EarnedAmount', t_earnedamount);
                        END IF;
                    --when there are no licensefeeschedules it is assumed that they are earned imediatley. Create Paymentstatus with Earned.
                    EXCEPTION
                        WHEN NO_DATA_FOUND THEN
                            t_paymentstatusobjectid   := api.pkg_objectupdate.new(t_paymentstatusdefid);
                            t_paymentstatusrelid      :=
                                api.pkg_relationshipupdate.new(t_paymentstatusendpointid,
                                                               t_paymentstatusobjectid,
                                                               m.objectid);
                            api.pkg_columnupdate.setvalue(t_paymentstatusobjectid, 'Status', 'EARNED');
                            api.pkg_columnupdate.setvalue(t_paymentstatusobjectid, 'StatusDate', TRUNC(SYSDATE));
                            api.pkg_columnupdate.setvalue(t_paymentstatusobjectid, 'SystemGenerated', 'Y');
                    END;
                END LOOP;

                /* Assign the Payment Date to the dup_PaymentDate column on the Payment object because the lookup to the Payment Date on the
                Fee Transactions table do not work until after this transaction is complete - this means that the toolbox procedure to
                maintain dup_ details does not work for this detail at this point.*/
                api.pkg_columnupdate.setvalue(t_paymentobjectid, 'PaymentDateStored', a_paymentdate);

                /* Assign the Amount to the dup_PaymentAmount column on the Payment object because the lookup to the Payment Amount on the
                Fee Transactions table do not work until after this transaction is complete - this means that the toolbox procedure to
                maintain dup_ details does not work for this detail at this point.*/
                t_amountsum                 := 0;

                FOR x IN 1 .. t_amountstopay.COUNT
                LOOP
                    t_amountsum   := t_amountsum + t_amountstopay(x);
                END LOOP;

                api.pkg_columnupdate.setvalue(t_paymentobjectid, 'PaymentAmountStored', t_amountsum);
            --else

            -- api.pkg_errors.RaiseError(-20001, 'eCom Transactions are not yet supported.');

            END IF;

            /* Reset a_ProcessPaymentFlag to stop recursion */
            api.pkg_columnupdate.setvalue(a_jobid, 'ProcessPaymentFlag', 'N');
        END IF;
    END processproposedpayment;

    /*---------------------------------------------------------------------------
    * GetPaymentsForRefund() - public
    *-------------------------------------------------------------------------*/
    /*
    procedure GetPaymentsForRefund (
    a_ObjectId udt_Id,
    a_EndPointId udt_Id,
    a_RelatedObjectIds out api.udt_ObjectList
    ) is

    t_EndPoints udt_IdList;
    t_JobId udt_Id;
    t_Payments udt_IdList;

    begin

    a_RelatedObjectIds := api.udt_ObjectList();

    --Get the EndPointId for the Payment relationship
    select r.ToEndPointId
    bulk collect into t_EndPoints
    from api.relationshipdefs r
    join api.jobtypes t
    on t.JobTypeId = r.FromObjectDefId
    join api.ObjectDefs p
    on p.ObjectDefId = r.ToObjectDefId
    where t.name in('j_SubdivisionApplication', 'j_PermitApplication', 'j_ApprovalApplication')
    and p.Name = 'o_Payment';

    --Get our job id
    select a.JobId
    into t_JobId
    from api.Processes a
    where a.ProcessId = a_ObjectId;

    t_Payments := api.pkg_ObjectQuery.RelatedObjects(t_JobId, t_EndPoints);

    for i in 1..t_Payments.count loop

    a_RelatedObjectIds.extend(1);
    a_RelatedObjectIds(i) := api.udt_Object(t_Payments(i));

    end loop;

    end;
    */
    /*-------------------------------------------------------------------------
    * ProcessRefund() - Public
    *------------------------------------------------------------------------*/
    /*
    Procedure ProcessRefund(a_ProcessId udt_Id,
    a_AsOfDate date,
    a_Amount number,
    a_ReceiptNumber varchar2,
    a_PayeeReference varchar2,
    a_Reason varchar2,
    a_RefundDate date,
    a_PaymentId udt_Id) is

    t_Count number;
    t_FairShare number;
    t_FeeCount number;
    t_FeeIds udt_IdList;
    t_JobId udt_Id;
    t_TempIds udt_IdList;
    t_PaymentMethod varchar2(100);
    t_PaymentMethodId udt_Id;
    t_PaymentObjectId udt_Id;
    t_ProvideRefundDefId udt_Id;
    t_ReferenceLabel varchar2(100);
    t_ReferenceRequiredFlag boolean;
    t_RefundAmounts udt_NumberList;
    t_RefundId udt_Id;
    t_RefundDefId udt_Id;
    t_RefundObjectId udt_Id;
    t_RelId udt_Id;
    t_PaymentMethodEndPointId udt_Id;
    t_RefundTransObjectId udt_Id;
    t_RemainingAmount number;
    t_TransactionObjId udt_Id;

    begin

    --Get defid's etc.
    select JobId, ProcessTypeId
    into t_JobId, t_ProvideRefundDefId
    from api.Processes
    where ProcessId = a_ProcessId;
    t_RefundDefId := api.pkg_ConfigQuery.ObjectDefIdForName('o_Payment');
    t_PaymentObjectId := api.pkg_SimpleSearch.ObjectByIndex('o_Payment',
    'PaymentId',
    a_PaymentId);
    if t_PaymentObjectId is null then
    raise_application_error(-20001,
    'Cannot get o_Payment for this payment');
    end if;

    --Get Payment Method related info
    t_TempIds := api.pkg_ObjectQuery.RelatedObjects(a_ProcessId,
    api.pkg_ConfigQuery.EndPointIdForName(t_ProvideRefundDefId,
    'PaymentMethod'));
    if t_TempIds.count != 1 then
    api.pkg_errors.RaiseError(-20001,
    'Please choose a Refund Payment Method.');
    end if;
    t_PaymentMethodId := t_TempIds(1);
    t_PaymentMethod := api.pkg_ColumnQuery.Value(t_PaymentMethodId,
    'Name');
    t_ReferenceLabel := api.pkg_ColumnQuery.Value(t_PaymentMethodId,
    'ReferenceLabel');
    t_ReferenceRequiredFlag := case when api.pkg_ColumnQuery.Value(t_PaymentMethodId, 'ReferenceRequiredFlag') = 'Y' then true else false end;
    -- t_EComFlag := case when api.pkg_ColumnQuery.Value(t_PaymentMethodId, 'EComFlag') = 'Y' then true else false end;

    -- Check for required data
    if a_Amount is null or a_Amount = 0 then
    api.pkg_errors.RaiseError(-20001,
    'Please enter the Amount to refund.');
    elsif a_Amount < 0 then
    api.pkg_errors.RaiseError(-20001,
    'Amount to refund must be positive.');
    end if;
    if t_ReferenceRequiredFlag and a_PayeeReference is null then
    api.pkg_errors.RaiseError(-20001,
    'A Refund Payment Method of ' ||
    t_PaymentMethod ||
    ' requires that you enter a ' ||
    t_ReferenceLabel || '.');
    end if;
    if a_ReceiptNumber is null then
    api.pkg_errors.RaiseError(-20001,
    'Please enter the Receipt Number from the POS receipt.');
    end if;

    -- Allocate the refund across the fees for this payment
    select count(*)
    into t_FeeCount
    from api.PaymentTransactions a
    join api.FeeTransactions b on b.TransactionId = a.TransactionId
    where a.PaymentId = a_PaymentId;

    t_RemainingAmount := a_Amount * -1;
    t_Count := 0;

    -- Loop through all of the fees, allocating a fair share of the refund
    --Remember: Refunds are negative, so <> logic is reversed
    for i in (select b.*
    from api.PaymentTransactions a
    join api.FeeTransactions b on b.TransactionId =
    a.TransactionId
    where a.PaymentId = a_PaymentId
    order by b.Amount desc) loop

    t_Count := t_Count + 1;
    if t_Count = t_FeeCount then

    -- The last item gets the remainder
    t_FairShare := t_RemainingAmount;

    else

    -- Give this fee it's fair share, unless the fee is too small
    t_FairShare := round(t_RemainingAmount / (t_FeeCount - t_Count + 1),
    2);
    if i.Amount > t_FairShare then
    t_FairShare := i.Amount;
    end if;

    end if;

    t_FeeIds(t_Count) := i.FeeId;
    t_RefundAmounts(t_Count) := t_FairShare;

    t_RemainingAmount := t_RemainingAmount + t_FairShare;

    end loop;

    -- Create the refund (negative payment as POSSE finance doesn't actually support refunds)
    begin
    t_RefundId := api.pkg_PaymentUpdate.New(a_RefundDate,
    t_FeeIds,
    t_RefundAmounts);
    api.pkg_PaymentUpdate.Modify(t_RefundId,
    a_PayeeReference,
    a_ReceiptNumber);
    exception
    when no_data_found then
    api.pkg_errors.RaiseError(-20001,
    'Create refund could not find one of the fees.');
    end;

    -- A search from here won't do the dynamic registration, so register the new payment manually
    t_RefundObjectId := api.pkg_ObjectUpdate.RegisterExternalObject('o_Payment',
    t_RefundId);

    -- For each Payment Transaction for the Payment that was just created, register the external Payment Transaction and Fee Transaction
    For c in (select pt.TransactionId
    from api.PaymentTransactions pt
    where pt.PaymentId = t_RefundId) Loop

    t_RefundTransObjectId := api.pkg_ObjectUpdate.RegisterExternalObject('o_PaymentTransactions',
    c.TransactionId);
    t_TransactionObjId := api.pkg_ObjectUpdate.RegisterExternalObject('o_FeeTransactions',
    c.TransactionId);

    End Loop;

    -- Now fill in all the additional details
    api.pkg_ColumnUpdate.SetValue(t_RefundObjectId,
    'PaymentDateStored',
    api.pkg_columnquery.value(t_RefundObjectId, 'PaymentDate')); --Added by David while procedure was commented out (3.22.10)
    api.pkg_ColumnUpdate.SetValue(t_RefundObjectId,
    'CABINIncomeInd',
    'R')); --Added by David while procedure was commented out (3.22.10)
    api.pkg_ColumnUpdate.SetValue(t_RefundObjectId,
    'PaymentAmountStored',
    api.pkg_columnquery.value(t_RefundObjectId, 'PaymentAmount')); --Added by David while procedure was commented out (3.22.10)
    api.pkg_ColumnUpdate.SetValue(t_RefundObjectId, 'IsRefund', 'Y');
    api.pkg_ColumnUpdate.SetValue(t_RefundObjectId,
    'ReasonForRefund',
    a_Reason);

    -- Update the Payment Method
    t_RelId := api.pkg_RelationshipUpdate.New(api.pkg_ConfigQuery.EndPointIdForName(t_RefundDefId,
    'PaymentMethod'),
    t_RefundObjectId,
    t_PaymentMethodId);

    -- Relate the refund to the payment
    t_RelId := api.pkg_RelationshipUpdate.New(api.pkg_ConfigQuery.EndPointIdForName(t_RefundDefId,
    'Refund'),
    t_PaymentObjectId,
    t_RefundObjectId);

    -- Relate the refund to the Provide Refund process
    t_RelId := api.pkg_RelationshipUpdate.New(api.pkg_ConfigQuery.EndPointIdForName(t_ProvideRefundDefId,
    'Refund'),
    a_ProcessId,
    t_RefundObjectId);

    end;
    */

    /*--------------------------------------------------------------------------
    * NewFee()
    *------------------------------------------------------------------------*/
    PROCEDURE newfee(a_feeid        IN OUT NUMBER,
                     a_amount              NUMBER,
                     a_description         VARCHAR2,
                     a_glaccountid         NUMBER,
                     a_jobid               NUMBER,
                     a_taxrateid           NUMBER,
                     a_feeobjid        OUT NUMBER,
                     a_round               BOOLEAN DEFAULT TRUE)
    IS
        t_feetransactionid   NUMBER;
    BEGIN
        IF a_amount >= 0 THEN
            a_feeid      :=
                api.pkg_feeupdate.new(a_jobid,
                                      CASE
                                          WHEN (a_round = TRUE
                                            AND a_amount > 0) THEN
                                              ROUND(a_amount)
                                          WHEN a_amount = 0 THEN
                                              (a_amount + .01)
                                          ELSE
                                              a_amount
                                      END,  --round the fee amount.
                                      a_description,
                                      a_glaccountid,
                                      NULL,
                                      a_taxrateid,
                                      SYSDATE);
            a_feeobjid   := api.pkg_objectupdate.registerexternalobject('o_Fee', a_feeid, SYSDATE);
        ELSE
            NULL;
        END IF;

        IF a_amount = 0 THEN
            --Adjust Fee Balance to 0 if a_Amount = 0
            t_feetransactionid   :=
                api.pkg_feeupdate.adjust(a_feeid,
                                         (-.01),  --Round the Fee Amount
                                         a_description,  --a_FeeActivity,
                                         SYSDATE);
        ELSE
            NULL;
        END IF;
    END;

    /*-------------------------------------------------------------------------
    * PrepareRefund() - Public
    *------------------------------------------------------------------------*/
    /* Procedure PrepareRefund(a_ProcessId udt_Id, a_AsOfDate date) is
    t_JobId udt_Id;
    t_PaymentDefId udt_Id;
    t_PaymentMethod varchar2(100);
    t_PaymentMethodId udt_Id;
    t_ProcessPaymentDefId udt_Id;
    t_ProposedPaymentDefId udt_Id;
    t_PayeeReference varchar2(60);
    t_ReceiptNumber varchar2(60);
    t_ReceiptNumberLabel varchar2(100);
    t_ReferenceLabel varchar2(100);
    t_ReferenceRequiredFlag boolean;
    t_TempIds udt_IdList;
    t_TotalAmountsToRefund number;
    t_TotalPayment number(15, 2);
    t_Transactions udt_IdList;

    begin

    --Get DefId's and Proposed Payment Info
    select a.JobId, b.TotalPayment, b.ReceiptNumber, b.PayeeReference
    into t_JobId, t_TotalPayment, t_ReceiptNumber, t_PayeeReference
    from api.Processes a
    join query.j_ProposedPayment b on b.JobId = a.JobId
    where a.ProcessId = a_ProcessId;

    t_ProcessPaymentDefId := api.pkg_ObjectDefQuery.IdForName('p_ProcessPayment');
    if t_ProcessPaymentDefId is null then
    api.pkg_errors.RaiseError(-20001,
    'Cannot get the DefId for p_ProcessPayment.');
    end if;
    t_ProposedPaymentDefId := api.pkg_ObjectDefQuery.IdForName('j_ProposedPayment');
    if t_ProposedPaymentDefId is null then
    api.pkg_errors.RaiseError(-20001,
    'Cannot get the DefId for j_ProposedPayment.');
    end if;
    t_PaymentDefId := api.pkg_ObjectDefQuery.IdForName('o_Payment');
    if t_PaymentDefId is null then
    api.pkg_errors.RaiseError(-20001,
    'Cannot get the DefId for o_Payment.');
    end if;

    --Get Payment Method related info
    t_TempIds := api.pkg_ObjectQuery.RelatedObjects(t_JobId,
    api.pkg_ConfigQuery.EndPointIdForName(t_ProposedPaymentDefId,
    'PaymentMethod'));
    if t_TempIds.count != 1 then
    api.pkg_errors.RaiseError(-20001, 'Please choose a Payment Method.');
    end if;
    t_PaymentMethodId := t_TempIds(1);
    t_PaymentMethod := api.pkg_ColumnQuery.Value(t_PaymentMethodId,
    'Name');
    t_ReceiptNumberLabel := api.pkg_ColumnQuery.Value(t_PaymentMethodId,
    'ReceiptNumberLabel');
    t_ReferenceLabel := api.pkg_ColumnQuery.Value(t_PaymentMethodId,
    'ReferenceLabel');
    t_ReferenceRequiredFlag := case when api.pkg_ColumnQuery.Value(t_PaymentMethodId, 'ReferenceRequiredFlag') = 'Y' then true else false end;

    --Check for required data
    if t_TotalPayment is null or t_TotalPayment = 0 then
    api.pkg_errors.RaiseError(-20001,
    'Please enter the Total Refund Amount.');
    elsif t_TotalPayment < 0 then
    api.pkg_errors.RaiseError(-20001,
    'Total Refund Amount must be positive.');
    end if;

    --Set the payment date
    if api.pkg_ColumnQuery.DateValue(t_JobId, 'PaymentDate') is null then
    api.pkg_ColumnUpdate.SetValue(t_JobId, 'PaymentDate', trunc(sysdate));
    end if;

    if t_ReferenceRequiredFlag and t_PayeeReference is null then
    api.pkg_errors.RaiseError(-20001,
    'A Payment Method of ' || t_PaymentMethod ||
    ' requires that you enter a ' ||
    t_ReferenceLabel || '.');
    end if;

    --Sum up the amounts to pay and make sure they're all valid
    t_TotalAmountsToRefund := 0;
    for c in (select ft.feeid,
    api.pkg_ColumnQuery.Value(api.pkg_simplesearch.ObjectByIndex('o_FeeTransactions',
    'TransactionID',
    ft.transactionid),
    'AmountToRefund') AmountToRefund
    from api.relationshipdefs a
    join api.Relationships b on b.FromObjectId = t_JobId
    and b.EndPointId = a.FromEndPointId
    join api.paymenttransactions p on p.paymentid =
    api.pkg_columnquery.value(b.ToObjectId,
    'PaymentId')
    join api.feetransactions ft on ft.transactionid =
    p.TransactionId
    where a.FromEndPointName = 'Payment') loop

    if c.AmountToRefund is null then
    api.pkg_errors.RaiseError(-20001,
    'Please enter the amount to refund for each fee.');
    elsif c.AmountToRefund < 0 then
    api.pkg_errors.RaiseError(-20001,
    'Each amount to refund must be positive.');
    end if;

    t_TotalAmountsToRefund := t_TotalAmountsToRefund + c.AmountToRefund;
    end loop;

    if t_TotalPayment <> t_TotalAmountsToRefund then
    api.pkg_errors.RaiseError(-20001,
    'Total Refund Amount (' ||
    to_char(t_TotalPayment,
    'FM$999,999,999,999,990.00') ||
    ') must equal to the sum of all the individual amounts (' ||
    to_char(t_TotalAmountsToRefund,
    'FM$999,999,999,999,990.00') || ').');
    end if;

    if t_ReceiptNumber is null then
    api.pkg_errors.RaiseError(-20001,
    'Please enter the ' || t_ReceiptNumberLabel ||
    ' from the POS receipt.');
    end if;

    end PrepareRefund;
     */

    /*--------------------------------------------------------------------------
    * CreateMiscFees() - Public
    * This procedure is intended to run from the Create Misc Fee Process
    *------------------------------------------------------------------------*/
    PROCEDURE createmiscfee(a_processid     udt_id,
                            a_asofdate      DATE,
                            a_jobid         udt_id,
                            a_objectdefname VARCHAR2)
    IS
        t_feeid                        udt_id;
        t_glaccountid                  udt_id;
        t_feeobjid                     udt_id;
        t_miscfeefeescheduleendpoint   udt_id;
        t_miscfeefeeschedulerelid      udt_id;
    BEGIN
        FOR i IN (  SELECT o.code,
                           o.description,
                           o.taxable,
                           o.objectid,
                           r.quantity,
                           r.amount                                                                      unitamount,
                           CASE WHEN r.quantity > 1 THEN ROUND(r.amount * r.quantity, 2) ELSE r.amount END feeamount
                      FROM query.r_createmiscfeemiscfeeschedule r
                           JOIN query.o_miscfeeschedule o
                           ON o.objectid = r.miscfeeschedobjectid
                     WHERE r.createmiscfeeprocessid = a_processid
                  ORDER BY o.code,
                           o.description,
                           r.quantity,
                           r.amount)
        LOOP
            BEGIN
                SELECT g.glaccountid
                  INTO t_glaccountid
                  FROM api.glaccounts g
                 WHERE g.glaccount = i.code;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    api.pkg_errors.raiseerror(-20000,
                                                 'Missing GL Account - '
                                              || i.code
                                              || '.');
            END;

            IF i.feeamount > 0 THEN
                sitespecific.pkg_fees.newfee(t_feeid,
                                             i.feeamount,
                                             i.description,
                                             t_glaccountid,
                                             a_jobid,
                                             NULL,
                                             t_feeobjid,
                                             FALSE);

                api.pkg_columnupdate.setvalue(t_feeobjid, 'Quantity', i.quantity);
                api.pkg_columnupdate.setvalue(t_feeobjid, 'UnitAmount', i.unitamount);

                -------------------------------------------------------------------------
                --create the rels to the miscfeeschedule from the fee

                t_miscfeefeescheduleendpoint   := api.pkg_configquery.endpointidforname('o_Fee', 'MiscFeeSchedule');

                t_miscfeefeeschedulerelid      :=
                    api.pkg_relationshipupdate.new(t_miscfeefeescheduleendpoint, t_feeobjid, i.objectid);
            END IF;
        END LOOP;
    END createmiscfee;

    /*--------------------------------------------------------------------------
    * CalculateTax() - Public
    * This procedure is intended to run from the Create Misc Fee Job
    * on the fees an payments Tab
    *------------------------------------------------------------------------*/
    PROCEDURE calculatetax(a_objectid udt_id, a_asofdate DATE)
    IS
        t_adjusttaxamount    NUMBER;
        t_existingfeeid      udt_id;
        t_description        VARCHAR2(250);
        t_feeamount          NUMBER;
        t_feeid              udt_id;
        t_feeobjid           udt_id;
        t_feetransactionid   udt_id;
        t_glaccountid        udt_id;
        t_taxamount          NUMBER;
        t_taxschedid         udt_id;
        t_relid              udt_id;
        t_feeobjectdefid     udt_id := api.pkg_configquery.objectdefidforname('o_Fee');
    BEGIN
        /* select sum(round(r.amount * r.quantity, 2))
        into t_Feeamount
        from query.j_miscellaneousfee mf
        join api.processes ap
        on ap.JobId = mf.JobId
        join query.r_Createmiscfeemiscfeeschedule r
        on r.CreateMiscFeeProcessId = ap.ProcessId
        join query.o_MiscFeeSchedule o
        on o.objectid = r.MiscFeeSchedObjectId
        where mf.JobId = a_Objectid
        and o.Taxable in 'Y';*/

        SELECT SUM(api.pkg_columnquery.numericvalue(reo.objectid, 'AmountForDisplay'))
          INTO t_feeamount
          FROM query.j_miscellaneousfee mf
               JOIN api.fees af
               ON af.jobid = mf.jobid
               JOIN api.registeredexternalobjects reo  -- RyanL: PIP Task 8.5
               ON reo.linkvalue = TO_CHAR(af.feeid)
              AND reo.objectdefid = t_feeobjectdefid
               JOIN query.r_miscfeefeeschedule rmfs
               ON rmfs.feeobjectid = reo.objectid
               JOIN query.o_miscfeeschedule o
               ON o.objectid = rmfs.miscfeescheduleobjectid
         WHERE mf.jobid = a_objectid
           AND o.taxable IN 'Y';

        -- Find the tax rate(s) and add to fee total for each tax

        SELECT glaccountid
          INTO t_glaccountid
          FROM api.glaccounts
         WHERE glaccount = 'TAX';

        FOR t
            IN (SELECT tr.rate taxrate, tr.description
                  FROM api.users u
                       JOIN api.relationships r1
                       ON (r1.toobjectid = u.userid
                       AND r1.endpointid = api.pkg_configquery.endpointidforname('o_Office', 'User'))
                       JOIN query.o_office ofc
                       ON ofc.objectid = r1.fromobjectid
                       JOIN api.relationships r2
                       ON (r2.fromobjectid = ofc.objectid
                       AND r2.endpointid = api.pkg_configquery.endpointidforname('o_Office', 'TaxRate'))
                       JOIN query.o_taxrate tr
                       ON tr.objectid = r2.toobjectid
                 WHERE u.userid = api.pkg_securityquery.effectiveuserid
                   AND tr.startdate =
                       (SELECT MAX(tr2.startdate)
                          FROM api.users u
                               JOIN api.relationships r1
                               ON (r1.toobjectid = u.userid
                               AND r1.endpointid = api.pkg_configquery.endpointidforname('o_Office', 'User'))
                               JOIN query.o_office ofc
                               ON ofc.objectid = r1.fromobjectid
                               JOIN api.relationships r2
                               ON (r2.fromobjectid = ofc.objectid
                               AND r2.endpointid = api.pkg_configquery.endpointidforname('o_Office', 'TaxRate'))
                               JOIN query.o_taxrate tr2
                               ON tr2.objectid = r2.toobjectid
                         WHERE tr2.objectid = r2.toobjectid
                           AND tr2.startdate <= SYSDATE
                           AND tr2.code = tr.code))
        LOOP
            BEGIN
                SELECT MAX(f.feeid)
                  INTO t_existingfeeid
                  FROM query.j_miscellaneousfee mf
                       JOIN api.fees f
                       ON f.jobid = mf.jobid
                 WHERE mf.jobid = a_objectid
                   AND f.description = t.description;  /*'%TAX%'
                and f.Quantity = t.TaxRate;*/
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    t_existingfeeid   := NULL;
            END;

            t_description   := t.description;

            t_taxamount     := ROUND(t_feeamount * t.taxrate, 2);

            IF t_taxamount > 0
           AND t_existingfeeid IS NOT NULL THEN
                --Get the current tax fee amount and calculate adjustment amount

                SELECT (t_taxamount - f.amountfordisplay), f.objectid
                  INTO t_adjusttaxamount, t_feeobjid
                  FROM query.o_fee f
                 WHERE f.objectid = api.pkg_simplesearch.objectbyindex('o_Fee', 'feeid', t_existingfeeid);

                t_feetransactionid   :=
                    api.pkg_feeupdate.adjust(t_existingfeeid,
                                             t_adjusttaxamount,
                                             t_description,
                                             SYSDATE);
            --If there is no current tax fees create the tax line item

            ELSIF t_taxamount > 0
              AND t_existingfeeid IS NULL THEN
                sitespecific.pkg_fees.newfee(t_feeid,
                                             t_taxamount,
                                             t_description,
                                             t_glaccountid,
                                             a_objectid,
                                             NULL,
                                             t_feeobjid,
                                             FALSE);

                -- Get the TAX Fee Schedule ID, and create a rel from it to the new fee
                t_taxschedid   := api.pkg_simplesearch.objectbyindex('o_MiscFeeSchedule', 'Code', 'TAX');

                IF t_taxschedid IS NULL THEN
                    api.pkg_errors.raiseerror(-20000, 'There is no Miscellaneous Fee Schedule with a Code of TAX.');
                END IF;

                t_relid        :=
                    api.pkg_relationshipupdate.new(api.pkg_configquery.endpointidforname('o_Fee', 'MiscFeeSchedule'),
                                                   t_feeobjid,
                                                   t_taxschedid);
            END IF;

            --Set the values to the Fee stored details of the TAX line item for display on the Misc Fee Job
            api.pkg_columnupdate.setvalue(t_feeobjid, 'Quantity', t.taxrate);

            api.pkg_columnupdate.setvalue(t_feeobjid, 'UnitAmount', t_feeamount);
        END LOOP;  -- tax items for this office and Misc Fee Item

        api.pkg_columnupdate.setvalue(a_objectid, 'CalculateTax', 'N');
    END calculatetax;

    /*--------------------------------------------------------------------------
    * NewReceiptPayments()
    *------------------------------------------------------------------------*/
    PROCEDURE newreceiptpayments(a_objectid udt_id, a_asofdate DATE, a_jobid udt_id)
    IS
        t_relid               udt_id;
        t_paymentendpointid   udt_id;
        t_rpobjectdefid       udt_id;
        t_jobdefid            udt_id;
        t_jobendpointid       udt_id;
        t_payments            udt_idlist;
        t_payment             PLS_INTEGER;
        t_cnt                 PLS_INTEGER;
    BEGIN
        BEGIN
            SELECT a.objectdefid
              INTO t_rpobjectdefid
              FROM api.objects a
             WHERE a.objectid = a_objectid;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                api.pkg_errors.raiseerror(-20001,
                                             'Cannot determine ObjectDefId for Receipt Payments ['
                                          || a_objectid
                                          || '].');
        END;

        BEGIN
            SELECT o.objectdefid
              INTO t_jobdefid
              FROM api.objects o
             WHERE o.objectid = a_jobid;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                api.pkg_errors.raiseerror(-20001,
                                             'Cannot determine ObjectDefId for Receipt Payments ['
                                          || a_objectid
                                          || '].');
        END;

        t_paymentendpointid   := api.pkg_configquery.endpointidforname(t_rpobjectdefid, 'Payment');

        IF t_paymentendpointid IS NULL THEN
            api.pkg_errors.raiseerror(-20001,
                                         'From object ['
                                      || t_rpobjectdefid
                                      || '] does not have a relationship named ''Payment''.');
        END IF;

        t_jobendpointid       := api.pkg_configquery.endpointidforname(t_jobdefid, 'Payment');

        IF t_jobendpointid IS NULL THEN
            api.pkg_errors.raiseerror(-20001,
                                         'From object ['
                                      || a_jobid
                                      || '] does not have a relationship named ''Payment''.');
        END IF;

        t_payments            := api.pkg_objectquery.relatedobjects(a_jobid, t_jobendpointid);

        FOR t_payment IN 1 .. t_payments.COUNT
        LOOP
            SELECT COUNT(*)
              INTO t_cnt
              FROM api.relationships r
             WHERE r.endpointid = api.pkg_configquery.endpointidforname(t_rpobjectdefid, 'Payment')
               AND r.toobjectid = t_payments(t_payment);

            IF api.pkg_columnquery.VALUE(t_payments(t_payment), 'IsReceipted') = 'Y' THEN
                t_cnt   := t_cnt + 1;
            ELSIF api.pkg_columnquery.VALUE(t_payments(t_payment), 'IsRefund') = 'Y' THEN
                t_cnt   := t_cnt + 1;
            ELSIF api.pkg_columnquery.VALUE(t_payments(t_payment), 'BatchPaymentId') IS NOT NULL THEN
                t_cnt   := t_cnt + 1;
            ELSIF api.pkg_columnquery.VALUE(t_payments(t_payment), 'IsVoidedFlag') = 'Y' THEN
                t_cnt   := t_cnt + 1;
            END IF;

            IF t_cnt = 0 THEN
                t_relid   := api.pkg_relationshipupdate.new(t_paymentendpointid, a_objectid, t_payments(t_payment));
            END IF;
        END LOOP;
    END newreceiptpayments;

    /* ----------------------------------------------------------------
    -- SetReceiptNumberOnPayment
    -----------------------------------------------------------------
    Procedure SetReceiptNumOnPayment(a_ObjectId udt_id
    ,a_AsOfDate date
    )is
    t_PayeeReference varchar2(60);

    begin

    for c in (select
    r.FromObjectId ReceiptProcId
    ,r.ToObjectId PaymentObjId
    ,p2.PaymentId
    ,p2.PayeeReference
    from
    query.o_payment p
    join api.relationships r on (r.ToObjectId = p.ObjectId
    and r.EndPointId = api.pkg_configquery.EndPointIdForName(
    'p_ReceiptPayments','Payment'))
    join api.payments p2 on p2.PaymentId = p.PaymentId
    where r.RelationshipId = a_ObjectId) loop

    t_PayeeReference := c.payeereference;

    api.pkg_paymentupdate.Modify(c.paymentid,t_PayeeReference, api.pkg_columnquery.Value(c.ReceiptProcId, 'ReceiptNumber'));

    end loop;

    end SetReceiptNumOnPayment;*/

    ----------------------------------------------------------------
    -- SetReceiptNumberOnPayment
    -----------------------------------------------------------------
    PROCEDURE setreceiptnumonpayment(a_objectid udt_id, a_asofdate DATE)
    IS
        t_payeereference   VARCHAR2(60);
    BEGIN
        FOR c IN (SELECT r.toobjectid paymentobjid, p.paymentid, p.payeereference
                    FROM query.o_payment p
                         JOIN api.relationships r
                         ON r.toobjectid = p.objectid
                        AND r.endpointid = api.pkg_configquery.endpointidforname('p_ReceiptPayments', 'Payment')
                   WHERE r.fromobjectid = a_objectid)
        LOOP
            t_payeereference   := c.payeereference;

            api.pkg_paymentupdate.modify(c.paymentid,
                                         t_payeereference,
                                         api.pkg_columnquery.VALUE(a_objectid, 'ReceiptNumber'));

            api.pkg_objectupdate.verify(c.paymentobjid);
        END LOOP;
    END setreceiptnumonpayment;

    ----------------------------------------------------------------------------------------------------
    -- RemReceiptNumFromPayment() -- PUBLIC
    -- Remove receipt number from payment.
    -- On Destructor of the relationship between o_Payment and p_ReceiptPayments
    -- set the receipt number on Payment to null.
    ----------------------------------------------------------------------------------------------------
    PROCEDURE remreceiptnumfrompayment(a_objectid udt_id, a_asofdate DATE)
    IS
        t_payeereference   VARCHAR2(60);
    BEGIN
        FOR c IN (SELECT r.toobjectid paymentobjid, p2.paymentid, p2.payeereference
                    FROM query.o_payment p
                         JOIN api.relationships r
                         ON (r.toobjectid = p.objectid
                         AND r.endpointid = api.pkg_configquery.endpointidforname('p_ReceiptPayments', 'Payment'))
                         JOIN api.payments p2
                         ON p2.paymentid = p.paymentid
                   WHERE r.relationshipid = a_objectid)
        LOOP
            t_payeereference   := c.payeereference;

            api.pkg_paymentupdate.modify(c.paymentid, t_payeereference, NULL);
        END LOOP;
    END remreceiptnumfrompayment;

    ----------------------------------------------------------------------------------------------------
    -- UpdatePayment() -- PUBLIC
    -- Update Payment so that all dup_ columns will be filled.
    ----------------------------------------------------------------------------------------------------

    ----------------------------------------------------------------------------------------------------
    -- GenerateReceiptNumber() -- PUBLIC
    -- This is for generating the receipt number for a receipt document type on created of that object.
    ----------------------------------------------------------------------------------------------------
    PROCEDURE generatereceiptnumber(a_objectid udt_id  --,
                                                     --a_AsOfDate date
                                                     )
    IS
        t_receiptnumber   VARCHAR2(40);
        t_sequenceid      udt_id;
    BEGIN
        api.pkg_logicaltransactionupdate.resettransaction;
        api.pkg_logicaltransactionupdate.starttransaction;

        IF api.pkg_columnquery.VALUE(a_objectid, 'ReceiptNumber') IS NULL
       AND api.pkg_columnquery.VALUE(a_objectid, 'ObjectDefName') != 'p_VoidPayment' THEN
            BEGIN
                SELECT s.sequenceid
                  INTO t_sequenceid
                  FROM api.sequences s
                 WHERE s.description = 'Receipt Number';
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    api.pkg_errors.raiseerror(-20000, 'Receipt Number sequence not found.');
            END;

            t_receiptnumber   := api.pkg_utils.generateexternalfilenum('[0000000]', t_sequenceid);

            /* select sitespecific.receiptnumber_s.nextval
            into t_ReceiptNumber
            from dual;*/

            api.pkg_columnupdate.setvalue(a_objectid, 'ReceiptNumber', t_receiptnumber);
        END IF;

        pkg_debug.putline('Calling api.pkg_logicaltransactionupdate.EndTransaction()');
        pkg_debug.putline(   ' Unit: '
                          || $$plsql_unit);
        pkg_debug.putline(   ' Line number: '
                          || $$plsql_line);
        api.pkg_logicaltransactionupdate.endtransaction;
        pkg_debug.putline('Returned from EndTransaction()');
        COMMIT;
    END generatereceiptnumber;

    /*-------------------------------------------------------------------------------
    * Procedure CreateFeeSchedule() Used on creation of o_FeeSchedule.
    *-----------------------------------------------------------------------------*/

    PROCEDURE createfeeschedule(a_objectid     IN OUT NUMBER,
                                a_gallonagerange      VARCHAR2,
                                a_numberofmonthslicensed VARCHAR2,
                                a_populationrange     VARCHAR2,
                                a_primaryamount       NUMBER,
                                a_secondaryamount     NUMBER,
                                a_description         VARCHAR2,
                                a_effectivedate       DATE,
                                a_branchamount        NUMBER,
                                a_feeactivity         VARCHAR2,
                                a_surchargecode       VARCHAR2,
                                a_licensetypecode     VARCHAR2,
                                a_otherfeecode        VARCHAR2,
                                a_inactive            CHAR DEFAULT 'N',
                                a_feetier             VARCHAR2,  -- 03/29/2019 TJL WO 17566
                                a_originalfee         NUMBER,
                                a_originalsecondaryfee NUMBER)  -- 04/17/2019 TJL WO 17566
    IS
        t_surchargecount   NUMBER;
        t_ltcount          NUMBER;
    BEGIN
        SELECT COUNT(f.objectid)
          INTO t_surchargecount
          FROM sitespecific.feesurchargeschedule_t f
         WHERE f.surchargecode = a_surchargecode;

        SELECT COUNT(x.objectid)
          INTO t_ltcount
          FROM TABLE(
                   CAST(
                       api.pkg_simplesearch.castableobjectsbyindex('o_LicenseTypeCategory',
                                                                   'LicenseTypeCode',
                                                                   a_licensetypecode) AS api.udt_objectlist)) x;

        -- query.o_licensetypecategory ltc
        -- where ltc.LicenseTypeCode = a_LicenseTypeCode;

        IF t_surchargecount = 0
       AND a_surchargecode IS NOT NULL THEN
            api.pkg_errors.raiseerror(-20000,
                                      'The Surcharge Code must equal a Fee Surcharge Schedule''s Surcharge Code.');
        ELSIF t_ltcount = 0
          AND a_licensetypecode IS NOT NULL THEN
            api.pkg_errors.raiseerror(
                -20000,
                'The License Type Code must equal a License Type Category''s License Type Code.');
        ELSE
            NULL;
        END IF;

        INSERT INTO sitespecific.feeschedule_t(objectid,
                                               gallonagerange,
                                               numberofmonthslicensed,
                                               populationrange,
                                               primaryamount,
                                               secondaryamount,
                                               description,
                                               effectivedate,
                                               branchamount,
                                               feeactivity,
                                               surchargecode,
                                               licensetypecode,
                                               otherfeecode,
                                               inactive,
                                               originalfee,
                                               feetier,  -- 03/29/2019 TJL WO 17566
                                               originalsecondaryfee)  -- 04/17/2019 TJL WO 17566
             VALUES (a_objectid,
                     a_gallonagerange,
                     a_numberofmonthslicensed,
                     a_populationrange,
                     a_primaryamount,
                     a_secondaryamount,
                     a_description,
                     a_effectivedate,
                     a_branchamount,
                     a_feeactivity,
                     a_surchargecode,
                     a_licensetypecode,
                     a_otherfeecode,
                     NVL(a_inactive, 'N'),
                     a_originalfee,
                     a_feetier,  -- 03/29/2019 TJL WO 17566
                     a_originalsecondaryfee);  -- 04/17/2019 TJL WO 17566
    END createfeeschedule;

    /*-------------------------------------------------------------------------------
    * Procedure ModifyFeeSchedule() Used on creation of o_FeeSchedule.
    *-----------------------------------------------------------------------------*/

    PROCEDURE modifyfeeschedule(a_objectid     IN OUT NUMBER,
                                a_gallonagerange      VARCHAR2,
                                a_numberofmonthslicensed VARCHAR2,
                                a_populationrange     VARCHAR2,
                                a_primaryamount       NUMBER,
                                a_secondaryamount     NUMBER,
                                a_description         VARCHAR2,
                                a_effectivedate       DATE,
                                a_branchamount        NUMBER,
                                a_feeactivity         VARCHAR2,
                                a_surchargecode       VARCHAR2,
                                a_licensetypecode     VARCHAR2,
                                a_otherfeecode        VARCHAR2,
                                a_inactive            CHAR DEFAULT 'N',
                                a_feetier             VARCHAR2,  -- 03/29/2019 TJL WO 17566
                                a_originalfee         NUMBER,
                                a_originalsecondaryfee NUMBER)  -- 04/17/2019 TJL WO 17566
    IS
        t_surchargecount   NUMBER;
        t_ltcount          NUMBER;
    BEGIN
        SELECT COUNT(f.objectid)
          INTO t_surchargecount
          FROM sitespecific.feesurchargeschedule_t f
         WHERE f.surchargecode = a_surchargecode;

        SELECT COUNT(x.objectid)
          INTO t_ltcount
          FROM TABLE(
                   CAST(
                       api.pkg_simplesearch.castableobjectsbyindex('o_LicenseTypeCategory',
                                                                   'LicenseTypeCode',
                                                                   a_licensetypecode) AS api.udt_objectlist)) x;

        -- from query.o_licensetypecategory ltc
        -- where ltc.LicenseTypeCode = a_LicenseTypeCode;

        IF t_surchargecount = 0
       AND a_surchargecode IS NOT NULL THEN
            api.pkg_errors.raiseerror(-20000,
                                      'The Surcharge Code must equal a Fee Surcharge Schedule''s Surcharge Code.');
        ELSIF t_ltcount = 0
          AND a_licensetypecode IS NOT NULL THEN
            api.pkg_errors.raiseerror(
                -20000,
                'The License Type Code must equal a License Type Category''s License Type Code.');
        ELSE
            NULL;
        END IF;

        UPDATE sitespecific.feeschedule_t t
           SET t.gallonagerange           = a_gallonagerange,
               t.numberofmonthslicensed   = a_numberofmonthslicensed,
               t.populationrange          = a_populationrange,
               t.primaryamount            = a_primaryamount,
               t.secondaryamount          = a_secondaryamount,
               t.description              = a_description,
               t.effectivedate            = a_effectivedate,
               t.branchamount             = a_branchamount,
               t.feeactivity              = a_feeactivity,
               t.surchargecode            = a_surchargecode,
               t.licensetypecode          = a_licensetypecode,
               t.otherfeecode             = a_otherfeecode,
               t.inactive                 = a_inactive,
               t.originalfee              = a_originalfee,
               t.feetier                  = a_feetier,  -- 03/29/2019 TJL WO 17566
               t.originalsecondaryfee     = a_originalsecondaryfee  -- 04/17/2019 TJL WO 17566
         WHERE t.objectid = a_objectid;
    END modifyfeeschedule;

    ----------------------------------------------------------------------------------------------------
    -- CreateSimpleFee() -- PUBLIC
    ----------------------------------------------------------------------------------------------------
    PROCEDURE createsimplefee(a_objectid      NUMBER,
                              a_asofdate      DATE,
                              a_jobid         NUMBER,
                              a_feeactivity   VARCHAR2,
                              a_count         NUMBER,
                              a_ltcode        VARCHAR2 DEFAULT NULL,
                              a_poprange      VARCHAR2 DEFAULT NULL)
    IS
        t_description   VARCHAR2(100);
        t_amount        NUMBER;
        t_feeid         NUMBER;
        t_feeobjid      NUMBER;
        t_feeschedid    NUMBER;
        t_glaccountid   NUMBER;
        t_relid         NUMBER;
    BEGIN
        --Get Fee Amount and Fee ScheduleId
        sitespecific.pkg_fees.getltfeeamount(a_jobid,
                                             SYSDATE,
                                             a_feeactivity,
                                             NULL,
                                             a_ltcode,
                                             NULL,
                                             NULL,
                                             NULL,
                                             a_poprange,
                                             'P',
                                             NULL,
                                             a_asofdate,
                                             t_amount,
                                             t_feeschedid);

        --Raise error if there is no Primary Amount returned by GetLTFeeAmount
        IF t_amount IS NULL
        OR t_amount < 0 THEN
            api.pkg_errors.raiseerror(-20000,
                                         'There is no currently effective '
                                      || a_feeactivity
                                      || ' License Fee Schedule that has a Primary Amount that is $0.00 or greater.');
        END IF;

        --Raise error if the Count is equal or below 0
        IF a_count <= 0 THEN
            api.pkg_errors.raiseerror(-20000, 'The Count must be greater than 0.');
        END IF;

        --Fee amount * count
        t_amount        := (t_amount * NVL(a_count, 1));

        --Get GLAccountId
        SELECT g.glaccountid
          INTO t_glaccountid
          FROM api.glaccounts g
         WHERE g.glaccount = a_feeactivity;

        --Set Description
        t_description   := api.pkg_columnquery.VALUE(t_feeschedid, 'ProcedureDescription');

        --Create Fee
        sitespecific.pkg_fees.newfee(t_feeid,
                                     t_amount,
                                     t_description,
                                     t_glaccountid,
                                     a_jobid,
                                     NULL,
                                     t_feeobjid);

        --Relate Fee to Fee Schedule
        t_relid         :=
            api.pkg_relationshipupdate.new(api.pkg_configquery.endpointidforname('o_Fee', 'LicenseFeeSchedule'),
                                           t_feeobjid,
                                           t_feeschedid);

        -- Set the Count on the Fee to the Count provided.
        api.pkg_columnupdate.setvalue(t_relid, 'SecondaryCount', NVL(a_count, 1));
    --Set the IsMaster Column to Y
    --api.pkg_Columnupdate.setvalue(t_RelId, 'IsMaster', 'Y');

    END createsimplefee;

    ----------------------------------------------------------------------------------------------------
    -- CreateAdjustSimpleFee() -- PUBLIC
    -- This is the same as CreateSimpleFee, except that if a fee with the desired Fee Activity already
    -- exists, that fee will be adjusted instead of the procedure creating a new one. NOTE: This adjust-
    -- ment is not the same as the CheckExistingFees procedure. This will adjust the amount back to the
    -- original amount on the Fee Schedule (plus any unpaid amount from before) instead of only
    -- adjusting to match diferences between the Fee Schedule amount and the Amount+AdjustedAmount.
    ----------------------------------------------------------------------------------------------------
    PROCEDURE createadjustsimplefee(a_objectid      NUMBER,
                                    a_asofdate      DATE,
                                    a_jobid         NUMBER,
                                    a_feeactivity   VARCHAR2,
                                    a_count         NUMBER)
    IS
        t_amount           NUMBER;
        t_createfee        VARCHAR2(1);
        t_feeid            udt_id;
        t_feeobjid         udt_id;
        t_feeschedid       udt_id;
        t_glaccountid      NUMBER;
        t_relid            udt_id;
        t_transid          udt_id;
        t_description      VARCHAR2(100);
        t_count            NUMBER;
        t_feeobjectdefid   udt_id := api.pkg_configquery.objectdefidforname('o_Fee');
    BEGIN
        -- Set t_CreateFee to Y
        t_createfee   := 'Y';

        --Get Fee Amount and Fee ScheduleId
        sitespecific.pkg_fees.getltfeeamount(a_jobid,
                                             SYSDATE,
                                             a_feeactivity,
                                             NULL,
                                             NULL,
                                             NULL,
                                             NULL,
                                             NULL,
                                             NULL,
                                             'P',
                                             NULL,
                                             a_asofdate,
                                             t_amount,
                                             t_feeschedid);

        --Raise error if there is no Primary Amount returned by GetLTFeeAmount
        IF t_amount IS NULL
        OR t_amount < 0 THEN
            api.pkg_errors.raiseerror(-20000,
                                         'There is no currently effective '
                                      || a_feeactivity
                                      || ' License Fee Schedule that has a Primary Amount that is $0.00 or greater.');
        END IF;

        --Raise error if the Count is equal or below 0
        IF a_count <= 0 THEN
            api.pkg_errors.raiseerror(-20000, 'The Count must be greater than 0.');
        END IF;

        --Fee amount * count
        t_amount      := (t_amount * NVL(a_count, 1));

        --Get GLAccountId
        SELECT g.glaccountid
          INTO t_glaccountid
          FROM api.glaccounts g
         WHERE g.glaccount = a_feeactivity;

        -- For each Fee Schedule that is already related through a fee to the Application
        -- RyanL: Changed the select clause to be a subselect for performance (PIP Task 8.5)
        FOR c IN (SELECT (  f.amount
                          + NVL((SELECT SUM(amount)
                                   FROM api.feetransactions ft
                                  WHERE ft.feeid = f.feeid
                                    AND ft.transactiontype = 'Adj'),
                                0))
                             amount,
                         f.feeid
                             feeid,
                         reo.objectid
                             feeobjectid,
                         ffs.relationshipid,
                         ffs.secondarycount,
                         fs.feeactivity,
                         fs.objectid
                             feescheduleid
                    FROM api.jobs j
                         JOIN api.fees f
                         ON f.jobid = j.jobid
                         JOIN api.registeredexternalobjects reo  -- RyanL: PIP Task 8.5
                         ON reo.linkvalue = TO_CHAR(f.feeid)
                        AND reo.objectdefid = t_feeobjectdefid
                         JOIN query.r_feelicensefeeschedule ffs
                         ON ffs.feeobjectid = reo.objectid
                         JOIN sitespecific.feeschedule_t fs
                         ON fs.objectid = ffs.licensefeescheduleid
                   WHERE j.jobid = a_jobid)
        LOOP
            -- If t_PFeeAmount = the Fee Schedule Id
            IF c.feeactivity = a_feeactivity THEN
                -- Set a_CreateFee to 'N'
                t_createfee     := 'N';

                --Get the Description for the fee
                t_description   := api.pkg_columnquery.VALUE(c.feescheduleid, 'ProcedureDescription');

                -- Adjust the fee
                t_feeid         :=
                    api.pkg_feeupdate.adjust(c.feeid,
                                             ROUND(t_amount),  --Round the Fee Amount
                                             t_description,  --a_FeeActivity,
                                             SYSDATE);

                -- Register the Fee Transaction External Object
                t_transid       := api.pkg_objectupdate.registerexternalobject('o_FeeTransactions', t_feeid);

                -- Drop the old relationship to from the Fee to the Fee Schedule
                api.pkg_relationshipupdate.remove(c.relationshipid);

                -- Create a new relationship from the Fee to the Fee Schedule
                t_relid         :=
                    api.pkg_relationshipupdate.new(
                        api.pkg_configquery.endpointidforname('o_Fee', 'LicenseFeeSchedule'),
                        c.feeobjectid,
                        t_feeschedid);
                -- Take the previous and add it to the new count.
                t_count         := c.secondarycount + NVL(a_count, 1);

                -- Set the Count on the Fee to the Count provided.
                api.pkg_columnupdate.setvalue(t_relid, 'SecondaryCount', t_count);
            -- End If
            END IF;
        -- End Loop
        END LOOP;

        -- If t_CreateFee = 'Y'
        IF t_createfee = 'Y' THEN
            --Get the Description
            t_description   := api.pkg_columnquery.VALUE(t_feeschedid, 'ProcedureDescription');
            -- Then Create Fee
            sitespecific.pkg_fees.newfee(t_feeid,
                                         t_amount,
                                         t_description,  -- a_FeeActivity,
                                         t_glaccountid,
                                         a_jobid,
                                         NULL,
                                         t_feeobjid);

            --Relate Fee to Fee Schedule
            t_relid         :=
                api.pkg_relationshipupdate.new(api.pkg_configquery.endpointidforname('o_Fee', 'LicenseFeeSchedule'),
                                               t_feeobjid,
                                               t_feeschedid);
            -- Set the Count on the Fee to the Count provided.
            api.pkg_columnupdate.setvalue(t_relid, 'SecondaryCount', (NVL(a_count, 1) - 1));
        END IF;
    END createadjustsimplefee;

    ----------------------------------------------------------------------------------------------------
    -- CreateProcessPOICFee() -- PUBLIC
    -- Charges fee for Issue Temporary Permit Permit process
    ----------------------------------------------------------------------------------------------------
    PROCEDURE createprocesspoicfee(a_objectid         udt_id,
                                   a_asofdate         DATE,
                                   a_jobid            NUMBER,
                                   a_poicfee          NUMBER,
                                   a_ltcode           VARCHAR2,
                                   a_feeid        OUT NUMBER)
    IS
        t_description   VARCHAR2(100);
        t_feeobjid      NUMBER;
        t_glaccountid   NUMBER;
        t_poicschedid   NUMBER;
        t_relid         NUMBER;
    BEGIN
        --Get POIC feeschedule id
        SELECT max(objectid)
        INTO t_poicschedid
        FROM (
          -- Determine the latest fee schedule by ordering by Logical Transaction
          SELECT o.logicaltransactionid, o.objectid
            FROM sitespecific.feeschedule_t t
            JOIN api.objects o
              ON t.objectid = o.objectid
           WHERE t.feeactivity = 'POIC'
             AND (t.licensetypecode = a_ltcode
                  OR (t.licensetypecode IS NULL
                  AND a_ltcode IS NULL))
             -- Get the latest Fee Schedule Date for the provided license code and/or where Fee Activity is POIC
             AND t.effectivedate =
                 (SELECT MAX(q.effectivedate)
                    FROM sitespecific.feeschedule_t q
                   WHERE (q.licensetypecode = a_ltcode
                          OR (q.licensetypecode IS NULL
                          AND a_ltcode IS NULL))
                     AND q.feeactivity = 'POIC')
           GROUP BY o.logicaltransactionid, o.objectid
           HAVING o.logicaltransactionid = max(o.logicaltransactionid)
         );

        --raise error when there is no POIC feeschedule record.
        IF t_poicschedid IS NULL THEN
            BEGIN
                SELECT max(objectid)
                INTO t_poicschedid
                FROM (
                    SELECT o.logicaltransactionid, o.objectid
                      FROM sitespecific.feeschedule_t t
                      JOIN api.objects o
                        ON t.objectid = o.objectid
                     WHERE t.feeactivity = 'POIC'
                       AND t.licensetypecode IS NULL
                       AND t.effectivedate = (SELECT MAX(q.effectivedate)
                                            FROM sitespecific.feeschedule_t q
                                           WHERE q.licensetypecode IS NULL
                                             AND q.feeactivity = 'POIC')
                 GROUP BY o.logicaltransactionid, o.objectid
                 HAVING o.logicaltransactionid = max(o.logicaltransactionid));
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    api.pkg_errors.raiseerror(
                        -20000,
                        'There is no POIC License Fee Schedule record where License Type is NULL.');
            END;
        END IF;

        --Get GLAccountId
        SELECT g.glaccountid
          INTO t_glaccountid
          FROM api.glaccounts g
         WHERE g.glaccount = 'POIC';

        --Set Description
        t_description   := api.pkg_columnquery.VALUE(t_poicschedid, 'ProcedureDescription');

        --Create Fee
        sitespecific.pkg_fees.newfee(a_feeid,
                                     a_poicfee,
                                     t_description,
                                     t_glaccountid,
                                     a_jobid,
                                     NULL,
                                     t_feeobjid,
                                     FALSE);

        -- Relate Fee to Fee Schedule
        t_relid         :=
            api.pkg_relationshipupdate.new(api.pkg_configquery.endpointidforname('o_Fee', 'LicenseFeeSchedule'),
                                           t_feeobjid,
                                           t_poicschedid);

        api.pkg_columnupdate.setvalue(t_poicschedid, 'EarnedOn', 'PAYMENT');
    END createprocesspoicfee;

    ----------------------------------------------------------------------------------------------------
    -- CreateRenewalFees() -- PUBLIC
    -- Called from Create Renewal/Penalty Fees process on License Type job, or from the License Batch (Batch types Send 1st
    -- Renewal Letter, 50% Penalty, 100% Penalty).
    -- RunType parameter should be B for batchtype (errors are not raised, unless a feeschedule record does not exists).
    -- For RunType B, ExpireLT is passed out Y when a REN100 fee is created.
    ----------------------------------------------------------------------------------------------------
    PROCEDURE createrenewalfees(a_objectid         NUMBER,
                                a_asofdate         DATE,
                                a_jobid            NUMBER,
                                a_expirationdate   DATE,
                                a_renpenfeetype    VARCHAR2,
                                a_runtype          VARCHAR2,
                                a_expirelt     OUT VARCHAR2)
    IS
        t_additionalmilliongallons   NUMBER;
        t_adjustid                   NUMBER;
        t_checkexists                VARCHAR(30);
        t_checkexistsnice            VARCHAR(50);
        t_description                VARCHAR2(50);
        t_existingfeeid              NUMBER;
        t_expirationdate             DATE;
        t_expiringyear               NUMBER;
        t_feeactivity                VARCHAR2(6);
        t_feeid                      NUMBER;
        t_feeobjid                   NUMBER;
        t_feepaid                    VARCHAR(1);
        t_feeschedid                 NUMBER;
        t_feetransobjid              NUMBER;
        t_fssearch                   VARCHAR2(6);
        t_gallonagerange             VARCHAR2(20);
        t_glaccountid                NUMBER;
        t_ismaster                   VARCHAR2(1);
        t_ltcode                     VARCHAR2(2);
        t_numberofmonthslicensed     VARCHAR2(10);
        t_originalamount             NUMBER;
        t_paidcount                  NUMBER;
        t_pfeeamount                 NUMBER;
        t_populationapplies          VARCHAR2(1);
        t_populationrange            VARCHAR2(30);
        t_ppriorcount                NUMBER;
        t_primarycount               NUMBER;
        t_primissec                  VARCHAR2(1);
        t_primorbranch               VARCHAR2(1);
        t_priorfeeactivity           VARCHAR2(15);
        t_priorfeeactivitynice       VARCHAR(30);
        t_relid                      NUMBER;
        t_renexpdate                 DATE;
        t_sadjustid                  NUMBER;
        t_sdescription               VARCHAR2(50);
        t_seasonal                   VARCHAR2(1);
        t_seasonstartmonth           VARCHAR2(2);
        t_sexistingfeeid             NUMBER;
        t_sfeeamount                 NUMBER;
        t_sfeeid                     NUMBER;
        t_sfeeobjid                  NUMBER;
        t_sfeescheduleid             NUMBER;
        t_snumberofmonthslicensed    VARCHAR2(10);
        t_spopulationrange           VARCHAR2(30);
        t_spriorcount                NUMBER;
        t_totalcount                 NUMBER;
        t_feeobjectdefid             udt_id := api.pkg_configquery.objectdefidforname('o_Fee');
        t_skip                       VARCHAR2(1) := 'N';  -- 05/29/2020 TJL WO 8924
    BEGIN
        t_paidcount     := 0;
        t_totalcount    := 0;
        t_ppriorcount   := 0;
        t_spriorcount   := 0;

        --Get Necessary License Type information.
        SELECT lt.gallonagerange,
               lt.numberofmonthslicensedfeecode,
               lt.licensetypecode,
               CASE WHEN lt.isbranchpy = 'Y' THEN 'B' ELSE 'P' END,
               ltc.populationapplies,
               lt.additionalmilliongallons,
               CASE
                   WHEN lt.isbranchpy = 'Y' THEN 1
                   WHEN lt.additionalmilliongallons IS NOT NULL THEN lt.additionalmilliongallons  -- +1 is removed by Pawanto fix issue5323 on 5/20/2015
                   WHEN lt.primarycount IS NOT NULL THEN lt.primarycount
                   ELSE 0
               END
                   primarycount,
               ltc.seasonalmonthsapply
          INTO t_gallonagerange,
               t_numberofmonthslicensed,
               t_ltcode,
               t_primorbranch,
               t_populationapplies,
               t_additionalmilliongallons,
               t_primarycount,
               t_seasonal
          FROM query.j_licensetype lt
               JOIN api.relationships r
               ON r.fromobjectid = lt.objectid
               JOIN query.o_licensetypecategory ltc
               ON ltc.objectid = r.toobjectid
         WHERE lt.objectid = a_jobid
           AND r.endpointid = api.pkg_configquery.endpointidforname('j_LicenseType', 'LicTypeCatPrimary');

        --If not a batch, set t_renewaldate to process RenewalDate (otherwise leave as LicenseType RenewalDate.
        -- if a_RunType <> 'B' or a_RunType is null
        -- then t_RenewalDate := api.pkg_columnquery.DateValue(a_objectid, 'RenewalDate');
        -- end if;

        --If Population Applies, get population range for LT.
        IF t_populationapplies = 'Y'
        OR t_ltcode IN (50, 51, 52) THEN
            SELECT ad.populationrange
              INTO t_populationrange
              FROM query.j_licensetype lt
                   JOIN query.r_licenselicensetype rlt
                   ON rlt.licensetypejobid = lt.objectid
                   JOIN query.j_license l
                   ON l.jobid = rlt.licensejobid
                   JOIN query.r_licenseaddrpremises lap
                   ON lap.licensejobid = l.jobid
                   JOIN query.o_address ad
                   ON ad.objectid = lap.premisesobjectid
             WHERE lt.jobid = a_jobid;
        END IF;

        --Set t_FeeActivityType, for Renewal, Set RENFeeCreated to Y on job.
        IF a_renpenfeetype = 'Renewal' THEN
            t_feeactivity       := 'REN';
            t_checkexists       := 'REN.REN50.REN100.';
            t_checkexistsnice   := 'Renewal or Penalty';

            --Only set RENfeecreated when it is not a Batch run (it exists for referencing by the batch process).
            IF a_runtype <> 'B'
            OR a_runtype IS NULL THEN
                api.pkg_columnupdate.setvalue(a_jobid, 'RENFeeCreated', 'Y');
            END IF;
        ELSIF a_renpenfeetype = '50% Penalty' THEN
            t_feeactivity            := 'REN50';
            t_checkexists            := 'REN50.REN100.';
            t_checkexistsnice        := '50% Penalty or 100% Penalty';
            t_priorfeeactivity       := 'REN.';
            t_priorfeeactivitynice   := 'Renewal';
            t_fssearch               := 'REN';
        ELSIF a_renpenfeetype = '100% Penalty' THEN
            t_feeactivity            := 'REN100';
            t_checkexists            := 'REN100.';
            t_checkexistsnice        := '100% Penalty';
            t_priorfeeactivity       := 'REN.REN50.';
            t_priorfeeactivitynice   := 'Renewal or 50% Penalty';
            t_fssearch               := 'REN50';
        END IF;

        -- Set t_ExpirationDate to a_ExpirationDate. If a_ExpirationDate is null, use nvls
        t_expirationdate   :=
            NVL(NVL(a_expirationdate, api.pkg_columnquery.datevalue(a_jobid, 'ExpirationDate')), SYSDATE);

        -- **********************************************************************
        -- 05/23/2018 TJL WO8517 Change how expiration date is generated for seasonals
        -- *********************************************************************
        -- Get Seasonal Info
        IF t_seasonal = 'Y' THEN
            t_renexpdate       :=
                  TO_DATE(
                         LPAD(api.pkg_columnquery.VALUE(a_jobid, 'SeasonStartMonthnumber'), 2, '00')
                      || '/01/'
                      || CASE
                             WHEN (  TO_NUMBER(
                                         TO_CHAR(api.pkg_columnquery.datevalue(a_jobid, 'dup_ExpirationDate'), 'MM'))
                                   - (api.pkg_columnquery.numericvalue(a_jobid, 'NumberOfMonthsLicensedNumber') + 1)) <  -- 01/09/2019 TJL 16435 removed = from test
                                  0 THEN
                                 NVL(api.pkg_columnquery.numericvalue(a_jobid, 'ExpiringYear'), 9999)
                             ELSE
                                 NVL(api.pkg_columnquery.numericvalue(a_jobid, 'ExpiringYear') + 1, '9999')
                         END,
                      'MM/DD/YYYY')
                - 1;
            t_expirationdate   := t_renexpdate;
        ELSE
            t_renexpdate   := t_expirationdate;
        END IF;

        -- 05/29/2020 TJL WO 8924 Now that a fee that has been paid can have a penalty applied to it since one of
        --  the renewal fee was not paid, added checking to see if all fees have been paid for a license. So no
        --  penalties will be created if a license is run through penalty process that have been paid.  It is
        --  possible if fees are paid but license not yet issue could go through the penalty process.
        IF t_feeactivity <> 'REN' THEN
            SELECT CASE WHEN SUM(totalowing) > 0 THEN 'N' ELSE 'Y' END
              INTO t_skip
              FROM (  -- check for any secondary owing any fees
                    SELECT api.pkg_columnquery.numericvalue(reo.objectid, 'TotalOwing') totalowing
                      FROM api.fees f
                           JOIN api.registeredexternalobjects reo
                           ON reo.linkvalue = TO_CHAR(f.feeid)
                          AND reo.objectdefid = t_feeobjectdefid
                           JOIN sitespecific.feeschedule_t fs
                           ON fs.objectid = sitespecific.pkg_fees.getlicfeeschedulobjid(f.feeid)
                           JOIN query.r_licensetypeltcatsecondary sltc
                           ON (sltc.licensetypejobid = f.jobid)
                           JOIN query.o_licensetypecategory ltc
                           ON (sltc.licensetypecategoryobjectid = ltc.objectid
                           AND ltc.licensetypecode = fs.licensetypecode)
                     WHERE f.jobid = a_jobid
                       AND sltc.status IN ('ACTIVE',
                                           'SURRENDERED',
                                           'RULE 64B',
                                           'SLMS HOLD',
                                           'SUSPENDED')  --     and sltc.status is null
                       AND t_priorfeeactivity LIKE
                                  '%'
                               || fs.feeactivity
                               || '.'
                               || '%'
                       AND (f.transactiondate, fs.licensetypecode) =
                           (  SELECT MAX(f2.transactiondate), fs2.licensetypecode
                                FROM api.fees f2
                                     JOIN api.registeredexternalobjects reo
                                     ON reo.linkvalue = TO_CHAR(f2.feeid)
                                    AND reo.objectdefid = t_feeobjectdefid
                                     JOIN sitespecific.feeschedule_t fs2
                                     ON fs2.objectid = sitespecific.pkg_fees.getlicfeeschedulobjid(f2.feeid)
                               WHERE f.jobid = f2.jobid
                                 AND fs.licensetypecode = fs2.licensetypecode
                                 AND fs2.feeactivity = fs.feeactivity
                            GROUP BY fs2.licensetypecode)
                    UNION
                    -- checking primary owing any fees
                    SELECT api.pkg_columnquery.numericvalue(reo.objectid, 'TotalOwing') totalowing
                      FROM api.fees f
                           JOIN api.registeredexternalobjects reo
                           ON reo.linkvalue = TO_CHAR(f.feeid)
                          AND reo.objectdefid = t_feeobjectdefid
                           JOIN sitespecific.feeschedule_t fs
                           ON fs.objectid = sitespecific.pkg_fees.getlicfeeschedulobjid(f.feeid)
                           JOIN api.relationships r
                           ON (r.endpointid =
                               api.pkg_configquery.endpointidforname('j_LicenseType', 'LicTypeCatPrimary')
                           AND r.fromobjectid = f.jobid
                           AND fs.licensetypecode = api.pkg_columnquery.VALUE(r.toobjectid, 'LicenseTypeCode'))
                     WHERE f.jobid = a_jobid
                       AND t_priorfeeactivity LIKE
                                  '%'
                               || fs.feeactivity
                               || '.'
                               || '%'
                       AND (f.transactiondate, fs.licensetypecode) =
                           (  SELECT MAX(f2.transactiondate), fs2.licensetypecode
                                FROM api.fees f2
                                     JOIN api.registeredexternalobjects reo  -- RyanL: PIP Task 8.5
                                     ON reo.linkvalue = TO_CHAR(f2.feeid)
                                    AND reo.objectdefid = t_feeobjectdefid
                                     JOIN sitespecific.feeschedule_t fs2
                                     ON fs2.objectid = sitespecific.pkg_fees.getlicfeeschedulobjid(f.feeid)
                               WHERE f.jobid = f2.jobid
                                 AND fs.licensetypecode = fs2.licensetypecode
                                 AND fs2.feeactivity = fs.feeactivity
                            GROUP BY fs2.licensetypecode));
        END IF;

        -- 05/29/2020 TJL WO 8924
        IF (NVL(t_skip, 'N') = 'N') THEN
            --If there is already a REN% fee, use the GallonageRange, NumberOfMonthsLicensed, and PopulationRange from the feeschedule record related to that fee.
            IF t_feeactivity <> 'REN' THEN
                BEGIN
                    SELECT feeid
                      INTO t_existingfeeid
                      FROM (  SELECT f.feeid
                                FROM api.fees f
                                     JOIN api.registeredexternalobjects reo  -- RyanL: PIP Task 8.5
                                     ON reo.linkvalue = TO_CHAR(f.feeid)
                                    AND reo.objectdefid = t_feeobjectdefid
                                     JOIN sitespecific.feeschedule_t fs
                                     ON fs.objectid = sitespecific.pkg_fees.getlicfeeschedulobjid(f.feeid)
                               WHERE f.jobid = a_jobid
                                 AND fs.feeactivity = t_fssearch
                                 AND fs.licensetypecode = t_ltcode
                                 AND NVL(
                                         api.pkg_columnquery.datevalue(reo.objectid, 'RENExpirationDate'),
                                         NVL(
                                             DECODE(
                                                 SUBSTR(fs.description, -1),
                                                 '9', TO_DATE(  -- Final Date
                                                             TO_CHAR(  -- Day of month
                                                                 LAST_DAY(
                                                                        '01-'
                                                                     || TO_CHAR(
                                                                            LAST_DAY(
                                                                                api.pkg_columnquery.datevalue(
                                                                                    a_jobid,
                                                                                    'ExpirationDate')),
                                                                            'MON')
                                                                     || '-2009'),
                                                                 'DD')  -- End Day of month
                                                          || '-'
                                                          || TO_CHAR(
                                                                 api.pkg_columnquery.datevalue(a_jobid,
                                                                                               'ExpirationDate'),
                                                                 'MON')  -- Month
                                                          || '-2009'  -- Year
                                                                    ),  -- final date
                                                 'A', TO_DATE(  -- Final Date
                                                             TO_CHAR(  -- Day of month
                                                                 LAST_DAY(
                                                                     TO_DATE(
                                                                            '01-'
                                                                         || TO_CHAR(
                                                                                LAST_DAY(
                                                                                    api.pkg_columnquery.datevalue(
                                                                                        a_jobid,
                                                                                        'ExpirationDate')),
                                                                                'MON')
                                                                         || '-2010',
                                                                         'DD-MON-YYYY')),
                                                                 'DD')  -- End Day of month
                                                          || '-'
                                                          || TO_CHAR(
                                                                 api.pkg_columnquery.datevalue(a_jobid,
                                                                                               'ExpirationDate'),
                                                                 'MON')  -- Month
                                                          || '-2010'  -- Year
                                                                    )),  --final date
                                             LAST_DAY(SYSDATE))) =
                                     t_expirationdate
                            ORDER BY f.transactiondate DESC)
                     WHERE ROWNUM = 1;
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        IF t_feeactivity = 'REN100' THEN
                            BEGIN
                                SELECT feeid
                                  INTO t_existingfeeid
                                  FROM (  SELECT f.feeid
                                            FROM api.fees f
                                                 JOIN api.registeredexternalobjects reo  -- RyanL: PIP Task 8.5
                                                 ON reo.linkvalue = TO_CHAR(f.feeid)
                                                AND reo.objectdefid = t_feeobjectdefid
                                                 JOIN sitespecific.feeschedule_t fs
                                                 ON fs.objectid = sitespecific.pkg_fees.getlicfeeschedulobjid(f.feeid)
                                           WHERE f.jobid = a_jobid
                                             AND fs.feeactivity = 'REN'
                                             AND fs.licensetypecode = t_ltcode
                                             AND NVL(
                                                     api.pkg_columnquery.datevalue(reo.objectid, 'RENExpirationDate'),
                                                     NVL(
                                                         DECODE(
                                                             SUBSTR(fs.description, -1),
                                                             '9', TO_DATE(  -- Final Date
                                                                         TO_CHAR(  -- Day of month
                                                                             LAST_DAY(
                                                                                    '01-'
                                                                                 || TO_CHAR(
                                                                                        LAST_DAY(
                                                                                            api.pkg_columnquery.datevalue(
                                                                                                a_jobid,
                                                                                                'ExpirationDate')),
                                                                                        'MON')
                                                                                 || '-2009'),
                                                                             'DD')  -- End Day of month
                                                                      || '-'
                                                                      || TO_CHAR(
                                                                             api.pkg_columnquery.datevalue(
                                                                                 a_jobid,
                                                                                 'ExpirationDate'),
                                                                             'MON')  -- Month
                                                                      || '-2009'  -- Year
                                                                                ),  -- final date
                                                             'A', TO_DATE(  -- Final Date
                                                                         TO_CHAR(  -- Day of month
                                                                             LAST_DAY(
                                                                                 TO_DATE(
                                                                                        '01-'
                                                                                     || TO_CHAR(
                                                                                            LAST_DAY(
                                                                                                api.pkg_columnquery.datevalue(
                                                                                                    a_jobid,
                                                                                                    'ExpirationDate')),
                                                                                            'MON')
                                                                                     || '-2010',
                                                                                     'DD-MON-YYYY')),
                                                                             'DD')  -- End Day of month
                                                                      || '-'
                                                                      || TO_CHAR(
                                                                             api.pkg_columnquery.datevalue(
                                                                                 a_jobid,
                                                                                 'ExpirationDate'),
                                                                             'MON')  -- Month
                                                                      || '-2010'  -- Year
                                                                                )),  --final date
                                                         LAST_DAY(SYSDATE))) =
                                                 t_expirationdate
                                        ORDER BY f.transactiondate DESC)
                                 WHERE ROWNUM = 1;
                            EXCEPTION
                                WHEN NO_DATA_FOUND THEN
                                    t_existingfeeid   := NULL;
                            END;
                        ELSE
                            t_existingfeeid   := NULL;
                        END IF;
                END;

                IF t_existingfeeid IS NOT NULL THEN
                    BEGIN
                        SELECT fs.gallonagerange,
                               api.pkg_columnquery.VALUE(fs.objectid, 'NumberOfMonthsLicensedFeeCode'),
                               fs.populationrange
                          INTO t_gallonagerange, t_numberofmonthslicensed, t_populationrange
                          FROM api.fees f
                               JOIN api.registeredexternalobjects reo  -- RyanL: PIP Task 8.5
                               ON reo.linkvalue = TO_CHAR(f.feeid)
                              AND reo.objectdefid = t_feeobjectdefid
                               JOIN sitespecific.feeschedule_t fs
                               ON fs.objectid = sitespecific.pkg_fees.getlicfeeschedulobjid(f.feeid)
                         WHERE f.feeid = t_existingfeeid
                           AND NVL(
                                   api.pkg_columnquery.datevalue(reo.objectid, 'RENExpirationDate'),
                                   NVL(
                                       DECODE(
                                           SUBSTR(fs.description, -1),
                                           '9', TO_DATE(  -- Final Date
                                                       TO_CHAR(  -- Day of month
                                                           LAST_DAY(
                                                                  '01-'
                                                               || TO_CHAR(
                                                                      LAST_DAY(
                                                                          api.pkg_columnquery.datevalue(
                                                                              a_jobid,
                                                                              'ExpirationDate')),
                                                                      'MON')
                                                               || '-2009'),
                                                           'DD')  -- End Day of month
                                                    || '-'
                                                    || TO_CHAR(
                                                           api.pkg_columnquery.datevalue(a_jobid, 'ExpirationDate'),
                                                           'MON')  -- Month
                                                    || '-2009'  -- Year
                                                              ),  -- final date
                                           'A', TO_DATE(  -- Final Date
                                                       TO_CHAR(  -- Day of month
                                                           LAST_DAY(
                                                               TO_DATE(
                                                                      '01-'
                                                                   || TO_CHAR(
                                                                          LAST_DAY(
                                                                              api.pkg_columnquery.datevalue(
                                                                                  a_jobid,
                                                                                  'ExpirationDate')),
                                                                          'MON')
                                                                   || '-2010',
                                                                   'DD-MON-YYYY')),
                                                           'DD')  -- End Day of month
                                                    || '-'
                                                    || TO_CHAR(
                                                           api.pkg_columnquery.datevalue(a_jobid, 'ExpirationDate'),
                                                           'MON')  -- Month
                                                    || '-2010'  -- Year
                                                              )),  --final date
                                       LAST_DAY(SYSDATE))) =
                               t_expirationdate;
                    EXCEPTION
                        WHEN NO_DATA_FOUND THEN
                            NULL;
                    END;
                END IF;
            END IF;

            --Get GLAccountId
            SELECT g.glaccountid
              INTO t_glaccountid
              FROM api.glaccounts g
             WHERE g.glaccount = t_feeactivity;

            --Get Primary Fee Amount and Fee ScheduleId (This is up here because it may or may not be used in the secondary loop - an error is raised later if it is null))
            sitespecific.pkg_fees.getltfeeamount(
                a_jobid,
                t_renexpdate,
                t_feeactivity,
                NULL,
                t_ltcode,
                t_gallonagerange,
                t_additionalmilliongallons,
                t_numberofmonthslicensed,
                CASE WHEN t_populationapplies = 'Y' THEN t_populationrange ELSE NULL END,
                t_primorbranch,
                t_primarycount,
                NULL,
                t_pfeeamount,
                t_feeschedid);

            -- For SecondaryLTs
            -- Get LT Code
            -- Get LT Count
            FOR z IN (SELECT ltc.licensetypecode,
                             sltc.licensetypecount,
                             ltc.populationapplies,
                             ltc.seasonalmonthsapply
                        FROM query.r_licensetypeltcatsecondary sltc
                             JOIN query.o_licensetypecategory ltc
                             ON sltc.licensetypecategoryobjectid = ltc.objectid
                       WHERE sltc.licensetypejobid = a_jobid
                         AND sltc.status IN ('ACTIVE',
                                             'SURRENDERED',
                                             'RULE 64B',
                                             'SLMS HOLD',
                                             'SUSPENDED'))
            LOOP
                -- If there is already a fee for this FeeActivity, licensetype and expirationdate on this job, count
                -- so procedure can raise error or skip (depending on RunType)
                FOR c IN (  SELECT f.feeid
                              FROM api.fees f
                                   /* RyanL: PIP Task 8.5: Removed because we are not using this as api.Notes no object
                                   join table(cast(api.pkg_simplesearch.CastableObjectsByIndex('o_Fee', 'FeeId', f.feeid) as api.udt_objectlist)) x
                                     on 1 = 1*/
                                   JOIN sitespecific.feeschedule_t fs
                                   ON fs.objectid = sitespecific.pkg_fees.getlicfeeschedulobjid(f.feeid)
                             WHERE f.jobid = a_jobid
                               AND t_checkexists LIKE
                                          '%'
                                       || fs.feeactivity
                                       || '.'
                                       || '%'
                               AND fs.licensetypecode = z.licensetypecode
                          ORDER BY f.transactiondate DESC)
                LOOP
                    SELECT COUNT(1)
                      INTO t_spriorcount
                      FROM api.fees f
                           JOIN api.registeredexternalobjects reo  -- RyanL: PIP Task 8.5
                           ON reo.linkvalue = TO_CHAR(f.feeid)
                          AND reo.objectdefid = t_feeobjectdefid
                           JOIN sitespecific.feeschedule_t fs
                           ON fs.objectid = sitespecific.pkg_fees.getlicfeeschedulobjid(f.feeid)
                     WHERE f.feeid = c.feeid
                       AND api.pkg_columnquery.numericvalue(reo.objectid, 'AmountForDisplay') <> 0
                       AND NVL(
                               api.pkg_columnquery.datevalue(reo.objectid, 'RENExpirationDate'),
                               NVL(
                                   DECODE(
                                       SUBSTR(fs.description, -1),
                                       '9', TO_DATE(  -- Final Date
                                                   TO_CHAR(  -- Day of month
                                                       LAST_DAY(
                                                              '01-'
                                                           || TO_CHAR(
                                                                  LAST_DAY(
                                                                      api.pkg_columnquery.datevalue(a_jobid,
                                                                                                    'ExpirationDate')),
                                                                  'MON')
                                                           || '-2009'),
                                                       'DD')  -- End Day of month
                                                || '-'
                                                || TO_CHAR(api.pkg_columnquery.datevalue(a_jobid, 'ExpirationDate'),
                                                           'MON')  -- Month
                                                || '-2009'  -- Year
                                                          ),  -- final date
                                       'A', TO_DATE(  -- Final Date
                                                   TO_CHAR(  -- Day of month
                                                       LAST_DAY(
                                                           TO_DATE(
                                                                  '01-'
                                                               || TO_CHAR(
                                                                      LAST_DAY(
                                                                          api.pkg_columnquery.datevalue(
                                                                              a_jobid,
                                                                              'ExpirationDate')),
                                                                      'MON')
                                                               || '-2010',
                                                               'DD-MON-YYYY')),
                                                       'DD')  -- End Day of month
                                                || '-'
                                                || TO_CHAR(api.pkg_columnquery.datevalue(a_jobid, 'ExpirationDate'),
                                                           'MON')  -- Month
                                                || '-2010'  -- Year
                                                          )),  --final date
                                   LAST_DAY(SYSDATE))) =
                           t_expirationdate;

                    EXIT WHEN t_spriorcount > 0;
                END LOOP;

                --If there are no prior fees of this type or a subsequent type or already paid ones of a prior type.
                IF t_spriorcount = 0 THEN
                    --if population applies for this secondary, set secondary populationrange to primary populationrange, else set it to null.
                    IF z.populationapplies = 'Y'
                    OR (t_ltcode IN (50, 51, 52)
                    AND z.licensetypecode = 58) THEN
                        t_spopulationrange   := t_populationrange;
                    ELSE
                        t_spopulationrange   := NULL;
                    END IF;

                    --if seasonal months apply this for secondary, set secondary numberofmonthslicensed to primary numberofmonthslicensed, else set it to null.
                    IF z.seasonalmonthsapply = 'Y' THEN
                        t_snumberofmonthslicensed   := t_numberofmonthslicensed;
                    ELSE
                        t_snumberofmonthslicensed   := NULL;
                    END IF;

                    --This count is compared the paidcount (count of paid fees) to conditionally raise an error at the end of the procedure.
                    t_totalcount   := t_totalcount + 1;

                    --If there is already a REN fee, use the GallonageRange, NumberOfMonthsLicensed, and PopulationRange from the feeschedule record related to that fee.
                    IF t_feeactivity <> 'REN' THEN
                        BEGIN
                            SELECT feeid
                              INTO t_sexistingfeeid
                              FROM (  SELECT f.feeid
                                        FROM api.fees f
                                             JOIN api.registeredexternalobjects reo  -- RyanL: PIP Task 8.5
                                             ON reo.linkvalue = TO_CHAR(f.feeid)
                                            AND reo.objectdefid = t_feeobjectdefid
                                             JOIN sitespecific.feeschedule_t fs
                                             ON fs.objectid = sitespecific.pkg_fees.getlicfeeschedulobjid(f.feeid)
                                       WHERE f.jobid = a_jobid
                                         AND fs.feeactivity IN t_fssearch
                                         AND fs.licensetypecode = z.licensetypecode
                                         AND NVL(
                                                 api.pkg_columnquery.datevalue(reo.objectid, 'RENExpirationDate'),
                                                 NVL(
                                                     DECODE(
                                                         SUBSTR(fs.description, -1),
                                                         '9', TO_DATE(  -- Final Date
                                                                     TO_CHAR(  -- Day of month
                                                                         LAST_DAY(
                                                                                '01-'
                                                                             || TO_CHAR(
                                                                                    LAST_DAY(
                                                                                        api.pkg_columnquery.datevalue(
                                                                                            a_jobid,
                                                                                            'ExpirationDate')),
                                                                                    'MON')
                                                                             || '-2009'),
                                                                         'DD')  -- End Day of month
                                                                  || '-'
                                                                  || TO_CHAR(
                                                                         api.pkg_columnquery.datevalue(
                                                                             a_jobid,
                                                                             'ExpirationDate'),
                                                                         'MON')  -- Month
                                                                  || '-2009'  -- Year
                                                                            ),  -- final date
                                                         'A', TO_DATE(  -- Final Date
                                                                     TO_CHAR(  -- Day of month
                                                                         LAST_DAY(
                                                                             TO_DATE(
                                                                                    '01-'
                                                                                 || TO_CHAR(
                                                                                        LAST_DAY(
                                                                                            api.pkg_columnquery.datevalue(
                                                                                                a_jobid,
                                                                                                'ExpirationDate')),
                                                                                        'MON')
                                                                                 || '-2010',
                                                                                 'DD-MON-YYYY')),
                                                                         'DD')  -- End Day of month
                                                                  || '-'
                                                                  || TO_CHAR(
                                                                         api.pkg_columnquery.datevalue(
                                                                             a_jobid,
                                                                             'ExpirationDate'),
                                                                         'MON')  -- Month
                                                                  || '-2010'  -- Year
                                                                            )),  --final date
                                                     LAST_DAY(SYSDATE))) =
                                             t_expirationdate
                                    ORDER BY f.transactiondate DESC)
                             WHERE ROWNUM = 1;
                        EXCEPTION
                            WHEN NO_DATA_FOUND THEN
                                IF t_feeactivity = 'REN100' THEN
                                    BEGIN
                                        SELECT feeid
                                          INTO t_sexistingfeeid
                                          FROM (  SELECT f.feeid
                                                    FROM api.fees f
                                                         JOIN api.registeredexternalobjects reo  -- RyanL: PIP Task 8.5
                                                         ON reo.linkvalue = TO_CHAR(f.feeid)
                                                        AND reo.objectdefid = t_feeobjectdefid
                                                         JOIN sitespecific.feeschedule_t fs
                                                         ON fs.objectid =
                                                            sitespecific.pkg_fees.getlicfeeschedulobjid(f.feeid)
                                                   WHERE f.jobid = a_jobid
                                                     AND fs.feeactivity IN 'REN'
                                                     AND fs.licensetypecode = z.licensetypecode
                                                     AND NVL(
                                                             api.pkg_columnquery.datevalue(reo.objectid,
                                                                                           'RENExpirationDate'),
                                                             NVL(
                                                                 DECODE(
                                                                     SUBSTR(fs.description, -1),
                                                                     '9', TO_DATE(  -- Final Date
                                                                                 TO_CHAR(  -- Day of month
                                                                                     LAST_DAY(
                                                                                            '01-'
                                                                                         || TO_CHAR(
                                                                                                LAST_DAY(
                                                                                                    api.pkg_columnquery.datevalue(
                                                                                                        a_jobid,
                                                                                                        'ExpirationDate')),
                                                                                                'MON')
                                                                                         || '-2009'),
                                                                                     'DD')  -- End Day of month
                                                                              || '-'
                                                                              || TO_CHAR(
                                                                                     api.pkg_columnquery.datevalue(
                                                                                         a_jobid,
                                                                                         'ExpirationDate'),
                                                                                     'MON')  -- Month
                                                                              || '-2009'  -- Year
                                                                                        ),  -- final date
                                                                     'A', TO_DATE(  -- Final Date
                                                                                 TO_CHAR(  -- Day of month
                                                                                     LAST_DAY(
                                                                                         TO_DATE(
                                                                                                '01-'
                                                                                             || TO_CHAR(
                                                                                                    LAST_DAY(
                                                                                                        api.pkg_columnquery.datevalue(
                                                                                                            a_jobid,
                                                                                                            'ExpirationDate')),
                                                                                                    'MON')
                                                                                             || '-2010',
                                                                                             'DD-MON-YYYY')),
                                                                                     'DD')  -- End Day of month
                                                                              || '-'
                                                                              || TO_CHAR(
                                                                                     api.pkg_columnquery.datevalue(
                                                                                         a_jobid,
                                                                                         'ExpirationDate'),
                                                                                     'MON')  -- Month
                                                                              || '-2010'  -- Year
                                                                                        )),  --final date
                                                                 LAST_DAY(SYSDATE))) =
                                                         t_expirationdate
                                                ORDER BY f.transactiondate DESC)
                                         WHERE ROWNUM = 1;
                                    EXCEPTION
                                        WHEN NO_DATA_FOUND THEN
                                            t_sexistingfeeid   := NULL;
                                    END;
                                ELSE
                                    t_sexistingfeeid   := NULL;
                                END IF;
                        END;

                        IF t_sexistingfeeid IS NOT NULL THEN
                            BEGIN
                                SELECT api.pkg_columnquery.VALUE(fs.objectid, 'NumberOfMonthsLicensedFeeCode'),
                                       fs.populationrange
                                  INTO t_snumberofmonthslicensed, t_spopulationrange
                                  FROM api.fees f
                                       JOIN api.registeredexternalobjects reo  -- RyanL: PIP Task 8.5
                                       ON reo.linkvalue = TO_CHAR(f.feeid)
                                      AND reo.objectdefid = t_feeobjectdefid
                                       JOIN sitespecific.feeschedule_t fs
                                       ON fs.objectid = sitespecific.pkg_fees.getlicfeeschedulobjid(f.feeid)
                                 WHERE f.feeid = t_sexistingfeeid
                                   AND NVL(
                                           api.pkg_columnquery.datevalue(reo.objectid, 'RENExpirationDate'),
                                           NVL(
                                               DECODE(
                                                   SUBSTR(fs.description, -1),
                                                   '9', TO_DATE(  -- Final Date
                                                               TO_CHAR(  -- Day of month
                                                                   LAST_DAY(
                                                                          '01-'
                                                                       || TO_CHAR(
                                                                              LAST_DAY(
                                                                                  api.pkg_columnquery.datevalue(
                                                                                      a_jobid,
                                                                                      'ExpirationDate')),
                                                                              'MON')
                                                                       || '-2009'),
                                                                   'DD')  -- End Day of month
                                                            || '-'
                                                            || TO_CHAR(
                                                                   api.pkg_columnquery.datevalue(a_jobid,
                                                                                                 'ExpirationDate'),
                                                                   'MON')  -- Month
                                                            || '-2009'  -- Year
                                                                      ),  -- final date
                                                   'A', TO_DATE(  -- Final Date
                                                               TO_CHAR(  -- Day of month
                                                                   LAST_DAY(
                                                                       TO_DATE(
                                                                              '01-'
                                                                           || TO_CHAR(
                                                                                  LAST_DAY(
                                                                                      api.pkg_columnquery.datevalue(
                                                                                          a_jobid,
                                                                                          'ExpirationDate')),
                                                                                  'MON')
                                                                           || '-2010',
                                                                           'DD-MON-YYYY')),
                                                                   'DD')  -- End Day of month
                                                            || '-'
                                                            || TO_CHAR(
                                                                   api.pkg_columnquery.datevalue(a_jobid,
                                                                                                 'ExpirationDate'),
                                                                   'MON')  -- Month
                                                            || '-2010'  -- Year
                                                                      )),  --final date
                                               LAST_DAY(SYSDATE))) =
                                       t_expirationdate;
                            EXCEPTION
                                WHEN NO_DATA_FOUND THEN
                                    NULL;
                            END;
                        END IF;
                    END IF;

                    -- then Pass the fee amount into t_SFeeAmount, and the Fee Schedule Id into t_FeeScheduleId
                    sitespecific.pkg_fees.getltfeeamount(a_jobid,
                                                         t_renexpdate,
                                                         t_feeactivity,
                                                         NULL,
                                                         z.licensetypecode,
                                                         NULL,
                                                         NULL,
                                                         t_snumberofmonthslicensed,
                                                         t_spopulationrange,
                                                         'S',
                                                         z.licensetypecount,
                                                         NULL,
                                                         t_sfeeamount,
                                                         t_sfeescheduleid);

                    -- If the fee amount is not null
                    IF t_sfeeamount >= 0
                   AND t_sfeeamount IS NOT NULL THEN
                        -- If Secondary LT Code = Primary LT Code
                        IF z.licensetypecode = t_ltcode THEN
                            --Raise an error if the Primary fee amount is null or 0 (this code is also in Primary Fee Creation (for when secondary and primary are not equal)
                            IF t_pfeeamount IS NULL
                            OR t_pfeeamount < 0 THEN
                                INSERT INTO licensebatchexceptions_t
                                         VALUES (
                                                    a_jobid,
                                                    'Both',
                                                    t_feeactivity,
                                                    t_ltcode,
                                                    t_expirationdate,
                                                       'There is no '
                                                    || t_feeactivity
                                                    || ' Fee Schedule record for License Type '
                                                    || t_ltcode
                                                    || ' that is effective on '
                                                    || TO_CHAR(t_expirationdate, 'FmMonth dd, yyyy')
                                                    || ' (Expiration Date) and has the necessary amount information. Jobid: '
                                                    || a_jobid);
                            END IF;

                            -- Add the Primary Lt Fee Amount to the Secondary Fee Amount
                            t_sfeeamount       := t_sfeeamount + t_pfeeamount;
                            --Set Description Information for fee
                            t_sdescription     := api.pkg_columnquery.VALUE(t_feeschedid, 'ProcedureDescription');
                            --Set IsMaster to Y (used in rel detail)
                            t_ismaster         := 'Y';
                            --Set detail so that Primary fee creation will be skipped.
                            t_primissec        := 'Y';
                            --Set t_SFeeScheduleId to equal t_FeeSchedId so that relationship will be to the FeeSchedule record for the Primary.
                            t_sfeescheduleid   := t_feeschedid;
                        ELSE
                            --Set IsMaster to N (used in rel detail)
                            t_ismaster       := 'N';
                            --Set Description Information for fee
                            t_sdescription   := api.pkg_columnquery.VALUE(t_sfeescheduleid, 'ProcedureDescription');
                        END IF;

                        IF t_feeactivity = 'REN' THEN
                            -- CreateFees. This will pass the api Fee Id into t_FeeId, and the POSSE Fee ObjectId into t_FeeObjectId
                            sitespecific.pkg_fees.newfee(t_sfeeid,
                                                         t_sfeeamount,
                                                         t_sdescription,
                                                         t_glaccountid,
                                                         a_jobid,
                                                         NULL,
                                                         t_sfeeobjid);
                        ELSE
                            BEGIN
                                SELECT feeid
                                  INTO t_sexistingfeeid
                                  FROM (  SELECT f.feeid
                                            FROM api.fees f
                                                 JOIN api.registeredexternalobjects reo  -- RyanL: PIP Task 8.5
                                                 ON reo.linkvalue = TO_CHAR(f.feeid)
                                                AND reo.objectdefid = t_feeobjectdefid
                                                 JOIN api.relationships r
                                                 ON r.fromobjectid = reo.objectid
                                                AND r.endpointid =
                                                    api.pkg_configquery.endpointidforname('o_Fee',
                                                                                          'LicenseFeeSchedule')
                                                 JOIN sitespecific.feeschedule_t fs
                                                 ON fs.objectid = sitespecific.pkg_fees.getlicfeeschedulobjid(f.feeid)
                                           WHERE f.jobid = a_jobid
                                             AND fs.feeactivity IN t_fssearch
                                             AND fs.licensetypecode = z.licensetypecode
                                             AND NVL(
                                                     api.pkg_columnquery.datevalue(reo.objectid, 'RENExpirationDate'),
                                                     NVL(
                                                         DECODE(
                                                             SUBSTR(fs.description, -1),
                                                             '9', TO_DATE(  -- Final Date
                                                                         TO_CHAR(  -- Day of month
                                                                             LAST_DAY(
                                                                                    '01-'
                                                                                 || TO_CHAR(
                                                                                        LAST_DAY(
                                                                                            api.pkg_columnquery.datevalue(
                                                                                                a_jobid,
                                                                                                'ExpirationDate')),
                                                                                        'MON')
                                                                                 || '-2009'),
                                                                             'DD')  -- End Day of month
                                                                      || '-'
                                                                      || TO_CHAR(
                                                                             api.pkg_columnquery.datevalue(
                                                                                 a_jobid,
                                                                                 'ExpirationDate'),
                                                                             'MON')  -- Month
                                                                      || '-2009'  -- Year
                                                                                ),  -- final date
                                                             'A', TO_DATE(  -- Final Date
                                                                         TO_CHAR(  -- Day of month
                                                                             LAST_DAY(
                                                                                 TO_DATE(
                                                                                        '01-'
                                                                                     || TO_CHAR(
                                                                                            LAST_DAY(
                                                                                                api.pkg_columnquery.datevalue(
                                                                                                    a_jobid,
                                                                                                    'ExpirationDate')),
                                                                                            'MON')
                                                                                     || '-2010',
                                                                                     'DD-MON-YYYY')),
                                                                             'DD')  -- End Day of month
                                                                      || '-'
                                                                      || TO_CHAR(
                                                                             api.pkg_columnquery.datevalue(
                                                                                 a_jobid,
                                                                                 'ExpirationDate'),
                                                                             'MON')  -- Month
                                                                      || '-2010'  -- Year
                                                                                )),  --final date
                                                         LAST_DAY(SYSDATE))) =
                                                 t_expirationdate
                                        ORDER BY f.transactiondate DESC)
                                 WHERE ROWNUM = 1;
                            EXCEPTION
                                WHEN NO_DATA_FOUND THEN
                                    IF t_feeactivity = 'REN100' THEN
                                        BEGIN
                                            SELECT feeid
                                              INTO t_sexistingfeeid
                                              FROM (  SELECT f.feeid
                                                        FROM api.fees f
                                                             JOIN api.registeredexternalobjects reo  -- RyanL: PIP Task 8.5
                                                             ON reo.linkvalue = TO_CHAR(f.feeid)
                                                            AND reo.objectdefid = t_feeobjectdefid
                                                             JOIN api.relationships r
                                                             ON r.fromobjectid = reo.objectid
                                                            AND r.endpointid =
                                                                api.pkg_configquery.endpointidforname(
                                                                    'o_Fee',
                                                                    'LicenseFeeSchedule')
                                                             JOIN sitespecific.feeschedule_t fs
                                                             ON fs.objectid =
                                                                sitespecific.pkg_fees.getlicfeeschedulobjid(f.feeid)
                                                       WHERE f.jobid = a_jobid
                                                         AND fs.feeactivity = 'REN'
                                                         AND fs.licensetypecode = z.licensetypecode
                                                         AND NVL(
                                                                 api.pkg_columnquery.datevalue(reo.objectid,
                                                                                               'RENExpirationDate'),
                                                                 NVL(
                                                                     DECODE(
                                                                         SUBSTR(fs.description, -1),
                                                                         '9', TO_DATE(  -- Final Date
                                                                                     TO_CHAR(  -- Day of month
                                                                                         LAST_DAY(
                                                                                                '01-'
                                                                                             || TO_CHAR(
                                                                                                    LAST_DAY(
                                                                                                        api.pkg_columnquery.datevalue(
                                                                                                            a_jobid,
                                                                                                            'ExpirationDate')),
                                                                                                    'MON')
                                                                                             || '-2009'),
                                                                                         'DD')  -- End Day of month
                                                                                  || '-'
                                                                                  || TO_CHAR(
                                                                                         api.pkg_columnquery.datevalue(
                                                                                             a_jobid,
                                                                                             'ExpirationDate'),
                                                                                         'MON')  -- Month
                                                                                  || '-2009'  -- Year
                                                                                            ),  -- final date
                                                                         'A', TO_DATE(  -- Final Date
                                                                                     TO_CHAR(  -- Day of month
                                                                                         LAST_DAY(
                                                                                             TO_DATE(
                                                                                                    '01-'
                                                                                                 || TO_CHAR(
                                                                                                        LAST_DAY(
                                                                                                            api.pkg_columnquery.datevalue(
                                                                                                                a_jobid,
                                                                                                                'ExpirationDate')),
                                                                                                        'MON')
                                                                                                 || '-2010',
                                                                                                 'DD-MON-YYYY')),
                                                                                         'DD')  -- End Day of month
                                                                                  || '-'
                                                                                  || TO_CHAR(
                                                                                         api.pkg_columnquery.datevalue(
                                                                                             a_jobid,
                                                                                             'ExpirationDate'),
                                                                                         'MON')  -- Month
                                                                                  || '-2010'  -- Year
                                                                                            )),  --final date
                                                                     LAST_DAY(SYSDATE))) =
                                                             t_expirationdate
                                                    ORDER BY f.transactiondate DESC)
                                             WHERE ROWNUM = 1;
                                        EXCEPTION
                                            WHEN NO_DATA_FOUND THEN
                                                t_sexistingfeeid   := NULL;
                                        END;
                                    ELSE
                                        t_sexistingfeeid   := NULL;
                                    END IF;
                            END;

                            BEGIN
                                -- RyanL: Changed the select clause to be a subselect for performance (PIP Task 8.5)
                                SELECT f.feeid,
                                       (  f.amount
                                        + NVL((SELECT SUM(amount)
                                                 FROM api.feetransactions ft
                                                WHERE ft.feeid = f.feeid
                                                  AND ft.transactiontype = 'Adj'),
                                              0)),
                                       reo.objectid,
                                       r.relationshipid,
                                       'N'  -- 05/29/2020 TJL WO 8924
                                  INTO t_sfeeid,
                                       t_originalamount,
                                       t_sfeeobjid,
                                       t_relid,
                                       t_feepaid
                                  FROM api.fees f
                                       JOIN api.registeredexternalobjects reo  -- RyanL: PIP Task 8.5
                                       ON reo.linkvalue = TO_CHAR(f.feeid)
                                      AND reo.objectdefid = t_feeobjectdefid
                                       JOIN api.relationships r
                                       ON r.fromobjectid = reo.objectid
                                      AND r.endpointid =
                                          api.pkg_configquery.endpointidforname('o_Fee', 'LicenseFeeSchedule')
                                       JOIN sitespecific.feeschedule_t fs
                                       ON fs.objectid = sitespecific.pkg_fees.getlicfeeschedulobjid(f.feeid)
                                 WHERE f.feeid = t_sexistingfeeid
                                   AND NVL(
                                           api.pkg_columnquery.datevalue(reo.objectid, 'RENExpirationDate'),
                                           NVL(
                                               DECODE(
                                                   SUBSTR(fs.description, -1),
                                                   '9', TO_DATE(  -- Final Date
                                                               TO_CHAR(  -- Day of month
                                                                   LAST_DAY(
                                                                          '01-'
                                                                       || TO_CHAR(
                                                                              LAST_DAY(
                                                                                  api.pkg_columnquery.datevalue(
                                                                                      a_jobid,
                                                                                      'ExpirationDate')),
                                                                              'MON')
                                                                       || '-2009'),
                                                                   'DD')  -- End Day of month
                                                            || '-'
                                                            || TO_CHAR(
                                                                   api.pkg_columnquery.datevalue(a_jobid,
                                                                                                 'ExpirationDate'),
                                                                   'MON')  -- Month
                                                            || '-2009'  -- Year
                                                                      ),  -- final date
                                                   'A', TO_DATE(  -- Final Date
                                                               TO_CHAR(  -- Day of month
                                                                   LAST_DAY(
                                                                       TO_DATE(
                                                                              '01-'
                                                                           || TO_CHAR(
                                                                                  LAST_DAY(
                                                                                      api.pkg_columnquery.datevalue(
                                                                                          a_jobid,
                                                                                          'ExpirationDate')),
                                                                                  'MON')
                                                                           || '-2010',
                                                                           'DD-MON-YYYY')),
                                                                   'DD')  -- End Day of month
                                                            || '-'
                                                            || TO_CHAR(
                                                                   api.pkg_columnquery.datevalue(a_jobid,
                                                                                                 'ExpirationDate'),
                                                                   'MON')  -- Month
                                                            || '-2010'  -- Year
                                                                      )),  --final date
                                               LAST_DAY(SYSDATE))) =
                                       t_expirationdate;

                                --Only update fee when it is still owing
                                IF t_feepaid = 'N' THEN
                                    --Adjust Fee
                                    t_sadjustid   :=
                                        api.pkg_feeupdate.adjust(t_sfeeid,
                                                                 ROUND(t_sfeeamount - t_originalamount),
                                                                 t_sdescription,
                                                                 SYSDATE);
                                    --Register FeeTransaction Object
                                    t_feetransobjid   :=
                                        api.pkg_objectupdate.registerexternalobject('o_FeeTransactions', t_sadjustid);
                                    --Delete old relationship to feeschedule
                                    api.pkg_relationshipupdate.remove(t_relid);
                                END IF;
                            EXCEPTION
                                WHEN NO_DATA_FOUND THEN
                                    --When there was no prior REN fee, simply create fee.
                                    --Create Fee
                                    sitespecific.pkg_fees.newfee(t_sfeeid,
                                                                 t_sfeeamount,
                                                                 t_sdescription,
                                                                 t_glaccountid,
                                                                 a_jobid,
                                                                 NULL,
                                                                 t_sfeeobjid);
                            END;

                            --Count number of times Fee was already paid.
                            IF t_feepaid = 'Y' THEN
                                t_paidcount   := t_paidcount + 1;
                            END IF;
                        END IF;

                        --Only relate feeschedule and set values when a new fee was created (vs. when the fee record not adjusted due to being already paid.
                        IF t_feepaid = 'N'
                        OR t_feepaid IS NULL THEN
                            api.pkg_columnupdate.setvalue(t_sfeeobjid, 'RENExpirationDate', t_renexpdate);
                            t_relid   :=
                                api.pkg_relationshipupdate.new(
                                    api.pkg_configquery.endpointidforname('o_Fee', 'LicenseFeeSchedule'),
                                    t_sfeeobjid,
                                    t_sfeescheduleid);
                            api.pkg_columnupdate.setvalue(t_relid, 'IsMaster', t_ismaster);
                            api.pkg_columnupdate.setvalue(t_relid, 'SecondaryCount', z.licensetypecount);
                            api.pkg_columnupdate.setvalue(t_relid, 'MasterLT', t_ltcode);
                            api.pkg_columnupdate.setvalue(t_sfeeobjid, 'Quantity', z.licensetypecount);
                        END IF;
                    ELSE
                        INSERT INTO licensebatchexceptions_t
                             VALUES (a_jobid,
                                     'Secondary',
                                     t_feeactivity,
                                     z.licensetypecode,
                                     t_expirationdate,
                                        'There is no '
                                     || t_feeactivity
                                     || ' Fee Schedule record for License Type '
                                     || z.licensetypecode
                                     || ' that is effective on '
                                     || TO_CHAR(t_expirationdate, 'FmMonth dd, yyyy')
                                     || ' (Expiration Date) and has the necessary amount information. Jobid: '
                                     || a_jobid);
                    END IF;  --if Secondary Fee Amount is not null
                END IF;  --If there is Prior fee created, this is skipped.

                --Set to null for next loop
                t_feepaid       := NULL;
                t_spriorcount   := 0;
            END LOOP;  --Secondary LT loop

            --Create Fee when Primary is not equal to secondary (in which case the fee is created in the secondary LT loop)
            -- If there is already a fee for this FeeActivity, licensetype and expirationdate on this job, count so
            -- procedure can raise error or skip (depending on RunType)
            FOR c IN (  SELECT f.feeid
                          FROM api.fees f
                               /* RyanL: PIP Task 8.5: Removed because we are not using this as api.Notes no object
                               join table(cast(api.pkg_simplesearch.CastableObjectsByIndex('o_Fee', 'FeeId', f.feeid) as api.udt_objectlist)) x
                                 on 1 = 1*/
                               JOIN sitespecific.feeschedule_t fs
                               ON fs.objectid = sitespecific.pkg_fees.getlicfeeschedulobjid(f.feeid)
                         WHERE f.jobid = a_jobid
                           AND t_checkexists LIKE
                                      '%'
                                   || fs.feeactivity
                                   || '.'
                                   || '%'
                           AND fs.licensetypecode = t_ltcode
                      ORDER BY f.transactiondate DESC)
            LOOP
                SELECT COUNT(1)
                  INTO t_ppriorcount
                  FROM api.fees f
                       JOIN api.registeredexternalobjects reo  -- RyanL: PIP Task 8.5
                       ON reo.linkvalue = TO_CHAR(f.feeid)
                      AND reo.objectdefid = t_feeobjectdefid
                       JOIN sitespecific.feeschedule_t fs
                       ON fs.objectid = sitespecific.pkg_fees.getlicfeeschedulobjid(f.feeid)
                 WHERE f.feeid = c.feeid
                   AND api.pkg_columnquery.numericvalue(reo.objectid, 'AmountForDisplay') <> 0
                   AND NVL(
                           api.pkg_columnquery.datevalue(reo.objectid, 'RENExpirationDate'),
                           NVL(
                               DECODE(
                                   SUBSTR(fs.description, -1),
                                   '9', TO_DATE(  -- Final Date
                                               TO_CHAR(  -- Day of month
                                                   LAST_DAY(
                                                          '01-'
                                                       || TO_CHAR(
                                                              LAST_DAY(
                                                                  api.pkg_columnquery.datevalue(a_jobid,
                                                                                                'ExpirationDate')),
                                                              'MON')
                                                       || '-2009'),
                                                   'DD')  -- End Day of month
                                            || '-'
                                            || TO_CHAR(api.pkg_columnquery.datevalue(a_jobid, 'ExpirationDate'),
                                                       'MON')  -- Month
                                            || '-2009'  -- Year
                                                      ),  -- final date
                                   'A', TO_DATE(  -- Final Date
                                               TO_CHAR(  -- Day of month
                                                   LAST_DAY(
                                                       TO_DATE(
                                                              '01-'
                                                           || TO_CHAR(
                                                                  LAST_DAY(
                                                                      api.pkg_columnquery.datevalue(a_jobid,
                                                                                                    'ExpirationDate')),
                                                                  'MON')
                                                           || '-2010',
                                                           'DD-MON-YYYY')),
                                                   'DD')  -- End Day of month
                                            || '-'
                                            || TO_CHAR(api.pkg_columnquery.datevalue(a_jobid, 'ExpirationDate'),
                                                       'MON')  -- Month
                                            || '-2010'  -- Year
                                                      )),  --final date
                               LAST_DAY(SYSDATE))) =
                       t_expirationdate;

                EXIT WHEN t_ppriorcount > 0;
            END LOOP;

            --If there are no prior fees of this type or a subsequent type or already paid ones of a prior type.
            IF t_ppriorcount = 0 THEN
                --Raises an error if the fee amount is null or 0 (this code is also in the secondary loop for when primary and secondary are the same
                IF t_pfeeamount IS NULL
                OR t_pfeeamount < 0 THEN
                    INSERT INTO licensebatchexceptions_t
                         VALUES (a_jobid,
                                 'Primary',
                                 t_feeactivity,
                                 t_ltcode,
                                 t_expirationdate,
                                    'There is no '
                                 || t_feeactivity
                                 || ' Fee Schedule record for License Type '
                                 || t_ltcode
                                 || ' that is effective on '
                                 || TO_CHAR(t_expirationdate, 'FmMonth dd, yyyy')
                                 || ' (Expiration Date) and has the necessary amount information. JobId: '
                                 || a_jobid);
                ELSE
                    --If Primary was not also a secondary
                    IF t_primissec IS NULL
                    OR t_primissec <> 'Y' THEN
                        --Get PrimaryLT Description
                        SELECT f.proceduredescription
                          INTO t_description
                          FROM query.o_feeschedule f
                         WHERE f.objectid = t_feeschedid;

                        --This count is compared the paidcount (count of paid fees) to conditionally raise an error at the end of the procedure.
                        t_totalcount   := t_totalcount + 1;

                        IF t_feeactivity = 'REN' THEN
                            --Create Fee
                            sitespecific.pkg_fees.newfee(t_feeid,
                                                         t_pfeeamount,
                                                         t_description,
                                                         t_glaccountid,
                                                         a_jobid,
                                                         NULL,
                                                         t_feeobjid);
                        ELSE
                            --Adjust Fee if there is a past fee
                            BEGIN
                                SELECT f.feeid,
                                       api.pkg_columnquery.numericvalue(reo.objectid, 'AmountForDisplay'),
                                       reo.objectid,
                                       r.relationshipid,
                                       'N'  -- 05/29/2020 TJL WO 8924
                                  INTO t_feeid,
                                       t_originalamount,
                                       t_feeobjid,
                                       t_relid,
                                       t_feepaid
                                  FROM api.fees f
                                       JOIN api.registeredexternalobjects reo  -- RyanL: PIP Task 8.5
                                       ON reo.linkvalue = TO_CHAR(f.feeid)
                                      AND reo.objectdefid = t_feeobjectdefid
                                       JOIN query.r_feelicensefeeschedule r
                                       ON r.feeobjectid = reo.objectid
                                       JOIN sitespecific.feeschedule_t fs
                                       ON fs.objectid = sitespecific.pkg_fees.getlicfeeschedulobjid(f.feeid)
                                 WHERE f.feeid = t_existingfeeid
                                   AND api.pkg_columnquery.numericvalue(reo.objectid, 'AmountForDisplay') <> 0
                                   AND NVL(
                                           api.pkg_columnquery.datevalue(reo.objectid, 'RENExpirationDate'),
                                           NVL(
                                               DECODE(
                                                   SUBSTR(fs.description, -1),
                                                   '9', TO_DATE(  -- Final Date
                                                               TO_CHAR(  -- Day of month
                                                                   LAST_DAY(
                                                                          '01-'
                                                                       || TO_CHAR(
                                                                              LAST_DAY(
                                                                                  api.pkg_columnquery.datevalue(
                                                                                      a_jobid,
                                                                                      'ExpirationDate')),
                                                                              'MON')
                                                                       || '-2009'),
                                                                   'DD')  -- End Day of month
                                                            || '-'
                                                            || TO_CHAR(
                                                                   api.pkg_columnquery.datevalue(a_jobid,
                                                                                                 'ExpirationDate'),
                                                                   'MON')  -- Month
                                                            || '-2009'  -- Year
                                                                      ),  -- final date
                                                   'A', TO_DATE(  -- Final Date
                                                               TO_CHAR(  -- Day of month
                                                                   LAST_DAY(
                                                                       TO_DATE(
                                                                              '01-'
                                                                           || TO_CHAR(
                                                                                  LAST_DAY(
                                                                                      api.pkg_columnquery.datevalue(
                                                                                          a_jobid,
                                                                                          'ExpirationDate')),
                                                                                  'MON')
                                                                           || '-2010',
                                                                           'DD-MON-YYYY')),
                                                                   'DD')  -- End Day of month
                                                            || '-'
                                                            || TO_CHAR(
                                                                   api.pkg_columnquery.datevalue(a_jobid,
                                                                                                 'ExpirationDate'),
                                                                   'MON')  -- Month
                                                            || '-2010'  -- Year
                                                                      )),  --final date
                                               LAST_DAY(SYSDATE))) =
                                       t_expirationdate;

                                --Only update fee when it is still owing
                                IF t_feepaid = 'N' THEN
                                    t_adjustid   :=
                                        api.pkg_feeupdate.adjust(t_feeid,
                                                                 ROUND(t_pfeeamount - t_originalamount),
                                                                 t_description,
                                                                 SYSDATE);
                                    t_feetransobjid   :=
                                        api.pkg_objectupdate.registerexternalobject('o_FeeTransactions', t_adjustid);
                                    api.pkg_relationshipupdate.remove(t_relid);
                                END IF;
                            EXCEPTION
                                WHEN NO_DATA_FOUND THEN
                                    --Create Fee
                                    sitespecific.pkg_fees.newfee(t_feeid,
                                                                 t_pfeeamount,
                                                                 t_description,
                                                                 t_glaccountid,
                                                                 a_jobid,
                                                                 NULL,
                                                                 t_feeobjid);
                            END;

                            --Count number of times Fee was already paid.
                            IF t_feepaid = 'Y' THEN
                                t_paidcount   := t_paidcount + 1;
                            END IF;
                        END IF;

                        --Only relate feeschedule and set values when a new fee was created (vs. when the fee record not adjusted due to being already paid.
                        IF t_feepaid = 'N'
                        OR t_feepaid IS NULL THEN
                            api.pkg_columnupdate.setvalue(t_feeobjid, 'RENExpirationDate', t_renexpdate);
                            t_relid   :=
                                api.pkg_relationshipupdate.new(
                                    api.pkg_configquery.endpointidforname('o_Fee', 'LicenseFeeSchedule'),
                                    t_feeobjid,
                                    t_feeschedid);

                            IF t_primorbranch <> 'B' THEN
                                api.pkg_columnupdate.setvalue(t_relid, 'IsMaster', 'Y');
                            END IF;

                            IF t_primorbranch = 'B' THEN
                                api.pkg_columnupdate.setvalue(t_relid, 'SecondaryCount', 1);
                            ELSE
                                api.pkg_columnupdate.setvalue(t_relid, 'SecondaryCount', t_primarycount);
                            END IF;
                        END IF;
                    END IF;  --If the Primary fee was done in the secondary loop (when PLT and an SLT are the same), fee creation will be skipped.
                END IF;  --Log Error
            END IF;  --If there is Prior fee created, fee creation will be skipped.

            --Raise error (not for Batch) when no fees were created because past fees were paid or no fees were created because current or 'future' fees have already been created.
            IF t_totalcount = t_paidcount
           AND (a_runtype <> 'B'
             OR a_runtype IS NULL) THEN
                api.pkg_errors.raiseerror(
                    -20000,
                       'All '
                    || t_priorfeeactivitynice
                    || ' fees have already been paid, and/or '
                    || t_checkexistsnice
                    || ' fees have already been created for this Expiration Date for each License Type.');
            END IF;

            --For Batch, when REN100 and fees were created, pass out ExpireLT as Y
            IF t_totalcount <> t_paidcount
           AND t_feeactivity = 'REN100'
           AND a_runtype = 'B' THEN
                a_expirelt   := 'Y';
            END IF;
        END IF;
    END createrenewalfees;

    ----------------------------------------------------------------------------------------------------
    -- CreateBatch1stRenewalFees() -- PUBLIC
    -- Charges fee for Issue Temporary Permit Permit process
    ----------------------------------------------------------------------------------------------------
    PROCEDURE createbatch1strenewalfees(a_objectid NUMBER, a_asofdate DATE, a_jobid NUMBER)
    IS
        t_temp   VARCHAR(1);
    BEGIN
        FOR z IN (SELECT r.licensetypejobid ltjobid, lt.expirationdate
                    FROM sitespecific.licbatchlictype_xref_t r
                         JOIN query.j_licensetype lt
                         ON lt.objectid = r.licensetypejobid
                   WHERE r.licensebatchjobid = a_jobid
                     AND r.processid = a_objectid  -- added AWP (CXUSA) 5/13/2016 to speed up batch and conform to new "chunking" of batch.
                                                 )
        LOOP
            IF api.pkg_columnquery.VALUE(z.ltjobid, 'RENFeeCreated') = 'N' THEN
                sitespecific.pkg_fees.createrenewalfees(a_objectid,
                                                        NULL,
                                                        z.ltjobid,
                                                        z.expirationdate,
                                                        'Renewal',
                                                        'B',
                                                        t_temp);
            ELSE
                api.pkg_columnupdate.setvalue(z.ltjobid, 'RENFeeCreated', 'N');
            END IF;
        END LOOP;
    END createbatch1strenewalfees;

    ----------------------------------------------------------------------------------------------------
    -- CreateBatchPenaltyFees() --Public
    -- This will create fees on all Related LTs when the Assess 100% or Assess 50% process is completed
    ----------------------------------------------------------------------------------------------------

    PROCEDURE createbatchpenaltyfees(a_objectid      udt_id,
                                     a_asofdate      DATE,
                                     a_jobid         udt_id,
                                     a_objectdefid   udt_id)
    IS
        a_expirationdate       DATE := api.pkg_columnquery.datevalue(a_jobid, 'ExpirationDate');
        t_expirelictype        VARCHAR2(1);
        t_renpenfeetype        VARCHAR2(30);

        t_ren50procesdefid     udt_id := api.pkg_configquery.objectdefidforname('p_Assess50Penalty');
        t_ren100processdefid   udt_id := api.pkg_configquery.objectdefidforname('p_Assess100Penalty');
        t_subject              VARCHAR2(4000);
        t_body                 VARCHAR2(4000);
        t_toaddress            VARCHAR2(4000) := api.pkg_constantquery.VALUE('LICENSINGNOTIFICATIONEMAIL');
        t_ccaddress            VARCHAR2(4000) := api.pkg_constantquery.VALUE('APPLICATIONSUPPORTEMAIL');
    BEGIN
        IF api.pkg_columnquery.VALUE(a_objectid, 'ForceFailure') = 'Y' THEN
            api.pkg_errors.raiseerror(-20000, 'Failure forced by process checkbox');
        END IF;

        IF a_expirationdate IS NULL THEN
            api.pkg_errors.raiseerror(-20000, 'The Expiration Date must have a value.');
        END IF;

        --when it is a Ren 50% penialty type
        IF a_objectdefid = t_ren50procesdefid THEN
            t_renpenfeetype   := '50% Penalty';
        -- else when it is a Ren 100% penialty type
        ELSIF a_objectdefid = t_ren100processdefid THEN
            t_renpenfeetype   := '100% Penalty';
        END IF;

        -- For LTs
        -- Create Renewal Fees
        FOR x IN (SELECT ltc.licensetypejobid ltobjectid
                    FROM sitespecific.licbatchlictype_xref_t ltc
                         JOIN query.j_licensetype lt
                         ON ltc.licensetypejobid = lt.jobid
                   WHERE ltc.licensebatchjobid = a_jobid)
        LOOP
            sitespecific.pkg_fees.createrenewalfees(a_objectid,
                                                    a_asofdate,
                                                    x.ltobjectid,
                                                    a_expirationdate,
                                                    t_renpenfeetype,
                                                    'B',
                                                    t_expirelictype);
        END LOOP;
    EXCEPTION
        WHEN OTHERS THEN
            BEGIN
                t_subject   :=
                       'BATCH: Create Batch Penalty Fees Failed: JobID='
                    || api.pkg_columnquery.VALUE(a_jobid, 'ExternalFileNum');
                t_body   :=
                       'Batch Job FAILED: '
                    || SQLERRM;

                --set flag that an error message email has been sent for this job, do not send a "success" email
                --g_ErrorEmailSent := 'Y';

                pkg_batchtype.emailerrororsuccess(t_toaddress,  --ToAddress
                                                  t_subject,  --Subject
                                                  t_body,  --Body
                                                  NULL,  --[priority] --1 means high priority
                                                  t_ccaddress,  --[ccaddress]
                                                  a_objectid);
            END;

            RAISE;
    END createbatchpenaltyfees;

    /********************************************
    * Create Application Fees
    ********************************************/
    PROCEDURE applicationfeecalc(a_objectid udt_id, a_asofdate DATE, a_jobid udt_id)
    IS
        TYPE feeactivity IS VARRAY(100) OF VARCHAR2(3);

        t_feeactivity        feeactivity := feeactivity();
        t_index              INTEGER;

        t_addprimarylt       VARCHAR2(1);
        t_addrenfee          VARCHAR2(1);
        t_applicationtype    VARCHAR2(40);
        t_createfee          VARCHAR2(1);
        t_createsfee         VARCHAR2(1);
        t_description        VARCHAR2(250);
        t_feeid              udt_id;
        t_feeobjectid        udt_id;
        t_glaccountid        udt_id;
        t_issuedate          DATE;
        t_lttype             VARCHAR2(1);
        t_otherfeecode       VARCHAR2(50);
        t_pertoper           VARCHAR2(1);
        t_pfeeamount         NUMBER;
        t_pfeescheduleid     udt_id;
        t_populationrange    VARCHAR2(100);
        t_prmtoprm           VARCHAR2(1);
        t_relid              udt_id;
        t_sfeeamount         NUMBER;
        t_sfeescheduleid     udt_id;
        t_transactionid      udt_id;
        t_transactionobjid   udt_id;
        t_feescheduleepid    udt_id := api.pkg_configquery.endpointidforname('o_fee', 'LicenseFeeSchedule');
        t_feedefid           udt_id := api.pkg_configquery.objectdefidforname('o_Fee');
        t_count              NUMBER;
        t_tier               VARCHAR2(50) := NULL;  --  03/29/2019 TJL WO 17566
    BEGIN
        -- Set t_ApplicationType to j_Application.ApplicationType
        t_applicationtype   := api.pkg_columnquery.VALUE(a_jobid, 'ApplicationType');

        -- Set t_PerToPer to j_Application.PersonToPerson
        t_pertoper          := api.pkg_columnquery.VALUE(a_jobid, 'PersonToPerson');

        -- Set t_PrmToPrm to j_Application.PremiseToPremise
        t_prmtoprm          := api.pkg_columnquery.VALUE(a_jobid, 'PremiseToPremise');

        -- Set t_AddPrimaryLT to j_Application.AddPrimaryLicenseType
        t_addprimarylt      := api.pkg_columnquery.VALUE(a_jobid, 'AddPrimaryLicenseType');

        -- If this is being run on the Issue License process
        IF api.pkg_columnquery.VALUE(a_objectid, 'ObjectDefName') = 'p_IssueLicense' THEN
            -- Then set t_ReadyToIssueDate to p_IssueLicense.ReadyToIssueDate
            t_issuedate   := api.pkg_columnquery.datevalue(a_objectid, 'ReadyToIssueDate');
        -- Else
        ELSE
            -- Set t_EstimatedIssueDate to j_Application.EstimatedIssueDate
            t_issuedate   :=  --  08/01/2019 TJL  18697   changed to 'CopiesMailed' from 'EstimatedIssueDate'
                             api.pkg_columnquery.datevalue(a_jobid, 'CopiesMailed');
        -- End If
        END IF;

        -- Set t_CreateFee initial value to 'Y'
        t_createfee         := 'Y';

        -- Set t_CreateSFee initial value to 'Y'
        t_createsfee        := 'Y';

        -- Set t_AddRenFee initial value to 'N'
        t_addrenfee         := 'N';

        -- Then set t_PopulationRange from the Premises Address
        BEGIN
            -- If the Application is not a change
            IF (t_applicationtype = 'Original')
            OR (t_applicationtype = 'Transfer'
            AND t_prmtoprm = 'Y') THEN
                -- then get the premises address Population Range
                SELECT addr.populationrange
                  INTO t_populationrange
                  FROM query.j_application a
                       JOIN query.r_applicationpremaddr apa
                       ON a.jobid = apa.applicationjobid
                       JOIN query.o_address addr
                       ON addr.objectid = apa.addressobjectid
                 WHERE a.jobid = a_jobid;
            -- Else if the Application is a change
            ELSIF t_applicationtype = 'Change' THEN
                -- Get the Population Range off the premises address on the related License
                SELECT ad.populationrange
                  INTO t_populationrange
                  FROM query.j_application a
                       JOIN query.r_applicationlicense al
                       ON al.applicationjobid = a.jobid
                       JOIN query.j_license l
                       ON l.jobid = al.licensejobid
                       JOIN query.r_licenseaddrpremises lap
                       ON lap.licensejobid = l.jobid
                       JOIN query.o_address ad
                       ON ad.objectid = lap.premisesobjectid
                 WHERE a.jobid = a_jobid;
            -- Else if the Application is a transfer, but is NOT a Prem to Prem
            ELSIF t_applicationtype = 'Transfer'
              AND t_prmtoprm != 'Y' THEN
                -- then get the Population Range off the premises address on the License Transferring From
                SELECT ad.populationrange
                  INTO t_populationrange
                  FROM query.j_application a
                       JOIN query.r_applicationlicensetransfer alt
                       ON alt.apptransferredtoobjectid = a.jobid
                       JOIN query.j_license l
                       ON l.jobid = alt.licensetransferredfromobjectid
                       JOIN query.r_licenseaddrpremises lap
                       ON lap.licensejobid = l.jobid
                       JOIN query.o_address ad
                       ON ad.objectid = lap.premisesobjectid
                 WHERE a.jobid = a_jobid;
            -- End If
            END IF;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                api.pkg_errors.raiseerror(
                    -20000,
                       'CA City related to the Premises Address related to the Application '
                    || a_jobid
                    || ', or related to the License related to this Application, cannot be found.');
        END;

        -- 04/08/2019 TJL WO 17620 Added new procedure for creating APP fees
        -- Create the APP fee for application
        sitespecific.createappfee(a_objectid, a_asofdate, a_jobid);


        -- For LTs
        -- Get LT Code
        -- Get GallonageRange
        -- Get NumberOfMonthsLicensed
        -- Get IsBranch (If MasterLicenseType is not null)
        -- Get AddRenewalFee
        -- Get ManualFee LOOP:
        FOR x IN (SELECT plt.objectid                         pltobjectid,
                         plt.licensetypecode,
                         ltc.gallonageapplies,
                         plt.gallonagerange,
                         NVL(plt.additionalmilliongallons, 0) additionalmilliongallons,
                         NVL(plt.primarycount, 0)             primarycount,
                         plt.numberofmonthslicensedfeecode,
                         plt.isbranchs                        isbranch,  /* changed the select to the currect from case when plt.MasterLicenseType is not null then 'Y' else 'N' end*/
                         plt.conda,
                         plt.istransferred,
                         plt.addrenewalfee,
                         plt.manualfee,
                         plt.prioritydrawlicensetype,
                         ltc.populationapplies,
                         ltc.seasonalmonthsapply,
                         plt.secondaryltobjectids,
                         ltc.prioritydrawlicensetype          pdlt
                    FROM query.r_appprimarylicensetype aplt
                         JOIN query.o_primarylicensetype plt
                         ON aplt.licensetypeobjectid = plt.objectid
                         JOIN query.r_priltltcatprimary pltltc
                         ON plt.objectid = pltltc.primarylicensetypeobjectid
                         JOIN query.o_licensetypecategory ltc
                         ON pltltc.licensetypecategoryobjectid = ltc.objectid
                   WHERE aplt.applicationobjectid = a_jobid
                     -- 11/18/2019 TJL 19788 only process pending fees
                     AND plt.status = 'PENDING')
        LOOP
            --******************************************************************
            --  new logic for fee codes
            --******************************************************************
            -- Set t_index to 0
            t_index   := 0;

            -- 04/08/2019 TJL WO 17620 Removed creating APP (ORI) from code creating
            --   fee activity.
            CASE
                WHEN ((t_applicationtype = 'Original')
                   OR  -- 05/24/2019 TJL WO 17565 check for transfer application
                       --    adding another license type
                      (x.istransferred = 'N'
                   AND api.pkg_columnquery.VALUE(x.pltobjectid, 'applicationtype') = 'Transfer')) THEN
                    IF (x.isbranch = 'Y') THEN
                        -- Set t_FeeActivityType to 'DOR'
                        t_index                  := t_index + 1;
                        t_feeactivity.EXTEND;
                        t_feeactivity(t_index)   := 'DOR';
                    ELSE  -- branch = 'N'
                        -- No ANN fee if the LT = 80/67 or priority
                        --  this is handled by not having ANN fee records for 67 and 80
                        t_index                  := t_index + 1;
                        t_feeactivity.EXTEND;
                        t_feeactivity(t_index)   := 'ANN';

                        IF x.licensetypecode IN ('80', '67') THEN
                            -- Set t_FeeActivityType to 'DOR'
                            t_index                  := t_index + 1;
                            t_feeactivity.EXTEND;
                            t_feeactivity(t_index)   := 'DOR';
                        END IF;
                    END IF;
                WHEN t_applicationtype = 'Transfer' THEN
                    IF t_pertoper = 'Y' THEN
                        IF (x.licensetypecode NOT IN ('80', '67'))
                       AND x.isbranch != 'Y' THEN
                            -- Set t_FeeActivityType to 'ANN'
                            t_index                  := t_index + 1;
                            t_feeactivity.EXTEND;
                            t_feeactivity(t_index)   := 'ANN';
                        ELSE
                            t_index                  := t_index + 1;
                            t_feeactivity.EXTEND;
                            t_feeactivity(t_index)   := 'DOR';
                        END IF;
                    END IF;

                    -- TJL 02/27/2018 WO14321
                    -- Intercounry Transfer
                    IF (x.prioritydrawlicensetype = 'Y') THEN
                        t_index                  := t_index + 1;
                        t_feeactivity.EXTEND;
                        t_feeactivity(t_index)   := 'ANN';
                    END IF;
                WHEN t_applicationtype = 'Change' THEN
                    -- 11/18/2019 TJL WO19788 Added testing for branch
                    CASE
                        WHEN (t_addprimarylt = 'Y')
                         AND x.isbranch != 'Y' THEN
                            -- Set t_FeeActivityType to 'ANN'
                            t_index                  := t_index + 1;
                            t_feeactivity.EXTEND;
                            t_feeactivity(t_index)   := 'ANN';
                        --  12/30/2019 TJL WO 20134 added test for exchange only to not create DOR fee
                        WHEN api.pkg_columnquery.VALUE(a_jobid, 'IsExchangeOnly') = 'N' THEN
                            t_index                  := t_index + 1;
                            t_feeactivity.EXTEND;
                            t_feeactivity(t_index)   := 'DOR';
                        ELSE
                            NULL;
                    END CASE;
                ELSE
                    CONTINUE;
            END CASE;

            IF x.addrenewalfee = 'Y' THEN
                t_index                  := t_index + 1;
                t_feeactivity.EXTEND;
                t_feeactivity(t_index)   := 'REN';
                t_addrenfee              := 'Y';
            END IF;

            -- For each Applicable Fee Activity Type LOOP:
            FOR c IN 1 .. t_feeactivity.COUNT
            LOOP
                -- If IsBranch = 'Y'
                IF x.isbranch = 'Y'  -- Then t_LTType := 'B'
                                    THEN
                    t_lttype   := 'B';
                -- Else
                ELSE
                    -- Then t_LTType := 'P'
                    t_lttype   := 'P';
                -- End If
                END IF;

                -- Get the GL Account Id for the Fee Activity Type
                BEGIN
                    SELECT gl.glaccountid
                      INTO t_glaccountid
                      FROM api.glaccounts gl
                     WHERE gl.glaccount = t_feeactivity(c);
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        t_glaccountid   := 332550;  -- MISC MISCELLANEOUS
                END;

                -- Pass the fee amount into t_PFeeAmount, and the Fee Schedule Id into t_FeeScheduleId
                sitespecific.pkg_fees.getltfeeamount(
                    a_jobid,
                    t_issuedate,
                    t_feeactivity(c),
                    t_otherfeecode,
                    x.licensetypecode,
                    CASE
                        WHEN x.gallonageapplies = 'Y'
                         AND t_feeactivity(c) NOT IN ('MOD') THEN
                            x.gallonagerange
                        ELSE
                            NULL
                    END,
                    x.additionalmilliongallons,
                    CASE WHEN x.seasonalmonthsapply = 'Y' THEN x.numberofmonthslicensedfeecode ELSE NULL END,
                    CASE WHEN x.populationapplies = 'Y' THEN t_populationrange ELSE NULL END,
                    t_tier,  -- 04/01/2019 TJL WO 17620
                    t_lttype,
                    x.primarycount,
                    NULL,
                    t_pfeeamount,
                    t_pfeescheduleid);

                -- For SecondaryLTs
                -- Get LT Code
                -- Get LT Count LOOP:
                FOR z IN (SELECT ltc.gallonageapplies,
                                 ltc.licensetypecode,
                                 sltc.licensetypecount,
                                 ltc.populationapplies,
                                 ltc.seasonalmonthsapply,
                                 sltc.istransferred
                            FROM query.r_priltltcatsecondary sltc
                                 JOIN query.o_licensetypecategory ltc
                                 ON sltc.licensetypecategoryobjectid = ltc.objectid
                           WHERE sltc.primarylicensetypeobjectid = x.pltobjectid)
                LOOP
                    t_lttype   := 'S';

                    -- if the Fee Activity Code is ANN or the SLT is Transferred and then don't create the secondary fee.
                    IF (z.istransferred = 'N'
                    AND x.istransferred = 'Y')
                    OR (t_feeactivity(c) = 'ANN'  /*and z.LicenseTypeCode <> x.LicenseTypeCode*/
                    AND z.istransferred = 'N') THEN
                        NULL;
                    ELSE
                        -- then Pass the fee amount into t_SFeeAmount, and the Fee Schedule Id into t_FeeScheduleId
                        sitespecific.pkg_fees.getltfeeamount(
                            a_jobid,
                            t_issuedate,
                            t_feeactivity(c),
                            NULL,
                            z.licensetypecode,
                            NULL,  -- Gallonage Range does not apply to Secondaries.
                            NULL,
                            CASE WHEN z.seasonalmonthsapply = 'Y' THEN x.numberofmonthslicensedfeecode ELSE NULL END,
                            CASE
                                WHEN z.populationapplies = 'Y'
                                 AND z.licensetypecode NOT IN ('68') THEN  -- Added by Pawan for new LT 88 on 12/20/2018 WO 16989
                                    t_populationrange
                                WHEN x.licensetypecode IN (50, 51, 52)
                                 AND z.licensetypecode = 58
                                  OR x.licensetypecode IN (47,
                                                           48,
                                                           50,
                                                           51,
                                                           52,
                                                           57,
                                                           64,
                                                           70,
                                                           71,
                                                           72,
                                                           75,  -- Added by Pawan for new LT 88 on 12/20/2018 WO 16989
                                                           99,  -- Added by Sheik for new LT 99 on 9/28/2019
                                                           90   --12/28/2022 PK WO 30274   Added code to make type 68 work when added as secondary on new LT 90
                                                              )
                                 AND z.licensetypecode = 68 THEN
                                    t_populationrange
                                ELSE
                                    NULL
                            END,
                            t_tier,  -- 04/01/2019 TJL WO 17620
                            t_lttype,
                            z.licensetypecount,
                            NULL,
                            t_sfeeamount,
                            t_sfeescheduleid);

                        -- If Secondary LT Code = Primary LT Code
                        IF z.licensetypecode = x.licensetypecode THEN
                            -- Add the Primary Lt Fee Amount to the Secondary Fee Amount
                            t_sfeeamount    := t_sfeeamount + t_pfeeamount;

                            -- Get the Description for the fee
                            t_description   := api.pkg_columnquery.VALUE(t_pfeescheduleid, 'ProcedureDescription');

                            -- Set t_CreateFee to 'N' so that this fee will not be adjusted/re-created in some form later in the procedure
                            t_createfee     := 'N';

                            -- Check for Existing Fees and Adjust ones that need it
                            sitespecific.pkg_fees.checkexistingfees(  --' - Primary, '|| -- out dated 2009_3_19
                                'N',
                                t_description,
                                x.addrenewalfee,
                                t_feeactivity(c),
                                NULL,
                                t_sfeeamount,
                                t_sfeescheduleid,
                                CASE WHEN z.gallonageapplies = 'Y' THEN x.gallonagerange ELSE NULL END,
                                t_glaccountid,
                                'Y',
                                'Y',
                                a_jobid,
                                z.licensetypecode,
                                z.licensetypecount,
                                CASE
                                    WHEN z.seasonalmonthsapply = 'Y' THEN x.numberofmonthslicensedfeecode
                                    ELSE NULL
                                END,
                                CASE
                                    WHEN z.populationapplies = 'Y'
                                     AND z.licensetypecode NOT IN ('68') THEN  ---- Added by Pawan for new LT 88 on 12/20/2018 WO 16989
                                        t_populationrange
                                    WHEN x.licensetypecode IN (50, 51, 52)
                                     AND z.licensetypecode = 58
                                      OR x.licensetypecode IN (47,
                                                               48,
                                                               50,
                                                               51,
                                                               52,
                                                               57,
                                                               64,
                                                               70,
                                                               71,
                                                               72,
                                                               75,  -- Added by Pawan for new LT 88 on 12/20/2018 WO 16989
                                                               99,  -- Added by Sheik for new LT 99 on 9/28/2019
                                                               90   --12/16/2022 PK WO 30274   Added code to make type 68 work when added as secondary on new LT 90
                                                                 )
                                     AND z.licensetypecode = 68 THEN
                                        t_populationrange
                                    ELSE
                                        NULL
                                END,
                                t_tier,  --  03/29/2019 TJL WO 17566
                                x.secondaryltobjectids,
                                t_createsfee,
                                t_feeid);

                            IF t_createsfee = 'Y'
                           AND t_sfeeamount >= 0 THEN
                                -- CreateFees. This will pass the api Fee Id into t_FeeId, and the POSSE Fee ObjectId into t_FeeObjectId
                                sitespecific.pkg_fees.newfee(t_feeid,
                                                             t_sfeeamount,
                                                             t_description,
                                                             t_glaccountid,
                                                             a_jobid,
                                                             NULL,
                                                             t_feeobjectid);
                                -- Relate Fee to Fee Schedule
                                t_relid        :=
                                    api.pkg_relationshipupdate.new(
                                        api.pkg_configquery.endpointidforname('o_Fee', 'LicenseFeeSchedule'),
                                        t_feeobjectid,
                                        t_pfeescheduleid);
                                -- Set the relationship detail MasterLT
                                api.pkg_columnupdate.setvalue(t_relid, 'MasterLT', x.licensetypecode);
                                -- Set the relationship detail IsMaster 'Y'
                                api.pkg_columnupdate.setvalue(t_relid, 'IsMaster', 'Y');
                                -- Set the relationship detail SecondaryCount to the count of secondary LTs
                                api.pkg_columnupdate.setvalue(t_relid, 'SecondaryCount', z.licensetypecount);

                                -- t_CreateFee := 'N'
                                t_createsfee   := 'N';

                                -- Set the Quantity on the Fee Object
                                api.pkg_columnupdate.setvalue(t_feeobjectid, 'Quantity', z.licensetypecount);
                            -- End If
                            END IF;
                        -- Else
                        ELSIF t_feeactivity(c) <> 'ANN' THEN
                            -- Get the Description for the fee
                            t_description   := api.pkg_columnquery.VALUE(t_sfeescheduleid, 'ProcedureDescription');

                            -- Check for Existing Fees and Adjust ones that need it
                            sitespecific.pkg_fees.checkexistingfees(  --' - Secondary, '|| --out dated 2009_3_19
                                'N',
                                t_description,
                                x.addrenewalfee,
                                t_feeactivity(c),
                                NULL,
                                t_sfeeamount,
                                t_sfeescheduleid,
                                CASE WHEN z.gallonageapplies = 'Y' THEN x.gallonagerange ELSE NULL END,
                                t_glaccountid,
                                'Y',
                                'N',
                                a_jobid,
                                z.licensetypecode,
                                z.licensetypecount,
                                CASE
                                    WHEN z.seasonalmonthsapply = 'Y' THEN x.numberofmonthslicensedfeecode
                                    ELSE NULL
                                END,
                                CASE
                                    WHEN z.populationapplies = 'Y'
                                     AND z.licensetypecode NOT IN ('68') THEN  ---- Added by Pawan for new LT 88 on 12/20/2018 WO 16989
                                        t_populationrange
                                    WHEN x.licensetypecode IN (50, 51, 52)
                                     AND z.licensetypecode = 58
                                      OR x.licensetypecode IN (47,
                                                               48,
                                                               50,
                                                               51,
                                                               52,
                                                               57,
                                                               64,
                                                               70,
                                                               71,
                                                               72,
                                                               75,  -- Added by Pawan for new LT 88 on 12/20/2018 WO 16989
                                                               99,  -- Added by Sheik for new LT 99 on 9/28/2019
                                                               90   --12/16/2022 PK WO 30274   Added code to make type 68 work when added as secondary on new LT 90
                                                                 )
                                     AND z.licensetypecode = 68 THEN
                                        t_populationrange
                                    ELSE
                                        NULL
                                END,
                                t_tier,  --  03/29/2019 TJL WO 17566
                                x.secondaryltobjectids,
                                t_createsfee,
                                t_feeid);

                            IF t_createsfee = 'Y'
                           AND t_sfeeamount >= 0 THEN
                                -- CreateFees. This will pass the api Fee Id into t_FeeId, and the POSSE Fee ObjectId into t_FeeObjectId
                                sitespecific.pkg_fees.newfee(t_feeid,
                                                             t_sfeeamount,
                                                             t_description,
                                                             t_glaccountid,
                                                             a_jobid,
                                                             NULL,
                                                             t_feeobjectid);

                                -- Relate Fee to Fee Schedule
                                t_relid   :=
                                    api.pkg_relationshipupdate.new(
                                        api.pkg_configquery.endpointidforname('o_Fee', 'LicenseFeeSchedule'),
                                        t_feeobjectid,
                                        t_sfeescheduleid);

                                -- Set the relationship detail MasterLT
                                api.pkg_columnupdate.setvalue(t_relid, 'MasterLT', x.licensetypecode);
                                -- Set the relationship detail IsMaster to 'N'
                                api.pkg_columnupdate.setvalue(t_relid, 'IsMaster', 'N');
                                -- Set the relationship detail SecondaryCount to the count of secondary LTs
                                api.pkg_columnupdate.setvalue(t_relid, 'SecondaryCount', z.licensetypecount);

                                -- Set the Quantity on the Fee Object
                                api.pkg_columnupdate.setvalue(t_feeobjectid, 'Quantity', z.licensetypecount);
                            -- End If
                            END IF;
                        -- End If
                        END IF;
                    -- End if not in ORI or ANN
                    END IF;
                -- End Secondary LT Loop
                END LOOP;

                -- If t_CreateFee = 'Y'
                IF t_createfee = 'Y' THEN
                    -- Get the Description for the fee
                    t_description   := api.pkg_columnquery.VALUE(t_pfeescheduleid, 'ProcedureDescription');

                    -- Check for Existing Fees and Adjust ones that need it
                    sitespecific.pkg_fees.checkexistingfees(
                        'N',
                        t_description,
                        x.addrenewalfee,
                        t_feeactivity(c),
                        t_otherfeecode,
                        t_pfeeamount,
                        t_pfeescheduleid,
                        CASE WHEN x.gallonageapplies = 'Y' THEN x.gallonagerange ELSE NULL END,
                        t_glaccountid,
                        'N',
                        CASE WHEN x.isbranch = 'Y' THEN 'N' ELSE 'Y' END,
                        --'Y', --IsMaster
                        a_jobid,
                        x.licensetypecode,
                        CASE WHEN x.isbranch = 'Y' THEN 1 ELSE x.additionalmilliongallons + x.primarycount END,
                        --x.AdditionalMillionGallons + x.primarycount, --LTCount
                        CASE WHEN x.seasonalmonthsapply = 'Y' THEN x.numberofmonthslicensedfeecode ELSE NULL END,
                        CASE WHEN x.populationapplies = 'Y' THEN t_populationrange ELSE NULL END,
                        t_tier,  --  03/29/2019 TJL WO 17566
                        x.secondaryltobjectids,
                        t_createfee,
                        t_feeid);

                    IF t_createfee = 'Y'
                   AND t_pfeeamount >= 0 THEN
                        -- CreateFees. This will pass the api Fee Id into t_FeeId, and the POSSE Fee ObjectId into t_FeeObjectId
                        sitespecific.pkg_fees.newfee(t_feeid,
                                                     t_pfeeamount,
                                                     --x.LicenseTypeCode||' - Primary, '|| -- out dated 2009_3_19
                                                     t_description,
                                                     t_glaccountid,
                                                     a_jobid,
                                                     NULL,
                                                     t_feeobjectid);

                        -- Relate Fee to Fee Schedule
                        t_relid   :=
                            api.pkg_relationshipupdate.new(
                                api.pkg_configquery.endpointidforname('o_Fee', 'LicenseFeeSchedule'),
                                t_feeobjectid,
                                t_pfeescheduleid);

                        -- Set the relationship detail MasterLT to the License Type Code
                        api.pkg_columnupdate.setvalue(t_relid, 'MasterLT', x.licensetypecode);

                        -- Set the relationship detail IsMaster to 'Y'
                        api.pkg_columnupdate.setvalue(t_relid,
                                                      'IsMaster',
                                                      CASE WHEN x.isbranch = 'Y' THEN 'N' ELSE 'Y' END);

                        -- Set the relationship detail SecondaryCount to the count of secondary LTs
                        api.pkg_columnupdate.setvalue(
                            t_relid,
                            'SecondaryCount',
                            CASE WHEN x.isbranch = 'Y' THEN 1 ELSE x.additionalmilliongallons + x.primarycount END);
                    -- End If
                    END IF;
                -- End If
                END IF;

                -- If t_CreateFee = 'N'
                IF t_createfee = 'N' THEN
                    -- t_CreateFee := 'Y'
                    t_createfee   := 'Y';
                -- End If
                END IF;
            -- End Fee Activity Loop
            END LOOP;

            -- Remove the values from t_FeeActivity
            t_feeactivity.TRIM(t_feeactivity.COUNT);

            -- If this is not a Add Primary LT Change APP
            --If t_AddPrimaryLT != 'Y' then Changed by Pawan related to ticket 2131- add permit license type
            -- Loop through the Secondary LTs and add the DOR fees
            FOR z IN (SELECT ltc.gallonageapplies,
                             sltc.istransferred,
                             ltc.licensetypecode,
                             sltc.licensetypecount,
                             ltc.populationapplies,
                             ltc.seasonalmonthsapply
                        FROM query.r_priltltcatsecondary sltc
                             JOIN query.o_licensetypecategory ltc
                             ON sltc.licensetypecategoryobjectid = ltc.objectid
                       WHERE sltc.primarylicensetypeobjectid = x.pltobjectid)
            LOOP
                IF z.istransferred = 'N'
                OR (z.istransferred = 'Y'
                AND z.licensetypecode <> x.licensetypecode
                AND (t_pertoper = 'Y'  --or t_PrmToPrm = 'Y' --BA REMOVED UNDER CMAS III ISSUE 2271
                                     --or t_DropPartner = 'Y'--BA REMOVED UNDER CMAS III ISSUE 2271
                                     --or t_MembershipTrans = 'Y'--BA REMOVED UNDER CMAS III ISSUE 2271
                                     --or t_StockTransfer = 'Y'--BA REMOVED UNDER CMAS III ISSUE 2271
                                     )) THEN
                    -- t_LTType := 'S'
                    t_lttype        := 'S';

                    -- Get the GL Account Id for the DOR Fee Activity Type
                    BEGIN
                        SELECT gl.glaccountid
                          INTO t_glaccountid
                          FROM api.glaccounts gl
                         WHERE gl.glaccount = 'DOR';
                    EXCEPTION
                        WHEN NO_DATA_FOUND THEN
                            api.pkg_errors.raiseerror(-20000,
                                                         'No GL Account exists for Fee Activity '
                                                      || 'DOR');
                    END;

                    -- then Pass the fee amount into t_SFeeAmount, and the Fee Schedule Id into t_FeeScheduleId
                    sitespecific.pkg_fees.getltfeeamount(
                        a_jobid,
                        t_issuedate,
                        'DOR',
                        NULL,
                        z.licensetypecode,
                        NULL,  -- Gallonage Range does not apply to Secondaries.
                        NULL,
                        CASE WHEN z.seasonalmonthsapply = 'Y' THEN x.numberofmonthslicensedfeecode ELSE NULL END,
                        CASE
                            WHEN z.populationapplies = 'Y'
                             AND z.licensetypecode NOT IN ('68') THEN  --Added by Pawan for new LT 88 on 12/20/2018 WO 16989
                                t_populationrange
                            WHEN x.licensetypecode IN (50, 51, 52)
                             AND z.licensetypecode = 58
                              OR x.licensetypecode IN (47,
                                                       48,
                                                       50,
                                                       51,
                                                       52,
                                                       57,
                                                       64,
                                                       70,
                                                       71,
                                                       72,
                                                       75,  -- Added by Pawan for new LT 88 on 12/20/2018 WO 16989
                                                       99,  -- Added by Sheik for new LT 99 on 9/28/2019
                                                       90   --12/16/2022 PK WO 30274   Added code to make type 68 work when added as secondary on new LT 90
                                                          )
                             AND z.licensetypecode = 68 THEN
                                t_populationrange
                            ELSE
                                NULL
                        END,
                        NULL,  -- t_tier do not apply to DOR (secondarys),
                        t_lttype,
                        z.licensetypecount,
                        NULL,
                        t_sfeeamount,
                        t_sfeescheduleid);

                    -- Get the Description for the fee
                    t_description   := api.pkg_columnquery.VALUE(t_sfeescheduleid, 'ProcedureDescription');

                    -- Check for Existing Fees and Adjust ones that need it
                    sitespecific.pkg_fees.checkexistingfees(  --' - Secondary, '|| --out dated 2009_3_19
                        'N',
                        t_description,
                        x.addrenewalfee,
                        'DOR',
                        NULL,
                        t_sfeeamount,
                        t_sfeescheduleid,
                        NULL,  -- Gallonage Range does not apply to Secondaries.
                        t_glaccountid,
                        'Y',
                        'N',
                        a_jobid,
                        z.licensetypecode,
                        z.licensetypecount,
                        CASE WHEN z.seasonalmonthsapply = 'Y' THEN x.numberofmonthslicensedfeecode ELSE NULL END,
                        CASE
                            WHEN z.populationapplies = 'Y'
                             AND z.licensetypecode NOT IN ('68') THEN  --Added by Pawan for new LT 88 on 12/20/2018 WO 16989
                                t_populationrange
                            WHEN x.licensetypecode IN (50, 51, 52)
                             AND z.licensetypecode = 58
                              OR x.licensetypecode IN (47,
                                                       48,
                                                       50,
                                                       51,
                                                       52,
                                                       57,
                                                       64,
                                                       70,
                                                       71,
                                                       72,
                                                       75,  -- Added by Pawan for new LT 88 on 12/20/2018 WO 16989
                                                       99,  -- Added by Sheik for new LT 99 on 9/28/2019
                                                       90   --12/16/2022 PK WO 30274   Added code to make type 68 work when added as secondary on new LT 90
                                                          )
                             AND z.licensetypecode = 68 THEN
                                t_populationrange
                            ELSE
                                NULL
                        END,
                        NULL,  -- t_tier, --  03/29/2019 TJL WO 17566 Tier do not apply to DOR (secondarys)
                        x.secondaryltobjectids,
                        t_createsfee,
                        t_feeid);

                    /*
                    Priority Item #5B - check for voided payments for the secondary license type fee.
                    if payments for the secondary license type have been voided and
                    if the secondary license type has been added back then
                    create a new fee line for the secondary license type
                    */
                    IF t_createsfee = 'N'
                   AND t_sfeeamount > 0 THEN
                        SELECT COUNT(f.feeid)
                          INTO t_count
                          FROM api.fees f
                               JOIN api.registeredexternalobjects reo
                               ON reo.linkvalue = TO_CHAR(f.feeid)
                              AND reo.objectdefid = t_feedefid
                               JOIN api.relationships r
                               ON r.fromobjectid = reo.objectid
                               JOIN sitespecific.feeschedule_t fs
                               ON fs.objectid = r.toobjectid
                         WHERE f.jobid = a_jobid
                           AND r.endpointid = t_feescheduleepid
                           AND f.amount > 0
                           AND f.description LIKE
                                      z.licensetypecode
                                   || ' - DOR%'
                           AND EXISTS
                                   (SELECT 1
                                      FROM api.feetransactions ft
                                           JOIN api.paymenttransactions pt
                                           ON pt.transactionid = ft.transactionid
                                     WHERE ft.feeid = f.feeid
                                       AND pt.voidedbytransactionid IS NOT NULL);

                        --create a new fee for the secondary license tye
                        IF t_count > 0 THEN
                            t_createsfee   := 'Y';
                        END IF;
                    END IF;

                    IF t_createsfee = 'Y'
                   AND t_sfeeamount >= 0 THEN
                        -- CreateFees. This will pass the api Fee Id into t_FeeId, and the POSSE Fee ObjectId into t_FeeObjectId
                        sitespecific.pkg_fees.newfee(t_feeid,
                                                     t_sfeeamount,
                                                     --z.LicenseTypeCode||' - Secondary, ' || -- out dated 2009_3_19
                                                     t_description,
                                                     t_glaccountid,
                                                     a_jobid,
                                                     NULL,
                                                     t_feeobjectid);
                        -- Relate Fee to Fee Schedule
                        t_relid   :=
                            api.pkg_relationshipupdate.new(
                                api.pkg_configquery.endpointidforname('o_Fee', 'LicenseFeeSchedule'),
                                t_feeobjectid,
                                t_sfeescheduleid);

                        -- Set the relationship detail MasterLT
                        api.pkg_columnupdate.setvalue(t_relid, 'MasterLT', x.licensetypecode);
                        -- Set the relationship detail IsMaster to 'N'
                        api.pkg_columnupdate.setvalue(t_relid, 'IsMaster', 'N');
                        -- Set the relationship detail SecondaryCount to the count of secondary LTs
                        api.pkg_columnupdate.setvalue(t_relid, 'SecondaryCount', z.licensetypecount);

                        -- Set the Quantity on the Fee Object
                        api.pkg_columnupdate.setvalue(t_feeobjectid, 'Quantity', z.licensetypecount);
                    -- End If
                    END IF;
                END IF;
            -- End Secondary LT Loop
            END LOOP;
        -- End If
        --            END IF;
        -- End If Not Priority LT
        -- End If;changed by pawan

        -- End Primary LT Loop
        END LOOP;

        -- Loop through the existing fees and adjust ones that do not correspond to an existing LT to 0
        -- RyanL: Changed the select and where clause to be a subselect for performance (PIP Task 8.5)
        FOR c IN (SELECT f.feeid
                             feeid,
                         (  f.amount
                          + NVL((SELECT SUM(amount)
                                   FROM api.feetransactions ft
                                  WHERE ft.feeid = f.feeid),
                                0))
                             totalowing,
                         fs.objectid,
                         fs.licensetypecode
                    FROM api.fees f
                         JOIN sitespecific.feeschedule_t fs
                         ON fs.objectid = sitespecific.pkg_fees.getlicfeeschedulobjid(f.feeid)
                   WHERE f.jobid = a_jobid
                     AND fs.licensetypecode IS NOT NULL
                     AND (  f.amount
                          + NVL((SELECT SUM(amount)
                                   FROM api.feetransactions ft
                                  WHERE ft.feeid = f.feeid),
                                0)) > 0
                     AND (fs.licensetypecode NOT IN (SELECT plt.licensetypecode
                                                       FROM query.j_application a
                                                            JOIN query.r_appprimarylicensetype aplt
                                                            ON a.jobid = aplt.applicationobjectid
                                                            JOIN query.o_primarylicensetype plt
                                                            ON aplt.licensetypeobjectid = plt.objectid
                                                      WHERE a.jobid = a_jobid)
                      AND fs.licensetypecode NOT IN (SELECT ltc.licensetypecode
                                                       FROM query.j_application a
                                                            JOIN query.r_appprimarylicensetype aplt
                                                            ON a.jobid = aplt.applicationobjectid
                                                            JOIN query.o_primarylicensetype plt
                                                            ON aplt.licensetypeobjectid = plt.objectid
                                                            JOIN query.r_priltltcatsecondary psec
                                                            ON plt.objectid = psec.primarylicensetypeobjectid
                                                            JOIN query.o_licensetypecategory ltc
                                                            ON psec.licensetypecategoryobjectid = ltc.objectid
                                                      WHERE a.jobid = a_jobid)))
        LOOP
            pkg_debug.putline('Application Fee Calc - adjusting fee ');

            t_transactionid      :=
                api.pkg_feeupdate.adjust(c.feeid,
                                         ROUND(-c.totalowing),
                                            api.pkg_columnquery.VALUE(c.objectid, 'ProcedureDescription')
                                         || ', Removed',
                                         SYSDATE);

            -- Register the adjust transaction object
            t_transactionobjid   := api.pkg_objectupdate.registerexternalobject('o_FeeTransactions', t_transactionid);
        -- End Loop
        END LOOP;
    END applicationfeecalc;

    /***********************************************************************************************
    ** FUNCTION SecLTCLicenseTypeCount(ProcessId, LTCId)
    ** This function is for returning the License Type Count of the Secondary License Type related
    ** to the License Type job related to the License of the Add Permit/License Type to License
    ** process. The variables that are passed in are the ProcessId and the License Type Category
    ** ObjectId.
    ***********************************************************************************************/
    FUNCTION secltclicensetypecount(a_processid udt_id, a_ltcid udt_id, a_masterltcode VARCHAR2)
        RETURN NUMBER
    IS
        t_licensetypecount   NUMBER;
    BEGIN
        BEGIN
            SELECT COUNT(d.objectid)
              INTO t_licensetypecount
              FROM query.p_addpermitlttolicense aplt2
                   JOIN query.j_license l2
                   ON aplt2.jobid = l2.jobid
                   JOIN query.r_licenselicensetype llt2
                   ON l2.jobid = llt2.licensejobid
                   JOIN query.j_licensetype lt2
                   ON llt2.licensetypejobid = lt2.jobid
                   JOIN query.r_licensetypeltcatsecondary lts
                   ON lt2.jobid = lts.licensetypejobid
                   JOIN query.o_licensetypecategory ltc2
                   ON lts.licensetypecategoryobjectid = ltc2.objectid
                   JOIN sitespecific.duplicate_t dt
                   ON dt.licensetypejobid = lt2.objectid
                   JOIN query.o_duplicate d
                   ON d.objectid = dt.duplicateid
                  AND d.licensetypecategoryobjectid = ltc2.objectid
             --and d.LicenseTypeCategoryObjectID = ltc2.ObjectId
             WHERE aplt2.processid = a_processid
               AND lt2.licensetypecode = a_masterltcode
               AND ltc2.objectid = a_ltcid
               AND d.batchdate IS NULL;
        /* select lts.LicenseTypeCount
        into t_LicenseTypeCount
        from query.p_AddPermitLTToLicense aplt2
        join query.j_License l2 on aplt2.JobId = l2.JobId
        join query.r_LicenseLicenseType llt2 on l2.JobId =
        llt2.LicenseJobId
        join query.j_LicenseType lt2 on llt2.LicenseTypeJobId = lt2.JobId
        join query.r_LicenseTypeLTCatSecondary lts on lt2.JobId =
        lts.LicenseTypeJobId
        join query.o_LicenseTypeCategory ltc2 on lts.LicenseTypeCategoryObjectId =
        ltc2.ObjectId
        where aplt2.ProcessId = a_ProcessId
        and lt2.licensetypecode = a_MasterLTCode
        and ltc2.ObjectId = a_LTCId;*/
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                t_licensetypecount   := NULL;
        END;

        RETURN t_licensetypecount;
    END secltclicensetypecount;

    /**************************************
    ** License Fee Calc
    **************************************/
    PROCEDURE licensefeecalc(a_objectid udt_id, a_asofdate DATE, a_jobid udt_id)
    IS
        TYPE feeactivity IS VARRAY(100) OF VARCHAR2(3);

        t_feeactivity       feeactivity := feeactivity(1);
        t_index             INTEGER;
        t_description       VARCHAR2(50);
        t_feeamount         NUMBER;
        t_feeid             udt_id;
        t_feeobjectid       udt_id;
        t_feescheduleid     udt_id;
        t_glaccountid       udt_id;
        t_populationrange   VARCHAR2(40);
        t_relid             udt_id;
        l_lt_count          NUMBER;

        CURSOR get_secondarylt_recs
        IS
            (SELECT ltc.gallonageapplies,
                    NVL(ltp.reapply, 'N') reapply,
                    ltc.licensetypecode,
                    ltp.masterltcode,
                    ltp.numberofmonthslicensedfeecode,
                    ltp.gallonagerange,
                    ltp.manualfee,
                    ltc.populationapplies,
                    ltc.seasonalmonthsapply,
                    aplt.processid        rec_objectid,
                    llt.licensejobid      rec_jobid,
                    llt.licensetypejobid  licensetypejobid,
                    ltc.objectid          licensetypecatobjectid,
                    ltps.status           status
               FROM query.p_addpermitlttolicense aplt
                    JOIN query.r_addpermitlttopendlt applt
                    ON aplt.processid = applt.addpermitltprocessid
                    JOIN query.o_pendinglicensetype plt  --Fix these?.
                    ON applt.pendinglicensetypeobjectid = plt.objectid  --Fix these?.
                    JOIN query.r_addpermitlttolicpendltc ltp
                    ON plt.objectid = ltp.pendinglicensetypeobjid
                    JOIN query.o_licensetypecategory ltc
                    ON ltp.licensetypecategoryobjectid = ltc.objectid
                    JOIN query.j_license l
                    ON l.jobid = aplt.jobid
                    JOIN query.r_licenselicensetype llt
                    ON llt.licensejobid = l.jobid
                    JOIN query.r_licensetypependsecltcat ltps
                    ON ltps.licensetypejobid = llt.licensetypejobid
                   AND ltps.licensetypecategoryobjectid = ltc.objectid
              WHERE aplt.processid = a_objectid
                AND ltps.newcount >= 1);
    BEGIN
        -- Set t_FeeActivityType to 'DOR'
        t_index                  := 1;
        t_feeactivity(t_index)   := 'DOR';

        -- Get PopulationRange
        BEGIN
            SELECT a.populationrange
              INTO t_populationrange
              FROM query.r_licenseaddrpremises lap
                   JOIN query.o_address a
                   ON lap.premisesobjectid = a.objectid
             WHERE lap.licensejobid = a_jobid;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                api.pkg_errors.raiseerror(-20000,
                                             'CA City related to the Premises Address related to the License: '
                                          || a_jobid
                                          || ' could not be found.');
        END;

        -- For each Fee Activity Type loop
        FOR x IN 1 .. t_feeactivity.COUNT
        LOOP
            -- Get GLAccountId
            BEGIN
                SELECT gl.glaccountid
                  INTO t_glaccountid
                  FROM api.glaccounts gl
                 WHERE gl.glaccount = t_feeactivity(x);
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    api.pkg_errors.raiseerror(-20000,
                                                 'No GL Account exists for Fee Activity '
                                              || t_feeactivity(x));
            END;

            -- For each Secondary LT
            FOR c IN get_secondarylt_recs
            LOOP
                l_lt_count   := NULL;

                IF c.reapply = 'Y' THEN
                    BEGIN
                        SELECT licensetypecount non_pend_lt_count
                          INTO l_lt_count
                          FROM query.r_licensetypeltcatsecondary ltps
                         WHERE ltps.licensetypecategoryobjectid = c.licensetypecatobjectid
                           /*FIX THIS*/
                           AND ltps.licensetypejobid = c.licensetypejobid  --   should it be a_JobId?
                           --  and LTPS.NEWCOUNT >=1
                           AND c.status IN ('AUTO REVOKED',
                                            'WITHDRAWN',
                                            'REV PENDING',
                                            'DEPARTMENT REVOKED',
                                            'VOIDED',
                                            'RULE 64B',
                                            'SURRENDERED',
                                            'NON-RENEWED',
                                            'CANCELED',
                                            'DENIED',
                                            'SUSPENDED',
                                            'SLMS REVOKED');
                    EXCEPTION
                        WHEN OTHERS THEN
                            l_lt_count   := NULL;
                    END;
                ELSIF c.reapply = 'N' THEN
                    --  10/24/2018 PK WO 16219 Modified procedure licensefeecalc to revert back Tim's changes
                    BEGIN
                        SELECT licensetypecount pend_lt_count
                          INTO l_lt_count
                          FROM query.r_licensetypependsecltcat ltps
                         WHERE ltps.licensetypecategoryobjectid = c.licensetypecatobjectid
                           /*FIX THIS*/
                           AND ltps.licensetypejobid = c.licensetypejobid
                           AND c.status = 'PENDING';
                    EXCEPTION
                        WHEN OTHERS THEN
                            l_lt_count   := NULL;
                    END;
                END IF;

                -- what results go here???

                -- If Manual Fee is not 'Y'
                IF c.manualfee != 'Y' THEN
                    sitespecific.pkg_fees.getltfeeamount(
                        a_jobid,
                        SYSDATE,
                        t_feeactivity(x),
                        NULL,
                        c.licensetypecode,
                        NULL,  -- Gallonage Range does not apply to Secondary LTs
                        NULL,
                        CASE WHEN c.seasonalmonthsapply = 'Y' THEN c.numberofmonthslicensedfeecode ELSE NULL END,
                        CASE WHEN c.populationapplies = 'Y' THEN t_populationrange ELSE NULL END,
                        'S',
                        /*FIX THIS*/
                        l_lt_count,  --c.LicenseTypeCount,
                        NULL,
                        t_feeamount,
                        t_feescheduleid);
                    -- Set Description
                    t_description   := api.pkg_columnquery.VALUE(t_feescheduleid, 'ProcedureDescription');

                    IF t_feeamount >= 0 THEN
                        -- Then create Fees
                        sitespecific.pkg_fees.newfee(t_feeid,
                                                     t_feeamount,
                                                     --c.LicenseTypeCode || ' - Secondary, ' || --out dated 2009_3_19
                                                     t_description,
                                                     t_glaccountid,
                                                     a_jobid,
                                                     NULL,
                                                     t_feeobjectid);
                        -- Relate Fee to Fee Schedule
                        t_relid   :=
                            api.pkg_relationshipupdate.new(
                                api.pkg_configquery.endpointidforname('o_Fee', 'LicenseFeeSchedule'),
                                t_feeobjectid,
                                t_feescheduleid);
                        -- Set the relationship detail MasterLT
                        api.pkg_columnupdate.setvalue(t_relid, 'MasterLT', c.masterltcode);
                        -- Set the relationship detail IsMaster to 'N'
                        api.pkg_columnupdate.setvalue(t_relid, 'IsMaster', 'N');
                        -- Set the relationship detail SecondaryCount to the count of secondary LTs
                        api.pkg_columnupdate.setvalue(t_relid, 'SecondaryCount',  /*FIX THIS*/
                                                                                 l_lt_count);  --c.LicenseTypeCount);

                        -- Set the Quantity on the Fee Object
                        api.pkg_columnupdate.setvalue(t_feeobjectid, 'Quantity',  /*FIX THIS*/
                                                                                 l_lt_count);  --c.LicenseTypeCount);
                    -- End If
                    END IF;
                -- End If
                END IF;
            -- End Loop
            END LOOP;
        -- End Loop
        END LOOP;
    END licensefeecalc;

    /**************************************
    ** Check Existing Fees
    **************************************/
    PROCEDURE checkexistingfees(a_adjusttoamount   VARCHAR2,  -- If this is 'Y' then the Fee will be adjusted by the Fee Schedule Amount
                                -- regardless of the current fee amount/adjusted amount
                                a_description      VARCHAR2,
                                a_addrenfee        VARCHAR2,
                                a_feeactivity      VARCHAR2,
                                a_otherfeecode     VARCHAR2,
                                a_feeamount        NUMBER,
                                a_feescheduleid    udt_id,
                                a_gallonagerange   VARCHAR2,
                                a_glaccountid      udt_id,
                                a_hassecondary     VARCHAR2,
                                a_ismaster         VARCHAR2,
                                a_jobid            udt_id,
                                a_licensetypecode  VARCHAR2,
                                a_licensetypecount NUMBER,
                                a_numberofmonthslicensed VARCHAR2,
                                a_populationrange  VARCHAR2,
                                a_tier             VARCHAR2,  --  03/29/2019 TJL WO 17566
                                a_secondaryids     VARCHAR2,
                                a_createfee    OUT VARCHAR2,
                                a_feeid        OUT NUMBER)
    IS
        t_amount             NUMBER := 0;
        t_balance            NUMBER;
        t_master             VARCHAR2(1);
        t_masterlt           VARCHAR2(2);
        t_transactionojbid   udt_id;
        t_relid              udt_id;
        t_feeobjectdefid     udt_id := api.pkg_configquery.objectdefidforname('o_Fee');
    BEGIN
        -- Make a_AdjustToAmount mandatory
        IF a_adjusttoamount NOT IN ('Y', 'N') THEN
            api.pkg_errors.raiseerror(
                -20000,
                'a_AdjustToAmount in procedure CheckExistingFees must have a value of either ''Y'' or ''N''.');
        END IF;

        -- Make a_IsMaster mandatory
        IF a_ismaster NOT IN ('Y', 'N') THEN
            api.pkg_errors.raiseerror(
                -20000,
                'a_IsMaster in procedure CheckExistingFees must have a value of either ''Y'' or ''N''.');
        END IF;

        -- For each Fee Schedule that is already related through a fee to the Application
        FOR c IN (SELECT f.feeid                                                    feeid,
                         reo.objectid                                               feeobjectid,
                         api.pkg_columnquery.numericvalue(reo.objectid, 'Quantity') quantity,
                         ffs.ismaster,
                         ffs.relationshipid,
                         ffs.secondarycount,
                         fs.feeactivity,
                         fs.gallonagerange,
                         fs.licensetypecode,
                         fs.numberofmonthslicensedfeecode,
                         fs.objectid,
                         fs.populationrange,
                         fs.feetier,  --  03/29/2019 TJL WO 17566
                         fs.otherfeecode,
                         fs.feecode
                    FROM api.jobs j
                         JOIN api.fees f
                         ON f.jobid = j.jobid
                         JOIN api.registeredexternalobjects reo  -- RyanL: PIP Task 8.5
                         ON reo.linkvalue = TO_CHAR(f.feeid)
                        AND reo.objectdefid = t_feeobjectdefid
                         JOIN query.r_feelicensefeeschedule ffs
                         ON ffs.feeobjectid = reo.objectid
                         JOIN query.o_feeschedule fs
                         ON fs.objectid = ffs.licensefeescheduleid
                   WHERE j.jobid = a_jobid)
        LOOP
              -- SG: FIX FOR ISSUE0042771 - Application fee amount being adjusted
              -- Fixed this SQL so it would not double count the same fee multiple times when multiple payments have been made for the fee
              -- Get the Fee Amount and current balance
              SELECT (  NVL(SUM(f.amount + f.taxamount), 0)
                      + NVL(
                            (SELECT SUM(ft.amount + ft.taxamount)
                               FROM api.feetransactions ft
                              WHERE ft.feeid = f.feeid
                                AND ft.transactiontype = 'Adj'
                                AND api.pkg_columnquery.VALUE(
                                        api.pkg_simplesearch.objectbyindex('o_PaymentTransactions',
                                                                           'TransactionId',
                                                                           ft.transactionid),
                                        'VoidedByTransactionId')
                                        IS NULL
                                AND api.pkg_columnquery.VALUE(
                                        api.pkg_simplesearch.objectbyindex('o_PaymentTransactions',
                                                                           'TransactionId',
                                                                           ft.transactionid),
                                        'IsRefunded') =
                                    'N'
                                AND api.pkg_columnquery.VALUE(
                                        api.pkg_simplesearch.objectbyindex('o_PaymentTransactions',
                                                                           'TransactionId',
                                                                           ft.transactionid),
                                        'IsDishonored') =
                                    'N'
                                AND api.pkg_columnquery.VALUE(
                                        api.pkg_simplesearch.objectbyindex('o_PaymentTransactions',
                                                                           'TransactionId',
                                                                           ft.transactionid),
                                        'CABINAmtType') <>
                                    'C'),
                            0))
                         AS amount,
                     (  SELECT (  NVL(SUM(f2.amount + f2.taxamount), 0)
                                + NVL((SELECT SUM(ft.amount + ft.taxamount)
                                         FROM api.feetransactions ft
                                        WHERE ft.feeid = f.feeid),
                                      0))
                          FROM api.fees f2
                         WHERE f2.feeid = f.feeid
                      GROUP BY f2.feeid)
                         AS balance
                INTO t_amount, t_balance
                FROM api.fees f
               WHERE f.feeid = c.feeid
            GROUP BY f.feeid;

            -- If t_PFeeAmount = the Fee Schedule Id
            IF (c.feeactivity = a_feeactivity)
           --or (c.FeeActivity = 'REN' and a_AddRenFee = 'N'))
           AND (c.ismaster = a_ismaster)
           AND (NVL(c.licensetypecode, ' ') = NVL(a_licensetypecode, ' '))  --  04/01/2019 TJL WO 17620
           AND ((c.gallonagerange = a_gallonagerange)
             OR (c.gallonagerange IS NULL
             AND a_gallonagerange IS NULL))
           AND ((c.numberofmonthslicensedfeecode = a_numberofmonthslicensed)
             OR (c.numberofmonthslicensedfeecode IS NULL
             AND a_numberofmonthslicensed IS NULL))
           AND ((c.populationrange = a_populationrange)
             OR (c.populationrange IS NULL
             AND a_populationrange IS NULL))
           AND ((c.feetier = a_tier)  --  03/29/2019 TJL WO 17566
             OR (c.feetier IS NULL
             AND a_tier IS NULL)) THEN
                -- Set a_CreateFee to 'N'
                a_createfee   := 'N';

                -- If the License Type does not have Secondary LTs and IsMaster = 'Y' and SecondaryCount is not greater than 0
                IF a_hassecondary = 'N'
               AND c.ismaster = 'Y'
               AND c.secondarycount > 0
               AND a_secondaryids IS NOT NULL THEN
                    NULL;
                ELSIF a_hassecondary = 'N'
                  AND c.ismaster = 'Y'
                  AND c.secondarycount > 0
                  AND a_secondaryids IS NULL THEN
                    -- SG: FIX FOR ISSUE0042771 - Application fee amount being adjusted
                    -- Only adjust fees that have not been fully paid
                    IF t_balance > 0 THEN
                        -- If the Fee Amount is not equal to the Fee Schedule Amount or if a_Adjust to Amount = 'Y'
                        IF (a_feeamount != t_amount)
                        OR (a_adjusttoamount = 'Y') THEN
                            -- then Adjust the fee
                            a_feeid      :=
                                api.pkg_feeupdate.adjust(c.feeid,
                                                         CASE
                                                             WHEN a_feeamount != t_amount
                                                              AND a_adjusttoamount != 'Y' THEN
                                                                 ROUND(a_feeamount - t_amount)
                                                             WHEN a_adjusttoamount = 'Y' THEN
                                                                 ROUND(a_feeamount)
                                                         END,
                                                         a_description,
                                                         SYSDATE);

                            -- Register the Fee Transaction External Object
                            t_transactionojbid   :=
                                api.pkg_objectupdate.registerexternalobject('o_FeeTransactions', a_feeid);

                            -- Then update the Quantity column to ''
                            api.pkg_columnupdate.setvalue(c.feeobjectid, 'Quantity', '');

                            -- Set MasterLT and IsMaster to variables
                            t_masterlt   := api.pkg_columnquery.VALUE(c.relationshipid, 'MasterLT');
                            t_master     := api.pkg_columnquery.VALUE(c.relationshipid, 'IsMaster');

                            -- Drop the old relationship to from the Fee to the Fee Schedule
                            api.pkg_relationshipupdate.remove(c.relationshipid);

                            -- Create a new relationship from the Fee to the Fee Schedule
                            t_relid      :=
                                api.pkg_relationshipupdate.new(
                                    api.pkg_configquery.endpointidforname('o_Fee', 'LicenseFeeSchedule'),
                                    c.feeobjectid,
                                    a_feescheduleid);

                            -- then set the MasterLT rel detail to the MasterLT code
                            api.pkg_columnupdate.setvalue(t_relid, 'MasterLT', t_masterlt);

                            -- Update the Secondary Count rel column to match a_LicenseTypeCount
                            api.pkg_columnupdate.setvalue(t_relid, 'SecondaryCount', a_licensetypecount);

                            -- Set the IsMaster flag to what the old rel was
                            api.pkg_columnupdate.setvalue(t_relid, 'IsMaster', t_master);
                        -- End If
                        END IF;
                    END IF;
                -- Else if a_FeeAmount does not equal the Fee Amount
                ELSIF ((a_feeamount != t_amount)
                    OR (a_adjusttoamount = 'Y'))
                   OR ((c.feecode != a_otherfeecode)
                   AND (a_otherfeecode IS NOT NULL)) THEN
                    -- SG: FIX FOR ISSUE0042771 - Application fee amount being adjusted
                    -- Only adjust fees that have not been fully paid
                    IF t_balance > 0 THEN
                        -- then adjust the existing fee
                        a_feeid      :=
                            api.pkg_feeupdate.adjust(c.feeid,
                                                     CASE
                                                         WHEN a_feeamount != t_amount
                                                          AND a_adjusttoamount != 'Y' THEN
                                                             ROUND(a_feeamount - t_amount)
                                                         WHEN a_adjusttoamount = 'Y' THEN
                                                             ROUND(a_feeamount)
                                                         ELSE
                                                             0
                                                     END,
                                                     a_description,
                                                     SYSDATE);

                        -- Register the Fee Transaction External Object
                        t_transactionojbid   :=
                            api.pkg_objectupdate.registerexternalobject('o_FeeTransactions', a_feeid);

                        -- Set MasterLT and IsMaster to variables
                        t_masterlt   := api.pkg_columnquery.VALUE(c.relationshipid, 'MasterLT');
                        t_master     := api.pkg_columnquery.VALUE(c.relationshipid, 'IsMaster');

                        -- Drop the old relationship to from the Fee to the Fee Schedule
                        api.pkg_relationshipupdate.remove(c.relationshipid);

                        -- Create a new relationship from the Fee to the Fee Schedule
                        t_relid      :=
                            api.pkg_relationshipupdate.new(
                                api.pkg_configquery.endpointidforname('o_Fee', 'LicenseFeeSchedule'),
                                c.feeobjectid,
                                a_feescheduleid);

                        -- Update the Secondary Count rel column to match the License Type Count
                        api.pkg_columnupdate.setvalue(t_relid, 'SecondaryCount', a_licensetypecount);

                        -- then set the MasterLT rel detail to the MasterLT code
                        api.pkg_columnupdate.setvalue(t_relid, 'MasterLT', t_masterlt);

                        -- If the License Type Count is not equal to the Fee Quantity Column
                        IF a_licensetypecount > 0 THEN
                            -- Then update the Quantity column to match the License Type Count
                            api.pkg_columnupdate.setvalue(c.feeobjectid, 'Quantity', a_licensetypecount);
                        -- Else
                        ELSE
                            -- Set the Quantity to ''
                            api.pkg_columnupdate.setvalue(c.feeobjectid, 'Quantity', '');
                        -- End If
                        END IF;

                        -- Then Set the IsMaster flag to the prior Rels IsMaster
                        api.pkg_columnupdate.setvalue(t_relid, 'IsMaster', t_master);
                    END IF;
                END IF;
            END IF;
        END LOOP;

        -- If a_CreateFee is null
        IF a_createfee IS NULL THEN
            -- then set it to 'Y'
            a_createfee   := 'Y';
        -- End If
        END IF;
    END checkexistingfees;

    /**************************************
    ** Check the LTs on the Job and charge fees for it
    **************************************/
    -- --  03/29/2019 TJL WO 17566  Overloaded procedure to provide backwards compatability
    PROCEDURE getltfeeamount(a_jobid            udt_id,
                             a_effectivedate    DATE,
                             a_feeactivitytype  VARCHAR2,
                             a_otherfeecode     VARCHAR2,
                             a_ltcode           VARCHAR2,
                             a_gallonagerange   VARCHAR2,
                             a_additionalmilliongallons NUMBER,
                             a_numberofmonthslicensed VARCHAR2,
                             a_populationrange  VARCHAR2,
                             a_feetype          VARCHAR2,
                             a_ltcount          NUMBER,
                             a_asofdate         DATE,
                             a_feeamount    OUT NUMBER,
                             a_licensefeescheduleid OUT udt_id)
    IS
    BEGIN
        getltfeeamount(a_jobid,
                       a_effectivedate,
                       a_feeactivitytype,
                       a_otherfeecode,
                       a_ltcode,
                       a_gallonagerange,
                       a_additionalmilliongallons,
                       a_numberofmonthslicensed,
                       a_populationrange,
                       NULL,
                       a_feetype,
                       a_ltcount,
                       a_asofdate,
                       a_feeamount,
                       a_licensefeescheduleid);
    END getltfeeamount;

    PROCEDURE getltfeeamount(a_jobid            udt_id,
                             a_effectivedate    DATE,
                             a_feeactivitytype  VARCHAR2,
                             a_otherfeecode     VARCHAR2,
                             a_ltcode           VARCHAR2,
                             a_gallonagerange   VARCHAR2,
                             a_additionalmilliongallons NUMBER,
                             a_numberofmonthslicensed VARCHAR2,
                             a_populationrange  VARCHAR2,
                             a_tier             VARCHAR2,  --  03/29/2019 TJL WO 17566
                             a_feetype          VARCHAR2,
                             a_ltcount          NUMBER,
                             a_asofdate         DATE,
                             a_feeamount    OUT NUMBER,
                             a_licensefeescheduleid OUT udt_id)
    IS
        t_gallonagerange           VARCHAR2(100);
        t_numberofmonthslicensed   VARCHAR2(100);
        t_populationrange          VARCHAR2(100);
        t_surchargeobjectid        udt_id;
    BEGIN
        -- Raise error if a_FeeType is null
        IF a_feetype NOT IN ('S', 'P', 'B') THEN
            api.pkg_errors.raiseerror(-20000,
                                         'a_FeeType must have a value of either '
                                      || '''B'''
                                      || ', '
                                      || '''S'''
                                      || ', or '
                                      || '''P''. Current a_FeeType value: '
                                      || a_feetype);
        -- End If
        END IF;

        -- decodes to get the correct values into the Gallonage Range, Population Range, and Number of Months Licensed vars
        -- PopulationRange
        CASE
            WHEN a_populationrange = 'P0' THEN
                t_populationrange   := 'P0 - LESS THAN 20,000';
            WHEN a_populationrange = 'P20' THEN
                t_populationrange   := 'P20 - FROM 20,000 TO 40,000';
            WHEN a_populationrange = 'P40' THEN
                t_populationrange   := 'P40 - OVER 40,000';
            ELSE
                t_populationrange   := a_populationrange;
        END CASE;

        -- GallonageRange
        CASE
            WHEN a_gallonagerange = 'GL5K' THEN
                t_gallonagerange   := '0 TO 5K';
            WHEN a_gallonagerange = 'GL20K' THEN
                t_gallonagerange   := '5K TO 20K';
            WHEN a_gallonagerange = 'GL100K' THEN
                t_gallonagerange   := '20K TO 100K';
            WHEN a_gallonagerange = 'GL200K' THEN
                t_gallonagerange   := '100 TO 200K';
            WHEN a_gallonagerange = 'GL1M' THEN
                t_gallonagerange   := '200K TO 1M';
            ELSE
                t_gallonagerange   := a_gallonagerange;
        END CASE;

        -- Number Of Months Licensed
        CASE
            -- 12/10/2018 TJL 16791
            -- License type 59 and 60 do not have fees for 0-3mos use 3-6mos fees schedule
            WHEN a_numberofmonthslicensed = '0-3MOS'
             AND a_ltcode NOT IN ('59', '60') THEN
                t_numberofmonthslicensed   := '3 MONTHS';
            WHEN a_numberofmonthslicensed = '0-3MOS'
             AND a_ltcode IN ('59', '60') THEN
                t_numberofmonthslicensed   := '6 MONTHS';
            WHEN a_numberofmonthslicensed = '3-6MOS' THEN
                t_numberofmonthslicensed   := '6 MONTHS';
            WHEN a_numberofmonthslicensed = '6-9MOS' THEN
                t_numberofmonthslicensed   := '9 MONTHS';
            ELSE
                t_numberofmonthslicensed   := a_numberofmonthslicensed;
        END CASE;

        -- Find Fee Schedule with passed in vars
        BEGIN
            SELECT lfs.objectid, s.objectid
              INTO a_licensefeescheduleid, t_surchargeobjectid
              FROM sitespecific.feeschedule_t lfs
                   LEFT OUTER JOIN sitespecific.feesurchargeschedule_t s
                   ON (NVL(lfs.surchargecode, 'x') = s.surchargecode)
                  AND lfs.inactive = 'N'
                  AND (s.effectivedate = (SELECT MAX(s2.effectivedate)
                                            FROM sitespecific.feesurchargeschedule_t s2
                                           WHERE s2.effectivedate <= a_effectivedate
                                             AND lfs.surchargecode = s2.surchargecode))
             WHERE lfs.feeactivity = a_feeactivitytype
               AND (lfs.licensetypecode = a_ltcode
                 OR lfs.licensetypecode IS NULL
                AND a_ltcode IS NULL)
               -- Remove or from EffectiveDate criteria when procedure calls are fixed.
               AND (lfs.effectivedate =
                    (SELECT MAX(fs.effectivedate) effectivedate
                       FROM sitespecific.feeschedule_t fs
                      WHERE fs.feeactivity = a_feeactivitytype
                        AND (fs.licensetypecode = a_ltcode
                          OR (fs.licensetypecode IS NULL
                          AND a_ltcode IS NULL))
                        AND effectivedate <= a_effectivedate
                        AND (fs.gallonagerange = t_gallonagerange
                          OR (fs.gallonagerange IS NULL
                          AND t_gallonagerange IS NULL))
                        AND (api.pkg_columnquery.VALUE(fs.objectid, 'NumberOfMonthsLicensed') =
                             t_numberofmonthslicensed
                          OR (api.pkg_columnquery.VALUE(fs.objectid, 'NumberOfMonthsLicensed') IS NULL
                          AND t_numberofmonthslicensed IS NULL))
                        --  03/29/2019 TJL WO 17566
                        AND (NVL(fs.feetier, ' ') = NVL(a_tier, ' '))
                        AND (fs.populationrange = t_populationrange
                          OR (fs.populationrange IS NULL
                          AND t_populationrange IS NULL))
                        AND (fs.otherfeecode = a_otherfeecode
                          OR (fs.otherfeecode IS NULL
                          AND a_otherfeecode IS NULL)))
                 OR lfs.effectivedate IS NULL)  --NOTE: The lfs.EffectiveDate will never be null. Not sure you need to worry that a_effectivedate may be null..?
               AND (lfs.gallonagerange = t_gallonagerange
                 OR (lfs.gallonagerange IS NULL
                 AND t_gallonagerange IS NULL))
               AND (api.pkg_columnquery.VALUE(lfs.objectid, 'NumberOfMonthsLicensed') = t_numberofmonthslicensed
                 OR (api.pkg_columnquery.VALUE(lfs.objectid, 'NumberOfMonthsLicensed') IS NULL
                 AND t_numberofmonthslicensed IS NULL))
               AND (lfs.populationrange = t_populationrange
                 OR (lfs.populationrange IS NULL
                 AND t_populationrange IS NULL))
               AND (NVL(lfs.feetier, ' ') = NVL(a_tier, ' '))
               AND (lfs.otherfeecode = a_otherfeecode
                 OR (lfs.otherfeecode IS NULL
                 AND a_otherfeecode IS NULL))
               AND lfs.inactive = 'N';
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                NULL;
            WHEN TOO_MANY_ROWS THEN
                api.pkg_errors.raiseerror(-20000,
                                             'Multiple Fee Scheduled Objects with criteria FeeActivity = '
                                          || a_feeactivitytype
                                          || ', LicenseTypeCode = '
                                          || a_ltcode
                                          || ', GallonageRange = '
                                          || t_gallonagerange
                                          || ', NumberOfMonthsLicensed = '
                                          || t_numberofmonthslicensed
                                          || ', PopulationRange = '
                                          || t_populationrange);
        END;

        IF (a_licensefeescheduleid IS NOT NULL) THEN
            --Get fee amount based on License Type
            -- If a_FeeType = 'B'
            IF a_feetype = 'B' THEN
                -- a_FeeAmount := Branch Amount
                a_feeamount   := NVL(api.pkg_columnquery.numericvalue(a_licensefeescheduleid, 'BranchAmount'), 0);
            -- Else If a_FeeType = 'S'
            ELSIF a_feetype = 'S' THEN
                -- a_FeeAmount := Secondary Fee Amount
                a_feeamount   :=
                    NVL(api.pkg_columnquery.numericvalue(a_licensefeescheduleid, 'SecondaryAmount'), 0) * a_ltcount;
            -- Else If a_FeeType = 'P'
            ELSIF a_feetype = 'P' THEN
                -- a_FeeAmount := Fee Amount
                a_feeamount   := NVL(api.pkg_columnquery.numericvalue(a_licensefeescheduleid, 'PrimaryAmount'), 0);

                IF a_additionalmilliongallons > 0 THEN
                    a_feeamount   :=
                          a_feeamount
                        -- 12/06/2018 TJL WO 16775 Added NVL Check
                        +   NVL(api.pkg_columnquery.numericvalue(a_licensefeescheduleid, 'SecondaryAmount'), 0)
                          * a_additionalmilliongallons;
                END IF;

                -- conditions for using primary count for LT 06
                -- 12/11/2018 TJL WO 16777 Added ORI fee activity to be adjusted by ltcount
                IF a_ltcode = '06'
               AND a_feeactivitytype IN ('ANN',
                                         'APP',  -- 04/01/2019 TJL WO 17620 ORI to APP
                                         'PER',
                                         'FID',
                                         'DPR',
                                         'STK',
                                         'STM',
                                         'PRM',
                                         'MBR',
                                         'MBM',
                                         'REN',
                                         'REN50',
                                         'REN100') THEN
                    -- If there exists a Primary Count
                    IF a_ltcount IS NOT NULL
                   AND a_ltcount != 0 THEN
                        a_feeamount   :=
                              NVL(api.pkg_columnquery.numericvalue(a_licensefeescheduleid, 'SecondaryAmount'), 0)
                            * (a_ltcount + 1);
                    END IF;
                END IF;

                -- special situation for using room count for LTs 80 and 67
                --
                -- 2/14/2018 NW - WO 14464
                -- IF a_ltcode IN ('80', '67') THEN
                IF a_ltcode IN ('80', '67')
               AND a_feeactivitytype IN ('DOR',
                                         'REN',
                                         'REN50',
                                         'REN100') THEN
                    a_feeamount   :=
                          NVL(api.pkg_columnquery.numericvalue(a_licensefeescheduleid, 'SecondaryAmount'), 0)
                        * a_ltcount;

                    -- Add surcharge to fee
                    IF (t_surchargeobjectid IS NOT NULL) THEN
                        -- round to 5 dollar  round(num/5)*5
                        a_feeamount   :=
                              a_feeamount
                            + (  (  ROUND(
                                          (  NVL(
                                                 api.pkg_columnquery.numericvalue(t_surchargeobjectid,
                                                                                  'ab_surcharge_pct'),
                                                 0)
                                           / 100)
                                        * (  NVL(
                                                 api.pkg_columnquery.numericvalue(a_licensefeescheduleid,
                                                                                  'originalsecondaryfee'),
                                                 0)
                                           * a_ltcount)
                                        / 5)
                                  * 5)
                               + NVL(api.pkg_columnquery.numericvalue(t_surchargeobjectid, 'bpu_fee'), 0)
                               + NVL(api.pkg_columnquery.numericvalue(t_surchargeobjectid, 'dmv_surcharge_amt'), 0));
                    END IF;
                END IF;

                IF a_feeamount IS NULL
                OR a_feeamount = 0 THEN
                    a_feeamount   :=
                        NVL(api.pkg_columnquery.numericvalue(a_licensefeescheduleid, 'SecondaryAmount'), 0);

                    IF a_ltcount IS NOT NULL
                   AND a_ltcount != 0 THEN
                        a_feeamount   := a_feeamount * a_ltcount;
                    END IF;
                END IF;
            END IF;
        END IF;

        --Set Returned value to 0 when null
        IF a_feeamount IS NULL
        OR a_licensefeescheduleid IS NULL THEN
            a_feeamount   := -1;
        END IF;
    END getltfeeamount;

    FUNCTION getltfeeamount(a_effectivedate DATE,
                            a_feeactivitytype VARCHAR2,
                            a_ltcode        VARCHAR2,
                            a_gallonagerange VARCHAR2,
                            a_additionalmilliongallons NUMBER,
                            a_numberofmonthslicensed VARCHAR2,
                            a_populationrange VARCHAR2,
                            a_feetype       VARCHAR2,
                            a_ltcount       NUMBER)
        RETURN NUMBER
    IS
        t_feeamount              NUMBER;
        t_licensefeescheduleid   udt_id;
    BEGIN
        sitespecific.pkg_fees.getltfeeamount(NULL,
                                             a_effectivedate,
                                             a_feeactivitytype,
                                             NULL,
                                             a_ltcode,
                                             a_gallonagerange,
                                             a_additionalmilliongallons,
                                             a_numberofmonthslicensed,
                                             a_populationrange,
                                             a_feetype,
                                             a_ltcount,
                                             NULL,
                                             t_feeamount,
                                             t_licensefeescheduleid);
        RETURN t_feeamount;
    END getltfeeamount;

    /********************************************
    * Create One Day License Fees
    ********************************************/
    PROCEDURE onedaylicensefeecalc(a_objectid udt_id, a_asofdate DATE, a_jobid udt_id)
    IS
        t_days            NUMBER;
        t_description     VARCHAR2(250);
        t_effectivedate   DATE;
        t_feeactivity     VARCHAR2(40);
        t_feeamount       NUMBER;
        t_feeid           udt_id;
        t_feeobjectid     udt_id;
        t_feescheduleid   udt_id;
        t_glaccountid     udt_id;
        t_lttype          VARCHAR2(1);
        t_relid           udt_id;
    BEGIN
        -- Set t_EffectiveDate to the first date of the event
        t_effectivedate   := api.pkg_columnquery.datevalue(a_jobid, 'DateOfEventFrom');

        -- t_FeeActivityType := 'ODL'
        t_feeactivity     := 'ODL';

        -- Get the GL Account Id
        BEGIN
            SELECT gl.glaccountid
              INTO t_glaccountid
              FROM api.glaccounts gl
             WHERE gl.glaccount = t_feeactivity;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                api.pkg_errors.raiseerror(-20000,
                                             'No GL Account exists for Fee Activity '
                                          || t_feeactivity);
        END;

        -- Set t_LTType to 'S'
        t_lttype          := 'S';

        -- Get the number of days the license is for
        t_days            := api.pkg_columnquery.numericvalue(a_jobid, 'Days');

        -- For each LT
        -- Get LT Code
        -- Get LT Count LOOP:
        FOR c IN (SELECT lt.licensetypecode
                    FROM query.j_onedaylicense odl
                         JOIN query.r_onedaylicenseltcategory oltc
                         ON oltc.onedaylicensejobid = odl.jobid
                         JOIN query.o_licensetypecategory lt
                         ON lt.objectid = oltc.licensetypecategoryobjectid
                   WHERE odl.jobid = a_jobid)
        LOOP
            -- t_PrimaryBranchMaster := 'P'
            -- GetLTFeeAmount
            sitespecific.pkg_fees.getltfeeamount(a_jobid,
                                                 t_effectivedate,
                                                 t_feeactivity,
                                                 NULL,
                                                 c.licensetypecode,
                                                 NULL,
                                                 NULL,
                                                 NULL,
                                                 NULL,
                                                 t_lttype,
                                                 t_days,
                                                 NULL,
                                                 t_feeamount,
                                                 t_feescheduleid);

            -- If the fee amount is not null
            IF t_feeamount >= 0 THEN
                -- Then get the Description for the fee
                t_description   := api.pkg_columnquery.VALUE(t_feescheduleid, 'ProcedureDescription');

                -- Create Fees
                sitespecific.pkg_fees.newfee(t_feeid,
                                             t_feeamount,
                                             --c.LicenseTypeCode||', '|| -- out dated 2009_3_19
                                             t_description,
                                             t_glaccountid,
                                             a_jobid,
                                             NULL,
                                             t_feeobjectid);
                -- Relate Fee to Fee Schedule
                t_relid         :=
                    api.pkg_relationshipupdate.new(
                        api.pkg_configquery.endpointidforname('o_Fee', 'LicenseFeeSchedule'),
                        t_feeobjectid,
                        t_feescheduleid);
                -- Set the relationship detail IsMaster to 'Y'
                api.pkg_columnupdate.setvalue(t_relid, 'IsMaster', 'Y');
                -- Set the relationship detail SecondaryCount to the count of secondary LTs
                api.pkg_columnupdate.setvalue(t_relid, 'SecondaryCount', t_days);

                -- Set the Quantity on the Fee Object
                api.pkg_columnupdate.setvalue(t_feeobjectid, 'Quantity', t_days);
            --End If
            END IF;
        -- End Loop
        END LOOP;
    END onedaylicensefeecalc;

    /********************************************
    * Create Priority Application Fees
    ********************************************/
    PROCEDURE priorityappfeecalc(a_objectid udt_id, a_asofdate DATE, a_jobid udt_id)
    IS
    BEGIN
        sitespecific.createappfee(a_objectid, a_asofdate, a_jobid);
    END priorityappfeecalc;

    ----------------------------------------------------------------------------------------------------
    -- CreateIssueInterimPermitFee() -- PUBLIC
    -- Charges fee for Issue Interim Retail Permit process
    -- 07/17/2019  PK  WO 18109 below procedure is deprecated
    ----------------------------------------------------------------------------------------------------
    PROCEDURE createinterimpermitfee(a_objectid NUMBER, a_asofdate DATE, a_jobid NUMBER)
    IS
        t_createfee              VARCHAR2(1);
        t_createsfee             VARCHAR2(1);
        t_description            VARCHAR2(100);
        t_proceduredescription   VARCHAR2(100);
        t_feeid                  NUMBER;
        t_feeobjid               NUMBER;
        t_sfeeid                 NUMBER;
        t_sfeeobjid              NUMBER;
        t_feeschedid             NUMBER;
        t_sfeeschedid            NUMBER;
        t_glaccountid            NUMBER;
        t_relid                  NUMBER;
        t_pamount                NUMBER;
        t_sfeeamount             NUMBER;
        t_primissec              VARCHAR2(1);
        t_ismaster               VARCHAR2(1);
    BEGIN
        --Get GLAccountId
        SELECT g.glaccountid
          INTO t_glaccountid
          FROM api.glaccounts g
         WHERE g.glaccount = 'IPT';

        --Primary LT Loop
        FOR x IN (SELECT plt.objectid                                                      pltobjectid,
                         ltc.licensetypecode,
                         CASE WHEN plt.masterlicensetype IS NOT NULL THEN 'B' ELSE 'P' END primorbranch,
                         plt.secondaryltobjectids
                    FROM query.r_appprimarylicensetype aplt
                         JOIN query.o_primarylicensetype plt
                         ON aplt.licensetypeobjectid = plt.objectid
                         JOIN query.r_priltltcatprimary pltltc
                         ON plt.objectid = pltltc.primarylicensetypeobjectid
                         JOIN query.o_licensetypecategory ltc
                         ON pltltc.licensetypecategoryobjectid = ltc.objectid
                   WHERE aplt.applicationobjectid = a_jobid)
        LOOP
            -- Set t_CreateFee to 'Y'
            t_createfee   := 'Y';

            --Get Fee Amount and Fee ScheduleId
            sitespecific.pkg_fees.getltfeeamount(a_jobid,
                                                 SYSDATE,
                                                 'IPT',
                                                 NULL,
                                                 x.licensetypecode,
                                                 NULL,
                                                 NULL,
                                                 NULL,
                                                 NULL,
                                                 x.primorbranch,
                                                 NULL,
                                                 a_asofdate,
                                                 t_pamount,
                                                 t_feeschedid);

            --Secondary LT loop
            FOR z IN (SELECT sltc.licensetypecount, ltc.licensetypecode
                        FROM query.r_priltltcatsecondary sltc
                             JOIN query.o_licensetypecategory ltc
                             ON sltc.licensetypecategoryobjectid = ltc.objectid
                       WHERE sltc.primarylicensetypeobjectid = x.pltobjectid)
            LOOP
                -- Set t_CreateSFee to 'Y'
                t_createsfee   := 'Y';

                --Get Fee Amount and Fee ScheduleId
                sitespecific.pkg_fees.getltfeeamount(a_jobid,
                                                     SYSDATE,
                                                     'IPT',
                                                     NULL,
                                                     z.licensetypecode,
                                                     NULL,
                                                     NULL,
                                                     NULL,
                                                     NULL,
                                                     'S',
                                                     z.licensetypecount,
                                                     a_asofdate,
                                                     t_sfeeamount,
                                                     t_sfeeschedid);

                IF t_sfeeamount >= 0 THEN
                    --Set Description
                    --If Secondary ltc is Primary ltc
                    IF z.licensetypecode = x.licensetypecode  --Set Description, Amount, IsMaster, and PrimIsSec for secondary that is also primary
                                                             --Some of this below is out dated 2009_3_19 the is master detail setting is just fine though
                                                             THEN
                        t_primissec     := 'Y';
                        t_sfeeamount    := t_sfeeamount + t_pamount;
                        t_ismaster      := 'Y';
                        t_sfeeschedid   := t_feeschedid;  --so that relationship is to the primaryLTfeeschedule record.
                    --else Set IsMaster for normal secondary
                    ELSE
                        t_ismaster   := 'N';
                    END IF;

                    --Set Description
                    t_proceduredescription   := api.pkg_columnquery.VALUE(t_sfeeschedid, 'ProcedureDescription');

                    -- Check existing Fees
                    sitespecific.pkg_fees.checkexistingfees('Y',
                                                            t_proceduredescription,
                                                            'N',
                                                            'IPT',
                                                            NULL,
                                                            t_sfeeamount,
                                                            t_sfeeschedid,
                                                            NULL,
                                                            t_glaccountid,
                                                            'Y',
                                                            t_ismaster,
                                                            a_jobid,
                                                            z.licensetypecode,
                                                            z.licensetypecount,
                                                            NULL,
                                                            NULL,
                                                            NULL,  --  03/29/2019 TJL WO 17566
                                                            x.secondaryltobjectids,
                                                            t_createsfee,
                                                            t_feeid);

                    -- If t_CreateSFee = 'Y'
                    IF t_createsfee = 'Y' THEN
                        -- Then Create Fee
                        sitespecific.pkg_fees.newfee(t_sfeeid,
                                                     t_sfeeamount,
                                                     t_proceduredescription,
                                                     t_glaccountid,
                                                     a_jobid,
                                                     NULL,
                                                     t_sfeeobjid);

                        --Relate Fee to Fee Schedule
                        t_relid   :=
                            api.pkg_relationshipupdate.new(
                                api.pkg_configquery.endpointidforname('o_Fee', 'LicenseFeeSchedule'),
                                t_sfeeobjid,
                                t_sfeeschedid);

                        -- Set the relationship detail IsMaster
                        api.pkg_columnupdate.setvalue(t_relid, 'IsMaster', t_ismaster);
                        -- Set the relationship detail SecondaryCount to the count of secondary LTs
                        api.pkg_columnupdate.setvalue(t_relid, 'SecondaryCount', z.licensetypecount);
                        -- Set the relationship detail MasterLT to the Primary LT Code
                        api.pkg_columnupdate.setvalue(t_relid, 'MasterLT', x.licensetypecode);
                        -- Set the Quantity on the Fee Object
                        api.pkg_columnupdate.setvalue(t_sfeeobjid, 'Quantity', z.licensetypecount);
                    -- End If
                    END IF;
                END IF;
            END LOOP;  --secondary loop

            --Continue Primary loop
            --if Primary is Retail, but not retail permit and its fee was not already charged in the secondary loop (when secondary and primary are the same)
            IF t_pamount >= 0
           AND (t_primissec IS NULL
             OR t_primissec <> 'Y') THEN
                --Set Procedure Description
                t_proceduredescription   := api.pkg_columnquery.VALUE(t_feeschedid, 'ProcedureDescription');

                --Set Description
                t_description            :=  --x.licensetypecode || ' - Primary, '|| --out dated 2009_3_19
                                            t_proceduredescription;

                -- Check existing Fees
                sitespecific.pkg_fees.checkexistingfees('Y',
                                                        t_description,
                                                        'N',
                                                        'IPT',
                                                        NULL,
                                                        t_pamount,
                                                        t_feeschedid,
                                                        NULL,
                                                        t_glaccountid,
                                                        'N',
                                                        'Y',
                                                        a_jobid,
                                                        x.licensetypecode,
                                                        0,
                                                        NULL,
                                                        NULL,
                                                        NULL,  --  03/29/2019 TJL WO 17566
                                                        x.secondaryltobjectids,
                                                        t_createfee,
                                                        t_feeid);

                -- If t_CreateFee = 'Y'
                IF t_createfee = 'Y' THEN
                    -- Then Create Fee
                    sitespecific.pkg_fees.newfee(t_feeid,
                                                 t_pamount,
                                                 t_description,
                                                 t_glaccountid,
                                                 a_jobid,
                                                 NULL,
                                                 t_feeobjid);

                    --Relate Fee to Fee Schedule
                    t_relid   :=
                        api.pkg_relationshipupdate.new(
                            api.pkg_configquery.endpointidforname('o_Fee', 'LicenseFeeSchedule'),
                            t_feeobjid,
                            t_feeschedid);

                    -- Set the relationship detail IsMaster to 'N'
                    api.pkg_columnupdate.setvalue(t_relid, 'IsMaster', 'Y');
                -- End If
                END IF;
            END IF;

            --Set Primary Equals secondary to N for next primary loop.
            t_primissec   := 'N';
        END LOOP;  --primary loop
    END createinterimpermitfee;

    ------------------------------------------------
    --CreatePaymentStatus() -- PUBLIC
    --run from the Issue License Process on botht the App. and the Lic.
    ------------------------------------------------
    PROCEDURE createpaymentstatus(a_jobid udt_id, a_asofdate DATE)
    IS
        t_jobid                      udt_id;
        t_paymentstatusdefid         udt_id;
        t_newpaymentstatusobjectid   udt_id;
        t_paytranspaystatendpoint    udt_id;
        t_paytranspaystatrelid       udt_id;
        t_paymentstatusstatus        VARCHAR2(100);
        t_paymenttransnops           udt_id;
        t_paytransobjectdefid        udt_id := api.pkg_configquery.objectdefidforname('o_PaymentTransactions');
    BEGIN
        t_jobid                := api.pkg_columnquery.VALUE(a_jobid, 'JobId');
        t_paymentstatusdefid   := api.pkg_objectdefquery.idforname('o_PaymentStatus');
        t_paytranspaystatendpoint   :=
            api.pkg_configquery.endpointidforname('o_PaymentTransactions', 'PaymentStatus');

        FOR c IN (SELECT reo.objectid  --TAyers: PIP Task 8.5
                    FROM api.fees f
                         JOIN api.feetransactions ft
                         ON ft.feeid = f.feeid
                         JOIN api.registeredexternalobjects reo
                         ON reo.linkvalue = TO_CHAR(ft.transactionid)
                        AND reo.objectdefid = t_paytransobjectdefid
                   WHERE f.jobid = t_jobid
                     AND api.pkg_columnquery.VALUE(reo.objectid, 'CABINAmtType') NOT IN ('R', 'C')
                     AND api.pkg_columnquery.VALUE(reo.objectid, 'IsOverpayment') = 'N')
        LOOP
            SELECT api.pkg_columnquery.VALUE(MAX(r.toobjectid), 'Status')
              INTO t_paymentstatusstatus
              FROM api.relationships r
             WHERE r.fromobjectid = c.objectid
               AND r.endpointid = api.pkg_configquery.endpointidforname('o_PaymentTransactions', 'PaymentStatus');

            IF t_paymentstatusstatus = 'UNEARNED' THEN
                t_newpaymentstatusobjectid   := api.pkg_objectupdate.new(t_paymentstatusdefid);
                t_paytranspaystatrelid       :=
                    api.pkg_relationshipupdate.new(t_paytranspaystatendpoint, c.objectid, t_newpaymentstatusobjectid);
                api.pkg_columnupdate.setvalue(t_newpaymentstatusobjectid, 'Status', 'EARNED');
                api.pkg_columnupdate.setvalue(t_newpaymentstatusobjectid, 'StatusDate', TRUNC(SYSDATE));
                api.pkg_columnupdate.setvalue(t_newpaymentstatusobjectid, 'SystemGenerated', 'Y');
            ELSIF t_paymentstatusstatus IS NULL THEN
                t_paymenttransnops           := c.objectid;
                t_newpaymentstatusobjectid   := api.pkg_objectupdate.new(t_paymentstatusdefid);
                t_paytranspaystatrelid       :=
                    api.pkg_relationshipupdate.new(t_paytranspaystatendpoint, c.objectid, t_newpaymentstatusobjectid);
                api.pkg_columnupdate.setvalue(t_newpaymentstatusobjectid, 'Status', 'EARNED');
                api.pkg_columnupdate.setvalue(t_newpaymentstatusobjectid, 'StatusDate', TRUNC(SYSDATE));
                api.pkg_columnupdate.setvalue(t_newpaymentstatusobjectid, 'SystemGenerated', 'Y');
            END IF;
        END LOOP;
    END createpaymentstatus;

    ----------------------------------------------------------------------------------------------------
    --CreateLTPaymentStatus() -- PUBLIC
    --run from the Produce License Batch, earns payment transactions on fees that are earned on payment
    ----------------------------------------------------------------------------------------------------
    PROCEDURE createltpaymentstatus(a_objectid udt_id, a_asofdate DATE)
    IS
        t_earnedamount               NUMBER;
        t_jobid                      udt_id;
        t_paymentstatusdefid         udt_id;
        t_newpaymentstatusobjectid   udt_id;
        t_paytranspaystatendpoint    udt_id;
        t_paymenttransferep          udt_id;
        t_paytranspaystatrelid       udt_id;
        t_paymentstatusstatus        VARCHAR2(100);
        t_renexpdate                 DATE;
        t_paymenttransfercheck       NUMBER;
        t_paytransobjectdefid        udt_id := api.pkg_configquery.objectdefidforname('o_PaymentTransactions');
        t_seasonal                   VARCHAR2(1);  -- WO 8517 TJL 05/25/2018
        t_StatusObjectId             udt_id;
    BEGIN
        t_jobid                := api.pkg_columnquery.VALUE(a_objectid, 'JobId');
        t_paymentstatusdefid   := api.pkg_objectdefquery.idforname('o_PaymentStatus');
        t_paytranspaystatendpoint   :=
            api.pkg_configquery.endpointidforname('o_PaymentTransactions', 'PaymentStatus');
        t_paymenttransferep    :=
            api.pkg_configquery.endpointidforname('p_PaymentTransfer', 'PaymentTransaction');

        pkg_debug.putline('Sitespecific.pkg_Fees - Create LT Payment Status - Start');
        --Loop thru the payment transaction on the license type and earn records that have no payment status and that relate to the license types in the batch
        FOR ltc_1
            IN (SELECT lt.licensetypecode ltcode,
                       lt.jobid,
                       lt.issuedate,
                       lt.PRINT,
                       lt.expirationdate,
                       lt.includeinchangeappbatch
                  FROM query.j_licensetype lt
                 WHERE lt.jobid = t_jobid
                UNION ALL
                  SELECT api.pkg_columnquery.VALUE(ltls.licensetypecategoryobjectid, 'LicenseTypeCode') ltcode,
                         lt.jobid,
                         api.pkg_columnquery.datevalue(d.duplicateid, 'BatchDate')                    issuedate,  --ltls.IssueDate, -- Changed Issue Date to Batch Date - Gurpreet
                         MAX(d.PRINT)                                                                 PRINT,  --ltls.Print, -- Added per CX recomendations - Issue # 2528 - by Gurpreet
                         lt.expirationdate,
                         ltls.includeinchangeappbatch
                    FROM query.j_licensetype lt
                         JOIN query.r_licensetypeltcatsecondary ltls
                         ON ltls.licensetypejobid = lt.jobid
                         JOIN sitespecific.duplicate_t d
                         ON d.relationshipid = ltls.relationshipid  -- Added per CX recomendations - Issue # 2528 - by Gurpreet
                   WHERE lt.jobid = t_jobid
                GROUP BY ltls.licensetypecategoryobjectid,
                         lt.jobid,
                         api.pkg_columnquery.datevalue(d.duplicateid, 'BatchDate'),
                         lt.expirationdate,
                         ltls.includeinchangeappbatch  -- Added per CX recomendations - Issue # 2528 - by Gurpreet
                                                     )
        LOOP
          pkg_debug.putline(' Create LT Payment Status, License Type Job ID: ' || t_jobid);
            -- RyanL: Changed the select and where clause to be a subselect for performance (PIP Task 8.5)
            FOR c IN (SELECT  /*+ CARDINALTY(x 1) */
                             reo.objectid,
                             f.feeid,
                             f.transactiondate,
                             ft.amount,
                             (  f.amount
                              + NVL((SELECT SUM(amount)
                                       FROM api.feetransactions ft
                                      WHERE ft.feeid = f.feeid
                                        AND ft.transactiontype = 'Adj'),
                                    0))
                                 feeamount
                        FROM api.fees f
                             JOIN sitespecific.feeschedule_t fs
                             ON fs.objectid = sitespecific.pkg_fees.getlicfeeschedulobjid(f.feeid)
                             JOIN api.feetransactions ft
                             ON ft.feeid = f.feeid
                             JOIN api.registeredexternalobjects reo  --TAyers: PIP Task 8.5
                             ON reo.linkvalue = TO_CHAR(ft.transactionid)
                            AND reo.objectdefid = t_paytransobjectdefid
                       WHERE f.jobid = ltc_1.jobid
                         AND api.pkg_columnquery.VALUE(fs.objectid, 'EarnedOn') = 'LICENSE ISSUANCE'
                         AND (api.pkg_columnquery.VALUE(reo.objectid, 'CABINAmtType') <> 'R'
                           OR (api.pkg_columnquery.VALUE(reo.objectid, 'CABINAmtType') = 'R'
                           AND api.pkg_columnquery.VALUE(reo.objectid, 'IsRefunded') = 'N'
                           AND api.pkg_columnquery.VALUE(reo.objectid, 'IsRefundReversed') = 'N'))
                         AND api.pkg_columnquery.VALUE(reo.objectid, 'IsRefunded') = 'N'
                         AND api.pkg_columnquery.VALUE(reo.objectid, 'IsOverpayment') = 'N'
                         AND api.pkg_columnquery.VALUE(reo.objectid, 'IsDishonored') = 'N'
                         AND api.pkg_columnquery.VALUE(reo.objectid, 'LicenseTypeCode') = ltc_1.ltcode
                         AND api.pkg_columnquery.VALUE(reo.objectid, 'PaymentAmount') > 0
                         AND (  f.amount
                              + NVL((SELECT SUM(amount)
                                       FROM api.feetransactions ft
                                      WHERE ft.feeid = f.feeid
                                        AND ft.transactiontype = 'Adj'),
                                    0)) > 0
                         AND api.pkg_columnquery.VALUE(reo.objectid, 'VoidedByTransactionId') IS NULL
                         AND ltc_1.PRINT = 'Y')
            LOOP
                -- Get the summed earned amounts for this transaction
                SELECT  /*+ CARDINALITY (pt 1) */
                       NVL(ABS(SUM(api.pkg_columnquery.numericvalue(r.paymentstatusobjectid, 'EarnedAmount'))), 0)
                  INTO t_earnedamount
                  FROM api.feetransactions ft
                       JOIN api.registeredexternalobjects reo  --TAyers: PIP Task 8.5
                       ON reo.linkvalue = TO_CHAR(ft.transactionid)
                      AND reo.objectdefid = t_paytransobjectdefid
                       JOIN query.r_paymentstatuspaymenttrans r
                       ON r.paymenttransactionobjectid = reo.objectid
                 WHERE ft.feeid = c.feeid;


                /*                SELECT COUNT(1)
                                  INTO t_paymenttransfercheck
                                  FROM query.r_paymenttransfertrans r
                                 WHERE r.paymenttransactionobjectid = c.objectid
                                   AND api.pkg_columnquery.VALUE(r.paymenttransferprocessid,
                                                                 'Outcome')
                                           IS NOT NULL
                                   AND r.amount < 0;*/
                -- SG: Equivalent SQL Statement that uses correct index
                SELECT COUNT(*)
                  INTO t_paymenttransfercheck
                  FROM query.p_paymenttransfer pt
                       JOIN api.relationships r
                       ON r.fromobjectid = pt.objectid
                 WHERE r.toobjectid = c.objectid
                   AND r.endpointid = t_paymenttransferep
                   AND api.pkg_columnquery.VALUE(r.relationshipid, 'Amount') < 0
                   AND pt.outcome IS NOT NULL;

                IF t_paymenttransfercheck = 0
               AND t_earnedamount < c.feeamount THEN
                    -- Get the correct amount to earn
                    IF t_earnedamount - c.amount > c.feeamount THEN
                        t_earnedamount   := -c.feeamount + t_earnedamount;
                    ELSE
                        t_earnedamount   := c.amount;
                    END IF;

                    t_renexpdate   :=
                        api.pkg_columnquery.datevalue(api.pkg_simplesearch.objectbyindex('o_Fee', 'FeeId', c.feeid),
                                                      'RENExpirationDate');

                    -- WO 8517 TJL 05/25/2018 Added for seasonal testing
                    t_seasonal     :=
                        CASE
                            WHEN api.pkg_columnquery.VALUE(ltc_1.jobid, 'SeasonStartMonth') IS NOT NULL THEN 'Y'
                            ELSE 'N'
                        END;

                    -- If the RENExpirationDate on the fee = the Exp Date entered in the batch, or the transaction date is
                    -- greater than the expiration date - 1 year.
                    IF (  -- WO 8517 TJL 05/25/2018
                        (t_seasonal = 'N'
                     AND t_renexpdate = ltc_1.expirationdate)
                     OR  -- For seasonal licenses the license expiration date is different from the renewal date. You
                         --  have to generate a license renewal date from the license experation to compare against
                         --  the renewal experation date from the renew fee object.
                        (t_seasonal = 'Y'
                     AND t_renexpdate =
                           (TRUNC(
                                ADD_MONTHS(
                                    ltc_1.expirationdate,
                                      -(api.pkg_columnquery.numericvalue(ltc_1.jobid, 'NumberOfMonthsLicensedNumber'))
                                    + 12),
                                'Month'))
                         - 1))  -- end of changes
                    OR (t_renexpdate IS NULL
                    AND c.transactiondate >= LAST_DAY(TO_DATE(   TO_CHAR(ltc_1.expirationdate, 'MM')
                                                              || '/01/'
                                                              || (TO_CHAR(ltc_1.expirationdate, 'YYYY') - 1),
                                                              'MM/DD/YYYY'))) THEN
                        SELECT api.pkg_columnquery.VALUE(MAX(r.toobjectid), 'Status')
                          INTO t_paymentstatusstatus
                          FROM api.relationships r
                         WHERE r.fromobjectid = c.objectid
                           AND r.endpointid = t_paytranspaystatendpoint;

                        IF t_paymentstatusstatus IS NULL
                        OR t_paymentstatusstatus = 'UNEARNED' THEN
                            t_newpaymentstatusobjectid   := api.pkg_objectupdate.new(t_paymentstatusdefid);
                            t_paytranspaystatrelid       :=
                                api.pkg_relationshipupdate.new(t_paytranspaystatendpoint,
                                                               c.objectid,
                                                               t_newpaymentstatusobjectid);
                            api.pkg_columnupdate.setvalue(t_newpaymentstatusobjectid, 'Status', 'EARNED');
                            api.pkg_columnupdate.setvalue(t_newpaymentstatusobjectid, 'StatusDate', TRUNC(SYSDATE));
                            api.pkg_columnupdate.setvalue(t_newpaymentstatusobjectid, 'SystemGenerated', 'Y');
                            api.pkg_columnupdate.setvalue(t_newpaymentstatusobjectid, 'EarnedAmount', t_earnedamount);
                        END IF;
                    END IF;

                    -- Remove RENExpDate variable value
                    t_renexpdate   := NULL;
                END IF;
            END LOOP;

            --Loop thru the payment transaction on the license and earn records that have no payment status and that relate to the license types in the batch
            FOR ltc_2 IN (SELECT llt.licensejobid jobid
                            FROM query.r_licenselicensetype llt
                           WHERE llt.licensetypejobid = ltc_1.jobid)
            LOOP
                -- RyanL: Changed the select and where clause to be a subselect for performance (PIP Task 8.5)
                FOR d IN (SELECT  /*+ CARDINALITY (x 1)*/
                                 reo.objectid,
                                 f.feeid,
                                 f.transactiondate,
                                 fs.feeactivity,
                                 ft.amount,
                                 (  f.amount
                                  + NVL((SELECT SUM(amount)
                                           FROM api.feetransactions ft
                                          WHERE ft.feeid = f.feeid
                                            AND ft.transactiontype = 'Adj'),
                                        0))
                                     feeamount
                            FROM api.fees f
                                 JOIN sitespecific.feeschedule_t fs
                                 ON fs.objectid = sitespecific.pkg_fees.getlicfeeschedulobjid(f.feeid)
                                 JOIN api.feetransactions ft
                                 ON ft.feeid = f.feeid
                                 JOIN api.registeredexternalobjects reo  --TAyers: PIP Task 8.5
                                 ON reo.linkvalue = TO_CHAR(ft.transactionid)
                                AND reo.objectdefid = t_paytransobjectdefid
                           WHERE f.jobid = ltc_2.jobid
                             AND api.pkg_columnquery.VALUE(fs.objectid, 'EarnedOn') = 'LICENSE ISSUANCE'
                             AND (api.pkg_columnquery.VALUE(reo.objectid, 'CABINAmtType') <> 'R'
                               OR (api.pkg_columnquery.VALUE(reo.objectid, 'CABINAmtType') = 'R'
                               AND api.pkg_columnquery.VALUE(reo.objectid, 'IsRefunded') = 'N'
                               AND api.pkg_columnquery.VALUE(reo.objectid, 'IsRefundReversed') = 'N'))
                             AND api.pkg_columnquery.VALUE(reo.objectid, 'IsRefunded') = 'N'
                             AND api.pkg_columnquery.VALUE(reo.objectid, 'IsOverpayment') = 'N'
                             AND api.pkg_columnquery.VALUE(reo.objectid, 'IsDishonored') = 'N'
                             AND api.pkg_columnquery.VALUE(reo.objectid, 'LicenseTypeCode') = ltc_1.ltcode
                             AND api.pkg_columnquery.VALUE(reo.objectid, 'PaymentAmount') > 0
                             AND (  f.amount
                                  + NVL((SELECT SUM(amount)
                                           FROM api.feetransactions ft
                                          WHERE ft.feeid = f.feeid
                                            AND ft.transactiontype = 'Adj'),
                                        0)) > 0
                             AND api.pkg_columnquery.VALUE(reo.objectid, 'VoidedByTransactionId') IS NULL
                             AND ltc_1.PRINT = 'Y'
                             AND ((ltc_1.issuedate IS NOT NULL
                               AND fs.feeactivity IN ('REN', 'REN50', 'REN100'))
                               OR (ltc_1.issuedate IS NULL
                               AND fs.feeactivity NOT IN ('REN', 'REN50', 'REN100'))))
                LOOP
                    -- Get the summed earned amounts for this transaction
                    SELECT  /*+ CARDINALITY (pt 1) */
                           NVL(ABS(SUM(api.pkg_columnquery.numericvalue(r.paymentstatusobjectid, 'EarnedAmount'))),
                               0)
                      INTO t_earnedamount
                      FROM api.feetransactions ft
                           JOIN api.registeredexternalobjects reo  --TAyers: PIP Task 8.5
                           ON reo.linkvalue = TO_CHAR(ft.transactionid)
                          AND reo.objectdefid = t_paytransobjectdefid
                           JOIN query.r_paymentstatuspaymenttrans r
                           ON r.paymenttransactionobjectid = reo.objectid
                     WHERE ft.feeid = d.feeid;

                    /*                    SELECT COUNT(1)
                                          INTO t_paymenttransfercheck
                                          FROM query.r_paymenttransfertrans r
                                         WHERE r.paymenttransactionobjectid = d.objectid
                                           AND api.pkg_columnquery.VALUE(
                                                   r.paymenttransferprocessid,
                                                   'Outcome')
                                                   IS NOT NULL
                                           AND r.amount < 0;*/
                    -- SG: Equivalent SQL Statement that uses correct index
                    SELECT COUNT(*)
                      INTO t_paymenttransfercheck
                      FROM query.p_paymenttransfer pt
                           JOIN api.relationships r
                           ON r.fromobjectid = pt.objectid
                     WHERE r.toobjectid = d.objectid
                       AND r.endpointid = t_paymenttransferep
                       AND api.pkg_columnquery.VALUE(r.relationshipid, 'Amount') < 0
                       AND pt.outcome IS NOT NULL;

                    IF t_paymenttransfercheck = 0
                   AND t_earnedamount < d.feeamount THEN
                        -- Get the correct amount to earn
                        IF t_earnedamount - d.amount > d.feeamount THEN
                            t_earnedamount   := -d.feeamount + t_earnedamount;
                        ELSE
                            t_earnedamount   := d.amount;
                        END IF;

                        t_renexpdate   :=
                            api.pkg_columnquery.datevalue(
                                api.pkg_simplesearch.objectbyindex('o_Fee', 'FeeId', d.feeid),
                                'RENExpirationDate');

                        -- if the Fee is a REN and the RENExpirationDate on the fee = the Exp Date entered in the batch, or the transaction date is
                        -- greater than the expiration date - 1 year.
                        IF (d.feeactivity IN ('REN', 'REN50', 'REN100')
                        AND t_renexpdate = ltc_1.expirationdate
                         OR (t_renexpdate IS NULL
                         AND d.transactiondate >= LAST_DAY(TO_DATE(   TO_CHAR(ltc_1.expirationdate, 'MM')
                                                                   || '/01/'
                                                                   || (TO_CHAR(ltc_1.expirationdate, 'YYYY') - 1),
                                                                   'MM/DD/YYYY'))))
                        OR d.feeactivity NOT IN ('REN', 'REN50', 'REN100') THEN
                         begin 
                            SELECT r.toobjectid
                              INTO t_StatusObjectId
                              FROM api.relationships r
                             WHERE r.fromobjectid = d.objectid
                               AND r.endpointid = t_paytranspaystatendpoint
                               ORDER BY r.logicaltransactionid
                               FETCH FIRST 1 ROWS ONLY;

                            t_paymentstatusstatus := api.pkg_columnquery.VALUE(t_StatusObjectId, 'Status');
                            
                          exception when no_data_found then
                            pkg_debug.putline('    Payment Status not found, setting to Null');
                            t_StatusObjectId := null;
                            t_paymentstatusstatus := null;
                          end; -- Added as per Dalainya to resolve no data found on produce license5/9/2023
                          

                            IF t_paymentstatusstatus IS NULL
                            OR t_paymentstatusstatus = 'UNEARNED' THEN
                                t_newpaymentstatusobjectid   := api.pkg_objectupdate.new(t_paymentstatusdefid);
                                t_paytranspaystatrelid       :=
                                    api.pkg_relationshipupdate.new(t_paytranspaystatendpoint,
                                                                   d.objectid,
                                                                   t_newpaymentstatusobjectid);
                                api.pkg_columnupdate.setvalue(t_newpaymentstatusobjectid, 'Status', 'EARNED');
                                api.pkg_columnupdate.setvalue(t_newpaymentstatusobjectid,
                                                              'StatusDate',
                                                              TRUNC(SYSDATE));
                                api.pkg_columnupdate.setvalue(t_newpaymentstatusobjectid, 'SystemGenerated', 'Y');
                                api.pkg_columnupdate.setvalue(t_newpaymentstatusobjectid,
                                                              'EarnedAmount',
                                                              t_earnedamount);
                            END IF;
                        END IF;

                        -- Remove RENExpDate variable value
                        t_renexpdate   := NULL;
                    END IF;
                END LOOP;
            END LOOP;

            --Loop thru the payment transaction on the application and earn records that have no payment status and that relate to the license types in the batch
            FOR ltc_3 IN (SELECT al.applicationjobid jobid
                            FROM query.r_licenselicensetype llt
                                 JOIN query.j_license l
                                 ON l.objectid = llt.licensejobid
                                 JOIN query.r_applicationlicense al
                                 ON al.licensejobid = l.objectid
                           WHERE llt.licensetypejobid = ltc_1.jobid)
            LOOP
                  pkg_debug.putline('    Application Job ID: ' || ltc_3.JobId);
                  pkg_debug.putline('    License Type Job ID: ' ||ltc_1.jobid);
                -- RyanL: Changed the select and where clause to be a subselect for performance (PIP Task 8.5)
                FOR e
                    IN (SELECT  /*+ CARDINALITY(x 1) */
                               reo.objectid,
                               f.feeid,
                               ft.amount,
                               (  f.amount
                                + NVL((SELECT SUM(amount)
                                         FROM api.feetransactions ft
                                        WHERE ft.feeid = f.feeid
                                          AND ft.transactiontype = 'Adj'),
                                      0))
                                   feeamount
                          FROM api.fees f
                               JOIN api.feetransactions ft
                               ON ft.feeid = f.feeid
                               JOIN sitespecific.feeschedule_t fs
                               ON fs.objectid = sitespecific.pkg_fees.getlicfeeschedulobjid(f.feeid)
                               JOIN api.registeredexternalobjects reo  --TAyers: PIP Task 8.5
                               ON reo.linkvalue = TO_CHAR(ft.transactionid)
                              AND reo.objectdefid = t_paytransobjectdefid
                         WHERE f.jobid = ltc_3.jobid
                           AND api.pkg_columnquery.VALUE(fs.objectid, 'EarnedOn') = 'LICENSE ISSUANCE'
                           AND (api.pkg_columnquery.VALUE(reo.objectid, 'CABINAmtType') <> 'R'
                             OR (api.pkg_columnquery.VALUE(reo.objectid, 'CABINAmtType') = 'R'
                             AND api.pkg_columnquery.VALUE(reo.objectid, 'IsRefunded') = 'N'
                             AND api.pkg_columnquery.VALUE(reo.objectid, 'IsRefundReversed') = 'N'))
                           AND api.pkg_columnquery.VALUE(reo.objectid, 'IsRefunded') = 'N'
                           AND api.pkg_columnquery.VALUE(reo.objectid, 'IsOverpayment') = 'N'
                           AND api.pkg_columnquery.VALUE(reo.objectid, 'IsDishonored') = 'N'
                           -- 04/04/2019 TJL WO 17620 Add null check for APP not linked to license type
                           AND NVL(api.pkg_columnquery.VALUE(reo.objectid, 'LicenseTypeCode'), ltc_1.ltcode) =
                               ltc_1.ltcode
                           AND api.pkg_columnquery.VALUE(reo.objectid, 'PaymentAmount') > 0
                           AND (  f.amount
                                + NVL((SELECT SUM(amount)
                                         FROM api.feetransactions ft
                                        WHERE ft.feeid = f.feeid
                                          AND ft.transactiontype = 'Adj'),
                                      0)) > 0
                           AND api.pkg_columnquery.VALUE(reo.objectid, 'VoidedByTransactionId') IS NULL
                           AND ltc_1.PRINT = 'Y'
                           AND ((ltc_1.issuedate IS NOT NULL
                             AND ltc_1.includeinchangeappbatch = 'N'
                             AND fs.feeactivity IN ('REN', 'REN50', 'REN100'))
                             OR (ltc_1.issuedate IS NULL
                              OR ltc_1.includeinchangeappbatch = 'Y'
                             AND fs.feeactivity NOT IN ('REN', 'REN50', 'REN100'))))
                LOOP
                    pkg_debug.putline('   Loop E, Fee Id: ' || e.feeid);
                    pkg_debug.putline('   Loop E, Fee Ammount: ' || e.FeeAmount);
                    -- Get the summed earned amounts for this transaction
                    SELECT  /*+ CARDINALITY (pt 1) */
                           NVL(ABS(SUM(api.pkg_columnquery.numericvalue(r.paymentstatusobjectid, 'EarnedAmount'))),
                               0)
                      INTO t_earnedamount
                      FROM api.feetransactions ft
                           JOIN api.registeredexternalobjects reo  --TAyers: PIP Task 8.5
                           ON reo.linkvalue = TO_CHAR(ft.transactionid)
                          AND reo.objectdefid = t_paytransobjectdefid
                           JOIN query.r_paymentstatuspaymenttrans r
                           ON r.paymenttransactionobjectid = reo.objectid
                     WHERE ft.feeid = e.feeid;

                    /*                    SELECT COUNT(1)
                                          INTO t_paymenttransfercheck
                                          FROM query.r_paymenttransfertrans r
                                         WHERE r.paymenttransactionobjectid = e.objectid
                                           AND api.pkg_columnquery.VALUE(
                                                   r.paymenttransferprocessid,
                                                   'Outcome')
                                                   IS NOT NULL
                                           AND r.amount < 0;*/

                    pkg_debug.putline('   Loop E, Earned Ammount: ' || t_earnedamount);
                    -- SG: Equivalent SQL Statement that uses correct index
                    SELECT COUNT(*)
                      INTO t_paymenttransfercheck
                      FROM query.p_paymenttransfer pt
                           JOIN api.relationships r
                           ON r.fromobjectid = pt.objectid
                     WHERE r.toobjectid = e.objectid
                       AND r.endpointid = t_paymenttransferep
                       AND api.pkg_columnquery.VALUE(r.relationshipid, 'Amount') < 0
                       AND pt.outcome IS NOT NULL;

                   pkg_debug.putline('   Loop E, paymenttransfercheck: ' || t_paymenttransfercheck);

                    IF t_paymenttransfercheck = 0
                   AND t_earnedamount < e.feeamount THEN
                        -- Get the correct amount to earn
                        IF t_earnedamount - e.amount > e.feeamount THEN
                            t_earnedamount   := -e.feeamount + t_earnedamount;
                        ELSE
                            t_earnedamount   := e.amount;
                        END IF;
                             pkg_debug.putline('   Loop E,  e.objectid: ' || e.ObjectId);

                          begin
                            SELECT r.toobjectid
                              INTO t_StatusObjectId
                              FROM api.relationships r
                             WHERE r.fromobjectid = e.objectid
                               AND r.endpointid = t_paytranspaystatendpoint
                               ORDER BY r.logicaltransactionid
                               FETCH FIRST 1 ROWS ONLY;

                            t_paymentstatusstatus := api.pkg_columnquery.VALUE(t_StatusObjectId, 'Status');

                          exception when no_data_found then
                            pkg_debug.putline('    Payment Status not found, setting to Null');
                            t_StatusObjectId := null;
                            t_paymentstatusstatus := null;
                          end;

                        IF t_paymentstatusstatus IS NULL
                        OR t_paymentstatusstatus = 'UNEARNED' THEN
                            t_newpaymentstatusobjectid   := api.pkg_objectupdate.new(t_paymentstatusdefid);
                            t_paytranspaystatrelid       :=
                                api.pkg_relationshipupdate.new(t_paytranspaystatendpoint,
                                                               e.objectid,
                                                               t_newpaymentstatusobjectid);
                            api.pkg_columnupdate.setvalue(t_newpaymentstatusobjectid, 'Status', 'EARNED');
                            api.pkg_columnupdate.setvalue(t_newpaymentstatusobjectid, 'StatusDate', TRUNC(SYSDATE));
                            api.pkg_columnupdate.setvalue(t_newpaymentstatusobjectid, 'SystemGenerated', 'Y');
                            api.pkg_columnupdate.setvalue(t_newpaymentstatusobjectid, 'EarnedAmount', t_earnedamount);
                        END IF;
                    END IF;
                END LOOP;
            END LOOP;
        END LOOP;
    END createltpaymentstatus;

    --------------------------------------------------------
    -- Create Manual Fee - Public
    -- Run from the Create Manual Fee process.
    --------------------------------------------------------
    PROCEDURE createmanualfee(a_objectid NUMBER, a_asofdate DATE, a_jobid NUMBER)
    IS
        t_glaccountid            NUMBER;
        t_feeobjid               NUMBER;
        t_feeid                  NUMBER;
        t_proceduredescription   VARCHAR2(50);
        t_description            VARCHAR2(50);
        t_relid                  NUMBER;
        t_pltcodes               VARCHAR2(4000);
    BEGIN
        --select Primary License Type Codes from Application
        BEGIN
            SELECT a.primarylicensetypecodes
              INTO t_pltcodes
              FROM query.j_application a
             WHERE a.jobid = a_jobid;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                NULL;
        END;

        --select Primary License Type Codes from License
        BEGIN
            SELECT l.primarylicensetypecodes
              INTO t_pltcodes
              FROM query.j_license l
             WHERE l.jobid = a_jobid;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                NULL;
        END;

        --select Primary License Type Codes from License Type
        BEGIN
            SELECT lt.primarylicensetypecodes
              INTO t_pltcodes
              FROM query.j_licensetype lt
             WHERE lt.jobid = a_jobid;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                NULL;
        END;

        --Get FeeActivity, Amount from feeschedules related to the process
        FOR i IN (SELECT fs.feeactivity,
                         fs.objectid,
                         fs.licensetypecode,
                         r.amount feeamount,
                         r.secondarycount,
                         r.ismaster,
                         r.masterlt
                    FROM sitespecific.feeschedule_t fs
                         JOIN query.r_createmanualfeefeeschedule r
                         ON r.licensefeescheduleobjectid = fs.objectid
                   WHERE r.createmanualfeeprocessid = a_objectid)
        LOOP
            IF t_pltcodes NOT LIKE
                      '%'
                   || i.masterlt
                   || '%' THEN
                api.pkg_errors.raiseerror(-20000, 'Each Master LT Code must be a Primary License Type.');
            END IF;

            --The following code about the Valid MasterLTCount is being commented out because we need to allow
            --for the user to enter a count when there is not an LT code on the Fee Schedule such as Fingerprints
            /* select count(1) into t_ValidMasterLTCount
            from query.o_licensetypecategory ltc
            join query.r_PrimarySecondaryLTCategory q on q.PrimaryLTCategoryObjectId = ltc.ObjectId
            join query.o_licensetypecategory sltc on sltc.ObjectId = q.SecondaryLTCategoryObjectId
            where ltc.LicenseTypeCode = i.masterlt
            and i.licensetypecode = sltc.LicenseTypeCode;*/

            IF i.ismaster = 'Y'
           AND i.masterlt <> i.licensetypecode
           AND i.masterlt IS NOT NULL THEN
                api.pkg_errors.raiseerror(
                    -20000,
                    'When Is Master is checked, the Master LT Code must match the Fee Schedule''s LT Code.');
            /* elsif i.secondarycount > 0 and
            t_ValidMasterLTCount = 0
            then api.pkg_errors.RaiseError(-20000, 'Each Fee Schedule''s LT Code must be a valid secondary for its Master LT Code.');*/
            ELSIF (i.secondarycount = 0
                OR i.secondarycount IS NULL)
              AND i.masterlt IS NOT NULL THEN
                api.pkg_errors.raiseerror(
                    -20000,
                    'The Master LT Code can only be entered when the Secondary Count is greater than zero.');
            END IF;

            --If there is a FeeAmount, create fee.
            IF i.feeamount >= 0 THEN
                --Get GLAccountId
                BEGIN
                    SELECT g.glaccountid
                      INTO t_glaccountid
                      FROM api.glaccounts g
                     WHERE g.glaccount = i.feeactivity;
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        api.pkg_errors.raiseerror(-20000,
                                                     'Missing GL Account - '
                                                  || i.feeactivity
                                                  || '.');
                END;

                --select procedure description
                SELECT f.proceduredescription
                  INTO t_proceduredescription
                  FROM query.o_feeschedule f
                 WHERE f.objectid = i.objectid;

                --set description. When LTcode is null, then simply procedure description. When LTCode is not null and IsMaster = Y then Primary, else secondary.
                --Most of this is out dated 2009_3_19
                /*if i.licensetypecode is null
                then */
                t_description   := t_proceduredescription;
                /*elsif i.ismaster = 'Y'
                then t_Description := i.licensetypecode || ' - Primary, ' || t_ProcedureDescription;
                elsif i.ismaster = 'N'
                then t_Description := i.licensetypecode || ' - Secondary, ' || t_ProcedureDescription;
                end if;*/

                --CreateFee
                sitespecific.pkg_fees.newfee(t_feeid,
                                             i.feeamount,
                                             t_description,
                                             t_glaccountid,
                                             a_jobid,
                                             NULL,
                                             t_feeobjid,
                                             FALSE);  /*Manual Fee should not be rounding when creating a new Fee set: case when i.feeactivity = 'RPL'
                then False
                else True end to always be false --KL 2/25/2010*/

                -- Relate Fee to Fee Schedule
                t_relid         :=
                    api.pkg_relationshipupdate.new(
                        api.pkg_configquery.endpointidforname('o_Fee', 'LicenseFeeSchedule'),
                        t_feeobjid,
                        i.objectid);

                -- Set Quantity on Fee
                IF i.secondarycount > 0 THEN
                    api.pkg_columnupdate.setvalue(t_feeobjid, 'Quantity', i.secondarycount);

                    -- Set the relationship detail SecondaryCount to the count of secondary LTs
                    api.pkg_columnupdate.setvalue(t_relid, 'SecondaryCount', i.secondarycount);
                END IF;

                -- Set the relationship detail IsMaster
                -- 09/17/2019 TJL 19066 moved below from licensetypecode test
                api.pkg_columnupdate.setvalue(t_relid, 'IsMaster', i.ismaster);

                --When LT information aplices
                IF i.licensetypecode IS NOT NULL THEN
                    IF i.secondarycount > 0 THEN
                        -- Set the relationship detail MasterLT to the Master LT Code
                        api.pkg_columnupdate.setvalue(t_relid, 'MasterLT', i.masterlt);
                    END IF;

                    -- If the job is a License Type, set the RENExpiration Date detail on the Fee object
                    IF api.pkg_columnquery.VALUE(a_jobid, 'ObjectDefName') = 'j_LicenseType' THEN
                        api.pkg_columnupdate.setvalue(t_feeobjid,
                                                      'RENExpirationDate',
                                                      api.pkg_columnquery.datevalue(a_jobid, 'ExpirationDate'));
                    END IF;
                END IF;
            ELSE
                api.pkg_errors.raiseerror(
                    -20000,
                    'An Amount greater than $0.00 must be entered for each Manual Fee in the grid.');
            END IF;
        END LOOP;
    END createmanualfee;

    --------------------------------------------------------
    -- RelatePaymentTransactions -PUBLIC
    -- Run on Constructor of Payment(From) to PaymentTransfer relationship
    -- Relate Payment Transactions objects to Payment Transfer process when Payment is related
    --------------------------------------------------------
    PROCEDURE relatepaymenttransactions(a_objectid NUMBER, a_asofdate DATE)
    IS
        t_endpointid            NUMBER;
        t_paymentid             NUMBER;
        t_relid                 NUMBER;
        t_ptobjids              udt_idlist;
        t_priorcount            NUMBER;
        t_paytransobjectdefid   udt_id := api.pkg_configquery.objectdefidforname('o_PaymentTransactions');
    BEGIN
        --PaymentId
        SELECT p.paymentid
          INTO t_paymentid
          FROM api.relationships r
               JOIN query.o_payment p
               ON p.objectid = r.toobjectid
         WHERE r.fromobjectid = a_objectid
           AND r.endpointid = api.pkg_configquery.endpointidforname('p_PaymentTransfer', 'Payment');

        --Check if Relationships to Payment Transaction already exists
        SELECT COUNT(r.relationshipid)
          INTO t_priorcount
          FROM api.relationships r
               JOIN query.o_paymenttransactions pt
               ON pt.objectid = r.toobjectid
         WHERE r.fromobjectid = a_objectid
           AND r.endpointid = api.pkg_configquery.endpointidforname('p_PaymentTransfer', 'PaymentTransaction')
           AND pt.paymentid = t_paymentid;

        --only run rest of procedure if there are no prior Payment Transactions related.
        IF t_priorcount = 0 THEN
            --Get PaymentId and Payment PaymentTransferObjectId

            t_endpointid   := api.pkg_configquery.endpointidforname('p_PaymentTransfer', 'PaymentTransaction');

            --use PaymentID to get Payment Transaction objectIds
            SELECT t.objectid
              BULK COLLECT INTO t_ptobjids
              FROM (SELECT reo.objectid, api.pkg_columnquery.VALUE(objectid, 'PaymentAmount') pamt
                      FROM api.paymenttransactions pt
                           JOIN api.registeredexternalobjects reo  --TAyers: PIP Task 8.5
                           ON reo.linkvalue = TO_CHAR(pt.transactionid)
                          AND reo.objectdefid = t_paytransobjectdefid
                     WHERE pt.paymentid = t_paymentid
                       AND reo.objectid NOT IN (SELECT DISTINCT (reo.objectid)
                                                  FROM api.paymenttransactions pt
                                                       JOIN api.registeredexternalobjects reo  --TAyers: PIP Task 8.5
                                                       ON reo.linkvalue = TO_CHAR(pt.transactionid)
                                                      AND reo.objectdefid = t_paytransobjectdefid
                                                       JOIN query.r_paymenttransfertrans rpt
                                                       ON rpt.paymenttransactionobjectid = reo.objectid
                                                 WHERE pt.paymentid = t_paymentid
                                                   AND (rpt.amount > 0))) t
             WHERE t.pamt > 0;

            --Relate Payment Transactions to Process
            FOR c IN 1 .. t_ptobjids.COUNT
            LOOP
                IF api.pkg_columnquery.VALUE(t_ptobjids(c), 'IsRefunded') = 'N' THEN
                    t_relid   := api.pkg_relationshipupdate.new(t_endpointid, a_objectid, t_ptobjids(c));
                END IF;
            END LOOP;
        END IF;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            NULL;  --api.pkg_errors.RaiseError(-20000,'test');
    END relatepaymenttransactions;

    --------------------------------------------------------
    -- Delete Payment Transactions
    -- Run on Destructor of Payment(From) to PaymentTransfer relationship
    -- Deletes Payment Transactions related to the Payment Transfer Process when the Related Payment is deleted
    --------------------------------------------------------
    PROCEDURE deletepaymenttransrel(a_objectid NUMBER, a_asofdate DATE)
    IS
    BEGIN
        --Delete rels from Payment Transfer to Payment Transaction
        FOR c
            IN (SELECT DISTINCT (r.relationshipid)
                  FROM api.relationships r
                       JOIN query.o_paymenttransactions pt
                       ON pt.objectid = r.toobjectid
                 WHERE r.fromobjectid = a_objectid
                   AND r.endpointid =
                       api.pkg_configquery.endpointidforname('p_PaymentTransfer', 'PaymentTransaction')
                   AND pt.paymentid <>
                       (SELECT p.paymentid
                          FROM api.relationships r
                               JOIN query.o_payment p
                               ON p.objectid = r.toobjectid
                         WHERE r.fromobjectid = a_objectid
                           AND r.endpointid = api.pkg_configquery.endpointidforname('p_PaymentTransfer', 'Payment')))
        LOOP
            api.pkg_relationshipupdate.remove(c.relationshipid);
        END LOOP;
    END deletepaymenttransrel;

    --------------------------------------------------------
    -- Transfer Payment
    -- To be run off the Transfer Payment process, the process adjusts fees.
    --------------------------------------------------------
    PROCEDURE transferpayment(a_objectid NUMBER, a_asofdate DATE)
    IS
        TYPE udt_feeids IS TABLE OF NUMBER
            INDEX BY BINARY_INTEGER;

        TYPE boollist IS VARRAY(100) OF VARCHAR2(1);

        t_batchpaymentid          VARCHAR2(20);
        t_defaultofficeobjectid   udt_id;
        t_depositdate             DATE;
        t_doneonce                VARCHAR2(1);
        t_earnedamount            NUMBER;
        t_earnedonpay             NUMBER;
        t_endpointid              NUMBER;
        t_feejobid                udt_id;
        t_feescheduleid           udt_id;
        t_hqreceipt               VARCHAR2(8);
        t_isreceipted             VARCHAR2(1);
        t_methodid                NUMBER;
        t_newpaymentsdate         DATE;
        t_newsrvfee               udt_id;
        t_newsrvfeeobjid          udt_id;
        t_origamounts             udt_numberlist;
        t_origfeeid               udt_idlist;
        t_origfeeids              udt_feeids;
        t_origpaymentids          udt_idlist;
        t_origpaymentobjid        NUMBER;
        t_ovrpayamounts           udt_numberlist;
        t_ovrtofeeid              udt_idlist;
        t_payamounts              udt_numberlist;
        t_payamountsovr           udt_numberlist;
        t_paymentid               NUMBER;
        t_paymentids              api.udt_objectlist;
        t_paymentobjectid         NUMBER;
        t_paymentstatusdefid      NUMBER;
        t_paymentstatusendpoint   NUMBER;
        t_paymentstatusobjid      NUMBER;
        t_paytransobjectid        NUMBER;
        t_paytransobjectids       udt_idlist;
        t_priorcount              NUMBER;
        t_processid               udt_id;
        t_ptamounts               udt_numberlist;
        t_ptfeeid                 udt_idlist;
        t_ptorigobjlist           udt_idlist;
        t_receiptnumber           VARCHAR2(40);
        t_reference               VARCHAR2(4000);
        t_relid                   NUMBER;
        t_srvamounts              api.pkg_definition.udt_numberlist;
        t_srvfeeamount            NUMBER;
        t_srvfeeids               api.pkg_definition.udt_objectlist;
        t_srvflag                 boollist := boollist();
        t_srvglaccountid          NUMBER;
        t_srvpaymentid            NUMBER;
        t_temp                    udt_idlist;
        t_tofeeid                 udt_idlist;
        t_tofeeisovr              udt_idlist;
        t_transactionobjid        NUMBER;
        t_unearnamount            NUMBER;
        t_unpaymentid             NUMBER;
        t_var                     pkg_refund.var := pkg_refund.var();
        t_xlicensenumber          udt_numberlist;
        t_xlicensetypecode        udt_numberlist;
        t_transmittalobjectid     udt_id;
        t_paymentobjectdefid      udt_id := api.pkg_configquery.objectdefidforname('o_Payment');
        t_paytransobjectdefid     udt_id := api.pkg_configquery.objectdefidforname('o_PaymentTransactions');
    BEGIN
        -- This will be the payment date on the
        t_newpaymentsdate   := TRUNC(SYSDATE);

        BEGIN
            --Get SRV GL Account Id
            SELECT gl.glaccountid
              INTO t_srvglaccountid
              FROM api.glaccounts gl
             WHERE gl.glaccount = 'SRV';
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                api.pkg_errors.raiseerror(-20000,
                                             'No GL Account exists for Fee Activity '
                                          || 'SRV');
        END;

        --Remove all Var values and reset the index
        t_var.delete;

        SELECT COUNT(r.relationshipid)
          INTO t_priorcount
          FROM api.relationships r
         WHERE r.fromobjectid = a_objectid
           AND r.endpointid = api.pkg_configquery.endpointidforname('p_PaymentTransfer', 'PaymentTo');

        --only run procedure when process is completed and the procedure has not already created a PaymentTo relationship
        IF (api.pkg_columnquery.VALUE(a_objectid, 'Outcome') IS NOT NULL
        AND t_priorcount = 0) THEN
            --Find the HQ receipt number
            SELECT api.pkg_columnquery.VALUE(pfpt.paymentobjectid, 'HQReceiptLookup')
              INTO t_hqreceipt
              FROM query.r_paymentfrompaytransfer pfpt
             WHERE pfpt.paytransferprocessid = a_objectid;

            --Find the Deposited Date
            SELECT api.pkg_columnquery.datevalue(pfpt.paymentobjectid, 'DepositedDate')
              INTO t_depositdate
              FROM query.r_paymentfrompaytransfer pfpt
             WHERE pfpt.paytransferprocessid = a_objectid;

            --Raise error when Move From Payment has been voided.
            IF api.pkg_columnquery.VALUE(a_objectid, 'IsVoidedFrom') = 'Y' THEN
                api.pkg_errors.raiseerror(-20000, 'Payment has been voided!');
            END IF;

            --Raise error when Move From Payment Transaction and Fee grid Pay amounts don't equal.
            IF api.pkg_columnquery.VALUE(a_objectid, 'RaiseErrToFromAmounts') = 'Y' THEN
                api.pkg_errors.raiseerror(
                    -20000,
                    'The Total amount you are Moving from the Payment Transactions Must Be Equal to the total Pay Amounts in the Move to Fees grid.');
            END IF;

            --Get from FeeIds will have payments adjusted off and the Amounts to be removed
            SELECT ft.feeid,
                   r.amount,  --change -r.amount to r.amount
                   reo.objectid,
                   pt.paymentid,
                   pt.objectid,
                   pt.licensenumber,
                   pt.licensetypecode,
                   pt.isservicecharge
              BULK COLLECT INTO t_origfeeid,
                   t_origamounts,
                   t_temp,
                   t_origpaymentids,
                   t_ptorigobjlist,
                   t_xlicensenumber,
                   t_xlicensetypecode,
                   t_srvflag
              FROM query.r_paymenttransfertrans r
                   JOIN query.o_paymenttransactions pt
                   ON pt.objectid = r.paymenttransactionobjectid
                   JOIN api.feetransactions ft
                   ON ft.transactionid = pt.transactionid
                   JOIN api.registeredexternalobjects reo  --TAyers: PIP Task 8.5
                   ON reo.linkvalue = TO_CHAR(pt.paymentid)
                  AND reo.objectdefid = t_paymentobjectdefid
             WHERE r.paymenttransferprocessid = a_objectid
               AND r.amount < 0;  -- edited this to be less the 0 since r.amount is now negative

            -- loop through the SRV rows and add FeeId information.
            FOR c1 IN 1 .. t_ptorigobjlist.COUNT
            LOOP
                pkg_refund.srvtransaction(a_objectid,
                                          t_origfeeid(c1),
                                          t_xlicensenumber(c1),
                                          t_xlicensetypecode(c1),
                                          t_var,
                                          t_ptfeeid,
                                          t_ptamounts,
                                          t_srvfeeids,
                                          t_srvamounts);

                --Set Payment Status Def Variables
                t_paymentstatusdefid   := api.pkg_objectdefquery.idforname('o_PaymentStatus');
                t_paymentstatusendpoint   :=
                    api.pkg_configquery.endpointidforname('o_PaymentTransactions', 'PaymentStatus');

                --if the amount being moved is equal to the amount of the original fee
                --Unearn the Original transaction IF the original had earned
                --and the original was earned
                --if api.pkg_columnquery.numericvalue(api.pkg_columnquery.numericvalue(t_PTOrigObjList(c1), 'FeeObjId'), 'Amount') = t_OrigAmounts(c1) * -1
                IF api.pkg_columnquery.numericvalue(t_ptorigobjlist(c1), 'PaymentAmount') = t_origamounts(c1) * -1
               AND api.pkg_columnquery.VALUE(
                       api.pkg_columnquery.numericvalue(t_ptorigobjlist(c1), 'PaymentStatusObjectId'),
                       'Status') =
                   'EARNED' THEN
                    --unearn the orginal
                    t_unearnamount         :=
                        -api.pkg_columnquery.VALUE(
                             api.pkg_columnquery.numericvalue(t_ptorigobjlist(c1), 'PaymentStatusObjectId'),
                             'EarnedAmount');
                    t_paymentstatusobjid   := api.pkg_objectupdate.new(t_paymentstatusdefid);
                    t_relid                :=
                        api.pkg_relationshipupdate.new(t_paymentstatusendpoint,
                                                       t_ptorigobjlist(c1),
                                                       t_paymentstatusobjid);
                    --set details
                    api.pkg_columnupdate.setvalue(t_paymentstatusobjid, 'Status', 'UNEARNED');
                    api.pkg_columnupdate.setvalue(t_paymentstatusobjid, 'StatusDate', TRUNC(SYSDATE));
                    api.pkg_columnupdate.setvalue(t_paymentstatusobjid, 'SystemGenerated', 'Y');
                    api.pkg_columnupdate.setvalue(t_paymentstatusobjid, 'EarnedAmount', t_unearnamount);
                -- unearn the reverse transaction that hasn't been created yet!
                ELSIF t_origamounts(c1) * -1 < api.pkg_columnquery.numericvalue(t_ptorigobjlist(c1), 'Amount')
                  AND api.pkg_columnquery.VALUE(
                          api.pkg_columnquery.numericvalue(t_ptorigobjlist(c1), 'PaymentStatusObjectId'),
                          'Status') =
                      'EARNED' THEN
                    --load an array of FeeObjId values to process on New Payment loop
                    --t_OrigFeeIds.extend;
                    t_origfeeids(
                        api.pkg_columnquery.numericvalue(
                            api.pkg_columnquery.numericvalue(t_ptorigobjlist(c1), 'FeeObjId'),
                            'FeeId'))   :=
                        api.pkg_columnquery.numericvalue(t_ptorigobjlist(c1), 'FeeObjId');
                END IF;
            END LOOP;

            --Original Payment Object Id
            t_origpaymentobjid                 := t_temp(1);

            --Create the SRV Fee
            IF t_srvamounts.COUNT > 0 THEN
                SELECT MAX(x.objectid)
                  INTO t_feescheduleid
                  FROM TABLE(
                           CAST(
                               api.pkg_simplesearch.castableobjectsbyindex('o_FeeSchedule', 'FeeActivity', 'SRV') AS api.udt_objectlist))
                       x
                 WHERE api.pkg_columnquery.datevalue(x.objectid, 'EffectiveDate') =
                       (SELECT MAX(effectivedate)
                          FROM sitespecific.feeschedule_t
                         WHERE feeactivity = 'SRV');

                SELECT SUM(
                           api.pkg_columnquery.numericvalue(ptrc.refundcheckitemobjectid,
                                                            'SRVAmountForDisplayOnPaymentTr'))
                  INTO t_srvfeeamount
                  FROM query.r_paymenttransferrefundcheckit ptrc
                 WHERE ptrc.paymenttransferobjectid = a_objectid;

                pkg_fees.newfee(t_newsrvfee,
                                t_srvfeeamount,
                                'SRV',
                                t_srvglaccountid,
                                api.pkg_columnquery.numericvalue(a_objectid, 'JobId'),
                                NULL,
                                t_newsrvfeeobjid);
                -- Relate Fee to Fee Schedule
                t_relid             :=
                    api.pkg_relationshipupdate.new(
                        api.pkg_configquery.endpointidforname('o_Fee', 'LicenseFeeSchedule'),
                        t_newsrvfeeobjid,
                        t_feescheduleid);

                FOR x IN 1 .. t_srvfeeids.COUNT
                LOOP
                    t_srvfeeids(x)   := t_newsrvfee;
                END LOOP;

                -- Create SRV Payment
                t_srvpaymentid      := api.pkg_paymentupdate.new(t_newpaymentsdate, t_srvfeeids, t_srvamounts);

                --Register SRV-Payment
                t_paymentobjectid   := api.pkg_objectupdate.registerexternalobject('o_Payment', t_srvpaymentid);

                -- LOG SRV PAYMENTTRANSFER??
                INSERT INTO sitespecific.paymenttransfers_t
                     VALUES (t_origpaymentobjid,
                             t_origpaymentids(1),
                             t_paymentobjectid,
                             t_srvpaymentid,
                             'Y');

                -- Set the income code for the SRV payment to 'C'
                api.pkg_columnupdate.setvalue(t_paymentobjectid, 'CABINIncomeInd', 'C');

                -- Set the DepositedDate of the transfered payment
                api.pkg_columnupdate.setvalue(t_paymentobjectid, 'DepositedDate', t_depositdate);

                -- For each Payment Transaction for the Payment that was just created, register the external Payment Transaction and Fee Transaction
                FOR c IN (SELECT pt.transactionid
                            FROM api.paymenttransactions pt
                           WHERE pt.paymentid = t_srvpaymentid)
                LOOP
                    t_paytransobjectid   :=
                        api.pkg_objectupdate.registerexternalobject('o_PaymentTransactions', c.transactionid);
                    t_transactionobjid   :=
                        api.pkg_objectupdate.registerexternalobject('o_FeeTransactions', c.transactionid);
                    -- Set the amount type for the SRV payment transactions to 'C'
                    api.pkg_columnupdate.setvalue(t_paytransobjectid, 'CABINAmtType', 'C');

                    --Set the HQ Receipt Number
                    api.pkg_columnupdate.setvalue(t_paytransobjectid, 'HQReceipt', t_hqreceipt);
                END LOOP;

                --Set Payment PaymentDateStored
                api.pkg_columnupdate.setvalue(t_paymentobjectid, 'PaymentDateStored', TRUNC(SYSDATE));

                --Set Payment PaymentAmountStored
                api.pkg_columnupdate.setvalue(t_paymentobjectid,
                                              'PaymentAmountStored',
                                              api.pkg_columnquery.VALUE(t_paymentobjectid, 'PaymentAmount'));
            END IF;

            --Adjust Payment off of original Fee.
            t_unpaymentid                      := api.pkg_paymentupdate.new(t_newpaymentsdate, t_origfeeid, t_origamounts);
            -- Process this payment
            pkg_fees.processnegativepayment(a_paymentid => t_unpaymentid);

            --Register Un-Payment
            t_paymentobjectid                  := api.pkg_objectupdate.registerexternalobject('o_Payment', t_unpaymentid);

            -- Set the income code for the payment to 'C'
            api.pkg_columnupdate.setvalue(t_paymentobjectid, 'CABINIncomeInd', 'C');

            -- Set the DepositedDate of the transfered payment
            api.pkg_columnupdate.setvalue(t_paymentobjectid, 'DepositedDate', t_depositdate);

            -- For each Payment Transaction for the Payment that was just created, register the external Payment Transaction and Fee Transaction
            FOR c IN (SELECT pt.transactionid, ft.feeid
                        FROM api.paymenttransactions pt
                             JOIN api.feetransactions ft
                             ON ft.transactionid = pt.transactionid
                       WHERE pt.paymentid = t_unpaymentid)
            LOOP
                t_paytransobjectid   :=
                    api.pkg_objectupdate.registerexternalobject('o_PaymentTransactions', c.transactionid);
                t_transactionobjid   :=
                    api.pkg_objectupdate.registerexternalobject('o_FeeTransactions', c.transactionid);
                -- Set the amount type for the payment transactions to 'C'
                api.pkg_columnupdate.setvalue(t_paytransobjectid, 'CABINAmtType', 'C');
                --Set the HQ Receipt Number
                api.pkg_columnupdate.setvalue(t_paytransobjectid, 'HQReceipt', t_hqreceipt);

                -- Set IsServiceCharge flag
                IF t_srvflag(1) = 'Y' THEN
                    api.pkg_columnupdate.setvalue(t_paytransobjectid, 'IsServiceCharge', 'Y');
                END IF;

                --check array of OrigFeeIds for existance in the array, if exists, UNEARN here.
                IF t_origfeeids.EXISTS(c.feeid) THEN
                    --unearn the transaction we just created
                    t_paymentstatusobjid   := api.pkg_objectupdate.new(t_paymentstatusdefid);
                    t_relid                :=
                        api.pkg_relationshipupdate.new(t_paymentstatusendpoint,
                                                       t_paytransobjectid,
                                                       t_paymentstatusobjid);
                    --set details
                    api.pkg_columnupdate.setvalue(t_paymentstatusobjid, 'Status', 'UNEARNED');
                    api.pkg_columnupdate.setvalue(t_paymentstatusobjid, 'StatusDate', TRUNC(SYSDATE));
                    api.pkg_columnupdate.setvalue(t_paymentstatusobjid, 'SystemGenerated', 'Y');
                END IF;
            END LOOP;

            --Set Payment PaymentDateStored
            api.pkg_columnupdate.setvalue(t_paymentobjectid, 'PaymentDateStored', TRUNC(SYSDATE));

            --Set Payment PaymentAmountStored
            api.pkg_columnupdate.setvalue(t_paymentobjectid,
                                          'PaymentAmountStored',
                                          api.pkg_columnquery.VALUE(t_paymentobjectid, 'PaymentAmount'));

            --Set all of the Fee Transactions' OVR value to 'N' where Amt to Pay is less then the balance.
            FOR o IN (SELECT r.relationshipid, r.amounttopay
                        FROM query.r_paymenttransferfee r
                             JOIN query.o_fee f
                             ON f.objectid = r.feeobjectid
                       WHERE r.paymenttransferprocessid = a_objectid
                         AND r.ovr = 'Y'
                         AND r.amounttopay <= f.totalowing)
            LOOP
                api.pkg_columnupdate.setvalue(o.relationshipid, 'OVR', 'N');
            END LOOP;

            --Get to FeeIds that should be calculated as OVRs
            SELECT f.feeid, r.amounttopay
              BULK COLLECT INTO t_tofeeisovr, t_payamountsovr
              FROM query.r_paymenttransferfee r
                   JOIN query.o_fee f
                   ON f.objectid = r.feeobjectid
             WHERE r.paymenttransferprocessid = a_objectid
               AND r.ovr = 'Y';

            --Create Overpayment records (for separate, flagged PaymentTransactions) if The OVR checkbox is checked and the OVR checkbox on the Payment transfer screen is checked
            sitespecific.pkg_fees.calculateoverpayment(t_tofeeisovr,
                                                       t_payamountsovr,
                                                       t_ovrtofeeid,
                                                       t_ovrpayamounts);

            --Get to FeeIds and Amounts to apply
            SELECT f.feeid, r.amounttopay
              BULK COLLECT INTO t_tofeeid, t_payamounts
              FROM query.r_paymenttransferfee r
                   JOIN query.o_fee f
                   ON f.objectid = r.feeobjectid
             WHERE r.paymenttransferprocessid = a_objectid
               AND r.ovr = 'N';

            --t_TofeeisOVR(t_TofeeisOVR.count + 1) := t_ToFeeId;
            --t_PayAmountsOVR(t_PayAmountsOVR.count + 1) := t_PayAmounts;
            FOR c IN 1 .. t_tofeeisovr.COUNT
            LOOP
                t_tofeeid(t_tofeeid.COUNT + 1)         := t_tofeeisovr(c);
                t_payamounts(t_payamounts.COUNT + 1)   := t_payamountsovr(c);
            END LOOP;

            --Create Payment for against to fee.
            t_paymentid                        := api.pkg_paymentupdate.new(t_newpaymentsdate, t_tofeeid, t_payamounts);

            --Register Payment
            t_paymentobjectid                  := api.pkg_objectupdate.registerexternalobject('o_Payment', t_paymentid);

            -- Log to PaymentTransfer table
            INSERT INTO sitespecific.paymenttransfers_t
                 VALUES (t_origpaymentobjid,
                         t_origpaymentids(1),
                         t_paymentobjectid,
                         t_paymentid,
                         'N');

            -- Set the amount type for the payment to 'C'
            api.pkg_columnupdate.setvalue(t_paymentobjectid, 'CABINIncomeInd', 'C');

            -- Set the DepositedDate of the transfered payment
            api.pkg_columnupdate.setvalue(t_paymentobjectid, 'DepositedDate', t_depositdate);

            -- For each fee that was paid, check if the job is a LT. If so, create and complete the Receive Payments process
            FOR p IN 1 .. t_tofeeid.COUNT
            LOOP
                SELECT f.jobid
                  INTO t_feejobid
                  FROM api.fees f
                 WHERE f.feeid = t_tofeeid(p);
            /* If api.pkg_ColumnQuery.Value(t_FeeJobId, 'ObjectDefName') = 'j_LicenseType' then

             t_ProcessId := api.pkg_ProcessUpdate.New(t_FeeJobId,
             api.pkg_ConfigQuery.ObjectDefIdForName('p_ReceivePayment'),
             null,
             sysdate,
             sysdate,
             sysdate);
             End If;*/
            END LOOP;

            -- For each Payment Transaction for the Payment that was just created, register the external Payment Transaction and Fee Transaction
            FOR c IN (SELECT pt.transactionid
                        FROM api.paymenttransactions pt
                       WHERE pt.paymentid = t_paymentid)
            LOOP
                t_paytransobjectid   :=
                    api.pkg_objectupdate.registerexternalobject('o_PaymentTransactions', c.transactionid);
                t_transactionobjid   :=
                    api.pkg_objectupdate.registerexternalobject('o_FeeTransactions', c.transactionid);
                -- Set the amount type for the payment transactions to 'C'
                api.pkg_columnupdate.setvalue(t_paytransobjectid, 'CABINAmtType', 'C');
                --Set the HQ Receipt Number
                api.pkg_columnupdate.setvalue(t_paytransobjectid, 'HQReceipt', t_hqreceipt);
            END LOOP;

            -- Add Payment Ids to collection for loop
            t_paymentids                       := api.udt_objectlist();
            t_paymentids.EXTEND(1);
            t_paymentids(t_paymentids.COUNT)   := api.udt_object(t_unpaymentid);

            t_paymentids.EXTEND(1);
            t_paymentids(t_paymentids.COUNT)   := api.udt_object(t_paymentid);

            IF t_srvpaymentid IS NOT NULL THEN
                t_paymentids.EXTEND(1);
                t_paymentids(t_paymentids.COUNT)   := api.udt_object(t_srvpaymentid);
            END IF;

            --Register Payment and Transaction Objects and set Payment details and rels.
            FOR w IN 1 .. t_paymentids.COUNT
            LOOP
                -- Get t_PaymentObjectId for the payment id
                SELECT reo.objectid
                  INTO t_paymentobjectid
                  FROM api.registeredexternalobjects reo  --TAyers: PIP Task 8.5
                 WHERE reo.linkvalue = TO_CHAR(t_paymentids(w).objectid)
                   AND reo.objectdefid = t_paymentobjectdefid;

                --TEst
                SELECT reo.objectid
                  BULK COLLECT INTO t_paytransobjectids
                  FROM api.paymenttransactions pt
                       JOIN api.registeredexternalobjects reo  --TAyers: PIP Task 8.5
                       ON reo.linkvalue = TO_CHAR(pt.transactionid)
                      AND reo.objectdefid = t_paytransobjectdefid
                 WHERE pt.paymentid = t_paymentids(w).objectid;

                --Copy Details from original Payment to created payment.
                --Get Details
                t_reference               := api.pkg_columnquery.VALUE(t_origpaymentobjid, 'PayeeReference');
                t_isreceipted             := api.pkg_columnquery.VALUE(t_origpaymentobjid, 'IsReceipted');

                SELECT r.paymentmethodobjectid
                  INTO t_methodid
                  FROM query.r_paymentpaymentmethod r
                 WHERE r.paymentobjectid = t_origpaymentobjid;

                t_receiptnumber           := api.pkg_columnquery.VALUE(t_origpaymentobjid, 'ReceiptNumber');
                t_batchpaymentid          := api.pkg_columnquery.VALUE(t_origpaymentobjid, 'BatchPaymentId');

                --Set Details, create rel.
                api.pkg_paymentupdate.modify(t_paymentids(w).objectid, t_reference, t_receiptnumber);
                api.pkg_columnupdate.setvalue(t_paymentobjectid, 'BatchPaymentId', t_batchpaymentid);
                api.pkg_columnupdate.setvalue(t_paymentobjectid, 'IsReceiptedStored', t_isreceipted);

                -- *************************************************************
                -- 12/28/2020 TJL W23630  Added following
                SELECT MAX(r.toobjectid)
                  INTO t_transmittalobjectid
                  FROM api.relationships r
                 WHERE r.endpointid = api.pkg_configquery.endpointidforname('o_payment', 'transmittal')
                   AND r.fromobjectid = t_origpaymentobjid;

                IF (t_transmittalobjectid IS NOT NULL) THEN
                    -- add new relationship                (endpointid, fromobjectid, toobjectid)
                    t_relid   :=
                        api.pkg_relationshipupdate.new(
                            api.pkg_configquery.endpointidforname('o_payment', 'transmittal'),
                            t_paymentobjectid,
                            t_transmittalobjectid);
                END IF;

                -- End
                -- **************************************************************

                t_relid                   :=
                    api.pkg_relationshipupdate.new(
                        api.pkg_configquery.endpointidforname('o_Payment', 'PaymentMethod'),
                        t_paymentobjectid,
                        t_methodid);

                --Create a relationship to the user's default office
                t_defaultofficeobjectid   :=
                    api.pkg_columnquery.VALUE(api.pkg_securityquery.effectiveuserid, 'DefaultOfficeObjectId');

                IF t_defaultofficeobjectid IS NULL THEN
                    api.pkg_errors.raiseerror(-20000, 'The User is not related to a Default Office.');
                END IF;

                t_relid                   :=
                    api.pkg_relationshipupdate.new(api.pkg_configquery.endpointidforname('o_Office', 'Payment'),
                                                   t_defaultofficeobjectid,
                                                   t_paymentobjectid);

                --Set stored detail (see ProcessProposedPayment for explanation)
                api.pkg_columnupdate.setvalue(t_paymentobjectid, 'PaymentDateStored', TRUNC(SYSDATE));

                --Set stored detail (see ProcessProposedPayment for explanation)
                api.pkg_columnupdate.setvalue(t_paymentobjectid,
                                              'PaymentAmountStored',
                                              api.pkg_columnquery.VALUE(t_paymentobjectid, 'PaymentAmount'));

                --Relate Payment to PaymentTransfer process using appropriate relationship (AdjustingFrom, To)
                --Also set Payment Statuses appropriately for first loop set ToPayment to earned
                --when feeschedule says it should be earned on payment.

                IF t_doneonce IS NULL  --means this is the loop for the PaymentAdjustingFrom
                                      --Create Rel to process for PaymentAdjustingFrom
                                      THEN
                    t_endpointid   :=
                        api.pkg_configquery.endpointidforname('p_PaymentTransfer', 'PaymentAdjustingFrom');
                    t_relid   := api.pkg_relationshipupdate.new(t_endpointid, a_objectid, t_paymentobjectid);

                    --Set the IsOverPayment on the Transactions to match previous transaction
                    FOR q IN 1 .. t_ptorigobjlist.COUNT
                    LOOP
                        --set details
                        api.pkg_columnupdate.setvalue(t_paytransobjectids(q),
                                                      'IsOverpayment',
                                                      api.pkg_columnquery.VALUE(t_ptorigobjlist(q), 'IsOverpayment'));
                    END LOOP;
                --Create rel to process for PaymentTo
                ELSE
                    t_endpointid   := api.pkg_configquery.endpointidforname('p_PaymentTransfer', 'PaymentTo');
                    t_relid        := api.pkg_relationshipupdate.new(t_endpointid, a_objectid, t_paymentobjectid);

                    --Earned Payment Immediately if it should be.
                    FOR m IN 1 .. t_tofeeid.COUNT
                    LOOP
                        SELECT COUNT(f.feeid)
                          INTO t_earnedonpay
                          FROM api.fees f
                               /* RyanL: PIP Task 8.5: Removed because this is not being used in the query
                               join table(cast(api.pkg_simplesearch.CastableObjectsByIndex('o_Fee', 'FeeId', f.feeid) as api.udt_objectlist)) x
                                 on 1 = 1*/
                               -- join api.relationships r on r.FromObjectId = x.ObjectId
                               -- and r.EndPointId = api.pkg_configquery.EndPointIdForName('o_Fee', 'LicenseFeeSchedule')
                               JOIN sitespecific.feeschedule_t fs
                               ON fs.objectid = sitespecific.pkg_fees.getlicfeeschedulobjid(f.feeid)
                         WHERE f.feeid = t_tofeeid(m)
                           AND api.pkg_columnquery.VALUE(fs.objectid, 'EarnedOn') = 'PAYMENT';

                        --and api.pkg_columnquery.Value(r.ToObjectId, 'EarnedOn') = 'PAYMENT'

                        --If Payment Transaction is overpayment, set flag to indicate it (used in Fees and Payments grid)
                        sitespecific.pkg_fees.setpaymenttransactionflag(t_ovrtofeeid,
                                                                        t_ovrpayamounts,
                                                                        'IsOverpayment');

                        --Create Payment Status for new payment if the fee's feeschedule is earned on payment.
                        IF t_earnedonpay > 0 THEN
                            -- RyanL: Changed the select clause to be a subselect for performance (PIP Task 8.5)
                            FOR v IN (SELECT reo.objectid,
                                             ft.amount,
                                             (  f.amount
                                              + NVL((SELECT SUM(amount)
                                                       FROM api.feetransactions ft
                                                      WHERE ft.feeid = f.feeid
                                                        AND ft.transactiontype = 'Adj'),
                                                    0))
                                                 feeamount,
                                             f.feeid
                                        FROM api.fees f
                                             JOIN api.feetransactions ft
                                             ON ft.feeid = f.feeid
                                             JOIN api.paymenttransactions ipt
                                             ON ipt.transactionid = ft.transactionid
                                             JOIN api.registeredexternalobjects reo  --TAyers: PIP Task 8.5
                                             ON reo.linkvalue = TO_CHAR(ipt.transactionid)
                                            AND reo.objectdefid = t_paytransobjectdefid
                                       WHERE f.feeid = t_tofeeid(m)
                                         AND ipt.paymentid = t_paymentids(w).objectid
                                         AND api.pkg_columnquery.VALUE(reo.objectid, 'IsOverpayment') = 'N')
                            LOOP
                                -- Get the summed earned amounts for this transaction
                                SELECT  /*+ CARDINALITY (pt 1) */
                                       NVL(
                                           ABS(
                                               SUM(
                                                   api.pkg_columnquery.numericvalue(r.paymentstatusobjectid,
                                                                                    'EarnedAmount'))),
                                           0)
                                  INTO t_earnedamount
                                  FROM api.feetransactions ft
                                       JOIN api.registeredexternalobjects reo  --TAyers: PIP Task 8.5
                                       ON reo.linkvalue = TO_CHAR(ft.transactionid)
                                      AND reo.objectdefid = t_paytransobjectdefid
                                       JOIN query.r_paymentstatuspaymenttrans r
                                       ON r.paymenttransactionobjectid = reo.objectid
                                 WHERE ft.feeid = v.feeid;

                                -- if there is an unearned amount for the fee
                                IF t_earnedamount < v.feeamount THEN
                                    --create object and rel
                                    t_paymentstatusobjid   := api.pkg_objectupdate.new(t_paymentstatusdefid);
                                    t_relid                :=
                                        api.pkg_relationshipupdate.new(t_paymentstatusendpoint,
                                                                       v.objectid,
                                                                       t_paymentstatusobjid);

                                    -- Get the correct amount to earn
                                    IF t_earnedamount - v.amount > v.feeamount THEN
                                        t_earnedamount   := -v.feeamount + t_earnedamount;
                                    ELSE
                                        t_earnedamount   := v.amount;
                                    END IF;

                                    --set details
                                    api.pkg_columnupdate.setvalue(t_paymentstatusobjid, 'Status', 'EARNED');
                                    api.pkg_columnupdate.setvalue(t_paymentstatusobjid, 'StatusDate', TRUNC(SYSDATE));
                                    api.pkg_columnupdate.setvalue(t_paymentstatusobjid, 'SystemGenerated', 'Y');
                                    api.pkg_columnupdate.setvalue(t_paymentstatusobjid,
                                                                  'EarnedAmount',
                                                                  t_earnedamount);
                                END IF;
                            END LOOP;
                        END IF;
                    END LOOP;
                END IF;

                t_doneonce                := 'Y';
            END LOOP;

            --Check the SRV charge flag on SRV Payment Transactions
            IF t_srvfeeids.COUNT > 0 THEN
                sitespecific.pkg_fees.setpaymenttransactionflag(t_srvfeeids, t_srvamounts, 'IsServiceCharge');
                -- Create Payment Statuses for all SRV values where the most recent SRV Fee Activity code is set to earn on payment.
                sitespecific.pkg_refund.earnsrvpaytrans(t_srvfeeids, t_srvamounts, TRUE);
            END IF;
        END IF;  --only run procedure when outcome is not null
    END transferpayment;

    ----------------------------------------------------------------------------------------------------
    -- FingerPrintFee() -- PUBLIC
    -- Charges fees when the Fingerprints column is changed.
    ----------------------------------------------------------------------------------------------------
    PROCEDURE fingerprintfee(a_objectid      udt_id,
                             a_asofdate      DATE,
                             a_fingerprints  NUMBER,
                             a_jobid         udt_id)
    IS
        t_description      VARCHAR2(100);
        t_feecorrect       VARCHAR2(1);
        t_feeamount        NUMBER;
        t_feescheduleid    udt_id;
        t_glaccountid      udt_id;
        t_feeid            udt_id;
        t_newfeeobjid      udt_id;
        t_relid            udt_id;
        t_transationid     udt_id;

        t_feeobjectdefid   udt_id := api.pkg_configquery.objectdefidforname('o_Fee');

        -- Array
        TYPE feeactivity IS VARRAY(100) OF VARCHAR2(3);

        t_feeactivity      feeactivity := feeactivity(1);
        t_index            INTEGER;
    BEGIN
        --include SFP
        t_index                  := 1;
        t_feeactivity(t_index)   := 'SFP';
        --include FFP
        t_index                  := t_index + 1;
        t_feeactivity.EXTEND;
        t_feeactivity(t_index)   := 'FFP';

        -- Find existing fees with the fee activity code above
        FOR c IN 1 .. t_feeactivity.COUNT
        LOOP
            -- FeeCorrect := 'N';
            t_feecorrect   := 'N';

            -- loop through existing Fees
            -- RyanL: Changed the select clause to be a subselect for performance (PIP Task 8.5)
            FOR x IN (SELECT  /*+ cardinality (reo 1) */
                             (  f.amount
                              + NVL((SELECT SUM(amount)
                                       FROM api.feetransactions ft
                                      WHERE ft.feeid = f.feeid),
                                    0))
                                 totalowing,
                             ffs.secondarycount
                                 secondarycount,
                             f.feeid,
                             ffs.relationshipid
                                 relid
                        FROM api.fees f
                             JOIN api.registeredexternalobjects reo  -- RyanL: PIP Task 8.5
                             ON reo.linkvalue = TO_CHAR(f.feeid)
                            AND reo.objectdefid = t_feeobjectdefid
                             JOIN query.r_feelicensefeeschedule ffs
                             ON ffs.feeobjectid = reo.objectid
                             JOIN sitespecific.feeschedule_t fs
                             ON fs.objectid = ffs.licensefeescheduleid
                       WHERE f.jobid = a_jobid
                         AND fs.feeactivity = t_feeactivity(c)
                         AND f.feeid = (SELECT MAX(f.feeid)
                                          FROM api.fees f
                                               JOIN sitespecific.feeschedule_t fs
                                               ON fs.objectid = sitespecific.pkg_fees.getlicfeeschedulobjid(f.feeid)
                                         WHERE f.jobid = a_jobid
                                           AND fs.feeactivity = t_feeactivity(c))
                         AND NOT EXISTS
                                 (SELECT 1
                                    FROM query.r_modifyfeefee r
                                         JOIN query.p_modifyfee m
                                         ON m.objectid = r.modifyfeeprocessid
                                   WHERE r.feeobjectid = reo.objectid
                                     AND m.outcome IS NOT NULL
                                     AND m.modifytype = 'Void Fee'))
            LOOP
                -- Check to see if it needs adjusting
                -- if x.SecondaryCount <> a_FingerPrints then
                IF x.secondarycount <> a_fingerprints THEN
                    -- get Fee Amounts
                    sitespecific.pkg_fees.getltfeeamount(a_jobid,
                                                         SYSDATE,
                                                         t_feeactivity(c),
                                                         NULL,
                                                         NULL,  -- the LT should not Apply
                                                         NULL,
                                                         NULL,
                                                         NULL,
                                                         NULL,
                                                         'S',
                                                         a_fingerprints,
                                                         a_asofdate,
                                                         t_feeamount,
                                                         t_feescheduleid);

                    -- If the Amount is null then raise error.
                    IF t_feeamount < 0
                   AND a_fingerprints <> 0 THEN
                        api.pkg_errors.raiseerror(-20000,
                                                     'There is no currently effective '
                                                  || t_feeactivity(c)
                                                  || ' License Fee Schedule'
                                                  || ' that has the necessary amount information.');
                    END IF;

                    IF x.totalowing <> t_feeamount THEN
                        --Get PrimaryLT Description
                        SELECT f.proceduredescription
                          INTO t_description
                          FROM query.o_feeschedule f
                         WHERE f.objectid = t_feescheduleid;

                        --Adjust fee
                        t_transationid   :=
                            api.pkg_feeupdate.adjust(x.feeid,
                                                     ROUND(t_feeamount - x.totalowing),
                                                     t_description,
                                                     SYSDATE);

                        -- Change SecondaryCount to the Correct Value
                        api.pkg_columnupdate.setvalue(x.relid, 'SecondaryCount', a_fingerprints);
                    END IF;
                -- end if;
                END IF;

                -- if the Procedure looped through this section then the Fee is now correct
                t_feecorrect   := 'Y';
            END LOOP;  -- Existing Fee Loop

            --If t_FeeCorrect is incorrect (ie. 'N') then
            IF t_feecorrect = 'N'
           AND a_fingerprints > 0 THEN
                --Get GLAccountId
                SELECT g.glaccountid
                  INTO t_glaccountid
                  FROM api.glaccounts g
                 WHERE g.glaccount = t_feeactivity(c);

                --TODO? Raise error when GL Account is not found, should I do this?

                --Get Fee Amount
                sitespecific.pkg_fees.getltfeeamount(a_jobid,
                                                     SYSDATE,
                                                     t_feeactivity(c),
                                                     NULL,
                                                     NULL,  --LT Code is Null
                                                     NULL,
                                                     NULL,
                                                     NULL,
                                                     NULL,
                                                     'S',
                                                     a_fingerprints,
                                                     a_asofdate,
                                                     t_feeamount,
                                                     t_feescheduleid);

                IF t_feeamount >= 0 THEN
                    --Get PrimaryLT Description
                    SELECT f.proceduredescription
                      INTO t_description
                      FROM query.o_feeschedule f
                     WHERE f.objectid = t_feescheduleid;

                    --Create Fee.
                    sitespecific.pkg_fees.newfee(t_feeid,
                                                 t_feeamount,
                                                 t_description,
                                                 t_glaccountid,
                                                 a_jobid,
                                                 NULL,
                                                 t_newfeeobjid);

                    -- Relate Fee to Fee Schedule
                    t_relid   :=
                        api.pkg_relationshipupdate.new(
                            api.pkg_configquery.endpointidforname('o_Fee', 'LicenseFeeSchedule'),
                            t_newfeeobjid,
                            t_feescheduleid);

                    -- Set the relationship detail SecondaryCount to the count of secondary LTs
                    api.pkg_columnupdate.setvalue(t_relid, 'SecondaryCount', a_fingerprints);
                ELSE
                    api.pkg_errors.raiseerror(-20000,
                                                 'There is no currently effective '
                                              || t_feeactivity(c)
                                              || ' License Fee Schedule'
                                              || ' that has the necessary amount information.');
                END IF;
            --end if;
            END IF;
        END LOOP;  --Activity Loop
    END fingerprintfee;

    --*------------------------------------------------------------------------------------------------
    --* GetFeesForJob() -- PUBLIC
    --* This procedure is for a procedural relationship that will relate Fees that are already related
    --* to this job (app or lic) and also relate the fees that are related to the related LT(s) and
    --* the other job, whatever that may be, App or Lic. It will also get the Fees from the related
    --* Accusation(s) and Investigation(s).
    --*------------------------------------------------------------------------------------------------
    PROCEDURE getfeesforjob(a_objectid udt_id, a_endpointid udt_id, a_relatedobjectids OUT api.udt_objectlist)
    IS
        t_jobtypename                VARCHAR2(25);
        t_jobtypeid                  udt_id;
        t_feeobjectdefid             udt_id;
        t_applicenseendpointid       udt_id;
        t_licenseappendpointid       udt_id;
        t_licenselictypeendpointid   udt_id;
        t_licenseinvendpointid       udt_id;
        t_invaccusationendpointid    udt_id;
    BEGIN
        a_relatedobjectids           := api.udt_objectlist();

        SELECT od.name
          INTO t_jobtypename
          FROM api.objects o
               JOIN api.objectdefs od
               ON od.objectdefid = o.objectdefid
         WHERE o.objectid = a_objectid;

        t_jobtypeid                  := api.pkg_configquery.objectdefidforname(t_jobtypename);
        t_feeobjectdefid             := api.pkg_configquery.objectdefidforname('o_Fee');
        t_applicenseendpointid       := api.pkg_configquery.endpointidforname('j_Application', 'License');
        t_licenseappendpointid       := api.pkg_configquery.endpointidforname('j_License', 'ApplicationLicense');
        t_licenselictypeendpointid   := api.pkg_configquery.endpointidforname('j_License', 'LicenseType');
        t_licenseinvendpointid       := api.pkg_configquery.endpointidforname('j_License', 'Investigation');
        t_invaccusationendpointid    := api.pkg_configquery.endpointidforname('j_Investigation', 'Accusation');

        --starting from job that I am on, get the Fees related to it.
        FOR a IN (SELECT reo.objectid
                    FROM api.fees f
                         JOIN api.registeredexternalobjects reo
                         ON reo.linkvalue = TO_CHAR(f.feeid)
                        AND reo.objectdefid = t_feeobjectdefid
                   WHERE f.jobid = a_objectid)
        LOOP
            a_relatedobjectids.EXTEND(1);
            a_relatedobjectids(a_relatedobjectids.COUNT)   := api.udt_object(a.objectid);
        END LOOP;

        --if it is an app then get the Fees by walking through the rels for the app
        IF t_jobtypeid = api.pkg_configquery.objectdefidforname('j_Application') THEN
            --starting from App get License fees
            FOR l IN (SELECT reo.objectid
                        FROM api.relationships r
                             JOIN api.fees f
                             ON f.jobid = r.toobjectid
                             JOIN api.registeredexternalobjects reo
                             ON reo.linkvalue = TO_CHAR(f.feeid)
                            AND reo.objectdefid = t_feeobjectdefid
                       WHERE r.fromobjectid = a_objectid
                         AND r.endpointid = t_applicenseendpointid)
            LOOP
                a_relatedobjectids.EXTEND(1);
                a_relatedobjectids(a_relatedobjectids.COUNT)   := api.udt_object(l.objectid);
            END LOOP;

            --starting from App get LicenseType fees through License
            FOR lt IN (SELECT reo.objectid
                         FROM api.relationships r1
                              JOIN api.relationships r2
                              ON r2.fromobjectid = r1.toobjectid
                             AND r2.endpointid = t_licenselictypeendpointid
                              JOIN api.fees f
                              ON f.jobid = r2.toobjectid
                              JOIN api.registeredexternalobjects reo
                              ON reo.linkvalue = TO_CHAR(f.feeid)
                             AND reo.objectdefid = t_feeobjectdefid
                        WHERE r1.fromobjectid = a_objectid
                          AND r1.endpointid = t_applicenseendpointid)
            LOOP
                a_relatedobjectids.EXTEND(1);
                a_relatedobjectids(a_relatedobjectids.COUNT)   := api.udt_object(lt.objectid);
            END LOOP;

            --starting from app get Investigation fees through the license.
            FOR ai IN (SELECT reo.objectid
                         FROM api.relationships r1
                              JOIN api.relationships r2
                              ON r2.fromobjectid = r1.toobjectid
                             AND r2.endpointid = t_licenseinvendpointid
                              JOIN api.fees f
                              ON f.jobid = r2.toobjectid
                              JOIN api.registeredexternalobjects reo
                              ON reo.linkvalue = TO_CHAR(f.feeid)
                             AND reo.objectdefid = t_feeobjectdefid
                        WHERE r1.fromobjectid = a_objectid
                          AND r1.endpointid = t_applicenseendpointid)
            LOOP
                a_relatedobjectids.EXTEND(1);
                a_relatedobjectids(a_relatedobjectids.COUNT)   := api.udt_object(ai.objectid);
            END LOOP;

            --starting from app get Accusation Fees through Investigation through License
            FOR aa IN (SELECT reo.objectid
                         FROM api.relationships r1
                              JOIN api.relationships r2
                              ON r2.fromobjectid = r1.toobjectid
                             AND r2.endpointid = t_licenseinvendpointid
                              JOIN api.relationships r3
                              ON r3.fromobjectid = r2.toobjectid
                             AND r3.endpointid = t_invaccusationendpointid
                              JOIN api.fees f
                              ON f.jobid = r3.toobjectid
                              JOIN api.registeredexternalobjects reo
                              ON reo.linkvalue = TO_CHAR(f.feeid)
                             AND reo.objectdefid = t_feeobjectdefid
                        WHERE r1.fromobjectid = a_objectid
                          AND r1.endpointid = t_applicenseendpointid)
            LOOP
                a_relatedobjectids.EXTEND(1);
                a_relatedobjectids(a_relatedobjectids.COUNT)   := api.udt_object(aa.objectid);
            END LOOP;
        ELSIF t_jobtypeid = api.pkg_configquery.objectdefidforname('j_License') THEN
            --it is a License and get the fees through the rels from the license
            --Starting from License get Application Fees
            FOR a IN (SELECT reo.objectid
                        FROM api.relationships r
                             JOIN api.fees f
                             ON f.jobid = r.toobjectid
                             JOIN api.registeredexternalobjects reo
                             ON reo.linkvalue = TO_CHAR(f.feeid)
                            AND reo.objectdefid = t_feeobjectdefid
                       WHERE r.fromobjectid = a_objectid
                         AND r.endpointid = t_licenseappendpointid)
            LOOP
                a_relatedobjectids.EXTEND(1);
                a_relatedobjectids(a_relatedobjectids.COUNT)   := api.udt_object(a.objectid);
            END LOOP;

            --starting from License get LicenseType Fees
            FOR lt IN (SELECT reo.objectid
                         FROM api.relationships r
                              JOIN api.fees f
                              ON f.jobid = r.toobjectid
                              JOIN api.registeredexternalobjects reo
                              ON reo.linkvalue = TO_CHAR(f.feeid)
                             AND reo.objectdefid = t_feeobjectdefid
                        WHERE r.fromobjectid = a_objectid
                          AND r.endpointid = t_licenselictypeendpointid)
            LOOP
                a_relatedobjectids.EXTEND(1);
                a_relatedobjectids(a_relatedobjectids.COUNT)   := api.udt_object(lt.objectid);
            END LOOP;

            --starting from lic get inv fees
            FOR li IN (SELECT reo.objectid
                         FROM api.relationships r1
                              JOIN api.fees f
                              ON f.jobid = r1.toobjectid
                              JOIN api.registeredexternalobjects reo
                              ON reo.linkvalue = TO_CHAR(f.feeid)
                             AND reo.objectdefid = t_feeobjectdefid
                        WHERE r1.fromobjectid = a_objectid
                          AND r1.endpointid = t_licenseinvendpointid)
            LOOP
                a_relatedobjectids.EXTEND(1);
                a_relatedobjectids(a_relatedobjectids.COUNT)   := api.udt_object(li.objectid);
            END LOOP;

            --starting from lic get acc fees through inv
            FOR la IN (SELECT reo.objectid
                         FROM api.relationships r1
                              JOIN api.relationships r2
                              ON r2.fromobjectid = r1.toobjectid
                             AND r2.endpointid = t_invaccusationendpointid
                              JOIN api.fees f
                              ON f.jobid = r2.toobjectid
                              JOIN api.registeredexternalobjects reo
                              ON reo.linkvalue = TO_CHAR(f.feeid)
                             AND reo.objectdefid = t_feeobjectdefid
                        WHERE r1.fromobjectid = a_objectid
                          AND r1.endpointid = t_licenseinvendpointid)
            LOOP
                a_relatedobjectids.EXTEND(1);
                a_relatedobjectids(a_relatedobjectids.COUNT)   := api.udt_object(la.objectid);
            END LOOP;
        END IF;
    END getfeesforjob;

    --*------------------------------------------------------------------------------------------------
    --* GetLicenseFSFeesForJob() -- PUBLIC
    --* This procedure is for a procedural relationship that will relate License Fee Schedule Fees
    --* (not Misc Fee Schedule fees) that are already related to this job (app or lic) and also relate
    --* the fees that are related to the related LT(s) and the other job, whatever that may be, App or
    --* Lic. It will also get the Fees from the related Accusation(s) and Investigation(s).
    --*------------------------------------------------------------------------------------------------
    PROCEDURE getlicensefsfeesforjob(a_objectid         udt_id,
                                     a_endpointid       udt_id,
                                     a_relatedobjectids OUT api.udt_objectlist)
    IS
        t_jobtypename                VARCHAR2(25);
        t_jobtypeid                  udt_id;
        t_feeobjectdefid             udt_id;
        t_applicenseendpointid       udt_id;
        t_licenseappendpointid       udt_id;
        t_licenselictypeendpointid   udt_id;
        t_licenseinvendpointid       udt_id;
        t_invaccusationendpointid    udt_id;
    BEGIN
        a_relatedobjectids           := api.udt_objectlist();

        SELECT od.name
          INTO t_jobtypename
          FROM api.objects o
               JOIN api.objectdefs od
               ON od.objectdefid = o.objectdefid
         WHERE o.objectid = a_objectid;

        t_jobtypeid                  := api.pkg_configquery.objectdefidforname(t_jobtypename);
        t_feeobjectdefid             := api.pkg_configquery.objectdefidforname('o_Fee');
        t_applicenseendpointid       := api.pkg_configquery.endpointidforname('j_Application', 'License');
        t_licenseappendpointid       := api.pkg_configquery.endpointidforname('j_License', 'ApplicationLicense');
        t_licenselictypeendpointid   := api.pkg_configquery.endpointidforname('j_License', 'LicenseType');
        t_licenseinvendpointid       := api.pkg_configquery.endpointidforname('j_License', 'Investigation');
        t_invaccusationendpointid    := api.pkg_configquery.endpointidforname('j_Investigation', 'Accusation');

        --starting from job that I am on, get the Fees related to it.
        FOR a IN (SELECT reo.objectid objectid
                    FROM api.fees f
                         JOIN api.registeredexternalobjects reo
                         ON reo.linkvalue = TO_CHAR(f.feeid)
                        AND reo.objectdefid = t_feeobjectdefid
                         JOIN query.r_feelicensefeeschedule flfs
                         ON flfs.feeobjectid = reo.objectid
                   WHERE f.jobid = a_objectid)
        LOOP
            a_relatedobjectids.EXTEND(1);
            a_relatedobjectids(a_relatedobjectids.COUNT)   := api.udt_object(a.objectid);
        END LOOP;

        --if it is an app then get the Fees by walking through the rels for the app
        IF t_jobtypeid = api.pkg_configquery.objectdefidforname('j_Application') THEN
            --staring from App get License Fees
            FOR l IN (SELECT reo.objectid
                        FROM api.relationships r
                             JOIN api.fees f
                             ON f.jobid = r.toobjectid
                             JOIN api.registeredexternalobjects reo
                             ON reo.linkvalue = TO_CHAR(f.feeid)
                            AND reo.objectdefid = t_feeobjectdefid
                             JOIN query.r_feelicensefeeschedule flfs
                             ON flfs.feeobjectid = reo.objectid
                       WHERE r.fromobjectid = a_objectid
                         AND r.endpointid = t_applicenseendpointid)
            LOOP
                a_relatedobjectids.EXTEND(1);
                a_relatedobjectids(a_relatedobjectids.COUNT)   := api.udt_object(l.objectid);
            END LOOP;

            --starting from App get LicenseType fees through License
            FOR lt IN (SELECT reo.objectid
                         FROM api.relationships r1
                              JOIN api.relationships r2
                              ON r2.fromobjectid = r1.toobjectid
                             AND r2.endpointid = t_licenselictypeendpointid
                              JOIN api.fees f
                              ON f.jobid = r2.toobjectid
                              JOIN api.registeredexternalobjects reo
                              ON reo.linkvalue = TO_CHAR(f.feeid)
                             AND reo.objectdefid = t_feeobjectdefid
                              JOIN query.r_feelicensefeeschedule flfs
                              ON flfs.feeobjectid = reo.objectid
                        WHERE r1.fromobjectid = a_objectid
                          AND r1.endpointid = t_applicenseendpointid)
            LOOP
                a_relatedobjectids.EXTEND(1);
                a_relatedobjectids(a_relatedobjectids.COUNT)   := api.udt_object(lt.objectid);
            END LOOP;

            --starting from app get Investigation fees through the license.
            FOR ai IN (SELECT reo.objectid
                         FROM api.relationships r1
                              JOIN api.relationships r2
                              ON r2.fromobjectid = r1.toobjectid
                             AND r2.endpointid = t_licenseinvendpointid
                              JOIN api.fees f
                              ON f.jobid = r2.toobjectid
                              JOIN api.registeredexternalobjects reo
                              ON reo.linkvalue = TO_CHAR(f.feeid)
                             AND reo.objectdefid = t_feeobjectdefid
                              JOIN query.r_feelicensefeeschedule flfs
                              ON flfs.feeobjectid = reo.objectid
                        WHERE r1.fromobjectid = a_objectid
                          AND r1.endpointid = t_applicenseendpointid)
            LOOP
                a_relatedobjectids.EXTEND(1);
                a_relatedobjectids(a_relatedobjectids.COUNT)   := api.udt_object(ai.objectid);
            END LOOP;
        --starting from app get Accusation Fees through Investigation through License
        -- 04/15/2018 TJL WO 17497 SLOWNESS WHEN ISSUING STK/MBR TRANSFERS
        --            FOR aa
        --                IN (SELECT reo.objectid
        --                      FROM api.relationships  r1
        --                           JOIN api.relationships r2
        --                               ON r2.fromobjectid = r1.toobjectid
        --                              AND r2.endpointid = t_licenseinvendpointid
        --                           JOIN api.relationships r3
        --                               ON r3.fromobjectid = r2.toobjectid
        --                              AND r3.endpointid =
        --                                  t_invaccusationendpointid
        --                           JOIN api.fees f ON f.jobid = r3.toobjectid
        --                           JOIN api.registeredexternalobjects reo
        --                               ON reo.linkvalue = TO_CHAR(f.feeid)
        --                              AND reo.objectdefid = t_feeobjectdefid
        --                           JOIN query.r_feelicensefeeschedule flfs
        --                               ON flfs.feeobjectid = reo.objectid
        --                     WHERE r1.fromobjectid = a_objectid
        --                       AND r1.endpointid = t_applicenseendpointid)
        --            LOOP
        --                a_relatedobjectids.EXTEND(1);
        --                a_relatedobjectids(a_relatedobjectids.COUNT)   :=
        --                    api.udt_object(aa.objectid);
        --            END LOOP;
        ELSIF t_jobtypeid = api.pkg_configquery.objectdefidforname('j_License') THEN
            --it is a License and get the fees through the rels from the license
            --Starting from License get Application Fees
            FOR a IN (SELECT reo.objectid
                        FROM api.relationships r
                             JOIN api.fees f
                             ON f.jobid = r.toobjectid
                             JOIN api.registeredexternalobjects reo
                             ON reo.linkvalue = TO_CHAR(f.feeid)
                            AND reo.objectdefid = t_feeobjectdefid
                             JOIN query.r_feelicensefeeschedule flfs
                             ON flfs.feeobjectid = reo.objectid
                       WHERE r.fromobjectid = a_objectid
                         AND r.endpointid = t_licenseappendpointid)
            LOOP
                a_relatedobjectids.EXTEND(1);
                a_relatedobjectids(a_relatedobjectids.COUNT)   := api.udt_object(a.objectid);
            END LOOP;

            --starting from License get LicenseType Fees
            FOR lt IN (SELECT reo.objectid
                         FROM api.relationships r
                              JOIN api.fees f
                              ON f.jobid = r.toobjectid
                              JOIN api.registeredexternalobjects reo
                              ON reo.linkvalue = TO_CHAR(f.feeid)
                             AND reo.objectdefid = t_feeobjectdefid
                              JOIN query.r_feelicensefeeschedule flfs
                              ON flfs.feeobjectid = reo.objectid
                        WHERE r.fromobjectid = a_objectid
                          AND r.endpointid = t_licenselictypeendpointid)
            LOOP
                a_relatedobjectids.EXTEND(1);
                a_relatedobjectids(a_relatedobjectids.COUNT)   := api.udt_object(lt.objectid);
            END LOOP;

            --starting from license get investigation fees
            FOR li IN (SELECT reo.objectid
                         FROM api.relationships r1
                              JOIN api.fees f
                              ON f.jobid = r1.toobjectid
                              JOIN api.registeredexternalobjects reo
                              ON reo.linkvalue = TO_CHAR(f.feeid)
                             AND reo.objectdefid = t_feeobjectdefid
                              JOIN query.r_feelicensefeeschedule flfs
                              ON flfs.feeobjectid = reo.objectid
                        WHERE r1.fromobjectid = a_objectid
                          AND r1.endpointid = t_licenseinvendpointid)
            LOOP
                a_relatedobjectids.EXTEND(1);
                a_relatedobjectids(a_relatedobjectids.COUNT)   := api.udt_object(li.objectid);
            END LOOP;

            --starting from license get Accusation Fees through Investigation
            FOR la IN (SELECT reo.objectid
                         FROM api.relationships r1
                              JOIN api.relationships r2
                              ON r2.fromobjectid = r1.toobjectid
                             AND r2.endpointid = t_invaccusationendpointid
                              JOIN api.fees f
                              ON f.jobid = r2.toobjectid
                              JOIN api.registeredexternalobjects reo
                              ON reo.linkvalue = TO_CHAR(f.feeid)
                             AND reo.objectdefid = t_feeobjectdefid
                              JOIN query.r_feelicensefeeschedule flfs
                              ON flfs.feeobjectid = reo.objectid
                        WHERE r1.fromobjectid = a_objectid
                          AND r1.endpointid = t_licenseinvendpointid)
            LOOP
                a_relatedobjectids.EXTEND(1);
                a_relatedobjectids(a_relatedobjectids.COUNT)   := api.udt_object(la.objectid);
            END LOOP;
        END IF;
    END getlicensefsfeesforjob;

    --*------------------------------------------------------------------------------------------------
    --* GetPaymentTransactionsForJob() -- PUBLIC
    --* This procedure is for a procedural relationship that will relate Payment Transactions that are
    --* already related to this job (app or lic) and also relate the PTs that are related to the
    --* related LT(s) and the other job, whatever that may be, App or Lic. It will also get the PTs
    --* from the related Accusation(s) and Investigation(s).
    --*------------------------------------------------------------------------------------------------
    PROCEDURE getpaymenttransactionsforjob(a_objectid         udt_id,
                                           a_endpointid       udt_id,
                                           a_relatedobjectids OUT api.udt_objectlist)
    IS
        t_jobtypename                VARCHAR2(25);
        t_jobtypeid                  udt_id;
        t_paymenttransobjectdefid    udt_id;
        t_applicenseendpointid       udt_id;
        t_licenseappendpointid       udt_id;
        t_licenselictypeendpointid   udt_id;
        t_licenseinvendpointid       udt_id;
        t_invaccusationendpointid    udt_id;
    BEGIN
        a_relatedobjectids           := api.udt_objectlist();

        SELECT od.name
          INTO t_jobtypename
          FROM api.objects o
               JOIN api.objectdefs od
               ON od.objectdefid = o.objectdefid
         WHERE o.objectid = a_objectid;

        t_jobtypeid                  := api.pkg_configquery.objectdefidforname(t_jobtypename);
        t_paymenttransobjectdefid    := api.pkg_configquery.objectdefidforname('o_PaymentTransactions');
        t_applicenseendpointid       := api.pkg_configquery.endpointidforname('j_Application', 'License');
        t_licenseappendpointid       := api.pkg_configquery.endpointidforname('j_License', 'ApplicationLicense');
        t_licenselictypeendpointid   := api.pkg_configquery.endpointidforname('j_License', 'LicenseType');
        t_licenseinvendpointid       := api.pkg_configquery.endpointidforname('j_License', 'Investigation');
        t_invaccusationendpointid    := api.pkg_configquery.endpointidforname('j_Investigation', 'Accusation');

        --starting from job that I am on, get the PTs related to it.
        FOR a IN (SELECT reo.objectid
                    FROM api.fees f
                         JOIN api.feetransactions ft
                         ON ft.feeid = f.feeid
                         JOIN api.registeredexternalobjects reo
                         ON reo.linkvalue = TO_CHAR(ft.transactionid)
                        AND reo.objectdefid = t_paymenttransobjectdefid
                   WHERE f.jobid = a_objectid)
        LOOP
            a_relatedobjectids.EXTEND(1);
            a_relatedobjectids(a_relatedobjectids.COUNT)   := api.udt_object(a.objectid);
        END LOOP;

        --if it is an app then get the PaymentTransactions by walking through the rels for the app
        IF t_jobtypeid = api.pkg_configquery.objectdefidforname('j_Application') THEN
            --starting from App get License PaymentTransactions
            FOR l IN (SELECT reo.objectid
                        FROM api.relationships r
                             JOIN api.fees f
                             ON f.jobid = r.toobjectid
                             JOIN api.feetransactions ft
                             ON ft.feeid = f.feeid
                             JOIN api.registeredexternalobjects reo
                             ON reo.linkvalue = TO_CHAR(ft.transactionid)
                            AND reo.objectdefid = t_paymenttransobjectdefid
                       WHERE r.fromobjectid = a_objectid
                         AND r.endpointid = t_applicenseendpointid)
            LOOP
                a_relatedobjectids.EXTEND(1);
                a_relatedobjectids(a_relatedobjectids.COUNT)   := api.udt_object(l.objectid);
            END LOOP;

            --starting from App get LicenseType PaymentTranactionss through License
            FOR lt IN (SELECT reo.objectid
                         FROM api.relationships r1
                              JOIN api.relationships r2
                              ON r2.fromobjectid = r1.toobjectid
                             AND r2.endpointid = t_licenselictypeendpointid
                              JOIN api.fees f
                              ON f.jobid = r2.toobjectid
                              JOIN api.feetransactions ft
                              ON ft.feeid = f.feeid
                              JOIN api.registeredexternalobjects reo
                              ON reo.linkvalue = TO_CHAR(ft.transactionid)
                             AND reo.objectdefid = t_paymenttransobjectdefid
                        WHERE r1.fromobjectid = a_objectid
                          AND r1.endpointid = t_applicenseendpointid)
            LOOP
                a_relatedobjectids.EXTEND(1);
                a_relatedobjectids(a_relatedobjectids.COUNT)   := api.udt_object(lt.objectid);
            END LOOP;

            --starting from app get Investigation PaymentTransactions through the license.
            FOR ai IN (SELECT reo.objectid
                         FROM api.relationships r1
                              JOIN api.relationships r2
                              ON r2.fromobjectid = r1.toobjectid
                             AND r2.endpointid = t_licenseinvendpointid
                              JOIN api.fees f
                              ON f.jobid = r2.toobjectid
                              JOIN api.feetransactions ft
                              ON ft.feeid = f.feeid
                              JOIN api.registeredexternalobjects reo
                              ON reo.linkvalue = TO_CHAR(ft.transactionid)
                             AND reo.objectdefid = t_paymenttransobjectdefid
                        WHERE r1.fromobjectid = a_objectid
                          AND r1.endpointid = t_applicenseendpointid)
            LOOP
                a_relatedobjectids.EXTEND(1);
                a_relatedobjectids(a_relatedobjectids.COUNT)   := api.udt_object(ai.objectid);
            END LOOP;

            --starting from App get Accusation PaymentTransactionsthrough Investigation and License
            FOR aa IN (SELECT reo.objectid
                         FROM api.relationships r1
                              JOIN api.relationships r2
                              ON r2.fromobjectid = r1.toobjectid
                             AND r2.endpointid = t_licenseinvendpointid
                              JOIN api.relationships r3
                              ON r3.fromobjectid = r2.toobjectid
                             AND r3.endpointid = t_invaccusationendpointid
                              JOIN api.fees f
                              ON f.jobid = r3.toobjectid
                              JOIN api.feetransactions ft
                              ON ft.feeid = f.feeid
                              JOIN api.registeredexternalobjects reo
                              ON reo.linkvalue = TO_CHAR(ft.transactionid)
                             AND reo.objectdefid = t_paymenttransobjectdefid
                        WHERE r1.fromobjectid = a_objectid
                          AND r1.endpointid = t_applicenseendpointid)
            LOOP
                a_relatedobjectids.EXTEND(1);
                a_relatedobjectids(a_relatedobjectids.COUNT)   := api.udt_object(aa.objectid);
            END LOOP;
        ELSIF t_jobtypeid = api.pkg_configquery.objectdefidforname('j_License') THEN
            --it is a license and walk through rels from license
            --Starting from License get Application Fees
            FOR a IN (SELECT reo.objectid
                        FROM api.relationships r
                             JOIN api.fees f
                             ON f.jobid = r.toobjectid
                             JOIN api.feetransactions ft
                             ON ft.feeid = f.feeid
                             JOIN api.registeredexternalobjects reo
                             ON reo.linkvalue = TO_CHAR(ft.transactionid)
                            AND reo.objectdefid = t_paymenttransobjectdefid
                       WHERE r.fromobjectid = a_objectid
                         AND r.endpointid = t_licenseappendpointid)
            LOOP
                a_relatedobjectids.EXTEND(1);
                a_relatedobjectids(a_relatedobjectids.COUNT)   := api.udt_object(a.objectid);
            END LOOP;

            --starting from License get LicenseType PaymentTransactions
            FOR lt IN (SELECT reo.objectid
                         FROM api.relationships r
                              JOIN api.fees f
                              ON f.jobid = r.toobjectid
                              JOIN api.feetransactions ft
                              ON ft.feeid = f.feeid
                              JOIN api.registeredexternalobjects reo
                              ON reo.linkvalue = TO_CHAR(ft.transactionid)
                             AND reo.objectdefid = t_paymenttransobjectdefid
                        WHERE r.fromobjectid = a_objectid
                          AND r.endpointid = t_licenselictypeendpointid)
            LOOP
                a_relatedobjectids.EXTEND(1);
                a_relatedobjectids(a_relatedobjectids.COUNT)   := api.udt_object(lt.objectid);
            END LOOP;

            --starting from License get Investigation PaymentTransacctions
            FOR li IN (SELECT reo.objectid
                         FROM api.relationships r1
                              JOIN api.fees f
                              ON f.jobid = r1.toobjectid
                              JOIN api.feetransactions ft
                              ON ft.feeid = f.feeid
                              JOIN api.registeredexternalobjects reo
                              ON reo.linkvalue = TO_CHAR(ft.transactionid)
                             AND reo.objectdefid = t_paymenttransobjectdefid
                        WHERE r1.fromobjectid = a_objectid
                          AND r1.endpointid = t_licenseinvendpointid)
            LOOP
                a_relatedobjectids.EXTEND(1);
                a_relatedobjectids(a_relatedobjectids.COUNT)   := api.udt_object(li.objectid);
            END LOOP;

            --starting from License get Accusation PaymentTransacctions through Investigation
            FOR la IN (SELECT reo.objectid
                         FROM api.relationships r1
                              JOIN api.relationships r2
                              ON r2.fromobjectid = r1.toobjectid
                             AND r2.endpointid = t_invaccusationendpointid
                              JOIN api.fees f
                              ON f.jobid = r2.toobjectid
                              JOIN api.feetransactions ft
                              ON ft.feeid = f.feeid
                              JOIN api.registeredexternalobjects reo
                              ON reo.linkvalue = TO_CHAR(ft.transactionid)
                             AND reo.objectdefid = t_paymenttransobjectdefid
                        WHERE r1.fromobjectid = a_objectid
                          AND r1.endpointid = t_licenseinvendpointid)
            LOOP
                a_relatedobjectids.EXTEND(1);
                a_relatedobjectids(a_relatedobjectids.COUNT)   := api.udt_object(la.objectid);
            END LOOP;
        END IF;
    END getpaymenttransactionsforjob;

    --*------------------------------------------------------------------------------------------------
    --* GetPaymentsForJob() -- PUBLIC
    --* This procedure is for a procedural relationship that will relate Payments that are
    --* already related to this job (app or lic) and also relate the Payments that are related to the
    --* related LT(s) and the other job, whatever that may be, App or Lic. It will also get the Payments
    --* from the related Accusation(s) and Investigation(s).
    --*------------------------------------------------------------------------------------------------
    PROCEDURE getpaymentsforjob(a_objectid udt_id, a_endpointid udt_id, a_relatedobjectids OUT api.udt_objectlist)
    IS
        t_jobtypename                VARCHAR2(25);
        t_jobtypeid                  udt_id;
        t_paymentobjectdefid         udt_id;
        t_applicenseendpointid       udt_id;
        t_licenseappendpointid       udt_id;
        t_licenselictypeendpointid   udt_id;
        t_licenseinvendpointid       udt_id;
        t_invaccusationendpointid    udt_id;
    BEGIN
        a_relatedobjectids           := api.udt_objectlist();

        SELECT od.name
          INTO t_jobtypename
          FROM api.objects o
               JOIN api.objectdefs od
               ON od.objectdefid = o.objectdefid
         WHERE o.objectid = a_objectid;

        t_jobtypeid                  := api.pkg_configquery.objectdefidforname(t_jobtypename);
        t_paymentobjectdefid         := api.pkg_configquery.objectdefidforname('o_Payment');
        t_applicenseendpointid       := api.pkg_configquery.endpointidforname('j_Application', 'License');
        t_licenseappendpointid       := api.pkg_configquery.endpointidforname('j_License', 'ApplicationLicense');
        t_licenselictypeendpointid   := api.pkg_configquery.endpointidforname('j_License', 'LicenseType');
        t_licenseinvendpointid       := api.pkg_configquery.endpointidforname('j_License', 'Investigation');
        t_invaccusationendpointid    := api.pkg_configquery.endpointidforname('j_Investigation', 'Accusation');

        --starting from job that I am on, get the Payments related to it.
        FOR a IN (SELECT reo.objectid
                    FROM api.fees f
                         JOIN api.feetransactions ft
                         ON ft.feeid = f.feeid
                         JOIN api.paymenttransactions pt
                         ON pt.transactionid = ft.transactionid
                         JOIN api.registeredexternalobjects reo
                         ON reo.linkvalue = TO_CHAR(pt.paymentid)
                        AND reo.objectdefid = t_paymentobjectdefid
                   WHERE f.jobid = a_objectid)
        LOOP
            a_relatedobjectids.EXTEND(1);
            a_relatedobjectids(a_relatedobjectids.COUNT)   := api.udt_object(a.objectid);
        END LOOP;

        --if it is an app then get the Payments by walking through the rels for the app
        IF t_jobtypeid = api.pkg_configquery.objectdefidforname('j_Application') THEN
            --starting from App get License PaymentTransactions
            FOR l IN (SELECT reo.objectid
                        FROM api.relationships r
                             JOIN api.fees f
                             ON f.jobid = r.toobjectid
                             JOIN api.feetransactions ft
                             ON ft.feeid = f.feeid
                             JOIN api.paymenttransactions pt
                             ON pt.transactionid = ft.transactionid
                             JOIN api.registeredexternalobjects reo
                             ON reo.linkvalue = TO_CHAR(pt.paymentid)
                            AND reo.objectdefid = t_paymentobjectdefid
                       WHERE r.fromobjectid = a_objectid
                         AND r.endpointid = t_applicenseendpointid)
            LOOP
                a_relatedobjectids.EXTEND(1);
                a_relatedobjectids(a_relatedobjectids.COUNT)   := api.udt_object(l.objectid);
            END LOOP;

            --starting from App get LicenseType Payments through License
            FOR lt IN (SELECT reo.objectid
                         FROM api.relationships r1
                              JOIN api.relationships r2
                              ON r2.fromobjectid = r1.toobjectid
                             AND r2.endpointid = t_licenselictypeendpointid
                              JOIN api.fees f
                              ON f.jobid = r2.toobjectid
                              JOIN api.feetransactions ft
                              ON ft.feeid = f.feeid
                              JOIN api.paymenttransactions pt
                              ON pt.transactionid = ft.transactionid
                              JOIN api.registeredexternalobjects reo
                              ON reo.linkvalue = TO_CHAR(pt.paymentid)
                             AND reo.objectdefid = t_paymentobjectdefid
                        WHERE r1.fromobjectid = a_objectid
                          AND r1.endpointid = t_applicenseendpointid)
            LOOP
                a_relatedobjectids.EXTEND(1);
                a_relatedobjectids(a_relatedobjectids.COUNT)   := api.udt_object(lt.objectid);
            END LOOP;

            --starting from app get Investigation Payments through the license.
            FOR ai IN (SELECT reo.objectid
                         FROM api.relationships r1
                              JOIN api.relationships r2
                              ON r2.fromobjectid = r1.toobjectid
                             AND r2.endpointid = t_licenseinvendpointid
                              JOIN api.fees f
                              ON f.jobid = r2.toobjectid
                              JOIN api.feetransactions ft
                              ON ft.feeid = f.feeid
                              JOIN api.paymenttransactions pt
                              ON pt.transactionid = ft.transactionid
                              JOIN api.registeredexternalobjects reo
                              ON reo.linkvalue = TO_CHAR(pt.paymentid)
                             AND reo.objectdefid = t_paymentobjectdefid
                        WHERE r1.fromobjectid = a_objectid
                          AND r1.endpointid = t_applicenseendpointid)
            LOOP
                a_relatedobjectids.EXTEND(1);
                a_relatedobjectids(a_relatedobjectids.COUNT)   := api.udt_object(ai.objectid);
            END LOOP;

            --starting from App get Accusation Payments through Investigation and License
            FOR aa IN (SELECT reo.objectid
                         FROM api.relationships r1
                              JOIN api.relationships r2
                              ON r2.fromobjectid = r1.toobjectid
                             AND r2.endpointid = t_licenseinvendpointid
                              JOIN api.relationships r3
                              ON r3.fromobjectid = r2.toobjectid
                             AND r3.endpointid = t_invaccusationendpointid
                              JOIN api.fees f
                              ON f.jobid = r3.toobjectid
                              JOIN api.feetransactions ft
                              ON ft.feeid = f.feeid
                              JOIN api.paymenttransactions pt
                              ON pt.transactionid = ft.transactionid
                              JOIN api.registeredexternalobjects reo
                              ON reo.linkvalue = TO_CHAR(pt.paymentid)
                             AND reo.objectdefid = t_paymentobjectdefid
                        WHERE r1.fromobjectid = a_objectid
                          AND r1.endpointid = t_applicenseendpointid)
            LOOP
                a_relatedobjectids.EXTEND(1);
                a_relatedobjectids(a_relatedobjectids.COUNT)   := api.udt_object(aa.objectid);
            END LOOP;
        ELSIF t_jobtypeid = api.pkg_configquery.objectdefidforname('j_License') THEN
            --it is a license and walk through rels from license
            --Starting from License get Application Payments
            FOR a IN (SELECT reo.objectid
                        FROM api.relationships r
                             JOIN api.fees f
                             ON f.jobid = r.toobjectid
                             JOIN api.feetransactions ft
                             ON ft.feeid = f.feeid
                             JOIN api.paymenttransactions pt
                             ON pt.transactionid = ft.transactionid
                             JOIN api.registeredexternalobjects reo
                             ON reo.linkvalue = TO_CHAR(pt.paymentid)
                            AND reo.objectdefid = t_paymentobjectdefid
                       WHERE r.fromobjectid = a_objectid
                         AND r.endpointid = t_licenseappendpointid)
            LOOP
                a_relatedobjectids.EXTEND(1);
                a_relatedobjectids(a_relatedobjectids.COUNT)   := api.udt_object(a.objectid);
            END LOOP;

            --starting from License get LicenseType Payments
            FOR lt IN (SELECT reo.objectid
                         FROM api.relationships r
                              JOIN api.fees f
                              ON f.jobid = r.toobjectid
                              JOIN api.feetransactions ft
                              ON ft.feeid = f.feeid
                              JOIN api.paymenttransactions pt
                              ON pt.transactionid = ft.transactionid
                              JOIN api.registeredexternalobjects reo
                              ON reo.linkvalue = TO_CHAR(pt.paymentid)
                             AND reo.objectdefid = t_paymentobjectdefid
                        WHERE r.fromobjectid = a_objectid
                          AND r.endpointid = t_licenselictypeendpointid)
            LOOP
                a_relatedobjectids.EXTEND(1);
                a_relatedobjectids(a_relatedobjectids.COUNT)   := api.udt_object(lt.objectid);
            END LOOP;

            --starting from License get Investigation Payments
            FOR li IN (SELECT reo.objectid
                         FROM api.relationships r1
                              JOIN api.fees f
                              ON f.jobid = r1.toobjectid
                              JOIN api.feetransactions ft
                              ON ft.feeid = f.feeid
                              JOIN api.paymenttransactions pt
                              ON pt.transactionid = ft.transactionid
                              JOIN api.registeredexternalobjects reo
                              ON reo.linkvalue = TO_CHAR(pt.paymentid)
                             AND reo.objectdefid = t_paymentobjectdefid
                        WHERE r1.fromobjectid = a_objectid
                          AND r1.endpointid = t_licenseinvendpointid)
            LOOP
                a_relatedobjectids.EXTEND(1);
                a_relatedobjectids(a_relatedobjectids.COUNT)   := api.udt_object(li.objectid);
            END LOOP;

            --starting from License get Accusation Payments through Investigation
            FOR la IN (SELECT reo.objectid
                         FROM api.relationships r1
                              JOIN api.relationships r2
                              ON r2.fromobjectid = r1.toobjectid
                             AND r2.endpointid = t_invaccusationendpointid
                              JOIN api.fees f
                              ON f.jobid = r2.toobjectid
                              JOIN api.feetransactions ft
                              ON ft.feeid = f.feeid
                              JOIN api.paymenttransactions pt
                              ON pt.transactionid = ft.transactionid
                              JOIN api.registeredexternalobjects reo
                              ON reo.linkvalue = TO_CHAR(pt.paymentid)
                             AND reo.objectdefid = t_paymentobjectdefid
                        WHERE r1.fromobjectid = a_objectid
                          AND r1.endpointid = t_licenseinvendpointid)
            LOOP
                a_relatedobjectids.EXTEND(1);
                a_relatedobjectids(a_relatedobjectids.COUNT)   := api.udt_object(la.objectid);
            END LOOP;
        END IF;
    END getpaymentsforjob;

    ----------------------------------------------------------------------------------------------------
    -- CreateCatererEventFee() -- PUBLIC
    -- Run on completion of Issue Caterer/Event Authorization process
    --
    ----------------------------------------------------------------------------------------------------
    PROCEDURE createcaterereventfee(a_objectid      udt_id,
                                    a_asofdate      DATE,
                                    a_jobid         udt_id,
                                    a_feeactivity   VARCHAR2)
    IS
        t_description   VARCHAR2(100);
        t_amount        NUMBER;
        t_feeid         NUMBER;
        t_feeobjid      NUMBER;
        t_feeschedid    NUMBER;
        t_glaccountid   NUMBER;
        t_relid         NUMBER;
        t_ltcode        VARCHAR2(2);
        t_masterlt      VARCHAR2(2);
        t_tier          VARCHAR2(10);  --  03/29/2019 TJL WO 17566
    BEGIN
        CASE
            WHEN a_feeactivity = 'CATA' THEN
                t_ltcode   := '58';
            ELSE
                t_ltcode   := '77';
        END CASE;

        -- --  03/29/2019 TJL WO 17566  added getting tier level
        SELECT    'CATEVENT'
               || TO_CHAR(MAX(lv), 'FM0')
          INTO t_tier
          FROM (  SELECT VALUE, lv
                    FROM (    SELECT TRIM(REGEXP_SUBSTR(ltc.maxtiercount,
                                                        '[^,]+',
                                                        1,
                                                        LEVEL))
                                         VALUE,
                                     LEVEL
                                         lv
                                FROM query.o_licensetypecategory ltc
                               WHERE ltc.licensetypecode = t_ltcode
                          CONNECT BY REGEXP_SUBSTR(ltc.maxtiercount,
                                                   '[^,]+',
                                                   1,
                                                   LEVEL)
                                         IS NOT NULL)
                GROUP BY VALUE, lv
                  HAVING MAX(VALUE) <= api.pkg_columnquery.numericvalue(a_objectid, 'EstimatedAttendance')
                     AND MAX(lv) = lv);


        t_masterlt      := api.pkg_columnquery.VALUE(a_objectid, 'LicenseTypeCode');
        --Get Fee Amount and Fee ScheduleId
        sitespecific.pkg_fees.getltfeeamount(a_jobid,
                                             SYSDATE,
                                             a_feeactivity,
                                             NULL,
                                             t_ltcode,
                                             NULL,
                                             NULL,
                                             NULL,
                                             NULL,
                                             t_tier,  --  03/29/2019 TJL WO 17566
                                             'S',
                                             api.pkg_columnquery.numericvalue(a_objectid, 'Days'),
                                             a_asofdate,
                                             t_amount,
                                             t_feeschedid);

        --Raise error if there is no Primary Amount returned by GetLTFeeAmount
        IF t_amount IS NULL
        OR t_amount < 0 THEN
            api.pkg_errors.raiseerror(-20000,
                                         'There is no currently effective '
                                      || a_feeactivity
                                      || ' License Fee Schedule that has a Primary Amount that is $0.00 or greater.');
        END IF;

        --Get GLAccountId
        SELECT g.glaccountid
          INTO t_glaccountid
          FROM api.glaccounts g
         WHERE g.glaccount = a_feeactivity;

        --Set Description
        t_description   := api.pkg_columnquery.VALUE(t_feeschedid, 'ProcedureDescription');

        --Create Fee
        sitespecific.pkg_fees.newfee(t_feeid,
                                     t_amount,
                                     t_description,
                                     t_glaccountid,
                                     a_jobid,
                                     NULL,
                                     t_feeobjid);

        --Relate Fee to Fee Schedule
        t_relid         :=
            api.pkg_relationshipupdate.new(api.pkg_configquery.endpointidforname('o_Fee', 'LicenseFeeSchedule'),
                                           t_feeobjid,
                                           t_feeschedid);

        api.pkg_columnupdate.setvalue(t_relid, 'SecondaryCount', 1);
        api.pkg_columnupdate.setvalue(t_relid, 'MasterLT', t_masterlt);
    END createcaterereventfee;

    -------------------------------------------------------------
    --CalculateOverpayment - PUBLIC
    --This procedure will take an array of feeids and amountstopay and, in the case of an overpayment,
    --will reduce the original amounttopay to equal the totalowing, while adding an additional feeid and amounttopay
    --for the overpayment. It will also pass out a separate set of arrays for the overpayments, used in setting IsOverpayment
    --on the paymenttransaction.
    -------------------------------------------------------------
    PROCEDURE calculateoverpayment(a_feeids       IN OUT udt_idlist,
                                   a_amountstopay IN OUT udt_numberlist,
                                   a_ovrfeeids    IN OUT udt_idlist,
                                   a_ovramountstopay IN OUT udt_numberlist)
    IS
        t_totalowing       NUMBER;
        t_ovramount        NUMBER;
        t_partialovr       VARCHAR(1);
        t_feeobjectdefid   udt_id := api.pkg_configquery.objectdefidforname('o_Fee');
    BEGIN
        FOR c IN 1 .. a_feeids.COUNT
        LOOP
            --Reset loop variable
            t_ovramount    := 0;
            t_partialovr   := 'N';

            --Find total owing
            SELECT api.pkg_columnquery.VALUE(reo.objectid, 'TotalOwing')
              INTO t_totalowing
              FROM api.registeredexternalobjects reo  -- RyanL: PIP Task 8.5
             WHERE reo.linkvalue = TO_CHAR(a_feeids(c))
               AND reo.objectdefid = t_feeobjectdefid;

            --Set total owning to 0 when null or less than 0
            IF t_totalowing IS NULL
            OR t_totalowing < 0 THEN
                t_totalowing   := 0;
            END IF;

            --If Amount is more than TotalOwing and there is TotalOwing, set OVRAmount to the difference and set Amount to the TotalOwing
            --Also mark as Partial OVR (which will create additional values in main a_feeids, a_amountstopay arrays for the OVR
            IF a_amountstopay(c) > t_totalowing
           AND t_totalowing > 0 THEN
                t_ovramount         := a_amountstopay(c) - t_totalowing;
                a_amountstopay(c)   := t_totalowing;
                t_partialovr        := 'Y';
            --If entire payment is overpayment, set OVRAmount. The original values in a_feeids, a_Amountstopay will be used.
            ELSIF a_amountstopay(c) > t_totalowing THEN
                t_ovramount   := a_amountstopay(c) - t_totalowing;
            END IF;

            --Add Overpayment Amount to OVRarray
            IF t_ovramount > 0 THEN
                a_ovramountstopay(a_ovramountstopay.COUNT + 1)   := t_ovramount;
                a_ovrfeeids(a_ovrfeeids.COUNT + 1)               := a_feeids(c);
            END IF;

            --Add OVRarray values to main arrays (which are used to create payments) when the Original Payment was not entirely an OVR (in which case the
            --existing value will be regarded as OVR).
            IF t_partialovr = 'Y' THEN
                a_amountstopay(a_amountstopay.COUNT + 1)   := a_ovramountstopay(a_ovramountstopay.COUNT);
                a_feeids(a_feeids.COUNT + 1)               := a_ovrfeeids(a_ovramountstopay.COUNT);
            END IF;
        END LOOP;
    END calculateoverpayment;

    -------------------------------------------------
    -- SetPaymentTransactionFlag -PUBLIC
    -- Takes array of FeeIds and Amounts and marks flag (passed in ColumnName) on max(PaymentTransactions.objectid) with that same feeid and amount.
    -------------------------------------------------
    PROCEDURE setpaymenttransactionflag(a_ovrfeeids     udt_idlist,
                                        a_ovramountstopay udt_numberlist,
                                        a_columnname    VARCHAR2,
                                        a_refund        BOOLEAN DEFAULT FALSE)
    IS
        t_paytransobjectid      NUMBER;
        t_paytransobjectdefid   udt_id := api.pkg_configquery.objectdefidforname('o_PaymentTransactions');
    BEGIN
        IF a_columnname = 'IsServiceCharge'
       AND a_refund = FALSE THEN
            FOR ovr IN (SELECT reo.objectid
                          FROM api.feetransactions ft
                               JOIN api.registeredexternalobjects reo  --TAyers: PIP Task 8.5
                               ON reo.linkvalue = TO_CHAR(ft.transactionid)
                              AND reo.objectdefid = t_paytransobjectdefid
                               JOIN api.fees f
                               ON f.feeid = ft.feeid
                         WHERE ft.feeid = a_ovrfeeids(1))
            LOOP
                --Set Payment Transaction Flag to Y
                api.pkg_columnupdate.setvalue(ovr.objectid, a_columnname, 'Y');
            END LOOP;
        ELSE
            FOR ovr IN 1 .. a_ovrfeeids.COUNT
            LOOP
                --Select max Payment Transaction where feeid and amount are in array
                SELECT MAX(reo.objectid)
                  INTO t_paytransobjectid
                  FROM api.feetransactions ft
                       JOIN api.registeredexternalobjects reo  --TAyers: PIP Task 8.5
                       ON reo.linkvalue = TO_CHAR(ft.transactionid)
                      AND reo.objectdefid = t_paytransobjectdefid
                       JOIN api.fees f
                       ON f.feeid = ft.feeid
                 WHERE ft.feeid = a_ovrfeeids(ovr)
                   AND -ft.amount = a_ovramountstopay(ovr);

                --Set Payment Transaction Flag to Y
                api.pkg_columnupdate.setvalue(t_paytransobjectid, a_columnname, 'Y');
            END LOOP;
        END IF;
    END setpaymenttransactionflag;

    ------------------------------
    -- Process Receive Payment() - PUBLIC
    -- This process is scheduled and for 10 days plus work days after the deposit of the payment
    -- It uses the Receive Payment Process to track partial and complete payments
    -- It will have one of two outcomes: Partial Payment, when the job balance
    -- is greater than the IssueTolerance user constant; and Full Payment, when the job
    -- balance is less than or equal to the IssueTolerance constant. The Full Payment
    -- outcome also updates the Include in Batch flags on the LT so that only Include In
    -- Produce License Batch flag is checked.
    ------------------------------

    PROCEDURE processreceivepayment(a_jobid udt_id)
    IS
        t_feesremaining       NUMBER;
        t_issuetolerance      NUMBER;
        t_renexpdate          DATE;
        t_ltexpirationdate    DATE;
        t_ltcode              VARCHAR2(10);
        t_continue            VARCHAR2(1);
        t_jobid               NUMBER := 0;
        t_licensetypecode     VARCHAR2(2) := '';
        t_seasonaldate        DATE;
        t_paymentdateplus10   DATE;
        t_totalowing          NUMBER;
        t_feeobjectdefid      udt_id := api.pkg_configquery.objectdefidforname('o_Fee');
    BEGIN
        FOR z
            IN (  -- 08/05/2021 TJL WO 25899
                  SELECT jobid,
                         licensetypecode,
                         paymentid,
                         paymentdate,
                         CASE paymentmethod
                             WHEN 'CRCD' THEN maxdepositdateplus10
                             WHEN 'ECHECK' THEN maxdepositdateplus10
                             ELSE api.pkg_utils.dateplusworkdays(maxdepositdateplus10, 10)
                         END
                             maxdepositdateplus10
                    FROM (SELECT DISTINCT
                                 prp.jobid,
                                 prp.licensetypecode,
                                 prp.paymentid,
                                 prp.paymentdate,
                                 prp.maxdepositdateplus10,
                                 -- 08/05/2021 TJL WO 25899
                                 api.pkg_columnquery.VALUE(
                                     api.pkg_simplesearch.objectbyindex('o_Payment', 'Paymentid', prp.paymentid),
                                     'PaymentMethodCode')
                                     paymentmethod
                            FROM sitespecific.processesdepositedpayments_t prp
                           WHERE prp.paymentid IN
                                     (SELECT api.pkg_columnquery.numericvalue(pbp.paymentobjectid, 'PaymentId')
                                                 paymentid
                                        FROM query.r_depositpaymentbatch dpb
                                             JOIN query.r_paymentbatchpayment pbp
                                             ON pbp.paymentbatchjobid = dpb.paymentbatchjobid
                                       WHERE dpb.depositjobid = a_jobid
                                      UNION ALL
                                      SELECT api.pkg_columnquery.numericvalue(tp.paymentobjectid, 'PaymentId')
                                                 paymentid
                                        FROM query.r_transmittaldeposit t
                                             JOIN query.r_transmittalpayment tp
                                             ON tp.transmittaljobid = t.transmittaljobid
                                       WHERE t.depositjobid = a_jobid))
                ORDER BY 1, 2, 3)
        LOOP
            -- Only run for each specific JobId
            IF z.jobid <> t_jobid THEN
                pkg_issuelicense.validatepaymentcheck(NULL,
                                                      NULL,
                                                      z.jobid,
                                                      z.licensetypecode,
                                                      'Y',
                                                      t_continue);

                IF t_continue = 'Y' THEN
                    t_paymentdateplus10   := z.maxdepositdateplus10; -- 08/05/2021 TJL WO 25899

                    UPDATE sitespecific.processesdepositedpayments_t pt
                       SET pt.processeddate   = SYSDATE
                     WHERE pt.jobid = z.jobid
                       AND pt.licensetypecode = z.licensetypecode;

                    t_ltexpirationdate    := api.pkg_columnquery.datevalue(z.jobid, 'ExpirationDate');
                    t_ltcode              := api.pkg_columnquery.VALUE(z.jobid, 'LicenseTypeCode');

                    -- Get the Issue Tolerance user constant
                    t_issuetolerance      := api.pkg_constantquery.VALUE('ISSUETOLERANCE');

                    -- This code added by Pawan on 7/14/2016 to resolve issue 8045
                    SELECT SUM(api.pkg_columnquery.numericvalue(reo.objectid, 'TotalOwing'))
                      INTO t_totalowing
                      FROM query.j_licensetype lt
                           JOIN api.fees f
                           ON f.jobid = z.jobid
                           JOIN api.registeredexternalobjects reo  -- RyanL: PIP Task 8.5
                           ON reo.linkvalue = TO_CHAR(f.feeid)
                          AND reo.objectdefid = t_feeobjectdefid
                           JOIN query.r_feelicensefeeschedule flfs
                           ON flfs.feeobjectid = reo.objectid
                           JOIN sitespecific.feeschedule_t fs
                           ON fs.objectid = flfs.licensefeescheduleid
                     WHERE lt.jobid = z.jobid
                       AND fs.feeactivity IN ('REN', 'REN50', 'REN100')
                       --  02/20/2020 TJL WO 3838 added limit to how far back to look for balances
                       AND f.transactiondate > ADD_MONTHS(SYSDATE, -12);

                    IF t_totalowing <= 0 THEN
                        BEGIN
                            -- end of code added by Pawan on 7/14/2016 to resolve issue 8045
                            -- Get the remaining fee balance from the job and the REN Exp Date from the Fee
                            FOR c
                                IN (  SELECT fs.licensetypecode,
                                             MAX(
                                                 NVL(
                                                     api.pkg_columnquery.datevalue(reo.objectid, 'RENExpirationDate'),
                                                     NVL(
                                                         DECODE(
                                                             SUBSTR(fs.description, -1),
                                                             '9', TO_DATE(  -- Final Date
                                                                         TO_CHAR(  -- Day of month
                                                                             LAST_DAY(
                                                                                    '01-'
                                                                                 || TO_CHAR(
                                                                                        LAST_DAY(t_ltexpirationdate),
                                                                                        'MON')
                                                                                 || '-2009'),
                                                                             'DD')  -- End Day of month
                                                                      || '-'
                                                                      || TO_CHAR(t_ltexpirationdate, 'MON')  -- Month
                                                                      || '-2009'  -- Year
                                                                                ),  -- final date
                                                             'A', TO_DATE(  -- Final Date
                                                                         TO_CHAR(  -- Day of month
                                                                             LAST_DAY(
                                                                                 TO_DATE(
                                                                                        '01-'
                                                                                     || TO_CHAR(
                                                                                            LAST_DAY(
                                                                                                t_ltexpirationdate),
                                                                                            'MON')
                                                                                     || '-2010',
                                                                                     'DD-MON-YYYY')),
                                                                             'DD')  -- End Day of month
                                                                      || '-'
                                                                      || TO_CHAR(t_ltexpirationdate, 'MON')  -- Month
                                                                      || '-2010'  -- Year
                                                                                )),  --final date
                                                         LAST_DAY(SYSDATE))))
                                                 renexpdate,
                                             SUM(api.pkg_columnquery.numericvalue(reo.objectid, 'TotalOwing'))
                                                 feesremaining
                                        FROM query.j_licensetype lt
                                             JOIN api.fees f
                                             ON f.jobid = z.jobid
                                             JOIN api.registeredexternalobjects reo  -- RyanL: PIP Task 8.5
                                             ON reo.linkvalue = TO_CHAR(f.feeid)
                                            AND reo.objectdefid = t_feeobjectdefid
                                             JOIN query.r_feelicensefeeschedule flfs
                                             ON flfs.feeobjectid = reo.objectid
                                             JOIN sitespecific.feeschedule_t fs
                                             ON fs.objectid = flfs.licensefeescheduleid
                                       WHERE lt.jobid = z.jobid
                                         AND fs.feeactivity IN ('REN', 'REN50', 'REN100')
                                         --  02/20/2020 TJL  WO 3838  added limit to how far back to look for balances
                                         AND f.transactiondate > ADD_MONTHS(SYSDATE, -12)
                                    GROUP BY fs.licensetypecode
                                    ORDER BY MAX(CASE WHEN fs.licensetypecode = lt.licensetypecode THEN 1 ELSE 2 END))
                            LOOP
                                -- If the remaining balance is less than the issue tolerance, then complete the process with the Full Payment outcome,
                                -- advance the Expiration Year on the LT by one, and insures that Produce License is the only Include In Batch flag that is checked.
                                IF c.feesremaining <= t_issuetolerance
                               AND c.renexpdate >= t_ltexpirationdate THEN
                                    IF c.licensetypecode = t_ltcode THEN
                                        -- Update Include In Batch Flags
                                        api.pkg_columnupdate.setvalue(z.jobid, 'IncludeIn1stRenewal', 'N');
                                        api.pkg_columnupdate.setvalue(z.jobid, 'IncludeIn2ndRenewal', 'N');
                                        api.pkg_columnupdate.setvalue(z.jobid, 'IncludeInFinalRevPending', 'N');
                                        api.pkg_columnupdate.setvalue(z.jobid, 'IncludeInProduceLicenseBatch', 'Y');
                                        api.pkg_columnupdate.setvalue(z.jobid, 'IncludeInRevokeBatch', 'N');
                                        api.pkg_columnupdate.setvalue(z.jobid, 'RENFeeCreated', 'N');
                                        --Update the dup column because post verify did not run on the job
                                        api.pkg_columnupdate.setvalue(z.jobid, 'dup_IncludeInProduceLicBatchSe', 'Y');

                                        IF api.pkg_columnquery.VALUE(z.jobid, 'SeasonStartMonthNumber') IS NULL THEN
                                            api.pkg_columnupdate.setvalue(z.jobid,
                                                                          'ReadyToIssueDate',
                                                                          -- CASE -- Commented by Pawan on 2/24/2020 for fixing Processing renewals 10 days after deposit PK WO 20565
                                                                          --  WHEN t_ltexpirationdate >
                                                                          --    t_paymentdateplus10 THEN
                                                                          --  t_ltexpirationdate
                                                                          -- ELSE
                                                                          t_paymentdateplus10);
                                        -- END);
                                        ELSE
                                            t_seasonaldate   :=
                                                  -- **********************************************************
                                                  -- 01/08/2019 TJL WO 16435 changed how seasonal
                                                  --                         Ready to Issue date is created.
                                                  -- **********************************************************
                                                  TO_DATE(
                                                         LPAD(
                                                             api.pkg_columnquery.VALUE(z.jobid,
                                                                                       'SeasonStartMonthnumber'),
                                                             2,
                                                             '00')
                                                      || '/01/'
                                                      || CASE
                                                             WHEN (  TO_NUMBER(
                                                                         TO_CHAR(
                                                                             api.pkg_columnquery.datevalue(
                                                                                 z.jobid,
                                                                                 'dup_ExpirationDate'),
                                                                             'MM'))
                                                                   - (  api.pkg_columnquery.numericvalue(
                                                                            z.jobid,
                                                                            'NumberOfMonthsLicensedNumber')
                                                                      + 1)) <  -- 01/09/2019 TJL 16435 removed = from test
                                                                  0 THEN
                                                                 NVL(
                                                                     api.pkg_columnquery.numericvalue(z.jobid,
                                                                                                      'ExpiringYear'),
                                                                     9999)
                                                             ELSE
                                                                 NVL(
                                                                       api.pkg_columnquery.numericvalue(
                                                                           z.jobid,
                                                                           'ExpiringYear')
                                                                     + 1,
                                                                     '9999')
                                                         END,
                                                      'MM/DD/YYYY')
                                                - 1;
                                            -- **********************************************************
                                            api.pkg_columnupdate.setvalue(z.jobid,
                                                                          'ReadyToIssueDate',
                                                                          -- CASE -- Commented by Pawan on 2/24/2020 for fixing Processing renewals 10 days after deposit PK WO 20565
                                                                          --   WHEN t_seasonaldate >
                                                                          --     t_paymentdateplus10 THEN
                                                                          --     t_seasonaldate
                                                                          -- ELSE
                                                                          t_paymentdateplus10);
                                        --END);
                                        END IF;
                                    END IF;

                                    FOR slt
                                        IN (SELECT sltlt.relationshipid,
                                                   sltlt.includeindailybatch,
                                                   sltlt.licensetypejobid,
                                                   sltlt.licensetypecategoryobjectid
                                              FROM query.r_licensetypeltcatsecondary sltlt
                                                   JOIN query.o_licensetypecategory ltc
                                                   ON ltc.objectid = sltlt.licensetypecategoryobjectid
                                             WHERE sltlt.licensetypejobid = z.jobid
                                               AND ltc.licensetypecode = c.licensetypecode
                                               AND sltlt.status NOT IN ('PENDING',
                                                                        'NON-RENEWED',
                                                                        'AUTO-REVOKED',
                                                                        'CANCELED',
                                                                        'DEPARTMENTAL',
                                                                        'REVOKED',
                                                                        'DENIED',
                                                                        'SLMS REVOKED',
                                                                        'VOIDED',
                                                                        'WITHDRAWN')  -- Changed by Pawan 06/22/2014 to resolve issue 3775
                                               AND api.pkg_columnquery.VALUE(z.jobid, 'IncludeInProduceLicenseBatch') =
                                                   'Y')
                                    LOOP
                                        --For Each Secondary set the Include in Produce License Batch flags.
                                        sitespecific.pkg_batchtype.setbatchflags(
                                            a_lictypejobid => slt.relationshipid,
                                            a_includeinproducelicensebatch => 'Y',
                                            a_includeindailybatch => slt.includeindailybatch);

                                        IF api.pkg_columnquery.VALUE(z.jobid, 'SeasonStartMonthNumber') IS NULL THEN
                                            api.pkg_columnupdate.setvalue(slt.relationshipid,
                                                                          'ReadyToIssueDate',
                                                                          --   CASE -- Commented by Pawan on 2/24/2020 for fixing Processing renewals 10 days after deposit PK WO 20565
                                                                          --  WHEN t_ltexpirationdate >
                                                                          --     t_paymentdateplus10 THEN
                                                                          --  t_ltexpirationdate
                                                                          -- ELSE
                                                                          t_paymentdateplus10);

                                            -- END);

                                            --Set the Ready To Issue Date on Duplicates
                                            FOR c_dup
                                                IN (SELECT d.duplicateid objectid
                                                      FROM sitespecific.duplicate_t d
                                                     WHERE d.licensetypejobid = slt.licensetypejobid
                                                       AND d.licensetypecategoryobjectid =
                                                           slt.licensetypecategoryobjectid
                                                       AND d.relationshipid = slt.relationshipid)
                                            LOOP
                                                api.pkg_columnupdate.setvalue(c_dup.objectid,
                                                                              'ReadyToIssueDate',
                                                                              --    CASE -- Commented by Pawan on 2/24/2020 for fixing Processing renewals 10 days after deposit PK WO 20565
                                                                              --        WHEN t_ltexpirationdate >
                                                                              --            t_paymentdateplus10 THEN
                                                                              --            t_ltexpirationdate
                                                                              --        ELSE
                                                                              t_paymentdateplus10);
                                                --   END);
                                                -- 01/08/2019 TJL WO 16435 add updating ready to issue date in
                                                --                           relationship object
                                                api.pkg_columnupdate.setvalue(slt.relationshipid,
                                                                              'ReadyToIssueDate',
                                                                              --   CASE
                                                                              --      WHEN t_ltexpirationdate >
                                                                              --          t_paymentdateplus10 THEN
                                                                              --         t_ltexpirationdate
                                                                              --     ELSE
                                                                              t_paymentdateplus10);
                                            -- END);
                                            END LOOP;
                                        ELSE
                                            t_seasonaldate   :=
                                                  -- **********************************************************
                                                  -- 01/08/2019 TJL WO 16435 changed how seasonal
                                                  --                         Ready to Issue date is created.
                                                  -- **********************************************************
                                                  TO_DATE(
                                                         LPAD(
                                                             api.pkg_columnquery.VALUE(z.jobid,
                                                                                       'SeasonStartMonthnumber'),
                                                             2,
                                                             '00')
                                                      || '/01/'
                                                      || CASE
                                                             WHEN (  TO_NUMBER(
                                                                         TO_CHAR(
                                                                             api.pkg_columnquery.datevalue(
                                                                                 z.jobid,
                                                                                 'dup_ExpirationDate'),
                                                                             'MM'))
                                                                   - (  api.pkg_columnquery.numericvalue(
                                                                            z.jobid,
                                                                            'NumberOfMonthsLicensedNumber')
                                                                      + 1)) <  -- 01/09/2019 TJL 16435 removed = from test
                                                                  0 THEN
                                                                 NVL(
                                                                     api.pkg_columnquery.numericvalue(z.jobid,
                                                                                                      'ExpiringYear'),
                                                                     9999)
                                                             ELSE
                                                                 NVL(
                                                                       api.pkg_columnquery.numericvalue(
                                                                           z.jobid,
                                                                           'ExpiringYear')
                                                                     + 1,
                                                                     '9999')
                                                         END,
                                                      'MM/DD/YYYY')
                                                - 1;
                                            -- **********************************************************
                                            api.pkg_columnupdate.setvalue(z.jobid,
                                                                          'ReadyToIssueDate',
                                                                          -- CASE -- Commented by Pawan on 2/24/2020 for fixing Processing renewals 10 days after deposit PK WO 20565
                                                                          --   WHEN t_seasonaldate >
                                                                          --       t_paymentdateplus10 THEN
                                                                          --      t_seasonaldate
                                                                          --  ELSE
                                                                          t_paymentdateplus10);

                                            --  END);

                                            --Set the Ready To Issue Date on Duplicates
                                            FOR c_dup
                                                IN (SELECT d.duplicateid objectid
                                                      FROM sitespecific.duplicate_t d
                                                     WHERE d.licensetypejobid = slt.licensetypejobid
                                                       AND d.licensetypecategoryobjectid =
                                                           slt.licensetypecategoryobjectid
                                                       AND d.relationshipid = slt.relationshipid)
                                            LOOP
                                                api.pkg_columnupdate.setvalue(c_dup.objectid,
                                                                              'ReadyToIssueDate',
                                                                              -- CASE ---- Commented by Pawan on 2/24/2020 for fixing Processing renewals 10 days after deposit PK WO 20565
                                                                              --  WHEN t_seasonaldate >
                                                                              --     t_paymentdateplus10 THEN
                                                                              --      t_seasonaldate
                                                                              --  ELSE
                                                                              t_paymentdateplus10);
                                                --  END);
                                                -- 01/08/2019 TJL WO 16435 add updating ready to issue date in
                                                --                           relationship object
                                                api.pkg_columnupdate.setvalue(slt.relationshipid,
                                                                              'ReadyToIssueDate',
                                                                              --   CASE -- Commented by Pawan on 2/24/2020 for fixing Processing renewals 10 days after deposit PK WO 20565
                                                                              --  WHEN t_seasonaldate >
                                                                              --      t_paymentdateplus10 THEN
                                                                              --     t_seasonaldate

                                                                              --  ELSE
                                                                              t_paymentdateplus10);
                                            -- END);
                                            END LOOP;
                                        END IF;
                                    END LOOP;
                                END IF;
                            END LOOP;
                        END;
                    END IF;
                END IF;
            END IF;

            t_jobid             := z.jobid;
            t_licensetypecode   := z.licensetypecode;
        END LOOP;
    END processreceivepayment;

    ---------------------------------------
    -- ProcessNegativePayment()
    -- This takes negative payments from transfers, dishonors,
    -- voids, and refunds, and updateds the R2I date and
    -- batch flags on LTs
    ---------------------------------------

    PROCEDURE processnegativepayment(a_paymentid     udt_id DEFAULT NULL,
                                     a_feeid         udt_id DEFAULT NULL,
                                     a_jobid         udt_id DEFAULT NULL)
    IS
        t_temp   NUMBER;
    BEGIN
        IF a_paymentid IS NOT NULL
       AND a_feeid IS NULL THEN
            FOR c IN (SELECT f.feeid, f.jobid
                        FROM api.payments p
                             JOIN api.paymenttransactions pt
                             ON pt.paymentid = p.paymentid
                             JOIN api.feetransactions ft
                             ON ft.transactionid = pt.transactionid
                             JOIN api.fees f
                             ON f.feeid = ft.feeid
                       WHERE p.paymentid = a_paymentid)
            LOOP
                IF api.pkg_columnquery.VALUE(c.jobid, 'ObjectDefName') = 'j_LicenseType' THEN
                    -- Call function to update LT data
                    t_temp   := pkg_fees.processnpfunction(c.feeid, c.jobid);
                END IF;
            END LOOP;
        ELSIF a_feeid IS NOT NULL
          AND a_paymentid IS NULL THEN
            -- Call function to update LT data
            t_temp   := pkg_fees.processnpfunction(a_feeid, a_jobid);
        END IF;
    END processnegativepayment;

    -------------------------------
    -- ProcessNPFunction()
    -------------------------------
    FUNCTION processnpfunction(a_feeid udt_id, a_jobid udt_id)
        RETURN NUMBER
    IS
        t_firstrenewal     VARCHAR(1);
        t_secondrenewal    VARCHAR(1);
        t_finalrevp        VARCHAR(1);
        t_autorev          VARCHAR(1);
        t_relid            udt_id;
        t_master           VARCHAR(1);
        t_expirationdate   DATE;
        t_feeobjectdefid   udt_id := api.pkg_configquery.objectdefidforname('o_Fee');
    BEGIN
        -- Check for this being an SLT fee
        BEGIN
            SELECT slt.relationshipid, r.ismaster
              INTO t_relid, t_master
              FROM api.fees f
                   JOIN api.registeredexternalobjects reo  -- RyanL: PIP Task 8.5
                   ON reo.linkvalue = TO_CHAR(f.feeid)
                  AND reo.objectdefid = t_feeobjectdefid
                   JOIN query.r_feelicensefeeschedule r
                   ON r.feeobjectid = reo.objectid
                   JOIN sitespecific.feeschedule_t fs
                   ON fs.objectid = r.licensefeescheduleid
                   JOIN query.j_licensetype lt
                   ON lt.jobid = f.jobid
                   JOIN query.r_licensetypeltcatsecondary slt
                   ON slt.licensetypejobid = lt.jobid
             WHERE f.feeid = a_feeid
               AND api.pkg_columnquery.VALUE(slt.licensetypecategoryobjectid, 'LicenseTypeCode') = fs.licensetypecode;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                t_relid    := NULL;
                t_master   := NULL;
        END;

        t_expirationdate   := api.pkg_columnquery.datevalue(a_jobid, 'ExpirationDate');

        IF t_relid IS NULL
        OR (t_relid IS NOT NULL
        AND t_master = 'Y') THEN
            -- Remove value from R2I date
            api.pkg_columnupdate.removevalue(a_jobid, 'ReadyToIssueDate');

            -- Update Batch Flags: Get batch type from last completed batch from LT
            -- Logic Backported from Issue012889 to check the last run Batch Type and set to the correct batch
            BEGIN
                SELECT CASE WHEN batchtype = '1ST RENEWAL NOTICES' THEN 'Y' ELSE 'N' END              firstrenewal,
                       CASE WHEN batchtype = '2ND RENEWAL NOTICES' THEN 'Y' ELSE 'N' END              secondrenewal,
                       CASE WHEN batchtype = 'FINAL REVOCATION PENDING LETTERS' THEN 'Y' ELSE 'N' END finalrevp,
                       CASE WHEN batchtype = 'AUTO REVOKE LICENSE TYPES' THEN 'Y' ELSE 'N' END        autorev
                  INTO t_firstrenewal,
                       t_secondrenewal,
                       t_finalrevp,
                       t_autorev
                  FROM (  SELECT batchtype, MAX(expirationdate) expirationdate
                            FROM query.j_licensebatch lb
                           WHERE batchtype IN ('1ST RENEWAL NOTICES',
                                               '2ND RENEWAL NOTICES',
                                               'FINAL REVOCATION PENDING LETTERS',
                                               'AUTO REVOKE LICENSE TYPES')
                        GROUP BY batchtype
                        ORDER BY DECODE(batchtype,
                                        '1ST RENEWAL NOTICES', 1,
                                        '2ND RENEWAL NOTICES', 2,
                                        'FINAL REVOCATION PENDING LETTERS', 3,
                                        'AUTO REVOKE LICENSE TYPES', 4))
                 WHERE expirationdate < t_expirationdate
                   AND ROWNUM = 1;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    t_firstrenewal    := 'N';
                    t_secondrenewal   := 'N';
                    t_finalrevp       := 'N';
                    t_autorev         := 'N';
            END;

            -- Based on batch type, update batch flags to correct values
            pkg_batchtype.setbatchflags(a_jobid,
                                        'N',
                                        'N',
                                        t_firstrenewal,
                                        t_secondrenewal,
                                        t_finalrevp,
                                        t_autorev,
                                        api.pkg_columnquery.VALUE(a_jobid, 'IsGreenDone'),
                                        api.pkg_columnquery.VALUE(a_jobid, 'IsPinkDone'));
        END IF;

        IF t_relid IS NOT NULL THEN
            -- Remove value from R2I date
            api.pkg_columnupdate.removevalue(t_relid, 'ReadyToIssueDate');

            -- Update Batch Flags: Get batch type from last completed batch from LT
            -- Logic Backported from Issue012889 to check the last run Batch Type and set to the correct batch
            BEGIN
                SELECT CASE WHEN batchtype = '1ST RENEWAL NOTICES' THEN 'Y' ELSE 'N' END              firstrenewal,
                       CASE WHEN batchtype = '2ND RENEWAL NOTICES' THEN 'Y' ELSE 'N' END              secondrenewal,
                       CASE WHEN batchtype = 'FINAL REVOCATION PENDING LETTERS' THEN 'Y' ELSE 'N' END finalrevp,
                       CASE WHEN batchtype = 'AUTO REVOKE LICENSE TYPES' THEN 'Y' ELSE 'N' END        autorev
                  INTO t_firstrenewal,
                       t_secondrenewal,
                       t_finalrevp,
                       t_autorev
                  FROM (  SELECT batchtype, MAX(expirationdate) expirationdate
                            FROM query.j_licensebatch lb
                           WHERE batchtype IN ('1ST RENEWAL NOTICES',
                                               '2ND RENEWAL NOTICES',
                                               'FINAL REVOCATION PENDING LETTERS',
                                               'AUTO REVOKE LICENSE TYPES')
                        GROUP BY batchtype
                        ORDER BY DECODE(batchtype,
                                        '1ST RENEWAL NOTICES', 1,
                                        '2ND RENEWAL NOTICES', 2,
                                        'FINAL REVOCATION PENDING LETTERS', 3,
                                        'AUTO REVOKE LICENSE TYPES', 4))
                 WHERE expirationdate < t_expirationdate
                   AND ROWNUM = 1;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    t_firstrenewal    := 'N';
                    t_secondrenewal   := 'N';
                    t_finalrevp       := 'N';
                    t_autorev         := 'N';
            END;

            -- Based on batch type, update batch flags to correct values
            pkg_batchtype.setbatchflags(t_relid,
                                        'N',
                                        'N',
                                        t_firstrenewal,
                                        t_secondrenewal,
                                        t_finalrevp,
                                        t_autorev,
                                        api.pkg_columnquery.VALUE(a_jobid, 'IsGreenDone'),
                                        api.pkg_columnquery.VALUE(a_jobid, 'IsPinkDone'));
        END IF;

        RETURN a_jobid;
    END processnpfunction;

    ------------------------------------------------
    -- ModifyFee()
    -- there are two options for this procedure
    -- 1. Void the Fee by adjusting it to zero
    -- 2. change the Fee Schedule Record to the new fee.
    ------------------------------------------------

    PROCEDURE modifyfee(a_objectid      udt_id,
                        a_asofdate      DATE,
                        a_modifytype    VARCHAR2,
                        a_islicfeeschedule VARCHAR2)
    IS
        t_feedetails            VARCHAR2(100);
        t_feeid                 udt_id;
        t_feejobid              udt_id;
        t_processid             udt_id;
        t_amount                NUMBER;
        t_temp                  udt_id;
        t_ismaster              VARCHAR2(1);
        t_secondarycount        NUMBER;
        t_masterlt              NUMBER;
        t_earnedamount          NUMBER;
        t_feeactivity           VARCHAR2(60);
        t_tofeeschobjid         udt_id;
        t_feeamount             NUMBER;
        t_unitamount            NUMBER;
        t_totalowing1           NUMBER;
        t_totalowing2           NUMBER;
        t_paytransobjectdefid   udt_id := api.pkg_configquery.objectdefidforname('o_PaymentTransactions');
    BEGIN
        -- Check if the fee has earned transactions on it. If it does, raise an error
        SELECT NVL(SUM(ps.earnedamount), 0)
          INTO t_earnedamount
          FROM query.r_modifyfeefee r
               JOIN query.o_fee f
               ON f.objectid = r.feeobjectid
               JOIN api.feetransactions ft
               ON ft.feeid = f.feeid
               JOIN api.registeredexternalobjects reo  --TAyers: PIP Task 8.5
               ON reo.linkvalue = TO_CHAR(ft.transactionid)
              AND reo.objectdefid = t_paytransobjectdefid
               JOIN query.r_paymentstatuspaymenttrans psr
               ON psr.paymenttransactionobjectid = reo.objectid
               JOIN query.o_paymentstatus ps
               ON ps.objectid = psr.paymentstatusobjectid
         WHERE r.modifyfeeprocessid = a_objectid;

        IF t_earnedamount < 0 THEN
            api.pkg_errors.raiseerror(-20000, 'You cannot modify a fee that already has earned payments.');
        END IF;

        IF a_modifytype = 'Void Fee' THEN
            --Adjust the fee to zero
            SELECT f.feeid, -(f.amountfordisplay), f.feeconcat
              INTO t_feeid, t_amount, t_feedetails
              FROM query.r_modifyfeefee mff
                   JOIN query.o_fee f
                   ON f.objectid = mff.feeobjectid
             WHERE mff.modifyfeeprocessid = a_objectid;

            api.pkg_columnupdate.setvalue(a_objectid, 'FeeDetails', t_feedetails);
            t_temp   :=
                api.pkg_feeupdate.adjust(t_feeid,
                                         t_amount,
                                         'Modify Fee - Void',
                                         SYSDATE);
        -- Process batch flags

        ELSIF a_modifytype = 'Modify Fee' THEN
            --Change fee Schedule to the New record
            IF a_islicfeeschedule = 'Y' THEN
                SELECT ffs.relationshipid,
                       mff.feeobjectid,
                       f.amountfordisplay,
                       f.totalowing,
                       f.feeconcat
                  INTO t_temp,
                       t_feeid,
                       t_feeamount,
                       t_totalowing1,
                       t_feedetails
                  FROM query.r_modifyfeefee mff
                       JOIN query.o_fee f
                       ON f.objectid = mff.feeobjectid
                       JOIN query.r_feelicensefeeschedule ffs
                       ON ffs.feeobjectid = mff.feeobjectid
                 WHERE mff.modifyfeeprocessid = a_objectid;
            ELSE
                SELECT ffs.relationshipid,
                       mff.feeobjectid,
                       f.amountfordisplay,
                       f.totalowing,
                       f.feeconcat
                  INTO t_temp,
                       t_feeid,
                       t_feeamount,
                       t_totalowing1,
                       t_feedetails
                  FROM query.r_modifyfeefee mff
                       JOIN query.o_fee f
                       ON f.objectid = mff.feeobjectid
                       JOIN query.r_miscfeefeeschedule ffs
                       ON ffs.feeobjectid = mff.feeobjectid
                 WHERE mff.modifyfeeprocessid = a_objectid;
            END IF;

            api.pkg_columnupdate.setvalue(a_objectid, 'FeeDetails', t_feedetails);
            api.pkg_relationshipupdate.remove(t_temp, SYSDATE);

            IF a_islicfeeschedule = 'Y' THEN
                SELECT mffs.amount,
                       mffs.ismaster,
                       mffs.secondarycount,
                       mffs.masterlt,
                       fs.feeactivity,
                       fs.objectid
                  INTO t_amount,
                       t_ismaster,
                       t_secondarycount,
                       t_masterlt,
                       t_feeactivity,
                       t_tofeeschobjid
                  FROM query.r_modifyfeefeeschedule mffs
                       JOIN sitespecific.feeschedule_t fs
                       ON fs.objectid = mffs.feescheduleobjectid
                 WHERE mffs.modifyfeeprocessid = a_objectid;
            ELSE
                SELECT CASE
                           WHEN mmfs.quantity > 1
                            AND mfs.amount > 0 THEN
                               ROUND(mfs.amount * mmfs.quantity, 2)
                           WHEN mmfs.quantity <= 1
                            AND mfs.amount > 0 THEN
                               mfs.amount
                           WHEN mmfs.quantity > 1
                            AND mfs.amount <= 0 THEN
                               ROUND(mmfs.amount * mmfs.quantity, 2)
                           ELSE
                               mmfs.amount
                       END
                           feeamount,
                       mfs.objectid,
                       mfs.amount
                  INTO t_amount, t_tofeeschobjid, t_unitamount
                  FROM query.r_modifymiscfeesched mmfs
                       JOIN query.o_miscfeeschedule mfs
                       ON mfs.objectid = mmfs.miscfeescheobjid
                 WHERE mmfs.modifyfeeobjectid = a_objectid;
            END IF;

            IF a_islicfeeschedule = 'Y' THEN
                t_temp   :=
                    api.pkg_relationshipupdate.new(
                        api.pkg_configquery.endpointidforname('o_fee', 'LicenseFeeSchedule'),
                        t_feeid,
                        t_tofeeschobjid);
                api.pkg_columnupdate.setvalue(t_temp, 'IsMaster', t_ismaster);
                api.pkg_columnupdate.setvalue(t_temp, 'SecondaryCount', t_secondarycount);
                api.pkg_columnupdate.setvalue(t_temp, 'MasterLT', t_masterlt);
            ELSE
                t_temp   :=
                    api.pkg_relationshipupdate.new(api.pkg_configquery.endpointidforname('o_fee', 'MiscFeeSchedule'),
                                                   t_feeid,
                                                   t_tofeeschobjid);
                api.pkg_columnupdate.setvalue(t_feeid, 'UnitAmount', t_unitamount);
            END IF;

            t_temp          :=
                api.pkg_feeupdate.adjust(api.pkg_columnquery.VALUE(t_feeid, 'FeeId'),
                                         (NVL(t_amount, 0) - NVL(t_feeamount, 0)),
                                         'Modify Fee - Modify',
                                         SYSDATE);

            t_totalowing2   := api.pkg_columnquery.numericvalue(t_feeid, 'TotalOwing');

            -- For the Fee that is being modified, check if the job is a LT. If so, create and complete the Receive Payments process
            t_feejobid      := api.pkg_columnquery.numericvalue(t_feeid, 'JobId');

            IF api.pkg_columnquery.VALUE(t_feejobid, 'ObjectDefName') = 'j_LicenseType' THEN
                /* t_ProcessId := api.pkg_ProcessUpdate.New(t_FeeJobId,
                api.pkg_ConfigQuery.ObjectDefIdForName('p_ReceivePayment'),
                null,
                sysdate,
                sysdate,
                sysdate);*/

                -- Process update batch flags
                IF t_totalowing1 <= 0
               AND t_totalowing2 > 0 THEN
                    -- Call process procedure
                    pkg_fees.processnegativepayment(a_feeid => t_feeid, a_jobid => t_feejobid);
                    NULL;
                END IF;
            END IF;
        END IF;
    END modifyfee;

    ------------------------------------------------------------
    -- SetPaymentMethod()
    -- This will run on change of the Payment Method
    ------------------------------------------------------------
    PROCEDURE setpaymentmethod(a_objectid      udt_id,
                               a_asofdate      DATE,
                               a_paymentmethodcode VARCHAR2,
                               a_paymentid     udt_id)
    AS
        t_unpaymentobjid        udt_id;
        t_paytransobjectdefid   udt_id := api.pkg_configquery.objectdefidforname('o_PaymentTransactions');
    BEGIN
        -- Update negative payment from payment transfer if it exists
        BEGIN
            SELECT UNIQUE a.paymentobjectid
              INTO t_unpaymentobjid
              FROM api.paymenttransactions pt
                   JOIN api.registeredexternalobjects reo  --TAyers: PIP Task 8.5
                   ON reo.linkvalue = TO_CHAR(pt.transactionid)
                  AND reo.objectdefid = t_paytransobjectdefid
                   JOIN query.r_paymenttransfertrans r
                   ON r.paymenttransactionobjectid = reo.objectid
                   JOIN query.p_paymenttransfer t
                   ON t.objectid = r.paymenttransferprocessid
                   JOIN query.r_paytransferadjusting a
                   ON a.paymenttranserprocessid = t.objectid
             WHERE pt.paymentid = a_paymentid
               AND r.amount < 0;

            -- Update the negative payment from the payment transfer
            pkg_fees.updatepaymethodrel(t_unpaymentobjid, a_paymentmethodcode);
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                NULL;
        END;

        -- Update Transferred Payments
        pkg_fees.updatetranstopayment(a_paymentid,
                                      NULL,
                                      NULL,
                                      a_paymentmethodcode);
        pkg_fees.updatetransfrompayment(a_paymentid,
                                        NULL,
                                        NULL,
                                        a_paymentmethodcode);
    END setpaymentmethod;

    --------------------------------

    --------------------------------

    ----------------------------------------------------------
    -- UpdatePayMethodRel()
    -- This procedure updates the Payment Method relationship on a Payment.
    -- This is separated out into another procedure to prevent
    -- duplication because this code is called multiple times.
    ----------------------------------------------------------
    PROCEDURE updatepaymethodrel(a_objectid udt_id, a_code VARCHAR2)
    AS
        t_relid   NUMBER;
    BEGIN
        -- Remove the old rel
        SELECT r.relationshipid
          INTO t_relid
          FROM query.r_paymentpaymentmethod r
         WHERE r.paymentobjectid = a_objectid;

        api.pkg_relationshipupdate.remove(t_relid);
        -- Create the new rel
        t_relid   :=
            api.pkg_relationshipupdate.new(api.pkg_configquery.endpointidforname('o_Payment', 'PaymentMethod'),
                                           a_objectid,
                                           api.pkg_simplesearch.objectbyindex('o_PaymentMethod', 'Code', a_code));
    END updatepaymethodrel;

    ------------------------------------------------------------
    -- SetPayeeReference()
    -- This will run on change of PayeeReference
    ------------------------------------------------------------
    PROCEDURE setpayeereference(a_paymentid udt_id, a_payeereference VARCHAR2, a_receiptnumber VARCHAR2)
    AS
        t_unpaymentid           udt_id;
        t_paytransobjectdefid   udt_id := api.pkg_configquery.objectdefidforname('o_PaymentTransactions');
    BEGIN
        api.pkg_paymentupdate.modify(a_paymentid, a_payeereference, a_receiptnumber);

        BEGIN
            SELECT UNIQUE p.paymentid
              INTO t_unpaymentid
              FROM api.paymenttransactions pt
                   JOIN api.registeredexternalobjects reo  --TAyers: PIP Task 8.5
                   ON reo.linkvalue = TO_CHAR(pt.transactionid)
                  AND reo.objectdefid = t_paytransobjectdefid
                   JOIN query.r_paymenttransfertrans r
                   ON r.paymenttransactionobjectid = reo.objectid
                   JOIN query.p_paymenttransfer t
                   ON t.objectid = r.paymenttransferprocessid
                   JOIN query.r_paytransferadjusting a
                   ON a.paymenttranserprocessid = t.objectid
                   JOIN query.o_payment p
                   ON p.objectid = a.paymentobjectid
             WHERE pt.paymentid = a_paymentid
               AND r.amount < 0;

            -- Update the negative payment from the payment transfer
            api.pkg_paymentupdate.modify(t_unpaymentid, a_payeereference, a_receiptnumber);
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                NULL;
        END;

        -- Update transferred payments
        pkg_fees.updatetranstopayment(a_paymentid, a_payeereference, a_receiptnumber);
        pkg_fees.updatetransfrompayment(a_paymentid, a_payeereference, a_receiptnumber);
    END setpayeereference;

    ------------------------
    PROCEDURE updatetranstopayment(a_paymentid     udt_id,
                                   a_payeereference VARCHAR2 DEFAULT NULL,
                                   a_receiptnumber VARCHAR2 DEFAULT NULL,
                                   a_paymentmethod VARCHAR2 DEFAULT NULL)
    AS
        t_unpaymentid           udt_id;
        t_unpaymentobjid        udt_id;
        t_paytransobjectdefid   udt_id := api.pkg_configquery.objectdefidforname('o_PaymentTransactions');
    BEGIN
        -- Update transfer to Payments
        FOR c IN (SELECT t.topaymentid, t.toobjectid
                    FROM paymenttransfers_t t
                   WHERE t.frompaymentid = a_paymentid)
        LOOP
            IF a_paymentmethod IS NULL THEN
                api.pkg_paymentupdate.modify(c.topaymentid, a_payeereference, a_receiptnumber);
            ELSE
                pkg_fees.updatepaymethodrel(c.toobjectid, a_paymentmethod);
            END IF;

            BEGIN
                SELECT UNIQUE p.paymentid, p.objectid
                  INTO t_unpaymentid, t_unpaymentobjid
                  FROM api.paymenttransactions pt
                       JOIN api.registeredexternalobjects reo  --TAyers: PIP Task 8.5
                       ON reo.linkvalue = TO_CHAR(pt.transactionid)
                      AND reo.objectdefid = t_paytransobjectdefid
                       JOIN query.r_paymenttransfertrans r
                       ON r.paymenttransactionobjectid = reo.objectid
                       JOIN query.p_paymenttransfer t
                       ON t.objectid = r.paymenttransferprocessid
                       JOIN query.r_paytransferadjusting a
                       ON a.paymenttranserprocessid = t.objectid
                       JOIN query.o_payment p
                       ON p.objectid = a.paymentobjectid
                 WHERE pt.paymentid = c.topaymentid
                   AND r.amount < 0;

                -- Update the negative payment from the payment transfer
                IF a_paymentmethod IS NULL THEN
                    api.pkg_paymentupdate.modify(t_unpaymentid, a_payeereference, a_receiptnumber);
                ELSE
                    pkg_fees.updatepaymethodrel(t_unpaymentobjid, a_paymentmethod);
                END IF;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    NULL;
            END;

            -- Update transferred payments
            pkg_fees.updatetranstopayment(c.topaymentid,
                                          a_payeereference,
                                          a_receiptnumber,
                                          a_paymentmethod);
        END LOOP;
    END updatetranstopayment;

    ------------------------
    PROCEDURE updatetransfrompayment(a_paymentid     udt_id,
                                     a_payeereference VARCHAR2 DEFAULT NULL,
                                     a_receiptnumber VARCHAR2 DEFAULT NULL,
                                     a_paymentmethod VARCHAR2 DEFAULT NULL)
    AS
        t_unpaymentid           udt_id;
        t_unpaymentobjid        udt_id;
        t_paytransobjectdefid   udt_id := api.pkg_configquery.objectdefidforname('o_PaymentTransactions');
    BEGIN
        -- Update transfer from Payments
        FOR c IN (SELECT t.frompaymentid, t.fromobjectid
                    FROM paymenttransfers_t t
                   WHERE t.topaymentid = a_paymentid)
        LOOP
            IF a_paymentmethod IS NULL THEN
                api.pkg_paymentupdate.modify(c.frompaymentid, a_payeereference, a_receiptnumber);
            ELSE
                pkg_fees.updatepaymethodrel(c.fromobjectid, a_paymentmethod);
            END IF;

            BEGIN
                SELECT paymentid, objectid
                  INTO t_unpaymentid, t_unpaymentobjid
                  FROM (  SELECT UNIQUE p.paymentid, p.objectid
                            FROM api.paymenttransactions pt
                                 JOIN api.registeredexternalobjects reo  --TAyers: PIP Task 8.5
                                 ON reo.linkvalue = TO_CHAR(pt.transactionid)
                                AND reo.objectdefid = t_paytransobjectdefid
                                 JOIN query.r_paymenttransfertrans r
                                 ON r.paymenttransactionobjectid = reo.objectid
                                 JOIN query.p_paymenttransfer t
                                 ON t.objectid = r.paymenttransferprocessid
                                 JOIN query.r_paytransferadjusting a
                                 ON a.paymenttranserprocessid = t.objectid
                                 JOIN query.o_payment p
                                 ON p.objectid = a.paymentobjectid
                           WHERE pt.paymentid = c.frompaymentid
                             AND r.amount < 0
                        ORDER BY 1) x
                 WHERE ROWNUM = 1;

                -- Update the negative payment from the payment transfer
                IF a_paymentmethod IS NULL THEN
                    api.pkg_paymentupdate.modify(t_unpaymentid, a_payeereference, a_receiptnumber);
                ELSE
                    pkg_fees.updatepaymethodrel(t_unpaymentobjid, a_paymentmethod);
                END IF;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    NULL;
            END;

            -- Update transferred payments
            pkg_fees.updatetransfrompayment(c.frompaymentid,
                                            a_payeereference,
                                            a_receiptnumber,
                                            a_paymentmethod);
        END LOOP;
    END updatetransfrompayment;

    ------------------------------------------------
    -- GetLicFeeScheduleObjId()
    -- This Function will return the License Fee Schedule ObjectId for a FeeId passed it.
    -- This Function is used in the Accounting History Report and The Renewal List's
    -- Financial section.
    ------------------------------------------------
    FUNCTION getlicfeeschedulobjid(a_feeid udt_id)
        RETURN udt_id
    IS
        t_licfeescheduleobjid   udt_id;
        t_feeobjectid           udt_id;
        t_endpointid            udt_id;
    BEGIN
        t_feeobjectid   := api.pkg_simplesearch.objectbyindex('o_Fee', 'FeeId', a_feeid);
        t_endpointid    := api.pkg_configquery.endpointidforname('o_Fee', 'LicenseFeeSchedule');

        SELECT r.toobjectid
          INTO t_licfeescheduleobjid
          FROM api.relationships r
         WHERE r.fromobjectid = t_feeobjectid
           AND r.endpointid = t_endpointid;

        RETURN t_licfeescheduleobjid;
    END getlicfeeschedulobjid;

    FUNCTION getmiscfeeschedulobjid(a_feeid udt_id)
        RETURN udt_id
    IS
        t_miscfeescheduleobjid   udt_id;
        t_feeobjectid            udt_id;
        t_endpointid             udt_id;
    BEGIN
        t_feeobjectid   := api.pkg_simplesearch.objectbyindex('o_Fee', 'FeeId', a_feeid);
        t_endpointid    := api.pkg_configquery.endpointidforname('o_Fee', 'MiscFeeSchedule');

        SELECT r.toobjectid
          INTO t_miscfeescheduleobjid
          FROM api.relationships r
         WHERE r.fromobjectid = t_feeobjectid
           AND r.endpointid = t_endpointid;

        RETURN t_miscfeescheduleobjid;
    END getmiscfeeschedulobjid;

    ----------------------------------------------------------------------------------------------------
    -- CreateIssueInterimPermitRenewalFee() -- PUBLIC
    -- Charges fee for Issue Interim Retail Permit Renewal process WO 18109 IPTR Fee Change  Pawan 5/21/2019
    -- 07/17/2019  PK  WO 18109 below procedure is deprecated
    ----------------------------------------------------------------------------------------------------

    PROCEDURE createinterimpermitrenewalfee(a_objectid NUMBER, a_asofdate DATE, a_jobid NUMBER)
    IS
        t_createfee              VARCHAR2(1);
        t_createsfee             VARCHAR2(1);
        t_description            VARCHAR2(100);
        t_proceduredescription   VARCHAR2(100);
        t_feeid                  NUMBER;
        t_feeobjid               NUMBER;
        t_sfeeid                 NUMBER;
        t_sfeeobjid              NUMBER;
        t_feeschedid             NUMBER;
        t_sfeeschedid            NUMBER;
        t_glaccountid            NUMBER;
        t_relid                  NUMBER;
        t_pamount                NUMBER;
        t_sfeeamount             NUMBER;
        t_primissec              VARCHAR2(1);
        t_ismaster               VARCHAR2(1);
    BEGIN
        --Get GLAccountId
        SELECT g.glaccountid
          INTO t_glaccountid
          FROM api.glaccounts g
         WHERE g.glaccount = 'IPTR';

        --Primary LT Loop
        FOR x IN (SELECT plt.objectid                                                      pltobjectid,
                         ltc.licensetypecode,
                         CASE WHEN plt.masterlicensetype IS NOT NULL THEN 'B' ELSE 'P' END primorbranch,
                         plt.secondaryltobjectids
                    FROM query.r_appprimarylicensetype aplt
                         JOIN query.o_primarylicensetype plt
                         ON aplt.licensetypeobjectid = plt.objectid
                         JOIN query.r_priltltcatprimary pltltc
                         ON plt.objectid = pltltc.primarylicensetypeobjectid
                         JOIN query.o_licensetypecategory ltc
                         ON pltltc.licensetypecategoryobjectid = ltc.objectid
                   WHERE aplt.applicationobjectid = a_jobid)
        LOOP
            -- Set t_CreateFee to 'Y'
            t_createfee   := 'Y';

            --Get Fee Amount and Fee ScheduleId
            sitespecific.pkg_fees.getltfeeamount(a_jobid,
                                                 SYSDATE,
                                                 'IPTR',
                                                 NULL,
                                                 x.licensetypecode,
                                                 NULL,
                                                 NULL,
                                                 NULL,
                                                 NULL,
                                                 x.primorbranch,
                                                 NULL,
                                                 a_asofdate,
                                                 t_pamount,
                                                 t_feeschedid);

            --Secondary LT loop
            FOR z IN (SELECT sltc.licensetypecount, ltc.licensetypecode
                        FROM query.r_priltltcatsecondary sltc
                             JOIN query.o_licensetypecategory ltc
                             ON sltc.licensetypecategoryobjectid = ltc.objectid
                       WHERE sltc.primarylicensetypeobjectid = x.pltobjectid)
            LOOP
                -- Set t_CreateSFee to 'Y'
                t_createsfee   := 'Y';

                --Get Fee Amount and Fee ScheduleId
                sitespecific.pkg_fees.getltfeeamount(a_jobid,
                                                     SYSDATE,
                                                     'IPTR',
                                                     NULL,
                                                     z.licensetypecode,
                                                     NULL,
                                                     NULL,
                                                     NULL,
                                                     NULL,
                                                     'S',
                                                     z.licensetypecount,
                                                     a_asofdate,
                                                     t_sfeeamount,
                                                     t_sfeeschedid);

                IF t_sfeeamount >= 0 THEN
                    --Set Description
                    --If Secondary ltc is Primary ltc
                    IF z.licensetypecode = x.licensetypecode  --Set Description, Amount, IsMaster, and PrimIsSec for secondary that is also primary
                                                              --Some of this below is out dated 2009_3_19 the is master detail setting is just fine though
                     THEN
                        t_primissec     := 'Y';
                        t_sfeeamount    := t_sfeeamount + t_pamount;
                        t_ismaster      := 'Y';
                        t_sfeeschedid   := t_feeschedid;  --so that relationship is to the primaryLTfeeschedule record.
                    --else Set IsMaster for normal secondary
                    ELSE
                        t_ismaster   := 'N';
                    END IF;

                    --Set Description
                    t_proceduredescription   := api.pkg_columnquery.VALUE(t_sfeeschedid, 'ProcedureDescription');

                    -- Check existing Fees
                    sitespecific.pkg_fees.checkexistingfees('Y',
                                                            t_proceduredescription,
                                                            'N',
                                                            'IPTR',
                                                            NULL,
                                                            t_sfeeamount,
                                                            t_sfeeschedid,
                                                            NULL,
                                                            t_glaccountid,
                                                            'Y',
                                                            t_ismaster,
                                                            a_jobid,
                                                            z.licensetypecode,
                                                            z.licensetypecount,
                                                            NULL,
                                                            NULL,
                                                            NULL,  --  03/29/2019 TJL WO 17566
                                                            x.secondaryltobjectids,
                                                            t_createsfee,
                                                            t_feeid);

                    -- If t_CreateSFee = 'Y'
                    IF t_createsfee = 'Y' THEN
                        -- Then Create Fee
                        sitespecific.pkg_fees.newfee(t_sfeeid,
                                                     t_sfeeamount,
                                                     t_proceduredescription,
                                                     t_glaccountid,
                                                     a_jobid,
                                                     NULL,
                                                     t_sfeeobjid);

                        --Relate Fee to Fee Schedule
                        t_relid   :=
                            api.pkg_relationshipupdate.new(
                                api.pkg_configquery.endpointidforname('o_Fee', 'LicenseFeeSchedule'),
                                t_sfeeobjid,
                                t_sfeeschedid);

                        -- Set the relationship detail IsMaster
                        api.pkg_columnupdate.setvalue(t_relid, 'IsMaster', t_ismaster);
                        -- Set the relationship detail SecondaryCount to the count of secondary LTs
                        api.pkg_columnupdate.setvalue(t_relid, 'SecondaryCount', z.licensetypecount);
                        -- Set the relationship detail MasterLT to the Primary LT Code
                        api.pkg_columnupdate.setvalue(t_relid, 'MasterLT', x.licensetypecode);
                        -- Set the Quantity on the Fee Object
                        api.pkg_columnupdate.setvalue(t_sfeeobjid, 'Quantity', z.licensetypecount);
                    -- End If
                    END IF;
                END IF;
            END LOOP;  --secondary loop

            --Continue Primary loop
            --if Primary is Retail, but not retail permit and its fee was not already charged in the secondary loop (when secondary and primary are the same)
            IF t_pamount >= 0
           AND (t_primissec IS NULL
             OR t_primissec <> 'Y') THEN
                --Set Procedure Description
                t_proceduredescription   := api.pkg_columnquery.VALUE(t_feeschedid, 'ProcedureDescription');

                --Set Description
                t_description            :=  --x.licensetypecode || ' - Primary, '|| --out dated 2009_3_19
                                            t_proceduredescription;

                -- Check existing Fees
                sitespecific.pkg_fees.checkexistingfees('Y',
                                                        t_description,
                                                        'N',
                                                        'IPTR',
                                                        NULL,
                                                        t_pamount,
                                                        t_feeschedid,
                                                        NULL,
                                                        t_glaccountid,
                                                        'N',
                                                        'Y',
                                                        a_jobid,
                                                        x.licensetypecode,
                                                        0,
                                                        NULL,
                                                        NULL,
                                                        NULL,  --  03/29/2019 TJL WO 17566
                                                        x.secondaryltobjectids,
                                                        t_createfee,
                                                        t_feeid);

                -- If t_CreateFee = 'Y'
                IF t_createfee = 'Y' THEN
                    -- Then Create Fee
                    sitespecific.pkg_fees.newfee(t_feeid,
                                                 t_pamount,
                                                 t_description,
                                                 t_glaccountid,
                                                 a_jobid,
                                                 NULL,
                                                 t_feeobjid);

                    --Relate Fee to Fee Schedule
                    t_relid   :=
                        api.pkg_relationshipupdate.new(
                            api.pkg_configquery.endpointidforname('o_Fee', 'LicenseFeeSchedule'),
                            t_feeobjid,
                            t_feeschedid);

                    -- Set the relationship detail IsMaster to 'N'
                    api.pkg_columnupdate.setvalue(t_relid, 'IsMaster', 'Y');
                -- End If
                END IF;
            END IF;

            --Set Primary Equals secondary to N for next primary loop.
            t_primissec   := 'N';
        END LOOP;  --primary loop
    END createinterimpermitrenewalfee;
END pkg_fees;
/


GRANT EXECUTE ON SITESPECIFIC.PKG_FEES TO ABC;

GRANT EXECUTE ON SITESPECIFIC.PKG_FEES TO ABCREPORTS;

GRANT EXECUTE, DEBUG ON SITESPECIFIC.PKG_FEES TO BIZMOD_API;

GRANT EXECUTE ON SITESPECIFIC.PKG_FEES TO CONV;

GRANT EXECUTE ON SITESPECIFIC.PKG_FEES TO LASSO;

GRANT EXECUTE ON SITESPECIFIC.PKG_FEES TO POSSEEXTENSIONS;
