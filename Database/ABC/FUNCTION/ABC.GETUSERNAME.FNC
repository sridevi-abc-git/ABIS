CREATE OR REPLACE FUNCTION ABC.getusername(a_oraclelogonid VARCHAR2)
    RETURN VARCHAR2
IS
    -- **************************************************************************
    -- File:        GETUSERNAME.FNC
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
    -- 08/22/2018 TJL         Initial Check-in
    -- **************************************************************************
    t_name   VARCHAR2(25);
BEGIN
    SELECT DISTINCT pe.name
      INTO t_name
      FROM query.users pe
     WHERE pe.oraclelogonid = a_oraclelogonid;

    RETURN t_name;
END getusername;
/


GRANT EXECUTE ON ABC.GETUSERNAME TO POSSEEXTENSIONS;

GRANT EXECUTE ON ABC.GETUSERNAME TO PUBLIC;
