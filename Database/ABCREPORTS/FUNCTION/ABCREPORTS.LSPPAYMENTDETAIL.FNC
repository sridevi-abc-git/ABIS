CREATE OR REPLACE FUNCTION ABCREPORTS.lsppaymentdetail(p_parms IN OUT t_parameters, p_status_ind IN OUT VARCHAR2)
    RETURN BLOB
IS
    -- ****************************************************************************
    -- File:        lsppaymentdetail.fnc
    -- Author:      Timothy J. Lord
    --
    -- Description:
    --
    --
    -- History:
    -------------------------------------------------------------------------------
    --    Date                  Comment
    -- 10/15/2021 TJL  25843   File created
    -- ****************************************************************************
    lv_status_msg   VARCHAR2(8096);
    lblob_csv       BLOB;
    ld_start        DATE;
    ld_end          DATE;
BEGIN
    DBMS_LOB.createtemporary(lblob_csv, TRUE, DBMS_LOB.call);

    p_parms.upd_value('REPORT_DATE', TO_CHAR(SYSDATE, 'MM/DD/YYYY HH:MI PM'));

    FOR rec IN (  SELECT    '"'
                         || (SELECT DISTINCT TO_CHAR(p2.datepaid, 'MM/DD/YYYY HH24:MI:SS')
                               FROM bizmod_api.e_payments_t p2
                              WHERE p.confirmationid = p2.confirmationid
                                AND ROWNUM = 1)
                         || '","'
                         || p.licensenumber
                         || '","'
                         || (SELECT LISTAGG(p2.licensetypecode, ',') WITHIN GROUP (ORDER BY p2.licensetypecode)
                               FROM bizmod_api.e_payments_t p2
                              WHERE p2.confirmationid = p.confirmationid)
                         || '","'
                         || p.confirmationid
                         || '",'
                         || SUM(p.amountpaid)
                         || ',"'
                         || api.pkg_columnquery.VALUE(p.paymentobjectid, 'ReceiptNumber')
                         || '",'
                         || p.transmittalbatch
                         || ','
                         || p.depositbatchid
                         || CHR(13)
                         || CHR(10)
                             info
                    FROM bizmod_api.e_payments_t p
                   WHERE p.issued IS NULL
                GROUP BY licensenumber,
                         confirmationid,
                         p.paymentobjectid,
                         transmittalbatch,
                         depositbatchid
                ORDER BY 1)
    LOOP
        DBMS_LOB.append(lblob_csv, UTL_RAW.cast_to_raw(rec.info));
    END LOOP;

    COMMIT;

    RETURN lblob_csv;
EXCEPTION
    WHEN OTHERS THEN
        rqs_utils.LOG(p_log_type  => 'E',
                      p_job_id    => p_parms.get_value('JOB_ID'),
                      p_seq       => p_parms.get_value('SEQ'),
                      p_source    => 'LPSPAYMENTDETAIL',
                      p_msg       => SQLERRM,
                      p_additional_data => NULL,
                      p_error_trace => DBMS_UTILITY.format_error_backtrace);

        p_status_ind   := 'E';

        RETURN UTL_RAW.cast_to_raw(   'ERROR: '
                                   || SQLERRM
                                   || CHR(10)
                                   || CHR(13)
                                   || 'TRACE: '
                                   || DBMS_UTILITY.format_error_backtrace);
END lsppaymentdetail;
/
