CREATE OR REPLACE FUNCTION BIZMOD_API.paidfees(a_packet       IN CLOB,
                                               a_seq          IN NUMBER)
    RETURN CLOB
IS
    -- ****************************************************************************
    -- File:        BIZMOD_API.PAIDFEES.FNC
    -- Author:      Timothy J. Lord
    --
    -- Purpose :
    --
    -- History:
    -------------------------------------------------------------------------------
    --    Date              Comment
    --        05/12/2021  TJL             Initial Package Created
    --        11/29/2022  TJL             Added filters to prevent duplicate payments being
    --                                      added to payment table.
    --        12/09/2022  TJL             Added call to create a ABIS Payment Job
    --        12/07/2023  TJL             Added commit before creating payment job
    --   3.1  02/26/2024  TJL  BIZ-14645  Added status filter to license type select
    --   4.0  04/24/2024  TJL  BIZ-15142  Added extra validation and enhance error logging
    --   4.1  05/13/2024  TJL  BIZ-15465  Corrected bug in AWF payment returning a message
    --                                      that fees already paid.
    --   5.0  08/08/2024  TJL  BIZ-16000  Change to new createjob procedure
    -- ****************************************************************************
    t_payresult    payresult_tbl := payresult_tbl();
    t_packet       CLOB := EMPTY_CLOB();
    t_msg          VARCHAR2(4000);
    t_err_mesg     VARCHAR2(2000);
    t_licensenumber VARCHAR2(40);
    t_count        NUMBER := 0;
    t_paidcount    NUMBER := 0;
    t_amountpaid   NUMBER;
    t_paid         VARCHAR2(1);
    t_payment      NUMBER;
BEGIN
    FOR paidfees
        IN (SELECT info.*,
                   p.seq,
                   p.paymentobjectid,
                   LEAD(info.confirmationid, 1, '0')
                       OVER (ORDER BY info.confirmationid)    AS nextlic
              FROM JSON_TABLE(
                       a_packet,
                       '$'
                       COLUMNS(
                           packet_type VARCHAR2(1000) PATH '$.PACKET_TYPE',
                           NESTED PATH '$.DATA[*]'
                               COLUMNS(
                                   licensenumber VARCHAR2(1000)
                                       PATH '$.LICENSENUMBER',
                                   paymentmethod VARCHAR2(50)
                                       PATH '$.PAYMENTMETHOD',
                                   confirmationid VARCHAR2(1000)
                                       PATH '$.CONFIRMATIONID',
                                   payeename VARCHAR2(4000)
                                       PATH '$.PAYEENAME',
                                   datepaid TIMESTAMP PATH '$.DATEPAID',
                                   NESTED PATH '$.FEES[*]'
                                       COLUMNS(
                                           "LINE" FOR ORDINALITY,
                                           licensetypecode VARCHAR2(3)
                                               PATH '$.LICENSETYPECODE',
                                           feeobjid NUMBER PATH '$.FEEOBJID',
                                           description VARCHAR2(20)
                                               PATH '$.DESCRIPTION',
                                           amountpaid NUMBER
                                               PATH '$.AMOUNTPAID')))) info
                   LEFT OUTER JOIN bizmod_api.e_payments_t p
                       ON (p.feeobjid = info.feeobjid))
    LOOP
        t_count := 0;
        t_licensenumber := paidfees.licensenumber;
        t_paid := 'N';      -- 05/13/2024 TJL BIZ-15465
        
        BEGIN
            -- check if entry already their (duplicate payment)
            IF (paidfees.seq IS NOT NULL)
            THEN
                -- add error message
                t_payresult.EXTEND(1);
                t_payresult(t_payresult.COUNT) :=
                    payresult_rec(paidfees.licensenumber,
                                  paidfees.licensetypecode,
                                  'N',
                                  'Duplicate Payment not Allowed');


                CONTINUE WHEN paidfees.paymentobjectid IS NOT NULL;
            END IF;

            IF (paidfees.feeobjid is not null)      -- 05/13/2024 TJL BIZ-15465
            then
            -- check if fee already paid
            t_paid :=
                CASE
                    WHEN (  NVL(
                                api.pkg_columnquery.numericvalue(
                                    paidfees.feeobjid,
                                    'paidamount'),
                                0)
                          + NVL(
                                api.pkg_columnquery.numericvalue(
                                    paidfees.feeobjid,
                                    'amount'),
                                0)
                          + NVL(
                                api.pkg_columnquery.numericvalue(
                                    paidfees.feeobjid,
                                    'adjustedamount'),
                                0) <=
                          0)
                    THEN
                        'Y'
                    ELSE
                        'N'
                END;
            END IF;
            
            IF (paidfees.seq IS NULL)
            THEN
                -- add payment record
                INSERT INTO /*+ IGNORE_ROW_ON_DUPKEY_INDEX(e_payments_t, e_payments_t_pk) */
                            bizmod_api.e_payments_t(seq,
                                                    paymentmethod,
                                                    licensenumber,
                                                    licensetypecode,
                                                    feeobjid,
                                                    description,
                                                    payeename,
                                                    confirmationid,
                                                    datepaid,
                                                    amountpaid,
                                                    paymentobjectid,
                                                    jobid)
                         VALUES (
                             a_seq,
                             paidfees.paymentmethod,
                             paidfees.licensenumber,
                             paidfees.licensetypecode,
                             paidfees.feeobjid,
                             paidfees.description,
                             paidfees.payeename,
                             paidfees.confirmationid,
                             paidfees.datepaid,
                             paidfees.amountpaid,
                             CASE t_paid WHEN 'Y' THEN 0 ELSE NULL END,
                             api.pkg_columnquery.numericvalue(
                                 paidfees.feeobjid,
                                 'JobId'))
                        LOG ERRORS INTO bizmod_api.err$_e_payments_t
                                ('INSERT')
                                REJECT LIMIT UNLIMITED;

                t_count := SQL%ROWCOUNT;

                IF (t_count = 0)
                THEN
                    SELECT e.ora_err_mesg$
                      INTO t_err_mesg
                      FROM bizmod_api.err$_e_payments_t e
                     WHERE (e.feeobjid = paidfees.feeobjid
                           or e.licensenumber = paidfees.licensenumber)
                       AND e.seq = (SELECT MAX(seq)
                                      FROM bizmod_api.err$_e_payments_t e2
                                     WHERE e2.feeobjid = e.feeobjid
                                        or e2.licensenumber = e.licensenumber);

                    t_payresult.EXTEND(1);
                    t_payresult(t_payresult.COUNT) :=
                        payresult_rec(paidfees.licensenumber,
                                      paidfees.licensetypecode,
                                      'N',
                                      t_err_mesg);
                ELSE
                    t_payresult.EXTEND(1);
                    t_payresult(t_payresult.COUNT) :=
                        payresult_rec(
                            paidfees.licensenumber,
                            paidfees.licensetypecode,
                            CASE t_paid WHEN 'Y' THEN 'N' ELSE 'Y' END,
                            CASE t_paid
                                WHEN 'Y' THEN 'Fee Already Paid'
                                ELSE NULL
                            END);
                    t_paidcount :=
                          t_paidcount
                        + CASE t_paid WHEN 'Y' THEN 0 ELSE t_count END;

                    IF (t_paid = 'Y')
                    THEN
                        -- payment object and confirmation number paid with
                        SELECT 'Fee already paid -'
                               || LISTAGG(
                                      ' Payment Object Id: '
                                      || reo.objectid
                                      || '  ConfirmationNumber: '
                                      || api.pkg_columnquery.VALUE(reo.objectid, 'PayeeReference'),
                                      ',')
                                  WITHIN GROUP (ORDER BY reo.objectid)
                          INTO t_msg
                          FROM api.feetransactions  ft
                               JOIN api.paymenttransactions pt
                                   ON (pt.transactionid = ft.transactionid)
                               JOIN api.registeredexternalobjects reo
                                   ON (reo.objectdefid =
                                       api.pkg_configquery.objectdefidforname(
                                           'o_Payment')
                                   AND reo.linkvalue = TO_CHAR(pt.paymentid))
                         WHERE ft.feeid =
                               api.pkg_columnquery.numericvalue(
                                   paidfees.feeobjid,
                                   'FeeId');

                        -- log payment info
                        INSERT INTO bizmod_api.err$_e_payments_t ep(
                                        ep.ora_err_mesg$,
                                        ep.seq,
                                        ep.confirmationid)
                             VALUES (t_msg, a_seq, paidfees.confirmationid);
                    END IF;
                END IF;
            END IF;
        EXCEPTION
            WHEN OTHERS
            THEN
                t_msg :=
                    SQLERRM
                    || CHR(13)
                    || CHR(10)
                    || DBMS_UTILITY.format_error_backtrace;

                t_payresult.EXTEND(1);
                t_payresult(t_payresult.COUNT) :=
                    payresult_rec(paidfees.licensenumber,
                                  paidfees.licensetypecode,
                                  'N',
                                  t_msg);
        END;

        IF (paidfees.feeobjid IS NOT NULL
        AND t_paidcount > 0
        AND paidfees.confirmationid != paidfees.nextlic)
        THEN
            COMMIT;

            bizmod_api.utl_licenseinfo.createjob(
                a_procedure => 'E_PAYMENT.MAKEPAYMENT',
                a_description =>
                    'Pay License Number: '
                    || paidfees.licensenumber
                    || 'Confirmation Number: '
                    || paidfees.confirmationid,
                a_argument1 => paidfees.confirmationid);

            t_paidcount := 0;
        END IF;
    END LOOP;

    SELECT json_object(
               'PACKET_TYPE' VALUE 'PAYMENTRESULTS',
               'DATA' VALUE
                   json_arrayagg(
                       json_object('LICENSENUMBER' VALUE r.licensenumber,
                                   'LICENSETYPECODE' VALUE r.licensetypecode,
                                   'UPDATED' VALUE r.updated,
                                   'MSG' VALUE r.msg)
                       ABSENT ON NULL))
      INTO t_packet
      FROM TABLE(t_payresult) r;

    COMMIT;

    RETURN t_packet;
END paidfees;
/
