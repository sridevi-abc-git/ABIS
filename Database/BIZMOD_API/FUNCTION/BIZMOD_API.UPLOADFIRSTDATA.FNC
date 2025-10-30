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
    --    3.1.2 05/24/2024 TJL  BIZ-15485   Changed how uploade file data is processed
    --                                        and what email procedure is called
    --    4.0   07/08/2024 TJL              Add check to see if file already uploaded
    --    5.0   08/08/2024 TJL  BIZ-16000   Change to new createjob procedure
    --    6.0   10/14/2025 TJL  BIZ-19361   Change how file upload records are processed.
    -- ****************************************************************************

    t_return       CLOB;

    t_recordsprocessed NUMBER := 0;
    t_recordsloaded NUMBER := 0;
    t_errorrecords NUMBER := 0;
    t_recordsduplicate NUMBER := 0;
    t_awf          NUMBER := 0;
    t_other        NUMBER := 0;
    t_filename     VARCHAR2(512) := json_value(a_packet, '$.FILE_NAME');
    t_msg          VARCHAR2(4000);
    t_sqlerrm      VARCHAR2(4000);
    t_trace        VARCHAR2(4000);
    t_info         VARCHAR2(32000);

    t_fd           fd_tbl := fd_tbl();
    t_row          fd_rec;
    t_cnt          NUMBER;
    t_total        NUMBER := 0;

    t_paymentobjectid NUMBER;
    t_line_info    VARCHAR2(32000);
    t_error_info   VARCHAR2(32000);
    t_length       NUMBER;
    t_buffer       VARCHAR2(4000);
    t_quotes       BOOLEAN := FALSE;
    t_double       BOOLEAN := FALSE;
    t_char         VARCHAR2(1);
    t_end          BOOLEAN := FALSE;
    t_confirmation bizmod_api.var_tbl := bizmod_api.var_tbl();
    t_confirmation_position NUMBER;
    t_item_cnt     NUMBER := 0;
BEGIN
    SELECT COUNT(1)
      INTO t_cnt
      FROM bizmod_api.first_data_t fd
     WHERE UPPER(fd.filename) = UPPER(t_filename);

    IF (t_cnt = 0)
    THEN
        BEGIN
            FOR rec
                IN (WITH
                        data
                        AS
                            -- get the file data from the eservices log file by sequence number
                            (SELECT TO_CLOB(l.filedata)     AS clob_data
                               FROM bizmod_api.eservices_log_t l
                              WHERE l.seq = a_seq),
                        file_records
                        AS
                            -- Split the file data on CR/LF characters into rows
                            (    SELECT LEVEL         AS rn,
                                        REGEXP_SUBSTR(
                                            d.clob_data,
                                            '[^'
                                            || CHR(13)
                                            || CHR(10)
                                            || ']+',
                                            1,
                                            LEVEL)    AS row_data
                                   FROM data d
                             CONNECT BY LEVEL <=
                                        REGEXP_COUNT(
                                            d.clob_data,
                                            '[^'
                                            || CHR(13)
                                            || CHR(10)
                                            || ']+'))
                    -- Select file data row number and row data to be parsed in record loop
                    SELECT rn, row_data
                      FROM file_records)
            LOOP
                -- The following code will only parse out conformation number from the
                --  the individual settlement file records.

                -- first row of data contains the column headers and is parsed looking for
                --  the column location of the confirmation number to be retrieve from the
                --  row data

                -- get length of row data
                t_length := LENGTH(rec.row_data);

                -- walk thru row data one character at a time to parse the row data
                --   This is required because the settlement file does not follow normal
                --   CSV record format for some of their fields
                FOR inx IN 1 .. t_length
                LOOP
                    -- get character at current index position
                    t_char := DBMS_LOB.SUBSTR(rec.row_data, 1, inx);

                    -- check character for parsing
                    CASE t_char
                        -- check if comma, can delimit end of column being parsed
                        WHEN CHR(44)
                        THEN
                            -- if between quotes add to buffer, comma is part of the column data
                            IF (t_quotes)
                            THEN
                                t_buffer := CONCAT(t_buffer, t_char);
                            ELSE
                                -- end of column data which is comma delimited
                                t_end := TRUE;
                            END IF;
                        -- Double Quotes (")
                        WHEN CHR(34)
                        THEN
                            -- make sure not at the end of row data. With quoates
                            --  need to look at next character to make sure that
                            --  the quote was not escaped because it is part of the
                            --  column data being parsed
                            IF (inx != t_length
                            AND NOT t_double)
                            THEN
                                -- reverse current quote flag to indicate if at the
                                --  begining data or end. At the begining of column
                                --  parse, it be false which will then be true until
                                --  the next quote is found which could indicate end
                                --  of data between two quotes
                                t_quotes := NOT t_quotes;

                                -- check for two quotes are back to back
                                IF (DBMS_LOB.SUBSTR(rec.row_data, 1, inx + 1) =
                                    CHR(34))
                                THEN
                                    -- add quote to buffer and set quote flag to true
                                    --  since this is not the end of column data. The
                                    --  double flag is set so next quote will be skipped.
                                    t_buffer := CONCAT(t_buffer, t_char);
                                    t_quotes := TRUE;
                                    t_double := TRUE;
                                END IF;
                            ELSE
                                -- reset double flag so last quote will be processed
                                t_double := FALSE;
                            END IF;
                        -- Equal Sign (=)
                        WHEN CHR(61)
                        THEN
                            -- if equal sign is between quotes add to buffer
                            IF (t_quotes)
                            THEN
                                t_buffer := CONCAT(t_buffer, t_char);
                            ELSE
                                -- check if the next character is not a quote and
                                --  not at begining of data being parsed, add equal
                                --  sign to buffer. This will filter out equal sign
                                --  if is first character of column data
                                IF (DBMS_LOB.SUBSTR(rec.row_data, 1, inx + 1) !=
                                    CHR(34)
                                AND t_buffer IS NOT NULL)
                                THEN
                                    t_buffer := CONCAT(t_buffer, t_char);
                                END IF;
                            END IF;
                        -- add all other characters to buffer
                        ELSE
                            t_buffer := CONCAT(t_buffer, t_char);
                    END CASE;

                    IF (t_end)
                    THEN
                        t_item_cnt := t_item_cnt + 1;

                        IF (rec.rn = 1)
                        THEN
                            IF (UPPER(t_buffer) = 'CONFIRMATION #')
                            THEN
                                t_confirmation_position := t_item_cnt;
                                EXIT;
                            END IF;
                        ELSE
                            -- confirmation column is processed
                            EXIT WHEN t_confirmation_position = t_item_cnt;
                        END IF;

                        t_end := FALSE;
                        t_buffer := NULL;
                    END IF;
                END LOOP;

                -- skip header record
                IF (rec.rn > 1)
                THEN
                    -- add confirmation number to confirmation number list
                    t_confirmation.EXTEND(1);
                    t_confirmation(t_confirmation.COUNT) := t_buffer;
                END IF;

                t_buffer := NULL;
                t_item_cnt := 0;
                t_end := FALSE;
            END LOOP;

            -- walk thru the list of confirmation numbers
            FOR rec IN (  SELECT COLUMN_VALUE     v
                            FROM TABLE(t_confirmation)
                        GROUP BY COLUMN_VALUE
                        ORDER BY v)
            LOOP
                -- reset variable
                t_paymentobjectid := null;

                BEGIN
                    WITH
                        p
                        AS
                            -- Find the payment object by PayeeReference (Confirmation Number)
                            --  Do not process when more than one payment for a Confirmation Number)
                            --  This could be due to payment being disonhored or voided
                            (SELECT objectid, rec.v confirmationnumber
                               FROM TABLE(
                                        CAST(
                                            api.pkg_simplesearch.castableobjectsbyindex(
                                                a_objectdefname =>
                                                    'o_Payment',
                                                a_columnname =>
                                                    'PayeeReference',
                                                a_value     => rec.v)
                                                AS api.udt_objectlist)))
                      SELECT MAX(objectid)
                        INTO t_paymentobjectid
                        FROM p
                    GROUP BY p.confirmationnumber
                      HAVING COUNT(p.objectid) = 1;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        -- due nothing when payment object is not found. AWF Payment
                        --  at this time do not have a payment record
                        NULL;
                END;

                BEGIN
                      -- Retrieve payment information from eservices payment table.
                      --  It also checks to make sure that this payment has not been
                      --  processed in another settlement file.
                      SELECT fd_rec(
                                 LISTAGG(DISTINCT ep.licensenumber, ','), -- LICENSENUMBER
                                 NVL(
                                     LISTAGG(
                                         DISTINCT REGEXP_SUBSTR(ep.description,
                                                                '[^ ]+',
                                                                1,
                                                                3),
                                         ','),
                                     MAX(ep.description)), --FEEACTIVITY
                                 SUM(amountpaid), -- PAYMENTAMOUNT
                                 ep.paymentmethod, -- PAYMENTMEDIUM
                                 ep.confirmationid, -- CONFIRMATIONNUMBER
                                 CASE
                                     WHEN fd.confirmationnumber IS NULL
                                     THEN
                                         'Y'
                                     ELSE
                                         'D'
                                 END -- ABISPAYMENT
                                    )
                        INTO t_row
                        FROM bizmod_api.e_payments_t ep
                             LEFT OUTER JOIN bizmod_api.first_data_t fd
                                 ON (ep.confirmationid = fd.confirmationnumber)
                       WHERE ep.confirmationid = rec.v
                    GROUP BY ep.paymentmethod,
                             ep.confirmationid,
                             ep.seq,
                             ep.transmittalbatch,
                             fd.confirmationnumber;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        IF (t_paymentobjectid is not null)
                        then
                        -- If confirmation number not found in the eservices table
                        --  but has a payment object, then it was manually paid
                        --  thru ABIS and not LSP.
                        -- Retrieve payment information from payment objectid
                        SELECT fd_rec(
                                   LISTAGG(
                                       DISTINCT
                                           api.pkg_columnquery.VALUE(
                                               api.pkg_columnquery.VALUE(
                                                   r.fromobjectid,
                                                   'jobid'),
                                               'LicenseNumber'),
                                       ','),
                                   LISTAGG(
                                       DISTINCT
                                           api.pkg_columnquery.VALUE(
                                               r.toobjectid,
                                               'feeactivity'),
                                       ','), -- feeactivity,
                                   SUM(
                                       api.pkg_columnquery.numericvalue(
                                           reo.objectid,
                                           'PaymentAmount')), -- paymentamount,
                                   MAX(
                                       api.pkg_columnquery.VALUE(
                                           reo.objectid,
                                           'paymentmethod')), -- PAYMENTMEDIUM
                                   MAX(
                                       api.pkg_columnquery.VALUE(
                                           reo.objectid,
                                           'PayeeReference')), --   CONFIRMATIONNUMBER,
                                   CASE
                                       WHEN MAX(fd.confirmationnumber)
                                                IS NULL
                                       THEN
                                           'Y'
                                       ELSE
                                           'D'
                                   END) -- ABISPAYMENT)
                          INTO t_row
                          -- To get to some of the payment information need to go from
                          --  payment object -> payment transaction -> fee transaction
                          --   -> fee object -> license fee schedule
                          FROM api.registeredexternalobjects  reo
                               JOIN api.paymenttransactions pt
                                   ON pt.paymentid = TO_NUMBER(reo.linkvalue)
                               JOIN api.feetransactions ft
                                   ON ft.transactionid = pt.transactionid
                               JOIN api.relationships r
                                   ON (r.endpointid =
                                       api.pkg_configquery.endpointidforname(
                                           'o_fee',
                                           'LicenseFeeSchedule')
                                   AND r.fromobjectid =
                                       (SELECT reo.objectid -- feeobjid
                                          FROM api.registeredexternalobjects
                                               reo
                                         WHERE reo.objectdefid =
                                               api.pkg_configquery.objectdefidforname(
                                                   'o_fee')
                                           AND reo.linkvalue =
                                               TO_CHAR(ft.feeid)))
                               LEFT OUTER JOIN bizmod_api.first_data_t fd
                                   ON (fd.confirmationnumber =
                                       api.pkg_columnquery.VALUE(
                                           reo.objectid,
                                           'PayeeReference'))
                         WHERE reo.objectid = t_paymentobjectid;
                    else
                        t_row := fd_rec(null,null,null,null,rec.v,'E');
                    END IF;
                END;

                -- start building email information for body of a processing email
                t_line_info :=
                    t_row.licensenumber
                    || ', "'
                    || t_row.feeactivity
                    || '", '
                    || TO_CHAR(t_row.paymentamount, 'fmL99G999D00')
                    || ', '
                    || t_row.confirmationnumber
                    || ', "'
                    || api.pkg_columnquery.VALUE(t_paymentobjectid,
                                                 'PayeeName')
                    || '"'
                    || CHR(13);

                -- add a check to see if this payment was already been processed in
                --  a transmittal or awf payment batch
                IF (api.pkg_columnquery.VALUE(t_paymentobjectid, 'BatchId')
                        IS NOT NULL
                AND t_row.abispayment = 'Y')
                THEN
                    t_row.abispayment := 'B'; -- indicates already in a batch
                END IF;
                t_recordsprocessed := t_recordsprocessed + 1;

                -- setup error information if duplicate or already processed in a batch
                --   add to the process counters
                CASE t_row.abispayment
                    WHEN 'D'
                    THEN
                        t_recordsduplicate := t_recordsduplicate + 1;
                        t_error_info :=
                            t_error_info
                            || 'Duplicate Payment:  '
                            || t_line_info;
                    WHEN 'B'
                    THEN
                        t_error_info :=
                            t_error_info
                            || 'Allready Processed: '
                            || t_line_info;

                        t_errorrecords := t_errorrecords + 1;
                    WHEN 'E'
                    THEN
                        t_error_info :=
                            t_error_info
                            || 'Not Found: '
                            || t_line_info;

                        t_errorrecords := t_errorrecords + 1;
                    ELSE
                        CASE
                            WHEN t_row.feeactivity LIKE '%AWF%'
                            THEN
                                t_awf := t_awf + 1;
                            ELSE
                                t_other := t_other + 1;
                        END CASE;
                END CASE;

                -- only save valid payments to first data table
                IF (t_row.abispayment = 'Y')
                THEN
                    INSERT INTO bizmod_api.first_data_t fd(
                                    confirmationnumber,
                                    filename,
                                    logseq,
                                    paymentobjectid)
                         VALUES (t_row.confirmationnumber,
                                 t_filename,
                                 a_seq,
                                 t_paymentobjectid);

                    t_recordsloaded := t_recordsloaded + SQL%ROWCOUNT;
                    COMMIT;
                END IF;

                -- add payment row to the payment array
                t_fd.EXTEND(1);
                t_fd(t_fd.COUNT) := t_row;
            END LOOP;


            -- build the email and logging results of all processing data
            t_info :=
                t_info
                || CHR(13)
                || CHR(9)
                || 'Seq: '
                || CHR(9)
                || a_seq
                || CHR(13)
                || CHR(9)
                || 'File: '
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
                || t_recordsduplicate
                || CHR(13)
                || CHR(9)
                || 'Unable to Process: '
                || CHR(9)
                || t_errorrecords
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
                -- build information for email body and info logging
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
                    || TO_CHAR(t_total, 'fm9G999G999D00')
                    || CHR(13);
            END IF;

            IF (t_error_info IS NOT NULL)
            THEN
                -- add error information to be logged
                t_error_info :=
                    'Error Records:   (Error, License Number, Fee Activity(s), Payment Amount, Confirmation Number, Payee Name)'
                    || CHR(13)
                    || t_error_info;
                t_sqlerrm := t_error_info;
            END IF;

            -- if there were any AWF payments in the upload then call the create job process
            --  to schedule the job to Create AWF Payments
            IF (t_awf > 0)
            THEN
                bizmod_api.utl_licenseinfo.createjob(
                    a_procedure => 'CREATEAWFPAYMENTSJOB',
                    a_description =>
                        'Create AWF Payment Batch (File: '
                        || t_filename
                        || ')',
                    a_argument1 => a_seq);
            END IF;

            -- for all other payments call the Create Job Process to schedule the job
            --  to schedule the Create Transmittal process
            IF (t_other > 0)
            THEN
                bizmod_api.utl_licenseinfo.createjob(
                    a_procedure => 'CREATETRANSMITTALJOB',
                    a_description =>
                        'Create Transmittals (File: ' || t_filename || ')',
                    a_argument1 => a_seq);
            END IF;

            -- Create the JSON response that the settlement file was processedc
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

                -- log the oracle error
                UPDATE bizmod_api.eservices_log_t
                   SET err = t_msg, responsedate = SYSTIMESTAMP
                 WHERE seq = a_seq;

                COMMIT;

                -- Create the JSON response packet with the oracke error
                t_return :=
                    json_object(
                        'PACKET_TYPE' VALUE 'MESSAGE',
                        'DATA' VALUE
                            json_object('MSGNO' VALUE '5',
                                        'MSG' VALUE 'Oracle Exception',
                                        'EXCEPTION' VALUE t_msg));
        END;

        -- add the settlement file upload process to the process log.
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

        IF (t_sqlerrm IS NULL)
        THEN
            bizmod_api.utl_licenseinfo.sendemail(
                a_subject   =>
                    'First Data File Upload'
                    || CASE
                           WHEN t_sqlerrm IS NOT NULL
                             OR t_errorrecords > 0
                           THEN
                               ' has errors'
                           ELSE
                               NULL
                       END,
                a_body      => t_info);
        END IF;
    ELSE
        t_return :=
            json_object(
                'PACKET_TYPE' VALUE 'MESSAGE',
                'DATA' VALUE
                    json_object('MSGNO' VALUE '0',
                                'MSG' VALUE 'Duplicate File'));
    END IF;

    RETURN t_return;
END;
/
