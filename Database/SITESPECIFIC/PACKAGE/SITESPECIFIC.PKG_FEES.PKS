CREATE OR REPLACE PACKAGE SITESPECIFIC."PKG_FEES" is
-- ****************************************************************************
-- File:        PKG_FEES.PKS  
-- Author:      TREVOR.HAMM
--
-- $Rev: 322 $  
-- $Date: 2019-05-21 14:53:58 -0700 (Tue, 21 May 2019) $
-- Last Changed By:  $Author: PKaur $
--
-- Purpose : Online fee payment
--
-- History:
-------------------------------------------------------------------------------
--    Date         Ticket     Comment
--  01/21/2007 TH           Initial Package Created
--  07/03/2018 TJL          Header updated for checkin to SVN                                                          
--  03/29/2019 TJL  17566   Adding Tiers for Catering and Event Authorization    
-- 05/21/2019  PK  WO 18109 IPTR Fee Change                                                      
-------------------------------------------------------------------------------

  -- Purpose : Online fee payment

  -- Public type declarations
  subtype udt_id is api.pkg_definition.udt_Id;
  subtype udt_idlist is api.pkg_definition.udt_IdList;
  subtype udt_NumberList is api.pkg_Definition.udt_NumberList;
  subtype udt_ptdef is api.pkg_definition.udt_ProcessType;

  /*--------------------------------------------------------------------------
  * Initialize()
  * Sets up the Proposed Payment job by copying all the fees related to the
  * a_FromObjectId via the endpoint named 'Fee' and defaulting the AmountToPay
  * to the TotalOwing from the fee.
  *------------------------------------------------------------------------*/
  Procedure Initialize(a_ObjectId     udt_Id,
                       a_AsOfDate     date,
                       a_FromObjectId in out udt_Id);

  /*--------------------------------------------------------------------------
  * VoidPayment()
  * If a_IsVoidedFlag = 'N' and a_ReasonForVoid is not null, then this
  * procedure voids a_PaymentId
  *------------------------------------------------------------------------*/
  Procedure VoidPayment(a_ObjectId      udt_Id,
                        a_AsOfDate      date,
                        a_PaymentId     udt_Id,
                        a_IsVoidedFlag  varchar2,
                        a_ReasonForVoid varchar2,
                        a_DateVoided    date);
  ----------------------------------------------------------------------------------------------------
  -- PaymentsVoid()
  -- This will Void the payments related to the Void Payment process.
  ----------------------------------------------------------------------------------------------------
  procedure PaymentsVoid(a_ObjectId number, a_AsOfDate date);

  ----------------------------------------------------------------------------------------------------
  -- VoidBatchEntryObjects()
  -- This will Void the Batch Entry Objects of payments that are related to Payment Batches.
  ----------------------------------------------------------------------------------------------------

  procedure VoidBatchEntryObjects(a_ObjectId     number,
                                  a_AsOfDate     date,
                                  a_BatchId      number,
                                  a_HQReceiptNum varchar2);

  /*--------------------------------------------------------------------------
  * AdjustFee()
  * If a_AdjustAmountBy is not null and a_AdjustAmountBy is <> 0, this
  * procedure processes an adjustment on a_FeeId
  *------------------------------------------------------------------------*/
  /*Procedure AdjustFee(a_ObjectId udt_Id,
  a_AsOfDate date,
  a_FeeId udt_Id,
  a_AdjustAmountBy number,
  a_AdjustmentReason varchar2,
  a_AdjustmentDate date); */

  /*--------------------------------------------------------------------------
  * ProcessProposedPayment()
  * If a_CancelPaymentFlag = 'Y' then this cancels the proposed payment
  * If a_ProcessPaymentFalg = 'Y' then this turns a proposed payment into
  * an actual payment.
  *
  * NOTE:
  * If this is a manual payment, then upon completion of this procedure the
  * payment processing is complete.
  * If this is an ECom transaction, then this is just the first half.
  *------------------------------------------------------------------------*/
  Procedure ProcessProposedPayment(a_JobId              udt_Id,
                                   a_AsOfDate           date,
                                   a_TotalOwing         number,
                                   a_TotalPayment       number,
                                   a_ReceiptNumber      varchar2,
                                   a_PayeeReference     varchar2,
                                   a_PaymentDate        date,
                                   a_CancelPaymentFlag  varchar2,
                                   a_ProcessPaymentFlag varchar2);

  /*---------------------------------------------------------------------------
  * GetPaymentsForRefund()
  * Returns all of the payments related to the job refund process a_ObjectId
  * belongs to.
  *
  * NOTE:
  * This is expected to be run as a procedural relationship from POSSE
  *-------------------------------------------------------------------------*/
  /*
  procedure GetPaymentsForRefund (
  a_ObjectId udt_Id,
  a_EndPointId udt_Id,
  a_RelatedObjectIds out api.udt_ObjectList
  );
  */

  /*--------------------------------------------------------------------------
  * ProcessRefund()
  * Processes a refund for payment a_PaymentId, distributing a_Amount across
  * a_PaymentId's transaction evenly.
  *------------------------------------------------------------------------*/
  /* Procedure ProcessRefund(a_ProcessId udt_Id,
   a_AsOfDate date,
   a_Amount number,
   a_ReceiptNumber varchar2,
   a_PayeeReference varchar2,
   a_Reason varchar2,
   a_RefundDate date,
   a_PaymentId udt_Id);
  */

  /*--------------------------------------------------------------------------
  * NewFee()
  *------------------------------------------------------------------------*/
  procedure NewFee(a_FeeId       in out number,
                   a_Amount      number,
                   a_Description varchar2,
                   a_GLAccountId number,
                   a_JobId       number,
                   a_TaxRateId   number,
                   a_FeeObjId    out number,
                   a_Round       boolean default true);

  /*--------------------------------------------------------------------------
  * PreparRefund()
  * This routine prepares a refund for processing. This includes
  * a bunch of error checking.
  *------------------------------------------------------------------------*/
  -- Procedure PrepareRefund(a_ProcessId udt_Id, a_AsOfDate date);

  /*--------------------------------------------------------------------------
  * CreateMiscFees() - Public
  * This procedure is intended to run from the Create Misc Fee Process
  *------------------------------------------------------------------------*/
  Procedure CreateMiscFee(a_ProcessId     udt_Id,
                          a_AsOfDate      date,
                          a_JobId         udt_Id,
                          a_ObjectDefName varchar2);
  /*--------------------------------------------------------------------------
  * CalculateTax() - Public
  * This procedure is intended to run from the Create Misc Fee Jon
  * on the fees an payments Tab
  *------------------------------------------------------------------------*/

  Procedure CalculateTax(a_Objectid udt_id, a_asofDate Date);

  /*--------------------------------------------------------------------------
  * NewReceiptPayments()
  *------------------------------------------------------------------------*/
  procedure NewReceiptPayments(a_ObjectId udt_Id,
                               a_AsOfDate date,
                               a_JobId    udt_Id);

  /* ----------------------------------------------------------------------------------------------------
  -- SetReceiptNumOnPayment() -- PUBLIC
  -- On Constructor of the relationship between o_Payment and p_ReceiptPayments
  -- set the Receipt Number on Payment to the processid.
  ----------------------------------------------------------------------------------------------------
  Procedure SetReceiptNumOnPayment(
  a_ObjectId udt_id,
  a_AsOfDate date
  ); */

  ----------------------------------------------------------------
  -- SetReceiptNumberOnPayment() -- PUBLIC
  -- On completion of the Receipt Payments process, the receiptnumber is copied to the related payments
  -----------------------------------------------------------------
  Procedure SetReceiptNumOnPayment(a_ObjectId udt_id, a_AsOfDate date);

  ----------------------------------------------------------------------------------------------------
  -- RemReceiptNumFromPayment() -- PUBLIC
  -- Remove receipt number from payment.
  -- On Destructor of the relationship between o_Payment and p_ReceiptPayments
  -- set the receipt number on Payment to null.
  ----------------------------------------------------------------------------------------------------
  Procedure RemReceiptNumFromPayment(a_ObjectId udt_id, a_AsOfDate date);

  ----------------------------------------------------------------------------------------------------
  -- GenerateReceiptNumber() -- PUBLIC
  -- This is for generating the receipt number for a receipt document type on created of that object.
  ----------------------------------------------------------------------------------------------------
  procedure GenerateReceiptNumber(a_ObjectId udt_ID --,
                                  -- a_AsOfDate date
                                  );

  /*-------------------------------------------------------------------------------
  * Procedure CreateFeeSchedule() Used on creation of o_FeeSchedule.
  *-----------------------------------------------------------------------------*/

  procedure CreateFeeSchedule(a_ObjectId               in out number,
                              a_GallonageRange         varchar2,
                              a_NumberOfMonthsLicensed varchar2,
                              a_PopulationRange        varchar2,
                              a_PrimaryAmount          number,
                              a_SecondaryAmount        number,
                              a_Description            varchar2,
                              a_EffectiveDate          date,
                              a_BranchAmount           number,
                              a_FeeActivity            varchar2,
                              a_SurchargeCode          varchar2,
                              a_LicenseTypeCode        varchar2,
                              a_OtherFeeCode           varchar2,
                              a_Inactive               char default 'N',
                              a_FeeTier                VARCHAR2, -- 03/29/2019 TJL WO 17566
                              a_OriginalFee            NUMBER,
                              a_OriginalSecondaryFee   NUMBER);  -- 04/17/2019 TJL WO 17566 

  /*-------------------------------------------------------------------------------
  * Procedure ModifyFeeSchedule() Used on creation of o_FeeSchedule.
  *-----------------------------------------------------------------------------*/

  procedure ModifyFeeSchedule(a_ObjectId               in out number,
                              a_GallonageRange         varchar2,
                              a_NumberOfMonthsLicensed varchar2,
                              a_PopulationRange        varchar2,
                              a_PrimaryAmount          number,
                              a_SecondaryAmount        number,
                              a_Description            varchar2,
                              a_EffectiveDate          date,
                              a_BranchAmount           number,
                              a_FeeActivity            varchar2,
                              a_SurchargeCode          varchar2,
                              a_LicenseTypeCode        varchar2,
                              a_OtherFeeCode           varchar2,
                              a_Inactive               char default 'N',
                              a_FeeTier                VARCHAR2, -- 03/29/2019 TJL WO 17566
                              a_OriginalFee            NUMBER,
                              a_OriginalSecondaryFee   NUMBER);  -- 04/17/2019 TJL WO 17566 

  ----------------------------------------------------------------------------------------------------
  -- CreateSimpleFee() -- PUBLIC
  ----------------------------------------------------------------------------------------------------
  procedure CreateSimpleFee(a_ObjectId    number,
                            a_AsOfDate    date,
                            a_JobId       number,
                            a_FeeActivity varchar2,
                            a_Count       number,
                            a_LTCode      varchar2 default null,
                            a_PopRange    varchar2 default null);

  ----------------------------------------------------------------------------------------------------
  -- CreateAdjustSimpleFee() -- PUBLIC
  -- This is the same as CreateSimpleFee, except that if a fee with the desired Fee Activity already
  -- exists, that fee will be adjusted instead of the procedure creating a new one.
  ----------------------------------------------------------------------------------------------------
  procedure CreateAdjustSimpleFee(a_ObjectId    number,
                                  a_AsOfDate    date,
                                  a_JobId       number,
                                  a_FeeActivity varchar2,
                                  a_Count       number);

  ----------------------------------------------------------------------------------------------------
  -- CreateProcessPOICFee() -- PUBLIC
  -- Charges fee for Issue Temporary Permit Permit process
  ----------------------------------------------------------------------------------------------------
  procedure CreateProcessPOICFee(a_ObjectId udt_Id,
                                 a_AsOfDate date,
                                 a_JobId    number,
                                 a_POICFee  number,
                                 a_LTCode   varchar2,
                                 a_FeeId    out number);

  ----------------------------------------------------------------------------------------------------
  -- CreateRenewalFees() -- PUBLIC
  -- Called from Create Renewal/Penalty Fees process on License Type job, or from the License Batch (Batch types Send 1st
  -- Renewal Letter, 50% Penalty, 100% Penalty).
  -- RunType parameter should be B for batchtype (errors are not raised, unless a feeschedule record does not exists).
  -- For RunType B, ExpireLT is passed out Y when a REN100 fee is created.
  ----------------------------------------------------------------------------------------------------
  procedure CreateRenewalFees(a_ObjectId       number,
                              a_AsOfDate       date,
                              a_JobId          number,
                              a_ExpirationDate date,
                              a_RenPenFeeType  varchar2,
                              a_RunType        varchar2,
                              a_ExpireLT       out varchar2);

  ----------------------------------------------------------------------------------------------------
  -- CreateBatch1stRenewalFees() -- PUBLIC
  -- Charges fee for Issue Temporary Permit Permit process
  ----------------------------------------------------------------------------------------------------
  procedure CreateBatch1stRenewalFees(a_ObjectId number,
                                      a_AsOfDate date,
                                      a_JobId    number);

  ----------------------------------------------------------------------------------------------------
  -- CreateBatchPenaltyFees() --Public
  -- This will create fees on all Related LTs when the Assess 100% or Assess 50% process is completed
  ----------------------------------------------------------------------------------------------------
  Procedure CreateBatchPenaltyFees(a_ObjectId    udt_Id,
                                   a_AsOfDate    date,
                                   a_JobId       udt_Id,
                                   a_ObjectDefId udt_Id);

  /********************************************
  * Create Application Fees
  ********************************************/
  Procedure ApplicationFeeCalc(a_ObjectId udt_Id,
                               a_AsOfDate date,
                               a_JobId    udt_Id);

  /***********************************************************************************************
  ** FUNCTION SecLTCLicenseTypeCount(ProcessId, LTCId)
  ** This function is for returning the License Type Count of the Secondary License Type related
  ** to the License Type job related to the License of the Add Permit/License Type to License
  ** process. The variables that are passed in are the ProcessId and the License Type Category
  ** ObjectId.
  ***********************************************************************************************/
  function SecLTCLicenseTypeCount(a_ProcessId    udt_Id,
                                  a_LTCId        udt_Id,
                                  a_MasterLTCode varchar2) return number;

  /**************************************
  ** License Fee Calc
  **************************************/
  procedure LicenseFeeCalc(a_ObjectId udt_Id,
                           a_AsOfDate date,
                           a_JobId    udt_Id);

  /**************************************
  ** Check Existing Fees
  **************************************/

  procedure CheckExistingFees(a_AdjustToAmount         varchar2,
                              a_Description            varchar2,
                              a_AddRenFee              varchar2,
                              a_FeeActivity            varchar2,
                              a_OtherFeeCode           varchar2,
                              a_FeeAmount              number,
                              a_FeeScheduleId          udt_Id,
                              a_GallonageRange         varchar2,
                              a_GLAccountId            udt_Id,
                              a_HasSecondary           varchar2,
                              a_IsMaster               varchar2,
                              a_JobId                  udt_Id,
                              a_LicenseTypeCode        varchar2,
                              a_LicenseTypeCount       number,
                              a_NumberOfMonthsLicensed varchar2,
                              a_PopulationRange        varchar2,
                              a_tier                   VARCHAR2,  -- 03/29/2019 TJL  17566
                              a_SecondaryIds           varchar2,
                              a_CreateFee              OUT varchar2,
                              a_FeeId                  OUT number);

  /**************************************
  ** Check the LTs on the Job and charge fees for it
  **************************************/

  procedure GetLTFeeAmount(a_JobId                    udt_Id,
                           a_EffectiveDate            date,
                           a_FeeActivityType          varchar2,
                           a_OtherFeeCode             varchar2,
                           a_LTCode                   varchar2,
                           a_GallonageRange           varchar2,
                           a_AdditionalMillionGallons number,
                           a_NumberOfMonthsLicensed   varchar2,
                           a_PopulationRange          varchar2,
                           a_FeeType                  varchar2,
                           a_LTCount                  number,
                           a_AsOfDate                 date,
                           a_FeeAmount                OUT number,
                           a_LicenseFeeScheduleId     OUT udt_Id);

    PROCEDURE getltfeeamount(a_jobid            udt_id,
                             a_effectivedate    DATE,
                             a_feeactivitytype  VARCHAR2,
                             a_otherfeecode     VARCHAR2,
                             a_ltcode           VARCHAR2,
                             a_gallonagerange   VARCHAR2,
                             a_additionalmilliongallons NUMBER,
                             a_numberofmonthslicensed VARCHAR2,
                             a_populationrange  VARCHAR2,
                             a_tier             VARCHAR2, -- 03/29/2019 TJL  17566
                             a_feetype          VARCHAR2,
                             a_ltcount          NUMBER,
                             a_asofdate         DATE,
                             a_feeamount    OUT NUMBER,
                             a_licensefeescheduleid OUT udt_id);
                             
  function GetLTFeeAmount(a_EffectiveDate            date,
                          a_FeeActivityType          varchar2,
                          a_LTCode                   varchar2,
                          a_GallonageRange           varchar2,
                          a_AdditionalMillionGallons number,
                          a_NumberOfMonthsLicensed   varchar2,
                          a_PopulationRange          varchar2,
                          a_FeeType                  varchar2,
                          a_LTCount                  number) return number;

  /********************************************
  * Create One Day License Fees
  ********************************************/
  Procedure OneDayLicenseFeeCalc(a_ObjectId udt_Id,
                                 a_AsOfDate date,
                                 a_JobId    udt_Id);

  /********************************************
  * Create Priority Application Fees
  ********************************************/
  Procedure PriorityAppFeeCalc(a_ObjectId udt_Id,
                               a_AsOfDate date,
                               a_JobId    udt_Id);

  ----------------------------------------------------------------------------------------------------
  -- CreateIssueInterimPermitFee() -- PUBLIC
  -- Charges fee for Issue Interim Retail Permit process
  ----------------------------------------------------------------------------------------------------
  procedure CreateInterimPermitFee(a_ObjectId number,
                                   a_AsOfDate date,
                                   a_JobId    number);
  /* ------------------------------------------------
  --CreatePaymentStatus() -- PUBLIC
  --
  --Creates a new procedure which will create new
  --Payment Status objects with Earned values
  --for each payment transaction on a job which is
  --not yet earned. This runs
  --from the Issue License process type on both
  --the Application and the License jobs.
  --
  --
  ------------------------------------------------*/
  procedure CreatePaymentStatus(a_JobId udt_Id, a_AsOfDate date);

  /* ------------------------------------------------
  --CreateLTPaymentStatus() -- PUBLIC
  --
  --Creates a new procedure which will create new
  --Payment Status objects with Earned values
  --for each payment transaction on a job which is
  --not yet earned. This runs
  --from the Issue License process type on
  --the Application job.
  --
  --
  ------------------------------------------------*/
  procedure CreateLTPaymentStatus(a_ObjectId udt_Id, a_AsOfDate date);

  --------------------------------------------------------
  -- Create Manual Fee - Public
  -- Run from the Create Manual Fee process.
  --------------------------------------------------------
  procedure CreateManualFee(a_ObjectId number,
                            a_AsOfDate date,
                            a_JobId    number);

  --------------------------------------------------------
  -- RelatePaymentTransactions -PUBLIC
  -- Run on Constructor of Payment(From) to PaymentTransfer relationship
  -- Relate Payment Transactions objects to Payment Transfer process when Payment is related
  --------------------------------------------------------
  Procedure RelatePaymentTransactions(a_ObjectId number, a_AsOfDate date);

  --------------------------------------------------------
  -- Delete Payment Transactions
  -- Run on Destructor of Payment(From) to PaymentTransfer relationship
  -- Deletes Payment Transactions related to the Payment Transfer Process when the Related Payment is deleted
  --------------------------------------------------------
  Procedure DeletePaymentTransRel(a_ObjectId number, a_AsOfDate date);

  --------------------------------------------------------
  -- Transfer Payment
  -- To be run off the Transfer Payment process, the process adjusts fees.
  --------------------------------------------------------
  Procedure TransferPayment(a_ObjectId number, a_AsOfDate date);

  --------------------------------------------------------
  -- FingerPrintFee
  -- Runs off the Fingerprints column and creates Finger Print fees.
  --------------------------------------------------------
  procedure FingerPrintFee(a_ObjectId     udt_Id,
                           a_AsOfDate     date,
                           a_Fingerprints number,
                           a_JobId        udt_Id);

  --*------------------------------------------------------------------------------------------------
  --* GetFeesForJob() -- PUBLIC
  --* This procedure is for a procedural relationship that will relate Fees that are already related
  --* to this job (app or lic) and also relate the fees that are related to the related LT(s) and
  --* the other job, whatever that may be, App or Lic.
  --*------------------------------------------------------------------------------------------------
  procedure GetFeesForJob(a_ObjectId         udt_Id,
                          a_EndPointId       udt_Id,
                          a_RelatedObjectIds out api.udt_ObjectList);

  --*------------------------------------------------------------------------------------------------
  --* GetLicenseFSFeesForJob() -- PUBLIC
  --* This procedure is for a procedural relationship that will relate License Fee Schedule Fees
  --* (not Misc Fee Schedule fees) that are already related to this job (app or lic) and also relate
  --* the fees that are related to the related LT(s) and the other job, whatever that may be, App or
  --* Lic. It will also get the Fees from the related Accusation(s) and Investigation(s).
  --*------------------------------------------------------------------------------------------------
  procedure GetLicenseFSFeesForJob(a_ObjectId         udt_Id,
                                   a_EndPointId       udt_Id,
                                   a_RelatedObjectIds out api.udt_ObjectList);

  --*------------------------------------------------------------------------------------------------
  --* GetPaymentTransactionsForJob() -- PUBLIC
  --* This procedure is for a procedural relationship that will relate Payment Transactions that are
  --* already related to this job (app or lic) and also relate the PTs that are related to the
  --* related LT(s) and the other job, whatever that may be, App or Lic.
  --*------------------------------------------------------------------------------------------------
  procedure GetPaymentTransactionsForJob(a_ObjectId         udt_Id,
                                         a_EndPointId       udt_Id,
                                         a_RelatedObjectIds out api.udt_ObjectList);

  --*------------------------------------------------------------------------------------------------
  --* GetPaymentsForJob() -- PUBLIC
  --* This procedure is for a procedural relationship that will relate Payments that are
  --* already related to this job (app or lic) and also relate the Payments that are related to the
  --* related LT(s) and the other job, whatever that may be, App or Lic.
  --*------------------------------------------------------------------------------------------------
  procedure GetPaymentsForJob(a_ObjectId         udt_Id,
                              a_EndPointId       udt_Id,
                              a_RelatedObjectIds out api.udt_ObjectList);

  ----------------------------------------------------------------------------------------------------
  -- CreateCatererEventFee() -- PUBLIC
  -- Run on completion of Issue Caterer/Event Authorization process
  --
  ----------------------------------------------------------------------------------------------------
  procedure CreateCatererEventFee(a_ObjectId    udt_Id,
                                  a_AsOfDate    date,
                                  a_JobId       udt_Id,
                                  a_FeeActivity varchar2);

  -------------------------------------------------------------
  --CalculateOverpayment - PUBLIC
  --This procedure will take an array of feeids and amountstopay and, in the case of an overpayment,
  --will reduce the original amounttopay to equal the totalowing, while adding an additional feeid and amounttopay
  --for the overpayment.
  -------------------------------------------------------------
  procedure CalculateOverpayment(a_FeeIds          in out udt_idlist,
                                 a_AmountsToPay    in out udt_numberlist,
                                 a_OVRFeeIds       in out udt_idlist,
                                 a_OVRAmountsToPay in out udt_numberlist);

  -------------------------------------------------
  -- SetOverrideFlag -PUBLIC
  -- Takes array of FeeIds and Amounts and marks flag (passed in ColumnName) on max(PaymentTransactions.objectid) with that same feeid and amount.
  -------------------------------------------------
  procedure SetPaymentTransactionFlag(a_OVRFeeIds       udt_idlist,
                                      a_OVRAmountsToPay udt_numberlist,
                                      a_ColumnName      varchar2,
                                      a_Refund          boolean default False);

  ------------------------------
  -- Process Receive Payment() - PUBLIC
  -- This inserts and completes the Receive Payment process on the License Type job
  -- when a payment is created (the process is created in the ProcessProposedPayment()
  -- procedure). It will have one of two outcomes: Partial Payment, when the job balance
  -- is greater than the IssueTolerance user constant; and Full Payment, when the job
  -- balance is less than or equal to the IssueTolerance constant. The Full Payment
  -- outcome also updates the Include in Batch flags on the LT so that only Include In
  -- Produce License Batch flag is checked.
  ------------------------------

  procedure ProcessReceivePayment(a_JobId udt_Id);

  ---------------------------------------
  -- ProcessNegativePayment()
  -- This takes negative payments from transfers, dishonors,
  -- voids, and refunds, and updateds the R2I date and
  -- batch flags on LTs
  ---------------------------------------

  procedure ProcessNegativePayment(a_PaymentId udt_Id default null,
                                   a_FeeId     udt_Id default null,
                                   a_JobId     udt_Id default null);
  function ProcessNPFunction(a_FeeId udt_Id, a_JobId udt_Id) return number;

  ------------------------------------------------
  -- ModifyFee()
  ------------------------------------------------

  Procedure ModifyFee(a_ObjectId         udt_id,
                      a_AsOfDate         date,
                      a_ModifyType       Varchar2,
                      a_IsLicFeeSchedule varchar2);
  ------------------------------------------------------------
  -- SetPaymentMethod()
  -- This will run on change of the Payment Method
  ------------------------------------------------------------
  procedure SetPaymentMethod(a_ObjectId          udt_Id,
                             a_AsOfDate          date,
                             a_PaymentMethodCode varchar2,
                             a_PaymentId         udt_Id);

  ----------------------------------------------------------
  -- UpdatePayMethodRel()
  -- This procedure updates the Payment Method relationship on a Payment.
  -- This is separated out into another procedure to prevent
  -- duplication because this code is called so many times.
  ----------------------------------------------------------
  procedure UpdatePayMethodRel(a_ObjectId udt_Id, a_Code varchar2);

  ------------------------------------------------------------
  -- SetPayeeReference()
  -- This will run on change of PayeeReference
  ------------------------------------------------------------
  procedure SetPayeeReference(a_PaymentId      udt_Id,
                              a_PayeeReference varchar2,
                              a_ReceiptNumber  varchar2);

  procedure UpdateTransToPayment(a_PaymentId      udt_Id,
                                 a_PayeeReference varchar2 default null,
                                 a_ReceiptNumber  varchar2 default null,
                                 a_PaymentMethod  varchar2 default null);

  Procedure UpdateTransFromPayment(a_PaymentId      udt_Id,
                                   a_PayeeReference varchar2 default null,
                                   a_ReceiptNumber  varchar2 default null,
                                   a_PaymentMethod  varchar2 default null);
  ------------------------------------------------
  -- GetLicFeeScheduleObjId()
  -- This Function will return the License Fee Schedule ObjectId for a FeeId passed it.
  -- This Function is used in the Accounting History Report and The Renewal List's
  -- Financial section.
  ------------------------------------------------


  Function GetLicFeeSchedulObjId(a_FeeId udt_id) return udt_id;

  Function GetMiscFeeSchedulObjId(a_FeeId udt_id) return udt_id;
     ----------------------------------------------------------------------------------------------------
  -- CreateIssueInterimPermitRenewalFee() -- PUBLIC
  -- Charges fee for Issue Interim Retail Permit Renewal process
  ----------------------------------------------------------------------------------------------------
  procedure CreateInterimPermitRenewalFee(a_ObjectId number,
                                          a_AsOfDate date,
                                          a_JobId    number);
end PKG_FEES;
/


GRANT EXECUTE ON SITESPECIFIC.PKG_FEES TO ABC;

GRANT EXECUTE ON SITESPECIFIC.PKG_FEES TO ABCREPORTS;

GRANT EXECUTE, DEBUG ON SITESPECIFIC.PKG_FEES TO BIZMOD_API;

GRANT EXECUTE ON SITESPECIFIC.PKG_FEES TO CONV;

GRANT EXECUTE ON SITESPECIFIC.PKG_FEES TO LASSO;

GRANT EXECUTE ON SITESPECIFIC.PKG_FEES TO POSSEEXTENSIONS;
