CREATE OR REPLACE FORCE VIEW ABCREPORTS.V_REPORT_QUEUE_HISTORY
(REPORT_NUMBER, REPORT_NAME)
BEQUEATH DEFINER
AS 
SELECT d.report_number, 
       d.report_number
     
      FROM report_def d
 inner join report_xref x
    on (d.report_number = x.report_number)
 inner join report_queue_history q
    using (seq)
 order by seq desc;
