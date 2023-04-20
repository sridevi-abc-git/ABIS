CREATE OR REPLACE FUNCTION ABC.getuseroralogonid(a_name VARCHAR2)
    RETURN VARCHAR2
IS
    -- **************************************************************************
    -- File:        GETUSERORALOGONID.FNC
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
    t_oralogonid   VARCHAR2(25);
BEGIN
    SELECT DISTINCT pe.oraclelogonid
      INTO t_oralogonid
      FROM query.users pe
     WHERE pe.name = a_name;

    RETURN t_oralogonid;
END getuseroralogonid;
/


GRANT EXECUTE ON ABC.GETUSERORALOGONID TO POSSEEXTENSIONS;

GRANT EXECUTE ON ABC.GETUSERORALOGONID TO PUBLIC;
