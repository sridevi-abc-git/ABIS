CREATE OR REPLACE FUNCTION ABC.gen_firstrenewal_ltpenalty_tst(
    a_feeschedid   IN api.pkg_definition.udt_id,
    a_ismaster     IN VARCHAR2,
    a_dupcount     IN NUMBER)
    RETURN NUMBER
IS
    -- **************************************************************************
    -- File:        GEN_FIRSTRENEWAL_LTPENALTY_TST.FNC
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
    -- 08/21/2018 TJL         Initial Check-in
    -- **************************************************************************
    v_penalty   NUMBER := 0;
BEGIN
    BEGIN
        SELECT NVL(
                     DECODE(a_ismaster,
                            'Y', lfs.primaryamount - f.primaryamount,
                            0)
                   + a_dupcount * (lfs.secondaryamount - f.secondaryamount),
                   0)
                   penaltyamt
          INTO v_penalty
          FROM sitespecific.feeschedule_t f, sitespecific.feeschedule_t lfs
         WHERE f.objectid = a_feeschedid
           AND lfs.feeactivity = f.feeactivity || '50'
           AND (lfs.licensetypecode = f.licensetypecode
             OR lfs.licensetypecode IS NULL
            AND f.licensetypecode IS NULL)
           AND (lfs.effectivedate =
                (SELECT MAX(fs.effectivedate) effectivedate
                   FROM sitespecific.feeschedule_t fs
                  WHERE fs.feeactivity = f.feeactivity || '50'
                    AND (fs.licensetypecode = f.licensetypecode
                      OR (fs.licensetypecode IS NULL
                      AND f.licensetypecode IS NULL))
                    AND effectivedate <= f.effectivedate
                    AND (fs.gallonagerange = f.gallonagerange
                      OR (fs.gallonagerange IS NULL
                      AND f.gallonagerange IS NULL))
                    -- and (api.pkg_columnquery.Value(fs.objectid, 'NumberOfMonthsLicensedFeeCode') = F.NUMBEROFMONTHSLICENSED or
                    --   (api.pkg_columnquery.Value(fs.objectid, 'NumberOfMonthsLicensedFeeCode') is null and
                    AND (api.pkg_columnquery.VALUE(fs.objectid,
                                                   'NumberOfMonthsLicensed') =
                         f.numberofmonthslicensed
                      OR (api.pkg_columnquery.VALUE(fs.objectid,
                                                    'NumberOfMonthsLicensed')
                              IS NULL
                      AND f.numberofmonthslicensed IS NULL))
                    AND (fs.populationrange = f.populationrange
                      OR (fs.populationrange IS NULL
                      AND f.populationrange IS NULL))
                    AND (fs.otherfeecode = f.otherfeecode
                      OR (fs.otherfeecode IS NULL
                      AND f.otherfeecode IS NULL)))
             OR lfs.effectivedate IS NULL)
           AND (lfs.gallonagerange = f.gallonagerange
             OR (lfs.gallonagerange IS NULL
             AND f.gallonagerange IS NULL))
           AND (api.pkg_columnquery.VALUE(lfs.objectid,
                                          'NumberOfMonthsLicensed') =
                f.numberofmonthslicensed
             OR (api.pkg_columnquery.VALUE(lfs.objectid,
                                           'NumberOfMonthsLicensed')
                     IS NULL
             AND f.numberofmonthslicensed IS NULL))
           AND (lfs.populationrange = f.populationrange
             OR (lfs.populationrange IS NULL
             AND f.populationrange IS NULL))
           AND (lfs.otherfeecode = f.otherfeecode
             OR (lfs.otherfeecode IS NULL
             AND f.otherfeecode IS NULL));
    END;

    RETURN v_penalty;
END gen_firstrenewal_ltpenalty_tst;
/
