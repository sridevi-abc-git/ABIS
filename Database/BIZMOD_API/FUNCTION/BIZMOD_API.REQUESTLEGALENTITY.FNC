CREATE OR REPLACE FUNCTION BIZMOD_API.requestlegalentity(a_packet       IN CLOB,
                                              a_seq          IN NUMBER)
    RETURN CLOB
IS
    -- ****************************************************************************
    -- File:    BIZMOD_API.REQUESTLEGALENTITY.FNC
    -- Author:  Timothy J. Lord
    --
    -- History
    -------------------------------------------------------------------------------
    --  Ver:       Date          Ticket       Comment
    --  1.1.0  08/22/2024  TJL  BIZ-16242  Inital function created
    -- ****************************************************************************

    TYPE legalentity_type IS TABLE OF NUMBER;

    -- *********************************************************
    --  Get Person
    -- *********************************************************
    FUNCTION get_person(a_personobjectid IN   NUMBER,
                        a_list         IN OUT legalentity_type)
        RETURN json_object_t
    AS
        t_entity       json_object_t := json_object_t();
        t_person       json_object_t := json_object_t();
    BEGIN
        a_list.EXTEND(1);
        a_list(a_list.COUNT) := a_personobjectid;

        t_entity.put('OBJECTID', a_personobjectid);
        t_entity.put(
            'FIRSTNAME',
            api.pkg_columnquery.VALUE(a_personobjectid, 'FirstName'));
        t_entity.put(
            'MIDDLENAME',
            api.pkg_columnquery.VALUE(a_personobjectid, 'MiddleName'));
        t_entity.put('LASTNAME',
                     api.pkg_columnquery.VALUE(a_personobjectid, 'LastName'));

        t_person.put('PERSON', t_entity);
        RETURN json_object_t(t_person);
    END;


    -- *********************************************************
    --  Get Company
    -- *********************************************************
    FUNCTION get_company(a_legalentityobjectid IN NUMBER,
                         a_list         IN OUT legalentity_type)
        RETURN json_object_t
    AS
        t_objectid     NUMBER;
        t_entity       json_object_t := json_object_t();
        t_company      json_object_t := json_object_t();
        t_array        json_array_t := json_array_t();
    BEGIN
        IF NOT legalentity_type(a_legalentityobjectid) SUBMULTISET a_list
        THEN
            a_list.EXTEND(1);
            a_list(a_list.COUNT) := a_legalentityobjectid;

            -- get company relationship
            SELECT r.toobjectid
              INTO t_objectid
              FROM api.relationships r
             WHERE r.endpointid =
                   api.pkg_configquery.endpointidforname('o_LegalEntity',
                                                         'Company')
               AND r.fromobjectid = a_legalentityobjectid;

            t_company.put('OBJECTID', a_legalentityobjectid);
            t_company.put(
                'COMPANYNAME',
                api.pkg_columnquery.VALUE(t_objectid, 'CompanyName'));
            t_company.put(
                'COMPANYSTRUCTURE',
                api.pkg_columnquery.VALUE(t_objectid, 'CompanyStructure'));
            t_company.put(
                'DATEOFINCORPORATION',
                api.pkg_columnquery.VALUE(t_objectid, 'DateOfIncorporation'));
            t_company.put(
                'STATEOFINCORPORATION',
                api.pkg_columnquery.VALUE(t_objectid, 'StateOfIncorporation'));
            t_company.put(
                'CASECRETARYOFSTATENUMBER',
                api.pkg_columnquery.VALUE(t_objectid,
                                          'CASecretaryOfStateNumber'));
            t_company.put(
                'FEDERALEMPLOYERIDENTIFICATIONN',
                api.pkg_columnquery.VALUE(t_objectid,
                                          'FederalEmployerIdentificationn'));

            FOR rec
                IN (  SELECT r.toobjectid
                        FROM api.relationships r
                       WHERE r.fromobjectid = a_legalentityobjectid
                         AND r.endpointid IN (292101,
                                              338110,
                                              310133,
                                              298362,
                                              311516,
                                              314059,
                                              329508,
                                              427253,
                                              447075,
                                              340283)
                    ORDER BY api.pkg_columnquery.VALUE(r.toobjectid,
                                                       'LegalEntityType'))
            LOOP
                CASE api.pkg_columnquery.VALUE(rec.toobjectid,
                                               'LegalEntityType')
                    WHEN 'Company'
                    THEN
                        IF NOT legalentity_type(rec.toobjectid)
                                    SUBMULTISET a_list
                        THEN
                            t_array.append(
                                get_company(
                                    a_legalentityobjectid => rec.toobjectid,
                                    a_list      => a_list));
                        END IF;
                    WHEN 'Person'
                    THEN
                        FOR p
                            IN (SELECT r.toobjectid
                                  FROM api.relationships r
                                 WHERE r.fromobjectid = rec.toobjectid
                                   AND r.endpointid =
                                       api.pkg_configquery.endpointidforname(
                                           'o_LegalEntity',
                                           'Person'))
                        LOOP
                            IF NOT legalentity_type(p.toobjectid)
                                        SUBMULTISET a_list
                            THEN
                                t_array.append(
                                    get_person(
                                        a_personobjectid => p.toobjectid,
                                        a_list      => a_list));
                            END IF;
                        END LOOP;
                    ELSE
                        NULL;
                END CASE;
            END LOOP;


            t_company.put('LEGALENTITIES', t_array);
            t_entity.put('COMPANY', t_company);
        END IF;

        RETURN t_entity;
    END;


    -- *********************************************************
    --
    -- *********************************************************
    FUNCTION get_entities(a_legalentity  IN api.udt_objectlist,
                          a_search       IN VARCHAR2)
        RETURN json_array_t
    AS
        t_legalentity  legalentity_type := legalentity_type();
        t_array        json_array_t := json_array_t();
    BEGIN
        FOR rec
            IN (  SELECT DISTINCT info.*
                    FROM (WITH
                              lg
                              AS
                                  (SELECT api.pkg_columnquery.VALUE(
                                              r.toobjectid,
                                              'LegalEntityType')    TYPE,
                                          r.toobjectid              lg,
                                          CASE api.pkg_columnquery.VALUE(
                                                   r.toobjectid,
                                                   'LegalEntityType')
                                              WHEN 'Company'
                                              THEN
                                                  r.toobjectid
                                              ELSE
                                                  (SELECT r2.toobjectid
                                                     FROM api.relationships
                                                          r2
                                                    WHERE r2.fromobjectid =
                                                          r.toobjectid
                                                      AND r2.endpointid =
                                                          api.pkg_configquery.endpointidforname(
                                                              'o_LegalEntity',
                                                              api.pkg_columnquery.VALUE(
                                                                  r.toobjectid,
                                                                  'LegalEntityType')))
                                          END                       cp,
                                          api.pkg_columnquery.VALUE(
                                              r.toobjectid,
                                              CASE api.pkg_columnquery.VALUE(
                                                       r.toobjectid,
                                                       'LegalEntityType')
                                                  WHEN 'Company'
                                                  THEN
                                                      'CompanyName'
                                                  ELSE
                                                      'FormattedPersonNameSearch'
                                              END)                  name
                                     FROM api.relationships r
                                    WHERE r.fromobjectid IN
                                              (SELECT o.objectid
                                                 FROM TABLE(a_legalentity) o)
                                      AND r.endpointid IN (453414) -- (Node)
                                                                  )
                            SELECT lg.TYPE, lg.cp
                              FROM lg
                          GROUP BY lg.TYPE, lg.name, lg.cp
                            HAVING lg.name LIKE '%' || a_search || '%') info
                ORDER BY info.TYPE)
        LOOP
            DBMS_OUTPUT.put_line('LOOPING');

            -- check if person already added to return information
            IF NOT legalentity_type(rec.cp) SUBMULTISET t_legalentity
            THEN
                CASE rec.TYPE
                    WHEN 'Person'
                    THEN
                        t_array.append(
                            get_person(a_personobjectid => rec.cp,
                                       a_list      => t_legalentity));
                    WHEN 'Company'
                    THEN
                        t_array.append(
                            get_company(a_legalentityobjectid => rec.cp,
                                        a_list      => t_legalentity));
                    ELSE
                        NULL;
                END CASE;
            END IF;
        END LOOP;

        RETURN t_array;
    END;
-- *********************************************************
--  Main Function Process
-- *********************************************************
BEGIN
    DECLARE
        t_licensenumber VARCHAR2(40);
        t_search       VARCHAR2(200);
        t_msg          VARCHAR2(4000);
        t_msgno        NUMBER;
        t_array        json_array_t := json_array_t();
        t_json         json_object_t := json_object_t();
        t_entities     json_object_t := json_object_t();
        t_jobid        api.pkg_definition.udt_id;
        t_feeobjidlst  api.udt_objectlist;
        t_sqlerrm      VARCHAR2(4000);
        t_trace        VARCHAR2(4000);
    BEGIN
        t_licensenumber := json_value(a_packet, '$.*.LICENSENUMBER');
        t_search := UPPER(json_value(a_packet, '$.*.SEARCH'));
        t_jobid :=
            api.pkg_simplesearch.objectbyindex(
                a_objectdefname => 'j_License',
                a_columnname => 'ExternalFileNum',
                a_lowvalue  => t_licensenumber);

        IF (t_jobid IS NOT NULL)
        THEN
            SELECT api.udt_object(r.toobjectid)
              BULK COLLECT INTO t_feeobjidlst
              FROM api.relationships r
             WHERE r.fromobjectid = t_jobid
               AND r.endpointid IN (292101,
                                    338110,
                                    310133,
                                    298362,
                                    311516,
                                    314059,
                                    329508,
                                    427253,
                                    447075,
                                    340283);

            t_entities.put(
                'LEGALENTITIES',
                get_entities(a_legalentity => t_feeobjidlst,
                             a_search    => t_search));

            t_json.put('PACKET_TYPE', 'LEGALENTITIES');
            t_json.put('DATA', t_entities);
        ELSE
            t_json :=
                json_object_t(
                    '{"PACKET_TYPE":"MESSAGE","DATA":{"MSGNO":"1","MSG":"License Number '
                    || t_licensenumber
                    || ' Not Found"}}');
        END IF;

        --        DBMS_OUTPUT.put_line(
        --            json_query(t_json.TO_CLOB, '$' RETURNING CLOB PRETTY));
        RETURN t_json.TO_CLOB;
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

            DBMS_OUTPUT.put_line(t_sqlerrm || CHR(13) || CHR(10) || t_trace);
            RETURN json_object(
                       'PACKET_TYPE' VALUE 'MESSAGE',
                       'DATA' VALUE
                           json_object('MSGNO' VALUE 5,
                                       'MSG' VALUE 'Oracle Exception',
                                       'EXCEPTION' VALUE t_sqlerrm));
    END;
-- ******************************************************
--  Main Process
-- ******************************************************
--BEGIN
--    DECLARE
--        t_licensenumber VARCHAR2(40);
--        t_msg          VARCHAR2(4000);
----        t_msgno        NUMBER;
----        t_array        json_array_t := json_array_t();
--        t_json         json_object_t := json_object_t();
--        t_entities     json_object_t := json_object_t();
--        t_jobid        api.pkg_definition.udt_id;
--        t_sqlerrm      VARCHAR2(4000);
--        t_trace        VARCHAR2(4000);
--    BEGIN
--        t_licensenumber := json_value(a_packet, '$.*.LICENSENUMBER');
--        t_jobid :=
--            api.pkg_simplesearch.objectbyindex(
--                a_objectdefname => 'j_License',
--                a_columnname => 'ExternalFileNum',
--                a_lowvalue  => t_licensenumber);
--
--        IF (t_jobid IS NOT NULL)
--        THEN
--            t_json.put('PACKET_TYPE', 'LEGALENTITIES');
--            t_entities.put(
--                'LEGALENTITIES',
--                bizmod_api.utl_licenseinfo.get_legalentity(a_objectid => t_jobid));
--
----            t_entities.put('LEGALENTITIES', t_array);
----
----            FOR rec
----                IN (    SELECT DISTINCT
----                               SYS_CONNECT_BY_PATH(r.toobjectid, '/')     path2
----                          FROM api.relationships r
----                               JOIN api.objects f ON f.objectid = r.toobjectid
----                    START WITH r.fromobjectid = t_jobid
----                           AND (f.objectdefid =
----                                api.pkg_configquery.objectdefidforname(
----                                    'o_LegalEntity')
----                             OR f.objectdefid =
----                                api.pkg_configquery.objectdefidforname(
----                                    'j_License'))
----                           AND r.endpointid IN (292101,
----                                                338110,
----                                                310133,
----                                                298362,
----                                                311516,
----                                                314059,
----                                                329508,
----                                                427253,
----                                                447075,340283)
----                    CONNECT BY r.fromobjectid = PRIOR r.toobjectid
----                           AND r.relationshipid != PRIOR r.relationshipid
----                           AND f.objectdefid =
----                               api.pkg_configquery.objectdefidforname(
----                                   'o_LegalEntity')
----                           AND r.endpointid IN (292101,
----                                                338110,
----                                                310133,
----                                                298362,
----                                                311516,
----                                                314059,
----                                                329508,
----                                                427253,
----                                                447075,340283)
----                      ORDER BY path2)
----            LOOP
----                bizmod_api.utl_licenseinfo.get_legalentity(a_json => t_entities, a_list => rec.path2);
----            END LOOP;
--
--            t_json.put('DATA', t_entities);
--        ELSE
--            t_json := json_object_t(
--                '{"PACKET_TYPE":"MESSAGE","DATA":{"MSGNO":"1","MSG":"License Number '
--                || t_licensenumber
--                || ' Not Found"}}');
--        END IF;
--
--        RETURN t_json.to_clob;
--    EXCEPTION
--        WHEN OTHERS
--        THEN
--            t_sqlerrm := SQLERRM;
--            t_trace := DBMS_UTILITY.format_error_backtrace;
--            t_msg := SUBSTR(t_sqlerrm || CHR(13) || t_trace, 1, 3990);
--
--            UPDATE bizmod_api.eservices_log_t
--               SET err = t_msg
--             WHERE seq = a_seq;
--
--            COMMIT;
--
--            DBMS_OUTPUT.put_line(t_sqlerrm || CHR(13) || CHR(10) || t_trace);
--            RETURN
--                json_object(
--                    'PACKET_TYPE' VALUE 'MESSAGE',
--                    'DATA' VALUE
--                        json_object('MSGNO' VALUE 5,
--                                    'MSG' VALUE 'Oracle Exception',
--                                    'EXCEPTION' VALUE t_sqlerrm));
--    END;
END;
/
