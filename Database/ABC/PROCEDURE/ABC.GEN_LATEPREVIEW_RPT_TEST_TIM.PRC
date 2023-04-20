CREATE OR REPLACE PROCEDURE ABC.gen_latepreview_rpt_test_tim(
    a_expdate      IN DATE)
IS
    -- **************************************************************************
    -- File:        GEN_LATEPREVIEW_RPT_TEST_TIM.PRC
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
    DELETE FROM abc.latepreview_rpt_test;

    -- for testing only; global temporary tables will be used in production; no commit command is needed;
    COMMIT;                       --uncommit back when done testing or use GTT

    FOR c_lictype
        IN (SELECT DISTINCT
                   jap.jobid                                       jobid,
                   jap.licensenumber                               filenum,
                   UPPER(NVL(jap.primarylicensee, jap.primarydba)) licensee,
                   jap.prioritystatus                              status,
                   jap.basefileofficename                          district
              /*
              Select JAP.JOBID app_jobid,JAP.OBJECTID app_objectid,
              opl.OBJECTID o_primlt_objectid, JAP.LICENSEENAMES, JAP.PRIMARYDBA
              OPL.LICENSETYPECODE LicType,
              JAP.LICENSENUMBER FileNum,
              JAP.JOBSTATUS Status,JAP.STATUSDATE,JAP.STATUSNAME,JAP.APPLICANTTYPE,JAP.CREATEDDATE app_createddate,
              JAP.ENTERAPPLICATIONCOMPLETEDDATE , JAP.ISPRIORITYDRAWWINNER, JAP.ISSUEDATE,JAP.ISSUETYPE,JAP.PRIORITYAPPLICATIONTYPE,
              JAP.PRIORITYDRAWRESULT,JAP.PRIORITYUPGRADE,
              JAP.BASEFILEOFFICECORRAL,
              JAP.BASEFILEOFFICENAME,
              JAP.COUNTYNAME,
              JAP.PRIORITYDRAWCOUNTY DrawCounty,
              JAP.PRIORITYISTRANSFERRED IC,
              case when JAP.INTERCOUNTYONSALEGENERAL = 'Y' then 'Intercounty On-Sale'
              when JAP.INTERCOUNTYOFFSALEGENERAL = 'Y' then 'Intercounty Off-Sale'
              when JAP.ORIGINALONSALEGENERAL = 'Y' then 'Original On-Sale'
              when JAP.ORIGINALOFFSALEGENERAL ='Y' then 'Original Off-Sale'
              else null
              end PType,
              JAP.PRIORITYRANK P_Rank,
              JAP.PRIORITYSTATUS P_Status,
              JAP.PRIORITYDRAWINGDATE DrawDate,
              JAP.PRIMARYLICENSEE Primary_Name,
              JAP.PREMADDRESS4LINE Prem_Address */
              FROM query.j_application  jap
                   JOIN query.r_appprimarylicensetype ral
                       ON ral.applicationobjectid = jap.objectid
                   JOIN query.o_primarylicensetype opl
                       ON opl.objectid = ral.licensetypeobjectid
             --  Join query.R_MANAGEPRIORITYAPPSAPP RMPA on JAP.JOBID = RMPA.APPLICATIONJOBID
             --  Join query.J_MANAGEPRIORITYAPPLICATIONS MPA on RMPA.MANAGEPRIORITYAPPSJOBID = MPA.JOBID
             WHERE jap.ispriorityapplication = 'Y'
               --and JAP.PRIORITYSTATUS='WINNER'
               --and JAP.JOBSTATUS = 'ISSUED'
               --and JAP.OBJECTID in (51364633,51498327,51372973,51488801)
               AND jap.prioritydrawingdate BETWEEN TO_DATE('01/01/2010',
                                                           'mm/dd/yyyy')
                                               AND TO_DATE('12/31/2010',
                                                           'mm/dd/yyyy'))
    LOOP
        ---------------------------
        IF c_lictype.jobid IS NOT NULL THEN
            INSERT INTO abc.latepreview_rpt_test(filenum,
                                                 licensee,
                                                 status,
                                                 district,
                                                 ltcode,
                                                 ltstatus,
                                                 ltexpdate,
                                                 ltfeecode,
                                                 expdate,
                                                 reportdate)
                SELECT DISTINCT c_lictype.filenum,
                                c_lictype.licensee,
                                c_lictype.status,
                                c_lictype.district,
                                jlt.licensetypecode
                                    ltcode,
                                jlt.statusname
                                    ltstatus,
                                jlt.expirationdate
                                    ltexpdate,
                                NULL,
                                (SELECT js.effectivestartdate
                                   FROM extension.jobstatuschange_t js
                                  WHERE js.jobid = jlt.jobid
                                    AND js.mostrecent = 'Y')
                                    expdate,             --this is STATUSDATE,
                                jlt.issuedate
                                    reportdate          --this is LT_ISSUEDATE
                  FROM query.j_license  l
                       JOIN query.r_licenselicensetype rllt
                           ON rllt.licensejobid = l.jobid
                       JOIN query.j_licensetype jlt
                           ON jlt.jobid = rllt.licensetypejobid
                 WHERE l.externalfilenum = c_lictype.filenum
                   AND jlt.issuedate BETWEEN TO_DATE('01/01/2010',
                                                     'mm/dd/yyyy')
                                         AND TO_DATE('12/31/2010',
                                                     'mm/dd/yyyy')
                --and l.objectid=19368615 --and l.LICENSENUMBER= '487305'
                UNION
                SELECT DISTINCT c_lictype.filenum,
                                c_lictype.licensee,
                                c_lictype.status,
                                c_lictype.district,
                                oltc.licensetypecode
                                    ltcode,
                                NVL(slt.status, jlt2.jobstatus)
                                    ltstatus,
                                jlt2.expirationdate
                                    ltexpdate,
                                NULL,                              --ltfeecode
                                NVL(slt.statusdate,
                                    (SELECT js.effectivestartdate
                                       FROM extension.jobstatuschange_t js
                                      WHERE js.jobid = jlt2.jobid
                                        AND js.mostrecent = 'Y'))
                                    expdate,             --this is STATUSDATE,
                                NVL(slt.issuedate, jlt2.issuedate)
                                    reportdate          --this is LT_ISSUEDATE
                  FROM query.j_license  l2
                       JOIN query.r_licenselicensetype rllt2
                           ON rllt2.licensejobid = l2.jobid
                       JOIN query.j_licensetype jlt2
                           ON jlt2.jobid = rllt2.licensetypejobid
                       JOIN query.r_licensetypeltcatsecondary slt
                           ON slt.licensetypejobid = jlt2.jobid
                       JOIN query.o_licensetypecategory oltc
                           ON oltc.objectid = slt.licensetypecategoryobjectid
                 WHERE l2.externalfilenum = c_lictype.filenum
                   AND NVL(slt.issuedate, jlt2.issuedate) BETWEEN TO_DATE(
                                                                      '01/01/2010',
                                                                      'mm/dd/yyyy')
                                                              AND TO_DATE(
                                                                      '12/31/2010',
                                                                      'mm/dd/yyyy');

            sitespecific.pkg_fees.getpaymenttransactionsforjob(
                c_lictype.jobid,
                NULL,
                t_ptobjectlist);

            FOR i IN 1 .. t_ptobjectlist.COUNT
            LOOP
                INSERT INTO abc.latepreview_rpt_test(filenum,
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
                       --and    qpt.TransactionDate >= add_months(t_expdate, -24)
                       --and    qpt.feescheduletransactioncode not in ('BALFWD','CABCON','POIC','CATA','583', 'CAT','BKR','BKT')
                       AND (qpt.licensetypecode IN
                                (SELECT x.ltcode
                                   FROM abc.latepreview_rpt_test x
                                  WHERE x.filenum = c_lictype.filenum
                                    AND x.ltcode = qpt.licensetypecode
                                    AND ROWNUM = 1)
                         OR qpt.licensetypecode IS NULL);

                INSERT INTO abc.latepreview_rpt_test(filenum,
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
                       --and    nvl(qpt.paymentstatus,qpt.TransactionDate) >= add_months(t_expdate, -24)
                       --and    qpt.feescheduletransactioncode not in ('BALFWD','CABCON','POIC','CATA','583', 'CAT','BKR','BKT')
                       AND (qpt.licensetypecode IN
                                (SELECT x.ltcode
                                   FROM abc.latepreview_rpt_test x
                                  WHERE x.filenum = c_lictype.filenum
                                    AND x.ltcode = qpt.licensetypecode
                                    AND ROWNUM = 1)
                         OR qpt.licensetypecode IS NULL);
            END LOOP;                   -- for i in 1..t_ptfeeobjectlist.count
        END IF;
    END LOOP;                                                 -- for c_lictype

    COMMIT;                       --uncommit back when done testing or use GTT
END gen_latepreview_rpt_test_tim;
/
