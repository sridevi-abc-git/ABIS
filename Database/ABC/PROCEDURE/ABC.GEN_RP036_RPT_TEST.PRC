CREATE OR REPLACE PROCEDURE ABC.gen_rp036_rpt_test(a_expdate IN DATE)
IS
    -- **************************************************************************
    -- File:        GEN_RP036_RPT_TEST.PRC
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

    t_ptobjectlist   api.udt_objectlist;
    t_expdate        DATE := TRUNC(a_expdate);
    t_reportdate     DATE := TRUNC(SYSDATE);
BEGIN
    DELETE FROM abc.rp036_rpt_test
          WHERE expdate = a_expdate
             OR reportdate < TRUNC(SYSDATE);

    COMMIT;

    FOR c_lictype
        IN (SELECT DISTINCT
                   l.jobid                                     jobid,
                   l.licensenumber                             filenum,
                   UPPER(NVL(l.primarylicensee, l.primarydba)) licensee,
                   l.statusname                                status,
                   l.basefileofficecodecorral                  district
              FROM TABLE(
                       CAST(
                           api.pkg_simplesearch.castableobjectsbyindex(
                               'j_LicenseType',
                               'dup_ExpirationDate',
                               TO_CHAR(t_expdate, 'YYYY-MM-DD')) AS api.udt_objectlist))
                   x
                   JOIN api.objects o ON o.objectid = x.objectid
                   JOIN query.j_licensetype lt
                       ON lt.jobid = o.objectid
                      AND lt.objectdeftypeid = 2 --this is used to tell the Oracle optimizer to use the correct index.
                   JOIN query.r_licenselicensetype r
                       ON r.licensetypejobid = o.objectid
                   JOIN query.j_license l ON l.jobid = r.licensejobid
                   LEFT OUTER JOIN extension.jobstatuschange_t jsc
                       ON jsc.jobid = o.objectid
                      AND jsc.mostrecent = 'Y'
             WHERE l.statusid IN (SELECT statusid
                                    FROM api.jobstatuses js1
                                   WHERE js1.jobtypeid = l.jobtypeid
                                     AND js1.statustype IN ('O', 'I'))
               AND lt.statusid IN (SELECT statusid
                                     FROM api.jobstatuses js2
                                    WHERE js2.jobtypeid = lt.jobtypeid
                                      AND js2.statustype IN ('O', 'I'))--and l.licensenumber in ('475646','422931', '431389', '466888', '414243', '392149')
                                                                       )
    LOOP
        IF c_lictype.licensee IS NOT NULL THEN
            INSERT INTO abc.rp036_rpt_test(filenum,
                                           licensee,
                                           status,
                                           district,
                                           ltcode,
                                           ltstatus,
                                           ltexpdate,
                                           ltfeecode,
                                           expdate,
                                           reportdate,
                                           premcity)
                -- License Type - Primary
                SELECT DISTINCT
                       c_lictype.filenum,
                       c_lictype.licensee,
                       c_lictype.status,
                       c_lictype.district,
                       lt.licensetypecode                  ltcode,
                       lt.statusname                       ltstatus,
                       TRUNC(lt.expirationdate)            ltexpdate,
                       NVL(lt.gallonagerangefeecode, 'NA') ltfeecode,
                       t_expdate,
                       t_reportdate,
                       lt.premisescity
                  FROM query.r_licenselicensetype  rlt
                       JOIN query.j_licensetype lt
                           ON lt.jobid = rlt.licensetypejobid
                       JOIN api.jobstatuses js2
                           ON js2.jobtypeid = lt.jobtypeid
                          AND js2.statusid = lt.statusid
                          AND js2.statustype IN ('O', 'I')
                       LEFT OUTER JOIN extension.jobstatuschange_t jsc
                           ON jsc.jobid = lt.jobid
                          AND jsc.mostrecent = 'Y'
                 WHERE rlt.licensejobid = c_lictype.jobid
                   AND TRUNC(lt.expirationdate) = t_expdate
                -- License Type - Secondary
                UNION
                SELECT DISTINCT
                       c_lictype.filenum,
                       c_lictype.licensee,
                       c_lictype.status,
                       c_lictype.district,
                       oltc.licensetypecode                ltcode,
                       slt.status                          ltstatus,
                       TRUNC(lt.expirationdate)            ltexpdate,
                       NVL(lt.gallonagerangefeecode, 'NA') ltfeecode,
                       t_expdate,
                       t_reportdate,
                       lt.premisescity
                  FROM query.r_licenselicensetype  rlt
                       JOIN query.j_licensetype lt
                           ON lt.jobid = rlt.licensetypejobid
                       JOIN query.r_licensetypeltcatsecondary slt
                           ON slt.licensetypejobid = lt.jobid
                       JOIN query.o_licensetypecategory oltc
                           ON oltc.objectid = slt.licensetypecategoryobjectid
                       JOIN api.jobstatuses js2
                           ON js2.jobtypeid = lt.jobtypeid
                          AND js2.statusid = lt.statusid
                          AND js2.statustype IN ('O', 'I')
                       LEFT OUTER JOIN extension.jobstatuschange_t jsc
                           ON jsc.jobid = lt.jobid
                          AND jsc.mostrecent = 'Y'
                 WHERE rlt.licensejobid = c_lictype.jobid
                   AND TRUNC(lt.expirationdate) = t_expdate;

            -- get objectid list for the pass parameter, jobid
            sitespecific.pkg_fees.getpaymenttransactionsforjob(
                c_lictype.jobid,
                NULL,
                t_ptobjectlist);

            FOR i IN 1 .. t_ptobjectlist.COUNT
            LOOP
                INSERT INTO abc.rp036_rpt_test(filenum,
                                               licensee,
                                               ltcode,
                                               amttype,
                                               mi,
                                               dup,
                                               transfeecode,
                                               transcode,
                                               transamt,
                                               transdate,
                                               transtype,
                                               expdate,
                                               reportdate,
                                               record_type,
                                               premcity)
                    -- payment transactions  -- C,R,V,I
                    SELECT DISTINCT
                           c_lictype.filenum
                               licnum,
                           c_lictype.licensee,
                           qpt.licensetypecode
                               ltcode,
                           qpt.licensetypecode
                               amttype,
                           qpt.ismaster
                               mi,
                           qpt.secondarycount
                               dup,
                           NVL(qpt.feecode, 'NA')
                               transfeecode,
                           CASE
                               WHEN qpt.isoverpayment = 'Y' THEN 'OVR'
                               WHEN qpt.isservicecharge = 'Y' THEN 'SRV'
                               ELSE qpt.feescheduletransactioncode
                           END
                               transcode,
                           ft.amount * -1
                               transamt,
                           TRUNC(qpt.transactiondate)
                               transdate,
                           qpt.cabinamttype
                               amounttype,
                           t_expdate,
                           t_reportdate,
                           'xxx',
                           'premcity'
                      FROM query.o_paymenttransactions  qpt
                           JOIN api.paymenttransactions pt
                               ON pt.transactionid = qpt.transactionid
                           JOIN
                           TABLE(
                               CAST(
                                   api.pkg_simplesearch.castableobjectsbyindex(
                                       'o_Payment',
                                       'PaymentId',
                                       pt.paymentid) AS api.udt_objectlist))
                           x
                               ON 1 = 1
                           JOIN api.feetransactions ft
                               ON ft.transactionid = pt.transactionid
                     WHERE qpt.objectid = t_ptobjectlist(i).objectid
                       --and    qpt.TransactionDate >= add_months(t_expdate, -24)
                       AND qpt.feescheduletransactioncode NOT IN ('BALFWD',
                                                                  'CABCON',
                                                                  'POIC',
                                                                  'CATA',
                                                                  '583',
                                                                  'CAT',
                                                                  'BKR',
                                                                  'BKT')
                       AND (qpt.licensetypecode IN
                                (SELECT x.ltcode
                                   FROM abc.rp036_rpt_test x
                                  WHERE x.filenum = c_lictype.filenum
                                    AND x.ltcode = qpt.licensetypecode
                                    AND ROWNUM = 1)
                         OR qpt.licensetypecode IS NULL);

                INSERT INTO abc.rp036_rpt_test(filenum,
                                               licensee,
                                               ltcode,
                                               amttype,
                                               mi,
                                               dup,
                                               transfeecode,
                                               transcode,
                                               transamt,
                                               transdate,
                                               transtype,
                                               expdate,
                                               reportdate,
                                               record_type,
                                               premcity)
                    -- payment transactions  -- g, a  (earned vs unearned)
                    SELECT DISTINCT
                           c_lictype.filenum
                               licnum,
                           c_lictype.licensee
                               licensee,
                           qpt.licensetypecode
                               ltcode,
                           qpt.licensetypecode
                               amttype,
                           qpt.ismaster
                               mi,
                           qpt.secondarycount
                               dup,
                           NVL(qpt.feecode, 'NA')
                               transfeecode,
                           CASE
                               WHEN qpt.isoverpayment = 'Y' THEN 'OVR'
                               WHEN qpt.isservicecharge = 'Y' THEN 'SRV'
                               ELSE qpt.feescheduletransactioncode
                           END
                               transcode,
                           CASE
                               WHEN UPPER(
                                        api.pkg_columnquery.VALUE(
                                            pspt.paymentstatusobjectid,
                                            'Status')) =
                                    'EARNED' THEN
                                   ft.amount * 1
                               ELSE
                                   ft.amount * -1
                           END
                               transamt,
                           TRUNC(NVL(qpt.paymentstatus, qpt.transactiondate))
                               transdate,
                           CASE
                               WHEN api.pkg_columnquery.VALUE(
                                        pspt.paymentstatusobjectid,
                                        'SystemGenerated') =
                                    'Y' THEN
                                   'G'
                               ELSE
                                   'A'
                           END
                               transtype,
                           t_expdate,
                           t_reportdate,
                           'unearned',
                           'premcity'
                      FROM query.o_paymenttransactions  qpt
                           JOIN api.paymenttransactions pt
                               ON pt.transactionid = qpt.transactionid
                           JOIN api.feetransactions ft
                               ON ft.transactionid = pt.transactionid
                           JOIN query.r_paymentstatuspaymenttrans pspt
                               ON pspt.paymenttransactionobjectid =
                                  qpt.objectid
                     WHERE qpt.objectid = t_ptobjectlist(i).objectid
                       AND qpt.feescheduletransactioncode NOT IN ('BALFWD',
                                                                  'CABCON',
                                                                  'POIC',
                                                                  'CATA',
                                                                  '583',
                                                                  'CAT',
                                                                  'BKR',
                                                                  'BKT')
                       AND (qpt.licensetypecode IN
                                (SELECT x.ltcode
                                   FROM abc.rp036_rpt_test x
                                  WHERE x.filenum = c_lictype.filenum
                                    AND x.ltcode = qpt.licensetypecode
                                    AND ROWNUM = 1)
                         OR qpt.licensetypecode IS NULL)
                       AND UPPER(
                               api.pkg_columnquery.VALUE(
                                   pspt.paymentstatusobjectid,
                                   'Status')) =
                           'UNEARNED';
            END LOOP;                   -- for i in 1..t_ptfeeobjectlist.count
        END IF;
    END LOOP;                                                 -- for c_lictype

    -- update table to set other missing details
    UPDATE rp036_rpt_test r
       SET r.status   =
               (SELECT r1.status
                  FROM rp036_rpt_test r1
                 WHERE r1.filenum = r.filenum
                   AND r1.ltcode = r.ltcode
                   AND r1.status IS NOT NULL
                   AND r1.district IS NOT NULL
                   AND r1.ltstatus IS NOT NULL
                   AND r1.ltexpdate IS NOT NULL
                   AND r1.ltfeecode IS NOT NULL
                   AND ROWNUM = 1),
           r.district   =
               (SELECT r1.district
                  FROM rp036_rpt_test r1
                 WHERE r1.filenum = r.filenum
                   AND r1.ltcode = r.ltcode
                   AND r1.status IS NOT NULL
                   AND r1.district IS NOT NULL
                   AND r1.ltstatus IS NOT NULL
                   AND r1.ltexpdate IS NOT NULL
                   AND r1.ltfeecode IS NOT NULL
                   AND ROWNUM = 1),
           r.ltstatus   =
               (SELECT r1.ltstatus
                  FROM rp036_rpt_test r1
                 WHERE r1.filenum = r.filenum
                   AND r1.ltcode = r.ltcode
                   AND r1.status IS NOT NULL
                   AND r1.district IS NOT NULL
                   AND r1.ltstatus IS NOT NULL
                   AND r1.ltexpdate IS NOT NULL
                   AND r1.ltfeecode IS NOT NULL
                   AND ROWNUM = 1),
           r.ltexpdate   =
               (SELECT r1.ltexpdate
                  FROM rp036_rpt_test r1
                 WHERE r1.filenum = r.filenum
                   AND r1.ltcode = r.ltcode
                   AND r1.status IS NOT NULL
                   AND r1.district IS NOT NULL
                   AND r1.ltstatus IS NOT NULL
                   AND r1.ltexpdate IS NOT NULL
                   AND r1.ltfeecode IS NOT NULL
                   AND ROWNUM = 1),
           r.ltfeecode   =
               (SELECT r1.ltfeecode
                  FROM rp036_rpt_test r1
                 WHERE r1.filenum = r.filenum
                   AND r1.ltcode = r.ltcode
                   AND r1.status IS NOT NULL
                   AND r1.district IS NOT NULL
                   AND r1.ltstatus IS NOT NULL
                   AND r1.ltexpdate IS NOT NULL
                   AND r1.ltfeecode IS NOT NULL
                   AND ROWNUM = 1),
           r.premcity   =
               (SELECT r1.premcity
                  FROM rp036_rpt_test r1
                 WHERE r1.filenum = r.filenum
                   AND r1.ltcode = r.ltcode
                   AND r1.status IS NOT NULL
                   AND r1.district IS NOT NULL
                   AND r1.ltstatus IS NOT NULL
                   AND r1.ltexpdate IS NOT NULL
                   AND r1.ltfeecode IS NOT NULL
                   AND ROWNUM = 1)
     WHERE r.status IS NULL
       AND r.district IS NULL
       AND r.ltstatus IS NULL
       AND r.ltexpdate IS NULL
       AND r.ltfeecode IS NULL;

    COMMIT;
END gen_rp036_rpt_test;
/


GRANT EXECUTE ON ABC.GEN_RP036_RPT_TEST TO POSSEEXTENSIONS;

GRANT EXECUTE ON ABC.GEN_RP036_RPT_TEST TO PUBLIC;
