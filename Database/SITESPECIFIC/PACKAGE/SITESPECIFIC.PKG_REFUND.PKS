CREATE OR REPLACE PACKAGE SITESPECIFIC."PKG_REFUND"
AS
    -- **************************************************************************
    -- File:        PKG_REFUND.PKS
    -- Author:      CX
    --
    -- $Rev: 381 $
    -- $Date: 2019-11-09 06:21:27 -0800 (Sat, 09 Nov 2019) $
    -- Last Changed By:  $Author: TLord $
    --
    -- Description:
    --
    --
    -- History:
    -----------------------------------------------------------------------------
    --    Date                  Comment
    -- 08/01/2018 SS  WO 14438  Fix to unearn the payment after the refund batch run.
    -- 03/04/2020 TJL WO 20884  Added procedure "CreateWithdrawalTransaction" and
    --                            "schedulecreatesvrtransaction" 
    -- **************************************************************************

    TYPE var IS VARRAY(100) OF NUMBER(1);

    SUBTYPE udt_idlist IS api.pkg_definition.udt_idlist;

    SUBTYPE udt_numberlist IS api.pkg_definition.udt_numberlist;

    /*---------------------------------------------------------------------------
    * Types
    *-------------------------------------------------------------------------*/
    SUBTYPE udt_id IS api.pkg_definition.udt_id;

    --CreateSRVLineItems
    --Called from the Calculate Service Charge checbox on the Refund Check object.
    --Creates SRV (Refund Check Item) objects for those Payment Transactions which
    --have Service Charge = Y
    PROCEDURE createsrvlineitems(a_objectid udt_id, a_asofdate DATE);

    --CreateRefundTransactions
    --Called from the outcome of the Batch Refunds process on the Refund Batch job.
    --Creates 'reversal' payment transactions and 'moves' money from the refund payments.
    PROCEDURE createrefundtransactions(a_objectid      NUMBER,
                                       a_asofdate      DATE,
                                       a_jobid         NUMBER);

    --UpdateRefundTransactions
    --Called from the outcome of the Generate Refund Checks process on the Refund Batch job.
    --Updates the Check number and sets the CheckDates to the current date.
    PROCEDURE updaterefundtransactions(a_objectid      NUMBER,
                                       a_asofdate      DATE,
                                       a_jobid         NUMBER);

    --  EarnPaymentTransactions()
    -- creates an Earned Payment Status for every Fee Id passed in.
    PROCEDURE earnsrvpaytrans(a_earnfeeids    udt_idlist,
                              a_amountstopay  udt_numberlist,
                              a_paymenttransfer BOOLEAN DEFAULT FALSE);

    --  SRVTransaction()
    -- This is used with in the CreateRefundTransactions and the pkg_Fees.TransferPayment procedures
    PROCEDURE srvtransaction(
        a_objectid            udt_id,
        a_xfeeid              udt_id,
        a_xlicensenumber      NUMBER,
        a_xlicensetypecode    NUMBER,
        a_var          IN OUT var, -- this must be declared at the top of the package
        a_feeids       IN OUT api.pkg_definition.udt_idlist,
        a_amounts      IN OUT api.pkg_definition.udt_numberlist,
        a_srvfeeids    IN OUT api.pkg_definition.udt_idlist,
        a_srvamounts   IN OUT api.pkg_definition.udt_numberlist);

    --Called on the refund batch job to generate check numbers
    PROCEDURE generatechecknumbers(a_objectid udt_id, a_asofdate DATE);

    --  ReverseRefundPayment()
    -- This is used on completion of the Reverse Refund Payment Process.
    PROCEDURE reverserefundpayment(a_objectid NUMBER, a_asofdate DATE);

    PROCEDURE ScheduleCreateSVRTransaction(a_objectid      NUMBER,
                                           a_asofdate      DATE,
                                           a_jobid         NUMBER);

    --CreateWithdrawalTransactions
    --Called from the outcome of the withdrawl process on application job.
    --Creates batch refund job that creates a service fee for the total of 
    --  all payments. It will only process the fee when the total fee is
    --  kept.  Any refund must be processed through POSSE Batch Refund.
    PROCEDURE CreateWithdrawalTransaction(a_objectid      NUMBER,
                                          a_asofdate      DATE,
                                          a_jobid         NUMBER);

    
END pkg_refund;
/


GRANT EXECUTE ON SITESPECIFIC.PKG_REFUND TO EXTENSION;

GRANT EXECUTE ON SITESPECIFIC.PKG_REFUND TO POSSEEXTENSIONS;
