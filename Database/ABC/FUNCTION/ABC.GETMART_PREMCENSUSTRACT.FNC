CREATE OR REPLACE FUNCTION ABC.getmart_premcensustract(bl_jobobjectid NUMBER)
    RETURN VARCHAR2
IS
    -- **************************************************************************
    -- File:        GETMART_PREMCENSUSTRACT.FNC
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
    SELECT TRIM(TO_CHAR(ad.censustract, '0000.00')) censustract
      INTO t_addressdata
      FROM mart.businesslocations  bl
           JOIN mart.address ad ON ad.objectid = bl.addressobjectid
     WHERE bl.jobobjectid = bl_jobobjectid;

    RETURN t_addressdata;
END getmart_premcensustract;
/


GRANT EXECUTE ON ABC.GETMART_PREMCENSUSTRACT TO POSSEEXTENSIONS;

GRANT EXECUTE ON ABC.GETMART_PREMCENSUSTRACT TO PUBLIC;
