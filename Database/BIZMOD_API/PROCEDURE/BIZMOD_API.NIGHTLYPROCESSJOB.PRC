CREATE OR REPLACE PROCEDURE BIZMOD_API.nightlyprocessjob
IS
    -- ****************************************************************************
    -- File:        BIZMOD_API.NIGHTLYPROCESSJOB.PRC
    -- Author:      Timothy J. Lord
    --
    -- Purpose :
    --
    -- History:
    -------------------------------------------------------------------------------
    --              Date           Ticket     Comment
    --          05/31/2023  TJL             Initial Procedure Created
    --   2.0    08/01/2023  TJL             Corrected bug in updating AWF completed flag
    --   3.0    01/11/2024  TJL             Added call to create AWF payment batches for zero
    --                                        amount due. Added updating new process log.
    --                                      Corrected bug in updating AWF fee object id.
    --   4.0    03/06/2024  TJL  BIZ-14725  Added getting AWF Payment Batch and updating payment
    --                                        record with payment batch job id when missing
    --   5.1    03/22/2024  TJL  BIZ-14833  Changed process name from nightlyprocess to
    --                                        nightlyprocessjob. Added new functionality to
    --                                        handle AWF reports.
    --   5.2    03/28/2024  TJL  BIZ-14833  Fix bug in not sending emails
    --   5.3    04/02/2024  TJL  BIZ-14833  fix bug in updating expiration date in table
    --                                        licensetype_t table.
    --   5.4    04/03/2024  TJL  BIZ-14833  Fix bug in figuring out AWF when AWF report
    --                                        is after expiration date
    --   6.0    04/18/2024  TJL  BIZ-15102  Fix bug in get_awfreninfo where transfer points
    --                                         back to itself which caused a recursion loop
    --                                         that eventually failed.
    --   7.0    04/26/2024  TJL  BIZ-15142  Fixed bug in AWF process in trying to reprocess
    --                                         Fee that failed
    --   7.1    05/14/2024  TJL  BIZ-15461  Fixed bug that indicated branch 02 required AWF
    --                                         Report in LSP.
    --   8.0    05/20/2024  TJL  BIZ-15523  Added test to see if AWF batch needs to be created
    --   8.1    05/24/2024  TJL  BIZ-15485  Removed sending emails on job being completed
    --   9.0    07/09/2024  TJL  BIZ-15837  Removed Fee Waiver Exception
    --  10.0    07/11/2024  TJL  BIZ-       Corrected bug when secondaries are added licensetype_t
    --                                        table not updated
    --  10.1    07/15/2024  TJL  BIZ-15858  change fiscal end date to expiration date for figuring 
    --                                        out which renewal fee to use for AWF.
    --  11.0.1  07/24/2024  TJL  BIZ-15915  change how fiscal end date is calculated
    -- ****************************************************************************

    FUNCTION get_awfreninfo(a_fiscalend DATE, a_jobid NUMBER)
        RETURN NUMBER
    AS
        t_start_date   DATE;
        t_end_date     DATE;
        t_application  NUMBER;
        t_applicationtype VARCHAR2(20);
        t_transferfromobjectid NUMBER;
        t_issuedate    DATE;
        t_feeid        NUMBER;
        t_feeobjid     NUMBER;
        t_old          NUMBER;
    BEGIN
        SELECT lt.applicationjobid
          INTO t_application
          FROM bizmod_api.licensetype_t lt
         WHERE lt.licensetypejobid = a_jobid;

        t_issuedate := api.pkg_columnquery.datevalue(a_jobid, 'IssueDate');

        t_start_date := ADD_MONTHS(a_fiscalend + 1, -36);
        t_end_date := ADD_MONTHS(a_fiscalend, -12);

        IF (t_application IS NULL)
        THEN
            FOR rec
                IN (  SELECT app.toobjectid
                                 applicationobjectid,
                             api.pkg_columnquery.VALUE(plt.toobjectid,
                                                       'LicenseTypeCode')
                                 licensetypecode,
                             api.pkg_columnquery.VALUE(app.toobjectid,
                                                       'Completeddate')
                                 completeddate
                        -- point to license (lic.toobjectid) from license type object id
                        FROM api.relationships lic
                             -- point to application (app.toobjectid) from license object id
                             JOIN api.relationships app
                                 ON (app.endpointid =
                                     api.pkg_configquery.endpointidforname(
                                         'j_License',
                                         'ApplicationLicense')
                                 AND app.fromobjectid = lic.toobjectid)
                             -- point to primary license type (plt.toobjectid) from application object id
                             JOIN api.relationships plt
                                 ON (plt.fromobjectid = app.toobjectid
                                 AND plt.endpointid =
                                     api.pkg_configquery.endpointidforname(
                                         'j_application',
                                         'PrimaryLicenseType'))
                       WHERE lic.endpointid =
                             api.pkg_configquery.endpointidforname(
                                 'j_LicenseType',
                                 'License')
                         AND lic.fromobjectid = a_jobid
                         AND REGEXP_LIKE(
                                 api.pkg_columnquery.VALUE(plt.toobjectid,
                                                           'LicenseTypeCode'),
                                 '02|22')
                    ORDER BY completeddate)
            LOOP
                t_application := rec.applicationobjectid;
            END LOOP;

            UPDATE bizmod_api.licensetype_t lt
               SET lt.applicationjobid = t_application
             WHERE lt.licensetypejobid = a_jobid;

            COMMIT;
        END IF;

        -- Older license don't have applications in ABIS
        --   Applications not need for licenses issued over 3 years ago
        IF (TRUNC(t_issuedate) >= t_start_date) -- 07/15/2024  TJL  BIZ-15858
        THEN
            t_applicationtype :=
                api.pkg_columnquery.VALUE(t_application, 'ApplicationType');
        ELSE
            -- assume original for applications issued over 3 years ago
            t_applicationtype := 'Original';
        END IF;

        IF (t_applicationtype = 'Transfer')
        THEN
            -- find license transfer from license. can have multiple transfer from's
            --   for an application
            FOR rec
                IN (  SELECT lt.toobjectid                             transferfromobjectid,
                             r.toobjectid                              licenseobjectid,
                             api.pkg_columnquery.VALUE(lt.toobjectid,
                                                       'issuedate')    issuedate
                        FROM api.relationships r
                             JOIN api.relationships lt
                                 ON (lt.endpointid =
                                     api.pkg_configquery.endpointidforname(
                                         'j_License',
                                         'LicenseType')
                                 AND lt.fromobjectid = r.toobjectid)
                       WHERE r.fromobjectid = t_application --t_application
                         AND r.endpointid IN
                                 (api.pkg_configquery.endpointidforname(
                                      'j_Application',
                                      'LicenseTransfer'),
                                  api.pkg_configquery.endpointidforname(
                                      'j_Application',
                                      'License'))
                         AND REGEXP_LIKE(
                                 api.pkg_columnquery.VALUE(lt.toobjectid,
                                                           'LicenseTypeCode'),
                                 '02|22')
                    ORDER BY issuedate)
            LOOP
                -- check to make sure transfer not pointing back to current
                --   license when another transer from license has already been selected
                IF (rec.licenseobjectid !=
                    api.pkg_columnquery.numericvalue(a_jobid, 'LicenseJobId'))
                THEN
                    t_transferfromobjectid := rec.transferfromobjectid;
                END IF;
            END LOOP;
        END IF;

        CASE
            -- get renewal fee information for licenses over a couple of years old
            WHEN TRUNC(t_issuedate) <= ADD_MONTHS(a_fiscalend + 1, -24)
            THEN
                -- get renewal fee
                SELECT MIN(f.feeid)
                  INTO t_feeid
                  FROM api.fees f
                 WHERE f.jobid = a_jobid
                   AND (f.description LIKE '02 - REN%'
                     OR f.description LIKE '22 - REN%')
                   AND f.transactiondate BETWEEN t_start_date AND t_end_date;
            -- for licenses issued was a transfer this year get renewal fees
            --    from the transfer from license

            WHEN TRUNC(t_issuedate) BETWEEN ADD_MONTHS(a_fiscalend + 1, -12)
                                        AND a_fiscalend
            THEN
                CASE
                    WHEN (t_applicationtype = 'Transfer'
                      AND api.pkg_columnquery.VALUE(t_application,
                                                    'PersonToPerson') =
                          'N')
                    THEN
                        --                        DBMS_OUTPUT.put_line('calling recursive');
                        t_feeid :=
                            api.pkg_columnquery.numericvalue(
                                get_awfreninfo(
                                    a_fiscalend => a_fiscalend,
                                    a_jobid     => t_transferfromobjectid),
                                'FeeId');
                    ELSE
                        NULL;
                END CASE;
            ELSE
                -- get renewal fee or ANN fee for licenses issued last fiscal year
                IF ((t_applicationtype = 'Original')
                 OR (t_applicationtype = 'Transfer'
                 AND api.pkg_columnquery.VALUE(t_application,
                                               'PersonToPerson') =
                     'Y')
                 OR (t_applicationtype = 'Change'
                 AND api.pkg_columnquery.VALUE(t_application,
                                               'AddPrimaryLicenseType') =
                     'Y'))
                THEN
                    -- get ANN Fees
                    FOR rec
                        IN (SELECT f.feeid, f.paidamount
                              FROM api.fees f
                             WHERE f.jobid = t_application
                               AND SUBSTR(f.description, 1, 2) IN
                                       ('02', '22')
                               AND f.description LIKE '%ANN%')
                    LOOP
                        t_feeid := rec.feeid;
                        EXIT WHEN rec.paidamount != 0;
                    END LOOP;
                ELSE
                    IF (t_applicationtype = 'Transfer'
                    AND t_transferfromobjectid != a_jobid)
                    THEN
                        t_feeid :=
                            api.pkg_columnquery.numericvalue(
                                get_awfreninfo(
                                    a_fiscalend => a_fiscalend,
                                    a_jobid     => t_transferfromobjectid),
                                'FeeId');
                    ELSE
                        -- get ren fees from job
                        SELECT MIN(f.feeid)
                          INTO t_feeid
                          FROM api.fees f
                         WHERE f.jobid = a_jobid
                           AND (f.description LIKE '02 - REN%'
                             OR f.description LIKE '22 - REN%')
                           AND f.transactiondate BETWEEN t_start_date
                                                     AND t_end_date;
                    END IF;
                END IF;
        END CASE;

        IF (t_feeid IS NOT NULL)
        THEN
            SELECT reo.objectid
              INTO t_feeobjid
              FROM api.registeredexternalobjects reo
             WHERE reo.objectdefid =
                   api.pkg_configquery.objectdefidforname('o_fee')
               AND reo.linkvalue = TO_CHAR(t_feeid);
        END IF;

        RETURN t_feeobjid;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            RETURN t_feeobjid;
    END;

    -- ****************************************************************************
    -- ****************************************************************************
    FUNCTION awfrequired(a_fiscalend DATE, a_licensetypeobjectid IN NUMBER)
        RETURN NUMBER
    IS
        t_issuedate    DATE;
        t_branchapplies VARCHAR2(1);
        t_awfdate      DATE;
        t_expiration   DATE;
        t_awfrequired  VARCHAR2(2) := 'NA';
        t_fiscalstart   DATE := Add_months(a_fiscalend, - 12) + 1;
--        t_start_date   DATE
--            := TO_DATE(
--                   '01-07-' || EXTRACT(YEAR FROM ADD_MONTHS(SYSDATE, -6)),
--                   'dd-mm-yyyy');
--        t_end_date     DATE
--            := TO_DATE('30-06-' || EXTRACT(YEAR FROM ADD_MONTHS(SYSDATE, 6)),
--                       'dd-mm-yyyy');
        t_application  NUMBER;
        t_applicationtype VARCHAR2(20);
        t_transferfromobjectid NUMBER;
        t_feeobjid     NUMBER;
        t_feeid        NUMBER;
        t_msgno        NUMBER;
--        t_licensetypejobid NUMBER;
    BEGIN
        SELECT --a_fiscalend,
               --ADD_MONTHS(a_fiscalend, -12), 
               lt.applicationjobid
               --a_licensetypeobjectid
          INTO --t_expiration,
               --t_start_date,
               t_application
               --t_licensetypejobid
          FROM bizmod_api.licensetype_t lt
         WHERE lt.licensetypejobid = a_licensetypeobjectid;

        t_issuedate :=
            api.pkg_columnquery.datevalue(a_licensetypeobjectid, 'IssueDate');

        SELECT CASE WHEN SUM(cnt) = 0 THEN NULL ELSE 9 END
          INTO t_msgno
          FROM (SELECT COUNT(1)     cnt
                  FROM api.fees  f
                       LEFT OUTER JOIN bizmod_api.awf_t a
                           ON (f.feeid = a.awffeeid)
                 WHERE f.jobid = a_licensetypeobjectid
                   AND f.description LIKE '%AWF%'
                   AND (t_expiration = a.expirationdate
                     OR a.expirationdate IS NULL)
                   AND TRUNC(f.transactiondate) >= t_fiscalstart
                UNION
                SELECT COUNT(1)     cnt
                  FROM bizmod_api.e_payments_t p
                 WHERE (p.licensenumber =
                        api.pkg_columnquery.VALUE(a_licensetypeobjectid,
                                                  'LicenseNumber')
                    AND p.licensetypecode IN ('02', '22')
                    AND p.description LIKE '%AWF%'
                    AND TRUNC(p.createddate) >= t_fiscalstart));

        -- check if this was liense was just issued or was transfered
        IF (t_msgno IS NULL
        AND t_issuedate > ADD_MONTHS(t_expiration, -24))
        THEN
            t_applicationtype :=
                api.pkg_columnquery.VALUE(t_application, 'ApplicationType');

            -- make sure that this license has been renewed in the pass not issued this year
            CASE
                WHEN ((t_issuedate >= ADD_MONTHS(t_expiration, -12)
                   AND ((t_applicationtype = 'Original')
                     OR (t_applicationtype = 'Transfer'
                     AND api.pkg_columnquery.VALUE(t_application,
                                                   'PersonToPerson') =
                         'Y')
                     OR (t_applicationtype = 'Change'
                     AND api.pkg_columnquery.VALUE(t_application,
                                                   'AddPrimaryLicenseType') =
                         'Y'))))
                THEN
                    t_msgno := 10;
                WHEN t_applicationtype = 'Transfer'
                THEN
                    -- find license transfer from license. can have multiple
                    --   transfer from's for an application
                    FOR rec
                        IN (  SELECT lt.toobjectid                             transferfromobjectid,
                                     r.toobjectid                              licenseobjectid,
                                     api.pkg_columnquery.VALUE(lt.toobjectid,
                                                               'issuedate')    issuedate
                                FROM api.relationships r
                                     JOIN api.relationships lt
                                         ON (lt.endpointid =
                                             api.pkg_configquery.endpointidforname(
                                                 'j_License',
                                                 'LicenseType')
                                         AND lt.fromobjectid = r.toobjectid)
                               WHERE r.fromobjectid = t_application --t_application
                                 AND r.endpointid IN
                                         (api.pkg_configquery.endpointidforname(
                                              'j_Application',
                                              'LicenseTransfer'),
                                          api.pkg_configquery.endpointidforname(
                                              'j_Application',
                                              'License'))
                                 AND REGEXP_LIKE(
                                         api.pkg_columnquery.VALUE(
                                             lt.toobjectid,
                                             'LicenseTypeCode'),
                                         '02|22')
                            ORDER BY issuedate)
                    LOOP
                        IF (t_transferfromobjectid IS NULL)
                        THEN
                            t_transferfromobjectid :=
                                rec.transferfromobjectid;
                        ELSE
                            -- check to make sure transfer not pointing back to current
                            --   license when another transer from license has already
                            --   been selected
                            IF (rec.licenseobjectid !=
                                api.pkg_columnquery.numericvalue(
                                    a_licensetypeobjectid,
                                    'LicenseJobId'))
                            THEN
                                t_transferfromobjectid :=
                                    rec.transferfromobjectid;
                            END IF;
                        END IF;
                    END LOOP;

                    IF (t_transferfromobjectid IS NOT NULL)
                    THEN
                        SELECT CASE WHEN SUM(cnt) = 0 THEN NULL ELSE 9 END
                          INTO t_msgno
                          FROM (SELECT COUNT(1)     cnt
                                  FROM api.fees f
                                 WHERE f.jobid = t_transferfromobjectid
                                   AND TRUNC(f.transactiondate) BETWEEN t_fiscalstart
                                                                    AND a_fiscalend
                                   AND f.description LIKE '%AWF%'
                                UNION
                                SELECT COUNT(1)     cnt
                                  FROM bizmod_api.e_payments_t p
                                 WHERE p.licensenumber =
                                       api.pkg_columnquery.VALUE(
                                           t_transferfromobjectid,
                                           'LicenseNumber')
                                   AND p.licensetypecode IN ('02', '22')
                                   AND TRUNC(p.createddate) BETWEEN t_fiscalstart
                                                                AND a_fiscalend
                                   AND p.description LIKE '%AWF%');
                    ELSE
                        t_msgno := 10;
                    END IF;
                ELSE
                    NULL;
            END CASE;
        END IF;

        RETURN t_msgno;
    END;

    -- ****************************************************************************
    -- ****************************************************************************

    PROCEDURE updateinfo
    AS
    BEGIN
        DECLARE
            t_msgno             NUMBER;
            t_feeobjid          NUMBER;
            t_feeid             NUMBER;
            t_old               NUMBER;
            t_cnt               NUMBER;
            t_expirationdate    DATE
                := TO_DATE(
                       '30-JUN-' || EXTRACT(YEAR FROM ADD_MONTHS(SYSDATE, 6)));
        BEGIN
            -- check to see if AWF batch needs to be created
            SELECT COUNT(1)
              INTO t_cnt
              FROM bizmod_api.awf_t a
             WHERE a.awffeeamount <= 0
               AND a.paymentbatch IS NULL
               AND a.submitteddate IS NOT NULL;

            IF (t_cnt > 0)
            THEN
                -- create awf payment batches
                bizmod_api.createawfpaymentsjob(0, SYSDATE);
            END IF;

            -- check for any new license types added
            MERGE INTO bizmod_api.licensetype_t l
                 USING (SELECT lt.licensenumber,
                               lt.licensejobid,
                               lt.objectid
                                   licensetypejobid, -- licensetypejobid
                               lt.expirationdate,
                               lt.licensetypecode,
                               CASE
                                   WHEN lt.licensetypecode IN ('02', '22')
                                    AND lt.statusname IN ('ACTIVE',
                                                          'SUREND',
                                                          'SUSPEN',
                                                          'R64B',
                                                          'REVPEN',
                                                          'SLMSHD')
                                   THEN
                                       NULL
                                   ELSE
                                       'NA'
                               END
                                   awfflag,
                               lt.statusname,
                               (SELECT json_arrayagg(
                                           json_object(
                                               'LTC' VALUE
                                                   api.pkg_columnquery.VALUE(
                                                       slt.toobjectid,
                                                       'LicenseTypeCode'),
                                               'ID' VALUE slt.relationshipid))
                                  FROM api.relationships slt
                                 WHERE (lt.objectid = slt.fromobjectid
                                    AND slt.endpointid =
                                        api.pkg_configquery.endpointidforname(
                                            'j_LicenseType',
                                            'LicTypeCatSecondary')))
                                   secondaries,
                               lt.createddate
                          FROM mart.licensetype lt) a2
                    ON (l.licensetypejobid = a2.licensetypejobid)
            WHEN NOT MATCHED
            THEN
                INSERT     (licensenumber,
                            licensejobid,
                            licensetypejobid,
                            licensetypeexpirationdate,
                            licensetypecode,
                            awfflag,
                            statusname,
                            secondaries, -- (secondary license type code, relationship id)
                            createddate)
                    VALUES (a2.licensenumber,
                            a2.licensejobid,
                            a2.licensetypejobid,
                            a2.expirationdate,
                            a2.licensetypecode,
                            a2.awfflag,
                            a2.statusname,
                            a2.secondaries, -- (secondary license type code, relationship id)
                            a2.createddate);

            -- update expiration dates or status that have changed and reset AWF control values
            UPDATE bizmod_api.licensetype_t lt
               SET lt.licensetypeexpirationdate =
                       (SELECT expirationdate
                          FROM mart.licensetype l
                         WHERE l.objectid = lt.licensetypejobid),
                   lt.statusname =
                       (SELECT statusname
                          FROM mart.licensetype l
                         WHERE l.objectid = lt.licensetypejobid),
                   lt.renfeeobjid = NULL,
                   lt.renewalfeedate = NULL,
                   lt.awfstatusnumber = NULL,
                   lt.awfflag = NULL
             WHERE EXISTS
                       (SELECT 1
                          FROM mart.licensetype l
                         WHERE l.objectid = lt.licensetypejobid
                           AND (l.expirationdate !=
                                lt.licensetypeexpirationdate
                             OR l.statusname != lt.statusname));

            -- update awfflag for non 02 and 22 and update 02 and 22 that are not active
            UPDATE bizmod_api.licensetype_t lt
               SET lt.awfflag = 'NA'
             WHERE lt.awfflag IS NULL
               AND (lt.licensetypecode NOT IN ('02', '22')
                 OR (lt.licensetypecode IN ('02', '22')
                 AND lt.statusname NOT IN ('ACTIVE',
                                           'SUREND',
                                           'SUSPEN',
                                           'R64B',
                                           'REVPEN',
                                           'SLMSHD')));

            COMMIT;

            -- check if new 02 and 22 was a branch license
            UPDATE bizmod_api.licensetype_t lt
               SET (lt.awfflag, lt.awfstatusnumber) =
                       (SELECT CASE WHEN COUNT(1) > 0 THEN 'NA' ELSE NULL END,
                               CASE WHEN COUNT(1) > 0 THEN 8 ELSE NULL END -- 05/14/2024  TJL  BIZ-15461
                          FROM api.relationships r
                         WHERE (r.endpointid =
                                api.pkg_configquery.endpointidforname(
                                    'j_LicenseType',
                                    'MasterBranchLicenseType')
                             OR r.endpointid =
                                api.pkg_configquery.endpointidforname(
                                    'j_LicenseType',
                                    'MasterLicenseType'))
                           AND r.fromobjectid = lt.licensetypejobid)
             WHERE lt.licensetypecode IN ('02', '22')
               AND lt.statusname IN ('ACTIVE',
                                     'SUREND',
                                     'SUSPEN',
                                     'R64B',
                                     'REVPEN',
                                     'SLMSHD')
               AND lt.awfflag IS NULL;

            --  update application job id for license types just added
            UPDATE bizmod_api.licensetype_t lt
               SET lt.applicationjobid =
                       bizmod_api.utl_licenseinfo.get_application(
                           a_jobid     => lt.licensetypejobid,
                           a_licensetypecode => lt.licensetypecode)
             WHERE lt.statusname IN ('ACTIVE',
                                     'SUREND',
                                     'SUSPEN',
                                     'R64B',
                                     'REVPEN',
                                     'SLMSHD')
               AND lt.licensetypecode IN ('02', '22')
               AND NVL(lt.awfflag, 'Y') != 'NA'
               AND lt.applicationjobid IS NULL;

            COMMIT;

            -- 07/11/2024  TJL  BIZ-
            -- Update secondaries that have changed with new values
            UPDATE bizmod_api.licensetype_t lt2
               SET lt2.secondaries =
                       (SELECT json_arrayagg(
                                   json_object(
                                       'LTC' VALUE
                                           api.pkg_columnquery.VALUE(
                                               slt.toobjectid,
                                               'LicenseTypeCode'),
                                       'ID' VALUE slt.relationshipid))
                          FROM api.relationships  slt
                               JOIN mart.licensetype lt
                                   ON (lt.objectid = slt.fromobjectid)
                         WHERE (lt.objectid = slt.fromobjectid
                            AND slt.endpointid =
                                api.pkg_configquery.endpointidforname(
                                    'j_LicenseType',
                                    'LicTypeCatSecondary'))
                           AND lt.objectid = lt2.licensetypejobid)
             WHERE NVL(lt2.secondaries, 'none') !=
                   NVL(
                       (SELECT json_arrayagg(
                                   json_object(
                                       'LTC' VALUE
                                           api.pkg_columnquery.VALUE(
                                               slt.toobjectid,
                                               'LicenseTypeCode'),
                                       'ID' VALUE slt.relationshipid))
                          FROM api.relationships  slt
                               JOIN mart.licensetype lt
                                   ON (lt.objectid = slt.fromobjectid)
                         WHERE (lt.objectid = slt.fromobjectid
                            AND slt.endpointid =
                                api.pkg_configquery.endpointidforname(
                                    'j_LicenseType',
                                    'LicTypeCatSecondary'))
                           AND lt.objectid = lt2.licensetypejobid),
                       'none');

            -- get awf renewal fee
            FOR lt IN (SELECT lt.*
                         FROM bizmod_api.licensetype_t lt
                        WHERE lt.licensetypecode IN ('02', '22')
                          AND lt.renfeeobjid IS NULL
                          AND NVL(lt.awfflag, 'Y') != 'NA' -- 05/14/2024  TJL  BIZ-15461
                          AND lt.statusname IN ('ACTIVE',
                                                'SUREND',
                                                'SUSPEN',
                                                'R64B',
                                                'REVPEN',
                                                'SLMSHD'))
            LOOP
                t_msgno := awfrequired(a_fiscalend => greatest(lt.licensetypeexpirationdate, t_expirationdate), -- 07/24/2024  TJL  BIZ-15915
                                       a_licensetypeobjectid     => lt.licensetypejobid);
                t_feeobjid :=
                    get_awfreninfo(a_fiscalend => greatest(lt.licensetypeexpirationdate, t_expirationdate), -- 07/24/2024  TJL  BIZ-15915
                                   a_jobid     => lt.licensetypejobid);

                UPDATE bizmod_api.licensetype_t lic
                   SET lic.renfeeobjid = t_feeobjid,
                       lic.renewalfeedate =
                           api.pkg_columnquery.datevalue(t_feeobjid,
                                                         'TransactionDate'),
                       lic.awfstatusnumber = t_msgno,
                       lic.awfflag =
                           CASE NVL(t_msgno, 0) WHEN 0 THEN 'Y'
                             ELSE 'N' END
                 WHERE lic.licensetypejobid = lt.licensetypejobid;
            END LOOP;

            COMMIT;
        END;
    END;
-- ****************************************************************************
-- ****************************************************************************
--   Main Process
-- ****************************************************************************
-- ****************************************************************************

BEGIN
    DECLARE
        t_refunded     VARCHAR2(1);
        t_feetransfer  NUMBER;
        t_paymenttransfer NUMBER;
        t_awfbatch     NUMBER;

        t_body         VARCHAR2(32000);
        t_rowcount     NUMBER;

        t_error        VARCHAR2(32000);
        t_sqlerrm      VARCHAR2(4000);
        t_trace        VARCHAR2(4000);
        t_payment      NUMBER;
        t_paymentbatch NUMBER;
        t_seq          NUMBER := bizmod_api.e_payment_seq.NEXTVAL();
        t_errorcnt     NUMBER := 0;
    BEGIN
        -- ********************************************************************
        t_body := 'E-Service Nightly Job Completed' || CHR(10) || CHR(13);

        -- ********************************************************************
        BEGIN
            -- ************************************************************
            -- Check for payments being removed from original transmittal and
            --   updating payment record with new transmittal batch id or
            --   NULL if not assigned to another transmittal batch
            -- ************************************************************
            UPDATE bizmod_api.e_payments_t p
               SET p.transmittalbatch =
                       (SELECT rn.fromobjectid
                          FROM api.relationships rn
                         WHERE rn.endpointid =
                               api.pkg_configquery.endpointidforname(
                                   'j_Transmittal',
                                   'Payment')
                           AND rn.toobjectid = p.paymentobjectid)
             WHERE p.paymentobjectid IN
                       (SELECT DISTINCT p.paymentobjectid
                          FROM bizmod_api.e_payments_t p
                         WHERE p.transmittalbatch IS NOT NULL
                           AND p.issued IS NULL
                           AND NOT EXISTS
                                   (SELECT 1
                                      FROM api.relationships rn
                                     WHERE rn.endpointid =
                                           api.pkg_configquery.endpointidforname(
                                               'j_Transmittal',
                                               'Payment')
                                       AND rn.fromobjectid =
                                           p.transmittalbatch
                                       AND rn.toobjectid = p.paymentobjectid));

            -- ************************************************************
            -- Update payment record for payments manually added to transmittal
            --    batch.
            -- ************************************************************
            UPDATE bizmod_api.e_payments_t p
               SET p.transmittalbatch =
                       (SELECT rn.fromobjectid
                          FROM api.relationships rn
                         WHERE rn.endpointid =
                               api.pkg_configquery.endpointidforname(
                                   'j_Transmittal',
                                   'Payment')
                           AND rn.toobjectid = p.paymentobjectid)
             WHERE p.paymentobjectid IN (SELECT DISTINCT p.paymentobjectid
                                           FROM bizmod_api.e_payments_t p
                                          WHERE p.transmittalbatch IS NULL)
               AND EXISTS
                       (SELECT 1
                          FROM api.relationships rn
                         WHERE rn.endpointid =
                               api.pkg_configquery.endpointidforname(
                                   'j_Transmittal',
                                   'Payment')
                           AND rn.toobjectid = p.paymentobjectid);

            -- ************************************************************
            --  Update transmittal completion date for transmittal manually completed
            -- ************************************************************
            UPDATE bizmod_api.e_payments_t p
               SET p.transmittalbatchdate =
                       api.pkg_columnquery.datevalue(p.transmittalbatch,
                                                     'CompletedDate')
             WHERE p.transmittalbatch IS NOT NULL
               AND p.transmittalbatchdate IS NULL;

            COMMIT;

            -- ************************************************************
            --  Get Deposit batch information for deposit batches that are
            --    manually created for completed transmittal batches.
            -- ************************************************************
            UPDATE bizmod_api.e_payments_t p
               SET (p.depositbatchid, p.depositbatchdate, p.depositstatus) =
                       (SELECT DISTINCT
                               r.toobjectid,
                               api.pkg_columnquery.datevalue(r.toobjectid,
                                                             'CreatedDate'),
                               api.pkg_columnquery.VALUE(r.toobjectid,
                                                         'StatusName')
                          FROM api.relationships r
                         WHERE r.endpointid =
                               api.pkg_configquery.endpointidforname(
                                   'j_transmittal',
                                   'Deposit')
                           AND r.fromobjectid = p.transmittalbatch)
             WHERE p.depositstatus IS NULL
               AND p.transmittalbatchdate IS NOT NULL;


            -- ************************************************************
            --  Update Deposit status of deposits completed
            -- ************************************************************
            UPDATE bizmod_api.e_payments_t p
               SET p.depositstatus =
                       api.pkg_columnquery.VALUE(p.depositbatchid,
                                                 'StatusName')
             WHERE NVL(p.depositstatus, 'X') = 'PREPAR';

            IF (SQL%ROWCOUNT > 0)
            THEN
                t_body :=
                    t_body
                    || 'Updating E-Services Payment Deposit Status'
                    || CHR(10)
                    || CHR(13);
            END IF;

            COMMIT;

            -- ********************************************************************
            --  Check for License Issued
            -- ********************************************************************
            t_rowcount := 0;

            FOR lts
                IN (SELECT api.pkg_columnquery.numericvalue(p.feeobjid,
                                                            'JobId')
                               jobid,
                           p.licensetypecode,
                           ltc.color,
                           TRUNC(
                               api.pkg_columnquery.datevalue(
                                   p.feeobjid,
                                   'TransactionDate'))
                               transactiondate,
                           p.depositbatchdate
                      FROM bizmod_api.e_payments_t  p
                           JOIN query.o_licensetypecategory ltc
                               ON (ltc.licensetypecode = p.licensetypecode)
                     WHERE p.issued IS NULL
                       AND p.depositstatus = 'DEP')
            LOOP
                -- look if license has been issued for this renewal activity
                FOR b
                    IN (SELECT *
                          FROM (SELECT /*+ materialize */
                                       api.pkg_columnquery.datevalue(
                                           x.licensebatchjobid,
                                           'completeddate')        completeddate,
                                       api.pkg_columnquery.VALUE(
                                           x.licensebatchjobid,
                                           'color')                color,
                                       api.pkg_columnquery.VALUE(
                                           x.licensebatchjobid,
                                           'BatchType')            batchtype,
                                       api.pkg_columnquery.VALUE(
                                           x.licensebatchjobid,
                                           'StatusDescription')    statusdescription
                                  FROM sitespecific.licbatchlictype_xref_t x
                                 WHERE x.licensetypejobid = lts.jobid) b
                         WHERE b.batchtype = 'PRODUCE LICENSES'
                           AND b.completeddate >= lts.depositbatchdate
                           AND b.color = lts.color
                           AND b.statusdescription = 'Complete')
                LOOP
                    UPDATE bizmod_api.e_payments_t p
                       SET p.issued = 'Y'
                     WHERE api.pkg_columnquery.numericvalue(p.feeobjid,
                                                            'JobId') =
                           lts.jobid
                       AND p.licensetypecode = lts.licensetypecode
                       LOG ERRORS INTO bizmod_api.err$_e_payments_t
                               ('UPDATE')
                               REJECT LIMIT UNLIMITED;

                    t_rowcount := t_rowcount + SQL%ROWCOUNT;

                    COMMIT;
                END LOOP;
            END LOOP;

            IF (t_rowcount > 0)
            THEN
                t_body :=
                    t_body
                    || 'Licenses Issued by Produce Licenses Batches: '
                    || t_rowcount
                    || CHR(10)
                    || CHR(13);
            END IF;

            -- ************************************************************
            -- Update license and AWF info
            -- ************************************************************
            updateinfo;

            -- ********************************************************************
            -- ********************************************************************
            --  Update awf fee id and fee object id after payments have been completed
            -- ********************************************************************
            UPDATE bizmod_api.awf_t a
               SET (a.completed, a.awffeeid) =
                       (SELECT CASE
                                   WHEN f.feeid IS NOT NULL THEN 'Y'
                                   ELSE a.completed
                               END,
                               f.feeid
                          FROM api.fees f
                         WHERE f.jobid = a.licensetypejobid
                           AND f.transactiondate > a.createddate
                           AND f.description LIKE '%AWF%'
                           AND ROWNUM = 1)
             WHERE a.awffeeid IS NULL
               AND ((a.awffeeamount = 0
                 AND a.paymentbatch IS NOT NULL)
                 OR (NVL(a.completed, 'N') = 'N'
                 AND a.awffeeamount > 0
                 AND EXISTS
                         (SELECT 1
                            FROM bizmod_api.e_payments_t p
                           WHERE p.licensenumber = a.licensenumber
                             AND p.createddate >= a.submitteddate
                             AND p.description LIKE '%AWF%'))
                AND EXISTS
                        (SELECT 1
                           FROM api.fees f
                          WHERE f.jobid = a.licensetypejobid
                            AND f.transactiondate > a.submitteddate
                            AND f.description LIKE '%AWF%'));

            IF (SQL%ROWCOUNT > 0)
            THEN
                t_body :=
                    t_body || 'AWF Processed: ' || SQL%ROWCOUNT || CHR(13);
            END IF;

            COMMIT;

            -- 03/22/2024 TJL BIZ-14833
            UPDATE bizmod_api.licensetype_t lt
               SET lt.awfflag = 'N', lt.awfstatusnumber = 9
             WHERE lt.awfflag = 'Y'
               AND EXISTS
                       (SELECT 1
                          FROM bizmod_api.awf_t a
                         WHERE a.licensetypejobid = lt.licensetypejobid
                           AND a.submitteddate >
                               ADD_MONTHS(lt.licensetypeexpirationdate, -12)
                           AND a.awffeeid IS NOT NULL);

            COMMIT;

            -- ********************************************************************
            --  03/06/2024  TJL  BIZ-14725
            --  Update AWF payment batch when missing from payment table
            -- ********************************************************************
            FOR rec IN (SELECT p.feeobjid, p.seq
                          FROM bizmod_api.e_payments_t p
                         WHERE p.feeobjid IS NOT NULL
                           AND NVL(p.paymentobjectid, 1) > 0 -- 04/26/2024 TJL BIZ-15142
                           AND p.description LIKE '%AWF%')
            LOOP
                BEGIN
                    t_payment := NULL;

                    SELECT api.pkg_simplesearch.objectbyindex(
                               'o_Payment',
                               'Paymentid',
                               api.pkg_columnquery.VALUE(reo.objectid,
                                                         'PaymentId'))
                      INTO t_payment
                      FROM api.registeredexternalobjects reo
                     WHERE reo.objectdefid =
                           api.pkg_configquery.objectdefidforname(
                               'o_PaymentTransactions')
                       AND reo.linkvalue =
                           (SELECT TO_CHAR(transactionid)
                              FROM api.feetransactions t
                             WHERE feeid =
                                   api.pkg_columnquery.numericvalue(
                                       rec.feeobjid,
                                       'FeeId'));

                    SELECT r.toobjectid
                      INTO t_paymentbatch
                      FROM api.relationships r
                     WHERE r.endpointid =
                           api.pkg_configquery.endpointidforname(
                               'o_Payment',
                               'PaymentBatch')
                       AND r.fromobjectid = t_payment;

                    UPDATE bizmod_api.e_payments_t p
                       SET p.paymentobjectid = t_paymentbatch,
                           p.processdate = SYSDATE,
                           p.processid = t_seq
                     WHERE seq = rec.seq;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        UPDATE bizmod_api.e_payments_t p
                           SET p.paymentobjectid = 0,
                               p.processdate = SYSDATE,
                               p.processid = t_seq
                         WHERE seq = rec.seq;

                        t_errorcnt := t_errorcnt + 1;
                END;

                COMMIT;
            END LOOP;

            FOR rec IN (SELECT a.awffeeid feeid, ROWID seq
                          FROM bizmod_api.awf_t a
                         WHERE a.awffeeid IS NOT NULL
                           AND a.paymentbatch IS NULL)
            LOOP
                BEGIN
                    t_payment := NULL;

                    SELECT api.pkg_simplesearch.objectbyindex(
                               'o_Payment',
                               'Paymentid',
                               api.pkg_columnquery.VALUE(reo.objectid,
                                                         'PaymentId'))
                      INTO t_payment
                      FROM api.registeredexternalobjects reo
                     WHERE reo.objectdefid =
                           api.pkg_configquery.objectdefidforname(
                               'o_PaymentTransactions')
                       AND reo.linkvalue = (SELECT TO_CHAR(transactionid)
                                              FROM api.feetransactions t
                                             WHERE feeid = rec.feeid);

                    SELECT r.toobjectid
                      INTO t_paymentbatch
                      FROM api.relationships r
                     WHERE r.endpointid =
                           api.pkg_configquery.endpointidforname(
                               'o_Payment',
                               'PaymentBatch')
                       AND r.fromobjectid = t_payment;

                    UPDATE bizmod_api.awf_t a
                       SET a.paymentbatch = t_paymentbatch,
                           a.paymentbatchdate =
                               api.pkg_columnquery.datevalue(t_paymentbatch,
                                                             'CreatedDate')
                     WHERE ROWID = rec.seq;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        UPDATE bizmod_api.awf_t a
                           SET a.paymentbatch = 0,
                               a.paymentbatchdate = SYSDATE
                         WHERE ROWID = rec.seq;

                        t_errorcnt := t_errorcnt + 1;
                END;

                COMMIT;
            END LOOP;

            IF (t_errorcnt > 0)
            THEN
                t_error :=
                    t_error
                    || CHR(13)
                    || 'AWF Process Errors: '
                    || t_errorcnt
                    || CHR(13);
            END IF;

            -- ********************************************************************
            --  check to see if AWF Refund has been completed
            -- ********************************************************************
            UPDATE bizmod_api.awf_t a
               SET a.awffeeid =
                       (SELECT f.feeid
                          FROM api.fees f
                         WHERE f.jobid = a.licensetypejobid
                           AND f.transactiondate > a.createddate
                           AND f.description LIKE '%AWF%'
                           AND ROWNUM = 1)
             WHERE a.awffeeid IS NULL
               AND a.awffeeamount < 0;

            COMMIT;

            FOR rec IN (SELECT a.renfeeid, a.renfeeobjid, ROWID id
                          FROM bizmod_api.awf_t a
                         WHERE a.awffeeamount < 0
                           AND NVL(a.completed, 'N') != 'Y')
            LOOP
                  -- check if awf was refunded
                  SELECT CASE
                             WHEN SUM(
                                      CASE
                                          WHEN api.pkg_columnquery.VALUE(
                                                   reo.objectid,
                                                   'RefundBatchId')
                                                   IS NOT NULL
                                          THEN
                                              1
                                          ELSE
                                              0
                                      END) >
                                  0
                             THEN
                                 'Y'
                             ELSE
                                 NULL
                         END
                    INTO t_refunded
                    FROM api.paymenttransactions pt
                         JOIN api.feetransactions ft
                             ON pt.transactionid = ft.transactionid
                         JOIN api.registeredexternalobjects reo
                             ON (reo.linkvalue = TO_CHAR(pt.paymentid)
                             AND reo.objectdefid =
                                 api.pkg_configquery.objectdefidforname(
                                     'o_Payment'))
                   WHERE ft.feeid = rec.renfeeid
                GROUP BY ft.feeid;

                IF (NVL(t_refunded, 'N') = 'Y')
                THEN
                    UPDATE bizmod_api.awf_t a
                       SET a.completed = t_refunded
                     WHERE a.ROWID = rec.id;
                END IF;
            END LOOP;

            COMMIT;

            UPDATE bizmod_api.e_payments_t p
               SET p.feeobjid =
                       (SELECT reo.objectid     feeobjid
                          FROM bizmod_api.awf_t  a
                               JOIN api.registeredexternalobjects reo
                                   ON (reo.linkvalue = TO_CHAR(a.awffeeid)
                                   AND reo.objectdefid =
                                       api.pkg_configquery.objectdefidforname(
                                           'o_Fee'))
                         WHERE a.awffeeid IS NOT NULL
                           AND p.licensenumber = a.licensenumber
                           AND p.licensetypecode = a.licensetypecode)
             WHERE p.feeobjid IS NULL
               AND p.description LIKE 'AWF';

            COMMIT;
        EXCEPTION
            WHEN OTHERS
            THEN
                t_sqlerrm := SQLERRM;
                t_trace := DBMS_UTILITY.format_error_backtrace;
        END;

        INSERT INTO bizmod_api.e_process_log_t(seq,
                                               processjob,
                                               info,
                                               errmsg,
                                               bktrace)
             VALUES (0,
                     'NIGHTLYPROCESSJOB',
                     t_body,
                     t_sqlerrm,
                     t_trace);

        COMMIT;
    END;
END nightlyprocessjob;
/


GRANT EXECUTE ON BIZMOD_API.NIGHTLYPROCESSJOB TO ABC;

GRANT EXECUTE ON BIZMOD_API.NIGHTLYPROCESSJOB TO POSSEEXTENSIONS;
