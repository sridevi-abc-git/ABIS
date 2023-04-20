CREATE OR REPLACE FUNCTION BIZMOD_API.requestlicenselist(a_packet       IN CLOB,
                                              a_seq          IN NUMBER)
    RETURN CLOB
IS
    -- ****************************************************************************
    -- File:        REQUESTLICENSELIST.SQL
    -- Author:      Timothy J. Lord
    --
    -- Purpose :    This function is called thru the eservices API to return a
    --              list of licenses. A JSON packet with an array of License
    --              Object ids is passed into this function to select which
    --              licenses will be returned in a JSON packet.
    --
    -- History:
    -------------------------------------------------------------------------------
    --    Date           Ticket     Comment
    --  04/13/2022 TJL  BIZ-5919  Initial Function Created
    --  04/21/2022 TJL            Fixed bug single-row subquery return more than
    --                              one row
    --  05/09/2022 TJL            Fixed bug in wrong secondary License Type being
    --                              returned. Change from calling function
    --                              statusmatrix to the function in utl_licenseinfo
    --                              package statusmatrix.
    -- ****************************************************************************
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
                            NESTED PATH '$.OBJECTIDS[*]'
                                COLUMNS(objectid PATH '$'))))
    SELECT TO_CLOB(
               '{"PACKET_TYPE":"LICENSELISTINFO","DATA":['
               || x.license
               || ']}')    info
      INTO t_results
      FROM (SELECT LISTAGG(
                       TO_CLOB(
                           '{"LICENSEOBJECTID":'
                           || l.objectid
                           || ',"LICENSENUMBER":"'
                           || api.pkg_columnquery.VALUE(l.objectid,
                                                        'licensenumber')
                           || '","PRIMARYLICENSEE":"'
                           || api.pkg_columnquery.VALUE(l.objectid,
                                                        'PrimaryLicensee')
                           ||                                 -- Primary Owner
                              '","PREMISEADDRESS":"'
                           || api.pkg_columnquery.VALUE(l.objectid,
                                                        'PremAddressLine1')
                           ||                              -- Business Address
                              '","PREMISECITY":"'
                           || api.pkg_columnquery.VALUE(l.objectid,
                                                        'PremAddressUSCity')
                           ||                                 -- Business City
                              '","BUSINESSNAME":"'
                           || api.pkg_columnquery.VALUE(l.objectid,
                                                        'PrimaryDBA')
                           ||                                           -- DBA
                              '",'
                           || (SELECT TO_CLOB(
                                          '"LICENSE_TYPES":['
                                          || LISTAGG(
                                                 '{"LICENSETYPECODE":"'
                                                 || api.pkg_columnquery.VALUE(
                                                        r.toobjectid,
                                                        'LicenseTypeCode')
                                                 || '","EXPIRATIONDATE":"'
                                                 || TO_CHAR(
                                                        api.pkg_columnquery.datevalue(
                                                            r.toobjectid,
                                                            'ExpirationDate'),
                                                        'YYYY-MM-DD"T"HH24:MI:SS"Z"')
                                                 || '","STATUS":"'
                                                 || utl_licenseinfo.statusmatrix(
                                                        api.pkg_columnquery.VALUE(
                                                            r.toobjectid,
                                                            'StatusDescription'))
                                                 || '"'
                                                 || (  SELECT NVL2(
                                                                  slt.fromobjectid,
                                                                  ',"SECONDARY":['
                                                                  || LISTAGG(
                                                                         '{"LICENSETYPECODE":"'
                                                                         || api.pkg_columnquery.VALUE(
                                                                                slt.toobjectid,
                                                                                'LicenseTypeCode')
                                                                         || '","EXPIRATIONDATE":"'
                                                                         || TO_CHAR(
                                                                                api.pkg_columnquery.datevalue(
                                                                                    r.toobjectid,
                                                                                    'ExpiratiONDate'),
                                                                                'YYYY-MM-DD"T"HH24:MI:SS"Z"')
                                                                         || '","STATUS":"'
                                                                         || utl_licenseinfo.statusmatrix(
                                                                                api.pkg_columnquery.VALUE(
                                                                                    slt.relationshipid,
                                                                                    'Status'))
                                                                         || '"}',
                                                                         ',')
                                                                     WITHIN GROUP (ORDER BY
                                                                                       1)
                                                                  || ']',
                                                                  NULL)    secondarylicensetype
                                                         FROM api.relationships
                                                              slt
                                                        WHERE (r.toobjectid =
                                                               slt.fromobjectid
                                                           AND slt.endpointid =
                                                               api.pkg_configquery.endpointidforname(
                                                                   'j_LicenseType',
                                                                   'LicTypeCatSecONdary')
                                                           AND slt.relationshipid
                                                                   IS NOT NULL)
                                                     GROUP BY slt.fromobjectid)
                                                 || '}',
                                                 ',')
                                             WITHIN GROUP (ORDER BY 1)
                                          || ']')    licensetype
                                 FROM api.relationships r
                                WHERE r.endpointid =
                                      api.pkg_configquery.endpointidforname(
                                          'j_License',
                                          'LicenseType')
                                  AND r.fromobjectid = l.objectid)
                           || '}'),
                       ',')
                   WITHIN GROUP (ORDER BY 1)    license
              FROM licenses l) x;

    RETURN REGEXP_REPLACE(t_results, '[^[:print:]]', '');
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

        t_results :=
            '{"PACKET_TYPE":"MESSAGE","DATA":{"MSGNO":"5","MSG":"Oracle Exception","EXCEPTION":"'
            || REGEXP_REPLACE(t_sqlerrm, '[^[:print:]]', '')
            || '"}}';

        RETURN t_results;
END;
/
