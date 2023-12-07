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
    -- **************************************************************************
    t_data         BLOB;
    t_outcome      VARCHAR2(20);
    t_url          VARCHAR2(1000)
        := '<<path>>/api/licensing/internal/catering/applications/<<applicationId>>';
    t_packet       CLOB;
    t_response     CLOB;
    t_results      CLOB;
    t_json_app     json_object_t;

    t_applicationid VARCHAR2(1000);
    t_sponsoringorganizationaddr VARCHAR(1000);
    t_addressid    NUMBER;
    t_address      bizmod_api.var_tbl := bizmod_api.var_tbl();
    t_phone        VARCHAR2(20);

    t_error        VARCHAR2(4000);
    t_sqlerrm      VARCHAR2(4000);
    t_trace        VARCHAR2(4000);
    t_msg          VARCHAR2(4000 BYTE);
BEGIN
    -- check if application was just created
    IF (  api.pkg_columnquery.datevalue(a_objectid, 'CreatedDate')
        + ((1 / 24 / 60) * 5) >
        SYSDATE)
    THEN
        DBMS_OUTPUT.put_line('exiting: ');
        RETURN;
    END IF;

    t_applicationid := api.pkg_columnquery.VALUE(a_objectid, 'LSPId');
    t_outcome := api.pkg_columnquery.VALUE(a_objectid, 'OutCome');

    t_sponsoringorganizationaddr :=
        REPLACE(
            api.pkg_columnquery.VALUE(a_objectid,
                                      'SponsoringOrganizationMailing'),
            ',,',
            ', ,');
    t_addressid :=
        api.pkg_columnquery.VALUE(a_objectid, 'EventLocAddressObjectId');

        SELECT REGEXP_SUBSTR(t_sponsoringorganizationaddr,
                             '[^,]+',
                             1,
                             LEVEL)
          BULK COLLECT INTO t_address
          FROM DUAL
    CONNECT BY REGEXP_SUBSTR(t_sponsoringorganizationaddr,
                             '[^,]+',
                             1,
                             LEVEL)
                   IS NOT NULL;

    IF (t_address.COUNT < 5)
    THEN
        t_address.EXTEND(5 - t_address.COUNT);
    END IF;

    t_addressid :=
        api.pkg_columnquery.VALUE(a_objectid, 'EventLocAddressObjectId');

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
                                    0))
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
                                    0))
                    END,
                    4,
                    '0'),
                'HH24MI'),
            'HH24:MI'));
    t_json_app.put(
        'expectedAttendance',
        api.pkg_columnquery.numericvalue(a_objectid, 'EstimatedAttendance'));
    t_json_app.put('publicEvent',
                   api.pkg_columnquery.VALUE(a_objectid, 'PublicEvent'));
    t_json_app.put('contactName',
                   api.pkg_columnquery.VALUE(a_objectid, 'ContactName'));

    t_phone := api.pkg_columnquery.VALUE(a_objectid, 'ContactPhoneNumber');

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
    t_json_app.put('sponsoringOrganizationAddress1', t_address(1));
    t_json_app.put('sponsoringOrganizationAddress2', t_address(2));
    t_json_app.put('sponsoringOrganizationCity', t_address(3));
    t_json_app.put('sponsoringOrganizationState', t_address(4));
    t_json_app.put('sponsoringOrganizationZip', t_address(5));
    t_json_app.put(
        'personInCharge',
        api.pkg_columnquery.VALUE(a_objectid, 'PersonInChargeOfEvent'));

    t_phone :=
        api.pkg_columnquery.VALUE(a_objectid, 'PersonInChargePhoneNumber');

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

    t_json_app.put('eventLocationAddress1',
                   api.pkg_columnquery.VALUE(t_addressid, 'AddressLine1'));
    t_json_app.put(
        'eventLocationAddress2',
        NVL(api.pkg_columnquery.VALUE(t_addressid, 'AddressLine2'), ''));
    t_json_app.put('eventLocationCity',
                   api.pkg_columnquery.VALUE(t_addressid, 'CACity'));
    t_json_app.put('eventLocationZip',
                   api.pkg_columnquery.VALUE(t_addressid, 'ZipCode'));
    t_json_app.put('withinCityLimits',
                   api.pkg_columnquery.VALUE(a_objectid, 'WithinCityLimits'));
    t_json_app.put('annualEventsCount',
                   api.pkg_columnquery.VALUE(a_objectid, ''));
    t_json_app.put('specificLocation',
                   api.pkg_columnquery.VALUE(a_objectid, 'SpecificLocation'));

    t_url :=
        REPLACE(
            REPLACE(
                t_url,
                '<<path>>',
                CASE ora_database_name
                    WHEN 'ABISST1' THEN 'https://services-sb.abc.ca.gov'
                    WHEN 'ABISP1' THEN 'https://abcbiz.abc.ca.gov'
                    WHEN 'ABISQA1' THEN 'https://qa-01.abcbiz-qa.abc.ca.gov'
                    WHEN 'ABISD1' THEN 'https://qa-02.abcbiz-qa.abc.ca.gov'
                    ELSE 'https://unknown'
                END),
            '<<applicationId>>',
            t_applicationid);

    t_packet := t_json_app.TO_CLOB;
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
                 || 'Application Update'
                 || CHR(13)
                 || 'URL: '
                 || t_url,
                 SUBSTR(t_response, 1, 3990),
                 t_packet);

    COMMIT;

    IF (t_outcome IS NOT NULL
    AND t_response IS NULL)
    THEN
        t_url := t_url || CHR(63) || 'status=' || t_outcome;

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
               AND r.fromobjectid = a_objectid;

            t_url :=
                t_url
                || CHR(38)
                || 'file=ABC-218.pdf'
                || CHR(38)
                || 'metadata=ABC-218.pdf';
            t_response :=
                bizmod_api.utl_licenseinfo.calllsp(a_url       => t_url,
                                                   a_method    => 'PATCH',
                                                   a_content   => NULL,
                                                   a_file      => t_data);
        ELSE
            t_response :=
                bizmod_api.utl_licenseinfo.calllsp(a_url       => t_url,
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
                     || CASE
                            WHEN t_outcome IS NULL THEN 'Application Update'
                            ELSE 'Outcome: ' || t_outcome
                        END
                     || CHR(13)
                     || 'URL: '
                     || t_url,
                     t_response);

        COMMIT;
    END IF;
EXCEPTION
    WHEN UTL_HTTP.request_failed
    THEN
        t_sqlerrm :=
            'HTTP: ' || UTL_HTTP.get_detailed_sqlerrm || CHR(13) || SQLERRM;
        t_trace := DBMS_UTILITY.format_error_backtrace;

        INSERT INTO bizmod_api.e_process_log_t(seq,
                                               processjob,
                                               info,
                                               errmsg,
                                               bktrace)
                 VALUES (
                     0,
                     'CATERINGNOTIFYLSPJOB',
                     'Application Id: '
                     || t_applicationid
                     || CHR(13)
                     || CASE
                            WHEN t_outcome IS NULL THEN 'Application Update'
                            ELSE 'Outcome: ' || t_outcome
                        END
                     || CHR(13)
                     || 'URL: '
                     || t_url,
                     t_sqlerrm,
                     t_trace);

        COMMIT;
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
                     'CATERINGNOTIFYLSPJOB',
                     'Application Id: '
                     || t_applicationid
                     || CHR(13)
                     || CASE
                            WHEN t_outcome IS NULL THEN 'Application Update'
                            ELSE 'Outcome: ' || t_outcome
                        END
                     || CHR(13)
                     || 'URL: '
                     || t_url,
                     t_sqlerrm,
                     t_trace);

        COMMIT;
END;
/


GRANT EXECUTE ON BIZMOD_API.CATERINGNOTIFYLSPJOB TO POSSEEXTENSIONS;
