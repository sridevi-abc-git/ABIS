CREATE OR REPLACE PACKAGE BODY BIZMOD_API.utl_licenseinfo
AS
    -- ****************************************************************************
    -- File:        BIZMOD_API.UTL_LICENSEINFO.PKB
    -- Author:      Timothy J. Lord
    --
    -- Purpose:
    --
    -- History:
    -------------------------------------------------------------------------------
    --              Date           Ticket     Comment
    --          07/20/2023  TJL  BIZ-11991    Added return code 7 for license that have not
    --                                        been renewed for current fiscal year.
    --   2.1    07/25/2023  TJL  BIZ-12102    Added procedure get_awfreninfo
    --   2.2    07/27/2023  TJL  BIZ-12070    Added error handling and handling two
    --                                          renewal fees in same fiscal year in get_awfreninfo
    --   2.3    08/02/2023  TJL  BIZ-12220    Corrected bug in awfrequired function in returning
    --                                          Y for license type 22 after payment
    --   3.0    08/07/2023  TJL  BIZ-11961    Added checking for CVR payment
    --   3.0    08/09/2023  TJL  BIZ-12302    Added handling exception when an application as two ANN fees
    --   3.0    08/10/2023  TJL  BIZ-12319    Added handling when more than one application is found on a License
    --   3.0    08/14/2023  TJL  BIZ-12340    Change how the process gets license transfers from ABIS
    --                           BIZ-12331
    --   3.0    08/15/2023  TJL  BIZ-12351    Change how the process gets license transfers for an applications
    --   3.0    08/16/2023  TJL  BIZ-12424    Changed how how 02/22 applications for a license are selected
    --   4.0    10/18/2023  TJL  BIZ-12887    Added new function to allow ABIS to send information to LSP
    --                                          HTTPS endpoints. Function CALLLSP
    --   4.1    10/31/2023  TJL  BIZ-12802    Added new function to allow ABIS to send files to LSP. Function
    --                                          CALLLSP (different parameters)
    --   4.1    12/07/2023  TJL  BIZ-12802    Removed old CALLLSP function
    --   4.2    12/14/2023  TJL  BIZ-13929    Added logging to ESERVICES_LOT_T to calllsp function
    --   5.0    02/06/2024  TJL  BIZ-14444    Change how Wallet path is created.
    --   6.0    03/26/2024  TJL  BIZ-14833    Added new functions (get_application and checkpayment)
    --   6.1    03/28/2024  TJL  BIZ-14833    Remove functions (awfrequired and get_awfreninfo)
    --   6.2    05/20/2024  APD  BIZ-15210    Fix bug to send UTF content and Content-Length for multi-byte chars
    -- ****************************************************************************

    FUNCTION calllsp(a_url          IN VARCHAR2,
                     a_method       IN VARCHAR2,
                     a_content      IN CLOB,
                     a_file         IN BLOB)
        RETURN CLOB
    IS
        t_seq          NUMBER;
        t_boundary     VARCHAR2(100)
                           := '----WebKitFormBoundary7MA4YWxkTrZu0gW';
        t_request      UTL_HTTP.req;
        t_response     UTL_HTTP.resp;
        t_response_text CLOB;
        t_blob_len     NUMBER;
        t_chunk_size   NUMBER := 32767;
        t_offset       NUMBER := 1;
        t_chunk        RAW(32767);
        t_content_type VARCHAR2(100)
                           := 'multipart/form-data; boundary=' || t_boundary;
        t_body_start   VARCHAR2(1000)
            := '--'
               || t_boundary
               || UTL_TCP.crlf
               || 'Content-Disposition: form-data; name="file"; filename="report.pdf"'
               || UTL_TCP.crlf
               || 'Content-Type: application/pdf'
               || UTL_TCP.crlf
               || UTL_TCP.crlf;
        t_body_end     VARCHAR2(100)
            := UTL_TCP.crlf || '--' || t_boundary || '--' || UTL_TCP.crlf;
        t_response_header_name VARCHAR2(256);
        t_response_header_value VARCHAR2(1024);
        t_response_body VARCHAR2(32767);
        t_text         VARCHAR2(32767);
        t_wallet       VARCHAR2(1000);
        t_length       NUMBER;
    BEGIN
        INSERT INTO eservices_log_t(request,
                                    packet,
                                    info,
                                    filedata,
                                    requestdate)
             VALUES ('CALLLSP',
                     a_content,
                     'URL: ' || a_url || CHR(13) || 'Method: ' || a_method,
                     a_file,
                     SYSTIMESTAMP)
          RETURNING seq
               INTO t_seq;

        t_wallet :=
            CASE LOWER(ora_database_name)
                WHEN 'abisp1'
                THEN
                    'file:/u01/app/oracle/admin/abisp1/walletSSL'
                ELSE
                    'file:/orabin1/admin/'
                    || LOWER(ora_database_name)
                    || '/walletSSL/'
            END;

        UTL_HTTP.set_wallet(t_wallet, NULL);

        -- Open the HTTP request
        t_request := UTL_HTTP.begin_request(url => a_url, method => a_method);

        UTL_HTTP.set_header(t_request, 'X-Internal-Request', 'True');
        UTL_HTTP.set_body_charset(t_request,'UTF-8') ;

        IF (a_file IS NULL)
        THEN
            IF (a_content IS NOT NULL)
            THEN
                t_length :=
                utl_raw.length(utl_raw.convert(utl_raw.cast_to_raw(a_content),'american_america.al32utf8','AMERICAN_america.WE8MSWIN1252')) ;
                UTL_HTTP.set_header(t_request,
                                    'content-type',
                                    'application/json');
                UTL_HTTP.set_header(t_request,
                                    'Content-Length',
                                    t_length) ;

                UTL_HTTP.write_text(t_request, a_content);
            END IF;
        ELSE
            -- Set the request headers
            UTL_HTTP.set_header(t_request, 'Content-Type', t_content_type);
            UTL_HTTP.set_header(
                t_request,
                'Content-Length',
                TO_CHAR(
                      DBMS_LOB.getlength(t_body_start)
                    + DBMS_LOB.getlength(a_file)
                    + DBMS_LOB.getlength(t_body_end)));

            -- Write the start of the body to the request
            UTL_HTTP.write_text(t_request, t_body_start);

            -- Read the PDF file into a BLOB (replace this with your actual PDF file reading logic)
            t_blob_len := DBMS_LOB.getlength(a_file);

            -- Write the BLOB content to the request in chunks
            WHILE t_offset <= t_blob_len
            LOOP
                DBMS_LOB.read(a_file,
                              t_chunk_size,
                              t_offset,
                              t_chunk);
                UTL_HTTP.write_raw(t_request, t_chunk);
                t_offset := t_offset + t_chunk_size;
            END LOOP;

            -- Write the end of the body to the request
            UTL_HTTP.write_text(t_request, t_body_end);
        END IF;

        -- Get the response
        t_response := UTL_HTTP.get_response(t_request);

        IF (t_response.status_code NOT IN (200, 201, 204))
        THEN
            DBMS_LOB.createtemporary(t_response_text, TRUE, DBMS_LOB.session);

            BEGIN
                LOOP
                    UTL_HTTP.read_text(t_response, t_text, 32766);
                    DBMS_LOB.writeappend(t_response_text,
                                         LENGTH(t_text),
                                         t_text);
                END LOOP;
            EXCEPTION
                WHEN UTL_HTTP.end_of_body
                THEN
                    UTL_HTTP.end_response(t_response);
            END;
        END IF;

        -- Close the HTTP request/response
        UTL_HTTP.end_response(t_response);
        UTL_HTTP.end_request(t_request);

        UPDATE eservices_log_t
           SET response = json_object('LSPRESPONSE' VALUE t_response_text),
               responsedate = SYSTIMESTAMP
         WHERE seq = t_seq
           LOG ERRORS INTO bizmod_api.err$_eservices_log_t
                   ('UPDATE')
                   REJECT LIMIT UNLIMITED;

        RETURN t_response_text;
    END;



    FUNCTION statusmatrix(a_status IN VARCHAR2)
        RETURN VARCHAR2
    IS
    -- ****************************************************************************
    -- Purpose :    This function is called to convert a status description to
    --              a status code.  If status description is not found then the
    --              status discription is retuned as the status code.
    --
    -- ****************************************************************************
    BEGIN
        RETURN CASE UPPER(a_status)
                   WHEN 'ACTIVE' THEN 'ACTIVE'
                   WHEN 'AUTO REVOKED' THEN 'AUTREV'
                   WHEN 'CANCELED' THEN 'CANCEL'
                   WHEN 'DENIED' THEN 'DENIED'
                   WHEN 'DEPARTMENT REVOKED' THEN 'DEPREV'
                   WHEN 'NON-RENEWED' THEN 'NREN'
                   WHEN 'PENDING' THEN 'PEND'
                   WHEN 'REV PENDING' THEN 'REVPEN'
                   WHEN 'RULE 64B' THEN 'R64B'
                   WHEN 'SLMS REVOKED' THEN 'SLMSRV'
                   WHEN 'SURRENDERED' THEN 'SUREND'
                   WHEN 'SUSPENDED' THEN 'SUSPEN'
                   WHEN 'VOIDED' THEN 'VOIDED'
                   WHEN 'WITHDRAWN' THEN 'WTHDRN'
                   WHEN 'SLMS' THEN 'SLMSHD'
                   ELSE UPPER(a_status)
               END;
    END;

    -- ****************************************************************************
    -- This procedure is called to remove any json elements that are null
    -- ****************************************************************************
    PROCEDURE clean(a_json IN OUT json_object_t)
    IS
        t_json         json_object_t;
        t_array        json_array_t;
        t_element      json_element_t;
        keys           json_key_list;
    BEGIN
        IF (a_json IS NOT NULL)
        THEN
            keys := a_json.get_keys;

            IF (keys.COUNT > 0)
            THEN
                FOR i IN 1 .. keys.COUNT
                LOOP
                    IF (a_json.get_type(keys(i)) = 'ARRAY')
                    THEN
                        t_array := a_json.get_array(keys(i));

                        IF (t_array.get_size = 0)
                        THEN
                            a_json.remove(keys(i));
                        ELSE
                            FOR pos IN 0 .. t_array.get_size - 1
                            LOOP
                                t_element := t_array.get(pos);

                                IF (t_element.is_object)
                                THEN
                                    t_json :=
                                        TREAT(t_element AS json_object_t);
                                END IF;

                                clean(a_json => t_json);
                            END LOOP;
                        END IF;
                    ELSE
                        t_json := a_json.get_object(keys(i));

                        IF (t_json IS NOT NULL)
                        THEN
                            clean(a_json => t_json);
                        ELSE
                            IF (a_json.get_string(keys(i)) IS NULL)
                            THEN
                                a_json.remove(keys(i));
                            END IF;
                        END IF;
                    END IF;
                END LOOP;
            END IF;
        END IF;
    END;

    FUNCTION get_application(a_jobid        IN NUMBER,
                             a_licensetypecode IN VARCHAR2)
        RETURN NUMBER
    AS
        t_applicationjobid NUMBER;

        t_cnt          NUMBER := 0;
    BEGIN
        SELECT DISTINCT applicationobjectid
          INTO t_applicationjobid
          FROM (  SELECT lic.fromobjectid
                             licensetypejobid,
                         app.toobjectid
                             applicationobjectid,
                         api.pkg_columnquery.VALUE(plt.toobjectid,
                                                   'LicenseTypeCode')
                             licensetypecode,
                         api.pkg_columnquery.VALUE(app.toobjectid,
                                                   'CreatedDate')
                             createddate,
                         RANK()
                             OVER(
                                 PARTITION BY lic.fromobjectid
                                 ORDER BY
                                     api.pkg_columnquery.VALUE(app.toobjectid,
                                                               'CreatedDate') DESC)
                             rnk
                    -- point to license (lic.toobjectid) from license type object id
                    FROM api.relationships lic
                         -- point to application (app.toobjectid) from license object id
                         JOIN api.relationships app
                             ON (app.endpointid =
                                 api.pkg_configquery.endpointidforname(
                                     'j_License',
                                     'ApplicationLicense')
                             AND app.fromobjectid = lic.toobjectid)
                         -- point to primary license type (plt.toobjectid) from application object id
                         JOIN api.relationships plt
                             ON (plt.fromobjectid = app.toobjectid
                             AND plt.endpointid =
                                 api.pkg_configquery.endpointidforname(
                                     'j_application',
                                     'PrimaryLicenseType'))
                   WHERE lic.endpointid =
                         api.pkg_configquery.endpointidforname('j_LicenseType',
                                                               'License')
                     AND lic.fromobjectid = a_jobid -- 1646815
                     AND REGEXP_LIKE(
                             api.pkg_columnquery.VALUE(plt.toobjectid,
                                                       'LicenseTypeCode'),
                             a_licensetypecode)
                ORDER BY createddate) app
         WHERE app.rnk = 1
           AND createddate IS NOT NULL;

        RETURN t_applicationjobid;
    END;


    FUNCTION checkpayment(a_licensenumber IN VARCHAR2,
                          a_licensetypecode IN VARCHAR2,
                          a_renewalfeedate IN DATE)
        RETURN VARCHAR2
    AS
        t_awfflag      VARCHAR2(10);
    BEGIN
        SELECT CASE COUNT(1) WHEN 0 THEN 'Y' ELSE 'N' END     awfflag
          INTO t_awfflag
          FROM (SELECT p.*,
                       RANK()
                           OVER(PARTITION BY p.jobid
                                ORDER BY p.datepaid DESC)    rnk
                  FROM bizmod_api.e_payments_t p
                 WHERE p.description = 'AWF'
                   AND p.licensenumber = a_licensenumber
                   AND p.licensetypecode = a_licensetypecode
                   AND p.datepaid > a_renewalfeedate) lic
         WHERE lic.rnk = 1;

        RETURN t_awfflag;
    END;

END;
/


GRANT EXECUTE ON BIZMOD_API.UTL_LICENSEINFO TO ABC;

GRANT EXECUTE ON BIZMOD_API.UTL_LICENSEINFO TO BIZMOD_USER;

GRANT EXECUTE ON BIZMOD_API.UTL_LICENSEINFO TO LORDT;

GRANT EXECUTE ON BIZMOD_API.UTL_LICENSEINFO TO SITESPECIFIC;
