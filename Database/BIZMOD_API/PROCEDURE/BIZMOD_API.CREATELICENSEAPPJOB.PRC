CREATE OR REPLACE PROCEDURE BIZMOD_API.CREATELICENSEAPPJOB(
        a_seq          IN NUMBER,
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
    --          Date                         Comment
    --   1.1  05/09/2024  TJL  BIZ-15800  Initial Package Created
    -- ****************************************************************************
    
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
                           '$'
                           COLUMNS(
                               licensetypecode VARCHAR2(3)
                                   PATH '$.LICENSE_TYPE_CODE',
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
    END;


    PROCEDURE add_primary_license_types(
        a_jobid        IN api.pkg_definition.udt_id,
        a_primary_license_types IN CLOB)
    IS
        t_endpointid   api.pkg_definition.udt_id;
        t_relid        api.pkg_definition.udt_id;
        t_licensetypedefid api.pkg_definition.udt_id;
        t_licensetypecodeobjectid api.pkg_definition.udt_id;
        t_licensetypeobjectid api.pkg_definition.udt_id;

        t_gallonagerange VARCHAR2(15);
        t_additionalmilliongallons NUMBER;
    BEGIN
        FOR rec
            IN (SELECT *
                  FROM JSON_TABLE(
                           a_primary_license_types,
                           '$'
                           COLUMNS(
                               licensetypecode VARCHAR2(3)
                                   PATH '$.LICENSE_TYPE_CODE',
                               gallonage NUMBER PATH '$.GALLONAGE',
                               numberofmonths NUMBER
                                   PATH '$.NUMBER_OF_MONTHS',
                               seasonstartmonth VARCHAR2(100)
                                   PATH '$.SEASON_START_MONTH',
                               primarycount NUMBER PATH '$.PRIMARY_COUNT',
                               secondary_license_types VARCHAR2(4000)
                                   FORMAT JSON
                                   PATH '$.SECONDARY_LICENSE_TYPES')))
        LOOP
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
                                                  rec.numberofmonths);
                --                    api.pkg_columnupdate.setvalue(
                --                        t_licensetypeobjectid,
                --                        'SeasonStartMonth',
                --                        TRIM(TO_CHAR(testcases(i).licenseissuedate, 'MONTH')));

                --                        WHEN testcases(i).licensetypecode IN ('86')
                --                        THEN
                --                            -- create primary licene type
                --                            t_licensetypedefid :=
                --                                api.pkg_configquery.objectdefidforname(
                --                                    'o_PrimaryLicenseType');
                --                            t_licensetypeobjectid86 :=
                --                                api.pkg_objectupdate.new(t_licensetypedefid);
                --
                --                            -- create relationship from primary license type to license type catagory
                --                            SELECT ltc.objectid
                --                              INTO t_licensetypecategoryid
                --                              FROM query.o_licensetypecategory ltc
                --                             WHERE ltc.licensetypecode =
                --                                   testcases(i).masterlicensetypecode;
                --
                --                            t_endpointidto :=
                --                                api.pkg_configquery.endpointidforname(
                --                                    'o_PrimaryLicenseType',
                --                                    'LicTypeCatPrimary');
                --                            t_relid :=
                --                                api.pkg_relationshipupdate.new(
                --                                    t_endpointidto,
                --                                    t_licensetypeobjectid86,
                --                                    t_licensetypecategoryid);
                --
                --                            -- add primary license type to application
                --                            t_endpointidto :=
                --                                api.pkg_configquery.endpointidforname(
                --                                    'j_application',
                --                                    'PrimaryLicenseType');
                --                            t_relid :=
                --                                api.pkg_relationshipupdate.new(
                --                                    t_endpointidto,
                --                                    t_applicationobjectid,
                --                                    t_licensetypeobjectid86);
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
                a_secondary_license_types => rec.secondary_license_types);

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
    END;

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
        SELECT *
          INTO t_addr
          FROM JSON_TABLE(
                   a_address,
                   '$'
                   COLUMNS(address_1 VARCHAR2(4000) PATH '$.ADDRESS_1',
                           address_2 VARCHAR2(4000) PATH '$.ADDRESS_2',
                           city VARCHAR2(4000) PATH '$.CITY',
                           state VARCHAR2(4000) PATH '$.STATE',
                           zip VARCHAR2(4000) PATH '$.ZIP'));

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
                                       t_addr.address_1
                                       || '%'
                                       || t_addr.address_2
                                       || '%'
                                       || t_addr.city
                                       || '%') AS api.udt_objectlist)))
        LOOP
            IF (UPPER(t_addr.address_1) =
                UPPER(
                    api.pkg_columnquery.VALUE(rec.objectid, 'addressline1'))
            AND UPPER(NVL(t_addr.address_2, 'X')) =
                UPPER(
                    NVL(
                        api.pkg_columnquery.VALUE(rec.objectid,
                                                  'addressline2'),
                        'X'))
            AND UPPER(t_addr.city) =
                UPPER(api.pkg_columnquery.VALUE(rec.objectid, 'USACity')))
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
                api.pkg_configquery.endpointidforname('o_Address', 'CACity');

            --****************
            --Add address data
            --****************
            api.pkg_columnupdate.setvalue(t_addressobjectid,
                                          'AddressLine1',
                                          t_addr.address_1);
            api.pkg_columnupdate.setvalue(t_addressobjectid,
                                          'AddressLine2',
                                          t_addr.address_2);
            api.pkg_columnupdate.setvalue(t_addressobjectid,
                                          'ZipCode',
                                          t_addr.zip);

            IF (SUBSTR(t_addr.state, 1, 2) = 'CA')
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
                                   a_value     => t_addr.city)
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
                                              'In USA, Outside CA');

                api.pkg_columnupdate.setvalue(t_addressobjectid,
                                              'USACity',
                                              t_addr.city);

                api.pkg_columnupdate.setvalue(t_addressobjectid,
                                              'USAState',
                                              t_addr.state);
            END IF;
        END IF;

        t_endpointid :=
            api.pkg_configquery.endpointidforname(api.pkg_columnquery.value(a_jobid, 'ObjectDefName'),
                                                  a_address_type);

        t_addrel :=
            api.pkg_relationshipupdate.new(a_endpoint  => t_endpointid,
                                           a_fromobject => a_jobid,
                                           a_toobject  => t_addressobjectid);

        api.pkg_logicaltransactionupdate.endtransaction;
        COMMIT;
    END;

    PROCEDURE add_legal_entities(a_jobid        IN api.pkg_definition.udt_id,
                                 a_legal_entity IN CLOB)
    IS
        t_entity         bizmod_api.utl_licenseinfo.gc_entity_t;
        t_objectdefid    api.pkg_definition.udt_id;
        t_objectid  api.pkg_definition.udt_id;

        t_entitydefid  api.pkg_definition.udt_id;
        t_entityobjectid api.pkg_definition.udt_id;

        t_relid        api.pkg_definition.udt_id;
        t_endpointid   api.pkg_definition.udt_id;
    BEGIN
        SELECT *
          INTO t_entity
          FROM JSON_TABLE(
                   a_legal_entity,
                   '$'
                   COLUMNS(
                       TYPE VARCHAR2(4000) PATH '$.TYPE',
                       first_name VARCHAR2(4000) PATH '$.FIRST_NAME',
                       last_name VARCHAR2(4000) PATH '$.LAST_NAME',
                       owner_type VARCHAR2(4000) PATH '$.OWNER_TYPE',
                       percentage NUMBER PATH '$.PERCENTAGE',
                       address  CLOB
                           FORMAT JSON
                           PATH '$.ADDRESS',
                       legal_entities CLOB
                           FORMAT JSON
                           PATH '$.LEGAL_ENTITIES'));

        -- *****************************************************************
        -- create legal entity for the Application
        -- *****************************************************************
        t_entitydefid :=
            api.pkg_configquery.objectdefidforname('o_legalentity');
        t_entityobjectid := api.pkg_objectupdate.new(t_entitydefid);

        CASE t_entity.TYPE
            WHEN 'PERSON'
            THEN
                -- *****************************************************************
                -- create person object for the application legal entity object
                -- *****************************************************************
                t_objectdefid :=
                    api.pkg_configquery.objectdefidforname('o_person');
                t_objectid := api.pkg_objectupdate.new(t_objectdefid);

                -- create first and last name from regression run
                api.pkg_columnupdate.setvalue(t_objectid,
                                              'FirstName',
                                              t_entity.first_name);
                api.pkg_columnupdate.setvalue(t_objectid,
                                              'LastName',
                                              t_entity.last_name);
                                              
                -- update legal entity with needed information                              
                api.pkg_columnupdate.setvalue(t_entityobjectid,
                                              'dup_lastname',
                                              t_entity.last_name);
                if (t_entity.owner_type not in ('SPOUSE'))
                then                              
                api.pkg_columnupdate.setvalue(t_entityobjectid,
                                              'OwnerType',
                                              t_entity.owner_type);
                api.pkg_columnupdate.setvalue(t_entityobjectid,
                                              'PercentageOfOwnership',
                                              t_entity.percentage);
                  end if;                             
                -- create relationship from person object to legal entity object
                t_endpointid :=
                    api.pkg_configquery.endpointidforname('o_legalentity',
                                                          'Person');
                t_relid :=
                    api.pkg_relationshipupdate.new(t_endpointid,
                                                   t_entityobjectid,
                                                   t_objectid);

                if (t_entity.owner_type is not null)
                then
                    case t_entity.owner_type
                    when 'SPOUSE' then
                        t_endpointid :=
                            api.pkg_configquery.endpointidforname('o_LegalEntity',
                                                                  'Spouse1');

                    WHEN 'GENERAL PARTNER' then
                    null;
                    WHEN 'LIMITED PARTNER' then
                    null;
                    WHEN 'MEMBER' then
                    null;
                    WHEN 'PUBLICLY TRADED' then
                    null;
                    WHEN 'STOCKHOLDER' then
                        t_endpointid :=
                            api.pkg_configquery.endpointidforname('o_LegalEntity',
                                                                  'Stockholder');

                    else
                        NULL;
                    end case;
                end if;
            
            WHEN 'COMPANY'
            THEN
                t_objectdefid :=
                    api.pkg_configquery.objectdefidforname('o_Company');
                t_objectid := api.pkg_objectupdate.new(t_objectdefid);

                api.pkg_columnupdate.setvalue(t_objectid,
                                              'CompanyName',
                                              t_entity.last_name);
                                              
                -- create relationship from company object to legal entity object
                t_endpointid :=
                    api.pkg_configquery.endpointidforname('o_legalentity',
                                                          'Company');
                t_relid :=
                    api.pkg_relationshipupdate.new(t_endpointid,
                                                   t_entityobjectid,
                                                   t_objectid);

            ELSE
                NULL;
        END CASE;

        IF (api.pkg_columnquery.VALUE(a_jobid, 'ObjectDefName') =
            'j_Application')
        THEN
            t_endpointid :=
                api.pkg_configquery.endpointidforname('j_Application',
                                                      'Applicant');
--        ELSE
--            t_endpointid :=
--                api.pkg_configquery.endpointidforname('o_LegalEntity',
--                                                      'Node');
        END IF;

        t_relid :=
            api.pkg_relationshipupdate.new(t_endpointid,
                                           a_jobid,
                                           t_entityobjectid);
                                           
        api.pkg_logicaltransactionupdate.endtransaction;
        COMMIT;

                -- add address to this legal entity
        if (t_entity.address is not null)
        then
                add_address(a_jobid     => t_objectid,
                    a_address_type => 'Address',
                    a_address   => t_entity.address);
        end if;

        IF (t_entity.legal_entities IS NOT NULL)
        THEN
            add_legal_entities(a_jobid     => t_entityobjectid,
                               a_legal_entity => t_entity.legal_entities);
        END IF;
    END;
    
    
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

    
        SELECT appl_type,
               lsp_application_id,
               primary_license_types,
               premise_address,
               mailing_address,
               legal_entities
          INTO t_apprec
          FROM JSON_TABLE(
                   t_packet,
                   '$.DATA'
                   COLUMNS(
                       appl_type VARCHAR2(50) PATH '$.APPL_TYPE',
                       lsp_application_id VARCHAR2(40) PATH '$.LSP_APPLICATION_ID',
                       primary_license_types VARCHAR2(4000)
                           FORMAT JSON
                           PATH '$[*].PRIMARY_LICENSE_TYPES',
                       premise_address VARCHAR2(4000)
                           FORMAT JSON
                           PATH '$.PREMISE_ADDRESS',
                       mailing_address VARCHAR2(4000)
                           FORMAT JSON
                           PATH '$.MAILING_ADDRESS',
                       legal_entities CLOB FORMAT JSON PATH '$.LEGAL_ENTITIES'));

        -- ************************************************************************
        -- Create new application job
        -- ************************************************************************
        t_jobid :=
            api.pkg_objectupdate.new(
                api.pkg_configquery.objectdefidforname('j_Application'));

--        api.pkg_logicaltransactionupdate.endtransaction;
--        COMMIT;

        -- Update required fields on new application
        api.pkg_columnupdate.setvalue(t_jobid,
                                      'ApplicationType',
                                      t_apprec.appl_type);
        api.pkg_columnupdate.setvalue(t_jobid, 'LSPID', t_apprec.lsp_application_id);
        --        api.pkg_columnupdate.setvalue(t_jobid, 'Felony', 'No');
        --        api.pkg_columnupdate.setvalue(t_jobid, 'Violation', 'No');
        --        --            api.pkg_columnupdate.setvalue(t_jobid,
        --        --                                          'CopiesMailed',
        --        --                                          sysdate);
        --        api.pkg_columnupdate.setvalue(t_jobid, 'Fingerprints', 0);
        --
        --        api.pkg_columnupdate.setvalue(t_jobid, 'BusinessPurchasePrice', 0);
        --        api.pkg_columnupdate.setvalue(t_jobid, 'LicensePurchasePrice', 0);
        api.pkg_logicaltransactionupdate.endtransaction;
        COMMIT;

        --                    -- if this is a branch license
        --                    IF (NVL(testcases(i).isbranch, 'N') = 'Y')
        --                    THEN
        --                        -- indicate this is a branch license
        --                        api.pkg_columnupdate.setvalue(t_licensetypeobjectid,
        --                                                      'IsBranchS',
        --                                                      'Y');
        --
        --                        -- setup relationship to master of the branch license using
        --                        --   the information in the t_TransFromLicenseTypeObjectId
        --                        t_endpointidto :=
        --                            api.pkg_configquery.endpointidforname(
        --                                'o_PrimaryLicenseType',
        --                                'MasterLicenseType');
        --                        t_relid :=
        --                            api.pkg_relationshipupdate.new(
        --                                t_endpointidto,
        --                                t_licensetypeobjectid,
        --                                t_transfromlicensetypeobjectid);
        --                    END IF;
        --

        add_primary_license_types(
            a_jobid     => t_jobid,
            a_primary_license_types => t_apprec.primary_license_types);

        add_address(a_jobid     => t_jobid,
                    a_address_type => 'Premises',
                    a_address   => t_apprec.premise_address);

        add_address(a_jobid     => t_jobid,
                    a_address_type => 'MailingAddress',
                    a_address   => t_apprec.mailing_address);

        add_legal_entities(a_jobid        => t_jobid,
                           a_legal_entity => t_apprec.legal_entities);

--        DBMS_OUTPUT.put_line('type: ' || t_apprec.appl_type);
--        DBMS_OUTPUT.put_line(
--            'primary_license_types: ' || t_apprec.primary_license_types);
--        DBMS_OUTPUT.put_line(t_apprec.premise_address);
--        DBMS_OUTPUT.put_line(t_apprec.mailing_address);

        -- "ApplicationCreatedDate" must be set last before save
        api.pkg_columnupdate.setvalue(t_jobid, 'ApplicationCreatedDate', SYSDATE);

        INSERT INTO bizmod_api.license_app_t(lspid,
                                             jobid,
                                             newfee,
                                             createddate)
                 VALUES (
                     t_apprec.lsp_application_id,
                     t_jobid,
                     NULL,
                     SYSDATE);
                     
        sitespecific.pkg_license.generateappexternalfilenum(t_jobid, SYSDATE);
        api.pkg_logicaltransactionupdate.endtransaction;
        COMMIT;

        DBMS_OUTPUT.put_line(
            'Application: '
            || api.pkg_columnquery.VALUE(t_jobid, 'ExternalFileNum')
            || ' *  '
            || CHR(9)
            || t_jobid);
        
        -- notify LSP application has completed
        bizmod_api.pkg_abis.applicationsave(a_objectid => NULL, a_asofdate => sysdate, a_jobid => t_jobid);
        INSERT INTO bizmod_api.e_process_log_t(seq,
                                               processjob,
                                               info,
                                               errmsg,
                                               bktrace)
                 VALUES (
                     a_seq,
                     'CREATELICENSEAPPJOB',
                     'Application Id: '
                     || t_apprec.lsp_application_id
                     || CHR(13)
                     || 'License Number: '
                     || api.pkg_columnquery.VALUE(t_jobid, 'ExternalFileNum')
                     || CHR(13)
                     || 'j_Application: '
                     || t_jobid,
                     t_sqlerrm,
                     t_trace);

        COMMIT;
    END;
END;
/


GRANT EXECUTE ON BIZMOD_API.CREATELICENSEAPPJOB TO POSSEEXTENSIONS;
