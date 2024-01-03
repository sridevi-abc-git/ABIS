CREATE OR REPLACE PROCEDURE BIZMOD_API.cateringnotifylspjob(
    a_objectid     api.pkg_definition.udt_id,
    a_asofdate     DATE)
AS
    -- **************************************************************************
    -- File:        BIZMOD_API.CATERINGNOTIFYLSPJOB.PRC
    -- Author:      Timothy J. Lord
    --
    -- History:
    -----------------------------------------------------------------------------
    --    Ver:     Date                       Comment
    --     1.0   11/01/2023  TJL BIZ-12802  Initial Procedure Created
    --     1.1   12/12/2023  TJL BIZ-13929  Added additional logging and removing
    --                                        null tags.
    --                                      Corrected bug in time formatting
    --     1.2   12/14/2023  TJL            Corrected bug when Application has more than
    --                                          one ABC-218 files attached
    --     1.2   12/19/2023  TJL            Added check that once application is completed
    --                                          that no more updates will be sent. After
    --                                          complete a ABC-172 can be created which would
    --                                          generate a notify request that generate an
    --                                          error email.
    --                                      Added parsing function to parse Sponsoring Organization
    --                                          Mailing Address.
    --   2.0     01/02/2024 TJL  BIZ-14058  Corrected bug in parsing Sponsoring Organization
    --                                          Mailing Address.
    -- **************************************************************************
    FUNCTION parseaddress(a_address IN VARCHAR2)
        RETURN bizmod_api.var_tbl
    IS
        t_address      bizmod_api.var_tbl := bizmod_api.var_tbl();
        t_array        bizmod_api.var_tbl := bizmod_api.var_tbl();

        t_count        NUMBER;
        t_state_zip    BOOLEAN;
        t_pos          NUMBER;
    BEGIN
        t_address.EXTEND(5);

            SELECT TRIM(REGEXP_SUBSTR(a_address,
                                      '[^,]+',
                                      1,
                                      LEVEL))    str
              BULK COLLECT INTO t_array
              FROM DUAL
        CONNECT BY REGEXP_SUBSTR(a_address,
                                 '[^,]+',
                                 1,
                                 LEVEL)
                       IS NOT NULL;

        t_count := t_array.COUNT;

        -- get position of first non space for begining of zip code
        t_pos := REGEXP_INSTR(t_array(t_count), '[^ ]*$');

        -- when no space is found it points to first position
        --  t_state_zip when false indicates the state is missing or a
        --     comma was used to seprate zip and state
        t_state_zip := CASE t_pos WHEN 1 THEN FALSE ELSE TRUE END;

        -- get zip code
        t_address(5) := SUBSTR(t_array(t_count), t_pos);

        -- get state
        --   (location in array can vary depending on parsing address)
        IF (t_state_zip)
        THEN
            t_address(4) := SUBSTR(t_array(t_count), 1, 2);
        ELSE
            -- check if a comma seprated between state and zip
            t_address(4) :=
                CASE LENGTH(t_array(t_count - 1))
                    WHEN 2
                    THEN
                        t_array(t_count - 1)
                    WHEN 3
                    THEN
                        CASE SUBSTR(t_array(t_count - 1), 3, 1)
                            WHEN '.' THEN SUBSTR(t_array(t_count - 1), 1, 2)
                            ELSE NULL
                        END
                    ELSE
                        NULL
                END;
        END IF;

        -- get address2 and city
        --   (location in array can vary depending on parsing address)
        IF (t_state_zip)
        THEN
            t_address(3) := t_array(t_count - 1);

            -- check if address2 was found
            IF (t_count = 4
             OR t_count = 5)
            THEN
                t_address(2) := t_array(2);
            END IF;
        ELSE
            IF (t_address(4) IS NULL)
            THEN
                t_address(3) := t_array(t_count - 1);

                IF (t_count = 4)
                THEN
                    t_address(2) := t_array(2);
                END IF;
            ELSE
                t_address(3) := t_array(t_count - 2);

                IF (t_count = 5)
                THEN
                    t_address(2) := t_array(2);
                END IF;
            END IF;
        END IF;

        -- save address 1
        t_address(1) := t_array(1);


        RETURN t_address;
    END;
-- ****************************************************************************
-- ****************************************************************************
--  Main Function Body
-- ****************************************************************************
-- ****************************************************************************
BEGIN
    DECLARE
        t_data         BLOB;
        t_outcome      VARCHAR2(20);
        t_url          VARCHAR2(1000)
            := '<<path>>/api/licensing/internal/catering/applications/<<applicationId>>';
        t_packet       CLOB;
        t_response     CLOB;
        t_results      CLOB;
        t_json_app     json_object_t;

        t_applicationid VARCHAR2(1000);
        t_licensenumber VARCHAR2(100);
        t_sponsoringorganizationaddr VARCHAR(1000);
        t_addressid    NUMBER;
        t_address      bizmod_api.var_tbl := bizmod_api.var_tbl();
        t_phone        VARCHAR2(20);

        t_error        VARCHAR2(4000);
        t_sqlerrm      VARCHAR2(4000);
        t_trace        VARCHAR2(4000);
        t_msg          VARCHAR2(4000 BYTE);
        t_notifynumber NUMBER := 0;
        t_wordcnt      NUMBER := 0;
    BEGIN
        -- check to see if word document was created after application completed
        SELECT COUNT(1)
          INTO t_wordcnt
          FROM api.relationships  r
               LEFT OUTER JOIN doc.documentblobs d
                   ON d.documentid = r.toobjectid
         WHERE r.endpointid =
               api.pkg_configquery.endpointidforname(
                   'p_IssueCatererEventAuth',
                   'ABCWordDocument')
           AND r.fromobjectid = a_objectid
           AND api.pkg_columnquery.datevalue(r.toobjectid, 'Createddate') >
               api.pkg_columnquery.datevalue(r.fromobjectid, 'DateCompleted');

        -- check if application was just created
        IF (  api.pkg_columnquery.datevalue(a_objectid, 'CreatedDate')
            + ((1 / 24 / 60) * 2) >
            SYSDATE)
        OR (t_wordcnt > 0)
        THEN
            RETURN;
        END IF;

        t_applicationid := api.pkg_columnquery.VALUE(a_objectid, 'LSPId');
        t_licensenumber :=
            api.pkg_columnquery.VALUE(
                api.pkg_columnquery.numericvalue(a_objectid, 'jobid'),
                'licensenumber');
        t_outcome := api.pkg_columnquery.VALUE(a_objectid, 'OutCome');

        IF (t_applicationid IS NOT NULL)
        THEN
            t_address :=
                parseaddress(
                    api.pkg_columnquery.VALUE(
                        a_objectid,
                        'SponsoringOrganizationMailing'));

            t_addressid :=
                api.pkg_columnquery.VALUE(a_objectid,
                                          'EventLocAddressObjectId');

            t_json_app := NEW json_object_t();
            t_json_app.put('applicationId', t_applicationid);
            t_json_app.put(
                'eventStartDate',
                api.pkg_columnquery.datevalue(a_objectid, 'DateOfEventFrom'));
            t_json_app.put(
                'eventEndDate',
                api.pkg_columnquery.datevalue(a_objectid, 'dateofeventto'));
            t_json_app.put(
                'eventStartTime',
                TO_CHAR(
                    TO_TIMESTAMP(
                        LPAD(
                            CASE api.pkg_columnquery.VALUE(
                                     a_objectid,
                                     'BeginServingAlcoholAMPMTime')
                                WHEN 'PM'
                                THEN
                                    TO_CHAR(
                                          NVL(
                                              api.pkg_columnquery.numericvalue(
                                                  a_objectid,
                                                  'Timeyouwillbeginservingalcohol'),
                                              0)
                                        + CASE
                                              WHEN NVL(
                                                       api.pkg_columnquery.numericvalue(
                                                           a_objectid,
                                                           'Timeyouwillbeginservingalcohol'),
                                                       0) <
                                                   1200
                                              THEN
                                                  1200
                                              ELSE
                                                  0
                                          END)
                                ELSE
                                    TO_CHAR(
                                          NVL(
                                              api.pkg_columnquery.numericvalue(
                                                  a_objectid,
                                                  'Timeyouwillbeginservingalcohol'),
                                              0)
                                        - CASE
                                              WHEN NVL(
                                                       api.pkg_columnquery.numericvalue(
                                                           a_objectid,
                                                           'Timeyouwillbeginservingalcohol'),
                                                       0) >=
                                                   1200
                                              THEN
                                                  1200
                                              ELSE
                                                  0
                                          END)
                            END,
                            4,
                            '0'),
                        'HH24MI'),
                    'HH24:MI'));
            t_json_app.put(
                'eventEndTime',
                TO_CHAR(
                    TO_TIMESTAMP(
                        LPAD(
                            CASE api.pkg_columnquery.VALUE(
                                     a_objectid,
                                     'StopServingAlcoholAMPMTime')
                                WHEN 'PM'
                                THEN
                                    TO_CHAR(
                                          NVL(
                                              api.pkg_columnquery.numericvalue(
                                                  a_objectid,
                                                  'TimeYouWillStopServingAlcohol'),
                                              0)
                                        + CASE
                                              WHEN NVL(
                                                       api.pkg_columnquery.numericvalue(
                                                           a_objectid,
                                                           'TimeYouWillStopServingAlcohol'),
                                                       0) <
                                                   1200
                                              THEN
                                                  1200
                                              ELSE
                                                  0
                                          END)
                                ELSE
                                    TO_CHAR(
                                          NVL(
                                              api.pkg_columnquery.numericvalue(
                                                  a_objectid,
                                                  'TimeYouWillStopServingAlcohol'),
                                              0)
                                        - CASE
                                              WHEN NVL(
                                                       api.pkg_columnquery.numericvalue(
                                                           a_objectid,
                                                           'TimeYouWillStopServingAlcohol'),
                                                       0) >=
                                                   1200
                                              THEN
                                                  1200
                                              ELSE
                                                  0
                                          END)
                            END,
                            4,
                            '0'),
                        'HH24MI'),
                    'HH24:MI'));
            t_json_app.put(
                'expectedAttendance',
                api.pkg_columnquery.numericvalue(a_objectid,
                                                 'EstimatedAttendance'));
            t_json_app.put(
                'publicEvent',
                api.pkg_columnquery.VALUE(a_objectid, 'PublicEvent'));
            t_json_app.put(
                'contactName',
                api.pkg_columnquery.VALUE(a_objectid, 'ContactName'));

            t_phone :=
                api.pkg_columnquery.VALUE(a_objectid, 'ContactPhoneNumber');

            IF (t_phone IS NOT NULL
            AND LENGTH(t_phone) > 9)
            THEN
                t_json_app.put(
                    'contactPhone',
                    '('
                    || SUBSTR(t_phone, 1, 3)
                    || ')'
                    || SUBSTR(t_phone, 4, 3)
                    || '-'
                    || SUBSTR(t_phone, 7, 4));
            END IF;

            t_json_app.put(
                'contactEmail',
                api.pkg_columnquery.VALUE(a_objectid, 'ContactEmail'));
            t_json_app.put(
                'eventType',
                CASE api.pkg_columnquery.VALUE(a_objectid, 'EventType')
                    WHEN 'OTHER EVENT'
                    THEN
                        api.pkg_columnquery.VALUE(a_objectid,
                                                  'OtherEventType')
                    ELSE
                        api.pkg_columnquery.VALUE(a_objectid, 'EventType')
                END);
            t_json_app.put(
                'sponsoringOrganization',
                api.pkg_columnquery.VALUE(a_objectid,
                                          'SponsoringOrganization'));
            t_json_app.put('sponsoringOrganizationAddress1',
                           TRIM(t_address(1)));
            t_json_app.put('sponsoringOrganizationAddress2',
                           TRIM(t_address(2)));
            t_json_app.put('sponsoringOrganizationCity', TRIM(t_address(3)));
            t_json_app.put('sponsoringOrganizationState', TRIM(t_address(4)));
            t_json_app.put('sponsoringOrganizationZip', TRIM(t_address(5)));
            t_json_app.put(
                'personInCharge',
                api.pkg_columnquery.VALUE(a_objectid,
                                          'PersonInChargeOfEvent'));

            t_phone :=
                api.pkg_columnquery.VALUE(a_objectid,
                                          'PersonInChargePhoneNumber');

            IF (t_phone IS NOT NULL
            AND LENGTH(t_phone) > 9)
            THEN
                t_json_app.put(
                    'personInChargePhone',
                    '('
                    || SUBSTR(t_phone, 1, 3)
                    || ')'
                    || SUBSTR(t_phone, 4, 3)
                    || '-'
                    || SUBSTR(t_phone, 7, 4));
            END IF;

            t_json_app.put(
                'eventLocationAddress1',
                api.pkg_columnquery.VALUE(t_addressid, 'AddressLine1'));
            t_json_app.put(
                'eventLocationAddress2',
                NVL(api.pkg_columnquery.VALUE(t_addressid, 'AddressLine2'),
                    ''));
            t_json_app.put('eventLocationCity',
                           api.pkg_columnquery.VALUE(t_addressid, 'CACity'));
            t_json_app.put('eventLocationZip',
                           api.pkg_columnquery.VALUE(t_addressid, 'ZipCode'));
            t_json_app.put(
                'withinCityLimits',
                api.pkg_columnquery.VALUE(a_objectid, 'WithinCityLimits'));
            t_json_app.put('annualEventsCount',
                           api.pkg_columnquery.VALUE(a_objectid, ''));
            t_json_app.put(
                'specificLocation',
                api.pkg_columnquery.VALUE(a_objectid, 'SpecificLocation'));

            t_url :=
                REPLACE(
                    REPLACE(
                        t_url,
                        '<<path>>',
                        CASE ora_database_name
                            WHEN 'ABISST1'
                            THEN
                                'https://services-sb.abc.ca.gov'
                            WHEN 'ABISP1'
                            THEN
                                'https://abcbiz.abc.ca.gov'
                            WHEN 'ABISQA1'
                            THEN
                                'https://qa-01.abcbiz-qa.abc.ca.gov'
                            WHEN 'ABISD1'
                            THEN
                                'https://qa-02.abcbiz-qa.abc.ca.gov'
                            ELSE
                                'https://unknown'
                        END),
                    '<<applicationId>>',
                    t_applicationid);

            bizmod_api.utl_licenseinfo.clean(t_json_app);

            t_packet := t_json_app.TO_CLOB;
            t_notifynumber := 1;
            t_response :=
                bizmod_api.utl_licenseinfo.calllsp(a_url       => t_url,
                                                   a_method    => 'PUT',
                                                   a_content   => t_packet,
                                                   a_file      => NULL);

            INSERT INTO bizmod_api.e_process_log_t(seq,
                                                   processjob,
                                                   info,
                                                   errmsg,
                                                   packet)
                     VALUES (
                         0,
                         'CATERINGNOTIFYLSPJOB',
                         'Application Id: '
                         || t_applicationid
                         || CHR(13)
                         || 'License Number: '
                         || t_licensenumber
                         || CHR(13)
                         || 'Catering Object Id: '
                         || a_objectid
                         || CHR(13)
                         || 'Application Update'
                         || CHR(13)
                         || 'URL: '
                         || t_url,
                         CASE
                             WHEN t_response IS NOT NULL
                             THEN
                                 'LSP Response: '
                                 || SUBSTR(t_response, 1, 3990)
                             ELSE
                                 NULL
                         END,
                         t_packet);

            COMMIT;

            IF (t_outcome IS NOT NULL
            AND t_response IS NULL)
            THEN
                t_url := t_url || CHR(63) || 'status=' || t_outcome;
                t_notifynumber := 2;

                IF (t_outcome = 'Approved')
                THEN
                    -- get 218 file to send to LSP
                    SELECT d.VALUE
                      INTO t_data
                      FROM api.relationships  r
                           LEFT OUTER JOIN doc.documentblobs d
                               ON d.documentid = r.toobjectid
                     WHERE r.endpointid =
                           api.pkg_configquery.endpointidforname(
                               'p_IssueCatererEventAuth',
                               'Document')
                       AND api.pkg_columnquery.VALUE(d.documentid,
                                                     'filename') =
                           'ABC-218.pdf'
                       AND r.fromobjectid = a_objectid
                       AND ROWNUM = 1;

                    t_url :=
                        t_url
                        || CHR(38)
                        || 'file=ABC-218.pdf'
                        || CHR(38)
                        || 'metadata=ABC-218.pdf';
                    t_response :=
                        bizmod_api.utl_licenseinfo.calllsp(
                            a_url       => t_url,
                            a_method    => 'PATCH',
                            a_content   => NULL,
                            a_file      => t_data);
                ELSE
                    t_response :=
                        bizmod_api.utl_licenseinfo.calllsp(
                            a_url       => t_url,
                            a_method    => 'PATCH',
                            a_content   => NULL,
                            a_file      => NULL);
                END IF;

                INSERT INTO bizmod_api.e_process_log_t(seq,
                                                       processjob,
                                                       info,
                                                       errmsg)
                         VALUES (
                             0,
                             'CATERINGNOTIFYLSPJOB',
                             'Application Id: '
                             || t_applicationid
                             || CHR(13)
                             || 'License Number: '
                             || t_licensenumber
                             || CHR(13)
                             || 'Catering Object Id: '
                             || a_objectid
                             || CHR(13)
                             || 'Outcome: '
                             || t_outcome
                             || CHR(13)
                             || 'URL: '
                             || t_url,
                             CASE
                                 WHEN t_response IS NULL THEN NULL
                                 ELSE 'LSP Response: ' || t_response
                             END);

                COMMIT;
            END IF;
        ELSE
            INSERT INTO bizmod_api.e_process_log_t(seq, processjob, info)
                     VALUES (
                         0,
                         'CATERINGNOTIFYLSPJOB',
                         'Application Id: '
                         || t_applicationid
                         || CHR(13)
                         || 'License Number: '
                         || t_licensenumber
                         || CHR(13)
                         || 'Catering Object Id: '
                         || a_objectid
                         || CHR(13)
                         || 'Outcome: '
                         || t_outcome
                         || CHR(13)
                         || 'Application Id missing from Catering Application');

            COMMIT;
        END IF;
    EXCEPTION
        WHEN UTL_HTTP.request_failed
        THEN
            t_sqlerrm :=
                'HTTP: '
                || UTL_HTTP.get_detailed_sqlerrm
                || CHR(13)
                || SQLERRM;
            t_trace := DBMS_UTILITY.format_error_backtrace;

            INSERT INTO bizmod_api.e_process_log_t(seq,
                                                   processjob,
                                                   info,
                                                   errmsg,
                                                   bktrace,
                                                   packet)
                     VALUES (
                         0,
                         'CATERINGNOTIFYLSPJOB',
                         'Application Id: '
                         || t_applicationid
                         || CHR(13)
                         || 'License Number: '
                         || t_licensenumber
                         || CHR(13)
                         || 'Catering Object Id: '
                         || a_objectid
                         || CHR(13)
                         || CASE t_notifynumber
                                WHEN 1 THEN 'Application Update'
                                ELSE 'Outcome: ' || t_outcome
                            END
                         || CHR(13)
                         || 'URL: '
                         || t_url,
                         t_sqlerrm,
                         t_trace,
                         CASE t_notifynumber
                             WHEN 1 THEN t_packet
                             ELSE NULL
                         END);

            COMMIT;
        WHEN OTHERS
        THEN
            t_sqlerrm := SQLERRM;
            t_trace := DBMS_UTILITY.format_error_backtrace;

            INSERT INTO bizmod_api.e_process_log_t(seq,
                                                   processjob,
                                                   info,
                                                   errmsg,
                                                   bktrace,
                                                   packet)
                     VALUES (
                         0,
                         'CATERINGNOTIFYLSPJOB',
                         'Application Id: '
                         || t_applicationid
                         || CHR(13)
                         || CASE t_notifynumber
                                WHEN 1 THEN 'Application Update'
                                ELSE 'Outcome: ' || t_outcome
                            END
                         || CHR(13)
                         || 'URL: '
                         || t_url,
                         t_sqlerrm,
                         t_trace,
                         CASE t_notifynumber
                             WHEN 1 THEN t_packet
                             ELSE NULL
                         END);

            COMMIT;
    END;
END;
/


GRANT EXECUTE ON BIZMOD_API.CATERINGNOTIFYLSPJOB TO POSSEEXTENSIONS;
