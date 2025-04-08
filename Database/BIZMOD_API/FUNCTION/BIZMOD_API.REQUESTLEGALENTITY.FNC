CREATE OR REPLACE FUNCTION BIZMOD_API.requestlegalentity(
    a_packet       IN CLOB,
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
    --  1.4.0  11/05/2024  TJL  BIZ-16705  Corrected bug of not finding entity
    --                                      when entity Hierarchy Level is level one.
    --                                     Corrected code to only bring back person one
    --                                      time when multiple of same person is found.
    --  1.4.1  11/14/2024  TJL  BIZ-16706  Change code for OWNERTYPE and TITLETYPE
    --  1.4.2  11/19/2024  TJL  BIZ-16706  Adding remarks to code
    --  1.4.3  12/02/2024  TJL  BIZ-16842  Removed Referenceid and objectid. Added
    --                                      LegalEntityObjectId
    --  1.5.0  12/18/2024  TJL  BIZ-16968  Change TITLETYPE from string to JSON array
    --  1.5.1  01/28/2025  TJL  BIZ-       Change how to determine if stockholder or
    --                                      officer for companies
    -- ****************************************************************************

    TYPE lecompany_type IS TABLE OF VARCHAR2(100);

    -- *********************************************************
    --  Get Title
    --
    --  This function creats a json array with Legal Entity title(s) information.
    --      a_legalentityobjectid - Legal Entity Object id that the person object is
    --                               pointed to.
    -- *********************************************************
    FUNCTION get_title(a_legalentityobjectid IN api.pkg_definition.udt_id)
        RETURN json_array_t
    AS
        t_array        json_array_t := json_array_t();
    BEGIN
        FOR rec
            IN (SELECT r.toobjectid objectid, r.relationshipid
                  FROM api.relationships r
                 WHERE r.endpointid =
                       api.pkg_configquery.endpointidforname(
                           api.pkg_columnquery.VALUE(a_legalentityobjectid,
                                                     'ObjectDefName'),
                           'Title')
                   AND r.fromobjectid = a_legalentityobjectid)
        LOOP
            t_array.append(
                api.pkg_columnquery.VALUE(rec.objectid, 'Description'));
        END LOOP;

        RETURN t_array;
    END;

    -- *********************************************************
    --  Get Person
    --
    --  This function creats a json object with person object information.
    --      a_legalentityobjectid - Legal Entity Object id that the person object is
    --                               pointed to.
    --      a_personobjectid      - Person Object id to retrieve data from.
    --      a_officer_stockholder - Indicator whether or not to return ownertype,
    --                               Percentage Of Ownership, title for this person.
    -- *********************************************************
    FUNCTION get_person(a_legalentityobjectid IN api.pkg_definition.udt_id,
                        a_personobjectid IN api.pkg_definition.udt_id,
                        a_officer_stockholder IN VARCHAR2)
        RETURN json_object_t
    AS
        t_entity       json_object_t := json_object_t();
    BEGIN
        -- In JSON, return Legal Entity
        t_entity.put('LEGALENTITYOBJECTID', a_legalentityobjectid);

        -- Get Person information for JSON using ABIS API's
        t_entity.put(
            'FIRSTNAME',
            api.pkg_columnquery.VALUE(a_personobjectid, 'FirstName'));
        t_entity.put(
            'MIDDLENAME',
            api.pkg_columnquery.VALUE(a_personobjectid, 'MiddleName'));
        t_entity.put('LASTNAME',
                     api.pkg_columnquery.VALUE(a_personobjectid, 'LastName'));

        -- Get Owner Type,
        CASE
            WHEN a_officer_stockholder IS NOT NULL
            THEN
                t_entity.put(
                    'OWNERTYPE',
                    api.pkg_columnquery.VALUE(a_legalentityobjectid,
                                              'OwnerType'));
                t_entity.put(
                    'PERCENTAGEOFOWNERSHIP',
                    api.pkg_columnquery.VALUE(a_legalentityobjectid,
                                              'PercentageOfOwnership'));

                -- Get title type only if Percentage Of Ownerhip is null
                --  Title is only returned if Officer, Percentage Of Ownership
                --  indicates Stock Holder
                IF (api.pkg_columnquery.VALUE(a_legalentityobjectid,
                                              'PercentageOfOwnership')
                        IS NULL)
                THEN
                    t_entity.put('TITLETYPE',
                                 get_title(a_legalentityobjectid));
                END IF;
            ELSE
                NULL;
        END CASE;

        RETURN t_entity;
    END get_person;


    -- *********************************************************
    --  Get Company
    --
    --  This function creats a json object with company object information.
    --      a_legalentityobjectid - Legal Entity Object id for a company
    --      a_level               - Indicates what level in the Hierarchy being
    --                                returned in the JSON
    -- *********************************************************
    FUNCTION get_company(a_legalentityobjectid IN api.pkg_definition.udt_id,
                         a_level        IN NUMBER)
        RETURN json_object_t
    AS
        t_objectid     NUMBER;
        t_company      json_object_t;
--        t_info         json_object_t;
        t_company_arry json_array_t := json_array_t();
        t_person_arry  json_array_t := json_array_t();
--        t_officer_stockholder VARCHAR2(20);
        t_titles       VARCHAR2(32000);
        t_feeobjidlst  api.udt_objectlist := api.udt_objectlist();
    BEGIN
        -- get company relationship
        SELECT r.toobjectid
          INTO t_objectid
          FROM api.relationships r
         WHERE r.endpointid =
               api.pkg_configquery.endpointidforname('o_LegalEntity',
                                                     'Company')
           AND r.fromobjectid = a_legalentityobjectid;

        -- get any titles associated to this legal entity
        SELECT LISTAGG(
                   api.pkg_columnquery.VALUE(let.titleobjectid,
                                             'Description'),
                   ', ')
               WITHIN GROUP (ORDER BY
                                 api.pkg_columnquery.VALUE(let.titleobjectid,
                                                           'Description'))
          INTO t_titles
          FROM query.r_legalentitytitle let
         WHERE let.legalentityobjectid = a_legalentityobjectid;

        -- initialize JSON object
        t_company := json_object_t();

        -- figure out if this legal entity is a P12(A)
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

        t_company.put('LEGALENTITYOBJECTID', a_legalentityobjectid);

        -- if P12(A) get master license number and base file office
        CASE
            WHEN api.pkg_columnquery.VALUE(a_legalentityobjectid,
                                           'P12Status') =
                 'Y'
              OR api.pkg_columnquery.VALUE(a_legalentityobjectid,
                                           'P12AStatus') =
                 'Y'
            THEN
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
                NULL;
        END CASE;

        -- Get company information for JSON using ABIS API's
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

        -- get information for selected fields if stock holder or officer.
        --   All JSON tags are created even if data is not selected for tag.
        IF (api.pkg_columnquery.VALUE(a_legalentityobjectid,
                                      'PercentageOfOwnership')
                IS NULL)
        THEN
                t_company.put('TITLETYPE', get_title(a_legalentityobjectid));
        else
                t_company.put(
                    'OWNERTYPE',
                    api.pkg_columnquery.VALUE(a_legalentityobjectid,
                                              'OwnerType'));
                t_company.put(
                    'PERCENTAGEOFOWNERSHIP',
                    api.pkg_columnquery.VALUE(a_legalentityobjectid,
                                              'PercentageOfOwnership'));
        END if;

        -- if this company is level one in hierarchy get second level of
        --  hierarchy data.
        IF a_level = 1
        THEN
            -- get childern for this company using ABIS procedure. It returns
            --  a collection of child legal entities
            sitespecific.pkg_legalentity.getlegalentitychildren(
                a_objectid  => a_legalentityobjectid,
                a_relatedobjectids => t_feeobjidlst);

            -- loop thru the collection of legal entities returned.
            FOR rec
                IN (WITH
                        le
                        AS
                            (SELECT objectid,
                                    api.pkg_columnquery.numericvalue(
                                        objectid,
                                        'HierarchyLevel')     hierarchylevel,
                                    api.pkg_columnquery.VALUE(
                                        objectid,
                                        'LegalEntityType')    legalentitytype
                               FROM TABLE(
                                        CAST(
                                            t_feeobjidlst
                                                AS api.udt_objectlist)))
                      SELECT le.*
                        FROM le
                       -- only process first level of the childern legal entities
                       WHERE le.hierarchylevel =
                             (  api.pkg_columnquery.numericvalue(
                                    a_legalentityobjectid,
                                    'HierarchyLevel')
                              + 1)
                    ORDER BY le.legalentitytype)
            LOOP
                CASE rec.legalentitytype
                    WHEN 'Company'
                    THEN
                        -- Do recursive call but indicate second level
                        t_company_arry.append(
                            get_company(
                                a_legalentityobjectid => rec.objectid,
                                a_level     => 2));
                    WHEN 'Person'
                    THEN
                        -- get the person object ids
                        FOR p
                            IN (SELECT r.toobjectid, r.fromobjectid
                                  FROM api.relationships r
                                 WHERE r.fromobjectid = rec.objectid
                                   AND r.endpointid =
                                       api.pkg_configquery.endpointidforname(
                                           'o_LegalEntity',
                                           'Person'))
                        LOOP
                            -- call the person function to get person data and
                            --   officer or stock holder information
                            t_person_arry.append(
                                get_person(
                                    a_legalentityobjectid => p.fromobjectid,
                                    a_personobjectid => p.toobjectid,
                                    a_officer_stockholder =>
                                        'OfficerStockholder'));
                        END LOOP;
                    ELSE
                        NULL;
                END CASE;
            END LOOP;

            -- add any childern companies to parent JSON
            IF (t_company_arry.get_size() > 0)
            THEN
                t_company.put('COMPANY', t_company_arry);
            END IF;

            -- add any childern persons to parent JSON
            IF (t_person_arry.get_size() > 0)
            THEN
                t_company.put('PERSON', t_person_arry);
            END IF;
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
        t_json         json_object_t := json_object_t();
        t_jobid        api.pkg_definition.udt_id;
        t_feeobjidlst  api.udt_objectlist;
        t_objects      lecompany_type := lecompany_type();
        t_sqlerrm      VARCHAR2(4000);
        t_trace        VARCHAR2(4000);
    BEGIN
        -- get license number and search values from request packet
        t_licensenumber := json_value(a_packet, '$.*.LICENSENUMBER');
        t_search := UPPER(json_value(a_packet, '$.*.SEARCH'));

        -- find job id for license number
        t_jobid :=
            api.pkg_simplesearch.objectbyindex(
                a_objectdefname => 'j_License',
                a_columnname => 'ExternalFileNum',
                a_lowvalue  => t_licensenumber);

        -- make sure license number was found
        IF (t_jobid IS NOT NULL)
        THEN
            -- get all legal entities for license found
            sitespecific.pkg_legalentity.legalentityhierarchy(
                a_objectid  => t_jobid,
                a_endpointid => NULL,
                a_relatedobjectids => t_feeobjidlst);

            -- start looping thru legal entities found
            FOR rec
                IN (WITH
                        le
                        AS
                            -- get information from the legal entity
                            (SELECT objectid,
                                    api.pkg_columnquery.numericvalue(
                                        objectid,
                                        'HierarchyLevel')     hierarchylevel,
                                    -- get value to search on when search is being used
                                    api.pkg_columnquery.VALUE(
                                        objectid,
                                        CASE api.pkg_columnquery.VALUE(
                                                 objectid,
                                                 'IsCompany')
                                            WHEN 'Y'
                                            THEN
                                                'CompanyName'
                                            ELSE
                                                'FormattedPersonNameSearch'
                                        END)                  name,
                                    api.pkg_columnquery.VALUE(
                                        objectid,
                                        'LegalEntityType')    legalentitytype
                               FROM TABLE(
                                        CAST(
                                            t_feeobjidlst
                                                AS api.udt_objectlist)))
                    SELECT le.*
                      FROM le
                     -- if search is not used only select top level hierarchy else
                     --  select all entities matching the search value
                     WHERE le.hierarchylevel =
                           CASE
                               WHEN t_search IS NULL THEN 1
                               ELSE le.hierarchylevel
                           END
                       AND le.name LIKE '%' || t_search || '%')
            LOOP
                CASE rec.legalentitytype
                    WHEN 'Person'
                    THEN
                        FOR p
                            IN (SELECT r.toobjectid, r.fromobjectid
                                  FROM api.relationships r
                                 WHERE r.fromobjectid = rec.objectid
                                   AND r.endpointid =
                                       api.pkg_configquery.endpointidforname(
                                           'o_LegalEntity',
                                           'Person'))
                        LOOP
                            -- at top level only return person one time even thou they
                            --  can have multiple legal entities on this license
                            IF NOT lecompany_type(p.toobjectid)
                                        SUBMULTISET t_objects
                            THEN
                                -- add to collection to indicate it has been processed
                                t_objects.EXTEND(1);
                                t_objects(t_objects.COUNT) := p.toobjectid;

                                -- get the person data and append to JSON.
                                t_person_arry.append(
                                    get_person(
                                        a_legalentityobjectid =>
                                            p.fromobjectid,
                                        a_personobjectid => p.toobjectid,
                                        a_officer_stockholder => NULL));
                            END IF;
                        END LOOP;
                    WHEN 'Company'
                    THEN
                        -- get compan data and indicate first level.
                        t_company_arry.append(
                            get_company(
                                a_legalentityobjectid => rec.objectid,
                                a_level     => 1));
                    ELSE
                        NULL;
                END CASE;
            END LOOP;

            -- add any companies processed to the JSON being returned
            IF (t_company_arry.get_size() > 0)
            THEN
                t_data.put('COMPANY', t_company_arry);
            END IF;

            -- add any persons processed to the JSON being returned
            IF (t_person_arry.get_size() > 0)
            THEN
                t_data.put('PERSON', t_person_arry);
            END IF;

            -- build the return JSON PACKET
            t_json.put('PACKET_TYPE', 'LEGALENTITIES');
            t_json.put('DATA', t_data);
        ELSE
            -- return JSON message of file not found
            t_json :=
                json_object_t(
                    '{"PACKET_TYPE":"MESSAGE","DATA":{"MSGNO":"1","MSG":"License Number '
                    || t_licensenumber
                    || ' Not Found"}}');
        END IF;

        utl_licenseinfo.clean(a_json => t_json);

        -- return json as a clob
        RETURN t_json.TO_CLOB;
    EXCEPTION
        WHEN OTHERS
        THEN
            t_sqlerrm := SQLERRM;
            t_trace := DBMS_UTILITY.format_error_backtrace;
            t_msg := SUBSTR(t_sqlerrm || CHR(13) || t_trace, 1, 3990);

            -- log exceptions thrown in processing legal entities
            UPDATE bizmod_api.eservices_log_t
               SET err = t_msg
             WHERE seq = a_seq;

            COMMIT;

            -- return JSON message for oracle exception
            RETURN json_object(
                       'PACKET_TYPE' VALUE 'MESSAGE',
                       'DATA' VALUE
                           json_object('MSGNO' VALUE 5,
                                       'MSG' VALUE 'Oracle Exception',
                                       'EXCEPTION' VALUE t_msg));
    END;
END;
/
