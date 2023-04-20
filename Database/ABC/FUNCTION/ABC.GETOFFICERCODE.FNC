CREATE OR REPLACE FUNCTION ABC.getofficercode(bl_desc VARCHAR2)
    RETURN VARCHAR2
IS
    -- **************************************************************************
    -- File:        GETOFFICERCODE.FNC
    -- Author:      CX
    --
    -- $Rev$
    -- $Date$
    -- Last Changed By:  $Author$
    --
    -- Description:
    --      pass in officer type description
    --
    --
    -- History:
    -----------------------------------------------------------------------------
    --    Date                  Comment
    -- 08/22/2018 TJL         Initial Check-in
    -- **************************************************************************
    t_officercode   VARCHAR2(10);
BEGIN
    SELECT d.code
      INTO t_officercode
      FROM abc.officer_codes d
     WHERE d.description = bl_desc;

    RETURN t_officercode;
END;
/


GRANT EXECUTE ON ABC.GETOFFICERCODE TO POSSEEXTENSIONS;

GRANT EXECUTE ON ABC.GETOFFICERCODE TO PUBLIC;
