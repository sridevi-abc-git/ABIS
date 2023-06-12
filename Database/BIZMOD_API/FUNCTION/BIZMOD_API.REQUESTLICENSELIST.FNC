CREATE OR REPLACE FUNCTION requestlicenselist(a_packet       IN CLOB,
                                              a_seq          IN NUMBER)
    RETURN CLOB
-- ****************************************************************************
-- File:        REQUESTLICENSELIST.FNC
-- Author:      Timothy J. Lord
--
-- Purpose :
--
-- History:
-------------------------------------------------------------------------------
--    Date                       Comment
--  04/13/2022 TJL   Initial Package Created for 19C Database
--  12/09/2022 TJL   Implemented for eservices after 19C upgrad
-- ****************************************************************************
IS
    t_json_obj     json_object_t;
    t_results      CLOB;
    t_sqlerrm      VARCHAR2(4000);
    t_trace        VARCHAR2(4000);
    t_msg          VARCHAR2(4000 BYTE);
BEGIN
    WITH
        licenses
        AS
            (SELECT *
               FROM JSON_TABLE(
                        a_packet,
                        '$[*]'
                        COLUMNS(
                            NESTED PATH '$.DATA.OBJECTIDS[*]'
                                COLUMNS(objectid PATH '$'))))
    SELECT json_object(
               'PACKET_TYPE' VALUE 'LICENSELISTINFO',
               'DATA' VALUE
                   json_arrayagg(
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
                               api.pkg_columnquery.VALUE(l.objectid,
                                                         'PrimaryDBA'), -- DBA
                           'LICENSE_TYPES' VALUE
                               (SELECT json_arrayagg(
                                           json_object(
                                               'LICENSETYPECODE' VALUE
                                                   ltc.licensetypecode,
                                               'EXPIRATIONDATE' VALUE
                                                   ltc.expirationdate,
                                               'STATUS' VALUE ltc.status,
                                               'AWFREQUIRED' VALUE
                                                   CASE
                                                       WHEN ltc.licensetypecode IN
                                                                ('02', '22')
                                                       THEN
                                                           utl_licenseinfo.awfrequired(
                                                               ltc.licensetypeobjectid)
                                                       ELSE
                                                           'NA'
                                                   END,
                                               'SECONDARY' VALUE
                                                   (SELECT json_arrayagg(
                                                               json_object(
                                                                   'LICENSETYPECODE' VALUE
                                                                       lts.licensetypecode,
                                                                   'EXPIRATIONDATE' VALUE
                                                                       lts.expirationdate,
                                                                   'STATUS' VALUE
                                                                       lts.status))
                                                      FROM (SELECT api.pkg_columnquery.VALUE(
                                                                       slt.toobjectid,
                                                                       'LicenseTypeCode')
                                                                       licensetypecode,
                                                                   api.pkg_columnquery.datevalue(
                                                                       r.toobjectid,
                                                                       'ExpirationDate')
                                                                       expirationdate,
                                                                   bizmod_api.utl_licenseinfo.statusmatrix(
                                                                       api.pkg_columnquery.VALUE(
                                                                           slt.relationshipid,
                                                                           'Status'))
                                                                       status
                                                              FROM api.relationships
                                                                   r
                                                                   JOIN
                                                                   api.relationships
                                                                   slt
                                                                       ON (r.toobjectid =
                                                                           slt.fromobjectid
                                                                       AND slt.endpointid =
                                                                           api.pkg_configquery.endpointidforname(
                                                                               'j_LicenseType',
                                                                               'LicTypeCatSecondary'))
                                                             WHERE r.endpointid =
                                                                   api.pkg_configquery.endpointidforname(
                                                                       'j_License',
                                                                       'LicenseType')
                                                               AND r.fromobjectid =
                                                                   ltc.objectid
                                                               AND slt.toobjectid
                                                                       IS NOT NULL)
                                                           lts)
                                               ABSENT ON NULL))
                                  FROM (SELECT DISTINCT
                                               r.fromobjectid
                                                   objectid,
                                               api.pkg_columnquery.VALUE(
                                                   r.toobjectid,
                                                   'LicenseTypeCode')
                                                   licensetypecode,
                                               api.pkg_columnquery.datevalue(
                                                   r.toobjectid,
                                                   'ExpirationDate')
                                                   expirationdate,
                                               bizmod_api.utl_licenseinfo.statusmatrix(
                                                   api.pkg_columnquery.VALUE(
                                                       r.toobjectid,
                                                       'StatusDescription'))
                                                   status,
                                               r.toobjectid
                                                   licensetypeobjectid
                                          FROM api.relationships r
                                         WHERE r.endpointid =
                                               api.pkg_configquery.endpointidforname(
                                                   'j_License',
                                                   'LicenseType')
                                           AND r.fromobjectid = l.objectid)
                                       ltc)))
               RETURNING CLOB)
      INTO t_results
      FROM licenses l;

    t_json_obj := NEW json_object_t(t_results);
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