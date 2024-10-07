CREATE OR REPLACE FUNCTION BIZMOD_API.REQUESTLICENSEAPPINFO(a_packet       IN CLOB,
                                                         a_seq          IN NUMBER)
    RETURN CLOB
IS
    -- ****************************************************************************
    -- File:    BIZMOD_API.REQUESTLICENSEAPPINFO.FNC
    -- Author:  Timothy J. Lord
    --
    -- History
    -------------------------------------------------------------------------------
    --  Ver:       Date          Ticket       Comment
    --   1.0   10/07/2024  TJL  BIZ-16424  Inital function created
    -- ****************************************************************************

    TYPE legalentity_type IS TABLE OF NUMBER;


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
        t_json.put('ADDRESSLINE3',
                   api.pkg_columnquery.VALUE(t_objectid, 'ADDRESSLINE3'));
        t_json.put('USACITY',
                   api.pkg_columnquery.VALUE(t_objectid, 'USACITY'));
        t_json.put('USASTATE',
                   api.pkg_columnquery.VALUE(t_objectid, 'USASTATE'));
        t_json.put('ZIPCODE',
                   api.pkg_columnquery.VALUE(t_objectid, 'ZIPCODE'));
        t_json.put('COUNTRY',
                   api.pkg_columnquery.VALUE(t_objectid, 'COUNTRY'));
        t_json.put(
            'PHONENUMBER',
            REGEXP_REPLACE(
                api.pkg_columnquery.VALUE(t_objectid, 'PHONENUMBER'),
                '(\d{3})(\d{3})(\d{4})',
                '(\1)\2-\3'));
        t_json.put(
            'FAXNUMBER',
            REGEXP_REPLACE(
                api.pkg_columnquery.VALUE(t_objectid, 'FAXNUMBER'),
                '(\d{3})(\d{3})(\d{4})',
                '(\1)\2-\3'));
        t_json.put(
            'INTERNATIONALPHONENUMBER',
            api.pkg_columnquery.VALUE(t_objectid, 'INTERNATIONALPHONENUMBER'));

        IF (a_endpoint =
            api.pkg_configquery.endpointidforname('j_Application',
                                                  'Premises'))
        THEN
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
        t_array := a_json.get_array('LEGALENTITIES');

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

        IF (t_json IS NULL --    AND SUBSTR(api.pkg_columnquery.VALUE(t_value, 'LEStructureRel'), 1, 3) !=
                           --        'P12'
           )
        THEN
            --        DBMS_OUTPUT.put_line(
            --            'st: ' || api.pkg_columnquery.VALUE(t_value, 'LeStructureRel'));
            --        DBMS_OUTPUT.put_line(
            --            t_value
            --            || '  name: '
            --            || api.pkg_columnquery.VALUE(t_value, 'objectdefname'));

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
                CASE
                    WHEN gc_use_entity
                    --                WHEN SUBSTR(
                    --                         api.pkg_columnquery.VALUE(t_value, 'LEStructureRel'),
                    --                         1,
                    --                         3) =
                    --                     'P12'
                    --                 AND api.pkg_columnquery.numericvalue(t_value,
                    --                                                      'HierarchyLevel') =
                    --                     1
                    --                CASE SUBSTR(
                    --                         api.pkg_columnquery.VALUE(t_value, 'LEStructureRel'),
                    --                         1,
                    --                         3)
                    --                    WHEN 'P12'
                    THEN
                        'Entity'
                    ELSE
                        api.pkg_columnquery.VALUE(t_value, 'LegalEntityType')
                END);

            t_entity.put(
                'P12TYPE',
                CASE SUBSTR(
                         api.pkg_columnquery.VALUE(t_value, 'LEStructureRel'),
                         1,
                         3)
                    WHEN 'P12'
                    THEN
                        api.pkg_columnquery.VALUE(t_value, 'LEStructureRel')
                    ELSE
                        NULL
                END);

            CASE
                WHEN gc_use_entity
                --        CASE
                --            WHEN SUBSTR(api.pkg_columnquery.VALUE(t_value, 'LEStructureRel'),
                --                        1,
                --                        3) =
                --                 'P12'
                --             AND api.pkg_columnquery.numericvalue(t_value, 'HierarchyLevel') =
                --                 1
                THEN
                    t_pos := 0; -- don't get rest of le
                ELSE
                    t_entity.put(
                        'OWNERTYPE',
                        api.pkg_columnquery.VALUE(t_value, 'OwnerType'));
                    t_entity.put(
                        'TITLE',
                        get_titles(a_legalentityobjectid => t_value));
                    t_entity.put(
                        'PERCENTAGEOFOWNERSHIP',
                        api.pkg_columnquery.VALUE(t_value,
                                                  'PercentageOfOwnership'));

                    CASE api.pkg_columnquery.VALUE(t_value,
                                                   'LegalEntityType')
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
            END CASE;

            t_array.append(t_entity);

            t_json := json_object_t();
            t_json.put('LEGALENTITIES', t_array);
        END IF;

        IF (t_pos > 0
        AND SUBSTR(api.pkg_columnquery.VALUE(t_value, 'LEStructureRel'),
                   1,
                   3) !=
            'P12'
        AND NOT gc_use_entity)
        THEN
            IF api.pkg_columnquery.VALUE(t_value, 'HierarchyLevel') = 2
            THEN
                t_le_cnt := t_le_cnt + 1;
            END IF;

            IF t_le_cnt < 6
            THEN
                get_legalentity(a_json => t_json, a_list => t_next);
            END IF;
        END IF;
    END;

    -- ******************************************************
    -- ******************************************************

    FUNCTION get_legalentity(a_applicationobjectid IN NUMBER)
        RETURN json_array_t
    IS
        t_array        json_array_t := json_array_t();
        t_return       json_object_t := json_object_t();
    BEGIN
        t_return.put('LEGALENTITIES', t_array);

        FOR rec
            IN (    SELECT DISTINCT
                           SYS_CONNECT_BY_PATH(r.toobjectid, '/')     path2
                      FROM api.relationships r
                           JOIN api.objects f ON f.objectid = r.toobjectid
                START WITH r.fromobjectid = a_applicationobjectid
                       AND (f.objectdefid =
                            api.pkg_configquery.objectdefidforname(
                                'o_LegalEntity')
                         OR f.objectdefid =
                            api.pkg_configquery.objectdefidforname(
                                'j_License'))
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
                                            447075,
                                            340283)
                  ORDER BY path2)
        LOOP
            get_legalentity(a_json => t_return, a_list => rec.path2);
        END LOOP;

        RETURN t_return.get_array('LEGALENTITIES');
    END;


    FUNCTION get_attorney(a_objectid IN NUMBER)
        RETURN json_object_t
    AS
        t_attorneyobjectid NUMBER;
        t_attorney     json_object_t := json_object_t();
    BEGIN
        SELECT r.toobjectid
          INTO t_attorneyobjectid
          FROM api.relationships r
         WHERE r.fromobjectid = a_objectid
           AND r.endpointid =
               api.pkg_configquery.endpointidforname(
                   api.pkg_columnquery.VALUE(a_objectid, 'ObjectDefName'),
                   'Attorney');


        t_attorney.put(
            'FIRSTNAME',
            api.pkg_columnquery.VALUE(t_attorneyobjectid, 'FIRSTNAME'));
        t_attorney.put(
            'MIDDLENAME',
            api.pkg_columnquery.VALUE(t_attorneyobjectid, 'MIDDLENAME'));
        t_attorney.put(
            'LASTNAME',
            api.pkg_columnquery.VALUE(t_attorneyobjectid, 'LASTNAME'));
        t_attorney.put(
            'FIRMNAME',
            api.pkg_columnquery.VALUE(t_attorneyobjectid, 'FIRMNAME'));
        t_attorney.put(
            'PHONENUMBER',
            REGEXP_REPLACE(
                api.pkg_columnquery.VALUE(t_attorneyobjectid, 'PHONENUMBER'),
                '(\d{3})(\d{3})(\d{4})',
                '(\1)\2-\3'));
        t_attorney.put(
            'FAXNUMBER',
            REGEXP_REPLACE(
                api.pkg_columnquery.VALUE(t_attorneyobjectid, 'FAXNUMBER'),
                '(\d{3})(\d{3})(\d{4})',
                '(\1)\2-\3'));
        t_attorney.put(
            'EMAIL',
            api.pkg_columnquery.VALUE(t_attorneyobjectid, 'EMAIL'));

        t_attorney.put(
            'ADDRESS',
            get_address(
                a_objectid  => t_attorneyobjectid,
                a_endpoint  =>
                    api.pkg_configquery.endpointidforname(
                        api.pkg_columnquery.VALUE(t_attorneyobjectid,
                                                  'ObjectDefName'),
                        'Address')));

        RETURN t_attorney;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            RETURN NULL;
    END;

    FUNCTION get_escrow(a_objectid IN NUMBER)
        RETURN json_object_t
    AS
        t_escrowobjectid NUMBER;
        t_escrow       json_object_t := json_object_t();
    BEGIN
        SELECT r.toobjectid
          INTO t_escrowobjectid
          FROM api.relationships r
         WHERE r.fromobjectid =
               api.pkg_columnquery.numericvalue(a_objectid,
                                                'LatestIssuedApplicationId')
           AND r.endpointid =
               api.pkg_configquery.endpointidforname(
                   api.pkg_columnquery.VALUE(
                       api.pkg_columnquery.numericvalue(
                           a_objectid,
                           'LatestIssuedApplicationId'),
                       'ObjectDefName'),
                   'Escrow');

        t_escrow.put(
            'ESCROWCOMPANYNAME',
            api.pkg_columnquery.VALUE(t_escrowobjectid, 'EscrowCompanyName'));

        t_escrow.put(
            'ADDRESS',
            get_address(
                a_objectid  => t_escrowobjectid,
                a_endpoint  =>
                    api.pkg_configquery.endpointidforname(
                        api.pkg_columnquery.VALUE(t_escrowobjectid,
                                                  'ObjectDefName'),
                        'Address')));

        RETURN t_escrow;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            RETURN NULL;
    END;


    FUNCTION get_secondarylicensetypes(a_objectid IN NUMBER)
        RETURN json_array_t
    AS
        t_array        json_array_t := json_array_t();
        t_object       json_object_t;
    BEGIN
        FOR rec
            IN (SELECT r.toobjectid objectid, r.relationshipid
                  FROM api.relationships r
                 WHERE r.endpointid =
                       api.pkg_configquery.endpointidforname(
                           api.pkg_columnquery.VALUE(a_objectid,
                                                     'ObjectDefName'),
                           'LicTypeCatSecondary')
                   AND r.fromobjectid = a_objectid)
        LOOP
            t_object := json_object_t();

            t_object.put(
                'LICENSETYPECODE',
                api.pkg_columnquery.VALUE(rec.objectid, 'LICENSETYPECODE'));
            t_object.put(
                'PRIMARYCOUNT',
                api.pkg_columnquery.VALUE(rec.relationshipid, 'NewCount'));

            t_array.append(t_object);
        END LOOP;

        RETURN t_array;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            RETURN NULL;
    END;


    FUNCTION get_primarylicensetypes(a_objectid IN NUMBER)
        RETURN json_array_t
    AS
        t_array        json_array_t := json_array_t();
        t_object       json_object_t;
    BEGIN
        FOR rec
            IN (SELECT r.toobjectid     objectid
                  FROM api.relationships r
                 WHERE r.endpointid =
                       api.pkg_configquery.endpointidforname(
                           api.pkg_columnquery.VALUE(a_objectid,
                                                     'ObjectDefName'),
                           'LicenseType')
                   AND r.fromobjectid = a_objectid)
        LOOP
            t_object := json_object_t();
            t_object.put(
                'LICENSETYPECODE',
                api.pkg_columnquery.VALUE(rec.objectid, 'LicenseTypeCode'));
            t_object.put(
                'GALLONAGE',
                api.pkg_columnquery.VALUE(rec.objectid, 'GallonageRange'));
            t_object.put(
                'NUMBEROFMONTHSLICENSED',
                api.pkg_columnquery.VALUE(rec.objectid,
                                          'NumberOfMonthsLicensed'));
            t_object.put(
                'SEASONSTARTMONTH',
                api.pkg_columnquery.VALUE(rec.objectid, 'SeasonStartMonth'));
            t_object.put(
                'PRIMARYCOUNT',
                api.pkg_columnquery.VALUE(rec.objectid, 'PrimaryCount'));
            t_object.put(
                'MASTERLICENSE',
                api.pkg_columnquery.VALUE(rec.objectid,
                                          'MasterPLTLicenseNum'));
            t_object.put(
                'ISBRANCH',
                api.pkg_columnquery.VALUE(rec.objectid, 'IsBranchS'));
            t_object.put(
                'SECONDARYLICENSETYPES',
                get_secondarylicensetypes(a_objectid => rec.objectid));

            t_array.append(t_object);
        END LOOP;

        RETURN t_array;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            RETURN NULL;
    END;
-- ******************************************************
--
--
-- ******************************************************
BEGIN
    DECLARE
        t_application  json_object_t := json_object_t();
        t_data         json_object_t := json_object_t();
        t_applicationjobid api.pkg_definition.udt_id;
        t_response     CLOB;
    BEGIN
    
            t_applicationjobid := json_value(a_packet, '$.*.OBJECTID' returning number);

        --        FOR rec
        --            IN (WITH
        --                    appl
        --                    AS
        --                        (SELECT lt.licensejobid,
        --                                --        lt.licensetypejobid,
        --                                lt.licensetypecode,
        --                                ROW_NUMBER()
        --                                    OVER(PARTITION BY lt.licensetypecode
        --                                         ORDER BY lt.licensetypecode)    AS rn
        --                           FROM bizmod_api.licensetype_t lt
        --                          WHERE lt.statusname = 'ACTIVE'
        --                            AND lt.licensetypecode =
        --                                NVL(gc_license_type, lt.licensetypecode)
        --                            AND (lt.licensetypejobid =
        --                                 NVL(gc_jobid, lt.licensetypejobid)
        --                              OR lt.licensejobid =
        --                                 NVL(gc_jobid, lt.licensejobid)))
        --                  SELECT *
        --                    FROM appl a
        --                   WHERE a.rn = 1
        --                -- and rownum < 3
        --                ORDER BY a.licensetypecode)
        --        LOOP
        --            SELECT MAX(TO_NUMBER(NVL(la.lspid, 0))) + 1
        --              INTO t_lspapplicationid
        --              FROM bizmod_api.license_app_t la;

        t_application.put('PACKET_TYPE', gc_packettype);
        t_application.put('SOURCELICENSE', rec.licensejobid);
        t_application.put('DATA', t_data);
        t_data := t_application.get_object('DATA');

        t_data.put('LSPAPPLICATIONID',
                   api.pkg_columnquery.VALUE(t_applicationjobid, 'LSPID'));
        t_data.put(
            'APPLICATIONTYPE',
            api.pkg_columnquery.VALUE(t_applicationjobid, 'APPLICATIONTYPE'));
        t_data.put('DBA',
                   api.pkg_columnquery.VALUE(t_applicationjobid, 'DBA'));
        t_data.put('FELONY',
                   api.pkg_columnquery.VALUE(t_applicationjobid, 'FELONY'));
        t_data.put('UNDERCONSTRUCTION', 'N');
        t_data.put(
            'VIOLATION',
            api.pkg_columnquery.VALUE(t_applicationjobid, 'VIOLATION'));
        t_data.put(
            'LICENSEPURCHASEPRICE',
            api.pkg_columnquery.numericvalue(t_applicationjobid,
                                             'LICENSEPURCHASEPRICE'));

        t_data.put('PRIMARYLICENSETYPES',
                   get_primarylicensetypes(a_objectid => t_applicationjobid));

        t_data.put(
            'PREMISESADDRESS',
            get_address(
                a_objectid  => t_applicationjobid,
                a_endpoint  =>
                    api.pkg_configquery.endpointidforname(
                        api.pkg_columnquery.VALUE(t_applicationjobid,
                                                  'ObjectDefName'),
                        'Premises')));
        t_data.put(
            'MAILINGADDRESS',
            get_address(
                a_objectid  => t_applicationjobid,
                a_endpoint  =>
                    api.pkg_configquery.endpointidforname(
                        api.pkg_columnquery.VALUE(t_applicationjobid,
                                                  'ObjectDefName'),
                        'MailingAddress')));

        t_data.put('ATTORNEY',
                   get_attorney(a_objectid => t_applicationjobid));
        t_data.put('ESCROW', get_escrow(a_objectid => t_applicationjobid));

        t_data.put(
            'LEGALENTITIES',
            get_legalentity(a_applicationobjectid => t_applicationjobid));

        DBMS_OUTPUT.put_line(
            SUBSTR(
                json_query(t_application.TO_CLOB, '$' RETURNING CLOB PRETTY),
                1,
                32000));

        bizmod_api.utl_licenseinfo.clean(t_application);
        RETURN t_application.TO_CLOB;
    END;
END;
/
