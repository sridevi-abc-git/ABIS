CREATE OR REPLACE FUNCTION ABC.getmart_mailaddline3(bl_jobobjectid NUMBER)
    -- **************************************************************************
    -- File:        GETMART_MAILADDLINE3.FNC
    -- Author:      CX
    --
    -- $Rev$
    -- $Date$
    -- Last Changed By:  $Author$
    --
    -- Description:
    --      Returns the Premise  Mail Address Data from Mart (Corral).
    --      For both Applicatoin or License,
    --      pass in mart.licnese jobid  (mart.license:jobid = MART.BUSINESSMAILINGLOCATIONS:JOBOBJECTID)
    --        or mart.application objectid (mart.application:objectid = MART.BUSINESSMAILINGLOCATIONS:JOBOBJECTID
    --
    --
    -- History:
    -----------------------------------------------------------------------------
    --    Date                  Comment
    -- 08/22/2018 TJL         Initial Check-in
    -- **************************************************************************


    RETURN VARCHAR2
IS
    t_addressdata   VARCHAR2(100);
BEGIN
    SELECT ad.addressline3
      INTO t_addressdata
      FROM mart.businessmailinglocations  bl
           JOIN mart.address ad ON ad.objectid = bl.addressobjectid
     WHERE bl.jobobjectid = bl_jobobjectid;

    RETURN t_addressdata;
END getmart_mailaddline3;
/


GRANT EXECUTE ON ABC.GETMART_MAILADDLINE3 TO POSSEEXTENSIONS;

GRANT EXECUTE ON ABC.GETMART_MAILADDLINE3 TO PUBLIC;
