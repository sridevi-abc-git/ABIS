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
    --          10/11/2022  TJL BIZ-12463  Initial Package Created for 19C Database
    -- ****************************************************************************
    t_json_obj     json_object_t;
    t_json_arr     json_array_t := json_array_t();

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
                        (SELECT p.processid,
                                api.pkg_columnquery.datevalue(
                                    p.processid,
                                    'DateOfEventTo')    dateofeventto
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
                            AND r.fromobjectid = lic.objectid)
                SELECT cat.processid
                  FROM cat
                 WHERE cat.dateofeventto BETWEEN lic.startdate
                                             AND lic.enddate)
        LOOP
            t_addressid :=
                api.pkg_columnquery.VALUE(c.processid,
                                          'EventLocAddressObjectId');

            t_packet :=
                json_object(
                    'APPLICATIONTYPE' VALUE
                        TRIM(
                            REGEXP_SUBSTR(
                                api.pkg_columnquery.VALUE(c.processid,
                                                          'CateringOrEvent'),
                                '[^-]+',
                                1,
                                2)),
                    'LSPPAYMENTID' VALUE
                        api.pkg_columnquery.VALUE(c.processid, ''),
                    'LICENSENUMBER' VALUE
                        api.pkg_columnquery.VALUE(c.processid,
                                                  'LicenseNumber'),
                    'APPLICATIONID' VALUE
                        api.pkg_columnquery.VALUE(c.processid, 'LSPId'),
                    'EVENTSTARTDATE' VALUE
                        api.pkg_columnquery.VALUE(c.processid,
                                                  'DateOfEventFrom'),
                    'EVENTENDDATE' VALUE
                        api.pkg_columnquery.VALUE(c.processid,
                                                  'dateofeventto'),
                    'EVENTSTARTTIME' VALUE
                        api.pkg_columnquery.VALUE(c.processid, ''),
                    'EVENTENDTIME' VALUE
                        api.pkg_columnquery.VALUE(c.processid, ''),
                    'EXPECTEDATTENDANCE' VALUE
                        api.pkg_columnquery.VALUE(c.processid,
                                                  'EstimatedAttendance'),
                    'PUBLICEVENT' VALUE
                        api.pkg_columnquery.VALUE(c.processid, 'PublicEvent'),
                    'EVENTTYPE' VALUE
                        api.pkg_columnquery.VALUE(c.processid, 'EventType'),
                    'SPONSORINGORGANIZATION' VALUE
                        api.pkg_columnquery.VALUE(c.processid,
                                                  'SponsoringOrganization'),
                    'SPONSORINGORGANIZATIONADDRESS1' VALUE
                        api.pkg_columnquery.VALUE(c.processid, ''),
                    'SPONSORINGORGANIZATIONADDRESS2' VALUE
                        api.pkg_columnquery.VALUE(c.processid, ''),
                    'SPONSORINGORGANIZATIONCITY' VALUE
                        api.pkg_columnquery.VALUE(c.processid, ''),
                    'SPONSORINGORGANIZATIONZIP' VALUE
                        api.pkg_columnquery.VALUE(c.processid, ''),
                    'PERSONINCHARGEOFEVENT' VALUE
                        api.pkg_columnquery.VALUE(c.processid,
                                                  'PersonInChargeOfEvent'),
                    'PERSONINCHARGEPHONENUMBER' VALUE
                        api.pkg_columnquery.VALUE(
                            c.processid,
                            'PersonInChargePhoneNumber'),
                    'EVENTLOCATIONADDRESS1' VALUE
                        api.pkg_columnquery.VALUE(t_addressid,
                                                  'AddressLine1'),
                    'EVENTLOCATIONADDRESS2' VALUE
                        api.pkg_columnquery.VALUE(t_addressid,
                                                  'AddressLine2'),
                    'EVENTLOCATIONCITY' VALUE
                        api.pkg_columnquery.VALUE(t_addressid, 'CACity'),
                    'EVENTLOCATIONZIP' VALUE
                        api.pkg_columnquery.VALUE(t_addressid, 'ZipCode'),
                    'SPECIFICLOCATION' VALUE
                        api.pkg_columnquery.VALUE(c.processid,
                                                  'SpecificLocation'),
                    'TOTALAMOUNTDUE' VALUE
                        api.pkg_columnquery.VALUE(c.processid, ''),
                    'SUBMITTEDDATE' VALUE
                        api.pkg_columnquery.VALUE(c.processid, 'CreatedDate'),
                    'CONTACTNAME' VALUE
                        api.pkg_columnquery.VALUE(c.processid, 'ContactName'),
                    'CONTACTPHONE' VALUE
                        api.pkg_columnquery.VALUE(c.processid,
                                                  'ContactPhoneNumber'),
                    'CONTACTEMAIL' VALUE
                        api.pkg_columnquery.VALUE(c.processid,
                                                  'ContactEmail'),
                    'WITHINCITYLIMITS' VALUE
                        api.pkg_columnquery.VALUE(c.processid,
                                                  'WithinCityLimits'),
                    'ANNUALEVENTSCOUNT' VALUE
                        api.pkg_columnquery.VALUE(c.processid, ''),
                    'DISCLAIMERATTESTED' VALUE
                        api.pkg_columnquery.VALUE(c.processid, ''));
        END LOOP;
    END LOOP;
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
                               REGEXP_REPLACE(t_sqlerrm, '[^[:print:]]', ' ')))
          INTO t_results
          FROM DUAL;

        RETURN t_results;
END;
/
