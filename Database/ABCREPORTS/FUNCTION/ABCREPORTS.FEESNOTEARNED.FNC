CREATE OR REPLACE FUNCTION feesnotearned(p_parms        IN OUT t_parameters,
                                         p_status_ind   IN OUT VARCHAR2)
    RETURN BLOB
IS
    /**************************************************************************
        File:

        Description:    This file contains the script to load a temporary table
                        with payment transactions that should have been earned
                        but were not earned.  This script only load payment
                        transactions that are type 'I' and 'C'.  Transaction
                        types 'R' and 'V' are not loaded.

                        From this table customized un-earn reports can be
                        generated for business to validate which payment should
                        be earned.

    **************************************************************************/
    lv_status_msg  VARCHAR2(8096);
    lblob_csv      BLOB;
    ld_start       DATE;
    ld_end         DATE;
BEGIN
    DELETE feesnotearned_t;

    DBMS_LOB.createtemporary(lblob_csv, TRUE, DBMS_LOB.call);

    ld_start := TO_DATE(p_parms.get_value('START_DATE'), 'MM/DD/YYYY');
    ld_end := TO_DATE(p_parms.get_value('END_DATE'), 'MM/DD/YYYY');
    p_parms.upd_value('REPORT_DATE', TO_CHAR(SYSDATE, 'MM/DD/YYYY HH:MI PM'));


    /**********************************************************************
        Load table with payment transactions that have not been earned
    **********************************************************************/
    --    select trunc(nvl(max(tmp.transactiondate), ld_start), 'MM')
    --      into ld_start
    --      from NotEarnFees_t tmp
    --     where tmp.transactiondate >= ld_start;

    WHILE ld_start < ld_end
    LOOP
        INSERT /*+ IGNORE_ROW_ON_DUPKEY_INDEX(f, notearnfees_pk) */
               INTO feesnotearned_t f(jobtype,
                                    licensenumber,
                                    jobid,
                                    feeid,
                                    transactionid,
                                    transactiondate,
                                    description,
                                    amount,
                                    cabinamttype,
                                    earnedon,
                                    feeobjid,
                                    paymenttransactionobjectid)
              SELECT api.pkg_columnquery.VALUE(itm.jobid, 'Objectdefname')
                         jobtype,
                     api.pkg_columnquery.VALUE(itm.jobid, 'LicenseNumber')
                         licensenumber,
                     itm.jobid,
                     itm.feeid,
                     itm.transactionid,
                     itm.transactiondate,
                     api.pkg_columnquery.VALUE(o_paymenttransactions,
                                               'DescriptionForDisplay')
                         feedescription,
                     api.pkg_columnquery.numericvalue(o_fee,
                                                      'AmountForDisplay'),
                     api.pkg_columnquery.VALUE(itm.o_paymenttransactions,
                                               'CABINAmtType')
                         cabinamttype,
                     api.pkg_columnquery.VALUE(
                         api.pkg_columnquery.numericvalue(o_fee,
                                                          'LicenseFeeSchedId'),
                         'EarnedOn')
                         earnedon,
                     o_fee,
                     o_paymenttransactions
                FROM (WITH
                          t
                          AS
                              (SELECT /*+ materialize */
                                      t.feeid,
                                      f.jobid,
                                      t.transactionid,
                                      t.transactiondate,
                                      api.pkg_simplesearch.objectbyindex(
                                          'o_Fee',
                                          'FeeId',
                                          f.transactionid)    o_fee,
                                      api.pkg_simplesearch.objectbyindex(
                                          'o_PaymentTransactions',
                                          'TransactionId',
                                          t.transactionid)    o_paymenttransactions
                                 FROM finance.fees_t f
                                      JOIN finance.transactions_t t
                                          ON (f.transactionid = t.feeid)
                                WHERE f.transactionid IN
                                          (SELECT t2.transactionid
                                             FROM finance.transactions_t t2
                                            WHERE t2.transactiondate BETWEEN ld_start
                                                                         AND   ADD_MONTHS(
                                                                                   ld_start,
                                                                                   1)
                                                                             - 1
                                              AND t2.transactiontypeid = 1))
                        SELECT t.*
                          FROM t
                         WHERE o_paymenttransactions IS NOT NULL
                           AND NOT EXISTS
                                   (SELECT 1
                                      FROM t t2
                                     WHERE t2.feeid = t.feeid
                                       AND api.pkg_columnquery.datevalue(
                                               t2.o_paymenttransactions,
                                               'dup_PaymentStatus')
                                               IS NOT NULL)
                           AND api.pkg_columnquery.numericvalue(t.o_fee,
                                                                'TotalOwing') =
                               0
                           AND api.pkg_columnquery.numericvalue(
                                   t.o_fee,
                                   'AmountForDisplay') >
                               0
                           AND NVL(
                                   api.pkg_columnquery.VALUE(
                                       t.jobid,
                                       'IncludeIn1stRenewal'),
                                   'Y') =
                               'Y'
                           AND api.pkg_columnquery.VALUE(t.o_paymenttransactions,
                                                         'CABINAmtType') IN
                                   ('I', 'C')
                           AND api.pkg_columnquery.VALUE(t.o_paymenttransactions,
                                                         'IsDishonored') =
                               'N'
                           AND api.pkg_columnquery.VALUE(t.o_paymenttransactions,
                                                         'IsOverpayment') =
                               'N'
                           AND api.pkg_columnquery.VALUE(t.o_paymenttransactions,
                                                         'IsRefunded') =
                               'N'
                           AND api.pkg_columnquery.VALUE(t.o_paymenttransactions,
                                                         'IsServiceCharge') =
                               'N'
                           AND api.pkg_columnquery.VALUE(t.o_paymenttransactions,
                                                         'IsVoidedFlag') =
                               'N'
                      ORDER BY t.feeid, t.transactiondate, t.transactionid) itm
            ORDER BY LPAD(licensenumber, 7, '0'), feeid;

        DBMS_OUTPUT.put_line(ld_start || '  Rows added: ' || SQL%ROWCOUNT);
        ld_start := ADD_MONTHS(ld_start, 1);
    END LOOP;

    /**********************************************************************
        This sections removes all fees that do have payments because of
        payment transfers or were refunded.
    **********************************************************************/
    DELETE feesnotearned_t tmp
     WHERE tmp.feeobjid IN
               (  SELECT feeobjid
                    FROM feesnotearned_t m
                GROUP BY feeobjid
                  HAVING SUM(
                             NVL(
                                 api.pkg_columnquery.numericvalue(
                                     m.paymenttransactionobjectid,
                                     'PaymentAmount'),
                                 0)) <=
                         0);

    DBMS_OUTPUT.put_line('No Payments Fees Removed: ' || SQL%ROWCOUNT);

    /**********************************************************************
        This sections update the payment records with the license type
        for the primary and fee license type.  Fees not associated to a
        license type, the license type value will be NULL
    **********************************************************************/
    /* Fee license type */
    UPDATE feesnotearned_t tmp
       SET feelicensetypecode = SUBSTR(tmp.description, 1, 2)
     WHERE tmp.jobtype != 'j_MiscellaneousFee';

    /* Application Job */
    UPDATE feesnotearned_t tmp
       SET licensetypecode =
               (SELECT pltc
                  FROM (SELECT api.pkg_columnquery.VALUE(plt.toobjectid,
                                                         'LicenseTypeCode')
                                   pltc,
                               api.pkg_columnquery.VALUE(slt.toobjectid,
                                                         'LicenseTypeCode')
                                   sltc
                          FROM api.relationships  plt
                               LEFT OUTER JOIN api.relationships slt
                                   ON (slt.endpointid =
                                       api.pkg_configquery.endpointidforname(
                                           'o_PrimaryLicenseType',
                                           'LicTypeCatSecondary')
                                   AND slt.fromobjectid = plt.toobjectid
                                   AND api.pkg_columnquery.VALUE(
                                           slt.toobjectid,
                                           'LicenseTypeCode') =
                                       tmp.feelicensetypecode)
                         WHERE plt.endpointid =
                               api.pkg_configquery.endpointidforname(
                                   'j_Application',
                                   'PrimaryLicenseType')
                           AND plt.fromobjectid = tmp.jobid) lt
                 WHERE CASE
                           WHEN lt.pltc = tmp.feelicensetypecode
                           THEN
                               1
                           WHEN lt.sltc = tmp.feelicensetypecode
                           THEN
                               1
                           WHEN lt.pltc = '41'
                            AND tmp.feelicensetypecode = '42'
                           THEN
                               1
                           WHEN lt.pltc = '42'
                            AND tmp.feelicensetypecode = '41'
                           THEN
                               1
                           WHEN lt.pltc = '47'
                            AND tmp.feelicensetypecode = '48'
                           THEN
                               1
                           WHEN lt.pltc = '48'
                            AND tmp.feelicensetypecode = '47'
                           THEN
                               1
                           ELSE
                               0
                       END = 1
                   AND ROWNUM = 1)
     WHERE tmp.jobtype = 'j_Application';

    -- Get license type codes that are still missing for applications
    UPDATE feesnotearned_t tmp
       SET tmp.licensetypecode =
               (SELECT api.pkg_columnquery.VALUE(plt.toobjectid,
                                                 'LicenseTypeCode')    pltc
                  FROM api.relationships plt
                 WHERE plt.endpointid =
                       api.pkg_configquery.endpointidforname(
                           'j_Application',
                           'PrimaryLicenseType')
                   AND plt.fromobjectid = tmp.jobid
                   AND ROWNUM = 1)
     WHERE tmp.licensetypecode IS NULL
       AND tmp.jobtype = 'j_Application';

    /* License Job */
    UPDATE feesnotearned_t tmp
       SET licensetypecode =
               (SELECT pltc
                  FROM (SELECT api.pkg_columnquery.VALUE(plt.toobjectid,
                                                         'LicenseTypeCode')
                                   pltc,
                               api.pkg_columnquery.VALUE(slt.toobjectid,
                                                         'LicenseTypeCode')
                                   sltc
                          FROM api.relationships  plt
                               LEFT OUTER JOIN api.relationships slt
                                   ON (slt.endpointid =
                                       api.pkg_configquery.endpointidforname(
                                           'j_LicenseType',
                                           'LicTypeCatSecondary')
                                   AND slt.fromobjectid = plt.toobjectid
                                   AND api.pkg_columnquery.VALUE(
                                           slt.toobjectid,
                                           'LicenseTypeCode') =
                                       tmp.feelicensetypecode)
                         WHERE plt.endpointid =
                               api.pkg_configquery.endpointidforname(
                                   'j_License',
                                   'LicenseType')
                           AND plt.fromobjectid = tmp.jobid) lt
                 WHERE (NVL(lt.pltc, '00') = tmp.feelicensetypecode
                     OR NVL(lt.sltc, '00') = tmp.feelicensetypecode)
                   AND ROWNUM = 1)
     WHERE tmp.jobtype = 'j_License';

    -- Get license type codes that are still missing for licenses
    UPDATE feesnotearned_t tmp
       SET tmp.licensetypecode =
               (SELECT api.pkg_columnquery.VALUE(plt.toobjectid,
                                                 'LicenseTypeCode')    pltc
                  FROM api.relationships plt
                 WHERE plt.endpointid =
                       api.pkg_configquery.endpointidforname('j_License',
                                                             'LicenseType')
                   AND plt.fromobjectid = tmp.jobid
                   AND ROWNUM = 1)
     WHERE tmp.licensetypecode IS NULL
       AND tmp.jobtype = 'j_License';

    /* License Type Job */
    UPDATE feesnotearned_t tmp
       SET licensetypecode =
               api.pkg_columnquery.VALUE(tmp.jobid, 'LicenseTypeCode')
     WHERE tmp.jobtype = 'j_LicenseType';

    /* One Day License Job */
    UPDATE feesnotearned_t tmp
       SET licensetypecode =
               (SELECT ltc
                  FROM (SELECT api.pkg_columnquery.VALUE(plt.toobjectid,
                                                         'LicenseTypeCode')    ltc
                          FROM api.relationships plt
                         WHERE plt.endpointid =
                               api.pkg_configquery.endpointidforname(
                                   'j_OneDayLicense',
                                   'LicenseTypeCategory')
                           AND plt.fromobjectid = tmp.jobid)
                 WHERE ltc = tmp.feelicensetypecode)
     WHERE tmp.jobtype = 'j_OneDayLicense';

    /* Miscellaneous Fee Job */
    -- No license types associated with Miscellaneous fees

    /**********************************************************************
        This sections update the payment records with when the color of the
        primary license type.  Fees not associated to a license type, the
        color value will be NULL
    **********************************************************************/
    UPDATE feesnotearned_t tmp
       SET color =
               (SELECT color
                  FROM query.o_licensetypecategory ltc
                 WHERE ltc.licensetypecode = tmp.licensetypecode)
     WHERE tmp.licensetypecode IS NOT NULL;

    UPDATE feesnotearned_t tmp
       SET tmp.feecolor =
               (SELECT color
                  FROM query.o_licensetypecategory ltc
                 WHERE ltc.licensetypecode = tmp.feelicensetypecode)
     WHERE tmp.feelicensetypecode IS NOT NULL;

    /**********************************************************************
        This sections update the payment records with when the fees should
        have been earned by the system.
    **********************************************************************/
    -- expected earn date for Applications
    UPDATE feesnotearned_t t
       SET expectedearneddate =
               (SELECT MIN(
                           api.pkg_columnquery.datevalue(x.licensebatchjobid,
                                                         'CompletedDate'))    completeddate
                  FROM sitespecific.licbatchlictype_xref_t x
                 WHERE (api.pkg_columnquery.VALUE(x.licensebatchjobid,
                                                  'BatchType') =
                        'PRODUCE LICENSES'
                    AND api.pkg_columnquery.VALUE(x.licensebatchjobid,
                                                  'Color') =
                        NVL(t.feecolor, 'Pink')
                    AND TRUNC(
                            api.pkg_columnquery.datevalue(
                                x.licensebatchjobid,
                                'CompletedDate')) >=
                        TRUNC(t.transactiondate)
                    AND x.licensetypejobid =
                        (SELECT MIN(toobjectid)
                           FROM (SELECT api.pkg_columnquery.VALUE(
                                            plt.toobjectid,
                                            'LicenseTypeCode')    pltc,
                                        api.pkg_columnquery.VALUE(
                                            slt.toobjectid,
                                            'LicenseTypeCode')    sltc,
                                        plt.toobjectid
                                   FROM api.relationships  plt
                                        LEFT OUTER JOIN api.relationships slt
                                            ON (slt.endpointid =
                                                api.pkg_configquery.endpointidforname(
                                                    'o_PrimaryLicenseType',
                                                    'LicTypeCatSecondary')
                                            AND slt.fromobjectid =
                                                plt.toobjectid
                                            AND api.pkg_columnquery.VALUE(
                                                    slt.toobjectid,
                                                    'LicenseTypeCode') =
                                                t.feelicensetypecode)
                                  WHERE plt.endpointid =
                                        api.pkg_configquery.endpointidforname(
                                            'j_Application',
                                            'PrimaryLicenseType')
                                    AND plt.fromobjectid = t.jobid) lt
                          WHERE CASE
                                    WHEN lt.pltc = t.feelicensetypecode
                                    THEN
                                        1
                                    WHEN lt.sltc = t.feelicensetypecode
                                    THEN
                                        1
                                    WHEN lt.pltc = '41'
                                     AND t.feelicensetypecode = '42'
                                    THEN
                                        1
                                    WHEN lt.pltc = '42'
                                     AND t.feelicensetypecode = '41'
                                    THEN
                                        1
                                    WHEN lt.pltc = '47'
                                     AND t.feelicensetypecode = '48'
                                    THEN
                                        1
                                    WHEN lt.pltc = '48'
                                     AND t.feelicensetypecode = '47'
                                    THEN
                                        1
                                    ELSE
                                        0
                                END = 1)))
     WHERE t.earnedon = 'LICENSE ISSUANCE'
       AND t.jobtype = 'j_Application';

    -- expected earn date for Licenses
    UPDATE feesnotearned_t t
       SET expectedearneddate =
               (  SELECT MIN(
                             api.pkg_columnquery.datevalue(x.licensebatchjobid,
                                                           'CompletedDate'))    completeddate
                    FROM sitespecific.licbatchlictype_xref_t x
                   WHERE (api.pkg_columnquery.VALUE(x.licensebatchjobid,
                                                    'BatchType') =
                          'PRODUCE LICENSES'
                      AND api.pkg_columnquery.VALUE(x.licensebatchjobid,
                                                    'Color') =
                          NVL(t.feecolor, 'Pink')
                      AND TRUNC(
                              api.pkg_columnquery.datevalue(
                                  x.licensebatchjobid,
                                  'CompletedDate')) >=
                          TRUNC(t.transactiondate)
                      AND x.licensetypejobid =
                          (SELECT DISTINCT toobjectid
                             FROM (SELECT api.pkg_columnquery.VALUE(
                                              plt.toobjectid,
                                              'LicenseTypeCode')    pltc,
                                          api.pkg_columnquery.VALUE(
                                              slt.toobjectid,
                                              'LicenseTypeCode')    sltc,
                                          plt.toobjectid
                                     FROM api.relationships plt
                                          LEFT OUTER JOIN api.relationships slt
                                              ON (slt.endpointid =
                                                  api.pkg_configquery.endpointidforname(
                                                      'j_LicenseType',
                                                      'LicTypeCatSecondary')
                                              AND slt.fromobjectid =
                                                  plt.toobjectid
                                              AND api.pkg_columnquery.VALUE(
                                                      slt.toobjectid,
                                                      'LicenseTypeCode') =
                                                  t.feelicensetypecode)
                                    WHERE plt.endpointid =
                                          api.pkg_configquery.endpointidforname(
                                              'j_License',
                                              'LicenseType')
                                      AND plt.fromobjectid = t.jobid) lt
                            WHERE (NVL(lt.pltc, '00') = t.feelicensetypecode
                                OR NVL(lt.sltc, '00') = t.feelicensetypecode)
                              AND ROWNUM = 1))
                GROUP BY x.licensetypejobid, t.transactionid)
     WHERE t.earnedon = 'LICENSE ISSUANCE'
       AND t.jobtype = 'j_License';

    -- expected earn date for License Types
    UPDATE feesnotearned_t t
       SET t.expectedearneddate =
               (  SELECT MIN(
                             api.pkg_columnquery.datevalue(x.licensebatchjobid,
                                                           'CompletedDate'))    completeddate
                    FROM sitespecific.licbatchlictype_xref_t x
                   WHERE (api.pkg_columnquery.VALUE(x.licensebatchjobid,
                                                    'BatchType') =
                          'PRODUCE LICENSES'
                      AND api.pkg_columnquery.VALUE(x.licensebatchjobid,
                                                    'Color') =
                          NVL(t.feecolor, 'Pink')
                      AND TRUNC(
                              api.pkg_columnquery.datevalue(
                                  x.licensebatchjobid,
                                  'CompletedDate')) >=
                          TRUNC(t.transactiondate)
                      AND x.licensetypejobid = t.jobid)
                GROUP BY x.licensetypejobid, t.transactionid)
     WHERE t.earnedon = 'LICENSE ISSUANCE'
       AND t.jobtype = 'j_LicenseType';

    UPDATE feesnotearned_t t
       SET t.expectedearneddate = t.transactiondate
     WHERE t.earnedon != 'LICENSE ISSUANCE';


    /**********************************************************************
        This section updates the license status at the the time it should
        have been earned. (not current license status)
    **********************************************************************/
    --  Get primary status of license at time when it should have been earned
    UPDATE feesnotearned_t t
       SET t.statusname =
               NVL(
                   (SELECT js3.statusname
                      FROM extension.jobstatuschange js3
                     WHERE js3.jobstatuschangeid =
                           (SELECT MAX(js2.jobstatuschangeid)
                              FROM extension.jobstatuschange js2
                             WHERE (js2.effectivestartdate, js2.jobid) =
                                   (  SELECT MAX(js1.effectivestartdate),
                                             js1.jobid
                                        FROM extension.jobstatuschange js1
                                       WHERE js1.jobid = t.jobid
                                         AND TRUNC(js1.effectivestartdate) <=
                                             TRUNC(
                                                 NVL(t.expectedearneddate,
                                                     t.transactiondate))
                                    GROUP BY js1.jobid))),
                   api.pkg_columnquery.VALUE(t.jobid, 'StatusName'))
     /* primary fees only */
     WHERE (CASE
                WHEN NVL(t.licensetypecode, 'NA') = t.feelicensetypecode
                THEN
                    1
                WHEN NVL(t.licensetypecode, 'NA') = '41'
                 AND t.feelicensetypecode = '42'
                THEN
                    1
                WHEN NVL(t.licensetypecode, 'NA') = '42'
                 AND t.feelicensetypecode = '41'
                THEN
                    1
                WHEN NVL(t.licensetypecode, 'NA') = '47'
                 AND t.feelicensetypecode = '48'
                THEN
                    1
                WHEN NVL(t.licensetypecode, 'NA') = '48'
                 AND t.feelicensetypecode = '47'
                THEN
                    1
                WHEN t.feelicensetypecode = 'NA'
                THEN
                    1
                ELSE
                    0
            END = 1);

    --  Get status of secondary license type at the time when it should have been earned.
    -- Application Job
    UPDATE feesnotearned_t t
       SET t.statusname =
               NVL(
                   (SELECT sc2.statusname
                      FROM sitespecific.sltstatuschange_t sc2
                     WHERE sc2.sltstatuschangeid =
                           (SELECT MAX(sc1.sltstatuschangeid)
                              FROM sitespecific.sltstatuschange_t sc1
                             WHERE (sc1.relationshipid,
                                    sc1.effectivestartdate) =
                                   (  SELECT sc.relationshipid,
                                             MAX(sc.effectivestartdate)    effectivestartdate
                                        FROM api.relationships r
                                             JOIN
                                             sitespecific.sltstatuschange_t sc
                                                 ON sc.relationshipid =
                                                    r.relationshipid
                                       WHERE r.fromobjectid = t.jobid
                                         AND sc.effectivestartdate <=
                                             TRUNC(
                                                 NVL(t.expectedearneddate,
                                                     t.transactiondate))
                                         AND api.pkg_columnquery.VALUE(
                                                 r.toobjectid,
                                                 'licensetypecode') =
                                             t.feelicensetypecode
                                    GROUP BY sc.relationshipid))),
                   (SELECT status
                      FROM (SELECT api.pkg_columnquery.VALUE(
                                       plt.toobjectid,
                                       'LicenseTypeCode')    pltc,
                                   api.pkg_columnquery.VALUE(
                                       slt.toobjectid,
                                       'LicenseTypeCode')    sltc,
                                   api.pkg_columnquery.VALUE(
                                       slt.relationshipid,
                                       'status')             status
                              FROM api.relationships  plt
                                   LEFT OUTER JOIN api.relationships slt
                                       ON (slt.endpointid =
                                           api.pkg_configquery.endpointidforname(
                                               'o_PrimaryLicenseType',
                                               'LicTypeCatSecondary')
                                       AND slt.fromobjectid = plt.toobjectid
                                       AND api.pkg_columnquery.VALUE(
                                               slt.toobjectid,
                                               'LicenseTypeCode') =
                                           t.feelicensetypecode)
                             WHERE plt.endpointid =
                                   api.pkg_configquery.endpointidforname(
                                       'j_Application',
                                       'PrimaryLicenseType')
                               AND plt.fromobjectid = t.jobid) lt
                     WHERE (NVL(lt.pltc, '00') = t.feelicensetypecode
                         OR NVL(lt.sltc, '00') = t.feelicensetypecode)))
     WHERE NVL(t.licensetypecode, 'NA') != t.feelicensetypecode /* secondary fees only */
       AND t.jobtype = 'j_Application'
       AND t.statusname IS NULL;

    -- License Job
    UPDATE feesnotearned_t t
       SET t.statusname =
               NVL(
                   (SELECT sc2.statusname
                      FROM sitespecific.sltstatuschange_t sc2
                     WHERE sc2.sltstatuschangeid =
                           (SELECT MAX(sc1.sltstatuschangeid)
                              FROM sitespecific.sltstatuschange_t sc1
                             WHERE (sc1.relationshipid,
                                    sc1.effectivestartdate) =
                                   (  SELECT sc.relationshipid,
                                             MAX(sc.effectivestartdate)    effectivestartdate
                                        FROM api.relationships r
                                             JOIN
                                             sitespecific.sltstatuschange_t sc
                                                 ON sc.relationshipid =
                                                    r.relationshipid
                                       WHERE r.fromobjectid = t.jobid
                                         AND sc.effectivestartdate <=
                                             TRUNC(
                                                 NVL(t.expectedearneddate,
                                                     t.transactiondate))
                                         AND api.pkg_columnquery.VALUE(
                                                 r.toobjectid,
                                                 'licensetypecode') =
                                             t.feelicensetypecode
                                    GROUP BY sc.relationshipid))),
                   (SELECT status
                      FROM (SELECT api.pkg_columnquery.VALUE(
                                       plt.toobjectid,
                                       'LicenseTypeCode')    pltc,
                                   api.pkg_columnquery.VALUE(
                                       slt.toobjectid,
                                       'LicenseTypeCode')    sltc,
                                   api.pkg_columnquery.VALUE(
                                       slt.relationshipid,
                                       'status')             status
                              FROM api.relationships  plt
                                   LEFT OUTER JOIN api.relationships slt
                                       ON (slt.endpointid =
                                           api.pkg_configquery.endpointidforname(
                                               'j_LicenseType',
                                               'LicTypeCatSecondary')
                                       AND slt.fromobjectid = plt.toobjectid
                                       AND api.pkg_columnquery.VALUE(
                                               slt.toobjectid,
                                               'LicenseTypeCode') =
                                           t.feelicensetypecode)
                             WHERE plt.endpointid =
                                   api.pkg_configquery.endpointidforname(
                                       'j_License',
                                       'LicenseType')
                               AND plt.fromobjectid = t.jobid) lt
                     WHERE (NVL(lt.pltc, '00') = t.feelicensetypecode
                         OR NVL(lt.sltc, '00') = t.feelicensetypecode)
                       AND ROWNUM = 1))
     WHERE NVL(t.licensetypecode, 'NA') != t.feelicensetypecode /* secondary fees only */
       AND t.jobtype = 'j_License';

    -- License Type job
    UPDATE feesnotearned_t t
       SET t.statusname =
               NVL(
                   (SELECT sc2.statusname
                      FROM sitespecific.sltstatuschange_t sc2
                     WHERE sc2.sltstatuschangeid =
                           (SELECT MAX(sc1.sltstatuschangeid)
                              FROM sitespecific.sltstatuschange_t sc1
                             WHERE (sc1.relationshipid,
                                    sc1.effectivestartdate) =
                                   (  SELECT sc.relationshipid,
                                             MAX(sc.effectivestartdate)    effectivestartdate
                                        FROM api.relationships r
                                             JOIN
                                             sitespecific.sltstatuschange_t sc
                                                 ON sc.relationshipid =
                                                    r.relationshipid
                                       WHERE r.fromobjectid = t.jobid
                                         AND sc.effectivestartdate <=
                                             TRUNC(
                                                 NVL(t.expectedearneddate,
                                                     t.transactiondate))
                                         AND api.pkg_columnquery.VALUE(
                                                 r.toobjectid,
                                                 'licensetypecode') =
                                             t.feelicensetypecode
                                    GROUP BY sc.relationshipid))),
                   (SELECT api.pkg_columnquery.VALUE(r.relationshipid,
                                                     'Status')    status
                      FROM api.relationships r
                     WHERE r.fromobjectid = t.jobid
                       AND r.endpointid IN
                               (api.pkg_configquery.endpointidforname(
                                    'j_LicenseType',
                                    'LicTypeCatSecondary'))
                       AND api.pkg_columnquery.VALUE(r.toobjectid,
                                                     'licensetypecode') =
                           t.feelicensetypecode))
     WHERE NVL(t.licensetypecode, 'NA') != t.feelicensetypecode /* secondary fees only */
       AND t.jobtype = 'j_LicenseType';

    /**********************************************************************
        This sections looks to see if the payment transaction have payment
        transfers associated with the fee and payment.
    **********************************************************************/
    -- Check if the fee is associated to a payment transfer (usually transfer to)
    UPDATE feesnotearned_t t
       SET t.feetransferrel =
               (SELECT LISTAGG(r.relationshipid, ',')
                           WITHIN GROUP (ORDER BY r.relationshipid)
                  FROM api.relationships r
                 WHERE r.endpointid =
                       api.pkg_configquery.endpointidforname(
                           'p_paymentTransfer',
                           'Fee')
                   AND r.toobjectid = t.feeobjid);

    -- Check if the payment is associated to a payment transfer (usually transfer from)
    UPDATE feesnotearned_t t
       SET t.paymenttransferrel =
               (SELECT LISTAGG(r.relationshipid, ',')
                           WITHIN GROUP (ORDER BY r.relationshipid)
                  FROM api.relationships r
                 WHERE r.endpointid =
                       api.pkg_configquery.endpointidforname(
                           'p_paymentTransfer',
                           'PaymentTransaction')
                   AND r.toobjectid = t.paymenttransactionobjectid);

    /**********************************************************************
        This sections deletes all records that are not active licenses.
    **********************************************************************/
    DELETE feesnotearned_t t
     WHERE statusname NOT IN ('ACTIVE',
                              'SUREND',
                              'SURRENDERED',
                              'SUSPEN',
                              'SUSPENDED',
                              'R64B',
                              'RULE 64B',
                              'REVPEN',
                              'REV PENDING',
                              'SLMSHD',
                              'SLMS',
                              'ISSUED')
       AND t.jobtype != 'j_MiscellaneousFee';

    DBMS_OUTPUT.put_line('Inactive License Fees Removed: ' || SQL%ROWCOUNT);

    /**********************************************************************
        This sections selects only the last payment transaction to be
        earned.  Some fees can have muliple payment transactions because
        of payment transfers and correction being made.
    **********************************************************************/
    UPDATE feesnotearned_t pt
       SET pt.toearn = 'Y'
     WHERE pt.paymenttransactionobjectid IN
               (  SELECT MAX(tmp.paymenttransactionobjectid)
                    FROM feesnotearned_t tmp
                GROUP BY feeobjid);

    DBMS_OUTPUT.put_line('Fees to Earn: ' || SQL%ROWCOUNT);

    /******************************************************************************
        This sections updates the primary secondary field to indicate if the
        license fee is a primary, secondary, or branch.
    ******************************************************************************/
    UPDATE feesnotearned_t pt
       SET pt.primarysecondary =
               (SELECT CASE
                           WHEN pt.licensetypecode = pt.feelicensetypecode
                           THEN
                               (SELECT CASE NVL(cnt, 0)
                                           WHEN 0 THEN 'Primary'
                                           ELSE 'Branch'
                                       END
                                  FROM (SELECT COUNT(1)     cnt
                                          FROM api.relationships r
                                         WHERE (r.endpointid =
                                                api.pkg_configquery.endpointidforname(
                                                    'j_LicenseType',
                                                    'MasterBranchLicenseType')
                                             OR r.endpointid =
                                                api.pkg_configquery.endpointidforname(
                                                    'j_LicenseType',
                                                    'MasterLicenseType'))
                                           AND r.fromobjectid = pt.jobid))
                           ELSE
                               'Secondary'
                       END
                  FROM DUAL);


    /******************************************************************************
        Pink/Green - fees where the fee license type color is different license type
          color with no payment transfers
    ******************************************************************************/
    DBMS_LOB.append(
        lblob_csv,
        UTL_RAW.cast_to_raw(
            CHR(34) || 'Pink/Green' || CHR(34) || CHR(13) || CHR(10)));

    FOR rec
        IN (  SELECT CHR(44) -- toearn
                     || CHR(44)
                     || CHR(34)
                     || jobtype
                     || CHR(34)
                     || CHR(44)
                     || CHR(34)
                     || licensenumber
                     || CHR(34)
                     || CHR(44)
                     || CHR(34)
                     || licensetypecode
                     || CHR(34)
                     || CHR(44)
                     || CHR(34)
                     || statusname
                     || CHR(34)
                     || CHR(44)
                     || CHR(34)
                     || transactiondate
                     || CHR(34)
                     || CHR(44)
                     || CHR(34)
                     || description --fee,
                     || CHR(34)
                     || CHR(44)
                     || CHR(34)
                     || primarysecondary
                     --                     || CASE
                     --                            WHEN pt.licensetypecode = pt.feelicensetypecode
                     --                            THEN
                     --                                'Primary / Branch'
                     --                            ELSE
                     --                                'Secondary'
                     --                        END
                     || CHR(34)
                     || CHR(44)
                     || CHR(34)
                     || color --licensetypecodecolor
                     || CHR(34)
                     || CHR(44)
                     || CHR(34)
                     || feecolor --feelicensetypecodecolor
                     || CHR(34)
                     || CHR(44)
                     || amount
                     || CHR(44)
                     || CHR(34)
                     || expectedearneddate
                     || CHR(34)
                     || CHR(44)
                     || CHR(34)
                     || earnedon
                     || CHR(34)
                     || CHR(44)
                     || paymenttransactionobjectid
                     || CHR(44)
                     || jobid
                     || CHR(44)
                     || feeobjid
                     || CHR(13)
                     || CHR(10)    info
                FROM feesnotearned_t pt
               WHERE pt.feetransferrel IS NULL
                 AND pt.paymenttransferrel IS NULL
                 AND pt.feecolor != pt.color
                 AND pt.toearn = 'Y'
            ORDER BY LPAD(licensenumber, 8, '0'))
    LOOP
        DBMS_LOB.append(lblob_csv, UTL_RAW.cast_to_raw(rec.info));
    END LOOP;

    /******************************************************************************
        fees where the fees license type color is same as the license type color
          with no payment transfers
    ******************************************************************************/
    DBMS_LOB.append(
        lblob_csv,
        UTL_RAW.cast_to_raw(
            CHR(13)
            || CHR(10)
            || CHR(34)
            || 'Not Earned'
            || CHR(34)
            || CHR(13)
            || CHR(10)));

    FOR rec
        IN (  SELECT CHR(44) -- toearn
                     || CHR(44)
                     || CHR(34)
                     || jobtype
                     || CHR(34)
                     || CHR(44)
                     || CHR(34)
                     || licensenumber
                     || CHR(34)
                     || CHR(44)
                     || CHR(34)
                     || licensetypecode
                     || CHR(34)
                     || CHR(44)
                     || CHR(34)
                     || statusname
                     || CHR(34)
                     || CHR(44)
                     || CHR(34)
                     || transactiondate
                     || CHR(34)
                     || CHR(44)
                     || CHR(34)
                     || description --fee,
                     || CHR(34)
                     || CHR(44)
                     || CHR(34)
                     || primarysecondary
                     --                     || (CASE
                     --                            WHEN pt.licensetypecode = pt.feelicensetypecode
                     --                            THEN
                     --                                'Primary / Branch'
                     --                            ELSE
                     --                                'Secondary'
                     --                        END)
                     || CHR(34)
                     || CHR(44)
                     || CHR(34)
                     || color --licensetypecodecolor
                     || CHR(34)
                     || CHR(44)
                     || CHR(34)
                     || feecolor --feelicensetypecodecolor
                     || CHR(34)
                     || CHR(44)
                     || amount
                     || CHR(44)
                     || CHR(34)
                     || expectedearneddate
                     || CHR(34)
                     || CHR(44)
                     || CHR(34)
                     || earnedon
                     || CHR(34)
                     || CHR(44)
                     || paymenttransactionobjectid
                     || CHR(44)
                     || jobid
                     || CHR(44)
                     || feeobjid
                     || CHR(13)
                     || CHR(10)    info
                FROM feesnotearned_t pt
               WHERE pt.toearn = 'Y'
                 AND pt.feetransferrel IS NULL
                 AND pt.paymenttransferrel IS NULL
                 AND NVL(pt.feecolor, pt.color) = NVL(pt.color, pt.feecolor)
            ORDER BY LPAD(licensenumber, 8, '0'))
    LOOP
        DBMS_LOB.append(lblob_csv, UTL_RAW.cast_to_raw(rec.info));
    END LOOP;

    /******************************************************************************
        This script returns fees that had payments transfered in to pay the fee but
        no payment transfer out of any part of the payment
    ******************************************************************************/
    DBMS_LOB.append(
        lblob_csv,
        UTL_RAW.cast_to_raw(
            CHR(13)
            || CHR(10)
            || CHR(34)
            || 'Transfers Not Earned'
            || CHR(34)
            || CHR(13)
            || CHR(10)));

    FOR rec
        IN (  SELECT CHR(44) -- toearn
                     || CHR(44)
                     || CHR(34)
                     || jobtype
                     || CHR(34)
                     || CHR(44)
                     || CHR(34)
                     || licensenumber
                     || CHR(34)
                     || CHR(44)
                     || CHR(34)
                     || licensetypecode
                     || CHR(34)
                     || CHR(44)
                     || CHR(34)
                     || statusname
                     || CHR(34)
                     || CHR(44)
                     || CHR(34)
                     || transactiondate
                     || CHR(34)
                     || CHR(44)
                     || CHR(34)
                     || description --fee,
                     || CHR(34)
                     || CHR(44)
                     || CHR(34)
                     || primarysecondary
                     --                     || CASE
                     --                            WHEN pt.licensetypecode = pt.feelicensetypecode
                     --                            THEN
                     --                                'Primary / Branch'
                     --                            ELSE
                     --                                'Secondary'
                     --                        END
                     || CHR(34)
                     || CHR(44)
                     || CHR(34)
                     || color --licensetypecodecolor
                     || CHR(34)
                     || CHR(44)
                     || CHR(34)
                     || feecolor --feelicensetypecodecolor
                     || CHR(34)
                     || CHR(44)
                     || amount
                     || CHR(44)
                     || CHR(34)
                     || expectedearneddate
                     || CHR(34)
                     || CHR(44)
                     || CHR(34)
                     || earnedon
                     || CHR(34)
                     || CHR(44)
                     || paymenttransactionobjectid
                     || CHR(44)
                     || jobid
                     || CHR(44)
                     || feeobjid
                     || CHR(44)
                     || feetransferrel --transfer_in,
                     || CHR(44)
                     || paymenttransferrel --transfer_out
                     || CHR(13)
                     || CHR(10)    info
                FROM feesnotearned_t pt
               WHERE (pt.feetransferrel IS NOT NULL
                   OR pt.paymenttransferrel IS NOT NULL)
                 AND pt.toearn = 'Y'
            ORDER BY LPAD(licensenumber, 8, '0'))
    LOOP
        DBMS_LOB.append(lblob_csv, UTL_RAW.cast_to_raw(rec.info));
    END LOOP;


    COMMIT;
    RETURN lblob_csv;
END;
/