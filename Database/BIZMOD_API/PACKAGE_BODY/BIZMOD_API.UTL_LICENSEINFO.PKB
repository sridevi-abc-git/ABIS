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
    --   6.3    05/24/2024  TJL  BIZ-15485    Add email function to use new configuration table and
    --                                          changed calllsp parameters and parameter types
    -- ****************************************************************************
    gc_newline CONSTANT CHAR(2) := CHR(13) || CHR(10);

    boundary CONSTANT VARCHAR2(256) := '-----7D81B75CCC90D2974F7A1CBD';
    first_boundary CONSTANT VARCHAR2(256) := '--' || boundary || gc_newline;
    last_boundary CONSTANT VARCHAR2(256)
                       := '--' || boundary || '--' || gc_newline ;

    multipart_mime_type CONSTANT VARCHAR2(256)
                       := 'multipart/mixed; boundary="' || boundary || '"' ;

    TYPE t_recp IS TABLE OF VARCHAR(512);

    FUNCTION calllsp(a_process      IN     VARCHAR,
                     a_parameternames IN OUT json_object_t,
                     a_replacementvalues IN json_object_t,
                     a_content      IN     CLOB DEFAULT NULL,
                     a_file         IN     BLOB DEFAULT NULL)
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
        t_infotext     VARCHAR2(32767);
        t_length       NUMBER;
        t_sqlerrm      VARCHAR2(4000);
        t_trace        VARCHAR2(4000);
        t_keys         json_key_list;
        t_column       VARCHAR2(100);
        t_value        VARCHAR2(4000);
        t_info         json_object_t := json_object_t();
        t_header       json_object_t := json_object_t();
        
    BEGIN
        BEGIN
            -- add wallet to get wallet location from configuration table
            a_parameternames.put('WALLET', 'WALLET');
            t_keys := a_parameternames.get_keys;

            -- get configuration information
            FOR i IN 1 .. t_keys.COUNT
            LOOP
                t_column := a_parameternames.get_string(t_keys(i));
--dbms_output.put_line('Columns: ' || t_column);
                SELECT c.parametervalue
                  INTO t_value
                  FROM bizmod_api.eservices_config_t c
                 WHERE c.dbname = UPPER(ora_database_name)
                   AND c.process = a_process
                   AND c.parametername = t_column;

                t_info.put(t_keys(i), t_value);
            END LOOP;

            -- replace the replacement keys from values provided
            t_keys := a_replacementvalues.get_keys;

            FOR i IN 1 .. t_keys.COUNT
            LOOP
                t_info.put(
                    'URL',
                    REPLACE(t_info.get_string('URL'),
                            t_keys(i),
                            a_replacementvalues.get_string(t_keys(i))));
            END LOOP;

            t_infotext := t_info.to_clob;
--dbms_output.put_line(t_infotext);

            INSERT INTO eservices_log_t(request,
                                        packet,
                                        info,
                                        filedata,
                                        requestdate)
                 VALUES (
                     'CALLLSP',
                     a_content,
                     t_infotext,
                     a_file,
                     SYSTIMESTAMP)
              RETURNING seq
                   INTO t_seq;

            COMMIT;
            
            UTL_HTTP.set_wallet(t_info.get_string('WALLET'), NULL);

            -- Open the HTTP request
            t_request :=
                UTL_HTTP.begin_request(
                    url         => t_info.get_string('URL'),
                    method      => t_info.get_string('METHOD'));

            UTL_HTTP.set_header(t_request, 'X-Internal-Request', 'True');
            UTL_HTTP.set_body_charset(t_request, 'UTF-8');

            IF (a_file IS NULL)
            THEN
                IF (a_content IS NOT NULL)
                THEN
                    t_length :=
                        UTL_RAW.LENGTH(
                            UTL_RAW.CONVERT(UTL_RAW.cast_to_raw(a_content),
                                            'american_america.al32utf8',
                                            'AMERICAN_america.WE8MSWIN1252'));
                    UTL_HTTP.set_header(t_request,
                                        'content-type',
                                        'application/json');
                    UTL_HTTP.set_header(t_request,
                                        'Content-Length',
                                        t_length);

                    UTL_HTTP.write_text(t_request, a_content);
                END IF;
            ELSE
                -- Set the request headers
                UTL_HTTP.set_header(t_request,
                                    'Content-Type',
                                    t_content_type);
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
            
                DBMS_LOB.createtemporary(t_response_text,
                                         TRUE,
                                         DBMS_LOB.session);
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
                
                    t_info.put('LSPRESPONSE', t_response_text);
            END IF;

            -- Close the HTTP request/response
            UTL_HTTP.end_response(t_response);
            UTL_HTTP.end_request(t_request);
            
        EXCEPTION
            WHEN UTL_HTTP.request_failed
            THEN
                t_sqlerrm :=
                    'HTTP: '
                    || UTL_HTTP.get_detailed_sqlerrm
                    || CHR(13)
                    || SQLERRM;
                t_trace := DBMS_UTILITY.format_error_backtrace;
t_info.put('ORA-ERROR', t_sqlerrm);
t_response_text := t_response_text || chr(13) || t_sqlerrm;                
        END;

        t_infotext := t_info.to_clob;

        UPDATE eservices_log_t e
           SET response = t_infotext,
               responsedate = SYSTIMESTAMP,
               e.err = SUBSTR(t_sqlerrm || CHR(13) || t_trace, 1, 3990)
         WHERE seq = t_seq
           LOG ERRORS INTO bizmod_api.err$_eservices_log_t
                   ('UPDATE')
                   REJECT LIMIT UNLIMITED;

        COMMIT;

        RETURN case when t_response_text is not null then t_info.to_clob else null end;
    END;


--    FUNCTION calllsp(a_url          IN VARCHAR2,
--                     a_method       IN VARCHAR2,
--                     a_content      IN CLOB,
--                     a_file         IN BLOB)
--        RETURN CLOB
--    IS
--        t_seq          NUMBER;
--        t_boundary     VARCHAR2(100)
--                           := '----WebKitFormBoundary7MA4YWxkTrZu0gW';
--        t_request      UTL_HTTP.req;
--        t_response     UTL_HTTP.resp;
--        t_response_text CLOB;
--        t_blob_len     NUMBER;
--        t_chunk_size   NUMBER := 32767;
--        t_offset       NUMBER := 1;
--        t_chunk        RAW(32767);
--        t_content_type VARCHAR2(100)
--                           := 'multipart/form-data; boundary=' || t_boundary;
--        t_body_start   VARCHAR2(1000)
--            := '--'
--               || t_boundary
--               || UTL_TCP.crlf
--               || 'Content-Disposition: form-data; name="file"; filename="report.pdf"'
--               || UTL_TCP.crlf
--               || 'Content-Type: application/pdf'
--               || UTL_TCP.crlf
--               || UTL_TCP.crlf;
--        t_body_end     VARCHAR2(100)
--            := UTL_TCP.crlf || '--' || t_boundary || '--' || UTL_TCP.crlf;
--        t_response_header_name VARCHAR2(256);
--        t_response_header_value VARCHAR2(1024);
--        t_response_body VARCHAR2(32767);
--        t_text         VARCHAR2(32767);
--        t_wallet       VARCHAR2(1000);
--        t_length       NUMBER;
--    BEGIN
--        INSERT INTO eservices_log_t(request,
--                                    packet,
--                                    info,
--                                    filedata,
--                                    requestdate)
--             VALUES ('CALLLSP',
--                     a_content,
--                     'URL: ' || a_url || CHR(13) || 'Method: ' || a_method,
--                     a_file,
--                     SYSTIMESTAMP)
--          RETURNING seq
--               INTO t_seq;
--
--        t_wallet :=
--            CASE LOWER(ora_database_name)
--                WHEN 'abisp1'
--                THEN
--                    'file:/u01/app/oracle/admin/abisp1/walletSSL'
--                ELSE
--                    'file:/orabin1/admin/'
--                    || LOWER(ora_database_name)
--                    || '/walletSSL/'
--            END;
--
--        UTL_HTTP.set_wallet(t_wallet, NULL);
--
--        -- Open the HTTP request
--        t_request := UTL_HTTP.begin_request(url => a_url, method => a_method);
--
--        UTL_HTTP.set_header(t_request, 'X-Internal-Request', 'True');
--        UTL_HTTP.set_body_charset(t_request, 'UTF-8');
--
--        IF (a_file IS NULL)
--        THEN
--            IF (a_content IS NOT NULL)
--            THEN
--                t_length :=
--                    UTL_RAW.LENGTH(
--                        UTL_RAW.CONVERT(UTL_RAW.cast_to_raw(a_content),
--                                        'american_america.al32utf8',
--                                        'AMERICAN_america.WE8MSWIN1252'));
--                UTL_HTTP.set_header(t_request,
--                                    'content-type',
--                                    'application/json');
--                UTL_HTTP.set_header(t_request, 'Content-Length', t_length);
--
--                UTL_HTTP.write_text(t_request, a_content);
--            END IF;
--        ELSE
--            -- Set the request headers
--            UTL_HTTP.set_header(t_request, 'Content-Type', t_content_type);
--            UTL_HTTP.set_header(
--                t_request,
--                'Content-Length',
--                TO_CHAR(
--                      DBMS_LOB.getlength(t_body_start)
--                    + DBMS_LOB.getlength(a_file)
--                    + DBMS_LOB.getlength(t_body_end)));
--
--            -- Write the start of the body to the request
--            UTL_HTTP.write_text(t_request, t_body_start);
--
--            -- Read the PDF file into a BLOB (replace this with your actual PDF file reading logic)
--            t_blob_len := DBMS_LOB.getlength(a_file);
--
--            -- Write the BLOB content to the request in chunks
--            WHILE t_offset <= t_blob_len
--            LOOP
--                DBMS_LOB.read(a_file,
--                              t_chunk_size,
--                              t_offset,
--                              t_chunk);
--                UTL_HTTP.write_raw(t_request, t_chunk);
--                t_offset := t_offset + t_chunk_size;
--            END LOOP;
--
--            -- Write the end of the body to the request
--            UTL_HTTP.write_text(t_request, t_body_end);
--        END IF;
--
--        -- Get the response
--        t_response := UTL_HTTP.get_response(t_request);
--
--        IF (t_response.status_code NOT IN (200, 201, 204))
--        THEN
--            DBMS_LOB.createtemporary(t_response_text, TRUE, DBMS_LOB.session);
--
--            BEGIN
--                LOOP
--                    UTL_HTTP.read_text(t_response, t_text, 32766);
--                    DBMS_LOB.writeappend(t_response_text,
--                                         LENGTH(t_text),
--                                         t_text);
--                END LOOP;
--            EXCEPTION
--                WHEN UTL_HTTP.end_of_body
--                THEN
--                    UTL_HTTP.end_response(t_response);
--            END;
--        END IF;
--
--        -- Close the HTTP request/response
--        UTL_HTTP.end_response(t_response);
--        UTL_HTTP.end_request(t_request);
--
--        UPDATE eservices_log_t
--           SET response = json_object('LSPRESPONSE' VALUE t_response_text),
--               responsedate = SYSTIMESTAMP
--         WHERE seq = t_seq
--           LOG ERRORS INTO bizmod_api.err$_eservices_log_t
--                   ('UPDATE')
--                   REJECT LIMIT UNLIMITED;
--
--        RETURN t_response_text;
--    END;



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

    PROCEDURE sendemail(a_process      IN VARCHAR2 DEFAULT 'EMAIL',
                        a_subject      IN VARCHAR2,
                        a_body         IN VARCHAR2,
                        a_file_name    IN VARCHAR2 DEFAULT NULL,
                        a_clob         IN CLOB DEFAULT NULL,
                        a_encoding        VARCHAR2 DEFAULT 'text/plain',
                        a_mimetype        VARCHAR2 DEFAULT 'text/plain')
    IS
        CURSOR cur_rcpt(p_to IN VARCHAR2)
        IS
                SELECT REGEXP_SUBSTR(p_to,
                                     '[^;]+',
                                     1,
                                     LEVEL)    txt
                  FROM DUAL
            CONNECT BY REGEXP_SUBSTR(p_to,
                                     '[^;]+',
                                     1,
                                     LEVEL)
                           IS NOT NULL;

        t_from         VARCHAR2(512);
        t_to           VARCHAR2(512);
        t_cc           VARCHAR2(512);
        t_bcc          VARCHAR2(512);
        t_conn         UTL_SMTP.connection;
        t_production   VARCHAR2(1);
        t_subject      VARCHAR2(512) := a_subject;
        t_host         VARCHAR2(512); -- := '134.186.202.119';
        t_len          INTEGER;
        t_index        INTEGER;
        t_file_type    VARCHAR2(50);
        t_body         VARCHAR2(32000) := a_body;
        t_rcpt         t_recp;
    BEGIN
        -- Generate email of completion of first data processing
        SELECT pto,
               pfrom,
               pcc,
               pbcc,
               psmtp,
               pprod
          INTO t_to,
               t_from,
               t_cc,
               t_bcc,
               t_host,
               t_production
          FROM (SELECT c.parametername, c.parametervalue
                  FROM bizmod_api.eservices_config_t c
                 WHERE c.process = a_process
                   AND c.dbname = UPPER(ora_database_name))
               PIVOT (MAX(parametervalue)
                     FOR parametername
                     IN ('TO' pto, 'FROM' pfrom, 'CC' pcc, 'BCC' pbcc, 'SMTPSERVER' psmtp, 'PRODUCTION' pprod));

        IF (t_from IS NULL)
        THEN
            RETURN;
        END IF;

        IF (a_file_name IS NOT NULL)
        THEN
            SELECT CASE LOWER(REGEXP_SUBSTR(a_file_name, '\.[^\.]*$'))
                       WHEN 'doc' THEN 'application/msword'
                       WHEN 'xls' THEN 'application/excel'
                       WHEN 'xlsx' THEN 'application/excel'
                       WHEN 'pdf' THEN 'application/pdf'
                       WHEN 'zip' THEN 'application/zip'
                       WHEN 'bmp' THEN 'image/bmp'
                       WHEN 'jpg' THEN 'image/jpg'
                       WHEN 'jpeg' THEN 'image/jpg'
                       WHEN 'gif' THEN 'image/gif'
                       WHEN 'htm' THEN 'text/html'
                       WHEN 'html' THEN 'text/html'
                       WHEN 'txt' THEN 'text/plain'
                       WHEN 'log' THEN 'text/plain'
                       WHEN 'csv' THEN 'text/plain'
                       WHEN 'text' THEN 'text/plain'
                       ELSE 'text/plain'
                   END    CASE
              INTO t_file_type
              FROM DUAL;
        ELSE
            t_file_type := a_mimetype;
        END IF;

        OPEN cur_rcpt(t_to || ';' || t_cc || ';' || t_bcc);

        FETCH cur_rcpt BULK COLLECT INTO t_rcpt LIMIT 30;

        CLOSE cur_rcpt;

        IF (t_production = 'N')
        THEN -- Changed DB name to ABISP1 by pawan on 10/26/2022
            t_subject := '(' || UPPER(ora_database_name) || ') ' || t_subject;
            t_body :=
                '*** ('
                || UPPER(ora_database_name)
                || ') THIS IS A TEST *** '
                || UTL_TCP.crlf
                || UTL_TCP.crlf
                || t_body;
        END IF;

        t_conn := UTL_SMTP.open_connection(t_host, 25);
        UTL_SMTP.helo(t_conn, t_host);

        UTL_SMTP.mail(t_conn, t_from);

        -- loop through the to address list
        FOR inx IN 1 .. t_rcpt.COUNT
        LOOP
            UTL_SMTP.rcpt(t_conn, t_rcpt(inx));
        END LOOP;

        UTL_SMTP.open_data(t_conn);
        UTL_SMTP.write_data(t_conn, 'From: ' || t_from || UTL_TCP.crlf);
        UTL_SMTP.write_data(t_conn, 'To: ' || t_to || UTL_TCP.crlf);
        UTL_SMTP.write_data(t_conn, 'Cc: ' || t_cc || UTL_TCP.crlf);
        UTL_SMTP.write_data(t_conn, 'Subject: ' || t_subject || UTL_TCP.crlf);

        UTL_SMTP.write_data(
            t_conn,
            'Content-Type: ' || multipart_mime_type || UTL_TCP.crlf);

        UTL_SMTP.write_data(t_conn, UTL_TCP.crlf);
        UTL_SMTP.write_data(t_conn, first_boundary);
        UTL_SMTP.write_data(t_conn,
                            'Content-Type: ' || a_mimetype || UTL_TCP.crlf);
        UTL_SMTP.write_data(t_conn, UTL_TCP.crlf);
        UTL_SMTP.write_data(t_conn, t_body || UTL_TCP.crlf);
        UTL_SMTP.write_data(t_conn, UTL_TCP.crlf);

        IF (a_clob IS NOT NULL
        AND a_file_name IS NOT NULL)
        THEN
            UTL_SMTP.write_data(t_conn, first_boundary);
            UTL_SMTP.write_data(
                t_conn,
                'Content-Type: ' || t_file_type || UTL_TCP.crlf);

            -- Set up attachment header
            UTL_SMTP.write_data(
                t_conn,
                'Content-Disposition: attachment; filename="'
                || a_file_name
                || '"'
                || UTL_TCP.crlf);

            UTL_SMTP.write_data(
                t_conn,
                'Content-Transfer-Encoding: ' || a_encoding || UTL_TCP.crlf);
            UTL_SMTP.write_data(t_conn, UTL_TCP.crlf);

            -- Write attachment contents
            t_len := DBMS_LOB.getlength(a_clob);
            t_index := 1;

            WHILE t_index <= t_len
            LOOP
                UTL_SMTP.write_data(t_conn,
                                    DBMS_LOB.SUBSTR(a_clob, 32000, t_index));
                t_index := t_index + 32000;
            END LOOP;

            -- End attachment
            UTL_SMTP.write_data(t_conn, UTL_TCP.crlf);
        END IF;

        UTL_SMTP.write_data(t_conn, last_boundary);

        UTL_SMTP.close_data(t_conn);
        UTL_SMTP.quit(t_conn);
    END sendemail;
END;
/


GRANT EXECUTE ON BIZMOD_API.UTL_LICENSEINFO TO ABC;

GRANT EXECUTE ON BIZMOD_API.UTL_LICENSEINFO TO BIZMOD_USER;

GRANT EXECUTE ON BIZMOD_API.UTL_LICENSEINFO TO LORDT;

GRANT EXECUTE ON BIZMOD_API.UTL_LICENSEINFO TO SITESPECIFIC;
