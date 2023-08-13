CREATE OR REPLACE FUNCTION ABCREPORTS.awfpending(
    p_parms        IN OUT t_parameters,
    p_status_ind   IN OUT VARCHAR2)
    RETURN BLOB
IS
    /**************************************************************************
        File:   ABCREPORTS.AWFPENDING.FNC

        Description:
        
     History:
    -----------------------------------------------------------------------------
      Ver:       Date           Ticket        Comment
       1.0   08/11/2023 TJL  BIZ-12323   Initial Function Created
    **************************************************************************/
    lv_status_msg  VARCHAR2(8096);
    lblob_csv      BLOB;
    ld_start       DATE;
    ld_end         DATE;
BEGIN
    DBMS_LOB.createtemporary(lblob_csv, TRUE, DBMS_LOB.call);
    p_parms.upd_value('REPORT_DATE', TO_CHAR(SYSDATE, 'MM/DD/YYYY HH:MI PM'));

    FOR rec
        IN (  SELECT --distinct
                     CHR(34)
                     || p.paymentmethod
                     || CHR(34)
                     || CHR(44)
                     || CHR(34)
                     || a.licensenumber
                     || CHR(34)
                     || CHR(44)
                     || CHR(34)
                     || to_char(a.licensetypecode, '00')
                     || CHR(34)
                     || CHR(44)
                     || CHR(34)
                     || TO_CHAR(a.submitteddate, 'mm/dd/yyyy hh24:mi:ss')
                     || CHR(34)
                     || CHR(44)
                     || a.gallonage261
                     || CHR(44)
                     || a.feerequired
                     || CHR(44)
                     || a.renewalamountpaid
                     || CHR(44)
                     || a.awffeeamount
                     || CHR(44)
                     || p.amountpaid
                     || CHR(44)
                     || CHR(34)
                     || p.confirmationid
                     || CHR(34)
                     || CHR(44)
                     || CHR(34)
                     || CASE
                            WHEN a.awffeeamount = 0
                             AND NVL(completed, 'N') = 'Y'
                            THEN
                                'COMPLETED'
                            WHEN a.awffeeamount > 0
                             AND NVL(amountpaid, 0) > 0
                             AND NVL(completed, 'N') = 'Y'
                            THEN
                                'COMPLETED'
                            WHEN a.awffeeamount > 0
                             AND NVL(amountpaid, 0) > 0
                             AND NVL(completed, 'N') = 'N'
                            THEN
                                'PAID'
                            WHEN a.awffeeamount < 0
                             AND NVL(completed, 'N') = 'Y'
                            THEN
                                'COMPLETED'
                            WHEN a.awffeeamount < 0
                             AND NVL(completed, 'N') = 'N'
                            THEN
                                'REFUND PENDING'
                            ELSE
                                'PENDING'
                        END
                     || CHR(34)
                     || CHR(13)
                     || CHR(10)    info
                FROM bizmod_api.awf_t a
                     LEFT OUTER JOIN bizmod_api.e_payments_t p
                         ON (a.licensenumber = p.licensenumber
                         AND a.licensetypecode = p.licensetypecode
                         AND a.description = p.description)
               WHERE a.submitteddate IS NOT NULL
                 AND nvl(a.completed, 'N') != 'Y'
            ORDER BY CASE
                         WHEN a.awffeeamount = 0 THEN 1
                         WHEN a.awffeeamount > 0 THEN 2
                         ELSE 3
                     END,
                     a.submitteddate)
    LOOP
        DBMS_LOB.append(lblob_csv, UTL_RAW.cast_to_raw(rec.info));
    END LOOP;


    COMMIT;
    RETURN lblob_csv;
EXCEPTION
    WHEN OTHERS
    THEN
        rqs_utils.LOG(p_log_type  => 'E',
                      p_job_id    => p_parms.get_value('JOB_ID'),
                      p_seq       => p_parms.get_value('SEQ'),
                      p_source    => 'AWF Submitted Report',
                      p_msg       => SQLERRM,
                      p_additional_data => NULL,
                      p_error_trace => DBMS_UTILITY.format_error_backtrace);

        p_status_ind := 'E';

        RETURN UTL_RAW.cast_to_raw(
                   'ERROR: '
                   || SQLERRM
                   || CHR(10)
                   || CHR(13)
                   || 'TRACE: '
                   || DBMS_UTILITY.format_error_backtrace);
END;
/
