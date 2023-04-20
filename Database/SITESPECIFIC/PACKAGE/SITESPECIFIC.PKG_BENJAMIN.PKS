CREATE OR REPLACE package SITESPECIFIC.pkg_Benjamin as

  type VAR is varray(100) of number(1);
  subtype udt_idlist is api.pkg_definition.udt_IdList;
  subtype udt_NumberList is api.pkg_Definition.udt_NumberList;
  subtype udt_EndPoint is api.pkg_Definition.udt_EndPoint;
  subtype udt_ObjectList is api.udt_ObjectList;


  -- Public type declarations
  /*
  subtype udt_id is api.pkg_definition.udt_Id;
  subtype udt_idlist is api.pkg_definition.udt_IdList;
  subtype udt_NumberList is api.pkg_Definition.udt_NumberList;
  subtype udt_ptdef is api.pkg_definition.udt_ProcessType;*/

  /*---------------------------------------------------------------------------
  * Types
  *-------------------------------------------------------------------------*/
  subtype udt_Id is api.pkg_Definition.udt_Id;
  type t_number is table of number;
  Type t_Jobid is table of udt_id;


   /*----------------------------------------------------------
   * SetDefaultOffice()     --Public
   *---------------------------------------------------------*/

    Procedure SetDefaultOffice(a_ObjectId                    udt_Id,
                               a_AsOfDate                    date);


 ----------------------------------------------------------------------------------------------------
  --  GetBatchPenaltyCandidates()     --Public
  --  This get LT's and relate them to the to the License Batch job as Candidates for the REN50 and REN100 Types
  ----------------------------------------------------------------------------------------------------

  Procedure GetBatchPenaltyCandidates(a_JobId         udt_Id,
                                      a_AsOfDate      date,
                                      a_ExpirationDate date,
                                      a_REN50orREN100   Varchar2);



  ------------------------------
  -- Process Less Than Zero Balance ()
  -- PUBLIC
  ------------------------------

  procedure RevenueAndMiscStats(a_Year  number);


---------------------------------------------------------------
-- PaymentSearch() -- current version is in pkg_ABCSearch
-- this procedure will find payments made.
---------------------------------------------------------------

  Procedure PaymentSearch(a_PayeeReference varchar2,
                           a_PaymentDate    date,
                           a_PaymentDateUpper date,
                           a_PayeeName      varchar2,
                           a_PayeeAddress   varchar2,
                           a_LicenseNumber  varchar2,
                           a_ReceiptNumber  varchar2,
                           a_DepositNumber  number,
                           a_Objects   out nocopy api.udt_ObjectList) ;


/*Assign Office Staff to Process.
  Input the Office id Column name from the job.*/
 procedure AssignOfficeStaff(a_ObjectId          number,
                             a_AsOfDate          date,
                             a_OfficeIdColumnName varchar2);

----------------------------------------------------------------------------------------------------
--  SetExpMonthYear() -- this is now in pkg_LicenseType
-- Using parameter of application objectid
-- Set the ExpirationMonth and ExpirationYear using Primary License Type object data if exists.
----------------------------------------------------------------------------------------------------
  procedure SetExpMonthYear (
      a_ObjectId       udt_id,
      a_AsOfDate       date,
      a_PriLicTypeId   Udt_id,
      a_JobId          udt_id
   );

----------------------------------------------------------------------------------------------------
--  EarnPaymentTransactions() -- in pkg_refund
-- creates an Earned Payment Status for every Fee Id passed in.
----------------------------------------------------------------------------------------------------
  procedure EarnSRVPayTrans(
       a_EarnFeeIds   udt_idlist,
       a_AmountsToPay udt_numberlist);

------------------------------------------------
-- ModifyFeezzz()
------------------------------------------------

  Procedure ModifyFeezzz(
    a_ObjectId   udt_id,
    a_AsOfDate   date,
    a_ModifyType Varchar2,
    a_IsLicFeeSchedule varchar2);

--Pink and Green Report Procedure.
procedure zzzGreenPinkLicense (a_objectid udt_id);

Procedure zzzPrintLicenseBatch (a_objectid udt_id);

Procedure zzzProduceLicenseManual (a_Objectid udt_id);

----------------------------------------------------------------------------------------------------
--  () -- PUBLIC
--
--
----------------------------------------------------------------------------------------------------


procedure zzzActivatePendingSecondaryLTs(
  a_ProcessId         udt_Id,
  a_AsOfDate          date,
  a_JobId             udt_Id
    );

   /*---------------------------------------------------------------------------
  * CreateLineItemObject() -- PUBLIC
  * this will create Batch Payment Entry Objects for the Payment Batch Job based
  * on the Line Item Count and payment # From and # To
  * it will also throw in a GroupID if it is a P-12
  *-------------------------------------------------------------------------*/

  procedure zzzCreateLineItem (a_JobId udt_id, a_AsOfDate date);

/*---------------------------------------------------------------------------
  * UniqueHQReceiptError() -- PUBLIC
  * This procedure run on Column Change of HQ Receipt(PaymentNumber) will raise an error if this value
  * value has been used before. More info regarding the blocking Job(s) will be placed in the debug log.
  *-------------------------------------------------------------------------*/
  procedure zzzUniqueHQReceiptError(
    a_Objectid udt_id,
		a_AsOfDate date,
    a_PaymentNumberFrom Varchar2,
    a_PaymentNumberTo Varchar2,
    a_FromOrTo          Varchar2
  );

  /*---------------------------------------------------------------------------
  * FindDishonorPayments() -- PUBLIC
  * This procedures is used to find the Dishonor Payment(s) Jobs within the search procedure.
  *-------------------------------------------------------------------------*/
  Procedure FindDishonorPayments(
    a_ExternalFileNum  varchar2,
    a_BatchDate        date,
    a_BatchDateUpper   date,
    a_CreatedDate      date,
    a_CreatedDateUpper date,
    a_CompletedDate    date,
    a_CompletedDateUpper date,
	  a_Status           varchar2,
    a_Objects          out nocopy api.udt_ObjectList
  );

  --*------------------------------------------------------------------------------------------------
  --* Cancel Dishonor Payment(s) Job
  --*------------------------------------------------------------------------------------------------
  procedure CancelDishonorJob (
	  a_ObjectId udt_Id,
		a_AsOfDate Date,
    a_Jobid    udt_id);

  --*------------------------------------------------------------------------------------------------
  --* Dishonor Payments
  --*------------------------------------------------------------------------------------------------

  procedure DishonorPayments(
    a_ObjectId udt_Id,
    a_AsOfDate Date,
    a_Jobid    udt_Id);

  --*------------------------------------------------------------------------------------------------
  --* DishonorRenewalCalc --TO BE DELETED, WE DON'T NEED THIS PROCEDURE ANY MORE.
  -- Recalculate the REN/REN50/REN100 fees and Auto Revoke those past the Last Date 100% Penalty.
--  TODO ONLY RUN THIS PROCEDURE ON LICENSE TYPE JOBS.
  --*------------------------------------------------------------------------------------------------

  procedure zzzDishonorRenewalCalc(a_PaymentId udt_id,
                                a_BatchDate Date);

  --*------------------------------------------------------------------------------------------------
  --* DishonorBatchFlags
  -- Set the Batch Flags on the License Type Job if it is past a due date.
  --*------------------------------------------------------------------------------------------------

  procedure DishonorBatchFlags(a_PaymentObjectId udt_id,
                               a_BatchDate Date
  );
  --*------------------------------------------------------------------------------------------------
  --* DishonoredLicensePayments
  -- This relationship gets the Payments not assosiated to Misc Fee Job from the Dishonor Payment Job.
  --*------------------------------------------------------------------------------------------------

  procedure DishonoredLicensePayments(a_ObjectId         udt_Id,
                                    a_EndPointId       udt_Id,
                                    a_RelatedObjectIds out api.udt_ObjectList);

---------------------
--Performance Testing                                    
---------------------
procedure PaymentsVoid(a_ObjectId       number,
                         a_AsOfDate         date);

Procedure VoidBatchEntryObjects(a_ObjectId number, 
                                  a_AsOfDate date,
                                  a_BatchId  number,
                                  a_HQReceiptNum varchar2);

Procedure FindManualFee(
	  a_LicenseTypeCode             varchar2,
    a_EffectiveDate                   date,
    a_EffectiveDateUpper              date,
    a_Description                 varchar2,
    a_SearchForHistoricalRecords  varchar2,
    a_ExcludeObjectIds            varchar2,
    a_Processid                     udt_id,
    a_Objects          out nocopy api.udt_ObjectList);

end pkg_Benjamin;

 
/
