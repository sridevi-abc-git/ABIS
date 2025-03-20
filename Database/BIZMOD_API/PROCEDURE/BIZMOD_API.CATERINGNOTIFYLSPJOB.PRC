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
    --   3.0.1   05/17/2024 TJL  BIZ-15485  Change parameters to call to calllsp. New calllsp uses
    --                                          configuration table for HTTP Calls
    --   3.1.1   05/24/2024 TJL  BIZ-15021  Added support for new field Outside Event
    --   4.0     08/13/2024 TJL  BIZ-15808  Change call to new calllsp function
    --   5.0.0   02/04/2025 TJL  BIZ-17356    Added handling of the return value from CALLLSP and call
    --                                          to lsplogin
    -- **************************************************************************
    FUNCTION parseaddress(a_address IN VARCHAR2)
        RETURN bizmod_api.var_tbl
    IS
        t_address      bizmod_api.var_tbl := bizmod_api.var_tbl();
        t_array        bizmod_api.var_tbl := bizmod_api.var_tbl();

        t_count        NUMBER;
        t_state_zip    BOOLEAN;
        t_pos          NUMBER;
        t_tmp          VARCHAR2(1000);
    BEGIN
        t_address.EXTEND(5);

            SELECT TRIM(REGEXP_SUBSTR(a_address,
                                      '[^,]+',
                                      1,
                                      LEVEL))    str
              BULK COLLECT INTO t_array
              FROM DUAL
        CONNECT BY LEVEL <=
                   LENGTH(a_address) - LENGTH(REPLACE(a_address, ',')) + 1;

        t_count := t_array.COUNT;

        IF (t_count > 1)
        THEN
            -- get position of first non space for begining of zip code
            t_pos :=
                CASE t_count
                    WHEN 1 THEN 1
                    ELSE REGEXP_INSTR(t_array(t_count), '[^ ]*$')
                END;

            -- when no space is found it points to first position
            --  t_state_zip when false indicates the state is missing or a
            --     comma was used to seprate zip and state
            t_state_zip := CASE t_pos WHEN 1 THEN FALSE ELSE TRUE END;

            -- get zip code
            t_address(5) :=
                CASE
                    WHEN REGEXP_LIKE(SUBSTR(t_array(t_count), t_pos),
                                     '^([0-9]{5})(-[0-9]{4})?$')
                    THEN
                        SUBSTR(t_array(t_count), t_pos)
                    ELSE
                        NULL
                END;

            -- get state
            --   (location in array can vary depending on parsing address)
            IF (t_state_zip)
            THEN
                t_tmp := TRIM(SUBSTR(t_array(t_count), 1, t_pos - 1));
                t_address(4) :=
                    CASE
                        WHEN LENGTH(t_tmp) < 4 THEN SUBSTR(t_tmp, 1, 2)
                        ELSE ' '
                    END;
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
                                WHEN '.'
                                THEN
                                    SUBSTR(t_array(t_count - 1), 1, 2)
                                ELSE
                                    ' '
                            END
                        ELSE
                            ' '
                    END;
            END IF;
        END IF;

        IF (t_count > 2)
        THEN
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
        END IF;

        -- save address 1
        t_address(1) := t_array(1);

        t_address(4) := TRIM(t_address(4));

        RETURN t_address;
    END;

    FUNCTION create_packet(a_objectid IN api.pkg_definition.udt_id)
        RETURN json_object_t
    IS
        t_json_app     json_object_t := NEW json_object_t();
        t_addressid    NUMBER;
        t_address      bizmod_api.var_tbl := bizmod_api.var_tbl();
        t_phone        VARCHAR2(20);
    BEGIN
        t_address :=
            parseaddress(
                api.pkg_columnquery.VALUE(a_objectid,
                                          'SponsoringOrganizationMailing'));

        t_addressid :=
            api.pkg_columnquery.VALUE(a_objectid, 'EventLocAddressObjectId');

        t_json_app.put('applicationId',
                       api.pkg_columnquery.VALUE(a_objectid, 'LSPId'));
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
        t_json_app.put('publicEvent',
                       api.pkg_columnquery.VALUE(a_objectid, 'PublicEvent'));
        t_json_app.put('contactName',
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

        t_json_app.put('contactEmail',
                       api.pkg_columnquery.VALUE(a_objectid, 'ContactEmail'));
        t_json_app.put(
            'eventType',
            CASE api.pkg_columnquery.VALUE(a_objectid, 'EventType')
                WHEN 'OTHER EVENT'
                THEN
                    api.pkg_columnquery.VALUE(a_objectid, 'OtherEventType')
                ELSE
                    api.pkg_columnquery.VALUE(a_objectid, 'EventType')
            END);
        t_json_app.put(
            'sponsoringOrganization',
            api.pkg_columnquery.VALUE(a_objectid, 'SponsoringOrganization'));
        t_json_app.put('sponsoringOrganizationAddress1', TRIM(t_address(1)));
        t_json_app.put('sponsoringOrganizationAddress2', TRIM(t_address(2)));
        t_json_app.put('sponsoringOrganizationCity', TRIM(t_address(3)));
        t_json_app.put('sponsoringOrganizationState', TRIM(t_address(4)));
        t_json_app.put('sponsoringOrganizationZip', TRIM(t_address(5)));
        t_json_app.put(
            'personInCharge',
            api.pkg_columnquery.VALUE(a_objectid, 'PersonInChargeOfEvent'));

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
            NVL(api.pkg_columnquery.VALUE(t_addressid, 'AddressLine2'), ''));
        t_json_app.put('eventLocationCity',
                       api.pkg_columnquery.VALUE(t_addressid, 'CACity'));
        t_json_app.put('eventLocationZip',
                       api.pkg_columnquery.VALUE(t_addressid, 'ZipCode'));
        t_json_app.put(
            'withinCityLimits',
            api.pkg_columnquery.VALUE(a_objectid, 'WithinCityLimits'));
        t_json_app.put('annualEventsCount',
                       api.pkg_columnquery.VALUE(a_objectid, 'Quantity'));
        t_json_app.put(
            'specificLocation',
            api.pkg_columnquery.VALUE(a_objectid, 'SpecificLocation'));
        t_json_app.put('outsideEvent',
                       api.pkg_columnquery.VALUE(a_objectid, 'OutsideEvent'));

        RETURN t_json_app;
    END;
-- ****************************************************************************
-- ****************************************************************************
--  Main Function Body
-- ****************************************************************************
-- ****************************************************************************
BEGIN
    DECLARE
        t_url_update CONSTANT VARCHAR2(1000)
            := '/api/licensing/internal/catering/applications/<<applicationId>>' ;
        t_method_update CONSTANT VARCHAR2(10) := 'PUT';
        t_url_status CONSTANT VARCHAR2(1000)
            := '/api/licensing/internal/catering/applications/<<applicationId>>?status=<<status>>' ;
        t_method_status CONSTANT VARCHAR2(10) := 'PATCH';
        t_process      VARCHAR2(32) := 'CATERINGNOTIFYLSPJOB';
        t_urlinfo      VARCHAR2(10000);
        t_data         BLOB;
        t_outcome      VARCHAR2(20);
        t_packet       json_object_t;
        t_response     CLOB;
        --        t_results      CLOB;
        t_json_app     json_object_t;
        t_applicationid VARCHAR2(1000);
        t_licensenumber VARCHAR2(100);
        t_error        VARCHAR2(4000);
        t_sqlerrm      VARCHAR2(4000);
        t_trace        VARCHAR2(4000);
        t_msg          VARCHAR2(4000 BYTE);
        t_completed    VARCHAR2(1);
        t_hashvalue    NUMBER;
        t_currhash     NUMBER;
        t_header       VARCHAR2(4000);
        --        t_body         json_object_t := json_object_t();
        t_packet_value CLOB;
        t_results      json_object_t;
        t_token        VARCHAR2(1000);
        t_results_text VARCHAR2(32767);
        t_app_status   VARCHAR2(20) := 'Posted';
        t_text         VARCHAR2(32767);
    BEGIN
        BEGIN
            SELECT CASE WHEN c.outcome IS NULL THEN 'N' ELSE 'Y' END,
                   c.hashvalue
              INTO t_completed, t_currhash
              FROM bizmod_api.catering_app_t c
             WHERE c.processid = a_objectid;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                IF (api.pkg_columnquery.numericvalue(a_objectid, 'LSPId')
                        IS NOT NULL)
                THEN
                    -- get packet hash value
                    t_packet := create_packet(a_objectid => a_objectid);
                    t_text := t_packet.to_string;

                    SELECT ORA_HASH(t_text) INTO t_hashvalue FROM DUAL;

                    INSERT INTO bizmod_api.catering_app_t c(c.lspid,
                                                            c.processid,
                                                            c.outcome,
                                                            c.createddate,
                                                            c.datecompleted,
                                                            c.hashvalue)
                             VALUES (
                                        api.pkg_columnquery.numericvalue(
                                            a_objectid,
                                            'LSPId'),
                                        a_objectid,
                                        api.pkg_columnquery.VALUE(a_objectid,
                                                                  'Outcome'),
                                        api.pkg_columnquery.datevalue(
                                            a_objectid,
                                            'CreatedDate'),
                                        api.pkg_columnquery.datevalue(
                                            a_objectid,
                                            'DateCompleted'),
                                        t_hashvalue);

                    COMMIT;
                END IF;

                -- do not send application change when first created
                RETURN;
        END;

        IF (t_completed = 'Y')
        THEN
            RETURN;
        END IF;

        -- check if outcome has been set
        t_outcome := api.pkg_columnquery.VALUE(a_objectid, 'OutCome');
        t_applicationid := api.pkg_columnquery.VALUE(a_objectid, 'LSPId');

        t_header :=
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
            || CHR(13);

        IF (t_outcome IS NOT NULL)
        THEN
            UPDATE bizmod_api.catering_app_t c
               SET c.outcome =
                       api.pkg_columnquery.VALUE(a_objectid, 'Outcome'),
                   c.datecompleted =
                       api.pkg_columnquery.datevalue(a_objectid,
                                                     'DateCompleted')
             WHERE c.processid = a_objectid;

            COMMIT;
        END IF;

        t_packet := create_packet(a_objectid => a_objectid);
        t_text := t_packet.to_string;

        SELECT ORA_HASH(t_text) INTO t_hashvalue FROM DUAL;

        -- login to LSP
        t_results := bizmod_api.utl_licenseinfo.lsplogin;

        IF (t_results.get_number('status') = 200)
        THEN
            t_token :=
                t_results.get_object('lspresponse').get_string('token');

            IF (t_hashvalue != t_currhash)
            THEN
                UPDATE bizmod_api.catering_app_t c
                   SET c.hashvalue = t_hashvalue
                 WHERE c.processid = a_objectid;

                COMMIT;
                t_licensenumber :=
                    api.pkg_columnquery.VALUE(
                        api.pkg_columnquery.numericvalue(a_objectid, 'jobid'),
                        'licensenumber');


                -- update LSP of any changes to application data
                t_urlinfo :=
                    REPLACE(t_url_update,
                            '<<applicationId>>',
                            t_applicationid);

                t_results :=
                    bizmod_api.utl_licenseinfo.calllsp(
                        a_urlinfo   => t_urlinfo,
                        a_method    => t_method_update,
                        a_content   => t_packet,
                        a_token     => t_token);


                t_results_text := t_results.TO_CLOB;
                t_packet_value :=
                    json_query(t_packet.TO_CLOB, '$' RETURNING CLOB PRETTY);

                IF (t_results.get_number('status') != 200)
                THEN
                    t_sqlerrm :=
                        t_results.get_object('lspresponse').to_string;
                END IF;

                INSERT INTO bizmod_api.e_process_log_t(seq,
                                                       processjob,
                                                       info,
                                                       errmsg,
                                                       packet)
                     VALUES (0,
                             t_process,
                             t_header || CHR(13) || t_packet_value,
                             t_sqlerrm,
                             t_packet_value);

                COMMIT;
            END IF;
        END IF;

        IF (t_outcome IS NOT NULL
        AND t_results.get_number('status') = 200)
        THEN
            t_urlinfo :=
                REPLACE(
                    REPLACE(t_url_status,
                            '<<applicationId>>',
                            t_applicationid),
                    '<<status>>',
                    t_outcome);

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
                   AND api.pkg_columnquery.VALUE(d.documentid, 'filename') =
                       'ABC-218.pdf'
                   AND r.fromobjectid = a_objectid
                   AND ROWNUM = 1;

                t_urlinfo :=
                    t_urlinfo
                    || CHR(38)
                    || 'file=ABC-218.pdf'
                    || CHR(38)
                    || 'metadata=ABC-218.pdf';
            END IF;

            t_results :=
                bizmod_api.utl_licenseinfo.calllsp(
                    a_urlinfo   => t_urlinfo,
                    a_method    => t_method_status,
                    a_file      => t_data,
                    a_token     => t_token);

            IF (t_results.get_number('status') != 200)
            THEN
                t_sqlerrm := t_results.get_object('lspresponse').to_string;
            END IF;

            INSERT INTO bizmod_api.e_process_log_t(seq,
                                                   processjob,
                                                   info,
                                                   errmsg)
                 VALUES (0,
                         t_process,
                         t_header,
                         t_sqlerrm);

            COMMIT;
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
                                                   bktrace,
                                                   packet)
                 VALUES (0,
                         t_process,
                         t_header,
                         t_sqlerrm,
                         t_trace,
                         t_packet_value);

            COMMIT;
    END;
END;
/


GRANT EXECUTE ON BIZMOD_API.CATERINGNOTIFYLSPJOB TO POSSEEXTENSIONS;
