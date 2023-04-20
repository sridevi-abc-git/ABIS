CREATE OR REPLACE PACKAGE BODY SITESPECIFIC.pkg_dishonor
AS
    -- **************************************************************************
    -- File:        PKG_DISHONOR.pb
    -- Author:      CX
    --
    -- $Rev$
    -- $Date$
    -- Last Changed By:  $Author$
    --
    -- Description:
    --
    --
    -- History:
    -----------------------------------------------------------------------------
    --    Date                  Comment
    -- 08/16/2018 TJL         Initial Check-in
    -- **************************************************************************

    --*------------------------------------------------------------------------------------------------
    --* SetDepositRelationships() -- PUBLIC
    --* This procedure relates the Transmittal job and the Payment Batch job to the Deposit job
    --* when the Transmittal and Payment Batch jobs are not currently related to a Deposit job of type
    --* Cash or Check and when the Transmittal and Payment Batch jobs are in the Complete status.
    --*------------------------------------------------------------------------------------------------
    PROCEDURE setexternalfilenum(a_objectid udt_id, a_asofdate DATE)
    IS
        t_externalfilenum   VARCHAR2(20);
        t_batchid           VARCHAR2(20);
    BEGIN
        t_batchid   := api.pkg_columnquery.VALUE(a_objectid, 'BatchId');
        t_externalfilenum   :=
            api.pkg_columnquery.VALUE(a_objectid, 'ExternalFileNum');

        IF t_externalfilenum <> t_batchid
        OR t_externalfilenum IS NULL
        OR t_batchid IS NULL THEN
            api.pkg_jobupdate.setexternalfilenum(a_objectid, t_batchid);
        END IF;
    END setexternalfilenum;

    --*------------------------------------------------------------------------------------------------
    --* Cancel Dishonor Payment(s) Job
    --*------------------------------------------------------------------------------------------------
    PROCEDURE canceldishonorjob(a_objectid      udt_id,
                                a_asofdate      DATE,
                                a_jobid         udt_id)
    IS
        t_processdefid       udt_id;
        t_newchangeprocess   udt_id;
        t_status             VARCHAR2(60)
            := api.pkg_columnquery.VALUE(a_jobid, 'StatusDescription');
    BEGIN
        t_processdefid   :=
            api.pkg_configquery.objectdefidforname('p_ChangeStatus');
        t_newchangeprocess   :=
            api.pkg_processupdate.new(a_jobid,
                                      t_processdefid,
                                      'System Generated Process',
                                      NULL,
                                      NULL,
                                      NULL);
        api.pkg_processupdate.complete(t_newchangeprocess, 'Canceled');
    END canceldishonorjob;

    --*------------------------------------------------------------------------------------------------
    --* Dishonor Payments
    --*  Run on completion of the Verify Dishonor Payment(s) Job.
    --*------------------------------------------------------------------------------------------------
    PROCEDURE dishonorpayments(a_objectid      udt_id,
                               a_asofdate      DATE,
                               a_jobid         udt_id)
    IS
        t_newpaymentstatus        udt_id;
        t_relid                   udt_id;
        t_paymentobjectid         udt_id;
        t_unpaymentid             udt_id;
        t_paymentjobid            udt_id;

        t_paytransobjectid        udt_id;
        t_transactionobjid        udt_id;
        t_methodid                udt_id;
        t_defaultofficeobjectid   udt_id;
        t_earnedamount            NUMBER;

        t_origfeeid               udt_idlist;
        t_origamounts             udt_numberlist;
        t_ovrs                    udt_numberlist;
        t_paymentids              udt_idlist;
        t_srvs                    udt_numberlist;
        t_temp                    VARCHAR2(1);
        t_tempnum1                NUMBER;
        t_tempnum2                NUMBER;
        t_batchdate               DATE
            := api.pkg_columnquery.datevalue(a_jobid, 'BatchDate');
        t_paytransobjectdefid     udt_id
            := api.pkg_configquery.objectdefidforname(
                   'o_PaymentTransactions');
    BEGIN
        -- Loop through the payments to be dishonored in the system.
        FOR c
            IN (SELECT dpp.paymentobjectid,
                       p.paymentid,
                       p.paymentamount,
                       p.payeereference,
                       p.receiptnumber,
                       p.payeename,
                       p.payeeaddress,
                       p.isreceipted,
                       p.batchpaymentid,
                       p.hqreceiptlookup
                  FROM query.r_dishonorpaymentpayment  dpp
                       JOIN query.o_payment p
                           ON p.objectid = dpp.paymentobjectid
                 WHERE dpp.dishonorpaymentjobid = a_jobid)
        LOOP
            -- Clear Fee/Payment collections
            t_paymentids.delete;
            t_origfeeid.delete;
            t_origamounts.delete;
            t_ovrs.delete;
            t_srvs.delete;
            t_tempnum1   := NULL;
            t_tempnum2   := NULL;

            -- Set the Is Dihonored on the Original Payment to 'Y'
            api.pkg_columnupdate.setvalue(c.paymentobjectid,
                                          'IsDishonored',
                                          'Y');

            -- Get all the PaymentIds that will be dishonored, and the FeeIds and Amounts for the negative payments
            pkg_dishonor.dishonorpaymentcandidateswrap(c.paymentobjectid,
                                                       t_paymentids,
                                                       t_origfeeid,
                                                       t_origamounts,
                                                       t_ovrs,
                                                       t_srvs,
                                                       t_tempnum1,
                                                       t_tempnum2);

            --Adjust Payment off of original Fee
            t_unpaymentid   :=
                api.pkg_paymentupdate.new(SYSDATE,
                                          t_origfeeid,
                                          t_origamounts);

            --Register Un-Payment
            t_paymentobjectid   :=
                api.pkg_objectupdate.registerexternalobject('o_Payment',
                                                            t_unpaymentid);
            --Copy Details from the original payment to the new payment

            --Copy the Payee Reference (PaymentID) and Receipt Number
            api.pkg_paymentupdate.modify(t_unpaymentid,
                                         c.payeereference,
                                         c.receiptnumber);
            api.pkg_columnupdate.setvalue(t_paymentobjectid,
                                          'BatchPaymentId',
                                          c.batchpaymentid);
            api.pkg_columnupdate.setvalue(t_paymentobjectid,
                                          'IsReceiptedStored',
                                          c.isreceipted);

            --Set the Payee information on the new Payment
            api.pkg_columnupdate.setvalue(t_paymentobjectid,
                                          'PayeeAddressStored',
                                          c.payeeaddress);
            api.pkg_columnupdate.setvalue(t_paymentobjectid,
                                          'PayeeNameStored',
                                          c.payeename);

            --Set the *.Stored details
            api.pkg_columnupdate.setvalue(t_paymentobjectid,
                                          'PaymentDateStored',
                                          TRUNC(SYSDATE));
            api.pkg_columnupdate.setvalue(
                t_paymentobjectid,
                'PaymentAmountStored',
                api.pkg_columnquery.VALUE(t_paymentobjectid,
                                          'PaymentAmountforDisplay'));



            -- Set the CABINIncomeInd to 'D'
            api.pkg_columnupdate.setvalue(t_paymentobjectid,
                                          'CABINIncomeInd',
                                          'D');

            --Set the Payment Method
            SELECT r.paymentmethodobjectid
              INTO t_methodid
              FROM query.r_paymentpaymentmethod r
             WHERE r.paymentobjectid = c.paymentobjectid; --t_OrigPaymentObjId;

            t_relid      :=
                api.pkg_relationshipupdate.new(
                    api.pkg_configquery.endpointidforname('o_Payment',
                                                          'PaymentMethod'),
                    t_paymentobjectid,
                    t_methodid);


            --Create a relationship to the Original Payment's Office
            BEGIN
                SELECT po.officeobjectid
                  INTO t_defaultofficeobjectid
                  FROM query.r_paymentoffice po
                 WHERE po.paymentobjectid = c.paymentobjectid;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    t_defaultofficeobjectid   := NULL;
            END;

            IF t_defaultofficeobjectid IS NOT NULL THEN
                t_relid   :=
                    api.pkg_relationshipupdate.new(
                        api.pkg_configquery.endpointidforname('o_Office',
                                                              'Payment'),
                        t_defaultofficeobjectid,
                        t_paymentobjectid);
            END IF;

            -- Relate the Payment to the Dishonor Job as the Dishonoring Payment.
            t_relid      :=
                api.pkg_relationshipupdate.new(
                    api.pkg_configquery.endpointidforname('o_Payment',
                                                          'Dishonor'),
                    t_paymentobjectid,
                    a_jobid);

            -- For each Payment Transaction for the Payment that was just created, register the external Payment Transaction and Fee Transaction
            FOR c_1
                IN (SELECT pt.transactionid, ft.feeid, ROWNUM
                      FROM api.paymenttransactions  pt
                           JOIN api.feetransactions ft
                               ON ft.transactionid = pt.transactionid
                     WHERE pt.paymentid = t_unpaymentid)
            LOOP
                t_paytransobjectid   :=
                    api.pkg_objectupdate.registerexternalobject(
                        'o_PaymentTransactions',
                        c_1.transactionid);
                t_transactionobjid   :=
                    api.pkg_objectupdate.registerexternalobject(
                        'o_FeeTransactions',
                        c_1.transactionid);

                --Set the HQ receipt number to the dishonored payments HQ Receipt Number
                api.pkg_columnupdate.setvalue(t_paytransobjectid,
                                              'HqReceipt',
                                              c.hqreceiptlookup);

                --Set the Payment Transaction to OVR if dishonored transaction was an OVR
                SELECT CASE WHEN t_ovrs(c_1.ROWNUM) = 1 THEN 'Y' ELSE 'N' END
                  INTO t_temp
                  FROM DUAL;

                api.pkg_columnupdate.setvalue(t_paytransobjectid,
                                              'ISOverPayment',
                                              t_temp);

                --Set the Payment Transaction to SRV if dishonored transaction was an SRV
                SELECT CASE WHEN t_srvs(c_1.ROWNUM) = 1 THEN 'Y' ELSE 'N' END
                  INTO t_temp
                  FROM DUAL;

                api.pkg_columnupdate.setvalue(t_paytransobjectid,
                                              'ISServiceCharge',
                                              t_temp);


                -- Set the amount type for the payment transactions to 'D'
                api.pkg_columnupdate.setvalue(t_paytransobjectid,
                                              'CABINAmtType',
                                              'D');
            END LOOP;

            FOR x IN 1 .. t_paymentids.COUNT
            LOOP
                FOR c_2 IN (SELECT reo.objectid
                              FROM api.paymenttransactions  pt
                                   JOIN api.registeredexternalobjects reo --TAyers: PIP Task 8.5
                                       ON reo.linkvalue =
                                          TO_CHAR(pt.transactionid)
                                      AND reo.objectdefid =
                                          t_paytransobjectdefid
                             WHERE pt.paymentid = t_paymentids(x))
                LOOP
                    -- If it was Earned.
                    IF api.pkg_columnquery.VALUE(
                           api.pkg_columnquery.numericvalue(
                               c_2.objectid,
                               'PaymentStatusObjectId'),
                           'Status') =
                       'EARNED' THEN
                        -- Get the amount to unearn
                        t_earnedamount   :=
                            -api.pkg_columnquery.VALUE(
                                 api.pkg_columnquery.numericvalue(
                                     c_2.objectid,
                                     'PaymentStatusObjectId'),
                                 'EarnedAmount');
                        --Unearn the transaction
                        t_newpaymentstatus   :=
                            api.pkg_objectupdate.new(
                                api.pkg_configquery.objectdefidforname(
                                    'o_PaymentStatus'));
                        t_relid   :=
                            api.pkg_relationshipupdate.new(
                                api.pkg_configquery.endpointidforname(
                                    'o_PaymentStatus',
                                    'PaymentTransactions'),
                                t_newpaymentstatus,
                                c_2.objectid);
                        api.pkg_columnupdate.setvalue(t_newpaymentstatus,
                                                      'Status',
                                                      'UNEARNED');
                        api.pkg_columnupdate.setvalue(t_newpaymentstatus,
                                                      'StatusDate',
                                                      TRUNC(SYSDATE));
                        api.pkg_columnupdate.setvalue(t_newpaymentstatus,
                                                      'SystemGenerated',
                                                      'Y');
                        api.pkg_columnupdate.setvalue(t_newpaymentstatus,
                                                      'EarnedAmount',
                                                      t_earnedamount);
                    END IF;
                END LOOP;

                -- Set the Batch Flags when appropriately to allow for
                -- Recalculation of the REN fees and Auto Revoke if necessary
                --sitespecific.pkg_Dishonor.DishonorBatchFlags(c.Paymentobjectid, t_BatchDate);
                ---- Commented by Pawan to create dishonor payments for March 2023 paymen tcorrections
                pkg_fees.processnegativepayment( 
                  a_paymentid => t_paymentids(x)); 
            END LOOP;

            --Create 'CHK' fees for the Job the Dishonored Payment Appears on
            SELECT MAX(jobid)
              INTO t_paymentjobid
              FROM api.payments  p
                   JOIN api.paymenttransactions pt
                       ON pt.paymentid = p.paymentid
                   JOIN api.feetransactions ft
                       ON ft.transactionid = pt.transactionid
                   JOIN api.fees f ON f.feeid = ft.feeid
             WHERE p.paymentid = c.paymentid;

            -- Add the CHK Fees for each Payment
            sitespecific.pkg_fees.createsimplefee(c.paymentobjectid,
                                                  a_asofdate,
                                                  t_paymentjobid,
                                                  'CHK',
                                                  1);
                                                  -- Commented by Pawan to create dishonor payments for March 2023 paymen tcorrections
        END LOOP;                                          -- End Payment Loop
    END dishonorpayments;

    --*------------------------------------------------------------------------------------------------
    --* DishonorBatchFlags
    -- Set the Batch Flags on the License Type Job to Include the Type in the next step
    -- if it is past a due date.
    --*------------------------------------------------------------------------------------------------

    PROCEDURE dishonorbatchflags(a_paymentobjectid udt_id, a_batchdate DATE)
    IS
        t_changeprocessid    udt_id;
        t_licensetypedefid   udt_id
            := api.pkg_configquery.objectdefidforname('j_LicenseType');
        t_expmon             query.j_licensetype.expiringmonth%TYPE;
    BEGIN
        --Loop through distinct License Job Ids from the fee.
        --Using the Max Expiration, Renewal, Last50%, and Last100% dates because they will be the most accurate.
        FOR c
            IN (  SELECT f.jobid,
                         concatlist(pt.licensenumber)
                             licenseexternalfilenum,
                         concatlist(pt.licensetypecode)
                             licensetypecode,
                         MAX(qf.renexpirationdate)
                             renexpirationdate,
                         api.pkg_utils.dateplusworkdays(
                             MAX(qf.renexpirationdate),
                             0)
                             renewaldate,
                         api.pkg_utils.dateplusworkdays(
                             MAX(qf.renexpirationdate) + 60,
                             0)
                             late50date,
                         api.pkg_utils.dateplusworkdays(
                             MAX(qf.renexpirationdate) + 90,
                             0)
                             late100date
                    FROM query.o_payment p
                         JOIN api.paymenttransactions apt
                             ON apt.paymentid = p.paymentid
                         JOIN query.o_paymenttransactions pt
                             ON pt.objectid =
                                api.pkg_simplesearch.objectbyindex(
                                    'o_PaymentTransactions',
                                    'TransactionId',
                                    apt.transactionid)
                         JOIN api.feetransactions aft
                             ON aft.transactionid = apt.transactionid
                         JOIN api.fees f ON f.feeid = aft.feeid
                         JOIN api.jobs j ON j.jobid = f.jobid
                         JOIN query.o_fee qf
                             ON qf.objectid =
                                api.pkg_simplesearch.objectbyindex('o_fee',
                                                                   'FeeId',
                                                                   f.feeid)
                         JOIN sitespecific.feeschedule_t fs
                             ON fs.objectid =
                                sitespecific.pkg_fees.getlicfeeschedulobjid(
                                    f.feeid)
                   WHERE p.objectid = a_paymentobjectid
                     AND pt.licensetypecode IS NOT NULL
                     AND pt.licensenumber IS NOT NULL
                     AND fs.feeactivity IN ('REN', 'REN50', 'REN100')
                     AND j.jobtypeid = t_licensetypedefid
                GROUP BY f.jobid)
        LOOP
            --For each JobId check their Batch Flags and update accordingly.
            -- For Each License Type Jobid
            IF a_batchdate BETWEEN c.renewaldate AND c.late50date THEN
                --include in Second Renewal
                pkg_batchtype.setbatchflags(a_lictypejobid => c.jobid, --c_2.Licensetypejobid,
                                            a_includein2ndrenewal => 'Y');
            ELSIF a_batchdate BETWEEN c.late50date AND c.late100date THEN
                --Include in Final Rev. Pending
                pkg_batchtype.setbatchflags(
                    a_lictypejobid => c.jobid,         --c_2.Licensetypejobid,
                    a_includeinfinalrevpending => 'Y');
            ELSIF a_batchdate > c.late100date THEN
                --Include in Auto Revoke
                pkg_batchtype.setbatchflags(a_lictypejobid => c.jobid, --c_2.Licensetypejobid,
                                            a_includeinrevokebatch => 'Y');
                t_changeprocessid   :=
                    api.pkg_processupdate.new(
                        c.jobid,                       --c_2.Licensetypejobid,
                        api.pkg_configquery.objectdefidforname(
                            'p_ChangeStatus'),
                        'System Generated.',         --Via Dishonor Batch Job.
                        SYSDATE,
                        SYSDATE,
                        SYSDATE);
                api.pkg_processupdate.complete(t_changeprocessid,
                                               'Rev Pending');
            END IF;

            -- When the payment dishonoring changes flags the expiration date
            -- on the license Job should be current and not updated,
            -- i.e. set back to what it was before the licesne was renewed.
            IF c.renexpirationdate <
               api.pkg_columnquery.datevalue(c.jobid, 'ExpirationDate') THEN
                api.pkg_columnupdate.removevalue(c.jobid, 'ExpiringMonth');
                --Trimming is necessary since the to_char function will leave white space on the end of the word.
                t_expmon   := TRIM(TO_CHAR(c.renexpirationdate, 'MONTH'));
                api.pkg_columnupdate.setvalue(
                    c.jobid,
                    'ExpiringYear',
                    TO_CHAR(c.renexpirationdate, 'YYYY'));
                api.pkg_columnupdate.setvalue(c.jobid,
                                              'ExpiringMonth',
                                              t_expmon);
            END IF;
        END LOOP;                                     -- Loop through payments
    END dishonorbatchflags;

    --*------------------------------------------------------------------------------------------------
    --* DishonorLicensePayments
    --  This relationship gets Payments not assosiated to Misc Fee Job from the Dishonor Payment Job.
    --   And is used mainly with the Word Interface Mapping.
    --*------------------------------------------------------------------------------------------------

    PROCEDURE dishonoredlicensepayments(
        a_objectid         udt_id,
        a_endpointid       udt_id,
        a_relatedobjectids OUT api.udt_objectlist)
    IS
    BEGIN
        a_relatedobjectids   := api.udt_objectlist();

        SELECT api.udt_object(dpp.paymentobjectid)
          BULK COLLECT INTO a_relatedobjectids -- return a payment without a Misc payment transaction.
          FROM query.r_dishonorpaymentpayment dpp
         WHERE dpp.dishonorpaymentjobid = a_objectid
           AND dpp.paymentobjectid NOT IN
                   (  SELECT p.objectid
                        FROM query.o_payment p
                             JOIN api.paymenttransactions apt
                                 ON apt.paymentid = p.paymentid
                             JOIN query.o_paymenttransactions pt
                                 ON pt.objectid =
                                    api.pkg_simplesearch.objectbyindex(
                                        'o_PaymentTransactions',
                                        'TransactionId',
                                        apt.transactionid) -- might not be the best way.
                             JOIN api.feetransactions ft
                                 ON ft.transactionid = apt.transactionid
                             JOIN query.r_miscfeefeeschedule mfs
                                 ON mfs.feeobjectid =
                                    api.pkg_simplesearch.objectbyindex(
                                        'o_Fee',
                                        'FeeId',
                                        ft.feeid)
                       WHERE p.objectid = dpp.paymentobjectid
                    GROUP BY p.objectid);
    END dishonoredlicensepayments;

    /*---------------------------------------------------------------------
    -- DishonorPaymentCandidates()
    -- This is called in DishonorPaymentsWrap to process the payments to dishonor.
    -- This steps through the hierarchy of payment transfers, and gets all the
    -- fees/amounts for which a negative (dishonoring) transaction is needed.
    ---------------------------------------------------------------------*/

    PROCEDURE dishonorpaymentcandidates(
        a_paymentobjectid     udt_id,
        a_paymentids   IN OUT udt_idlist,
        a_dishonorfees IN OUT udt_idlist,
        a_dishonoramounts IN OUT udt_numberlist,
        a_ovrs         IN OUT udt_numberlist,
        a_srvs         IN OUT udt_numberlist,
        a_index        IN OUT NUMBER,
        a_pindex       IN OUT NUMBER,
        a_srv                 VARCHAR2)
    IS
        t_amounts               udt_numberlist;
        t_common                BOOLEAN;
        t_feeids                udt_idlist;
        t_ovrlist               udt_numberlist;
        t_srvlist               udt_numberlist;
        t_templista             udt_numberlist;
        t_templist              udt_idlist;
        t_topaymentid           udt_id;
        t_topaymentobjid        udt_id;
        t_tovr                  udt_numberlist;
        t_tsrv                  udt_numberlist;
        t_paytransobjectdefid   udt_id
            := api.pkg_configquery.objectdefidforname(
                   'o_PaymentTransactions');
    BEGIN
        -- loop through the transferred payments and get any that need to be dishonored
        FOR c IN (SELECT t.frompaymentid, t.toobjectid, t.topaymentid
                    FROM sitespecific.paymenttransfers_t t
                   WHERE t.fromobjectid = a_paymentobjectid
                     AND t.issrv = a_srv)
        LOOP
            t_topaymentobjid   := c.toobjectid;
            t_topaymentid      := c.topaymentid;

              -- Get any amounts to dishonor from the trans from payment that didn't get transferred
              SELECT feeid,
                     issrv,
                     isovr,
                     SUM(amount)
                BULK COLLECT INTO t_feeids,
                     t_srvlist,
                     t_ovrlist,
                     t_amounts
                FROM (SELECT DISTINCT
                             (ft.transactionid),
                             ft.feeid,
                             ft.amount,             --APatterson: PIP Task 8.5
                             CASE
                                 WHEN pt2.isservicecharge = 'Y' THEN 1
                                 ELSE 0
                             END
                                 issrv,
                             CASE
                                 WHEN pt2.isoverpayment = 'Y' THEN 1
                                 ELSE 0
                             END
                                 isovr
                        FROM api.payments p
                             JOIN api.paymenttransactions pt
                                 ON pt.paymentid = p.paymentid
                             JOIN api.feetransactions ft1
                                 ON ft1.transactionid = pt.transactionid
                             JOIN api.feetransactions ft
                                 ON ft1.feeid = ft.feeid
                             JOIN api.registeredexternalobjects reo --TAyers: PIP Task 8.5
                                 ON reo.linkvalue = TO_CHAR(ft.transactionid)
                             JOIN query.o_paymenttransactions pt2
                                 ON pt2.objectid = reo.objectid
                       WHERE p.paymentid = c.frompaymentid
                         AND ft.transactiontype = 'Pay')
            GROUP BY feeid, issrv, isovr
              HAVING SUM(amount) < 0;

            FOR x IN 1 .. t_feeids.COUNT
            LOOP
                a_index                      := a_index + 1;
                a_dishonorfees(a_index)      := t_feeids(x);
                a_dishonoramounts(a_index)   := t_amounts(x);
                a_ovrs(a_index)              := t_ovrlist(x);
                a_srvs(a_index)              := t_srvlist(x);
            END LOOP;

            IF t_feeids.FIRST IS NOT NULL THEN
                a_pindex                 := a_pindex + 1;
                a_paymentids(a_pindex)   := c.frompaymentid;
            END IF;

            -- Check for another level of transfers
            dishonorpaymentcandidateswrap(t_topaymentobjid,
                                          a_paymentids,
                                          a_dishonorfees,
                                          a_dishonoramounts,
                                          a_ovrs,
                                          a_srvs,
                                          a_index,
                                          a_pindex);
            t_amounts.delete;
            t_feeids.delete;
        END LOOP;

          -- get the amount to dishonor from the last transfer to payment
          SELECT feeid,
                 issrv,
                 isovr,
                 SUM(amount)
            BULK COLLECT INTO t_feeids,
                 t_srvlist,
                 t_ovrlist,
                 t_amounts
            FROM (SELECT DISTINCT
                         (ft.transactionid),
                         ft.feeid,
                         ft.amount,                 --APatterson: PIP Task 8.5
                         CASE WHEN pt2.isservicecharge = 'Y' THEN 1 ELSE 0 END
                             issrv,
                         CASE WHEN pt2.isoverpayment = 'Y' THEN 1 ELSE 0 END
                             isovr
                    FROM api.payments p
                         JOIN api.paymenttransactions pt
                             ON pt.paymentid = p.paymentid
                         --join api.FeeTransactions ft1 on ft1.TransactionId = pt.TransactionId
                         --join api.FeeTransactions ft on ft1.FeeId = ft.FeeId
                         JOIN api.feetransactions ft
                             ON ft.transactionid = pt.transactionid
                         JOIN api.registeredexternalobjects reo --TAyers: PIP Task 8.5
                             ON reo.linkvalue = TO_CHAR(ft.transactionid)
                         JOIN query.o_paymenttransactions pt2
                             ON pt2.objectid = reo.objectid
                   WHERE p.paymentid =
                         NVL(
                             t_topaymentid,
                             api.pkg_columnquery.numericvalue(
                                 a_paymentobjectid,
                                 'PaymentId'))
                     AND ft.transactiontype = 'Pay'
                     AND NOT EXISTS
                             (SELECT 1
                                FROM query.r_paymenttransfertrans r
                               WHERE r.paymenttransactionobjectid =
                                     reo.objectid))
        GROUP BY feeid, issrv, isovr
          HAVING SUM(amount) < 0;

        -- Subtract any values from the t_FeeIds/t_Amounts arrays that are already in the Dishonor FeeId/Amount lists
        FOR x IN 1 .. t_feeids.COUNT
        LOOP
            t_common   := FALSE;

            FOR y IN 1 .. a_dishonorfees.COUNT
            LOOP
                IF t_feeids(x) = a_dishonorfees(y) THEN
                    t_common   := TRUE;
                END IF;
            END LOOP;

            IF NOT t_common
           AND ((t_srvlist(x) = 1
             AND a_srv = 'Y')
             OR (t_srvlist(x) = 0
             AND a_srv = 'N')) THEN
                t_templist(t_templist.COUNT + 1)     := t_feeids(x);
                t_templista(t_templista.COUNT + 1)   := t_amounts(x);
                t_tovr(t_tovr.COUNT + 1)             := t_ovrlist(x);
                t_tsrv(t_tsrv.COUNT + 1)             := t_srvlist(x);
            END IF;
        END LOOP;

        t_feeids    := t_templist;
        t_amounts   := t_templista;
        t_ovrlist   := t_tovr;
        t_srvlist   := t_tsrv;
        t_templist.delete;
        t_templista.delete;
        t_tovr.delete;
        t_tsrv.delete;

        -- Add the FeeIds/Amounts to the Dishonor lists
        FOR x IN 1 .. t_feeids.COUNT
        LOOP
            a_index                      := a_index + 1;
            a_dishonorfees(a_index)      := t_feeids(x);
            a_dishonoramounts(a_index)   := t_amounts(x);
            a_ovrs(a_index)              := t_ovrlist(x);
            a_srvs(a_index)              := t_srvlist(x);
        END LOOP;

        IF t_feeids.FIRST IS NOT NULL THEN
            a_pindex   := a_pindex + 1;
            a_paymentids(a_pindex)   :=
                NVL(
                    t_topaymentid,
                    api.pkg_columnquery.numericvalue(a_paymentobjectid,
                                                     'PaymentId'));
        END IF;
    END dishonorpaymentcandidates;

    /*------------------------------------------------------
    -- DishonorPaymentCandidatesWrap()
    -- This is a wrapper for DishonorPaymentCandidates so it
    -- will handle SRV fees.
    ------------------------------------------------------*/

    PROCEDURE dishonorpaymentcandidateswrap(
        a_paymentobjectid     udt_id,
        a_paymentids   IN OUT udt_idlist,
        a_dishonorfees IN OUT udt_idlist,
        a_dishonoramounts IN OUT udt_numberlist,
        a_ovrs         IN OUT udt_numberlist,
        a_srvs         IN OUT udt_numberlist,
        a_index        IN OUT NUMBER,
        a_pindex       IN OUT NUMBER)
    IS
        t_amounts          udt_numberlist;
        t_feeids           udt_idlist;
        t_topaymentid      udt_id;
        t_topaymentobjid   udt_id;
    BEGIN
        IF a_index IS NULL THEN
            a_index   := 0;
        END IF;

        IF a_pindex IS NULL THEN
            a_pindex   := 0;
        END IF;

        -- Process the non-SRV fees/payments
        dishonorpaymentcandidates(a_paymentobjectid,
                                  a_paymentids,
                                  a_dishonorfees,
                                  a_dishonoramounts,
                                  a_ovrs,
                                  a_srvs,
                                  a_index,
                                  a_pindex,
                                  'N');
        -- Process the SRV fees/payments
        dishonorpaymentcandidates(a_paymentobjectid,
                                  a_paymentids,
                                  a_dishonorfees,
                                  a_dishonoramounts,
                                  a_ovrs,
                                  a_srvs,
                                  a_index,
                                  a_pindex,
                                  'Y');
    END dishonorpaymentcandidateswrap;

    ----------------------------------------------------------------------------------------------------
    --  ReverseDishonoredPayment()
    -- This is used on completion of the Reverse Dishonored Payment Process.
    ----------------------------------------------------------------------------------------------------

    PROCEDURE reversedishonoredpayment(a_objectid NUMBER, a_asofdate DATE)
    IS
        t_feeids                    api.pkg_definition.udt_idlist;
        t_amountstoreverse          api.pkg_definition.udt_numberlist;

        t_ovrfeeids                 api.pkg_definition.udt_idlist;
        t_ovramountstopay           api.pkg_definition.udt_numberlist;

        t_oldpaymentid              udt_id;
        t_oldpaymentobjid           udt_id;
        t_paymentamt                NUMBER;
        t_hqreceiptnum              VARCHAR2(8);
        t_batchid                   VARCHAR2(20);
        t_payeeaddress              VARCHAR2(4000);
        t_payeename                 VARCHAR2(4000);
        t_payeereference            VARCHAR2(60);
        t_earnedamount              NUMBER;
        t_relid                     NUMBER;
        t_paytransobjectid          udt_id;
        t_transactionobjid          udt_id;
        t_paymentmethodobjid        udt_id;
        t_paymentmethodendpointid   udt_id
            := api.pkg_configquery.endpointidforname('o_Payment',
                                                     'PaymentMethod');
        t_receiptnumber             VARCHAR2(40);
        t_defaultofficeobjectid     udt_id;

        t_newpaymentid              udt_id;
        t_newpaymentobjid           udt_id;
        t_newpaystatus              udt_id;
        t_paytransobjectdefid       udt_id
            := api.pkg_configquery.objectdefidforname(
                   'o_PaymentTransactions');
    BEGIN
        t_feeids.delete;
        t_amountstoreverse.delete;

        --Select Payment
        SELECT p.paymentid,
               prdp.paymentobjectid,
               p.paymentamountfordisplay paymentamt,
               p.hqreceiptlookup         hqreceipt,
               p.batchid,
               p.payeeaddress,
               p.payeename,
               p.payeereference,
               p.receiptnumber
          INTO t_oldpaymentid,
               t_oldpaymentobjid,
               t_paymentamt,
               t_hqreceiptnum,
               t_batchid,
               t_payeeaddress,
               t_payeename,
               t_payeereference,
               t_receiptnumber
          FROM query.r_reversedishonoredpayment  prdp
               JOIN query.o_payment p ON p.objectid = prdp.paymentobjectid
         WHERE prdp.rdpaymentprocessid = a_objectid;

        FOR pt
            IN (SELECT ft.feeid,                    --APatterson: PIP Task 8.5
                       ft.amount   amttoreverse,
                       pt.paymentid,
                       pt.objectid paymenttranobjid,
                       pt.feescheduledescriptionforgrid
                  FROM api.paymenttransactions  pts
                       JOIN api.registeredexternalobjects reo --TAyers: PIP Task 8.5
                           ON reo.linkvalue = TO_CHAR(pts.transactionid)
                       JOIN query.o_paymenttransactions pt
                           ON pt.objectid = reo.objectid
                       JOIN api.feetransactions ft
                           ON ft.transactionid = pt.transactionid
                          AND pts.paymentid = t_oldpaymentid)
        LOOP
            --Load the arrays with the fees and amounts to reverse.
            t_feeids(t_feeids.COUNT + 1)   := pt.feeid;
            t_amountstoreverse(t_amountstoreverse.COUNT + 1)   :=
                pt.amttoreverse;

            --Find the OVR Payments -- we may not need this section.
            IF pt.feescheduledescriptionforgrid = 'OVR' THEN
                t_ovrfeeids(t_ovrfeeids.COUNT + 1)   := pt.feeid;
                t_ovramountstopay(t_ovramountstopay.COUNT + 1)   :=
                    pt.amttoreverse;
            END IF;

            -- If the PT is an SRV, unearn it
            IF api.pkg_columnquery.VALUE(
                   api.pkg_columnquery.numericvalue(pt.paymenttranobjid,
                                                    'PaymentStatusObjectId'),
                   'Status') =
               'EARNED' THEN
                -- Get the amount to unearn
                t_earnedamount   :=
                    -api.pkg_columnquery.VALUE(
                         api.pkg_columnquery.numericvalue(
                             pt.paymenttranobjid,
                             'PaymentStatusObjectId'),
                         'EarnedAmount');
                --Unearn the transaction
                t_newpaystatus   :=
                    api.pkg_objectupdate.new(
                        api.pkg_configquery.objectdefidforname(
                            'o_PaymentStatus'));
                t_relid   :=
                    api.pkg_relationshipupdate.new(
                        api.pkg_configquery.endpointidforname(
                            'o_PaymentStatus',
                            'PaymentTransactions'),
                        t_newpaystatus,
                        pt.paymenttranobjid);
                api.pkg_columnupdate.setvalue(t_newpaystatus,
                                              'Status',
                                              'UNEARNED');
                api.pkg_columnupdate.setvalue(t_newpaystatus,
                                              'StatusDate',
                                              TRUNC(SYSDATE));
                api.pkg_columnupdate.setvalue(t_newpaystatus,
                                              'SystemGenerated',
                                              'Y');
                api.pkg_columnupdate.setvalue(t_newpaystatus,
                                              'EarnedAmount',
                                              t_earnedamount);
            END IF;
        END LOOP;

        --Set IsDishonoredReversed to 'Y'
        api.pkg_columnupdate.setvalue(t_oldpaymentobjid,
                                      'IsDishonoredReversed',
                                      'Y');

        --Create the Reversal Payments
        t_newpaymentid   :=
            api.pkg_paymentupdate.new(SYSDATE, t_feeids, t_amountstoreverse);
        t_newpaymentobjid   :=
            api.pkg_objectupdate.registerexternalobject('o_Payment',
                                                        t_newpaymentid);

        --Set the income code for the payment to 'I'
        api.pkg_columnupdate.setvalue(t_newpaymentobjid,
                                      'CABINIncomeInd',
                                      'D');

        --For each Payment Transaction for the Payment that was just created, register the external Payment Transaction and Fee Transaction
        FOR c1
            IN (SELECT pt.transactionid, ft.amount
                  FROM api.paymenttransactions  pt
                       JOIN api.feetransactions ft
                           ON ft.transactionid = pt.transactionid
                 WHERE pt.paymentid = t_newpaymentid)
        LOOP
            t_paytransobjectid   :=
                api.pkg_objectupdate.registerexternalobject(
                    'o_PaymentTransactions',
                    c1.transactionid);
            t_transactionobjid   :=
                api.pkg_objectupdate.registerexternalobject(
                    'o_FeeTransactions',
                    c1.transactionid);

            -- Set the income code for the payment transactions to 'D'
            api.pkg_columnupdate.setvalue(t_paytransobjectid,
                                          'CABINAmtType',
                                          'D');

            -- Set HQReceipt on the Payment Transaction
            api.pkg_columnupdate.setvalue(t_paytransobjectid,
                                          'HQReceipt',
                                          t_hqreceiptnum);

            -- Set the IsServiceCharge flag for SRV transactions
            IF c1.amount > 0 THEN
                api.pkg_columnupdate.setvalue(t_paytransobjectid,
                                              'IsServiceCharge',
                                              'Y');
            END IF;
        END LOOP;                       --Register object, payment status loop

        --Get Payment Method ObjectId
        BEGIN
            SELECT  /*+ CARDINALITY(x 1) */
                   ppm.paymentmethodobjectid
              INTO t_paymentmethodobjid
              FROM query.r_paymentpaymentmethod ppm
             WHERE ppm.paymentobjectid = t_oldpaymentobjid;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                api.pkg_errors.raiseerror(-20000, 'No Payment Method found.');
        END;

        --Create a relationship to the Original Payment's Office
        BEGIN
            SELECT po.officeobjectid
              INTO t_defaultofficeobjectid
              FROM query.r_paymentoffice po
             WHERE po.paymentobjectid = t_oldpaymentobjid;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                t_defaultofficeobjectid   := NULL;
        END;

        IF t_defaultofficeobjectid IS NOT NULL THEN
            t_relid   :=
                api.pkg_relationshipupdate.new(
                    api.pkg_configquery.endpointidforname('o_Office',
                                                          'Payment'),
                    t_defaultofficeobjectid,
                    t_newpaymentobjid);
        END IF;

        -- Set the Payee Reference to the preveious value
        api.pkg_paymentupdate.modify(t_newpaymentid,
                                     t_payeereference,
                                     t_receiptnumber);
        api.pkg_columnupdate.setvalue(t_newpaymentobjid,
                                      'BatchPaymentId',
                                      t_batchid);
        api.pkg_columnupdate.setvalue(t_newpaymentobjid,
                                      'PaymentDateStored',
                                      TRUNC(SYSDATE));
        t_relid   :=
            api.pkg_relationshipupdate.new(t_paymentmethodendpointid,
                                           t_newpaymentobjid,
                                           t_paymentmethodobjid);
        api.pkg_columnupdate.setvalue(
            t_newpaymentobjid,
            'PaymentAmountStored',
            api.pkg_columnquery.VALUE(t_newpaymentobjid, 'PaymentAmount'));
        api.pkg_columnupdate.setvalue(t_newpaymentobjid,
                                      'PaymentDateStored',
                                      TRUNC(SYSDATE));
        api.pkg_columnupdate.setvalue(t_newpaymentobjid,
                                      'IsReceiptedStored',
                                      'Y');
        api.pkg_columnupdate.setvalue(t_newpaymentobjid,
                                      'PayeeAddressStored',
                                      t_payeeaddress);
        api.pkg_columnupdate.setvalue(t_newpaymentobjid,
                                      'PayeeNameStored',
                                      t_payeename);

        -- Set OVR flags on the new transactions
        IF t_ovrfeeids.COUNT > 0 THEN
            sitespecific.pkg_fees.setpaymenttransactionflag(
                t_ovrfeeids,
                t_ovramountstopay,
                'IsOverpayment');
        END IF;

        -- Set income code on the Payment Transactions to 'D' (BAQ should this be I or D?)
        FOR x IN (SELECT reo.objectid
                    FROM api.paymenttransactions  pt
                         JOIN api.registeredexternalobjects reo --TAyers: PIP Task 8.5
                             ON reo.linkvalue = TO_CHAR(pt.transactionid)
                            AND reo.objectdefid = t_paytransobjectdefid
                   WHERE pt.paymentid = t_newpaymentid)
        LOOP
            api.pkg_columnupdate.setvalue(x.objectid, 'CABINAmtType', 'D');
        END LOOP;
    --Void/Reverse/Refund the 20 CHK fee?

    END reversedishonoredpayment;
END pkg_dishonor;
/
