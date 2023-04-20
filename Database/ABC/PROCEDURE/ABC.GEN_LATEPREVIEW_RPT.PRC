CREATE OR REPLACE PROCEDURE ABC.gen_latepreview_rpt(a_expdate IN DATE)
IS
    -- **************************************************************************
    -- File:        GEN_LATEPREVIEW_RPT.PRC
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
    DELETE FROM abc.latepreview_rpt
          WHERE expdate = a_expdate
             OR reportdate < TRUNC(SYSDATE);

    -- for testing only; global temporary tables will be used in production; no commit command is needed;
    --commit;  --uncommit back when done testing or use GTT

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
             WHERE --l.statusid in (select statusid from api.jobstatuses js1 where js1.jobtypeid = l.jobtypeid and js1.statustype in ('O','I'))
                   --and
                   --per Josh do not need to use l.statusid
                    lt.statusid IN (SELECT statusid
                                      FROM api.jobstatuses js2
                                     WHERE js2.jobtypeid = lt.jobtypeid
                                       AND js2.statustype IN ('O', 'I'))
               --and l.licensenumber in ('484814','478566','407407','258769','62033') --testing only bee
               AND lt.licensetypecode NOT IN ('49', '59', '60'))
    LOOP
        IF c_lictype.licensee IS NOT NULL THEN
            INSERT INTO abc.latepreview_rpt(filenum,
                                            licensee,
                                            status,
                                            district,
                                            ltcode,
                                            ltstatus,
                                            ltexpdate,
                                            ltfeecode,
                                            expdate,
                                            reportdate)
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
                       t_reportdate
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
                       t_reportdate
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
                INSERT INTO abc.latepreview_rpt(filenum,
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
                                                reportdate)
                    /*-- payment transactions  -- C,R,V,I */
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
                           t_reportdate
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
                       AND qpt.transactiondate >= ADD_MONTHS(t_expdate, -24)
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
                                   FROM abc.latepreview_rpt x
                                  WHERE x.filenum = c_lictype.filenum
                                    AND x.ltcode = qpt.licensetypecode
                                    AND ROWNUM = 1)
                         OR qpt.licensetypecode IS NULL);

                INSERT INTO abc.latepreview_rpt(filenum,
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
                                                reportdate)
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
                           t_reportdate
                      FROM query.o_paymenttransactions  qpt
                           JOIN api.paymenttransactions pt
                               ON pt.transactionid = qpt.transactionid
                           JOIN api.feetransactions ft
                               ON ft.transactionid = pt.transactionid
                           JOIN query.r_paymentstatuspaymenttrans pspt
                               ON pspt.paymenttransactionobjectid =
                                  qpt.objectid
                     WHERE qpt.objectid = t_ptobjectlist(i).objectid
                       AND NVL(qpt.paymentstatus, qpt.transactiondate) >=
                           ADD_MONTHS(t_expdate, -24)
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
                                   FROM abc.latepreview_rpt x
                                  WHERE x.filenum = c_lictype.filenum
                                    AND x.ltcode = qpt.licensetypecode
                                    AND ROWNUM = 1)
                         OR qpt.licensetypecode IS NULL);
            END LOOP;                   -- for i in 1..t_ptfeeobjectlist.count
        END IF;
    END LOOP;                                                 -- for c_lictype
-- for testing only; global temporary tables will be used in production; no commit command;
--commit; --uncommit back when done testing or use GTT

--delete seasonal lt's
--delete FROM abc.latepreview_rpt rt
--where rt.ltcode in ('49','59','60');

--commit; --uncommit back when done testing or use GTT
--*** seasonal............Bee
/*
for c_lictype in
     (select distinct l.jobid jobid, l.licensenumber filenum,LT.SEASONSTARTMONTH,to_char(LT.EXPIRATIONDATE,'YYYY'),trunc(LT.EXPIRATIONDATE),
             upper(nvl(l.primarylicensee,l.primarydba)) licensee,
             l.statusname status, l.basefileofficecodecorral district
      from --table(cast(api.pkg_simplesearch.castableobjectsbyindex('j_LicenseType', 'dup_ExpirationDate', to_char(t_expdate, 'YYYY-MM-DD')) as api.udt_objectlist)) x
      --join
      api.objects o --on o.objectid = x.objectid
      join query.j_licensetype lt on lt.jobid = o.objectid and lt.ObjectDefTypeId = 2 --this is used to tell the Oracle optimizer to use the correct index.
      join query.r_licenselicensetype r on r.LicenseTypeJobId = o.objectid
      join query.j_license l on l.jobid = r.licensejobid
      left outer join extension.jobstatuschange_t jsc on jsc.jobid = o.objectid and jsc.mostrecent = 'Y'
      where l.statusid in (select statusid from api.jobstatuses js1 where js1.jobtypeid = l.jobtypeid and js1.statustype in ('O','I'))
      and  lt.statusid in (select statusid from api.jobstatuses js2 where js2.jobtypeid = lt.jobtypeid and js2.statustype in ('O','I'))
      --and l.licensenumber='438316' -- in ('105552','305962')--,'478566','407407','258769','62033') --testing only bee
      and LT.LICENSETYPECODE in ('49','59','60')
      and trunc(LT.RENEWALDATE) = t_expdate


     ) loop

  if c_lictype.licensee is not null then
    insert into abc.latepreview_rpt
    (filenum, licensee, status, district, ltcode, ltstatus,
     ltexpdate, ltfeecode, expdate, reportdate)
    -- License Type - Primary
    select distinct c_lictype.filenum, c_lictype.licensee, c_lictype.status, c_lictype.district,
           lt.licensetypecode ltcode, lt.statusname ltstatus,
           trunc(lt.expirationdate) ltexpdate,
           nvl(lt.gallonagerangefeecode,'NA') ltfeecode, t_expdate, t_reportdate
    from   query.r_licenselicensetype rlt
    join   query.j_licensetype lt on lt.jobid = rlt.licensetypejobid
    join   api.jobstatuses js2 on js2.jobtypeid = lt.jobtypeid and js2.statusid = lt.statusid and js2.statustype in ('O','I')
    left   outer join extension.jobstatuschange_t jsc on jsc.jobid = lt.jobid and jsc.mostrecent = 'Y'
    where  rlt.licensejobid = c_lictype.jobid
    and    trunc(LT.RENEWALDATE) = t_expdate
    -- License Type - Secondary
    union
    select distinct c_lictype.filenum, c_lictype.licensee, c_lictype.status, c_lictype.district,
           oltc.LicenseTypeCode ltcode, SLT.STATUS ltstatus,
           trunc(lt.expirationdate) ltexpdate,
           nvl(lt.gallonagerangefeecode,'NA') ltfeecode, t_expdate, t_reportdate
    from   query.r_licenselicensetype rlt
    join   query.j_licensetype lt on lt.jobid = rlt.licensetypejobid
    join   query.r_licensetypeltcatsecondary slt on slt.licensetypejobid = lt.jobid
    join   query.o_licensetypecategory oltc on oltc.objectid = slt.licensetypecategoryobjectid
    join   api.jobstatuses js2 on js2.jobtypeid = lt.jobtypeid and js2.statusid = lt.statusid and js2.statustype in ('O','I')
    left   outer join extension.jobstatuschange_t jsc on jsc.jobid = lt.jobid and jsc.mostrecent = 'Y'
    where  rlt.licensejobid = c_lictype.jobid
    and    trunc(LT.RENEWALDATE) = t_expdate ;

    -- get objectid list for the pass parameter, jobid
    sitespecific.pkg_fees.getpaymenttransactionsforjob(c_lictype.jobid,null,t_PTObjectList);

    for i in 1..t_PTObjectList.count loop

      insert into abc.latepreview_rpt
      (filenum, licensee, ltcode, amttype, mi, dup, transfeecode,
       transcode, transamt, transdate, transtype, expdate, reportdate)
      -- payment transactions  -- C,R,V,I
      select distinct c_lictype.filenum licnum, c_lictype.licensee,
             qpt.licensetypecode ltcode, qpt.licensetypecode amttype,
             qpt.IsMaster mi, qpt.SecondaryCount dup, nvl(qpt.feecode,'NA') transfeecode,
             Case
                when qpt.isOverpayment = 'Y' then 'OVR'
                when qpt.IsServiceCharge = 'Y' then 'SRV'
                else qpt.feescheduletransactioncode
             end transcode,
             ft.amount * -1 transamt, trunc(qpt.transactiondate) transdate,
             qpt.CABINAmtType amounttype, t_expdate, t_reportdate
      from   query.o_paymenttransactions qpt
      join   api.paymenttransactions pt on pt.transactionid = qpt.transactionid
      join   table(cast(api.pkg_simplesearch.CastableObjectsByIndex('o_Payment', 'PaymentId', pt.PaymentId) as api.udt_objectlist)) x on 1 = 1
      join   api.feetransactions ft on ft.transactionid = pt.transactionid
      where  qpt.objectid = t_PTObjectList(i).objectid
      and    qpt.TransactionDate >= add_months(t_expdate, -24)
      and    qpt.feescheduletransactioncode not in ('BALFWD','CABCON','POIC','CATA','583', 'CAT','BKR','BKT')
      and    ( qpt.licensetypecode in (select x.ltcode from abc.latepreview_rpt x where x.filenum=c_lictype.filenum
                                       and X.LTCODE=qpt.licensetypecode and rownum=1)
               or qpt.licensetypecode is NULL )
      ;

      insert into abc.latepreview_rpt
      (filenum, licensee, ltcode, amttype, mi, dup, transfeecode,
       transcode, transamt, transdate, transtype, expdate, reportdate)
      -- payment transactions  -- g, a  (earned vs unearned)
      select distinct c_lictype.filenum licnum, c_lictype.licensee licensee,
             qpt.licensetypecode ltcode, qpt.licensetypecode amttype,
             qpt.IsMaster mi, qpt.SecondaryCount dup,
             nvl(qpt.feecode,'NA') transfeecode,
             Case when qpt.IsServiceCharge = 'Y' then 'SRV' else qpt.feescheduletransactioncode
             end transcode,
             case when upper(api.pkg_columnquery.Value(pspt.paymentStatusObjectid, 'Status')) = 'EARNED'
                  then ft.Amount * 1
                  else ft.Amount * -1
             end  transamt,
             trunc(nvl(qpt.paymentstatus,qpt.TransactionDate)) transdate,
             case when api.pkg_columnquery.Value(pspt.PaymentStatusObjectId, 'SystemGenerated') = 'Y'
                  then 'G' else 'A'
             end  transtype, t_expdate, t_reportdate
      from   query.o_paymenttransactions qpt
      join   api.paymenttransactions pt on pt.transactionid = qpt.transactionid
      join   api.feetransactions ft on ft.transactionid = pt.transactionid
      join   query.r_paymentstatuspaymenttrans pspt on pspt.paymenttransactionobjectid = qpt.objectid
      where  qpt.objectid = t_PTObjectList(i).objectid
      and    nvl(qpt.paymentstatus,qpt.TransactionDate) >= add_months(t_expdate, -24)
      and    qpt.feescheduletransactioncode not in ('BALFWD','CABCON','POIC','CATA','583', 'CAT','BKR','BKT')
      and    ( qpt.licensetypecode in (select x.ltcode from abc.latepreview_rpt x where x.filenum=c_lictype.filenum
                                       and X.LTCODE=qpt.licensetypecode and rownum=1)
               or qpt.licensetypecode is NULL )
      ;

    end loop;       -- for i in 1..t_ptfeeobjectlist.count

    end if;
  end loop;         -- for c_lictype

  -- for testing only; global temporary tables will be used in production; no commit command;
  --commit; --uncommit back when done testing or use GTT
---*****************
 */
END gen_latepreview_rpt;
/


GRANT EXECUTE ON ABC.GEN_LATEPREVIEW_RPT TO POSSEEXTENSIONS;

GRANT EXECUTE ON ABC.GEN_LATEPREVIEW_RPT TO PUBLIC;
