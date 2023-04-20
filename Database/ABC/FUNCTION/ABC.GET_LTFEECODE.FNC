CREATE OR REPLACE FUNCTION ABC.get_ltfeecode(p_jobid IN NUMBER)
    RETURN query.o_fee.feecode%TYPE
IS
    -- **************************************************************************
    -- File:        GET_LTFEECODE.FNC
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
    v_feecode   query.o_fee.feecode%TYPE;
BEGIN
    BEGIN
        SELECT NULL
          INTO v_feecode
          FROM DUAL;
    EXCEPTION
        WHEN OTHERS THEN
            v_feecode   := NULL;
    END;

    RETURN (v_feecode);
END;
/


GRANT EXECUTE ON ABC.GET_LTFEECODE TO POSSEEXTENSIONS;
