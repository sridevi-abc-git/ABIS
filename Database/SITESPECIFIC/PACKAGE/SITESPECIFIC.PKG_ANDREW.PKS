CREATE OR REPLACE package SITESPECIFIC.pkg_Andrew as

  -- Public type declarations

  subtype udt_idlist is api.pkg_definition.udt_IdList;
  subtype udt_NumberList is api.pkg_Definition.udt_NumberList;
  subtype udt_ptdef is api.pkg_definition.udt_ProcessType;
  /*---------------------------------------------------------------------------
  * Types
  *-------------------------------------------------------------------------*/
  subtype udt_Id is api.pkg_Definition.udt_Id;
  /*
  --*------------------------------------------------------------------------------------------------
  --* SetFeeRelToResearchRefundsProc() -- PUBLIC
  --* This procedure relates the Research Refunds process to fees that are related to the job that it
  --* is on.  This relationship is set when the TotalOwing Dynamic Detail is < 0.  If the job that
  --* this process is on is a License the procedure will also relate fees on related License Types
  --*that also meet the TotalOwing criteria.
  --*------------------------------------------------------------------------------------------------

  */
  procedure SetFeeRelToResearchRefundsProc(a_ObjectId udt_Id,
                                           a_AsOfDate Date,
                                           a_JobId    udt_id);

  --*-------------------------------------------------------------------------------------------------
  --* SetDepositRelationships() -- PUBLIC
  --* This procedure relates the Transmittal job and the Payment Batch job to the Deposit job
  --* when the Transmittal and Payment Batch jobs are not currently related to a Deposit job
  --* and when the Transmittal and Payment Batch jobs are in the Complete status.
  --*------------------------------------------------------------------------------------------------
  procedure SetDepositRelationships(a_ObjectId udt_Id, a_AsOfDate Date);

  /*  ------------------------------------------------
  --CreatePaymentStatus() -- PUBLIC
  --
  --Creates a new procedure which will create new
  --Payment Status objects with Earned values
  --for each payment transaction on a job which is
  --not yet earned.  This procedure runs from the
  --Issue License process type on both the
  --Application and the License jobs.
  --
  --
  ------------------------------------------------*/
  procedure CreatePaymentStatus(a_JobId udt_Id, a_AsOfDate date);

  /*  -----------------------------------------------------------------------
  --CreateRecPOICPaymentProcess() -- PUBLIC
  --On an Accusation job, when all the POIC fees have been paid in full
  --(no amount due remaining), the system creates and completes the
  --?Receive POIC Payment? process type.  It also checks the balance of the
  --POIC fees and conditionally creates the ?Receive POIC Payment? process.
  --Is called Process Proposed Payment procedure only if the job type is
  --an Accusation.
  ---------------------------------------------------------------------*/
  procedure CreateRecPOICPaymentProcess(a_JobId    udt_Id,
                                        a_AsOfDate date,
                                        a_FeeIds   udt_IdList);

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

  /*  ------------------------------------------------
  *  TerminateLicense() -- PUBLIC
  *
  *  Creates a new procedure which will create new
  *  Payment Status objects with Earned values
  *  for each payment transaction on a job which is
  *  not yet earned.  This procedure runs from the
  *  Issue License process type on both the
  *  Application and the License jobs.
     -----------------------------------------------*/
  procedure TerminateLicense(a_ProcessId udt_Id, a_AsOfDate date);

  /***********************************************************************************************
  ** FUNCTION FeeEarnedSummaryMessage
  **
  **
  **
  **
  ***********************************************************************************************/
  function FeeEarnedSummaryMessage(a_JobId                  udt_Id,
                                   a_LicenseTypeCode        varchar2,
                                   a_IsMaster               varchar2,
                                   a_SecondaryCount         number,
                                   a_JobTypeId              udt_Id)
    return number;

  --*------------------------------------------------------------------------------------------------
  --* GetFeesForJob() -- PUBLIC
  --* This procedure is for a procedural relationship that will relate Fees that are already related
  --*  to this job (app or lic) and also relate the fees that are related to the related LT(s) and
  --* the other job, whatever that may be, App or Lic.
  --*------------------------------------------------------------------------------------------------
  procedure GetFeesForJob(a_ObjectId              udt_Id,
                          a_EndPointId            udt_Id,
                          a_RelatedObjectIds  out api.udt_ObjectList);

  --*------------------------------------------------------------------------------------------------
  --* GetPaymentTransactionsForJob() -- PUBLIC
  --* This procedure is for a procedural relationship that will relate Payment Transactions that are
  --* already related to this job (app or lic) and also relate the PTs that are related to the
  --* related LT(s) and the other job, whatever that may be, App or Lic.
  --*------------------------------------------------------------------------------------------------
  procedure GetPaymentTransactionsForJob(a_ObjectId              udt_Id,
                                         a_EndPointId            udt_Id,
                                         a_RelatedObjectIds  out api.udt_ObjectList);


  --*------------------------------------------------------------------------------------------------
  --* GetPaymentsForJob() -- PUBLIC
  --* This procedure is for a procedural relationship that will relate Payments that are
  --* already related to this job (app or lic) and also relate the Payments that are related to the
  --* related LT(s) and the other job, whatever that may be, App or Lic.
  --*------------------------------------------------------------------------------------------------
  procedure GetPaymentsForJob(a_ObjectId              udt_Id,
                              a_EndPointId            udt_Id,
                              a_RelatedObjectIds  out api.udt_ObjectList);

----------------------------------------------------------------------------------------------------
--  FindLicAndAppAccHistory() -- PUBLIC
--  Used by Outrider to Search for Licenses and Application (under label License)
--  Procedure limits based off of dynamic detail IncludeInAccHistorySearch on Application.
----------------------------------------------------------------------------------------------------
  Procedure FindLicAndAppAccHistory(a_ExternalFileNum varchar2,
                            a_Objects           out nocopy api.udt_ObjectList);


----------------------------------------------------------------------------------------------------
--  CreateCatererEventFee() -- PUBLIC
--  Run on completion of Issue Caterer/Event Authorization process
--
----------------------------------------------------------------------------------------------------
procedure CreateCatererEventFee(a_ObjectId    udt_Id,
                                a_AsOfDate    date,
                                a_JobId       udt_Id,
                                a_FeeActivity varchar2);

  --------------------------------------------------------
  -- Relate LT to Object
  -- Used to relate License Types to BatchPaymentEntry and Additional Item objects in the Payment Batch job.
-- Only does this for P-12 Renewals and Individual Renewal Fees (IR).
  --------------------------------------------------------
   procedure RelateLTToObject(a_ObjectId                  number,
                              a_AsOfDate                    date);

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
procedure WinegrowersCompletion(a_ObjectId       udt_Id,
                                a_AsofDate       date);


  --------------------------------------------------------
  -- CreateWinegrowerFees() -- PUBLIC
  -- Called by sitespecific.pkg_##**##**.WinegrowersCompletion
  -- Create a fee (transaction code AWF) for the amount passed in.
  --------------------------------------------------------

procedure CreateWinegrowerFees(a_ObjectId         udt_Id,
                               a_AsofDate         date,
                               a_JobId            udt_Id,
                               a_FeeAmount        number,
                               a_LTCode           varchar2,
                               a_GalRange         varchar2,
                               a_FeeSchedObjId    OUT number,
                               a_FeeId            OUT number,
                               a_FeeObjId         OUT number);

/*-------------------------------------------------------------------------
  * SetBranchDetail() - Public
  * This procedure is used to set details on the Branch LTs based off their
  * Master LT
  *------------------------------------------------------------------------*/

procedure SetBranchDetail(a_Objectid                    udt_id,
                          a_AsofDate                    date,
                          a_SourceColumnName            varchar2,
                          a_TargetColumnName            varchar2);

----------------------------------------------------------------------------------------------------
--  AccountingHistoryReport() -- PUBLIC
--
--
----------------------------------------------------------------------------------------------------
procedure AccountingHistoryReport(a_JobId    udt_Id);


/*-------------------------------------------------------------------------
  * AccountingHistoryReportNew() - Public
  *
  *
  *------------------------------------------------------------------------*/

procedure AccountingHistoryReportNew(a_ObjectId   udt_id);

  --*------------------------------------------------------------------------------------------------
  --* GetPayTransForAccHist() -- PUBLIC
  --*
  --*------------------------------------------------------------------------------------------------
  procedure GetPayTransForAccHist(a_ObjectId              udt_Id,
                                         a_EndPointId            udt_Id,
                                         a_RelatedObjectIds  out api.udt_ObjectList);

------------------------------------------------
-- GetLicFeeScheduleObjId()
-- This Function will return the License Fee Schedule ObjectId for a FeeId passed it.
-- This Function is used in the Accounting History Report and The Renewal List's
-- Financial section.
------------------------------------------------
  Function GetLicFeeSchedulObjId(a_FeeId udt_id)
  return udt_id;


end pkg_Andrew;

 
/
