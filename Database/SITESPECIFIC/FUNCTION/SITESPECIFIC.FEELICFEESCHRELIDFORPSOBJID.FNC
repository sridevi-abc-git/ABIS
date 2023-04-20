CREATE OR REPLACE FUNCTION SITESPECIFIC.feelicfeeschrelidforpsobjid(
    a_paymentstatus api.pkg_definition.udt_id)
    RETURN NUMBER
IS
    -- **************************************************************************
    -- File:        FEELICFEESCHRELIDFORPSOBJID.FNC
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
    t_feelicensefeeschedulerelid   NUMBER := 0;
BEGIN
    --This Function needs to be Granted to PosseExtenaions with Execute privileges at creation.
    --This function is referenced by o_PaymentStatus.IsMaster and o_PaymentStatus.SecondaryCount.

    SELECT  /*+ CARDINALITY(x 1)*/
           lfs.relationshipid
      INTO t_feelicensefeeschedulerelid
      FROM query.o_paymentstatus  ps
           JOIN query.r_paymentstatuspaymenttrans pspt
               ON pspt.paymentstatusobjectid = ps.objectid
           JOIN query.o_paymenttransactions pt
               ON pt.objectid = pspt.paymenttransactionobjectid
           JOIN api.feetransactions ft ON ft.transactionid = pt.transactionid
           JOIN
           TABLE(
               CAST(
                   api.pkg_simplesearch.castableobjectsbyindex('o_Fee',
                                                               'FeeId',
                                                               ft.feeid) AS api.udt_objectlist))
           x
               ON 1 = 1
           JOIN query.r_feelicensefeeschedule lfs
               ON lfs.feeobjectid = x.objectid
     WHERE ps.objectid = a_paymentstatus;

    RETURN t_feelicensefeeschedulerelid;
END;
/


GRANT EXECUTE ON SITESPECIFIC.FEELICFEESCHRELIDFORPSOBJID TO POSSEEXTENSIONS;
