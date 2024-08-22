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
    --          08/22/2024  TJL  BIZ-16040  Inital function created
    -- ****************************************************************************
    TYPE legalentity_type IS TABLE OF NUMBER;

    t_legalentity  legalentity_type := legalentity_type();


    FUNCTION get_address(a_objectid IN NUMBER, a_endpoint IN NUMBER)
        RETURN json_object_t
    AS
        t_json         json_object_t := json_object_t();
        t_objectid     NUMBER;
    BEGIN
        SELECT r.toobjectid
          INTO t_objectid
          FROM api.relationships r
         WHERE r.endpointid = a_endpoint
           AND r.fromobjectid = a_objectid;

        t_json.put('ADDRESSLOCATION',
                   api.pkg_columnquery.VALUE(t_objectid, 'ADDRESSLOCATION'));
        t_json.put('ADDRESSLINE1',
                   api.pkg_columnquery.VALUE(t_objectid, 'ADDRESSLINE1'));
        t_json.put('ADDRESSLINE2',
                   api.pkg_columnquery.VALUE(t_objectid, 'ADDRESSLINE2'));
        t_json.put('USACITY',
                   api.pkg_columnquery.VALUE(t_objectid, 'USACITY'));
        t_json.put('USASTATE',
                   api.pkg_columnquery.VALUE(t_objectid, 'USASTATE'));
        t_json.put('ZIPCODE',
                   api.pkg_columnquery.VALUE(t_objectid, 'ZIPCODE'));

        IF (a_endpoint =
            api.pkg_configquery.endpointidforname('j_Application',
                                                  'Premises'))
        THEN
            t_json.put('PHONENUMBER',
                       api.pkg_columnquery.VALUE(t_objectid, 'PHONENUMBER'));
            --    "PHONENUMBER": "(###)###-####",
            t_json.put('FAXNUMBER',
                       api.pkg_columnquery.VALUE(t_objectid, 'FAXNUMBER'));
            t_json.put(
                'INTERNATIONALPHONENUMBER',
                api.pkg_columnquery.VALUE(t_objectid,
                                          'INTERNATIONALPHONENUMBER'));
            t_json.put('CENSUSTRACT',
                       api.pkg_columnquery.VALUE(t_objectid, 'CENSUSTRACT'));
            t_json.put(
                'CENSUSTRACTSOURCE',
                api.pkg_columnquery.VALUE(t_objectid, 'CENSUSTRACTSOURCE'));
            t_json.put(
                'GEOCODEADDRESSLINE1',
                api.pkg_columnquery.VALUE(t_objectid, 'GEOCODEADDRESSLINE1'));
            t_json.put(
                'OUTSIDECITYLIMITS',
                api.pkg_columnquery.VALUE(t_objectid, 'OUTSIDECITYLIMITS'));
            t_json.put('HIGHCRIME',
                       api.pkg_columnquery.VALUE(t_objectid, 'HIGHCRIME'));
            t_json.put(
                'CARDROOMCASINO',
                api.pkg_columnquery.VALUE(t_objectid, 'CARDROOMCASINO'));
            t_json.put('NOEVENT',
                       api.pkg_columnquery.VALUE(t_objectid, 'NOEVENT'));
            t_json.put(
                'ELIGIBLEFORTRANSFER',
                api.pkg_columnquery.VALUE(t_objectid, 'ELIGIBLEFORTRANSFER'));
        END IF;

        RETURN t_json;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            RETURN NULL;
    END;


    FUNCTION get_person(a_legalentityobjectid IN NUMBER)
        RETURN json_object_t
    AS
        t_objectid     NUMBER;
        t_entity       json_object_t := json_object_t();
    BEGIN
        -- get person relationship
        SELECT r.toobjectid
          INTO t_objectid
          FROM api.relationships r
         WHERE r.endpointid =
               api.pkg_configquery.endpointidforname('o_LegalEntity',
                                                     'Person')
           AND r.fromobjectid = a_legalentityobjectid;

        --        t_entity.put('OWNERTYPE',
        --                     api.pkg_columnquery.VALUE(t_objectid, 'OwnerType'));
        --               api.pkg_columnquery.VALUE(t_value, 'LEStructureRel'));
        t_entity.put('FIRSTNAME',
                     api.pkg_columnquery.VALUE(t_objectid, 'FirstName'));
        t_entity.put('MIDDLENAME',
                     api.pkg_columnquery.VALUE(t_objectid, 'MiddleName'));
        t_entity.put('LASTNAME',
                     api.pkg_columnquery.VALUE(t_objectid, 'LastName'));
        t_entity.put('SUFFIX',
                     api.pkg_columnquery.VALUE(t_objectid, 'Suffix'));
        t_entity.put('ALIASNAMES',
                     api.pkg_columnquery.VALUE(t_objectid, 'AliasNames'));
        t_entity.put(
            'SOCIALSECURITYNUMBER',
            api.pkg_columnquery.VALUE(t_objectid, 'SocialSecurityNumber'));
        t_entity.put(
            'DRIVERSLICENSENUMBER',
            api.pkg_columnquery.VALUE(t_objectid, 'DriversLicenseNumber'));
        t_entity.put(
            'DRIVERSLICENSESTATE',
            api.pkg_columnquery.VALUE(t_objectid, 'DriversLicenseState'));
        t_entity.put('PASSPORTNUMBER',
                     api.pkg_columnquery.VALUE(t_objectid, 'PassportNumber'));
        t_entity.put('GENDER',
                     api.pkg_columnquery.VALUE(t_objectid, 'Gender'));
        t_entity.put('BIRTHDATE',
                     api.pkg_columnquery.VALUE(t_objectid, 'BirthDate'));
        t_entity.put('BIRTHCITY',
                     api.pkg_columnquery.VALUE(t_objectid, 'BirthCity'));
        t_entity.put('BIRTHSTATE',
                     api.pkg_columnquery.VALUE(t_objectid, 'BirthState'));
        t_entity.put('BIRTHCOUNTRY',
                     api.pkg_columnquery.VALUE(t_objectid, 'BirthCountry'));
        t_entity.put('MARITALSTATUS',
                     api.pkg_columnquery.VALUE(t_objectid, 'MaritalStatus'));
        t_entity.put(
            'FEDERALEMPLOYERIDENTIFICATIONN',
            api.pkg_columnquery.VALUE(t_objectid,
                                      'FederalEmployerIdentificationn'));

        t_entity.put(
            'PERCENTAGEOFOWNERSHIP',
            api.pkg_columnquery.VALUE(t_objectid, 'PercentageOfOwnership'));
        t_entity.put(
            'ADDRESS',
            get_address(
                a_objectid  => t_objectid,
                a_endpoint  =>
                    api.pkg_configquery.endpointidforname(
                        api.pkg_columnquery.VALUE(t_objectid,
                                                  'ObjectDefName'),
                        'Address')));

        RETURN t_entity;
    END;

    FUNCTION get_company(a_legalentityobjectid IN NUMBER)
        RETURN json_object_t
    AS
        t_objectid     NUMBER;
        t_entity       json_object_t := json_object_t();
    BEGIN
        -- get company relationship
        SELECT r.toobjectid
          INTO t_objectid
          FROM api.relationships r
         WHERE r.endpointid =
               api.pkg_configquery.endpointidforname('o_LegalEntity',
                                                     'Company')
           AND r.fromobjectid = a_legalentityobjectid;

        t_entity.put('COMPANYNAME',
                     api.pkg_columnquery.VALUE(t_objectid, 'CompanyName'));
        t_entity.put(
            'COMPANYSTRUCTURE',
            api.pkg_columnquery.VALUE(t_objectid, 'CompanyStructure'));
        t_entity.put(
            'DATEOFINCORPORATION',
            api.pkg_columnquery.VALUE(t_objectid, 'DateOfIncorporation'));
        t_entity.put(
            'STATEOFINCORPORATION',
            api.pkg_columnquery.VALUE(t_objectid, 'StateOfIncorporation'));
        t_entity.put(
            'CASECRETARYOFSTATENUMBER',
            api.pkg_columnquery.VALUE(t_objectid, 'CASecretaryOfStateNumber'));
        t_entity.put(
            'FEDERALEMPLOYERIDENTIFICATIONN',
            api.pkg_columnquery.VALUE(t_objectid,
                                      'FederalEmployerIdentificationn'));

        t_entity.put(
            'ADDRESS',
            get_address(
                a_objectid  => t_objectid,
                a_endpoint  =>
                    api.pkg_configquery.endpointidforname(
                        api.pkg_columnquery.VALUE(t_objectid,
                                                  'ObjectDefName'),
                        'Address')));

        RETURN t_entity;
    END;

    FUNCTION get_titles(a_legalentityobjectid IN NUMBER)
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


    PROCEDURE get_legalentity(a_json IN json_object_t, a_list IN VARCHAR2)
    AS
        t_value        NUMBER;
        t_next         VARCHAR2(1000);
        t_pos          NUMBER;

        t_array        json_array_t;
        t_json         json_object_t;
        t_tmp          json_object_t;
        t_entity       json_object_t := json_object_t();

        t_return       json_object_t := json_object_t();
    BEGIN
        t_value :=
            TO_NUMBER(REGEXP_SUBSTR(a_list,
                                    '[^/]+',
                                    1,
                                    1));
        t_array := a_json.get_array('DATA');

        -- get next level down
        t_pos :=
            INSTR(a_list,
                  '/',
                  1,
                  2);

        IF (t_pos > 0)
        THEN
            t_next := SUBSTR(a_list, t_pos);
        END IF;

        IF legalentity_type(t_value) SUBMULTISET t_legalentity
        THEN
            -- find object
            FOR inx IN 0 .. t_array.get_size() - 1
            LOOP
                t_tmp := TREAT(t_array.get(inx) AS json_object_t);

                IF t_tmp IS NOT NULL
                THEN
                    IF (t_tmp.get_number('OBJECTID') = t_value)
                    THEN
                        t_json := t_tmp;
                        t_array := t_json.get_array('LEGALENTITIES');

                        IF t_array IS NULL
                        THEN
                            t_json.put('LEGALENTITIES', json_array_t);
                        END IF;

                        EXIT;
                    END IF;
                END IF;
            END LOOP;
        END IF;

        IF t_json IS NULL
        THEN
            t_legalentity.EXTEND(1);
            t_legalentity(t_legalentity.COUNT) := t_value;

            t_entity.put('OBJECTID', t_value);
            t_entity.put(
                'LESTRUCTUREREL',
                api.pkg_columnquery.VALUE(t_value, 'LeStructureRel'));
            t_entity.put(
                'HIERARCHYLEVEL',
                api.pkg_columnquery.VALUE(t_value, 'HierarchyLevel'));
            t_entity.put(
                'LEGALENTITYTYPE',
                api.pkg_columnquery.VALUE(t_value, 'LegalEntityType'));
            t_entity.put(
                'P12TYPE',
                CASE SUBSTR(
                         api.pkg_columnquery.VALUE(t_value, 'LEStructureRel'),
                         1,
                         3)
                    WHEN 'P12'
                    THEN
                        'P12'
                    WHEN 'P12A'
                    THEN
                        'P12A'
                    ELSE
                        NULL
                END);

            t_entity.put('OWNERTYPE',
                         api.pkg_columnquery.VALUE(t_value, 'OwnerType'));
            t_entity.put('TITLE',
                         get_titles(a_legalentityobjectid => t_value));
            t_entity.put(
                'PERCENTAGEOFOWNERSHIP',
                api.pkg_columnquery.VALUE(t_value, 'PercentageOfOwnership'));

            CASE api.pkg_columnquery.VALUE(t_value, 'LegalEntityType')
                WHEN 'Person'
                THEN
                    t_entity.put(
                        'PERSON',
                        get_person(a_legalentityobjectid => t_value));
                WHEN 'Company'
                THEN
                    t_entity.put(
                        'COMPANY',
                        get_company(a_legalentityobjectid => t_value));
                ELSE
                    NULL;
            END CASE;

            t_array.append(t_entity);

            t_json := json_object_t();
            t_json.put('LEGALENTITIES', t_array);
        END IF;

        IF (t_pos > 0)
        THEN
            get_legalentity(a_json => t_json, a_list => t_next);
        END IF;
    END;
    
-- ******************************************************
--  Main Process
-- ******************************************************
BEGIN
    DECLARE
        t_licensenumber VARCHAR2(40);
        t_msg          VARCHAR2(4000);
        t_msgno        NUMBER;
        t_array        json_array_t := json_array_t();
        t_json         json_object_t := json_object_t();
        t_jobid        api.pkg_definition.udt_id;
    BEGIN
        t_licensenumber := json_value(a_packet, '$.*.LICENSENUMBER');
        t_jobid :=
            api.pkg_simplesearch.objectbyindex(
                a_objectdefname => 'j_License',
                a_columnname => 'ExternalFileNum',
                a_lowvalue  => t_licensenumber);

        IF (t_jobid IS NOT NULL)
        THEN
            t_json.put('PACKET_TYPE', 'LEGALENTITIES');
            t_json.put('DATA', t_array);

            FOR rec
                IN (    SELECT DISTINCT
                               SYS_CONNECT_BY_PATH(r.toobjectid, '/')     path2
                          FROM api.relationships r
                               JOIN api.objects f ON f.objectid = r.toobjectid
                    START WITH r.fromobjectid = t_jobid
                           AND (f.objectdefid =
                                api.pkg_configquery.objectdefidforname(
                                    'o_LegalEntity')
                             OR f.objectdefid =
                                api.pkg_configquery.objectdefidforname(
                                    'j_Application'))
                           AND r.endpointid IN (292101,
                                                338110,
                                                310133,
                                                298362,
                                                311516,
                                                314059,
                                                329508,
                                                427253,
                                                447075)
                    CONNECT BY r.fromobjectid = PRIOR r.toobjectid
                           AND r.relationshipid != PRIOR r.relationshipid
                           AND f.objectdefid =
                               api.pkg_configquery.objectdefidforname(
                                   'o_LegalEntity')
                           AND r.endpointid IN (292101,
                                                338110,
                                                310133,
                                                298362,
                                                311516,
                                                314059,
                                                329508,
                                                427253,
                                                447075)
                      ORDER BY path2)
            LOOP
                get_legalentity(a_json => t_json, a_list => rec.path2);
            END LOOP;
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
