CREATE OR REPLACE FUNCTION BIZMOD_API.uploadfirstdata(
    a_packet       IN CLOB,
    a_seq          IN NUMBER)
    RETURN CLOB
IS
    -- ****************************************************************************
    -- File:        BIZMOD_API.UPLOADFIRSTDATA.FNC
    -- Author:      Timothy J. Lord
    --
    -- Purpose :
    --
    -- History:
    -------------------------------------------------------------------------------
    --    Ver:     Date          Ticket          Comment
    --          09/13/2023 TJL  BIZ-14091   Initial File Created
    --          12/20/2023 TJL  BIZ-14091   Corrected bugs and adding logging
    --    1.0   01/04/2023 TJL  BIZ-14091   Corrected bug in parsing file
    -- ****************************************************************************

    FUNCTION split_clob(a_clob         IN CLOB,
                        a_delimiter    IN VARCHAR2 DEFAULT CHR(10))
        RETURN var_tbl
    IS
        t_tbl          var_tbl := var_tbl();

        t_line_limit CONSTANT INTEGER := 4000; -- for single byte characters
        t_chunk_limit CONSTANT INTEGER := 8 * t_line_limit;

        t_clob_length  INTEGER;
        t_clob_index   INTEGER;
        t_chunk        VARCHAR2(32767);
        t_chunk_end    INTEGER;
        t_chunk_length INTEGER;
        t_chunk_index  INTEGER;
        t_delim_len    INTEGER := LENGTH(a_delimiter);
        t_line_end     INTEGER;
        t_tmp          VARCHAR2(32767);
    BEGIN
        t_clob_length := DBMS_LOB.getlength(a_clob);
        t_clob_index := 1;

        WHILE t_clob_index <= t_clob_length
        LOOP
            -- Pull one chunk off the clob at a time and process it.
            t_chunk := DBMS_LOB.SUBSTR(a_clob, t_chunk_limit, t_clob_index);

            IF t_clob_index > t_clob_length - t_chunk_limit
            THEN
                -- If we walked off the end the clob,
                -- then the chunk is whatever we picked up at the end
                -- delimited or not.
                t_clob_index := t_clob_length + 1;
            ELSE
                -- Find the last delimiter in the chunk, mark that as the end.
                t_chunk_end := INSTR(t_chunk, a_delimiter, -1);

                IF t_chunk_end = 0
                THEN
                    -- If there aren't any delimiters in a chunk
                    -- then return a slightly smaller piece of the chunk
                    -- to avoid accidentally splitting a delimiter
                    -- that spans two chunks.
                    -- This would cause part of the delimiter
                    -- to be returned in the last line
                    -- of one chunk, and the rest
                    -- in the first line of the next chunk.
                    -- To avoid the possibility,
                    -- simply reduce the chunk by one line.
                    t_chunk :=
                        SUBSTR(t_chunk, 1, t_chunk_limit - t_line_limit);
                    t_clob_index :=
                        t_clob_index + t_chunk_limit - t_line_limit;
                ELSE
                    -- If there are delimiters (this is the expected condtion)
                    -- then pull the chunk up to and including the delimiter.
                    t_chunk :=
                        SUBSTR(t_chunk, 1, t_chunk_end + t_delim_len - 1);
                    t_clob_index :=
                        t_clob_index + t_chunk_end + t_delim_len - 1;
                END IF;
            END IF;

            --  Given a varchar2 chunk split it into lines
            t_chunk_index := 1;
            t_chunk_length := LENGTH(t_chunk);

            WHILE t_chunk_index <= t_chunk_length
            LOOP
                t_line_end := INSTR(t_chunk, a_delimiter, t_chunk_index);

                IF t_line_end = 0
                OR (t_line_end - t_chunk_index) > t_line_limit
                THEN
                    t_tmp := SUBSTR(t_chunk, t_chunk_index, t_line_limit);

                    FOR LN
                        IN (    SELECT TRIM(
                                           REGEXP_SUBSTR(
                                               REGEXP_REPLACE(t_tmp,
                                                              '([=()]+)',
                                                              ''),
                                               '[^' || a_delimiter || ']+',
                                               1,
                                               LEVEL))    str
                                  FROM DUAL
                            CONNECT BY REGEXP_SUBSTR(
                                           REGEXP_REPLACE(t_tmp,
                                                          '([=()]+)',
                                                          ''),
                                           '[^' || a_delimiter || ']+',
                                           1,
                                           LEVEL)
                                           IS NOT NULL)
                    LOOP
                        t_tbl.EXTEND(1);
                        t_tbl(t_tbl.COUNT) :=
                            REGEXP_REPLACE(LN.str, '([=()]+)', '');
                    END LOOP;

                    t_chunk_index := t_chunk_index + t_line_limit;
                ELSE
                    t_tmp :=
                        SUBSTR(t_chunk,
                               t_chunk_index,
                               t_line_end - t_chunk_index);

                    FOR LN
                        IN (    SELECT TRIM(
                                           REGEXP_SUBSTR(
                                               REGEXP_REPLACE(t_tmp,
                                                              '([=()]+)',
                                                              ''),
                                               '[^' || a_delimiter || ']+',
                                               1,
                                               LEVEL))    str
                                  FROM DUAL
                            CONNECT BY REGEXP_SUBSTR(
                                           t_tmp,
                                           '[^' || a_delimiter || ']+',
                                           1,
                                           LEVEL)
                                           IS NOT NULL)
                    LOOP
                        t_tbl.EXTEND(1);
                        t_tbl(t_tbl.COUNT) :=
                            REGEXP_REPLACE(LN.str, '([=()]+)', '');
                    END LOOP;

                    t_chunk_index := t_line_end + t_delim_len;
                END IF;
            END LOOP;
        END LOOP;

        RETURN t_tbl;
    EXCEPTION
        WHEN no_data_needed
        THEN
            NULL;
    END split_clob;
-- ***************************************************************************
-- ***************************************************************************
--  Main Function
-- ***************************************************************************
-- ***************************************************************************
BEGIN
    DECLARE
        t_headings     var_tbl;

        t_var          var_tbl;
        t_blob         BLOB;
        t_level        NUMBER := 0;
        t_row          e_payments_processed_t%ROWTYPE;
        t_return       CLOB;

        t_recordsprocessed NUMBER := 0;
        t_recordsloaded NUMBER := 0;
        t_errorrecords NUMBER := 0;
        t_recordsskipped NUMBER := 0;
        t_count        NUMBER;
        t_filename     VARCHAR2(512) := json_value(a_packet, '$.FILE_NAME');
        t_msg          VARCHAR2(4000);
        t_sqlerrm      VARCHAR2(4000);
        t_trace        VARCHAR2(4000);
        t_info         VARCHAR2(32000);
        t_to           VARCHAR2(4000);
        t_from         VARCHAR2(4000);
        t_cc           VARCHAR2(4000);
        t_bcc          VARCHAR2(4000);
    BEGIN
        BEGIN
            SELECT e.filedata
              INTO t_blob
              FROM bizmod_api.eservices_log_t e
             WHERE e.seq = a_seq;

            t_var := split_clob(TO_CLOB(t_blob));
            t_headings :=
                split_clob(a_clob => UPPER(t_var(1)), a_delimiter => ',');

            -- remove characters in headings
            FOR inx IN 1 .. t_headings.COUNT
            LOOP
                t_headings(inx) :=
                    UPPER(REGEXP_REPLACE(t_headings(inx), '([ ./#]+)', ''));
            END LOOP;

            FOR inx IN 2 .. t_var.COUNT
            LOOP
                DBMS_OUTPUT.put_line(
                    LPAD(inx, 2, '0') || ' - ' || t_var(inx));

                FOR rec
                    IN (    SELECT TRIM(
                                       BOTH '"' FROM TRIM(
                                                         BOTH ',' FROM REGEXP_SUBSTR(
                                                                           t_var(
                                                                               inx),
                                                                           '(".*?"|.*?)(,|$)',
                                                                           1,
                                                                           LEVEL)))
                                       split,
                                   LEVEL,
                                   ROWNUM
                                       LN
                              FROM DUAL
                        CONNECT BY REGEXP_SUBSTR(t_var(inx),
                                                 '(".*?"|.*?)(,|$)',
                                                 1,
                                                 LEVEL)
                                       IS NOT NULL)
                LOOP
                    --                                    DBMS_OUTPUT.put_line(
                    --                                        t_headings(rec.LN)
                    --                                        || ' : '
                    --                                        || NVL(rec.split, 'null')
                    --                                        || ' : '
                    --                                        || rec.LN);

                    CASE t_headings(rec.LN)
                        WHEN 'SITEID'
                        THEN
                            t_row.siteid := rec.split;
                        WHEN 'SITENAME'
                        THEN
                            t_row.sitename := rec.split;
                        WHEN 'TRANSACTIONID'
                        THEN
                            t_row.transactionid := rec.split;
                        WHEN 'PAYMENTID'
                        THEN
                            t_row.paymentid := rec.split;
                        WHEN 'APPID'
                        THEN
                            t_row.appid := rec.split;
                        WHEN 'TRANSACTIONRESULT'
                        THEN
                            t_row.transactionresult := rec.split;
                        WHEN 'PAYMENTRESULT'
                        THEN
                            t_row.paymentresult := rec.split;
                        WHEN 'PAYMENTTIMESTAMP'
                        THEN
                            t_row.paymenttimestamp :=
                                TO_DATE(rec.split, 'MM/DD/YYYY HH:MI:SS AM');
                        WHEN 'PAYMENTAMOUNT'
                        THEN
                            t_row.paymentamount :=
                                REGEXP_REPLACE(rec.split, '([$,]+)', '');
                        WHEN 'REFERENCE'
                        THEN
                            t_row.reference := rec.split;
                            t_row.licensenumber :=
                                REGEXP_SUBSTR(rec.split,
                                              '[^,]+',
                                              1,
                                              2);
                        WHEN 'RECURRINGID'
                        THEN
                            t_row.recurringid := rec.split;
                        WHEN 'REGISTRATIONID'
                        THEN
                            t_row.registrationid := rec.split;
                        WHEN 'PROCESSOR'
                        THEN
                            t_row.processor := rec.split;
                        WHEN 'PAYMTATTEMPTAMOUNT'
                        THEN
                            t_row.paymtattemptamount :=
                                REGEXP_REPLACE(rec.split, '([$,]+)', '');
                        WHEN 'PAYMTPROCESSEDAMOUNT'
                        THEN
                            t_row.paymtprocessedamount :=
                                REGEXP_REPLACE(rec.split, '([$,]+)', '');
                        WHEN 'USESCONVFEE'
                        THEN
                            t_row.usesconvfee := rec.split;
                        WHEN 'FULLNAME'
                        THEN
                            t_row.fullname := rec.split;
                        WHEN 'FIRSTNAME'
                        THEN
                            t_row.firstname := rec.split;
                        WHEN 'LASTNAME'
                        THEN
                            t_row.lastname := rec.split;
                        WHEN 'ACCOUNTNUMBER'
                        THEN
                            t_row.accountnumber := rec.split;
                        WHEN 'PAYMENTMEDIUM'
                        THEN
                            t_row.paymentmedium := rec.split;
                        WHEN 'ACCOUNTTYPECODE'
                        THEN
                            t_row.accounttypecode := rec.split;
                        WHEN 'CARDTYPE'
                        THEN
                            t_row.cardtype := rec.split;
                        WHEN 'CONFIRMATION'
                        THEN
                            t_row.confirmationnumber := rec.split;
                        WHEN 'PAYMENTTYPE'
                        THEN
                            t_row.paymenttype := rec.split;
                        WHEN 'PAYMENTCOMMAND'
                        THEN
                            t_row.paymentcommand := rec.split;
                        WHEN 'PAYMENTCHANNEL'
                        THEN
                            t_row.paymentchannel := rec.split;
                        WHEN 'PAYMENTSTATUS'
                        THEN
                            t_row.paymentstatus := rec.split;
                        WHEN 'SETTLEMENTBATCHID'
                        THEN
                            t_row.settlementbatchid := rec.split;
                        WHEN 'USERID'
                        THEN
                            t_row.userid := rec.split;
                        WHEN 'ACHPAYMENTTYPE'
                        THEN
                            t_row.achpaymenttype := rec.split;
                        WHEN 'ACHRETURNCODE'
                        THEN
                            t_row.achreturncode := rec.split;
                        WHEN 'BILLINGSTREET1'
                        THEN
                            t_row.billingstreet1 := rec.split;
                        WHEN 'BILLINGSTREET2'
                        THEN
                            t_row.billingstreet2 := rec.split;
                        WHEN 'BILLINGCITY'
                        THEN
                            t_row.billingcity := rec.split;
                        WHEN 'BILLINGSTATEPROVINCE'
                        THEN
                            t_row.billingstateprovince := rec.split;
                        WHEN 'BILLINGZIP'
                        THEN
                            t_row.billingzip := rec.split;
                        WHEN 'BILLINGCOUNTRY'
                        THEN
                            t_row.billingcountry := rec.split;
                        WHEN 'BILLINGPHONE'
                        THEN
                            t_row.billingphone := rec.split;
                        WHEN 'BILLINGEMAIL'
                        THEN
                            t_row.billingemail := rec.split;
                        WHEN 'SETTLEMENTREFERENCECODE'
                        THEN
                            t_row.settlementreferencecode := rec.split;
                        WHEN 'POSTDATEEDT'
                        THEN
                            t_row.postdateedt :=
                                TO_DATE(rec.split, 'MM/DD/YYYY');
                        WHEN 'ROUTINGNUMBER'
                        THEN
                            t_row.routingnumber := rec.split;
                        WHEN 'EXPORTTIMESTAMP'
                        THEN
                            t_row.exporttimestamp :=
                                TO_DATE(rec.split, 'MM/DD/YYYY HH:MI:SS AM');
                        ELSE
                            NULL;
                    END CASE;
                END LOOP;

                t_row.createddate := SYSDATE;

                -- make sure not adding duplicate records to payment process table
                MERGE INTO bizmod_api.e_payments_processed_t a
                     USING (SELECT t_row.confirmationnumber
                                       confirmationnumber,
                                   t_row.paymenttype
                                       paymenttype
                              FROM DUAL) a2
                        ON (a.confirmationnumber = a2.confirmationnumber
                        AND a.paymenttype = a2.paymenttype)
                WHEN NOT MATCHED
                THEN
                    INSERT     VALUES t_row
                       LOG ERRORS INTO bizmod_api.err$_e_payments_processed_t
                               ('INSERT')
                               REJECT LIMIT UNLIMITED;

                IF (SQL%ROWCOUNT = 0)
                THEN
                    -- check if error record generated
                    BEGIN
                        SELECT ora_err_mesg$
                          INTO t_return
                          FROM bizmod_api.err$_e_payments_processed_t e
                         WHERE e.confirmationnumber =
                               t_row.confirmationnumber
                           AND e.paymenttype = t_row.paymenttype
                           AND e.logdate =
                               (SELECT MAX(e2.logdate)
                                  FROM bizmod_api.err$_e_payments_processed_t
                                       e2
                                 WHERE e2.confirmationnumber =
                                       e.confirmationnumber
                                   AND e2.paymenttype = e.paymenttype
                                   AND e2.logdate >
                                         CURRENT_TIMESTAMP
                                       - NUMTODSINTERVAL(1, 'MINUTE'));

                        t_errorrecords := t_errorrecords + 1;
                        DBMS_OUTPUT.put_line('error: ' || t_return);
                    EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                            t_recordsskipped := t_recordsskipped + 1;
                    END;
                ELSE
                    t_recordsloaded := t_recordsloaded + 1;
                END IF;

                COMMIT;
                t_recordsprocessed := t_recordsprocessed + 1;
            END LOOP;

            --        DBMS_OUTPUT.put_line('Loaded: ' || t_recordsloaded);
            --        DBMS_OUTPUT.put_line('Duplicate: ' || t_recordsskipped);
            --        DBMS_OUTPUT.put_line('Errors: ' || t_errorrecords);
            --        DBMS_OUTPUT.put_line('Processed: ' || t_recordsprocessed);

            t_return :=
                json_object(
                    'PACKET_TYPE' VALUE 'MESSAGE',
                    'DATA' VALUE
                        json_object(
                            'MSGNO' VALUE '0',
                            'MSG' VALUE
                                'File Uploaded'
                                || CASE
                                       WHEN t_errorrecords > 0
                                       THEN
                                           ' with errors'
                                       ELSE
                                           NULL
                                   END));

            IF (t_recordsloaded > 0)
            THEN
                SELECT COUNT(1)
                  INTO t_count
                  FROM scheduler.sysschedule s
                 WHERE status IN (1)
                   AND s.description LIKE '%Create AWF Payment Batch';

                IF (t_count = 0)
                THEN
                    bizmod_api.createjob(
                        a_procedure => 'CREATEAWFPAYMENTSJOB',
                        a_description => 'Create AWF Payment Batch',
                        a_argument1 => '1');
                END IF;

                SELECT COUNT(1)
                  INTO t_count
                  FROM scheduler.sysschedule s
                 WHERE status IN (1)
                   AND s.description LIKE '%Create Transmittals';

                IF (t_count = 0)
                THEN
                    bizmod_api.createjob(
                        a_procedure => 'CREATETRANSMITTALJOB',
                        a_description => 'Create Transmittals');
                END IF;
            END IF;

            t_info :=
                'File Uploaded'
                || CHR(13)
                || CHR(9)
                || 'File Name: '
                || CHR(9)
                || t_filename
                || CHR(13)
                || CHR(9)
                || 'Processed: '
                || CHR(9)
                || t_recordsprocessed
                || CHR(13)
                || CHR(9)
                || 'Loaded: '
                || CHR(9)
                || t_recordsloaded
                || CHR(13)
                || CHR(9)
                || 'Duplicate: '
                || CHR(9)
                || t_recordsskipped
                || CHR(13)
                || CASE t_errorrecords
                       WHEN 0
                       THEN
                           NULL
                       ELSE
                           CHR(9)
                           || 'Errors: '
                           || CHR(9)
                           || t_errorrecords
                           || CHR(13)
                   END;

            UPDATE eservices_log_t e
               SET e.info = t_info,
                   e.err =
                       CASE
                           WHEN t_errorrecords > 0
                           THEN
                               t_errorrecords
                               || ' error(s) found on file upload'
                           ELSE
                               NULL
                       END
             WHERE seq = a_seq;

            COMMIT;

            IF (t_errorrecords > 0)
            THEN
                t_sqlerrm := 'Errors on First Data File Upload';
            END IF;
        EXCEPTION
            WHEN OTHERS
            THEN
                t_sqlerrm := SQLERRM;
                t_trace := DBMS_UTILITY.format_error_backtrace;
                t_msg := SUBSTR(t_sqlerrm || ' :: ' || t_trace, 1, 3990);

                t_info := t_info || 'Error in file upload';

                UPDATE eservices_log_t
                   SET err = t_msg, responsedate = SYSTIMESTAMP
                 WHERE seq = a_seq;

                COMMIT;

                t_return :=
                    json_object(
                        'PACKET_TYPE' VALUE 'MESSAGE',
                        'DATA' VALUE
                            json_object('MSGNO' VALUE '5',
                                        'MSG' VALUE 'Oracle Exception',
                                        'EXCEPTION' VALUE t_msg));
        END;

        INSERT INTO bizmod_api.e_process_log_t(seq,
                                               processjob,
                                               info,
                                               errmsg,
                                               bktrace)
             VALUES (0,
                     'UPLOADFIRSTDATA',
                     t_info,
                     t_sqlerrm,
                     t_trace);

        COMMIT;

        -- Generate email of completion of first data processing
        SELECT pto,
               pfrom,
               pcc,
               pbcc
          INTO t_to,
               t_from,
               t_cc,
               t_bcc
          FROM (SELECT m.parametername, m.parametervalue
                  FROM abc.email_parameters m
                 WHERE app = 'EPAYMENT')
               PIVOT (MAX(parametervalue)
                     FOR parametername
                     IN ('TO' pto, 'FROM' pfrom, 'CC' pcc, 'BCC' pbcc));

        IF (t_from IS NOT NULL)
        THEN
            sitespecific.pkg_tlemail.sendemail(
                p_fromaddress => t_from,
                p_toaddress => t_to,
                p_cc        => t_cc,
                p_bcc       => t_bcc,
                p_subject   => 'First Data File Upload'
                               || CASE
                                      WHEN t_sqlerrm IS NOT NULL
                                        OR t_errorrecords > 0
                                      THEN
                                          ' has errors'
                                      ELSE
                                          NULL
                                  END,
                p_body      => t_info,
                p_mimetype  => 'text/plain');
        END IF;

        RETURN t_return;
    END;
END;
/
