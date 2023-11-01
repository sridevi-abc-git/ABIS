CREATE OR REPLACE PACKAGE BODY SITESPECIFIC.pkg_catering
AS
    -- **************************************************************************
    -- File:        PSITESPECIFIC.PKG_CATERING.PKB
    -- Author:      Timothy J. Lord
    --
    -- History:
    -----------------------------------------------------------------------------
    --    Ver:     Date                       Comment
    --     1.0   11/01/2023  TJL BIZ-12802  Initial Package Created
    -- **************************************************************************
    PROCEDURE cateringnotifylsp(a_objectid api.pkg_definition.udt_id, a_asofdate DATE)
    IS
        t_data         BLOB;
        t_lspid        VARCHAR2(100);
        t_outcome      VARCHAR2(20);
        t_lsp          VARCHAR2(1000)
            := '<<path>>/api/licensing/internal/catering/applications/<<applicationId>>';
        t_packet       CLOB;
        t_response     CLOB;

        t_sponsoringorganizationaddr VARCHAR(1000);
        t_addressid    NUMBER;
        t_address      var_tbl := var_tbl();
    BEGIN
        t_sponsoringorganizationaddr :=
            api.pkg_columnquery.VALUE(a_objectid,
                                      'SponsoringOrganizationMailing');
        t_addressid :=
            api.pkg_columnquery.VALUE(a_objectid, 'EventLocAddressObjectId');

        t_address.EXTEND(5);

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

        t_address :=
            parseaddress(
                api.pkg_columnquery.VALUE(a_objectid,
                                          'SponsoringOrganizationMailing'));
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
        t_json_app.put(
            'LICENSENUMBER',
            api.pkg_columnquery.VALUE(a_objectid, 'LicenseNumber'));
        t_json_app.put('APPLICATIONID',
                       api.pkg_columnquery.VALUE(a_objectid, 'LSPId'));
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
                    CASE api.pkg_columnquery.VALUE(
                             a_objectid,
                             'BeginServingAlcoholAMPMTime')
                        WHEN 'PM'
                        THEN
                            TO_CHAR(
                                  api.pkg_columnquery.numericvalue(
                                      a_objectid,
                                      'Timeyouwillbeginservingalcohol')
                                + 1200)
                        ELSE
                            TO_CHAR(
                                api.pkg_columnquery.numericvalue(
                                    a_objectid,
                                    'Timeyouwillbeginservingalcohol'))
                    END,
                    'HH24MI'),
                'HH24:MI:SS'));
        t_json_app.put(
            'EVENTENDTIME',
            TO_CHAR(
                TO_TIMESTAMP(
                    CASE api.pkg_columnquery.VALUE(
                             a_objectid,
                             'StopServingAlcoholAMPMTime')
                        WHEN 'PM'
                        THEN
                            TO_CHAR(
                                  api.pkg_columnquery.numericvalue(
                                      a_objectid,
                                      'TimeYouWillStopServingAlcohol')
                                + 1200)
                        ELSE
                            TO_CHAR(
                                api.pkg_columnquery.numericvalue(
                                    a_objectid,
                                    'TimeYouWillStopServingAlcohol'))
                    END,
                    'HH24MI'),
                'HH24:MI:SS'));
        t_json_app.put(
            'EXPECTEDATTENDANCE',
            api.pkg_columnquery.numericvalue(a_objectid,
                                             'EstimatedAttendance'));
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
            api.pkg_columnquery.VALUE(a_objectid,
                                      'PersonInChargePhoneNumber');

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

        t_json_app.put(
            'EVENTLOCATIONADDRESS1',
            api.pkg_columnquery.VALUE(t_addressid, 'AddressLine1'));
        t_json_app.put(
            'EVENTLOCATIONADDRESS2',
            api.pkg_columnquery.VALUE(t_addressid, 'AddressLine2'));
        t_json_app.put('EVENTLOCATIONCITY',
                       api.pkg_columnquery.VALUE(t_addressid, 'CACity'));
        t_json_app.put('EVENTLOCATIONZIP',
                       api.pkg_columnquery.VALUE(t_addressid, 'ZipCode'));
        t_json_app.put(
            'SPECIFICLOCATION',
            api.pkg_columnquery.VALUE(a_objectid, 'SpecificLocation'));
        t_json_app.put('TOTALAMOUNTDUE',
                       api.pkg_columnquery.VALUE(a_objectid, ''));
        t_json_app.put(
            'SUBMITTEDDATE',
            api.pkg_columnquery.datevalue(a_objectid, 'CreatedDate'));
        t_json_app.put('CONTACTNAME',
                       api.pkg_columnquery.VALUE(a_objectid, 'ContactName'));

        t_phone :=
            api.pkg_columnquery.VALUE(a_objectid, 'ContactPhoneNumber');

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
        t_json_app.put(
            'WITHINCITYLIMITS',
            api.pkg_columnquery.VALUE(a_objectid, 'WithinCityLimits'));
        t_json_app.put('STATUS',
                       api.pkg_columnquery.VALUE(a_objectid, 'Outcome'));

        t_json_arr.append(t_json_app);


        SELECT d.VALUE,
               api.pkg_columnquery.VALUE(r.fromobjectid, 'LSPId')    applicationid
          INTO t_data, t_lspid
          FROM api.relationships  r
               LEFT OUTER JOIN doc.documentblobs_t d
                   ON d.documentid = r.toobjectid
         WHERE r.endpointid =
               api.pkg_configquery.endpointidforname(
                   'p_IssueCatererEventAuth',
                   'Document')
           AND r.fromobjectid = a_objectid;

        t_lsp :=
            REPLACE(
                REPLACE(
                    t_lsp,
                    '<<path>>',
                    CASE ora_database_name
                        WHEN 'ABISST1'
                        THEN
                            'https://qa-02.abcbiz-qa.abc.ca.gov'
                        WHEN 'ABISP1'
                        THEN
                            'https://qa-02.abcbiz-qa.abc.ca.gov'
                        ELSE
                            'https://qa-02.abcbiz-qa.abc.ca.gov'
                    END),
                '<<applicationId>>',
                t_applicationid);

        utl_licenseinfo.clean(a_json => t_json_arr);

        t_response :=
            bizmod_api.utl_licenseinfo.calllsp(NULL,
                                               t_lsp,
                                               t_json_arr.TO_CLOB);

        t_outcome := api.pkg_columnquery.VALUE(a_objectid, 'OutCome');

        IF (t_outcome IS NOT NULL)
        THEN
            IF (t_outcome = 'Approved')
            THEN
                t_response :=
                    bizmod_api.utl_licenseinfo.calllsp(t_lsp,
                                                       t_outcome,
                                                       t_data);
            ELSE
                t_response :=
                    bizmod_api.utl_licenseinfo.calllsp(NULL,
                                                       t_lsp,
                                                       t_outcome);
            END IF;
        END IF;
    END;
END;
/
