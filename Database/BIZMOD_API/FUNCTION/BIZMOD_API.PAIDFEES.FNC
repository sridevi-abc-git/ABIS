CREATE OR REPLACE FUNCTION bizmod_api.paidfees(a_packet       IN CLOB,
                                               a_seq          IN NUMBER)
    RETURN CLOB
IS
    -- ****************************************************************************
    -- File:        PAIDFEES V3.FNC
    -- Author:      Timothy J. Lord
    --
    -- Purpose :
    --
    -- History:
    -------------------------------------------------------------------------------
    --    Date              Comment
    --  05/12/2021 TJL   Initial Package Created
    --  11/29/2022 TJL   Added filters to prevent duplicate payments being
    --                     added to payment table.
    --  12/09/2022 TJL   Added call to create a ABIS Payment Job
    -- ****************************************************************************
    t_payresult    payresult_tbl := payresult_tbl();
    t_packet       CLOB := EMPTY_CLOB();
    t_msg          VARCHAR2(4000);
    t_err_mesg     VARCHAR2(2000);
    t_licensenumber VARCHAR2(10);
    t_count        NUMBER := 0;
    t_first        BOOLEAN := TRUE;

    t_amountpaid   NUMBER;
BEGIN
    FOR paidfees
        IN (SELECT info.*,
                   LEAD(licensenumber, 1, '0') OVER (ORDER BY licensenumber)    AS nextlic
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
                                               PATH '$.AMOUNTPAID')))) info)
    LOOP
        t_count := 0;
        t_licensenumber := paidfees.licensenumber;

        BEGIN
            SELECT NVL(SUM(amountpaid), 0)
              INTO t_amountpaid
              FROM bizmod_api.e_payments_t p
             WHERE p.feeobjid = paidfees.feeobjid;

            -- check if duplicate payment
            CASE
                WHEN (t_amountpaid > 0
                  AND t_amountpaid >=
                        NVL(
                            api.pkg_columnquery.numericvalue(
                                paidfees.feeobjid,
                                'Amount'),
                            0)
                      + NVL(
                            api.pkg_columnquery.numericvalue(
                                paidfees.feeobjid,
                                'AdjustedAmount'),
                            0))
                THEN
                    -- add error message
                    t_payresult.EXTEND(1);
                    t_payresult(t_payresult.COUNT) :=
                        payresult_rec(paidfees.licensenumber,
                                      paidfees.licensetypecode,
                                      'N',
                                      'Duplicate Payment not Allowed');
                -- check to see if payment was already made
                WHEN NVL(
                         api.pkg_columnquery.numericvalue(paidfees.feeobjid,
                                                          'TotalOwing'),
                         1) <=
                     0
                THEN
                    -- add error message
                    t_payresult.EXTEND(1);
                    t_payresult(t_payresult.COUNT) :=
                        payresult_rec(paidfees.licensenumber,
                                      paidfees.licensetypecode,
                                      'N',
                                      'Fee Already Paid');
                ELSE
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
                                 (SELECT o.objectid
                                    FROM TABLE(
                                             CAST(
                                                 api.pkg_simplesearch.castableobjectsbyindex(
                                                     a_objectdefname =>
                                                         'j_LicenseType',
                                                     a_columnname =>
                                                         'dup_LicenseExternalFileNum',
                                                     a_value     =>
                                                         paidfees.licensenumber)
                                                     AS api.udt_objectlist))
                                         o
                                   WHERE api.pkg_columnquery.VALUE(
                                             o.objectid,
                                             'LicenseTypeCode') =
                                         paidfees.licensetypecode))
                            LOG ERRORS INTO bizmod_api.err$_e_payments_t
                                    ('INSERT')
                                    REJECT LIMIT UNLIMITED;

                    t_count := SQL%ROWCOUNT;

                    IF (t_count = 0)
                    THEN
                        SELECT e.ora_err_mesg$
                          INTO t_err_mesg
                          FROM bizmod_api.err$_e_payments_t e
                         WHERE e.feeobjid = paidfees.feeobjid
                           AND e.seq =
                               (SELECT MAX(seq)
                                  FROM bizmod_api.err$_e_payments_t e2
                                 WHERE e2.feeobjid = e.feeobjid);

                        t_payresult.EXTEND(1);
                        t_payresult(t_payresult.COUNT) :=
                            payresult_rec(paidfees.licensenumber,
                                          paidfees.licensetypecode,
                                          'N',
                                          t_err_mesg);
                    ELSE
                        t_payresult.EXTEND(1);
                        t_payresult(t_payresult.COUNT) :=
                            payresult_rec(paidfees.licensenumber,
                                          paidfees.licensetypecode,
                                          'Y',
                                          NULL);
                    END IF;
            END CASE;
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
        AND paidfees.licensenumber != paidfees.nextlic)
        THEN
            bizmod_api.createjob(
                a_procedure => 'E_PAYMENT.MAKEPAYMENT',
                a_description => 'Pay License Number: ' || t_licensenumber,
                a_argument1 => t_licensenumber);
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