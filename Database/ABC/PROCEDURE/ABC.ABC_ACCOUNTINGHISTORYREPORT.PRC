CREATE OR REPLACE PROCEDURE ABC.abc_accountinghistoryreport(
    a_objectid      NUMBER)
IS
    -- **************************************************************************
    -- File:        ABC_ACCOUNTINGHISTORYREPORT.PRC
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
    t_ptobjectlist    api.udt_objectlist;
    t_maxptdate       DATE;
    t_feeobjectlist   api.udt_objectlist;
    t_maxptobjectid   NUMBER;
BEGIN
    --clear the Global Temp Table (GTT) for this session
    DELETE abc.abc_accountinghistoryreport_gt;

    COMMIT;

    --Grab the Payment Transactions for this License
    --abc.pkg_Reports.GetPayTransForAccHist(a_ObjectId, null, t_PTObjectList);

    --Grab the Most Recent Payment Transaction Date of Payments Related to this report
    /* select max(objectid) into t_MaxPTObjectId from table(cast(t_PTObjectList as api.udt_objectlist));
     select max(alt.CreatedDate)
        into t_MaxPTDate
       from query.o_paymenttransactions ap
       join api.feetransactions aft
           on aft.TransactionId = ap.TransactionId
       join api.logicaltransactions alt on alt.LogicalTransactionId = aft.LogicalTransactionId
       where ap.ObjectId = t_MaxPTObjectId;
       --dbms_output.put_line(t_MaxPTDate ); */
    --Grab the $0.00 Dollar Fees to Relate to this report
    --abc.Pkg_Reports.GetZeroDollarFeesForAccHist(a_ObjectId,t_MaxPTDate,t_FeeObjectList );
    --loop through the Payment Transactions for this report
    --for c in 1 .. t_PTObjectList.count loop
    --inserting into the GTT
    INSERT INTO abc.abc_accountinghistoryreport_gt
        SELECT api.pkg_columnquery.VALUE(f.jobid, 'LicenseNumber')
                   licnum,
               CASE
                   WHEN api.pkg_columnquery.VALUE(f.jobid, 'JobTypeId') =
                        api.pkg_configquery.objectdefidforname('j_License') THEN
                       SUBSTR(
                           api.pkg_columnquery.VALUE(f.jobid, 'StatusName'),
                           1,
                           3)
                   ELSE
                       NVL(
                           (SELECT DECODE(
                                       SUBSTR(
                                           api.pkg_columnquery.VALUE(
                                               r1.toobjectid,
                                               'StatusName'),
                                           1,
                                           3),
                                       'ISS', 'PEN',
                                       SUBSTR(
                                           api.pkg_columnquery.VALUE(
                                               f.jobid,
                                               'StatusName'),
                                           1,
                                           3))
                              FROM api.relationships r1
                             WHERE r1.fromobjectid = f.jobid
                               AND r1.endpointid =
                                   (api.pkg_configquery.endpointidforname(
                                        'j_Application',
                                        'License'))),
                           DECODE(
                               SUBSTR(
                                   api.pkg_columnquery.VALUE(f.jobid,
                                                             'StatusName'),
                                   1,
                                   3),
                               'ISS', 'PEN',
                               SUBSTR(
                                   api.pkg_columnquery.VALUE(f.jobid,
                                                             'StatusName'),
                                   1,
                                   3)))
               END
                   status,
               DECODE(st.statusdate,
                      NULL, st.effectivestartdate,
                      st.statusdate)
                   statusdate,
               NVL(
                   api.pkg_columnquery.VALUE(f.jobid,
                                             'BaseFileOfficeCodeCorral'),
                   api.pkg_columnquery.VALUE(f.jobid, 'DistrictOfficeCode'))
                   district,
               NVL(
                   api.pkg_columnquery.VALUE(f.jobid, 'PremAddress1Line'),
                   api.pkg_columnquery.VALUE(f.jobid, 'EventLocAddressLine1'))
                   premises,
               api.pkg_columnquery.VALUE(f.jobid, 'PrimaryLicensee')
                   "NAME",
               api.pkg_columnquery.datevalue(qpt.objectid, 'TransactionDate')
                   entrydate,
               qpt.cabinamttype
                   i,
               CASE
                   WHEN qpt.isoverpayment = 'Y' THEN 'OVR'
                   WHEN qpt.isservicecharge = 'Y' THEN 'SRV'
                   ELSE fs.description
               END
                   trans,
               fs.licensetypecode
                   lt,
               qpt.ismaster
                   m,
               qpt.secondarycount
                   dup,
               CASE
                   WHEN qpt.cabinamttype = 'V' --the purpose of this is that a payment that has been voided should show up as zero instead of the original value
                                               THEN 0
                   ELSE ft.amount * -1
               END
                   amount,
               NVL(p.payeereference, qpt.hqreceipt)
                   paymentid,
               p.receiptnumber
                   recnum,
               api.pkg_columnquery.datevalue(qpt.objectid, 'TransactionDate')
                   paiddate,
               f.jobid,
               NVL(
                   api.pkg_columnquery.VALUE(
                       sitespecific.pkg_fees.getlicfeeschedulobjid(ft.feeid),
                       'FeeCode'),
                   'NA')
                   feecode,
               ft.transactionid,
               qpt.legacykey
                   sortcolumn1,
               qpt.objectid
                   sortcolumn2
          FROM query.o_paymenttransactions  qpt
               JOIN api.payments p ON p.paymentid = qpt.paymentid
               JOIN
               TABLE(
                   CAST(
                       api.pkg_simplesearch.castableobjectsbyindex(
                           'o_Payment',
                           'PaymentId',
                           p.paymentid) AS api.udt_objectlist)) x
                   ON 1 = 1
               JOIN api.feetransactions ft
                   ON ft.transactionid = qpt.transactionid
               JOIN api.fees f ON f.feeid = ft.feeid
               JOIN sitespecific.feeschedule_t fs
                   ON fs.objectid =
                      sitespecific.pkg_fees.getlicfeeschedulobjid(ft.feeid) ---------
               JOIN extension.jobstatuschange st
                   ON st.jobid = f.jobid
                  AND st.mostrecent = 'Y';

    --where qpt.ObjectId = t_PTObjectList(c).objectid;
    --***** here to include all LICENSES!!!!!!!!!
    --get the payment status rows

    COMMIT;

    INSERT INTO abc_accountinghistoryreport_gt
        SELECT api.pkg_columnquery.VALUE(f.jobid, 'LicenseNumber')
                   licnum,
               CASE
                   WHEN api.pkg_columnquery.VALUE(f.jobid, 'JobTypeId') =
                        api.pkg_configquery.objectdefidforname('j_License') THEN
                       SUBSTR(
                           api.pkg_columnquery.VALUE(f.jobid, 'StatusName'),
                           1,
                           3)
                   ELSE
                       NVL(
                           (SELECT DECODE(
                                       SUBSTR(
                                           api.pkg_columnquery.VALUE(
                                               r1.toobjectid,
                                               'StatusName'),
                                           1,
                                           3),
                                       'ISS', 'PEN',
                                       SUBSTR(
                                           api.pkg_columnquery.VALUE(
                                               f.jobid,
                                               'StatusName'),
                                           1,
                                           3))
                              FROM api.relationships r1
                             WHERE r1.fromobjectid = f.jobid
                               AND r1.endpointid =
                                   (api.pkg_configquery.endpointidforname(
                                        'j_Application',
                                        'License'))),
                           DECODE(
                               SUBSTR(
                                   api.pkg_columnquery.VALUE(f.jobid,
                                                             'StatusName'),
                                   1,
                                   3),
                               'ISS', 'PEN',
                               SUBSTR(
                                   api.pkg_columnquery.VALUE(f.jobid,
                                                             'StatusName'),
                                   1,
                                   3)))
               END
                   status,
               DECODE(st.statusdate,
                      NULL, st.effectivestartdate,
                      st.statusdate)
                   statusdate,
               NVL(
                   api.pkg_columnquery.VALUE(f.jobid,
                                             'BaseFileOfficeCodeCorral'),
                   api.pkg_columnquery.VALUE(f.jobid, 'DistrictOfficeCode'))
                   district,
               NVL(
                   api.pkg_columnquery.VALUE(f.jobid, 'PremAddress1Line'),
                   api.pkg_columnquery.VALUE(f.jobid, 'EventLocAddressLine1'))
                   premises,
               api.pkg_columnquery.VALUE(f.jobid, 'PrimaryLicensee')
                   "NAME",
               TRUNC(
                   api.pkg_columnquery.datevalue(r.toobjectid, 'CreatedDate'))
                   entrydate,
               CASE
                   WHEN api.pkg_columnquery.VALUE(r.toobjectid,
                                                  'SystemGenerated') =
                        'Y' THEN
                       'G'
                   ELSE
                       'A'
               END
                   i,
               CASE
                   WHEN qpt.isoverpayment = 'Y' THEN
                       'OVR'
                   WHEN qpt.isservicecharge = 'Y' THEN
                       'SRV'
                   ELSE
                       api.pkg_columnquery.VALUE(r.toobjectid,
                                                 'TransactionCode')
               END
                   trans,
               api.pkg_columnquery.VALUE(r.toobjectid, 'LicenseTypeCode')
                   lt,
               api.pkg_columnquery.VALUE(r.toobjectid, 'IsMaster')
                   m,
               api.pkg_columnquery.VALUE(r.toobjectid, 'SecondaryCount')
                   dup,
               api.pkg_columnquery.numericvalue(r.toobjectid, 'EarnedAmount')
                   earnedamount,
               NULL
                   paymentid,
               NULL
                   recnum,
               TRUNC(
                   api.pkg_columnquery.datevalue(r.toobjectid, 'StatusDate'))
                   paiddate,
               f.jobid,
               NVL(api.pkg_columnquery.VALUE(r.toobjectid, 'FeeCode'), 'NA')
                   feecode,
               ft.transactionid,
               api.pkg_columnquery.numericvalue(r.toobjectid, 'LegacyKey')
                   sortcolumn1,
               r.toobjectid
                   sortcolumn2
          FROM query.o_paymenttransactions  qpt
               JOIN api.paymenttransactions pt
                   ON pt.transactionid = qpt.transactionid
               JOIN api.relationships r
                   ON r.fromobjectid = qpt.objectid
                  AND r.endpointid =
                      api.pkg_configquery.endpointidforname(
                          'o_PaymentTransactions',
                          'PaymentStatus')
               JOIN api.feetransactions ft
                   ON ft.transactionid = pt.transactionid
               JOIN api.fees f ON f.feeid = ft.feeid
               JOIN sitespecific.feeschedule_t fs
                   ON fs.objectid =
                      sitespecific.pkg_fees.getlicfeeschedulobjid(ft.feeid)
               JOIN extension.jobstatuschange st
                   ON st.jobid = f.jobid
                  AND st.mostrecent = 'Y';

    -- where qpt.ObjectId = t_PTObjectList(c).objectid;
    --***** here to include all LICENSES!!!!!!!!!
    --   end loop;
    COMMIT;                                                              --bee

    --Get The $0.00 Dollar Fee Rows
    --  for d in 1 .. t_FeeObjectList.count loop
    INSERT INTO abc.abc_accountinghistoryreport_gt
        SELECT api.pkg_columnquery.VALUE(af.jobid, 'LicenseNumber')
                   licnum,
               CASE
                   WHEN api.pkg_columnquery.VALUE(af.jobid, 'JobTypeId') =
                        api.pkg_configquery.objectdefidforname('j_License') THEN
                       SUBSTR(
                           api.pkg_columnquery.VALUE(af.jobid, 'StatusName'),
                           1,
                           3)
                   ELSE
                       NVL(
                           (SELECT DECODE(
                                       SUBSTR(
                                           api.pkg_columnquery.VALUE(
                                               r1.toobjectid,
                                               'StatusName'),
                                           1,
                                           3),
                                       'ISS', 'PEN',
                                       SUBSTR(
                                           api.pkg_columnquery.VALUE(
                                               af.jobid,
                                               'StatusName'),
                                           1,
                                           3))
                              FROM api.relationships r1
                             WHERE r1.fromobjectid = af.jobid
                               AND r1.endpointid =
                                   (api.pkg_configquery.endpointidforname(
                                        'j_Application',
                                        'License'))),
                           DECODE(
                               SUBSTR(
                                   api.pkg_columnquery.VALUE(af.jobid,
                                                             'StatusName'),
                                   1,
                                   3),
                               'ISS', 'PEN',
                               SUBSTR(
                                   api.pkg_columnquery.VALUE(af.jobid,
                                                             'StatusName'),
                                   1,
                                   3)))
               END
                   status,
               DECODE(st.statusdate,
                      NULL, st.effectivestartdate,
                      st.statusdate)
                   statusdate,
               NVL(
                   api.pkg_columnquery.VALUE(af.jobid,
                                             'BaseFileOfficeCodeCorral'),
                   api.pkg_columnquery.VALUE(af.jobid, 'DistrictOfficeCode'))
                   district,
               NVL(
                   api.pkg_columnquery.VALUE(af.jobid, 'PremAddress1Line'),
                   api.pkg_columnquery.VALUE(af.jobid,
                                             'EventLocAddressLine1'))
                   premises,
               api.pkg_columnquery.VALUE(af.jobid, 'PrimaryLicensee')
                   "NAME",
               af.transactiondate
                   entrydate,
               'I'
                   i,
               fs.description
                   trans,
               fs.licensetypecode
                   lt,
               api.pkg_columnquery.VALUE(fx.objectid, 'IsMaster')
                   m,
               NVL(api.pkg_columnquery.VALUE(fx.objectid, 'SecondaryCount'),
                   0)
                   dup,
               0
                   amount,
               api.pkg_columnquery.VALUE(fx.objectid, 'HQReceipt')
                   paymentid,
               NULL
                   recnum,
               af.transactiondate
                   paiddate,
               af.jobid,
               NVL(
                   api.pkg_columnquery.VALUE(
                       sitespecific.pkg_fees.getlicfeeschedulobjid(af.feeid),
                       'FeeCode'),
                   'NA')
                   feecode,
               af.feeid,
               NULL
                   sortcolumn1,                --The is no Legacy Key on a Fee
               fx.objectid
                   sortcolumn2                           --ObjectId of the Fee
          FROM api.fees  af
               JOIN
               TABLE(
                   CAST(
                       api.pkg_simplesearch.castableobjectsbyindex('o_Fee',
                                                                   'FeeId',
                                                                   af.feeid) AS api.udt_objectlist))
               fx
                   ON 1 = 1                                      --api.fees af
               JOIN sitespecific.feeschedule_t fs
                   ON fs.objectid =
                      sitespecific.pkg_fees.getlicfeeschedulobjid(af.feeid)
               JOIN extension.jobstatuschange st
                   ON st.jobid = af.jobid
                  AND st.mostrecent = 'Y';

    --where af.FeeId = t_FeeObjectList(d).ObjectId;
    --***** here to include all LICENSES!!!!!!!!!
    --   end loop;
    COMMIT;                                                              --bee
END abc_accountinghistoryreport;



/*
---table creation
DROP TABLE ABC.ABC_ACCOUNTINGHISTORYREPORT_GT CASCADE CONSTRAINTS;

CREATE TABLE ABC.ABC_ACCOUNTINGHISTORYREPORT_GT
(
  LICNUM          VARCHAR2(40 BYTE),
  STATUS          VARCHAR2(60 BYTE),
  STATUSDATE      DATE,
  DISTRICT        VARCHAR2(2 BYTE),
  PREMISES        VARCHAR2(100 BYTE),
  LICENSEE        VARCHAR2(250 BYTE),
  ENTRYDATE       DATE,
  I               VARCHAR2(1 BYTE),
  TRANS           VARCHAR2(20 BYTE),
  LT              VARCHAR2(2 BYTE),
  M               VARCHAR2(1 BYTE),
  DUP             NUMBER,
  AMOUNT          NUMBER,
  PAYMENTID       VARCHAR2(50 BYTE),
  RECNUM          VARCHAR2(50 BYTE),
  PAIDDATE        DATE,
  JOBID           NUMBER,
  FEECODE         VARCHAR2(20 BYTE),
  PAYMENTTRANSID  NUMBER,
  SORTCOLUMN1     NUMBER,
  SORTCOLUMN2     NUMBER
);

grant delete, insert, select, update on abc.ABC_ACCOUNTINGHISTORYREPORT_GT to posseextensions;
grant delete, insert, select, update on abc.ABC_ACCOUNTINGHISTORYREPORT_GT to public;

select * from ABC_ACCOUNTINGHISTORYREPORT_GT

*/
/
