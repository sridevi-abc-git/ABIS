/* Formatted on 9/25/2025 8:45:27 AM (QP5 v5.404) */
CREATE OR REPLACE PACKAGE BODY bizmod_api.pkg_abis
AS
    -- **************************************************************************
    -- File:        BIZMOD_API.PKG_ABIS.PKB
    -- Author:      Timothy J. Lord
    --
    -- History:
    -----------------------------------------------------------------------------
    --    Ver:     Date                       Comment
    --     1.2   07/01/2024  TJL BIZ-15808  Move and renamed package from
    --                          (BIZ-15812)   SITESPECIFIC.PKG_CATERING and added
    --                                        new procedures and functions to support
    --                                        License Applications
    --     2.0   09/12/2024  TJL  BIZ-16077  adjusted logging
    --     3.0   09/30/2024  BN   BIZ-16397  ERROR notification to LSP
    --   4.0.0   02/05/2025  TJL  BIZ-17356  Added test in newfee to only send update when
    --                                        new fee is only on applications.
    --   5.0.2   04/03/2025  TJL  BIZ-17503  Added common applications procedures
    --   5.0.3   04/10/2025  TJL  BIZ-17503  Removed updationg company information when
    --                                         doing legal entity copy
    --   6.0.0   05/13/2025  TJL  BIZ-18375  Removed looking up existing companies and persons
    --                                         when company and person information is given in
    --                                         application packet.
    --   7.0.0   05/29/2025  TJL             add_primary_license_types added section code and
    --                                         changed numberofmonthslicensed to a VARCHAR2
    --   8.0.0   06/16/2025  TJL             Added in add_address for priority draw application
    --                                         setting priority draw county. removed priority
    --                                         draw setting from add_primary_license_types
    --   9.0.0   07/17/2025  TJL  BIZ-18875  Added Manual Payments procedure
    --  10.0.0   08/19/2025  TJL  BIZ-19133  Added common procedures used by Change and Transfer
    --                                          Applications
    --  10.1.0   09/15/2025  TJL  BIZ-19212  Added fee_notification procedure.
    --  10.2.0   09/22/2025  BN   BIZ-19170  Gallonage value not getting set issue.
    -- **************************************************************************
    PROCEDURE cateringnotifylsp(a_objectid     api.pkg_definition.udt_id,
                                a_asofdate     DATE)
    IS
        a_scheduleddate DATE := SYSDATE;
        t_cnt          NUMBER := 0;
        t_sqlerrm      VARCHAR2(4000);
        t_trace        VARCHAR2(4000);
    BEGIN
        -- check if online application
        IF (api.pkg_columnquery.VALUE(a_objectid, 'LSPId') IS NOT NULL)
        THEN
            a_scheduleddate :=
                CASE api.pkg_columnquery.VALUE(a_objectid, 'OutCome')
                    -- add 2 minute delay to when job is to run to allow abc-218 to be generated
                    WHEN 'Approved' THEN SYSDATE + ((1 / 24 / 60) * 2)
                    ELSE SYSDATE
                END;

            -- check to see if this application has already been secheuled. This process can be called twice
            --  when application is approved
            SELECT COUNT(s.object)
              INTO t_cnt
              FROM scheduler.sysschedule s
             WHERE s.description =
                   'E-Services Catering Notify LSP Job ' || a_objectid
               AND TRUNC(s.scheduledate) >= TRUNC(SYSDATE)
               AND status IN (1, 3);

            IF (t_cnt = 0)
            THEN
                bizmod_api.utl_licenseinfo.createjob(
                    a_procedure => 'CATERINGNOTIFYLSPJOB',
                    a_description =>
                        'E-Services Catering Notify LSP Job ' || a_objectid,
                    a_argument1 => a_objectid,
                    a_argument2 => a_scheduleddate);
            END IF;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            t_sqlerrm := SQLERRM;
            t_trace := DBMS_UTILITY.format_error_backtrace;

            INSERT INTO bizmod_api.e_process_log_t(seq,
                                                   processjob,
                                                   info,
                                                   errmsg,
                                                   bktrace)
                 VALUES (0,
                         'CATERINGNOTIFYLSP',
                         'Application Id: ' || a_objectid,
                         t_sqlerrm,
                         t_trace);
    END;


    PROCEDURE newfee(a_objectid     IN api.pkg_definition.udt_id,
                     a_asofdate        DATE)
    IS
    BEGIN
        fee_notification(a_objectid  => a_objectid,
                         a_asofdate  => a_asofdate,
                         a_jobid     => a_objectid);
    END;


    PROCEDURE applicationsave(a_objectid     IN api.pkg_definition.udt_id,
                              a_asofdate     IN DATE,
                              a_jobid        IN api.pkg_definition.udt_id,
                              a_status       IN VARCHAR2 DEFAULT NULL)
    IS
        t_sqlerrm      VARCHAR2(4000);
        t_trace        VARCHAR2(4000);
    BEGIN
        IF (api.pkg_columnquery.VALUE(a_jobid, 'LSPId') IS NOT NULL)
        THEN
            bizmod_api.utl_licenseinfo.createjob(
                a_procedure => 'APPLICATIONSAVEJOB',
                a_description =>
                    'Application Saved Notify LSP ID: '
                    || api.pkg_columnquery.VALUE(a_jobid, 'LSPId'),
                a_argument1 => a_objectid,
                a_argument2 => SYSDATE,
                a_argument3 => a_jobid,
                a_argument4 => a_status);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            t_sqlerrm := SQLERRM;
            t_trace := DBMS_UTILITY.format_error_backtrace;

            INSERT INTO bizmod_api.e_process_log_t(seq,
                                                   processjob,
                                                   info,
                                                   errmsg,
                                                   bktrace)
                     VALUES (
                                0,
                                'APPLICATIONSAVE',
                                'Application Object Id: '
                                || a_jobid
                                || CHR(13)
                                || 'Process Id: '
                                || a_objectid,
                                t_sqlerrm,
                                t_trace);
    END;

    PROCEDURE manualpayment(a_objectid     IN api.pkg_definition.udt_id,
                            a_asofdate     IN DATE,
                            a_jobid        IN api.pkg_definition.udt_id)
    IS
        t_sqlerrm      VARCHAR2(4000);
        t_trace        VARCHAR2(4000);
        t_schedule_time DATE;
        t_lspid        NUMBER;
        t_count        NUMBER;
    BEGIN
        t_lspid := api.pkg_columnquery.VALUE(a_jobid, 'LSPId');

        IF (t_lspid IS NOT NULL
        AND api.pkg_columnquery.VALUE(a_jobid, 'ObjectDefName') =
            'j_Application')
        THEN
            -- check if payment made thru LSP
            SELECT COUNT(f.feeid)     cnt
              INTO t_count
          FROM api.relationships  p
               JOIN api.paymenttransactions pt
                   ON (pt.paymentid =
                       api.pkg_columnquery.numericvalue(p.toobjectid,
                                                        'PaymentId'))
               JOIN api.feetransactions f
                   ON (f.transactionid = pt.transactionid) -- in (10971819,10971820))
               JOIN api.registeredexternalobjects reo
                   ON (reo.objectdefid =
                       api.pkg_configquery.objectdefidforname('o_fee')
                   AND reo.linkvalue = TO_CHAR(f.feeid))
         WHERE (p.endpointid =
                api.pkg_configquery.endpointidforname('p_ReceiptPayments',
                                                      'Payment')
            AND p.fromobjectid = a_objectid
            -- 08/07/2025 TJL  BIZ-19030
            AND NOT EXISTS
                    (SELECT p.feeobjid
                       FROM bizmod_api.e_payments_t p
                      WHERE p.feeobjid = reo.objectid));
              
--              FROM api.fees  f
--                   JOIN api.registeredexternalobjects reo
--                       ON (reo.objectdefid =
--                           api.pkg_configquery.objectdefidforname('o_fee')
--                       AND reo.linkvalue = TO_CHAR(f.feeid))
--             WHERE api.pkg_columnquery.VALUE(f.jobid, 'ObjectDefName') =
--                   'j_Application'
--               AND NOT EXISTS
--                       (SELECT p.feeobjid
--                          FROM bizmod_api.e_payments_t p
--                         WHERE p.feeobjid = reo.objectid)
--               AND f.jobid = a_jobid
--               AND f.paidamount != 0;

            IF (t_count > 0)
            THEN
                -- check to see if there is a fee pending notification
                BEGIN
                      SELECT s.scheduledate + (5 / (24 * 60 * 60))
                        INTO t_schedule_time
                        FROM scheduler.sysschedule s
                       WHERE UPPER(s.description) LIKE
                                 UPPER(
                                     'E-Services Fee Notification %ID: '
                                     || t_lspid
                                     || '%')
                         AND s.status = 1
                    ORDER BY s.schedulekey DESC
                       FETCH FIRST ROWS ONLY;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        t_schedule_time := SYSDATE;
                END;

                bizmod_api.utl_licenseinfo.createjob(
                    a_procedure => 'MANUALPAYMENTJOB',
                    a_description =>
                        'Manual Payment for LSP ID: '
                        || api.pkg_columnquery.VALUE(a_jobid, 'LSPId'),
                    a_argument1 => a_objectid,
                    a_argument2 => t_schedule_time,
                    a_argument3 => a_jobid);
            END IF;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            t_sqlerrm := SQLERRM;
            t_trace := DBMS_UTILITY.format_error_backtrace;

            INSERT INTO bizmod_api.e_process_log_t(seq,
                                                   processjob,
                                                   info,
                                                   errmsg,
                                                   bktrace)
                     VALUES (
                                0,
                                'MANUALPAYMENT',
                                'Application Object Id: '
                                || a_jobid
                                || CHR(13)
                                || 'Process Id: '
                                || a_objectid,
                                t_sqlerrm,
                                t_trace);
    END;

    --09/15/2025  TJL  BIZ-19212
    PROCEDURE fee_notification(a_objectid     IN api.pkg_definition.udt_id,
                               a_asofdate     IN DATE,
                               a_jobid        IN api.pkg_definition.udt_id)
    IS
        t_sqlerrm      VARCHAR2(4000);
        t_trace        VARCHAR2(4000);
        t_notify_type  VARCHAR2(100);
        t_description  VARCHAR2(100);
        t_exists       VARCHAR2(1);
    BEGIN
        IF (api.pkg_columnquery.VALUE(a_jobid, 'LSPId') IS NOT NULL)
        THEN
            -- find out type of notification
            t_notify_type :=
                NVL(api.pkg_columnquery.VALUE(a_objectid, 'ModifyType'),
                    'New Fee');
            t_description :=
                'Fee Notification for LSP ID: '
                || api.pkg_columnquery.VALUE(a_jobid, 'LSPId')
                || ' ('
                || t_notify_type
                || ')';

            -- check to see if fee notification job has already been created for this LSP Id
            SELECT NVL2(MAX(s.schedulekey), 'Y', 'N')
              INTO t_exists
              FROM scheduler.sysschedule s
             WHERE status IN (1)
               AND s.description LIKE '%' || t_description || '%';

            IF (t_exists = 'N')
            THEN
                bizmod_api.utl_licenseinfo.createjob(
                    a_procedure => 'FEENOTIFICATIONJOB',
                    a_description => t_description, -- || ' (' || t_notify_type || ')',
                    a_argument1 => a_objectid,
                    a_argument2 => SYSDATE + (5 / (24 * 60 * 60)), -- five second delay
                    a_argument3 => a_jobid);
            END IF;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            t_sqlerrm := SQLERRM;
            t_trace := DBMS_UTILITY.format_error_backtrace;

            INSERT INTO bizmod_api.e_process_log_t(seq,
                                                   processjob,
                                                   info,
                                                   errmsg,
                                                   bktrace)
                     VALUES (
                                0,
                                'FEENOTIFICATION',
                                'Application Object Id: '
                                || a_jobid
                                || CHR(13)
                                || 'a_objectid: '
                                || a_objectid,
                                t_sqlerrm,
                                t_trace);
    END fee_notification;

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
                               primarycount NUMBER PATH '$.PRIMARYCOUNT')))
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
        t_endpointidto NUMBER;
        t_gallonagerange VARCHAR2(15);
        t_additionalmilliongallons NUMBER;
        t_countyobjectid api.pkg_definition.udt_id;
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
                               --                               prioritydrawcounty
                               --                                   VARCHAR2(100)
                               --                                   PATH '$.PRIORITYDRAWCOUNTY',
                               gallonage VARCHAR2(30) PATH '$.GALLONAGERANGE',
                               additionalgallonage
                                   NUMBER
                                   PATH '$.ADDITIONALGALLONAGE',
                               numberofmonthslicensed
                                   VARCHAR2(100)
                                   PATH '$.NUMBEROFMONTHSLICENSED',
                               seasonstartmonth
                                   VARCHAR2(100)
                                   PATH '$.SEASONSTARTMONTH',
                               primarycount NUMBER PATH '$.PRIMARYCOUNT',
                               isbranch VARCHAR2(1) PATH '$.ISBRANCH',
                               masterlicense
                                   VARCHAR2(50)
                                   PATH '$.MASTERLICENSE',
                               sectioncode VARCHAR2(50) PATH '$.SECTIONCODE',
                               secondarylicensetypes
                                   VARCHAR2(4000)
                                   FORMAT JSON
                                   PATH '$.SECONDARYLICENSETYPES')))
        LOOP
            IF (rec.licensetypecode = '48')
            THEN
                rec.licensetypecode := '47';
            END IF;

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

            -- The following is for cases that involved primary draw, gallonage, and seasonal to set
            --   the special values for each type
            CASE
                --                WHEN rec.licensetypecode IN ('21', '47')
                --                THEN
                --                    api.pkg_columnupdate.setvalue(
                --                        a_jobid,
                --                        'PriorityApplicationType',
                --                        api.pkg_columnquery.VALUE(a_jobid, 'ApplicationType'));
                --
                --                    api.pkg_columnupdate.setvalue(
                --                        a_jobid,
                --                        'CopyLicDetailsToAppProcHasRun',
                --                        'Y');
                --                    api.pkg_columnupdate.setvalue(a_jobid,
                --                                                  'PriorityUpgrade',
                --                                                  'No');
                --                    api.pkg_columnupdate.setvalue(a_jobid,
                --                                                  'IsPriorityApplication',
                --                                                  'Y');
                --
                --                    -- *****************************************************************
                --                    -- Add priority Draw County and license type
                --                    -- *****************************************************************
                --                    -- set priority draw county
                --                    t_countyobjectid :=
                --                        api.pkg_simplesearch.objectbyindex(
                --                            'o_CaCounty',
                --                            'CountyName',
                --                            rec.prioritydrawcounty);
                --
                --                    IF (t_countyobjectid IS NOT NULL)
                --                    THEN
                --                        t_endpointid :=
                --                            api.pkg_configquery.endpointidforname(
                --                                'j_application',
                --                                'PriorityCounty');
                --                        t_relid :=
                --                            api.pkg_relationshipupdate.new(t_endpointid,
                --                                                           a_jobid,
                --                                                           t_countyobjectid);
                --                    END IF;
                WHEN rec.licensetypecode IN ('02', '22')
                THEN
                    IF (rec.gallonage IS NOT NULL)
                    THEN
                        t_gallonagerange := rec.gallonage;
                    ELSE
                        t_gallonagerange := '200K TO 1M';
                    END IF;

                    IF (rec.additionalgallonage > 0)
                    THEN
                        api.pkg_columnupdate.setvalue(
                            t_licensetypeobjectid,
                            'AdditionalMillionGallons',
                            rec.additionalgallonage);
                    ELSE
                        api.pkg_columnupdate.removevalue(
                            t_licensetypeobjectid,
                            'AdditionalMillionGallons');
                    END IF;

                    api.pkg_columnupdate.setvalue(t_licensetypeobjectid,
                                                  'GallonageRange',
                                                  t_gallonagerange);
                WHEN rec.licensetypecode = '99'
                THEN
                    api.pkg_columnupdate.setvalue(t_licensetypeobjectid,
                                                  'SectionCodeList',
                                                  rec.sectioncode);
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
        t_countyobjectid api.pkg_definition.udt_id;
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

            -- add priority draw county if application is a priority draw
            IF (api.pkg_columnquery.VALUE(a_jobid, 'IsPriorityApplication') =
                'Y'
            AND a_address_type = 'Premises')
            THEN
                -- *****************************************************************
                -- Add priority Draw County
                -- *****************************************************************
                -- get county name

                -- set priority draw county
                t_countyobjectid :=
                    api.pkg_columnquery.numericvalue(t_addressobjectid,
                                                     'CountyId');

                IF (t_countyobjectid IS NOT NULL)
                THEN
                    t_endpointid :=
                        api.pkg_configquery.endpointidforname(
                            'j_application',
                            'PriorityCounty');
                    t_addrel :=
                        api.pkg_relationshipupdate.new(t_endpointid,
                                                       a_jobid,
                                                       t_countyobjectid);
                END IF;

                api.pkg_logicaltransactionupdate.endtransaction;
                COMMIT;
            END IF;
        END IF;
    END add_address;

    PROCEDURE add_title(a_entityobjectid IN api.pkg_definition.udt_id,
                        a_legal_entity IN CLOB)
    IS
        t_objectdefid  api.pkg_definition.udt_id;
        t_objectid     api.pkg_definition.udt_id;

        t_relid        api.pkg_definition.udt_id;
        t_endpointid   api.pkg_definition.udt_id;
    BEGIN
        FOR rec
            IN (SELECT *
                  FROM JSON_TABLE(
                           a_legal_entity,
                           '$[*]'
                           COLUMNS(description VARCHAR2(4000) PATH '$')))
        LOOP
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

    PROCEDURE copy_legal_entities(
        a_objectid     IN api.pkg_definition.udt_id,
        a_legal_entity IN CLOB)
    IS
        t_relid        api.pkg_definition.udt_id;
        t_endpointid   api.pkg_definition.udt_id;
    BEGIN
        IF (a_legal_entity IS NOT NULL)
        THEN
            FOR entity
                IN (SELECT *
                      FROM JSON_TABLE(
                               a_legal_entity,
                               '$[*]'
                               COLUMNS(
                                   objectid
                                       NUMBER
                                       PATH '$.LEGALENTITYOBJECTID')))
            LOOP
                IF (api.pkg_columnquery.VALUE(entity.objectid, 'P12Status') =
                    'Y')
                THEN
                    t_endpointid :=
                        api.pkg_configquery.endpointidforname(
                            'j_Application',
                            'P12Applicant');

                    t_relid :=
                        api.pkg_relationshipupdate.new(t_endpointid,
                                                       a_objectid,
                                                       entity.objectid);
                ELSE
                    CASE
                        WHEN api.pkg_columnquery.VALUE(entity.objectid,
                                                       'LEStructureRel') =
                             'Y'
                        THEN
                            t_endpointid :=
                                api.pkg_configquery.endpointidforname(
                                    'j_application',
                                    'OnSaleManager');
                        WHEN api.pkg_columnquery.VALUE(entity.objectid,
                                                       'IsPerson') =
                             'Y'
                        THEN
                            t_endpointid :=
                                api.pkg_configquery.endpointidforname(
                                    'j_application',
                                    'Applicant');
                        WHEN api.pkg_columnquery.VALUE(entity.objectid,
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
                        api.pkg_configquery.endpointidforname(
                            'j_Application',
                            'Applicant');

                    sitespecific.pkg_legalentity.lecopy(
                        a_relationshipid => NULL,
                        a_copyleobjid => entity.objectid,
                        a_copytoleobjid => a_objectid,
                        a_endpointid => t_endpointid,
                        a_lookup    => FALSE);
                END IF;
            END LOOP;

            api.pkg_logicaltransactionupdate.endtransaction;
            COMMIT;
        END IF;
    END copy_legal_entities;

    PROCEDURE add_attorney(a_jobid        IN api.pkg_definition.udt_id,
                           a_attorney     IN CLOB)
    IS
        t_objectdefid  api.pkg_definition.udt_id;
        t_objectid     api.pkg_definition.udt_id;

        t_relid        api.pkg_definition.udt_id;
        t_list         api.udt_objectlist;
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
                SELECT api.udt_object(objectid)
                  BULK COLLECT INTO t_list
                  FROM TABLE(
                           CAST(
                               api.pkg_simplesearch.castableobjectsbyindex(
                                   a_objectdefname => 'o_Attorney',
                                   a_columnname => 'FirmName',
                                   a_value     => rec.firmname)
                                   AS api.udt_objectlist));

                CASE t_list.COUNT
                    WHEN 0
                    THEN
                        t_objectid := NULL;
                    WHEN 1
                    THEN
                        t_objectid := t_list(1).objectid;
                    ELSE
                        -- find the first attorney that matches name
                        FOR inx IN 1 .. t_list.COUNT
                        LOOP
                            t_objectid := t_list(inx).objectid;

                            IF (UPPER(rec.firstname) =
                                UPPER(
                                    api.pkg_columnquery.VALUE(t_objectid,
                                                              'FirstName'))
                            AND UPPER(rec.lastname) =
                                UPPER(
                                    api.pkg_columnquery.VALUE(t_objectid,
                                                              'LastName')))
                            THEN
                                EXIT;
                            END IF;

                            t_objectid := NULL;
                        END LOOP;
                END CASE;

                IF (t_objectid IS NULL)
                THEN
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
                    api.pkg_columnupdate.setvalue(t_objectid,
                                                  'Email',
                                                  rec.email);

                    IF (rec.address IS NOT NULL)
                    THEN
                        add_address(a_jobid     => t_objectid,
                                    a_address_type => 'Address',
                                    a_address   => rec.address);
                    END IF;
                END IF;

                t_relid :=
                    api.pkg_relationshipupdate.new(
                        api.pkg_configquery.endpointidforname(
                            'j_Application',
                            'Attorney'),
                        a_jobid,
                        t_objectid);

                api.pkg_logicaltransactionupdate.endtransaction;
                COMMIT;
            END LOOP;
        END IF;
    END add_attorney;

    PROCEDURE add_escrow(a_jobid        IN api.pkg_definition.udt_id,
                         a_escrow       IN CLOB)
    IS
        t_objectdefid  api.pkg_definition.udt_id;
        t_objectid     api.pkg_definition.udt_id;
        t_relid        api.pkg_definition.udt_id;
        t_list         api.udt_objectlist;
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
                SELECT api.udt_object(objectid)
                  BULK COLLECT INTO t_list
                  FROM TABLE(
                           CAST(
                               api.pkg_simplesearch.castableobjectsbyindex(
                                   a_objectdefname => 'o_Escrow',
                                   a_columnname => 'EscrowCompanyName',
                                   a_value     => rec.escrowcompanyname)
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
                END CASE;

                IF (t_objectid IS NULL)
                THEN
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
                END IF;

                t_relid :=
                    api.pkg_relationshipupdate.new(
                        api.pkg_configquery.endpointidforname(
                            'j_Application',
                            'Escrow'),
                        a_jobid,
                        t_objectid);

                api.pkg_logicaltransactionupdate.endtransaction;
                COMMIT;
            END LOOP;
        END IF;
    END add_escrow;

    FUNCTION create_legalentity(a_parent       IN api.pkg_definition.udt_id,
                                a_child        IN api.pkg_definition.udt_id,
                                a_endpointid   IN api.pkg_definition.udt_id,
                                a_percentageofownership IN VARCHAR2,
                                a_ownertype    IN VARCHAR2,
                                a_title        IN VARCHAR2)
        RETURN api.pkg_definition.udt_id
    IS
        t_relid        api.pkg_definition.udt_id;
        t_entityobjectid api.pkg_definition.udt_id;
        t_hierarchylevel NUMBER;
    BEGIN
        IF (api.pkg_columnquery.VALUE(a_parent, 'ObjectDefName') =
            'j_Application')
        THEN
            t_hierarchylevel := 1;
        ELSE
            t_hierarchylevel :=
                  api.pkg_columnquery.numericvalue(a_parent,
                                                   'HierarchyLevel_Stored')
                + 1;
        END IF;

        t_entityobjectid :=
            api.pkg_objectupdate.new(
                api.pkg_configquery.objectdefidforname('o_LegalEntity'));

        -- add relation ship to parent legal entity
        t_relid :=
            api.pkg_relationshipupdate.new(a_endpointid,
                                           a_parent,
                                           t_entityobjectid);

        -- add information to legal entity just created
        api.pkg_columnupdate.setvalue(t_entityobjectid,
                                      'HierarchyLevel_Stored',
                                      t_hierarchylevel);

        api.pkg_columnupdate.setvalue(t_entityobjectid,
                                      'dup_HierarchyLevel',
                                      t_hierarchylevel);

        IF (a_percentageofownership IS NOT NULL)
        THEN
            api.pkg_columnupdate.setvalue(t_entityobjectid,
                                          'OwnerType',
                                          a_ownertype);
            api.pkg_columnupdate.setvalue(t_entityobjectid,
                                          'PercentageOfOwnership',
                                          a_percentageofownership);
        END IF;

        IF (a_title IS NOT NULL)
        THEN
            pkg_abis.add_title(a_entityobjectid => t_entityobjectid,
                               a_legal_entity => a_title);
        END IF;

        api.pkg_columnupdate.setvalue(
            t_entityobjectid,
            'dup_LastName',
            api.pkg_columnquery.VALUE(a_child, 'LastName'));
        api.pkg_columnupdate.setvalue(
            t_entityobjectid,
            'dup_FormattedName',
            api.pkg_columnquery.VALUE(a_child, 'FormattedName'));

        -- add relation ship to parent legal entity
        t_relid :=
            api.pkg_relationshipupdate.new(
                api.pkg_configquery.endpointidforname(
                    'o_legalentity',
                    SUBSTR(
                        api.pkg_columnquery.VALUE(a_child, 'ObjectDefName'),
                        3)),
                t_entityobjectid,
                a_child);
        api.pkg_logicaltransactionupdate.endtransaction;
        COMMIT;

        RETURN t_entityobjectid;
    END create_legalentity;


    PROCEDURE add_person(a_entityobjectid IN api.pkg_definition.udt_id,
                         a_person       IN CLOB)
    IS
        t_objectdefid  api.pkg_definition.udt_id;
        t_objectid     api.pkg_definition.udt_id;
        t_newentity    api.pkg_definition.udt_id;
    BEGIN
        FOR rec
            IN (SELECT j.*
                  FROM JSON_TABLE(
                           a_person,
                           '$[*]'
                           COLUMNS(
                               ownertype VARCHAR2(4000) PATH '$.OWNERTYPE',
                               title CLOB FORMAT JSON PATH '$.TITLE',
                               onsalemanager
                                   VARCHAR2(4000)
                                   PATH '$.ONSALEMANAGER',
                               percentageofownership
                                   NUMBER
                                   PATH '$.PERCENTAGEOFOWNERSHIP',
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
                               passportnumber
                                   VARCHAR2(4000)
                                   PATH '$.PASSPORTNUMBER',
                               gender VARCHAR2(4000) PATH '$.GENDER',
                               birthdate DATE PATH '$.BIRTHDATE',
                               birthcity VARCHAR2(4000) PATH '$.BIRTHCITY',
                               birthstate VARCHAR2(4000) PATH '$.BIRTHSTATE',
                               birthcountry
                                   VARCHAR2(4000)
                                   PATH '$.BIRTHCOUNTRY',
                               maritalstatus
                                   VARCHAR2(4000)
                                   PATH '$.MARITALSTATUS',
                               address CLOB FORMAT JSON PATH '$.ADDRESS',
                               person CLOB FORMAT JSON PATH '$.PERSON')) j)
        LOOP
            -- *****************************************************************
            -- Create Person object
            -- *****************************************************************
            t_objectdefid :=
                api.pkg_configquery.objectdefidforname('o_Person');
            t_objectid := api.pkg_objectupdate.new(t_objectdefid);

            -- create first and last name from regression run
            api.pkg_columnupdate.setvalue(t_objectid,
                                          'FirstName',
                                          rec.firstname);
            api.pkg_columnupdate.setvalue(t_objectid,
                                          'MiddleName',
                                          rec.middlename);
            api.pkg_columnupdate.setvalue(t_objectid,
                                          'LastName',
                                          rec.lastname);
            api.pkg_columnupdate.setvalue(t_objectid, 'Suffix', rec.suffix);
            api.pkg_columnupdate.setvalue(t_objectid,
                                          'AliasNames',
                                          rec.aliasnames);
            api.pkg_columnupdate.setvalue(t_objectid,
                                          'SocialSecurityNumber',
                                          rec.socialsecuritynumber);
            api.pkg_columnupdate.setvalue(t_objectid,
                                          'DriversLicenseNumber',
                                          rec.driverslicensenumber);
            api.pkg_columnupdate.setvalue(t_objectid,
                                          'DriversLicenseState',
                                          rec.driverslicensestate);
            api.pkg_columnupdate.setvalue(t_objectid,
                                          'PassportNumber',
                                          rec.passportnumber);
            api.pkg_columnupdate.setvalue(t_objectid, 'Gender', rec.gender);
            api.pkg_columnupdate.setvalue(t_objectid,
                                          'BirthDate',
                                          rec.birthdate);
            api.pkg_columnupdate.setvalue(t_objectid,
                                          'BirthCity',
                                          rec.birthcity);
            api.pkg_columnupdate.setvalue(t_objectid,
                                          'BirthState',
                                          rec.birthstate);
            api.pkg_columnupdate.setvalue(t_objectid,
                                          'BirthCountry',
                                          rec.birthcountry);
            api.pkg_columnupdate.setvalue(t_objectid,
                                          'MaritalStatus',
                                          rec.maritalstatus);

            -- check if applicant
            IF (api.pkg_columnquery.VALUE(a_entityobjectid, 'ObjectDefName') =
                'j_Application')
            THEN
                t_newentity :=
                    create_legalentity(
                        a_parent    => a_entityobjectid,
                        a_child     => t_objectid,
                        a_endpointid =>
                            CASE rec.onsalemanager
                                WHEN 'Y'
                                THEN
                                    api.pkg_configquery.endpointidforname(
                                        'j_Application',
                                        'OnSaleManager')
                                ELSE
                                    api.pkg_configquery.endpointidforname(
                                        'j_Application',
                                        'Applicant')
                            END,
                        a_percentageofownership => rec.percentageofownership,
                        a_ownertype => rec.ownertype,
                        a_title     => rec.title);

                IF (rec.person IS NOT NULL)
                THEN
                    add_person(a_entityobjectid => t_newentity,
                               a_person    => rec.person);
                END IF;
            ELSE
                IF (api.pkg_columnquery.VALUE(a_entityobjectid, 'IsAPerson') =
                    'Y')
                THEN
                    t_newentity :=
                        create_legalentity(
                            a_parent    => a_entityobjectid,
                            a_child     => t_objectid,
                            a_endpointid =>
                                api.pkg_configquery.endpointidforname(
                                    'o_LegalEntity',
                                    'Spouse1'),
                            a_percentageofownership =>
                                rec.percentageofownership,
                            a_ownertype => rec.ownertype,
                            a_title     => rec.title);

                    IF (rec.person IS NOT NULL)
                    THEN
                        add_person(a_entityobjectid => t_newentity,
                                   a_person    => rec.person);
                    END IF;
                ELSE
                    IF (rec.percentageofownership IS NOT NULL)
                    THEN
                        t_newentity :=
                            create_legalentity(
                                a_parent    => a_entityobjectid,
                                a_child     => t_objectid,
                                a_endpointid =>
                                    api.pkg_configquery.endpointidforname(
                                        'o_LegalEntity',
                                        'StockHolder'),
                                a_percentageofownership =>
                                    rec.percentageofownership,
                                a_ownertype => rec.ownertype,
                                a_title     => NULL); --rec.title);

                        IF (rec.person IS NOT NULL)
                        THEN
                            add_person(a_entityobjectid => t_newentity,
                                       a_person    => rec.person);
                        END IF;
                    END IF;

                    IF (LENGTH(NVL(rec.title, '[]')) > 3)
                    THEN
                        t_newentity :=
                            create_legalentity(
                                a_parent    => a_entityobjectid,
                                a_child     => t_objectid,
                                a_endpointid =>
                                    api.pkg_configquery.endpointidforname(
                                        'o_LegalEntity',
                                        'Officer'),
                                a_percentageofownership => NULL,
                                a_ownertype => NULL,
                                a_title     => rec.title);

                        IF (rec.person IS NOT NULL)
                        THEN
                            add_person(a_entityobjectid => t_newentity,
                                       a_person    => rec.person);
                        END IF;
                    END IF;
                END IF;
            END IF;
        END LOOP;

        api.pkg_logicaltransactionupdate.endtransaction;
        COMMIT;
    END add_person;

    PROCEDURE add_company(a_entityobjectid IN api.pkg_definition.udt_id,
                          a_legal_entity IN CLOB)
    IS
        t_objectdefid  api.pkg_definition.udt_id;
        t_objectid     api.pkg_definition.udt_id;
        t_newentity    api.pkg_definition.udt_id;
    BEGIN
        FOR rec
            IN (SELECT *
                  FROM JSON_TABLE(
                           a_legal_entity,
                           '$[*]'
                           COLUMNS(
                               ownertype VARCHAR2(4000) PATH '$.OWNERTYPE',
                               title CLOB FORMAT JSON PATH '$.TITLE',
                               lestructurerel
                                   VARCHAR2(4000)
                                   PATH '$.LESTRUCTUREREL',
                               percentageofownership
                                   NUMBER
                                   PATH '$.PERCENTAGEOFOWNERSHIP',
                               companyname
                                   VARCHAR2(4000)
                                   PATH '$.COMPANYNAME',
                               companystructure
                                   VARCHAR2(4000)
                                   PATH '$.COMPANYSTRUCTURE',
                               dateofincorporation
                                   DATE
                                   PATH '$.DATEOFINCORPORATION',
                               stateofincorporation
                                   VARCHAR2(4000)
                                   PATH '$.STATEOFINCORPORATION',
                               casecretaryofstatenumber
                                   VARCHAR2(4000)
                                   PATH '$.CASECRETARYOFSTATENUMBER',
                               federalemployeridentificationn
                                   VARCHAR2(4000)
                                   PATH '$.FEDERALEMPLOYERIDENTIFICATIONN',
                               address CLOB FORMAT JSON PATH '$.ADDRESS',
                               company CLOB FORMAT JSON PATH '$.COMPANY',
                               person CLOB FORMAT JSON PATH '$.PERSON')))
        LOOP
            t_objectdefid :=
                api.pkg_configquery.objectdefidforname('o_Company');
            t_objectid := api.pkg_objectupdate.new(t_objectdefid);

            api.pkg_columnupdate.setvalue(t_objectid,
                                          'CompanyName',
                                          rec.companyname);
            api.pkg_columnupdate.setvalue(t_objectid,
                                          'CompanyStructure',
                                          rec.companystructure);
            api.pkg_columnupdate.setvalue(t_objectid,
                                          'DateOfIncorporation',
                                          rec.dateofincorporation);
            api.pkg_columnupdate.setvalue(t_objectid,
                                          'StateoFinCorporation',
                                          rec.stateofincorporation);
            api.pkg_columnupdate.setvalue(t_objectid,
                                          'CaSecretaryOfStateNumber',
                                          rec.casecretaryofstatenumber);
            api.pkg_columnupdate.setvalue(t_objectid,
                                          'FederalEmployerIdentificationN',
                                          rec.federalemployeridentificationn);

            api.pkg_logicaltransactionupdate.endtransaction;
            COMMIT;

            IF (api.pkg_columnquery.VALUE(a_entityobjectid, 'ObjectDefName') =
                'j_Application')
            THEN
                t_newentity :=
                    create_legalentity(
                        a_parent    => a_entityobjectid,
                        a_child     => t_objectid,
                        a_endpointid =>
                            api.pkg_configquery.endpointidforname(
                                'j_Application',
                                'Applicant'),
                        a_percentageofownership => rec.percentageofownership,
                        a_ownertype => rec.ownertype,
                        a_title     => rec.title);

                IF (rec.company IS NOT NULL)
                THEN
                    add_company(a_entityobjectid => t_newentity,
                                a_legal_entity => rec.company);
                END IF;

                IF (rec.person IS NOT NULL)
                THEN
                    add_person(a_entityobjectid => t_newentity,
                               a_person    => rec.person);
                END IF;
            ELSE
                IF (rec.percentageofownership IS NOT NULL)
                THEN
                    t_newentity :=
                        create_legalentity(
                            a_parent    => a_entityobjectid,
                            a_child     => t_objectid,
                            a_endpointid =>
                                api.pkg_configquery.endpointidforname(
                                    'o_LegalEntity',
                                    'StockHolder'),
                            a_percentageofownership =>
                                rec.percentageofownership,
                            a_ownertype => rec.ownertype,
                            a_title     => NULL);

                    IF (rec.company IS NOT NULL)
                    THEN
                        add_company(a_entityobjectid => t_newentity,
                                    a_legal_entity => rec.company);
                    END IF;

                    IF (rec.person IS NOT NULL)
                    THEN
                        add_person(a_entityobjectid => t_newentity,
                                   a_person    => rec.person);
                    END IF;
                END IF;

                IF (LENGTH(NVL(rec.title, '[]')) > 3)
                THEN
                    t_newentity :=
                        create_legalentity(
                            a_parent    => a_entityobjectid,
                            a_child     => t_objectid,
                            a_endpointid =>
                                api.pkg_configquery.endpointidforname(
                                    'o_LegalEntity',
                                    'Officer'),
                            a_percentageofownership => NULL,
                            a_ownertype => NULL,
                            a_title     => rec.title);

                    IF (rec.company IS NOT NULL)
                    THEN
                        add_company(a_entityobjectid => t_newentity,
                                    a_legal_entity => rec.company);
                    END IF;

                    IF (rec.person IS NOT NULL)
                    THEN
                        add_person(a_entityobjectid => t_newentity,
                                   a_person    => rec.person);
                    END IF;
                END IF;
            END IF;

            api.pkg_logicaltransactionupdate.endtransaction;
            COMMIT;
        END LOOP;
    END add_company;

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

    PROCEDURE make_former_legalentity(
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

    PROCEDURE membership_stock_transfers(
        a_jobid        IN api.pkg_definition.udt_id,
        a_legal_entities IN CLOB)
    IS
        t_item         api.pkg_definition.udt_id;
        t_entity       CLOB;
        t_company      CLOB;
        t_person       CLOB;
        t_parent       api.pkg_definition.udt_id;
    BEGIN
        SELECT entity, company, person
          INTO t_entity, t_company, t_person
          FROM JSON_TABLE(
                   a_legal_entities,
                   '$'
                   COLUMNS(entity CLOB FORMAT JSON PATH '$.ENTITY',
                           company CLOB FORMAT JSON PATH '$.COMPANY',
                           person CLOB FORMAT JSON PATH '$.PERSON'));

        SELECT r.toobjectid
          INTO t_item
          FROM api.relationships r
         WHERE r.endpointid IN
                   (api.pkg_configquery.endpointidforname('o_legalEntity',
                                                          'Company'),
                    api.pkg_configquery.endpointidforname('o_legalEntity',
                                                          'Person'))
           AND r.fromobjectid =
               (SELECT MIN(tbl.removelegalentityobjectid)    removelegalentityobjectid
                  FROM JSON_TABLE(
                           t_entity,
                           '$[*]'
                           COLUMNS(
                               objectid NUMBER PATH '$.LEGALENTITYOBJECTID',
                               removelegalentityobjectid
                                   NUMBER
                                   PATH '$.REMOVELEGALENTITYOBJECTID')) tbl
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
           AND api.pkg_columnquery.VALUE(r.toobjectid, 'ApplicationJobId') =
               a_jobid
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
                        a_objectid  => a_jobid,
                        a_legalentityobjectid => entity.objectid);
                END IF;

                IF (entity.removelegalentityobjectid IS NOT NULL)
                THEN
                    make_former_legalentity(
                        a_applicationobjectid => a_jobid,
                        a_personcompanyobjectid =>
                            entity.removelegalentityobjectid);
                END IF;
            END LOOP;
        END IF;

        -- "ApplicationCreatedDate" must be set last before save
        api.pkg_columnupdate.setvalue(a_jobid,
                                      'ApplicationCreatedDate',
                                      SYSDATE);

        api.pkg_logicaltransactionupdate.endtransaction;
        COMMIT;
    END;

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
END;
/
