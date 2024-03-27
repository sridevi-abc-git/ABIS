CREATE OR REPLACE FUNCTION BIZMOD_API.requestlicenselist(
    a_packet       IN CLOB,
    a_seq          IN NUMBER)
    RETURN CLOB
IS
    -- ****************************************************************************
    -- File:        BIZMOD_API.REQUESTLICENSELIST.FNC
    -- Author:      Timothy J. Lord
    --
    -- Purpose :
    --
    -- History:
    -------------------------------------------------------------------------------
    --    Ver:     Date                       Comment
    --          04/13/2022  TJL             Initial Package Created for 19C Database
    --          12/09/2022  TJL             Implemented for eservices after 19C upgrad
    --    3.0   08/07/2023  TJL BIZ-11961   Add CVR to AWFREQUIRED status field for message number 14
    --          11/07/2023  JS  BIZ-13008   Added premise zip and state to return packet
    --    4.0   03/26/2024  TJL BIZ-14833   Rewrote function on how data is selected and from
    --                                        where.
    -- ****************************************************************************

    t_json_obj     json_object_t := json_object_t();
    t_json_arr     json_array_t := json_array_t();

    t_packet       CLOB;
    t_results      CLOB;
    t_sqlerrm      VARCHAR2(4000);
    t_trace        VARCHAR2(4000);
    t_msg          VARCHAR2(4000 BYTE);
BEGIN
    SELECT json_arrayagg(
               json_object(
                   'LICENSEOBJECTID' VALUE lt2.licensejobid,
                   'LICENSENUMBER' VALUE
                       api.pkg_columnquery.VALUE(lt2.licensejobid,
                                                 'LicenseNumber'),
                   'PRIMARYLICENSEE' VALUE
                       api.pkg_columnquery.VALUE(lt2.licensejobid,
                                                 'PrimaryLicensee'), -- Primary Owner
                   'PREMISEADDRESS' VALUE
                       api.pkg_columnquery.VALUE(lt2.licensejobid,
                                                 'PremAddressLine1'), -- Business Address
                   'PREMISECITY' VALUE
                       api.pkg_columnquery.VALUE(lt2.licensejobid,
                                                 'PremAddressUSCity'), -- Business City
                   'PREMISEZIP' VALUE
                       api.pkg_columnquery.VALUE(lt2.licensejobid,
                                                 'PremAddressZipCode'), -- Business Zip
                   'PREMISESTATE' VALUE
                       api.pkg_columnquery.VALUE(lt2.licensejobid,
                                                 'PremAddressState'), -- Business State
                   'BUSINESSNAME' VALUE
                       api.pkg_columnquery.VALUE(lt2.licensejobid,
                                                 'PrimaryDBA'), -- DBA
                   'LICENSE_TYPES' VALUE
                       (SELECT json_arrayagg(
                                   json_object(
                                       'LICENSETYPECODE' VALUE
                                           lt.licensetypecode,
                                       'EXPIRATIONDATE' VALUE
                                           lt.licensetypeexpirationdate,
                                       'STATUS' VALUE
                                           bizmod_api.utl_licenseinfo.statusmatrix(
                                               lt.statusname),
                                       'AWFREQUIRED' VALUE
                                           CASE lt.awfflag
                                               WHEN 'Y'
                                               THEN
                                                   bizmod_api.utl_licenseinfo.checkpayment(
                                                       a_licensenumber =>
                                                           lt.licensenumber,
                                                       a_licensetypecode =>
                                                           lt.licensetypecode,
                                                       a_renewalfeedate =>
                                                           NVL(
                                                               lt.renewalfeedate,
                                                               ADD_MONTHS(
                                                                   lt.licensetypeexpirationdate,
                                                                   -12)))
                                               ELSE
                                                   lt.awfflag
                                           END,
                                       'SECONDARY' VALUE
                                           CASE
                                               WHEN lt.secondaries IS NULL
                                               THEN
                                                   NULL
                                               ELSE
                                                   (SELECT json_arrayagg(
                                                               json_object(
                                                                   'LICENSETYPECODE' VALUE
                                                                       sec.licensetypecode,
                                                                   'EXPIRATIONDATE' VALUE
                                                                       lt.licensetypeexpirationdate,
                                                                   'STATUS' VALUE
                                                                       bizmod_api.utl_licenseinfo.statusmatrix(
                                                                           api.pkg_columnquery.VALUE(
                                                                               sec.id,
                                                                               'Status'))))    end
                                                      FROM JSON_TABLE(
                                                               lt.secondaries,
                                                               '$[*]'
                                                               COLUMNS(
                                                                   licensetypecode PATH '$.LTC',
                                                                   id PATH '$.ID'))
                                                           sec)
                                           END))
                          FROM bizmod_api.licensetype_t lt
                         WHERE lt.licensejobid = lt2.licensejobid))
               RETURNING CLOB)
      INTO t_packet
      FROM (SELECT objectid                                                licensejobid,
                   api.pkg_columnquery.VALUE(objectid, 'LicenseNumber')    licensenumber
              FROM JSON_TABLE(
                       a_packet,
                       '$[*]'
                       COLUMNS(
                           NESTED PATH '$.DATA.OBJECTIDS[*]'
                               COLUMNS(objectid PATH '$')))) lt2;

    t_json_arr := NEW json_array_t(t_packet);
    t_json_obj.put('PACKET_TYPE', 'LICENSELISTINFO');
    t_json_obj.put('DATA', t_json_arr);

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
                               REGEXP_REPLACE(t_sqlerrm, '[^[:print:]]', ' ')))
          INTO t_results
          FROM DUAL;

        RETURN t_results;
END;
/
