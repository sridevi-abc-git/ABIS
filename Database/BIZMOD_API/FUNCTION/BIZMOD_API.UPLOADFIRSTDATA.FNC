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
    --          09/13/2023 TJL  BIZ-        Initial File Created
    -- ****************************************************************************

    FUNCTION split_clob(
        a_clob         IN CLOB,
        a_delimiter    IN VARCHAR2 DEFAULT CHR(10) || CHR(13))
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
                                               '[^(' || a_delimiter || ')]+',
                                               1,
                                               LEVEL))    str
                                  FROM DUAL
                            CONNECT BY REGEXP_SUBSTR(
                                           REGEXP_REPLACE(t_tmp,
                                                          '([=()]+)',
                                                          ''),
                                           '[^(' || a_delimiter || ')]+',
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
                                               '[^(' || a_delimiter || ')]+',
                                               1,
                                               LEVEL))    str
                                  FROM DUAL
                            CONNECT BY REGEXP_SUBSTR(
                                           t_tmp,
                                           '[^(' || a_delimiter || ')]+',
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
BEGIN
    DECLARE
        t_headings     var_tbl;

        t_var          var_tbl;
        t_blob         BLOB
            := UTL_RAW.cast_to_raw(
                   'SiteID,SiteName,TransactionID,PaymentID,AppID,Transaction Result,Payment Result,Payment Timestamp,Payment Amount,Reference,RecurringID,RegistrationID,Processor,Paymt Attempt Amount,Paymt Processed Amount,Uses Conv. Fee,Full Name,First Name,Last Name,Account Number,Payment Medium,Account Type Code,CardType,Confirmation #,Payment Type,Payment Command,Payment Channel,Payment Status,Settlement BatchID,User ID,ACH Payment Type,ACH Return Code,Billing Street 1,Billing Street 2,Billing City,Billing State/Province,Billing Zip,Billing Country,Billing Phone,Billing Email,Settlement Reference Code,Post Date(EDT),Routing Number,Export Timestamp,'
                   || CHR(13)
                   || '30057,="State of California",="231012221",="250282380",31540,Settled,Settled,="10/26/2022 01:44:08 PM",$475.00,"=""629401, ""NAKED CHICKEN GROUP LLC""""",,,NFTF,$475.00,$475.00,Y,Mike Nguyen,,Naked Chicken Group LLC,1057,Business E-Check,Checking,,="22102665497567",Primary,SALE,Web,Settlement Complete,,ConsumerWeb,,,9901 Hageman Rd,ste 200,Bakersfield,CA,93312,,6287776162,naked.chicken@yahoo.com,="1400310000036204818875",="10/26/2022",="322271627",="10/27/2022 12:30:10 AM"');

        t_level        NUMBER := 0;
        t_row          e_payments_processed_t%ROWTYPE;
        t_return       CLOB;

        t_recordsprocessed NUMBER := 0;
        t_recordsloaded NUMBER := 0;
        t_errorrecords NUMBER := 0;
        t_msg          VARCHAR2(4000);
        t_sqlerrm      VARCHAR2(4000);
        t_trace        VARCHAR2(4000);
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
                REGEXP_REPLACE(t_headings(inx), '([ ./#]+)', '');
        --            dbms_output.put_line(t_headings(inx));
        END LOOP;

dbms_output.put_line(t_headings.count);

        FOR inx IN 2 .. t_var.COUNT
        LOOP
            FOR rec
                IN (    SELECT TRIM(
                                   REPLACE(
                                       TRIM(
                                           '"' FROM REGEXP_SUBSTR(
                                                        t_var(inx),
                                                        '(".*?"|.*?)(,|$)',
                                                        1,
                                                        LEVEL,
                                                        NULL,
                                                        1)),
                                       '"',
                                       ''))    split,
                               LEVEL,
                               ROWNUM          LN
                          FROM DUAL
                    CONNECT BY LEVEL <=
                                 LENGTH(
                                     REGEXP_REPLACE(t_var(inx),
                                                    '(".*?"|.*?)(,|$)'))
                               + 1)
            LOOP
                DBMS_OUTPUT.put_line(
                    t_headings(rec.LN)
                    || ' : '
                    || NVL(rec.split, 'null')
                    || ' : '
                    || rec.LN);

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
                        t_row.postdateedt := TO_DATE(rec.split, 'MM/DD/YYYY');
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

            INSERT INTO bizmod_api.e_payments_processed_t
                 VALUES t_row
                    LOG ERRORS INTO bizmod_api.err$_e_payments_processed_t
                            ('INSERT')
                            REJECT LIMIT UNLIMITED;

            IF (SQL%ROWCOUNT = 0)
            THEN
                t_errorrecords := t_errorrecords + 1;

                SELECT ora_err_mesg$
                  INTO t_return
                  FROM bizmod_api.err$_e_payments_processed_t e
                 WHERE ROWNUM = 1;

                DBMS_OUTPUT.put_line('error: ' || t_return);
            ELSE
                t_recordsloaded := t_recordsloaded + 1;
            END IF;

            COMMIT;
            t_recordsprocessed := t_recordsprocessed + 1;
        END LOOP;

        t_return :=
            json_object(
                'PACKET_TYPE' VALUE 'MESSAGE',
                'DATA' VALUE
                    json_object('MSGNO' VALUE '0',
                                'MSG' VALUE 'File Uploaded'));

        IF (t_recordsloaded > 0)
        THEN
            bizmod_api.createjob(a_procedure => 'PROCESSPAYMENTS',
                                 a_description => 'Process Payments');
        END IF;

        RETURN t_return;
    EXCEPTION
        WHEN OTHERS
        THEN
            t_sqlerrm := SQLERRM;
            t_trace := DBMS_UTILITY.format_error_backtrace;
            t_msg := SUBSTR(t_sqlerrm || ' :: ' || t_trace, 1, 3990);

            UPDATE eservices_log_t
               SET err = t_msg, responsedate = SYSTIMESTAMP
             WHERE seq = a_seq;

            COMMIT;

            RETURN json_object(
                       'PACKET_TYPE' VALUE 'MESSAGE',
                       'DATA' VALUE
                           json_object('MSGNO' VALUE '5',
                                       'MSG' VALUE 'Oracle Exception',
                                       'EXCEPTION' VALUE t_sqlerrm));
    END;
END;
/
