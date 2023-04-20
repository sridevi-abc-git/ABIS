CREATE OR REPLACE FORCE VIEW ABCREPORTS.V_REPORT_PENDING
(INDICATOR, JOB_ID, SEQ, REPORT_NUMBER, REPORT_NAME, 
 REPORT_PARAMETERS)
BEQUEATH DEFINER
AS 
SELECT  s.step_ind, x.job_id, seq, report_number, d.report_name, q.report_parameters
  FROM  report_xref x
 INNER JOIN report_queue_status s
 USING (seq)
 INNER JOIN report_queue q
 USING (seq)
 INNER JOIN report_def d
 USING (report_number)
 WHERE s.step_ind NOT IN ('E', 'C')
 ORDER BY seq DESC;
