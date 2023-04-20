CREATE OR REPLACE FUNCTION ABC.getstatusname(a_statd VARCHAR2)
    RETURN VARCHAR2
IS
    -- **************************************************************************
    -- File:        GETSTATUSNAME.FNC
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
    t_statname   VARCHAR2(100);
BEGIN
    SELECT z.tag
      INTO t_statname
      FROM api.statuses z
     WHERE LOWER(a_statd) = LOWER(z.description);

    RETURN t_statname;
END getstatusname;
/


GRANT EXECUTE ON ABC.GETSTATUSNAME TO POSSEEXTENSIONS;

GRANT EXECUTE ON ABC.GETSTATUSNAME TO PUBLIC;
