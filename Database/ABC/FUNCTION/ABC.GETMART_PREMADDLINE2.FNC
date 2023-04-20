CREATE OR REPLACE FUNCTION ABC.getmart_premaddline2(bl_jobobjectid NUMBER)
    RETURN VARCHAR2
IS
    -- **************************************************************************
    -- File:        GETMART_PREMADDLINE2.FNC
    -- Author:      CX
    --
    -- $Rev$
    -- $Date$
    -- Last Changed By:  $Author$
    --
    -- Description:
    --      Returns the Premise Address Data from Mart (Corral).
    --      For both Applicatoin or License this function,
    --      pass in mart.licnese jobid  (mart.license:jobid = MART.BUSINESSLOCATIONS:JOBOBJECTID)
    --        or mart.application objectid (mart.application:objectid = MART.BUSINESSLOCATIONS:JOBOBJECTID
    --
    --
    -- History:
    -----------------------------------------------------------------------------
    --    Date                  Comment
    -- 08/22/2018 TJL         Initial Check-in
    -- **************************************************************************
    t_addressdata   VARCHAR2(100);
BEGIN
    SELECT ad.addressline2
      INTO t_addressdata
      FROM mart.businesslocations  bl
           JOIN mart.address ad ON ad.objectid = bl.addressobjectid
     WHERE bl.jobobjectid = bl_jobobjectid;

    RETURN t_addressdata;
END getmart_premaddline2;
/


GRANT EXECUTE ON ABC.GETMART_PREMADDLINE2 TO POSSEEXTENSIONS;

GRANT EXECUTE ON ABC.GETMART_PREMADDLINE2 TO PUBLIC;
