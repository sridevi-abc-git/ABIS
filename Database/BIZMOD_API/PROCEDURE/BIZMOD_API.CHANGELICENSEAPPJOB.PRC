CREATE OR REPLACE PROCEDURE bizmod_api.changelicenseappjob(
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
    --   1.0.1  04/03/2025  TJL  BIZ-17503  Initial Package Created
    --   2.0.0  10/02/2025  TJL             Corrected bugs found in regression testing.
    -- ****************************************************************************

    TYPE apprec_t IS RECORD(applicationtype VARCHAR2(50),
                            --                            changetypelist VARCHAR2(1000),
                            changetypes VARCHAR2(1000),
                            changelicensenumber VARCHAR2(50),
                            multiplestockmembershiptrans VARCHAR2(1),
                            lspapplicationid VARCHAR2(40),
                            dba VARCHAR2(4000),
                            primarylicensetypes VARCHAR2(4000),
                            premiseaddress VARCHAR2(4000),
                            mailingaddress VARCHAR2(4000),
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
                               gallonage NUMBER PATH '$.GALLONAGE',
                               numberofmonthslicensed
                                   NUMBER
                                   PATH '$.NUMBEROFMONTHSLICENSED',
                               seasonstartmonth
                                   VARCHAR2(100)
                                   PATH '$.SEASON_START_MONTH',
                               primarycount NUMBER PATH '$.PRIMARYCOUNT',
                               isbranch VARCHAR2(1) PATH '$.ISBRANCH',
                               secondarylicensetypes
                                   VARCHAR2(4000)
                                   FORMAT JSON
                                   PATH '$.SECONDARYLICENSETYPES')))
        LOOP
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
                -- move secondary to new secondary
                t_endpointid :=
                    api.pkg_configquery.endpointidforname(
                        'o_PrimaryLicenseType',
                        'LicTypeCatSecondary');
                t_relid_sec :=
                    api.pkg_relationshipupdate.new(t_endpointid,
                                                   t_licensetypeobjectid,
                                                   sec.toobjectid);
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

                -- check if valid secondary for license type
                IF (INSTR(t_secondaries, sec.licensetypecode) > 0)
                THEN
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
                --                    SELECT DISTINCT
                --                           fs.description,
                --                           (  fs.secondaryamount
                --                            * NVL(sec.primarycount, 1))
                --                               secondaryamount,
                --                           (SELECT g.glaccountid
                --                              FROM api.glaccounts g
                --                             WHERE g.glaccount = fs.feeactivity)
                --                               glaccountid,
                --                           fs.objectid
                --                      INTO t_description,
                --                           t_amount,
                --                           t_glaccountid,
                --                           t_feeschedule
                --                      FROM sitespecific.feeschedule_t  fs
                --                           JOIN sitespecific.feeschedule_t fs2
                --                               ON (NVL(fs.licensetypecode, 'x') =
                --                                   NVL(fs2.licensetypecode, 'x')
                --                               AND NVL(fs.otherfeecode, 'x') =
                --                                   NVL(fs2.otherfeecode, 'x')
                --                               AND NVL(fs.gallonagerange, 'x') =
                --                                   NVL(fs2.gallonagerange, 'x')
                --                               AND NVL(fs.populationrange, 'x') =
                --                                   NVL(fs2.populationrange, 'x')
                --                               AND NVL(fs.numberofmonthslicensed, 'x') =
                --                                   NVL(fs2.numberofmonthslicensed, 'x')
                --                               AND NVL(fs.feetier, 'x') =
                --                                   NVL(fs2.feetier, 'x'))
                --                     WHERE fs.feeactivity = 'DOR'
                --                       AND fs.licensetypecode = sec.licensetypecode
                --                       AND NVL(fs.populationrange, 'x') =
                --                           NVL(
                --                               (SELECT api.pkg_columnquery.VALUE(
                --                                           r.toobjectid,
                --                                           'PopulationRange')
                --                                  FROM api.relationships r
                --                                 WHERE r.fromobjectid = a_jobid
                --                                   AND r.endpointid =
                --                                       api.pkg_configquery.endpointidforname(
                --                                           'j_Application',
                --                                           'Premises')
                --                                   AND t_populationapplies = 'Y'),
                --                               'x')
                --                       AND fs.effectivedate =
                --                           (SELECT MAX(fs2.effectivedate)
                --                              FROM sitespecific.feeschedule_t fs2
                --                             WHERE NVL(fs2.licensetypecode, '0') =
                --                                   NVL(fs.licensetypecode, '0')
                --                               AND fs2.feeactivity = fs.feeactivity
                --                               AND NVL(fs2.gallonagerange, 'x') =
                --                                   NVL(fs.gallonagerange, 'x')
                --                               AND NVL(fs2.populationrange, 'x') =
                --                                   NVL(fs.populationrange, 'x')
                --                               AND NVL(fs2.numberofmonthslicensed, 'x') =
                --                                   NVL(fs.numberofmonthslicensed, 'x')
                --                               AND NVL(fs2.feetier, 'x') =
                --                                   NVL(fs.feetier, 'x')
                --                               AND NVL(fs2.otherfeecode, 'x') =
                --                                   NVL(fs.otherfeecode, 'x')
                --                               AND fs2.effectivedate <= TRUNC(SYSDATE));
                --
                --
                --                    sitespecific.pkg_fees.newfee(
                --                        a_feeid     => t_feeid,
                --                        a_amount    => t_amount,
                --                        a_description => t_description,
                --                        a_glaccountid => t_glaccountid,
                --                        a_jobid     => a_jobid,
                --                        a_taxrateid => NULL,
                --                        a_feeobjid  => t_feeobjid);
                --
                --                    t_relid_sec :=
                --                        api.pkg_relationshipupdate.new(
                --                            api.pkg_configquery.endpointidforname(
                --                                'o_Fee',
                --                                'LicenseFeeSchedule'),
                --                            t_feeobjid,
                --                            t_feeschedule);
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
        END LOOP;

        api.pkg_logicaltransactionupdate.endtransaction;
        COMMIT;
    END;
-- **************************************************************
-- **************************************************************
--   Main Process
-- **************************************************************
-- **************************************************************
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
        t_change_type  VARCHAR2(100);
        t_change_types json_array_t;
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
               --               (select listagg(changetype, ',')
               --                  from json_table (changetype, '$[*]'
               --                     columns (changetype varchar2(100) path '$'))),
               changetype,
               changelicensenumber,
               multiplestockmembershiptrans,
               lspid,
               dba,
               primary_license_types,
               premise_address,
               mailing_address,
               legal_entities
          INTO t_apprec
          FROM JSON_TABLE(
                   t_packet,
                   '$.DATA'
                   COLUMNS(
                       applicationtype VARCHAR2(50) PATH '$.APPLICATIONTYPE',
                       changetype
                           VARCHAR2(1000)
                           FORMAT JSON
                           PATH '$.CHANGETYPE',
                       changelicensenumber
                           VARCHAR2(50)
                           PATH '$.CHANGELICENSENUMBER',
                       multiplestockmembershiptrans
                           VARCHAR2(1)
                           PATH '$.MULTIPLESTOCKMEMBERSHIPTRANS',
                       lspid VARCHAR2(40) PATH '$.LSPAPPLICATIONID',
                       dba VARCHAR2(4000) PATH '$.DBA',
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
        t_change_types := json_array_t.parse(t_apprec.changetypes);

        FOR inx IN 0 .. t_change_types.get_size
        LOOP
            IF (t_change_types.get_string(inx) IS NOT NULL)
            THEN
                api.pkg_columnupdate.setvalue(t_jobid, --'LicenseTypeExchange',
                                              t_change_types.get_string(inx),
                                              'Y');
            END IF;
        END LOOP;

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

        FOR inx IN 0 .. t_change_types.get_size
        LOOP
            t_change_type := t_change_types.get_string(inx);

            CASE
                WHEN t_change_type IN ('AddPrimaryLicenseType')
                THEN
                    pkg_abis.add_primary_license_types(
                        a_jobid     => t_jobid,
                        a_primarylicensetypes => t_apprec.primarylicensetypes);
                WHEN t_change_type IN ('MembershipTransfer', 'StockTransfer')
                THEN
                    SELECT entity, company, person
                      INTO t_entity, t_company, t_person
                      FROM JSON_TABLE(
                               t_apprec.legal_entities,
                               '$'
                               COLUMNS(
                                   entity CLOB FORMAT JSON PATH '$.ENTITY',
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
                       AND api.pkg_columnquery.VALUE(r.toobjectid,
                                                     'LEStructureRel') IN
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
                    api.pkg_columnupdate.setvalue(t_jobid,
                                                  'ApplicationCreatedDate',
                                                  SYSDATE);

                    api.pkg_logicaltransactionupdate.endtransaction;
                    COMMIT;
                WHEN t_change_type IN ('LicenseTypeExchange')
                THEN
                    exchange_primary_license_types(
                        a_jobid     => t_jobid,
                        a_primarylicensetypes => t_apprec.primarylicensetypes);
                ELSE
                    NULL;
            END CASE;
        END LOOP;

        api.pkg_columnupdate.setvalue(t_jobid,
                                      'ApplicationCreatedDate',
                                      SYSDATE);

        api.pkg_logicaltransactionupdate.endtransaction;
        COMMIT;



        INSERT INTO bizmod_api.e_process_log_t(seq,
                                               processjob,
                                               info,
                                               errmsg,
                                               bktrace)
                 VALUES (
                            a_seq,
                            'CHANGELICENSEAPPJOB',
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
                                'CHANGELICENSEAPPJOB',
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


GRANT EXECUTE ON bizmod_api.changelicenseappjob TO posseextensions;