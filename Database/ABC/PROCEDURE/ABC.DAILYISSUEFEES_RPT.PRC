CREATE OR REPLACE PROCEDURE ABC."DAILYISSUEFEES_RPT"(
    a_licjobid      api.pkg_definition.udt_id)
AS                                                --Parameter is License Batch
    -- **************************************************************************
    -- File:        DAILYISSUEFEES_RPT.PRC
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
    t_ptfeeobjectlist   api.udt_objectlist;
    t_jobid             NUMBER;
BEGIN
    t_jobid   := a_licjobid;

    DELETE FROM dailyissuefees_gt;

    --loop through all Licenses for License types for the License Batch.

    FOR license
        IN (SELECT DISTINCT l.licensejobid jobid               --license jobid
              FROM sitespecific.licbatchlictype_xref_t  lt --relationship from License Batch to License type
                   JOIN query.r_licenselicensetype l
                       ON l.licensetypejobid = lt.licensetypejobid --relationship from License Type to License
             WHERE lt.licensebatchjobid = a_licjobid)
    LOOP
        sitespecific.pkg_fees.getpaymenttransactionsforjob(license.jobid,
                                                           NULL,
                                                           t_ptfeeobjectlist);

        FOR c IN 1 .. t_ptfeeobjectlist.COUNT
        LOOP
            -- PAYMENT TRANSACTIONS  -- C,R,V,I  --josh to add D

            INSERT INTO dailyissuefees_gt(licjobid,
                                          ltlicnum,
                                          amounttype,
                                          paidamount,
                                          paiddate,
                                          feecode,
                                          trans)
                SELECT t_jobid,
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
                           amounttype,
                       ft.amount * -1
                           paidamount,
                       api.pkg_columnquery.datevalue(qpt.objectid,
                                                     'TransactionDate')
                           paiddate,
                       api.pkg_columnquery.VALUE(flfs.licensefeescheduleid,
                                                 'FeeCode')
                           feecode,
                       api.pkg_columnquery.VALUE(flfs.licensefeescheduleid,
                                                 'Description')
                           trans
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

            INSERT INTO dailyissuefees_gt(licjobid,
                                          ltlicnum,
                                          amounttype,
                                          paidamount,
                                          paiddate,
                                          feecode,
                                          trans)
                SELECT t_jobid,
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
                       CASE
                           WHEN ps.systemgenerated = 'Y' THEN 'G'
                           ELSE 'A'
                       END
                           amounttype,
                       CASE
                           WHEN api.pkg_columnquery.VALUE(ps.objectid,
                                                          'Status') =
                                'Earned' THEN
                               ft.amount * -1 --switch negative sign back if it does not work.
                           ELSE
                               ft.amount * 1
                       END
                           paidamount,
                       api.pkg_columnquery.datevalue(qpt.objectid,
                                                     'TransactionDate')
                           paiddate,
                       api.pkg_columnquery.VALUE(flfs.licensefeescheduleid,
                                                 'FeeCode')
                           feecode,
                       api.pkg_columnquery.VALUE(flfs.licensefeescheduleid,
                                                 'Description')
                           trans
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
                           ON pspt.paymenttransactionobjectid = qpt.objectid
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
        END LOOP;                                       --payment transactions
    END LOOP;                                                        --license

    --- Delete from above Global temp table those we don't want.

    DELETE FROM abc.dailyissuefees_gt
          WHERE ltlicnum NOT IN
                    (                              --get primary LTS for Batch
                     SELECT    SUBSTR(lt.licensetypecode, 1, 2)
                            || '-'
                            || SUBSTR(lt.licensenumber, 1, 6)
                                ltlicnum
                       FROM sitespecific.licbatchlictype_xref_t  r
                            JOIN query.j_licensetype lt
                                ON lt.jobid = r.licensetypejobid
                      WHERE r.licensebatchjobid = a_licjobid
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
                      WHERE ltlb.licensebatchjobid = a_licjobid);
END dailyissuefees_rpt;
/


GRANT EXECUTE ON ABC.DAILYISSUEFEES_RPT TO POSSEEXTENSIONS;
