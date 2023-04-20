CREATE OR REPLACE FUNCTION ABC.getmart_cnct_lictypstatdate(
    a_licensejobid  NUMBER)
    RETURN VARCHAR2
IS
    -- **************************************************************************
    -- File:        GETMART_CNCT_LICTYPSTATDATE.FNC
    -- Author:      CX
    --
    -- $Rev$
    -- $Date$
    -- Last Changed By:  $Author$
    --
    -- Description:
    --      Concats the License Type Status Date...
    --
    --
    -- History:
    -----------------------------------------------------------------------------
    --    Date                  Comment
    -- 08/22/2018 TJL         Initial Check-in
    -- **************************************************************************
    t_ltcodes   VARCHAR2(100);
BEGIN
    SELECT concatlist(t.status_date)
      INTO t_ltcodes
      FROM (SELECT lt.licensetypecode                        ltcode,
                   'pri'                                     sort, -- License Type Code is required to identiy returned data in the same order as concat type codes.
                   TO_CHAR(lt.statusdatecorral, 'DD-MON-YY') status_date
              FROM mart.licenselicensetyperel  llt
                   JOIN mart.licensetype lt
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
                   TO_CHAR(lt.statusdatecorral, 'DD-MON-YY')
                       status_date
              FROM mart.licenselicensetyperel  llt
                   JOIN mart.licensetype lt
                       ON lt.objectid = llt.licensetypejobid
                   JOIN mart.licensetypeltcatsecondary slt
                       ON slt.licensetypejobid = llt.licensetypejobid
                   JOIN mart.licensetypecategory ltc
                       ON ltc.objectid = slt.licensetypecategoryobjectid
             WHERE llt.licensejobid = a_licensejobid
            ORDER BY 2, 1) t;

    RETURN t_ltcodes;
END getmart_cnct_lictypstatdate;
/


GRANT EXECUTE ON ABC.GETMART_CNCT_LICTYPSTATDATE TO POSSEEXTENSIONS;

GRANT EXECUTE ON ABC.GETMART_CNCT_LICTYPSTATDATE TO PUBLIC;
