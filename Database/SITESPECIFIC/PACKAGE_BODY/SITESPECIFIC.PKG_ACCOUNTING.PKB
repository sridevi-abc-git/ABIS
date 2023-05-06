CREATE OR REPLACE PACKAGE BODY SITESPECIFIC."PKG_ACCOUNTING"
AS
    -- **************************************************************************
    -- File:        PKG_ACCOUNTING.PKB
    -- Author:      CX
    --
    -- History:
    -----------------------------------------------------------------------------
    --    Date                  Comment
    -- 08/16/2018 TJL         Initial Check-in
    -- 05/27/2020 PK          WO21537 Credit Card addition to relate to Transmittal for RBS
    -- 11/13/2020 PK          WO22865 - Transmittal external file num logic taken out of procedure.
    -- 12/02/2020 PK          WO23055 Credit Card Type in Posse’s Deposit Batch.
    -- 2/5/2021   PK          WO-24001 Added 'RBSFFP', 'RBSSFP' for RBS complex entity finger printing fee and RBS office 77
    -- 05/11/2021 TJL   WO18874 Add new procdeure 'VerifyBatchPayments'   
    -- 09/21/2021 PK          WO-25903 - Added EChecks as transmittal type BizMod eCheck: Transmittal Type  
    -- 09/21/2021 PK          WO-25904 -Added eCheck to the Deposit Type  
    -- 10/26/2022 PK          Changed DB name to ABISP1 after upgrade on libne   IF (UPPER(sys_context('USERENV', 'instance_name')) != 'ABCPROD') THEN   
    -- 05/05/2023 PK          Changed Modify Payment to address MAX(pspt.paymentstatusobjectid) after objectif gap fixes       
    -- **************************************************************************


    --*------------------------------------------------------------------------------------------------
    --* SetDepositRelationships() -- PUBLIC
    --* This procedure relates the Transmittal job and the Payment Batch job to the Deposit job
    --* when the Transmittal and Payment Batch jobs are not currently related to a Deposit job of type
    --* Cash or Check and when the Transmittal and Payment Batch jobs are in the Complete status.
    --*------------------------------------------------------------------------------------------------
    PROCEDURE setdepositrelationships(a_objectid udt_id, a_asofdate DATE)
    IS
        t_transmittalendpointid    udt_id;
        t_paymentbatchendpointid   udt_id;
        t_relationshipid           udt_id;
        t_deposittype              VARCHAR2(15); --changed to 15 by Pawan for credit card WO23055
    BEGIN
        t_transmittalendpointid   :=
            api.pkg_configquery.endpointidforname('j_Deposit', 'Transmittal');
        t_paymentbatchendpointid   :=
            api.pkg_configquery.endpointidforname('j_Deposit',
                                                  'PaymentBatch');
        t_deposittype   :=
            api.pkg_columnquery.VALUE(a_objectid, 'DepositType');

        IF t_deposittype = 'Cash' THEN
            FOR c IN (SELECT j.jobid
                        FROM query.j_transmittal j
                       WHERE j.statusname = 'CMPLTE'
                         AND j.objectdeftypeid = 2 --This is to force the Cost Based Optimizer to use the correct index on Objmodelphys.Objects_t
                         AND j.transmittaltype = t_deposittype
                         AND NOT EXISTS
                                 (SELECT 1
                                    FROM query.r_transmittaldeposit r
                                   WHERE r.transmittaljobid = j.jobid))
            LOOP
                t_relationshipid   :=
                    api.pkg_relationshipupdate.new(t_transmittalendpointid,
                                                   a_objectid,
                                                   c.jobid);
            END LOOP;
        ELSIF t_deposittype = 'Check' THEN
            FOR c IN (SELECT j.jobid
                        FROM query.j_transmittal j
                       WHERE j.statusname = 'CMPLTE'
                         AND j.objectdeftypeid = 2
                         AND j.transmittaltype = t_deposittype
                         AND NOT EXISTS
                                 (SELECT 1
                                    FROM query.r_transmittaldeposit r
                                   WHERE r.transmittaljobid = j.jobid))
            LOOP
                t_relationshipid   :=
                    api.pkg_relationshipupdate.new(t_transmittalendpointid,
                                                   a_objectid,
                                                   c.jobid);
            END LOOP;
             FOR c IN (SELECT p.jobid
                        FROM query.j_paymentbatch p
                       WHERE p.statusname = 'CMPLTE'
                         AND p.objectdeftypeid = 2
                         AND NOT EXISTS
                                 (SELECT 1
                                    FROM query.r_depositpaymentbatch re
                                   WHERE re.paymentbatchjobid = p.jobid))
            LOOP
                t_relationshipid   :=
                    api.pkg_relationshipupdate.new(t_paymentbatchendpointid,
                                                   a_objectid,
                                                   c.jobid);
            END LOOP;
        ELSIF t_deposittype = 'Credit Card' THEN   --Added by Pawan on 12/02/2020 for WO23055 Credit Card Type in Posse’s Deposit Batch
            FOR c IN (SELECT j.jobid
                        FROM query.j_transmittal j
                       WHERE j.statusname = 'CMPLTE'
                         AND j.objectdeftypeid = 2
                         AND j.transmittaltype = t_deposittype
                         AND NOT EXISTS
                                 (SELECT 1
                                    FROM query.r_transmittaldeposit r
                                   WHERE r.transmittaljobid = j.jobid))
            LOOP
                t_relationshipid   :=
                    api.pkg_relationshipupdate.new(t_transmittalendpointid,
                                                   a_objectid,
                                                   c.jobid);
            END LOOP;
        ELSIF t_deposittype = 'ECheck' THEN   --Added by Pawan on 09/21/2021 for WO-25904 -Added eCheck to the Deposit Type
            FOR c IN (SELECT j.jobid
                        FROM query.j_transmittal j
                       WHERE j.statusname = 'CMPLTE'
                         AND j.objectdeftypeid = 2
                         AND j.transmittaltype = t_deposittype
                         AND NOT EXISTS
                                 (SELECT 1
                                    FROM query.r_transmittaldeposit r
                                   WHERE r.transmittaljobid = j.jobid))
            LOOP
                t_relationshipid   :=
                    api.pkg_relationshipupdate.new(t_transmittalendpointid,
                                                   a_objectid,
                                                   c.jobid);
            END LOOP;
        END IF;
    END setdepositrelationships;

    /*---------------------------------------------------------------------------
    * RelatePaymentToTransmittal() -- PUBLIC
    * This procedure relates receipted payment objects to a Transmittal job.
    * The payments are only related when the Payment is of the same type (cash or check
    * as the Transmittal and when the Payment is not related to a Transmittal.
    * CHANGES: 1) Mike Lott - 12/14/2015 - Updated PaymentObjectIds cursor def
    *   to use r_TransmitPaymentOffice, not r_PaymentOffice.
    *-------------------------------------------------------------------------*/
    PROCEDURE relatepaymenttotransmittal(a_objectid      udt_id,
                                         a_asofdate      DATE,
                                         a_transmittaltype STRING)
    IS
        t_endpointid        udt_id;
        t_relationshipid    udt_id;
      --  t_externalfilenum   NUMBER;
      --  t_sequenceid        udt_id;
        t_officeid          udt_id;

        /* Get Payments that have been receipted, are not related to a Transmittal
         * yet, and have the same type (cash or check) as the Transmittal. */
        CURSOR paymentobjectids
        IS
            SELECT p.objectid
              FROM query.r_transmitpaymentoffice  x
                   JOIN query.o_payment p
                       ON p.objectid = x.transmittalpaymentid
                   JOIN query.r_generatereceiptpayment r
                       ON r.paymentobjectid = p.objectid
                   JOIN query.p_receiptpayments rp
                       ON rp.objectid = r.generatereceiptprocessid
             WHERE x.transmittalofficeid = t_officeid
               AND rp.datecompleted IS NOT NULL
               AND p.isvoidedflag = 'N'
               AND NOT EXISTS
                       (SELECT 1
                          FROM query.r_transmittalpayment rt
                         WHERE rt.paymentobjectid = p.objectid)
               --        and p.PaymentMethod like '%' || upper(a_TransmittalType) || '%';
                   AND a_transmittaltype =
                   
                   CASE
                       WHEN p.paymentmethod = 'CASH' THEN 'Cash'
                       WHEN p.paymentmethod = 'CREDIT CARD' THEN 'Credit Card'  --WO21537 Credit Card Transmittal by Pawan
                       WHEN p.paymentmethod = 'ELECTRONIC CHECK' THEN 'ECheck' --09/21/2021 WO-25903 - Added EChecks as transmittal type BizMod by Pawanjit Kaur
                       ELSE 'Check'
                   END;
    BEGIN
     -- WO22865 - Transmittal external file num logic taken out of procedure and commented out t_externalfilenum t_sequenceid (Check test for reference)
         BEGIN
            SELECT r.officeobjectid
              INTO t_officeid
              FROM query.r_transmittaloffice r
             WHERE r.transmittaljobid = a_objectid;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                t_officeid   := NULL;
        END;

        --Create the relationships
        t_endpointid   :=
            api.pkg_configquery.endpointidforname('j_Transmittal', 'Payment');

        FOR c IN paymentobjectids
        LOOP
            t_relationshipid   :=
                api.pkg_relationshipupdate.new(t_endpointid,
                                               a_objectid,
                                               c.objectid);
        END LOOP;

        api.pkg_columnupdate.setvalue(a_objectid,
                                      'GetReceiptedPayments',
                                      'N');
        api.pkg_columnupdate.setvalue(a_objectid,
                                      'GetPaymentProcedureIsRun',
                                      'Y');
    END;

    --*------------------------------------------------------------------------------------------------
    --* GetOfficesForTransmittal() -- PUBLIC
    --* This is a procedural relationship that is used to cross-validate a relationship between
    --* the Transmittal job and the Office object.  It allows the dependent dropdown to include both
    --* the user's secondary offices as well as the user's default office.
    --*------------------------------------------------------------------------------------------------
    PROCEDURE getofficesfortransmittal(
        a_objectid         udt_id,
        a_endpointid       udt_id,
        a_relatedobjectids OUT api.udt_objectlist)
    IS
        CURSOR relatedoffices
        IS
            SELECT r.toobjectid
              FROM query.j_transmittal  j
                   JOIN query.users u ON j.createdbyuserid = u.userid
                   JOIN api.relationships r ON u.userid = r.fromobjectid
                   JOIN api.relationshipdefs rd
                       ON r.relationshipdefid = rd.relationshipdefid
             WHERE rd.name IN ('r_OfficeUser', 'r_UserSecondaryOffice')
               AND j.jobid = a_objectid;
    BEGIN
        a_relatedobjectids   := api.udt_objectlist();

        FOR c IN relatedoffices
        LOOP
            a_relatedobjectids.EXTEND(1);
            a_relatedobjectids(a_relatedobjectids.COUNT)   :=
                api.udt_object(c.toobjectid);
        END LOOP;
    END;

    --*------------------------------------------------------------------------------------------------
    --* RelateTransmittalToOffice() -- PUBLIC
    --* This is a procedure that automatically relates the Transmittal job to the user's
    --* default office when a Transmittal job is created.
    --*------------------------------------------------------------------------------------------------
    PROCEDURE relatetransmittaltooffice(a_objectid udt_id, a_asofdate DATE)
    IS
        t_relid             udt_id;
        t_officeendpoint    VARCHAR2(4000);
        t_defaultofficeid   udt_id
            := api.pkg_columnquery.VALUE(a_objectid, 'DefaultOfficeObjectId');
    BEGIN
        IF t_defaultofficeid IS NOT NULL THEN
            t_officeendpoint   :=
                api.pkg_configquery.endpointidforname('j_Transmittal',
                                                      'Office');
            t_relid   :=
                api.pkg_relationshipupdate.new(t_officeendpoint,
                                               a_objectid,
                                               t_defaultofficeid);
        ELSE
            api.pkg_errors.raiseerror(
                -20000,
                'The current User must have a Default Office.');
        END IF;
    END;

    /*---------------------------------------------------------------------------
    * AssignValidateBatch()   -- PUBLIC
    *  This will assign the access group HQ Accounting to the Process Batch Entry on the job Payment Batch
    * Except for the person who created the First Process on the job
    *-------------------------------------------------------------------------*/
    PROCEDURE assignvalidatebatch(a_objectid      udt_id,
                                  a_asofdate      DATE,
                                  a_jobid         udt_id)
    IS
        t_completedby             VARCHAR2(4000);
        t_processid               NUMBER(10);
        t_batchentryobjectdefid   udt_id
            := api.pkg_configquery.objectdefidforname('p_BatchEntry');
    BEGIN
        SELECT MAX(p.processid)
          INTO t_processid
          FROM api.processes p
         WHERE p.jobid = a_jobid
           AND p.processtypeid = t_batchentryobjectdefid
           AND p.datecompleted IS NOT NULL;

        SELECT p.completedby
          INTO t_completedby
          FROM api.processes p
         WHERE p.processid = t_processid;

        FOR c
            IN (SELECT u.oraclelogonid
                  FROM api.accessgroups  a
                       JOIN api.accessgroupusers ag
                           ON ag.accessgroupid = a.accessgroupid
                       JOIN api.users u ON u.userid = ag.userid
                 WHERE a.description = 'HQ Accounting'
                   AND u.oraclelogonid <> t_completedby)
        LOOP
            api.pkg_processupdate.assign(a_objectid, c.oraclelogonid);
        END LOOP;
    END;


    --*------------------------------------------------------------------------------------------------
    --* SetFeeRelationshipsToResearchRefundsProcess() -- PUBLIC
    --*-----------------------------------------------------------------------------------------------
    PROCEDURE setfeereltoresearchrefundsproc(a_objectid      udt_id,
                                             a_asofdate      DATE,
                                             a_jobid         udt_id)
    IS
        t_relationshipid   udt_id;
    BEGIN
        -- RyanL: Changed the where clause to be a subselect for performance (PIP Task 8.5)
        FOR x
            IN (SELECT api.pkg_simplesearch.objectbyindex('o_Fee',
                                                          'FeeId',
                                                          af.feeid)
                           feeid
                  FROM api.fees af
                 WHERE af.jobid = a_jobid
                   AND (  af.amount
                        + NVL((SELECT SUM(amount)
                                 FROM api.feetransactions ft
                                WHERE ft.feeid = af.feeid),
                              0)) < 0 -- af.Amount + af.AdjustedAmount + af.PaidAmount
                UNION
                SELECT api.pkg_simplesearch.objectbyindex('o_Fee',
                                                          'FeeId',
                                                          af.feeid)
                           feeid
                  FROM query.r_licenselicensetype  r
                       JOIN api.fees af ON af.jobid = r.licensetypejobid
                 WHERE r.licensejobid = a_jobid
                   AND (  af.amount
                        + NVL((SELECT SUM(amount)
                                 FROM api.feetransactions ft
                                WHERE ft.feeid = af.feeid),
                              0)) < 0)
        LOOP
            t_relationshipid   :=
                api.pkg_relationshipupdate.new(
                    api.pkg_configquery.endpointidforname('p_ResearchRefund',
                                                          'Fee'),
                    a_objectid,
                    x.feeid);
        END LOOP;
    END setfeereltoresearchrefundsproc;

    /*---------------------------------------------------------------------------
    * CreateLineItemObject() -- PUBLIC
    * this will create Batch Payment Entry Objects for the Payment Batch Job based
    * on the Line Item Count and payment # From and # To
    * it will also throw in a GroupID if it is a P-12
    *-------------------------------------------------------------------------*/
    PROCEDURE createlineitem(a_jobid udt_id, a_asofdate DATE)
    IS
        t_lineitemcount             NUMBER;
        t_objectdefid               udt_id;
        t_newobjectid               udt_id;
        t_relationshipid            udt_id;
        t_endpointid                udt_id;
        t_paymentbatchtype          VARCHAR2(50)
            := api.pkg_columnquery.VALUE(a_jobid,
                                         'PaymentBatchType',
                                         a_asofdate);
        t_paymentnumberfrom         NUMBER
            := api.pkg_columnquery.VALUE(a_jobid,
                                         'PaymentNumberFrom',
                                         a_asofdate);
        t_paymentnumberto           NUMBER
            := api.pkg_columnquery.VALUE(a_jobid,
                                         'PaymentNumberTo',
                                         a_asofdate);
        t_paymentnumberfromverify   NUMBER
            := api.pkg_columnquery.VALUE(a_jobid,
                                         'PaymentNumberFromVerify',
                                         a_asofdate);
        t_paymentnumbertoverify     NUMBER
            := api.pkg_columnquery.VALUE(a_jobid,
                                         'PaymentNumberToVerify',
                                         a_asofdate);
        t_paymentnumberpadding      VARCHAR2(8);
        t_paymentnumbercount        NUMBER := 0;
        t_loopnumber                NUMBER := 0;
        t_numberofgroups            NUMBER;
        t_dividedcount              NUMBER;
        t_groupid                   NUMBER := 1;
        t_status                    VARCHAR2(50)
            := api.pkg_columnquery.VALUE(a_jobid,
                                         'StatusDescription',
                                         a_asofdate);
        t_isawfzerobatch            VARCHAR2(1)
            := api.pkg_columnquery.VALUE(a_jobid, 'IsAWFZeroBatch');
        t_awfrowcount               NUMBER;
    BEGIN
        -- Determine the Number of rows to create.
        IF t_status = 'Prepare'
       AND t_paymentbatchtype = 'P-12 RENEWALS' THEN
            t_lineitemcount   :=
                api.pkg_columnquery.VALUE(a_jobid,
                                          'NumberOfGroups',
                                          a_asofdate);
            t_numberofgroups   :=
                api.pkg_columnquery.VALUE(a_jobid,
                                          'NumberOfGroups',
                                          a_asofdate);
            t_dividedcount   := ROUND(t_lineitemcount / t_numberofgroups, 0);
            t_endpointid     :=
                api.pkg_configquery.endpointidforname('o_BatchPaymentEntry',
                                                      'PaymentBatch');
            t_paymentnumberpadding   :=
                api.pkg_columnquery.VALUE(a_jobid, 'PaymentNumberFrom');
            t_paymentnumberpadding   :=
                REPLACE(t_paymentnumberpadding,
                        LTRIM(t_paymentnumberpadding, 0));
        ELSIF t_status = 'Prepare'
          AND t_paymentbatchtype != 'P-12 RENEWALS' THEN
            t_paymentnumbercount   :=
                (t_paymentnumberto - t_paymentnumberfrom) + 1;
            t_lineitemcount   :=
                api.pkg_columnquery.VALUE(a_jobid, 'CheckCount', a_asofdate);
            t_endpointid   :=
                api.pkg_configquery.endpointidforname('o_BatchPaymentEntry',
                                                      'PaymentBatch');
            t_paymentnumberpadding   :=
                api.pkg_columnquery.VALUE(a_jobid, 'PaymentNumberFrom');
            t_paymentnumberpadding   :=
                REPLACE(t_paymentnumberpadding,
                        LTRIM(t_paymentnumberpadding, 0));
            t_awfrowcount   :=
                api.pkg_columnquery.VALUE(a_jobid, 'AWFRowCount');
        ELSIF t_status = 'Verify'
          AND t_paymentbatchtype = 'P-12 RENEWALS' THEN
            t_numberofgroups   :=
                api.pkg_columnquery.VALUE(a_jobid,
                                          'NumberOfGroupsVerify',
                                          a_asofdate);
            t_lineitemcount   :=
                api.pkg_columnquery.VALUE(a_jobid,
                                          'NumberOfGroupsVerify',
                                          a_asofdate);
            t_dividedcount   := ROUND(t_lineitemcount / t_numberofgroups, 0);
            t_endpointid     :=
                api.pkg_configquery.endpointidforname('o_BatchPaymentEntry',
                                                      'PaymentBatchVerify');
            t_paymentnumberpadding   :=
                api.pkg_columnquery.VALUE(a_jobid, 'PaymentNumberFromVerify');
            t_paymentnumberpadding   :=
                REPLACE(t_paymentnumberpadding,
                        LTRIM(t_paymentnumberpadding, 0));
        ELSIF t_status = 'Verify'
          AND t_paymentbatchtype != 'P-12 RENEWALS' THEN
            t_paymentnumbercount   :=
                (t_paymentnumbertoverify - t_paymentnumberfromverify) + 1;
            t_lineitemcount   :=
                api.pkg_columnquery.VALUE(a_jobid,
                                          'CheckCountValidation',
                                          a_asofdate);
            t_endpointid   :=
                api.pkg_configquery.endpointidforname('o_BatchPaymentEntry',
                                                      'PaymentBatchVerify');
            t_paymentnumberpadding   :=
                api.pkg_columnquery.VALUE(a_jobid, 'PaymentNumberFromVerify');
            t_paymentnumberpadding   :=
                REPLACE(t_paymentnumberpadding,
                        LTRIM(t_paymentnumberpadding, 0));
            t_awfrowcount   :=
                api.pkg_columnquery.VALUE(a_jobid, 'AWFRowCountVerify');
        ELSIF t_paymentbatchtype IS NULL THEN
            api.pkg_errors.raiseerror(-20000, 'Please select a Batch Type.');
        ELSE
            api.pkg_errors.raiseerror(
                -20000,
                'There has been an error determining the Number of Line Items to create please contact your Administrator with the steps taken prior to this error.');
        END IF;

        -- Raise an ERROR if Line Item Count does not equal the range in between From # and To # in the case of a non-P12.
        -- Also raise an ERROR if the From and To Payment Numbers are not the same in the case of a P12.
        IF t_lineitemcount <> t_paymentnumbercount
       AND t_paymentbatchtype != 'P-12 RENEWALS'
       AND t_isawfzerobatch = 'N' THEN
            api.pkg_errors.raiseerror(
                -20000,
                'The HQ Receipt range must equal the value entered in Checks.');
        END IF;

        IF (t_paymentbatchtype = 'P-12 RENEWALS'
         OR t_isawfzerobatch = 'Y')
       AND t_paymentnumberfrom != t_paymentnumberto
       AND t_status = 'Prepare' THEN
            api.pkg_errors.raiseerror(
                -20000,
                'The HQ Receipt From must equal the HQ Receipt To.');
        ELSIF (t_paymentbatchtype = 'P-12 RENEWALS'
            OR t_isawfzerobatch = 'Y')
          AND t_paymentnumberfromverify != t_paymentnumbertoverify
          AND t_status = 'Verify' THEN
            api.pkg_errors.raiseerror(
                -20000,
                'The HQ Receipt From must equal the HQ Receipt To.');
        END IF;

        IF t_status = 'Verify'
       AND (NVL(t_paymentnumberfrom, 0) != NVL(t_paymentnumberfromverify, 0)
         OR NVL(t_paymentnumberto, 0) != NVL(t_paymentnumbertoverify, 0)) THEN
            api.pkg_errors.raiseerror(
                -20000,
                'The From and To HQ Receipt number in Verify must equal the From and To HQ Receipt numbers in Entry.');
        END IF;

        -- Get the ObjectDefId for the Payment Batch Entry Object
        t_objectdefid   :=
            api.pkg_configquery.objectdefidforname('o_BatchPaymentEntry');

        -- Create the number of rows for the Range between From # and To # and relate it to the job.
        -- If it is not a P-12 then it will add a sequence number. If it is a P-12 then it will add a Group Id along with the sequance number.
        IF t_status = 'Prepare'
       AND t_paymentbatchtype != 'P-12 RENEWALS'
       AND t_isawfzerobatch = 'N' THEN
            FOR c_paymentnum IN t_paymentnumberfrom .. t_paymentnumberto
            LOOP
                t_loopnumber   := t_loopnumber + 1;
                t_newobjectid   :=
                    api.pkg_objectupdate.new(t_objectdefid, a_asofdate);
                api.pkg_columnupdate.setvalue(t_newobjectid,
                                              'Sequence',
                                              t_loopnumber,
                                              a_asofdate);
                t_relationshipid   :=
                    api.pkg_relationshipupdate.new(t_endpointid,
                                                   t_newobjectid,
                                                   a_jobid,
                                                   a_asofdate);
                api.pkg_columnupdate.setvalue(
                    t_newobjectid,
                    'PaymentNumber',
                    t_paymentnumberpadding || c_paymentnum,
                    a_asofdate);
            END LOOP;
        ELSIF t_status = 'Verify'
          AND t_paymentbatchtype != 'P-12 RENEWALS'
          AND t_isawfzerobatch = 'N' THEN
            FOR c_paymentnum IN t_paymentnumberfromverify ..
                                t_paymentnumbertoverify
            LOOP
                t_loopnumber   := t_loopnumber + 1;
                t_newobjectid   :=
                    api.pkg_objectupdate.new(t_objectdefid, a_asofdate);
                api.pkg_columnupdate.setvalue(t_newobjectid,
                                              'Sequence',
                                              t_loopnumber,
                                              a_asofdate);
                t_relationshipid   :=
                    api.pkg_relationshipupdate.new(t_endpointid,
                                                   t_newobjectid,
                                                   a_jobid,
                                                   a_asofdate);
                api.pkg_columnupdate.setvalue(
                    t_newobjectid,
                    'PaymentNumber',
                    t_paymentnumberpadding || c_paymentnum,
                    a_asofdate);
            END LOOP;
        ELSIF t_status = 'Prepare'
          AND t_paymentbatchtype = 'P-12 RENEWALS' THEN
            FOR c_paymentnum IN 1 .. t_lineitemcount
            LOOP
                t_loopnumber   := t_loopnumber + 1;
                t_newobjectid   :=
                    api.pkg_objectupdate.new(t_objectdefid, a_asofdate);
                api.pkg_columnupdate.setvalue(t_newobjectid,
                                              'Sequence',
                                              c_paymentnum,
                                              a_asofdate);
                t_relationshipid   :=
                    api.pkg_relationshipupdate.new(t_endpointid,
                                                   t_newobjectid,
                                                   a_jobid,
                                                   a_asofdate);
                api.pkg_columnupdate.setvalue(
                    t_newobjectid,
                    'PaymentNumber',
                    t_paymentnumberpadding || t_paymentnumberto,
                    a_asofdate);
                api.pkg_columnupdate.setvalue(t_newobjectid,
                                              'GroupId',
                                              t_groupid,
                                              a_asofdate);

                IF t_loopnumber = t_dividedcount THEN
                    t_groupid      := t_groupid + 1;
                    t_loopnumber   := 0;
                END IF;
            END LOOP;
        ELSIF t_status = 'Verify'
          AND t_paymentbatchtype = 'P-12 RENEWALS' THEN
            FOR c_paymentnum IN 1 .. t_lineitemcount
            LOOP
                t_loopnumber   := t_loopnumber + 1;
                t_newobjectid   :=
                    api.pkg_objectupdate.new(t_objectdefid, a_asofdate);
                api.pkg_columnupdate.setvalue(t_newobjectid,
                                              'Sequence',
                                              c_paymentnum,
                                              a_asofdate);
                t_relationshipid   :=
                    api.pkg_relationshipupdate.new(t_endpointid,
                                                   t_newobjectid,
                                                   a_jobid,
                                                   a_asofdate);
                api.pkg_columnupdate.setvalue(
                    t_newobjectid,
                    'PaymentNumber',
                    t_paymentnumberpadding || t_paymentnumbertoverify,
                    a_asofdate);
                api.pkg_columnupdate.setvalue(t_newobjectid,
                                              'GroupId',
                                              t_groupid,
                                              a_asofdate);

                IF t_loopnumber = t_dividedcount THEN
                    t_groupid      := t_groupid + 1;
                    t_loopnumber   := 0;
                END IF;
            END LOOP;
        ELSIF t_isawfzerobatch = 'Y' THEN --no difference between Prepare/Verify statuses.
            FOR c_paymentnum IN 1 .. t_awfrowcount
            LOOP
                t_loopnumber    := t_loopnumber + 1;
                t_newobjectid   := api.pkg_objectupdate.new(t_objectdefid);
                api.pkg_columnupdate.setvalue(t_newobjectid,
                                              'Sequence',
                                              t_loopnumber);
                t_relationshipid   :=
                    api.pkg_relationshipupdate.new(t_endpointid,
                                                   t_newobjectid,
                                                   a_jobid);
                api.pkg_columnupdate.setvalue(
                    t_newobjectid,
                    'PaymentNumber',
                    t_paymentnumberpadding || t_paymentnumberfrom);
                api.pkg_columnupdate.setvalue(t_newobjectid,
                                              'CheckAmount',
                                              0);
            END LOOP;
        END IF;
    END createlineitem;

    /*---------------------------------------------------------------------------
    * SortByColumn() -- PUBLIC
    * this will set a Squentced column for the Batch Payment Entry Object
    *-------------------------------------------------------------------------*/
    PROCEDURE sortbycolumn(a_objectid udt_id, a_asofdate DATE)
    IS
        t_newseq                         NUMBER;
        t_boeobjectid                    udt_id;
        t_sequence                       NUMBER; --Number := api.pkg_columnquery.Value(t_BOEObjectId, 'Sequence',a_AsOfDate);
        t_jobid                          udt_id;
        t_relationshipdefid              udt_id;
        t_paybatchentryendpointid        udt_id
            := api.pkg_configquery.endpointidforname('j_PaymentBatch',
                                                     'BatchPaymentEntry');
        t_paybatchverifyendpointid       udt_id
            := api.pkg_configquery.endpointidforname(
                   'j_PaymentBatch',
                   'BatchPaymentEntryVerify');
        t_batchentryadditemendpointid    udt_id
            := api.pkg_configquery.endpointidforname('o_BatchPaymentEntry',
                                                     'AdditionalItem');
        t_batchentrypaybatchendpointid   udt_id
            := api.pkg_configquery.endpointidforname('o_BatchPaymentEntry',
                                                     'PaymentBatch');
        t_batchentryverifyendpointid     udt_id
            := api.pkg_configquery.endpointidforname('o_BatchPaymentEntry',
                                                     'PaymentBatchVerify');
        t_additembatchentryendpointid    udt_id
            := api.pkg_configquery.endpointidforname('o_AdditionalItem',
                                                     'BatchPaymentEntry');
    BEGIN
        SELECT api.pkg_columnquery.VALUE(r.toobjectid, 'Sequence'),
               r.toobjectid,
               r.fromobjectid,
               r.relationshipdefid
          INTO t_sequence,
               t_boeobjectid,
               t_jobid,
               t_relationshipdefid
          FROM api.relationships r
         WHERE r.relationshipid = a_objectid
           AND r.endpointid IN
                   (t_paybatchentryendpointid,
                    t_paybatchverifyendpointid,
                    t_batchentryadditemendpointid);

        IF t_sequence IS NULL THEN
            SELECT   NVL(
                         MAX(
                             api.pkg_columnquery.numericvalue(b2.objectid,
                                                              'Sequence')),
                         0)
                   + 1
              INTO t_newseq
              FROM api.objects  b1     -- BatchPaymentEntry or AdditionalItems
                   JOIN api.relationships r ON b1.objectid = r.fromobjectid
                   JOIN api.objects j ON j.objectid = r.toobjectid -- BatchPaymentEntry or PaymentBatch job
                   JOIN api.relationships r2 ON j.objectid = r2.fromobjectid
                   JOIN api.objects b2 ON b2.objectid = r2.toobjectid -- BatchPaymentEntry or AdditionalItems
             WHERE b1.objectid = t_boeobjectid
               AND r.relationshipdefid = r2.relationshipdefid
               AND b1.objectdefid = b2.objectdefid
               AND r.endpointid IN
                       (t_batchentrypaybatchendpointid,
                        t_batchentryverifyendpointid,
                        t_additembatchentryendpointid)
               AND r2.endpointid IN
                       (t_batchentryadditemendpointid,
                        t_paybatchentryendpointid,
                        t_paybatchverifyendpointid);

            api.pkg_columnupdate.setvalue(t_boeobjectid,
                                          'Sequence',
                                          t_newseq);
        END IF;
    END sortbycolumn;

    /*----------------------------------------------------------------------------------
    -- DepositReport()
    -- This creates a table and populates it with values for the Account Deposit Report
    */
    ----------------------------------------------------------------------------------
    PROCEDURE depositreport(a_startdate DATE, a_enddate DATE)
    IS
        t_hqfingerprints               NUMBER;
        t_hqdishonoredcheckcharges     NUMBER;
        t_hqlicensefees                NUMBER;
        t_hqmiscamrs                   NUMBER;
        t_hqrevolvingfund              NUMBER;
        t_hqappealsboard               NUMBER;
        t_hqfederaldrugasset           NUMBER;
        t_hqstatedrugasset             NUMBER;
        t_hqunclaimedtrust             NUMBER;
        t_distfingerprints             NUMBER;
        t_distdishonoredcheckcharges   NUMBER;
        t_distlicensefees              NUMBER;
        t_distmiscamrs                 NUMBER;
        t_distrevolvingfund            NUMBER;
        t_distappealsboard             NUMBER;
        t_distfederaldrugasset         NUMBER;
        t_diststatedrugasset           NUMBER;
        t_distunclaimedtrust           NUMBER;
        t_cash                         NUMBER;
        t_checks                       NUMBER;
        t_cashconvertedtochecks        NUMBER;
        t_feeobjectdefid               udt_id
            := api.pkg_configquery.objectdefidforname('o_Fee');
    BEGIN
        DELETE FROM deposits_gt;

        DELETE FROM transmittallfs_gt;

        DELETE FROM paymentbatchlfs_gt;

        DELETE FROM transmittalmfs_gt;

        DELETE FROM paymentbatchmfs_gt;

        DELETE FROM transmittalpaymentcodes_gt;

        DELETE FROM depositreport_gt;

        -- Without this commit the records are not cleared and the report
        --commit;

        -- Deposit JobIds
        FOR c
            IN (SELECT d.objectid
                  FROM TABLE(
                           CAST(
                               api.pkg_simplesearch.castableobjectsbyindexrange(
                                   'j_Deposit',
                                   'DepositDate',
                                   TO_CHAR(a_startdate, 'YYYY-MM-DD'),
                                   TO_CHAR(a_enddate, 'YYYY-MM-DD')) AS api.udt_objectlist))
                       d)
        LOOP
            INSERT INTO deposits_gt(objectid)
                 VALUES (c.objectid);
        END LOOP;

        -- Transmittal License Fee Schedule Payments
        FOR c
            IN (SELECT ft.amount,
                       api.pkg_columnquery.VALUE(flfs.licensefeescheduleid,
                                                 'FeeActivity')
                           feeactivity,
                       SUBSTR(t.office, 1, 2)
                           office,
                       api.pkg_columnquery.VALUE(
                           api.pkg_simplesearch.objectbyindex(
                               'o_PaymentTransactions',
                               'TransactionId',
                               pt.transactionid),
                           'IsOverpayment')
                           isovr
                  FROM query.r_transmittaldeposit  td
                       JOIN query.j_transmittal t
                           ON td.transmittaljobid = t.jobid
                       JOIN query.r_transmittalpayment tp
                           ON t.jobid = tp.transmittaljobid
                       JOIN query.o_payment p
                           ON tp.paymentobjectid = p.objectid
                       JOIN api.paymenttransactions pt
                           ON p.paymentid = pt.paymentid
                       JOIN api.feetransactions ft
                           ON pt.transactionid = ft.transactionid
                       JOIN api.registeredexternalobjects reo -- RyanL: PIP Task 8.5
                           ON reo.linkvalue = TO_CHAR(ft.feeid)
                          AND reo.objectdefid = t_feeobjectdefid
                       JOIN query.r_feelicensefeeschedule flfs
                           ON reo.objectid = flfs.feeobjectid
                 WHERE td.depositjobid IN
                           (SELECT objectid FROM sitespecific.deposits_gt)
                   AND p.isvoidedflag != 'Y')
        LOOP
            INSERT INTO transmittallfs_gt(amount,
                                          feeactivity,
                                          office,
                                          isoverpayment)
                 VALUES (c.amount,
                         c.feeactivity,
                         c.office,
                         c.isovr);
        END LOOP;

        -- PaymentBatch License Fee Schedule Payments
        FOR c
            IN (SELECT ft.amount,
                       api.pkg_columnquery.VALUE(flfs.licensefeescheduleid,
                                                 'FeeActivity')
                           feeactivity,
                       api.pkg_columnquery.VALUE(
                           api.pkg_simplesearch.objectbyindex(
                               'o_PaymentTransactions',
                               'TransactionId',
                               pt.transactionid),
                           'IsOverpayment')
                           isovr
                  FROM query.r_depositpaymentbatch  dpb
                       JOIN query.j_paymentbatch pb
                           ON dpb.paymentbatchjobid = pb.jobid
                       JOIN query.r_paymentbatchpayment pbp
                           ON pb.jobid = pbp.paymentbatchjobid
                       JOIN query.o_payment p
                           ON pbp.paymentobjectid = p.objectid
                       JOIN api.paymenttransactions pt
                           ON p.paymentid = pt.paymentid
                       JOIN api.feetransactions ft
                           ON pt.transactionid = ft.transactionid
                       JOIN api.registeredexternalobjects reo -- RyanL: PIP Task 8.5
                           ON reo.linkvalue = TO_CHAR(ft.feeid)
                          AND reo.objectdefid = t_feeobjectdefid
                       JOIN query.r_feelicensefeeschedule flfs
                           ON reo.objectid = flfs.feeobjectid
                 WHERE dpb.depositjobid IN
                           (SELECT objectid FROM sitespecific.deposits_gt)
                   AND p.isvoidedflag != 'Y')
        LOOP
            INSERT INTO paymentbatchlfs_gt(amount,
                                           feeactivity,
                                           isoverpayment)
                 VALUES (c.amount, c.feeactivity, c.isovr);
        END LOOP;

        -- Transmittal Misc Fee Schedule Payments
        FOR c
            IN (SELECT ft.amount,
                       api.pkg_columnquery.VALUE(
                           mffs.miscfeescheduleobjectid,
                           'Code')
                           code,
                       SUBSTR(t.office, 1, 2)
                           office,
                       api.pkg_columnquery.VALUE(
                           api.pkg_simplesearch.objectbyindex(
                               'o_PaymentTransactions',
                               'TransactionId',
                               pt.transactionid),
                           'IsOverpayment')
                           isovr
                  FROM query.r_transmittaldeposit  td
                       JOIN query.j_transmittal t
                           ON td.transmittaljobid = t.jobid
                       JOIN query.r_transmittalpayment tp
                           ON t.jobid = tp.transmittaljobid
                       JOIN query.o_payment p
                           ON tp.paymentobjectid = p.objectid
                       JOIN api.paymenttransactions pt
                           ON p.paymentid = pt.paymentid
                       JOIN api.feetransactions ft
                           ON pt.transactionid = ft.transactionid
                       JOIN api.registeredexternalobjects reo -- RyanL: PIP Task 8.5
                           ON reo.linkvalue = TO_CHAR(ft.feeid)
                          AND reo.objectdefid = t_feeobjectdefid
                       JOIN query.r_miscfeefeeschedule mffs
                           ON reo.objectid = mffs.feeobjectid
                 WHERE td.depositjobid IN
                           (SELECT objectid FROM sitespecific.deposits_gt)
                   AND p.isvoidedflag != 'Y')
        LOOP
            INSERT INTO transmittalmfs_gt(amount,
                                          code,
                                          office,
                                          isoverpayment)
                 VALUES (c.amount,
                         c.code,
                         c.office,
                         c.isovr);
        END LOOP;

        -- PaymentBatch Misc Fee Schedule Payments
        FOR c
            IN (SELECT ft.amount,
                       api.pkg_columnquery.VALUE(
                           mffs.miscfeescheduleobjectid,
                           'Code')
                           code,
                       api.pkg_columnquery.VALUE(
                           api.pkg_simplesearch.objectbyindex(
                               'o_PaymentTransactions',
                               'TransactionId',
                               pt.transactionid),
                           'IsOverpayment')
                           isovr
                  FROM query.r_depositpaymentbatch  dpb
                       JOIN query.j_paymentbatch pb
                           ON dpb.paymentbatchjobid = pb.jobid
                       JOIN query.r_paymentbatchpayment pbp
                           ON pb.jobid = pbp.paymentbatchjobid
                       JOIN query.o_payment p
                           ON pbp.paymentobjectid = p.objectid
                       JOIN api.paymenttransactions pt
                           ON p.paymentid = pt.paymentid
                       JOIN api.feetransactions ft
                           ON pt.transactionid = ft.transactionid
                       JOIN api.registeredexternalobjects reo -- RyanL: PIP Task 8.5
                           ON reo.linkvalue = TO_CHAR(ft.feeid)
                          AND reo.objectdefid = t_feeobjectdefid
                       JOIN query.r_miscfeefeeschedule mffs
                           ON reo.objectid = mffs.feeobjectid
                 WHERE dpb.depositjobid IN
                           (SELECT objectid FROM sitespecific.deposits_gt)
                   AND p.isvoidedflag != 'Y')
        LOOP
            INSERT INTO paymentbatchmfs_gt(amount, code, isoverpayment)
                 VALUES (c.amount, c.code, c.isovr);
        END LOOP;

        -- Transmittal Payment Method Codes/Amounts
        FOR c
            IN (SELECT ft.amount, p.paymentmethodcode
                  FROM query.r_transmittaldeposit  td
                       JOIN query.j_transmittal t
                           ON td.transmittaljobid = t.jobid
                       JOIN query.r_transmittalpayment tp
                           ON t.jobid = tp.transmittaljobid
                       JOIN query.o_payment p
                           ON tp.paymentobjectid = p.objectid
                       JOIN api.paymenttransactions pt
                           ON p.paymentid = pt.paymentid
                       JOIN api.feetransactions ft
                           ON pt.transactionid = ft.transactionid
                 WHERE td.depositjobid IN
                           (SELECT objectid FROM sitespecific.deposits_gt)
                   AND p.isvoidedflag != 'Y')
        LOOP
            INSERT INTO transmittalpaymentcodes_gt(amount, paymentmethod)
                 VALUES (c.amount, c.paymentmethodcode);
        END LOOP;

        SELECT   (SELECT NVL(-SUM(t.amount), 0)
                    FROM sitespecific.transmittallfs_gt t
                   WHERE t.feeactivity IN ('SFP', 'FFP')
                     AND SUBSTR(t.office, 1, 2) IN ('50', '75')
                     AND t.isoverpayment = 'N')
               + (SELECT NVL(-SUM(mt.amount), 0) -- added 'RBSFFP', 'RBSSFP' for RBS complex entity finger printing fee WO-24001
                    from sitespecific.transmittalmfs_gt mt
                    WHERE mt.code IN ('RBSFFP', 'RBSSFP') 
                     AND SUBSTR(mt.office, 1, 2) IN ('77', '50') -- RBS office 77 pawan WO-24001 -- tjl added 50
                     AND mt.isoverpayment = 'N')
               + (SELECT NVL(-SUM(pb.amount), 0)
                    FROM sitespecific.paymentbatchlfs_gt pb
                   WHERE pb.feeactivity IN ('SFP', 'FFP')
                     AND pb.isoverpayment = 'N')
                   hqfingerprintfees,
                 (SELECT NVL(-SUM(t.amount), 0)
                    FROM sitespecific.transmittallfs_gt t
                   WHERE t.feeactivity = 'CHK'
                     AND SUBSTR(t.office, 1, 2) IN ('50', '75')
                     AND t.isoverpayment = 'N')
               + (SELECT NVL(-SUM(pb.amount), 0)
                    FROM sitespecific.paymentbatchlfs_gt pb
                   WHERE pb.feeactivity = 'CHK'
                     AND pb.isoverpayment = 'N')
                   hqdishonoredcheckcharges,
                 (SELECT NVL(-SUM(t.amount), 0)
                    FROM sitespecific.transmittallfs_gt t
                   WHERE (t.feeactivity NOT IN ('SFP', 'FFP', 'CHK')
                       OR t.isoverpayment = 'Y')
                     AND SUBSTR(t.office, 1, 2) IN ('50', '75'))
               + (SELECT NVL(-SUM(pb.amount), 0)
                    FROM sitespecific.paymentbatchlfs_gt pb
                   WHERE pb.feeactivity NOT IN ('SFP',
                                                'FFP',
                                                'CHK',
                                                'TCHK')
                      OR pb.isoverpayment = 'Y')
                   hqlicensefees,
                 (SELECT NVL(-SUM(t.amount), 0)
                    FROM sitespecific.transmittalmfs_gt t
                   WHERE (t.code NOT IN ('RFD',
                                         'SAR',
                                         'TAR',
                                         'APBD',
                                         'DAFF',
                                         'DAFS',
                                         'UTC',
                                         'RBSFFP', -- tjl 
                                         'RBSSFP')
                       OR t.isoverpayment = 'Y')
                     AND SUBSTR(t.office, 1, 2) IN ('50', '75', '77')) -- tjl added 77
               + (SELECT NVL(-SUM(pb.amount), 0)
                    FROM sitespecific.paymentbatchmfs_gt pb
                   WHERE pb.code NOT IN ('RFD',
                                         'SAR',
                                         'TAR',
                                         'APBD',
                                         'DAFF',
                                         'DAFS',
                                         'UTC',
                                         'RBSFFP',  -- tjl
                                         'RBSSFP')
                      OR pb.isoverpayment = 'Y')
                   hqmiscellaneousamrs,
                 (SELECT NVL(-SUM(t.amount), 0)
                    FROM sitespecific.transmittalmfs_gt t
                   WHERE t.code IN ('RFD', 'SAR', 'TAR')
                     AND SUBSTR(t.office, 1, 2) IN ('50', '75')
                     AND t.isoverpayment = 'N')
               + (SELECT NVL(-SUM(pb.amount), 0)
                    FROM sitespecific.paymentbatchmfs_gt pb
                   WHERE pb.code IN ('RFD', 'SAR', 'TAR')
                     AND pb.isoverpayment = 'N')
                   hqrevolvingfund,
                 (SELECT NVL(-SUM(t.amount), 0)
                    FROM sitespecific.transmittalmfs_gt t
                   WHERE t.code = 'APBD'
                     AND SUBSTR(t.office, 1, 2) IN ('50', '75')
                     AND t.isoverpayment = 'N')
               + (SELECT NVL(-SUM(pb.amount), 0)
                    FROM sitespecific.paymentbatchmfs_gt pb
                   WHERE pb.code = 'APBD'
                     AND pb.isoverpayment = 'N')
                   hqappealsboard,
                 (SELECT NVL(-SUM(t.amount), 0)
                    FROM sitespecific.transmittalmfs_gt t
                   WHERE t.code = 'DAFF'
                     AND SUBSTR(t.office, 1, 2) IN ('50', '75')
                     AND t.isoverpayment = 'N')
               + (SELECT NVL(-SUM(pb.amount), 0)
                    FROM sitespecific.paymentbatchmfs_gt pb
                   WHERE pb.code = 'DAFF'
                     AND pb.isoverpayment = 'N')
                   hqfederaldrugasset,
                 (SELECT NVL(-SUM(t.amount), 0)
                    FROM sitespecific.transmittalmfs_gt t
                   WHERE t.code = 'DAFS'
                     AND SUBSTR(t.office, 1, 2) IN ('50', '75')
                     AND t.isoverpayment = 'N')
               + (SELECT NVL(-SUM(pb.amount), 0)
                    FROM sitespecific.paymentbatchmfs_gt pb
                   WHERE pb.code = 'DAFS'
                     AND pb.isoverpayment = 'N')
                   hqstatedrugasset,
                 (SELECT NVL(-SUM(t.amount), 0)
                    FROM sitespecific.transmittalmfs_gt t
                   WHERE t.code = 'UTC'
                     AND SUBSTR(t.office, 1, 2) IN ('50', '75')
                     AND t.isoverpayment = 'N')
               + (SELECT NVL(-SUM(pb.amount), 0)
                    FROM sitespecific.paymentbatchmfs_gt pb
                   WHERE pb.code = 'UTC'
                     AND pb.isoverpayment = 'N')
                   hqunclaimedtrust,
               (SELECT NVL(-SUM(t.amount), 0)
                  FROM sitespecific.transmittallfs_gt t
                 WHERE t.feeactivity IN ('SFP', 'FFP')
                   AND SUBSTR(t.office, 1, 2) NOT IN ('50', '75')
                   AND t.isoverpayment = 'N')
                   distfingerprintfees,
               (SELECT NVL(-SUM(t.amount), 0)
                  FROM sitespecific.transmittallfs_gt t
                 WHERE t.feeactivity IN ('CHK', 'TCHK')
                   AND SUBSTR(t.office, 1, 2) NOT IN ('50', '75')
                   AND t.isoverpayment = 'N')
                   distdishonoredcheckcharges,
               (SELECT NVL(-SUM(t.amount), 0)
                  FROM sitespecific.transmittallfs_gt t
                 WHERE (t.feeactivity NOT IN ('SFP',
                                              'FFP',
                                              'CHK',
                                              'TCHK')
                     OR t.isoverpayment = 'Y')
                   AND SUBSTR(t.office, 1, 2) NOT IN ('50', '75'))
                   distlicensefees,
               (SELECT NVL(-SUM(t.amount), 0)
                  FROM sitespecific.transmittalmfs_gt t
                 WHERE (t.code NOT IN ('RFD',
                                       'SAR',
                                       'TAR',
                                       'APBD',
                                       'DAFF',
                                       'DAFS',
                                       'UTC' ,
                                       'RBSFFP',-- added 'RBSFFP', 'RBSSFP' for RBS complex entity finger printing fee WO-24001
                                       'RBSSFP',
                                       'RBSCC')--WO-24001 -- TJL
                     OR t.isoverpayment = 'Y')
                   AND SUBSTR(t.office, 1, 2) NOT IN ('50', '75'))
                   distmiscellaneousamrs,
               (SELECT NVL(-SUM(t.amount), 0)
                  FROM sitespecific.transmittalmfs_gt t
                 WHERE t.code IN ('RFD', 'SAR', 'TAR')
                   AND SUBSTR(t.office, 1, 2) NOT IN ('50', '75')
                   AND t.isoverpayment = 'N')
                   distrevolvingfund,
               (SELECT NVL(-SUM(t.amount), 0)
                  FROM sitespecific.transmittalmfs_gt t
                 WHERE t.code = 'APBD'
                   AND SUBSTR(t.office, 1, 2) NOT IN ('50', '75')
                   AND t.isoverpayment = 'N')
                   distappealsboard,
               (SELECT NVL(-SUM(t.amount), 0)
                  FROM sitespecific.transmittalmfs_gt t
                 WHERE t.code = 'DAFF'
                   AND SUBSTR(t.office, 1, 2) NOT IN ('50', '75')
                   AND t.isoverpayment = 'N')
                   distfederaldrugasset,
               (SELECT NVL(-SUM(t.amount), 0)
                  FROM sitespecific.transmittalmfs_gt t
                 WHERE t.code = 'DAFS'
                   AND SUBSTR(t.office, 1, 2) NOT IN ('50', '75')
                   AND t.isoverpayment = 'N')
                   diststatedrugasset,
               (SELECT NVL(-SUM(t.amount), 0)
                  FROM sitespecific.transmittalmfs_gt t
                 WHERE t.code = 'UTC'
                   AND SUBSTR(t.office, 1, 2) NOT IN ('50', '75')
                   AND t.isoverpayment = 'N')
                   distunclaimedtrust,
               (SELECT NVL(-SUM(t.amount), 0)
                  FROM sitespecific.transmittalpaymentcodes_gt t
                 WHERE t.paymentmethod = 'CASH')
                   cash,
                 (SELECT NVL(-SUM(t.amount), 0)
                    FROM sitespecific.transmittalpaymentcodes_gt t
                   WHERE t.paymentmethod IN ('GVT',
                                             'ABCK',
                                             'BCK',
                                             'PCK',
                                             'CCK',
                                             'MO'))
               + (SELECT NVL(-SUM(ft.amount), 0)
                    /*      from table(cast(api.pkg_SimpleSearch.CastableObjectsByIndexRange('j_Deposit',
                                                                                           'DepositDate',
                                                                                           to_char(a_StartDate, 'YYYY-MM-DD'),
                                                                                           to_char(a_EndDate, 'YYYY-MM-DD')) as api.udt_ObjectList)) d*/
                    FROM sitespecific.deposits_gt  d --APatterson: PIP Release 3 System Test.
                         --The Deposit JobIds for the date range already exist in this Global Temp table, no need to get them again.
                         --Takes this report from 12 mins to 10 secs.
                         JOIN query.r_depositpaymentbatch dpb
                             ON d.objectid = dpb.depositjobid
                         JOIN query.j_paymentbatch pb
                             ON dpb.paymentbatchjobid = pb.jobid
                         JOIN query.r_paymentbatchpayment pbp
                             ON pb.jobid = pbp.paymentbatchjobid
                         JOIN query.o_payment p
                             ON pbp.paymentobjectid = p.objectid
                         JOIN api.paymenttransactions pt
                             ON p.paymentid = pt.paymentid
                         JOIN api.feetransactions ft
                             ON pt.transactionid = ft.transactionid
                   WHERE p.paymentmethodcode = 'HQB'
                     AND p.isvoidedflag != 'Y')
                   checks,
               (SELECT NVL(-SUM(t.amount), 0)
                  FROM sitespecific.transmittalpaymentcodes_gt t
                 WHERE t.paymentmethod IN ('CC', 'CONV'))
                   cashconvertedtochecks
          INTO t_hqfingerprints,
               t_hqdishonoredcheckcharges,
               t_hqlicensefees,
               t_hqmiscamrs,
               t_hqrevolvingfund,
               t_hqappealsboard,
               t_hqfederaldrugasset,
               t_hqstatedrugasset,
               t_hqunclaimedtrust,
               t_distfingerprints,
               t_distdishonoredcheckcharges,
               t_distlicensefees,
               t_distmiscamrs,
               t_distrevolvingfund,
               t_distappealsboard,
               t_distfederaldrugasset,
               t_diststatedrugasset,
               t_distunclaimedtrust,
               t_cash,
               t_checks,
               t_cashconvertedtochecks
          FROM DUAL;

        INSERT INTO depositreport_gt(hqfingerprints,
                                     hqdishonoredcheckcharges,
                                     hqlicensefees,
                                     hqmiscamrs,
                                     hqrevolvingfund,
                                     hqappealsboard,
                                     hqfederaldrugasset,
                                     hqstatedrugasset,
                                     hqunclaimedtrust,
                                     distfingerprints,
                                     distdishonoredcheckcharges,
                                     distlicensefees,
                                     distmiscamrs,
                                     distrevolvingfund,
                                     distappealsboard,
                                     distfederaldrugasset,
                                     diststatedrugasset,
                                     distunclaimedtrust,
                                     cash,
                                     checks,
                                     cashconvertedtochecks)
             VALUES (t_hqfingerprints,
                     t_hqdishonoredcheckcharges,
                     t_hqlicensefees,
                     t_hqmiscamrs,
                     t_hqrevolvingfund,
                     t_hqappealsboard,
                     t_hqfederaldrugasset,
                     t_hqstatedrugasset,
                     t_hqunclaimedtrust,
                     t_distfingerprints,
                     t_distdishonoredcheckcharges,
                     t_distlicensefees,
                     t_distmiscamrs,
                     t_distrevolvingfund,
                     t_distappealsboard,
                     t_distfederaldrugasset,
                     t_diststatedrugasset,
                     t_distunclaimedtrust,
                     t_cash,
                     t_checks,
                     t_cashconvertedtochecks);
    END depositreport;

    --------------------------------------------------------
    -- WinegrowersCompletion() -- PUBLIC
    -- Run on completion of the Payment Batch.
    -- This procedure will automatically update the Gallonage domain field on the License Type job with the value
    -- entered on the batch.
    -- For a LT that has a Master LT we will not change the Gallonage for that LT or for its Master.  We will assess
    -- the fee but will not update the Gallonage.
    -- If Paid Amount > 0, the procedure will create a fee (transaction code AWF) for the amount and then create a
    -- payment for that amount.  Note, in the case of a Multiple entry, all the items listed under that entry are
    -- to be included in a single payment although they are all separate fees.
    --------------------------------------------------------
    PROCEDURE winegrowerscompletion(a_objectid udt_id, a_asofdate DATE)
    IS
        t_additionalmilliongallons   NUMBER;
        t_amounttopay                NUMBER;
        t_amountstopay               udt_numberlist;
        t_batchgallonage             NUMBER;
        t_feecount                   NUMBER;
        t_feeid                      udt_id;
        t_feeids                     udt_idlist;
        t_feeobjid                   udt_id;
        t_feeschedobjid              udt_id;
        t_galfeecode                 VARCHAR2(10);
        t_galrange                   VARCHAR2(15);
        t_hqreceipt                  VARCHAR2(8);
        t_jobid                      udt_id;
        t_ltcode                     VARCHAR2(2);
        t_ltobjectid                 udt_id;
        t_multiple                   VARCHAR2(1);
        t_paidamount                 NUMBER;
        t_newpaymentid               udt_id;
    BEGIN
        t_jobid   := api.pkg_columnquery.numericvalue(a_objectid, 'JobId');

        FOR c IN (SELECT pbpo.batchobjectid
                    FROM query.r_pbbatchpaymententry pbpo
                   WHERE pbpo.paymentbatchjobid = t_jobid)
        LOOP
            t_feeids.delete;
            t_feecount   := 0;
            t_amountstopay.delete;


            -- Get the HQ Receipt number
            t_hqreceipt   :=
                api.pkg_columnquery.VALUE(c.batchobjectid, 'PaymentNumber');

            t_multiple   :=
                api.pkg_columnquery.VALUE(c.batchobjectid, 'MultipleEntry');

            --if Multiple = 'Y' on the job, go through everytihng for Additional Items
            IF t_multiple = 'Y' THEN
                --Get the Additional Item objectIds that are related to the BatchPaymentsObject
                FOR m IN (SELECT bpai.additionalitemobjectid
                            FROM query.r_batchpaymentradditionalitem bpai
                           WHERE bpai.batchentryobjectid = c.batchobjectid)
                LOOP
                    --set t_PaidAmount, t_LTCode
                    t_paidamount   :=
                        api.pkg_columnquery.VALUE(m.additionalitemobjectid,
                                                  'PaidAmount');
                    t_ltcode   :=
                        api.pkg_columnquery.VALUE(m.additionalitemobjectid,
                                                  'LicenseTypeCode');

                    --get the LT objectId for the LT that is related to the additionalitem
                    SELECT ailt.licensetypejobid,
                           api.pkg_columnquery.numericvalue(
                               ailt.additionalitemobjectid,
                               'Gallonage')
                      INTO t_ltobjectid, t_batchgallonage
                      FROM query.r_additionalitemlicensetype ailt
                     WHERE ailt.additionalitemobjectid =
                           m.additionalitemobjectid;

                    --UPDATE GALLONAGE PRIOR TO CALLING PKG_CREATEWINEGROWERFEES
                    --Set the Gallonage Fee Code(s)
                    t_galfeecode   :=
                        api.pkg_columnquery.VALUE(m.additionalitemobjectid,
                                                  'GallonageFeeCode');

                    CASE
                        WHEN t_galfeecode = 'GL5K' THEN
                            t_galrange   := '0 TO 5K';
                        WHEN t_galfeecode = 'GL20K' THEN
                            t_galrange   := '5K TO 20K';
                        WHEN t_galfeecode = 'GL100K' THEN
                            t_galrange   := '20K TO 100K';
                        WHEN t_galfeecode = 'GL200K' THEN
                            t_galrange   := '100K TO 200K';
                        WHEN t_galfeecode = 'GL1M' THEN
                            t_galrange   := '200K TO 1M';
                    END CASE;

                    --if this LT does not have a Master LT then set the gallonage
                    IF api.pkg_columnquery.VALUE(t_ltobjectid,
                                                 'MasterLicenseNumber')
                           IS NULL THEN                           --Good code?
                        -- Remove Additional MillionGallons
                        api.pkg_columnupdate.removevalue(
                            t_ltobjectid,
                            'AdditionalMillionGallons');
                        --Set Gallonage on the LT based on the Gallonage from the o_AdditionalItem
                        api.pkg_columnupdate.setvalue(t_ltobjectid,
                                                      'GallonageRange',
                                                      t_galrange);

                        -- Set AdditionalMillionGallons on LT of the Gallonage Range is 1M and BatchGallonage > 1,000,000
                        IF t_galfeecode = 'GL1M'
                       AND t_batchgallonage > 1000000 THEN
                            t_additionalmilliongallons   :=
                                TRUNC(t_batchgallonage - 1, -6) * .000001;

                            api.pkg_columnupdate.setvalue(
                                t_ltobjectid,
                                'AdditionalMillionGallons',
                                t_additionalmilliongallons);
                        END IF;
                    END IF;

                    --If Paid Amount > 0, call pkg_CreateWinegrowerFees
                    IF t_paidamount >= 0 THEN           --edited KL 03_20_2010
                        sitespecific.pkg_accounting.createwinegrowerfees(
                            a_objectid,
                            NULL,
                            t_ltobjectid,
                            t_paidamount,
                            t_ltcode,
                            t_additionalmilliongallons,
                            t_galrange,
                            t_feeschedobjid,
                            t_feeid,
                            t_feeobjid);

                        --load arrays with data passed back from createwinegrowerfees where fee amount is greater then 0
                        IF t_paidamount > 0 THEN        --edited KL 03_22_2010
                            t_feecount                   := t_feecount + 1;
                            t_feeids(t_feecount)         := t_feeid;
                            t_amountstopay(t_feecount)   := t_paidamount;
                        END IF;

                        api.pkg_columnupdate.setvalue(t_feeobjid,
                                                      'HQReceipt',
                                                      t_hqreceipt);
                    END IF;
                END LOOP;

                --Create Payment for fees greater then 0
                pkg_accounting.createbatchpayments(t_feeids,
                                                   t_amountstopay,
                                                   t_jobid,
                                                   t_hqreceipt,
                                                   t_newpaymentid);

                INSERT INTO processesdepositedpayments_t
                     VALUES (t_jobid,
                             t_newpaymentid,
                             NULL,
                             NULL,
                             t_ltcode,
                             TRIM(SYSDATE));

                -- Remove values from FeeIds and Amounts to Pay
                t_feeids.delete;
                t_feecount   := 0;
                t_amountstopay.delete;
            ELSIF t_multiple = 'N' THEN
                --Check t_PaidAmount, t_LTCode
                t_paidamount   :=
                    api.pkg_columnquery.VALUE(c.batchobjectid,
                                              'TotalPaidAmount');
                t_ltcode   :=
                    api.pkg_columnquery.VALUE(c.batchobjectid,
                                              'LicenseTypeCode');

                -- Get the GallonageRange for the Batch Entry
                t_batchgallonage   :=
                    api.pkg_columnquery.numericvalue(c.batchobjectid,
                                                     'Gallonage');

                --get the LT objectId for the LT that is related to the additionalitem
                SELECT bplt.licensetypejobid
                  INTO t_ltobjectid
                  FROM query.r_ltbatchpaymententry bplt
                 WHERE bplt.batchpaymententryobjectid = c.batchobjectid;

                --UPDATE GALLONAGE PRIOR TO CALLING PKG_CREATEWINEGROWERFEES
                --Set the Gallonage Fee Code(s)
                t_galfeecode   :=
                    api.pkg_columnquery.VALUE(c.batchobjectid,
                                              'GallonageFeeCode');

                CASE
                    WHEN t_galfeecode = 'GL5K' THEN
                        t_galrange   := '0 TO 5K';
                    WHEN t_galfeecode = 'GL20K' THEN
                        t_galrange   := '5K TO 20K';
                    WHEN t_galfeecode = 'GL100K' THEN
                        t_galrange   := '20K TO 100K';
                    WHEN t_galfeecode = 'GL200K' THEN
                        t_galrange   := '100K TO 200K';
                    WHEN t_galfeecode = 'GL1M' THEN
                        t_galrange   := '200K TO 1M';
                END CASE;

                -- Set Additional Million Gallons var
                t_additionalmilliongallons   :=
                    TRUNC(t_batchgallonage - 1, -6) * .000001;

                --if this LT does not have a Master LT then set the gallonage
                IF api.pkg_columnquery.VALUE(t_ltobjectid,
                                             'MasterLicenseNumber')
                       IS NULL THEN
                    -- Remove Additional MillionGallons
                    api.pkg_columnupdate.removevalue(
                        t_ltobjectid,
                        'AdditionalMillionGallons');
                    -- Set Gallonage on the LT based on the Gallonage from the o_AdditionalItem
                    api.pkg_columnupdate.setvalue(t_ltobjectid,
                                                  'GallonageRange',
                                                  t_galrange);

                    -- Set AdditionalMillionGallons on LT of the Gallonage Range is 1M and BatchGallonage > 1,000,000
                    IF t_galfeecode = 'GL1M'
                   AND t_batchgallonage > 1000000 THEN
                        api.pkg_columnupdate.setvalue(
                            t_ltobjectid,
                            'AdditionalMillionGallons',
                            t_additionalmilliongallons);
                    END IF;
                END IF;

                --If Paid Amount >= 0, call pkg_CreateWinegrowerFees
                IF t_paidamount >= 0 THEN               --edited KL 03_20_2010
                    sitespecific.pkg_accounting.createwinegrowerfees(
                        a_objectid,
                        NULL,
                        t_ltobjectid,
                        t_paidamount,
                        t_ltcode,
                        t_additionalmilliongallons,
                        t_galrange,
                        t_feeschedobjid,
                        t_feeid,
                        t_feeobjid);

                    --load arrays with data passed back from pkg_andrew.createwinegrowerfees
                    IF t_feecount IS NULL THEN
                        t_feecount   := 0;
                    END IF;

                    IF t_paidamount > 0 THEN
                        t_feecount                   := t_feecount + 1;
                        t_feeids(t_feecount)         := t_feeid;
                        t_amountstopay(t_feecount)   := t_paidamount;
                    END IF;

                    api.pkg_columnupdate.setvalue(t_feeobjid,
                                                  'HQReceipt',
                                                  t_hqreceipt);
                END IF;

                --Create Payments for Fees greater then 0
                pkg_accounting.createbatchpayments(t_feeids,
                                                   t_amountstopay,
                                                   t_jobid,
                                                   t_hqreceipt,
                                                   t_newpaymentid,
                                                   'N');

                INSERT INTO processesdepositedpayments_t
                     VALUES (t_jobid,
                             t_newpaymentid,
                             NULL,
                             NULL,
                             t_ltcode,
                             TRIM(SYSDATE));
            END IF;
        END LOOP;
    END winegrowerscompletion;

    --------------------------------------------------------
    -- CreateWinegrowerFees() -- PUBLIC
    -- Called by sitespecific.pkg_Fees.WinegrowersCompletion
    -- Create a fee (transaction code AWF) for the amount passed in.
    --------------------------------------------------------
    PROCEDURE createwinegrowerfees(a_objectid         udt_id,
                                   a_asofdate         DATE,
                                   a_jobid            udt_id,
                                   a_feeamount        NUMBER,
                                   a_ltcode           VARCHAR2,
                                   a_additmgall       NUMBER,
                                   a_galrange         VARCHAR2,
                                   a_feeschedobjid OUT NUMBER,
                                   a_feeid        OUT NUMBER,
                                   a_feeobjid     OUT NUMBER)
    IS
        t_feefeeschedendpointid   udt_id;
        t_feefeeschedrelid        udt_id;
        t_glaccountid             udt_id;
        t_feeamount               udt_id;
        t_secondarycount          NUMBER;
    BEGIN
        sitespecific.pkg_fees.getltfeeamount(a_objectid,
                                             SYSDATE,
                                             'AWF',
                                             NULL,
                                             a_ltcode,
                                             a_galrange,
                                             NULL,
                                             NULL,
                                             NULL,
                                             'P', --This will return an ERROR, I think...
                                             1,
                                             a_asofdate,
                                             t_feeamount,
                                             a_feeschedobjid);

        t_feefeeschedendpointid   :=
            api.pkg_configquery.endpointidforname('o_Fee',
                                                  'LicenseFeeSchedule');

        --Get GLAccountId
        SELECT g.glaccountid
          INTO t_glaccountid
          FROM api.glaccounts g
         WHERE g.glaccount = 'AWF';

        IF a_feeamount >= 0 THEN
            sitespecific.pkg_fees.newfee(a_feeid,
                                         a_feeamount,
                                         'AWF',
                                         t_glaccountid,
                                         a_jobid,
                                         NULL,
                                         a_feeobjid,
                                         FALSE);
            --Set Fee Schedule Rel
            t_feefeeschedrelid   :=
                api.pkg_relationshipupdate.new(t_feefeeschedendpointid,
                                               a_feeobjid,
                                               a_feeschedobjid);
        END IF;                   --edited KL 03_20_2010 added the if statment

        api.pkg_columnupdate.setvalue(t_feefeeschedrelid, 'IsMaster', 'Y');
        t_secondarycount   := NVL(a_additmgall, 0);
        api.pkg_columnupdate.setvalue(t_feefeeschedrelid,
                                      'SecondaryCount',
                                      t_secondarycount);

        IF api.pkg_columnquery.VALUE(a_jobid, 'dup_LicenseTypeCode') IN
               (api.pkg_columnquery.VALUE(a_jobid,
                                          'SecondaryLicenseTypeCode')) THEN
            SELECT r.licensetypecount
              INTO t_secondarycount
              FROM query.j_licensetype  lt
                   JOIN query.r_licensetypeltcatsecondary r
                       ON r.licensetypejobid = lt.jobid
                   JOIN query.o_licensetypecategory ltc
                       ON ltc.objectid = r.licensetypecategoryobjectid
             WHERE ltc.licensetypecode = a_ltcode
               AND lt.objectid = a_jobid;

            api.pkg_columnupdate.setvalue(t_feefeeschedrelid,
                                          'SecondaryCount',
                                          t_secondarycount);
            api.pkg_columnupdate.setvalue(
                t_feefeeschedrelid,
                'MasterLT',
                api.pkg_columnquery.VALUE(a_jobid, 'dup_LicenseTypeCode'));
        END IF;
    END createwinegrowerfees;

    --------------------------------------------------------
    -- Relate LT to Object
    -- Used to relate License Types to BatchPaymentEntry and Additional Item objects in the Payment Batch job.
    -- Only does this for P-12 Renewals and Individual Renewal Fees (IR).
    --------------------------------------------------------
    PROCEDURE relatelttoobject(a_objectid NUMBER, a_asofdate DATE)
    IS
        t_objectdefname                  VARCHAR2(30);
        t_endpointid                     NUMBER;
        t_ltobjectid                     NUMBER;
        t_relid                          NUMBER;
        t_licensetypecode                VARCHAR2(2);
        t_licensenum                     VARCHAR2(40);
        t_paymentbatchtype               VARCHAR2(50);
        t_priorcount                     NUMBER;
        t_liccatcount                    NUMBER;
        t_ignoreerrduetostatus           VARCHAR2(1);
        t_batchentrypaybatchendpointid   udt_id
            := api.pkg_configquery.endpointidforname('o_BatchPaymentEntry',
                                                     'PaymentBatch');
        t_batchentryverifyendpointid     udt_id
            := api.pkg_configquery.endpointidforname('o_BatchPaymentEntry',
                                                     'PaymentBatchVerify');
    BEGIN
        t_licensetypecode   :=
            api.pkg_columnquery.VALUE(a_objectid, 'LicenseTypeCode');
        t_licensenum   := api.pkg_columnquery.VALUE(a_objectid, 'LicenseNum');
        t_paymentbatchtype   :=
            api.pkg_columnquery.VALUE(a_objectid, 'PaymentBatchType');

        --Select the Status, to See if the Errors should Raise
        SELECT CASE WHEN COUNT(js.statusid) > 0 THEN 'Y' ELSE 'N' END
          INTO t_ignoreerrduetostatus
          FROM api.relationships  rpbe
               JOIN api.jobs j ON j.jobid = rpbe.toobjectid
               JOIN api.jobstatuses js
                   ON js.jobtypeid = j.jobtypeid
                  AND j.statusid = js.statusid
         WHERE rpbe.fromobjectid = a_objectid
           AND rpbe.endpointid IN
                   (t_batchentrypaybatchendpointid,
                    t_batchentryverifyendpointid)
           AND js.statustype IN ('X', 'C');

    -- *************************************************************************
    -- The following code block to prevent exceptions being thrown when 
    -- creating and entering license number and license type code in Batch Payment 
    -- Entry object.  This procedure is called anytime the value is changed
    -- for license number or license type code.
    -- *************************************************************************
    -- ignore if this is production environment
    IF (UPPER(sys_context('USERENV', 'instance_name')) != 'ABISP1') THEN --  10/26/2022 Changed by Pawan
        if (t_LicenseNum is null or t_LicenseTypeCode is null) THEN 
            t_ignoreerrduetostatus := 'Y';
        END IF; 
    END IF; 
    -- *************************************************************************	

        --If there is no Entry PaymentBatchType, then get the Verify PaymentBatchType
        IF t_paymentbatchtype IS NULL THEN
            t_paymentbatchtype   :=
                api.pkg_columnquery.VALUE(a_objectid, 'PaymentBatchTypeVal');
        END IF;

        --If PaymentBatchType not POIC, then run procedure.
        --if t_PaymentBatchType <> 'PETITION FOR OFFER IN COMPROMISE (POIC)' then
        --Raise error when either LTCode or LicenseNum is null.  If both are null, skip to end.  If both are not null, then run.
        IF ((t_licensenum IS NULL
         AND t_licensetypecode IS NOT NULL)
         OR (t_licensetypecode IS NULL
         AND t_licensenum IS NOT NULL))
       AND (t_ignoreerrduetostatus != 'Y') THEN
            api.pkg_errors.raiseerror(
                -20000,
                'Please fill in both LT Code and License Num.');
        ELSIF t_licensenum IS NOT NULL
          AND t_licensetypecode IS NOT NULL THEN
            --Set ObjectDef variables
            SELECT od.name
              INTO t_objectdefname
              FROM api.objectdefs od
             WHERE od.objectdefid =
                   api.pkg_columnquery.numericvalue(a_objectid,
                                                    'ObjectDefId');

            --Set Endpoint for rel.
            t_endpointid   :=
                api.pkg_configquery.endpointidforname(t_objectdefname,
                                                      'LicenseType');

            BEGIN
                --Delete existing rel (in case a different LT was already related)
                SELECT r.relationshipid
                  INTO t_relid
                  FROM api.relationships r
                 WHERE r.fromobjectid = a_objectid
                   AND r.endpointid = t_endpointid;

                api.pkg_relationshipupdate.remove(t_relid);
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    NULL;
            END;                                                 --end Del Rel

            --Create new rel
            BEGIN
                SELECT lt.objectid
                  INTO t_ltobjectid
                  FROM query.j_licensetype  lt
                       JOIN query.r_licenselicensetype rllt
                           ON rllt.licensetypejobid = lt.objectid
                       JOIN query.j_license l
                           ON l.objectid = rllt.licensejobid
                 WHERE l.externalfilenum = t_licensenum
                   AND lt.dup_licensetypecode = t_licensetypecode
                   AND lt.statusname = 'ACTIVE';
            EXCEPTION
                WHEN NO_DATA_FOUND THEN -- if there are no 'ACTIVE' lts, get the other active first, then the max objectid from whatever is left
                    BEGIN
                        SELECT lt.objectid
                          INTO t_ltobjectid
                          FROM query.j_licensetype  lt
                               JOIN query.r_licenselicensetype rllt
                                   ON rllt.licensetypejobid = lt.objectid
                               JOIN query.j_license l
                                   ON l.objectid = rllt.licensejobid
                         WHERE l.externalfilenum = t_licensenum
                           AND lt.dup_licensetypecode = t_licensetypecode
                           AND lt.objectid =
                               (SELECT DECODE(
                                           lt.statusname,
                                           'SLMSHD', lt.objectid,
                                           'SUSPEN', lt.objectid,
                                           'SUREND', lt.objectid,
                                           'REVPEN', lt.objectid,
                                           'SUREND', lt.objectid,
                                           'R64B', lt.objectid,
                                           'PEND', lt.objectid,
                                           'ISSUPD', lt.objectid,
                                           (SELECT MAX(lt.objectid)
                                              FROM query.j_licensetype  lt
                                                   JOIN
                                                   query.r_licenselicensetype
                                                   rllt
                                                       ON rllt.licensetypejobid =
                                                          lt.objectid
                                                   JOIN query.j_license l
                                                       ON l.objectid =
                                                          rllt.licensejobid
                                             WHERE l.externalfilenum =
                                                   t_licensenum
                                               AND lt.dup_licensetypecode =
                                                   t_licensetypecode))
                                           obj_id
                                  FROM query.j_licensetype  lt
                                       JOIN query.r_licenselicensetype rllt
                                           ON rllt.licensetypejobid =
                                              lt.objectid
                                       JOIN query.j_license l
                                           ON l.objectid = rllt.licensejobid
                                 WHERE l.externalfilenum = t_licensenum
                                   AND lt.dup_licensetypecode =
                                       t_licensetypecode
                                   AND ROWNUM = 1);
                    /*   select max(lt.ObjectId)
                          from query.j_licensetype lt
                          join query.r_licenselicensetype rllt on rllt.LicenseTypeJobId = lt.ObjectId
                          join query.j_license l on l.ObjectId = rllt.LicenseJobId
                         where l.ExternalFileNum = t_licensenum
                           and lt.dup_LicenseTypeCode = t_licensetypecode);  */
                    EXCEPTION
                        WHEN NO_DATA_FOUND THEN
                            BEGIN                                      -- SLTs
                                SELECT lt2.objectid
                                  INTO t_ltobjectid
                                  FROM query.j_licensetype  lt2
                                       JOIN
                                       query.r_licensetypeltcatsecondary r2
                                           ON r2.licensetypejobid =
                                              lt2.objectid
                                       JOIN query.o_licensetypecategory ltc
                                           ON ltc.objectid =
                                              r2.licensetypecategoryobjectid
                                       JOIN query.r_licenselicensetype rllt
                                           ON rllt.licensetypejobid =
                                              lt2.objectid
                                       JOIN query.j_license l
                                           ON l.objectid = rllt.licensejobid
                                 WHERE l.externalfilenum = t_licensenum
                                   AND ltc.licensetypecode =
                                       t_licensetypecode
                                   AND r2.status = 'ACTIVE';
                            EXCEPTION
                                WHEN NO_DATA_FOUND THEN
                                    -- if there are no active SLTs, get the max objectid from the others
                                    BEGIN
                                        SELECT lt2.objectid
                                          INTO t_ltobjectid
                                          FROM query.j_licensetype  lt2
                                               JOIN
                                               query.r_licensetypeltcatsecondary
                                               r2
                                                   ON r2.licensetypejobid =
                                                      lt2.objectid
                                               JOIN
                                               query.o_licensetypecategory
                                               ltc
                                                   ON ltc.objectid =
                                                      r2.licensetypecategoryobjectid
                                               JOIN
                                               query.r_licenselicensetype
                                               rllt
                                                   ON rllt.licensetypejobid =
                                                      lt2.objectid
                                               JOIN query.j_license l
                                                   ON l.objectid =
                                                      rllt.licensejobid
                                         WHERE l.externalfilenum =
                                               t_licensenum
                                           AND ltc.licensetypecode =
                                               t_licensetypecode
                                           AND lt2.objectid =
                                               (SELECT DECODE(
                                                           lt2.statusname,
                                                           'SLMSHD', lt2.objectid,
                                                           'SUSPEN', lt2.objectid,
                                                           'SUREND', lt2.objectid,
                                                           'REVPEN', lt2.objectid,
                                                           'SUREND', lt2.objectid,
                                                           'R64B', lt2.objectid,
                                                           'PEND', lt2.objectid,
                                                           'ISSUPD', lt2.objectid,
                                                           (SELECT MAX(
                                                                       lt2.objectid)
                                                              FROM query.j_licensetype
                                                                   lt2
                                                                   JOIN
                                                                   query.r_licensetypeltcatsecondary
                                                                   r2
                                                                       ON r2.licensetypejobid =
                                                                          lt2.objectid
                                                                   JOIN
                                                                   query.o_licensetypecategory
                                                                   ltc
                                                                       ON ltc.objectid =
                                                                          r2.licensetypecategoryobjectid
                                                                   JOIN
                                                                   query.r_licenselicensetype
                                                                   rllt
                                                                       ON rllt.licensetypejobid =
                                                                          lt2.objectid
                                                                   JOIN
                                                                   query.j_license
                                                                   l
                                                                       ON l.objectid =
                                                                          rllt.licensejobid
                                                             WHERE l.externalfilenum =
                                                                   t_licensenum
                                                               AND ltc.licensetypecode =
                                                                   t_licensetypecode))
                                                           obj_id
                                                  FROM query.j_licensetype
                                                       lt2
                                                       JOIN
                                                       query.r_licensetypeltcatsecondary
                                                       r2
                                                           ON r2.licensetypejobid =
                                                              lt2.objectid
                                                       JOIN
                                                       query.o_licensetypecategory
                                                       ltc
                                                           ON ltc.objectid =
                                                              r2.licensetypecategoryobjectid
                                                       JOIN
                                                       query.r_licenselicensetype
                                                       rllt
                                                           ON rllt.licensetypejobid =
                                                              lt2.objectid
                                                       JOIN query.j_license l
                                                           ON l.objectid =
                                                              rllt.licensejobid
                                                 WHERE l.externalfilenum =
                                                       t_licensenum
                                                   AND ltc.licensetypecode =
                                                       t_licensetypecode
                                                   AND ROWNUM = 1);
                                    /* select max(lt2.objectid)
                                        from query.j_licensetype lt2
                                        join query.r_LicenseTypeLTCatSecondary r2 on r2.LicenseTypeJobId = lt2.ObjectId
                                        join query.o_licensetypecategory ltc on ltc.ObjectId = r2.LicenseTypeCategoryObjectId
                                        join query.r_licenselicensetype rllt on rllt.LicenseTypeJobId = lt2.ObjectId
                                        join query.j_license l on l.ObjectId = rllt.LicenseJobId
                                       where l.ExternalFileNum = t_LicenseNum
                                         and ltc.LicenseTypeCode = t_LicenseTypeCode);  */
                                    EXCEPTION
                                        WHEN NO_DATA_FOUND THEN
                                            api.pkg_errors.raiseerror(
                                                -20000,
                                                   t_licensetypecode
                                                || '-'
                                                || t_licensenum
                                                || ' is not an existing License Type.');
                                    END;
                            END;
                    END;
            END;

            t_relid   :=
                api.pkg_relationshipupdate.new(t_endpointid,
                                               a_objectid,
                                               t_ltobjectid);

            --if BatchType = Additional Wine Fees then check that the LT has Gallonage that applies, if it does not raise an error
            IF t_paymentbatchtype = 'ADDITIONAL WINE FEES (AWF)' THEN
                --select count of Licensetypecategories where the LT code = to t_LicenseTypeCode and where Gallonage applies.
                SELECT COUNT(1)
                  INTO t_liccatcount
                  FROM TABLE(
                           CAST(
                               api.pkg_simplesearch.castableobjectsbyindex(
                                   'o_LicenseTypeCategory',
                                   'LicenseTypeCode',
                                   t_licensetypecode) AS api.udt_objectlist))
                       x
                 WHERE api.pkg_columnquery.VALUE(x.objectid,
                                                 'GallonageApplies') =
                       'Y';

                CASE
                    WHEN t_liccatcount = 0 THEN
                        api.pkg_errors.raiseerror(
                            -20000,
                               'Gallonage does not apply for a '
                            || t_licensetypecode
                            || ' License Type.');
                    ELSE
                        NULL;
                END CASE;
            END IF;  --if Batchtype is AWF check gallonage applies for that LT
        END IF;                   --if both LTCode and LicenseNum are not null
    --end if; --PaymentBatchType not POIC
    END relatelttoobject;

    --------------------------------------------------------
    -- Create Batch Payments
    -- Called from Payment Batch Completion procedures to create payments for an array of FeeIds and array of Amounts
    -- Earned should be 'Earned' or 'Unearned' as appropriate for the FeeSchedule being paid.  Overpayments are separate Payment Transactions.
    --------------------------------------------------------
    PROCEDURE createbatchpayments(a_feeids           udt_idlist,
                                  a_amountstopay     udt_numberlist,
                                  a_jobid            NUMBER,
                                  a_hqreceipt        VARCHAR2,
                                  a_paymentid    OUT udt_id,
                                  a_setoverflag      VARCHAR DEFAULT 'Y',
                                  a_setpaymentstatus VARCHAR DEFAULT 'Y',
                                  a_setpaymentbatchid VARCHAR DEFAULT 'Y',
                                  a_cabinincomeind   VARCHAR2 DEFAULT 'I',
                                  a_cabinamttype     VARCHAR2 DEFAULT 'I')
    IS
        t_earnedamount                  NUMBER;
        t_paytransobjectid              NUMBER;
        t_transactionobjid              NUMBER;
        t_paymentstatusobjid            NUMBER;
        t_paymentstatusdefid            NUMBER;
        t_paytranspaystatusendpointid   NUMBER;
        t_paymentid                     NUMBER;
        t_paymentobjid                  NUMBER;
        t_relid                         NUMBER;
        t_earnedon                      VARCHAR2(20);
        t_jobpaymentendpointid          NUMBER;
        t_paymentmethodobjid            NUMBER;
        t_paymentmethodendpointid       NUMBER;
        t_ovrfeeids                     udt_idlist;
        t_ovramountstopay               udt_numberlist;
        t_feeids                        udt_idlist;
        t_amountstopay                  udt_numberlist;
        t_jobdefid                      NUMBER;
        t_paytransobjectdefid           udt_id
            := api.pkg_configquery.objectdefidforname(
                   'o_PaymentTransactions');
    BEGIN
        t_paytranspaystatusendpointid   :=
            api.pkg_configquery.endpointidforname('o_PaymentTransactions',
                                                  'PaymentStatus');
        t_jobdefid                  := api.pkg_columnquery.VALUE(a_jobid, 'ObjectDefId');
        t_jobpaymentendpointid      :=
            api.pkg_configquery.endpointidforname(t_jobdefid, 'Payment');
        t_paymentmethodendpointid   :=
            api.pkg_configquery.endpointidforname('o_Payment',
                                                  'PaymentMethod');
        t_paymentstatusdefid        :=
            api.pkg_configquery.objectdefidforname('o_PaymentStatus');
        t_feeids                    := a_feeids;
        t_amountstopay              := a_amountstopay;

        /*  for test2 in 1..t_FeeIds.count loop
            dbms_Output.put_Line('pret_FeeIds: ' || t_FeeIds(test2));
            dbms_Output.put_Line('pret_RefundAmounts: ' || t_AmountsToPay(test2));
          end loop;*/

        IF a_setoverflag = 'Y' THEN
            --Create Overpayment feeID and Amounts to pay arrays (in order to have separate, flagged PaymentTransactions)
            sitespecific.pkg_fees.calculateoverpayment(t_feeids,
                                                       t_amountstopay,
                                                       t_ovrfeeids,
                                                       t_ovramountstopay);
        END IF;

        /*  for test2 in 1..t_FeeIds.count loop
            dbms_Output.put_Line('postt_FeeIds: ' || t_FeeIds(test2));
            dbms_Output.put_Line('postt_RefundAmounts: ' || t_AmountsToPay(test2));
          end loop;*/

        --Create payment
        t_paymentid                 :=
            api.pkg_paymentupdate.new(SYSDATE, t_feeids, t_amountstopay);
        t_paymentobjid              :=
            api.pkg_objectupdate.registerexternalobject('o_Payment',
                                                        t_paymentid);

        -- Set the income code for the payment to 'R'
        api.pkg_columnupdate.setvalue(t_paymentobjid,
                                      'CABINIncomeInd',
                                      a_cabinincomeind);

        --Pass out the Payment Id
        a_paymentid                 := t_paymentid;



        --For each Payment Transaction for the Payment that was just created, register the external Payment Transaction and Fee Transaction
        -- RyanL: Changed the select clause to be a subselect for prerformance (PIP Task 8.5)
        FOR c1
            IN (SELECT pt.transactionid,
                       ft.amount,
                       (  f.amount
                        + NVL((SELECT SUM(amount)
                                 FROM api.feetransactions ft
                                WHERE ft.feeid = f.feeid
                                  AND ft.transactiontype = 'Adj'),
                              0))
                           feeamount,
                       f.feeid
                  FROM api.paymenttransactions  pt
                       JOIN api.feetransactions ft
                           ON ft.transactionid = pt.transactionid
                       JOIN api.fees f ON f.feeid = ft.feeid
                 WHERE pt.paymentid = t_paymentid)
        LOOP
            t_paytransobjectid   :=
                api.pkg_objectupdate.registerexternalobject(
                    'o_PaymentTransactions',
                    c1.transactionid);
            t_transactionobjid   :=
                api.pkg_objectupdate.registerexternalobject(
                    'o_FeeTransactions',
                    c1.transactionid);

            -- Get the summed earned amounts for this transaction
            SELECT  /*+ CARDINALITY (pt 1) */
                   NVL(
                       ABS(
                           SUM(
                               api.pkg_columnquery.numericvalue(
                                   r.paymentstatusobjectid,
                                   'EarnedAmount'))),
                       0)
              INTO t_earnedamount
              FROM api.feetransactions  ft
                   JOIN api.registeredexternalobjects reo --TAyers: PIP Task 8.5
                       ON reo.linkvalue = TO_CHAR(ft.transactionid)
                      AND reo.objectdefid = t_paytransobjectdefid
                   JOIN query.r_paymentstatuspaymenttrans r
                       ON r.paymenttransactionobjectid = reo.objectid
             WHERE ft.feeid = c1.feeid;

            -- Set the income code for the payment transactions to 'R'
            api.pkg_columnupdate.setvalue(t_paytransobjectid,
                                          'CABINAmtType',
                                          a_cabinamttype);

            -- Set HQReceipt on the Payment Transaction
            api.pkg_columnupdate.setvalue(t_paytransobjectid,
                                          'HQReceipt',
                                          a_hqreceipt);

            IF a_setpaymentstatus = 'Y'
           AND t_earnedamount < c1.feeamount THEN
                IF t_earnedamount - c1.amount > c1.feeamount THEN
                    t_earnedamount   := -c1.feeamount + t_earnedamount;
                ELSE
                    t_earnedamount   := c1.amount;
                END IF;

                --Get earned information from the feetransactions's feeschedule record
                SELECT api.pkg_columnquery.VALUE(fs.objectid, 'EarnedOn')
                  INTO t_earnedon
                  FROM query.o_feetransactions  ft
                       JOIN sitespecific.feeschedule_t fs
                           ON fs.objectid =
                              sitespecific.pkg_fees.getlicfeeschedulobjid(
                                  ft.feeid)
                 WHERE ft.objectid = t_transactionobjid;

                --If fee is earned on payment, create Payment Status
                IF t_earnedon = 'PAYMENT'
               AND api.pkg_columnquery.VALUE(t_paytransobjectid,
                                             'IsOverpayment') =
                   'N' THEN
                    --create paymentstatus for paymenttransactions
                    t_paymentstatusobjid   :=
                        api.pkg_objectupdate.new(t_paymentstatusdefid);
                    --set details on PaymentStatus Object
                    api.pkg_columnupdate.setvalue(t_paymentstatusobjid,
                                                  'Status',
                                                  'EARNED');
                    api.pkg_columnupdate.setvalue(t_paymentstatusobjid,
                                                  'StatusDate',
                                                  TRUNC(SYSDATE));
                    api.pkg_columnupdate.setvalue(t_paymentstatusobjid,
                                                  'SystemGenerated',
                                                  'Y');
                    api.pkg_columnupdate.setvalue(t_paymentstatusobjid,
                                                  'EarnedAmount',
                                                  t_earnedamount);
                    --create rel to paymentstatus from paymentTransaction
                    t_relid   :=
                        api.pkg_relationshipupdate.new(
                            t_paytranspaystatusendpointid,
                            t_paytransobjectid,
                            t_paymentstatusobjid);
                END IF;
            END IF;
        END LOOP;                       --Register object, payment status loop

        IF a_setoverflag = 'Y' THEN
            --If Payment Transaction is overpayment, set flag to indicate it (used in Fees  grid)
            sitespecific.pkg_fees.setpaymenttransactionflag(
                t_ovrfeeids,
                t_ovramountstopay,
                'IsOverpayment');
        END IF;

        --Get Payment Method ObjectId
        BEGIN
            SELECT pm.objectid
              INTO t_paymentmethodobjid
              FROM query.o_paymentmethod pm
             WHERE pm.code = 'HQB';
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                api.pkg_errors.raiseerror(
                    -20000,
                    'No Payment Method with the Code ''HQB'' exists.');
        END;

        --Set Payment BatchPaymentId
        IF a_setpaymentbatchid = 'Y' THEN
            api.pkg_columnupdate.setvalue(
                t_paymentobjid,
                'BatchPaymentId',
                api.pkg_columnquery.VALUE(a_jobid, 'ExternalFileNum'));
        END IF;

        --Set Payment PaymentDateStored
        api.pkg_columnupdate.setvalue(t_paymentobjid,
                                      'PaymentDateStored',
                                      TRUNC(SYSDATE));

        --Relate Payment to Payment Method
        t_relid                     :=
            api.pkg_relationshipupdate.new(t_paymentmethodendpointid,
                                           t_paymentobjid,
                                           t_paymentmethodobjid);

        --Relate Payment to Payment Batch job
        t_relid                     :=
            api.pkg_relationshipupdate.new(t_jobpaymentendpointid,
                                           a_jobid,
                                           t_paymentobjid);

        --Set Payment PaymentDateStored
        api.pkg_columnupdate.setvalue(
            t_paymentobjid,
            'PaymentAmountStored',
            api.pkg_columnquery.VALUE(t_paymentobjid, 'PaymentAmount'));
    END createbatchpayments;


    --------------------------------------------------------
    -- POICCompletion - public
    -- Run from payment batch for POIC payments, this will pay appropriate POIC fees.
    --------------------------------------------------------
    PROCEDURE poiccompletion(a_objectid      NUMBER,
                             a_asofdate      DATE,
                             a_jobid         NUMBER)
    IS
        t_multiple       VARCHAR(2);
        t_amountstopay   udt_numberlist;
        t_finalfeeids    udt_idlist;
        t_feeid          udt_id;
        t_feecount       NUMBER := 0;
        t_jobid          NUMBER;
        t_ltcode         VARCHAR2(2);
        t_paidamount     NUMBER;
        t_newpaymentid   udt_id;
        t_hqreceipt      VARCHAR2(8);
    BEGIN
        --Loop through Batch Payment Objects
        FOR c IN (SELECT pbpo.batchobjectid
                    FROM query.r_pbbatchpaymententry pbpo
                   WHERE pbpo.paymentbatchjobid = a_jobid)
        LOOP
            --POIC has a payment per batchpaymententry object, arrays are restarted, while P12s only have one payment, and so add to array
            t_finalfeeids.delete;
            t_amountstopay.delete;
            t_feecount   := 0;

            -- Get the HQ Receipt number fromt the Addit Item
            t_hqreceipt   :=
                api.pkg_columnquery.VALUE(c.batchobjectid, 'PaymentNumber');

            t_multiple   :=
                api.pkg_columnquery.VALUE(c.batchobjectid, 'MultipleEntry');

            --if Multiple = 'Y' on the job, loop through Additional Items
            IF t_multiple = 'Y' THEN
                --Get the Additional Item objectIds that are related to the BatchPaymentsObject
                FOR m IN (SELECT bpai.additionalitemobjectid
                            FROM query.r_batchpaymentradditionalitem bpai
                           WHERE bpai.batchentryobjectid = c.batchobjectid)
                LOOP
                    --set t_PaidAmount
                    t_paidamount   :=
                        api.pkg_columnquery.VALUE(m.additionalitemobjectid,
                                                  'PaidAmount');
                    t_ltcode   :=
                        api.pkg_columnquery.VALUE(m.additionalitemobjectid,
                                                  'LicenseTypeCode');

                    --get the LT objectId for the LT that is related to the additionalitem
                    SELECT llt.licensejobid
                      INTO t_jobid
                      FROM query.r_additionalitemlicensetype  ailt
                           JOIN query.j_licensetype lt
                               ON lt.objectid = ailt.licensetypejobid
                           JOIN query.r_licenselicensetype llt
                               ON llt.licensetypejobid = lt.jobid
                     WHERE ailt.additionalitemobjectid =
                           m.additionalitemobjectid;

                    --If Paid Amount > 0, call pkg_CreateWinegrowerFees
                    IF t_paidamount >= 0 THEN
                        -- Create the Fee
                        pkg_fees.createprocesspoicfee(t_jobid,
                                                      SYSDATE,
                                                      t_jobid,
                                                      t_paidamount,
                                                      t_ltcode,
                                                      t_feeid);


                        t_feecount                   := t_feecount + 1;
                        t_finalfeeids(t_feecount)    := t_feeid;
                        t_amountstopay(t_feecount)   := t_paidamount;
                    END IF;
                END LOOP;

                -- Create Payment for POIC (one per BatchPaymentEntry Item)
                pkg_accounting.createbatchpayments(t_finalfeeids,
                                                   t_amountstopay,
                                                   a_jobid,
                                                   t_hqreceipt,
                                                   t_newpaymentid);


                INSERT INTO processesdepositedpayments_t
                     VALUES (a_jobid,
                             t_newpaymentid,
                             NULL,
                             NULL,
                             t_ltcode,
                             TRIM(SYSDATE));

                t_finalfeeids.delete;
                t_amountstopay.delete;
                t_feecount   := 0;
            --If Multiple is N  then look at BatchPaymentEntry objects instead of Additional Items
            ELSIF t_multiple = 'N' THEN
                --Check t_PaidAmount
                t_paidamount   :=
                    api.pkg_columnquery.VALUE(c.batchobjectid,
                                              'TotalPaidAmount');
                t_ltcode   :=
                    api.pkg_columnquery.VALUE(c.batchobjectid,
                                              'LicenseTypeCode');

                --get the LT objectId for the LT that is related to the additionalitem
                SELECT llt.licensejobid
                  INTO t_jobid
                  FROM query.r_ltbatchpaymententry  bplt
                       JOIN query.j_licensetype lt
                           ON lt.objectid = bplt.licensetypejobid
                       JOIN query.r_licenselicensetype llt
                           ON llt.licensetypejobid = lt.jobid
                 WHERE bplt.batchpaymententryobjectid = c.batchobjectid;

                --If Paid Amount > 0, call pkg_CreateWinegrowerFees
                IF t_paidamount >= 0 THEN
                    -- Create the Fee
                    pkg_fees.createprocesspoicfee(t_jobid,
                                                  SYSDATE,
                                                  t_jobid,
                                                  t_paidamount,
                                                  t_ltcode,
                                                  t_feeid);


                    t_feecount                   := t_feecount + 1;
                    t_finalfeeids(t_feecount)    := t_feeid;
                    t_amountstopay(t_feecount)   := t_paidamount;
                END IF;
            END IF;

            --Create Payment for POIC (one per BatchPaymentEntry Item)
            pkg_accounting.createbatchpayments(t_finalfeeids,
                                               t_amountstopay,
                                               a_jobid,
                                               t_hqreceipt,
                                               t_newpaymentid,
                                               'N');
        END LOOP;
    END poiccompletion;


    --------------------------------------------------------
    -- IRP12Completion - public
    -- Run from j_PaymentBatch for IR and P-12 batch types, this will create and pay appropriate REN fees.
    -- P12 is one payment, while IR has a payment per BatchPaymentEntry object on the Payment Batch job.
    --------------------------------------------------------
    PROCEDURE irp12completion(a_objectid      udt_id,
                              a_asofdate      DATE,
                              a_jobid         udt_id)
    IS
        t_multiple              VARCHAR2(1);
        t_ltobjectid            udt_id;
        t_paidamount            NUMBER;
        t_ltcode                VARCHAR2(2);
        t_amountstopay          udt_numberlist;
        t_finalfeeids           udt_idlist;
        t_paymentbatchtype      VARCHAR2(50);
        t_ltexpirationdate      DATE;
        t_receivepaymentid      udt_id;
        t_receivepaymentdefid   udt_id;
        t_rentype               VARCHAR2(10);
        t_newpaymentid          udt_id;
        t_hqreceipt             VARCHAR2(8);
        t_copyfeecode           VARCHAR2(500);
        t_ltjobids              udt_idlist;
    BEGIN
        t_paymentbatchtype   :=
            api.pkg_columnquery.VALUE(a_jobid, 'PaymentBatchType');
        t_rentype   := api.pkg_columnquery.VALUE(a_jobid, 'Penalty');

        --Loop through Batch Payment Objects
        FOR c IN (SELECT pbpo.batchobjectid
                    FROM query.r_pbbatchpaymententry pbpo
                   WHERE pbpo.paymentbatchjobid = a_jobid)
        LOOP
            --IR has a payment per batchpaymententry object, arrays are restarted, while P12s only have one payment, and so add to array
            IF t_paymentbatchtype <> 'P-12 RENEWALS' THEN
                t_finalfeeids.delete;
                t_amountstopay.delete;
            END IF;

            --FREEZE the Transaction Codes on the Batch Entry object
            t_copyfeecode   :=
                api.pkg_columnquery.VALUE(c.batchobjectid, 'FeeCodesForGrid');
            api.pkg_columnupdate.setvalue(c.batchobjectid,
                                          'FeeCodesForGrid',
                                          'x');
            api.pkg_columnupdate.setvalue(c.batchobjectid,
                                          'FeeCodesForGrid',
                                          t_copyfeecode);

            -- Get the HQ Receipt number fromt he Addit Item
            t_hqreceipt   :=
                api.pkg_columnquery.VALUE(c.batchobjectid, 'PaymentNumber');

            t_multiple   :=
                api.pkg_columnquery.VALUE(c.batchobjectid, 'MultipleEntry');

            --if Multiple = 'Y' on the job, loop through Additional Items
            IF t_multiple = 'Y'
            OR t_paymentbatchtype = 'P-12 RENEWALS' THEN
                --Get the Additional Item objectIds that are related to the BatchPaymentsObject
                FOR m IN (SELECT bpai.additionalitemobjectid
                            FROM query.r_batchpaymentradditionalitem bpai
                           WHERE bpai.batchentryobjectid = c.batchobjectid)
                LOOP
                    --FREEZE the Transaction Codes on the Additional Item
                    t_copyfeecode                        :=
                        api.pkg_columnquery.VALUE(m.additionalitemobjectid,
                                                  'FeeCodes');
                    api.pkg_columnupdate.setvalue(m.additionalitemobjectid,
                                                  'FeeCodes',
                                                  'x');
                    api.pkg_columnupdate.setvalue(m.additionalitemobjectid,
                                                  'FeeCodes',
                                                  t_copyfeecode);
                    --set t_PaidAmount, t_LTCode
                    t_paidamount                         :=
                        api.pkg_columnquery.VALUE(m.additionalitemobjectid,
                                                  'PaidAmount');
                    t_ltcode                             :=
                        api.pkg_columnquery.VALUE(m.additionalitemobjectid,
                                                  'LicenseTypeCode');

                    --get the LT objectId for the LT that is related to the additionalitem
                    SELECT ailt.licensetypejobid, lt.expirationdate
                      INTO t_ltobjectid, t_ltexpirationdate
                      FROM query.r_additionalitemlicensetype  ailt
                           JOIN query.j_licensetype lt
                               ON lt.objectid = ailt.licensetypejobid
                     WHERE ailt.additionalitemobjectid =
                           m.additionalitemobjectid;

                    --Get array of FeeIds and Corresponding Amounts based on Paid Amount (this could include creating new REN fee).
                    --FinalFeeIds will be added to in each additional item loop (which will all be one payment).
                    pkg_accounting.getrenfeeidsandamounts(t_paidamount,
                                                          t_ltcode,
                                                          t_ltobjectid,
                                                          t_ltexpirationdate,
                                                          t_rentype,
                                                          t_finalfeeids,
                                                          t_amountstopay);

                    --add each t_LTObjectID to the array
                    --t_LTJobIds.extend(1, t_LTObjectId);
                    t_ltjobids(t_ltjobids.COUNT() + 1)   := t_ltobjectid;
                END LOOP;
            --If Multiple is N and this is not a P-12 payment batch, then look at BatchPaymentEntry objects instead of Additional Items
            ELSIF t_multiple = 'N' THEN
                --Check t_PaidAmount, t_LTCode
                t_paidamount   :=
                    api.pkg_columnquery.VALUE(c.batchobjectid,
                                              'TotalPaidAmount');
                t_ltcode   :=
                    api.pkg_columnquery.VALUE(c.batchobjectid,
                                              'LicenseTypeCode');

                --get the LT objectId for the LT that is related to the additionalitem
                SELECT bplt.licensetypejobid, lt.expirationdate
                  INTO t_ltobjectid, t_ltexpirationdate
                  FROM query.r_ltbatchpaymententry  bplt
                       JOIN query.j_licensetype lt
                           ON lt.objectid = bplt.licensetypejobid
                 WHERE bplt.batchpaymententryobjectid = c.batchobjectid;

                --Get array of FeeIds and Corresponding Amounts based on Paid Amount
                --This could include creating new REN fee or updating existing fee to current Penalty).
                pkg_accounting.getrenfeeidsandamounts(t_paidamount,
                                                      t_ltcode,
                                                      t_ltobjectid,
                                                      t_ltexpirationdate,
                                                      t_rentype,
                                                      t_finalfeeids,
                                                      t_amountstopay);
            END IF;

            --Create Payment for IR (one per BatchPaymentEntry Item)
            IF t_paymentbatchtype <> 'P-12 RENEWALS' THEN
                pkg_accounting.createbatchpayments(t_finalfeeids,
                                                   t_amountstopay,
                                                   a_jobid,
                                                   t_hqreceipt,
                                                   t_newpaymentid,
                                                   'N');

                -- Insert into the table to allow Deposite procedure to set the Batch flags correctly and R2Idate
                IF t_multiple = 'N' THEN
                    INSERT INTO processesdepositedpayments_t
                             VALUES (
                                        t_ltobjectid,
                                        t_newpaymentid,
                                        NULL,
                                        NULL,
                                        api.pkg_columnquery.VALUE(
                                            t_ltobjectid,
                                            'LicenseTypeCode'),
                                        TRIM(SYSDATE));
                ELSIF t_multiple = 'Y' THEN
                    --loop through additional items to insert into table.
                    FOR lts IN 1 .. t_ltjobids.COUNT()
                    LOOP
                        INSERT INTO processesdepositedpayments_t
                                 VALUES (
                                            t_ltjobids(lts),
                                            t_newpaymentid,
                                            NULL,
                                            NULL,
                                            api.pkg_columnquery.VALUE(
                                                t_ltjobids(lts),
                                                'LicenseTypeCode'),
                                            TRIM(SYSDATE));
                    END LOOP;
                END IF;
            END IF;
        END LOOP;

        --Create Payment for P12 (one payment for entire job)
        IF t_paymentbatchtype = 'P-12 RENEWALS' THEN
            pkg_accounting.createbatchpayments(t_finalfeeids,
                                               t_amountstopay,
                                               a_jobid,
                                               t_hqreceipt,
                                               t_newpaymentid,
                                               'N');

            --Loop through additional items to insert into table.
            FOR lts IN 1 .. t_ltjobids.COUNT()
            LOOP
                INSERT INTO processesdepositedpayments_t
                         VALUES (
                                    t_ltjobids(lts),
                                    t_newpaymentid,
                                    NULL,
                                    NULL,
                                    api.pkg_columnquery.VALUE(
                                        t_ltjobids(lts),
                                        'LicenseTypeCode'),
                                    TRIM(SYSDATE));
            END LOOP;
        END IF;
    END irp12completion;


    -------------------------------------------------------------------
    -- GetRENFeeIdsAndAmounts  - PUBLIC
    -- When a LicenseType has prior REN fees of a previous variety to the Payment Batch's Penalty field,
    -- only the most recent will be updated to the Penalty REN Type.  All of them will be considered for payment
    -- (those owing are paid and the most recent fee gets the overpayment)
    -------------------------------------------------------------------
    PROCEDURE getrenfeeidsandamounts(a_paidamount          NUMBER,
                                     a_ltcode              VARCHAR2,
                                     a_ltobjectid          NUMBER,
                                     a_ltexpirationdate    DATE,
                                     a_rentype             VARCHAR2,
                                     a_finalfeeids  IN OUT udt_idlist,
                                     a_amountstopay IN OUT udt_numberlist)
    IS
        t_temp                VARCHAR2(10);
        t_priorfeeactivity    VARCHAR2(6);
        t_checkexists         VARCHAR2(20);
        t_feeid               NUMBER;
        t_createfeerentype    VARCHAR2(15);
        t_tfeeids             udt_idlist;
        t_renexpirationdate   DATE;
    BEGIN
        --Set REN info details.
        IF a_rentype = 'Timely' THEN
            t_checkexists        := 'REN.REN50.REN100.';
            t_createfeerentype   := 'Renewal';
        ELSIF a_rentype = '50%' THEN
            t_checkexists        := 'REN50.REN100.';
            t_createfeerentype   := '50% Penalty';
        ELSIF a_rentype = '100%' THEN
            t_checkexists        := 'REN100.';
            t_createfeerentype   := '100% Penalty';
        END IF;

        /*--Load all REN fees on LT Job for the LTCode into array (from earliest to newest)
        select f.feeid bulk collect into t_TFeeIds
          from api.fees f
          join sitespecific.feeschedule_t fs on fs.objectid = sitespecific.pkg_fees.getlicfeeschedulobjid(f.feeid)
          where f.JobId = a_LTObjectId
          and fs.feeactivity in ('REN', 'REN50', 'REN100')
          and fs.licensetypecode = a_LTCode
          order by 1;

        --If no fee exists, create one; else update existing one
          begin
            select t_TFeeIds(1) into t_Temp from dual;

            --Get last FeeId in array
            t_FeeId := t_TFeeIds(t_TFeeIds.count);

            --Get FeeSchedule record for last FeeId in array
            select fs.feeactivity, api.pkg_columnquery.datevalue(f.objectid, 'RENExpirationDate') into t_PriorFeeActivity, t_RENExpirationDate
              from table(cast(api.pkg_simplesearch.CastableObjectsByIndex('o_Fee', 'FeeId', t_feeid) as api.udt_ObjectList)) f
              join sitespecific.feeschedule_t fs on fs.objectid = sitespecific.pkg_fees.GetLicFeeSchedulObjId(t_feeid);

            --If the last FeeId's FeeActivity is not the same or after the feeactivity for the Penalty on this Payment Batch, then update fee.
            if t_CheckExists not like '%'||t_PriorFeeActivity||'.'||'%' then
              sitespecific.pkg_fees.CreateRenewalFees(null, null, a_LTObjectId, t_RENExpirationDate, t_CreateFeeRENType, 'B', t_temp);
            end if;

          exception when no_data_found then
               sitespecific.pkg_fees.CreateRenewalFees(null, null, a_LTObjectId, a_LTExpirationDate, t_CreateFeeRENType, 'B', t_temp);
          end;*/

        -- Create or update the REN fees for this License Type
        sitespecific.pkg_fees.createrenewalfees(NULL,
                                                NULL,
                                                a_ltobjectid,
                                                a_ltexpirationdate,
                                                t_createfeerentype,
                                                'B',
                                                t_temp);

        --Reload feeid list (a new one would have been added if the original array had nothing in it).
        SELECT q.feeid
          BULK COLLECT INTO t_tfeeids
          FROM (  SELECT f.feeid, f.transactiondate
                    FROM api.fees f
                         JOIN sitespecific.feeschedule_t fs
                             ON fs.objectid =
                                sitespecific.pkg_fees.getlicfeeschedulobjid(
                                    f.feeid)
                   WHERE f.jobid = a_ltobjectid
                     AND fs.feeactivity IN ('REN', 'REN50', 'REN100')
                     AND fs.licensetypecode = a_ltcode
                ORDER BY 2 DESC) q
         WHERE ROWNUM = 1;

        --Get Final array of FeeIds and Corresponding Amounts based on Paid Amount
        pkg_accounting.setamountsforfeeids(t_tfeeids,
                                           a_paidamount,
                                           a_amountstopay,
                                           a_finalfeeids);
    END getrenfeeidsandamounts;

    --------------------------------------------------------
    -- Set Amounts for FeeIdArray - public
    -- Called from Payment Batch completion procedures to take a array of FeeIds and a total PaidAmount,
    -- and gives a corresponding payment amount for each feeid, which is passed out in another array
    -- (since some feeids in the original list would have payments of zero otherwise).
    --------------------------------------------------------
    PROCEDURE setamountsforfeeids(a_feeids              udt_idlist,
                                  a_paidamount          NUMBER,
                                  a_amountstopay IN OUT udt_numberlist,
                                  a_finalfeeids  IN OUT udt_idlist)
    IS
        t_totalowing    NUMBER;
        t_topayamount   NUMBER;
        t_paidamount    NUMBER;
        t_feeid         NUMBER;
        t_temp          NUMBER;
    BEGIN
        t_paidamount                               := a_paidamount;


        a_finalfeeids(a_finalfeeids.COUNT + 1)     := a_feeids(1);
        a_amountstopay(a_amountstopay.COUNT + 1)   := t_paidamount;
    END setamountsforfeeids;


    --------------------------------------------------------
    -- ReadyToIssue()
    -- Called upon completion of the Deposit job this procedure will look at all related Payments for
    -- REN feeActivity types and if the job had been fully paid then the procedure will set the
    -- Ready to Issue Date to the current date plus the user constant "ReadyToIssueDate."
    --------------------------------------------------------
    PROCEDURE readytoissue(a_objectid udt_id, a_asofdate DATE)
    IS
        t_jobid   udt_id := api.pkg_columnquery.VALUE(a_objectid, 'Jobid');
    BEGIN
        --Set the Deposited date on the payment
        FOR x
            IN (SELECT pbp.paymentobjectid,
                       ROWNUM,
                       api.pkg_columnquery.numericvalue(pbp.paymentobjectid,
                                                        'PaymentId')
                           paymentid,
                       api.pkg_columnquery.datevalue(dpb.depositjobid,
                                                     'DepositDate')
                           depositdate
                  FROM query.r_depositpaymentbatch  dpb
                       JOIN query.r_paymentbatchpayment pbp
                           ON pbp.paymentbatchjobid = dpb.paymentbatchjobid
                 WHERE dpb.depositjobid = t_jobid
                UNION ALL
                SELECT tp.paymentobjectid,
                       ROWNUM,
                       api.pkg_columnquery.numericvalue(tp.paymentobjectid,
                                                        'PaymentId'),
                       api.pkg_columnquery.datevalue(t.depositjobid,
                                                     'DepositDate')
                           depositdate
                  FROM query.r_transmittaldeposit  t
                       JOIN query.r_transmittalpayment tp
                           ON tp.transmittaljobid = t.transmittaljobid
                 WHERE t.depositjobid = t_jobid)
        LOOP
            api.pkg_columnupdate.setvalue(x.paymentobjectid,
                                          'DepositedDate',
                                          x.depositdate);

            UPDATE processesdepositedpayments_t t
               SET t.maxdepositdateplus10   = x.depositdate
             WHERE t.paymentid = x.paymentid;
        END LOOP;

        --Process the Payments and set ready to issue date if applicable
        pkg_fees.processreceivepayment(t_jobid);
    END readytoissue;

    /*---------------------------------------------------------------------------
    * UniqueHQReceiptError() -- PUBLIC
    * This procedure run on Column Change of HQ Receipt(PaymentNumber) will raise
    * an error if this value has been used before. More info regarding the blocking
    * Job(s) will be placed in the debug log.
    *-------------------------------------------------------------------------*/
    PROCEDURE uniquehqreceipterror(a_objectid      udt_id,
                                   a_asofdate      DATE,
                                   a_paymentnumberfrom VARCHAR2,
                                   a_paymentnumberto VARCHAR2,
                                   a_paymentnumberfromverify VARCHAR2,
                                   a_paymentnumbertoverify VARCHAR2,
                                   a_fromorto      VARCHAR2)
    IS
        t_errorinfo              VARCHAR2(4000);
        t_range                  VARCHAR2(4000);
        t_paymentnumerrorvalue   VARCHAR2(10);
        t_isawfzerobatch         VARCHAR2(1)
            := api.pkg_columnquery.VALUE(a_objectid, 'IsAWFZeroBatch');
    BEGIN
        IF t_isawfzerobatch = 'N' THEN
            api.pkg_errors.clear();

            IF a_fromorto = 'From' THEN
                t_paymentnumerrorvalue   := a_paymentnumberfrom;
            ELSIF a_fromorto = 'To' THEN
                t_paymentnumerrorvalue   := a_paymentnumberto;
            ELSIF a_fromorto = 'From Verify' THEN
                t_paymentnumerrorvalue   := a_paymentnumberfromverify;
            ELSIF a_fromorto = 'To Verify' THEN
                t_paymentnumerrorvalue   := a_paymentnumbertoverify;
            ELSE
                t_paymentnumerrorvalue   := NULL;
            END IF;

            IF t_paymentnumerrorvalue IS NOT NULL THEN
                SELECT concatlist2(
                           udt_aggrstring(
                                  pb.paymentnumberfrom
                               || '-'
                               || pb.paymentnumberto,
                               ', ')),
                       concatlist2(
                           udt_aggrstring(
                                  'ErrorValue: '
                               || t_paymentnumerrorvalue
                               || ' ProcedureType: '
                               || a_fromorto
                               || ' BatchJobId: '
                               || pb.jobid
                               || ', BatchType: '
                               || pb.paymentbatchtype
                               || ', Status: '
                               || pb.statusdescription
                               || ', HQ Receipt From: '
                               || pb.paymentnumberfrom
                               || ', HQ Receipt To: '
                               || pb.paymentnumberto,
                               '; '))
                  INTO t_range, t_errorinfo
                  FROM query.j_paymentbatch pb
                 WHERE TO_NUMBER(t_paymentnumerrorvalue) BETWEEN TO_NUMBER(
                                                                     pb.paymentnumberfrom)
                                                             AND TO_NUMBER(
                                                                     pb.paymentnumberto)
                   AND pb.jobid != a_objectid;

                IF t_errorinfo IS NOT NULL THEN
                    pkg_debug.putline(
                        '---------Error Info, Payment Batch range already in use. ---------');
                    pkg_debug.putline(t_errorinfo);
                    pkg_debug.putline(
                        '---------Error Info, Payment Batch range already in use. ---------');
                    api.pkg_errors.raiseerror(
                        -20000,
                           'The HQ Receipt '
                        || a_fromorto
                        || ' number ('
                        || t_paymentnumerrorvalue
                        || ') is already in use within the Payment Batch range '
                        || t_range
                        || '.');
                END IF;
            END IF;
        END IF;
    END uniquehqreceipterror;

    /*---------------------------------------------------------------------------
      *procedure UpdatePaymentPayeeReferance()
      *This updates the payment payee referance
      *-------------------------------------------------------------------------*/
    PROCEDURE updatepaymentpayeereference(a_objectid      udt_id,
                                          a_asofdate      DATE,
                                          a_payeereference VARCHAR2)
    IS
        t_paymentid   udt_id
            := api.pkg_columnquery.VALUE(a_objectid, 'PaymentId');
        t_receiptid   udt_id
            := api.pkg_columnquery.VALUE(a_objectid, 'ReceiptNumber');
    BEGIN
        api.pkg_paymentupdate.modify(t_paymentid,
                                     a_payeereference,
                                     t_receiptid);
    END updatepaymentpayeereference;

    /******************************************************************************************************************
      * RelatePaymentTransactions() Is called By Modify Payment to Relate the payment transactions
      * for the payment related
      ********************************************************************************************************************/

    PROCEDURE relatepaymenttransactions(a_objectid NUMBER, a_asofdate DATE)
    IS
        t_paymenttransferobjid   NUMBER;
        t_endpointid             NUMBER;
        t_paymentid              NUMBER;
        t_relid                  NUMBER;
        t_ptobjids               udt_idlist;
        t_priorcount             NUMBER;
        t_paytransobjectdefid    udt_id
            := api.pkg_configquery.objectdefidforname(
                   'o_PaymentTransactions');
    BEGIN
        --PaymentId
        SELECT p.paymentid
          INTO t_paymentid
          FROM api.relationships  r
               JOIN query.o_payment p ON p.objectid = r.toobjectid
         WHERE r.fromobjectid = a_objectid
           AND r.endpointid =
               api.pkg_configquery.endpointidforname('p_ModifyPayment',
                                                     'Payment');

        --Check if Relationships to Payment Transaction already exists
        SELECT COUNT(r.relationshipid)
          INTO t_priorcount
          FROM api.relationships  r
               JOIN query.o_paymenttransactions pt
                   ON pt.objectid = r.toobjectid
         WHERE r.fromobjectid = a_objectid
           AND r.endpointid =
               api.pkg_configquery.endpointidforname('p_ModifyPayment',
                                                     'PaymentTransaction')
           AND pt.paymentid = t_paymentid;

        --only run rest of procedure if there are no prior Payment Transactions related.
        IF t_priorcount = 0 THEN
            --Get PaymentId and Payment PaymentTransferObjectId

            t_endpointid   :=
                api.pkg_configquery.endpointidforname('p_ModifyPayment',
                                                      'PaymentTransaction');

            --use PaymentID to get Payment Transaction objectIds
            SELECT DISTINCT reo.objectid
              BULK COLLECT INTO t_ptobjids
              FROM api.paymenttransactions  pt
                   JOIN api.registeredexternalobjects reo --TAyers: PIP Task 8.5
                       ON reo.linkvalue = TO_CHAR(pt.transactionid)
                      AND reo.objectdefid = t_paytransobjectdefid
             WHERE pt.paymentid = t_paymentid
               AND pt.transactionid NOT IN
                       (SELECT pt.transactionid     --APatterson: PIP Task 8.5
                          FROM api.paymenttransactions  pt
                               JOIN api.registeredexternalobjects reo --TAyers: PIP Task 8.5
                                   ON reo.linkvalue =
                                      TO_CHAR(pt.transactionid)
                                  AND reo.objectdefid = t_paytransobjectdefid
                               JOIN query.r_modifypaymentpaymenttrans rpt
                                   ON rpt.paymenttransactionobjectid =
                                      reo.objectid
                         WHERE pt.paymentid = t_paymentid
                           AND rpt.amounttopay > 0);

            --Relate Payment Transactions to Process
            FOR c IN 1 .. t_ptobjids.COUNT
            LOOP
                IF api.pkg_columnquery.VALUE(t_ptobjids(c), 'IsRefunded') =
                   'N' THEN
                    --MM894
                    t_relid   :=
                        api.pkg_relationshipupdate.new(t_endpointid,
                                                       a_objectid,
                                                       t_ptobjids(c));
                END IF;
            END LOOP;
        END IF;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            NULL;                  --api.pkg_errors.RaiseError(-20000,'test');
    END relatepaymenttransactions;

    /******************************************************************************************************************
    * DeletePaymentTransRel() Is called By Modify Payment to Delete the payment transactions
    * for the payment that is no longer related
    ********************************************************************************************************************/
    PROCEDURE deletepaymenttransrel(a_objectid NUMBER, a_asofdate DATE)
    IS
        t_paytransobjid        NUMBER;
        t_endpointid           NUMBER;
        t_relid                NUMBER;
        t_paymenttransaction   NUMBER;
        t_payrelcount          NUMBER;
    BEGIN
        --Get PaymentTransferProcessId
        /*  select max(r.FromObjectId) into t_PayTransObjId
        from api.relationships r
        where r.FromObjectId = a_ObjectId
        and r.EndPointId = api.pkg_configquery.EndPointIdForName('p_PaymentTransfer', 'Payment'); */

        --Delete rels from Payment Transfer to Payment Transaction
        FOR c
            IN (SELECT DISTINCT (r.relationshipid)
                  FROM api.relationships  r
                       JOIN query.o_paymenttransactions pt
                           ON pt.objectid = r.toobjectid
                 WHERE r.fromobjectid = a_objectid
                   AND r.endpointid =
                       api.pkg_configquery.endpointidforname(
                           'p_ModifyPayment',
                           'PaymentTransaction')
                   AND pt.paymentid <>
                       (SELECT p.paymentid
                          FROM api.relationships  r
                               JOIN query.o_payment p
                                   ON p.objectid = r.toobjectid
                         WHERE r.fromobjectid = a_objectid
                           AND r.endpointid =
                               api.pkg_configquery.endpointidforname(
                                   'p_ModifyPayment',
                                   'Payment')))
        LOOP
            api.pkg_relationshipupdate.remove(c.relationshipid);
        END LOOP;
    END deletepaymenttransrel;

    /******************************************************************************************************************
    *ModifyPayment() this is run on the modify outcome of the Modify Payment process
    *First it voids the old payment -Done
    *Second it Creates a new payment
    *Third is replaces the old payment with the new payment in the following jobs, transmittal, payment batch, deposit
    ********************************************************************************************************************/

    PROCEDURE modifypayment(a_objectid NUMBER, a_asofdate DATE)
    IS
        t_amountstopay                   udt_numberlist;
        t_amountstopayovr                udt_numberlist;
        t_additionalitemerelid           udt_id;
        t_additionalitemvrelid           udt_id;
        t_additionalobjid                udt_id;
        t_additionalobjdefid             udt_id;
        t_balance                        NUMBER := 0;
        t_balances                       udt_numberlist;
        t_batchentryobjid                udt_id;
        t_batchentryobjids               udt_idlist;
        t_batchpaymentmultiple           VARCHAR2(1);
        t_batchpaymenttype               VARCHAR2(100);
        t_feeids                         udt_idlist;
        t_feeidstopay                    udt_idlist;
        t_feeidstopayovr                 udt_idlist;
        t_feejobid                       udt_id;
        t_newpaymentamount               NUMBER;
        t_newpaymentid                   udt_id;
        t_newpaymentrel                  udt_id;
        t_newpaymentobjid                udt_id;
        t_newpaymentref                  VARCHAR2(4000);
        t_officerelid                    udt_id;
        t_paytransobjectid               udt_id;
        t_paymentmethodendid             udt_id;
        t_processid                      udt_id;
        t_transactionobjid               udt_id;
        t_transmitalorbatchid            udt_id;
        t_transmitalorbatchrelid         udt_id;
        t_voidpaymentreceiptnum          VARCHAR2(100);
        t_voidpaymentid                  udt_id;
        t_voidpaymentobjid               udt_id;
        t_voidpaymentmethodid            udt_id;
        t_voidpaymentofficeid            udt_id;
        t_voidpaymentbatchid             VARCHAR2(20);
        t_voidpaymentpayeename           VARCHAR2(4000);
        t_voidpaymentpayeeaddres         VARCHAR2(4000);
        t_voidpaymentisreceipted         VARCHAR2(1);
        t_raiseerrpayment                VARCHAR2(1);
        t_voidpaymenthqnum               VARCHAR2(8);
        t_voidpaymentdate                DATE;
        t_voidpaymentreceiptdate         DATE;
        t_maxpaymentstatusobjid          udt_id;
        t_receiptpaymentsprocid          udt_id;
        t_newreceiptpaymentrel           udt_id;


        t_ovrtofeeids                    udt_idlist;
        t_ovrpayamounts                  udt_numberlist;
        t_newpaymentstatus               NUMBER;
        t_relid                          NUMBER;
        t_paymentofficeendpointid        udt_id
            := api.pkg_configquery.endpointidforname('o_Payment', 'Office');
        t_paymenttransmittalendpointid   udt_id
            := api.pkg_configquery.endpointidforname('o_Payment',
                                                     'Transmittal');
        t_paymentpaybatchendpointid      udt_id
            := api.pkg_configquery.endpointidforname('o_Payment',
                                                     'PaymentBatch');
        t_modifypaymentpayendpointid     udt_id
            := api.pkg_configquery.endpointidforname('p_ModifyPayment',
                                                     'Payment');
        t_paytransobjectdefid            udt_id
            := api.pkg_configquery.objectdefidforname(
                   'o_PaymentTransactions');
    BEGIN
        --Check To Make sure a payment has been related if not raise an error
        BEGIN
              --Check the sum of the Amounts To Pay to see if it is equal to the new payment amount
              SELECT CASE
                         WHEN (SUM(r.amounttopay) !=
                               api.pkg_columnquery.numericvalue(
                                   r.modifypaymentprocessid,
                                   'NewPaymentAmount')
                            OR api.pkg_columnquery.numericvalue(
                                   r.modifypaymentprocessid,
                                   'NewPaymentAmount')
                                   IS NULL) THEN
                             'Y'
                         ELSE
                             'N'
                     END
                INTO t_raiseerrpayment
                FROM query.r_modifypaymentpaymenttrans r
               WHERE r.modifypaymentprocessid = a_objectid
            GROUP BY r.modifypaymentprocessid;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                api.pkg_errors.raiseerror(
                    '-20000',
                    'Fees must be related before saving with an outcome.');
        END;

        IF t_raiseerrpayment = 'Y' THEN
            api.pkg_errors.raiseerror(
                '-20000',
                'The New Payment Amount must be equal to the Total Amount To Pay.');
        ELSE
            NULL;
        END IF;


        --Get the related payment Id
        SELECT p.paymentid,
               pm.objectid,
               p.payeereference,
               ro.toobjectid  officeid,
               rtb.toobjectid transmittalorpaymentbatchid,
               p.receiptnumber,
               p.batchpaymentid,
               p.payeename,
               p.payeeaddress,
               p.isreceipted,
               p.objectid,
               p.hqreceiptlookup,
               p.paymentdate,
               p.receiptdatenvl,
               p.generatereceiptprocessid
          INTO t_voidpaymentid,
               t_voidpaymentmethodid,
               t_newpaymentref,
               t_voidpaymentofficeid,
               t_transmitalorbatchid,
               t_voidpaymentreceiptnum,
               t_voidpaymentbatchid,
               t_voidpaymentpayeename,
               t_voidpaymentpayeeaddres,
               t_voidpaymentisreceipted,
               t_voidpaymentobjid,
               t_voidpaymenthqnum,
               t_voidpaymentdate,
               t_voidpaymentreceiptdate,
               t_receiptpaymentsprocid
          FROM api.relationships  rmp
               JOIN query.o_payment p
                   ON rmp.toobjectid = p.objectid
                  AND rmp.endpointid = t_modifypaymentpayendpointid
                  AND rmp.fromobjectid = a_objectid
               JOIN query.r_paymentpaymentmethod r2
                   ON r2.paymentobjectid = p.objectid
               JOIN query.o_paymentmethod pm
                   ON pm.objectid = r2.paymentmethodobjectid
               LEFT OUTER JOIN api.relationships ro
                   ON ro.endpointid = t_paymentofficeendpointid
                  AND ro.fromobjectid = rmp.toobjectid
               LEFT OUTER JOIN api.relationships rtb
                   ON rtb.endpointid IN
                          (t_paymenttransmittalendpointid,
                           t_paymentpaybatchendpointid)
                  AND rtb.fromobjectid = p.objectid;

        -- Check current Fee balance for REN Fees
        -- RyanL: Changed the select clause to be a subselect for performance (PIP Task 8.5)
        SELECT f.feeid,
               (  f.amount
                + NVL((SELECT SUM(amount)
                         FROM api.feetransactions ft
                        WHERE ft.feeid = f.feeid),
                      0))
          BULK COLLECT INTO t_feeids, t_balances
          FROM query.r_modifypaymentpaymenttrans  r
               JOIN api.feetransactions ft
                   ON ft.transactionid =
                      api.pkg_columnquery.VALUE(r.paymenttransactionobjectid,
                                                'TransactionId')
               JOIN api.fees f ON f.feeid = ft.feeid
         WHERE r.modifypaymentprocessid = a_objectid
           AND api.pkg_columnquery.VALUE(f.jobid, 'ObjectDefName') =
               'j_LicenseType';


        --Get the Amounts to Pay for each fee related to a payment transaction
        SELECT r.amounttopay, aft.feeid
          BULK COLLECT INTO t_amountstopay, t_feeidstopay
          FROM query.r_modifypaymentpaymenttrans  r
               JOIN api.feetransactions aft
                   ON aft.transactionid =
                      api.pkg_columnquery.VALUE(r.paymenttransactionobjectid,
                                                'TransactionId')
         WHERE r.modifypaymentprocessid = a_objectid
           AND r.amounttopay > 0
           AND r.ovr = 'N';


        --Select which Payment Transaction modifications will be calculated as OVRs, and pass them to calculate OVR
        SELECT r.amounttopay, aft.feeid
          BULK COLLECT INTO t_amountstopayovr, t_feeidstopayovr
          FROM query.r_modifypaymentpaymenttrans  r
               JOIN api.feetransactions aft
                   ON aft.transactionid =
                      api.pkg_columnquery.VALUE(r.paymenttransactionobjectid,
                                                'TransactionId')
         WHERE r.modifypaymentprocessid = a_objectid
           AND r.amounttopay > 0
           AND r.ovr = 'Y';


        --Void the related payment
        api.pkg_paymentupdate.void(t_voidpaymentid, SYSDATE);

        --Now 'freeze' data voided
        api.pkg_columnupdate.setvalue(t_voidpaymentobjid,
                                      'DateVoided',
                                      SYSDATE - 1);
        api.pkg_columnupdate.setvalue(t_voidpaymentobjid,
                                      'DateVoided',
                                      TRUNC(SYSDATE));
        -- Set income code to 'V'
        api.pkg_columnupdate.setvalue(t_voidpaymentobjid,
                                      'CABINIncomeInd',
                                      'V');

        --Find the Max object id of the payment stati on the payment transactions of the voided payment,
        --used to create the new stati on the the new payment transactions
   -- 05/05/2023 PK          Changed Modify Payment to address MAX(pspt.paymentstatusobjectid) after objectif gap fixes  
        SELECT pspt.paymentstatusobjectid     --APatterson: PIP Task 8.5
          INTO t_maxpaymentstatusobjid
          FROM api.paymenttransactions  pt
               JOIN api.registeredexternalobjects reo   --TAyers: PIP Task 8.5
                   ON reo.linkvalue = TO_CHAR(pt.transactionid)
                  AND reo.objectdefid = t_paytransobjectdefid
               JOIN query.r_paymentstatuspaymenttrans pspt
                   ON pspt.paymenttransactionobjectid = reo.objectid
                   join query.o_Paymentstatus ps
                 on ps.ObjectId = pspt.PaymentStatusObjectId
         WHERE pt.paymentid =  t_voidpaymentid
          order by ps.StatusDate desc
           fetch first 1 row only ;
--              END of changes 05/05/2023 PK         


        -- Set income code to 'V' on payment transactions
        --and unearn the transaction if the transaction has already been earned
        FOR c IN (SELECT reo.objectid
                    FROM api.paymenttransactions  pt
                         JOIN api.registeredexternalobjects reo --TAyers: PIP Task 8.5
                             ON reo.linkvalue = TO_CHAR(pt.transactionid)
                            AND reo.objectdefid = t_paytransobjectdefid
                   WHERE pt.paymentid = t_voidpaymentid)
        LOOP
            api.pkg_columnupdate.setvalue(c.objectid, 'CABINAmtType', 'V');

            --if it has earned
            IF api.pkg_columnquery.VALUE(
                   api.pkg_columnquery.numericvalue(c.objectid,
                                                    'PaymentStatusObjectId'),
                   'Status') =
               'EARNED' THEN
                --unearn the transaction
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
                        c.objectid);
                api.pkg_columnupdate.setvalue(t_newpaymentstatus,
                                              'Status',
                                              'UNEARNED');
                api.pkg_columnupdate.setvalue(t_newpaymentstatus,
                                              'StatusDate',
                                              TRUNC(SYSDATE));
                api.pkg_columnupdate.setvalue(t_newpaymentstatus,
                                              'SystemGenerated',
                                              'Y');
            END IF;
        END LOOP;

        --Calculate Overpayment records (for separate, flagged PaymentTransactions) if The OVR checkbox is checked
        sitespecific.pkg_fees.calculateoverpayment(t_feeidstopayovr,
                                                   t_amountstopayovr,
                                                   t_ovrtofeeids,
                                                   t_ovrpayamounts);

        --Add OVR Fees to the payment arrays from the related fees that are OVRS
        FOR g IN 1 .. t_feeidstopayovr.COUNT
        LOOP
            t_amountstopay(t_amountstopay.COUNT + 1)   :=
                t_amountstopayovr(g);
            t_feeidstopay(t_feeidstopay.COUNT + 1)   := t_feeidstopayovr(g);
        END LOOP;

        t_newpaymentamount   :=
            api.pkg_columnquery.numericvalue(a_objectid, 'NewPaymentAmount');

        -- Create the New Payment
        t_newpaymentid   :=
            api.pkg_paymentupdate.new(t_voidpaymentdate,
                                      t_feeidstopay,
                                      t_amountstopay);

        -- Register the Payment
        t_newpaymentobjid   :=
            api.pkg_objectupdate.registerexternalobject('o_Payment',
                                                        t_newpaymentid);

        -- For each fee that was paid, check if the job is a LT. If so, create and complete the Receive Payments process
        /*for p in 1..t_FeeIdsToPay.count loop
          select f.JobId
            into t_FeeJobId
            from api.Fees f
           where f.FeeId = t_FeeIdsToPay(p);

          If api.pkg_ColumnQuery.Value(t_FeeJobId, 'ObjectDefName') = 'j_LicenseType' then

            t_ProcessId := api.pkg_ProcessUpdate.New(t_FeeJobId,
                                                     api.pkg_ConfigQuery.ObjectDefIdForName('p_ReceivePayment'),
                                                     null,
                                                     sysdate,
                                                     sysdate,
                                                     sysdate);
          End If;
        end loop;*/

        -- Update LT data when REN fees get un-paid.
        FOR c IN 1 .. t_feeids.COUNT
        LOOP
            SELECT f.jobid, f.amount + f.adjustedamount + f.paidamount
              INTO t_feejobid, t_balance
              FROM api.fees f
             WHERE f.feeid = t_feeids(c);

            IF t_balances(c) <= 0
           AND t_balance > 0 THEN
                pkg_fees.processnegativepayment(a_feeid     => t_feeids(c),
                                                a_jobid     => t_feejobid);
            END IF;
        END LOOP;

        --For the payment just created register the payment transactions and fee transactions, and set the payment transaction HQ-Receipt Number if it exists
        FOR c IN (SELECT pt.transactionid
                    FROM api.paymenttransactions pt
                   WHERE pt.paymentid = t_newpaymentid)
        LOOP
            t_paytransobjectid   :=
                api.pkg_objectupdate.registerexternalobject(
                    'o_PaymentTransactions',
                    c.transactionid);

            IF t_voidpaymenthqnum IS NOT NULL THEN
                api.pkg_columnupdate.setvalue(t_paytransobjectid,
                                              'HQReceipt',
                                              t_voidpaymenthqnum);
            ELSE
                NULL;
            END IF;

            t_transactionobjid   :=
                api.pkg_objectupdate.registerexternalobject(
                    'o_FeeTransactions',
                    c.transactionid);
            -- Set the amount type for the payment transactions to 'I'
            api.pkg_columnupdate.setvalue(t_paytransobjectid,
                                          'CABINAmtType',
                                          'I');
        END LOOP;

        --Relate the new payment to a payment method
        t_paymentmethodendid   :=
            api.pkg_configquery.endpointidforname('o_Payment',
                                                  'PaymentMethod');

        t_newpaymentrel   :=
            api.pkg_relationshipupdate.new(t_paymentmethodendid,
                                           t_newpaymentobjid,
                                           t_voidpaymentmethodid);

        --If Payment Transaction is overpayment, set flag to indicate it (used in Fees and Payments grid)
        sitespecific.pkg_fees.setpaymenttransactionflag(t_ovrtofeeids,
                                                        t_ovrpayamounts,
                                                        'IsOverpayment');



        --Loop Thru the Payment transactions of the new payment that are not OVR and copy the payment Status Objects from the old payment
        FOR d
            IN (SELECT reo.objectid newobjectid, reo2.objectid oldobjectid
                  FROM api.paymenttransactions  pt
                       JOIN api.registeredexternalobjects reo --TAyers: PIP Task 8.5
                           ON reo.linkvalue = TO_CHAR(pt.transactionid)
                          AND reo.objectdefid = t_paytransobjectdefid
                       JOIN api.feetransactions aft
                           ON aft.transactionid = pt.transactionid --APatterson: PIP Task 8.5
                       JOIN api.fees af ON af.feeid = aft.feeid
                       JOIN api.feetransactions aft2 ON aft2.feeid = af.feeid
                       JOIN api.registeredexternalobjects reo2 --TAyers: PIP Task 8.5
                           ON reo2.linkvalue = TO_CHAR(aft2.transactionid)
                          AND reo2.objectdefid = t_paytransobjectdefid
                 WHERE pt.paymentid = t_newpaymentid
                   AND api.pkg_columnquery.VALUE(reo.objectid,
                                                 'IsOverpayment') NOT IN
                           'Y'
                   AND aft2.transactionid IN
                           (SELECT apt.transactionid
                              FROM api.payments  p
                                   JOIN api.paymenttransactions apt
                                       ON apt.paymentid = p.paymentid
                             WHERE p.paymentid = t_voidpaymentid))
        LOOP
            --Loop Thru and create the payment stati objects on each new payment transaction that was created
            FOR e
                IN (SELECT pspt.paymentstatusobjectid
                      FROM query.r_paymentstatuspaymenttrans pspt
                     WHERE pspt.paymenttransactionobjectid = d.oldobjectid
                       AND pspt.paymentstatusobjectid <=
                           t_maxpaymentstatusobjid)
            LOOP
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
                        d.newobjectid);
                api.pkg_columnupdate.setvalue(
                    t_newpaymentstatus,
                    'Status',
                    api.pkg_columnquery.VALUE(e.paymentstatusobjectid,
                                              'Status'));
                api.pkg_columnupdate.setvalue(
                    t_newpaymentstatus,
                    'StatusDate',
                    api.pkg_columnquery.VALUE(e.paymentstatusobjectid,
                                              'StatusDate'));
                api.pkg_columnupdate.setvalue(
                    t_newpaymentstatus,
                    'SystemGenerated',
                    api.pkg_columnquery.VALUE(e.paymentstatusobjectid,
                                              'SystemGenerated'));
            END LOOP;
        END LOOP;


        --Set the Payment Referance, and Reciept of the new Payment
        api.pkg_paymentupdate.modify(t_newpaymentid,
                                     t_newpaymentref,
                                     t_voidpaymentreceiptnum);

        --Relate the New payment to the old receipt payments process or old void payment process

        IF t_receiptpaymentsprocid IS NOT NULL THEN
            t_newreceiptpaymentrel   :=
                api.pkg_relationshipupdate.new(
                    api.pkg_configquery.endpointidforname('o_Payment',
                                                          'ReceiptPayments'),
                    t_newpaymentobjid,
                    t_receiptpaymentsprocid);
        END IF;



        --Create the Relationship of the new payment to Office of the old payment, if the old payment had an office
        IF t_voidpaymentofficeid IS NOT NULL THEN
            t_officerelid   :=
                api.pkg_relationshipupdate.new(
                    api.pkg_configquery.endpointidforname('o_Office',
                                                          'Payment'),
                    t_voidpaymentofficeid,
                    t_newpaymentobjid);
        ELSE
            NULL;
        END IF;

        --Copy Payment Details to New Payment
        api.pkg_columnupdate.setvalue(t_newpaymentobjid,
                                      'BatchPaymentId',
                                      t_voidpaymentbatchid);

        api.pkg_columnupdate.setvalue(t_newpaymentobjid,
                                      'PayeeAddressStored',
                                      t_voidpaymentpayeeaddres);

        api.pkg_columnupdate.setvalue(t_newpaymentobjid,
                                      'PayeeNameStored',
                                      t_voidpaymentpayeename);

        api.pkg_columnupdate.setvalue(t_newpaymentobjid,
                                      'IsReceiptedStored',
                                      t_voidpaymentisreceipted);

        api.pkg_columnupdate.setvalue(t_newpaymentobjid,
                                      'PaymentDateStored',
                                      t_voidpaymentdate);

        api.pkg_columnupdate.setvalue(t_newpaymentobjid,
                                      'ReceiptDateStored',
                                      t_voidpaymentreceiptdate);



        -- If there is a transmittal or payment batch job related to the old payment, relate it to the new payment

        IF t_transmitalorbatchid IS NOT NULL THEN
            IF api.pkg_columnquery.VALUE(t_transmitalorbatchid,
                                         'ObjectDefName') =
               'j_Transmittal' THEN
                t_transmitalorbatchrelid   :=
                    api.pkg_relationshipupdate.new(
                        (api.pkg_configquery.endpointidforname('o_Payment',
                                                               'Transmittal')),
                        t_newpaymentobjid,
                        t_transmitalorbatchid);
            ELSIF api.pkg_columnquery.VALUE(t_transmitalorbatchid,
                                            'ObjectDefName') =
                  'j_PaymentBatch' THEN
                t_transmitalorbatchrelid   :=
                    api.pkg_relationshipupdate.new(
                        (api.pkg_configquery.endpointidforname(
                             'o_Payment',
                             'PaymentBatch')),
                        t_newpaymentobjid,
                        t_transmitalorbatchid);


                SELECT MAX(
                           api.pkg_columnquery.VALUE(
                               rmpt.paymenttransactionobjectid,
                               'HQReceipt'))
                  INTO t_voidpaymenthqnum
                  FROM query.r_modifypaymentpaymenttrans rmpt
                 WHERE rmpt.modifypaymentprocessid = a_objectid;

                SELECT qpb.multiple, qpb.paymentbatchtype
                  INTO t_batchpaymentmultiple, t_batchpaymenttype
                  FROM query.j_paymentbatch qpb
                 WHERE qpb.objectid = t_transmitalorbatchid;

                --update batch entry object
                IF t_batchpaymentmultiple = 'N'
               AND t_batchpaymenttype != 'P-12 RENEWALS' THEN
                    SELECT b.objectid
                      INTO t_batchentryobjid
                      FROM query.r_modifypaymentpayment  rmpp
                           JOIN query.o_payment p
                               ON p.objectid = rmpp.paymentobjectid
                           JOIN query.r_paymentbatchpayment rpbp
                               ON rpbp.paymentobjectid = p.objectid
                           JOIN query.r_pbbatchpaymententry rpbe
                               ON rpbe.paymentbatchjobid =
                                  rpbp.paymentbatchjobid
                           JOIN query.o_batchpaymententry b
                               ON b.objectid = rpbe.batchobjectid
                     WHERE (rmpp.modifypaymentprocessid = a_objectid
                        AND b.paymentnumber = t_voidpaymenthqnum);

                    api.pkg_columnupdate.setvalue(t_batchentryobjid,
                                                  'CheckAmount',
                                                  t_newpaymentamount);
                ELSIF t_batchpaymentmultiple = 'Y'
                   OR t_batchpaymenttype = 'P-12 RENEWALS' THEN
                    FOR x
                        IN (  SELECT oai.objectid,
                                     SUM(mpt.amounttopay) amounttopay,
                                     b.objectid         beobjectid
                                FROM query.r_modifypaymentpaymenttrans mpt
                                     JOIN query.o_paymenttransactions qpt
                                         ON qpt.objectid =
                                            mpt.paymenttransactionobjectid
                                     JOIN query.o_payment p
                                         ON p.objectid =
                                            api.pkg_simplesearch.objectbyindex(
                                                'o_Payment',
                                                'PaymentId',
                                                qpt.paymentid)
                                     JOIN query.r_paymentbatchpayment rpbp
                                         ON rpbp.paymentobjectid = p.objectid
                                     JOIN query.r_pbbatchpaymententry rpbe
                                         ON rpbe.paymentbatchjobid =
                                            rpbp.paymentbatchjobid
                                     JOIN query.o_batchpaymententry b
                                         ON b.objectid = rpbe.batchobjectid
                                     JOIN
                                     query.r_batchpaymentradditionalitem rai
                                         ON rai.batchentryobjectid = b.objectid
                                     JOIN query.o_additionalitem oai
                                         ON oai.objectid =
                                            rai.additionalitemobjectid
                               WHERE mpt.modifypaymentprocessid = a_objectid
                                 AND ((qpt.hqreceipt = b.paymentnumber
                                   AND b.groupid = oai.groupid
                                   AND oai.licensenum = qpt.licensenumber
                                   AND oai.licensetypecode =
                                       qpt.licensetypecode
                                   AND mpt.amounttopay != qpt.paymentamount)
                                   OR (qpt.hqreceipt = b.paymentnumber
                                   AND oai.licensenum = qpt.licensenumber
                                   AND oai.licensetypecode =
                                       qpt.licensetypecode
                                   AND mpt.amounttopay != qpt.paymentamount))
                            GROUP BY oai.objectid, b.objectid
                            ORDER BY b.objectid)
                    LOOP
                        api.pkg_columnupdate.setvalue(x.objectid,
                                                      'PaidAmount',
                                                      x.amounttopay);

                        IF t_batchentryobjid != x.beobjectid
                        OR t_batchentryobjid IS NULL THEN
                            t_batchentryobjids(t_batchentryobjids.COUNT + 1)   :=
                                x.beobjectid;
                            t_batchentryobjid   := x.beobjectid;
                        END IF;
                    END LOOP;

                    -- loop thru the batch entry objects and set the paid amoutn correctly
                    FOR z IN 1 .. t_batchentryobjids.COUNT
                    LOOP
                        api.pkg_columnupdate.setvalue(
                            t_batchentryobjids(z),
                            'CheckAmount',
                            api.pkg_columnquery.VALUE(t_batchentryobjids(z),
                                                      'TotalPaidAmount'));
                    END LOOP;
                ELSE
                    NULL;
                END IF;
            END IF;
        ELSE
            NULL;
        END IF;
    END modifypayment;

    /*---------------------------------------------------------------------------
   * RemovePaymentFromTransmittal() -- PUBLIC
   * This procedure will run on a post verify of a Transmittal job when a user
   * clicks on the delete selected payments link.  It will remove the relationship
   * from the job to the payment for all selected payments.
   *-------------------------------------------------------------------------*/
    PROCEDURE removepaymentfromtransmittal(a_objectid      NUMBER,
                                           a_asofdate      DATE)
    IS
        t_count   NUMBER;
    BEGIN
        IF (api.pkg_columnquery.VALUE(a_objectid, 'ProcessDeletePayments') =
            'Y') THEN
            SELECT COUNT(*)
              INTO t_count
              FROM query.r_transmittalpayment r
             WHERE r.deletepayment = 'Y'
               AND r.transmittaljobid = a_objectid;

            IF t_count = 0 THEN
                --Reset flag to remove all payments marked for deletion.
                api.pkg_columnupdate.setvalue(a_objectid,
                                              'ProcessDeletePayments',
                                              'N');
                api.pkg_errors.raiseerror(
                    -20000,
                    'No Payments Selected For Deletion.');
            END IF;

            --Delele all relationships that are marked for deletion
            FOR c IN (SELECT r.relationshipid
                        FROM query.r_transmittalpayment r
                       WHERE r.deletepayment = 'Y'
                         AND r.transmittaljobid = a_objectid)
            LOOP
                api.pkg_relationshipupdate.remove(c.relationshipid);
            END LOOP;

            --Reset flag to remove all payments marked for deletion.
            api.pkg_columnupdate.setvalue(a_objectid,
                                          'ProcessDeletePayments',
                                          'N');
        END IF;
    END removepaymentfromtransmittal;

    /*---------------------------------------------------------------------------
     * CreateTransmitPaymentOfficeRel() -- Mike Lott
     * Added to create relationship that flags a payment for transmittal. Called
     * from r_PaymentOffice constructor.
     *-------------------------------------------------------------------------*/
    PROCEDURE createtransmitpaymentofficerel(a_objectid      udt_id,
                                             a_asofdate      DATE)
    IS
        t_paymentobjectid           udt_id;
        t_officeobjectid            udt_id;
        t_officeendpointid          udt_id;
        t_newrelationshipobjectid   udt_id;
    BEGIN
        -- Get Payment and Office ObjectIds
        SELECT paymentobjectid, officeobjectid
          INTO t_paymentobjectid, t_officeobjectid
          FROM query.r_paymentoffice
         WHERE relationshipid = a_objectid;

        -- Get Office endpoint Id
        t_officeendpointid   :=
            api.pkg_configquery.endpointidforname('o_Payment',
                                                  'TransmittalOffice');

        -- Create a new TransmitPaymentOffice (Payment : Office) relationship
        t_newrelationshipobjectid   :=
            api.pkg_relationshipupdate.new(t_officeendpointid,
                                           t_paymentobjectid,
                                           t_officeobjectid,
                                           a_asofdate);
    END createtransmitpaymentofficerel;

    /*---------------------------------------------------------------------------
     * RemoveTransmitPaymentOfficeRel() -- Mike Lott
     * Will remove the r_TransmitPaymentOffice relationship. Should be called after
     * transmittal job has been completed.
     *-------------------------------------------------------------------------*/
    PROCEDURE removetransmitpaymentofficerel(a_objectid      udt_id,
                                             a_asofdate      DATE,
                                             a_jobid         udt_id)
    IS
        t_relationshipid   udt_id;                        -- to be deteremined
    BEGIN
        -- Find the r_TransmitPaymentOffice RelationshipIds for the Transmittal job
        -- through the Payment ObjectId and Remove the relationships.
        FOR rels
            IN (SELECT tpo.relationshipid
                  FROM query.r_transmittalpayment  tp
                       JOIN query.r_transmitpaymentoffice tpo
                           ON tp.paymentobjectid = tpo.transmittalpaymentid
                 WHERE tp.transmittaljobid = a_jobid)
        LOOP
            api.pkg_relationshipupdate.remove(rels.relationshipid);
        END LOOP;
    END removetransmitpaymentofficerel;

    /*---------------------------------------------------------------------------
     * verifybatchpayments() -- 05/11/2021 TJL   WO18874
     * Will verify the payment batch does not have any duplicate payments in it and 
     * that the license type was not paid in another payment batch (duplicate payment).
     *-------------------------------------------------------------------------*/
PROCEDURE verifybatchpayments(a_objectid udt_id, a_asofdate DATE)
IS
    t_paymentbatchobjectid   api.pkg_definition.udt_id;
    t_paymentbatchtype       VARCHAR2(100);
    t_total                  NUMBER;
    t_error                  BOOLEAN := FALSE;
    t_errormsg               VARCHAR2(4000);
BEGIN
    -- Get payment batch object from batch entry object id
    SELECT jobid, api.pkg_columnquery.VALUE(jobid, 'PaymentBatchType')
      INTO t_paymentbatchobjectid, t_paymentbatchtype
      FROM api.processes p
     WHERE p.processid = a_objectid;

    -- insert into temp
    INSERT INTO sitespecific.paymentbatch_t
          SELECT lt.toobjectid
                     jobobjectid,
                 api.pkg_columnquery.VALUE(lt.toobjectid, 'LicenseNumber')
                     licensenumber,
                 api.pkg_columnquery.VALUE(NVL(bpe.toobjectid, pb.toobjectid), 'LicenseTypeCode')
                     licensetypecode,
                 CASE
                     WHEN bpe.toobjectid IS NULL THEN api.pkg_columnquery.VALUE(pb.toobjectid, 'CheckAmount')
                     ELSE api.pkg_columnquery.VALUE(bpe.toobjectid, 'PaidAmount')
                 END
                     paidamount
            FROM api.relationships pb
                 LEFT OUTER JOIN api.relationships bpe
                 ON pb.toobjectid = bpe.fromobjectid
                AND bpe.endpointid = api.pkg_configquery.endpointidforname('o_BatchPaymentEntry', 'AdditionalItem')
                 JOIN api.relationships lt
                 ON (lt.endpointid IN
                         (api.pkg_configquery.endpointidforname('o_BatchPaymentEntry', 'LicenseType'),
                          api.pkg_configquery.endpointidforname('o_AdditionalItem', 'LicenseType'))
                 AND lt.fromobjectid = NVL(bpe.toobjectid, pb.toobjectid))
           WHERE (pb.fromobjectid = t_paymentbatchobjectid
              AND pb.endpointid = api.pkg_configquery.endpointidforname('j_paymentbatch', 'BatchPaymentEntry'))
        ORDER BY 2, 3;

    CASE t_paymentbatchtype
        WHEN 'INDIVIDUAL RENEWAL PAYMENTS (IR)' THEN
            -- check for duplicate payments in same batch
            FOR paymentbatch IN (WITH
                                     dup
                                     AS
                                         (  SELECT licensetypejobid, licensetypecode
                                              FROM sitespecific.paymentbatch_t p
                                          GROUP BY licensetypejobid, licensetypecode
                                            HAVING COUNT(licensetypejobid) > 1
                                          ORDER BY 1)
                                   SELECT DISTINCT p.*
                                     FROM dup d
                                          JOIN sitespecific.paymentbatch_t p
                                          ON (d.licensetypejobid = p.licensetypejobid
                                          AND d.licensetypecode = p.licensetypecode)
                                 ORDER BY 1)
            LOOP
                WITH
                    fee
                    AS
                        (  SELECT SUBSTR(f.description, 1, 2)
                                      licensetypecode,
                                  SUBSTR(REGEXP_SUBSTR(f.description,
                                                       '[^ ]+',
                                                       1,
                                                       3),
                                         1,
                                         3)
                                      feeactivity,
                                  -f.paidamount
                                      paidamount,
                                  (f.amount + f.adjustedamount)
                                      amount,
                                  LEAD(f.transactiondate, 1)
                                      OVER(PARTITION BY f.jobid, SUBSTR(f.description, 1, 2)  --, f.licensetype
                                                                                            ORDER BY f.transactiondate)
                                      AS transactionenddate,
                                  f.transactiondate
                                      currdate
                             FROM api.fees f
                            WHERE f.jobid = paymentbatch.licensetypejobid
                         ORDER BY f.transactiondate)
                SELECT SUM(amount)
                  INTO t_total
                  FROM fee f
                 WHERE f.transactionenddate IS NULL
                   AND f.licensetypecode = paymentbatch.licensetypecode
                   AND f.feeactivity = 'REN';

                IF (paymentbatch.paidamount >= t_total) THEN
                    t_errormsg   :=
                           t_errormsg
                        || 'Double Payment - License Number: '
                        || api.pkg_columnquery.VALUE(paymentbatch.licensetypejobid, 'LicenseNumber')
                        || '  License Type Code: '
                        || paymentbatch.licensetypecode
                        || CHR(13)
                        || CHR(10);
                    t_error   := TRUE;
                END IF;
            END LOOP;


            -- check to see if payments have already been made
            FOR paymentbatch IN (SELECT *
                                   FROM sitespecific.paymentbatch_t p)
            LOOP
                FOR licfees
                    IN (WITH
                            fee
                            AS
                                (  SELECT SUBSTR(f.description, 1, 2)
                                              licensetypecode,
                                          SUBSTR(REGEXP_SUBSTR(f.description,
                                                               '[^ ]+',
                                                               1,
                                                               3),
                                                 1,
                                                 3)
                                              feeactivity,
                                          -f.paidamount
                                              paidamount,
                                          (f.amount + f.adjustedamount)
                                              amount,
                                          LEAD(
                                              f.transactiondate,
                                              1)
                                          OVER(PARTITION BY f.jobid, SUBSTR(f.description, 1, 2)  --, f.licensetype
                                               ORDER BY f.transactiondate)
                                              AS transactionenddate,
                                          f.transactiondate
                                              currdate
                                     FROM api.fees f
                                    WHERE f.jobid = paymentbatch.licensetypejobid
                                 ORDER BY f.transactiondate)
                        SELECT f.licensetypecode,
                               feeactivity,
                               paidamount,
                               amount
                          FROM fee f
                         WHERE f.transactionenddate IS NULL
                           AND f.licensetypecode = paymentbatch.licensetypecode
                           AND f.feeactivity = 'REN')
                LOOP
                    -- allow second payment if first payment is under payment
                    IF (licfees.paidamount - licfees.amount >= 0) THEN
                        t_errormsg   :=
                               t_errormsg
                            || 'Already Paid - License Number: '
                            || api.pkg_columnquery.VALUE(paymentbatch.licensetypejobid, 'LicenseNumber')
                            || '  License Type Code: '
                            || licfees.licensetypecode
                            || CHR(13)
                            || CHR(10);
                        t_error   := TRUE;
                    END IF;
                END LOOP;
            END LOOP;
        ELSE
            NULL;
    END CASE;

    IF (t_error) THEN
        api.pkg_errors.raiseerror(-20000, t_errormsg);
    END IF;
END verifybatchpayments;

END pkg_accounting;
/


GRANT EXECUTE ON SITESPECIFIC.PKG_ACCOUNTING TO POSSEEXTENSIONS;
