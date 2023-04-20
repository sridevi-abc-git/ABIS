CREATE OR REPLACE PROCEDURE ABC.firstrenewal_due4ren_amtrpt(
    a_lbjobid       api.pkg_definition.udt_id)
AS                                                --Parameter is License Batch
    -- **************************************************************************
    -- File:        FIRSTRENEWAL_DUE4REN_AMTRPT.PRC
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
    -- 08/20/2018 TJL         Initial Check-in
    -- **************************************************************************

    t_feeobjectids   api.udt_objectlist;
    t_jobid          NUMBER;
BEGIN
    t_jobid   := a_lbjobid;

    DELETE FROM firstrenewal_due4ren_amt_gt;

    COMMIT;

    sitespecific.pkg_fees.getfeesforjob(a_lbjobid, NULL, t_feeobjectids);

    FOR i IN 1 .. t_feeobjectids.COUNT
    LOOP
        INSERT INTO firstrenewal_due4ren_amt_gt(licjobid,
                                                feeobjectid,
                                                feeid,
                                                licensetypenumber,
                                                totalowing,
                                                adjustedamount)
            SELECT a_lbjobid,
                   f.objectid,
                   f.feeid,
                     SUBSTR(fs.licensetypecode, 1, 2)
                   + '-'
                   + SUBSTR(f.licensenumber, 1, 6)
                       ltlicno,
                   f.totalowing,                                 --total owing
                   f.adjustedamount
              FROM query.o_fee  f
                   JOIN query.r_feelicensefeeschedule r
                       ON r.feeobjectid = f.objectid
                   LEFT OUTER JOIN query.o_feeschedule fs
                       ON fs.objectid = r.licensefeescheduleid
             WHERE f.objectid = t_feeobjectids(i).objectid;
    --         and f.totalowing > 0;
    END LOOP;
END firstrenewal_due4ren_amtrpt;
/


GRANT EXECUTE ON ABC.FIRSTRENEWAL_DUE4REN_AMTRPT TO POSSEEXTENSIONS;
