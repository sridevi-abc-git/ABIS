CREATE OR REPLACE FUNCTION ABC.getmart_mailcity(bl_jobobjectid NUMBER)
    RETURN VARCHAR2
IS
    -- **************************************************************************
    -- File:        GETMART_MAILCITY.FNC
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

    t_addressdata   VARCHAR2(50);
BEGIN
    SELECT ad.usacity
      INTO t_addressdata
      FROM mart.businessmailinglocations  bl
           JOIN mart.address ad ON ad.objectid = bl.addressobjectid
     WHERE bl.jobobjectid = bl_jobobjectid;

    RETURN t_addressdata;
END getmart_mailcity;
/


GRANT EXECUTE ON ABC.GETMART_MAILCITY TO POSSEEXTENSIONS;

GRANT EXECUTE ON ABC.GETMART_MAILCITY TO PUBLIC;
