CREATE OR REPLACE FUNCTION ABC.get_statusdate(
    p_jobid        IN api.pkg_definition.udt_id)
    RETURN extension.jobstatuschange_t.effectivestartdate%TYPE
IS
    -- **************************************************************************
    -- File:        GET_STATUSDATE.FNC
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
    v_date   extension.jobstatuschange_t.effectivestartdate%TYPE := NULL;
BEGIN
    BEGIN
        SELECT js.effectivestartdate
          INTO v_date
          FROM extension.jobstatuschange_t js
         WHERE js.jobid = p_jobid
           AND js.mostrecent = 'Y';
    EXCEPTION
        WHEN OTHERS THEN
            v_date   := NULL;
    END;

    RETURN (v_date);
END;
/


GRANT EXECUTE ON ABC.GET_STATUSDATE TO POSSEEXTENSIONS;
