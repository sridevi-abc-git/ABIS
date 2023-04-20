CREATE OR REPLACE FORCE VIEW ABCREPORTS.V_REPORT_STATUS
(JOB_ID, REPORT_NUMBER, SEQ, STEP_IND, ORA_STATUS, 
 WEB_STATUS, RETRY_CNT, UPDATE_DATE, CANCEL_FLG, MSG, 
 ERROR_TRACE, ADDITIONAL_DATA)
BEQUEATH DEFINER
AS 
SELECT x.job_id,
       report_number,
       seq, 
       step_ind, 
       ora_status, 
       web_status, 
       retry_cnt, 
       update_date, 
       cancel_flg,
       msg,
       error_trace,
       additional_data
  FROM report_queue_status
 INNER JOIN report_xref x
 USING (seq)
  LEFT OUTER JOIN report_error_log
 USING (seq)
 WHERE log_type_ind = 'E' 
    OR log_type_ind IS NULL
 ORDER BY seq DESC;
