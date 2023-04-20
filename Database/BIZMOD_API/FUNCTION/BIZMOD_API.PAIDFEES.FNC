CREATE OR REPLACE FUNCTION BIZMOD_API.paidfees(a_packet IN CLOB, a_seq IN NUMBER)
    RETURN CLOB
IS
    -- ****************************************************************************
    -- File:        PAIDFEES.FNC
    -- Author:      Timothy J. Lord
    --
    -- Purpose :
    --
    -- History:
    -------------------------------------------------------------------------------
    --    Date         Ticket     Comment
    --  05/12/2021 TJL           Initial Package Created
    -- ****************************************************************************
    t_packet          CLOB := EMPTY_CLOB();
    t_msg             VARCHAR2(4000);
    t_err_mesg        VARCHAR2(2000);
    t_licensenumber   VARCHAR2(10);
    t_count           NUMBER := 0;
    t_first           BOOLEAN := TRUE;
BEGIN
    t_packet   := '{"PACKET_TYPE":"PAYMENTRESULTS","DATA":[';

    FOR paidfees
        IN (SELECT *
              FROM JSON_TABLE(
                       a_packet, '$'
                       COLUMNS (packet_type VARCHAR2(1000) PATH '$.PACKET_TYPE',
                                NESTED PATH '$.DATA[*]'
                                    COLUMNS (licensenumber VARCHAR2(1000) PATH '$.LICENSENUMBER',
                                             paymentmethod VARCHAR2(50) PATH '$.PAYMENTMETHOD',
                                             confirmationid VARCHAR2(1000) PATH '$.CONFIRMATIONID',
                                             payeename VARCHAR2(4000) PATH '$.PAYEENAME', --Changed by Pawan on 1/4/2022 to prevent this error ORA-01400: cannot insert NULL into ("BIZMOD_API"."E_PAYMENTS_T"."PAYEENAME")
                                             datepaid VARCHAR2(100) PATH '$.DATEPAID',
                                             NESTED PATH '$.FEES[*]'
                                                 COLUMNS ("LINE" FOR ORDINALITY,
                                                          licensetypecode VARCHAR2(3) PATH '$.LICENSETYPECODE',
                                                          feeobjid NUMBER PATH '$.FEEOBJID',
                                                          description VARCHAR2(20) PATH '$.DESCRIPTION',
                                                          amountpaid NUMBER PATH '$.AMOUNTPAID')))))
    LOOP
        t_count   := 0;

        BEGIN
            -- setup response header information
            -- add license info to return packet
            IF (NOT t_first) THEN
                t_packet   :=
                       t_packet
                    || ',';
            END IF;

            t_first   := FALSE;
            t_packet   :=
                   t_packet
                || '{"LICENSENUMBER":"'
                || paidfees.licensenumber
                || '","LICENSETYPECODE":"'
                || paidfees.licensetypecode
                || '",';

            -- add payment record if money is still owning on a fee
            IF (api.pkg_columnquery.numericvalue(paidfees.feeobjid, 'TotalOwing') > 0
             OR paidfees.amountpaid > 0) THEN
                INSERT INTO  /*+ IGNORE_ROW_ON_DUPKEY_INDEX(e_payments_t, e_payments_t_pk) */
                            bizmod_api.e_payments_t(seq,
                                                    paymentmethod,
                                                    licensenumber,
                                                    licensetypecode,
                                                    feeobjid,
                                                    description,
                                                    payeename,
                                                    confirmationid,
                                                    datepaid,
                                                    amountpaid)
                         VALUES (
                                    a_seq,
                                    paidfees.paymentmethod,
                                    paidfees.licensenumber,
                                    paidfees.licensetypecode,
                                    paidfees.feeobjid,
                                    paidfees.description,
                                    paidfees.payeename,
                                    paidfees.confirmationid,
                                    CAST(
                                        FROM_TZ(TO_TIMESTAMP(paidfees.datepaid, 'YYYY-MM-DD"T"HH24:MI:SS"Z"'), 'UTC')
                                            AT TIME ZONE DBTIMEZONE AS DATE),  --
                                    --  to_date(paidfees.datepaid, 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
                                    paidfees.amountpaid)
                        LOG ERRORS INTO bizmod_api.err$_e_payments_t
                                ('INSERT')
                                REJECT LIMIT UNLIMITED;

                t_count   := SQL%ROWCOUNT;

                IF (t_count = 0) THEN
                    SELECT REGEXP_REPLACE(e.ora_err_mesg$, '[^[:print:]]', '')
                      INTO t_err_mesg
                      FROM bizmod_api.err$_e_payments_t e
                     WHERE e.feeobjid = paidfees.feeobjid
                       AND e.seq = (SELECT MAX(seq)
                                      FROM bizmod_api.err$_e_payments_t e2
                                     WHERE e2.feeobjid = e.feeobjid);

                    t_packet   :=
                           t_packet
                        || '"UPDATED":"N", "MSG":"'
                        || REGEXP_REPLACE(t_err_mesg, '"', ' ')
                        || '"}';
                ELSE
                    t_packet   :=
                           t_packet
                        || '"UPDATED":"Y"}';
                END IF;
            ELSE
                t_packet   :=
                       t_packet
                    || '"UPDATED":"N","MSG":"Payment Amount for Fee is Zero or Amount Owing for Fee is Zero"}';
            END IF;
        EXCEPTION
            WHEN OTHERS THEN
                t_msg   := SQLERRM;
                t_packet   :=
                       t_packet
                    || '"UPDATED":"N","MSG":"'
                    || REGEXP_REPLACE(REGEXP_REPLACE(t_msg, '[^[:print:]]', ''), '"', ' ')
                    || '"}';
        END;
    --        DBMS_OUTPUT.put_line(   'Packet Type: '
    --                             || paidfees.packet_type
    --                             || '   confirmationid: '
    --                             || paidfees.confirmationid
    --                             || '   License Number: '
    --                             || paidfees.licensenumber
    --                             || '   License Type Code: '
    --                             || paidfees.licensetypecode
    --                             || '   Fee Object Id: '
    --                             || paidfees.feeobjid
    --                             || '   Fee Activity: '
    --                             || paidfees.feeactivity
    --                             || '   Payee: '
    --                             || paidfees.payeename
    --                             || '   Amount Paid: '
    --                             || paidfees.amountpaid);
    END LOOP;

    t_packet   :=
           t_packet
        || ']}';

    COMMIT;

    RETURN t_packet;
END paidfees;
/
