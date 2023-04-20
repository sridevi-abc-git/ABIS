CREATE OR REPLACE FORCE VIEW ABCREPORTS.V_REPORTS_DEFS
(REPORT_NUMBER, REPORT_NAME, PROCESS, CYCLE_IND, BY_OFFICE_FLG, 
 DATA_FORMAT, FINALIZE_ID)
BEQUEATH DEFINER
AS 
SELECT report_number,
           report_name,
           process,
           cycle_ind,
           by_office_flg,
           data_format,
           finalize_id
      FROM report_def
    ORDER BY report_number;
