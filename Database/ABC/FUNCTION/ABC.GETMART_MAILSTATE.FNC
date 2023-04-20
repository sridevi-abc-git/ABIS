CREATE OR REPLACE FUNCTION ABC.getmart_mailstate(bl_jobobjectid NUMBER)
    RETURN VARCHAR2
IS
    -- **************************************************************************
    -- File:        GETMART_MAILSTATE.FNC
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
    t_addressdata   VARCHAR2(2);
BEGIN
    SELECT ad.usastatecode
      INTO t_addressdata
      FROM mart.businessmailinglocations  bl
           JOIN mart.address ad ON ad.objectid = bl.addressobjectid
     WHERE bl.jobobjectid = bl_jobobjectid;

    RETURN t_addressdata;
END getmart_mailstate;
/


GRANT EXECUTE ON ABC.GETMART_MAILSTATE TO POSSEEXTENSIONS;

GRANT EXECUTE ON ABC.GETMART_MAILSTATE TO PUBLIC;
