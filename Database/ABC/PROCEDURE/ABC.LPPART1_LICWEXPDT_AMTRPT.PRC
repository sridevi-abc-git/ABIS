CREATE OR REPLACE PROCEDURE ABC.lppart1_licwexpdt_amtrpt(
    a_jobid         api.pkg_definition.udt_id)
AS                                                --Parameter is License Batch
    -- **************************************************************************
    -- File:        LPPART1_LICWEXPDT_AMTRPT.PRC
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
    DELETE lppart1_licwexpdt_amt_gt;

    COMMIT;

    sitespecific.pkg_fees.getfeesforjob(a_jobid, NULL, t_feeobjectids);

    FOR i IN 1 .. t_feeobjectids.COUNT
    LOOP
        INSERT INTO lppart1_licwexpdt_amt_gt(licjobid,
                                             feeobjectid,
                                             feeid,
                                             licensetypenumber,
                                             totalowing,
                                             pen50)
            SELECT a_jobid,
                   f.objectid,
                   f.feeid,
                   f.licensetypenumber,
                   f.totalowing,                                 --total owing
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
                       pen50
              FROM query.o_fee  f
                   JOIN query.r_feelicensefeeschedule r
                       ON r.feeobjectid = f.objectid
                   LEFT OUTER JOIN query.o_feeschedule fs
                       ON fs.objectid = r.licensefeescheduleid
             WHERE f.objectid = t_feeobjectids(i).objectid;
    --         and f.totalowing > 0;
    END LOOP;
END lppart1_licwexpdt_amtrpt;
/


GRANT EXECUTE ON ABC.LPPART1_LICWEXPDT_AMTRPT TO POSSEEXTENSIONS;
