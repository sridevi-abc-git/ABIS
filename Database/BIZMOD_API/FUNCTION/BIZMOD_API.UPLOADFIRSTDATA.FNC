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
    --    2.0   02/06/2024 TJL  BIZ-14440   Removed parsing of Reference Column Data
    --    3.0   05/21/2024 TJL  BIZ-15523   Changed how batches are scheduled
    --    3.1.1 05/24/2024 TJL  BIZ-15485   Changed how uploade file data is processed
    --                                        and what email procedure is called
    -- ****************************************************************************

    FUNCTION split_clob(a_clob         IN CLOB,
                        a_delimiter    IN VARCHAR2 DEFAULT CHR(10))
        RETURN bizmod_api.var_tbl
    IS
        t_tbl          bizmod_api.var_tbl := bizmod_api.var_tbl();

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

    PROCEDURE get_ref_info(a_info IN VARCHAR2, a_rec IN OUT fd_rec)
    IS
        t_list         api.pkg_definition.udt_idlist;
    BEGIN
        FOR rec IN (    SELECT TRIM(
                                   BOTH '"' FROM TRIM(
                                                     BOTH ',' FROM REGEXP_SUBSTR(
                                                                       a_info,
                                                                       '(".*?"|.*?)(,|$)',
                                                                       1,
                                                                       LEVEL)))    split
                          FROM DUAL
                    CONNECT BY REGEXP_SUBSTR(a_info,
                                             '(".*?"|.*?)(,|$)',
                                             1,
                                             LEVEL)
                                   IS NOT NULL)
        LOOP
            -- find license number in string by lookup
            t_list :=
                api.pkg_simplesearch.objectsbyindex(
                    'j_License',
                    'ExternalFileNum',
                    REGEXP_REPLACE(rec.split, '[^[:digit:]]+'));

            IF (t_list.COUNT > 0)
            THEN
                a_rec.licensenumber :=
                    api.pkg_columnquery.VALUE(t_list(1), 'LicenseNumber');
            END IF;

            -- find fee activity in string by lookup
            t_list :=
                api.pkg_simplesearch.objectsbyindex('o_FeeSchedule',
                                                    'FeeActivity',
                                                    TRIM(rec.split));

            IF (t_list.COUNT > 0)
            THEN
                a_rec.feeactivity := TRIM(rec.split);
            END IF;
        END LOOP;
    END;
-- ***************************************************************************
-- ***************************************************************************
--  Main Function
-- ***************************************************************************
-- ***************************************************************************
BEGIN
    DECLARE
        t_headings     bizmod_api.var_tbl;

        t_var          bizmod_api.var_tbl;
        t_blob         BLOB;
        t_level        NUMBER := 0;
        t_return       CLOB;

        t_recordsprocessed NUMBER := 0;
        t_recordsloaded NUMBER := 0;
        t_errorrecords NUMBER := 0;
        t_recordsskipped NUMBER := 0;
        t_recordsduplicate NUMBER := 0;
        t_recordsvoided NUMBER := 0;
        t_awf          NUMBER;
        t_other        NUMBER;
        t_filename     VARCHAR2(512) := json_value(a_packet, '$.FILE_NAME');
        t_msg          VARCHAR2(4000);
        t_sqlerrm      VARCHAR2(4000);
        t_trace        VARCHAR2(4000);
        t_info         VARCHAR2(32000);

        t_fd           fd_tbl := fd_tbl();
        t_row          fd_rec;
        t_cnt          NUMBER;
        t_total        NUMBER := 0;
    BEGIN
        BEGIN
            t_info :=
                'File Uploaded'
                || CHR(13)
                || CHR(9)
                || 'File Name: '
                || CHR(9)
                || t_filename
                || CHR(13);

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
                t_row :=
                    NEW fd_rec(NULL,
                               NULL,
                               NULL,
                               NULL,
                               NULL,
                               NULL,
                               NULL,
                               NULL,
                               t_filename,
                               SYSDATE,
                               a_seq,
                               NULL);

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
                    DBMS_OUTPUT.put_line(
                        t_headings(rec.LN)
                        || ' : '
                        || NVL(rec.split, 'null')
                        || ' : '
                        || rec.LN);

                    CASE t_headings(rec.LN)
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
                            get_ref_info(a_info => rec.split, a_rec => t_row);
                        WHEN 'PAYMENTMEDIUM'
                        THEN
                            t_row.paymentmedium := rec.split;
                        WHEN 'CONFIRMATION'
                        THEN
                            t_row.confirmationnumber := rec.split;
                        WHEN 'PAYMENTTYPE'
                        THEN
                            t_row.paymenttype := rec.split;
                        ELSE
                            NULL;
                    END CASE;
                END LOOP;

                  -- make sure payment is in abis and not voided
                  SELECT CASE COUNT(p.confirmationid)
                             WHEN 0
                             THEN
                                 'N'
                             ELSE
                                 CASE
                                     WHEN api.pkg_columnquery.VALUE(
                                              p.paymentobjectid,
                                              'IsVoidedFlag') =
                                          'Y'
                                       OR api.pkg_columnquery.VALUE(
                                              p.paymentobjectid,
                                              'IsDishonored') =
                                          'Y'
                                       OR api.pkg_columnquery.VALUE(
                                              p.paymentobjectid,
                                              'IsRefund') =
                                          'Y'
                                     THEN
                                         'V'
                                     --                                     WHEN api.pkg_columnquery.numericvalue(
                                     --                                              p.paymentobjectid,
                                     --                                              'PaymentAmount') !=
                                     --                                          t_row.paymentamount
                                     --                                     THEN
                                     --                                         'E'
                                     WHEN p.paymentobjectid IS NOT NULL
                                              THEN
                                                  CASE
                                                      WHEN api.pkg_columnquery.numericvalue(
                                                               p.paymentobjectid,
                                                               'PaymentAmount') !=
                                                           t_row.paymentamount
                                                      THEN
                                                          'E'
                                                      ELSE
                                                          'Y'
                                                      END    
                                     ELSE
                                         'Y'
                                 END
                         END
                    INTO t_row.abispayment
                    FROM bizmod_api.e_payments_t p
                   WHERE p.confirmationid = t_row.confirmationnumber
                GROUP BY p.paymentobjectid;

                -- check if duplicate record
                SELECT COUNT(licensenumber)
                  INTO t_cnt
                  FROM bizmod_api.first_data_t fd
                 WHERE fd.confirmationnumber = t_row.confirmationnumber;

                IF (t_cnt > 0)
                THEN
                    t_recordsduplicate := t_recordsduplicate + 1;
                    t_recordsprocessed := t_recordsprocessed + 1;
                    CONTINUE;
                END IF;

                -- skip record if payment type is not Primary
                IF (t_row.paymenttype != 'Primary')
                THEN
                    CONTINUE;
                END IF;

                t_recordsprocessed := t_recordsprocessed + 1;
                t_fd.EXTEND(1);
                t_fd(t_fd.COUNT) := t_row;
            END LOOP;

            -- insert records in to first data table
            INSERT INTO bizmod_api.first_data_t fd
                SELECT * FROM TABLE(t_fd)
                    LOG ERRORS INTO bizmod_api.err$_first_data_t
                            ('INSERT')
                            REJECT LIMIT UNLIMITED;

            t_recordsloaded := SQL%ROWCOUNT;

            -- check for error records
            IF (t_recordsloaded < t_fd.COUNT)
            THEN
                t_errorrecords := t_fd.COUNT - t_recordsloaded;
            END IF;

            -- get count of void/refund/dishonored
            SELECT COUNT(fd.feeactivity)     cnt
              INTO t_recordsvoided
              FROM TABLE(t_fd) fd
             WHERE fd.abispayment != 'Y';

            COMMIT;
            t_info :=
                CHR(9)
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
                || t_recordsduplicate
                || CHR(13)
                || CHR(9)
                || 'Unable to Process: '
                || CHR(9)
                || t_recordsvoided
                || CHR(13)
                || CASE
                       WHEN t_errorrecords > 0
                       THEN
                           CHR(9)
                           || 'Error Records: '
                           || CHR(9)
                           || t_errorrecords
                       ELSE
                           NULL
                   END
                || CHR(13);

            IF (t_recordsloaded > 0)
            THEN
                t_cnt := 0;
                t_info := t_info || CHR(13) || 'Fee Activities: ' || CHR(13);

                FOR rec
                    IN (  SELECT fd.feeactivity,
                                 COUNT(fd.feeactivity)     cnt,
                                 SUM(fd.paymentamount)     paymentamount
                            FROM TABLE(t_fd) fd
                           WHERE fd.abispayment = 'Y'
                        GROUP BY fd.feeactivity)
                LOOP
                    t_total := t_total + rec.paymentamount;
                    t_cnt := t_cnt + rec.cnt;
                    t_info :=
                        t_info
                        || CHR(9)
                        || rec.cnt
                        || CHR(9)
                        || rec.feeactivity
                        || CHR(9)
                        || TO_CHAR(rec.paymentamount, 'fm9G999G999D00')
                        || CHR(13);
                END LOOP;

                t_info :=
                    t_info
                    || CHR(9)
                    || t_cnt
                    || CHR(9)
                    || 'Total:'
                    || CHR(9)
                    || TO_CHAR(t_total, 'fm9G999G999D00');
            END IF;

            IF (t_errorrecords > 0)
            THEN
                t_info := t_info || CHR(13) || 'ERRORS:' || CHR(13);

                FOR rec IN (SELECT e.licensenumber, ora_err_mesg$ msg
                              FROM err$_first_data_t e
                             WHERE e.logseq = a_seq)
                LOOP
                    t_info :=
                        t_info
                        || CHR(9)
                        || rec.licensenumber
                        || CHR(9)
                        || rec.msg;
                END LOOP;
            END IF;

            DBMS_OUTPUT.put_line(t_info);

            IF (t_recordsloaded > 0)
            THEN
                SELECT SUM(
                           CASE
                               WHEN fd.feeactivity LIKE '%AWF%' THEN 1
                               ELSE 0
                           END),
                       SUM(
                           CASE
                               WHEN fd.feeactivity NOT LIKE '%AWF%' THEN 1
                               ELSE 0
                           END)
                  INTO t_awf, t_other
                  FROM bizmod_api.first_data_t fd
                 WHERE fd.logseq = a_seq
                   AND fd.abispayment = 'Y';

                IF (t_awf > 0)
                THEN
                    bizmod_api.createjob(
                        a_procedure => 'CREATEAWFPAYMENTSJOB',
                        a_description => 'Create AWF Payment Batch',
                        a_argument1 => a_seq);
                END IF;

                IF (t_other > 0)
                THEN
                    bizmod_api.createjob(
                        a_procedure => 'CREATETRANSMITTALJOB',
                        a_description => 'Create Transmittals',
                        a_argument1 => a_seq);
                END IF;
            END IF;

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
        EXCEPTION
            WHEN OTHERS
            THEN
                t_sqlerrm := SQLERRM;
                t_trace := DBMS_UTILITY.format_error_backtrace;
                t_msg := SUBSTR(t_sqlerrm || ' :: ' || t_trace, 1, 3990);

                t_info := t_info || CHR(13) || 'Error in file upload';

                UPDATE bizmod_api.eservices_log_t
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
                     SUBSTR(t_info, 1, 3900),
                     t_sqlerrm,
                     t_trace);

        COMMIT;

        bizmod_api.utl_licenseinfo.sendemail(
            a_subject   => 'First Data File Upload'
                           || CASE
                                  WHEN t_sqlerrm IS NOT NULL
                                    OR t_errorrecords > 0
                                  THEN
                                      ' has errors'
                                  ELSE
                                      NULL
                              END,
            a_body      => t_info);

        RETURN t_return;
    END;
END;
/
