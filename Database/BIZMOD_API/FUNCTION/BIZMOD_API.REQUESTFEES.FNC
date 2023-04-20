CREATE OR REPLACE FUNCTION BIZMOD_API.requestfees(a_packet IN CLOB, a_seq IN NUMBER)
    RETURN CLOB
IS
   
----------------------------------------------------------------------------

---12/17/2021  Pawanjit kaur    Added LicenseTypeName column as per BIZ-4491 requirement

----------------------------------------------------------------------------

 PROCEDURE get_penalityamount(a_licensefeeschedid IN NUMBER,
                                 a_primarysecondary IN VARCHAR2,
                                 a_feeactivity  IN     VARCHAR2,
                                 a_secondarycount IN   NUMBER,
                                 a_description  IN OUT VARCHAR2,
                                 a_adjustedamount IN OUT VARCHAR2,
                                 a_originalfeeamount IN NUMBER)
    IS
        t_primaryamount     NUMBER;
        t_secondaryamount   NUMBER;
        t_branchamount      NUMBER;
        t_amount            NUMBER;
        t_count             NUMBER := NVL(a_secondarycount, 0);
    BEGIN
        SELECT fs.primaryamount,
               fs.secondaryamount,
               fs.branchamount,
                  fs.licensetypecode
               || ' - '
               || fs.description
          INTO t_primaryamount,
               t_secondaryamount,
               t_branchamount,
               a_description
          FROM sitespecific.feeschedule_t fs
               JOIN sitespecific.feeschedule_t fs2
               ON (NVL(fs.licensetypecode, 'x') = NVL(fs2.licensetypecode, 'x')
               AND NVL(fs.otherfeecode, 'x') = NVL(fs2.otherfeecode, 'x')
               AND NVL(fs.gallonagerange, 'x') = NVL(fs2.gallonagerange, 'x')
               AND NVL(fs.populationrange, 'x') = NVL(fs2.populationrange, 'x')
               AND NVL(fs.numberofmonthslicensed, 'x') = NVL(fs2.numberofmonthslicensed, 'x')
               AND NVL(fs.feetier, 'x') = NVL(fs2.feetier, 'x')
               AND fs2.objectid = a_licensefeeschedid)
         WHERE fs.feeactivity = a_feeactivity
           AND fs.effectivedate = (SELECT MAX(fs2.effectivedate)
                                     FROM sitespecific.feeschedule_t fs2
                                    WHERE NVL(fs2.licensetypecode, '0') = NVL(fs.licensetypecode, '0')
                                      AND fs2.feeactivity = fs.feeactivity
                                      AND NVL(fs2.gallonagerange, 'x') = NVL(fs.gallonagerange, 'x')
                                      AND NVL(fs2.populationrange, 'x') = NVL(fs.populationrange, 'x')
                                      AND NVL(fs2.numberofmonthslicensed, 'x') = NVL(fs.numberofmonthslicensed, 'x')
                                      AND NVL(fs2.feetier, 'x') = NVL(fs.feetier, 'x')
                                      AND NVL(fs2.otherfeecode, 'x') = NVL(fs.otherfeecode, 'x'));

        t_amount           :=
            CASE a_primarysecondary
                WHEN 'P' THEN t_primaryamount + (t_secondaryamount * t_count)
                WHEN 'S' THEN (t_secondaryamount * t_count)
                WHEN 'B' THEN t_branchamount + (t_secondaryamount * t_count)
            END;
        a_adjustedamount   := (t_amount - a_originalfeeamount);
    END;
BEGIN
    DECLARE
        -- *****************************************************************************

        -- *****************************************************************************
        t_licensenumber    VARCHAR2(10);

        t_msg              VARCHAR2(4000 BYTE);
        t_skip             BOOLEAN := FALSE;
        t_comma            BOOLEAN := FALSE;
        t_packet           CLOB := EMPTY_CLOB();
        t_fees             CLOB := EMPTY_CLOB();
        t_totalamountdue   NUMBER := 0;
        t_owing            VARCHAR2(1);
        t_sqlerrm          VARCHAR2(4000);
        t_trace            VARCHAR2(4000);
    BEGIN
        SELECT json_value(a_packet, '$.*.LICENSENUMBER') INTO t_licensenumber FROM DUAL;

        -- get license type job id
        FOR lic
            IN (SELECT ROWNUM
                           line,
                       o.objectid
                           jobid,
                       api.pkg_columnquery.VALUE(o.objectid, 'StatusName')
                           statusname,
                       api.pkg_columnquery.datevalue(o.objectid, 'dup_ExpirationDate')
                           expirationdate,
                       api.pkg_columnquery.datevalue(o.objectid, 'RenewalDate')
                           renewaldate,
                       TO_DATE(api.pkg_columnquery.VALUE(o.objectid, 'LastDate50Penalty'), 'Mon dd, yyyy')
                           lastdate50penalty,
                       TO_DATE(api.pkg_columnquery.VALUE(o.objectid, 'LastDate100Penalty'), 'Mon dd, yyyy')
                           lastdate100penalty
                  FROM TABLE(
                           CAST(
                               api.pkg_simplesearch.castableobjectsbyindex(
                                   a_objectdefname => 'j_LicenseType',
                                   a_columnname => 'dup_LicenseExternalFileNum',
                                   a_value     => t_licensenumber) AS api.udt_objectlist)) o)
        LOOP
            CONTINUE WHEN lic.expirationdate IS NULL;

            -- do not process license types that are not activie
            CONTINUE WHEN lic.statusname NOT IN ('ACTIVE',
                                                 'REVPEN',
                                                 'SUREND',
                                                 'R64B',
                                                 'SLMSRV',
                                                 'SUSPEN');

            --dbms_output.put_line('object id: ' || lic.jobid);
            IF (NOT t_skip) THEN
                t_packet   :=
                       t_packet
                    || '{"PACKET_TYPE":"RENEWALFEES",';
                t_packet   :=
                       t_packet
                    || '"DATA":{';
                t_packet   :=
                       t_packet
                    || '"LICENSENUMBER":"'
                    || t_licensenumber
                    || '",';
                t_packet   :=
                       t_packet
                    || '"LICENSEENAME":"'
                    || api.pkg_columnquery.VALUE(lic.jobid, 'LicenseeNames')
                    || '",';
                t_packet   :=
                       t_packet
                    || '"BUSINESSNAME":"'
                    || api.pkg_columnquery.VALUE(lic.jobid, 'PrimaryDBA')
                    || '",';
                t_packet   :=
                       t_packet
                    || '"PREMISEADDRESS":"'
                    || api.pkg_columnquery.VALUE(lic.jobid, 'PremAddress1stOf2Lines')
                    || ','
                    || api.pkg_columnquery.VALUE(lic.jobid, 'PremAddress2ndOf2Lines')
                    || '",';
                t_skip   := TRUE;

                -- check if payment made to one of mutiple fees with other fees not paid
                SELECT CASE WHEN SUM(amount) + SUM(paidamount) > 0 THEN 'Y' ELSE 'N' END owning
                  INTO t_owing
                  FROM api.fees f
                 WHERE f.jobid = lic.jobid
                   AND f.transactiondate > api.pkg_columnquery.datevalue(f.jobid, 'ExpirationDate') - 90;
            END IF;

            -- get latest renewal fees
            FOR rec
                IN (SELECT ROWNUM line, d.*
                      FROM (  SELECT DISTINCT
                                     fees.licensetypecode,
                                     fees.feeactivity,
                                     fees.description,
                                     fees.LicenseTypeName, -- PK - Added LicenseTypeName column as per BIZ-4491 requirement
                                     fees.primarysecondary,
                                     fees.secondarycount,
                                     CASE
                                         WHEN fees.primarysecondary = 'P' THEN
                                                'M'
                                             || CASE
                                                    WHEN fees.secondarycount > 0 THEN
                                                           '-'
                                                        || TO_CHAR(fees.secondarycount, 'FM000')
                                                    ELSE
                                                        NULL
                                                END
                                         ELSE
                                                '-'
                                             || TO_CHAR(fees.secondarycount, 'FM000')
                                     END
                                         quantity,
                                     api.pkg_columnquery.numericvalue(feeobjid, 'Amount')
                                         amount,
                                     api.pkg_columnquery.numericvalue(feeobjid, 'AdjustedAmount')
                                         adjustedamount,
                                     api.pkg_columnquery.numericvalue(feeobjid, 'PaidAmount')
                                         paidamount,
                                     api.pkg_columnquery.numericvalue(feeobjid, 'TotalOwing')
                                         totalowing,
                                     NVL(
                                         (SELECT CASE
                                                     WHEN p.depositbatchid IS NOT NULL THEN
                                                         'Processing'
                                                     WHEN p.paymentobjectid IS NULL
                                                      AND p.feeobjid IS NOT NULL THEN
                                                         'Pending'
                                                     WHEN api.pkg_columnquery.numericvalue(feeobjid, 'AdjustedAmount') >
                                                          0 THEN
                                                         'Penalty'
                                                     WHEN fees.status IN ('REVPEN', 'REV PENDING') THEN
                                                         'Revoke-pending'
                                                     WHEN fees.status = 'SLMS HOLD' THEN
                                                         'SLMS-hold'
                                                     ELSE
                                                         NULL
                                                 END
                                            FROM bizmod_api.e_payments_t p
                                           WHERE p.feeobjid = fees.feeobjid
                                             and p.createddate = (select max(p2.createddate) 
                                                                    from bizmod_api.e_payments_t p2
                                                                   where p.feeobjid = p2.feeobjid)),
                                         NVL((SELECT 'Self-certified'
                                                FROM abc.self_certification sc
                                               WHERE sc.licensenumber = t_licensenumber
                                                 AND sc.licensetypecode = fees.licensetypecode
                                                 AND sc.expirationdate = lic.expirationdate
                                                 AND sc.eligible = 'Y'),
                                             'New'))
                                         status,
                                     fees.feeobjid
                                FROM (  -- Secondary License Types
                                      SELECT DISTINCT
                                             'S'
                                                 primarysecondary,
                                             SUBSTR(f.description, 1, 2)
                                                 licensetypecode,
                                             fs.feeactivity,
                                             api.pkg_columnquery.value(reo.objectid, 'DescriptionForDisplay') description,
                                             api.pkg_columnquery.VALUE(f.jobid, 'LicenseTypeName')LicenseTypeName,-- PK - Added LicenseTypeName column as per BIZ-4491 requirement
                                             NVL(api.pkg_columnquery.numericvalue(reo.objectid, 'Quantity'), 0)
                                                 secondarycount,
                                             sltc.status,
                                             reo.objectid
                                                 feeobjid
                                        FROM api.fees f
                                             JOIN api.registeredexternalobjects reo
                                             ON reo.linkvalue = TO_CHAR(f.feeid)
                                            AND reo.objectdefid = api.pkg_configquery.objectdefidforname('o_Fee')  --t_feeobjectdefid
                                             JOIN sitespecific.feeschedule_t fs
                                             ON fs.objectid =
                                                api.pkg_columnquery.numericvalue(reo.objectid, 'LicenseFeeSchedid')  -- sitespecific.pkg_fees.getlicfeeschedulobjid(f.feeid)
                                             JOIN query.r_licensetypeltcatsecondary sltc
                                             ON (sltc.licensetypejobid = f.jobid)
                                             JOIN query.o_licensetypecategory ltc
                                             ON (sltc.licensetypecategoryobjectid = ltc.objectid
                                             AND ltc.licensetypecode = fs.licensetypecode)
                                       WHERE f.jobid = lic.jobid
                                         AND sltc.status IN ('ACTIVE',
                                                             'SURRENDERED',
                                                             'RULE 64B',
                                                             'SLMS HOLD',
                                                             'SUSPENDED',
                                                             'REVPEN',
                                                             'REV PENDING')
                                         AND 'REN' LIKE
                                                    '%'
                                                 || SUBSTR(fs.feeactivity, 1, 3)
                                                 || '%'
                                         AND fs.licensetypecode !=
                                             api.pkg_columnquery.VALUE(f.jobid, 'dup_LicenseTypeCode')
                                         AND (f.transactiondate, fs.licensetypecode) =
                                             (  SELECT MAX(f2.transactiondate), fs2.licensetypecode
                                                  FROM api.fees f2
                                                       JOIN api.registeredexternalobjects reo  -- RyanL: PIP Task 8.5
                                                       ON reo.linkvalue = TO_CHAR(f2.feeid)
                                                      AND reo.objectdefid =
                                                          api.pkg_configquery.objectdefidforname('o_Fee')  --t_feeobjectdefid
                                                       JOIN sitespecific.feeschedule_t fs2
                                                       ON fs2.objectid =
                                                          api.pkg_columnquery.numericvalue(reo.objectid,
                                                                                           'LicenseFeeSchedid')
                                                 --                                                          sitespecific.pkg_fees.getlicfeeschedulobjid(f.feeid)
                                                 WHERE f.jobid = f2.jobid  -- 357849436
                                                   AND fs.licensetypecode = fs2.licensetypecode
                                                   AND fs2.feeactivity = fs.feeactivity
                                                   AND f.transactiondate > lic.expirationdate - 90
                                              GROUP BY fs2.licensetypecode)
                                      UNION
                                      -- Primary / Branch License Types
                                      SELECT (SELECT CASE WHEN MAX(r.toobjectid) IS NULL THEN 'P' ELSE 'B' END
                                                FROM api.relationships r
                                               WHERE r.endpointid =
                                                     api.pkg_configquery.endpointidforname('j_LicenseType',
                                                                                           'MasterLicenseType')
                                                 AND r.fromobjectid = f.jobid)
                                                 secondaryprimary,
                                             SUBSTR(f.description, 1, 2)
                                                 licensetype,
                                             fs.feeactivity,
                                             api.pkg_columnquery.value(reo.objectid, 'DescriptionForDisplay') description,
                                             api.pkg_columnquery.VALUE(f.jobid, 'LicenseTypeName')LicenseTypeName,-- PK - Added LicenseTypeName column as per BIZ-4491 requirement
                                             NVL(api.pkg_columnquery.numericvalue(reo.objectid, 'Quantity'), 0)
                                                 secondarycount,
                                             api.pkg_columnquery.VALUE(f.jobid, 'StatusName')
                                                 status,
                                             reo.objectid
                                                 feeobjid
                                        FROM api.fees f
                                             JOIN api.registeredexternalobjects reo
                                             ON reo.linkvalue = TO_CHAR(f.feeid)
                                            AND reo.objectdefid = api.pkg_configquery.objectdefidforname('o_Fee')  --t_feeobjectdefid
                                             JOIN sitespecific.feeschedule_t fs
                                             ON fs.objectid =
                                                api.pkg_columnquery.numericvalue(reo.objectid, 'LicenseFeeSchedid')  --sitespecific.pkg_fees.getlicfeeschedulobjid(f.feeid)
                                             JOIN api.relationships r
                                             ON (r.endpointid =
                                                 api.pkg_configquery.endpointidforname('j_LicenseType',
                                                                                       'LicTypeCatPrimary')
                                             AND r.fromobjectid = f.jobid
                                             AND fs.licensetypecode =
                                                 api.pkg_columnquery.VALUE(r.toobjectid, 'LicenseTypeCode'))
                                       WHERE f.jobid = lic.jobid
                                         AND api.pkg_columnquery.VALUE(f.jobid, 'StatusName') IN ('ACTIVE',
                                                                                                  'REVPEN',
                                                                                                  'SUREND',
                                                                                                  'R64B',
                                                                                                  'SLMSRV',
                                                                                                  'SUSPEN')
                                         AND 'REN' LIKE
                                                    '%'
                                                 || SUBSTR(fs.feeactivity, 1, 3)
                                                 || '%'
                                         AND (f.transactiondate, fs.licensetypecode) =
                                             (  SELECT MAX(f2.transactiondate), fs2.licensetypecode
                                                  FROM api.fees f2
                                                       JOIN api.registeredexternalobjects reo
                                                       ON reo.linkvalue = TO_CHAR(f2.feeid)
                                                      AND reo.objectdefid =
                                                          api.pkg_configquery.objectdefidforname('o_Fee')  --t_feeobjectdefid
                                                       JOIN sitespecific.feeschedule_t fs2
                                                       ON fs2.objectid =
                                                          api.pkg_columnquery.numericvalue(reo.objectid,
                                                                                           'LicenseFeeSchedid')
                                                 --                                                          sitespecific.pkg_fees.getlicfeeschedulobjid(f.feeid)
                                                 WHERE f.jobid = f2.jobid  -- 357849436
                                                   AND fs.licensetypecode = fs2.licensetypecode
                                                   AND fs2.feeactivity = fs.feeactivity
                                                   AND f.transactiondate > lic.expirationdate - 90
                                              GROUP BY fs2.licensetypecode)) fees
                            ORDER BY SUBSTR(quantity, 1, 1) DESC, licensetypecode) d)
            LOOP
                /******************************************************************
                -- check if penality fees have to be supply if not already applied
                CASE
                    WHEN SYSDATE > t_lastdate50penalty
                     AND rec.feeactivity != 'REN100'
                     AND rec.status IN ('New', 'Penalty')
                     AND (rec.totalowing > 0 or t_owing = 'Y') THEN
                        get_penalityamount(a_licensefeeschedid =>
                                               api.pkg_columnquery.numericvalue(rec.feeobjid, 'LicenseFeeSchedId'),
                                           a_primarysecondary =>
                                               rec.primarysecondary,
                                           a_feeactivity =>
                                               'REN100',
                                           a_secondarycount =>
                                               rec.secondarycount,
                                           a_description =>
                                               rec.description,
                                           a_adjustedamount =>
                                               rec.adjustedamount,
                                           a_originalfeeamount =>
                                               rec.amount);
                        rec.totalowing := rec.totalowing + rec.adjustedamount;
                        rec.status   := 'Penalty';
                    WHEN SYSDATE BETWEEN (t_renewaldate + 1) AND t_lastdate50penalty
                     AND rec.feeactivity != 'REN50'
                     AND rec.status IN ('New', 'Penalty')
                     AND (rec.totalowing > 0 or t_owing = 'Y') THEN
                        get_penalityamount(a_licensefeeschedid =>
                                               api.pkg_columnquery.numericvalue(rec.feeobjid, 'LicenseFeeSchedId'),
                                           a_primarysecondary =>
                                               rec.primarysecondary,
                                           a_feeactivity =>
                                               'REN50',
                                           a_secondarycount =>
                                               rec.secondarycount,
                                           a_description =>
                                               rec.description,
                                           a_adjustedamount =>
                                               rec.adjustedamount,
                                           a_originalfeeamount =>
                                               rec.amount);
                        rec.totalowing := rec.totalowing + rec.adjustedamount;
                        rec.status   := 'Penalty';
                    ELSE
                        NULL;
                END CASE;
                **************************************************************/

                --rec.feeactivity
                IF (NOT t_comma) THEN
                    t_fees    := '"FEES":[';
                    t_comma   := TRUE;
                ELSE
                    t_fees   :=
                           t_fees
                        || ',';
                END IF;

                t_fees   :=
                       t_fees
                    || '{"EXPIRATIONDATE": "'
                    || TO_CHAR(lic.expirationdate, 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
                    || '",';
                t_fees   :=
                       t_fees
                    || '"DUEDATE":"'
                    || TO_CHAR(lic.renewaldate, 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
                    || '",';
                t_fees   :=
                       t_fees
                    || '"DUEDATE50":"'
                    || TO_CHAR(lic.lastdate50penalty, 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
                    || '",';
                t_fees   :=
                       t_fees
                    || '"DUEDATE100":"'
                    || TO_CHAR(lic.lastdate100penalty, 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
                    || '",';
                t_fees   :=
                       t_fees
                    || '"LICENSETYPECODE": "'
                    || rec.licensetypecode
                    || '",';
                t_fees   :=
                       t_fees
                    || '"DESCRIPTION": "'
                    || rec.description
                    || '",';
                t_fees   :=
                       t_fees
                    || '"LICENSETYPENAME": "' -- PK - Added LicenseTypeName column as per BIZ-4491 requirement
                    || rec.LicenseTypeName
                    || '",';
                t_fees   :=
                       t_fees
                    || '"QUANTITY": "'
                    || rec.quantity
                    || '",';
                t_fees   :=
                       t_fees
                    || '"AMOUNT": "'
                    || rec.amount
                    || '",';
                t_fees   :=
                       t_fees
                    || '"PENALTY": "'
                    || CASE WHEN rec.adjustedamount > 0 THEN rec.adjustedamount ELSE 0 END
                    || '",';
                t_fees   :=
                       t_fees
                    || '"ADJUSTMENTS": "'
                    || CASE WHEN rec.adjustedamount < 0 THEN rec.adjustedamount ELSE 0 END
                    || '",';
                t_fees   :=
                       t_fees
                    || '"AMOUNTPAID": "'
                    || rec.paidamount
                    || '",';
                t_fees   :=
                       t_fees
                    || '"AMOUNTDUE": "'
                    || CASE WHEN rec.status IN ('Self-certified', 'Pending') THEN 0 ELSE rec.totalowing END
                    || '",';
                t_fees   :=
                       t_fees
                    || '"STATUS": "'
                    || rec.status
                    || '",';
                t_fees   :=
                       t_fees
                    || '"FEEOBJID": "'
                    || rec.feeobjid
                    || '"}';

                IF (rec.status NOT IN ('Self-certified', 'Pending')) THEN
                    t_totalamountdue   := t_totalamountdue + rec.totalowing;
                END IF;
            END LOOP;
        END LOOP;

        IF t_packet = EMPTY_CLOB() THEN
            t_packet   := '{"PACKET_TYPE":"MESSAGE","DATA":{"MSGNO":"1","MSG":"License Number Not Found"}}';
        ELSE
            IF t_fees = EMPTY_CLOB THEN
                t_fees   := '"MSGNO":"2","MSG":"No Renewal Fees Found"';
            ELSE
                t_fees   :=
                       t_fees
                    || ']';
                t_packet   :=
                       t_packet
                    || '"TOTALAMOUNTDUE": "'
                    || t_totalamountdue
                    || '",';
            END IF;

            t_packet   :=
                   t_packet
                || t_fees
                || '}}';
        END IF;

        RETURN REGEXP_REPLACE(t_packet, '[[:cntrl:]]', '');
    EXCEPTION
        WHEN OTHERS THEN
            t_sqlerrm   := SQLERRM;
            t_trace     := DBMS_UTILITY.format_error_backtrace;
            t_msg       :=
                SUBSTR(   t_sqlerrm
                       || ' :: '
                       || t_trace,
                       1,
                       3990);

            UPDATE eservices_log_t
               SET err   = t_msg
             WHERE seq = a_seq;

            COMMIT;
            RETURN    '{"PACKET_TYPE":"MESSAGE","DATA":{"MSGNO":"5","MSG":"Oracle Exception","EXCEPTION":"'
                   || REGEXP_REPLACE(t_sqlerrm, '[^[:print:]]', '')
                   || '"}}';
    END;
END requestfees;
/


GRANT EXECUTE ON BIZMOD_API.REQUESTFEES TO BIZMOD_USER;
