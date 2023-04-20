CREATE OR REPLACE FUNCTION ABCREPORTS.ModifiedFeeReport(p_parms      IN OUT t_parameters,
                                             p_status_ind IN OUT VARCHAR2) 
              RETURN BLOB IS
-- ****************************************************************************
-- File:        ModifiedFeeReport.fnc  
-- Author:      Timothy J. Lord
--
-- $Rev: 3044 $  
-- $Date: 2016-09-27 15:06:25 -0700 (Tue, 27 Sep 2016) $
-- Last Changed By:  $Author: tlord $
--
-- Description:      
--
-- Parameters: 
--
-- History:
-------------------------------------------------------------------------------
--    Date         Ticket     Comment
-- 06/24/2015 TJL   7265    Original file created
-- 04/14/2016 TJL   9440    Add sort order to report
-- 09/27/2016 TJL   7213    Changed output from CLOB to BLOB  
-- ****************************************************************************

    lblob               BLOB;
    lxml                XMLTYPE;
    lv_report_heading   VARCHAR2(200);
    
    BEGIN 
        SELECT report_name
          INTO lv_report_heading
          FROM report_def
         WHERE report_number = TO_NUMBER(p_parms.get_value('REPORT_NUMBER'));

        SELECT XMLELEMENT("ROOT",
                                xmlattributes(TO_CHAR(SYSDATE, 'MM/DD/YYYY HH:MI AM') AS "REPORT_TAKEN",
                                              NVL(lv_report_heading,'unknown') AS "REPORT_NAME",
                                              p_parms.get_value('START_DATE') AS "REPORT_START_DATE",
                                              p_parms.get_value('END_DATE') AS "REPORT_END_DATE"),
              (SELECT DISTINCT
                    XMLAGG(XMLELEMENT
                            ("DATA",
                                XMLFOREST
                                    (
                                    externalfilenum,
                                    description,
                                    jobstatus,
                                    outcome,
                                    TO_CHAR(process_created_date, 'MM/DD/YYYY') process_created_date,
                                    process_created_by,
                                    transactioncode,
                                    amount
                                    )
                            )
                          )
                 FROM
        (SELECT j.externalfilenum,
                j.description,
                j.jobstatus,
                p.outcome,
                p.createddate process_created_date,
                p.createdby process_created_by,
                o.description transactioncode,
                tx.amount
           FROM api.jobs j
           JOIN api.processes p ON p.jobid = j.jobid
           JOIN api.feetransactions tx ON tx.logicaltransactionid = p.logicaltransactionid
           JOIN query.r_modifyfeefeeschedule r ON r.modifyfeeprocessid = p.processid
           JOIN query.o_feeschedule o ON o.objectid = r.feescheduleobjectid
          WHERE processtypeid IN ( 301005)  -- Modify Fee, (Modify Payment 395461)
            AND TRUNC(p.createddate) BETWEEN TO_DATE(p_parms.get_value('START_DATE'), 'MM/DD/YYYY')
                                         AND TO_DATE(p_parms.get_value('END_DATE'), 'MM/DD/YYYY')
          ORDER BY TRUNC(p.createddate), j.externalfilenum
            )))
          INTO lxml
          FROM DUAL;

        lblob := rqs_utils.clob2blob(lxml.getclobval());
        p_status_ind := 'F';          
        RETURN lblob;

    EXCEPTION
        WHEN OTHERS THEN
                rqs_utils.log(p_log_type          =>  'E',
                              p_job_id            =>  p_parms.get_value('JOB_ID'),
                              p_seq               =>  TO_NUMBER(p_parms.get_value('SEQ')),
                              p_source            =>  'ModifiedFeeReport',
                              p_msg               =>  SQLERRM,
                              p_error_trace       =>  dbms_utility.format_error_backtrace);             

                p_status_ind := 'E';
                RETURN utl_raw.cast_to_raw('ERROR: ' || SQLERRM || CHR(10) || CHR(13) ||
                                           'TRACE: ' || dbms_utility.format_error_backtrace);
            
    END ModifiedFeeReport;
/


GRANT EXECUTE ON ABCREPORTS.MODIFIEDFEEREPORT TO ABCREPORTS_ROLE;
