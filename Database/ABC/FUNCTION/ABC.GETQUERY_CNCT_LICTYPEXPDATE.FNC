CREATE OR REPLACE FUNCTION ABC.getquery_cnct_lictypexpdate(
    a_licensejobid  NUMBER)
    RETURN VARCHAR2
IS
    -- **************************************************************************
    -- File:        GETQUERY_CNCT_LICTYPEXPDATE.FNC
    -- Author:      CX
    --
    -- $Rev$
    -- $Date$
    -- Last Changed By:  $Author$
    --
    -- Description:
    --      Concats the License Type Expiration (Renewal Date)
    --
    --
    -- History:
    -----------------------------------------------------------------------------
    --    Date                  Comment
    -- 08/22/2018 TJL         Initial Check-in
    -- **************************************************************************
    t_ltcodes   VARCHAR2(100);
BEGIN
    SELECT concatlist(t.expiration_date)
      INTO t_ltcodes
      FROM (SELECT lt.licensetypecode                   ltcode,
                   'pri'                                sort, -- License Type Code is required to identiy returned data in the same order as concat type codes.
                   TO_CHAR(lt.renewaldate, 'DD-MON-YY') expiration_date
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
                       sort, -- License Type Code is required to identiy returned data in the same order as concat type codes.
                   TO_CHAR(lt.renewaldate, 'DD-MON-YY')
                       expiration_date
              FROM query.r_licenselicensetype  llt
                   JOIN query.j_licensetype lt
                       ON lt.objectid = llt.licensetypejobid
                   JOIN query.r_licensetypeltcatsecondary slt
                       ON slt.licensetypejobid = llt.licensetypejobid
                   JOIN query.o_licensetypecategory ltc
                       ON ltc.objectid = slt.licensetypecategoryobjectid
             WHERE llt.licensejobid = a_licensejobid
            ORDER BY 2, 1) t;

    RETURN t_ltcodes;
END getquery_cnct_lictypexpdate;
/


GRANT EXECUTE ON ABC.GETQUERY_CNCT_LICTYPEXPDATE TO POSSEEXTENSIONS;

GRANT EXECUTE ON ABC.GETQUERY_CNCT_LICTYPEXPDATE TO PUBLIC;
