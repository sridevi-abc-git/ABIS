CREATE OR REPLACE PACKAGE BODY BIZMOD_API.utl_licenseinfo
AS
    -- ****************************************************************************
    -- File:        BIZMOD_API.UTL_LICENSEINFO.PKB
    -- Author:      Timothy J. Lord
    --
    -- Purpose:
    --
    -- History:
    -------------------------------------------------------------------------------
    --              Date           Ticket     Comment
    --          07/20/2023  TJL  BIZ-11991    Added return code 7 for license that have not
    --                                        been renewed for current fiscal year.
    --   2.1    07/25/2023  TJL  BIZ-12102    Added procedure get_awfreninfo
    --   2.2    07/27/2023  TJL  BIZ-12070    Added error handling and handling two
    --                                          renewal fees in same fiscal year in get_awfreninfo
    --   2.3    08/02/2023  TJL  BIZ-12220    Corrected bug in awfrequired function in returning
    --                                          Y for license type 22 after payment
    -- ****************************************************************************


    FUNCTION statusmatrix(a_status IN VARCHAR2)
        RETURN VARCHAR2
    IS
    -- ****************************************************************************
    -- Purpose :    This function is called to convert a status description to
    --              a status code.  If status description is not found then the
    --              status discription is retuned as the status code.
    --
    -- ****************************************************************************
    BEGIN
        RETURN CASE UPPER(a_status)
                   WHEN 'ACTIVE' THEN 'ACTIVE'
                   WHEN 'AUTO REVOKED' THEN 'AUTREV'
                   WHEN 'CANCELED' THEN 'CANCEL'
                   WHEN 'DENIED' THEN 'DENIED'
                   WHEN 'DEPARTMENT REVOKED' THEN 'DEPREV'
                   WHEN 'NON-RENEWED' THEN 'NREN'
                   WHEN 'PENDING' THEN 'PEND'
                   WHEN 'REV PENDING' THEN 'REVPEN'
                   WHEN 'RULE 64B' THEN 'R64B'
                   WHEN 'SLMS REVOKED' THEN 'SLMSRV'
                   WHEN 'SURRENDERED' THEN 'SUREND'
                   WHEN 'SUSPENDED' THEN 'SUSPEN'
                   WHEN 'VOIDED' THEN 'VOIDED'
                   WHEN 'WITHDRAWN' THEN 'WTHDRN'
                   WHEN 'SLMS' THEN 'SLMSHD'
                   ELSE UPPER(a_status)
               END;
    END;

    -- ****************************************************************************
    -- This procedure is called to remove any json elements that are null
    -- ****************************************************************************
    PROCEDURE clean(a_json IN OUT json_object_t)
    IS
        t_json         json_object_t;
        t_array        json_array_t;
        t_element      json_element_t;
        keys           json_key_list;
    BEGIN
        IF (a_json IS NOT NULL)
        THEN
            keys := a_json.get_keys;

            IF (keys.COUNT > 0)
            THEN
                FOR i IN 1 .. keys.COUNT
                LOOP
                    IF (a_json.get_type(keys(i)) = 'ARRAY')
                    THEN
                        t_array := a_json.get_array(keys(i));

                        IF (t_array.get_size = 0)
                        THEN
                            a_json.remove(keys(i));
                        ELSE
                            FOR pos IN 0 .. t_array.get_size - 1
                            LOOP
                                t_element := t_array.get(pos);

                                IF (t_element.is_object)
                                THEN
                                    t_json :=
                                        TREAT(t_element AS json_object_t);
                                END IF;

                                clean(a_json => t_json);
                            END LOOP;
                        END IF;
                    ELSE
                        t_json := a_json.get_object(keys(i));

                        IF (t_json IS NOT NULL)
                        THEN
                            clean(a_json => t_json);
                        ELSE
                            IF (a_json.get_string(keys(i)) IS NULL)
                            THEN
                                a_json.remove(keys(i));
                            END IF;
                        END IF;
                    END IF;
                END LOOP;
            END IF;
        END IF;
    END;

    -- ****************************************************************************
    -- This function is called to check if a license type 02 or 22 have not reported
    --   their gallonage produce for last fiscal year.
    -- ****************************************************************************
    FUNCTION awfrequired(a_licensetypeobjectid IN NUMBER)
        RETURN NUMBER
    IS
        t_issuedate    DATE;
        t_branchapplies VARCHAR2(1);
        t_awfdate      DATE;
        t_expiration   DATE;
        t_awfrequired  VARCHAR2(2) := 'NA';
        t_start_date   DATE
            := TO_DATE(
                   '01-07-' || EXTRACT(YEAR FROM ADD_MONTHS(SYSDATE, -6)),
                   'dd-mm-yyyy');
        t_end_date     DATE
            := TO_DATE('30-06-' || EXTRACT(YEAR FROM ADD_MONTHS(SYSDATE, 6)),
                       'dd-mm-yyyy');
        t_application  NUMBER;
        t_applicationtype VARCHAR2(20);
        t_transferfromobjectid NUMBER;
        t_msgno        NUMBER;
    BEGIN
        IF (api.pkg_columnquery.VALUE(a_licensetypeobjectid,
                                      'LicenseTypeCode') IN
                ('02', '22'))
        THEN
            t_expiration :=
                api.pkg_columnquery.datevalue(a_licensetypeobjectid,
                                              'ExpirationDate');

            SELECT CASE NVL(cnt, 0) WHEN 0 THEN 'N' ELSE 'Y' END
              INTO t_branchapplies
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
                       AND r.fromobjectid = a_licensetypeobjectid);

            CASE
                WHEN (t_branchapplies = 'Y')
                THEN
                    t_msgno := 8;
                WHEN (t_expiration < TRUNC(SYSDATE))
                THEN
                    t_msgno := 7;
                ELSE
                    t_issuedate :=
                        api.pkg_columnquery.datevalue(a_licensetypeobjectid,
                                                      'IssueDate');

                    SELECT CASE WHEN SUM(cnt) = 0 THEN NULL ELSE 9 END
                      INTO t_msgno -- t_awfrequired
                      FROM (SELECT COUNT(1)     cnt
                              FROM api.fees f
                             WHERE f.jobid = a_licensetypeobjectid
                               AND TRUNC(f.transactiondate) BETWEEN t_start_date
                                                                AND t_end_date
                               AND f.description LIKE '%AWF%'
                            UNION
                            SELECT COUNT(1)     cnt
                              FROM bizmod_api.e_payments_t p
                             WHERE (p.licensenumber =
                                    api.pkg_columnquery.VALUE(
                                        a_licensetypeobjectid,
                                        'LicenseNumber')
                                AND p.licensetypecode IN ('02', '22')
                                AND p.description LIKE '%AWF%'
                                AND TRUNC(p.createddate) BETWEEN t_start_date
                                                             AND t_end_date));

                    --            DBMS_OUTPUT.put_line(
                    --                'xxx: '
                    --                || t_awfrequired
                    --                || CHR(9)
                    --                || t_issuedate
                    --                || CHR(9)
                    --                || ADD_MONTHS(t_expiration, -24));

                    -- check if this was liense was just issued or was transfered
                    IF (t_msgno IS NULL
                    AND t_issuedate > ADD_MONTHS(t_expiration, -24))
                    THEN
                        -- get application for this license
                        SELECT a.toobjectid
                          INTO t_application
                          FROM api.relationships  l
                               JOIN api.relationships a
                                   ON (a.endpointid =
                                       api.pkg_configquery.endpointidforname(
                                           'j_License',
                                           'ApplicationLicense')
                                   AND a.fromobjectid = l.toobjectid)
                         WHERE l.endpointid =
                               api.pkg_configquery.endpointidforname(
                                   'j_LicenseType',
                                   'License')
                           AND l.fromobjectid = a_licensetypeobjectid
                           AND REGEXP_LIKE(
                                   api.pkg_columnquery.VALUE(
                                       a.toobjectid,
                                       'PrimaryLicenseTypeCodes'),
                                   '02|22');

                        t_applicationtype :=
                            api.pkg_columnquery.VALUE(t_application,
                                                      'ApplicationType');

                        --                DBMS_OUTPUT.put_line(
                        --                    t_application
                        --                    || CHR(9)
                        --                    || t_applicationtype
                        --                    || CHR(9)
                        --                    || t_issuedate);

                        -- make sure that this license has been renewed in the pass not issued this year
                        CASE
                            WHEN ((t_issuedate >=
                                   ADD_MONTHS(t_expiration, -12)
                               AND ((t_applicationtype = 'Original')
                                 OR (t_applicationtype = 'Transfer'
                                 AND api.pkg_columnquery.VALUE(
                                         t_application,
                                         'PersonToPerson') =
                                     'Y')
                                 OR (t_applicationtype = 'Change'
                                 AND api.pkg_columnquery.VALUE(
                                         t_application,
                                         'AddPrimaryLicenseType') =
                                     'Y'))))
                            THEN
                                t_msgno := 10;
                            WHEN t_applicationtype = 'Transfer'
                            THEN
                                -- find license transfer from
                                SELECT lt.toobjectid
                                  INTO t_transferfromobjectid
                                  FROM api.relationships lt
                                 WHERE (lt.endpointid =
                                        api.pkg_configquery.endpointidforname(
                                            'j_License',
                                            'LicenseType')
                                    AND lt.fromobjectid =
                                        api.pkg_columnquery.numericvalue(
                                            t_application,
                                            'TransferFromLicenseObjectId')
                               AND REGEXP_LIKE(
                                       api.pkg_columnquery.VALUE(
                                           lt.toobjectid,
                                           'LicenseTypeCode'),
                                       '02|22'));

                                --t_transferfromobjectid := api.pkg_columnquery.numericvalue(
                                --                                    t_application,
                                --                                    'TransferFromLicenseObjectId');

                                --                        DBMS_OUTPUT.put_line(
                                --                            'transfer: ' || t_transferfromobjectid);


                                SELECT CASE
                                           WHEN SUM(cnt) = 0 THEN NULL
                                           ELSE 9
                                       END
                                  INTO t_msgno
                                  FROM (SELECT COUNT(1)     cnt
                                          FROM api.fees f
                                         WHERE f.jobid =
                                               t_transferfromobjectid
                                           AND TRUNC(f.transactiondate) BETWEEN t_start_date
                                                                            AND t_end_date
                                           AND f.description LIKE '%AWF%'
                                        UNION
                                        SELECT COUNT(1)     cnt
                                          FROM bizmod_api.e_payments_t p
                                         WHERE p.licensenumber =
                                               api.pkg_columnquery.VALUE(
                                                   t_transferfromobjectid,
                                                   'LicenseNumber')
                                           AND p.licensetypecode IN ('02', '22')
                                           AND TRUNC(p.createddate) BETWEEN t_start_date
                                                                        AND t_end_date
                                           AND p.description LIKE '%AWF%');
                            ELSE
                                NULL;
                        END CASE;
                    END IF;
            END CASE;
        END IF;

        RETURN t_msgno;
    END;

    FUNCTION get_awfreninfo(a_fiscalend IN DATE, a_jobid IN NUMBER)
        RETURN NUMBER
    IS
        t_start_date   DATE;
        t_end_date     DATE;
        t_application  NUMBER;
        t_applicationtype VARCHAR2(20);
        t_transferfromobjectid NUMBER;
        t_issuedate    DATE;
        t_feeid        NUMBER;
        t_feeobjid     NUMBER;
    BEGIN
        t_issuedate := api.pkg_columnquery.datevalue(a_jobid, 'IssueDate');

        t_start_date := ADD_MONTHS(a_fiscalend + 1, -36);
        t_end_date := ADD_MONTHS(a_fiscalend, -12);

        -- Older license don't have applications in ABIS
        --   Applications not need for licenses issued over 3 years ago
        IF (TRUNC(t_issuedate) >= ADD_MONTHS(a_fiscalend + 1, -36))
        THEN
            -- get application for this license
            SELECT a.toobjectid
              INTO t_application
              FROM api.relationships  l
                   JOIN api.relationships a
                       ON (a.endpointid =
                           api.pkg_configquery.endpointidforname(
                               'j_License',
                               'ApplicationLicense')
                       AND a.fromobjectid = l.toobjectid)
             WHERE l.endpointid =
                   api.pkg_configquery.endpointidforname('j_LicenseType',
                                                         'License')
               AND l.fromobjectid = a_jobid
               AND REGEXP_LIKE(
                       api.pkg_columnquery.VALUE(a.toobjectid,
                                                 'PrimaryLicenseTypeCodes'),
                       '02|22');

            t_applicationtype :=
                api.pkg_columnquery.VALUE(t_application, 'ApplicationType');
        ELSE
            -- assume original for applications issued over 3 years ago
            t_applicationtype  := 'Original';
        END IF;

        IF (t_applicationtype = 'Transfer')
        THEN
            -- find license transfer from
            SELECT lt.toobjectid
              INTO t_transferfromobjectid
              FROM api.relationships lt
             WHERE (lt.endpointid =
                    api.pkg_configquery.endpointidforname('j_License',
                                                          'LicenseType')
                AND lt.fromobjectid =
                    api.pkg_columnquery.numericvalue(
                        t_application,
                        'TransferFromLicenseObjectId')
                AND REGEXP_LIKE(
                        api.pkg_columnquery.VALUE(lt.toobjectid,
                                                  'LicenseTypeCode'),
                        '02|22'));
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
                        t_feeid := api.pkg_columnquery.numericvalue(
                            bizmod_api.utl_licenseinfo.get_awfreninfo(
                                a_fiscalend => a_fiscalend,
                                a_jobid     => t_transferfromobjectid), 'FeeId');
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
                    SELECT f.feeid
                      INTO t_feeid
                      FROM api.fees f
                     WHERE f.jobid = t_application
                       AND SUBSTR(f.description, 1, 2) IN ('02', '22')
                       AND (f.description LIKE '%ANN%');
                ELSE
                    IF (t_applicationtype = 'Transfer')
                    THEN
                        t_feeid := api.pkg_columnquery.numericvalue(
                            bizmod_api.utl_licenseinfo.get_awfreninfo(
                                a_fiscalend => a_fiscalend,
                                a_jobid     => t_transferfromobjectid), 'FeeId');
                    ELSE
                        -- get ren fees from application
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

        SELECT reo.objectid
          INTO t_feeobjid
          FROM api.registeredexternalobjects reo
         WHERE reo.objectdefid =
               api.pkg_configquery.objectdefidforname('o_fee')
           AND reo.linkvalue = TO_CHAR(t_feeid);

        RETURN t_feeobjid;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            RETURN t_feeobjid;
    END;
END;
/


GRANT EXECUTE ON BIZMOD_API.UTL_LICENSEINFO TO ABC;

GRANT EXECUTE ON BIZMOD_API.UTL_LICENSEINFO TO BIZMOD_USER;
