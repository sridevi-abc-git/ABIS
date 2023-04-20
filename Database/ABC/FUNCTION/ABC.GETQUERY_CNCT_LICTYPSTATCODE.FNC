CREATE OR REPLACE FUNCTION ABC.getquery_cnct_lictypstatcode(
    a_licensejobid  NUMBER)
    RETURN VARCHAR2
IS
    -- **************************************************************************
    -- File:        GETQUERY_CNCT_LICTYPSTATCODEFNC
    -- Author:      CX
    --
    -- $Rev$
    -- $Date$
    -- Last Changed By:  $Author$
    --
    -- Description:
    --      Concats License Type Status Codes
    --
    --
    -- History:
    -----------------------------------------------------------------------------
    --    Date                  Comment
    -- 08/22/2018 TJL         Initial Check-in
    -- **************************************************************************
    t_ltcodes   VARCHAR2(4000);
BEGIN
    SELECT concatlist(t.statusname)
      INTO t_ltcodes
      FROM (SELECT lt.licensetypecode ltcode, 'pri' sort, lt.statusname
              FROM query.r_licenselicensetype  llt
                   JOIN query.j_licensetype lt
                       ON lt.objectid = llt.licensetypejobid
             WHERE llt.licensejobid = a_licensejobid
            UNION ALL
            SELECT    ltc.licensetypecode
                   || CASE
                          WHEN slt.licensetypecount > 0 THEN
                              '[' || slt.licensetypecount || ']'
                      END
                       ltcode,
                   'sec'
                       sort,
                   slt.status
                       statusname
              FROM query.r_licenselicensetype  llt
                   JOIN query.r_licensetypeltcatsecondary slt
                       ON slt.licensetypejobid = llt.licensetypejobid
                   JOIN query.o_licensetypecategory ltc
                       ON ltc.objectid = slt.licensetypecategoryobjectid
             WHERE llt.licensejobid = a_licensejobid
            ORDER BY 2, 1) t;

    RETURN t_ltcodes;
END getquery_cnct_lictypstatcode;
/


GRANT EXECUTE ON ABC.GETQUERY_CNCT_LICTYPSTATCODE TO POSSEEXTENSIONS;

GRANT EXECUTE ON ABC.GETQUERY_CNCT_LICTYPSTATCODE TO PUBLIC;
