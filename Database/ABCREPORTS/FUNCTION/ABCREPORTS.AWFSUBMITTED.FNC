CREATE OR REPLACE FUNCTION abcreports.awfsubmitted(
    p_parms        IN OUT t_parameters,
    p_status_ind   IN OUT VARCHAR2)
    RETURN BLOB
IS
    /**************************************************************************
        File:   ABCREPORTS.AWFSUBMITTED.FNC

        Description:

     History:
    -----------------------------------------------------------------------------
      Ver:       Date           Ticket        Comment
       1.0   08/04/2023 TJL  BIZ-12143   Initial Function Created
       1.0   08/11/2023 TJL  BIZ-12327   Added additional fields confirmation # and payment Type
       2.1   12/05/2024 TJL  BIZ-16612   Added a test for null payment when payment is manually made
       3.0.1 12/18/2025 TJL  BIZ-19829   Change how records are selected
    **************************************************************************/
    lblob_csv      BLOB;
    ld_start       DATE;
    ld_end         DATE;
BEGIN
    DBMS_LOB.createtemporary(lblob_csv, TRUE, DBMS_LOB.call);

    ld_start := TO_DATE(p_parms.get_value('START_DATE'), 'MM/DD/YYYY');
    ld_end := TO_DATE(p_parms.get_value('END_DATE'), 'MM/DD/YYYY');
    p_parms.upd_value('REPORT_DATE', TO_CHAR(SYSDATE, 'MM/DD/YYYY HH:MI PM'));

    FOR rec IN (SELECT CHR(34)
                       || CASE
                              WHEN a.awffeeamount > 0
                              THEN
                                  NVL(
                                      p.paymentmethod,
                                      api.pkg_columnquery.VALUE(
                                          a.paymentbatch,
                                          'PaymentType'))
                              ELSE
                                  NULL
                          END
                       || CHR(34)
                       || CHR(44)
                       || CHR(34)
                       || a.licensenumber
                       || CHR(34)
                       || CHR(44)
                       || CHR(34)
                       || TO_CHAR(a.licensetypecode, '00')
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
                       || NVL(p.amountpaid, -f.paidamount)
                       || CHR(44)
                       || CHR(34)
                       || NVL(
                              p.confirmationid,
                              (SELECT api.pkg_columnquery.VALUE(
                                          reo.objectid,
                                          'ConfirmationNumber') -- feeobjid
                                 FROM api.registeredexternalobjects reo
                                WHERE reo.objectdefid =
                                      api.pkg_configquery.objectdefidforname(
                                          'o_fee')
                                  AND reo.linkvalue = TO_CHAR(a.awffeeid) -- feeid
                                                                         ))
                       || CHR(34)
                       || CHR(44)
                       || CHR(34)
                       || CASE
                              WHEN NVL(a.completed, 'N') = 'Y'
                              THEN
                                  'COMPLETED'
                              WHEN a.awffeeamount > 0
                               AND NVL(p.amountpaid, 0) > 0
                              THEN
                                  'PAID'
                              WHEN a.awffeeamount < 0
                              THEN
                                  'REFUND PENDING'
                              ELSE
                                  'PENDING'
                          END
                       || CHR(34)
                       || CHR(13)
                       || CHR(10)    info
                  FROM bizmod_api.awf_t  a
                       LEFT OUTER JOIN bizmod_api.e_payments_t p
                           ON (p.description = 'AWF'
                           AND p.licensenumber = a.licensenumber
                           AND p.licensetypecode = a.licensetypecode
                           AND p.createddate >= a.submitteddate
                           AND p.seq =
                               (SELECT MAX(p1.seq)
                                  FROM bizmod_api.e_payments_t p1
                                 WHERE p1.description = 'AWF'
                                   AND p1.licensenumber = a.licensenumber
                                   AND p1.licensetypecode = a.licensetypecode
                                   AND p1.createddate >= a.submitteddate))
                       LEFT OUTER JOIN api.fees f ON (a.awffeeid = f.feeid)
                 WHERE a.submitteddate IS NOT NULL
                   AND TRUNC(a.submitteddate) BETWEEN ld_start AND ld_end)
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
