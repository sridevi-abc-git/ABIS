CREATE OR REPLACE FUNCTION ABC.getmart_cnct_lictypandstatus(
    a_licensejobid  NUMBER)
    RETURN VARCHAR2
IS
    -- **************************************************************************
    -- File:        GETMART_CNCT_LICTYPANDSTATUS.FNC
    -- Author:      CX
    --
    -- $Rev$
    -- $Date$
    -- Last Changed By:  $Author$
    --
    -- Description:
    --      Concats License Types and Status Codes
    --
    --
    -- History:
    -----------------------------------------------------------------------------
    --    Date                  Comment
    -- 08/22/2018 TJL         Initial Check-in
    -- **************************************************************************
    t_ltcodes   VARCHAR2(4000);
BEGIN
    SELECT concatlist(typeandstatus)
      INTO t_ltcodes
      FROM (SELECT                               -- lt.LicenseTypeCode ltcode,
                   'pri'
                       sort,
                   -- lt.STATUSNAME,
                   lt.licensetypecode || '-(' || lt.statusname || ')'
                       typeandstatus
              FROM mart.licenselicensetyperel  llt
                   JOIN mart.licensetype lt
                       ON lt.objectid = llt.licensetypejobid
             WHERE llt.licensejobid = a_licensejobid
            UNION ALL
            SELECT /*ltc.licensetypecode  || case
                     when slt.LicenseTypeCount > 0 then
                      '[' || slt.LicenseTypeCount || ']'
                   end ltcode, */
                   'sec'
                       sort,
                   -- slt.STATUS statusname ,
                   ltc.licensetypecode || '-(' || slt.status || ')'
                       typeandstatus
              FROM mart.licenselicensetyperel  llt
                   JOIN mart.licensetypeltcatsecondary slt
                       ON slt.licensetypejobid = llt.licensetypejobid
                   JOIN mart.licensetypecategory ltc
                       ON ltc.objectid = slt.licensetypecategoryobjectid
             WHERE llt.licensejobid = a_licensejobid
            ORDER BY 2, 1) t;

    RETURN t_ltcodes;
END getmart_cnct_lictypandstatus;
/


GRANT EXECUTE ON ABC.GETMART_CNCT_LICTYPANDSTATUS TO POSSEEXTENSIONS;

GRANT EXECUTE ON ABC.GETMART_CNCT_LICTYPANDSTATUS TO PUBLIC;
