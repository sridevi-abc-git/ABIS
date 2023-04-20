CREATE OR REPLACE PROCEDURE ABC."LATE2NDNOTICE_AMTRPT"(
    a_jobid         api.pkg_definition.udt_id)
IS
    -- **************************************************************************
    -- File:        LATE2NDNOTICE_AMTRPT.PRC
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
    t_feeobjectids   api.udt_objectlist;
BEGIN
    DELETE late2ndnotice_amt_gt;

    COMMIT;

    FOR c
        IN (SELECT DISTINCT li.jobid
              FROM query.j_licensebatch  lb
                   JOIN sitespecific.licbatchlictype_xref_t ltlb
                       ON ltlb.licensebatchjobid = lb.jobid
                   JOIN query.j_licensetype lt
                       ON lt.jobid = ltlb.licensetypejobid
                   JOIN query.r_licenselicensetype lilt
                       ON lilt.licensetypejobid = lt.jobid
                   JOIN query.j_license li ON li.jobid = lilt.licensejobid
             WHERE lb.jobid = a_jobid
               AND lb.batchtype = '2ND RENEWAL NOTICES')
    LOOP
        sitespecific.pkg_fees.getfeesforjob(c.jobid, NULL, t_feeobjectids);

        FOR i IN 1 .. t_feeobjectids.COUNT
        LOOP
            INSERT INTO late2ndnotice_amt_gt(licjobid,
                                             feeobjectid,
                                             feeid,
                                             licensetypecode,
                                             quantity,
                                             description,
                                             totalowing,
                                             penalty)
                SELECT c.jobid,
                       f.objectid,
                       f.feeid,
                       fs.licensetypecode,
                       r.secondarycount,
                       (SELECT api.pkg_columnquery.VALUE(x.objectid,
                                                         'LicenseTypeName')
                          FROM TABLE(
                                   CAST(
                                       api.pkg_simplesearch.castableobjectsbyindex(
                                           'o_LicenseTypeCategory',
                                           'LicenseTypeCode',
                                           fs.licensetypecode) AS api.udt_objectlist))
                               x),                  --License Type Description
                       f.totalowing
                           totaldue,                             --total owing
                       CASE
                           WHEN fs.feeactivity = 'REN50' THEN
                                 f.amount
                               - sitespecific.pkg_fees.getltfeeamount(
                                     fs.effectivedate,
                                     'REN',
                                     fs.licensetypecode,
                                     fs.gallonagerange,
                                     NULL,
                                     fs.numberofmonthslicensed,
                                     fs.populationrange,
                                     DECODE(r.ismaster, 'Y', 'P', 'S'),
                                     r.secondarycount)
                           ELSE
                               0
                       END
                           penalty
                  FROM query.o_fee  f
                       JOIN query.r_feelicensefeeschedule r
                           ON r.feeobjectid = f.objectid
                       JOIN query.o_feeschedule fs
                           ON fs.objectid = r.licensefeescheduleid
                 WHERE f.objectid = t_feeobjectids(i).objectid
                   AND f.totalowing > 0;
        END LOOP;
    END LOOP;
END late2ndnotice_amtrpt;
/


GRANT EXECUTE ON ABC.LATE2NDNOTICE_AMTRPT TO POSSEEXTENSIONS;
