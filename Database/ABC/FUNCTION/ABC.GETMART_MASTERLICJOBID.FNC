CREATE OR REPLACE FUNCTION ABC.getmart_masterlicjobid(lt_objectid NUMBER)
    RETURN NUMBER
IS
    -- **************************************************************************
    -- File:        GETMART_MASTERLICJOBID.FNC
    -- Author:      CX
    --
    -- $Rev$
    -- $Date$
    -- Last Changed By:  $Author$
    --
    -- Description:
    --      Returns the Master License Number for License Types 02
    --      pass in mart.licensetype ObjectId (mart.licensetype:ObjectId)
    --
    --
    -- History:
    -----------------------------------------------------------------------------
    --    Date                  Comment
    -- 08/22/2018 TJL         Initial Check-in
    -- **************************************************************************
    t_data   NUMBER;
BEGIN
    BEGIN
        SELECT UNIQUE mlt.licensejobid masterlicensejobid
          INTO t_data
          FROM mart.branchlicensetype  r
               JOIN mart.licensetype mlt
                   ON mlt.objectid = r.masterlicensetypejobid
         WHERE r.branchlicensetypejobid = lt_objectid;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            t_data   := NULL;
        WHEN OTHERS THEN
            t_data   := NULL;
            RETURN t_data;
    END;

    RETURN t_data;
END getmart_masterlicjobid;
/


GRANT EXECUTE ON ABC.GETMART_MASTERLICJOBID TO POSSEEXTENSIONS;

GRANT EXECUTE ON ABC.GETMART_MASTERLICJOBID TO PUBLIC;
