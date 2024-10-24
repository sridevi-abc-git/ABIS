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
    --  1.3.0  08/22/2024  TJL  BIZ-16242  Inital function created
    --  1.3.0  10/23/2024  TJL  BIZ-16519  Change JSON format and walking thru HIERARCHY
    --  1.3.1  10/24/2024  TJL  BIZ-16519  Made second change to JSON format
    -- ****************************************************************************

    TYPE legalentity_type IS TABLE OF NUMBER;

    -- *********************************************************
    --  Get Person
    -- *********************************************************
    FUNCTION get_person(a_legalentityobjectid IN api.pkg_definition.udt_id,
                        a_personobjectid IN api.pkg_definition.udt_id)
        RETURN json_object_t
    AS
        t_entity       json_object_t := json_object_t();
    BEGIN
        t_entity.put('REFERENCEID', a_legalentityobjectid);
        t_entity.put('OBJECTID', a_personobjectid);
        t_entity.put(
            'FIRSTNAME',
            api.pkg_columnquery.VALUE(a_personobjectid, 'FirstName'));
        t_entity.put(
            'MIDDLENAME',
            api.pkg_columnquery.VALUE(a_personobjectid, 'MiddleName'));
        t_entity.put('LASTNAME',
                     api.pkg_columnquery.VALUE(a_personobjectid, 'LastName'));

        t_entity.put(
            'OWNERTYPE',
            api.pkg_columnquery.VALUE(a_legalentityobjectid, 'OwnerType'));
        t_entity.put(
            'TITLETYPE',
            api.pkg_columnquery.VALUE(a_legalentityobjectid, 'TitleType'));

        t_entity.put(
            'PERCENTAGEOFOWNERSHIP',
            api.pkg_columnquery.VALUE(a_legalentityobjectid,
                                      'PrcentageOfOwnership'));
        RETURN t_entity;
    END get_person;


    -- *********************************************************
    --  Get Company
    -- *********************************************************
    FUNCTION get_company(a_legalentityobjectid IN api.pkg_definition.udt_id)
        RETURN json_object_t
    AS
        t_objectid     NUMBER;
        t_company      json_object_t;
        t_company_arry json_array_t := json_array_t();
        t_person_arry  json_array_t := json_array_t();
    BEGIN
        -- get company relationship
        SELECT r.toobjectid
          INTO t_objectid
          FROM api.relationships r
         WHERE r.endpointid =
               api.pkg_configquery.endpointidforname('o_LegalEntity',
                                                     'Company')
           AND r.fromobjectid = a_legalentityobjectid;

        t_company := json_object_t();

        t_company.put(
            'P12TYPE',
            CASE
                WHEN api.pkg_columnquery.VALUE(a_legalentityobjectid,
                                               'P12Status') =
                     'Y'
                THEN
                    'P12'
                WHEN api.pkg_columnquery.VALUE(a_legalentityobjectid,
                                               'P12AStatus') =
                     'Y'
                THEN
                    'P12A'
                ELSE
                    NULL
            END);

        t_company.put('REFERENCEID', a_legalentityobjectid);

        CASE
            WHEN api.pkg_columnquery.VALUE(a_legalentityobjectid,
                                           'P12Status') =
                 'Y'
              OR api.pkg_columnquery.VALUE(a_legalentityobjectid,
                                           'P12AStatus') =
                 'Y'
            THEN
                t_company.put('OBJECTID', a_legalentityobjectid);
                t_company.put(
                    'MASTERLICENSE',
                    api.pkg_columnquery.VALUE(
                        a_legalentityobjectid,
                        CASE api.pkg_columnquery.VALUE(a_legalentityobjectid,
                                                       'P12Status')
                            WHEN 'Y'
                            THEN
                                'P12MasterLicenseNo'
                            ELSE
                                'P12AMasterLicenseNo'
                        END));
                t_company.put(
                    'BASEFILEOFFICE',
                    api.pkg_columnquery.VALUE(
                        api.pkg_columnquery.numericvalue(
                            a_legalentityobjectid,
                            'LicenseJobId'),
                        'BaseFileOfficeCodeDescription'));
            ELSE
                t_company.put('OBJECTID', t_objectid);
        END CASE;

        t_company.put('COMPANYNAME',
                      api.pkg_columnquery.VALUE(t_objectid, 'CompanyName'));
        t_company.put(
            'COMPANYSTRUCTURE',
            api.pkg_columnquery.VALUE(t_objectid, 'CompanyStructure'));
        t_company.put(
            'DATEOFINCORPORATION',
            api.pkg_columnquery.datevalue(t_objectid, 'DateOfIncorporation'));
        t_company.put(
            'STATEOFINCORPORATION',
            api.pkg_columnquery.VALUE(t_objectid, 'StateOfIncorporation'));
        t_company.put(
            'CASECRETARYOFSTATENUMBER',
            api.pkg_columnquery.VALUE(t_objectid, 'CASecretaryOfStateNumber'));
        t_company.put(
            'FEDERALEMPLOYERIDENTIFICATIONN',
            api.pkg_columnquery.VALUE(t_objectid,
                                      'FederalEmployerIdentificationn'));

        t_company.put(
            'OWNERTYPE',
            api.pkg_columnquery.VALUE(a_legalentityobjectid, 'OwnerType'));
        t_company.put(
            'TITLETYPE',
            api.pkg_columnquery.VALUE(a_legalentityobjectid, 'TitleType'));

        t_company.put(
            'PERCENTAGEOFOWNERSHIP',
            api.pkg_columnquery.VALUE(a_legalentityobjectid,
                                      'PercentageOfOwnership'));

        FOR rec
            IN (  SELECT DISTINCT r.toobjectid, r.fromobjectid
                    FROM api.relationships r
                   WHERE r.fromobjectid = a_legalentityobjectid
                     AND r.endpointid IN
                             (api.pkg_configquery.endpointidforname(
                                  'o_LegalEntity',
                                  'Node'),
                              api.pkg_configquery.endpointidforname(
                                  'o_LegalEntity',
                                  'Officer'),
                              api.pkg_configquery.endpointidforname(
                                  'o_LegalEntity',
                                  'Stockholder'),
                              api.pkg_configquery.endpointidforname(
                                  'o_LegalEntity',
                                  'OfficerStockholder'),
                              api.pkg_configquery.endpointidforname(
                                  'o_LegalEntity',
                                  'P12AStockholder'),
                              api.pkg_configquery.endpointidforname(
                                  'o_LegalEntity',
                                  'P12ADescendant'))
                     AND r.toobjectid != r.fromobjectid
                ORDER BY api.pkg_columnquery.VALUE(r.toobjectid,
                                                   'LegalEntityType'))
        LOOP
            CASE api.pkg_columnquery.VALUE(rec.toobjectid, 'LegalEntityType')
                WHEN 'Company'
                THEN
                    t_company_arry.append(
                        get_company(a_legalentityobjectid => rec.toobjectid));
                WHEN 'Person'
                THEN
                    FOR p
                        IN (SELECT r.toobjectid, r.fromobjectid
                              FROM api.relationships r
                             WHERE r.fromobjectid = rec.toobjectid
                               AND r.endpointid =
                                   api.pkg_configquery.endpointidforname(
                                       'o_LegalEntity',
                                       'Person'))
                    LOOP
                        t_person_arry.append(
                            get_person(
                                a_legalentityobjectid => p.fromobjectid,
                                a_personobjectid => p.toobjectid));
                    END LOOP;
                ELSE
                    NULL;
            END CASE;
        END LOOP;

        IF (t_company_arry.get_size() > 0)
        THEN
            t_company.put('COMPANY', t_company_arry);
        END IF;

        IF (t_person_arry.get_size() > 0)
        THEN
            t_company.put('PERSON', t_person_arry);
        END IF;

        RETURN t_company;
    END get_company;
-- *********************************************************
--
-- *********************************************************
-- *********************************************************
--  Main Function Process
-- *********************************************************
BEGIN
    DECLARE
        t_licensenumber VARCHAR2(40);
        t_search       VARCHAR2(200);
        t_msg          VARCHAR2(4000);
        t_data         json_object_t := json_object_t();
        t_person_arry  json_array_t := json_array_t();
        t_company_arry json_array_t := json_array_t();
        t_person       json_object_t := json_object_t();
        t_company      json_object_t := json_object_t();
        t_value        json_object_t := json_object_t();
        t_json         json_object_t := json_object_t();
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
               AND api.pkg_columnquery.VALUE(r.toobjectid, 'ObjectDefName') =
                   'o_LegalEntity';

            FOR rec
                IN (WITH
                        le
                        AS
                            (SELECT r.toobjectid
                                        lg,
                                    api.pkg_columnquery.VALUE(
                                        r.toobjectid,
                                        'LegalEntityType')
                                        legalentitytype,
                                    api.pkg_columnquery.numericvalue(
                                        r.toobjectid,
                                        'HierarchyLevel')
                                        hierarchylevel
                               FROM api.relationships r
                              WHERE r.fromobjectid IN
                                        (SELECT o.objectid
                                           FROM TABLE(t_feeobjidlst) o)
                                AND r.endpointid IN
                                        (api.pkg_configquery.endpointidforname(
                                             'o_LegalEntity',
                                             'Node'),
                                         api.pkg_configquery.endpointidforname(
                                             'o_LegalEntity',
                                             'Officer'),
                                         api.pkg_configquery.endpointidforname(
                                             'o_LegalEntity',
                                             'Stockholder'),
                                         api.pkg_configquery.endpointidforname(
                                             'o_LegalEntity',
                                             'OfficerStockholder'),
                                         api.pkg_configquery.endpointidforname(
                                             'o_LegalEntity',
                                             'P12AStockholder'),
                                         api.pkg_configquery.endpointidforname(
                                             'o_LegalEntity',
                                             'P12ADescendant'))
                                AND 1 =
                                    CASE
                                        WHEN t_search IS NULL
                                        THEN
                                            1
                                        WHEN r.toobjectid != r.fromobjectid
                                        THEN
                                            1
                                        ELSE
                                            0
                                    END
                                AND api.pkg_columnquery.VALUE(
                                        r.toobjectid,
                                        CASE api.pkg_columnquery.VALUE(
                                                 r.toobjectid,
                                                 'LegalEntityType')
                                            WHEN 'Company'
                                            THEN
                                                'CompanyName'
                                            ELSE
                                                'FormattedPersonNameSearch'
                                        END) LIKE
                                        '%' || t_search || '%')
                    SELECT *
                      FROM le
                     WHERE le.hierarchylevel =
                           CASE WHEN t_search IS NULL THEN 1
                                ELSE le.hierarchylevel END)
            LOOP
                CASE rec.legalentitytype
                    WHEN 'Person'
                    THEN
                        FOR p
                            IN (SELECT r.toobjectid, r.fromobjectid
                                  FROM api.relationships r
                                 WHERE r.fromobjectid = rec.lg
                                   AND r.endpointid =
                                       api.pkg_configquery.endpointidforname(
                                           'o_LegalEntity',
                                           'Person'))
                        LOOP
                            t_person_arry.append(
                                get_person(
                                    a_legalentityobjectid => p.fromobjectid,
                                    a_personobjectid => p.toobjectid));
                        END LOOP;
                    WHEN 'Company'
                    THEN
                        t_value :=
                            get_company(a_legalentityobjectid => rec.lg);

                        IF (t_value IS NOT NULL)
                        THEN
                            t_company_arry.append(t_value);
                        END IF;
                    ELSE
                        NULL;
                END CASE;
            END LOOP;


            IF (t_company_arry.get_size() > 0)
            THEN
                t_data.put('COMPANY', t_company_arry);
--                t_array.append(t_company);
            END IF;

            IF (t_person_arry.get_size() > 0)
            THEN
                t_data.put('PERSON', t_person_arry);
--                t_array.append(t_person);
            END IF;

            t_json.put('PACKET_TYPE', 'LEGALENTITIES');
            t_json.put('DATA', t_data);
        ELSE
            t_json :=
                json_object_t(
                    '{"PACKET_TYPE":"MESSAGE","DATA":{"MSGNO":"1","MSG":"License Number '
                    || t_licensenumber
                    || ' Not Found"}}');
        END IF;

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

            RETURN json_object(
                       'PACKET_TYPE' VALUE 'MESSAGE',
                       'DATA' VALUE
                           json_object('MSGNO' VALUE 5,
                                       'MSG' VALUE 'Oracle Exception',
                                       'EXCEPTION' VALUE t_msg));
    END;
END;
/
