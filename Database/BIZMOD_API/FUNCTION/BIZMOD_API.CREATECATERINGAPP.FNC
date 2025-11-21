CREATE OR REPLACE FUNCTION BIZMOD_API.createcateringapp(
    a_packet       IN CLOB,
    a_seq          IN NUMBER)
    RETURN CLOB
IS
    -- ****************************************************************************
    -- File:        BIZMOD_API.CREATECATERINGAPP.FNC
    -- Author:      Timothy J. Lord
    --
    -- Purpose :
    --
    -- History:
    -------------------------------------------------------------------------------
    --    Ver:     Date                       Comment
    --    1.0   09/12/2023  TJL BIZ-12467   Initial Function Created
    --                          BIZ-12643   Validation Rules
    --    1.1   12/14/2023  TJL             Corrected bug in selecting license type
    --    2.0   01/11/2024  TJL BIZ-12162   Added validating License Type status
    --    3.0   06/06/2024  BN  BIZ-15641   Fixed Duplicate Catering Auth packets issue
    --    4.0   08/08/2024  TJL BIZ-16000   Change to new createjob procedure
    --    5.0.1 11/03/2025  TJL BIZ-19526   Change how the parameters are passed to createjob
    -- ****************************************************************************
    t_process      VARCHAR2(40);
    t_json_obj     json_object_t := json_object_t();
    t_json_arr     json_array_t := json_array_t();
    t_json_data    json_object_t := json_object_t();
    t_licensetypecode VARCHAR2(3);
    t_starttime    NUMBER;
    t_endtime      NUMBER;
    t_count        NUMBER;
    t_packet       CLOB;
    t_sqlerrm      VARCHAR2(4000);
    t_trace        VARCHAR2(4000);
    t_msg          VARCHAR2(4000 BYTE);
    t_dupreqcount  NUMBER;
BEGIN
    DBMS_OUTPUT.put_line('packaet information: ' || a_packet);

    FOR rec
        IN (SELECT *
              FROM JSON_TABLE(
                       a_packet,
                       '$'
                       COLUMNS(
                           packet_type VARCHAR2(1000) PATH '$.PACKET_TYPE',
                           NESTED PATH '$.DATA.APPLICATION[*]'
                               COLUMNS(
                                   applicationtype
                                       VARCHAR2(4000)
                                       PATH '$.APPLICATIONTYPE',
                                   lsppaymentid
                                       VARCHAR2(4000)
                                       PATH '$.LSPPAYMENTID',
                                   licensenumber
                                       VARCHAR2(4000)
                                       PATH '$.LICENSENUMBER',
                                   applicationid
                                       VARCHAR2(4000)
                                       PATH '$.APPLICATIONID',
                                   eventstartdate
                                       DATE
                                       PATH '$.EVENTSTARTDATE',
                                   eventenddate DATE PATH '$.EVENTENDDATE',
                                   eventstarttime
                                       VARCHAR2(8)
                                       PATH '$.EVENTSTARTTIME',
                                   eventendtime
                                       VARCHAR2(8)
                                       PATH '$.EVENTENDTIME',
                                   expectedattendance
                                       NUMBER
                                       PATH '$.EXPECTEDATTENDANCE',
                                   publicevent
                                       VARCHAR2(4000)
                                       PATH '$.PUBLICEVENT',
                                   eventtype
                                       VARCHAR2(4000)
                                       PATH '$.EVENTTYPE',
                                   sponsoringorganization
                                       VARCHAR2(4000)
                                       PATH '$.SPONSORINGORGANIZATION',
                                   sponsoringorganizationaddress1
                                       VARCHAR2(4000)
                                       PATH '$.SPONSORINGORGANIZATIONADDRESS1',
                                   sponsoringorganizationaddress2
                                       VARCHAR2(4000)
                                       PATH '$.SPONSORINGORGANIZATIONADDRESS2',
                                   sponsoringorganizationcity
                                       VARCHAR2(4000)
                                       PATH '$.SPONSORINGORGANIZATIONCITY',
                                   sponsoringorganizationzip
                                       VARCHAR2(4000)
                                       PATH '$.SPONSORINGORGANIZATIONZIP',
                                   personinchargeofevent
                                       VARCHAR2(4000)
                                       PATH '$.PERSONINCHARGEOFEVENT',
                                   personinchargephonenumber
                                       VARCHAR2(4000)
                                       PATH '$.PERSONINCHARGEPHONENUMBER',
                                   eventlocationaddress1
                                       VARCHAR2(4000)
                                       PATH '$.EVENTLOCATIONADDRESS1',
                                   eventlocationaddress2
                                       VARCHAR2(4000)
                                       PATH '$.EVENTLOCATIONADDRESS2',
                                   eventlocationcity
                                       VARCHAR2(4000)
                                       PATH '$.EVENTLOCATIONCITY',
                                   eventlocationzip
                                       VARCHAR2(4000)
                                       PATH '$.EVENTLOCATIONZIP',
                                   specificlocation
                                       VARCHAR2(4000)
                                       PATH '$.SPECIFICLOCATION',
                                   contactname
                                       VARCHAR2(4000)
                                       PATH '$.CONTACTNAME',
                                   contactphone
                                       VARCHAR2(4000)
                                       PATH '$.CONTACTPHONE',
                                   contactemail
                                       VARCHAR2(4000)
                                       PATH '$.CONTACTEMAIL',
                                   withincitylimits
                                       VARCHAR2(4000)
                                       PATH '$.WITHINCITYLIMITS',
                                   annualeventscount
                                       NUMBER
                                       PATH '$.ANNUALEVENTSCOUNT',
                                   disclaimerattested
                                       VARCHAR2(4000)
                                       PATH '$.DISCLAIMERATTESTED',
                                   totalamountdue
                                       NUMBER
                                       PATH '$.TOTALAMOUNTDUE',
                                   submitteddate DATE PATH '$.SUBMITTEDDATE'))))
    LOOP
        BEGIN
            SELECT DISTINCT
                   api.pkg_columnquery.VALUE(o.objectid, 'LicenseTypeCode')    licensetypecode
              INTO t_licensetypecode
              FROM TABLE(
                       CAST(
                           api.pkg_simplesearch.castableobjectsbyindex(
                               a_objectdefname => 'j_LicenseType',
                               a_columnname => 'dup_LicenseExternalFileNum',
                               a_value     => rec.licensenumber)
                               AS api.udt_objectlist)) o
                   JOIN api.relationships slt
                       ON (slt.fromobjectid = o.objectid
                       AND slt.endpointid =
                           api.pkg_configquery.endpointidforname(
                               'j_LicenseType',
                               'LicTypeCatSecondary'))
             WHERE api.pkg_columnquery.VALUE(slt.toobjectid,
                                             'LicenseTypeCode') IN
                       ('58')
               AND api.pkg_columnquery.VALUE(o.objectid, 'StatusName') =
                   'ACTIVE';
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                t_json_arr.append('Invalid License Type or Status');
        END;


        -- BIZ-15641   Fixed Duplicate Catering Auth packets issue
        -- Fetching on the number of request which have been present in the ESERVICES_LOG_T

        SELECT COUNT(*)
          INTO t_dupreqcount
          FROM bizmod_api.eservices_log_t eg
         WHERE json_value(eg.packet, '$.DATA.APPLICATION.APPLICATIONID') =
               rec.applicationid
           AND eg.request = 'CREATECATERINGAPP';


        DBMS_OUTPUT.put_line('t_dupReqCount: ' || t_dupreqcount);

        IF (t_dupreqcount > 1)
        THEN
            t_json_arr.append('Duplicate Application Request');
        END IF;


        -- check if duplicate application
        IF (api.pkg_simplesearch.objectbyindex(
                a_objectdefname => 'p_IssueCatererEventAuth',
                a_columnname => 'LSPId',
                a_lowvalue  => rec.applicationid)
                IS NOT NULL)
        THEN
            t_json_arr.append('Duplicate Application Id');
        END IF;

        -- validate fields
        IF (rec.licensenumber IS NULL)
        THEN
            t_json_arr.append('LICENSENUMBER');
        END IF;

        IF (rec.applicationid IS NULL)
        THEN
            t_json_arr.append('APPLICATIONID');
        END IF;

        IF (rec.lsppaymentid IS NULL)
        THEN
            t_json_arr.append('LSPPAYMENTID');
        END IF;

        IF (TRUNC(rec.eventstartdate) NOT BETWEEN TRUNC(SYSDATE + 6)
                                              AND TRUNC(SYSDATE + 60)
         OR rec.eventstartdate IS NULL)
        THEN
            t_json_arr.append('EVENTSTARTDATE');
        END IF;

        IF (TRUNC(rec.eventenddate) NOT BETWEEN (TRUNC(rec.eventstartdate))
                                            AND (TRUNC(
                                                     rec.eventstartdate + 2))
         OR rec.eventenddate IS NULL)
        THEN
            t_json_arr.append('EVENTSTARTDATE');
        END IF;

        t_starttime :=
              TO_NUMBER(
                  REPLACE(NVL(rec.eventstarttime, '02:00:00'), ':', ''))
            / 100;
        t_endtime :=
              TO_NUMBER(REPLACE(NVL(rec.eventendtime, '02:00:00'), ':', ''))
            / 100;

        IF (t_starttime BETWEEN 200 AND 559) -- between 2 and 6 am
        THEN
            t_json_arr.append('EVENTSTARTTIME');
        END IF;

        IF (t_endtime BETWEEN 200 AND 559) -- between 2 and 6 am
        THEN
            t_json_arr.append('EVENTENDTIME');
        ELSE
            IF ((t_starttime < 200
             AND t_endtime > 200)
             OR (t_starttime > 559
             AND t_endtime BETWEEN 200 AND 559)
             OR (t_starttime > 559
             AND t_endtime > 200
             AND t_endtime < t_starttime))
            THEN
                t_json_arr.append('EVENTENDTIME');
            END IF;
        END IF;

        IF (NVL(rec.expectedattendance, 0) <= 0
         OR rec.expectedattendance > 999999)
        THEN
            t_json_arr.append('EXPECTEDATTENDANCE');
        END IF;

        IF (CASE NVL(rec.publicevent, 'x')
                WHEN 'Yes' THEN 0
                WHEN 'No' THEN 0
                ELSE 1
            END =
            1)
        THEN
            t_json_arr.append('PUBLICEVENT');
        END IF;

        IF (NOT REGEXP_LIKE(rec.sponsoringorganizationzip,
                            '([[:digit:]]{5})(-[[:digit:]]{4})?$')
        AND rec.sponsoringorganizationzip IS NOT NULL)
        THEN
            t_json_arr.append('SPONSORINGORGANIZATIONZIP');
        END IF;

        IF (NOT REGEXP_LIKE(rec.personinchargeofevent, '^[A-za-z ,.''-]+$')
        AND rec.personinchargeofevent IS NOT NULL)
        THEN
            t_json_arr.append('PERSONINCHARGEOFEVENT');
        END IF;

        IF (rec.personinchargephonenumber IS NOT NULL
        AND (NOT REGEXP_LIKE(rec.personinchargephonenumber,
                             '^\(\d{3}\)\d{3}-\d{4}$')
          OR LENGTH(rec.personinchargephonenumber) NOT BETWEEN 10 AND 15))
        THEN
            t_json_arr.append('PERSONINCHARGEPHONENUMBER');
        END IF;

        IF (rec.eventlocationaddress1 IS NULL)
        THEN
            t_json_arr.append('EVENTLOCATIONADDRESS1');
        END IF;

        SELECT COUNT(attributevalue)
          INTO t_count
          FROM possedata.objectcolumndata d
         WHERE columndefid = 328470
           AND attributevalue = UPPER(rec.eventlocationcity);

        IF (t_count = 0)
        THEN
            t_json_arr.append('EVENTLOCATIONCITY');
        END IF;


        IF (NOT REGEXP_LIKE(rec.eventlocationzip,
                            '([[:digit:]]{5})(-[[:digit:]]{4})?$')
        AND rec.eventlocationzip IS NOT NULL)
        THEN
            t_json_arr.append('EVENTLOCATIONZIP');
        END IF;

        IF (NOT REGEXP_LIKE(rec.contactname, '^[A-za-z ,.''-]+$')
         OR rec.contactname IS NULL)
        THEN
            t_json_arr.append('CONTACTNAME');
        END IF;

        IF (NOT REGEXP_LIKE(rec.contactphone, '^\(\d{3}\)\d{3}-\d{4}$')
         OR rec.contactphone IS NULL
         OR LENGTH(rec.contactphone) NOT BETWEEN 10 AND 15)
        THEN
            t_json_arr.append('CONTACTPHONE');
        END IF;

        IF (NOT REGEXP_LIKE(
                    rec.contactemail,
                    '^\w([a-zA-Z0-9_.+-]{0,63})@(([a-zA-Z0-9-]+.)+)([a-zA-Z]{2,63}|\d{2,4})(]?)$')
         OR rec.contactemail IS NULL)
        THEN
            t_json_arr.append('CONTACTEMAIL');
        END IF;

        IF (CASE NVL(rec.withincitylimits, 'x')
                WHEN 'Yes' THEN 0
                WHEN 'No' THEN 0
                ELSE 1
            END =
            1)
        THEN
            t_json_arr.append('WITHINCITYLIMITS');
        END IF;

        IF (NVL(rec.annualeventscount, 0) > 36
        AND t_licensetypecode NOT IN ('50', '51', '52'))
        THEN
            t_json_arr.append('ANNUALEVENTSCOUNT');
        END IF;

        IF (CASE NVL(rec.disclaimerattested, 'x')
                WHEN 'Yes' THEN 0
                WHEN 'No' THEN 0
                ELSE 1
            END =
            1)
        THEN
            t_json_arr.append('DISCLAIMERATTESTED');
        END IF;
    END LOOP;

    IF (t_json_arr.get_size() = 0)
    THEN
        bizmod_api.utl_licenseinfo.createjob(
            a_procedure => 'CREATECATERINGAPPJOB',
            a_application_id =>
                json_value(a_packet,
                           '$.DATA.APPLICATION.APPLICATIONID'
                           RETURNING NUMBER),
            a_parameters => bizmod_api.job_prameters_tbl(a_seq, SYSDATE));

        t_json_data.put('MSGNO', '0');
        t_json_data.put('MSG', 'E-Services ' || t_process || ' Scheduled');
    ELSE
        t_msg :=
            'Catering Application Validation Failed: ('
            || a_seq
            || ') '
            || REPLACE(t_json_arr.TO_CLOB, '"', '');

        t_json_data.put('MSGNO', '17');
        t_json_data.put('MSG', t_msg);
    END IF;

    t_json_obj.put('PACKET_TYPE', 'MESSAGE');
    t_json_obj.put('DATA', t_json_data);
    utl_licenseinfo.clean(a_json => t_json_obj);

    RETURN t_json_obj.TO_CLOB;
EXCEPTION
    WHEN OTHERS
    THEN
        t_sqlerrm := SQLERRM;
        t_trace := DBMS_UTILITY.format_error_backtrace;
        t_msg := SUBSTR(t_sqlerrm || CHR(13) || t_trace, 1, 3990);

        UPDATE bizmod_api.eservices_log_t
           SET err = t_msg
         WHERE seq = a_seq;

        COMMIT;

        t_packet :=
            json_object(
                'PACKET_TYPE' VALUE 'MESSAGE',
                'DATA' VALUE
                    json_object('MSGNO' VALUE 5,
                                'MSG' VALUE 'Oracle Exception',
                                'EXCEPTION' VALUE t_sqlerrm));

        RETURN t_packet;
END;
/
