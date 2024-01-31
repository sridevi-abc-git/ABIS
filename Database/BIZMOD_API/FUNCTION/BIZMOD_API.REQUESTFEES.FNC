CREATE OR REPLACE FUNCTION BIZMOD_API.requestfees(a_packet       IN CLOB,
                                                  a_seq          IN NUMBER)
    RETURN CLOB
IS
    -- ****************************************************************************
    -- File:    BIZMOD_API.REQUESTFEES.FNC
    -- Author:  Timothy J. Lord
    --
    -- History
    -------------------------------------------------------------------------------
    -- 11/17/2022  TJL  Rewrite of REQUESTFEES
    -- 06/27/2023  TJL  BIZ-11779 Correct premise address not being retrieved
    -- 06/30/2023  TJL  Fixed bug with incorrect message number.
    -- 01/29/2024  APD  Ordered lic view in main loop to make sure j_license row is first
    -- ****************************************************************************

    FUNCTION get_awf(a_licensetypejobid IN NUMBER)
        RETURN fee_tbl
    IS
        t_feetbl       fee_tbl;
    BEGIN
        SELECT fee_rec(
                   licensetypejobid, -- jobid
                   'P', -- primarysecondary
                   api.pkg_columnquery.datevalue(a.licensetypejobid,
                                                 'expirationdate'),
                   api.pkg_columnquery.datevalue(a.licensetypejobid,
                                                 'renewaldate'),
                   TO_DATE(
                       api.pkg_columnquery.VALUE(a.licensetypejobid,
                                                 'LastDate50Penalty'),
                       'Mon dd, yyyy'),
                   TO_DATE(
                       api.pkg_columnquery.VALUE(a.licensetypejobid,
                                                 'LastDate100Penalty'),
                       'Mon dd, yyyy'),
                   a.licensetypecode,
                   --                   NULL,                                      -- feescheduleid
                   'AWF', -- feeactivity,
                   --                   'P',                                    -- primarysecondary
                   'AWF', -- description,
                   api.pkg_columnquery.VALUE(a.licensetypejobid,
                                             'LicenseTypeName'),
                   NVL(
                       api.pkg_columnquery.numericvalue(a.renfeeobjid,
                                                        'Quantity'),
                       0), -- secondarycount,
                   'M'
                   || CASE
                          WHEN api.pkg_columnquery.numericvalue(
                                   a.renfeeobjid,
                                   'Quantity')
                                   IS NOT NULL
                          THEN
                              '-'
                              || TO_CHAR(
                                     api.pkg_columnquery.numericvalue(
                                         a.renfeeobjid,
                                         'Quantity'),
                                     'FM000')
                          ELSE
                              NULL
                      END, -- quantity,
                   a.awffeeamount, -- amount
                   0, -- adjustedamount,
                   NVL(-p.amountpaid, 0),
                   (a.awffeeamount - NVL(p.amountpaid, 0)), -- totalowing,
                   'New', -- status
                   NULL -- feeobjectid
                       )
          BULK COLLECT INTO t_feetbl
          FROM awf_t  a
               LEFT OUTER JOIN e_payments_t p
                   ON (p.licensenumber = a.licensenumber
                   AND p.licensetypecode = a.licensetypecode
                   AND p.createddate > ADD_MONTHS(a.expirationdate, -12) -->= a.awfdate
                   AND p.description = a.description)
         WHERE a.licensetypejobid = a_licensetypejobid
           AND a.awffeeamount > 0
           AND NOT EXISTS -- make sure fee has not already been created
                   (SELECT 1
                      FROM api.fees f
                     WHERE f.jobid = a.licensetypejobid
                       AND f.transactiondate >
                           ADD_MONTHS(a.expirationdate, -12) -- a.awfdate
                       AND f.description LIKE '%AWF%')
           AND p.depositbatchid IS NULL;

        DBMS_OUTPUT.put_line(
            a_licensetypejobid || '  AWF count: ' || t_feetbl.COUNT);
        --                DBMS_OUTPUT.put_line('awf::totalowing: ' || t_feetbl(1).totalowing);
        RETURN t_feetbl;
    END;


    PROCEDURE get_fee_amounts(license IN license_tbl, fees IN OUT fee_tbl)
    IS
        t_totalowing   NUMBER;
        t_caculate     BOOLEAN;
    BEGIN
        FOR indx IN 1 .. fees.COUNT
        LOOP
            IF (fees(indx).feeobjid IS NOT NULL)
            THEN
                fees(indx).secondarycount :=
                    NVL(
                        api.pkg_columnquery.numericvalue(fees(indx).feeobjid,
                                                         'Quantity'),
                        0);
                fees(indx).amount :=
                    api.pkg_columnquery.numericvalue(fees(indx).feeobjid,
                                                     'Amount');
                fees(indx).paidamount :=
                    api.pkg_columnquery.numericvalue(fees(indx).feeobjid,
                                                     'PaidAmount');
                fees(indx).quantity :=
                    CASE
                        WHEN fees(indx).primarysecondary = 'P'
                        THEN
                            'M'
                            || CASE
                                   WHEN fees(indx).secondarycount > 0
                                   THEN
                                       '-'
                                       || TO_CHAR(fees(indx).secondarycount,
                                                  'FM000')
                                   ELSE
                                       NULL
                               END
                        ELSE
                            '-'
                            || TO_CHAR(fees(indx).secondarycount, 'FM000')
                    END;

                t_totalowing :=
                    api.pkg_columnquery.numericvalue(fees(indx).feeobjid,
                                                     'TotalOwing');

                -- check if penality fees have to be supply if not already applied
                CASE
                    WHEN TRUNC(SYSDATE) > fees(indx).lastdate50penalty
                     AND fees(indx).feeactivity != 'REN100'
                     AND SUBSTR(fees(indx).feeactivity, 1, 3) = 'REN'
                    THEN
                        t_caculate := TRUE;
                        fees(indx).feeactivity := 'REN100';
                    WHEN TRUNC(SYSDATE) BETWEEN (fees(indx).renewaldate + 1)
                                            AND fees(indx).lastdate50penalty
                     AND fees(indx).feeactivity != 'REN50'
                     AND SUBSTR(fees(indx).feeactivity, 1, 3) = 'REN'
                    THEN
                        t_caculate := TRUE;
                        fees(indx).feeactivity := 'REN50';
                    ELSE
                        t_caculate := FALSE;
                        fees(indx).adjustedamount :=
                            api.pkg_columnquery.numericvalue(
                                fees(indx).feeobjid,
                                'AdjustedAmount');
                        fees(indx).description :=
                            api.pkg_columnquery.VALUE(
                                fees(indx).feeobjid,
                                'DescriptionForDisplay');
                        fees(indx).totalowing := t_totalowing;
                END CASE;

                IF (t_caculate)
                THEN
                    fees(indx).status := 'Penalty';

                    SELECT -- figure out adjustment amount
                             CASE fees(indx).primarysecondary
                                 WHEN 'P'
                                 THEN
                                       fs.primaryamount
                                     + (  fs.secondaryamount
                                        * fees(indx).secondarycount)
                                 WHEN 'S'
                                 THEN
                                     (  fs.secondaryamount
                                      * fees(indx).secondarycount)
                                 WHEN 'B'
                                 THEN
                                       fs.branchamount
                                     + (  fs.secondaryamount
                                        * fees(indx).secondarycount)
                             END
                           - fees(indx).amount,
                           fs.licensetypecode || ' - ' || fs.description
                      INTO fees(indx).adjustedamount, fees(indx).description
                      FROM sitespecific.feeschedule_t  fs
                           JOIN sitespecific.feeschedule_t fs2
                               ON (NVL(fs.licensetypecode, 'x') =
                                   NVL(fs2.licensetypecode, 'x')
                               AND NVL(fs.otherfeecode, 'x') =
                                   NVL(fs2.otherfeecode, 'x')
                               AND NVL(fs.gallonagerange, 'x') =
                                   NVL(fs2.gallonagerange, 'x')
                               AND NVL(fs.populationrange, 'x') =
                                   NVL(fs2.populationrange, 'x')
                               AND NVL(fs.numberofmonthslicensed, 'x') =
                                   NVL(fs2.numberofmonthslicensed, 'x')
                               AND NVL(fs.feetier, 'x') =
                                   NVL(fs2.feetier, 'x')
                               AND fs2.objectid =
                                   api.pkg_columnquery.numericvalue(
                                       fees(indx).feeobjid,
                                       'LicenseFeeSchedId'))
                     WHERE fs.feeactivity = fees(indx).feeactivity
                       AND fs.effectivedate =
                           (SELECT MAX(fs2.effectivedate)
                              FROM sitespecific.feeschedule_t fs2
                             WHERE NVL(fs2.licensetypecode, '0') =
                                   NVL(fs.licensetypecode, '0')
                               AND fs2.feeactivity = fs.feeactivity
                               AND NVL(fs2.gallonagerange, 'x') =
                                   NVL(fs.gallonagerange, 'x')
                               AND NVL(fs2.populationrange, 'x') =
                                   NVL(fs.populationrange, 'x')
                               AND NVL(fs2.numberofmonthslicensed, 'x') =
                                   NVL(fs.numberofmonthslicensed, 'x')
                               AND NVL(fs2.feetier, 'x') =
                                   NVL(fs.feetier, 'x')
                               AND NVL(fs2.otherfeecode, 'x') =
                                   NVL(fs.otherfeecode, 'x')
                               AND fs2.effectivedate <=
                                   fees(indx).renewaldate);

                    fees(indx).totalowing :=
                        t_totalowing + fees(indx).adjustedamount;
                END IF;
            END IF;
        END LOOP;
    END;

    FUNCTION get_fees(license IN OUT license_tbl)
        RETURN fee_tbl
    IS
        fees           fee_tbl := fee_tbl();
        fees_tmp       fee_tbl;
    BEGIN
        FOR indx IN 1 .. license.COUNT
        LOOP
            SELECT fee_rec(
                       fees.jobid,
                       primarysecondary,
                       license(indx).expirationdate,
                       license(indx).renewaldate,
                       license(indx).lastdate50penalty,
                       license(indx).lastdate100penalty,
                       fees.licensetypecode,
                       fees.feeactivity,
                       NULL,
                       fees.licensetypename,
                       NULL,
                       NULL,
                       NULL,
                       NULL,
                       NULL,
                       NULL,
                       NVL(
                           (SELECT 'Self-certified'
                              FROM abc.self_certification sc
                             WHERE sc.licensenumber =
                                   api.pkg_columnquery.VALUE(fees.jobid,
                                                             'LicenseNumber') -- t_licensenumber
                               AND sc.licensetypecode = fees.licensetypecode
                               AND sc.expirationdate =
                                   license(1).expirationdate
                               AND sc.eligible = 'Y'),
                           (SELECT CASE
                                       WHEN fees.status IN
                                                ('REVPEN', 'REV PENDING')
                                       THEN
                                           'Revoke-pending'
                                       WHEN fees.status = 'SLMS HOLD'
                                       THEN
                                           'SLMS-hold'
                                       ELSE
                                           'New'
                                   END
                              FROM DUAL)),
                       fees.feeobjid)
              BULK COLLECT INTO fees_tmp
              FROM (SELECT DISTINCT
                           'S'
                               primarysecondary,
                           SUBSTR(f.description, 1, 2)
                               licensetypecode,
                           fs.feeactivity,
                           api.pkg_columnquery.VALUE(ltc.objectid,
                                                     'LicenseTypeName')
                               licensetypename,
                           sltc.status,
                           reo.objectid
                               feeobjid,
                           f.jobid
                      FROM api.fees  f
                           JOIN api.registeredexternalobjects reo
                               ON reo.linkvalue = TO_CHAR(f.feeid)
                              AND reo.objectdefid =
                                  api.pkg_configquery.objectdefidforname(
                                      'o_Fee')
                           JOIN sitespecific.feeschedule_t fs
                               ON fs.objectid =
                                  api.pkg_columnquery.numericvalue(
                                      reo.objectid,
                                      'LicenseFeeSchedid')
                           JOIN query.r_licensetypeltcatsecondary sltc
                               ON (sltc.licensetypejobid = f.jobid)
                           JOIN query.o_licensetypecategory ltc
                               ON (sltc.licensetypecategoryobjectid =
                                   ltc.objectid
                               AND ltc.licensetypecode = fs.licensetypecode)
                     WHERE f.jobid = license(indx).jobid
                       AND sltc.status IN ('ACTIVE',
                                           'SURRENDERED',
                                           'RULE 64B',
                                           'SLMS HOLD',
                                           'SUSPENDED',
                                           'REVPEN',
                                           'REV PENDING')
                       AND fs.licensetypecode !=
                           api.pkg_columnquery.VALUE(f.jobid,
                                                     'dup_LicenseTypeCode')
                       AND (f.transactiondate, fs.licensetypecode) =
                           (  SELECT MAX(f2.transactiondate),
                                     fs2.licensetypecode
                                FROM api.fees f2
                                     JOIN api.registeredexternalobjects reo
                                         ON reo.linkvalue = TO_CHAR(f2.feeid)
                                        AND reo.objectdefid =
                                            api.pkg_configquery.objectdefidforname(
                                                'o_Fee') --t_feeobjectdefid
                                     JOIN sitespecific.feeschedule_t fs2
                                         ON fs2.objectid =
                                            api.pkg_columnquery.numericvalue(
                                                reo.objectid,
                                                'LicenseFeeSchedid')
                               WHERE f.jobid = f2.jobid
                                 AND fs.licensetypecode = fs2.licensetypecode
                                 AND fs2.feeactivity = fs.feeactivity
                                 AND f.transactiondate >
                                     ADD_MONTHS(
                                         api.pkg_columnquery.datevalue(
                                             f2.jobid,
                                             'dup_ExpirationDate'),
                                         -12)
                            GROUP BY fs2.licensetypecode)
                    UNION
                    -- Primary / Branch License Types
                    SELECT (SELECT CASE
                                       WHEN MAX(r.toobjectid) IS NULL
                                       THEN
                                           'P'
                                       ELSE
                                           'B'
                                   END
                              FROM api.relationships r
                             WHERE r.endpointid =
                                   api.pkg_configquery.endpointidforname(
                                       'j_LicenseType',
                                       'MasterLicenseType')
                               AND r.fromobjectid = f.jobid)
                               secondaryprimary,
                           SUBSTR(f.description, 1, 2)
                               licensetype,
                           fs.feeactivity,
                           api.pkg_columnquery.VALUE(f.jobid,
                                                     'LicenseTypeName')
                               licensetypename,
                           api.pkg_columnquery.VALUE(f.jobid, 'StatusName')
                               status,
                           reo.objectid
                               feeobjid,
                           f.jobid
                      FROM api.fees  f
                           JOIN api.registeredexternalobjects reo
                               ON reo.linkvalue = TO_CHAR(f.feeid)
                              AND reo.objectdefid =
                                  api.pkg_configquery.objectdefidforname(
                                      'o_Fee')
                           JOIN sitespecific.feeschedule_t fs
                               ON fs.objectid =
                                  api.pkg_columnquery.numericvalue(
                                      reo.objectid,
                                      'LicenseFeeSchedid')
                           JOIN api.relationships r
                               ON (r.endpointid =
                                   api.pkg_configquery.endpointidforname(
                                       'j_LicenseType',
                                       'LicTypeCatPrimary')
                               AND r.fromobjectid = f.jobid
                               AND fs.licensetypecode =
                                   api.pkg_columnquery.VALUE(
                                       r.toobjectid,
                                       'LicenseTypeCode'))
                     WHERE f.jobid = license(indx).jobid
                       AND api.pkg_columnquery.VALUE(f.jobid, 'StatusName') IN
                               ('ACTIVE',
                                'REVPEN',
                                'SUREND',
                                'R64B',
                                'SLMSRV',
                                'SUSPEN')
                       AND (f.transactiondate, fs.licensetypecode) =
                           (  SELECT MAX(f2.transactiondate),
                                     fs2.licensetypecode
                                FROM api.fees f2
                                     JOIN api.registeredexternalobjects reo
                                         ON reo.linkvalue = TO_CHAR(f2.feeid)
                                        AND reo.objectdefid =
                                            api.pkg_configquery.objectdefidforname(
                                                'o_Fee') --t_feeobjectdefid
                                     JOIN sitespecific.feeschedule_t fs2
                                         ON fs2.objectid =
                                            api.pkg_columnquery.numericvalue(
                                                reo.objectid,
                                                'LicenseFeeSchedid')
                               WHERE f.jobid = f2.jobid
                                 AND fs.licensetypecode = fs2.licensetypecode
                                 AND fs2.feeactivity = fs.feeactivity
                                 AND f.transactiondate >
                                     ADD_MONTHS(
                                         api.pkg_columnquery.datevalue(
                                             f2.jobid,
                                             'dup_ExpirationDate'),
                                         -12)
                            GROUP BY fs2.licensetypecode)) fees
             WHERE NOT EXISTS
                       (SELECT 1
                          FROM bizmod_api.e_payments_t p
                         WHERE p.feeobjid = fees.feeobjid
                           AND p.depositbatchdate IS NOT NULL);

            IF (fees_tmp.COUNT > 0)
            THEN
                fees := fees MULTISET UNION fees_tmp;
            END IF;

            IF (api.pkg_columnquery.VALUE(license(indx).jobid,
                                          'LicenseTypeCode') IN
                    ('02', '22'))
            THEN
                fees := fees MULTISET UNION get_awf(license(indx).jobid);
            END IF;
        END LOOP;

        get_fee_amounts(license => license, fees => fees);

        RETURN fees;
    END;
-- *****************************************************************************
--  Main processing loop
-- *****************************************************************************
BEGIN
    DECLARE
        license        license_tbl;
        fees           fee_tbl := fee_tbl();
        fees_tmp       fee_tbl;
        t_json         CLOB;
        t_licensenumber VARCHAR2(10);
        t_paid         VARCHAR2(1);
        t_amountpaid   NUMBER;
        t_totalowing   NUMBER;
    BEGIN
        SELECT json_value(a_packet, '$.*.LICENSENUMBER')
          INTO t_licensenumber
          FROM DUAL;

        WITH
            lic
            AS
                (  SELECT ROWNUM
                              line,
                          o.objectid
                              jobid,
                          api.pkg_columnquery.VALUE(o.objectid, 'StatusName')
                              statusname,
                          api.pkg_columnquery.datevalue(o.objectid,
                                                        'dup_ExpirationDate')
                              expirationdate,
                          api.pkg_columnquery.datevalue(o.objectid,
                                                        'RenewalDate')
                              renewaldate,
                          TO_DATE(
                              api.pkg_columnquery.VALUE(o.objectid,
                                                        'LastDate50Penalty'),
                              'Mon dd, yyyy')
                              lastdate50penalty,
                          TO_DATE(
                              api.pkg_columnquery.VALUE(o.objectid,
                                                        'LastDate100Penalty'),
                              'Mon dd, yyyy')
                              lastdate100penalty
                     FROM (SELECT objectid
                             FROM TABLE(
                                      CAST(
                                          api.pkg_simplesearch.castableobjectsbyindex(
                                              a_objectdefname => 'j_License',
                                              a_columnname => 'ExternalFileNum',
                                              a_value     => t_licensenumber)
                                              AS api.udt_objectlist)) o
                           UNION
                           SELECT objectid
                             FROM TABLE(
                                      CAST(
                                          api.pkg_simplesearch.castableobjectsbyindex(
                                              a_objectdefname =>
                                                  'j_LicenseType',
                                              a_columnname =>
                                                  'dup_LicenseExternalFileNum',
                                              a_value     => t_licensenumber)
                                              AS api.udt_objectlist))) o
                 ORDER BY renewaldate NULLS FIRST) -- Ensure j_license is first APD
        SELECT license_rec(lic.line,
                           lic.jobid,
                           lic.statusname,
                           expirationdate,
                           renewaldate,
                           lastdate50penalty,
                           lastdate100penalty,
                           NULL,
                           NULL)
          BULK COLLECT INTO license
          FROM lic
         WHERE lic.statusname IN ('ACTIVE',
                                  'REVPEN',
                                  'SUREND',
                                  'R64B',
                                  'SLMSRV',
                                  'SUSPEN');

        IF (license.COUNT > 0)
        THEN
            fees := get_fees(license => license);

            IF (fees.COUNT = 0)
            THEN
                license(1).msgno := 2;
                license(1).msg := 'No Fees Found';
            ELSE
                t_paid := NULL;

                FOR indx2 IN 1 .. fees.COUNT
                LOOP
                    SELECT NVL(SUM(fee.totalowing), 0)
                      INTO t_totalowing
                      FROM TABLE(fees) fee
                     WHERE NOT EXISTS
                               (SELECT 1
                                  FROM bizmod_api.e_payments_t p
                                 WHERE p.feeobjid = fee.feeobjid);

                    CASE
                        WHEN TRUNC(SYSDATE) > fees(indx2).lastdate100penalty
                        THEN
                            t_paid := 'R';
                            fees(indx2).totalowing := 0;
                        WHEN t_totalowing > 0
                        THEN
                            t_paid := 'N';
                        ELSE
                            t_paid := 'Y';
                    END CASE;
                END LOOP;

                IF (t_paid = 'Y')
                THEN
                    license(1).msgno := 12;
                    license(1).msg := 'Processing Paid Fees';
                END IF;

                IF (t_paid = 'R')
                THEN
                    license(1).msgno := 13;
                    license(1).msg := 'Fee cannot be paid online';
                END IF;
            END IF;

            SELECT json_object(
                       'PACKET_TYPE' VALUE 'FEES',
                       'DATA' VALUE
                           json_object(
                               'LICENSENUMBER' VALUE t_licensenumber,
                               'LICENSEENAME' VALUE
                                   api.pkg_columnquery.VALUE(lic.jobid,
                                                             'LicenseeNames'),
                               'BUSINESSNAME' VALUE
                                   api.pkg_columnquery.VALUE(lic.jobid,
                                                             'PrimaryDBA'),
                               'PREMISEADDRESS' VALUE
                                   api.pkg_columnquery.VALUE(
                                       lic.jobid,
                                       'PremAddress1Line'),
                               'TOTALAMOUNTDUE' VALUE
                                   (SELECT SUM(
                                                 fee.amount
                                               + fee.adjustedamount
                                               + fee.paidamount)
                                      FROM TABLE(fees) fee),
                               'MSGNO' VALUE lic.msgno,
                               'MSG' VALUE lic.msg,
                               'FEES' VALUE
                                   (SELECT json_arrayagg(
                                               json_object(
                                                   'EXPIRATIONDATE' VALUE
                                                       fee.expirationdate,
                                                   'DUEDATE' VALUE
                                                       fee.renewaldate,
                                                   'DUEDATE50' VALUE
                                                       fee.lastdate50penalty,
                                                   'DUEDATE100' VALUE
                                                       fee.lastdate100penalty,
                                                   'LICENSETYPECODE' VALUE
                                                       fee.licensetypecode,
                                                   'DESCRIPTION' VALUE
                                                       fee.description,
                                                   'LICENSETYPENAME' VALUE
                                                       fee.licensetypename,
                                                   'QUANTITY' VALUE
                                                       fee.quantity,
                                                   'AMOUNT' VALUE fee.amount,
                                                   'PENALTY' VALUE
                                                       CASE
                                                           WHEN fee.adjustedamount >
                                                                0
                                                           THEN
                                                               fee.adjustedamount
                                                           ELSE
                                                               0
                                                       END,
                                                   'ADJUSTMENTS' VALUE
                                                       CASE
                                                           WHEN fee.adjustedamount <
                                                                0
                                                           THEN
                                                               fee.adjustedamount
                                                           ELSE
                                                               0
                                                       END,
                                                   'AMOUNTPAID' VALUE
                                                       fee.paidamount,
                                                   'AMOUNTDUE' VALUE
                                                         fee.amount
                                                       + fee.adjustedamount
                                                       + fee.paidamount,
                                                   'STATUS' VALUE fee.status,
                                                   'FEEOBJID' VALUE
                                                       fee.feeobjid))
                                      FROM TABLE(fees) fee
                                     WHERE fee.totalowing > 0)
                               ABSENT ON NULL))
              INTO t_json
              FROM TABLE(license) lic
             WHERE api.pkg_columnquery.VALUE(lic.jobid, 'objectdefname') =
                   'j_License'
               AND ROWNUM = 1;
        ELSE
            t_json :=
                '{"PACKET_TYPE":"MESSAGE","DATA":{"MSGNO":"1","MSG":"License Number Not Found"}}';
        END IF;

        RETURN t_json;
    EXCEPTION
        WHEN OTHERS
        THEN
            DBMS_OUTPUT.put_line(
                SQLERRM
                || CHR(13)
                || CHR(10)
                || DBMS_UTILITY.format_error_backtrace);

            RETURN t_json;
    END;
END;
/


GRANT EXECUTE ON BIZMOD_API.REQUESTFEES TO BIZMOD_USER;
