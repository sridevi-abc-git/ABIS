CREATE OR REPLACE FUNCTION BIZMOD_API.requestlicenselist(a_packet       IN CLOB,
                                              a_seq          IN NUMBER)
    RETURN CLOB
IS
    -- ****************************************************************************
    -- File:        REQUESTLICENSELIST.FNC
    -- Author:      Timothy J. Lord
    --
    -- Purpose :
    --
    -- History:
    -------------------------------------------------------------------------------
    --    Date                       Comment
    --  04/13/2022 TJL              Initial Package Created for 19C Database
    --  12/09/2022 TJL              Implemented for eservices after 19C upgrad
    --  07/19/2023 TJL  BIZ-11770   Correct string to long bug exception
    --  07/20/2023 TJL  BIZ-11991   
    -- ****************************************************************************
    FUNCTION secondary(a_licensetypejobid IN NUMBER)
        RETURN CLOB
    IS
        t_packet       CLOB;
    BEGIN
        SELECT json_arrayagg(
                   json_object(
                       'LICENSETYPECODE' VALUE
                           api.pkg_columnquery.VALUE(slt.toobjectid,
                                                     'LicenseTypeCode'),
                       'EXPIRATIONDATE' VALUE
                           api.pkg_columnquery.datevalue(a_licensetypejobid,
                                                         'ExpirationDate'),
                       'STATUS' VALUE
                           bizmod_api.utl_licenseinfo.statusmatrix(
                               api.pkg_columnquery.VALUE(slt.relationshipid,
                                                         'Status'))))
          INTO t_packet
          FROM api.relationships slt
         WHERE (a_licensetypejobid = slt.fromobjectid
            AND slt.endpointid =
                api.pkg_configquery.endpointidforname('j_LicenseType',
                                                      'LicTypeCatSecondary'));

        RETURN t_packet;
    END;

    FUNCTION licensetypes(a_licensejobid IN NUMBER)
        RETURN CLOB
    IS
        t_json_arr     json_array_t := json_array_t();
        t_json         json_object_t := json_object_t();
        t_packet       CLOB;
    BEGIN
        FOR o
            IN (SELECT r.toobjectid                                    objectid,
                       api.pkg_columnquery.VALUE(r.toobjectid,
                                                 'LicenseTypeCode')    licensetypecode
                  FROM api.relationships r
                 WHERE r.endpointid =
                       api.pkg_configquery.endpointidforname('j_License',
                                                             'LicenseType')
                   AND r.fromobjectid = a_licensejobid)
        LOOP
            t_packet :=
                json_object(
                    'LICENSETYPECODE' VALUE o.licensetypecode,
                    'EXPIRATIONDATE' VALUE
                        api.pkg_columnquery.datevalue(o.objectid,
                                                      'ExpirationDate'),
                    'STATUS' VALUE
                        bizmod_api.utl_licenseinfo.statusmatrix(
                            api.pkg_columnquery.VALUE(o.objectid,
                                                      'StatusDescription')),
                    'AWFREQUIRED' VALUE
                        CASE
                            WHEN o.licensetypecode IN ('02', '22')
                            THEN 
                                case nvl(utl_licenseinfo.awfrequired(o.objectid), 0) 
                                  when 0 then 'Y'
                                  when 7 then 'Y'   -- not renewed in penalty
                                  when 8 then 'NA'
                                  else 'N' end
                            ELSE
                                'NA'
                        END,
                    'SECONDARY' VALUE secondary(o.objectid) FORMAT JSON);

            t_json_arr.append(json_object_t(t_packet));
        END LOOP;


        RETURN t_json_arr.TO_CLOB;
    END;
BEGIN
    DECLARE
        t_json_obj     json_object_t;
        t_json_arr     json_array_t;

        t_packet       CLOB;
        t_results      CLOB;
        t_sqlerrm      VARCHAR2(4000);
        t_trace        VARCHAR2(4000);
        t_msg          VARCHAR2(4000 BYTE);
    BEGIN
        -- 07/19/2023 TJL  BIZ-11770 
        t_json_obj := NEW json_object_t(json_object('PACKET_TYPE' VALUE 'LICENSELISTINFO'));
        t_json_obj.put('DATA', new json_array_t());
        t_json_arr := t_json_obj.get_Array('DATA');
        
        FOR l
            IN ((SELECT *
                   FROM JSON_TABLE(
                            a_packet,
                            '$[*]'
                            COLUMNS(
                                NESTED PATH '$.DATA.OBJECTIDS[*]'
                                    COLUMNS(objectid PATH '$')))))
        LOOP
            t_packet :=
                json_object(
                    'LICENSEOBJECTID' VALUE l.objectid,
                    'LICENSENUMBER' VALUE
                        api.pkg_columnquery.VALUE(l.objectid,
                                                  'licensenumber'),
                    'PRIMARYLICENSEE' VALUE
                        api.pkg_columnquery.VALUE(l.objectid,
                                                  'PrimaryLicensee'), -- Primary Owner
                    'PREMISEADDRESS' VALUE
                        api.pkg_columnquery.VALUE(l.objectid,
                                                  'PremAddressLine1'), -- Business Address
                    'PREMISECITY' VALUE
                        api.pkg_columnquery.VALUE(l.objectid,
                                                  'PremAddressUSCity'), -- Business City
                    'BUSINESSNAME' VALUE
                        api.pkg_columnquery.VALUE(l.objectid, 'PrimaryDBA'), -- DBA
                    'LICENSE_TYPES' VALUE
                        licensetypes(l.objectid) FORMAT JSON);

            t_json_arr.append(json_object_t(t_packet));
        END LOOP;

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
