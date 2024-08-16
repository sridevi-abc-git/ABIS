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
    --  Ver:       Date          Ticket       Comment
    --          11/17/2022  TJL             Rewrite of REQUESTFEES
    --          06/27/2023  TJL  BIZ-11779  Correct premise address not being retrieved
    --          06/30/2023  TJL             Fixed bug with incorrect message number.
    --          01/29/2024  APD             Ordered lic view in main loop to make sure j_license row is first
    --          02/13/2024  APD  BIZ-14426  Fixed bug in getting renewal fees
    --          02/21/2024  TJL  BIZ-14521  Corrected so payment received message is displayed until
    --                                        licenses is issued
    --   5.0    05/13/2024  TJL  BIZ-15090  Changed request fees process and added test to return
    --                                        Payment was received before license was issued and
    --                                        No license fee was found after issued
    --   6.0.4  06/10/2024  TJL  BIZ-15612
    --                           BIZ-15616  Corrected bug in wrong message being returned to LSP
    --   7.0    07/11/2024  TJL  BIZ-15837  Removed CVR test
    -- ****************************************************************************

    PROCEDURE get_fee_amounts(fees IN OUT bizmod_api.fee_tbl)
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

                IF (t_totalowing > 0) -- 02/13/2024 APD BIZ-14426
                THEN
                    CASE
                        WHEN TRUNC(SYSDATE) > fees(indx).lastdate50penalty
                         AND fees(indx).feeactivity != 'REN100'
                         AND SUBSTR(fees(indx).feeactivity, 1, 3) = 'REN'
                        THEN
                            t_caculate := TRUE;
                            fees(indx).feeactivity := 'REN100';
                        WHEN TRUNC(SYSDATE) BETWEEN (  fees(indx).renewaldate
                                                     + 1)
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
                ELSE
                    t_caculate := FALSE;
                    fees(indx).adjustedamount :=
                        api.pkg_columnquery.numericvalue(fees(indx).feeobjid,
                                                         'AdjustedAmount');
                    fees(indx).description :=
                        api.pkg_columnquery.VALUE(fees(indx).feeobjid,
                                                  'DescriptionForDisplay');
                    fees(indx).totalowing := t_totalowing;
                END IF;

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
-- ********************************************************
-- ********************************************************
BEGIN
    DECLARE
        t_licensenumber VARCHAR2(40); -- := '550312'; -- '645954'; --'641428'; --'651570';
        t_msg          VARCHAR2(4000);
        t_msgno        NUMBER;
        t_fees         bizmod_api.fee_tbl := bizmod_api.fee_tbl();
        t_json         CLOB;
        t_jobid        api.pkg_definition.udt_id;
        t_total        NUMBER := 0;
        t_available    BOOLEAN := FALSE;
        t_sqlerrm      VARCHAR2(4000);
        t_trace        VARCHAR2(4000);
    BEGIN
        t_licensenumber := json_value(a_packet, '$.*.LICENSENUMBER');

        WITH
            f
            AS
                (SELECT DISTINCT o.objectid      jobid,
                                 reo.objectid    feeobjid,
                                 fs.feeactivity,
                                 fs.licensetypecode,
                                 ltc.licensetypename,
                                 CASE fs.licensetypecode
                                     WHEN api.pkg_columnquery.VALUE(
                                              o.objectid,
                                              'LicenseTypeCode')
                                     THEN
                                         (SELECT CASE
                                                     WHEN MAX(r.toobjectid)
                                                              IS NULL
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
                                             AND r.fromobjectid = o.objectid)
                                     ELSE
                                         'S'
                                 END             secondaryprimary
                   FROM (SELECT objectid
                           FROM TABLE(
                                    CAST(
                                        api.pkg_simplesearch.castableobjectsbyindex(
                                            a_objectdefname =>
                                                'j_Application',
                                            a_columnname =>
                                                'dup_LicenseNumber',
                                            a_value     => t_licensenumber)
                                            AS api.udt_objectlist)) o
                          WHERE api.pkg_columnquery.VALUE(objectid,
                                                          'StatusName') IN
                                    ('PEND', 'NEW')
                         UNION
                         SELECT objectid
                           FROM TABLE(
                                    CAST(
                                        api.pkg_simplesearch.castableobjectsbyindex(
                                            a_objectdefname => 'j_License',
                                            a_columnname => 'ExternalFileNum',
                                            a_value     => t_licensenumber)
                                            AS api.udt_objectlist)) o
                          WHERE api.pkg_columnquery.VALUE(objectid,
                                                          'StatusName') IN
                                    ('ACTIVE',
                                     'SUREND',
                                     'SUSPEN',
                                     'R64B',
                                     'REVPEN',
                                     'SLMSHD')
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
                                            AS api.udt_objectlist)) o
                          WHERE api.pkg_columnquery.VALUE(objectid,
                                                          'StatusName') IN
                                    ('ACTIVE',
                                     'SUREND',
                                     'SUSPEN',
                                     'R64B',
                                     'REVPEN',
                                     'SLMSHD')) o
                        JOIN api.fees f
                            ON (o.objectid = f.jobid
                            AND f.transactiondate >=
                                CASE api.pkg_columnquery.VALUE(
                                         f.jobid,
                                         'ObjectDefName')
                                    WHEN 'j_Application'
                                    THEN
                                        TO_DATE('01-jan-10')
                                    ELSE
                                        ADD_MONTHS(SYSDATE, -15)
                                END)
                        JOIN api.registeredexternalobjects reo
                            ON (reo.linkvalue = TO_CHAR(f.feeid)
                            AND reo.objectdefid =
                                api.pkg_configquery.objectdefidforname(
                                    'o_Fee'))
                        JOIN sitespecific.feeschedule_t fs
                            ON fs.objectid =
                               api.pkg_columnquery.numericvalue(
                                   reo.objectid,
                                   'LicenseFeeSchedid')
                        JOIN query.o_licensetypecategory ltc
                            ON (ltc.licensetypecode = fs.licensetypecode)
                        LEFT OUTER JOIN api.relationships sltc
                            ON (sltc.endpointid =
                                api.pkg_configquery.endpointidforname(
                                    'j_LicenseType',
                                    'LicTypeCatSecondary')
                            AND sltc.fromobjectid = f.jobid
                            AND fs.licensetypecode !=
                                api.pkg_columnquery.VALUE(o.objectid,
                                                          'LicenseTypeCode'))
                  WHERE NVL(
                            api.pkg_columnquery.VALUE(sltc.relationshipid,
                                                      'Status'),
                            'ACTIVE') IN
                            ('ACTIVE',
                             'SURRENDERED',
                             'RULE 64B',
                             'SLMS HOLD',
                             'SUSPENDED',
                             'REVPEN',
                             'REV PENDING'))
        SELECT bizmod_api.fee_rec(
                   f.jobid,
                   f.secondaryprimary,
                   api.pkg_columnquery.datevalue(f.jobid,
                                                 'dup_ExpirationDate'),
                   api.pkg_columnquery.datevalue(f.jobid, 'renewaldate'),
                   TO_DATE(
                       api.pkg_columnquery.VALUE(f.jobid,
                                                 'LastDate50Penalty'),
                       'Mon dd, yyyy'),
                   TO_DATE(
                       api.pkg_columnquery.VALUE(f.jobid,
                                                 'LastDate100Penalty'),
                       'Mon dd, yyyy'),
                   f.licensetypecode,
                   f.feeactivity,
                   NULL,
                   f.licensetypename,
                   NULL,
                   NULL,
                   NULL,
                   NULL,
                   NULL,
                   NULL,
                   CASE
                           WHEN api.pkg_columnquery.VALUE(f.jobid, 'Status') IN
                                    ('REVPEN', 'REV PENDING')
                           THEN
                               'Revoke-pending'
                           WHEN api.pkg_columnquery.VALUE(f.jobid, 'status') =
                                'SLMS HOLD'
                           THEN
                               'SLMS-hold'
                           ELSE
                               'New'
                       END,
                   f.feeobjid)
          BULK COLLECT INTO t_fees
          FROM f;

        IF (t_fees.COUNT = 0)
        THEN -- BIZ-15616
            t_msgno := 1;
            t_msg := 'NO ACTIVE LICENSE FOUND';

            FOR rec
                IN (SELECT objectid,
                           api.pkg_columnquery.VALUE(objectid, 'StatusName')    statusname
                      FROM TABLE(
                               CAST(
                                   api.pkg_simplesearch.castableobjectsbyindex(
                                       a_objectdefname => 'j_LicenseType',
                                       a_columnname =>
                                           'dup_LicenseExternalFileNum',
                                       a_value     => t_licensenumber)
                                       AS api.udt_objectlist)) o)
            LOOP
                IF (rec.statusname IN ('ACTIVE',
                                       'SUREND',
                                       'SUSPEN',
                                       'R64B',
                                       'REVPEN',
                                       'SLMSHD'))
                THEN
                    t_msgno := 2;
                    t_msg := 'NO LICENSE FEES FOUND';
                    t_jobid := rec.objectid;
                    EXIT;
                END IF;
            END LOOP;
        ELSE
            t_jobid := t_fees(1).jobid;

            get_fee_amounts(fees => t_fees);

            FOR inx IN 1 .. t_fees.COUNT
            LOOP
                t_total :=
                    CASE
                        WHEN   NVL(t_fees(inx).amount, 0)
                             + NVL(t_fees(inx).adjustedamount, 0)
                             + NVL(t_fees(inx).paidamount, 0) <=
                             0
                        THEN
                            0
                        ELSE
                            1
                    END;

                CASE
                    WHEN api.pkg_columnquery.VALUE(t_fees(inx).jobid,
                                                   'ObjectDefName') =
                         'j_Application'
                     AND t_total <= 0
                    THEN
                        t_msgno := 12;
                        t_msg := 'PAYMENT WAS RECEIVED';
                    WHEN api.pkg_columnquery.VALUE(t_fees(inx).jobid,
                                                   'ObjectDefName') =
                         'j_LicenseType'
                     AND ADD_MONTHS(t_fees(inx).expirationdate, -12) <=
                         api.pkg_columnquery.datevalue(t_fees(inx).feeobjid,
                                                       'TransactionDate')
                     AND t_fees(inx).feeactivity IN
                             ('REN', 'REN50', 'REN100')
                     AND t_total <= 0
                    THEN
                        t_msgno := 12;
                        t_msg := 'PAYMENT WAS RECEIVED';
                    WHEN api.pkg_columnquery.VALUE(t_fees(inx).jobid,
                                                   'ObjectDefName') =
                         'j_LicenseType'
                     AND TRUNC(SYSDATE) > t_fees(inx).lastdate100penalty
                     AND t_total > 0
                    THEN
                        t_fees(inx).amount := 0;
                        t_msgno := 13;
                        t_msg := 'Fee cannot be paid online';
                    WHEN api.pkg_columnquery.VALUE(t_fees(inx).jobid,
                                                   'ObjectDefName') =
                         'j_LicenseType'
                     AND t_fees(inx).feeactivity IN
                             ('REN', 'REN50', 'REN100')
                     AND t_total <= 0
                    THEN
                        t_fees.delete(inx);

                        IF (t_msgno IS NULL)
                        THEN
                            t_msgno := 2;
                            t_msg := 'NO LICENSE FEES FOUND';
                        END IF;
                    WHEN api.pkg_columnquery.VALUE(t_fees(inx).jobid,
                                                   'ObjectDefName') =
                         'j_LicenseType'
                     AND t_fees(inx).feeactivity NOT IN
                             ('REN', 'REN50', 'REN100')
                     AND t_total <= 0
                    THEN
                        t_fees.delete(inx);
                    WHEN api.pkg_columnquery.VALUE(t_fees(inx).jobid,
                                                   'ObjectDefName') =
                         'j_License'
                     AND t_total <= 0
                    THEN
                        t_fees.delete(inx);
                    ELSE
                        IF (t_total > 0)
                        THEN
                            t_available := TRUE;
                        END IF;
                END CASE;
            END LOOP;
        END IF;

        IF (NOT t_available
        AND t_fees.COUNT = 0
        AND t_msgno IS NULL)
        THEN
            t_jobid := NULL; -- force message #1
        END IF;

        IF (t_jobid IS NOT NULL)
        THEN
            IF (t_available)
            THEN
                -- messages that might been generated by fees not
                --  elegible for payment
                t_msgno := NULL;
                t_msg := NULL;
            END IF;

            SELECT json_object(
                       'PACKET_TYPE' VALUE 'FEES',
                       'DATA' VALUE
                           json_object(
                               'LICENSENUMBER' VALUE t_licensenumber,
                               'LICENSEENAME' VALUE
                                   api.pkg_columnquery.VALUE(t_jobid,
                                                             'LicenseeNames'),
                               'BUSINESSNAME' VALUE
                                   api.pkg_columnquery.VALUE(t_jobid,
                                                             'PrimaryDBA'),
                               'PREMISEADDRESS' VALUE
                                   api.pkg_columnquery.VALUE(
                                       t_jobid,
                                       'PremAddress1Line'),
                               'TOTALAMOUNTDUE' VALUE
                                   (SELECT SUM(
                                                 fee.amount
                                               + fee.adjustedamount
                                               + fee.paidamount)
                                      FROM TABLE(t_fees) fee
                                     WHERE (  NVL(fee.amount, 0)
                                            + NVL(fee.adjustedamount, 0)
                                            + NVL(fee.paidamount, 0) >
                                            0)),
                               'MSGNO' VALUE t_msgno,
                               'MSG' VALUE t_msg,
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
                                                       (  NVL(fee.amount, 0)
                                                        + NVL(
                                                              fee.adjustedamount,
                                                              0)
                                                        + NVL(fee.paidamount,
                                                              0)),
                                                   'STATUS' VALUE fee.status,
                                                   'FEEOBJID' VALUE
                                                       fee.feeobjid
                                                   ABSENT ON NULL))
                                      FROM TABLE(t_fees) fee
                                     WHERE (  NVL(fee.amount, 0)
                                            + NVL(fee.adjustedamount, 0)
                                            + NVL(fee.paidamount, 0) >
                                            0))
                               ABSENT ON NULL))
              INTO t_json
              FROM DUAL;
        ELSE
            t_json :=
                '{"PACKET_TYPE":"MESSAGE","DATA":{"MSGNO":"1","MSG":"License Number '
                || t_licensenumber
                || ' Not Found"}}';
        END IF;

        RETURN t_json;
    EXCEPTION
        WHEN OTHERS
        THEN
            t_sqlerrm := SQLERRM;
            t_trace := DBMS_UTILITY.format_error_backtrace;
            t_msg := SUBSTR(t_sqlerrm || CHR(13) || t_trace, 1, 3990);

            UPDATE bizmod_api.eservices_log_t
               SET err = t_msg
             WHERE seq = a_seq;

            COMMIT;

            t_json :=
                json_object(
                    'PACKET_TYPE' VALUE 'MESSAGE',
                    'DATA' VALUE
                        json_object('MSGNO' VALUE 5,
                                    'MSG' VALUE 'Oracle Exception',
                                    'EXCEPTION' VALUE t_sqlerrm));
            DBMS_OUTPUT.put_line(t_sqlerrm || CHR(13) || CHR(10) || t_trace);

            RETURN t_json;
    END;
END;
/


GRANT EXECUTE ON BIZMOD_API.REQUESTFEES TO BIZMOD_USER;
