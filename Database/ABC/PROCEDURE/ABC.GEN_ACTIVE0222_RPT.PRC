CREATE OR REPLACE PROCEDURE ABC.gen_active0222_rpt(
    a_duedate       DATE DEFAULT NULL,
    a_maildate      DATE DEFAULT NULL,
    a_firstnotice   VARCHAR2 DEFAULT NULL)
AS
    -- **************************************************************************
    -- File:
    -- Author:      CX
    --
    -- $Rev: 24 $
    -- $Date: 2018-08-21 08:06:35 -0700 (Tue, 21 Aug 2018) $
    -- Last Changed By:  $Author: tlord $
    --
    -- Description:
    --    This procedure gets invoked when Accounting runs the Active 02/22 - (ABC261) First Notice List.
    --    Accounting will review the list and then run the Active 02/22 - (ABC261) First Notice Letters
    --
    --
    -- History:
    -----------------------------------------------------------------------------
    --    Date                  Comment
    -- 02/01/2018 NW          Copy taken from ABCPROD
    -- 02/05/2018 NW          Add a column for Renewal Fees Collected from prior year
    -- 08/20/2018 TJL         Initial Check-in
    -- **************************************************************************

    -- For Active 02/22 List Report, no parameter is needed.

    t_ptfeeobjectlist   api.udt_objectlist;
    -- t_Count             pls_integer := 0;
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
    t_transdateend     := TO_DATE('04/14/' || t_yr, 'mm/dd/yy');  -- 7/28/2018 NW

    /*_________________________________________________________________

    Get primary licenses
    _________________________________________________________________*/

    DELETE FROM abc.active0222_rpt;

    COMMIT;                                 --comment it out for regular table

    -- for testing only; global temporary tables will be used in production; no commit command is needed;

    INSERT INTO abc.active0222_rpt(jobid,
                                   filenum,
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
        SELECT DISTINCT
               l.jobid,
               l.externalfilenum
                   filenum,
               l.primarylicensee
                   licensee,
               l.statusname
                   status,
               lt.basefileofficecode
                   district,
               lt.licensetypecode
                   ltcode,
               lt.statusname
                   ltstatus,
               TRUNC(lt.renewaldate)
                   ltexpdate,
               qlt.gallonagerangefeecode
                   ltfeecode,
               TRUNC(NVL(lt.issuedate, jsc.effectivestartdate))
                   AS "LtIssueDate"--, NVL(LT.MailAddress1stOf2Lines,LT.PremAddress1stOf2Lines) ADDRESS
                                   ,
               NVL2(
                   lt.mailaddress1stof2lines || lt.mailaddress2ndof2lines,
                      lt.mailaddress1stof2lines
                   || CHR(13)
                   || CHR(10)
                   || mailaddress2ndof2lines,
                      lt.premaddress1stof2lines
                   || CHR(13)
                   || CHR(10)
                   || premaddress2ndof2lines)
                   address,
               t_maildate                       --, MAILDATE      -- parameter
                         ,
               t_duedate                        --, DUEDATE       -- parameter
                        ,
               t_firstnotice                    --, FIRSTNOTICE   -- parameter
                            ,
               t_startdate                     --, STARTDATE     -- calculated
                          ,
               t_enddate                       --, ENDDATE       -- calculated
                        ,
               t_issuedate                      --, ISSUEDATE     -- parameter
                          ,
               t_transdatestart              --, TRANSDATESTART  -- calculated
                               ,
               t_transdateend                --, TRANSDATEEND    -- calculated
          FROM mart.license  l
               JOIN mart.licenselicensetyperel ll
                   ON ll.licensejobid = l.jobid
               JOIN mart.licensetype lt ON lt.licensejobid = ll.licensejobid
               JOIN
               (SELECT b.objectid    AS jobid,
                       b.objectdefid AS jobtypeid,
                       e.statusid
                  FROM possedata.readableobjects  b
                       JOIN workflow.jobs e ON e.jobid = b.objectid
                 WHERE b.objectdefid = 325227) ql
                   ON ql.jobid = l.jobid
               JOIN
               (SELECT b.objectid,
                       b.objectdefid
                           jobtypeid,
                       e.statusid,
                       api.pkg_columnquery.VALUE(b.objectid,
                                                 'GallonageRangeFeeCode')
                           AS gallonagerangefeecode
                  FROM possedata.readableobjects  b
                       JOIN workflow.jobs e ON e.jobid = b.objectid
                 WHERE b.objectdefid = 329416) qlt
                   ON qlt.objectid = lt.objectid
               JOIN api.jobstatuses js1
                   ON js1.jobtypeid = ql.jobtypeid
                  AND js1.statusid = ql.statusid
                  AND js1.statustype IN ('O', 'I')
               JOIN api.jobstatuses js2
                   ON js2.jobtypeid = qlt.jobtypeid
                  AND js2.statusid = qlt.statusid
                  AND js2.statustype IN ('O', 'I')
               LEFT OUTER JOIN extension.jobstatuschange_t jsc
                   ON jsc.jobid = qlt.objectid
                  AND jsc.mostrecent = 'Y'
         WHERE lt.licensetypecode IN ('02', '22')
           AND TRUNC(NVL(lt.issuedate, jsc.effectivestartdate)) <=
               t_issuedate
           AND qlt.gallonagerangefeecode IS NOT NULL;

    COMMIT;

    -- 1/27/2016 1:07 minutes, 3681 records

    /*___________________________________________________________________________

    Get Secondary Licenses
    NW: The original had a UNION JOIN here. I get significant performance
        gains using separate INSERT statements.
    ___________________________________________________________________________*/


    INSERT INTO abc.active0222_rpt(jobid,
                                   filenum,
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
        SELECT DISTINCT
               l.jobid,
               l.externalfilenum
                   filenum,
               l.primarylicensee
                   licensee,
               l.statusname
                   status,
               lt.basefileofficecode
                   district,
               oltc.licensetypecode
                   ltcode,
               lt.statusname
                   ltstatus,
               TRUNC(lt.renewaldate)
                   ltexpdate,
               qlt.gallonagerangefeecode
                   ltfeecode,
               TRUNC(NVL(lt.issuedate, jsc.effectivestartdate))
                   ltissuedate,
               NVL2(
                   lt.mailaddress1stof2lines || lt.mailaddress2ndof2lines,
                      lt.mailaddress1stof2lines
                   || CHR(13)
                   || CHR(10)
                   || mailaddress2ndof2lines,
                      lt.premaddress1stof2lines
                   || CHR(13)
                   || CHR(10)
                   || premaddress2ndof2lines)
                   address,
               t_maildate                       --, MAILDATE      -- parameter
                         ,
               t_duedate                        --, DUEDATE       -- parameter
                        ,
               t_firstnotice                    --, FIRSTNOTICE   -- parameter
                            ,
               t_startdate                     --, STARTDATE     -- calculated
                          ,
               t_enddate                       --, ENDDATE       -- calculated
                        ,
               t_issuedate                      --, ISSUEDATE     -- parameter
                          ,
               t_transdatestart              --, TRANSDATESTART  -- calculated
                               ,
               t_transdateend                --, TRANSDATEEND    -- calculated
          FROM mart.license  l
               JOIN (SELECT b.objectid, b.objectdefid jobtypeid, e.statusid
                       FROM possedata.readableobjects  b
                            JOIN workflow.jobs e ON e.jobid = b.objectid
                      WHERE b.objectdefid = 325227) ql
                   ON ql.objectid = l.jobid
               JOIN mart.licenselicensetyperel ll
                   ON ll.licensejobid = l.jobid
               JOIN mart.licensetype lt ON lt.licensejobid = ll.licensejobid
               JOIN
               (SELECT b.objectid,
                       b.objectdefid
                           jobtypeid,
                       e.statusid,
                       api.pkg_columnquery.VALUE(b.objectid,
                                                 'GallonageRangeFeeCode')
                           gallonagerangefeecode
                  FROM possedata.readableobjects  b
                       JOIN workflow.jobs e ON e.jobid = b.objectid
                 WHERE b.objectdefid = 329416) qlt
                   ON qlt.objectid = lt.objectid
                  AND qlt.gallonagerangefeecode IS NOT NULL
               JOIN mart.licensetypeltcatsecondary slt
                   ON slt.licensetypejobid = lt.objectid
               JOIN mart.licensetypecategory oltc
                   ON oltc.objectid = slt.licensetypecategoryobjectid
               JOIN api.jobstatuses js1
                   ON js1.jobtypeid = ql.jobtypeid
                  AND js1.statusid = ql.statusid
                  AND js1.statustype IN ('O', 'I')
               JOIN api.jobstatuses js2
                   ON js2.jobtypeid = qlt.jobtypeid
                  AND js2.statusid = qlt.statusid
                  AND js2.statustype IN ('O', 'I')
               LEFT OUTER JOIN extension.jobstatuschange_t jsc
                   ON jsc.jobid = qlt.objectid
                  AND jsc.mostrecent = 'Y'
         WHERE oltc.licensetypecode IN ('02', '22')
           AND TRUNC(NVL(lt.issuedate, jsc.effectivestartdate)) <=
               t_issuedate;

    COMMIT;


    /*_______________________________________________________________________________________

    Create a relationship table to link licenses to their payment ObjectIDs
    NW - Much performance gains by doing it this way
    _______________________________________________________________________________________*/

    DELETE FROM abc.active0222_objects;

    COMMIT;

    FOR c_license IN --( SELECT JobId , LtCode FROM ABC.Active0222_Rpt_DEV)
                     (SELECT jobid, ltcode FROM abc.active0222_rpt)
    LOOP
        sitespecific.pkg_fees.getpaymenttransactionsforjob(c_license.jobid,
                                                           NULL,
                                                           t_ptfeeobjectlist); -- Abyss (The ABIS Blackbox!)

        FOR i IN 1 .. t_ptfeeobjectlist.COUNT
        LOOP
            INSERT INTO abc.active0222_objects(jobid, objectid, ltcode)
                SELECT c_license.jobid,
                       t_ptfeeobjectlist(i).objectid,
                       c_license.ltcode
                  FROM DUAL;
        END LOOP;
    END LOOP;

    COMMIT;

    -- 5:19 minutes 74003 records


    /*___________________________________________________________________________________________________________

    Get Payments FROM O_PaymentTransactions
    NW: This is an added step to solely use objectid as the index key to avoid full table scans on ABIS wrapped functions
    ___________________________________________________________________________________________________________*/


    DELETE FROM active0222_payments;

    COMMIT;

    INSERT INTO active0222_payments
        SELECT DISTINCT o.jobid,
                        o.objectid,
                        p.transactionid,
                        p.licensetypecode,
                        p.ismaster,
                        p.secondarycount,
                        p.feecode,
                        p.isservicecharge,
                        p.isoverpayment,
                        p.feescheduletransactioncode,
                        TRUNC(p.transactiondate) transactiondate,
                        p.feescheduletransactionfeeactiv
          FROM query.o_paymenttransactions  p
               JOIN active0222_objects o ON o.objectid = p.objectid;

    COMMIT;

    --24:20 Minutes , 73708 Records

    /*___________________________________

    Get Payments for Primary Licenses
    ___________________________________*/

    INSERT INTO abc.active0222_rpt(filenum,
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
                                   issuedate,
                                   transdatestart,
                                   transdateend,
                                   jobid,
                                   renewalpaid)
          SELECT                                                    --DISTINCT
                 r.filenum
                     filenum,
                 r.licensee
                     licensee,
                 r.ltcode
                     ltcode,
                 r.ltissdate
                     ltissdate,
                 p.licensetypecode
                     amttype,
                 p.ismaster
                     amtmi,
                 p.secondarycount
                     amtdup,
                 p.feecode
                     amtfeecode,
                 CASE
                     WHEN p.isservicecharge = 'Y' THEN 'SRV'
                     WHEN p.isoverpayment = 'Y' THEN 'OVR'
                     ELSE p.feescheduletransactioncode
                 END
                     amttranscode,
                 ft.amount * -1
                     amtearnedamt,
                 p.transactiondate
                     amtearneddate,
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
                     amtearnedtype,
                 r.issuedate,
                 r.transdatestart,
                 r.transdateend,
                 r.jobid,
                 f.amount
                     renewalpaid
            FROM active0222_rpt r
                 JOIN active0222_payments p
                     ON r.jobid = p.jobid
                    AND p.licensetypecode = r.ltcode
                 JOIN api.paymenttransactions pt
                     ON pt.transactionid = p.transactionid
                 JOIN api.feetransactions ft
                     ON ft.transactionid = pt.transactionid
                 JOIN
                 TABLE(
                     CAST(
                         api.pkg_simplesearch.castableobjectsbyindex(
                             'o_Payment',
                             'PaymentId',
                             pt.paymentid) AS api.udt_objectlist)) x
                     ON 1 = 1
                 JOIN api.fees f ON f.feeid = ft.feeid
           WHERE r.amttype IS NULL
             AND p.transactiondate BETWEEN t_transdatestart AND t_transdateend
             --  AND P.TransactionDate BETWEEN '15-apr-2016' and '15-apr-2017' --t_TransDateStart AND t_TransDateEnd  AND P.LicenseTypeCode IN ('02','22')
             AND p.feescheduletransactionfeeactiv IN ('ANN',
                                                      'REN',
                                                      'REN50',
                                                      'REN100')
             AND p.licensetypecode IN ('02', '22')
        ORDER BY r.jobid, p.transactiondate DESC;

    COMMIT;

    /*___________________________________

    Get Payments for Secondary Licenses
    ___________________________________*/

    INSERT INTO abc.active0222_rpt(filenum,
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
                                   issuedate,
                                   transdatestart,
                                   transdateend,
                                   jobid,
                                   renewalpaid)
        SELECT r.filenum,
               r.licensee,
               r.ltcode,
               r.ltissdate,
               p.licensetypecode
                   amttype,
               p.ismaster
                   amtmi,
               p.secondarycount
                   amtdup,
               p.feecode
                   amtfeecode,
               CASE
                   WHEN p.isservicecharge = 'Y' THEN 'SRV'
                   WHEN p.isoverpayment = 'Y' THEN 'OVR'
                   ELSE p.feescheduletransactioncode
               END
                   amttranscode--, FT.Amount*-1 AmtEarnedAmt
                               ,
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
                   amtearnedamt,
               TRUNC(p.transactiondate)
                   amtearneddate,
               CASE
                   WHEN api.pkg_columnquery.VALUE(pspt.paymentstatusobjectid,
                                                  'SystemGenerated') =
                        'Y' THEN
                       'G'
                   ELSE
                       'A'
               END
                   amtearnedtype,
               r.issuedate,
               r.transdatestart,
               r.transdateend,
               r.jobid,
               f.amount
                   renewalpaid
          FROM active0222_rpt  r
               --FROM active0222_TEST R

               JOIN active0222_payments p
                   ON r.jobid = p.jobid
                  AND p.licensetypecode = r.ltcode
               JOIN api.paymenttransactions pt
                   ON pt.transactionid = p.transactionid
               JOIN
               TABLE(
                   CAST(
                       api.pkg_simplesearch.castableobjectsbyindex(
                           'o_Payment',
                           'PaymentId',
                           pt.paymentid) AS api.udt_objectlist)) x
                   ON 1 = 1
               JOIN api.feetransactions ft
                   ON ft.transactionid = pt.transactionid
               JOIN query.r_paymentstatuspaymenttrans pspt
                   ON pspt.paymenttransactionobjectid = p.objectid
               JOIN api.fees f ON f.feeid = ft.feeid
         WHERE r.amttype IS NULL
           AND p.transactiondate BETWEEN t_transdatestart AND t_transdateend
           --  AND P.TransactionDate BETWEEN '15-apr-2016' and '15-apr-2017' --t_TransDateStart AND t_TransDateEnd  AND P.LicenseTypeCode IN ('02','22')
           AND p.licensetypecode IN ('02', '22')
           AND p.feescheduletransactionfeeactiv IN ('ANN',
                                                    'REN',
                                                    'REN50',
                                                    'REN100');

    COMMIT;

    UPDATE abc.active0222_rpt
       SET renewalpaid   = NULL
     WHERE amtearnedtype <> 'I';

    COMMIT;
END;                                                    -- GEN_ACTIVE0222_RPT;
/


GRANT EXECUTE ON ABC.GEN_ACTIVE0222_RPT TO POSSEEXTENSIONS;

GRANT EXECUTE ON ABC.GEN_ACTIVE0222_RPT TO PUBLIC;
