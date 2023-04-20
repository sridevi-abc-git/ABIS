CREATE OR REPLACE FUNCTION SITESPECIFIC.feescheduleobjidforpsobjid(
    a_paymentstatus api.pkg_definition.udt_id)
    RETURN NUMBER
IS
    -- **************************************************************************
    -- File:        FEESCHEDULEOBJIDFORPSOBJID.FNC
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
    t_licensefeescheduleobjid   NUMBER := 0;
BEGIN
    --This function needs to be Granted to PosseExtenaions with Execute privileges at creation.
    --This function is referenced by o_PaymentStatus.FeeScheduleObjectId.

    SELECT  /*+ CARDINALITY(x 1)*/
           lfs.licensefeescheduleid feescheduleid
      INTO t_licensefeescheduleobjid
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

    RETURN t_licensefeescheduleobjid;
END;
/


GRANT EXECUTE ON SITESPECIFIC.FEESCHEDULEOBJIDFORPSOBJID TO POSSEEXTENSIONS;
