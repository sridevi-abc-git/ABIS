CREATE OR REPLACE FUNCTION SITESPECIFIC.feetransactionobjidforpsobjid(
    a_paymentstatus api.pkg_definition.udt_id)
    RETURN NUMBER
IS
    -- **************************************************************************
    -- File:        FEETRANSACTIONOBJIDFORPSOBJID.FNC
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
    -- 08/20/2018 TJL         Initial Check-in
    -- **************************************************************************
    t_feetransactionobjid   NUMBER := 0;
BEGIN
    --This function needs to be Granted to PosseExtenaions with Execute privileges at creation.
    --This function is referenced by o_PaymentStatus.EarnedAmount.

    SELECT api.pkg_simplesearch.objectbyindex('o_FeeTransactions',
                                              'TransactionId',
                                              pt.transactionid)
      INTO t_feetransactionobjid
      FROM query.o_paymentstatus  ps
           JOIN query.r_paymentstatuspaymenttrans pspt
               ON pspt.paymentstatusobjectid = ps.objectid
           JOIN query.o_paymenttransactions pt
               ON pt.objectid = pspt.paymenttransactionobjectid
     WHERE ps.objectid = a_paymentstatus;

    RETURN t_feetransactionobjid;
END;
/


GRANT EXECUTE ON SITESPECIFIC.FEETRANSACTIONOBJIDFORPSOBJID TO POSSEEXTENSIONS;
