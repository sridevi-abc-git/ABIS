CREATE OR REPLACE PACKAGE BODY BIZMOD_API.utl_licenseinfo
AS
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


    FUNCTION licensetypes(a_licensejobid IN api.pkg_definition.udt_id)
        RETURN CLOB
    IS
        t_json         CLOB;
        t_cnt          NUMBER;
    BEGIN
        SELECT TO_CLOB(
                   LISTAGG(
                       '{"LICENSETYPECODE":"'
                       || api.pkg_columnquery.VALUE(r.toobjectid,
                                                    'LicenseTypeCode')
                       || '","LICENSETYPECODEOBJECTID":"'
                       || r.toobjectid
                       || '","STATUS":"'
                       || statusmatrix(
                              api.pkg_columnquery.VALUE(r.toobjectid,
                                                        'StatusDescription'))
                       || '","STATUSDATE":"'
                       || TO_CHAR(
                              api.pkg_columnquery.datevalue(
                                  r.toobjectid,
                                  'StatusDateCorral'),
                              'YYYY-MM-DD"T"HH24:MI:SS"Z"')     -- status date
                       || '","TERM":"12'                                -- term
                       || '","ISSUEDATE":"'
                       || TO_CHAR(
                              api.pkg_columnquery.datevalue(r.toobjectid,
                                                            'IssueDate'),
                              'YYYY-MM-DD"T"HH24:MI:SS"Z"') -- original issue date
                       || '","EXPIRATIONDATE":"'
                       || TO_CHAR(
                              api.pkg_columnquery.datevalue(
                                  r.toobjectid,
                                  'dup_ExpirationDate'),
                              'YYYY-MM-DD"T"HH24:MI:SS"Z"')
                       || '","MASTERINDICATOR":"Y'           --master indicator
                       || '","DUPLICATECOUNT":0'            -- duplicate count
                       || ',"FEECODE":"'                           -- fee code
                       || api.pkg_columnquery.VALUE(r.toobjectid,
                                                    'FeeScheduleCode')
                       || '"'
                       || utl_licenseinfo.secondary(r.toobjectid)
                       || utl_licenseinfo.conditions_count(a_licensejobid,
                                                           r.toobjectid)
                       || (SELECT CASE
                                      WHEN SUM(info.cnt) > 0
                                      THEN
                                          ',"TRANSFER":'
                                          || LISTAGG(info.transfer, ',')
                                                 WITHIN GROUP (ORDER BY 1)
                                      ELSE
                                          NULL
                                  END    data
                             FROM (SELECT NVL2(
                                              tr.objectid,
                                              '{"TO":"'
                                              || tr.transtolicensenumber
                                              || '","TRANSFERDDON":"'
                                              ||                         --tr.
                                                 TO_CHAR(
                                                     api.pkg_columnquery.datevalue(
                                                         tr.transtoltjobid,
                                                         'ISSUEDATE'),
                                                     'YYYY-MM-DD"T"HH24:MI:SS"Z"')
                                              || '"}',
                                              NULL)    transfer,
                                          1            cnt
                                     FROM sitespecific.licensetransfers_t tr
                                    WHERE tr.transfromltjobid = r.toobjectid
                                      AND tr.objectid =
                                          (SELECT MAX(t2.objectid)
                                             FROM sitespecific.licensetransfers_t
                                                  t2
                                            WHERE t2.transfromltjobid =
                                                  r.toobjectid)
                                   UNION
                                   SELECT NVL2(
                                              tr.objectid,
                                              '{"FROM":"'
                                              || tr.transfromlicensenumber
                                              || '","TRANSFEREDON":"'
                                              ||                         --tr.
                                                 TO_CHAR(
                                                     api.pkg_columnquery.datevalue(
                                                         tr.transtoltjobid,
                                                         'ISSUEDATE'),
                                                     'YYYY-MM-DD"T"HH24:MI:SS"Z"')
                                              || '"}',
                                              NULL)    transfer,
                                          1            cnt
                                     FROM sitespecific.licensetransfers_t tr
                                    WHERE tr.transtoltjobid = r.toobjectid
                                      AND tr.objectid =
                                          (SELECT MAX(t2.objectid)
                                             FROM sitespecific.licensetransfers_t
                                                  t2
                                            WHERE t2.transtoltjobid =
                                                  r.toobjectid)) info
                            WHERE info.cnt > 0)
                       || '}',
                       ',')
                   WITHIN GROUP (ORDER BY 1))    licensetype,
               COUNT(1)                          cnt
          INTO t_json, t_cnt
          FROM api.relationships r
         WHERE r.endpointid =
               api.pkg_configquery.endpointidforname('j_License',
                                                     'LicenseType')
           AND r.fromobjectid = a_licensejobid;

        t_json :=
            CASE t_cnt
                WHEN 0 THEN NULL
                WHEN 1 THEN ',"LICENSE_TYPES":' || t_json
                ELSE ',"LICENSE_TYPES":[' || t_json || ']'
            END;


        RETURN t_json;
    END;


    FUNCTION secondary(a_licensetypejobid IN api.pkg_definition.udt_id)
        RETURN CLOB
    IS
        t_json         CLOB;
        t_cnt          NUMBER;
    BEGIN
          SELECT LISTAGG(
                     '{"LICENSETYPECODE":"'
                     || api.pkg_columnquery.VALUE(slt.toobjectid,
                                                  'LicenseTypeCode')
                     || '","STATUS":"'
                     || utl_licenseinfo.statusmatrix(
                            api.pkg_columnquery.VALUE(slt.relationshipid,
                                                      'Status'))
                     || '","STATUSDATE":"'
                     || TO_CHAR(
                            NVL(
                                api.pkg_columnquery.datevalue(
                                    slt.relationshipid,
                                    'EFFECTIVEDATE'),
                                api.pkg_columnquery.datevalue(
                                    a_licensetypejobid,
                                    'StatusDateCorral')),
                            'YYYY-MM-DD"T"HH24:MI:SS"Z"')       -- status date
                     || '","TERM":"12'                                 -- term
                     || '","ISSUEDATE":"'
                     || TO_CHAR(
                            api.pkg_columnquery.datevalue(slt.relationshipid,
                                                          'IssueDate'),
                            'YYYY-MM-DD"T"HH24:MI:SS"Z"') -- original issue date
                     || '","EXPIRATIONDATE":"'
                     || TO_CHAR(
                            api.pkg_columnquery.datevalue(slt.fromobjectid,
                                                          'ExpiratiONDate'),
                            'YYYY-MM-DD"T"HH24:MI:SS"Z"')
                     || ',"MASTERINDICATOR":"N'             --master indicator
                     || '","DUPLICATECOUNT":'               -- duplicate count
                     || api.pkg_columnquery.VALUE(slt.relationshipid,
                                                  'LicenseTypeCount')
                     || ',"FEECODE":"'                             -- fee code
                     || api.pkg_columnquery.VALUE(a_licensetypejobid,
                                                  'FeeScheduleCode')
                     || (SELECT CASE
                                    WHEN SUM(info.cnt) > 0
                                    THEN
                                        ',"TRANSFER":'
                                        || LISTAGG(info.transfer, ',')
                                               WITHIN GROUP (ORDER BY 1)
                                    ELSE
                                        NULL
                                END    data
                           FROM (SELECT NVL2(
                                            tr.objectid,
                                            '{"TO":"'
                                            || tr.transtolicensenumber
                                            || '","TRANSFERDDON":"'
                                            ||                           --tr.
                                               TO_CHAR(
                                                   api.pkg_columnquery.datevalue(
                                                       tr.transtoltjobid,
                                                       'ISSUEDATE'),
                                                   'YYYY-MM-DD"T"HH24:MI:SS"Z"')
                                            || '"}',
                                            NULL)    transfer,
                                        1            cnt
                                   FROM sitespecific.licensetransfers_t tr
                                  WHERE tr.transfromltjobid =
                                        a_licensetypejobid
                                    AND tr.objectid =
                                        (SELECT MAX(t2.objectid)
                                           FROM sitespecific.licensetransfers_t
                                                t2
                                          WHERE t2.transfromltjobid =
                                                a_licensetypejobid)
                                 UNION
                                 SELECT NVL2(
                                            tr.objectid,
                                            '{"FROM":"'
                                            || tr.transfromlicensenumber
                                            || '","TRANSFEREDON":"'
                                            ||                           --tr.
                                               TO_CHAR(
                                                   api.pkg_columnquery.datevalue(
                                                       tr.transtoltjobid,
                                                       'ISSUEDATE'),
                                                   'YYYY-MM-DD"T"HH24:MI:SS"Z"')
                                            || '"}',
                                            NULL)    transfer,
                                        1            cnt
                                   FROM sitespecific.licensetransfers_t tr
                                  WHERE tr.transtoltjobid = a_licensetypejobid
                                    AND tr.objectid =
                                        (SELECT MAX(t2.objectid)
                                           FROM sitespecific.licensetransfers_t
                                                t2
                                          WHERE t2.transtoltjobid =
                                                a_licensetypejobid)) info
                          WHERE info.cnt > 0)
                     || '"}',
                     ',')
                 WITHIN GROUP (ORDER BY 1)    secondarylicensetype,
                 COUNT(1)                     cnt
            INTO t_json, t_cnt
            FROM api.relationships slt
           WHERE (slt.fromobjectid = a_licensetypejobid
              AND slt.endpointid =
                  api.pkg_configquery.endpointidforname('j_LicenseType',
                                                        'LicTypeCatSecONdary'))
        GROUP BY slt.fromobjectid;

        t_json :=
            CASE t_cnt
                WHEN 0 THEN NULL
                WHEN 1 THEN ',"SECONDARY":' || t_json
                ELSE ',"SECONDARY":[' || t_json || ']'
            END;

        RETURN t_json;
    END;

    FUNCTION conditions_count(t_licensejobid NUMBER,
                              t_licensetypejobid NUMBER)
        RETURN VARCHAR2
    IS
        t_cond_desc    VARCHAR2(200);
        t_cnt          NUMBER;
    BEGIN
        WITH l AS(SELECT t_licensejobid, t_licensetypejobid FROM DUAL)
        SELECT LISTAGG('"' || code || '"', ',') WITHIN GROUP (ORDER BY code),
               COUNT(*)     cnt
          INTO t_cond_desc, t_cnt
          FROM (SELECT CASE api.pkg_columnquery.VALUE(t_licensejobid,
                                                      'CONDAV')
                           WHEN 'Y'
                           THEN
                               'LIMITED ALIEN VERIFICATION DATE'
                           ELSE
                               NULL
                       END    condav,
                       CASE api.pkg_columnquery.VALUE(t_licensetypejobid,
                                                      'COND1C')
                           WHEN 'Y'
                           THEN
                               'SEASONAL CONVERSIONS'
                           ELSE
                               NULL
                       END    cond1c,
                       CASE api.pkg_columnquery.VALUE(t_licensetypejobid,
                                                      'COND2')
                           WHEN 'Y'
                           THEN
                               'INTERCOUNTY PRIORITIES, NO SALE 5 YEARS'
                           ELSE
                               NULL
                       END    cond2,
                       CASE api.pkg_columnquery.VALUE(t_licensetypejobid,
                                                      'COND5')
                           WHEN 'Y'
                           THEN
                               'PRIORITIES 1995 AND LATER, NO SALE 2 YEARS'
                           ELSE
                               NULL
                       END    cond5,
                       CASE api.pkg_columnquery.VALUE(t_licensetypejobid,
                                                      'COND7')
                           WHEN 'Y'
                           THEN
                               'OPERATING RESTRICTIONS'
                           ELSE
                               NULL
                       END    cond7,
                       CASE api.pkg_columnquery.VALUE(t_licensetypejobid,
                                                      'COND8')
                           WHEN 'Y'
                           THEN
                               'CODE 8 - SELF-INCORPORATION - HISTORICAL VALUE'
                           ELSE
                               NULL
                       END    cond8,
                       CASE api.pkg_columnquery.VALUE(t_licensetypejobid,
                                                      'COND9')
                           WHEN 'Y'
                           THEN
                               'TIED HOUSE UNDERTAKINGS'
                           ELSE
                               NULL
                       END    cond9,
                       CASE api.pkg_columnquery.VALUE(t_licensetypejobid,
                                                      'CONDA')
                           WHEN 'Y'
                           THEN
                               '23824 CITY/COUNTY OWNED PROPERTY, PERS-PERS ONLY'
                           ELSE
                               NULL
                       END    conda,
                       CASE api.pkg_columnquery.VALUE(t_licensetypejobid,
                                                      'CONDD')
                           WHEN 'Y'
                           THEN
                               'PERS-PERS TRANSFER ONLY, PER SECTION 23817.5'
                           ELSE
                               NULL
                       END    condd,
                       CASE api.pkg_columnquery.VALUE(t_licensetypejobid,
                                                      'CONDG')
                           WHEN 'Y'
                           THEN
                               'SECTION 23433 - GOLF CLUB NON-TRANSFERABLE'
                           ELSE
                               NULL
                       END    condg,
                       CASE api.pkg_columnquery.VALUE(t_licensetypejobid,
                                                      'CONDI')
                           WHEN 'Y'
                           THEN
                               'INTERNET SALES ONLY'
                           ELSE
                               NULL
                       END    condi,
                       CASE api.pkg_columnquery.VALUE(t_licensetypejobid,
                                                      'CONDM')
                           WHEN 'Y'
                           THEN
                               'MICROENTERPRISE HOME KITCHEN'
                           ELSE
                               NULL
                       END    condm
                  -- CONDR
                  FROM l)
               UNPIVOT EXCLUDE NULLS (code
                                     FOR condition_code
                                     IN (cond1c,
                                        cond2,
                                        cond5,
                                        --COND7,
                                        cond8,
                                        cond9,
                                        conda,
                                        condd,
                                        condg,
                                        condi,
                                        condm));

        t_cond_desc :=
            CASE t_cnt
                WHEN 0 THEN NULL
                WHEN 1 THEN ',"CONDITIONS":' || t_cond_desc
                ELSE ',"CONDITIONS":[' || t_cond_desc || ']'
            END;

        RETURN t_cond_desc;
    END;

    FUNCTION legalentities(a_objectid IN api.pkg_definition.udt_id)
        RETURN CLOB
    IS
        FUNCTION getlegalentityinfo(
            a_legalentity  IN api.pkg_definition.udt_id)
            RETURN CLOB
        IS
            t_json         CLOB := EMPTY_CLOB();
            t_entity       CLOB;
            t_count        NUMBER := 0;
        BEGIN
            FOR e
                IN (SELECT api.pkg_columnquery.VALUE(a_legalentity,
                                                     'dup_HierarchyLevel')
                               nestedlevel,
                           api.pkg_columnquery.VALUE(a_legalentity,
                                                     'LETreeViewTitle')
                               title,
                           api.pkg_columnquery.VALUE(a_legalentity,
                                                     'dup_FormattedName')
                               name,
                           api.pkg_columnquery.VALUE(a_legalentity,
                                                     'LegalEntityType')
                               legalentitytype,
                           api.pkg_columnquery.VALUE(a_legalentity,
                                                     'LEStructureRel')
                               lestructurerel
                      FROM DUAL)
            LOOP
                t_entity :=
                    '"LEGALENTITYTYPE":"'
                    || e.legalentitytype
                    || '","LESTRUCTUREREL":"'
                    || e.lestructurerel
                    || '","NAME":"'
                    || e.name
                    || '","TITLE":"'
                    || e.title
                    || '","LEVEL":'
                    || e.nestedlevel
                    || ',"OBJECTID":'
                    || a_legalentity;
            END LOOP;

            FOR c
                IN (  SELECT DISTINCT r.toobjectid
                        FROM api.relationships r
                       WHERE api.pkg_columnquery.VALUE(r.toobjectid,
                                                       'ObjectDefId') =
                             295282                       -- ('o_LegalEntity')
                         AND r.fromobjectid = a_legalentity
                         AND r.fromobjectid =
                             api.pkg_columnquery.VALUE(r.toobjectid,
                                                       'dup_ParentObjectId')
                    ORDER BY r.toobjectid)
            LOOP
                IF (t_count > 0)
                THEN
                    t_json := t_json || ',';
                END IF;

                t_json := t_json || getlegalentityinfo(c.toobjectid);
                t_count := t_count + 1;
            END LOOP;

            IF (DBMS_LOB.getlength(t_json) != 0)
            THEN
                t_entity :=
                    t_entity
                    || ',"CHILDENTITY":'
                    || CASE t_count WHEN 1 THEN '' ELSE '[' END
                    || t_json
                    || CASE t_count WHEN 1 THEN '' ELSE ']' END;
            END IF;

            t_entity := '{' || t_entity || '}';
            RETURN t_entity;
        END;
    BEGIN
        DECLARE
            t_json         CLOB := EMPTY_CLOB();
            t_count        NUMBER := 0;
        BEGIN
            -- Get Top Legal Entities for a license job.
            --   a_objectid input parameter will contain the License Job Id

            -- The following select will select all Legal Entities that are
            --  pointed to from the License Job Id.  This will only contain
            --  top level Legal Entities since License Job Id do not have a
            --  relationship associated to childern Legal Entities.
            FOR c
                IN (  SELECT DISTINCT r.toobjectid
                        FROM api.relationships r
                       WHERE api.pkg_columnquery.VALUE(r.toobjectid,
                                                       'ObjectDefId') =
                             295282                       -- ('o_LegalEntity')
                         AND r.fromobjectid = a_objectid
                    ORDER BY r.toobjectid)
            LOOP
                -- Call GETLEGALENTITYINFO to get the information for the
                --  Legal Entity in JSON Format
                IF (t_count > 0)
                THEN
                    t_json := t_json || ',';
                END IF;

                t_json := t_json || getlegalentityinfo(c.toobjectid);
                t_count := t_count + 1;
            END LOOP;

            IF (DBMS_LOB.getlength(t_json) != 0)
            THEN
                t_json :=
                    ',"LEGALENTITIES":'
                    || CASE t_count WHEN 1 THEN '' ELSE '[' END
                    || t_json
                    || CASE t_count WHEN 1 THEN '' ELSE ']' END;
            END IF;

            RETURN t_json;
        END;
    END;
END;
/


GRANT EXECUTE ON BIZMOD_API.UTL_LICENSEINFO TO ABC;

GRANT EXECUTE ON BIZMOD_API.UTL_LICENSEINFO TO BIZMOD_USER;
