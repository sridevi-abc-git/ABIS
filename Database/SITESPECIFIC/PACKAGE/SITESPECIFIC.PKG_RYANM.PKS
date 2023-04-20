CREATE OR REPLACE package SITESPECIFIC.PKG_RYANM is

  -- Private type declarations
  subtype udt_ID is api.pkg_Definition.udt_ID;
  subtype udt_IdList is api.pkg_definition.udt_IdList;
  subtype udt_ObjectList is api.udt_ObjectList;
  subtype udt_NumberList is api.pkg_Definition.udt_NumberList;


 ---------------------------------------------------------
  --  FindUserOffices() -- PUBLIC
  --  Used by FindABC19MonthlyHeader and FindUserProcesses
  ---------------------------------------------------------

  Procedure FindUserOffices(a_UserId            udt_Id,
                            a_ValidOfficeIdList in out udt_IdList);

/*-------------------------------------------------------------------------------
 * Procedure FindABC19MonthlyTotal()
 *-----------------------------------------------------------------------------*/
 Procedure FindABC19MonthlyHeader (
                a_dup_Month                              number,
                a_Year                                   number,
                a_dup_DistrictOffice                     varchar2,
                a_Objects                out api.udt_ObjectList);

   /*-------------------------------------------------------------------------------
   * Procedure FindUserProcesses()
   *   Purpose: This procedure will return a list of incompleted processes assigned to
   *            a current login user for the purpose of filling a To-Do-List. You have
   *            the option of either displaying current processes(i.e. the scheduledstartdate
   *            is null or it is less than the sysdate) or all processes.
   *-----------------------------------------------------------------------------*/
  Procedure FindUserProcesses(
                a_User                   varchar2,
                a_ProcessType            varchar2,
                a_Investigations         varchar2,
                a_JobExternalFileNum     varchar2,
                a_DateCompletedFrom      date,
                a_DateCompletedTo        date,
                a_RelatedObjectIds	 out nocopy api.udt_ObjectList
                );


  procedure LEAuditDestructor (
    a_ObjectId                  udt_Id,
    a_AsOfDate                  date
  );

  procedure TestPostVerify (
    a_ObjectId                  udt_Id,
    a_AsOfDate                  date
  );
   /*
  ----------------------------------------------------------------------------------------------------
--  CreateIssueInterimPermitFee() -- PUBLIC
--  Charges fee for Issue Interim Retail Permit process
----------------------------------------------------------------------------------------------------
 procedure CreateInterimPermitFee(a_ObjectId       number,
                                       a_AsOfDate         date,
                                       a_JobId          number);

----------------------------------------------------------------------------------------------------
--  CreateIssuePrivateWHouseFee() -- PUBLIC
--  Charges fee for Issue Private Warhouse Permit process
----------------------------------------------------------------------------------------------------
 procedure CreatePrivateWhousePermitFee(a_ObjectId       number,
                                       a_AsOfDate         date,
                                       a_JobId          number);

----------------------------------------------------------------------------------------------------
--  CreateIssueTemporaryPermitFee() -- PUBLIC
--  Charges fee for Issue Temporary Permit Permit process
----------------------------------------------------------------------------------------------------
 procedure CreateTempPermitFee(a_ObjectId       number,
                                       a_AsOfDate         date,
                                       a_JobId          number);


----------------------------------------------------------------------------------------------------
--  CreateProcessPOICFee() -- PUBLIC
--  Charges fee for Issue Temporary Permit Permit process
----------------------------------------------------------------------------------------------------
 procedure CreateProcessPOICFee(a_ObjectId       number,
                                a_AsOfDate         date,
                                a_JobId          number,
                                a_POICFee     number);

----------------------------------------------------------------------------------------------------
--  CreateRenewalFees() -- PUBLIC
--  Charges fee for Issue Temporary Permit Permit process
----------------------------------------------------------------------------------------------------
 procedure CreateRenewalFees(a_ObjectId                    number,
                             a_AsOfDate                      date,
                             a_JobId                       number,
                             a_Renewal                   varchar2,
                             a_FiftyPercentPenalty       varchar2,
                             a_OneHundredPercentPenalty  varchar2);


----------------------------------------------------------------------------------------------------
--  CreateBatch1stRenewalFees() -- PUBLIC
--  Charges fee for Issue Temporary Permit Permit process
----------------------------------------------------------------------------------------------------
 procedure CreateBatch1stRenewalFees(a_ObjectId                    number,
                                   a_AsOfDate                      date,
                                   a_JobId                       number);


*/

--------------------------------------------------------
-- Create Misc Fee

--------------------------------------------------------
 procedure CreateManualFee(a_ObjectId                  number,
                         a_AsOfDate                    date,
                         a_JobId                     number);


--------------------------------------------------------
-- FindJobPayment

--------------------------------------------------------
  Procedure FindJobPayment(a_dup_SimpleJobId             number,
                           a_PaymentDate         date,
                           a_PaymentDateUpper    date,
                           a_dup_ReceiptNumber     varchar2,
                           a_BatchId         varchar2,
                           a_Objects          out nocopy api.udt_ObjectList);

--------------------------------------------------------
-- Relate Payment Transactions

--------------------------------------------------------
  Procedure RelatePaymentTransactions(a_ObjectId    number,
                                      a_AsOfDate          date);

--------------------------------------------------------
-- Delete Payment Transactions

--------------------------------------------------------
  Procedure DeletePaymentTransRel(a_ObjectId    number,
                                      a_AsOfDate          date);

 --------------------------------------------------------
-- Transfer Payment
-- to be run off the Transfer Payment process
--------------------------------------------------------
  Procedure TransferPayment(a_ObjectId        number,
                          a_AsOfDate          date);

     ----------------------------------------------------------------------------------------------------
    --  CreateRenewalFees() -- PUBLIC
    --
    ----------------------------------------------------------------------------------------------------
    procedure CreateRenewalFees(a_ObjectId                 number,
                                a_AsOfDate                 date,
                                a_JobId                    number,
                                a_ExpirationDate           date,
                                a_RenPenFeeType            varchar2,
                                a_RunType                  varchar2,
                                a_ExpireLT            out  varchar2);

     procedure CreateBatch1stRenewalFees(a_ObjectId number,
                                      a_AsOfDate date,
                                      a_JobId    number);

    Procedure CreateBatchPenaltyFee(a_ProcessId     udt_Id,
                                  a_AsOfDate      date,
                                  a_JobId         udt_Id,
                                  a_DateCompleted date,
                                  a_ObjectDefId   udt_Id);

  Procedure FindLicenseAndApplication(a_ExternalFileNum varchar2,
                            a_RegNumber         varchar2,
                            a_LicenseeNames    varchar2,
                            a_PremAddressLine1  varchar2,
                            a_PremUSCity        varchar2,
                            a_PremZipCode       varchar2,
                            a_dup_DBAs              varchar2,
                            a_CreatedDate       date,
                            a_CreatedDateUpper  date,
                            a_Status            varchar2,
                            a_Objects           out nocopy api.udt_ObjectList);


  --------------------------------------------------------
  -- Relate LT to Object
  -- Used to relate License Types to BatchPaymentEntry and Additional Item objects in the Payment Batch job.
-- Only does this for P-12 Renewals and Individual Renewal Fees (IR).
  --------------------------------------------------------
   procedure RelateLTToObject(a_ObjectId                  number,
                              a_AsOfDate                    date);


   procedure CompletePaymentBatchProcess(a_ObjectId                  number,
                                         a_AsOfDate                    date);


  --------------------------------------------------------
  -- POICCompletion - public
  -- Run from payment batch for POIC payments
  --------------------------------------------------------
   procedure POICCompletion(a_ObjectId                  number,
                            a_AsOfDate                    date,
                            a_JobId                     number);


     --------------------------------------------------------
  -- Set Amounts for FeeIdArray - public
  -- Called from Payment Batch completion procedures to take a array of FeeIds, and give a corresponding payment amount for each,
  -- based on a passed-in total PaidAmount.
  --------------------------------------------------------
  procedure SetAmountsForFeeIds(a_FeeIds        udt_IdList,
                                a_PaidAmount        number,
                                a_AmountsToPay  in out udt_numberlist,
                                a_FinalFeeIds   in out udt_IdList);


  --------------------------------------------------------
  -- IRCompletion - public
  -- Run from payment batch for IR and P-12 payments, this will create and pay appropriate REN fees.
  -- When a LicenseType has prior REN fees of a previous variety to the Payment Batch's Penalty field,
  -- only the most recent will be updated.  All of them will be considered for payment
  -- (those owing are paid and the most recent fee gets the overpayment)
  --------------------------------------------------------
procedure IRP12Completion(a_ObjectId       udt_Id,
                          a_AsofDate       date,
                          a_JobId          udt_Id);

-------------------------------------------------------------------
  -- GetRENFeeIdsAndAmounts  - PUBLIC
  -- When a LicenseType has prior REN fees of a previous variety to the Payment Batch's Penalty field,
  -- only the most recent will be updated to the Penalty REN Type.  All of them will be considered for payment
  -- (those owing are paid and the most recent fee gets the overpayment)
-------------------------------------------------------------------
procedure GetRENFeeIdsAndAmounts(a_PaidAmount          number,
                                 a_LTCode              varchar2,
                                 a_LTObjectid          number,
                                 a_LTExpirationDate    date,
                                 a_RenType             varchar2,
                                 a_FinalFeeIds  in out udt_idlist,
                                 a_AmountsToPay in out udt_numberlist
                                 );

-------------------------------------------------------------------
  -- GetPOICFeeIdsAndAmounts  - PUBLIC
  -- POIC fees owing are paid and the most recent fee gets the overpayment.
-------------------------------------------------------------------
procedure GetPOICFeeIdsAndAmounts(a_PaidAmount          number,
                                  a_AccusationJobId     number,
                                  a_FinalFeeIds  in out udt_idlist,
                                  a_AmountsToPay in out udt_numberlist
                                 );

-------------------------------------------------------------
  --CalculateOverpayment - PUBLIC
  --This procedure will take an array of feeids and amountstopay and, in the case of an overpayment,
  --will reduce the original amounttopay to equal the totalowing, while adding an additional feeid and amounttopay
  --for the overpayment.
-------------------------------------------------------------
  procedure CalculateOverpayment (a_FeeIds       in out  udt_idlist,
                                  a_AmountsToPay in out  udt_numberlist,
                                  a_OVRFeeIds       in out  udt_idlist,
                                  a_OVRAmountsToPay in out  udt_numberlist);

end PKG_RYANM;

 
/
