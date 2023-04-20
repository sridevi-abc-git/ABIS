CREATE OR REPLACE PROCEDURE ABCREPORTS.RQS_SCHEDULE(p_parms       IN XMLTYPE, 
                                         p_status_ind OUT VARCHAR2,
                                         p_job_id     OUT VARCHAR2, 
                                         p_status_msg OUT VARCHAR2) IS
-- ****************************************************************************
-- File:        rqs_schedule_v2.prc  
-- Author:      Timothy J. Lord
--
-- $Rev: 3045 $  
-- $Date: 2016-09-27 15:09:44 -0700 (Tue, 27 Sep 2016) $
-- Last Changed By:  $Author: tlord $
--
-- Description: RQS_SCHEDULE is called to schedule a manual report to run    
--
-- Parameters:  p_parms       - XML report parameters.
--              p_status_ind  - return status of job being schedule
--              p_parms_id    - Id of the parms record for scheduled job
--              p_status_msg  - error message if it fails to schedule job
--
-- Dependences: abcreports.t_parameters
--
-- History:
-------------------------------------------------------------------------------
--    Date         Ticket     Comment
-- 09/16/2015 TJL           Original file created for v2 enhancements
-- 09/22/2016 TJL    7213   Added parameter finialize id
-- ****************************************************************************

--*****************************************************************************
--      RQS_SCHEDULE (Main Process)
--*****************************************************************************
    BEGIN    
        DECLARE
            ld_schedule         DATE;
            lt_                 t_parameters;
            lt_parameters       t_parameters;
            lv_scheduled_date   VARCHAR2(20);
            lv_scheduled_time   VARCHAR2(20);
            
    BEGIN
        lt_ := t_parameters(p_parms);
        
        -- load required parameters that don't come from web.    
        FOR reports IN 
            (SELECT report_number,     
                    report_name,   
                    process,       
                    cycle_ind,     
                    by_office_flg, 
                    data_format,
                    finalize_id
               FROM v_reports_defs
              WHERE report_number = lt_.get_value('REPORT_NUMBER'))
        LOOP
            -- create report parameters from report schedule data
            lt_parameters := t_parameters(XMLTYPE('<ROOT/>'));
                
            -- build standard parametes for the report
            lt_parameters.add_value('REPORT_NAME', reports.report_name);            
            lt_parameters.add_value('PROCESS', reports.process);            
            lt_parameters.add_value('CYCLE_IND', reports.cycle_ind);            
            lt_parameters.add_value('BY_OFFICE_FLG', reports.by_office_flg);            
            lt_parameters.add_value('DATA_FORMAT', reports.data_format);            
            lt_parameters.add_value('FINALIZE_ID', reports.finalize_id);            

            -- get the rest of the parameters for reports.  These value can
            --  override the standard paramters if required
            FOR parameter IN 
                (SELECT parameter_name, 
                        parameter_value                     
                   FROM report_parameters de  
                  WHERE (parameter_type IN ('W', 'F'))
                    AND (report_number = 0 OR report_number = reports.report_number)
                    AND NOT EXISTS (SELECT * FROM report_parameters 
                                     WHERE de.report_number = 0 AND report_number = reports.report_number 
                                       AND (parameter_type IN ('W', 'F')) 
                                       AND parameter_name = de.parameter_name))
            LOOP
                lt_parameters.upd_value(parameter.parameter_name,
                                        rqs_process_parameters.process(parameter.parameter_value, 
                                                                       lt_parameters));                
            END LOOP;                                                     
            
            -- update parameters from site
            FOR rec IN
                (SELECT parameter_name, parameter_value
                   FROM TABLE(lt_.recs))
            LOOP
                lt_parameters.upd_value(rec.parameter_name,
                                        rec.parameter_value);                
            END LOOP;    
        END LOOP;
            
        -- queue up requested report
        create_queue_rec(p_parms      => lt_parameters, 
                         p_job_id     => p_job_id, 
                         p_status_msg => p_status_msg);
                         
        IF (p_status_msg IS NULL) THEN
            -- Check if report is schedule for later date and / or time
            lv_scheduled_date := lt_.get_value('SCHEDULE_DATE');
            lv_scheduled_time := lt_.get_value('SCHEDULE_TIME');

            IF (NVL(lt_.get_value('REPORT_WAIT'), 'N') = 'N') THEN             
                ld_schedule := TO_DATE(lv_scheduled_date || ' ' || 
                                       lv_scheduled_time, 'MM/DD/YYYY HH24:MI');
            
                p_status_ind := 'S';  -- scheduled --
            ELSE
                p_status_ind := 'W';    -- client waiting for completion
                ld_schedule := SYSDATE;
            END IF;
            
            p_status_msg := 'Job Id - ' || p_job_id;   
            
            rqs_utils.log(p_log_type          =>  'T',
                          p_job_id            =>  p_job_id,
                          p_seq               =>  NULL,
                          p_source            =>  'rqs_schedule',
                          p_msg               =>  SQLERRM,
                          p_additional_data   =>  p_parms.GETSTRINGVAL(),
                          p_error_trace       =>  dbms_utility.format_error_backtrace);
                
            -- create job
            DBMS_SCHEDULER.CREATE_JOB(
               job_name          =>  'W' || p_job_id,
               job_type          =>  'PLSQL_BLOCK',
               job_action        =>  'BEGIN rqs_process_request_id(''' || p_job_id || '''); END;',
               start_date        =>  ld_schedule,
               repeat_interval   =>  null,
               enabled           =>  TRUE);
        END IF;            
    EXCEPTION
        WHEN OTHERS THEN
            rqs_utils.log(p_log_type          =>  'E',
                          p_job_id            =>  p_job_id,
                          p_seq               =>  NULL,
                          p_source            =>  'rqs_schedule',
                          p_msg               =>  SQLERRM,
                          p_error_trace       =>  dbms_utility.format_error_backtrace);
                                    
            p_status_msg := 'ERROR: ' || SQLERRM || CHR(10) || CHR(13) 
                         || 'TRACE: ' || dbms_utility.format_error_backtrace;
            p_status_ind := 'E';
    END;
END RQS_SCHEDULE;
/


CREATE OR REPLACE PUBLIC SYNONYM RQS_SCHEDULE FOR ABCREPORTS.RQS_SCHEDULE;


GRANT EXECUTE ON ABCREPORTS.RQS_SCHEDULE TO ABCREPORTS_ROLE;

GRANT EXECUTE ON ABCREPORTS.RQS_SCHEDULE TO POSSEEXTENSIONS;
