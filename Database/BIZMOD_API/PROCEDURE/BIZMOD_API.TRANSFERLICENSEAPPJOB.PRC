CREATE OR REPLACE PROCEDURE BIZMOD_API.TRANSFERLICENSEAPPJOB(
    a_seq          IN NUMBER,
    a_asofdate     IN DATE)
IS
    -- ****************************************************************************
    -- File:        BIZMOD_API.TRABSFERLICENSEAPPJOB.PRC
    -- Author:      Timothy J. Lord
    --
    -- Purpose :
    --
    -- History:
    -------------------------------------------------------------------------------
    --             Date                         Comment
    --   1.0.2  06/03/2025  TJL  BIZ-18536  Initial Package Created
    --   1.0.3  07/14/2025  TJL  BIZ-18845  Added Person to Person processing
    -- ****************************************************************************

    TYPE apprec_t IS RECORD(applicationtype VARCHAR2(50),
                            transferchangetype VARCHAR2(100),
                            transferfromlicensenumber VARCHAR2(50),
                            transfertolicensenumber VARCHAR2(50),
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
    BEGIN
        NULL;
    END exchange_primary_license_types;


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

    PROCEDURE premisetopremise
    IS
    BEGIN
        NULL;
    END premisetopremise;

    PROCEDURE fiduciarytransfer
    IS
    BEGIN
        NULL;
    END fiduciarytransfer;

    PROCEDURE licensetypeexchange
    IS
    BEGIN
        NULL;
    END licensetypeexchange;

    PROCEDURE droppartner
    IS
    BEGIN
        NULL;
    END droppartner;

    PROCEDURE reportedstocktransfer
    IS
    BEGIN
        NULL;
    END reportedstocktransfer;

    PROCEDURE unreportedstocktransfer
    IS
    BEGIN
        NULL;
    END unreportedstocktransfer;

    PROCEDURE unreportedmembershiptransfer
    IS
    BEGIN
        NULL;
    END unreportedmembershiptransfer;

    PROCEDURE addprimarylicensetype
    IS
    BEGIN
        NULL;
    END addprimarylicensetype;

    PROCEDURE membershiptransfer
    IS
    BEGIN
        NULL;
    END membershiptransfer;

    PROCEDURE stocktransfer
    IS
    BEGIN
        NULL;
    END stocktransfer;

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
        t_transferfromid    api.pkg_definition.udt_id;
        t_transfertoid    api.pkg_definition.udt_id;
        t_count        NUMBER;
--        t_entity       CLOB;
--        t_company      CLOB;
--        t_person       CLOB;
--        t_parent       api.pkg_definition.udt_id;
--        t_item         api.pkg_definition.udt_id;
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
               transferfromlicensenumber,
               transfertolicensenumber,
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
                       transferchangetype
                           VARCHAR2(100)
                           PATH '$.TRANSFERCHANGETYPE',
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

        -- update application job to indicate transfer type application
        api.pkg_columnupdate.setvalue(t_jobid,
                                      t_apprec.transferchangetype,
                                      'Y');
        if (t_apprec.TRANSFERTOLICENSENUMBER is null)
        then
        sitespecific.pkg_license.generateappexternalfilenum(t_jobid, SYSDATE);

        api.pkg_columnupdate.setvalue(t_jobid,
                                      'NewLicenseTransferringTo',
                                      'Y');
        else
            t_transfertoid :=
                api.pkg_simplesearch.objectbyindex(
                    a_objectdefname => 'j_License',
                    a_columnname => 'ExternalFileNum',
                    a_lowvalue  => t_apprec.transfertolicensenumber);

            -- create relationship between change application and license being changed
            t_endpointidfrom :=
                api.pkg_configquery.endpointidforname('j_application', 'LicenseTransferTo');
            t_relid :=
                api.pkg_relationshipupdate.new(t_endpointidfrom,
                                               t_jobid,
                                               t_transferfromid);

        end if;

        t_transferfromid :=
            api.pkg_simplesearch.objectbyindex(
                a_objectdefname => 'j_License',
                a_columnname => 'ExternalFileNum',
                a_lowvalue  => t_apprec.transferfromlicensenumber);

        -- create relationship between change application and license being changed
        t_endpointidfrom :=
            api.pkg_configquery.endpointidforname('j_application', 'LicenseTransfer');
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

        CASE t_apprec.transferchangetype
            WHEN 'PersonToPerson'
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
            WHEN 'PremiseToPremise'
            THEN
                premisetopremise;
            WHEN 'FiduciaryTransfer'
            THEN
                fiduciarytransfer;
            WHEN 'LicenseTypeExchange'
            THEN
                licensetypeexchange;
            WHEN 'DropPartner'
            THEN
                droppartner;
            WHEN 'ReportedStockTransfer'
            THEN
                reportedstocktransfer;
            WHEN 'UnreportedStockTransfer'
            THEN
                unreportedstocktransfer;
            WHEN 'UnreportedMembershipTransfer'
            THEN
                unreportedmembershiptransfer;
            WHEN 'AddPrimaryLicenseType'
            THEN
                addprimarylicensetype;
            WHEN 'MembershipTransfer'
            THEN
                membershiptransfer;
            WHEN 'StockTransfer'
            THEN
                stocktransfer;
            WHEN 'IntercountyTransfer'
            THEN
                intercountytransfer;
            ELSE
                NULL;
        END CASE;


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

    /*
             PROCEDURE   PersonToPerson is begin null; end                   PersonToPerson;
             PROCEDURE   PremiseToPremise  is begin null; end                PremiseToPremise;
             PROCEDURE   FiduciaryTransfer              is begin null; end   FiduciaryTransfer;
             PROCEDURE   LicenseTypeExchange            is begin null; end   LicenseTypeExchange;
             PROCEDURE   DropPartner                    is begin null; end   DropPartner;
             PROCEDURE   ReportedStockTransfer          is begin null; end   ReportedStockTransfer;
             PROCEDURE   UnreportedStockTransfer        is begin null; end   UnreportedStockTransfer;
             PROCEDURE   UnreportedMembershipTransfer   is begin null; end   UnreportedMembershipTransfer;
             PROCEDURE   AddPrimaryLicenseType          is begin null; end   AddPrimaryLicenseType;
             PROCEDURE   MembershipTransfer             is begin null; end   MembershipTransfer;
             PROCEDURE   StockTransfer                  is begin null; end   StockTransfer;
             PROCEDURE   IntercountyTransfer          is begin null; end   IntercountyTransfer;
    */

    /*
                PersonToPerson
                PremiseToPremise
                FiduciaryTransfer
                LicenseTypeExchange
                DropPartner
                ReportedStockTransfer
                UnreportedStockTransfer
                UnreportedMembershipTransfer
                AddPrimaryLicenseType
                MembershipTransfer
                StockTransfer
                IntercountyTransfer
    */

    /*
            IF (t_apprec.transferchangetype IN ('AddPrimaryLicenseType'))
            THEN
                pkg_abis.add_primary_license_types(
                    a_jobid     => t_jobid,
                    a_primarylicensetypes => t_apprec.primarylicensetypes);
            END IF;

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
                api.pkg_columnupdate.setvalue(t_jobid,
                                              'ApplicationCreatedDate',
                                              SYSDATE);

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
    */
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
