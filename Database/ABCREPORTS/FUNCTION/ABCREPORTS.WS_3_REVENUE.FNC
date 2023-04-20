CREATE OR REPLACE FUNCTION ABCREPORTS.ws_3_revenue(
    p_parms        IN OUT t_parameters,
    p_status_ind   IN OUT VARCHAR2)
    RETURN BLOB
IS
    -- ****************************************************************************
    -- File:        WS_3_REVENUE.FNC
    -- Author:      Timothy J. Lord
    --
    -- Description:
    --
    --
    -- History:
    -------------------------------------------------------------------------------
    --    Date                  Comment
    --  09/13/2022  TJL   - Function created
    -- ****************************************************************************

    FUNCTION get_data(p_value        IN OUT CLOB,
                      p_start_date   IN     DATE,
                      p_end_date     IN     DATE,
                      p_status_msg   IN OUT VARCHAR2)
        RETURN BOOLEAN
    IS
        LN             NUMBER;
    BEGIN
        abcreports.f_utils.get_revenue(p_start_date, p_end_date);

        FOR rec
            IN (SELECT d.item,
                      TRIM(
                           TO_CHAR(
                               d.amount,
                               CASE ROWNUM
                                   WHEN 11 THEN '999,990'
                                   ELSE '$999,999,990'
                               END))    amount
                  FROM (SELECT *
                          FROM (SELECT ROUND(renewalsannuals)
                                           renewalsannuals,
                                       originalfees,
                                       transfer,
                                       dailylicenses,
                                       cateventpermits,
                                       cateventauth,
                                       ROUND(
                                             gt
                                           - (  renewalsannuals
                                              + originalfees
                                              + transfer
                                              + dailylicenses
                                              + cateventpermits
                                              + cateventauth
                                              + poicaccepted)
                                           + poicaccepted)
                                           other,
                                       ROUND(gt)
                                           total,
                                       dm,
                                       ROUND(poicaccepted)
                                           poicaccepted,
                                       poiccount
                                  FROM ( -- ***** Renewals *****************************************
                                        SELECT (SELECT -NVL(
                                                            (  SUM(
                                                                   fd.earnedamount)
                                                             - SUM(
                                                                   fd.ab_surcharge)
                                                             - SUM(
                                                                   fd.dmv_surcharge_amt)
                                                             - SUM(
                                                                   fd.bpu_fee)
                                                             + SUM(
                                                                   fd.penalties)),
                                                            0)
                                                  FROM abcreports.f_transactions
                                                       f
                                                       JOIN
                                                       abcreports.f_transactions_rpt
                                                       fd
                                                           ON f.transactionid =
                                                              fd.feeid
                                                 WHERE fd.earnedamount < 0
                                                   AND fd.servicechargeamount =
                                                       0
                                                   AND ((fd.feeactivity IN
                                                             ('REN',
                                                              'REN50',
                                                              'REN100')
                                                     AND f.feelicensetypecode NOT IN
                                                             ('26',
                                                              '28',
                                                              '29',
                                                              '58',
                                                              '77'))
                                                     OR (fd.feeactivity IN
                                                             ('ANN')
                                                     AND f.feelicensetypecode NOT IN
                                                             ('26', '28'))
                                                     OR (fd.feeactivity IN
                                                             ('AWF'))
                                                     OR (fd.feeactivity IN
                                                             ('DOR')
                                                     AND f.feelicensetypecode NOT IN
                                                             ('06', -- 03/23/2021 TJL 21921 removed selected license types
                                                              '58',
                                                              '66',
                                                              '67',
                                                              '77')))
                                                   AND fd.objectdefname NOT IN
                                                           ('j_MiscellaneousFee'))
                                                   renewalsannuals,
                                               -- ***** Originals *****************************************
                                               (WITH
                                                    fd
                                                    AS
                                                        (SELECT api.pkg_columnquery.VALUE(
                                                                    f.jobid,
                                                                    'PrimaryLicenseTypeCodes')
                                                                    primarylicensetypecodes,
                                                                fd.*
                                                           FROM abcreports.f_transactions
                                                                f
                                                                JOIN
                                                                abcreports.f_transactions_rpt
                                                                fd
                                                                    ON f.transactionid =
                                                                       fd.feeid
                                                          WHERE fd.earnedamount <
                                                                0
                                                            AND fd.servicechargeamount =
                                                                0
                                                            AND (fd.feeactivity IN
                                                                     ('APP',
                                                                      'ORI')
                                                             AND fd.objectdefname NOT IN
                                                                     ('j_MiscellaneousFee')))
                                                SELECT -NVL(
                                                            (  SUM(
                                                                   fd.earnedamount)
                                                             - SUM(
                                                                   fd.ab_surcharge)
                                                             - SUM(
                                                                   fd.dmv_surcharge_amt)
                                                             - SUM(
                                                                   fd.bpu_fee)),
                                                            0)
                                                  FROM fd fd
                                                 WHERE LENGTH(
                                                           primarylicensetypecodes) >
                                                       2
                                                    OR (INSTR(
                                                            primarylicensetypecodes,
                                                            '26') =
                                                        0
                                                    AND INSTR(
                                                            primarylicensetypecodes,
                                                            '28') =
                                                        0))
                                                   originalfees,
                                               -- ***** Transfers *****************************************
                                               (SELECT -NVL(
                                                            (  SUM(
                                                                   fd.earnedamount)
                                                             - SUM(
                                                                   fd.ab_surcharge)
                                                             - SUM(
                                                                   fd.dmv_surcharge_amt)
                                                             - SUM(
                                                                   fd.bpu_fee)),
                                                            0)
                                                  FROM abcreports.f_transactions
                                                       f
                                                       JOIN
                                                       abcreports.f_transactions_rpt
                                                       fd
                                                           ON f.transactionid =
                                                              fd.feeid
                                                 WHERE fd.earnedamount < 0
                                                   AND fd.servicechargeamount =
                                                       0
                                                   AND fd.feeactivity IN
                                                           ('CD8',
                                                            'DPR',
                                                            'FID',
                                                            'EXC',
                                                            'ICO',
                                                            'MBM',
                                                            'MBR',
                                                            'PER',
                                                            'PRM',
                                                            'STK',
                                                            'STM',
                                                            'PERRFT',
                                                            'PREMPREM',
                                                            'PRMFID',
                                                            'PRMMBR',
                                                            'PRMMBM',
                                                            'PRMRFT',
                                                            'PRMPER',
                                                            'PRMSTK',
                                                            'PRMSTM',
                                                            'UMBR',
                                                            'UMBM',
                                                            'USTK',
                                                            'USTM')
                                                   AND fd.objectdefname NOT IN
                                                           ('j_MiscellaneousFee'))
                                                   transfer,
                                               -- ***** Daily *****************************************

                                               (SELECT -NVL(
                                                            (  SUM(
                                                                   fd.earnedamount)
                                                             - SUM(
                                                                   fd.ab_surcharge)
                                                             - SUM(
                                                                   fd.dmv_surcharge_amt)
                                                             - SUM(
                                                                   fd.bpu_fee)),
                                                            0)
                                                  FROM abcreports.f_transactions
                                                       f
                                                       JOIN
                                                       abcreports.f_transactions_rpt
                                                       fd
                                                           ON f.transactionid =
                                                              fd.feeid
                                                 WHERE fd.earnedamount < 0
                                                   AND fd.servicechargeamount =
                                                       0
                                                   AND fd.feeactivity IN
                                                           ('ODL',
                                                            'SPD',
                                                            'TST',
                                                            'SDV')
                                                   AND fd.objectdefname NOT IN
                                                           ('j_MiscellaneousFee'))
                                                   dailylicenses,
                                               -- ***** cater Permits *****************************************
                                               (WITH
                                                    fd
                                                    AS
                                                        (SELECT api.pkg_columnquery.VALUE(
                                                                    f.jobid,
                                                                    'PrimaryLicenseTypeCodes')
                                                                    primarylicensetypecodes,
                                                                fd.*,
                                                                f.feelicensetypecode
                                                           FROM abcreports.f_transactions
                                                                f
                                                                JOIN
                                                                abcreports.f_transactions_rpt
                                                                fd
                                                                    ON f.transactionid =
                                                                       fd.feeid
                                                          WHERE fd.earnedamount <
                                                                0
                                                            AND fd.servicechargeamount =
                                                                0
                                                            AND f.feelicensetypecode IN
                                                                    ('58',
                                                                     '77')
                                                            AND (fd.feeactivity IN
                                                                     ('REN',
                                                                      'REN50',
                                                                      'REN100',
                                                                      'DOR')
                                                             AND fd.objectdefname NOT IN
                                                                     ('j_MiscellaneousFee')))
                                                SELECT -NVL(
                                                            (  SUM(
                                                                   fd.earnedamount)
                                                             - SUM(
                                                                   fd.ab_surcharge)
                                                             - SUM(
                                                                   fd.dmv_surcharge_amt)
                                                             - SUM(
                                                                   fd.bpu_fee)),
                                                            0)
                                                  FROM fd fd
                                                 WHERE (fd.feelicensetypecode =
                                                        '58'
                                                    AND (INSTR(
                                                             primarylicensetypecodes,
                                                             '50') =
                                                         0
                                                     AND INSTR(
                                                             primarylicensetypecodes,
                                                             '51') =
                                                         0
                                                     AND INSTR(
                                                             primarylicensetypecodes,
                                                             '52') =
                                                         0))
                                                    OR fd.feelicensetypecode =
                                                       '77')
                                                   cateventpermits,
                                               -- ***** Cater Auth *****************************************
                                               (SELECT -NVL(
                                                            (  SUM(
                                                                   fd.earnedamount)
                                                             - SUM(
                                                                   fd.ab_surcharge)
                                                             - SUM(
                                                                   fd.dmv_surcharge_amt)
                                                             - SUM(
                                                                   fd.bpu_fee)),
                                                            0)
                                                  FROM abcreports.f_transactions
                                                       f
                                                       JOIN
                                                       abcreports.f_transactions_rpt
                                                       fd
                                                           ON f.transactionid =
                                                              fd.feeid
                                                 WHERE fd.earnedamount < 0
                                                   AND fd.servicechargeamount =
                                                       0
                                                   AND fd.feeactivity IN
                                                           ('CATA', 'EPA')
                                                   AND fd.objectdefname NOT IN
                                                           ('j_MiscellaneousFee'))
                                                   cateventauth,
                                               -- ***** Grand Total *****************************************
                                               (SELECT -NVL(
                                                            (  SUM(
                                                                   fd.earnedamount)
                                                             - SUM(
                                                                   fd.ab_surcharge)
                                                             - SUM(
                                                                   fd.dmv_surcharge_amt)
                                                             - SUM(
                                                                   fd.bpu_fee)),
                                                            0)
                                                  FROM abcreports.f_transactions
                                                       f
                                                       JOIN
                                                       abcreports.f_transactions_rpt
                                                       fd
                                                           ON f.transactionid =
                                                              fd.feeid
                                                 WHERE fd.earnedamount < 0
                                                   AND fd.feeactivity NOT IN
                                                           ('POIC')
                                                   AND fd.objectdefname NOT IN
                                                           ('j_MiscellaneousFee'))
                                                   gt,
                                               NULL
                                                   dm,
                                               -- ***** POIC Count *****************************************
                                               (SELECT COUNT(fd.feeid)
                                                  FROM abcreports.f_transactions
                                                       f
                                                       JOIN
                                                       abcreports.f_transactions_rpt
                                                       fd
                                                           ON f.transactionid =
                                                              fd.feeid
                                                 WHERE fd.earnedamount < 0
                                                   AND fd.servicechargeamount =
                                                       0
                                                   AND fd.feeactivity IN
                                                           ('POIC')
                                                   AND fd.objectdefname NOT IN
                                                           ('j_MiscellaneousFee'))
                                                   poiccount,
                                               -- ***** POID Amount *****************************************
                                               (SELECT -NVL(
                                                            (  SUM(
                                                                   fd.earnedamount)
                                                             - SUM(
                                                                   fd.ab_surcharge)
                                                             - SUM(
                                                                   fd.dmv_surcharge_amt)
                                                             - SUM(
                                                                   fd.bpu_fee)),
                                                            0)    adjustedamount
                                                  FROM abcreports.f_transactions
                                                       f
                                                       JOIN
                                                       abcreports.f_transactions_rpt
                                                       fd
                                                           ON f.transactionid =
                                                              fd.feeid
                                                 WHERE fd.earnedamount < 0
                                                   AND fd.servicechargeamount =
                                                       0
                                                   AND fd.feeactivity IN
                                                           ('POIC')
                                                   AND fd.objectdefname NOT IN
                                                           ('j_MiscellaneousFee'))
                                                   poicaccepted
                                          FROM DUAL      -- end of new section
                                                   -- ****************************************************
                                                   )) d
                               UNPIVOT INCLUDE NULLS (amount
                                                     FOR item
                                                     IN (renewalsannuals AS 'Renewals',
                                                        originalfees AS '"Original" & chr(10) & " Fees',
                                                        transfer AS 'Transfers ',
                                                        dailylicenses AS 'Daily Licenses',
                                                        cateventpermits AS 'Catering Permits',
                                                        cateventauth AS 'Caterer''s Authorization',
                                                        other AS 'Other',
                                                        total AS 'Total Licensing Revenue',
                                                        dm AS 'Offers in Compromise Accepted:',
                                                        poicaccepted AS 'Amount',
                                                        poiccount AS 'Number')))
                       d)
        LOOP
            DBMS_LOB.append(
                p_value,
                '"","'
                || rec.item
                || '","'
                || rec.amount
                || '"'
                || CHR(13)
                || CHR(10));
        END LOOP;



        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_status_msg :=
                'ws_3_revenue.get_data: '
                || DBMS_UTILITY.format_error_backtrace
                || ' :: '
                || SQLERRM;

            RETURN FALSE;
    END;
--*****************************************************************************
--*****************************************************************************
--      Main Process
--*****************************************************************************
--*****************************************************************************


BEGIN
    DECLARE
        blob_          BLOB;
        lc_csv         CLOB;
        ld_start_date  DATE;
        ld_end_date    DATE;
        lv_status_msg  VARCHAR2(4000);
        lb_proc        BOOLEAN := TRUE;
    BEGIN
        DBMS_LOB.createtemporary(lob_loc     => lc_csv,
                                 cache       => TRUE,
                                 dur         => DBMS_LOB.session);

        IF (p_parms.get_value('START_DATE') IS NOT NULL)
        THEN
            ld_start_date :=
                TRUNC(TO_DATE(p_parms.get_value('START_DATE'), 'MM/DD/YYYY'));
            ld_end_date :=
                  TO_DATE(p_parms.get_value('END_DATE'), 'MM/DD/YYYY')
                + (1 - 1 / (24 * 60 * 60));
        ELSE
            lb_proc := FALSE;
            lv_status_msg := 'No report date found';
        END IF;

        p_parms.upd_value('REPORT_DATE',
                          TO_CHAR(SYSDATE, 'MM/DD/YYYY HH:MI PM'));

        lb_proc := (lv_status_msg IS NULL);

        lb_proc :=
            get_data(lc_csv,
                     ld_start_date,
                     ld_end_date,
                     lv_status_msg);

        IF (lb_proc)
        THEN
            p_status_ind := 'F';
            blob_ := rqs_utils.clob2blob(lc_csv);
        ELSE
            p_status_ind := 'E';
            blob_ := UTL_RAW.cast_to_raw(lv_status_msg);

            rqs_utils.LOG(p_log_type  => 'E',
                          p_job_id    => p_parms.get_value('JOB_ID'),
                          p_seq       => p_parms.get_value('SEQ'),
                          p_source    => 'Workload Summary Revenue Report',
                          p_msg       => lv_status_msg);
        END IF;

        RETURN blob_;
    EXCEPTION
        WHEN OTHERS
        THEN
            rqs_utils.LOG(
                p_log_type  => 'E',
                p_job_id    => p_parms.get_value('JOB_ID'),
                p_seq       => p_parms.get_value('SEQ'),
                p_source    => 'ws_3_revenue',
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
END;
/
