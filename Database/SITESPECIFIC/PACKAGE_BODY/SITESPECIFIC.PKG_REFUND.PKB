CREATE OR REPLACE PACKAGE BODY SITESPECIFIC."PKG_REFUND"
AS
    -- **************************************************************************
    -- File:        PKG_REFUND.PKB
    -- Author:      COMPUTRONIX
    --
    -- $Rev: 396 $
    -- $Date: 2020-01-10 10:26:34 -0800 (Fri, 10 Jan 2020) $
    -- Last Changed By:  $Author: TLord $
    --
    -- Description:
    --
    --
    -- History:
    -----------------------------------------------------------------------------
    --    Date                  Comment
    -- 08/01/2018 SS  WO 14438  Fix to unearn the payment after the refund batch run.
    -- 07/29/2019 TJL WO 17565  Added logic to createsrvlineitems to change how
    --                            service charges are calculated.
    -- 12/06/2019 TJL WO 19946  Corrected bug in how service charges are calculated.
    -- 02/27/2020 TJL WO 20884  Refund Part C - Fixed bug that prevented SRV being
    --                            created when called from Payment Transfer Screen
    -- 03/04/2020 TJL WO 20884  Added procedure "CreateWithdrawalTransaction" and
    --                            "schedulecreatesvrtransaction"
    -- 04/14/2020 TJL WO 21317  Fixed bug with incorrect SRV amount being generated
    --                            for applications prior to july 1, 2019
    -- 06/10/2020 TJL WO 21772  Fixed bug in createwithdrawaltransaction in filtering
    --                            out jobs that have refundable fees associated with
    --                            them.
    -- **************************************************************************
    PROCEDURE createsrvlineitems(a_objectid udt_id, a_asofdate DATE)
    IS
        -- 07/29/2019 TJL WO 17565
        TYPE license_rec IS RECORD
        (
            licensenumber VARCHAR2(20),
            createddate DATE,
            maxnonrefundable NUMBER
        );

        TYPE license_tbl IS TABLE OF license_rec;

        t_lic               license_tbl;
        -- end

        t_srvpercentage     NUMBER(3, 2) := .25;
        t_transactioncode   VARCHAR2(8) := 'SRV';
        t_objectdefid       udt_id := api.pkg_configquery.objectdefidforname('o_RefundCheckItem');
        t_calculatesrv      VARCHAR2(1);
        t_srvamount         NUMBER(11, 2);
        t_maxsrvamount      NUMBER(11, 2);
        t_rciobjectid       udt_id;
        t_relid             udt_id;
        t_objectdefname     VARCHAR2(30) := api.pkg_columnquery.VALUE(a_objectid, 'ObjectDefName');
        t_endpointid        udt_id := api.pkg_configquery.endpointidforname(t_objectdefname, 'RefundCheckItem');

        TYPE cur_typ IS REF CURSOR;

        c1                  cur_typ;
        query_str           VARCHAR(4000);

        t_amount            NUMBER;
        t_licensenumber     NUMBER;
        t_licensetypecode   VARCHAR2(2);
        t_primaryamount     NUMBER;  -- 12/06/2019 TJL WO 19946
        t_feeobjid          udt_id;  -- 12/06/2019 TJL WO 19946
    BEGIN
        t_calculatesrv   := api.pkg_columnquery.VALUE(a_objectid, 'CalculateSRV');

        IF t_calculatesrv = 'Y' THEN
            WITH
                feeobject
                AS
                    (SELECT pt.licensenumber, api.pkg_columnquery.VALUE(pt.feeobjid, 'jobid') jobid
                       FROM query.r_refundcheckpaytrans r
                            JOIN query.o_paymenttransactions pt
                            ON pt.objectid = r.paymenttransactionobjectid
                      WHERE r.refundcheckobjectid = a_objectid
                        -- 02/27/2020 TJL WP 20884 -- add code for Payment Transfer
                        AND t_objectdefname = 'o_RefundCheck'
                     UNION
                     SELECT pt.licensenumber, api.pkg_columnquery.VALUE(pt.feeobjid, 'jobid') jobid
                       FROM query.r_paymenttransfertrans r
                            JOIN query.o_paymenttransactions pt
                            ON pt.objectid = r.paymenttransactionobjectid
                      WHERE r.paymenttransferprocessid = a_objectid
                        AND t_objectdefname = 'p_PaymentTransfer')
              -- end of add code
              SELECT f.licensenumber,
                     api.pkg_columnquery.datevalue(f.jobid, 'createddate')
                         createddate,
                     CASE
                         WHEN (SELECT p.processstatus
                                 FROM api.processes p
                                WHERE p.jobid = f.jobid
                                  /* api.pkg_objectdefquery.idforname('p_enterapplication') */
                                  AND p.processtypeid = 338940
                                  AND api.pkg_columnquery.VALUE(f.jobid, 'ObjectDefName') = 'j_Application')
                                  IS NULL THEN
                             -api.pkg_constantquery.VALUE('MINNONREFUNDABLEAMT')
                         ELSE
                             CASE   -- 04/14/2020 TJL WO 21317  
                                 WHEN api.pkg_columnquery.datevalue(f.jobid, 'createddate') < TO_DATE('01-JUL-19') THEN
                                     -100
                                 ELSE
                                     -api.pkg_constantquery.VALUE('MAXNONREFUNDABLEAMT')
                             END
                     END
                         maxnonrefunablefee
                BULK COLLECT INTO t_lic
                FROM feeobject f
            GROUP BY f.jobid, f.licensenumber;

            FOR inx IN 1 .. t_lic.COUNT
            LOOP
                IF t_objectdefname = 'p_PaymentTransfer' THEN
                    --in the line below changed select sum(r.Amount) * -1 RefundAmount to select sum(r.Amount) RefundAmount
                    -- 12/06/2019 TJL WO 19946 added returning feeobjid
                    query_str   :=
                           'select sum(r.Amount) RefundAmount,
											 pt.LicenseNumber,
											 pt.LicenseTypeCode,
											pt.feeobjid
			            from query.r_PaymentTransferTrans r 
									join query.o_PaymentTransactions pt on pt.objectid = r.PaymentTransactionObjectId
                 where r.PaymentTransferProcessId = '
                        || a_objectid
                        || '
								   and r.ServiceCharge = ''Y''
									 and pt.FeeScheduleTransactionFeeActiv not in (''REN'',''REN50'',''REN100'')
                   and pt.IsOverpayment != ''Y''
                   and pt.LicenseNumber = '
                        || t_lic(inx).licensenumber
                        || '
								group by pt.LicenseNumber,
       									 pt.LicenseTypeCode,
       									 pt.feeobjid';
                ELSIF t_objectdefname = 'o_RefundCheck' THEN
                    query_str   :=
                           'select sum(r.RefundAmount) * -1 RefundAmount, 
											 pt.LicenseNumber,
											 pt.LicenseTypeCode,
											pt.feeobjid
			            from query.r_RefundCheckPayTrans r
									join query.o_PaymentTransactions pt on pt.objectid = r.PaymentTransactionObjectId
                 where r.RefundCheckObjectId = '
                        || a_objectid
                        || '
								   and r.ServiceCharge = ''Y''
									 and pt.FeeScheduleTransactionFeeActiv not in (''REN'',''REN50'',''REN100'')
                   and pt.IsOverpayment != ''Y''
                   AND pt.licensenumber = '
                        || t_lic(inx).licensenumber
                        || '
                   						group by pt.LicenseNumber,
       									 pt.LicenseTypeCode,
       									 pt.feeobjid';
                END IF;

                OPEN c1 FOR query_str;

                LOOP
                    FETCH c1 INTO t_amount, t_licensenumber, t_licensetypecode, t_feeobjid;

                    EXIT WHEN c1%NOTFOUND;

                    -- 12/06/2019 TJL WO 19946
                    t_primaryamount   :=
                        GREATEST(
                            t_lic(inx).maxnonrefundable,
                            -api.pkg_columnquery.numericvalue(
                                 api.pkg_columnquery.numericvalue(t_feeobjid, 'LicenseFeeSchedId'),
                                 'primaryamount'));

                    IF t_lic(inx).createddate < TO_DATE('01-JUL-19') THEN
                        --SRV Amount is calculated as 25% of total amount, limited to $100
                        t_srvamount   := GREATEST(ROUND((t_amount * t_srvpercentage)), -100);
                    ELSE
                        t_srvamount   := GREATEST(t_amount, t_primaryamount);
                    END IF;


                    --adding LicenseTypeCode to the TransactionCode
                    IF t_objectdefname = 'p_PaymentTransfer' THEN
                        --reset transationcode to srv when looping through a second time
                        t_transactioncode   := 'SRV';

                        --and if the licensetypecode has a value then add the code and the dash
                        IF t_licensetypecode IS NOT NULL THEN
                            t_transactioncode   :=
                                   t_licensetypecode
                                || ' - '
                                || t_transactioncode;
                        END IF;
                    END IF;

                    --create one RefundCheckItem per LicenseType/LicenseNumber combo (or update an existing object with that combo).
                    BEGIN
                        IF t_objectdefname = 'o_RefundCheck' THEN
                            SELECT o.objectid
                              INTO t_rciobjectid
                              FROM query.r_refundcheckrefundcheckitem r
                                   JOIN query.o_refundcheckitem o
                                   ON o.objectid = r.refundcheckitemobjectid
                             WHERE r.refundcheckobjectid = a_objectid
                               AND o.licensenumber = t_licensenumber
                               AND (o.licensetypecode = t_licensetypecode
                                 OR (o.licensetypecode IS NULL
                                 AND t_licensetypecode IS NULL));
                        ELSIF t_objectdefname = 'p_PaymentTransfer' THEN
                            SELECT o.objectid
                              INTO t_rciobjectid
                              FROM query.r_paymenttransferrefundcheckit r
                                   JOIN query.o_refundcheckitem o
                                   ON o.objectid = r.refundcheckitemobjectid
                             WHERE r.paymenttransferobjectid = a_objectid
                               AND o.licensenumber = t_licensenumber
                               AND (o.licensetypecode = t_licensetypecode
                                 OR (o.licensetypecode IS NULL
                                 AND t_licensetypecode IS NULL));
                        END IF;

                        t_srvamount   :=
                            GREATEST(
                                NVL(t_srvamount, 0) + api.pkg_columnquery.numericvalue(t_rciobjectid, 'SRVAmount'),
                                t_lic(inx).maxnonrefundable);
                        api.pkg_columnupdate.setvalue(t_rciobjectid, 'SRVAmount', t_srvamount);
                    EXCEPTION
                        WHEN NO_DATA_FOUND THEN
                            t_rciobjectid   := api.pkg_objectupdate.new(t_objectdefid);
                            api.pkg_columnupdate.setvalue(t_rciobjectid, 'LicenseNumber', t_licensenumber);
                            api.pkg_columnupdate.setvalue(t_rciobjectid, 'LicenseTypeCode', t_licensetypecode);
                            api.pkg_columnupdate.setvalue(t_rciobjectid, 'SRVAmount', t_srvamount);
                            api.pkg_columnupdate.setvalue(t_rciobjectid, 'TransactionCode', t_transactioncode);
                            t_relid         :=
                                api.pkg_relationshipupdate.new(t_endpointid, a_objectid, t_rciobjectid);
                    END;
                END LOOP;
            END LOOP;

            api.pkg_columnupdate.setvalue(a_objectid, 'CalculateSRV', 'N');
        END IF;
    END createsrvlineitems;

    PROCEDURE createrefundtransactions(a_objectid NUMBER, a_asofdate DATE, a_jobid NUMBER)
    IS
        --type VAR is varray(100) of number(1);
        t_var                   pkg_refund.var := pkg_refund.var();  --VAR := VAR();
        -- t_index       integer;

        t_oldpaymentid          udt_id;
        t_ispayrefund           VARCHAR(1);
        t_newpaymentid          udt_id;
        t_feeids                api.pkg_definition.udt_idlist;
        t_refundamounts         api.pkg_definition.udt_numberlist;
        t_srvfeeids             api.pkg_definition.udt_idlist;
        t_srvamounts            api.pkg_definition.udt_numberlist;
        t_ovrfeeids             api.pkg_definition.udt_idlist;
        t_ovramountstopay       api.pkg_definition.udt_numberlist;
        t_batchamount           NUMBER;
        t_srvamount             NUMBER;
        t_newpaymentobjid       udt_id;
        t_newpaystatus          udt_id;
        t_newrelid              udt_id;
        t_oldpaytrans           udt_id;
        t_paytransobjectid      udt_id;
        t_payeeaddress          VARCHAR2(4000);
        t_payeename             VARCHAR2(4000);
        t_earnedamount          NUMBER;
        t_paymentobjectdefid    udt_id := api.pkg_configquery.objectdefidforname('o_Payment');
        t_paytransobjectdefid   udt_id := api.pkg_configquery.objectdefidforname('o_PaymentTransactions');
    BEGIN
        FOR c IN (SELECT rc.objectid refundcheckobjectid, rc.checknumber
                    FROM query.o_refundcheck rc
                         JOIN query.r_refundbatchcheck rb
                         ON rb.refundcheckobjectid = rc.objectid
                   WHERE rb.refundbatchjobid = a_jobid  -- The Refund Batch JobId
                                                      )
        LOOP
            --Remove all fee Ids and Refund Amounts from the array
            t_feeids.delete;
            t_refundamounts.delete;
            --Remove all Var values and reset the index
            t_var.delete;

            --t_index := 0;
            BEGIN
                FOR x IN (SELECT ROWNUM,
                                 ft.feeid,
                                 (rcpt.refundamount * -1)
                                     refundamount,
                                 pt.licensenumber,
                                 pt.licensetypecode,
                                 rcpt.servicecharge,
                                 pt.feescheduledescriptionforgrid,
                                 pt.objectid
                                     paytransobjid,
                                 pt.paymentid,
                                 rc.payeename,
                                    rc.payeeaddress
                                 || CHR(10)
                                 || rc.citystatezip
                                     payeeaddress
                            FROM query.o_refundcheck rc
                                 JOIN query.r_refundcheckpaytrans rcpt
                                 ON rcpt.refundcheckobjectid = rc.objectid
                                 JOIN query.o_paymenttransactions pt
                                 ON pt.objectid = rcpt.paymenttransactionobjectid
                                 JOIN api.feetransactions ft
                                 ON ft.transactionid = pt.transactionid
                           WHERE rc.objectid = c.refundcheckobjectid)
                LOOP
                    -- Set the IsRefunded flag on the Payment Transfer
                    api.pkg_columnupdate.setvalue(x.paytransobjid, 'IsRefunded', 'Y');

                    --Find the appropreate fee for which the SRV transactions will be related.
                    IF x.servicecharge = 'Y' THEN
                        pkg_refund.srvtransaction(c.refundcheckobjectid,
                                                  x.feeid,
                                                  x.licensenumber,
                                                  x.licensetypecode,
                                                  t_var,
                                                  t_feeids,
                                                  t_refundamounts,
                                                  t_srvfeeids,
                                                  t_srvamounts);
                    END IF;

                    --Reset the index
                    /*        t_Index := 0; -- old procedure
                                           for y in (select rownum, rci.ObjectId, rci.SRVAmount, rci.LicenseNumber, rci.LicenseTypeCode
                                                       from query.o_refundcheck rc
                                                       join query.r_RefundCheckRefundCheckItem rcrci on rcrci.RefundCheckObjectId = rc.ObjectId
                                                       join query.o_Refundcheckitem rci on rci.ObjectId = rcrci.RefundCheckItemObjectId
                                                      where rc.ObjectId = c.RefundCheckObjectId
                                                        and x.Servicecharge = 'Y') loop

                                              t_index := t_index + 1;
                                             --if the Value doesn't exists then Insert it.
                                             if t_VAR.EXISTS(t_Index) then
                                              null;
                                             else
                                              t_VAR.EXTEND;
                                              t_VAR(t_index) := 1;
                                             end if;

                                              --If the service charge equals the payment transaction's license number and code
                                              If x.licensenumber = y.licensenumber
                                              and x.licensetypecode = y.licensetypecode
                                              and t_VAR(t_index) = 1 -- and it has not been used before
                                               then --then Add it to the Array using the matching feeid for the FeeObjId value
                                                 -- Change the Var into 2 so it will not add this to the array the next time around
                                                 t_VAR(t_index) := 2;
                                                 -- Add to array
                                                 t_FeeIds(t_FeeIds.count + 1) := x.feeid; --Add x.feeId to the array
                                                 t_RefundAmounts(t_RefundAmounts.count + 1) := y.SRVAmount; --Add y.SRVAmount to the array

                                                 -- Add to seperate array so it will get the Service Charge flag set.
                                                 t_SRVFeeIds(t_SRVFeeIds.count + 1) := x.feeid;
                                                 t_SRVAmounts(t_SRVAmounts.count + 1) := y.SRVAmount;


                                              end if;
                                           end loop;*/

                    --Unearn the old Payment Transaction if the old PT is earned
                    /* Sheik 3/22/2018 - WO# 14438
                                   if api.pkg_columnquery.value(api.pkg_columnquery.numericvalue(x.paytransobjid, 'PaymentStatusObjectId'), 'Status') = 'EARNED' then
                                     -- Get the amount to unearn
                                     t_EarnedAmount := -api.pkg_columnquery.value(api.pkg_columnquery.numericvalue(x.paytransobjid, 'PaymentStatusObjectId'), 'EarnedAmount');
                                   t_NewPayStatus := api.pkg_objectupdate.New(api.pkg_configquery.objectdefidforname('o_PaymentStatus'));
                                   api.pkg_columnupdate.setvalue(t_NewPayStatus, 'StatusDate', trunc(sysdate));
                                   api.pkg_columnupdate.setvalue(t_NewPayStatus, 'Status', 'UNEARNED');
                                   api.pkg_columnupdate.setvalue(t_NewPayStatus, 'SystemGenerated', 'Y');
                                     api.pkg_columnupdate.setvalue(t_NewPayStatus, 'EarnedAmount', t_EarnedAmount);
                                   t_NewRelId := api.pkg_relationshipupdate.New(api.pkg_configquery.EndPointIdForName('o_PaymentStatus', 'PaymentTransactions'),
                                                                                t_NewPayStatus,
                                                                                x.paytransobjid);
                                   else
                                     null;
                                   end if;
                               */
                    --Add x.feeId and x.Refund Amount to the Array
                    t_feeids(t_feeids.COUNT + 1)                 := x.feeid;
                    t_refundamounts(t_refundamounts.COUNT + 1)   := x.refundamount;
                    
                         pkg_debug.put_line('****current feeid '||x.feeid);
                         pkg_debug.put_line('****current refund amount '||x.refundamount);
            
                    --If it was previously an Over Payment then track it as an OVR refund.
                    --or if it was previously a Service Charge then track it as a SRV.
                    IF x.feescheduledescriptionforgrid = 'OVR' THEN
                        t_ovrfeeids(t_ovrfeeids.COUNT + 1)               := x.feeid;
                        t_ovramountstopay(t_ovramountstopay.COUNT + 1)   := x.refundamount;
                    ELSIF x.feescheduledescriptionforgrid = 'SRV' THEN
                        t_srvfeeids(t_srvfeeids.COUNT + 1)     := x.feeid;
                        t_srvamounts(t_srvamounts.COUNT + 1)   := x.refundamount;
                    END IF;

                    -- Set the variables for Payee information so they can be used later to set details on the payment
                    t_payeeaddress                               := x.payeeaddress;
                    t_payeename                                  := x.payeename;

                    SELECT reo.objectid, api.pkg_columnquery.VALUE(reo.objectid, 'IsRefundedlookup') ir
                      INTO t_oldpaymentid, t_ispayrefund
                      FROM api.registeredexternalobjects reo  --TAyers: PIP Task 8.5
                     WHERE reo.linkvalue = TO_CHAR(x.paymentid)
                       AND reo.objectdefid = t_paymentobjectdefid;

                    api.pkg_columnupdate.setvalue(t_oldpaymentid, 'IsRefund', t_ispayrefund);
                END LOOP;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    api.pkg_errors.raiseerror(-20000, 'All Checks must have a Payment Transaction related.');
            END;
            

            --Create a Reversal Payment
            pkg_accounting.createbatchpayments(t_feeids,
                                               t_refundamounts,
                                               c.refundcheckobjectid,
                                               NULL,
                                               t_newpaymentid,
                                               'N',
                                               'N',
                                               'N',
                                               'R',
                                               'R');
            -- Process reversal payment (updates R2I and Batch Flags on LT)
            pkg_fees.processnegativepayment(a_paymentid => t_newpaymentid);

            -- Set the Reference Name from the Sequance to the temporary Check Number
            api.pkg_paymentupdate.modify(t_newpaymentid, c.checknumber, NULL);

            -- select the extearnal Id into the
            SELECT reo.objectid
              INTO t_newpaymentobjid
              FROM api.registeredexternalobjects reo  --TAyers: PIP Task 8.5
             WHERE reo.linkvalue = TO_CHAR(t_newpaymentid)
               AND reo.objectdefid = t_paymentobjectdefid;

            -- Set the Payment date to the current date
            api.pkg_columnupdate.setvalue(t_newpaymentobjid, 'PaymentDateStored', TRUNC(SYSDATE));
            -- Set the Is Receipted flag to Y Preventing it from being receipted
            api.pkg_columnupdate.setvalue(t_newpaymentobjid, 'IsReceiptedStored', 'Y');
            --Set the Payee information on the new Payment
            api.pkg_columnupdate.setvalue(t_newpaymentobjid, 'PayeeAddressStored', t_payeeaddress);
            api.pkg_columnupdate.setvalue(t_newpaymentobjid, 'PayeeNameStored', t_payeename);
        END LOOP;

        --Add the Refund Totals together
        SELECT SUM(rc.remittanceadvicetotal), SUM(rc.srvtotal)
          INTO t_batchamount, t_srvamount
          FROM query.o_refundcheck rc
               JOIN query.r_refundbatchcheck rbc
               ON rbc.refundcheckobjectid = rc.objectid
         WHERE rbc.refundbatchjobid = a_jobid;

        --Default the Batch Amount and the Batch SRV Amount
        --api.pkg_columnupdate.SetValue(a_JobId, 'BatchAmount', nvl(t_BatchAmount,0));
        --api.pkg_columnupdate.SetValue(a_JobId, 'BatchSRVAmt', nvl(t_SRVAmount,0));

        IF t_srvfeeids.COUNT > 0 THEN
            sitespecific.pkg_fees.setpaymenttransactionflag(t_srvfeeids,
                                                            t_srvamounts,
                                                            'IsServiceCharge',
                                                            TRUE);
        END IF;

        IF t_ovrfeeids.COUNT > 0 THEN
            sitespecific.pkg_fees.setpaymenttransactionflag(t_ovrfeeids, t_ovramountstopay, 'IsOverpayment');
        END IF;

        -- Create Payment Statuses for all SRV values where the most recent SRV Fee Activity code is set to earn on payment.
        sitespecific.pkg_refund.earnsrvpaytrans(t_srvfeeids, t_srvamounts);

        -- Set CABINAmtType it I for SRV transactions
        FOR c IN 1 .. t_srvfeeids.COUNT
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
             WHERE ft.feeid = t_srvfeeids(c)
               AND -ft.amount = t_srvamounts(c);

            --Set CABINAmtType to I
            api.pkg_columnupdate.setvalue(t_paytransobjectid, 'CABINAmtType', 'R');
        END LOOP;
    END createrefundtransactions;

    PROCEDURE updaterefundtransactions(a_objectid NUMBER, a_asofdate DATE, a_jobid NUMBER)
    IS
    BEGIN
        FOR c IN (SELECT rc.objectid refundcheckobjectid, rc.checknumber
                    FROM query.o_refundcheck rc
                         JOIN query.r_refundbatchcheck rb
                         ON rb.refundcheckobjectid = rc.objectid
                   WHERE rb.refundbatchjobid = a_jobid)
        LOOP
            FOR x IN (SELECT p.paymentid
                        FROM query.o_refundcheck rc
                             JOIN query.r_refundcheckpayment rcp
                             ON rcp.refundcheckobjid = rc.objectid
                             JOIN query.o_payment p
                             ON p.objectid = rcp.paymentobjectid  -- this is an external tables so it might be slow
                       WHERE rc.objectid = c.refundcheckobjectid)
            LOOP
                -- Update the Reference Name from the Sequance to the Actual Check Number
                api.pkg_paymentupdate.modify(x.paymentid, c.checknumber, NULL);
            END LOOP;

            --Set the Check Date to the current date
            api.pkg_columnupdate.setvalue(c.refundcheckobjectid, 'CheckDate', SYSDATE);
        END LOOP;
    END updaterefundtransactions;

    ----------------------------------------------------------------------------------------------------
    --  EarnPaymentTransactions()
    -- creates an Earned Payment Status for every Fee Id passed in.
    ----------------------------------------------------------------------------------------------------
    PROCEDURE earnsrvpaytrans(a_earnfeeids    udt_idlist,
                              a_amountstopay  udt_numberlist,
                              a_paymenttransfer BOOLEAN DEFAULT FALSE)
    AS
        t_paytransobjectid              udt_id;
        t_earnedon                      VARCHAR2(4000);
        t_paymentstatusobjid            udt_id;
        t_paymentstatusdefid            udt_id := api.pkg_configquery.objectdefidforname('o_PaymentStatus');
        t_paytranspaystatusendpointid   udt_id
            := api.pkg_configquery.endpointidforname('o_PaymentTransactions', 'PaymentStatus');
        t_relid                         udt_id;
        t_paytransobjectdefid           udt_id := api.pkg_configquery.objectdefidforname('o_PaymentTransactions');
    BEGIN
        SELECT api.pkg_columnquery.VALUE(x.objectid, 'EarnedOn')
          INTO t_earnedon
          FROM TABLE(
                   CAST(
                       api.pkg_simplesearch.castableobjectsbyindex('o_FeeSchedule', 'FeeActivity', 'SRV') AS api.udt_objectlist))
               x
         WHERE api.pkg_columnquery.datevalue(x.objectid, 'EffectiveDate') = (SELECT MAX(effectivedate)
                                                                               FROM sitespecific.feeschedule_t
                                                                              WHERE feeactivity = 'SRV');

        IF t_earnedon = 'PAYMENT'
       AND a_paymenttransfer = FALSE THEN
            FOR c IN 1 .. a_earnfeeids.COUNT
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
                 WHERE ft.feeid = a_earnfeeids(c)
                   AND -ft.amount = a_amountstopay(c)
                   AND api.pkg_columnquery.VALUE(reo.objectid, 'IsServiceCharge') = 'Y';

                IF t_paytransobjectid IS NOT NULL THEN
                    --create paymentstatus for paymenttransactions
                    t_paymentstatusobjid   := api.pkg_objectupdate.new(t_paymentstatusdefid);
                    --set details on PaymentStatus Object
                    api.pkg_columnupdate.setvalue(t_paymentstatusobjid, 'Status', 'EARNED');
                    api.pkg_columnupdate.setvalue(t_paymentstatusobjid, 'StatusDate', TRUNC(SYSDATE));
                    api.pkg_columnupdate.setvalue(t_paymentstatusobjid, 'SystemGenerated', 'Y');
                    --create rel to paymentstatus from paymentTransaction
                    t_relid                :=
                        api.pkg_relationshipupdate.new(t_paytranspaystatusendpointid,
                                                       t_paytransobjectid,
                                                       t_paymentstatusobjid);
                END IF;
            END LOOP;
        ELSIF t_earnedon = 'PAYMENT'
          AND a_paymenttransfer = TRUE THEN
            FOR c1 IN (SELECT reo.objectid  --into t_PayTransObjectId
                         FROM api.feetransactions ft
                              JOIN api.registeredexternalobjects reo  --TAyers: PIP Task 8.5
                              ON reo.linkvalue = TO_CHAR(ft.transactionid)
                             AND reo.objectdefid = t_paytransobjectdefid
                              JOIN api.fees f
                              ON f.feeid = ft.feeid
                        WHERE ft.feeid = a_earnfeeids(1)
                          AND api.pkg_columnquery.VALUE(reo.objectid, 'IsServiceCharge') = 'Y')
            LOOP
                --Select max Payment Transaction where feeid and amount are in array

                --create paymentstatus for paymenttransactions
                t_paymentstatusobjid   := api.pkg_objectupdate.new(t_paymentstatusdefid);
                --set details on PaymentStatus Object
                api.pkg_columnupdate.setvalue(t_paymentstatusobjid, 'Status', 'EARNED');
                api.pkg_columnupdate.setvalue(t_paymentstatusobjid, 'StatusDate', TRUNC(SYSDATE));
                api.pkg_columnupdate.setvalue(t_paymentstatusobjid, 'SystemGenerated', 'Y');
                --create rel to paymentstatus from paymentTransaction
                t_relid                :=
                    api.pkg_relationshipupdate.new(t_paytranspaystatusendpointid, c1.objectid, t_paymentstatusobjid);
            END LOOP;
        END IF;
    END earnsrvpaytrans;

    ----------------------------------------------------------------------------------------------------
    --  SRVTransaction()
    -- This is used within the CreateRefundTransaction and the pkg_Fees.TransferPayment procedures
    ----------------------------------------------------------------------------------------------------
    PROCEDURE srvtransaction(a_objectid            udt_id,
                             a_xfeeid              udt_id,
                             a_xlicensenumber      NUMBER,
                             a_xlicensetypecode    NUMBER,
                             a_var          IN OUT var,  -- this must be declared at the top of the package
                             a_feeids       IN OUT api.pkg_definition.udt_idlist,
                             a_amounts      IN OUT api.pkg_definition.udt_numberlist,
                             a_srvfeeids    IN OUT api.pkg_definition.udt_idlist,
                             a_srvamounts   IN OUT api.pkg_definition.udt_numberlist)
    IS
        TYPE cur_typ IS REF CURSOR;

        c1                   cur_typ;
        query_str            VARCHAR(4000);

        t_objectdefname      VARCHAR2(30) := api.pkg_columnquery.VALUE(a_objectid, 'ObjectDefName');
        t_index              INTEGER;

        t_ysrvamount         NUMBER;
        t_ylicensenumber     NUMBER;
        t_ylicensetypecode   VARCHAR2(2);
    BEGIN
        IF t_objectdefname = 'o_RefundCheck' THEN
            query_str   :=
                   'select -rci.SRVAmount, rci.LicenseNumber, rci.LicenseTypeCode 
            from query.o_refundcheck rc
            join query.r_RefundCheckRefundCheckItem rcrci on rcrci.RefundCheckObjectId = rc.ObjectId
            join query.o_Refundcheckitem rci on rci.ObjectId = rcrci.RefundCheckItemObjectId
           where rc.ObjectId = '
                || a_objectid
                || '
           order by rownum, rci.objectid';
        ELSIF t_objectdefname = 'p_PaymentTransfer' THEN
            query_str   :=
                   'select -rci.SRVAmount, rci.LicenseNumber, rci.LicenseTypeCode 
            from query.p_paymenttransfer pt
            join query.r_PaymentTransferRefundCheckIt ptrci on ptrci.PaymentTransferObjectId = pt.ObjectId
            join query.o_Refundcheckitem rci on rci.ObjectId = ptrci.RefundCheckItemObjectId
           where pt.ObjectId = '
                || a_objectid
                || '
           order by rownum, rci.objectid';
        END IF;

        --reset t_index
        t_index   := 0;

        OPEN c1 FOR query_str;

        LOOP
            FETCH c1 INTO t_ysrvamount, t_ylicensenumber, t_ylicensetypecode;

            EXIT WHEN c1%NOTFOUND;

            t_index   := t_index + 1;

            --if the Value doesn't exists then Insert it.
            IF a_var.EXISTS(t_index) THEN
                NULL;
            ELSE
                a_var.EXTEND;
                a_var(t_index)   := 1;
            END IF;

            --If the service charge equals the payment transaction's license number and code
            IF a_xlicensenumber = t_ylicensenumber
           AND (a_xlicensetypecode = t_ylicensetypecode
             OR (a_xlicensetypecode IS NULL
             AND t_ylicensetypecode IS NULL))
           AND a_var(t_index) = 1  -- and it has not been used before -- no function with name 'a_VAR' exists in this scope??
                                  THEN  --then Add it to the Array using the matching feeid for the FeeObjId value
                -- Change the Var into 2 so it will not add this to the array the next time around
                a_var(t_index)                         := 2;
                -- Add to array
                a_feeids(a_feeids.COUNT + 1)           := a_xfeeid;  --Add x.feeId to the array
                a_amounts(a_amounts.COUNT + 1)         := t_ysrvamount;  --Add y.SRVAmount to the array

                -- Add to seperate array so it will get the Service Charge flag set.
                a_srvfeeids(a_srvfeeids.COUNT + 1)     := a_xfeeid;
                a_srvamounts(a_srvamounts.COUNT + 1)   := t_ysrvamount;
            END IF;
        END LOOP;
    END srvtransaction;

    /*************************************************************************************************
       Generate Check Numbers is run on teh refund batch to populate the refund check numbers
       *************************************************************************************************/
    PROCEDURE generatechecknumbers(a_objectid udt_id, a_asofdate DATE)
    AS
        t_checkids      udt_idlist;
        t_checknumber   NUMBER;
        t_checknumto    NUMBER;
    BEGIN
        --get check # from field
        SELECT jrb2.checknumberfrom, jrb2.checknumberto
          INTO t_checknumber, t_checknumto
          FROM query.j_refundbatch jrb2
         WHERE jrb2.objectid = a_objectid;

          -- get the objectids of the checks that need to be updated
          SELECT orc.objectid
            BULK COLLECT INTO t_checkids
            FROM query.j_refundbatch jrb
                 JOIN query.r_refundbatchcheck rbc
                 ON rbc.refundbatchjobid = jrb.objectid
                 JOIN query.o_refundcheck orc
                 ON orc.objectid = rbc.refundcheckobjectid
           WHERE jrb.objectid = a_objectid
        ORDER BY orc.objectid;

        -- set the checknumber field on the Refund Check Item to a value between the Check # From and the Check # To fields at an increment of one
        IF (api.pkg_columnquery.VALUE(a_objectid, 'CheckCount') <> api.pkg_columnquery.VALUE(a_objectid, 'Items')) THEN
            api.pkg_errors.raiseerror(-20000,
                                      'The entered number of Items does not match the number of rows in the grid.');
        ELSE
            FOR c IN 1 .. t_checkids.COUNT
            LOOP
                api.pkg_columnupdate.setvalue(t_checkids(c), 'CheckNumber', t_checknumber);

                IF t_checknumber < t_checknumto THEN
                    t_checknumber   := t_checknumber + 1;
                END IF;
            END LOOP;
        END IF;
    END generatechecknumbers;

    ----------------------------------------------------------------------------------------------------
    --  ReverseRefundPayment()
    -- This is used on completion of the Reverse Refund Payment Process.
    ----------------------------------------------------------------------------------------------------

    PROCEDURE reverserefundpayment(a_objectid NUMBER, a_asofdate DATE)
    IS
        t_relid                     NUMBER;
        t_batchid                   VARCHAR2(20);
        t_hqreceiptnum              VARCHAR2(8);
        t_feeids                    api.pkg_definition.udt_idlist;
        t_amountstoreverse          api.pkg_definition.udt_numberlist;
        t_newpaymentid              udt_id;
        t_newpaymentobjid           udt_id;
        t_newpaystatus              udt_id;
        t_oldpaymentid              udt_id;
        t_oldpaymentobjid           udt_id;
        t_paymentamt                NUMBER;
        t_paytransobjectid          udt_id;
        t_transactionobjid          udt_id;
        t_payeeaddress              VARCHAR2(4000);
        t_payeename                 VARCHAR2(4000);
        t_payeereference            VARCHAR2(60);
        t_earnedamount              NUMBER;
        t_paymentmethodobjid        udt_id;
        t_paymentmethodendpointid   udt_id := api.pkg_configquery.endpointidforname('o_Payment', 'PaymentMethod');

        t_ovrfeeids                 api.pkg_definition.udt_idlist;
        t_ovramountstopay           api.pkg_definition.udt_numberlist;
        t_paytransobjectdefid       udt_id := api.pkg_configquery.objectdefidforname('o_PaymentTransactions');
    BEGIN
        t_feeids.delete;
        t_amountstoreverse.delete;

        --Select Payment
        SELECT p.paymentid,
               prrp.paymentobjectid,
               p.paymentamountfordisplay paymentamt,
               p.hqreceiptlookup         hqreceipt,
               p.batchid,
               p.payeeaddress,
               p.payeename,
               p.payeereference
          INTO t_oldpaymentid,
               t_oldpaymentobjid,
               t_paymentamt,
               t_hqreceiptnum,
               t_batchid,
               t_payeeaddress,
               t_payeename,
               t_payeereference
          FROM query.r_paymentrrpayment prrp
               JOIN query.o_payment p
               ON p.objectid = prrp.paymentobjectid
         WHERE prrp.rrpaymentprocessid = a_objectid;

        FOR pt IN (SELECT  /*+ CARDINALITY(x 1)*/
                          ft.feeid,
                          ft.amount   amttoreverse,
                          pt.paymentid,
                          pt.objectid paymenttranobjid,
                          pt.feescheduledescriptionforgrid
                     FROM api.paymenttransactions pts
                          JOIN api.registeredexternalobjects reo  --TAyers: PIP Task 8.5
                          ON reo.linkvalue = TO_CHAR(pts.transactionid)
                         AND reo.objectdefid = t_paytransobjectdefid
                          JOIN query.o_paymenttransactions pt
                          ON pt.objectid = reo.objectid
                          JOIN api.feetransactions ft
                          ON ft.transactionid = pt.transactionid
                    WHERE pts.paymentid = t_oldpaymentid)
        LOOP
            --Load the arrays with the fees and amounts to reverse.
            t_feeids(t_feeids.COUNT + 1)                       := pt.feeid;
            t_amountstoreverse(t_amountstoreverse.COUNT + 1)   := pt.amttoreverse;

            --Reverse the Is Refunded Check box
            api.pkg_columnupdate.setvalue(pt.paymenttranobjid, 'IsRefunded', 'N');

            --Find the OVR Payments
            IF pt.feescheduledescriptionforgrid = 'OVR' THEN
                t_ovrfeeids(t_ovrfeeids.COUNT + 1)               := pt.feeid;
                t_ovramountstopay(t_ovramountstopay.COUNT + 1)   := pt.amttoreverse;
            END IF;

            -- If the PT is an SRV, unearn it
            IF api.pkg_columnquery.VALUE(
                   api.pkg_columnquery.numericvalue(pt.paymenttranobjid, 'PaymentStatusObjectId'),
                   'Status') =
               'EARNED' THEN
                -- Get the amount to unearn
                t_earnedamount   :=
                    -api.pkg_columnquery.VALUE(
                         api.pkg_columnquery.numericvalue(pt.paymenttranobjid, 'PaymentStatusObjectId'),
                         'EarnedAmount');
                --Unearn the transaction
                t_newpaystatus   :=
                    api.pkg_objectupdate.new(api.pkg_configquery.objectdefidforname('o_PaymentStatus'));
                t_relid   :=
                    api.pkg_relationshipupdate.new(
                        api.pkg_configquery.endpointidforname('o_PaymentStatus', 'PaymentTransactions'),
                        t_newpaystatus,
                        pt.paymenttranobjid);
                api.pkg_columnupdate.setvalue(t_newpaystatus, 'Status', 'UNEARNED');
                api.pkg_columnupdate.setvalue(t_newpaystatus, 'StatusDate', TRUNC(SYSDATE));
                api.pkg_columnupdate.setvalue(t_newpaystatus, 'SystemGenerated', 'Y');
                api.pkg_columnupdate.setvalue(t_newpaystatus, 'EarnedAmount', t_earnedamount);
            END IF;
        END LOOP;

        --Reverse the Is Refund checkbox
        api.pkg_columnupdate.setvalue(t_oldpaymentobjid, 'IsRefund', 'N');

        --Set IsRefundReversed to 'Y'
        api.pkg_columnupdate.setvalue(t_oldpaymentobjid, 'IsRefundReversed', 'Y');

        --Create the Reversal Payments.
        t_newpaymentid      := api.pkg_paymentupdate.new(SYSDATE, t_feeids, t_amountstoreverse);
        t_newpaymentobjid   := api.pkg_objectupdate.registerexternalobject('o_Payment', t_newpaymentid);

        -- Set the income code for the payment to 'R'
        api.pkg_columnupdate.setvalue(t_newpaymentobjid, 'CABINIncomeInd', 'R');

        --For each Payment Transaction for the Payment that was just created, register the external Payment Transaction and Fee Transaction
        FOR c1 IN (SELECT pt.transactionid, ft.amount
                     FROM api.paymenttransactions pt
                          JOIN api.feetransactions ft
                          ON ft.transactionid = pt.transactionid
                    WHERE pt.paymentid = t_newpaymentid)
        LOOP
            t_paytransobjectid   :=
                api.pkg_objectupdate.registerexternalobject('o_PaymentTransactions', c1.transactionid);
            t_transactionobjid   :=
                api.pkg_objectupdate.registerexternalobject('o_FeeTransactions', c1.transactionid);

            -- Set the income code for the payment transactions to 'R'
            api.pkg_columnupdate.setvalue(t_paytransobjectid, 'CABINAmtType', 'R');

            -- Set HQReceipt on the Payment Transaction
            api.pkg_columnupdate.setvalue(t_paytransobjectid, 'HQReceipt', t_hqreceiptnum);

            -- Set the IsServiceCharge flag for SRV transactions
            IF c1.amount > 0 THEN
                api.pkg_columnupdate.setvalue(t_paytransobjectid, 'IsServiceCharge', 'Y');
            END IF;
        END LOOP;  --Register object, payment status loop

        --Get Payment Method ObjectId
        BEGIN
            SELECT  /*+ CARDINALITY(x 1) */
                   x.objectid
              INTO t_paymentmethodobjid
              FROM TABLE(
                       CAST(
                           api.pkg_simplesearch.castableobjectsbyindex('o_PaymentMethod', 'Code', 'HQB') AS api.udt_objectlist))
                   x;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                api.pkg_errors.raiseerror(-20000, 'No Payment Method with the Code ''HQB'' exists.');
        END;

        -- Set the Payee Reference to the preveious value
        api.pkg_paymentupdate.modify(t_newpaymentid, t_payeereference, NULL);
        api.pkg_columnupdate.setvalue(t_newpaymentobjid, 'BatchPaymentId', t_batchid);
        api.pkg_columnupdate.setvalue(t_newpaymentobjid, 'PaymentDateStored', TRUNC(SYSDATE));
        t_relid             :=
            api.pkg_relationshipupdate.new(t_paymentmethodendpointid, t_newpaymentobjid, t_paymentmethodobjid);
        api.pkg_columnupdate.setvalue(t_newpaymentobjid,
                                      'PaymentAmountStored',
                                      api.pkg_columnquery.VALUE(t_newpaymentobjid, 'PaymentAmount'));
        api.pkg_columnupdate.setvalue(t_newpaymentobjid, 'PaymentDateStored', TRUNC(SYSDATE));
        api.pkg_columnupdate.setvalue(t_newpaymentobjid, 'IsReceiptedStored', 'Y');
        api.pkg_columnupdate.setvalue(t_newpaymentobjid, 'PayeeAddressStored', t_payeeaddress);
        api.pkg_columnupdate.setvalue(t_newpaymentobjid, 'PayeeNameStored', t_payeename);

        -- Set OVR flags on the new transactions
        IF t_ovrfeeids.COUNT > 0 THEN
            sitespecific.pkg_fees.setpaymenttransactionflag(t_ovrfeeids, t_ovramountstopay, 'IsOverpayment');
        END IF;

        -- Set income code on the Payment Transactions to 'R'
        FOR x IN (SELECT reo.objectid
                    FROM api.paymenttransactions pt
                         JOIN api.registeredexternalobjects reo  --TAyers: PIP Task 8.5
                         ON reo.linkvalue = TO_CHAR(pt.transactionid)
                        AND reo.objectdefid = t_paytransobjectdefid
                   WHERE pt.paymentid = t_newpaymentid)
        LOOP
            api.pkg_columnupdate.setvalue(x.objectid, 'CABINAmtType', 'R');
        END LOOP;
    END reverserefundpayment;

    -- 03/04/2020 TJL WO 20884  Added procedure
    -- schedulecreatesvrtransaction is called from the application withdrawal process to schedule
    --  the creation of the SRV fee amount when not fees are being refunded.
    PROCEDURE schedulecreatesvrtransaction(a_objectid NUMBER, a_asofdate DATE, a_jobid NUMBER)
    IS
        t_args          VARCHAR2(4000);
        t_description   VARCHAR2(50) := 'Create SRV Fee Line';
        i               PLS_INTEGER;
    BEGIN
        IF (NVL(api.pkg_columnquery.VALUE(a_objectid, 'OutCome'), 'None') = 'Withdraw') THEN
            scheduler.pkg_scheduler.addargument(t_args,
                                                'procedure',
                                                'sitespecific.pkg_refund.createwithdrawaltransaction');
            scheduler.pkg_scheduler.addargument(t_args, 'effectiveuser', 'POSSESYS');  -- serves to track which process triggered this task.

            scheduler.pkg_scheduler.addargument(t_args, 'arg1', a_objectid);
            scheduler.pkg_scheduler.addargument(t_args, 'arg2', SYSDATE);
            scheduler.pkg_scheduler.addargument(t_args, 'arg3', a_jobid);

            INSERT INTO scheduler.sysschedule(schedulekey,
                                              userid,
                                              status,
                                              scheduledate,
                                              scheduleenddate,
                                              monthend,
                                              sunday,
                                              monday,
                                              tuesday,
                                              wednesday,
                                              thursday,
                                              friday,
                                              saturday,
                                              frequency,
                                              incrementby,
                                              unit,
                                              argument,
                                              description,
                                              object,
                                              output,
                                              collate,
                                              documentname,
                                              serverkey,
                                              assignedserverkey,
                                              priority,
                                              contiguous)
                 VALUES (scheduler.schedulekey_s.NEXTVAL,
                         'POSSESYS',
                         1,
                         TRUNC(SYSDATE) + 06 / 24,  -- schedule for 6AM
                         TO_DATE('12/31/3999', 'mm/dd/yyyy'),
                         'n',  --MonthEnd
                         'y',  --Sun
                         'y',  --Mon
                         'y',  --Tues
                         'y',  --Wed
                         'y',  --Thur
                         'y',  --Fri
                         'y',  --Sat
                         0,  --Every (Frequency drop down value)
                         0,  --IncrementBy
                         0,  --Hours (drop down value)
                         t_args,  --unit
                         t_description,  --description
                         'nc_0011_executeprocedureasposseuser',  --object
                         2,  -- output: process
                         'no',  --collate
                         'ITA_CUSTOM.PKG_BlendUtils.ProcessBlendQueue',  --documentname
                         2,  --serverkey
                         2,  --assignedserverkey
                         10,  --priority
                         'n'  --contiguous
                            );
        END IF;
    END schedulecreatesvrtransaction;


    -- 03/04/2020 TJL WO 20884  Added procedure
    --CreateWithdrawalTransactions
    --Called from the outcome of the withdrawl process on application job.
    --Creates batch refund job that creates a service fee for the total of
    --  all payments. It will only process the fee when the total fee is
    --  kept.  Any refund must be processed through POSSE Batch Refund.
    PROCEDURE createwithdrawaltransaction(a_objectid NUMBER, a_asofdate DATE, a_jobid NUMBER)
    IS
        t_refundbatchobjectid   api.pkg_definition.udt_id;
        t_refundbatchdefid      api.pkg_definition.udt_id;
        t_refundcheckobjectid   api.pkg_definition.udt_id;
        t_refundcheckdefid      api.pkg_definition.udt_id;
        t_endpointidfrom        api.pkg_definition.udt_id;
        t_relid                 api.pkg_definition.udt_id;
        t_nonrefundable         VARCHAR2(4000) := api.pkg_constantquery.VALUE('APPFEEACTIVITIES');
    BEGIN
        IF (NVL(api.pkg_columnquery.VALUE(a_objectid, 'OutCome'), 'None') != 'Withdraw') THEN
            RETURN;
        END IF;

        FOR j
            IN (  -- only process applications with non-refundable fees only and has not been refunded
                SELECT DISTINCT jobid
                  FROM api.fees f
                 WHERE f.jobid = a_jobid
                   AND EXISTS
                           -- check if any of the fees have non-refundable fees attached
                           (SELECT 1
                              FROM api.fees f2
                             WHERE f2.jobid = f.jobid
                               AND INSTR(api.pkg_constantquery.VALUE('APPFEEACTIVITIES'),
                                         REGEXP_SUBSTR(f2.description,  -- 06/10/2020 TJL WO 21772  
                                                       '[^ ]+',
                                                       1,
                                                       3)) > 0)
                   -- make sure that only fee activities that are non-refundable fees are processed
                   AND NOT EXISTS
                           (SELECT 1
                              FROM api.fees f2
                             WHERE f2.jobid = f.jobid
                               AND INSTR(api.pkg_constantquery.VALUE('APPFEEACTIVITIES'),
                                         REGEXP_SUBSTR(f2.description,  -- 06/10/2020 TJL WO 21772  
                                                       '[^ ]+',
                                                       1,
                                                       3)) = 0)
                   AND EXISTS
                           -- make sure the fee amounts do not exceed max non-refundable amount and transaction date
                           --   greater than jun 30, 2019
                           (SELECT 1
                              FROM api.fees f2
                             WHERE f2.jobid = f.jobid
                            HAVING SUM(f2.amount + f2.adjustedamount) <=
                                   TO_NUMBER(api.pkg_constantquery.VALUE('MAXNONREFUNDABLEAMT'))
                               AND SUM(f2.amount + f2.adjustedamount) = SUM(-f2.paidamount)
                               AND TRUNC(MIN(f2.transactiondate)) > TO_DATE('30-JUN-19'))
                   AND NOT EXISTS
                           -- make sure that the fees have not been refunded
                           (SELECT *
                              FROM (SELECT api.pkg_columnquery.VALUE(
                                               api.pkg_simplesearch.objectbyindex('o_PaymentTransactions',
                                                                                  'TransactionId',
                                                                                  t.transactionid),
                                               'IsRefunded')
                                               isrefunded
                                      FROM api.feetransactions t
                                     WHERE t.feeid = f.feeid)
                             WHERE isrefunded = 'Y') 
               )
        LOOP
            api.pkg_logicaltransactionupdate.resettransaction;
            ROLLBACK;

            t_refundbatchdefid      := api.pkg_configquery.objectdefidforname('j_refundbatch');
            t_refundbatchobjectid   := api.pkg_objectupdate.new(t_refundbatchdefid);

            DBMS_OUTPUT.put_line(   'RefundBatchObjectId: '
                                 || t_refundbatchobjectid);

            api.pkg_logicaltransactionupdate.endtransaction;
            COMMIT;

            -- create refund check
            t_refundcheckdefid      := api.pkg_configquery.objectdefidforname('o_refundcheck');
            t_refundcheckobjectid   := api.pkg_objectupdate.new(t_refundcheckdefid);

            api.pkg_columnupdate.setvalue(t_refundcheckobjectid, 'CheckNumber', 'WITHDRAWN');
            DBMS_OUTPUT.put_line(   'RefundcheckObjectId: '
                                 || t_refundcheckobjectid);

            -- relate to refund batch
            t_endpointidfrom        := api.pkg_configquery.endpointidforname('j_refundbatch', 'RefundCheck');
            t_relid                 :=
                api.pkg_relationshipupdate.new(t_endpointidfrom, t_refundbatchobjectid, t_refundcheckobjectid);

            DBMS_OUTPUT.put_line(   'RelationshipId RefundCheck: '
                                 || t_relid);
            api.pkg_logicaltransactionupdate.endtransaction;
            COMMIT;

            t_endpointidfrom        := api.pkg_configquery.endpointidforname('o_refundcheck', 'PaymentTransaction');

            -- find and add payment transaction to refund check object
            FOR rec
                IN (SELECT api.pkg_simplesearch.objectbyindex('o_PaymentTransactions',
                                                              'TransactionId',
                                                              t.transactionid)
                               paymenttransactionobjectid
                      FROM api.fees f
                           JOIN api.feetransactions t
                           ON (f.feeid = t.feeid)
                     WHERE f.jobid = j.jobid)
            LOOP
                -- check for no payment transaction
                CONTINUE WHEN rec.paymenttransactionobjectid IS NULL;

                t_relid   :=
                    api.pkg_relationshipupdate.new(t_endpointidfrom,
                                                   t_refundcheckobjectid,
                                                   rec.paymenttransactionobjectid);

                DBMS_OUTPUT.put_line(   'RelationshipId paymenttrans: '
                                     || t_relid);
            END LOOP;

            -- create srv
            -- call sitespecific.pkg_refund.createsrvlineitems(a_objectid udt_id, a_asofdate DATE)
            api.pkg_columnupdate.setvalue(t_refundcheckobjectid, 'CalculateSRV', 'Y');
            sitespecific.pkg_refund.createsrvlineitems(a_objectid => t_refundcheckobjectid, a_asofdate => NULL);

            api.pkg_logicaltransactionupdate.endtransaction;
            COMMIT;

            sitespecific.pkg_refund.createrefundtransactions(a_objectid  => NULL,
                                                             a_asofdate  => NULL,
                                                             a_jobid     => t_refundbatchobjectid);
            api.pkg_logicaltransactionupdate.endtransaction;
            COMMIT;
        END LOOP;

        -- remove refundcheck and batchrefund objects that were created when in production.
        --   keep in other environments for validation
        IF (t_refundbatchobjectid IS NOT NULL
        AND api.pkg_constantquery.VALUE('ISPRODUCTION') = 'Y') THEN
            FOR r
                IN (SELECT r.relationshipid
                      FROM api.relationships r
                     WHERE r.fromobjectid = t_refundcheckobjectid
                       AND r.endpointid IN
                               (api.pkg_configquery.endpointidforname('o_refundcheck', 'PaymentTransaction'),
                                api.pkg_configquery.endpointidforname('o_refundcheck', 'RefundCheckItem')))
            LOOP
                api.pkg_relationshipupdate.remove(r.relationshipid);
            END LOOP;

            api.pkg_objectupdate.remove(t_refundcheckobjectid);
            api.pkg_objectupdate.remove(t_refundbatchobjectid);

            api.pkg_logicaltransactionupdate.endtransaction;
            COMMIT;
        END IF;
    END createwithdrawaltransaction;
END pkg_refund;
/


GRANT EXECUTE ON SITESPECIFIC.PKG_REFUND TO EXTENSION;

GRANT EXECUTE ON SITESPECIFIC.PKG_REFUND TO POSSEEXTENSIONS;
