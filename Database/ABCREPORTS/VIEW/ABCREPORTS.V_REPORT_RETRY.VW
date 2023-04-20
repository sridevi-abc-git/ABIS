CREATE OR REPLACE FORCE VIEW ABCREPORTS.V_REPORT_RETRY
(REPORT_PARAMETERS, SEQ, JOB_ID)
BEQUEATH DEFINER
AS 
SELECT q.report_parameters, seq, x.job_id
  FROM  report_xref x
 INNER JOIN report_queue_status s
 USING (seq)
 INNER JOIN report_queue q
 USING (seq)
 WHERE s.step_ind = 'R'
 ORDER BY seq;
