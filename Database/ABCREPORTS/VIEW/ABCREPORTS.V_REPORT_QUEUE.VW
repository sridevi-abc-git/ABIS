CREATE OR REPLACE FORCE VIEW ABCREPORTS.V_REPORT_QUEUE
(REPORT_NUMBER, REPORT_DESC, PROCESS, CYCLE_IND, BY_OFFICE_FLG, 
 DATA_FORMAT, REPORT_PARAMETERS, JOB_ID, SEQ)
BEQUEATH DEFINER
AS 
SELECT d.report_number, 
       d.report_number, 
       d.process, 
       d.cycle_ind, 
       d.by_office_flg, 
       d.data_format, 
       q.report_parameters,
       x.job_id,
       seq 
  FROM report_def d
 INNER JOIN report_xref x
    ON (d.report_number = x.report_number)
 INNER JOIN report_queue q
 USING (seq)
 ORDER BY seq DESC;
