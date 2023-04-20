CREATE OR REPLACE FUNCTION ABC.getisbranch(lt_objectid NUMBER)
    RETURN VARCHAR2
IS
    -- **************************************************************************
    -- File:        GETISBRANCH.FNC
    -- Author:      CX
    --
    -- $Rev$
    -- $Date$
    -- Last Changed By:  $Author$
    --
    -- Description:
    --      Returns the Y for a branch and N for not
    --
    --
    -- History:
    -----------------------------------------------------------------------------
    --    Date                  Comment
    -- 08/22/2018 TJL         Initial Check-in
    -- **************************************************************************
    t_data   VARCHAR2(10);
BEGIN
    BEGIN
        SELECT 'Y'
          INTO t_data
          FROM query.r_branchltmasterlt rbmlt
         WHERE rbmlt.branchlicensetypejobid = lt_objectid;
    EXCEPTION
        WHEN OTHERS THEN
            t_data   := 'N';
    END;

    RETURN t_data;
END getisbranch;
/
