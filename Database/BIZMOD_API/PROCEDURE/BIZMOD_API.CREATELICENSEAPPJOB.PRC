CREATE OR REPLACE PROCEDURE BIZMOD_API.createlicenseappjob(
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
    --             Date                         Comment
    --   1.2    05/09/2024  TJL  BIZ-15800  Initial Package Created
    --   2.1    07/19/2024  TJL  BIZ-16000  Added additional fields for application
    --                                      update.
    --   3.0.1  09/09/2024  TJL  BIZ-16077  Added country to add address process
    --   3.1    10/09/2024  BN   BIZ-16428  Fixed the DBA missing and Duplicate address issue
    --   3.2.0  10/15/2024  TJL             Fixed bug when creating o_Person object (Dup Person)
    --   3.3.0  11/21/2024  TJL  BIZ-16842  Changing code to use ABIS copy entities routines
    --                                       when reference ids are passed
    --                                      Changed how Legal Entity packet is processed
    --   3.4.1  12/11/2024  TJL  BIZ-16842  Added support for Spouses being entered in LSP
    --                                       application.
    --   3.5.0  01/08/2025  TJL  BIZ-17077  Made a changed to person lookup logic.
    --   3.5.1  01/09/2025  TJL  BIZ-17077  Added clearing a variable between person lookup loop.
    --   3.6.0  01/10/2025  TJL             Change handling priority draw license application.
    --   4.0.0  03/04/2025  TJL  BIZ-17503  Adding support for change applications
    --   5.0.0  04/07/2025  TJL  BIZ-17503  Move common procedures between original and change
    --                                        applications to pkg_abis
    --   6.0.0  04/14/2025  TJL  BIZ-17979  Added setting the Alternate Base File Office when
    --                                        Base File Office is HQ
    --   7.0.0  04/30/2025  TJL  BIZ-18052  Added sorting to legal entity
    --   8.0.0  06/05/2025  TJL  BIZ-18536  Added not setting application date for priority draw
    --                                        removed support for transfer applications since
    --                                        that support was moved to a different process
    --   9.0.0  09/17/2025  TJL  BIZ-19069  Added getting hash value for the application
    -- ****************************************************************************

    TYPE apprec_t IS RECORD(lspapplicationid VARCHAR2(40),
                            underconstruction VARCHAR2(3),
                            dba VARCHAR2(4000),
                            felony VARCHAR2(3),
                            violation VARCHAR2(3),
                            licensepurchaseprice NUMBER,
                            primarylicensetypes VARCHAR2(4000),
                            premiseaddress VARCHAR2(4000),
                            mailingaddress VARCHAR2(4000),
                            istemporarymailingaddress VARCHAR2(3),
                            legal_entities CLOB);
BEGIN
    DECLARE
        t_apprec       apprec_t;
        t_packet       CLOB;
        t_sqlerrm      VARCHAR2(4000);
        t_trace        VARCHAR2(4000);
        t_jobid        api.pkg_definition.udt_id;
        t_dbanamesobjectid api.pkg_definition.udt_id;
        t_dbaendpointid api.pkg_definition.udt_id;
        t_primarydraw  VARCHAR2(1);
        t_dba          api.pkg_definition.udt_id;
        t_count        NUMBER;
        t_entity       CLOB;
        t_company      CLOB;
        t_person       CLOB;
        t_rel          api.pkg_definition.udt_id;
        t_officeid     api.pkg_definition.udt_id;
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

        SELECT lspid,
               underconstruction,
               dba,
               felony,
               violation,
               REGEXP_REPLACE(licensepurchaseprice, '[^.[:digit:]]+', ''),
               primary_license_types,
               premise_address,
               mailing_address,
               istemporarymailingaddress,
               legal_entities
          INTO t_apprec
          FROM JSON_TABLE(
                   t_packet,
                   '$.DATA'
                   COLUMNS(
                       lspid VARCHAR2(40) PATH '$.LSPAPPLICATIONID',
                       underconstruction
                           VARCHAR2(3)
                           PATH '$.UNDERCONSTRUCTION',
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
                       istemporarymailingaddress
                           VARCHAR2(3)
                           PATH '$.ISTEMPORARYMAILINGADDRESS',
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


        -- Update required fields on new application
        api.pkg_columnupdate.setvalue(t_jobid, 'ApplicationType', 'Original');
        api.pkg_columnupdate.setvalue(t_jobid,
                                      'LSPID',
                                      t_apprec.lspapplicationid);


        sitespecific.pkg_license.generateappexternalfilenum(t_jobid, SYSDATE);

        api.pkg_logicaltransactionupdate.endtransaction;
        COMMIT;

        -- notify LSP application was created
        bizmod_api.pkg_abis.applicationsave(a_objectid  => NULL,
                                            a_asofdate  => SYSDATE,
                                            a_jobid     => t_jobid);

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

        -- check if priority draw application
        SELECT CASE
                   WHEN (REGEXP_LIKE(
                             (SELECT json_query(
                                         eg.packet,
                                         '$.DATA.PRIMARYLICENSETYPES[*].LICENSETYPECODE'
                                         WITH WRAPPER)    AS licensetypecodes
                                FROM bizmod_api.eservices_log_t eg
                               WHERE eg.seq = a_seq),
                             '21|47'))
                   THEN
                       'Y'
                   ELSE
                       'N'
               END    a
          INTO t_primarydraw
          FROM DUAL;

        IF (t_primarydraw = 'Y')
        THEN
            api.pkg_columnupdate.setvalue(
                t_jobid,
                'PriorityApplicationType',
                api.pkg_columnquery.VALUE(t_jobid, 'ApplicationType'));

            api.pkg_columnupdate.setvalue(t_jobid,
                                          'CopyLicDetailsToAppProcHasRun',
                                          'Y');
            api.pkg_columnupdate.setvalue(t_jobid, 'PriorityUpgrade', 'No');
            api.pkg_columnupdate.setvalue(t_jobid,
                                          'IsPriorityApplication',
                                          'Y');
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

        BEGIN
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

                api.pkg_logicaltransactionupdate.endtransaction;
                COMMIT;
            END IF;
        EXCEPTION
            WHEN OTHERS
            THEN
                t_sqlerrm := SUBSTR(SQLERRM, 1, 3990);
                t_trace :=
                    SUBSTR(DBMS_UTILITY.format_error_backtrace, 1, 3990);

                api.pkg_logicaltransactionupdate.resettransaction;
                ROLLBACK;
        END;

        BEGIN
            IF (t_apprec.legal_entities IS NOT NULL)
            THEN
                SELECT entity, company, person
                  INTO t_entity, t_company, t_person
                  FROM JSON_TABLE(
                           t_apprec.legal_entities,
                           '$'
                           COLUMNS(entity CLOB FORMAT JSON PATH '$.ENTITY',
                                   company CLOB FORMAT JSON PATH '$.COMPANY',
                                   person CLOB FORMAT JSON PATH '$.PERSON'));

                IF (t_entity IS NOT NULL)
                THEN
                    pkg_abis.copy_legal_entities(a_objectid  => t_jobid,
                                                 a_legal_entity => t_entity);
                END IF;

                IF (t_company IS NOT NULL)
                THEN
                    pkg_abis.add_company(a_entityobjectid => t_jobid,
                                         a_legal_entity => t_company);
                END IF;

                IF (t_person IS NOT NULL)
                THEN
                    pkg_abis.add_person(a_entityobjectid => t_jobid,
                                        a_person    => t_person);
                END IF;

                -- 04/30/2025  TJL  BIZ-18052
                -- order legal entities by name after being added to application
                FOR rec
                    IN (SELECT l.legalentity,
                               l.formattedname,
                               ROWNUM * 10     line
                          FROM (  SELECT r.toobjectid            legalentity,
                                         api.pkg_columnquery.VALUE(
                                             r.toobjectid,
                                             'FormattedName')    formattedname
                                    FROM api.relationships r
                                   WHERE r.fromobjectid = t_jobid
                                     AND r.endpointid IN
                                             (api.pkg_configquery.endpointidforname(
                                                  'j_Application',
                                                  'OnSaleManager'),
                                              api.pkg_configquery.endpointidforname(
                                                  'j_Application',
                                                  'Applicant'))
                                ORDER BY formattedname) l)
                LOOP
                    api.pkg_columnupdate.setvalue(rec.legalentity,
                                                  'SortKey',
                                                  rec.line);
                END LOOP;
            END IF;
        EXCEPTION
            WHEN OTHERS
            THEN
                t_sqlerrm := SUBSTR(SQLERRM, 1, 3990);
                t_trace :=
                    SUBSTR(DBMS_UTILITY.format_error_backtrace, 1, 3990);

                api.pkg_logicaltransactionupdate.resettransaction;
                ROLLBACK;
        END;

        BEGIN
            pkg_abis.add_address(a_jobid     => t_jobid,
                                 a_address_type => 'Premises',
                                 a_address   => t_apprec.premiseaddress);

            -- check if base file office is Headquarters
            IF (api.pkg_columnquery.numericvalue(t_jobid, 'BaseFileOfficeId') =
                5554)
            THEN
                BEGIN
                    -- get office for premise address
                    SELECT co.districtofficeid
                      INTO t_officeid
                      FROM api.relationships  r
                           JOIN api.relationships c
                               ON (r.toobjectid = c.fromobjectid
                               AND c.endpointid =
                                   api.pkg_configquery.endpointidforname(
                                       'o_Address',
                                       'CACity'))
                           JOIN bizmod_api.citytooffice_t co
                               ON (co.cacityid = c.toobjectid)
                     WHERE r.endpointid =
                           api.pkg_configquery.endpointidforname(
                               'j_Application',
                               'Premises')
                       AND r.fromobjectid = t_jobid;

                    -- set alternate base file office for premise city
                    api.pkg_columnupdate.setvalue(
                        t_jobid,
                        'IsAlternateBaseFileOffice',
                        'Y');

                    -- add new relationship                (endpointid, fromobjectid, toobjectid)
                    t_rel :=
                        api.pkg_relationshipupdate.new(
                            api.pkg_configquery.endpointidforname(
                                'j_Application',
                                'AlternateBaseFileOffice'),
                            t_jobid,
                            t_officeid);

                    api.pkg_logicaltransactionupdate.endtransaction;
                    COMMIT;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        NULL;
                END;
            END IF;
        EXCEPTION
            WHEN OTHERS
            THEN
                t_sqlerrm := SUBSTR(SQLERRM, 1, 3990);
                t_trace :=
                    SUBSTR(DBMS_UTILITY.format_error_backtrace, 1, 3990);

                api.pkg_logicaltransactionupdate.resettransaction;
                ROLLBACK;
        END;

        BEGIN
            pkg_abis.add_address(a_jobid     => t_jobid,
                                 a_address_type => 'MailingAddress',
                                 a_address   => t_apprec.mailingaddress);

            api.pkg_columnupdate.setvalue(t_jobid,
                                          'IsTemporaryMailingAddress',
                                          t_apprec.istemporarymailingaddress);
        EXCEPTION
            WHEN OTHERS
            THEN
                t_sqlerrm := SUBSTR(SQLERRM, 1, 3990);
                t_trace :=
                    SUBSTR(DBMS_UTILITY.format_error_backtrace, 1, 3990);

                api.pkg_logicaltransactionupdate.resettransaction;
                ROLLBACK;
        END;

        BEGIN
            pkg_abis.add_primary_license_types(
                a_jobid     => t_jobid,
                a_primarylicensetypes => t_apprec.primarylicensetypes);
        EXCEPTION
            WHEN OTHERS
            THEN
                t_sqlerrm := SUBSTR(SQLERRM, 1, 3990);
                t_trace :=
                    SUBSTR(DBMS_UTILITY.format_error_backtrace, 1, 3990);

                api.pkg_logicaltransactionupdate.resettransaction;
                ROLLBACK;
        END;

        IF (t_sqlerrm IS NULL)
        THEN
            BEGIN
                IF (api.pkg_columnquery.VALUE(t_jobid,
                                              'IsPriorityApplication') =
                    'N')
                THEN
                    api.pkg_columnupdate.setvalue(t_jobid,
                                                  'ApplicationCreatedDate',
                                                  SYSDATE);
                END IF;

                api.pkg_logicaltransactionupdate.endtransaction;
                COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    t_sqlerrm := SUBSTR(SQLERRM, 1, 3990);
                    t_trace :=
                        SUBSTR(DBMS_UTILITY.format_error_backtrace, 1, 3990);

                    api.pkg_logicaltransactionupdate.resettransaction;
                    ROLLBACK;
            END;
        END IF;

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

        UPDATE bizmod_api.license_app_t a
           SET a.hashvalue =
                   bizmod_api.utl_licenseinfo.gethashvalueforapplication(
                       a.jobid)
         WHERE a.jobid = t_jobid;

        IF (t_sqlerrm IS NOT NULL)
        THEN
            -- notify LSP application has completed
            bizmod_api.pkg_abis.applicationsave(a_objectid  => NULL,
                                                a_asofdate  => SYSDATE,
                                                a_jobid     => t_jobid,
                                                a_status    => 'ERRORED');
        END IF;

        COMMIT;
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


GRANT EXECUTE ON BIZMOD_API.CREATELICENSEAPPJOB TO ABC;

GRANT EXECUTE ON BIZMOD_API.CREATELICENSEAPPJOB TO POSSEEXTENSIONS;
