CREATE OR REPLACE FUNCTION ABC.get_lic_masterindicator(
    p_licenseobjectid IN NUMBER)
    RETURN VARCHAR
IS
    -- **************************************************************************
    -- File:        GET_LIC_MASTERINDICATOR.FNC
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
    v_yes     VARCHAR2(1);
    l_check   NUMBER;
BEGIN
    BEGIN
        SELECT COUNT(*)
          INTO l_check
          FROM query.r_licenselicensetype  rllt2
               JOIN query.j_licensetype jlt2
                   ON jlt2.jobid = rllt2.licensetypejobid
               JOIN query.r_licensetypeltcatsecondary slt
                   ON slt.licensetypejobid = jlt2.jobid
               JOIN query.o_licensetypecategory oltc
                   ON oltc.objectid = slt.licensetypecategoryobjectid
         WHERE rllt2.licensejobid = p_licenseobjectid;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            v_yes   := 'N';
        WHEN OTHERS THEN
            v_yes   := 'N';
    END;

    IF l_check > 0 THEN
        v_yes   := 'Y';
    ELSE
        v_yes   := 'N';
    END IF;

    RETURN (v_yes);
END;
/


GRANT EXECUTE ON ABC.GET_LIC_MASTERINDICATOR TO ABCREPORTS;

GRANT EXECUTE ON ABC.GET_LIC_MASTERINDICATOR TO ABCREPORTS_ROLE;

GRANT EXECUTE ON ABC.GET_LIC_MASTERINDICATOR TO POSSEEXTENSIONS;
