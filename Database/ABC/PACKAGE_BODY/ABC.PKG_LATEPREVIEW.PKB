CREATE OR REPLACE PACKAGE BODY ABC."PKG_LATEPREVIEW"
IS
    -- **************************************************************************
    -- File:        PKG_LATEPREVIEW.PKB
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
    -------------------------------------
    --     Populate temp table with data
    -------------------------------------
    PROCEDURE late2ndnotice_amtrpt_pkg(a_jobid udt_id)
    IS
        t_feeobjectids   api.udt_objectlist;
    BEGIN
        DELETE abc.late2ndnotice_amt_gt;

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
                       JOIN query.j_license li
                           ON li.jobid = lilt.licensejobid
                 WHERE lb.jobid = a_jobid--and LB.BATCHTYPE = '2ND RENEWAL NOTICES' -- I am not sure if this is correct. in the infomaker report is says it must = '50% PENALTY'??
                                         )
        LOOP
            sitespecific.pkg_fees.getfeesforjob(c.jobid,
                                                NULL,
                                                t_feeobjectids);

            FOR i IN 1 .. t_feeobjectids.COUNT
            LOOP
                INSERT INTO abc.late2ndnotice_amt_gt(licjobid,
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
                           (SELECT api.pkg_columnquery.VALUE(
                                       x.objectid,
                                       'LicenseTypeName')
                              FROM TABLE(
                                       CAST(
                                           api.pkg_simplesearch.castableobjectsbyindex(
                                               'o_LicenseTypeCategory',
                                               'LicenseTypeCode',
                                               fs.licensetypecode) AS api.udt_objectlist))
                                   x),              --License Type Description
                           f.totalowing
                               totaldue,                         --total owing
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
    END late2ndnotice_amtrpt_pkg;

    --

    PROCEDURE listlatelicensesrpt_pkg(a_jobid udt_id)
    AS                                            --Parameter is License Batch
        t_ptfeeobjectlist   api.udt_objectlist;
        t_jobid             NUMBER;
    BEGIN
        t_jobid   := a_jobid;

        DELETE FROM abc.listlatelicensesrpt_t;

        COMMIT;

        --loop through all Licenses for License types for the License Batch.

        FOR license
            IN (SELECT DISTINCT l.licensejobid jobid           --license jobid
                  FROM sitespecific.licbatchlictype_xref_t  lt --relationship from License Batch to License type
                       JOIN query.r_licenselicensetype l
                           ON l.licensetypejobid = lt.licensetypejobid --relationship from License Type to License
                 WHERE lt.licensebatchjobid = a_jobid)
        LOOP
            sitespecific.pkg_fees.getpaymenttransactionsforjob(
                license.jobid,
                NULL,
                t_ptfeeobjectlist);

            FOR c IN 1 .. t_ptfeeobjectlist.COUNT
            LOOP
                -- PAYMENT TRANSACTIONS  -- C,R,V,I  --josh to add D

                INSERT INTO abc.listlatelicensesrpt_t(jobid,
                                                      lb_jobid,
                                                      li_license,
                                                      ltlicnum,
                                                      li_primlicee,
                                                      amounttype,
                                                      feeschtrancd,
                                                      ltcode,
                                                      masterind,
                                                      lt_dupct,
                                                      amount,
                                                      amtdate,
                                                      lt_feeschcd)
                    SELECT j.jobid,
                           t_jobid,
                           api.pkg_columnquery.VALUE(j.jobid,
                                                     'LicenseNumber')
                               licnum,
                              SUBSTR(
                                  api.pkg_columnquery.VALUE(
                                      flfs.licensefeescheduleid,
                                      'LicenseTypeCode'),
                                  1,
                                  2)
                           || '-'
                           || SUBSTR(
                                  api.pkg_columnquery.VALUE(j.jobid,
                                                            'LicenseNumber'),
                                  1,
                                  6)
                               ltlicnum,
                           api.pkg_columnquery.VALUE(j.jobid,
                                                     'PrimaryLicensee')
                               licenseename,
                           CASE
                               WHEN (SELECT COUNT(*)
                                       FROM api.relationships r
                                      WHERE r.fromobjectid = x.objectid
                                        AND r.endpointid IN
                                                (api.pkg_configquery.endpointidforname(
                                                     'o_Payment',
                                                     'PaymentTransferAdjust'),
                                                 api.pkg_configquery.endpointidforname(
                                                     'o_Payment',
                                                     'PaymentTransferTo'))) >
                                    0 THEN
                                   'C'
                               WHEN (SELECT COUNT(*)
                                       FROM api.relationships r
                                      WHERE r.fromobjectid = x.objectid
                                        AND r.endpointid =
                                            api.pkg_configquery.endpointidforname(
                                                'o_Payment',
                                                'RefundCheck')) >
                                    0 THEN
                                   'R'
                               WHEN (SELECT COUNT(*)
                                       FROM api.relationships r
                                      WHERE r.fromobjectid = x.objectid
                                        AND r.endpointid =
                                            api.pkg_configquery.endpointidforname(
                                                'o_Payment',
                                                'VoidPayment')) >
                                    0 THEN
                                   'V'
                               ELSE
                                   'I'
                           END
                               i,
                           api.pkg_columnquery.VALUE(
                               flfs.licensefeescheduleid,
                               'Description')
                               trans,
                           api.pkg_columnquery.VALUE(
                               flfs.licensefeescheduleid,
                               'LicenseTypeCode')
                               lt,
                           flfs.ismaster
                               m,
                           flfs.secondarycount
                               dup,
                           ft.amount * -1
                               amount,
                           api.pkg_columnquery.datevalue(qpt.objectid,
                                                         'TransactionDate')
                               paiddate,
                           api.pkg_columnquery.VALUE(
                               flfs.licensefeescheduleid,
                               'FeeCode')
                               feecode
                      FROM query.o_paymenttransactions  qpt
                           JOIN api.paymenttransactions pt
                               ON pt.transactionid = qpt.transactionid
                           JOIN api.payments p ON p.paymentid = pt.paymentid
                           JOIN
                           TABLE(
                               CAST(
                                   api.pkg_simplesearch.castableobjectsbyindex(
                                       'o_Payment',
                                       'PaymentId',
                                       p.paymentid) AS api.udt_objectlist)) x
                               ON 1 = 1
                           JOIN api.feetransactions ft
                               ON ft.transactionid = pt.transactionid
                           JOIN api.fees f ON f.feeid = ft.feeid
                           JOIN api.jobs j ON j.jobid = f.jobid
                           JOIN
                           TABLE(
                               CAST(
                                   api.pkg_simplesearch.castableobjectsbyindex(
                                       'o_Fee',
                                       'FeeId',
                                       f.feeid) AS api.udt_objectlist)) z
                               ON 1 = 1
                           JOIN query.r_feelicensefeeschedule flfs
                               ON flfs.feeobjectid = z.objectid
                     WHERE qpt.objectid = t_ptfeeobjectlist(c).objectid;

                -- PAYMENT TRANSACTIONS  -- G, A  (earned vs unearned)
                INSERT INTO abc.listlatelicensesrpt_t(jobid,
                                                      lb_jobid,
                                                      li_license,
                                                      ltlicnum,
                                                      li_primlicee,
                                                      amounttype,
                                                      feeschtrancd,
                                                      ltcode,
                                                      masterind,
                                                      lt_dupct,
                                                      amount,
                                                      amtdate,
                                                      lt_feeschcd)
                    SELECT j.jobid,
                           t_jobid,
                           api.pkg_columnquery.VALUE(j.jobid,
                                                     'LicenseNumber')
                               licnum,
                              SUBSTR(
                                  api.pkg_columnquery.VALUE(
                                      flfs.licensefeescheduleid,
                                      'LicenseTypeCode'),
                                  1,
                                  2)
                           || '-'
                           || SUBSTR(
                                  api.pkg_columnquery.VALUE(j.jobid,
                                                            'LicenseNumber'),
                                  1,
                                  6)
                               ltlicnum,
                           api.pkg_columnquery.VALUE(j.jobid,
                                                     'PrimaryLicensee')
                               licenseename,
                           CASE
                               WHEN ps.systemgenerated = 'Y' THEN 'G'
                               ELSE 'A'
                           END
                               i,
                           api.pkg_columnquery.VALUE(
                               flfs.licensefeescheduleid,
                               'Description')
                               trans,
                           api.pkg_columnquery.VALUE(
                               flfs.licensefeescheduleid,
                               'LicenseTypeCode')
                               lt,
                           flfs.ismaster
                               m,
                           flfs.secondarycount
                               dup,
                           CASE
                               WHEN api.pkg_columnquery.VALUE(ps.objectid,
                                                              'Status') =
                                    'Earned' THEN
                                   ft.amount * -1 --switch negative sign back if it does not work.
                               ELSE
                                   ft.amount * 1
                           END
                               amount,
                           api.pkg_columnquery.datevalue(qpt.objectid,
                                                         'TransactionDate')
                               paiddate,
                           api.pkg_columnquery.VALUE(
                               flfs.licensefeescheduleid,
                               'FeeCode')
                               feecode
                      FROM query.o_paymenttransactions  qpt
                           JOIN api.paymenttransactions pt
                               ON pt.transactionid = qpt.transactionid
                           JOIN api.payments p ON p.paymentid = pt.paymentid
                           JOIN
                           TABLE(
                               CAST(
                                   api.pkg_simplesearch.castableobjectsbyindex(
                                       'o_Payment',
                                       'PaymentId',
                                       p.paymentid) AS api.udt_objectlist)) x
                               ON 1 = 1
                           JOIN query.r_paymentstatuspaymenttrans pspt
                               ON pspt.paymenttransactionobjectid =
                                  qpt.objectid
                           JOIN query.o_paymentstatus ps
                               ON ps.objectid = pspt.paymentstatusobjectid -- displayse G and A records.  Earned vs unearned.  may be negative or positive.
                           JOIN api.feetransactions ft
                               ON ft.transactionid = pt.transactionid
                           JOIN api.fees f ON f.feeid = ft.feeid
                           JOIN
                           TABLE(
                               CAST(
                                   api.pkg_simplesearch.castableobjectsbyindex(
                                       'o_Fee',
                                       'FeeId',
                                       f.feeid) AS api.udt_objectlist)) z
                               ON 1 = 1
                           JOIN query.r_feelicensefeeschedule flfs
                               ON flfs.feeobjectid = z.objectid
                           JOIN api.jobs j ON j.jobid = f.jobid
                     WHERE qpt.objectid = t_ptfeeobjectlist(c).objectid;
            END LOOP;                                   --payment transactions
        END LOOP;                                                    --license

        --- Delete from above Global temp table those we don't want.

        DELETE FROM abc.listlatelicensesrpt_t
              WHERE ltlicnum NOT IN
                        (                          --get primary LTS for Batch
                         SELECT    SUBSTR(lt.licensetypecode, 1, 2)
                                || '-'
                                || SUBSTR(lt.licensenumber, 1, 6)
                                    ltlicnum
                           FROM sitespecific.licbatchlictype_xref_t  r
                                JOIN query.j_licensetype lt
                                    ON lt.jobid = r.licensetypejobid
                          WHERE r.licensebatchjobid = a_jobid
                         UNION
                         --get secondary LTS for batch
                         SELECT    SUBSTR(oltc.licensetypecode, 1, 2)
                                || '-'
                                || SUBSTR(lt.licensenumber, 1, 6)
                                    ltlicnum
                           FROM sitespecific.licbatchlictype_xref_t  ltlb
                                JOIN query.j_licensetype lt
                                    ON lt.jobid = ltlb.licensetypejobid
                                JOIN query.r_licenselicensetype lilt
                                    ON lilt.licensetypejobid = lt.jobid
                                JOIN query.j_license li
                                    ON li.jobid = lilt.licensejobid
                                JOIN query.r_licensetypeltcatsecondary slt
                                    ON slt.licensetypejobid = lt.jobid
                                JOIN query.o_licensetypecategory oltc
                                    ON oltc.objectid =
                                       slt.licensetypecategoryobjectid
                          WHERE ltlb.licensebatchjobid = a_jobid);
    END listlatelicensesrpt_pkg;

    ---
    PROCEDURE lppart1_licwexpdt_amtrpt_pkg(a_jobid udt_id)
    AS                                            --Parameter is License Batch
        t_feeobjectids   api.udt_objectlist;
    BEGIN
        DELETE abc.lppart1_licwexpdt_amt_gt;

        COMMIT;

        FOR lt
            IN (SELECT DISTINCT li.jobid
                  FROM query.j_licensebatch  lb
                       JOIN sitespecific.licbatchlictype_xref_t ltlb
                           ON ltlb.licensebatchjobid = lb.jobid
                       JOIN query.j_licensetype lt
                           ON lt.jobid = ltlb.licensetypejobid
                       JOIN query.r_licenselicensetype lilt
                           ON lilt.licensetypejobid = lt.jobid
                       JOIN query.j_license li
                           ON li.jobid = lilt.licensejobid
                 WHERE lb.jobid = a_jobid/*select distinct ltlb.LicenseTypeJobId  jobid --license type jobid
                                                      from query.R_LICTYPEINLICBATCH ltlb--relationship from License Batch to License type
                                                     where ltlb.LICENSEBATCHJOBID = a_JobId*/
                                         )
        LOOP
            sitespecific.pkg_fees.getfeesforjob(lt.jobid,
                                                NULL,
                                                t_feeobjectids);

            FOR i IN 1 .. t_feeobjectids.COUNT
            LOOP
                INSERT INTO abc.lppart1_licwexpdt_amt_gt(licjobid,
                                                         feeobjectid,
                                                         feeid,
                                                         licensetypenumber,
                                                         totalowing,
                                                         pen50)
                    SELECT f.jobid,
                           f.objectid,
                           f.feeid,
                           f.licensetypenumber,
                           f.totalowing,                         --total owing
                           CASE
                               WHEN fs.feeactivity = 'REN50' THEN
                                     f.amount
                                   - sitespecific.pkg_fees.getltfeeamount(
                                         fs.effectivedate,
                                         'REN',
                                         fs.licensetypecode,
                                         fs.gallonagerange,
                                         fs.numberofmonthslicensed,
                                         fs.populationrange,
                                         DECODE(r.ismaster, 'Y', 'P', 'S'),
                                         r.secondarycount,
                                         NULL)
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
        END LOOP;                                         -- end GetGeesForJob
    END lppart1_licwexpdt_amtrpt_pkg;

    --

    PROCEDURE lppart2_r91latnotfor_rpt_pkg(a_jobid udt_id)
    AS                                            --Parameter is License Batch
        t_feeobjectids   api.udt_objectlist;
        t_jobid          NUMBER;
    BEGIN
        t_jobid   := a_jobid;

        DELETE FROM abc.lppart2_r91latenoticesfor_gt;

        COMMIT;

        FOR lt
            IN (SELECT DISTINCT li.jobid
                  FROM query.j_licensebatch  lb
                       JOIN sitespecific.licbatchlictype_xref_t ltlb
                           ON ltlb.licensebatchjobid = lb.jobid
                       JOIN query.j_licensetype lt
                           ON lt.jobid = ltlb.licensetypejobid
                       JOIN query.r_licenselicensetype lilt
                           ON lilt.licensetypejobid = lt.jobid
                       JOIN query.j_license li
                           ON li.jobid = lilt.licensejobid
                 WHERE lb.jobid = a_jobid/*select distinct ltlb.LicenseTypeJobId  jobid --license type jobid
                                             from query.R_LICTYPEINLICBATCH ltlb--relationship from License Batch to License type
                                            where ltlb.LICENSEBATCHJOBID = a_JobId*/
                                         )
        LOOP
            sitespecific.pkg_fees.getfeesforjob(lt.jobid,
                                                NULL,
                                                t_feeobjectids);

            FOR i IN 1 .. t_feeobjectids.COUNT
            LOOP
                INSERT INTO abc.lppart2_r91latenoticesfor_gt(
                                licjobid,
                                feeobjectid,
                                feeid,
                                licensetypenumber,
                                totalowing,
                                adjustedamount)
                    SELECT f.jobid,
                           f.objectid,
                           f.feeid,
                           (f.licensenumber || '-' || fs.licensetypecode)
                               ltlicno,
                           f.totalowing,                         --total owing
                           f.adjustedamount
                      FROM query.o_fee  f
                           JOIN query.r_feelicensefeeschedule r
                               ON r.feeobjectid = f.objectid
                           LEFT OUTER JOIN query.o_feeschedule fs
                               ON fs.objectid = r.licensefeescheduleid
                     WHERE f.objectid = t_feeobjectids(i).objectid;
            --         and f.totalowing > 0;
            END LOOP;
        END LOOP;                                     -- end license type loop
    END lppart2_r91latnotfor_rpt_pkg;
--
END pkg_latepreview;
/


GRANT EXECUTE ON ABC.PKG_LATEPREVIEW TO POSSEEXTENSIONS;
