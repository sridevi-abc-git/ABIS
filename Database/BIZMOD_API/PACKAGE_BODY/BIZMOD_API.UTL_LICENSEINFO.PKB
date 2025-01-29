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
    --   7.0    07/01/2024  TJL  BIZ-15444    Added procedure CREATEJOB
    --   8.0.1  07/08/2024  TJL  BIZ-15808    Updated callsp with more exception handling
    --   9.0    08/07/2024  TJL  BIZ-15800    Added new CALLLSP Function
    --   9.1    08/19/2024  TJL  BIZ-16036    Change how get_application finds the requested application
    --   9.1.1  08/26/2024  TJL  BIZ-16121    Trunc date test in checkpayment function
    --  10.0.0  10/08/2024  TJL  BIZ-16424    Added get_address, get_legalentity, get_company, get_person,
    --                                          and get_titles functons
    --  10.1.0  10/23/2024  TJL               Added extra logging.
    --  10.2.0  11/07/2024  TJL  BIZ-16535    Added logging for status codes 200's
    --  10.3.0  12/10/2024  TJL  BIZ-16906    Remove COMMIT from createjob process. ABIS throws error because
    --                                          the current ABIS transaction cannot be ended at this time.
    --  10.4.0  01/21/2025  TJL               Added the ability to turn off sending emails thru the configuration table.
    --  10.4.3  01/28/2025  TJL  BIZ-17289    Added recursive call to CALLLSP to get JWT token
    -- ****************************************************************************
    gc_newline CONSTANT CHAR(2) := CHR(13) || CHR(10);

    boundary CONSTANT VARCHAR2(256) := '-----7D81B75CCC90D2974F7A1CBD';
    first_boundary CONSTANT VARCHAR2(256) := '--' || boundary || gc_newline;
    last_boundary CONSTANT VARCHAR2(256)
                       := '--' || boundary || '--' || gc_newline ;

    multipart_mime_type CONSTANT VARCHAR2(256)
                       := 'multipart/mixed; boundary="' || boundary || '"' ;

    TYPE t_recp IS TABLE OF VARCHAR(512);

    TYPE legalentity_type IS TABLE OF NUMBER;

    t_legalentity  legalentity_type := legalentity_type();


    FUNCTION calllsp(a_urlinfo      IN VARCHAR2,
                     a_method       IN VARCHAR2,
                     a_content      IN CLOB DEFAULT NULL,
                     a_file         IN BLOB DEFAULT NULL,
                     a_process      IN VARCHAR2 DEFAULT 'CALLLSP')
        RETURN CLOB
    IS
        --  10.4.3  01/28/2025  TJL  BIZ-17289
        t_token        json_object_t := json_object_t();
        t_loginid      VARCHAR2(32767);
        t_ret          CLOB;
        ----------------------------------------------

        t_url          VARCHAR2(10000);
        t_wallet       VARCHAR2(10000);
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
        t_text         VARCHAR2(32767);
        t_infotext     VARCHAR2(32767);
        t_length       NUMBER;
        t_statuscode   NUMBER;
        t_sqlerrm      VARCHAR2(4000);
        t_trace        VARCHAR2(4000);
        t_info         json_object_t := json_object_t();
    BEGIN
        BEGIN
            BEGIN
                SELECT url || a_urlinfo, wallet, loginid
                  INTO t_url, t_wallet, t_loginid
                  FROM (SELECT c.process, c.parametername, c.parametervalue
                          FROM bizmod_api.eservices_config_t c
                         WHERE c.process = 'CALLLSP'
                           AND c.dbname = UPPER(ora_database_name))
                           PIVOT (
                                 MAX(parametervalue)
                                 FOR parametername
                                 IN ('URL' url,
                                    'WALLET' wallet,
                                    'LOGINID' loginid)); --  10.4.3  01/28/2025  TJL  BIZ-17289

                --  10.4.3  01/28/2025  TJL  BIZ-17289
                ------------------------------------------------------
                IF (a_process = 'CALLLSP')
                THEN
                    -- call get token
                    t_ret :=
                        calllsp(
                            a_urlinfo   =>
                                '/api/providermgmt/authenticate/login',
                            a_method    => 'POST',
                            a_content   => t_loginid,
                            a_process   => 'GETTOKEN');

                    IF (t_ret IS NOT NULL)
                    THEN
                        t_token := json_object_t.parse(t_ret);
                    END IF;

                    IF (NOT t_token.has('token'))
                    THEN
                        raise_application_error(
                            -20001,
                            'No LSP Token Returned' || CHR(13) || t_ret,
                            TRUE);
                    END IF;
                END IF;
            ----------------------------------------------------------
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    raise_application_error(-20001,
                                            'Parameter Not Found',
                                            TRUE);
            END;

            t_info.put('URL', t_url);
            t_info.put('METHOD', a_method);
            --            t_info.put('WALLET', t_wallet);
            t_infotext := t_info.TO_CLOB;

            INSERT INTO eservices_log_t(request,
                                        packet,
                                        info,
                                        filedata,
                                        requestdate)
                 VALUES (
                            a_process,
                            -- do not log userid and password contain in content for gettoken call
                            CASE a_process
                                WHEN 'CALLLSP' THEN a_content --  10.4.3  01/28/2025  TJL  BIZ-17289
                                ELSE NULL
                            END,
                            t_infotext,
                            a_file,
                            SYSTIMESTAMP)
              RETURNING seq
                   INTO t_seq;

            COMMIT;

            UTL_HTTP.set_wallet(t_wallet, NULL);

            -- Open the HTTP request
            t_request :=
                UTL_HTTP.begin_request(url => t_url, method => a_method);

            --  10.4.3  01/28/2025  TJL  BIZ-17289
            ------------------------------------------------------
            IF (a_process = 'CALLLSP')
            THEN
                UTL_HTTP.set_header(t_request,
                                    'Authorization',
                                    'Bearer ' || t_token.get_string('token')); --  10.4.2  01/28/2025  TJL  BIZ-17289
            END IF;

            ------------------------------------------------------

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
            t_statuscode := t_response.status_code;

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

            --  10.4.3  01/28/2025  TJL  BIZ-17289
            --------------------------------------------------------
            IF (t_statuscode = 200
            AND a_process = 'GETTOKEN'
            AND t_response_text IS JSON)
            THEN
                t_token := json_object_t.parse(t_response_text);
            END IF;
            --------------------------------------------------------

            t_info.put('HTTPRESPONSE', t_response.status_code);

            IF (t_response_text IS JSON) --  10.4.3  01/28/2025  TJL  BIZ-17289
            THEN
                t_info.put('LSPRESPONSE',
                           json_element_t.parse(t_response_text));
            ELSE
                t_info.put('LSPRESPONSE', t_response_text);
            END IF;

            -- Close the HTTP request/response
            UTL_HTTP.end_response(t_response);
            UTL_HTTP.end_request(t_request);
        EXCEPTION
            WHEN OTHERS     --  10.4.3  01/28/2025  TJL  BIZ-17289
            THEN
                t_sqlerrm :=
                    'HTTPS: '
                    || UTL_HTTP.get_detailed_sqlerrm
                    || CHR(13)
                    || SQLERRM;
                t_trace := DBMS_UTILITY.format_error_backtrace;
                t_info.put('ORA-ERROR', t_sqlerrm);
                t_response_text := t_response_text || CHR(13) || t_sqlerrm;
        END;

        t_infotext := t_info.TO_CLOB;

        IF (t_sqlerrm IS NULL)
        THEN
            UPDATE eservices_log_t e
               SET response = t_infotext, responsedate = SYSTIMESTAMP
             WHERE seq = t_seq
               LOG ERRORS INTO bizmod_api.err$_eservices_log_t ('UPDATE')
                       REJECT LIMIT UNLIMITED;
        ELSE
            UPDATE eservices_log_t e
               SET response = t_infotext,
                   responsedate = SYSTIMESTAMP,
                   e.err = SUBSTR(t_sqlerrm || CHR(13) || t_trace, 1, 3990)
             WHERE seq = t_seq
               LOG ERRORS INTO bizmod_api.err$_eservices_log_t ('UPDATE')
                       REJECT LIMIT UNLIMITED;
        END IF;

        COMMIT;

        RETURN CASE
                   WHEN t_statuscode IN (200, 201, 204)
                   THEN
                       CASE a_process  --  10.4.3  01/28/2025  TJL  BIZ-17289
                           WHEN 'GETTOKEN' THEN t_token.TO_CLOB
                           ELSE NULL
                       END
                   ELSE
                       t_info.TO_CLOB
               END;
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
          FROM (  SELECT app.toobjectid
                             applicationobjectid,
                         api.pkg_columnquery.datevalue(lic.fromobjectid,
                                                       'issuedate')
                             issuedate,
                         TRUNC(
                             api.pkg_columnquery.datevalue(p.processid,
                                                           'datecompleted'))
                             datecompleted
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
                         JOIN api.processes p
                             ON (p.processtypeid =
                                 api.pkg_configquery.objectdefidforname(
                                     'p_IssueLicense')
                             AND p.jobid = app.toobjectid)
                   WHERE lic.endpointid =
                         api.pkg_configquery.endpointidforname('j_LicenseType',
                                                               'License')
                     AND lic.fromobjectid = a_jobid -- 1646815
                     AND REGEXP_LIKE(
                             api.pkg_columnquery.VALUE(plt.toobjectid,
                                                       'LicenseTypeCode'),
                             a_licensetypecode)
                ORDER BY createddate) app
         WHERE app.issuedate = app.datecompleted;

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
                   AND TRUNC(p.datepaid) >= TRUNC(a_renewalfeedate)) lic -- 08/26/2024 TJL BIZ-16121
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
        t_disable      VARCHAR2(1); -- 01/21/2025 TJL
        t_subject      VARCHAR2(512) := a_subject;
        t_host         VARCHAR2(512);
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
               pprod,
               pdisable --  10.4.0  01/21/2025  TJL
          INTO t_to,
               t_from,
               t_cc,
               t_bcc,
               t_host,
               t_production,
               t_disable --  10.4.0  01/21/2025  TJL
          FROM (SELECT c.parametername, c.parametervalue
                  FROM bizmod_api.eservices_config_t c
                 WHERE c.process = a_process
                   AND c.dbname = UPPER(ora_database_name))
                   PIVOT (
                         MAX(parametervalue)
                         FOR parametername
                         IN ('TO' pto,
                            'FROM' pfrom,
                            'CC' pcc,
                            'BCC' pbcc,
                            'SMTPSERVER' psmtp,
                            'PRODUCTION' pprod,
                            'DISABLE' pdisable));

        IF (t_from IS NULL
         OR UPPER(NVL(t_disable, 'N')) = 'Y') --  10.4.0  01/21/2025  TJL
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


    PROCEDURE createjob(a_procedure    IN VARCHAR2,
                        a_description  IN VARCHAR2,
                        a_argument1    IN VARCHAR2 DEFAULT '0',
                        a_argument2    IN DATE DEFAULT SYSDATE,
                        a_argument3    IN VARCHAR2 DEFAULT NULL,
                        a_argument4    IN VARCHAR2 DEFAULT NULL)
    IS
        t_arguments    VARCHAR2(4000);
        t_schedulekey  api.pkg_definition.udt_id;
    BEGIN
        --set up arguments for scheduler
        scheduler.pkg_scheduler.addargument(t_arguments,
                                            'procedure',
                                            'BIZMOD_API.' || a_procedure);
        scheduler.pkg_scheduler.addargument(t_arguments,
                                            'EffectiveUser',
                                            'ABC');

        scheduler.pkg_scheduler.addargument(t_arguments,
                                            'arg1',
                                            NVL(a_argument1, '0'));
        scheduler.pkg_scheduler.addargument(t_arguments, 'arg2', a_argument2);

        IF (a_argument3 IS NOT NULL)
        THEN
            scheduler.pkg_scheduler.addargument(t_arguments,
                                                'arg3',
                                                a_argument3);
        END IF;

        IF (a_argument4 IS NOT NULL)
        THEN
            scheduler.pkg_scheduler.addargument(t_arguments,
                                                'arg4',
                                                a_argument4);
        END IF;

        --schedule item to be handled by the process server
        t_schedulekey :=
            scheduler.pkg_scheduler.scheduleitem(
                a_argument2,
                2,
                'nc_0011_ExecuteProcedureAsPosseUser',
                t_arguments,
                'E-Services ' || a_description,
                1); --serverkey
    END;


    FUNCTION get_address(a_objectid IN NUMBER, a_endpoint IN NUMBER)
        RETURN json_object_t
    AS
        t_json         json_object_t := json_object_t();
        t_objectid     NUMBER;
    BEGIN
        SELECT r.toobjectid
          INTO t_objectid
          FROM api.relationships r
         WHERE r.endpointid = a_endpoint
           AND r.fromobjectid = a_objectid;

        t_json.put('ADDRESSLOCATION',
                   api.pkg_columnquery.VALUE(t_objectid, 'ADDRESSLOCATION'));
        t_json.put('ADDRESSLINE1',
                   api.pkg_columnquery.VALUE(t_objectid, 'ADDRESSLINE1'));
        t_json.put('ADDRESSLINE2',
                   api.pkg_columnquery.VALUE(t_objectid, 'ADDRESSLINE2'));
        t_json.put('ADDRESSLINE3',
                   api.pkg_columnquery.VALUE(t_objectid, 'ADDRESSLINE3'));
        t_json.put('USACITY',
                   api.pkg_columnquery.VALUE(t_objectid, 'USACITY'));
        t_json.put('USASTATE',
                   api.pkg_columnquery.VALUE(t_objectid, 'USASTATE'));
        t_json.put('ZIPCODE',
                   api.pkg_columnquery.VALUE(t_objectid, 'ZIPCODE'));
        t_json.put('COUNTRY',
                   api.pkg_columnquery.VALUE(t_objectid, 'COUNTRY'));
        t_json.put(
            'PHONENUMBER',
            REGEXP_REPLACE(
                api.pkg_columnquery.VALUE(t_objectid, 'PHONENUMBER'),
                '(\d{3})(\d{3})(\d{4})',
                '(\1)\2-\3'));
        t_json.put(
            'FAXNUMBER',
            REGEXP_REPLACE(
                api.pkg_columnquery.VALUE(t_objectid, 'FAXNUMBER'),
                '(\d{3})(\d{3})(\d{4})',
                '(\1)\2-\3'));
        t_json.put(
            'INTERNATIONALPHONENUMBER',
            REGEXP_REPLACE(
                api.pkg_columnquery.VALUE(t_objectid,
                                          'INTERNATIONALPHONENUMBER'),
                '(\d{3})(\d{3})(\d{4})',
                '(+1-\1-\2-\3)'));

        IF (a_endpoint =
            api.pkg_configquery.endpointidforname('j_Application',
                                                  'Premises'))
        THEN
            t_json.put('CENSUSTRACT',
                       api.pkg_columnquery.VALUE(t_objectid, 'CENSUSTRACT'));
            t_json.put(
                'CENSUSTRACTSOURCE',
                api.pkg_columnquery.VALUE(t_objectid, 'CENSUSTRACTSOURCE'));
            t_json.put(
                'GEOCODEADDRESSLINE1',
                api.pkg_columnquery.VALUE(t_objectid, 'GEOCODEADDRESSLINE1'));
            t_json.put(
                'OUTSIDECITYLIMITS',
                api.pkg_columnquery.VALUE(t_objectid, 'OUTSIDECITYLIMITS'));
            t_json.put('HIGHCRIME',
                       api.pkg_columnquery.VALUE(t_objectid, 'HIGHCRIME'));
            t_json.put(
                'CARDROOMCASINO',
                api.pkg_columnquery.VALUE(t_objectid, 'CARDROOMCASINO'));
            t_json.put('NOEVENT',
                       api.pkg_columnquery.VALUE(t_objectid, 'NOEVENT'));
            t_json.put(
                'ELIGIBLEFORTRANSFER',
                api.pkg_columnquery.VALUE(t_objectid, 'ELIGIBLEFORTRANSFER'));
        END IF;

        RETURN t_json;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            RETURN NULL;
    END;


    FUNCTION get_person(a_legalentityobjectid IN NUMBER)
        RETURN json_object_t
    AS
        t_objectid     NUMBER;
        t_entity       json_object_t := json_object_t();
    BEGIN
        -- get person relationship
        SELECT r.toobjectid
          INTO t_objectid
          FROM api.relationships r
         WHERE r.endpointid =
               api.pkg_configquery.endpointidforname('o_LegalEntity',
                                                     'Person')
           AND r.fromobjectid = a_legalentityobjectid;

        --        t_entity.put('OWNERTYPE',
        --                     api.pkg_columnquery.VALUE(t_objectid, 'OwnerType'));
        --               api.pkg_columnquery.VALUE(t_value, 'LEStructureRel'));
        t_entity.put('FIRSTNAME',
                     api.pkg_columnquery.VALUE(t_objectid, 'FirstName'));
        t_entity.put('MIDDLENAME',
                     api.pkg_columnquery.VALUE(t_objectid, 'MiddleName'));
        t_entity.put('LASTNAME',
                     api.pkg_columnquery.VALUE(t_objectid, 'LastName'));
        t_entity.put('SUFFIX',
                     api.pkg_columnquery.VALUE(t_objectid, 'Suffix'));
        t_entity.put('ALIASNAMES',
                     api.pkg_columnquery.VALUE(t_objectid, 'AliasNames'));
        t_entity.put(
            'SOCIALSECURITYNUMBER',
            api.pkg_columnquery.VALUE(t_objectid, 'SocialSecurityNumber'));
        t_entity.put(
            'DRIVERSLICENSENUMBER',
            api.pkg_columnquery.VALUE(t_objectid, 'DriversLicenseNumber'));
        t_entity.put(
            'DRIVERSLICENSESTATE',
            api.pkg_columnquery.VALUE(t_objectid, 'DriversLicenseState'));
        t_entity.put('PASSPORTNUMBER',
                     api.pkg_columnquery.VALUE(t_objectid, 'PassportNumber'));
        t_entity.put('GENDER',
                     api.pkg_columnquery.VALUE(t_objectid, 'Gender'));
        t_entity.put('BIRTHDATE',
                     api.pkg_columnquery.VALUE(t_objectid, 'BirthDate'));
        t_entity.put('BIRTHCITY',
                     api.pkg_columnquery.VALUE(t_objectid, 'BirthCity'));
        t_entity.put('BIRTHSTATE',
                     api.pkg_columnquery.VALUE(t_objectid, 'BirthState'));
        t_entity.put('BIRTHCOUNTRY',
                     api.pkg_columnquery.VALUE(t_objectid, 'BirthCountry'));
        t_entity.put('MARITALSTATUS',
                     api.pkg_columnquery.VALUE(t_objectid, 'MaritalStatus'));

        t_entity.put(
            'FEDERALEMPLOYERIDENTIFICATIONN',
            api.pkg_columnquery.VALUE(t_objectid,
                                      'FederalEmployerIdentificationn'));

        t_entity.put(
            'PERCENTAGEOFOWNERSHIP',
            api.pkg_columnquery.VALUE(t_objectid, 'PercentageOfOwnership'));
        t_entity.put(
            'ADDRESS',
            get_address(
                a_objectid  => t_objectid,
                a_endpoint  =>
                    api.pkg_configquery.endpointidforname(
                        api.pkg_columnquery.VALUE(t_objectid,
                                                  'ObjectDefName'),
                        'Address')));

        RETURN t_entity;
    END;

    FUNCTION get_company(a_legalentityobjectid IN NUMBER)
        RETURN json_object_t
    AS
        t_objectid     NUMBER;
        t_entity       json_object_t := json_object_t();
    BEGIN
        -- get company relationship
        SELECT r.toobjectid
          INTO t_objectid
          FROM api.relationships r
         WHERE r.endpointid =
               api.pkg_configquery.endpointidforname('o_LegalEntity',
                                                     'Company')
           AND r.fromobjectid = a_legalentityobjectid;

        t_entity.put('COMPANYNAME',
                     api.pkg_columnquery.VALUE(t_objectid, 'CompanyName'));
        t_entity.put(
            'COMPANYSTRUCTURE',
            api.pkg_columnquery.VALUE(t_objectid, 'CompanyStructure'));
        t_entity.put(
            'DATEOFINCORPORATION',
            api.pkg_columnquery.VALUE(t_objectid, 'DateOfIncorporation'));
        t_entity.put(
            'STATEOFINCORPORATION',
            api.pkg_columnquery.VALUE(t_objectid, 'StateOfIncorporation'));
        t_entity.put(
            'CASECRETARYOFSTATENUMBER',
            api.pkg_columnquery.VALUE(t_objectid, 'CASecretaryOfStateNumber'));
        t_entity.put(
            'FEDERALEMPLOYERIDENTIFICATIONN',
            api.pkg_columnquery.VALUE(t_objectid,
                                      'FederalEmployerIdentificationn'));

        t_entity.put(
            'ADDRESS',
            get_address(
                a_objectid  => t_objectid,
                a_endpoint  =>
                    api.pkg_configquery.endpointidforname(
                        api.pkg_columnquery.VALUE(t_objectid,
                                                  'ObjectDefName'),
                        'Address')));

        RETURN t_entity;
    END;

    FUNCTION get_titles(a_legalentityobjectid IN NUMBER)
        RETURN json_array_t
    AS
        t_array        json_array_t := json_array_t();
    BEGIN
        FOR rec
            IN (SELECT r.toobjectid objectid, r.relationshipid
                  FROM api.relationships r
                 WHERE r.endpointid =
                       api.pkg_configquery.endpointidforname(
                           api.pkg_columnquery.VALUE(a_legalentityobjectid,
                                                     'ObjectDefName'),
                           'Title')
                   AND r.fromobjectid = a_legalentityobjectid)
        LOOP
            t_array.append(
                api.pkg_columnquery.VALUE(rec.objectid, 'Description'));
        END LOOP;

        RETURN t_array;
    END;

    PROCEDURE get_legalentity(a_json IN json_object_t, a_list IN VARCHAR2)
    AS
        t_value        NUMBER;
        t_next         VARCHAR2(1000);
        t_pos          NUMBER;

        t_array        json_array_t;
        t_json         json_object_t;
        t_tmp          json_object_t;
        t_entity       json_object_t := json_object_t();

        t_return       json_object_t := json_object_t();
    BEGIN
        t_value :=
            TO_NUMBER(REGEXP_SUBSTR(a_list,
                                    '[^/]+',
                                    1,
                                    1));
        t_array := a_json.get_array('LEGALENTITIES');

        -- get next level down
        t_pos :=
            INSTR(a_list,
                  '/',
                  1,
                  2);

        IF (t_pos > 0)
        THEN
            t_next := SUBSTR(a_list, t_pos);
        END IF;

        IF legalentity_type(t_value) SUBMULTISET t_legalentity
        THEN
            -- find object
            FOR inx IN 0 .. t_array.get_size() - 1
            LOOP
                t_tmp := TREAT(t_array.get(inx) AS json_object_t);

                IF t_tmp IS NOT NULL
                THEN
                    IF (t_tmp.get_number('OBJECTID') = t_value)
                    THEN
                        t_json := t_tmp;
                        t_array := t_json.get_array('LEGALENTITIES');

                        IF t_array IS NULL
                        THEN
                            t_json.put('LEGALENTITIES', json_array_t);
                        END IF;

                        EXIT;
                    END IF;
                END IF;
            END LOOP;
        END IF;

        IF t_json IS NULL
        THEN
            t_legalentity.EXTEND(1);
            t_legalentity(t_legalentity.COUNT) := t_value;

            t_entity.put('OBJECTID', t_value);
            t_entity.put(
                'LESTRUCTUREREL',
                api.pkg_columnquery.VALUE(t_value, 'LeStructureRel'));
            t_entity.put(
                'HIERARCHYLEVEL',
                api.pkg_columnquery.VALUE(t_value, 'HierarchyLevel'));
            t_entity.put(
                'LEGALENTITYTYPE',
                api.pkg_columnquery.VALUE(t_value, 'LegalEntityType'));
            t_entity.put(
                'P12TYPE',
                CASE
                    WHEN api.pkg_columnquery.VALUE(t_value, 'P12Status') =
                         'Y'
                    THEN
                        'P12'
                    WHEN api.pkg_columnquery.VALUE(t_value, 'P12AStatus') =
                         'Y'
                    THEN
                        'P12A'
                    ELSE
                        NULL
                END);

            t_entity.put('OWNERTYPE',
                         api.pkg_columnquery.VALUE(t_value, 'OwnerType'));
            t_entity.put('TITLE',
                         get_titles(a_legalentityobjectid => t_value));
            t_entity.put(
                'PERCENTAGEOFOWNERSHIP',
                api.pkg_columnquery.VALUE(t_value, 'PercentageOfOwnership'));

            CASE api.pkg_columnquery.VALUE(t_value, 'LegalEntityType')
                WHEN 'Person'
                THEN
                    t_entity.put(
                        'PERSON',
                        get_person(a_legalentityobjectid => t_value));
                WHEN 'Company'
                THEN
                    t_entity.put(
                        'COMPANY',
                        get_company(a_legalentityobjectid => t_value));
                ELSE
                    NULL;
            END CASE;

            t_array.append(t_entity);

            t_json := json_object_t();
            t_json.put('LEGALENTITIES', t_array);
        END IF;

        IF (t_pos > 0)
        THEN
            get_legalentity(a_json => t_json, a_list => t_next);
        END IF;
    END;

    --    PROCEDURE get_legalentity2(a_json IN json_object_t, a_list IN VARCHAR2)
    --    AS
    --        t_value        NUMBER;
    --        t_next         VARCHAR2(1000);
    --        t_pos          NUMBER;
    --
    --        t_array        json_array_t;
    --        t_json         json_object_t;
    --        t_tmp          json_object_t;
    --        t_entity       json_object_t := json_object_t();
    --
    --        t_return       json_object_t := json_object_t();
    --    BEGIN
    --        t_value :=
    --            TO_NUMBER(REGEXP_SUBSTR(a_list,
    --                                    '[^/]+',
    --                                    1,
    --                                    1));
    --        t_array := a_json.get_array('LEGALENTITIES');
    --dbms_output.put_line('t_value: ' || t_value);
    --
    --        -- get next level down
    --        t_pos :=
    --            INSTR(a_list,
    --                  '/',
    --                  1,
    --                  2);
    --
    --        IF (t_pos > 0)
    --        THEN
    --            t_next := SUBSTR(a_list, t_pos);
    --        END IF;
    --dbms_output.put_line('t_pos: ' || t_pos || '  next: ' || t_next || '  cnt: ' || t_legalentity.count);
    --
    --        IF legalentity_type(t_value) SUBMULTISET t_legalentity
    --        THEN
    --            -- find object
    --dbms_output.put_line('find object');
    --            FOR inx IN 0 .. t_array.get_size() - 1
    --            LOOP
    --                t_tmp := TREAT(t_array.get(inx) AS json_object_t);
    --
    --                IF t_tmp IS NOT NULL
    --                THEN
    --                    IF (t_tmp.get_number('OBJECTID') = t_value)
    --                    THEN
    --                        t_json := t_tmp;
    --                        t_array := t_json.get_array('LEGALENTITIES');
    --
    --                        IF t_array IS NULL
    --                        THEN
    --                            t_json.put('LEGALENTITIES', json_array_t);
    --                        END IF;
    --
    --                        EXIT;
    --                    END IF;
    --                END IF;
    --            END LOOP;
    --        END IF;
    --
    --
    --        IF (t_json IS NULL --    AND SUBSTR(api.pkg_columnquery.VALUE(t_value, 'LEStructureRel'), 1, 3) !=
    --                           --        'P12'
    --           )
    --        THEN
    --                    DBMS_OUTPUT.put_line(
    --                        'HierarchyLevel: ' || api.pkg_columnquery.VALUE(t_value, 'HierarchyLevel'));
    --            --        DBMS_OUTPUT.put_line(
    --            --            t_value
    --            --            || '  name: '
    --            --            || api.pkg_columnquery.VALUE(t_value, 'objectdefname'));
    --
    --            t_legalentity.EXTEND(1);
    --            t_legalentity(t_legalentity.COUNT) := t_value;
    --
    --            t_entity.put('OBJECTID', t_value);
    --            t_entity.put(
    --                'LESTRUCTUREREL',
    --                api.pkg_columnquery.VALUE(t_value, 'LeStructureRel'));
    --            t_entity.put(
    --                'HIERARCHYLEVEL',
    --                api.pkg_columnquery.VALUE(t_value, 'HierarchyLevel'));
    --            t_entity.put(
    --                'LEGALENTITYTYPE',
    --                        api.pkg_columnquery.VALUE(t_value, 'LegalEntityType')
    --                );
    --
    --            t_entity.put(
    --                'P12TYPE',
    --                CASE SUBSTR(
    --                         api.pkg_columnquery.VALUE(t_value, 'LEStructureRel'),
    --                         1,
    --                         3)
    --                    WHEN 'P12'
    --                    THEN
    --                        api.pkg_columnquery.VALUE(t_value, 'LEStructureRel')
    --                    ELSE
    --                        NULL
    --                END);
    --
    --
    --                    t_entity.put(
    --                        'OWNERTYPE',
    --                        api.pkg_columnquery.VALUE(t_value, 'OwnerType'));
    --                    t_entity.put(
    --                        'TITLE',
    --                        get_titles(a_legalentityobjectid => t_value));
    --                    t_entity.put(
    --                        'PERCENTAGEOFOWNERSHIP',
    --                        api.pkg_columnquery.VALUE(t_value,
    --                                                  'PercentageOfOwnership'));
    --
    --                    CASE api.pkg_columnquery.VALUE(t_value,
    --                                                   'LegalEntityType')
    --                        WHEN 'Person'
    --                        THEN
    --                            t_entity.put(
    --                                'PERSON',
    --                                get_person(a_legalentityobjectid => t_value));
    --                        WHEN 'Company'
    --                        THEN
    --                            t_entity.put(
    --                                'COMPANY',
    --                                get_company(a_legalentityobjectid => t_value));
    --                        ELSE
    --                            NULL;
    --                    END CASE;
    --
    --            t_array.append(t_entity);
    --
    --            t_json := json_object_t();
    --            t_json.put('LEGALENTITIES', t_array);
    --        END IF;
    --
    --        IF (t_pos > 0)
    --        THEN
    --            get_legalentity2(a_json => t_json, a_list => t_next);
    --        END IF;
    --    END;

    -- ******************************************************
    -- ******************************************************
    FUNCTION get_legalentity(a_objectid IN NUMBER)
        RETURN json_array_t
    IS
        t_array        json_array_t := json_array_t();
        t_return       json_object_t := json_object_t();
    BEGIN
        t_return.put('LEGALENTITIES', t_array);

        FOR rec
            IN (    SELECT DISTINCT
                           SYS_CONNECT_BY_PATH(r.toobjectid, '/')     path2
                      FROM api.relationships r
                           JOIN api.objects f ON f.objectid = r.toobjectid
                START WITH r.fromobjectid = a_objectid
                       AND (f.objectdefid =
                            api.pkg_configquery.objectdefidforname(
                                'o_LegalEntity')
                         OR f.objectdefid =
                            api.pkg_configquery.objectdefidforname(
                                'j_License'))
                       AND r.endpointid IN (292101,
                                            338110,
                                            310133,
                                            298362,
                                            311516,
                                            314059,
                                            329508,
                                            427253,
                                            447075,
                                            340283)
                CONNECT BY r.fromobjectid = PRIOR r.toobjectid
                       AND r.relationshipid != PRIOR r.relationshipid
                       AND f.objectdefid =
                           api.pkg_configquery.objectdefidforname(
                               'o_LegalEntity')
                       AND r.endpointid IN (292101,
                                            338110,
                                            310133,
                                            298362,
                                            311516,
                                            314059,
                                            329508,
                                            427253,
                                            447075,
                                            340283)
                  ORDER BY path2)
        LOOP
            get_legalentity(a_json => t_return, a_list => rec.path2);
        END LOOP;

        RETURN t_return.get_array('LEGALENTITIES');
    END;
END;
/
