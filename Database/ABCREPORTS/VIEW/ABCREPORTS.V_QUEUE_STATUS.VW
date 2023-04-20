CREATE OR REPLACE FORCE VIEW ABCREPORTS.V_QUEUE_STATUS
(SEQ, JOB_ID, REPORT_NUMBER, REPORT_NAME, STEP_IND, 
 ORA_STATUS, WEB_STATUS, ELAPSE_TIME, RETRY_CNT, CANCEL_FLG, 
 UPDATE_DATE)
BEQUEATH DEFINER
AS 
SELECT seq,
           job_id,
           report_number,
           report_name,
           step_ind,
           ora_status,
           web_status,
           elapse_time,
           retry_cnt,
           cancel_flg,
           s.update_date
      FROM report_queue_status s
           LEFT OUTER JOIN report_xref x USING (seq)
           LEFT OUTER JOIN report_def d USING (report_number)
           LEFT OUTER JOIN report_queue_history h USING (seq)
    ORDER BY seq DESC;
