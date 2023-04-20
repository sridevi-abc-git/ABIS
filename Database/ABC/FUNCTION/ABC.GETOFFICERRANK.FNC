CREATE OR REPLACE FUNCTION ABC.getofficerrank(bl_desc VARCHAR2)
    RETURN NUMBER
IS
    -- **************************************************************************
    -- File:        GETOFFICERRANK.FNC
    -- Author:      CX
    --
    -- $Rev$
    -- $Date$
    -- Last Changed By:  $Author$
    --
    -- Description:
    --      pass in officer type description
    --      used in Raw Data Extracts
    --
    --
    -- History:
    -----------------------------------------------------------------------------
    --    Date                  Comment
    -- 08/22/2018 TJL         Initial Check-in
    -- **************************************************************************
    t_officercode   NUMBER;
BEGIN
    SELECT d.RANK
      INTO t_officercode
      FROM abc.officer_codes d
     WHERE d.description = bl_desc;

    RETURN t_officercode;
END;
/


GRANT EXECUTE ON ABC.GETOFFICERRANK TO POSSEEXTENSIONS;

GRANT EXECUTE ON ABC.GETOFFICERRANK TO PUBLIC;
