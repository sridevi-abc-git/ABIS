CREATE OR REPLACE PACKAGE SITESPECIFIC."PKG_ACCOUNTING"
AS
    -- **************************************************************************
    -- File:        PKG_ACCOUNTING.pks
    -- Author:      CX
    --
    -- History:
    -----------------------------------------------------------------------------
    --    Date                  Comment
    -- 08/16/2018 TJL         Initial Check-in
    -- 05/11/2021 TJL   WO18874 Add new procdeure 'VerifyBatchPayments'               
    -- **************************************************************************

    /*---------------------------------------------------------------------------
    * Types
    *-------------------------------------------------------------------------*/
    SUBTYPE udt_id IS api.pkg_definition.udt_id; 

    SUBTYPE udt_numberlist IS api.pkg_definition.udt_numberlist;

    SUBTYPE udt_idlist IS api.pkg_definition.udt_idlist;

    --*------------------------------------------------------------------------------------------------
    --* SetDepositRelationships() -- PUBLIC
    --* This procedure relates the Transmittal job and the Payment Batch job to the Deposit job
    --* when the Transmittal and Payment Batch jobs are not currently related to a Deposit job
    --* and when the Transmittal and Payment Batch jobs are in the Complete status.
    --*------------------------------------------------------------------------------------------------
    PROCEDURE setdepositrelationships(a_objectid udt_id, a_asofdate DATE);

    /*---------------------------------------------------------------------------
    * RelatePaymentToTransmittal() -- PUBLIC
    * This procedure relates receipted payment objects to a Transmittal job.
    * The payments are only related when the Payment is of the same type (cash or check
    * as the Transmittal and when the Payment is not related to a Transmittal.
    *-------------------------------------------------------------------------*/
    PROCEDURE relatepaymenttotransmittal(a_objectid udt_id, a_asofdate DATE, a_transmittaltype STRING);

    --*------------------------------------------------------------------------------------------------
    --* GetOfficesForTransmittal() -- PUBLIC
    --* This is a procedural relationship that is used to cross-validate a relationship between
    --* the Transmittal job and the Office object.  It allows the dependent dropdown to include both
    --* the user's secondary offices as well as the user's default office.
    --*------------------------------------------------------------------------------------------------
    PROCEDURE getofficesfortransmittal(a_objectid         udt_id,
                                       a_endpointid       udt_id,
                                       a_relatedobjectids OUT api.udt_objectlist);

    --*------------------------------------------------------------------------------------------------
    --* RelateTransmittalToOffice() -- PUBLIC
    --* This is a procedure that automatically relates the Transmittal job to the user's
    --* default office.
    --*------------------------------------------------------------------------------------------------
    PROCEDURE relatetransmittaltooffice(a_objectid udt_id, a_asofdate DATE);

    /*---------------------------------------------------------------------------
    * AssignHeadquarterstoProcess() -- PUBLIC
    * This will assign the access group HQ Accounting to the Process Batch Entry on the job Payment Batch
    * Except for the person who created the First Process on the job
    *-------------------------------------------------------------------------*/

    PROCEDURE assignvalidatebatch(a_objectid udt_id, a_asofdate DATE, a_jobid udt_id);

    --*------------------------------------------------------------------------------------------------
    --* SetFeeRelToResearchRefundsProc() -- PUBLIC
    --* This procedure relates the Research Refunds process to fees that are related to the job that it
    --* is on.  This relationship is set when the TotalOwing Dynamic Detail is < 0.  If the job that
    --* this process is on is a License the procedure will also relate fees on related License Types
    --*that also meet the TotalOwing criteria.
    --*------------------------------------------------------------------------------------------------

    PROCEDURE setfeereltoresearchrefundsproc(a_objectid udt_id, a_asofdate DATE, a_jobid udt_id);

    /*---------------------------------------------------------------------------
   * CreateLineItemObject() -- PUBLIC
   * this will create Batch Payment Entry Objects for the Payment Batch Job based
   * on the Line Item Count and Payment Number From and To
   * it will also throw in a GroupID if it is a P-12
   *-------------------------------------------------------------------------*/

    PROCEDURE createlineitem(a_jobid udt_id, a_asofdate DATE);

    /*---------------------------------------------------------------------------
 * SortByColumn() -- PUBLIC
 * this will set a Squentced column for the Batch Payment Entry Object
 *-------------------------------------------------------------------------*/
    PROCEDURE sortbycolumn(a_objectid udt_id, a_asofdate DATE);

    /*----------------------------------------------------------------------------------
    -- DepositReport()
    -- This creates a table and populates it with values for the Account Deposit Report
    */
    ----------------------------------------------------------------------------------

    PROCEDURE depositreport(a_startdate DATE, a_enddate DATE);

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
    PROCEDURE winegrowerscompletion(a_objectid udt_id, a_asofdate DATE);


    --------------------------------------------------------
    -- CreateWinegrowerFees() -- PUBLIC
    -- Called by sitespecific.pkg_##**##**.WinegrowersCompletion
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
                                   a_feeobjid     OUT NUMBER);

    --------------------------------------------------------
    -- Relate LT to Object
    -- Used to relate License Types to BatchPaymentEntry and Additional Item objects in the Payment Batch job.
    -- Only does this for P-12 Renewals and Individual Renewal Fees (IR).
    --------------------------------------------------------
    PROCEDURE relatelttoobject(a_objectid NUMBER, a_asofdate DATE);


    --------------------------------------------------------
    -- Create Batch Payments
    -- Called from Payment Batch Completion procedures to create payments for an array of FeeIds and array of Amounts
    -- Earned should be 'Earned' or 'Unearned' as appropriate for the payments
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
                                  a_cabinamttype     VARCHAR2 DEFAULT 'I');

    --------------------------------------------------------
    -- POICCompletion - public
    -- Run from payment batch for POIC payments, this will pay appropriate POIC fees.
    --------------------------------------------------------
    PROCEDURE poiccompletion(a_objectid NUMBER, a_asofdate DATE, a_jobid NUMBER);

    --------------------------------------------------------
    -- IRP12Completion - public
    -- Run from j_PaymentBatch for IR and P-12 batch types, this will create and pay appropriate REN fees.
    -- P12 is one payment, while IR has a payment per BatchPaymentEntry object on the Payment Batch job.
    --------------------------------------------------------
    PROCEDURE irp12completion(a_objectid udt_id, a_asofdate DATE, a_jobid udt_id);

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
                                     a_amountstopay IN OUT udt_numberlist);

    --------------------------------------------------------
    -- Set Amounts for FeeIdArray - public
    -- Called from Payment Batch completion procedures to take a array of FeeIds, and give a corresponding payment amount for each,
    -- based on a passed-in total PaidAmount.
    --------------------------------------------------------
    PROCEDURE setamountsforfeeids(a_feeids              udt_idlist,
                                  a_paidamount          NUMBER,
                                  a_amountstopay IN OUT udt_numberlist,
                                  a_finalfeeids  IN OUT udt_idlist);

    -------------------------------------------------------
    -- ReadyToIssue()
    -------------------------------------------------------
    PROCEDURE readytoissue(a_objectid udt_id, a_asofdate DATE);

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
                                   a_fromorto      VARCHAR2);

    /*---------------------------------------------------------------------------
    *procedure UpdatePaymentPayeeReferance()
    *This updates the payment payee referance
    *-------------------------------------------------------------------------*/
    PROCEDURE updatepaymentpayeereference(a_objectid udt_id, a_asofdate DATE, a_payeereference VARCHAR2);

    PROCEDURE relatepaymenttransactions(a_objectid NUMBER, a_asofdate DATE);

    PROCEDURE deletepaymenttransrel(a_objectid NUMBER, a_asofdate DATE);

    PROCEDURE modifypayment(a_objectid NUMBER, a_asofdate DATE);

    /*---------------------------------------------------------------------------
     * RemovePaymentFromTransmittal() -- PUBLIC
     * This procedure will run on a post verify of a Transmittal job when a user
     * clicks on the delete selected payments link.  It will remove the relationship
     * from the job to the payment for all selected payments.
     *-------------------------------------------------------------------------*/
    PROCEDURE removepaymentfromtransmittal(a_objectid NUMBER, a_asofdate DATE);

    /*---------------------------------------------------------------------------
     * CreateTransmitPaymentOfficeRel() -- Mike Lott
     * Added to create relationship that flags a payment for transmittal. Called
     * from r_PaymentOffice constructor.
     *-------------------------------------------------------------------------*/
    PROCEDURE createtransmitpaymentofficerel(a_objectid udt_id, a_asofdate DATE);

    /*---------------------------------------------------------------------------
     * RemoveTransmitPaymentOfficeRel() -- Mike Lott
     * Will remove the r_TransmitPaymentOffice relationship. Should be called after
     * transmittal job has been completed.
     *-------------------------------------------------------------------------*/
    PROCEDURE removetransmitpaymentofficerel(a_objectid udt_id, a_asofdate DATE, a_jobid udt_id);

    /*---------------------------------------------------------------------------
     * verifybatchpayments() -- Timothy Lord
     * Will verify the payment batch does not have any duplicate payments in it and 
     * that the license type was not paid in another payment batch (duplicate payment).
     *-------------------------------------------------------------------------*/
    PROCEDURE verifybatchpayments(a_objectid udt_id, a_asofdate DATE);
END pkg_accounting;
/


GRANT EXECUTE ON SITESPECIFIC.PKG_ACCOUNTING TO POSSEEXTENSIONS;
