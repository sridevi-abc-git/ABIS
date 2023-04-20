CREATE OR REPLACE FUNCTION ABC.get_lic_unqlictypes(p_jobid IN NUMBER)
    RETURN query.j_license.uniquelicensetypecodes%TYPE
IS
    -- **************************************************************************
    -- File:        GET_LIC_UNQLICTYPES.FNC
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
    v_alllictypes   query.j_license.uniquelicensetypecodes%TYPE := NULL;
BEGIN
    BEGIN
        SELECT concatlist(a.ltcd) lictypes
          INTO v_alllictypes
          FROM (SELECT jlt.licensetypecode ltcd, rllt.licensejobid licjobid
                  FROM query.j_licensetype  jlt
                       JOIN query.r_licenselicensetype rllt
                           ON rllt.licensetypejobid = jlt.jobid
                 WHERE rllt.licensejobid = p_jobid
                   AND jlt.jobstatus IN ('ACTIVE', 'REVPEN')
                UNION
                SELECT oltc.licensetypecode ltcd, rllt2.licensejobid licjobid
                  FROM query.r_licenselicensetype  rllt2
                       JOIN query.j_licensetype jlt2
                           ON jlt2.jobid = rllt2.licensetypejobid
                       JOIN query.r_licensetypeltcatsecondary slt
                           ON slt.licensetypejobid = jlt2.jobid
                       JOIN query.o_licensetypecategory oltc
                           ON oltc.objectid = slt.licensetypecategoryobjectid
                 WHERE rllt2.licensejobid = p_jobid
                   AND jlt2.jobstatus IN ('ACTIVE', 'REVPEN')
                   AND NVL(slt.status, jlt2.jobstatus) IN
                           ('ACTIVE', 'REVPEN')) a;
    EXCEPTION
        WHEN OTHERS THEN
            v_alllictypes   := NULL;
    END;

    RETURN (v_alllictypes);
END;
/


GRANT EXECUTE ON ABC.GET_LIC_UNQLICTYPES TO POSSEEXTENSIONS;
