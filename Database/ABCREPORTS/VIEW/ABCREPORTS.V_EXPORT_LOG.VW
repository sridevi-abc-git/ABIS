CREATE OR REPLACE FORCE VIEW ABCREPORTS.V_EXPORT_LOG
(SEQ, REPORT_NUMBER, REPORT_NAME, URL, EXPORT_ID, 
 STATUS_IND, RESPONSE, ERROR_MSG, EXPORT_DATE)
BEQUEATH DEFINER
AS 
SELECT seq,
           report_number,
           report_name,
           url,
           export_id,
           status_ind,
           response,
           error_msg,
           export_date
      FROM report_export_log
           JOIN report_xref x USING (seq)
           JOIN report_def d USING (report_number)
    ORDER BY seq DESC;
