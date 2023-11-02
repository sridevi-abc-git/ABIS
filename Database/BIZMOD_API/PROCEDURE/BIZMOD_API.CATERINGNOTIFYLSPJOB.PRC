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
    --        t_lspid        VARCHAR2(100);
    t_outcome      VARCHAR2(20);
    t_url          VARCHAR2(1000)
        := '<<path>>/api/licensing/internal/catering/applications/<<applicationId>>';
    t_packet       CLOB;
    t_response     CLOB;
    t_results      CLOB;
    t_json_app     json_object_t;
    t_json_arr     json_array_t := json_array_t();
    t_json_data    json_object_t := json_object_t();

    t_applicationid VARCHAR2(1000);
    t_sponsoringorganizationaddr VARCHAR(1000);
    t_addressid    NUMBER;
    t_address      bizmod_api.var_tbl := bizmod_api.var_tbl();
    t_phone        VARCHAR2(20);

    t_sqlerrm      VARCHAR2(4000);
    t_trace        VARCHAR2(4000);
    t_msg          VARCHAR2(4000 BYTE);
BEGIN
    t_applicationid := api.pkg_columnquery.VALUE(a_objectid, 'LSPId');
    t_sponsoringorganizationaddr :=
        api.pkg_columnquery.VALUE(a_objectid,
                                  'SponsoringOrganizationMailing');
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
    t_json_app.put(
        'APPLICATIONTYPE',
        TRIM(
            REGEXP_SUBSTR(
                api.pkg_columnquery.VALUE(a_objectid, 'CateringOrEvent'),
                '[^-]+',
                1,
                2)));
    t_json_app.put('LICENSENUMBER',
                   api.pkg_columnquery.VALUE(a_objectid, 'LicenseNumber'));
    t_json_app.put('APPLICATIONID', t_applicationid);
    t_json_app.put(
        'EVENTSTARTDATE',
        api.pkg_columnquery.datevalue(a_objectid, 'DateOfEventFrom'));
    t_json_app.put(
        'EVENTENDDATE',
        api.pkg_columnquery.datevalue(a_objectid, 'dateofeventto'));
    t_json_app.put(
        'EVENTSTARTTIME',
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
                                + 1200)
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
            'HH24:MI:SS'));
    t_json_app.put(
        'EVENTENDTIME',
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
                                + 1200)
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
            'HH24:MI:SS'));
    t_json_app.put(
        'EXPECTEDATTENDANCE',
        api.pkg_columnquery.numericvalue(a_objectid, 'EstimatedAttendance'));
    t_json_app.put('PUBLICEVENT',
                   api.pkg_columnquery.VALUE(a_objectid, 'PublicEvent'));
    t_json_app.put('EVENTTYPE',
                   api.pkg_columnquery.VALUE(a_objectid, 'EventType'));
    t_json_app.put(
        'SPONSORINGORGANIZATION',
        api.pkg_columnquery.VALUE(a_objectid, 'SponsoringOrganization'));
    t_json_app.put('SPONSORINGORGANIZATIONADDRESS1', t_address(1));
    t_json_app.put('SPONSORINGORGANIZATIONADDRESS2', t_address(2));
    t_json_app.put('SPONSORINGORGANIZATIONCITY', t_address(3));
    t_json_app.put('SPONSORINGORGANIZATIONSTATE', t_address(4));
    t_json_app.put('SPONSORINGORGANIZATIONZIP', t_address(5));
    t_json_app.put(
        'PERSONINCHARGEOFEVENT',
        api.pkg_columnquery.VALUE(a_objectid, 'PersonInChargeOfEvent'));

    t_phone :=
        api.pkg_columnquery.VALUE(a_objectid, 'PersonInChargePhoneNumber');

    IF (t_phone IS NOT NULL
    AND LENGTH(t_phone) > 9)
    THEN
        t_json_app.put(
            'PERSONINCHARGEPHONENUMBER',
            '('
            || SUBSTR(t_phone, 1, 3)
            || ')'
            || SUBSTR(t_phone, 4, 3)
            || '-'
            || SUBSTR(t_phone, 7, 4));
    END IF;

    t_json_app.put('EVENTLOCATIONADDRESS1',
                   api.pkg_columnquery.VALUE(t_addressid, 'AddressLine1'));
    t_json_app.put('EVENTLOCATIONADDRESS2',
                   api.pkg_columnquery.VALUE(t_addressid, 'AddressLine2'));
    t_json_app.put('EVENTLOCATIONCITY',
                   api.pkg_columnquery.VALUE(t_addressid, 'CACity'));
    t_json_app.put('EVENTLOCATIONZIP',
                   api.pkg_columnquery.VALUE(t_addressid, 'ZipCode'));
    t_json_app.put('SPECIFICLOCATION',
                   api.pkg_columnquery.VALUE(a_objectid, 'SpecificLocation'));
    t_json_app.put('TOTALAMOUNTDUE',
                   api.pkg_columnquery.VALUE(a_objectid, ''));
    t_json_app.put('SUBMITTEDDATE',
                   api.pkg_columnquery.datevalue(a_objectid, 'CreatedDate'));
    t_json_app.put('CONTACTNAME',
                   api.pkg_columnquery.VALUE(a_objectid, 'ContactName'));

    t_phone := api.pkg_columnquery.VALUE(a_objectid, 'ContactPhoneNumber');

    IF (t_phone IS NOT NULL
    AND LENGTH(t_phone) > 9)
    THEN
        t_json_app.put(
            'CONTACTPHONE',
            '('
            || SUBSTR(t_phone, 1, 3)
            || ')'
            || SUBSTR(t_phone, 4, 3)
            || '-'
            || SUBSTR(t_phone, 7, 4));
    END IF;

    t_json_app.put('CONTACTEMAIL',
                   api.pkg_columnquery.VALUE(a_objectid, 'ContactEmail'));
    t_json_app.put('WITHINCITYLIMITS',
                   api.pkg_columnquery.VALUE(a_objectid, 'WithinCityLimits'));
    t_json_app.put('STATUS',
                   api.pkg_columnquery.VALUE(a_objectid, 'Outcome'));

    t_json_arr.append(t_json_app);
    t_json_data.put('APPLICATION', t_json_arr);
    DBMS_OUTPUT.put_line(t_json_app.TO_CLOB);

    SELECT d.VALUE
      INTO t_data
      FROM api.relationships  r
           LEFT OUTER JOIN doc.documentblobs d ON d.documentid = r.toobjectid
     WHERE r.endpointid =
           api.pkg_configquery.endpointidforname('p_IssueCatererEventAuth',
                                                 'Document')
       AND r.fromobjectid = a_objectid;

    t_url :=
        REPLACE(
            REPLACE(
                t_url,
                '<<path>>',
                CASE ora_database_name
                    WHEN 'ABISST1' THEN 'https://qa-02.abcbiz-qa.abc.ca.gov'
                    WHEN 'ABISP1' THEN 'https://qa-02.abcbiz-qa.abc.ca.gov'
                    ELSE 'https://qa-02.abcbiz-qa.abc.ca.gov'
                END),
            '<<applicationId>>',
            t_applicationid);

    bizmod_api.utl_licenseinfo.clean(a_json => t_json_app);
    DBMS_OUTPUT.put_line(t_json_app.TO_CLOB);

    --        t_response :=
    --            bizmod_api.utl_licenseinfo.calllsp(NULL,
    --                                               t_url,
    --                                               t_json_arr.TO_CLOB);
    --dbms_output.put_line(t_response);

    t_outcome := api.pkg_columnquery.VALUE(a_objectid, 'OutCome');
    DBMS_OUTPUT.put_line(t_outcome || ' : ' || t_url);

    IF (t_outcome IS NOT NULL)
    THEN
        IF (t_outcome = 'Approved')
        THEN
            t_response :=
                bizmod_api.utl_licenseinfo.calllsp(t_url, t_outcome, t_data);
        ELSE
            t_response :=
                bizmod_api.utl_licenseinfo.calllsp(NULL, t_url, t_outcome);
        END IF;
    END IF;

    INSERT INTO bizmod_api.e_process_log_t(seq, processjob, info)
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
                 || t_url);
EXCEPTION
    WHEN OTHERS
    THEN
        t_sqlerrm := SQLERRM;
        t_trace := DBMS_UTILITY.format_error_backtrace;

        --        INSERT INTO bizmod_api.e_process_log_t(seq,
        --                                               processjob,
        --                                               info,
        --                                               errmsg,
        --                                               bktrace)
        --             VALUES (0,
        --                     'CATERINGNOTIFYLSPJOB',
        --                     'Application Id: ' || t_applicationid || chr(13) ||
        --                     case when t_outcome is null then 'Application Update'
        --                          else 'Outcome: ' || t_outcome end || chr(13) ||
        --                     'URL: ' || t_url
        --                     t_sqlerrm,
        --                     t_trace);
        --
        --        COMMIT;
        DBMS_OUTPUT.put_line(t_sqlerrm || CHR(13) || t_trace);

        RAISE;
END;
/
