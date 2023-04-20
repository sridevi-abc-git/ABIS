CREATE OR REPLACE FUNCTION ABC.getmart_cnct_apptypandstatus(
    a_applicationjobid NUMBER)
    RETURN VARCHAR2
IS
    -- **************************************************************************
    -- File:        GETMART_CNCT_APPTYPANDSTATUS.FNC
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
    t_ltcodes   VARCHAR2(4000);
BEGIN
    SELECT concatlist(t.typeandstatus)
      INTO t_ltcodes
      FROM (SELECT plt.licensetypecode
                       ltcode,
                   'pri'
                       sort,
                   plt.licensetypecode || '-(' || plt.status || ')'
                       typeandstatus
              FROM mart.appapplicationtype  aplt
                   JOIN mart.applictype plt
                       ON plt.objectid = aplt.applicationtypeobjectid
             WHERE aplt.applicationjobid = a_applicationjobid
               AND plt.status IN ('PENDING',
                                  'DENIED',
                                  'WITHDRAWN',
                                  'ISSUE PENDING') --added to exclude voided and issued
            UNION ALL
            SELECT    ltc.licensetypecode
                   || CASE
                          WHEN slt.licensetypecount > 0 THEN
                              '[' || slt.licensetypecount || ']'
                      END
                       ltcode,
                   'sec'
                       sort,
                   ltc.licensetypecode || '-(' || slt.status || ')'
                       typeandstatus
              FROM mart.appapplicationtype  aplt
                   JOIN mart.primaryandsecondaryapplictype slt
                       ON slt.primlictypeobjectid =
                          aplt.applicationtypeobjectid
                   JOIN mart.licensetypecategory ltc
                       ON ltc.objectid = slt.liccategoryobjectid
             WHERE aplt.applicationjobid = a_applicationjobid
               AND slt.status IN ('PENDING',
                                  'DENIED',
                                  'WITHDRAWN',
                                  'ISSUE PENDING') -- added to exclude voided and issued
            ORDER BY 2, 1) t;

    RETURN t_ltcodes;
END getmart_cnct_apptypandstatus;
/


GRANT EXECUTE ON ABC.GETMART_CNCT_APPTYPANDSTATUS TO POSSEEXTENSIONS;

GRANT EXECUTE ON ABC.GETMART_CNCT_APPTYPANDSTATUS TO PUBLIC;
