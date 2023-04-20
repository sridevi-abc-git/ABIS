CREATE OR REPLACE FUNCTION ABCREPORTS.lsppayment(p_parms IN OUT t_parameters, p_status_ind IN OUT VARCHAR2)
    RETURN BLOB
IS
    -- ****************************************************************************
    -- File:        lsppayment.fnc
    -- Author:      Timothy J. Lord
    --
    -- Description:
    --
    --
    -- History:
    -------------------------------------------------------------------------------
    --    Date                  Comment
    -- 09/29/2021 TJL  25843   File created
    -- ****************************************************************************
    lv_status_msg   VARCHAR2(8096);
    lblob_csv       BLOB;
    ld_start        DATE;
    ld_end          DATE;
BEGIN
    DBMS_LOB.createtemporary(lblob_csv, TRUE, DBMS_LOB.call);

    ld_start   := TO_DATE(p_parms.get_value('START_DATE'), 'MM/DD/YYYY');
    ld_end     := TO_DATE(p_parms.get_value('END_DATE'), 'MM/DD/YYYY');
    p_parms.upd_value('REPORT_DATE', TO_CHAR(SYSDATE, 'MM/DD/YYYY HH:MI PM'));

    FOR rec IN (SELECT    '"'
                       || p.licensetypecode
                       || '","'
                       || p.licensenumber
                       || '","'
                       || p.confirmationid
                       || '","'
                       || api.pkg_columnquery.VALUE(p.paymentobjectid, 'ReceiptNumber')
                       || '","'
                       || TO_CHAR(p.datepaid, 'MM/DD/YYYY HH24:MI:SS')
                       || '",'
                       || p.amountpaid
                       || ',"'
                       || p.paymentmethod
                       || '"'
                       || CHR(13)
                       || CHR(10)
                           info
                  FROM bizmod_api.e_payments_t p
                 WHERE TRUNC(p.datepaid) BETWEEN ld_start AND ld_end
                 ORDER BY p.datepaid)
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
                      p_source    => 'LPSPAYMENT',
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
END lsppayment;
/
