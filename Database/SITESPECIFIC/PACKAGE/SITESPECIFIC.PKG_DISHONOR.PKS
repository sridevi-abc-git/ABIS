CREATE OR REPLACE PACKAGE SITESPECIFIC.pkg_dishonor
AS
    -- **************************************************************************
    -- File:        PKG_DISHONOR.pks
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

    /*---------------------------------------------------------------------------
    * Types
    *-------------------------------------------------------------------------*/
    SUBTYPE udt_id IS api.pkg_definition.udt_id;

    SUBTYPE udt_numberlist IS api.pkg_definition.udt_numberlist;

    SUBTYPE udt_idlist IS api.pkg_definition.udt_idlist;

    PROCEDURE setexternalfilenum(a_objectid udt_id, a_asofdate DATE);

    --*------------------------------------------------------------------------------------------------
    --* Cancel Dishonor Payment(s) Job
    --*------------------------------------------------------------------------------------------------
    PROCEDURE canceldishonorjob(a_objectid      udt_id,
                                a_asofdate      DATE,
                                a_jobid         udt_id);

    --*------------------------------------------------------------------------------------------------
    --* Dishonor Payments
    --*------------------------------------------------------------------------------------------------
    PROCEDURE dishonorpayments(a_objectid      udt_id,
                               a_asofdate      DATE,
                               a_jobid         udt_id);

    --*------------------------------------------------------------------------------------------------
    --* DishonorBatchFlags
    -- Set the Batch Flags on the License Type Job if it is past a due date.
    --*------------------------------------------------------------------------------------------------
    PROCEDURE dishonorbatchflags(a_paymentobjectid udt_id, a_batchdate DATE);

    --*------------------------------------------------------------------------------------------------
    --* DishonoredLicensePayments
    --  This relationship gets Payments not assosiated to Misc Fee Job from the Dishonor Payment Job.
    --   And is used mainly with the Word Interface Mapping.
    --*------------------------------------------------------------------------------------------------

    PROCEDURE dishonoredlicensepayments(
        a_objectid         udt_id,
        a_endpointid       udt_id,
        a_relatedobjectids OUT api.udt_objectlist);


    /*---------------------------------------------------------------------
    -- DishonorPaymentCandidates()
    -- This is called in DishonorPayments to get transferred payments to dishonor.
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
        a_srv                 VARCHAR2);

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
        a_pindex       IN OUT NUMBER);

    /*------------------------------------------------------
    --  ReverseDishonoredPayment()
    -- This is used on completion of the Reverse dishonored Payment Process.
    */
    ------------------------------------------------------
    PROCEDURE reversedishonoredpayment(a_objectid NUMBER, a_asofdate DATE);
END pkg_dishonor;
/
