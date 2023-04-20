CREATE OR REPLACE FORCE VIEW ABCREPORTS.V_ERRORS
(LOG_SEQ, JOB_ID, SEQ, REPORT_NUMBER, REPORT_NAME, 
 LOG_TYPE_IND, SRC, MSG, ERROR_TRACE, ADDITIONAL_DATA, 
 CREATED_BY, CREATE_DATE)
BEQUEATH DEFINER
AS 
SELECT log_seq,
           e.job_id,
           seq,
           report_number,
           report_name,
           log_type_ind,
           src,
           msg,
           error_trace,
           additional_data,
           e.created_by,
           e.create_date
      FROM report_error_log e
      LEFT OUTER JOIN report_xref x
     USING (seq) 
      LEFT OUTER JOIN report_def d
     USING (report_number)
     WHERE UPPER(log_type_ind) = 'E'
     ORDER BY log_seq DESC;
