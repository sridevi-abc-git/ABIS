CREATE OR REPLACE FUNCTION ABCREPORTS.miscfees(p_parms IN OUT t_parameters, p_status_ind IN OUT VARCHAR2)
    RETURN BLOB
IS
    -- ****************************************************************************
    -- File:        miscfees.FNC
    -- Author:      Timothy J. Lord
    --
    -- Description:
    --
    --
    -- History:
    -------------------------------------------------------------------------------
    --    Date                  Comment
    -- 02/16/2021 TJL 24000  Initial file create
    -- ****************************************************************************
    lv_status_msg   VARCHAR2(8096);
    lblob_csv       BLOB;
    ld_start        DATE;
    ld_end          DATE;
    lv_csv_row      VARCHAR2(8096);
BEGIN
    DBMS_LOB.createtemporary(lblob_csv, TRUE, DBMS_LOB.call);

    ld_start   := TO_DATE(p_parms.get_value('START_DATE'), 'MM/DD/YYYY');
    ld_end     := TO_DATE(p_parms.get_value('END_DATE'), 'MM/DD/YYYY');
    p_parms.upd_value('REPORT_DATE', TO_CHAR(SYSDATE, 'MM/DD/YYYY HH:MI PM'));

    abcreports.f_utils.get_revenue(ld_start, ld_end);

    FOR rec
        IN (SELECT x.*
              FROM (SELECT cntrbscc,
                           cntrbsfp,
                           cntmiscfees,
                           rbscc,
                           rbsfp,
                           miscfees,
                           m.cntrbscc + m.cntrbsfp + m.cntmiscfees ttlcnt,
                           m.rbscc + m.rbsfp + m.miscfees          ttl
                      FROM (SELECT COUNT(CASE
                                             WHEN a.miscfee = 'Y'
                                              AND a.feeactivity = 'RBSCC' THEN
                                                 1
                                             ELSE
                                                 NULL
                                         END)
                                       cntrbscc,
                                   SUM(CASE
                                           WHEN a.miscfee = 'Y'
                                            AND a.feeactivity = 'RBSCC' THEN
                                               earnedamount
                                           ELSE
                                               0
                                       END)
                                       rbscc,
                                   COUNT(CASE
                                             WHEN a.miscfee = 'Y'
                                              AND a.feeactivity IN ('RBSSFP', 'RBSFFP') THEN
                                                 1
                                             ELSE
                                                 NULL
                                         END)
                                       cntrbsfp,
                                   SUM(CASE
                                           WHEN a.miscfee = 'Y'
                                            AND a.feeactivity IN ('RBSSFP', 'RBSFFP') THEN
                                               earnedamount
                                           ELSE
                                               0
                                       END)
                                       rbsfp,
                                   COUNT(CASE
                                             WHEN a.miscfee = 'Y'
                                              AND a.feeactivity NOT IN ('RBSCC', 'RBSSFP', 'RBSFFP') THEN
                                                 1
                                             ELSE
                                                 NULL
                                         END)
                                       cntmiscfees,
                                   SUM(CASE
                                           WHEN a.miscfee = 'Y'
                                            AND a.feeactivity NOT IN ('RBSCC', 'RBSSFP', 'RBSFFP') THEN
                                               earnedamount
                                           ELSE
                                               0
                                       END)
                                       miscfees
                              FROM abcreports.f_transactions_rpt a
                             WHERE a.earnedamount != 0) m)
                   UNPIVOT
                       ((cnt, amount)
                       FOR item
                       IN ((cntrbscc, rbscc) AS 'RBS FEES',
                          (cntrbsfp, rbsfp) AS 'RBS FINGERPRINT FEES',
                          (cntmiscfees, miscfees) AS 'OTHER MISC FEES',
                          (ttlcnt, ttl) AS 'TOTAL')) x)
    LOOP
        lv_csv_row   :=
               '"'
            || rec.item
            || '",'
            || rec.cnt
            || ','
            || rec.amount
            || ','
            || CHR(13)
            || CHR(10);

        DBMS_LOB.append(lblob_csv, UTL_RAW.cast_to_raw(lv_csv_row));
    END LOOP;

    COMMIT;

    RETURN lblob_csv;
EXCEPTION
    WHEN OTHERS THEN
        rqs_utils.LOG(p_log_type  => 'E',
                      p_job_id    => p_parms.get_value('JOB_ID'),
                      p_seq       => p_parms.get_value('SEQ'),
                      p_source    => 'MISCFEES',
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
END miscfees;
/
