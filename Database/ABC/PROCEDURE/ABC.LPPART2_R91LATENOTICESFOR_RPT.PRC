CREATE OR REPLACE PROCEDURE ABC.lppart2_r91latenoticesfor_rpt(
    a_jobid         api.pkg_definition.udt_id)
AS                                                --Parameter is License Batch
    -- **************************************************************************
    -- File:        LPPART2_R91LATENOTICESFOR_RPT.PRC
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
    t_jobid          NUMBER;
BEGIN
    t_jobid   := a_jobid;

    DELETE FROM lppart2_r91latenoticesfor_gt;

    COMMIT;

    sitespecific.pkg_fees.getfeesforjob(a_jobid, NULL, t_feeobjectids);

    FOR i IN 1 .. t_feeobjectids.COUNT
    LOOP
        INSERT INTO lppart2_r91latenoticesfor_gt(licjobid,
                                                 feeobjectid,
                                                 feeid,
                                                 licensetypenumber,
                                                 totalowing,
                                                 adjustedamount)
            SELECT a_jobid,
                   f.objectid,
                   f.feeid,
                   (f.licensenumber + '-' + fs.licensetypecode) ltlicno,
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
END lppart2_r91latenoticesfor_rpt;
/


GRANT EXECUTE ON ABC.LPPART2_R91LATENOTICESFOR_RPT TO POSSEEXTENSIONS;
