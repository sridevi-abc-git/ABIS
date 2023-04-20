CREATE OR REPLACE package body SITESPECIFIC.pkg_Michael is

Procedure TransferPayment(a_ObjectId        number,
                          a_AsOfDate        date)is

  type udt_FeeIds is table of number index by binary_integer;
  type BoolList is varray(100) of varchar2(1);

  t_BatchPaymentId         varchar2(20);
  t_DefaultOfficeObjectId  udt_Id;
  t_DepositDate            date;
  t_DoneOnce               varchar2(1);
  t_EarnedAmount           number;
  t_EarnedOnPay                  number;
  t_EndPointId             number;
  t_FeeJobId                      udt_Id;
  t_FeeScheduleId                 udt_id;
  t_HQReceipt              varchar2(8);
  t_IsReceipted            varchar2(1);
  t_MethodId               number;
  t_NewPaymentsDate               date;
  t_NewSRVFee                     udt_id;
  t_NewSRVFeeObjId                udt_id;
  t_OrigAmounts            udt_NumberList;
  t_OrigFeeId              udt_IdList;
  t_OrigFeeIds             udt_FeeIds;
  t_OrigPaymentIds         udt_IdList;
  t_OrigPaymentObjId       number;
  t_OVRPayAmounts          udt_NumberList;
  t_OVRToFeeId             udt_IdList;
  t_PayAmounts             udt_NumberList;
  t_PayAmountsOVR          udt_NumberList;
  t_PaymentId              number;
  t_PaymentIds             api.udt_objectlist;
  t_PaymentObjectId        number;
  t_PaymentStatusDefId           number;
  t_PaymentStatusEndpoint        number;
  t_PaymentStatusObjId           number;
  t_PayTransObjectId       number;
  t_PayTransObjectIds        udt_IdList;
  t_PriorCount                   number;
  t_ProcessId                     udt_Id;
  t_PTAmounts              udt_NumberList;
  t_PTFeeId                udt_IdList;
  t_PTOrigObjList            udt_IdList;
  t_ReceiptNumber          varchar2(40);
  t_Reference              varchar2(4000);
  t_RelId                  number;
  t_SRVAmounts               api.pkg_definition.udt_NumberList;
  t_SRVFeeAmount                  number;
  t_SRVFeeIds                api.pkg_definition.udt_ObjectList;
  t_SRVFlag                BoolList := BoolList();
  t_SRVGLAccountId                number;
  t_SRVPaymentId             number;
  t_temp                   udt_IdList;
  t_ToEarnAmount           number := 0;
  t_ToFeeId                udt_IdList;
  t_TofeeisOVR               udt_IdList;
  t_TotalEarnedAmount      number := 0;
  t_TransactionObjId       number;
  t_UnEarnAmount           number;
  t_UnPaymentId            number;
  t_VAR                      pkg_Refund.VAR := pkg_Refund.VAR();
  t_xLicenseNumber           udt_NumberList;
  t_xLicenseTypeCode         udt_NumberList;

  begin

  -- This will be the payment date on the
  t_NewPaymentsDate := trunc(sysdate);

  begin
  --Get SRV GL Account Id
    Select gl.GLAccountId
      into t_SRVGLAccountId
      from api.GLAccounts gl
     where gl.GLAccount = 'SRV';
  exception
  when no_data_found then
    api.Pkg_Errors.RaiseError(-20000,
                              'No GL Account exists for Fee Activity ' ||
                              'SRV');
  end;

  --Remove all Var values and reset the index
  t_VAR.DELETE;

  select count(r.RelationshipId) into t_PriorCount
                 from api.relationships r
                 where r.FromObjectId = a_Objectid
                 and r.EndPointId = api.pkg_configquery.EndPointIdForName('p_PaymentTransfer', 'PaymentTo');

   --only run procedure when process is completed and the procedure has not already created a PaymentTo relationship
 --   if (api.pkg_columnquery.Value(a_ObjectId, 'Outcome') is not null
 --     and t_PriorCount = 0)
 --        then
   --Find the HQ receipt number
   select api.pkg_columnquery.Value(pfpt.PaymentObjectId,'HQReceiptLookup')
     into t_HQReceipt
     from query.r_Paymentfrompaytransfer pfpt
   where pfpt.PayTransferProcessId = a_ObjectId;

   --Find the Deposited Date
   select api.pkg_columnquery.DateValue(pfpt.PaymentObjectId,'DepositedDate')
     into t_DepositDate
     from query.r_Paymentfrompaytransfer pfpt
   where pfpt.PayTransferProcessId = a_ObjectId;

   --Raise error when Move From Payment has been voided.
   if api.pkg_columnquery.Value(a_ObjectId, 'IsVoidedFrom') = 'Y'
     then api.pkg_errors.RaiseError(-20000, 'Payment has been voided!');
   end if;

   --Raise error when Move From Payment Transaction and Fee grid Pay amounts don't equal.
   if api.pkg_columnquery.Value(a_ObjectId, 'RaiseErrToFromAmounts') = 'Y'
     then api.pkg_errors.RaiseError(-20000, 'The Total amount you are Moving from the Payment Transactions Must Be Equal to the total Pay Amounts in the Move to Fees grid.');
   end if;

   --Get from FeeIds will have payments adjusted off and the Amounts to be removed
   select ft.FeeId,
          r.Amount, --change -r.amount to r.amount
          x.objectid,
          pt.PaymentId,
          pt.ObjectId,
          pt.LicenseNumber,
          pt.LicenseTypeCode,
          pt.IsServiceCharge
     bulk collect into
          t_OrigFeeId,
          t_OrigAmounts,
          t_temp,
          t_OrigPaymentIds,
          t_PTOrigObjList,
          t_xLicenseNumber,
          t_xLicenseTypeCode,
          t_SRVFlag
     from query.r_paymenttransfertrans r
     join query.o_paymenttransactions pt on pt.ObjectId = r.PaymentTransactionObjectId
     join api.feetransactions ft on ft.TransactionId = pt.TransactionId
     join table(cast(api.pkg_simplesearch.CastableObjectsByIndex('o_Payment', 'PaymentId', pt.PaymentId) as api.udt_ObjectList)) x on 1=1
    where r.PaymentTransferProcessId = a_ObjectId
      and r.Amount < 0; -- edited this to be less the 0 since r.amount is now negative

  -- loop through the SRV rows and add FeeId information.
  for c1 in 1..t_PTOrigObjList.count loop
     pkg_Refund.SRVTransaction(a_ObjectId,
                                 t_OrigFeeId(c1),
                                 t_xlicensenumber(c1),
                                 t_xlicensetypecode(c1),
                                 t_VAR,
                                 t_PTFeeId,
                                 t_PTAmounts,
                                 t_SRVFeeIds,
                                 t_SRVAmounts);

    --Set Payment Status Def Variables
    t_PaymentStatusDefId      := api.pkg_objectdefquery.IdForName('o_PaymentStatus');
    t_PaymentStatusEndpoint   := api.pkg_configquery.EndPointIdForName('o_PaymentTransactions',
                                                                       'PaymentStatus');

   --if the amount being moved is equal to the amount of the original fee
   --Unearn the Original transaction IF the original had earned
       --and the original was earned
   --if api.pkg_columnquery.numericvalue(api.pkg_columnquery.numericvalue(t_PTOrigObjList(c1), 'FeeObjId'), 'Amount') = t_OrigAmounts(c1) * -1
   if api.pkg_columnquery.numericvalue(t_PTOrigObjList(c1), 'PaymentAmount') = t_OrigAmounts(c1) * -1
     and api.pkg_columnquery.value(api.pkg_columnquery.numericvalue(t_PTOrigObjList(c1), 'PaymentStatusObjectId'), 'Status') = 'EARNED' then
     --unearn the orginal
     t_UnearnAmount := -api.pkg_columnquery.value(api.pkg_columnquery.numericvalue(t_PTOrigObjList(c1), 'PaymentStatusObjectId'), 'EarnedAmount');
     t_ToEarnAmount := t_ToEarnAmount - t_UnearnAmount;
                           t_PaymentStatusObjId      := api.pkg_objectupdate.New(t_PaymentStatusDefId);
                           t_RelId                   := api.pkg_relationshipupdate.New(t_PaymentStatusEndpoint,
                                                                                       t_PTOrigObjList(c1),
                                                                                       t_PaymentStatusObjId);
                           --set details
     api.pkg_columnupdate.SetValue(t_PaymentStatusObjId,'Status','UNEARNED');
     api.pkg_columnupdate.SetValue(t_PaymentStatusObjId,'StatusDate',trunc(sysdate));
     api.pkg_columnupdate.SetValue(t_PaymentStatusObjId,'SystemGenerated','Y');
     api.pkg_columnupdate.SetValue(t_PaymentStatusObjId,'EarnedAmount',t_UnearnAmount);
   -- unearn the reverse transaction that hasn't been created yet!
   elsif t_OrigAmounts(c1) * -1 < api.pkg_columnquery.numericvalue(t_PTOrigObjList(c1), 'Amount')
     and api.pkg_columnquery.value(api.pkg_columnquery.numericvalue(t_PTOrigObjList(c1), 'PaymentStatusObjectId'), 'Status') = 'EARNED' then
              --load an array of FeeObjId values  to process on New Payment loop
              --t_OrigFeeIds.extend;
              t_OrigFeeIds(api.pkg_columnquery.numericvalue(api.pkg_columnquery.numericvalue(t_PTOrigObjList(c1), 'FeeObjId'), 'FeeId')) := api.pkg_columnquery.numericvalue(t_PTOrigObjList(c1), 'FeeObjId');
        end if;


   end loop;

   --Original Payment Object Id
   t_OrigPaymentObjId := t_temp(1);

   --Create the SRV Fee
   if t_SRVAmounts.count > 0 then

   select max(x.Objectid)
     into t_FeeScheduleId
     from table(cast(api.pkg_simplesearch.CastableObjectsByIndex('o_FeeSchedule', 'FeeActivity', 'SRV') as api.udt_objectlist)) x
    where api.pkg_columnquery.datevalue(x.objectid, 'EffectiveDate') = (select max(EffectiveDate) from sitespecific.feeschedule_t where FeeActivity = 'SRV');

   select sum(api.pkg_columnquery.NumericValue(ptrc.RefundCheckItemObjectId, 'SRVAmountForDisplayOnPaymentTr'))
   into t_SRVFeeAmount
   from query.r_PaymentTransferRefundCheckIt ptrc
   where ptrc.PaymentTransferObjectId = a_ObjectId;

   pkg_fees.NewFee(t_NewSRVFee,
                   t_SRVFeeAmount,
                   'SRV',
                   t_SRVGLAccountId,
                   api.pkg_columnquery.NumericValue(a_ObjectId, 'JobId'),
                   null,
                   t_NewSRVFeeObjId);
    -- Relate Fee to Fee Schedule
       t_RelId := api.pkg_RelationshipUpdate.New(api.Pkg_ConfigQuery.EndPointIdForName('o_Fee',
                                                                                       'LicenseFeeSchedule'),
                                                                                        t_NewSRVFeeObjId,
                                                                                        t_FeeScheduleId);

   for x in 1..t_SRVFeeIds.count  loop
     t_SRVFeeIds(x):= t_NewSRVFee;
   end loop;

   -- Create SRV Payment
   t_SRVPaymentId := api.pkg_paymentupdate.New(t_NewPaymentsDate, t_SRVFeeIds, t_SRVAmounts);

   --Register SRV-Payment
   t_PaymentObjectId := api.pkg_objectupdate.RegisterExternalObject('o_Payment',
                                                                     t_SRVPaymentId);
   -- LOG SRV PAYMENTTRANSFER??
   insert into sitespecific.PaymentTransfers_t values(t_OrigPaymentObjId, t_OrigPaymentIds(1),t_PaymentObjectId,t_SRVPaymentId,'Y');

   -- Set the income code for the SRV payment to 'C'
   api.pkg_ColumnUpdate.SetValue(t_PaymentObjectId, 'CABINIncomeInd', 'C');

   -- Set the DepositedDate of the transfered payment
   api.pkg_ColumnUpdate.SetValue(t_PaymentObjectId, 'DepositedDate', t_DepositDate);

   -- For each Payment Transaction for the Payment that was just created, register the external Payment Transaction and Fee Transaction
   For c in (select pt.TransactionId
               from api.PaymentTransactions pt
              where pt.PaymentId = t_SRVPaymentId) Loop

     t_PayTransObjectId := api.pkg_ObjectUpdate.RegisterExternalObject('o_PaymentTransactions',
                                                                       c.TransactionId);
     t_TransactionObjId := api.pkg_ObjectUpdate.RegisterExternalObject('o_FeeTransactions',
                                                                       c.TransactionId);
     -- Set the amount type for the SRV payment transactions to 'C'
     api.pkg_ColumnUpdate.SetValue(t_PayTransObjectId, 'CABINAmtType', 'C');

     --Set the HQ Receipt Number
      api.pkg_columnupdate.SetValue(t_PayTransObjectId,
                                   'HQReceipt',
                                   t_HQReceipt);
   End Loop;

     --Set Payment PaymentDateStored
    api.pkg_columnupdate.SetValue(t_PaymentObjectId,
                                  'PaymentDateStored',
                                  trunc(sysdate));

     --Set Payment PaymentAmountStored
    api.pkg_columnupdate.SetValue(t_PaymentObjectId,
                                  'PaymentAmountStored',
                                  api.pkg_columnquery.value(t_PaymentObjectId, 'PaymentAmount'));

   end if;

    --Adjust Payment off of original Fee.
    t_UnPaymentId := api.pkg_paymentupdate.New(t_NewPaymentsDate, t_OrigFeeId, t_OrigAmounts);
    -- Process this payment
    pkg_Fees.ProcessNegativePayment(a_PaymentId => t_UnPaymentId);

    --Register Un-Payment
    t_PaymentObjectId := api.pkg_objectupdate.RegisterExternalObject('o_Payment',
                                                                     t_UnPaymentId);

    -- Set the income code for the payment to 'C'
    api.pkg_ColumnUpdate.SetValue(t_PaymentObjectId, 'CABINIncomeInd', 'C');

    -- Set the DepositedDate of the transfered payment
    api.pkg_ColumnUpdate.SetValue(t_PaymentObjectId, 'DepositedDate', t_DepositDate);


    -- For each Payment Transaction for the Payment that was just created, register the external Payment Transaction and Fee Transaction
    For c in (select pt.TransactionId, ft.feeid
                from api.paymenttransactions pt
                join api.feetransactions ft on ft.transactionid = pt.transactionid
               where pt.PaymentId = t_UnPaymentId) Loop

      t_PayTransObjectId := api.pkg_ObjectUpdate.RegisterExternalObject('o_PaymentTransactions',
                                                                        c.TransactionId);
      t_TransactionObjId := api.pkg_ObjectUpdate.RegisterExternalObject('o_FeeTransactions',
                                                                        c.TransactionId);
      -- Set the amount type for the payment transactions to 'C'
      api.pkg_ColumnUpdate.SetValue(t_PayTransObjectId, 'CABINAmtType', 'C');
      --Set the HQ Receipt Number
      api.pkg_columnupdate.SetValue(t_PayTransObjectId,
                                   'HqReceipt',
                                   t_HQReceipt);
      -- Set IsServiceCharge flag
      if t_SRVFlag(1) = 'Y' then
        api.pkg_ColumnUpdate.SetValue(t_PayTransObjectId, 'IsServiceCharge', 'Y');
      end if;
    --check array of OrigFeeIds for existance in the array, if exists, UNEARN here.
    if t_OrigFeeIds.exists(c.feeid) then
      --unearn the transaction we just created
     t_PaymentStatusObjId      := api.pkg_objectupdate.New(t_PaymentStatusDefId);
     t_RelId                   := api.pkg_relationshipupdate.New(t_PaymentStatusEndpoint,
                                                                 t_PayTransObjectId,
                                                                 t_PaymentStatusObjId);
     --set details
      api.pkg_columnupdate.SetValue(t_PaymentStatusObjId, 'Status', 'UNEARNED');
      api.pkg_columnupdate.SetValue(t_PaymentStatusObjId,'StatusDate',trunc(sysdate));
      api.pkg_columnupdate.SetValue(t_PaymentStatusObjId,'SystemGenerated','Y');
 end if;


    End Loop;

     --Set Payment PaymentDateStored
    api.pkg_columnupdate.SetValue(t_PaymentObjectId, 'PaymentDateStored', trunc(sysdate));

     --Set Payment PaymentAmountStored
    api.pkg_columnupdate.SetValue(t_PaymentObjectId,
                                  'PaymentAmountStored',
                                  api.pkg_columnquery.value(t_PaymentObjectId, 'PaymentAmount'));

    --Set all of the Fee Transactions' OVR value to 'N' where Amt to Pay is less then the balance.
    for O in (select r.RelationshipId, r.AmountToPay
                from query.r_paymenttransferfee r
                join query.o_fee f on f.ObjectId = r.FeeObjectId
               where r.PaymentTransferProcessId = a_ObjectId
                 and r.OVR = 'Y'
                 and r.AmountToPay <= f.TotalOwing ) loop
      api.pkg_columnupdate.SetValue(o.Relationshipid, 'OVR', 'N');

    end loop;
    --Get to FeeIds that should be calculated as OVRs
    select f.feeid, r.AmountToPay bulk collect into t_TofeeisOVR, t_PayAmountsOVR
         from query.r_paymenttransferfee r
         join query.o_fee f on f.ObjectId = r.FeeObjectId
         where r.PaymentTransferProcessId = a_ObjectId and r.OVR = 'Y';

    --Create Overpayment records (for separate, flagged PaymentTransactions) if The OVR checkbox is checked and the OVR checkbox on the Payment transfer screen is checked
    sitespecific.pkg_fees.CalculateOverpayment(t_TofeeisOVR, t_PayAmountsOVR, t_OVRToFeeId, t_OVRPayAmounts);

    --Get to FeeIds and Amounts to apply
    select f.feeid, r.AmountToPay  bulk collect into t_ToFeeId, t_PayAmounts
         from query.r_paymenttransferfee r
         join query.o_fee f on f.ObjectId = r.FeeObjectId
         where r.PaymentTransferProcessId = a_ObjectId and r.OVR = 'N';

    --t_TofeeisOVR(t_TofeeisOVR.count + 1) := t_ToFeeId;
    --t_PayAmountsOVR(t_PayAmountsOVR.count + 1) := t_PayAmounts;
    for c in 1..t_TofeeisOVR.count loop
      t_ToFeeId(t_ToFeeId.count + 1) := t_TofeeisOVR(c);
      t_PayAmounts(t_PayAmounts.count + 1) :=t_PayAmountsOVR(c);
    end loop;

    --Create Payment for against to fee.
    t_PaymentId := api.pkg_paymentupdate.New(t_NewPaymentsDate, t_TofeeId, t_PayAmounts);

    --Register Payment
    t_PaymentObjectId := api.pkg_objectupdate.RegisterExternalObject('o_Payment',
                                                                     t_PaymentId);
    -- Log to PaymentTransfer table
    insert into sitespecific.PaymentTransfers_t values(t_OrigPaymentObjId, t_OrigPaymentIds(1),t_PaymentObjectId,t_PaymentId,'N');

    -- Set the amount type for the payment to 'C'
    api.pkg_ColumnUpdate.SetValue(t_PaymentObjectId, 'CABINIncomeInd', 'C');

    -- Set the DepositedDate of the transfered payment
    api.pkg_ColumnUpdate.SetValue(t_PaymentObjectId, 'DepositedDate', t_DepositDate);

    -- For each fee that was paid, check if the job is a LT. If so, create and complete the Receive Payments process
    for p in 1..t_TofeeId.count loop
      select f.JobId
        into t_FeeJobId
        from api.Fees f
       where f.FeeId = t_ToFeeId(p);

 /*     If api.pkg_ColumnQuery.Value(t_FeeJobId, 'ObjectDefName') = 'j_LicenseType' then

        t_ProcessId := api.pkg_ProcessUpdate.New(t_FeeJobId,
                                                 api.pkg_ConfigQuery.ObjectDefIdForName('p_ReceivePayment'),
                                                 null,
                                                 sysdate,
                                                 sysdate,
                                                 sysdate);
      End If;*/
    end loop;

    -- For each Payment Transaction for the Payment that was just created, register the external Payment Transaction and Fee Transaction
    For c in (select pt.TransactionId
                from api.PaymentTransactions pt
               where pt.PaymentId = t_PaymentId) Loop

      t_PayTransObjectId := api.pkg_ObjectUpdate.RegisterExternalObject('o_PaymentTransactions',
                                                                        c.TransactionId);
      t_TransactionObjId := api.pkg_ObjectUpdate.RegisterExternalObject('o_FeeTransactions',
                                                                        c.TransactionId);
      -- Set the amount type for the payment transactions to 'C'
      api.pkg_ColumnUpdate.SetValue(t_PayTransObjectId, 'CABINAmtType', 'C');
      --Set the HQ Receipt Number
      api.pkg_columnupdate.SetValue(t_PayTransObjectId,
                                   'HqReceipt',
                                   t_HQReceipt);
    End Loop;

    -- Add Payment Ids to collection for loop
    t_PaymentIds := api.udt_objectlist();
      t_PaymentIds.extend(1);
      t_PaymentIds(t_PaymentIds.Count) := api.udt_object(t_UnPaymentId);

      t_PaymentIds.extend(1);
      t_PaymentIds(t_PaymentIds.Count) := api.udt_object(t_PaymentId);

      if t_SRVPaymentId is not null then
      t_PaymentIds.extend(1);
      t_PaymentIds(t_PaymentIds.Count) := api.udt_object(t_SRVPaymentId);
      end if;

    --Register Payment and Transaction Objects and set Payment details and rels.
    for w in 1..t_PaymentIds.count loop

      -- Get t_PaymentObjectId for the payment id
      select p.ObjectId
        into t_PaymentObjectId
        from table(cast(api.pkg_SimpleSearch.CastableObjectsByIndex('o_Payment',
                                                                    'PaymentId',
                                                                    t_PaymentIds(w).ObjectId) as api.udt_ObjectList)) p;
--TEst
         select x.objectid bulk collect into t_PayTransObjectIds
           from table(cast(api.pkg_simplesearch.CastableObjectsByIndex('o_PaymentTransactions', 'PaymentId', t_PaymentIds(w).objectid) as api.udt_objectlist ))x;

            --Copy Details from original Payment to created payment.
            --Get Details
            t_Reference := api.pkg_columnquery.Value(t_OrigPaymentObjId, 'PayeeReference');
            t_IsReceipted := api.pkg_columnquery.value(t_OrigPaymentObjId, 'IsReceipted');
            select r.PaymentMethodObjectId into t_MethodId
                   from query.r_PaymentPaymentMethod r
                   where r.PaymentObjectId = t_OrigPaymentObjId;
            t_ReceiptNumber   := api.pkg_columnquery.Value(t_OrigPaymentObjId, 'ReceiptNumber');
            t_BatchPaymentId  := api.pkg_columnquery.Value(t_OrigPaymentObjId, 'BatchPaymentId');

            --Set Details, create rel.
            api.pkg_paymentupdate.Modify(t_PaymentIds(w).objectid, t_Reference, t_ReceiptNumber);
            api.pkg_columnupdate.SetValue(t_PaymentObjectId, 'BatchPaymentId', t_BatchPaymentId);
            api.pkg_columnupdate.SetValue(t_PaymentObjectId, 'IsReceiptedStored', t_IsReceipted);

            t_RelId := api.pkg_RelationshipUpdate.New(api.pkg_ConfigQuery.EndPointIdForName('o_Payment',
                                                                                            'PaymentMethod'),
                                                  t_PaymentObjectId,
                                                  t_MethodId);


            --Create a relationship to the user's default office
            t_DefaultOfficeObjectId := api.pkg_columnquery.Value(api.pkg_securityquery.EffectiveUserId,
                                                                'DefaultOfficeObjectId');
            if t_DefaultOfficeObjectId is null then
              api.pkg_Errors.RaiseError(-20000, 'The User is not related to a Default Office.');
            end if;
            t_RelId := api.pkg_relationshipupdate.New(api.Pkg_Configquery.EndPointIdForName('o_Office',
                                                                                             'Payment'),
                                                  t_DefaultOfficeObjectId,
                                                  t_PaymentObjectId);

        --Set stored detail (see ProcessProposedPayment for explanation)
        api.pkg_columnupdate.SetValue(t_PaymentObjectId,
                                      'PaymentDateStored',
                                      trunc(sysdate));

        --Set stored detail (see ProcessProposedPayment for explanation)
        api.pkg_columnupdate.SetValue(t_PaymentObjectId,
                                      'PaymentAmountStored',
                                      api.pkg_columnquery.value(t_PaymentObjectId, 'PaymentAmount'));

      --Relate Payment to PaymentTransfer process using appropriate relationship (AdjustingFrom, To)
      --Also set Payment Statuses appropriately for first loop set ToPayment to earned
      --when feeschedule says it should be earned on payment.


        if t_DoneOnce is null --means this is the loop for the PaymentAdjustingFrom
          --Create Rel to process for PaymentAdjustingFrom
           then  t_EndPointId := api.pkg_configquery.EndPointIdForName('p_PaymentTransfer', 'PaymentAdjustingFrom');
                 t_RelId := api.pkg_relationshipupdate.New(t_EndPointId, a_ObjectId, t_PaymentObjectId);

          --Set the IsOverPayment on the Transactions to match previous transaction
           for q in 1..t_PTOrigObjList.count loop
                   --set details
                   api.pkg_columnupdate.SetValue(t_PayTransObjectIds(q),
                                                 'IsOverpayment',
                                                 api.pkg_columnquery.Value(t_PTOrigObjList(q), 'IsOverpayment'));
            end loop;
        --Create rel to process for PaymentTo
        else t_EndPointId := api.pkg_configquery.EndPointIdForName('p_PaymentTransfer', 'PaymentTo');
             t_RelId := api.pkg_relationshipupdate.New(t_EndPointId, a_ObjectId, t_PaymentObjectId);

           --Earned Payment Immediately if it should be.
           for m in 1..t_ToFeeId.count loop

                  select count(f.FeeId) into t_EarnedOnPay
                    from api.fees f
                    join table(cast(api.pkg_simplesearch.CastableObjectsByIndex('o_Fee','FeeId',f.feeid) as api.udt_objectlist)) x on 1=1
              -- join api.relationships r on r.FromObjectId = x.ObjectId
              -- and r.EndPointId = api.pkg_configquery.EndPointIdForName('o_Fee', 'LicenseFeeSchedule')
               join sitespecific.feeschedule_t fs on fs.objectid = sitespecific.pkg_fees.GetLicFeeSchedulObjId(f.feeid)
                    where f.FeeId = t_ToFeeId(m)
                      and api.pkg_columnquery.Value(fs.ObjectId, 'EarnedOn') = 'PAYMENT';
                --and api.pkg_columnquery.Value(r.ToObjectId, 'EarnedOn') = 'PAYMENT'

           --If Payment Transaction is overpayment, set flag to indicate it (used in Fees and Payments grid)
           sitespecific.pkg_fees.SetPaymentTransactionFlag(t_OVRToFeeId, t_OVRPayAmounts, 'IsOverpayment');

                --Create Payment Status for new payment if the fee's feeschedule is earned on payment.
            if t_EarnedOnPay > 0 then

               for v in (select x.objectid,
                                ft.Amount,
                                f.Amount+f.AdjustedAmount FeeAmount,
                                f.FeeId
                             from api.fees f
                             join api.feetransactions ft on ft.FeeId = f.FeeId
                             join api.paymenttransactions ipt on ipt.TransactionId = ft.TransactionId
                             join table(cast(api.pkg_simplesearch.CastableObjectsByIndex('o_PaymentTransactions', 'TransactionId', ipt.TransactionId) as api.udt_ObjectList)) x on 1=1
                             where f.feeid = t_ToFeeId(m)
                             and   ipt.PaymentId = t_PaymentIds(w).objectid
                             and   api.pkg_columnquery.value(x.objectid, 'IsOverpayment') = 'N') loop

                             --create object and rel
                             t_PaymentStatusObjId := api.pkg_objectupdate.New(t_PaymentStatusDefId);
                             t_RelId              := api.pkg_relationshipupdate.New(t_PaymentStatusEndPoint,
                                                                                    v.objectid,
                                                                                    t_PaymentStatusObjId);
                 -- Get the summed earned amounts for this transaction
                 select /*+ CARDINALITY (pt 1) */
                   nvl(abs(sum(api.pkg_ColumnQuery.NumericValue(r.PaymentStatusObjectId,'EarnedAmount'))),0)
                   into t_EarnedAmount
                   from api.FeeTransactions ft
                   join table(cast(api.pkg_SimpleSearch.CastableObjectsByIndex('o_PaymentTransactions',
                                                                               'TransactionId',
                                                                               ft.TransactionId)as api.udt_ObjectList)) pt on 1=1
                   join query.r_PaymentStatusPaymentTrans r on r.PaymentTransactionObjectId = pt.ObjectId
                  where ft.FeeId = v.FeeId;

                 -- if there is an unearned amount for the fee
                 if t_EarnedAmount < v.FeeAmount and t_TotalEarnedAmount > t_ToEarnAmount then
                   -- Get the correct amount to earn
                   if t_EarnedAmount-v.Amount > v.FeeAmount then
                     t_EarnedAmount := -v.FeeAmount+t_EarnedAmount;
                   else
                     t_EarnedAmount := v.Amount;
                   end if;
                   if t_EarnedAmount < (t_ToEarnAmount - t_TotalEarnedAmount) then
                     t_EarnedAmount := t_ToEarnAmount - t_TotalEarnedAmount;
                   end if;
                   t_TotalEarnedAmount := t_TotalEarnedAmount + t_EarnedAmount;
                   --set details
                   api.pkg_columnupdate.SetValue(t_PaymentStatusObjId,'Status','EARNED');
                   api.pkg_columnupdate.SetValue(t_PaymentStatusObjId,'StatusDate',trunc(sysdate));
                   api.pkg_columnupdate.SetValue(t_PaymentStatusObjId,'SystemGenerated', 'Y');
                   api.pkg_columnupdate.SetValue(t_PaymentStatusObjId,'EarnedAmount',t_EarnedAmount);
                 end if;
                   end loop;
                end if;
             end loop;
       end if;

        t_DoneOnce := 'Y';

    end loop;
    --Check the SRV charge flag on SRV Payment Transactions
    if t_SRVFeeIds.count > 0 then
    sitespecific.pkg_Fees.SetPaymentTransactionFlag(t_SRVFeeIds,
                                                    t_SRVAmounts,
                                                    'IsServiceCharge');
    -- Create Payment Statuses for all SRV values where the most recent SRV Fee Activity code is set to earn on payment.
    sitespecific.pkg_Refund.EarnSRVPayTrans(t_SRVFeeIds,
                                            t_SRVAmounts,
                                            true);
     end if;

 --  end if; --only run procedure when outcome is not null
  end TransferPayment;
end pkg_Michael;

/


GRANT EXECUTE ON SITESPECIFIC.PKG_MICHAEL TO CONV;

GRANT EXECUTE ON SITESPECIFIC.PKG_MICHAEL TO POSSEEXTENSIONS;
