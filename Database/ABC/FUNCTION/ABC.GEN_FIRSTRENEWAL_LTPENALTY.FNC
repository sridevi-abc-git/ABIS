CREATE OR REPLACE FUNCTION ABC.gen_firstrenewal_ltpenalty(
    a_feeschedid   IN api.pkg_definition.udt_id,
    a_ismaster     IN VARCHAR2,
    a_dupcount     IN NUMBER)
    RETURN NUMBER
IS
    -- ****************************************************************************
    -- File:        Gen_FirstRenewal_LtPenalty.SQL
    -- Author:      ?
    --
    -- $Rev: 141 $
    -- $Date: 2018-11-16 08:44:02 -0800 (Fri, 16 Nov 2018) $
    -- Last Changed By:  $Author: TLord $
    --
    -- Description:
    --
    --
    -- History:
    -------------------------------------------------------------------------------
    --    Date                      Comment
    -- 11/30/2017 NW    11670   Current version in production
    -- 12/01/2017 NW    11670   Add logic for Bed and Breakfast 67,80 per room charge
    -- 11/16/2018 TJL   16785   Add NVL to handle for null values in columns
    -- ****************************************************************************

    v_penalty   NUMBER := 0;
BEGIN
    SELECT --  11/30/2017 NW - Add logic for Bed and Breakfast per room charge and upgrade the DECODE function to CASE
           --          NVL(DECODE(a_ismaster, 'Y', LFS.PRIMARYAMOUNT-F.PRIMARYAMOUNT, 0) +
           --               a_dupcount * (LFS.SECONDARYAMOUNT-F.SECONDARYAMOUNT),0)  PENALTYAMT
           CASE
               WHEN f.licensetypecode IN ('67', '80') THEN
                   CASE
                       WHEN f.secondaryamount * a_dupcount > f.primaryamount THEN -- Charge maximum fee found in feeschedule_t.primaryamount
                           lfs.primaryamount - f.primaryamount -- Difference between MAX amount = ( REN50 - REN )
                       ELSE
                             (lfs.secondaryamount - f.secondaryamount)
                           * a_dupcount -- Difference between (REN50 AND REN) multiplied by room count
                   END                                               -- case 2
               ELSE
                   NVL(
                         -- 11/16/2018 TJL WO 16785 Add NVL to handle for null values in columns
                         CASE
                             WHEN a_ismaster = 'Y' THEN
                                   NVL(lfs.primaryamount, 0)
                                 - NVL(f.primaryamount, 0)
                             ELSE
                                 0
                         END
                       +   a_dupcount
                         * (  NVL(lfs.secondaryamount, 0)
                            - NVL(f.secondaryamount, 0)),
                       0)
           END
               penaltyamt                          -- end case when type 67,80
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
       AND (api.pkg_columnquery.VALUE(lfs.objectid, 'NumberOfMonthsLicensed') =
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

    RETURN v_penalty;
END gen_firstrenewal_ltpenalty;
/


GRANT EXECUTE ON ABC.GEN_FIRSTRENEWAL_LTPENALTY TO POSSEEXTENSIONS;
