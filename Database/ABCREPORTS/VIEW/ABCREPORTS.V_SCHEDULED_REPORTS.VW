CREATE OR REPLACE FORCE VIEW ABCREPORTS.V_SCHEDULED_REPORTS
(REPORT_NUMBER, REPORT_NAME, PROCESS, CYCLE_IND, BY_OFFICE_FLG, 
 DATA_FORMAT, FINALIZE_ID, REPORT_DAY)
BEQUEATH DEFINER
AS 
SELECT report_number,
           report_name,
           process,
           cycle_ind,
           by_office_flg,
           data_format,
           finalize_id,
           report_day
      FROM report_def
     WHERE report_day IS NOT NULL;
