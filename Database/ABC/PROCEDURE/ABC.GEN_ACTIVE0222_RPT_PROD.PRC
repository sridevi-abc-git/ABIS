CREATE OR REPLACE PROCEDURE ABC.gen_active0222_rpt_prod(
    a_maildate      DATE DEFAULT NULL,
    a_duedate       DATE DEFAULT NULL,
    a_firstnotice   VARCHAR2 DEFAULT NULL)
AS
    -- **************************************************************************
    -- File:        GEN_ACTIVE0222_RPT_PROD.PRC
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

    -- For Active 02/22 List Report, no parameter is needed.
    -- Once the report table is populated the ABC-261 report needs to be run
    -- to be mailed out by Accounting

    t_ptfeeobjectlist   api.udt_objectlist;
    t_count             PLS_INTEGER := 0;
    t_yr                VARCHAR2(2) := TO_CHAR(CURRENT_DATE, 'YY');

    -- Notice Report
    t_maildate          DATE := TRUNC(NVL(a_maildate, CURRENT_DATE));
    t_duedate           DATE := TRUNC(NVL(a_duedate, CURRENT_DATE));
    t_firstnotice       VARCHAR2(1) := NVL(UPPER(a_firstnotice), 'Y');
    t_issuedate         DATE := TO_DATE('05/31/' || t_yr, 'mm/dd/yy');

    t_startdate         DATE;
    t_enddate           DATE;
    t_transdatestart    DATE;
    t_transdateend      DATE;
BEGIN
    IF t_issuedate > CURRENT_DATE THEN
        t_yr   := TO_CHAR(ADD_MONTHS(CURRENT_DATE, -12), 'YY');
    END IF;

    t_issuedate        := TO_DATE('05/31/' || t_yr, 'mm/dd/yy');
    t_startdate        := ADD_MONTHS(TO_DATE('07/01/' || t_yr, 'mm/dd/yy'), -12);
    t_enddate          := TO_DATE('06/30/' || t_yr, 'mm/dd/yy');
    t_transdatestart   :=
        ADD_MONTHS(TO_DATE('04/15/' || t_yr, 'mm/dd/yy'), -12);
    t_transdateend     := TO_DATE('04/15/' || t_yr, 'mm/dd/yy');

    DELETE FROM abc.active0222_rpt_prod;

    -- for testing only; global temporary tables will be used in production; no commit command is needed;
    COMMIT;                                 --comment it out for regular table

    --loop through all license types.
    FOR c_lictype
        IN (SELECT DISTINCT
                   l.jobid
                       jobid,
                   l.licensenumber
                       filenum,
                   UPPER(NVL(l.primarylicensee, l.primarydba))
                       licensee,
                   l.statusname
                       status,
                   l.basefileofficecodecorral
                       district,
                   lt.licensetypecode
                       ltcode,
                   lt.statusname
                       ltstatus,
                   TRUNC(lt.expirationdate)
                       ltexpdate,
                   lt.gallonagerangefeecode
                       ltfeecode,
                   TRUNC(NVL(lt.issuedate, jsc.effectivestartdate))
                       ltissdate,
                   UPPER(
                       NVL(lt.licensemailingaddress2lines,
                           lt.licensepremisesaddress2lines))
                       address
              FROM query.j_license  l
                   JOIN query.r_licenselicensetype rlt
                       ON rlt.licensejobid = l.jobid
                   JOIN query.j_licensetype lt
                       ON lt.jobid = rlt.licensetypejobid
                   JOIN api.jobstatuses js1
                       ON js1.jobtypeid = l.jobtypeid
                      AND js1.statusid = l.statusid
                      AND js1.statustype IN ('O', 'I')
                   JOIN api.jobstatuses js2
                       ON js2.jobtypeid = lt.jobtypeid
                      AND js2.statusid = lt.statusid
                      AND js2.statustype IN ('O', 'I')
                   LEFT OUTER JOIN extension.jobstatuschange_t jsc
                       ON jsc.jobid = lt.jobid
                      AND jsc.mostrecent = 'Y'
             WHERE l.licensenumber IS NOT NULL
               AND NVL(l.primarylicensee, l.primarydba) IS NOT NULL
               AND lt.licensetypecode IS NOT NULL
               AND lt.gallonagerangefeecode IS NOT NULL
               AND lt.licensetypecode IN ('02', '22')
               AND TRUNC(NVL(lt.issuedate, jsc.effectivestartdate)) <=
                   t_issuedate
            UNION
            SELECT DISTINCT
                   l.jobid
                       jobid,
                   l.licensenumber
                       filenum,
                   UPPER(NVL(l.primarylicensee, l.primarydba))
                       licensee,
                   l.statusname
                       status,
                   l.basefileofficecodecorral
                       district,
                   oltc.licensetypecode
                       ltcode,
                   lt.statusname
                       ltstatus,
                   TRUNC(lt.expirationdate)
                       ltexpdate,
                   lt.gallonagerangefeecode
                       ltfeecode,
                   TRUNC(NVL(lt.issuedate, jsc.effectivestartdate))
                       ltissdate,
                   UPPER(
                       NVL(lt.licensemailingaddress2lines,
                           lt.licensepremisesaddress2lines))
                       address
              FROM query.j_license  l
                   JOIN query.r_licenselicensetype rlt
                       ON rlt.licensejobid = l.jobid
                   JOIN query.j_licensetype lt
                       ON lt.jobid = rlt.licensetypejobid
                   JOIN query.r_licensetypeltcatsecondary slt
                       ON slt.licensetypejobid = lt.jobid
                   JOIN query.o_licensetypecategory oltc
                       ON oltc.objectid = slt.licensetypecategoryobjectid
                   JOIN api.jobstatuses js1
                       ON js1.jobtypeid = l.jobtypeid
                      AND js1.statusid = l.statusid
                      AND js1.statustype IN ('O', 'I')
                   JOIN api.jobstatuses js2
                       ON js2.jobtypeid = lt.jobtypeid
                      AND js2.statusid = lt.statusid
                      AND js2.statustype IN ('O', 'I')
                   LEFT OUTER JOIN extension.jobstatuschange_t jsc
                       ON jsc.jobid = lt.jobid
                      AND jsc.mostrecent = 'Y'
             WHERE l.licensenumber IS NOT NULL
               AND NVL(l.primarylicensee, l.primarydba) IS NOT NULL
               AND lt.licensetypecode IS NOT NULL
               AND lt.gallonagerangefeecode IS NOT NULL
               AND oltc.licensetypecode IN ('02', '22')
               AND TRUNC(NVL(lt.issuedate, jsc.effectivestartdate)) <=
                   t_issuedate)
    LOOP
        SELECT COUNT(*)
          INTO t_count
          FROM abc.active0222_rpt_prod
         WHERE filenum = c_lictype.filenum
           AND ltcode = c_lictype.ltcode
           AND ROWNUM = 1;

        IF t_count = 0 THEN
            INSERT INTO abc.active0222_rpt_prod(filenum,
                                                licensee,
                                                status,
                                                district,
                                                ltcode,
                                                ltstatus,
                                                ltexpdate,
                                                ltfeecode,
                                                ltissdate,
                                                address,
                                                maildate,
                                                duedate,
                                                firstnotice,
                                                startdate,
                                                enddate,
                                                issuedate,
                                                transdatestart,
                                                transdateend)
                 VALUES (c_lictype.filenum,
                         c_lictype.licensee,
                         c_lictype.status,
                         c_lictype.district,
                         c_lictype.ltcode,
                         c_lictype.ltstatus,
                         c_lictype.ltexpdate,
                         c_lictype.ltfeecode,
                         c_lictype.ltissdate,
                         c_lictype.address,
                         t_maildate,
                         t_duedate,
                         t_firstnotice,
                         t_startdate,
                         t_enddate,
                         t_issuedate,
                         t_transdatestart,
                         t_transdateend);
        END IF;


        --
        -- payments
        --

        IF a_maildate IS NULL
       AND a_duedate IS NULL
       AND a_firstnotice IS NULL THEN
            sitespecific.pkg_fees.getpaymenttransactionsforjob(
                c_lictype.jobid,
                NULL,
                t_ptfeeobjectlist);

            FOR i IN 1 .. t_ptfeeobjectlist.COUNT
            LOOP
                INSERT INTO abc.active0222_rpt_prod(filenum,
                                                    licensee,
                                                    ltcode,
                                                    ltissdate,
                                                    amttype,
                                                    amtmi,
                                                    amtdup,
                                                    amtfeecode,
                                                    amttranscode,
                                                    amtearnedamt,
                                                    amtearneddate,
                                                    amtearnedtype,
                                                    --testfield,
                                                    issuedate,
                                                    transdatestart,
                                                    transdateend)
                    -- Payment Transactions  -- C,R,V,I
                    SELECT c_lictype.filenum
                               licnum,
                           c_lictype.licensee,
                           c_lictype.ltcode
                               ltcode,
                           c_lictype.ltissdate,
                           qpt.licensetypecode
                               licensetypecode,
                           qpt.ismaster
                               mi,
                           qpt.secondarycount
                               dup,
                           qpt.feecode
                               feecode,
                           CASE
                               WHEN qpt.isservicecharge = 'Y' THEN 'SRV'
                               WHEN qpt.isoverpayment = 'Y' THEN 'OVR'
                               ELSE qpt.feescheduletransactioncode
                           END
                               transcode,
                           ft.amount * -1
                               amount,
                           TRUNC(qpt.transactiondate)
                               transdate,
                           CASE
                               WHEN (SELECT 'x'
                                       FROM api.relationships r
                                      WHERE r.fromobjectid = x.objectid
                                        AND r.endpointid IN
                                                (api.pkg_configquery.endpointidforname(
                                                     'o_Payment',
                                                     'PaymentTransferAdjust'),
                                                 api.pkg_configquery.endpointidforname(
                                                     'o_Payment',
                                                     'PaymentTransferTo'))
                                        AND ROWNUM = 1) =
                                    'x' THEN
                                   'C'
                               WHEN (SELECT 'x'
                                       FROM api.relationships r
                                      WHERE r.fromobjectid = x.objectid
                                        AND r.endpointid =
                                            api.pkg_configquery.endpointidforname(
                                                'o_Payment',
                                                'RefundCheck')
                                        AND ROWNUM = 1) =
                                    'x' THEN
                                   'R'
                               WHEN (SELECT 'x'
                                       FROM api.relationships r
                                      WHERE r.fromobjectid = x.objectid
                                        AND r.endpointid =
                                            api.pkg_configquery.endpointidforname(
                                                'o_Payment',
                                                'VoidPayment')
                                        AND ROWNUM = 1) =
                                    'x' THEN
                                   'V'
                               ELSE
                                   'I'
                           END
                               amounttype,
                           --'Source=1, LTLicNum=' || api.pkg_columnquery.value (c_lictype.jobid,'LicenseNumber') testfield,
                           t_issuedate,
                           t_transdatestart,
                           t_transdateend
                      FROM query.o_paymenttransactions  qpt
                           JOIN api.paymenttransactions pt
                               ON pt.transactionid = qpt.transactionid
                           JOIN api.feetransactions ft
                               ON ft.transactionid = pt.transactionid
                           JOIN
                           TABLE(
                               CAST(
                                   api.pkg_simplesearch.castableobjectsbyindex(
                                       'o_Payment',
                                       'PaymentId',
                                       pt.paymentid) AS api.udt_objectlist))
                           x
                               ON 1 = 1
                     WHERE qpt.objectid = t_ptfeeobjectlist(i).objectid
                       AND qpt.licensetypecode = c_lictype.ltcode
                       --and    qpt.feescheduletransactionfeeactiv in ('ANN', 'REN')
                       AND qpt.feescheduletransactionfeeactiv IN ('ANN',
                                                                  'REN',
                                                                  'REN50',
                                                                  'REN100')
                       AND qpt.feecode IS NOT NULL
                       AND TRUNC(qpt.transactiondate) BETWEEN t_transdatestart
                                                          AND t_transdateend;

                INSERT INTO abc.active0222_rpt_prod(filenum,
                                                    licensee,
                                                    ltcode,
                                                    ltissdate,
                                                    amttype,
                                                    amtmi,
                                                    amtdup,
                                                    amtfeecode,
                                                    amttranscode,
                                                    amtearnedamt,
                                                    amtearneddate,
                                                    amtearnedtype,
                                                    --testfield,
                                                    issuedate,
                                                    transdatestart,
                                                    transdateend)
                    -- Payment Transactions  -- G, A  (earned vs unearned)
                    SELECT c_lictype.filenum
                               licnum,
                           c_lictype.licensee,
                           c_lictype.ltcode
                               ltcode,
                           c_lictype.ltissdate,
                           qpt.licensetypecode
                               licensetypecode,
                           qpt.ismaster
                               mi,
                           qpt.secondarycount
                               dup,
                           qpt.feecode
                               feecode,
                           CASE
                               WHEN qpt.isservicecharge = 'Y' THEN 'SRV'
                               WHEN qpt.isoverpayment = 'Y' THEN 'OVR'
                               ELSE qpt.feescheduletransactioncode
                           END
                               transcode,
                           CASE
                               WHEN UPPER(
                                        api.pkg_columnquery.VALUE(
                                            pspt.paymentstatusobjectid,
                                            'Status')) =
                                    'EARNED' THEN
                                   ft.amount
                               ELSE
                                   ft.amount * -1 --switch negative sign back if it does not work.
                           END
                               amount,
                           TRUNC(qpt.transactiondate)
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
                               amounttype,
                           --'Source=2, LTLicNum=' || api.pkg_columnquery.value (c_lictype.jobid,'LicenseNumber') testfield,
                           t_issuedate,
                           t_transdatestart,
                           t_transdateend
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
                           JOIN query.r_paymentstatuspaymenttrans pspt
                               ON pspt.paymenttransactionobjectid =
                                  qpt.objectid
                     WHERE qpt.objectid = t_ptfeeobjectlist(i).objectid
                       AND qpt.licensetypecode = c_lictype.ltcode
                       --and    qpt.feescheduletransactionfeeactiv in ('ANN', 'REN')
                       AND qpt.feescheduletransactionfeeactiv IN ('ANN',
                                                                  'REN',
                                                                  'REN50',
                                                                  'REN100')
                       AND qpt.feecode IS NOT NULL
                       AND TRUNC(qpt.transactiondate) BETWEEN t_transdatestart
                                                          AND t_transdateend;
            END LOOP;
        END IF;
    END LOOP;

    -- for testing only; global temporary tables will be used in production; no commit command is needed;
    COMMIT;
END gen_active0222_rpt_prod;
/
