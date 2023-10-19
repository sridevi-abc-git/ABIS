CREATE OR REPLACE FUNCTION BIZMOD_API.requestcateringinfo(
    a_packet       IN CLOB,
    a_seq          IN NUMBER)
    RETURN CLOB
IS
    -- ****************************************************************************
    -- File:        BIZMOD_API.REQUESTCATERINGINFO.FNC
    -- Author:      Timothy J. Lord
    --
    -- Purpose :
    --
    -- History:
    -------------------------------------------------------------------------------
    --    Ver:     Date                       Comment
    --          10/11/2022  TJL BIZ-12463  Initial Package Created
    -- ****************************************************************************
    FUNCTION parseaddress(a_address IN VARCHAR2)
        RETURN var_tbl
    IS
        t_address      var_tbl := var_tbl();
        t_parse        var_tbl;
        t_count        NUMBER := 1;
    BEGIN
        t_address.EXTEND(5);

            SELECT REGEXP_SUBSTR(a_address,
                                 '[^,]+',
                                 1,
                                 LEVEL)
              BULK COLLECT INTO t_parse
              FROM DUAL
        CONNECT BY REGEXP_SUBSTR(a_address,
                                 '[^,]+',
                                 1,
                                 LEVEL)
                       IS NOT NULL;

        FOR inx IN t_parse.FIRST .. t_parse.LAST
        LOOP
            t_address(t_count) := t_parse(inx);
            t_count := t_count + 1;
        END LOOP;

        RETURN t_address;
    END;
BEGIN
    DECLARE
        t_json_obj     json_object_t := json_object_t();
        t_json_arr     json_array_t := json_array_t();
        t_json_app     json_object_t;
        t_json_data    json_object_t := json_object_t();
        t_address      var_tbl;

        t_addressid    NUMBER;
        t_packet       CLOB;
        t_results      CLOB;
        t_sqlerrm      VARCHAR2(4000);
        t_trace        VARCHAR2(4000);
        t_msg          VARCHAR2(4000 BYTE);
    BEGIN
        FOR lic
            IN (SELECT objectid,
                       NVL(startdate, TRUNC(SYSDATE))        startdate,
                       NVL(enddate, TRUNC(SYSDATE + 90))     enddate
                  FROM JSON_TABLE(
                           a_packet,
                           '$[*]'
                           COLUMNS(
                               NESTED PATH '$.DATA.OBJECTIDS[*]'
                                   COLUMNS(objectid PATH '$'),
                               startdate DATE PATH '$.DATA.STARTDATE',
                               enddate DATE PATH '$.DATA.ENDDATE')))
        LOOP
            FOR c
                IN (WITH
                        cat
                        AS
                            (SELECT /*+ materialize */
                                    p.processid,
                                    api.pkg_columnquery.datevalue(
                                        p.processid,
                                        'DateOfEventFrom')
                                        dateofeventfrom,
                                    api.pkg_columnquery.datevalue(
                                        p.processid,
                                        'DateOfEventTo')
                                        dateofeventto
                               FROM api.relationships  r
                                    JOIN api.relationships lt
                                        ON (lt.endpointid =
                                            api.pkg_configquery.endpointidforname(
                                                'j_LicenseType',
                                                'LicTypeCatSecondary')
                                        AND api.pkg_columnquery.VALUE(
                                                lt.toobjectid,
                                                'LicenseTypeCode') =
                                            '58'
                                        AND api.pkg_columnquery.VALUE(
                                                lt.relationshipid,
                                                'Status') =
                                            'ACTIVE')
                                    JOIN api.processes p
                                        ON (p.jobid = lt.fromobjectid
                                        AND p.processtypeid =
                                            api.pkg_configquery.objectdefidforname(
                                                'p_IssueCatererEventAuth'))
                              WHERE r.endpointid =
                                    api.pkg_configquery.endpointidforname(
                                        'j_License',
                                        'LicenseType')
                                AND r.fromobjectid = lic.objectid
                                AND lt.fromobjectid = r.toobjectid)
                    SELECT cat.processid
                      FROM cat
                     WHERE cat.dateofeventfrom BETWEEN lic.startdate
                                                   AND lic.enddate
                        OR cat.dateofeventto BETWEEN lic.startdate
                                                 AND lic.enddate)
            LOOP
                t_address :=
                    parseaddress(
                        api.pkg_columnquery.VALUE(
                            c.processid,
                            'SponsoringOrganizationMailing'));
                t_addressid :=
                    api.pkg_columnquery.VALUE(c.processid,
                                              'EventLocAddressObjectId');

                t_json_app := NEW json_object_t();
                t_json_app.put(
                    'APPLICATIONTYPE',
                    TRIM(
                        REGEXP_SUBSTR(
                            api.pkg_columnquery.VALUE(c.processid,
                                                      'CateringOrEvent'),
                            '[^-]+',
                            1,
                            2)));
                t_json_app.put('LSPPAYMENTID',
                               api.pkg_columnquery.VALUE(c.processid, ''));
                t_json_app.put(
                    'LICENSENUMBER',
                    api.pkg_columnquery.VALUE(c.processid, 'LicenseNumber'));
                t_json_app.put(
                    'APPLICATIONID',
                    api.pkg_columnquery.VALUE(c.processid, 'LSPId'));
                t_json_app.put(
                    'EVENTSTARTDATE',
                    api.pkg_columnquery.VALUE(c.processid, 'DateOfEventFrom'));
                t_json_app.put(
                    'EVENTENDDATE',
                    api.pkg_columnquery.VALUE(c.processid, 'dateofeventto'));
                t_json_app.put('EVENTSTARTTIME',
                               api.pkg_columnquery.VALUE(c.processid, ''));
                t_json_app.put('EVENTENDTIME',
                               api.pkg_columnquery.VALUE(c.processid, ''));
                t_json_app.put(
                    'EXPECTEDATTENDANCE',
                    api.pkg_columnquery.VALUE(c.processid,
                                              'EstimatedAttendance'));
                t_json_app.put(
                    'PUBLICEVENT',
                    api.pkg_columnquery.VALUE(c.processid, 'PublicEvent'));
                t_json_app.put(
                    'EVENTTYPE',
                    api.pkg_columnquery.VALUE(c.processid, 'EventType'));
                t_json_app.put(
                    'SPONSORINGORGANIZATION',
                    api.pkg_columnquery.VALUE(c.processid,
                                              'SponsoringOrganization'));
                t_json_app.put('SPONSORINGORGANIZATIONADDRESS1',
                               t_address(1));
                t_json_app.put('SPONSORINGORGANIZATIONADDRESS2',
                               t_address(2));
                t_json_app.put('SPONSORINGORGANIZATIONCITY', t_address(3));
                t_json_app.put('SPONSORINGORGANIZATIONSTATE', t_address(4));
                t_json_app.put('SPONSORINGORGANIZATIONZIP', t_address(5));
                t_json_app.put(
                    'PERSONINCHARGEOFEVENT',
                    api.pkg_columnquery.VALUE(c.processid,
                                              'PersonInChargeOfEvent'));
                t_json_app.put(
                    'PERSONINCHARGEPHONENUMBER',
                    api.pkg_columnquery.VALUE(c.processid,
                                              'PersonInChargePhoneNumber'));
                t_json_app.put(
                    'EVENTLOCATIONADDRESS1',
                    api.pkg_columnquery.VALUE(t_addressid, 'AddressLine1'));
                t_json_app.put(
                    'EVENTLOCATIONADDRESS2',
                    api.pkg_columnquery.VALUE(t_addressid, 'AddressLine2'));
                t_json_app.put(
                    'EVENTLOCATIONCITY',
                    api.pkg_columnquery.VALUE(t_addressid, 'CACity'));
                t_json_app.put(
                    'EVENTLOCATIONZIP',
                    api.pkg_columnquery.VALUE(t_addressid, 'ZipCode'));
                t_json_app.put(
                    'SPECIFICLOCATION',
                    api.pkg_columnquery.VALUE(c.processid,
                                              'SpecificLocation'));
                t_json_app.put('TOTALAMOUNTDUE',
                               api.pkg_columnquery.VALUE(c.processid, ''));
                t_json_app.put(
                    'SUBMITTEDDATE',
                    api.pkg_columnquery.VALUE(c.processid, 'CreatedDate'));
                t_json_app.put(
                    'CONTACTNAME',
                    api.pkg_columnquery.VALUE(c.processid, 'ContactName'));
                t_json_app.put(
                    'CONTACTPHONE',
                    api.pkg_columnquery.VALUE(c.processid,
                                              'ContactPhoneNumber'));
                t_json_app.put(
                    'CONTACTEMAIL',
                    api.pkg_columnquery.VALUE(c.processid, 'ContactEmail'));
                t_json_app.put(
                    'WITHINCITYLIMITS',
                    api.pkg_columnquery.VALUE(c.processid,
                                              'WithinCityLimits'));
                t_json_app.put('ANNUALEVENTSCOUNT',
                               api.pkg_columnquery.VALUE(c.processid, ''));
                t_json_app.put('DISCLAIMERATTESTED',
                               api.pkg_columnquery.VALUE(c.processid, ''));

                t_json_arr.append(t_json_app);
            END LOOP;
        END LOOP;

        IF (t_json_arr.get_size() > 0)
        THEN
            t_json_data.put('APPLICATION', t_json_arr);
        ELSE
            t_json_data.put('MSGNO', '0');
            t_json_data.put('MSG', 'No Catering Applications Found');
        END IF;

        t_json_obj.put('PACKET_TYPE', 'LICENSELISTINFO');
        t_json_obj.put('DATA', t_json_data);
        utl_licenseinfo.clean(a_json => t_json_obj);

        RETURN t_json_obj.TO_CLOB;
    EXCEPTION
        WHEN OTHERS
        THEN
            t_sqlerrm := SQLERRM;
            t_trace := DBMS_UTILITY.format_error_backtrace;
            t_msg := SUBSTR(t_sqlerrm || ' :: ' || t_trace, 1, 3990);

            UPDATE bizmod_api.eservices_log_t
               SET err = t_msg
             WHERE seq = a_seq;

            COMMIT;

            SELECT json_object(
                       'PACKET_TYPE' VALUE 'MESSAGE',
                       'DATA' VALUE
                           json_object(
                               'MSGNO' VALUE 5,
                               'MSG' VALUE 'Oracle Exception',
                               'EXCEPTION' VALUE
                                   REGEXP_REPLACE(t_sqlerrm,
                                                  '[^[:print:]]',
                                                  ' ')))
              INTO t_results
              FROM DUAL;

            RETURN t_results;
    END;
END;
/
