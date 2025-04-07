CREATE OR REPLACE PROCEDURE BIZMOD_API.changelicenseappjob(
    a_seq          IN NUMBER,
    a_asofdate     IN DATE)
IS
    -- ****************************************************************************
    -- File:        BIZMOD_API.CHANGELICENSEAPPJOB.PRC
    -- Author:      Timothy J. Lord
    --
    -- Purpose :
    --
    -- History:
    -------------------------------------------------------------------------------
    --             Date                         Comment
    --   1.0.0  04/03/2025  TJL  BIZ-17503  Initial Package Created
    -- ****************************************************************************

    TYPE apprec_t IS RECORD(applicationtype VARCHAR2(50),
                            transferchangetype VARCHAR2(100),
--                            transferfromlicensenumber VARCHAR2(50),
--                            transfertolicensenumber VARCHAR2(50),
                            changelicensenumber VARCHAR2(50),
                            multiplestockmembershiptrans VARCHAR2(1),
                            lspapplicationid VARCHAR2(40),
--                            underconstruction VARCHAR2(3),
                            dba VARCHAR2(4000),
--                            felony VARCHAR2(3),
--                            violation VARCHAR2(3),
--                            licensepurchaseprice NUMBER,
                            primarylicensetypes VARCHAR2(4000),
                            premiseaddress VARCHAR2(4000),
                            mailingaddress VARCHAR2(4000),
--                            istemporarymailingaddress VARCHAR2(3),
--                            attorney CLOB,
--                            escrow CLOB,
                            legal_entities CLOB);

    PROCEDURE exchange_primary_license_types(
        a_jobid        IN api.pkg_definition.udt_id,
        a_primarylicensetypes IN CLOB)
    IS
        t_endpointid   api.pkg_definition.udt_id;
        t_relid        api.pkg_definition.udt_id;
        t_relid_sec    api.pkg_definition.udt_id;
        t_licensetypedefid api.pkg_definition.udt_id;
        t_licensetypecodeobjectid api.pkg_definition.udt_id;
        t_licensetypeobjectid api.pkg_definition.udt_id;
        t_primarylicensetype api.pkg_definition.udt_id;
        t_populationapplies VARCHAR2(1);
        t_secondarytypeobjectid api.pkg_definition.udt_id;
        t_feeid        NUMBER;
        t_amount       NUMBER;
        t_description  VARCHAR2(100);
        t_glaccountid  NUMBER;
        t_feeobjid     NUMBER;
        t_feeschedule  api.pkg_definition.udt_id;
        t_secondaries  VARCHAR2(4000);
    BEGIN
        DBMS_OUTPUT.put_line('exchange_primary_license_types');

        FOR rec
            IN (SELECT *
                  FROM JSON_TABLE(
                           a_primarylicensetypes,
                           '$[*]'
                           COLUMNS(
                               licensetypecode
                                   VARCHAR2(3)
                                   PATH '$.LICENSETYPECODE',
                               exchangelicensetypecode
                                   VARCHAR2(3)
                                   PATH '$.EXCHANGELICENSETYPECODE',
                               --
                               --                       prioritydrawcounty
                               --                           VARCHAR2(100)
                               --                           PATH '$.PRIORITYDRAWCOUNTY',
                               gallonage NUMBER PATH '$.GALLONAGE',
                               numberofmonthslicensed
                                   NUMBER
                                   PATH '$.NUMBEROFMONTHSLICENSED',
                               seasonstartmonth
                                   VARCHAR2(100)
                                   PATH '$.SEASON_START_MONTH',
                               primarycount NUMBER PATH '$.PRIMARYCOUNT',
                               isbranch VARCHAR2(1) PATH '$.ISBRANCH',
                               --                               masterlicense
                               --                                   VARCHAR2(50)
                               --                                   PATH '$.MASTERLICENSE',
                               secondarylicensetypes
                                   VARCHAR2(4000)
                                   FORMAT JSON
                                   PATH '$.SECONDARYLICENSETYPES')))
        LOOP
            DBMS_OUTPUT.put_line('app: ' || a_jobid);
            DBMS_OUTPUT.put_line('ltc: ' || rec.licensetypecode);
            DBMS_OUTPUT.put_line('exc: ' || rec.exchangelicensetypecode);

            SELECT ltc.objectid,
                   ltc.secondarylicensetypecodes,
                   ltc.populationapplies
              INTO t_licensetypecodeobjectid,
                   t_secondaries,
                   t_populationapplies
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

            -- get relationship between application and license type being exchanged
            SELECT r.relationshipid, r.toobjectid
              INTO t_relid, t_primarylicensetype
              FROM api.relationships r
             WHERE r.fromobjectid = a_jobid
               AND r.endpointid =
                   api.pkg_configquery.endpointidforname(
                       'j_Application',
                       'PrimaryLicenseType')
               AND api.pkg_columnquery.VALUE(r.toobjectid, 'LicenseTypeCode') =
                   rec.exchangelicensetypecode;

            -- check if primary has secondary license types
            FOR sec
                IN (SELECT r.*
                      FROM api.relationships r
                     WHERE r.fromobjectid = t_primarylicensetype
                       AND r.endpointid =
                           api.pkg_configquery.endpointidforname(
                               'o_PrimaryLicenseType',
                               'LicTypeCatSecondary'))
            LOOP
                DBMS_OUTPUT.put_line('moving secondary ' || sec.toobjectid);
                -- move secondary to new secondary
                t_endpointid :=
                    api.pkg_configquery.endpointidforname(
                        'o_PrimaryLicenseType',
                        'LicTypeCatSecondary');
                t_relid_sec :=
                    api.pkg_relationshipupdate.new(t_endpointid,
                                                   t_licensetypeobjectid,
                                                   sec.toobjectid);
                DBMS_OUTPUT.put_line('new ');
                api.pkg_columnupdate.setvalue(
                    t_relid_sec,
                    'NewCount',
                    api.pkg_columnquery.numericvalue(sec.relationshipid,
                                                     'NewCount'));

                api.pkg_relationshipupdate.remove(sec.relationshipid);
            END LOOP;

            -- check to see if adding secondary license not moving.
            FOR sec
                IN (SELECT *
                      FROM JSON_TABLE(
                               rec.secondarylicensetypes,
                               '$[*]'
                               COLUMNS(
                                   licensetypecode
                                       VARCHAR2(3)
                                       PATH '$.LICENSETYPECODE',
                                   primarycount NUMBER PATH '$.PRIMARYCOUNT'))
                           j
                     WHERE NOT EXISTS
                               (SELECT r.toobjectid
                                  FROM api.relationships r
                                 WHERE r.fromobjectid = t_primarylicensetype
                                   AND r.endpointid =
                                       api.pkg_configquery.endpointidforname(
                                           'o_PrimaryLicenseType',
                                           'LicTypeCatSecondary')
                                   AND api.pkg_columnquery.VALUE(
                                           r.toobjectid,
                                           'LicenseTypeCode') =
                                       j.licensetypecode))
            LOOP
                SELECT c.objectid
                  INTO t_secondarytypeobjectid
                  FROM query.o_licensetypecategory c
                 WHERE c.licensetypecode = sec.licensetypecode;

                DBMS_OUTPUT.put_line(
                    'before:  '
                    || sec.licensetypecode
                    || '  '
                    || sec.primarycount
                    || '  secs: '
                    || t_secondaries);

                -- check if valid secondary for license type
                IF (INSTR(t_secondaries, sec.licensetypecode) > 0)
                THEN
                    DBMS_OUTPUT.put_line(
                        sec.licensetypecode || '  ' || sec.primarycount);
                    -- create releationship between primary license type and license type catagory
                    t_endpointid :=
                        api.pkg_configquery.endpointidforname(
                            'o_PrimaryLicenseType',
                            'LicTypeCatSecondary');
                    t_relid_sec :=
                        api.pkg_relationshipupdate.new(
                            t_endpointid,
                            t_licensetypeobjectid,
                            t_secondarytypeobjectid);

                    api.pkg_columnupdate.setvalue(t_relid_sec,
                                                  'NewCount',
                                                  NVL(sec.primarycount, 1));

                    -- create manual fee
                    SELECT DISTINCT
                           fs.description,
                           (  fs.secondaryamount
                            * NVL(sec.primarycount, 1))
                               secondaryamount,
                           (SELECT g.glaccountid
                              FROM api.glaccounts g
                             WHERE g.glaccount = fs.feeactivity)
                               glaccountid,
                           fs.objectid
                      INTO t_description,
                           t_amount,
                           t_glaccountid,
                           t_feeschedule
                      FROM sitespecific.feeschedule_t  fs
                           JOIN sitespecific.feeschedule_t fs2
                               ON (NVL(fs.licensetypecode, 'x') =
                                   NVL(fs2.licensetypecode, 'x')
                               AND NVL(fs.otherfeecode, 'x') =
                                   NVL(fs2.otherfeecode, 'x')
                               AND NVL(fs.gallonagerange, 'x') =
                                   NVL(fs2.gallonagerange, 'x')
                               AND NVL(fs.populationrange, 'x') =
                                   NVL(fs2.populationrange, 'x')
                               AND NVL(fs.numberofmonthslicensed, 'x') =
                                   NVL(fs2.numberofmonthslicensed, 'x')
                               AND NVL(fs.feetier, 'x') =
                                   NVL(fs2.feetier, 'x'))
                     WHERE fs.feeactivity = 'DOR'
                       AND fs.licensetypecode = sec.licensetypecode
                       AND NVL(fs.populationrange, 'x') =
                           NVL(
                               (SELECT api.pkg_columnquery.VALUE(
                                           r.toobjectid,
                                           'PopulationRange')
                                  FROM api.relationships r
                                 WHERE r.fromobjectid = a_jobid
                                   AND r.endpointid =
                                       api.pkg_configquery.endpointidforname(
                                           'j_Application',
                                           'Premises')
                                   AND t_populationapplies = 'Y'),
                               'x')
                       AND fs.effectivedate =
                           (SELECT MAX(fs2.effectivedate)
                              FROM sitespecific.feeschedule_t fs2
                             WHERE NVL(fs2.licensetypecode, '0') =
                                   NVL(fs.licensetypecode, '0')
                               AND fs2.feeactivity = fs.feeactivity
                               AND NVL(fs2.gallonagerange, 'x') =
                                   NVL(fs.gallonagerange, 'x')
                               AND NVL(fs2.populationrange, 'x') =
                                   NVL(fs.populationrange, 'x')
                               AND NVL(fs2.numberofmonthslicensed, 'x') =
                                   NVL(fs.numberofmonthslicensed, 'x')
                               AND NVL(fs2.feetier, 'x') =
                                   NVL(fs.feetier, 'x')
                               AND NVL(fs2.otherfeecode, 'x') =
                                   NVL(fs.otherfeecode, 'x')
                               AND fs2.effectivedate <= TRUNC(SYSDATE));


                    sitespecific.pkg_fees.newfee(
                        a_feeid     => t_feeid,
                        a_amount    => t_amount,
                        a_description => t_description,
                        a_glaccountid => t_glaccountid,
                        a_jobid     => a_jobid,
                        a_taxrateid => NULL,
                        a_feeobjid  => t_feeobjid);

                    t_relid_sec :=
                        api.pkg_relationshipupdate.new(
                            api.pkg_configquery.endpointidforname(
                                'o_Fee',
                                'LicenseFeeSchedule'),
                            t_feeobjid,
                            t_feeschedule);
                END IF;
            END LOOP;

            -- remove current primary license type
            api.pkg_relationshipupdate.remove(t_relid);

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
    END exchange_primary_license_types;


    PROCEDURE copy_legal_entities(
        a_objectid     IN api.pkg_definition.udt_id,
        a_legalentityobjectid IN api.pkg_definition.udt_id)
    IS
        t_relid        api.pkg_definition.udt_id;
        t_endpointid   api.pkg_definition.udt_id;
        t_objectid     api.pkg_definition.udt_id;
    BEGIN
        IF (api.pkg_columnquery.VALUE(a_legalentityobjectid, 'P12Status') =
            'Y')
        THEN
            t_endpointid :=
                api.pkg_configquery.endpointidforname('j_Application',
                                                      'P12Applicant');

            t_relid :=
                api.pkg_relationshipupdate.new(t_endpointid,
                                               a_objectid,
                                               a_legalentityobjectid);
        ELSE
            CASE
                WHEN api.pkg_columnquery.VALUE(a_legalentityobjectid,
                                               'LEStructureRel') =
                     'Y'
                THEN
                    t_endpointid :=
                        api.pkg_configquery.endpointidforname(
                            'j_application',
                            'OnSaleManager');
                WHEN api.pkg_columnquery.VALUE(a_legalentityobjectid,
                                               'IsPerson') =
                     'Y'
                THEN
                    t_endpointid :=
                        api.pkg_configquery.endpointidforname(
                            'j_application',
                            'Applicant');
                WHEN api.pkg_columnquery.VALUE(a_legalentityobjectid,
                                               'IsCompany') =
                     'Y'
                THEN
                    t_endpointid :=
                        api.pkg_configquery.endpointidforname(
                            'j_application',
                            'Applicant');
                ELSE
                    NULL;
            END CASE;

            t_endpointid :=
                api.pkg_configquery.endpointidforname('j_Application',
                                                      'Applicant');

            sitespecific.pkg_legalentity.lecopy(
                a_relationshipid => NULL,
                a_copyleobjid => a_legalentityobjectid,
                a_copytoleobjid => a_objectid,
                a_endpointid => t_endpointid,
                a_lookup    => FALSE);

            -- case if company
            IF (api.pkg_columnquery.VALUE(a_legalentityobjectid, 'IsCompany') =
                'Y')
            THEN
                -- get company info to update
                SELECT r.toobjectid
                  INTO t_objectid
                  FROM api.relationships r
                 WHERE r.endpointid IN
                           (api.pkg_configquery.endpointidforname(
                                'o_LegalEntity',
                                'Company'))
                   AND r.fromobjectid = a_legalentityobjectid;
            END IF;
        END IF;
    END copy_legal_entities;

    PROCEDURE remove_entity(
        a_applicationobjectid IN api.pkg_definition.udt_id,
        a_personcompanyobjectid IN api.pkg_definition.udt_id) -- o_legalentity
    AS
        t_endpoint     api.pkg_definition.udt_id
            := api.pkg_configquery.endpointidforname('o_LegalEntity',
                                                     'Title');
        t_rel          api.pkg_definition.udt_id;
        t_titleobjectid api.pkg_definition.udt_id;
    BEGIN
        FOR rec
            IN (SELECT r.toobjectid
                           legalentityobjectid,
                       api.pkg_columnquery.VALUE(r.toobjectid, 'OwnerType')
                           ownertype,
                       api.pkg_columnquery.VALUE(r.toobjectid,
                                                 'OfficerTitles')
                           officertitles,
                       api.pkg_columnquery.VALUE(r.toobjectid,
                                                 'LEStructureRel')
                           lestructurerel
                  FROM api.relationships r
                 WHERE r.fromobjectid =
                       (SELECT r.toobjectid
                          FROM api.relationships r
                         WHERE r.endpointid IN
                                   (api.pkg_configquery.endpointidforname(
                                        'o_legalEntity',
                                        'Company'),
                                    api.pkg_configquery.endpointidforname(
                                        'o_legalEntity',
                                        'Person'))
                           AND r.fromobjectid = a_personcompanyobjectid)
                   AND api.pkg_columnquery.VALUE(r.toobjectid,
                                                 'ApplicationJobId') =
                       a_applicationobjectid
                   AND api.pkg_columnquery.VALUE(r.toobjectid,
                                                 'LEStructureRel') IN
                           ('Stockholder', 'Officer'))
        LOOP
            IF (rec.lestructurerel = 'Stockholder')
            THEN
                api.pkg_columnupdate.setvalue(
                    rec.legalentityobjectid,
                    'OwnerType',
                    CASE rec.ownertype
                        WHEN 'MEMBER' THEN 'FORMER MEMBER'
                        ELSE 'FORMER STOCKHOLDER'
                    END);
            ELSE
                FOR rectitle
                    IN (SELECT r.relationshipid,
                               api.pkg_columnquery.VALUE(r.toobjectid,
                                                         'description')
                          FROM api.relationships r
                         WHERE r.endpointid = t_endpoint
                           AND r.fromobjectid = rec.legalentityobjectid)
                LOOP
                    SELECT objectid
                      INTO t_titleobjectid
                      FROM query.o_title t
                     WHERE description =
                           CASE rec.officertitles
                               WHEN 'GENERAL PARTNER'
                               THEN
                                   'FORMER GENERAL PARTNER'
                               WHEN 'LIMITED PARTNER'
                               THEN
                                   'FORMER LIMITED PARTNER'
                               WHEN 'MANAGER'
                               THEN
                                   'FORMER MANAGER'
                               WHEN 'MEMBER'
                               THEN
                                   'FORMER MEMBER'
                               WHEN 'NAME'
                               THEN
                                   'FORMER NAME'
                               WHEN 'OFFICER'
                               THEN
                                   'FORMER OFFICER'
                               WHEN 'STOCKHOLDER'
                               THEN
                                   'FORMER STOCKHOLDER'
                               WHEN 'TRUSTEE'
                               THEN
                                   'FORMER TRUSTEE'
                               ELSE
                                   'FORMER OFFICER'
                           END;

                    -- create relationship to former title
                    t_rel :=
                        api.pkg_relationshipupdate.new(
                            a_endpoint  => t_endpoint,
                            a_fromobject => rec.legalentityobjectid,
                            a_toobject  => t_titleobjectid);

                    -- remove current relationship
                    api.pkg_relationshipupdate.remove(
                        rectitle.relationshipid);
                END LOOP;
            END IF;
        --    dbms_output.put_line('Description: ' || t_title);



        END LOOP;

        api.pkg_logicaltransactionupdate.endtransaction;
        COMMIT;
    END;
BEGIN
    DECLARE
        t_apprec       apprec_t;
        t_packet       CLOB;
        t_sqlerrm      VARCHAR2(4000);
        t_trace        VARCHAR2(4000);
        t_jobid        api.pkg_definition.udt_id;
        t_endpointidfrom NUMBER;
        t_relid        api.pkg_definition.udt_id;
        t_changelic    api.pkg_definition.udt_id;
        t_count        NUMBER;
        t_entity       CLOB;
        t_company      CLOB;
        t_person       CLOB;
        t_parent       api.pkg_definition.udt_id;
        t_item         api.pkg_definition.udt_id;
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
--               transferfromlicensenumber,
--               transfertolicensenumber,
               changelicensenumber,
               multiplestockmembershiptrans,
               lspid,
--               underconstruction,
               dba,
--               felony,
--               violation,
--               REGEXP_REPLACE(licensepurchaseprice, '[^.[:digit:]]+', ''),
               primary_license_types,
               premise_address,
               mailing_address,
--               istemporarymailingaddress,
--               attorney,
--               escrow,
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
--                       transferfromlicensenumber
--                           VARCHAR2(50)
--                           PATH '$.TRANSFERFROMLICENSENUMBER',
--                       transfertolicensenumber
--                           VARCHAR2(50)
--                           PATH '$.TRANSFERTOLICENSENUMBER',
                       changelicensenumber
                           VARCHAR2(50)
                           PATH '$.CHANGELICENSENUMBER',
                       multiplestockmembershiptrans
                           VARCHAR2(1)
                           PATH '$.MULTIPLESTOCKMEMBERSHIPTRANS',
                       lspid VARCHAR2(40) PATH '$.LSPAPPLICATIONID',
--                       underconstruction
--                           VARCHAR2(3)
--                           PATH '$.UNDERCONSTRUCTION',
                       dba VARCHAR2(4000) PATH '$.DBA',
--                       felony VARCHAR2(3) PATH '$.FELONY',
--                       violation VARCHAR2(3) PATH '$.VIOLATION',
--                       licensepurchaseprice
--                           NUMBER
--                           PATH '$.LICENSEPURCHASEPRICE',
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
--                       istemporarymailingaddress
--                           VARCHAR2(3)
--                           PATH '$.ISTEMPORARYMAILINGADDRESS',
--                       attorney VARCHAR2(4000) FORMAT JSON PATH '$.ATTORNEY',
--                       escrow VARCHAR2(4000) FORMAT JSON PATH '$.ESCROW',
                       legal_entities CLOB FORMAT JSON PATH '$.LEGALENTITIES'));

        -- Check for duplicate key
        SELECT COUNT(*)
          INTO t_count
          FROM bizmod_api.license_app_t la
         WHERE la.lspid = t_apprec.lspapplicationid;

        IF (t_count > 0)
        THEN
            api.pkg_errors.raiseerror(
                -20000,
                'Duplicate LSP Appication Id: ' || t_apprec.lspapplicationid);
        END IF;

        DBMS_OUTPUT.put_line(
            'LSP Application Id: ' || t_apprec.lspapplicationid);
        -- ************************************************************************
        -- Create new application job
        -- ************************************************************************
        t_jobid :=
            api.pkg_objectupdate.new(
                api.pkg_configquery.objectdefidforname('j_Application'));

        DBMS_OUTPUT.put_line('job Id: ' || t_jobid);

        -- Update required fields on new application
        api.pkg_columnupdate.setvalue(t_jobid,
                                      'ApplicationType',
                                      t_apprec.applicationtype);
        api.pkg_columnupdate.setvalue(t_jobid,
                                      'LSPID',
                                      t_apprec.lspapplicationid);

        -- update application job to indicate change type application
        api.pkg_columnupdate.setvalue(t_jobid,
                                      t_apprec.transferchangetype,
                                      'Y');

        t_changelic :=
            api.pkg_simplesearch.objectbyindex(
                a_objectdefname => 'j_License',
                a_columnname => 'ExternalFileNum',
                a_lowvalue  => t_apprec.changelicensenumber);

        -- create relationship between change application and license being changed
        t_endpointidfrom :=
            api.pkg_configquery.endpointidforname('j_application', 'License');
        t_relid :=
            api.pkg_relationshipupdate.new(t_endpointidfrom,
                                           t_jobid,
                                           t_changelic);

        api.pkg_logicaltransactionupdate.endtransaction;
        COMMIT;

        INSERT INTO bizmod_api.license_app_t(lspid,
                                             jobid,
                                             createddate,
                                             licensenumber)
             VALUES (t_apprec.lspapplicationid,
                     t_jobid,
                     SYSDATE,
                     api.pkg_columnquery.VALUE(t_jobid, 'LicenseNumber'));

        api.pkg_logicaltransactionupdate.endtransaction;
        COMMIT;

        --        IF (t_apprec.dba IS NOT NULL)
        --        THEN
        --            t_dbanamesobjectid :=
        --                api.pkg_objectupdate.new(
        --                    api.pkg_configquery.objectdefidforname('o_DBANames'));
        --
        --            api.pkg_columnupdate.setvalue(t_dbanamesobjectid,
        --                                          'DBA',
        --                                          t_apprec.dba);
        --            api.pkg_columnupdate.setvalue(t_dbanamesobjectid,
        --                                          'PrimaryDBA',
        --                                          'Y');
        --
        --            t_dbaendpointid :=
        --                api.pkg_configquery.endpointidforname('j_application',
        --                                                      'DBANames');
        --
        --            t_dba :=
        --                api.pkg_relationshipupdate.new(t_dbaendpointid,
        --                                               t_jobid,
        --                                               t_dbanamesobjectid);
        --        END IF;

        --        -- api.pkg_columnupdate.setvalue(t_jobid, 'PrimaryDBA', t_apprec.dba);
        --        api.pkg_columnupdate.setvalue(t_jobid,
        --                                      'UnderConstruction',
        --                                      t_apprec.underconstruction);
        --        api.pkg_columnupdate.setvalue(t_jobid, 'Felony', t_apprec.felony);
        --        api.pkg_columnupdate.setvalue(t_jobid,
        --                                      'Violation',
        --                                      t_apprec.violation);
        --        api.pkg_columnupdate.setvalue(t_jobid,
        --                                      'LicensePurchasePrice',
        --                                      t_apprec.licensepurchaseprice);
        --        IF (t_apprec.applicationtype IN
        --                ('Transfer', 'Intercounty Transfer', 'Original')
        --         OR t_apprec.transferchangetype IN ('AddPrimaryLicenseType'))

        IF (t_apprec.transferchangetype IN ('AddPrimaryLicenseType'))
        THEN
            pkg_abis.add_primary_license_types(
                a_jobid     => t_jobid,
                a_primarylicensetypes => t_apprec.primarylicensetypes);
        END IF;

        --        add_address(a_jobid     => t_jobid,
        --                    a_address_type => 'Premises',
        --                    a_address   => t_apprec.premiseaddress);
        --
        --        add_address(a_jobid     => t_jobid,
        --                    a_address_type => 'MailingAddress',
        --                    a_address   => t_apprec.mailingaddress);
        --
        --        api.pkg_columnupdate.setvalue(t_jobid,
        --                                      'IsTemporaryMailingAddress',
        --                                      t_apprec.istemporarymailingaddress);
        --
        --        add_attorney(a_jobid => t_jobid, a_attorney => t_apprec.attorney);
        --
        --        add_escrow(a_jobid => t_jobid, a_escrow => t_apprec.escrow);

        DBMS_OUTPUT.put_line('type: ' || t_apprec.transferchangetype);

        IF (t_apprec.transferchangetype IN
                ('MembershipTransfer', 'StockTransfer'))
        THEN
            SELECT entity, company, person
              INTO t_entity, t_company, t_person
              FROM JSON_TABLE(
                       t_apprec.legal_entities,
                       '$'
                       COLUMNS(entity CLOB FORMAT JSON PATH '$.ENTITY',
                               company CLOB FORMAT JSON PATH '$.COMPANY',
                               person CLOB FORMAT JSON PATH '$.PERSON'));

            SELECT r.toobjectid
              INTO t_item
              FROM api.relationships r
             WHERE r.endpointid IN
                       (api.pkg_configquery.endpointidforname(
                            'o_legalEntity',
                            'Company'),
                        api.pkg_configquery.endpointidforname(
                            'o_legalEntity',
                            'Person'))
               AND r.fromobjectid =
                   (SELECT MIN(tbl.removelegalentityobjectid)    removelegalentityobjectid
                      FROM JSON_TABLE(
                               t_entity,
                               '$[*]'
                               COLUMNS(
                                   objectid
                                       NUMBER
                                       PATH '$.LEGALENTITYOBJECTID',
                                   removelegalentityobjectid
                                       NUMBER
                                       PATH '$.REMOVELEGALENTITYOBJECTID'))
                           tbl
                     WHERE tbl.removelegalentityobjectid IS NOT NULL);

            SELECT DISTINCT (SELECT r2.toobjectid
                               FROM api.relationships r2
                              WHERE (r2.endpointid =
                                     api.pkg_configquery.endpointidforname(
                                         'o_legalEntity',
                                         'OfficerParentEntity')
                                  OR r2.endpointid =
                                     api.pkg_configquery.endpointidforname(
                                         'o_legalEntity',
                                         'StockholderParentEntity'))
                                AND r2.fromobjectid = r.toobjectid)    legalentityparentobjectid
              INTO t_parent
              FROM api.relationships r
             WHERE r.fromobjectid = t_item
               AND api.pkg_columnquery.VALUE(r.toobjectid,
                                             'ApplicationJobId') =
                   t_jobid
               AND api.pkg_columnquery.VALUE(r.toobjectid, 'LEStructureRel') IN
                       ('Stockholder', 'Officer');

            IF (t_company IS NOT NULL)
            THEN
                pkg_abis.add_company(a_entityobjectid => t_parent,
                                     a_legal_entity => t_company);
            END IF;

            IF (t_person IS NOT NULL)
            THEN
                pkg_abis.add_person(a_entityobjectid => t_parent,
                                    a_person    => t_person);
            END IF;

            IF (t_entity IS NOT NULL)
            THEN
                FOR entity
                    IN (SELECT *
                          FROM JSON_TABLE(
                                   t_entity,
                                   '$[*]'
                                   COLUMNS(
                                       objectid
                                           NUMBER
                                           PATH '$.LEGALENTITYOBJECTID',
                                       removelegalentityobjectid
                                           NUMBER
                                           PATH '$.REMOVELEGALENTITYOBJECTID')))
                LOOP
                    IF (entity.objectid IS NOT NULL)
                    THEN
                        copy_legal_entities(
                            a_objectid  => t_jobid,
                            a_legalentityobjectid => entity.objectid);
                    END IF;

                    IF (entity.removelegalentityobjectid IS NOT NULL)
                    THEN
                        remove_entity(
                            a_applicationobjectid => t_jobid,
                            a_personcompanyobjectid =>
                                entity.removelegalentityobjectid);
                    END IF;
                END LOOP;
            END IF;

            -- "ApplicationCreatedDate" must be set last before save
            --        api.pkg_columnupdate.setvalue(t_jobid,
            --                                      'ApplicationCreatedDate',
            --                                      SYSDATE);

            api.pkg_logicaltransactionupdate.endtransaction;
            COMMIT;
        END IF;

        IF (t_apprec.applicationtype IN ('Change')
        AND t_apprec.transferchangetype IN ('LicenseTypeExchange'))
        THEN
            exchange_primary_license_types(
                a_jobid     => t_jobid,
                a_primarylicensetypes => t_apprec.primarylicensetypes);
        END IF;


        INSERT INTO bizmod_api.e_process_log_t(seq,
                                               processjob,
                                               info,
                                               errmsg,
                                               bktrace)
                 VALUES (
                            a_seq,
                            'CREATELICENSEAPPCHANGEJOB',
                            'Application Id: '
                            || t_apprec.lspapplicationid
                            || CHR(13)
                            || 'License Number: '
                            || api.pkg_columnquery.VALUE(t_jobid,
                                                         'ExternalFileNum')
                            || CHR(13)
                            || 'j_Application: '
                            || t_jobid,
                            t_sqlerrm,
                            t_trace);

        COMMIT;

        -- dbms_output.put_line('ApplicationSave being called');

        -- notify LSP application has completed
        --        bizmod_api.pkg_abis.applicationsave(a_objectid  => NULL,
        --                                            a_asofdate  => SYSDATE,
        --                                            a_jobid     => t_jobid);
        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            t_sqlerrm := SUBSTR(SQLERRM, 1, 3990);
            t_trace := SUBSTR(DBMS_UTILITY.format_error_backtrace, 1, 3990);

            api.pkg_logicaltransactionupdate.resettransaction;
            ROLLBACK;
            DBMS_OUTPUT.put_line(t_sqlerrm || CHR(13) || t_trace);

            --            bizmod_api.pkg_abis.applicationsave(a_objectid  => NULL,
            --                                                a_asofdate  => SYSDATE,
            --                                                a_jobid     => t_jobid,
            --                                                a_status    => 'ERRORED');

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
                                || t_jobid,
                                t_sqlerrm,
                                t_trace);

            COMMIT;
    END;
END;
/
