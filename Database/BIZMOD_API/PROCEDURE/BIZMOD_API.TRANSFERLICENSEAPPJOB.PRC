CREATE OR REPLACE PROCEDURE BIZMOD_API.transferlicenseappjob(
    a_seq          IN NUMBER,
    a_asofdate     IN DATE)
IS
    -- ****************************************************************************
    -- File:        BIZMOD_API.TRANSFERLICENSEAPPJOB.PRC
    -- Author:      Timothy J. Lord
    --
    -- Purpose :
    --
    -- History:
    -------------------------------------------------------------------------------
    --             Date                         Comment
    --   1.0.2  06/03/2025  TJL  BIZ-18536  Initial Package Created
    --   1.0.3  07/14/2025  TJL  BIZ-18845  Added Person to Person processing
    --   2.0.0  08/04/2025  TJL  BIZ-18987  Added Premise to Premise processing
    --          08/07/2025  TJL  BIZ-19133  Added fiduciary transfers
    -- ****************************************************************************

    TYPE apprec_t IS RECORD(applicationtype VARCHAR2(50),
                            transfertypes VARCHAR2(4000),
                            transferfromlicensenumber VARCHAR2(50),
                            transfertolicensenumber VARCHAR2(50),
                            multiplestockmembershiptrans VARCHAR2(1),
                            lspapplicationid VARCHAR2(40),
                            fiduciarytype VARCHAR2(100),
                            dba VARCHAR2(4000),
                            primarylicensetypes VARCHAR2(4000),
                            premiseaddress VARCHAR2(4000),
                            mailingaddress VARCHAR2(4000),
                            legal_entities CLOB);


    PROCEDURE persontoperson(a_objectid     IN api.pkg_definition.udt_id,
                             a_legal_entities IN CLOB)
    IS
        t_entity       CLOB;
        t_company      CLOB;
        t_person       CLOB;
    BEGIN
        SELECT entity, company, person
          INTO t_entity, t_company, t_person
          FROM JSON_TABLE(
                   a_legal_entities,
                   '$'
                   COLUMNS(entity CLOB FORMAT JSON PATH '$.ENTITY',
                           company CLOB FORMAT JSON PATH '$.COMPANY',
                           person CLOB FORMAT JSON PATH '$.PERSON'));

        IF (t_company IS NOT NULL)
        THEN
            pkg_abis.add_company(a_entityobjectid => a_objectid,
                                 a_legal_entity => t_company);
        END IF;

        IF (t_person IS NOT NULL)
        THEN
            pkg_abis.add_person(a_entityobjectid => a_objectid,
                                a_person    => t_person);
        END IF;

        IF (t_entity IS NOT NULL)
        THEN
            pkg_abis.copy_legal_entities(a_objectid  => a_objectid,
                                         a_legal_entity => t_entity);
        END IF;
    END persontoperson;

    PROCEDURE premisetopremise(a_objectid     IN api.pkg_definition.udt_id,
                               a_premise_addr IN CLOB,
                               a_mailling_addr IN CLOB)
    IS
    BEGIN
        bizmod_api.pkg_abis.add_address(a_jobid     => a_objectid,
                                        a_address_type => 'Premises',
                                        a_address   => a_premise_addr);
        bizmod_api.pkg_abis.add_address(a_jobid     => a_objectid,
                                        a_address_type => 'MailingAddress',
                                        a_address   => a_mailling_addr);
    END premisetopremise;

    PROCEDURE fiduciarytransfer(a_objectid     IN api.pkg_definition.udt_id,
                                a_fiduciarytype IN VARCHAR2,
                                a_legal_entities IN CLOB)
    IS
        t_entity       CLOB;
        t_company      CLOB;
        t_person       CLOB;
        t_entity_object api.pkg_definition.udt_id;
        t_spouse       api.pkg_definition.udt_id;
        t_tmp          api.pkg_definition.udt_id;
    BEGIN
        SELECT entity, company, person
          INTO t_entity, t_company, t_person
          FROM JSON_TABLE(
                   a_legal_entities,
                   '$'
                   COLUMNS(entity CLOB FORMAT JSON PATH '$.ENTITY',
                           company CLOB FORMAT JSON PATH '$.COMPANY',
                           person CLOB FORMAT JSON PATH '$.PERSON'));

        CASE
            WHEN a_fiduciarytype = 'DROP SPOUSE'
            THEN
                t_entity_object :=
                    json_value(t_entity,
                               '$.REMOVELEGALENTITYOBJECTID'
                               RETURNING NUMBER);

                BEGIN
                    -- check if spouse
                    SELECT r.fromobjectid
                      INTO t_spouse
                      FROM api.relationships r
                     WHERE r.fromobjectid = t_entity_object
                       AND r.endpointid =
                           api.pkg_configquery.endpointidforname(
                               'o_LegalEntity',
                               'Spouse1');

                    api.pkg_columnupdate.setvalue(t_entity_object,
                                                  'SpouseDelete',
                                                  'Y');
                    sitespecific.pkg_legalentity.deletespouse(
                        t_entity_object,
                        SYSDATE);
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        api.pkg_errors.raiseerror(
                            -20000,
                            'Legal Entity '
                            || t_entity_object
                            || ' is not a Spouse');
                END;
            WHEN a_fiduciarytype =
                 'DROP PARTNER ' || CHR(38) || ' ADD SPOUSE'
              OR a_fiduciarytype = 'ADD SPOUSE'
            THEN
                IF (a_fiduciarytype =
                    'DROP PARTNER ' || CHR(38) || ' ADD SPOUSE')
                THEN
                    -- code here for drop partner
                    NULL;
                END IF;

                CASE
                    WHEN t_person IS NOT NULL
                    THEN
                        t_entity_object :=
                            json_value(t_person,
                                       '$.LEGALENTITYOBJECTID'
                                       RETURNING NUMBER);
                        bizmod_api.pkg_abis.add_person(
                            a_entityobjectid => t_entity_object,
                            a_person    => t_person);
                    WHEN t_entity IS NOT NULL
                    THEN
                        t_entity_object :=
                            json_value(t_person,
                                       '$.LEGALENTITYOBJECTID'
                                       RETURNING NUMBER);
                        t_spouse :=
                            json_value(t_person,
                                       '$.SPOUSEOBJECTID'
                                       RETURNING NUMBER);

                        t_tmp :=
                            bizmod_api.pkg_abis.create_legalentity(
                                a_parent    => t_entity_object,
                                a_child     => t_spouse,
                                a_endpointid =>
                                    api.pkg_configquery.endpointidforname(
                                        'o_LegalEntity',
                                        'Spouse1'),
                                a_percentageofownership => NULL,
                                a_ownertype => NULL,
                                a_title     => NULL);
                    ELSE
                        api.pkg_errors.raiseerror(
                            -20000,
                            'ADD SPOUSE: No Spouse Information Received');
                END CASE;
            WHEN a_fiduciarytype = 'DROP DECEASED PARTNER'
            THEN
                NULL;
            WHEN a_fiduciarytype = 'TRANSFER BY SURVIVING SPOUSE/PARTNER'
            THEN
                NULL;
            WHEN a_fiduciarytype =
                 'TRANSFER BY ADMINISTRATOR/EXECUTOR/GUARDIAN/COURT ORDER'
            THEN
                NULL;
            WHEN a_fiduciarytype = 'SELF INCORPORATION'
            THEN
                NULL;
            WHEN a_fiduciarytype =
                 'UN-INCORPORATE (DISSOLUTION OF CORPORATION)'
            THEN
                NULL;
            WHEN a_fiduciarytype =
                 'CORPORATION TO CORPORATION (SAME STOCKHOLDERS/NATURAL PERSONS)'
            THEN
                NULL;
            WHEN a_fiduciarytype =
                 'LICENSEE TO LIMITED LIABILITY COMPANY (NO CHANGE IN NATURAL PERSONS)'
            THEN
                NULL;
            WHEN a_fiduciarytype =
                 'TRUSTEE/RECEIVER IN BANKRUPTCY/ASSIGNEE FOR BENEFIT OF CREDITORS/DEBTOR IN POSSESSION'
            THEN
                NULL;
        END CASE;
    END fiduciarytransfer;


    PROCEDURE droppartner(a_objectid     IN api.pkg_definition.udt_id,
                          a_legal_entities IN CLOB)
    IS
        t_entity       CLOB;
        t_entity_object api.pkg_definition.udt_id;
    BEGIN
        SELECT entity
          INTO t_entity
          FROM JSON_TABLE(a_legal_entities,
                          '$'
                          COLUMNS(entity CLOB FORMAT JSON PATH '$.ENTITY'));

        t_entity_object :=
            json_value(t_entity, '$.DROPENTITYOBJECTID' RETURNING NUMBER);

        IF (api.pkg_columnquery.VALUE(t_entity_object, 'IsCompany') = 'Y')
        THEN
            api.pkg_columnupdate.setvalue(t_entity_object,
                                          'CompanyDelete',
                                          'Y');
            sitespecific.pkg_legalentity.deletecompany(t_entity_object,
                                                       SYSDATE);
        ELSE
            api.pkg_columnupdate.setvalue(t_entity_object,
                                          'PersonDelete',
                                          'Y');
            sitespecific.pkg_legalentity.deleteperson(t_entity_object,
                                                      SYSDATE);
        END IF;
    END droppartner;

    PROCEDURE intercountytransfer
    IS
    BEGIN
        NULL;
    END intercountytransfer;
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
        t_transferfromid api.pkg_definition.udt_id;
        t_transfertoid api.pkg_definition.udt_id;
        t_count        NUMBER;
        t_transfertypes json_element_t;
        t_types        json_array_t;
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
               transfertypes,
               transferfromlicensenumber,
               transfertolicensenumber,
               multiplestockmembershiptrans,
               lspid,
               fiduciarytype,
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
                       transfertypes
                           VARCHAR2(4000)
                           FORMAT JSON
                           PATH '$[*].TRANSFERTYPE',
                       transferfromlicensenumber
                           VARCHAR2(50)
                           PATH '$.TRANSFERFROMLICENSENUMBER',
                       transfertolicensenumber
                           VARCHAR2(50)
                           PATH '$.TRANSFERTOLICENSENUMBER',
                       multiplestockmembershiptrans
                           VARCHAR2(1)
                           PATH '$.MULTIPLESTOCKMEMBERSHIPTRANS',
                       lspid VARCHAR2(40) PATH '$.LSPAPPLICATIONID',
                       fiduciarytype VARCHAR2(100) PATH '$.FIDUCIARYTYPE',
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

        IF (t_apprec.transfertypes IS JSON)
        THEN
            t_transfertypes := json_element_t.parse(t_apprec.transfertypes);
            CASE
                WHEN t_transfertypes.is_array
                THEN
                    t_types := TREAT(t_transfertypes AS json_array_t);
                ELSE
                    api.pkg_errors.raiseerror(
                        -20000,
                        'Invalid transfer type(s): '
                        || t_apprec.transfertypes);
            END CASE;
        ELSE
            api.pkg_errors.raiseerror(
                -20000,
                'Invalid transfer type format ');
        END IF;

        t_transferfromid :=
            api.pkg_simplesearch.objectbyindex(
                a_objectdefname => 'j_License',
                a_columnname => 'ExternalFileNum',
                a_lowvalue  => t_apprec.transferfromlicensenumber);

        if (t_transferfromid is null)
        then
                    api.pkg_errors.raiseerror(
                        -20000,
                        'License Number Not Found: '
                        || t_apprec.transferfromlicensenumber);
        end if;
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

        -- update application job to indicate transfer type application
        FOR inx IN 0 .. t_types.get_size - 1
        LOOP
            api.pkg_columnupdate.setvalue(t_jobid,
                                          t_types.get_string(inx),
                                          'Y');
        END LOOP;

        IF (t_apprec.transfertolicensenumber IS NULL)
        THEN
            sitespecific.pkg_license.generateappexternalfilenum(t_jobid,
                                                                SYSDATE);

            api.pkg_columnupdate.setvalue(t_jobid,
                                          'NewLicenseTransferringTo',
                                          'Y');
        ELSE
            t_transfertoid :=
                api.pkg_simplesearch.objectbyindex(
                    a_objectdefname => 'j_License',
                    a_columnname => 'ExternalFileNum',
                    a_lowvalue  => t_apprec.transfertolicensenumber);

            -- create relationship between change application and license being changed
            t_endpointidfrom :=
                api.pkg_configquery.endpointidforname('j_application',
                                                      'LicenseTransferTo');
            t_relid :=
                api.pkg_relationshipupdate.new(t_endpointidfrom,
                                               t_jobid,
                                               t_transfertoid);
        END IF;

        -- create relationship between change application and license being changed
        t_endpointidfrom :=
            api.pkg_configquery.endpointidforname('j_application',
                                                  'LicenseTransfer');
        t_relid :=
            api.pkg_relationshipupdate.new(t_endpointidfrom,
                                           t_jobid,
                                           t_transferfromid);

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

        FOR inx IN 0 .. t_types.get_size - 1
        LOOP
            CASE
                WHEN t_types.get_string(inx) = 'PersonToPerson'
                THEN
                    IF (t_apprec.legal_entities IS NOT NULL)
                    THEN
                        persontoperson(
                            a_objectid  => t_jobid,
                            a_legal_entities => t_apprec.legal_entities);
                    ELSE
                        -- raise error for no legal entity provided

                        NULL;
                    END IF;
                WHEN t_types.get_string(inx) = 'PremiseToPremise'
                THEN
                    IF (t_apprec.premiseaddress IS NOT NULL)
                    THEN
                        premisetopremise(
                            a_objectid  => t_jobid,
                            a_premise_addr => t_apprec.premiseaddress,
                            a_mailling_addr => t_apprec.mailingaddress);
                    END IF;
                WHEN t_types.get_string(inx) = 'FiduciaryTransfer'
                THEN
                    fiduciarytransfer(
                        a_objectid  => t_jobid,
                        a_fiduciarytype => t_apprec.fiduciarytype,
                        a_legal_entities => t_apprec.legal_entities);
                WHEN t_types.get_string(inx) = 'LicenseTypeExchange'
                THEN
                    bizmod_api.pkg_abis.exchange_primary_license_types(
                        a_jobid     => t_jobid,
                        a_primarylicensetypes => t_apprec.primarylicensetypes);
                WHEN t_types.get_string(inx) = 'DropPartner'
                THEN
                    droppartner(a_objectid  => t_jobid,
                                a_legal_entities => t_apprec.legal_entities);
                WHEN t_types.get_string(inx) = 'AddPrimaryLicenseType'
                THEN
                    pkg_abis.add_primary_license_types(
                        a_jobid     => t_jobid,
                        a_primarylicensetypes => t_apprec.primarylicensetypes);
                WHEN t_types.get_string(inx) IN
                         ('ReportedStockTransfer',
                          'MembershipTransfer',
                          'UnreportedStockTransfer',
                          'UnreportedMembershipTransfer')
                THEN
                    bizmod_api.pkg_abis.membership_stock_transfers(
                        a_jobid     => t_jobid,
                        a_legal_entities => t_apprec.legal_entities);
                WHEN t_types.get_string(inx) = 'IntercountyTransfer'
                THEN
                    intercountytransfer;
                ELSE
                    NULL;
            END CASE;
        END LOOP;

        -- "ApplicationCreatedDate" must be set last before save
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
                            'TRANSFERLICENSEAPPJOB',
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
                                'TRANSFERICENSEAPPJOB',
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


GRANT EXECUTE ON BIZMOD_API.TRANSFERLICENSEAPPJOB TO POSSEEXTENSIONS;
