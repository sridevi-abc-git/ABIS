CREATE OR REPLACE PROCEDURE BIZMOD_API.createlicenseappjob(a_seq          IN NUMBER,
                                                a_asofdate     IN DATE)
IS
    -- ****************************************************************************
    -- File:        BIZMOD_API.CREATELICENSEAPPJOB.PRC
    -- Author:      Timothy J. Lord
    --
    -- Purpose :
    --
    -- History:
    -------------------------------------------------------------------------------
    --             Date                         Comment
    --   1.2    05/09/2024  TJL  BIZ-15800  Initial Package Created
    --   2.1    07/19/2024  TJL  BIZ-16000  Added additional fields for application
    --                                      update.
    --   3.0.1  09/09/2024  TJL  BIZ-16077  Added country to add address process
    --   3.1    10/09/2024  BN   BIZ-16428  Fixed the DBA missing and Duplicate address issue
    --   3.2.0  10/15/2024  TJL             Fixed bug when creating o_Person object (Dup Person)
    -- ****************************************************************************

    PROCEDURE add_legal_entities(a_objectid     IN api.pkg_definition.udt_id,
                                 a_legal_entity IN CLOB);

    PROCEDURE add_secondary_license_types(
        a_primary_objectid IN api.pkg_definition.udt_id,
        a_licensetypecodeobjectid IN api.pkg_definition.udt_id,
        a_secondary_license_types IN CLOB)
    IS
        t_endpointid   api.pkg_definition.udt_id;
        t_relid        api.pkg_definition.udt_id;
        t_secondarytypeobjectid api.pkg_definition.udt_id;
        t_maximumcount NUMBER;
    BEGIN
        FOR rec
            IN (SELECT *
                  FROM JSON_TABLE(
                           a_secondary_license_types,
                           '$[*]'
                           COLUMNS(
                               licensetypecode
                                   VARCHAR2(3)
                                   PATH '$.LICENSETYPECODE',
                               primarycount NUMBER PATH '$.PRIMARY_COUNT')))
        LOOP
            SELECT c.objectid, c.maximumcount
              INTO t_secondarytypeobjectid, t_maximumcount
              FROM query.o_licensetypecategory c
             WHERE c.licensetypecode = rec.licensetypecode;

            -- check if valid secondary for license type
            IF (INSTR(
                    api.pkg_columnquery.VALUE(a_licensetypecodeobjectid,
                                              'secondarylicensetypecodes'),
                    rec.licensetypecode) >
                0)
            THEN
                -- create releationship between primary license type and license type catagory
                t_endpointid :=
                    api.pkg_configquery.endpointidforname(
                        'o_PrimaryLicenseType',
                        'LicTypeCatSecondary');
                t_relid :=
                    api.pkg_relationshipupdate.new(t_endpointid,
                                                   a_primary_objectid,
                                                   t_secondarytypeobjectid);

                IF (rec.primarycount IS NOT NULL)
                THEN
                    api.pkg_columnupdate.setvalue(
                        t_relid,
                        'NewCount',
                        LEAST(rec.primarycount, t_maximumcount));
                END IF;
            END IF;
        END LOOP;
    END add_secondary_license_types;


    PROCEDURE add_primary_license_types(
        a_jobid        IN api.pkg_definition.udt_id,
        a_primarylicensetypes IN CLOB)
    IS
        t_endpointid   api.pkg_definition.udt_id;
        t_relid        api.pkg_definition.udt_id;
        t_licensetypedefid api.pkg_definition.udt_id;
        t_licensetypecodeobjectid api.pkg_definition.udt_id;
        t_licensetypeobjectid api.pkg_definition.udt_id;
        t_licensetypeobjectid86 api.pkg_definition.udt_id;
        t_licensetypecategoryid api.pkg_definition.udt_id;
        t_endpointidto NUMBER;
        t_gallonagerange VARCHAR2(15);
        t_additionalmilliongallons NUMBER;
    BEGIN
        FOR rec
            IN (SELECT *
                  FROM JSON_TABLE(
                           a_primarylicensetypes,
                           '$[*]'
                           COLUMNS(
                               licensetypecode
                                   VARCHAR2(3)
                                   PATH '$.LICENSETYPECODE',
                               gallonage NUMBER PATH '$.GALLONAGE',
                               numberofmonthslicensed
                                   NUMBER
                                   PATH '$.NUMBEROFMONTHSLICENSED',
                               seasonstartmonth
                                   VARCHAR2(100)
                                   PATH '$.SEASON_START_MONTH',
                               primarycount NUMBER PATH '$.PRIMARYCOUNT',
                               isbranch VARCHAR2(1) PATH '$.ISBRANCH',
                               masterlicense
                                   VARCHAR2(50)
                                   PATH '$.MASTERLICENSE',
                               secondarylicensetypes
                                   VARCHAR2(4000)
                                   FORMAT JSON
                                   PATH '$.SECONDARYLICENSETYPES')))
        LOOP
            --dbms_output.put_line('ltc: ' || rec.licensetypecode);
            SELECT ltc.objectid
              INTO t_licensetypecodeobjectid
              FROM query.o_licensetypecategory ltc
             WHERE ltc.licensetypecode = rec.licensetypecode;

            -- create primary licene type
            t_licensetypedefid :=
                api.pkg_configquery.objectdefidforname(
                    'o_PrimaryLicenseType');
            t_licensetypeobjectid :=
                api.pkg_objectupdate.new(t_licensetypedefid);

            -- create relationship from primary license type to license type catagory
            t_endpointid :=
                api.pkg_configquery.endpointidforname('o_PrimaryLicenseType',
                                                      'LicTypeCatPrimary');
            t_relid :=
                api.pkg_relationshipupdate.new(t_endpointid,
                                               t_licensetypeobjectid,
                                               t_licensetypecodeobjectid);

            -- if this is a branch license
            IF (NVL(rec.isbranch, 'N') = 'Y')
            THEN
                FOR l
                    IN (SELECT objectid,
                               api.pkg_columnquery.VALUE(objectid,
                                                         'LicenseTypeCode')    licensetypecode
                          FROM TABLE(
                                   CAST(
                                       api.pkg_simplesearch.castableobjectsbyindex(
                                           a_objectdefname => 'j_LicenseType',
                                           a_columnname =>
                                               'dup_LicenseExternalFileNum',
                                           a_value     => rec.masterlicense)
                                           AS api.udt_objectlist)) o)
                LOOP
                    IF (rec.licensetypecode = l.licensetypecode)
                    THEN
                        -- indicate this is a branch license
                        api.pkg_columnupdate.setvalue(t_licensetypeobjectid,
                                                      'IsBranchS',
                                                      'Y');

                        -- setup relationship to master of the branch license using
                        --   the information in the t_TransFromLicenseTypeObjectId
                        t_endpointidto :=
                            api.pkg_configquery.endpointidforname(
                                'o_PrimaryLicenseType',
                                'MasterLicenseType');
                        t_relid :=
                            api.pkg_relationshipupdate.new(
                                t_endpointidto,
                                t_licensetypeobjectid,
                                l.objectid);

                        EXIT;
                    END IF;
                END LOOP;
            END IF;

            -- The following is for cases that involved gallonage, and seasonal to set
            --   the special values for each type
            CASE
                WHEN rec.licensetypecode IN ('02', '22')
                THEN
                    -- from gallonage entered figure out codes
                    t_gallonagerange :=
                        CASE
                            WHEN rec.gallonage BETWEEN 0 AND 5000
                            THEN
                                '0 TO 5K'
                            WHEN rec.gallonage BETWEEN 5001 AND 20000
                            THEN
                                '5K TO 20K'
                            WHEN rec.gallonage BETWEEN 20001 AND 100000
                            THEN
                                '20K TO 100K'
                            WHEN rec.gallonage BETWEEN 100001 AND 200000
                            THEN
                                '100K TO 200K'
                            ELSE
                                '200K TO 1M'
                        END;
                    t_additionalmilliongallons :=
                        CASE
                            WHEN rec.gallonage > 0
                            THEN
                                FLOOR((rec.gallonage - 1) / 1000000)
                            ELSE
                                0
                        END;

                    IF (t_additionalmilliongallons > 0)
                    THEN
                        api.pkg_columnupdate.setvalue(
                            t_licensetypeobjectid,
                            'AdditionalMillionGallons',
                            t_additionalmilliongallons);
                    ELSE
                        api.pkg_columnupdate.removevalue(
                            t_licensetypeobjectid,
                            'AdditionalMillionGallons');
                    END IF;

                    api.pkg_columnupdate.setvalue(t_licensetypeobjectid,
                                                  'GallonageRange',
                                                  t_gallonagerange);
                WHEN rec.licensetypecode IN ('49', '59', '60')
                THEN
                    api.pkg_columnupdate.setvalue(t_licensetypeobjectid,
                                                  'NumberOfMonthsLicensed',
                                                  rec.numberofmonthslicensed);
                    api.pkg_columnupdate.setvalue(t_licensetypeobjectid,
                                                  'SeasonStartMonth',
                                                  rec.seasonstartmonth);
                WHEN rec.licensetypecode IN ('86')
                THEN
                    -- create primary licene type
                    t_licensetypedefid :=
                        api.pkg_configquery.objectdefidforname(
                            'o_PrimaryLicenseType');
                    t_licensetypeobjectid86 :=
                        api.pkg_objectupdate.new(t_licensetypedefid);

                    -- create relationship from primary license type to license type catagory
                    SELECT ltc.objectid
                      INTO t_licensetypecategoryid
                      FROM query.o_licensetypecategory ltc
                     WHERE ltc.licensetypecode = '20';

                    t_endpointidto :=
                        api.pkg_configquery.endpointidforname(
                            'o_PrimaryLicenseType',
                            'LicTypeCatPrimary');
                    t_relid :=
                        api.pkg_relationshipupdate.new(
                            t_endpointidto,
                            t_licensetypeobjectid86,
                            t_licensetypecategoryid);

                    --     add primary license type to application
                    t_endpointidto :=
                        api.pkg_configquery.endpointidforname(
                            'j_application',
                            'PrimaryLicenseType');
                    t_relid :=
                        api.pkg_relationshipupdate.new(
                            t_endpointidto,
                            a_jobid,
                            t_licensetypeobjectid86);
                ELSE
                    NULL;
            END CASE;

            IF (rec.primarycount IS NOT NULL)
            THEN
                api.pkg_columnupdate.setvalue(t_licensetypeobjectid,
                                              'PrimaryCount',
                                              rec.primarycount);
            END IF;

            add_secondary_license_types(
                a_primary_objectid => t_licensetypeobjectid,
                a_licensetypecodeobjectid => t_licensetypecodeobjectid,
                a_secondary_license_types => rec.secondarylicensetypes);

            -- create relationship from primary license type to application
            t_endpointid :=
                api.pkg_configquery.endpointidforname('j_application',
                                                      'PrimaryLicenseType');
            t_relid :=
                api.pkg_relationshipupdate.new(t_endpointid,
                                               a_jobid,
                                               t_licensetypeobjectid);
        END LOOP;

        api.pkg_logicaltransactionupdate.endtransaction;
        COMMIT;
    END add_primary_license_types;

    PROCEDURE add_address(a_jobid        IN api.pkg_definition.udt_id,
                          a_address_type IN VARCHAR2,
                          a_address      IN CLOB)
    IS
        t_addr         bizmod_api.utl_licenseinfo.gc_addr_t;
        t_addressobjectid api.pkg_definition.udt_id;
        t_cityobjectid api.pkg_definition.udt_id;
        t_cityendpointid api.pkg_definition.udt_id;
        t_cityrel      api.pkg_definition.udt_id;
        t_endpointid   api.pkg_definition.udt_id;
        t_addrel       api.pkg_definition.udt_id;
    BEGIN
        IF (a_address IS NOT NULL)
        THEN
            SELECT *
              INTO t_addr
              FROM JSON_TABLE(
                       a_address,
                       '$'
                       COLUMNS(
                           addresslocation
                               VARCHAR2(4000)
                               PATH '$.ADDRESSLOCATION',
                           addressline1 VARCHAR2(4000) PATH '$.ADDRESSLINE1',
                           addressline2 VARCHAR2(4000) PATH '$.ADDRESSLINE2',
                           addressline3 VARCHAR2(4000) PATH '$.ADDRESSLINE3',
                           usacity VARCHAR2(4000) PATH '$.USACITY',
                           usastate VARCHAR2(4000) PATH '$.USASTATE',
                           zipcode VARCHAR2(4000) PATH '$.ZIPCODE',
                           country VARCHAR2(4000) PATH '$.COUNTRY',
                           phonenumber VARCHAR2(4000) PATH '$.PHONENUMBER',
                           faxnumber VARCHAR2(4000) PATH '$.FAXNUMBER',
                           internationalphonenumber
                               VARCHAR2(4000)
                               PATH '$.INTERNATIONALPHONENUMBER',
                           censustract VARCHAR2(4000) PATH '$.CENSUSTRACT',
                           censustractsource
                               VARCHAR2(4000)
                               PATH '$.CENSUSTRACTSOURCE',
                           geocodeaddressline1
                               VARCHAR2(4000)
                               PATH '$.GEOCODEADDRESSLINE1',
                           outsidecitylimits
                               VARCHAR2(3)
                               PATH '$.OUTSIDECITYLIMITS',
                           highcrime VARCHAR2(3) PATH '$.HIGHCRIME',
                           cardroomcasino VARCHAR2(3) PATH '$.CARDROOMCASINO',
                           noevent VARCHAR2(3) PATH '$.NOEVENT',
                           eligiblefortransfer
                               VARCHAR2(3)
                               PATH '$.ELIGIBLEFORTRANSFER'));

            --*********************
            --Get or create address
            --Check for existing addres
            --**************************
            FOR rec
                IN (SELECT objectid
                      FROM TABLE(
                               CAST(
                                   api.pkg_simplesearch.castableobjectsbyindex(
                                       a_objectdefname => 'o_Address',
                                       a_columnname => 'dup_UniqueAddress',
                                       a_value     =>
                                           t_addr.addressline1
                                           || '%'
                                           || t_addr.addressline2
                                           || '%'
                                           || t_addr.addressline3
                                           || '%'
                                           || t_addr.usacity
                                           || '%'
                                           || t_addr.country
                                           || '%')
                                       AS api.udt_objectlist)))
            LOOP
                IF (UPPER(t_addr.addressline1)) =
                   UPPER(
                       api.pkg_columnquery.VALUE(rec.objectid,
                                                 'addressline1'))
               AND UPPER(NVL(t_addr.addressline2, 'X')) =
                   UPPER(
                       NVL(
                           api.pkg_columnquery.VALUE(rec.objectid,
                                                     'addressline2'),
                           'X'))
               AND UPPER(NVL(t_addr.addressline3, 'X')) =
                   UPPER(
                       NVL(
                           api.pkg_columnquery.VALUE(rec.objectid,
                                                     'addressline3'),
                           'X'))
               AND UPPER(NVL(t_addr.usacity, 'X')) =
                   UPPER(
                       NVL(
                           api.pkg_columnquery.VALUE(rec.objectid, 'USACity'),
                           'X'))
               AND ((t_addr.addresslocation != 'Outside USA'
                 AND UPPER('UNITED STATES OF AMERICA') =
                     UPPER(
                         NVL(
                             api.pkg_columnquery.VALUE(rec.objectid,
                                                       'Country'),
                             'X')))
                 OR (t_addr.addresslocation = 'Outside USA'
                 AND UPPER(NVL(t_addr.country, 'X')) =
                     UPPER(
                         NVL(
                             api.pkg_columnquery.VALUE(rec.objectid,
                                                       'Country'),
                             'X'))))
                THEN
                    t_addressobjectid := rec.objectid;
                    EXIT WHEN t_addressobjectid IS NOT NULL;
                END IF;
            END LOOP;

            IF (t_addressobjectid IS NULL)
            THEN
                --******************
                --Create new addres
                --******************
                t_addressobjectid :=
                    api.pkg_objectupdate.new(
                        api.pkg_configquery.objectdefidforname('o_Address'));

                t_cityendpointid :=
                    api.pkg_configquery.endpointidforname('o_Address',
                                                          'CACity');

                --****************
                --Add address data
                --****************
                api.pkg_columnupdate.setvalue(t_addressobjectid,
                                              'AddressLine1',
                                              t_addr.addressline1);
                api.pkg_columnupdate.setvalue(t_addressobjectid,
                                              'AddressLine2',
                                              t_addr.addressline2);
                api.pkg_columnupdate.setvalue(t_addressobjectid,
                                              'AddressLine3',
                                              t_addr.addressline3);
                api.pkg_columnupdate.setvalue(t_addressobjectid,
                                              'ZipCode',
                                              t_addr.zipcode);
                api.pkg_columnupdate.setvalue(t_addressobjectid,
                                              'Country',
                                              t_addr.country);
                api.pkg_columnupdate.setvalue(
                    t_addressobjectid,
                    'PhoneNumber',
                    REGEXP_REPLACE(t_addr.phonenumber, '[^[:digit:]]+'));
                api.pkg_columnupdate.setvalue(
                    t_addressobjectid,
                    'InternationalPhoneNumber',
                    REGEXP_REPLACE(t_addr.internationalphonenumber,
                                   '[^[:digit:]]+'));
                api.pkg_columnupdate.setvalue(
                    t_addressobjectid,
                    'FaxNumber',
                    REGEXP_REPLACE(t_addr.faxnumber, '[^[:digit:]]+'));

                IF (t_addr.addresslocation = 'In California')
                THEN
                    --******************
                    --Get CA city object id
                    --******************
                    SELECT o.objectid
                      INTO t_cityobjectid
                      FROM TABLE(
                               CAST(
                                   api.pkg_simplesearch.castableobjectsbyindex(
                                       a_objectdefname => 'o_CaCity',
                                       a_columnname => 'CityName',
                                       a_value     => t_addr.usacity)
                                       AS api.udt_objectlist)) o;

                    api.pkg_columnupdate.setvalue(t_addressobjectid,
                                                  'AddressLocation',
                                                  'In California');

                    --***************************************************
                    --Create relationship between address and city object
                    --***************************************************
                    t_cityrel :=
                        api.pkg_relationshipupdate.new(
                            a_endpoint  => t_cityendpointid,
                            a_fromobject => t_addressobjectid,
                            a_toobject  => t_cityobjectid);
                ELSE
                    api.pkg_columnupdate.setvalue(t_addressobjectid,
                                                  'AddressLocation',
                                                  t_addr.addresslocation);

                    api.pkg_columnupdate.setvalue(t_addressobjectid,
                                                  'USACity',
                                                  t_addr.usacity);

                    api.pkg_columnupdate.setvalue(t_addressobjectid,
                                                  'USAState',
                                                  t_addr.usastate);
                END IF;

                IF (a_address_type = 'Premises')
                THEN
                    api.pkg_columnupdate.setvalue(t_addressobjectid,
                                                  'CensusTract',
                                                  t_addr.censustract);
                    api.pkg_columnupdate.setvalue(t_addressobjectid,
                                                  'CensusTractSource',
                                                  t_addr.censustractsource);
                    api.pkg_columnupdate.setvalue(t_addressobjectid,
                                                  'GeoCodeAddressLine1',
                                                  t_addr.geocodeaddressline1);
                    api.pkg_columnupdate.setvalue(t_addressobjectid,
                                                  'OutsideCityLimits',
                                                  t_addr.outsidecitylimits);
                    api.pkg_columnupdate.setvalue(t_addressobjectid,
                                                  'HighCrime',
                                                  t_addr.highcrime);
                    api.pkg_columnupdate.setvalue(t_addressobjectid,
                                                  'CardRoomCasino',
                                                  t_addr.cardroomcasino);
                    api.pkg_columnupdate.setvalue(t_addressobjectid,
                                                  'NoEvent',
                                                  t_addr.noevent);
                    api.pkg_columnupdate.setvalue(t_addressobjectid,
                                                  'EligibleForTransfer',
                                                  t_addr.eligiblefortransfer);
                END IF;
            END IF;

            t_endpointid :=
                api.pkg_configquery.endpointidforname(
                    api.pkg_columnquery.VALUE(a_jobid, 'ObjectDefName'),
                    a_address_type);

            t_addrel :=
                api.pkg_relationshipupdate.new(
                    a_endpoint  => t_endpointid,
                    a_fromobject => a_jobid,
                    a_toobject  => t_addressobjectid);

            api.pkg_logicaltransactionupdate.endtransaction;
            COMMIT;
        END IF;
    END add_address;

    PROCEDURE add_person(a_entityobjectid IN api.pkg_definition.udt_id,
                         a_legal_entity IN CLOB)
    IS
        t_entity       bizmod_api.utl_licenseinfo.gc_person_t;
        t_objectdefid  api.pkg_definition.udt_id;
        t_objectid     api.pkg_definition.udt_id;
        t_relid        api.pkg_definition.udt_id;
        t_endpointid   api.pkg_definition.udt_id;
        t_searchname   VARCHAR2(2000);
        t_list         api.udt_objectlist;
    BEGIN
        SELECT *
          INTO t_entity
          FROM JSON_TABLE(
                   a_legal_entity,
                   '$'
                   COLUMNS(
                       firstname VARCHAR2(4000) PATH '$.FIRSTNAME',
                       middlename VARCHAR2(4000) PATH '$.MIDDLENAME',
                       lastname VARCHAR2(4000) PATH '$.LASTNAME',
                       suffix VARCHAR2(20) PATH '$.SUFFIX',
                       aliasnames VARCHAR2(4000) PATH '$.ALIASNAMES',
                       socialsecuritynumber
                           VARCHAR2(4)
                           PATH '$.SOCIALSECURITYNUMBER',
                       driverslicensenumber
                           VARCHAR2(4000)
                           PATH '$.DRIVERSLICENSENUMBER',
                       driverslicensestate
                           VARCHAR2(4000)
                           PATH '$.DRIVERSLICENSESTATE',
                       passportnumber VARCHAR2(4000) PATH '$.PASSPORTNUMBER',
                       gender VARCHAR2(4000) PATH '$.GENDER',
                       birthdate DATE PATH '$.BIRTHDATE',
                       birthcity VARCHAR2(4000) PATH '$.BIRTHCITY',
                       birthstate VARCHAR2(4000) PATH '$.BIRTHSTATE',
                       birthcountry VARCHAR2(4000) PATH '$.BIRTHCOUNTRY',
                       maritalstatus VARCHAR2(4000) PATH '$.MARITALSTATUS',
                       address CLOB FORMAT JSON PATH '$.ADDRESS'));

        -- *****************************************************************
        -- check if person is already in system
        -- *****************************************************************
        t_searchname :=
            CASE
                WHEN t_entity.firstname IS NULL
                 AND t_entity.middlename IS NULL
                THEN
                    t_entity.lastname
                WHEN t_entity.middlename IS NULL
                THEN
                    t_entity.lastname || ' ' || t_entity.firstname
                WHEN t_entity.firstname IS NULL
                THEN
                    t_entity.lastname || ' ' || t_entity.middlename
                ELSE
                    t_entity.lastname
                    || ' '
                    || t_entity.firstname
                    || ' '
                    || t_entity.middlename
            END
            || CASE
                   WHEN t_entity.suffix IS NULL THEN ''
                   ELSE ' ' || t_entity.suffix
               END;

        SELECT api.udt_object(objectid)
          BULK COLLECT INTO t_list
          FROM TABLE(
                   CAST(
                       api.pkg_simplesearch.castableobjectsbyindex(
                           a_objectdefname => 'o_Person',
                           a_columnname => 'dup_FormattedPersonNameSearch',
                           a_value     => t_searchname)
                           AS api.udt_objectlist));


        CASE t_list.COUNT
            WHEN 0
            THEN
                t_objectid := NULL;
            WHEN 1
            THEN
                t_objectid := t_list(1).objectid;
            ELSE
                t_objectid := t_list(1).objectid;

                FOR inx IN 1 .. t_list.COUNT
                LOOP
                    IF (NVL(t_entity.socialsecuritynumber, 0) =
                        NVL(
                            api.pkg_columnquery.VALUE(t_list(1).objectid,
                                                      'SocialSecurityNumber'),
                            000))
                    THEN
                        t_objectid := t_list(1).objectid;
                        EXIT;
                    END IF;
                END LOOP;
        END CASE;

        IF (t_objectid IS NULL)
        THEN
            -- *****************************************************************
            -- create person object for the application legal entity object
            -- *****************************************************************
            t_objectdefid :=
                api.pkg_configquery.objectdefidforname('o_Person');
            t_objectid := api.pkg_objectupdate.new(t_objectdefid);

            -- create first and last name from regression run
            api.pkg_columnupdate.setvalue(t_objectid,
                                          'FirstName',
                                          t_entity.firstname);
            api.pkg_columnupdate.setvalue(t_objectid,
                                          'MiddleName',
                                          t_entity.middlename);
            api.pkg_columnupdate.setvalue(t_objectid,
                                          'LastName',
                                          t_entity.lastname);
            api.pkg_columnupdate.setvalue(a_entityobjectid,
                                          'dup_LastName',
                                          t_entity.lastname);
            api.pkg_columnupdate.setvalue(t_objectid,
                                          'Suffix',
                                          t_entity.suffix);
            api.pkg_columnupdate.setvalue(t_objectid,
                                          'AliasNames',
                                          t_entity.aliasnames);
            api.pkg_columnupdate.setvalue(t_objectid,
                                          'SocialSecurityNumber',
                                          t_entity.socialsecuritynumber);
            api.pkg_columnupdate.setvalue(t_objectid,
                                          'DriversLicenseNumber',
                                          t_entity.driverslicensenumber);
            api.pkg_columnupdate.setvalue(t_objectid,
                                          'DriversLicenseState',
                                          t_entity.driverslicensestate);
            api.pkg_columnupdate.setvalue(t_objectid,
                                          'PassportNumber',
                                          t_entity.passportnumber);
            api.pkg_columnupdate.setvalue(t_objectid,
                                          'Gender',
                                          t_entity.gender);
            api.pkg_columnupdate.setvalue(t_objectid,
                                          'BirthDate',
                                          t_entity.birthdate);
            api.pkg_columnupdate.setvalue(t_objectid,
                                          'BirthCity',
                                          t_entity.birthcity);
            api.pkg_columnupdate.setvalue(t_objectid,
                                          'BirthState',
                                          t_entity.birthstate);
            api.pkg_columnupdate.setvalue(t_objectid,
                                          'BirthCountry',
                                          t_entity.birthcountry);
            api.pkg_columnupdate.setvalue(t_objectid,
                                          'MaritalStatus',
                                          t_entity.maritalstatus);
        END IF;

        -- create relationship from person object to legal entity object
        t_endpointid :=
            api.pkg_configquery.endpointidforname('o_legalentity', 'Person');
        t_relid :=
            api.pkg_relationshipupdate.new(t_endpointid,
                                           a_entityobjectid,
                                           t_objectid);

        api.pkg_logicaltransactionupdate.endtransaction;
        COMMIT;
    -- add address to this legal entity
    --        IF (t_entity.address IS NOT NULL)
    --        THEN
    --            add_address(a_jobid     => t_objectid,
    --                        a_address_type => 'Address',
    --                        a_address   => t_entity.address);
    --        END IF;

    END add_person;

    PROCEDURE add_company(a_entityobjectid IN api.pkg_definition.udt_id,
                          a_legal_entity IN CLOB)
    IS
        t_entity       bizmod_api.utl_licenseinfo.gc_company_t;
        t_objectdefid  api.pkg_definition.udt_id;
        t_objectid     api.pkg_definition.udt_id;

        t_relid        api.pkg_definition.udt_id;
        t_endpointid   api.pkg_definition.udt_id;
    BEGIN
        --        DBMS_OUTPUT.put_line('add_company: ' || a_legal_entity);

        SELECT *
          INTO t_entity
          FROM JSON_TABLE(
                   a_legal_entity,
                   '$'
                   COLUMNS(
                       companyname VARCHAR2(4000) PATH '$.COMPANYNAME',
                       companystructure
                           VARCHAR2(4000)
                           PATH '$.COMPANYSTRUCTURE',
                       dateofincorporation DATE PATH '$.DATEOFINCORPORATION',
                       stateofincorporation
                           VARCHAR2(4000)
                           PATH '$.STATEOFINCORPORATION',
                       casecretaryofstatenumber
                           VARCHAR2(4000)
                           PATH '$.CASECRETARYOFSTATENUMBER',
                       federalemployeridentificationn
                           VARCHAR2(4000)
                           PATH '$.FEDERALEMPLOYERIDENTIFICATIONN',
                       address CLOB FORMAT JSON PATH '$.ADDRESS'));

        -- *****************************************************************
        -- create person object for the application legal entity object
        -- *****************************************************************
        t_objectdefid := api.pkg_configquery.objectdefidforname('o_Company');
        t_objectid := api.pkg_objectupdate.new(t_objectdefid);

        api.pkg_columnupdate.setvalue(t_objectid,
                                      'CompanyName',
                                      t_entity.companyname);
        api.pkg_columnupdate.setvalue(t_objectid,
                                      'CompanyStructure',
                                      t_entity.companystructure);
        api.pkg_columnupdate.setvalue(t_objectid,
                                      'DateOfIncorporation',
                                      t_entity.dateofincorporation);
        api.pkg_columnupdate.setvalue(t_objectid,
                                      'StateoFinCorporation',
                                      t_entity.stateofincorporation);
        api.pkg_columnupdate.setvalue(t_objectid,
                                      'CaSecretaryOfStateNumber',
                                      t_entity.casecretaryofstatenumber);
        api.pkg_columnupdate.setvalue(
            t_objectid,
            'FederalEmployerIdentificationN',
            t_entity.federalemployeridentificationn);

        --        DBMS_OUTPUT.put_line(
        --            'ent: ' || a_entityobjectid || 'cmpy: ' || t_objectid);
        -- create relationship from company object to legal entity object
        t_endpointid :=
            api.pkg_configquery.endpointidforname('o_LegalEntity', 'Company');
        t_relid :=
            api.pkg_relationshipupdate.new(t_endpointid,
                                           a_entityobjectid,
                                           t_objectid);

        api.pkg_logicaltransactionupdate.endtransaction;
        COMMIT;

        -- add address to this legal entity
        IF (t_entity.address IS NOT NULL)
        THEN
            add_address(a_jobid     => t_objectid,
                        a_address_type => 'Address',
                        a_address   => t_entity.address);
        END IF;
    END add_company;

    PROCEDURE add_title(a_entityobjectid IN api.pkg_definition.udt_id,
                        a_legal_entity IN CLOB)
    IS
        t_objectdefid  api.pkg_definition.udt_id;
        t_objectid     api.pkg_definition.udt_id;

        t_relid        api.pkg_definition.udt_id;
        t_endpointid   api.pkg_definition.udt_id;
    BEGIN
        --        DBMS_OUTPUT.put_line('add_title: ' || a_legal_entity);

        FOR rec
            IN (SELECT *
                  FROM JSON_TABLE(
                           a_legal_entity,
                           '$[*]'
                           COLUMNS(description VARCHAR2(4000) PATH '$')))
        LOOP
            --            DBMS_OUTPUT.put(
            --                a_entityobjectid || '  Desc: ' || rec.description);
            -- *****************************************************************
            -- create person object for the application legal entity object
            -- *****************************************************************
            t_objectdefid :=
                api.pkg_configquery.objectdefidforname('o_Title');
            t_objectid :=
                api.pkg_simplesearch.objectbyindex(
                    a_objectdefname => 'o_Title',
                    a_columnname => 'Description',
                    a_lowvalue  => rec.description);


            --            DBMS_OUTPUT.put_line(CHR(9) || t_objectid);

            -- create relationship from title object to legal entity object
            t_endpointid :=
                api.pkg_configquery.endpointidforname('o_LegalEntity',
                                                      'Title');
            t_relid :=
                api.pkg_relationshipupdate.new(t_endpointid,
                                               a_entityobjectid,
                                               t_objectid);

            api.pkg_logicaltransactionupdate.endtransaction;
            COMMIT;
        END LOOP;
    END add_title;


    PROCEDURE add_legal_entities(a_objectid     IN api.pkg_definition.udt_id,
                                 a_legal_entity IN CLOB)
    IS
        t_objectdefid  api.pkg_definition.udt_id;
        t_objectid     api.pkg_definition.udt_id;

        t_entitydefid  api.pkg_definition.udt_id
            := api.pkg_configquery.objectdefidforname('o_LegalEntity');
        t_entityobjectid api.pkg_definition.udt_id;

        t_relid        api.pkg_definition.udt_id;
        t_endpointid   api.pkg_definition.udt_id;
    BEGIN
        IF (a_legal_entity IS NOT NULL)
        THEN
            FOR rec
                IN (SELECT *
                      FROM JSON_TABLE(
                               a_legal_entity,
                               '$[*]'
                               COLUMNS(
                                   legalentitytype
                                       VARCHAR2(4000)
                                       PATH '$.LEGALENTITYTYPE',
                                   objectid NUMBER PATH '$.OBJECTID',
                                   referenceid NUMBER PATH '$.REFERENCEID',
                                   ownertype
                                       VARCHAR2(4000)
                                       PATH '$.OWNERTYPE',
                                   title CLOB FORMAT JSON PATH '$.TITLE',
                                   lestructurerel
                                       VARCHAR2(4000)
                                       PATH '$.LESTRUCTUREREL',
                                   percentageofownership
                                       NUMBER
                                       PATH '$.PERCENTAGEOFOWNERSHIP',
                                   phonenumber
                                       VARCHAR2(100)
                                       PATH '$.PHONENUMBER',
                                   company CLOB FORMAT JSON PATH '$.COMPANY',
                                   person CLOB FORMAT JSON PATH '$.PERSON',
                                   legalentities
                                       CLOB
                                       FORMAT JSON
                                       PATH '$.LEGALENTITIES')))
            LOOP
                IF (rec.legalentitytype = 'Entity')
                THEN
                    t_endpointid :=
                        api.pkg_configquery.endpointidforname(
                            'j_Application',
                            CASE
                                WHEN api.pkg_columnquery.VALUE(rec.referenceid,
                                                               'P12Status') =
                                     'Y'
                                THEN
                                    'P12Applicant'
                                WHEN api.pkg_columnquery.VALUE(rec.referenceid,
                                                               'P12AStatus') =
                                     'Y'
                                THEN
                                    'P12Applicant'
                                ELSE
                                    'Applicant'
                            END);

                    CASE api.pkg_columnquery.VALUE(rec.referenceid,
                                                   'LegalEntityType')
                        WHEN 'Company'
                        THEN
                            t_relid :=
                                api.pkg_relationshipupdate.new(t_endpointid,
                                                               a_objectid,
                                                               rec.objectid);
                        WHEN 'Person'
                        THEN
                            t_objectdefid :=
                                api.pkg_configquery.objectdefidforname(
                                    'o_LegalEntity');
                            t_objectid :=
                                api.pkg_objectupdate.new(t_objectdefid);

                            t_relid :=
                                api.pkg_relationshipupdate.new(t_endpointid,
                                                               a_objectid,
                                                               t_objectid);
                            t_relid :=
                                api.pkg_relationshipupdate.new(
                                    api.pkg_configquery.endpointidforname(
                                        'o_LegalEntity',
                                        'Person'),
                                    t_objectid,
                                    rec.objectid);

                            -- check if person has a spouse
--                            FOR rel
--                                IN (SELECT (SELECT re.name
--                                              FROM rel.endpoints_t re
--                                             WHERE re.endpointid =
--                                                   r.endpointid)
--                                               endpointname,
--                                           r.toobjectid
--                                      FROM api.relationships r
--                                     WHERE r.endpointid IN
--                                               (api.pkg_configquery.endpointidforname(
--                                                    'o_LegalEntity',
--                                                    'Spouse1'),
--                                                api.pkg_configquery.endpointidforname(
--                                                    'o_LegalEntity',
--                                                    'Spouse2'))
--                                       AND r.fromobjectid = rec.referenceid)
--                            LOOP
--                                -- add spouse to persons legal entity
--                                t_relid :=
--                                    api.pkg_relationshipupdate.new(
--                                        api.pkg_configquery.endpointidforname(
--                                            'o_LegalEntity',
--                                            rel.endpointname),
--                                        t_objectid,
--                                        rel.toobjectid);
--                            END LOOP;
                        ELSE
                            NULL;
                    END CASE;
                ELSE
                    -- *****************************************************************
                    -- create legal entity for the Application
                    -- *****************************************************************
                    t_entityobjectid :=
                        api.pkg_objectupdate.new(t_entitydefid);
                    --                    api.pkg_logicaltransactionupdate.endtransaction;
                    --                    COMMIT;


                    --                    DBMS_OUTPUT.put_line('ownertype: ' || rec.ownertype);

                    api.pkg_columnupdate.setvalue(t_entityobjectid,
                                                  'OwnerType',
                                                  rec.ownertype);

                    add_title(a_entityobjectid => t_entityobjectid,
                              a_legal_entity => rec.title);
                    api.pkg_columnupdate.setvalue(t_entityobjectid,
                                                  'PercentageOfOwnership',
                                                  rec.percentageofownership);

                    --                    DBMS_OUTPUT.put_line(
                    --                        'rec.lestructurerel: ' || rec.lestructurerel);

                    IF (api.pkg_columnquery.VALUE(a_objectid,
                                                  'ObjectDefName') =
                        'j_Application')
                    THEN
                        t_endpointid :=
                            api.pkg_configquery.endpointidforname(
                                'j_Application',
                                'Applicant');
                    ELSE
                        CASE rec.lestructurerel
                            WHEN 'Spouse'
                            THEN
                                t_endpointid :=
                                    api.pkg_configquery.endpointidforname(
                                        'o_LegalEntity',
                                        'Spouse1');
                            WHEN 'Stockholder'
                            THEN
                                t_endpointid :=
                                    api.pkg_configquery.endpointidforname(
                                        'o_LegalEntity',
                                        'Stockholder');
                            WHEN 'Officer'
                            THEN
                                t_endpointid :=
                                    api.pkg_configquery.endpointidforname(
                                        'o_LegalEntity',
                                        'Officer');
                            ELSE
                                t_endpointid :=
                                    api.pkg_configquery.endpointidforname(
                                        'o_LegalEntity',
                                        'Node');
                        END CASE;
                    END IF;

                    --                    DBMS_OUTPUT.put_line('t_endpointid -' || t_endpointid);
                    --                    DBMS_OUTPUT.put_line('a_objectid - ' || a_objectid);
                    --                    DBMS_OUTPUT.put_line(
                    --                        't_entityobjectid - ' || t_entityobjectid);

                    t_relid :=
                        api.pkg_relationshipupdate.new(t_endpointid,
                                                       a_objectid,
                                                       t_entityobjectid);

                    api.pkg_logicaltransactionupdate.endtransaction;
                    COMMIT;


                    CASE rec.legalentitytype
                        WHEN 'Company'
                        THEN
                            add_company(a_entityobjectid => t_entityobjectid,
                                        a_legal_entity => rec.company);
                        WHEN 'Person'
                        THEN
                            add_person(a_entityobjectid => t_entityobjectid,
                                       a_legal_entity => rec.person);
                        ELSE
                            NULL;
                    END CASE;

                    IF (rec.legalentities IS NOT NULL)
                    THEN
                        DBMS_OUTPUT.put_line(
                            'New legal Entity: '
                            || a_objectid
                            || '  rec.Legal entity: '
                            || rec.legalentities);
                        add_legal_entities(
                            a_objectid  => t_entityobjectid,
                            a_legal_entity => rec.legalentities);
                    END IF;
                END IF;
            END LOOP;
        END IF;
    END add_legal_entities;


    PROCEDURE add_attorney(a_jobid        IN api.pkg_definition.udt_id,
                           a_attorney     IN CLOB)
    IS
        t_objectdefid  api.pkg_definition.udt_id;
        t_objectid     api.pkg_definition.udt_id;

        t_relid        api.pkg_definition.udt_id;
        t_endpointid   api.pkg_definition.udt_id;
    BEGIN
        IF (a_attorney IS NOT NULL)
        THEN
            FOR rec
                IN (SELECT *
                      FROM JSON_TABLE(
                               a_attorney,
                               '$'
                               COLUMNS(
                                   firstname
                                       VARCHAR2(4000)
                                       PATH '$.FIRSTNAME',
                                   middlename
                                       VARCHAR2(4000)
                                       PATH '$.MIDDLENAME',
                                   lastname VARCHAR2(4000) PATH '$.LASTNAME',
                                   firmname VARCHAR2(4000) PATH '$.FIRMNAME',
                                   phonenumber
                                       VARCHAR2(4000)
                                       PATH '$.PHONENUMBER',
                                   faxnumber
                                       VARCHAR2(4000)
                                       PATH '$.FAXNUMBER',
                                   email VARCHAR2(4000) PATH '$.EMAIL',
                                   address
                                       VARCHAR2(4000)
                                       FORMAT JSON
                                       PATH '$.ADDRESS')))
            LOOP
                t_objectdefid :=
                    api.pkg_configquery.objectdefidforname('o_Attorney');
                t_objectid := api.pkg_objectupdate.new(t_objectdefid);

                api.pkg_columnupdate.setvalue(t_objectid,
                                              'FirstName',
                                              rec.firstname);
                api.pkg_columnupdate.setvalue(t_objectid,
                                              'MiddleName',
                                              rec.middlename);
                api.pkg_columnupdate.setvalue(t_objectid,
                                              'LastName',
                                              rec.lastname);
                api.pkg_columnupdate.setvalue(t_objectid,
                                              'FirmName',
                                              rec.firmname);
                api.pkg_columnupdate.setvalue(
                    t_objectid,
                    'PhoneNumber',
                    REGEXP_REPLACE(rec.phonenumber, '[^[:digit:]]+'));
                api.pkg_columnupdate.setvalue(
                    t_objectid,
                    'FaxNumber',
                    REGEXP_REPLACE(rec.faxnumber, '[^[:digit:]]+'));
                api.pkg_columnupdate.setvalue(t_objectid, 'Email', rec.email);

                IF (rec.address IS NOT NULL)
                THEN
                    add_address(a_jobid     => t_objectid,
                                a_address_type => 'Address',
                                a_address   => rec.address);
                END IF;
            END LOOP;

            t_relid :=
                api.pkg_relationshipupdate.new(
                    api.pkg_configquery.endpointidforname('j_Application',
                                                          'Attorney'),
                    a_jobid,
                    t_objectid);

            api.pkg_logicaltransactionupdate.endtransaction;
            COMMIT;
        END IF;
    END add_attorney;

    PROCEDURE add_escrow(a_jobid        IN api.pkg_definition.udt_id,
                         a_escrow       IN CLOB)
    IS
        t_objectdefid  api.pkg_definition.udt_id;
        t_objectid     api.pkg_definition.udt_id;

        t_relid        api.pkg_definition.udt_id;
        t_endpointid   api.pkg_definition.udt_id;
    BEGIN
        IF (a_escrow IS NOT NULL)
        THEN
            FOR rec
                IN (SELECT *
                      FROM JSON_TABLE(
                               a_escrow,
                               '$'
                               COLUMNS(
                                   escrowcompanyname
                                       VARCHAR2(4000)
                                       PATH '$.ESCROWCOMPANYNAME',
                                   address
                                       VARCHAR2(4000)
                                       FORMAT JSON
                                       PATH '$.ADDRESS')))
            LOOP
                t_objectdefid :=
                    api.pkg_configquery.objectdefidforname('o_Escrow');
                t_objectid := api.pkg_objectupdate.new(t_objectdefid);

                api.pkg_columnupdate.setvalue(t_objectid,
                                              'EscrowCompanyName',
                                              rec.escrowcompanyname);

                IF (rec.address IS NOT NULL)
                THEN
                    add_address(a_jobid     => t_objectid,
                                a_address_type => 'Address',
                                a_address   => rec.address);
                END IF;
            END LOOP;

            t_relid :=
                api.pkg_relationshipupdate.new(
                    api.pkg_configquery.endpointidforname('j_Application',
                                                          'Escrow'),
                    a_jobid,
                    t_objectid);

            api.pkg_logicaltransactionupdate.endtransaction;
            COMMIT;
        END IF;
    END add_escrow;
-- ************************************************************************
-- Main Process
-- ************************************************************************


BEGIN
    DECLARE
        t_apprec       bizmod_api.utl_licenseinfo.gc_apprec_t;
        t_packet       CLOB;
        t_sqlerrm      VARCHAR2(4000);
        t_trace        VARCHAR2(4000);
        t_jobid        api.pkg_definition.udt_id;
        t_endpointidfrom NUMBER;
        t_relid        api.pkg_definition.udt_id;
        t_transfromlic api.pkg_definition.udt_id;
        t_endpointid   api.pkg_definition.udt_id;
        t_countyobjectid api.pkg_definition.udt_id;
        t_dbanamesobjectid api.pkg_definition.udt_id;
        t_dbaendpointid api.pkg_definition.udt_id;
        t_dba          api.pkg_definition.udt_id;
    BEGIN
        --*****************
        --Clear any error
        --*****************
        api.pkg_logicaltransactionupdate.resettransaction;
        ROLLBACK;

        --***************
        --Get data packet
        --***************
        SELECT packet
          INTO t_packet
          FROM bizmod_api.eservices_log_t
         WHERE seq = a_seq;

        SELECT applicationtype,
               transferchangetype,
               transferchangelicensenumber,
               multiplestockmembershiptrans,
               lspid,
               underconstruction,
               prioritydrawapplication,
               prioritydrawcounty,
               dba,
               felony,
               violation,
               REGEXP_REPLACE(licensepurchaseprice, '[^.[:digit:]]+', ''),
               primary_license_types,
               premise_address,
               mailing_address,
               istemporarymailingaddress,
               attorney,
               escrow,
               legal_entities
          INTO t_apprec
          FROM JSON_TABLE(
                   t_packet,
                   '$.DATA'
                   COLUMNS(
                       applicationtype VARCHAR2(50) PATH '$.APPLICATIONTYPE',
                       transferchangetype
                           VARCHAR2(100)
                           PATH '$.TRANSFERCHANGETYPE',
                       transferchangelicensenumber
                           VARCHAR2(50)
                           PATH '$.TRANSFERCHANGELICENSENUMBER',
                       multiplestockmembershiptrans
                           VARCHAR2(1)
                           PATH '$.MULTIPLESTOCKMEMBERSHIPTRANS',
                       lspid VARCHAR2(40) PATH '$.LSPAPPLICATIONID',
                       underconstruction
                           VARCHAR2(3)
                           PATH '$.UNDERCONSTRUCTION',
                       prioritydrawapplication
                           VARCHAR2(1)
                           PATH '$.PRIORITYDRAWAPPLICATION',
                       prioritydrawcounty
                           VARCHAR2(100)
                           PATH '$.PRIORITYDRAWCOUNTY',
                       dba VARCHAR2(4000) PATH '$.DBA',
                       felony VARCHAR2(3) PATH '$.FELONY',
                       violation VARCHAR2(3) PATH '$.VIOLATION',
                       licensepurchaseprice
                           NUMBER
                           PATH '$.LICENSEPURCHASEPRICE',
                       primary_license_types
                           VARCHAR2(4000)
                           FORMAT JSON
                           PATH '$[*].PRIMARYLICENSETYPES',
                       premise_address
                           VARCHAR2(4000)
                           FORMAT JSON
                           PATH '$.PREMISESADDRESS',
                       mailing_address
                           VARCHAR2(4000)
                           FORMAT JSON
                           PATH '$.MAILINGADDRESS',
                       istemporarymailingaddress VARCHAR2(3) PATH '$.ISTEMPORARYMAILINGADDRESS',
                       attorney VARCHAR2(4000) FORMAT JSON PATH '$.ATTORNEY',
                       escrow VARCHAR2(4000) FORMAT JSON PATH '$.ESCROW',
                       legal_entities CLOB FORMAT JSON PATH '$.LEGALENTITIES'));

        -- ************************************************************************
        -- Create new application job
        -- ************************************************************************
        t_jobid :=
            api.pkg_objectupdate.new(
                api.pkg_configquery.objectdefidforname('j_Application'));


        -- Update required fields on new application
        api.pkg_columnupdate.setvalue(t_jobid,
                                      'ApplicationType',
                                      t_apprec.applicationtype);
        api.pkg_columnupdate.setvalue(t_jobid,
                                      'LSPID',
                                      t_apprec.lspapplicationid);

        sitespecific.pkg_license.generateappexternalfilenum(t_jobid, SYSDATE);

        api.pkg_logicaltransactionupdate.endtransaction;
        COMMIT;

        IF (t_apprec.dba IS NOT NULL)
        THEN
            t_dbanamesobjectid :=
                api.pkg_objectupdate.new(
                    api.pkg_configquery.objectdefidforname('o_DBANames'));

            api.pkg_columnupdate.setvalue(t_dbanamesobjectid,
                                          'DBA',
                                          t_apprec.dba);
            api.pkg_columnupdate.setvalue(t_dbanamesobjectid,
                                          'PrimaryDBA',
                                          'Y');

            t_dbaendpointid :=
                api.pkg_configquery.endpointidforname('j_application',
                                                      'DBANames');

            t_dba :=
                api.pkg_relationshipupdate.new(t_dbaendpointid,
                                               t_jobid,
                                               t_dbanamesobjectid);
        END IF;

        -- api.pkg_columnupdate.setvalue(t_jobid, 'PrimaryDBA', t_apprec.dba);
        api.pkg_columnupdate.setvalue(t_jobid,
                                      'UnderConstruction',
                                      t_apprec.underconstruction);
        api.pkg_columnupdate.setvalue(t_jobid, 'Felony', t_apprec.felony);
        api.pkg_columnupdate.setvalue(t_jobid,
                                      'Violation',
                                      t_apprec.violation);
        api.pkg_columnupdate.setvalue(t_jobid,
                                      'LicensePurchasePrice',
                                      t_apprec.licensepurchaseprice);

        INSERT INTO bizmod_api.license_app_t(lspid, jobid, createddate)
             VALUES (t_apprec.lspapplicationid, t_jobid, SYSDATE);

        api.pkg_logicaltransactionupdate.endtransaction;
        COMMIT;

        IF (t_apprec.prioritydrawapplication = 'Y')
        THEN
            api.pkg_columnupdate.setvalue(t_jobid,
                                          'PriorityApplicationType',
                                          t_apprec.applicationtype);

            api.pkg_columnupdate.setvalue(t_jobid,
                                          'CopyLicDetailsToAppProcHasRun',
                                          'Y');
            api.pkg_columnupdate.setvalue(t_jobid, 'PriorityUpgrade', 'No');
            api.pkg_columnupdate.setvalue(t_jobid,
                                          'IsPriorityApplication',
                                          'Y');
            api.pkg_columnupdate.setvalue(t_jobid,
                                          'ApplicationType',
                                          t_apprec.applicationtype);

            -- *****************************************************************
            -- Add priority Draw County and license type
            -- *****************************************************************
            -- set priority draw county
            t_countyobjectid :=
                api.pkg_simplesearch.objectbyindex(
                    'o_CaCounty',
                    'CountyName',
                    t_apprec.prioritydrawcounty);

            t_endpointid :=
                api.pkg_configquery.endpointidforname('j_application',
                                                      'PriorityCounty');
            t_relid :=
                api.pkg_relationshipupdate.new(t_endpointid,
                                               t_jobid,
                                               t_countyobjectid);
        END IF;

        IF (t_apprec.applicationtype IN ('Transfer', 'Intercounty Transfer'))
        THEN
            t_transfromlic :=
                api.pkg_simplesearch.objectbyindex(
                    a_objectdefname => 'j_License',
                    a_columnname => 'ExternalFileNum',
                    a_lowvalue  => t_apprec.transferchangelicensenumber);

            -- update application job to indicate this is a new application transfer
            api.pkg_columnupdate.setvalue(t_jobid,
                                          t_apprec.transferchangetype,
                                          'Y');
            api.pkg_columnupdate.setvalue(t_jobid,
                                          'NewLicenseTransferringTo',
                                          'Y');

            -- create relationship between transfer application and license being transfer from
            t_endpointidfrom :=
                api.pkg_configquery.endpointidforname('j_application',
                                                      'LicenseTransfer');
            t_relid :=
                api.pkg_relationshipupdate.new(t_endpointidfrom,
                                               t_jobid,
                                               t_transfromlic);
        END IF;

        add_primary_license_types(
            a_jobid     => t_jobid,
            a_primarylicensetypes => t_apprec.primarylicensetypes);

        add_address(a_jobid     => t_jobid,
                    a_address_type => 'Premises',
                    a_address   => t_apprec.premiseaddress);

        add_address(a_jobid     => t_jobid,
                    a_address_type => 'MailingAddress',
                    a_address   => t_apprec.mailingaddress);

        api.pkg_columnupdate.setvalue(t_jobid,
                                      'IsTemporaryMailingAddress',
                                      t_apprec.istemporarymailingaddress);

        add_legal_entities(a_objectid  => t_jobid,
                           a_legal_entity => t_apprec.legal_entities);

        add_attorney(a_jobid => t_jobid, a_attorney => t_apprec.attorney);

        add_escrow(a_jobid => t_jobid, a_escrow => t_apprec.escrow);

        add_legal_entities(a_objectid  => t_jobid,
                           a_legal_entity => t_apprec.legal_entities);

        -- "ApplicationCreatedDate" must be set last before save
        api.pkg_columnupdate.setvalue(t_jobid,
                                      'ApplicationCreatedDate',
                                      SYSDATE);

        api.pkg_logicaltransactionupdate.endtransaction;
        COMMIT;

        --        DBMS_OUTPUT.put_line(
        --            'Application: '
        --            || api.pkg_columnquery.VALUE(t_jobid, 'ExternalFileNum')
        --            || ' *  '
        --            || CHR(9)
        --            || t_jobid);
        --
        INSERT INTO bizmod_api.e_process_log_t(seq,
                                               processjob,
                                               info,
                                               errmsg,
                                               bktrace)
                 VALUES (
                            a_seq,
                            'CREATELICENSEAPPJOB',
                            'Application Id: '
                            || t_apprec.lspapplicationid
                            || CHR(13)
                            || 'License Number: '
                            || api.pkg_columnquery.VALUE(t_jobid,
                                                         'ExternalFileNum')
                            || CHR(13)
                            || 'j_Application: '
                            || t_jobid
                            || CASE
                                   WHEN json_value(t_packet, '$.*.SOURCEAPP')
                                            IS NOT NULL
                                   THEN
                                       '  ('
                                       || json_value(t_packet,
                                                     '$.*.SOURCEAPP')
                                       || ')'
                                   ELSE
                                       NULL
                               END,
                            t_sqlerrm,
                            t_trace);

        COMMIT;

        -- notify LSP application has completed
        bizmod_api.pkg_abis.applicationsave(a_objectid  => NULL,
                                            a_asofdate  => SYSDATE,
                                            a_jobid     => t_jobid);
    EXCEPTION
        WHEN OTHERS
        THEN
            t_sqlerrm := SUBSTR(SQLERRM, 1, 3990);
            t_trace := SUBSTR(DBMS_UTILITY.format_error_backtrace, 1, 3990);

            api.pkg_logicaltransactionupdate.resettransaction;
            ROLLBACK;

            bizmod_api.pkg_abis.applicationsave(a_objectid  => NULL,
                                                a_asofdate  => SYSDATE,
                                                a_jobid     => t_jobid,
                                                a_status    => 'ERRORED');



            INSERT INTO bizmod_api.e_process_log_t(seq,
                                                   processjob,
                                                   info,
                                                   errmsg,
                                                   bktrace)
                     VALUES (
                                a_seq,
                                'CREATELICENSEAPPJOB',
                                'Application Id: '
                                || t_apprec.lspapplicationid
                                || CHR(13)
                                || 'License Number: '
                                || api.pkg_columnquery.VALUE(
                                       t_jobid,
                                       'ExternalFileNum')
                                || CHR(13)
                                || 'j_Application: '
                                || t_jobid
                                || CASE
                                       WHEN json_value(t_packet,
                                                       '$.*.SOURCEAPP')
                                                IS NOT NULL
                                       THEN
                                           '  ('
                                           || json_value(t_packet,
                                                         '$.*.SOURCEAPP')
                                           || ')'
                                       ELSE
                                           NULL
                                   END,
                                t_sqlerrm,
                                t_trace);

            COMMIT;
    END;
END;
/


GRANT EXECUTE ON BIZMOD_API.CREATELICENSEAPPJOB TO POSSEEXTENSIONS;
