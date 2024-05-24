CREATE OR REPLACE PROCEDURE ABCREPORTS.RQS_AUTORUNREPORTS(p_override      IN VARCHAR := 'N',
                                               p_report_number IN NUMBER := NULL) IS
-- ****************************************************************************
-- File:        rqs_autorunreports_v2.prc  
-- Author:      Timothy J. Lord
--
-- $Rev: 3679 $  
-- $Date: 2017-10-12 13:01:59 -0700 (Thu, 12 Oct 2017) $
-- Last Changed By:  $Author: tlord $
--
-- Description: The RPT_RUN procdure is called from a scheduler and it will
--              read the control table to figure out what reports are due to
--              be run.     
-- Dependences: 
--
-- History:
-------------------------------------------------------------------------------
--    Date         Ticket     Comment
-- 09/17/2014 TJL           Original file created
-- 03/07/2016 TJL   9131    Added logging report that were exported
-- 09/22/2016 TJL   7213    Added parameter finialize id
-- 10/12/2017 TJL           Corrected formating of report
-- ****************************************************************************
            
    PROCEDURE get_last_report_date(p_cycle             IN  VARCHAR2,
                                   p_report_day        IN  NUMBER,
                                   p_last_report_date  OUT DATE) IS

    BEGIN

        CASE p_cycle
            WHEN 'D' THEN 
                p_last_report_date  := TRUNC(TRUNC(SYSDATE,'MM') - 1,'MM');
                
            WHEN 'W' THEN
                -- create start date week back for miss report check
                p_last_report_date  := TRUNC(TRUNC(SYSDATE,'MM') - 1,'MM');
                
            WHEN 'M' THEN
                -- create start date month back for report check
                p_last_report_date  := TRUNC(TRUNC(SYSDATE,'MM') - 2,'MM');
                
            WHEN 'Y' THEN
                -- create start date year back for report check
                p_last_report_date  := TRUNC(TRUNC(SYSDATE,'YEAR') - 1,'YEAR');
                
            WHEN 'F' THEN
                p_last_report_date  := ADD_MONTHS(TRUNC(ADD_MONTHS(TRUNC(SYSDATE,'MM'), -6), 'YEAR'), 6);                       
            
            ELSE
                p_last_report_date  := SYSDATE - 60;
        END CASE;
    
    END get_last_report_date;

--*****************************************************************************
--      ReportBody
--*****************************************************************************
PROCEDURE sendreport(p_job_id IN NUMBER) IS
    lv_body     VARCHAR2(32000);
    lv_subject  VARCHAR2(  200);
    lv_from     VARCHAR2(  200);
    lv_to       VARCHAR2( 4000);
    lv_cc       VARCHAR2( 4000);
    lv_bcc      VARCHAR2( 4000);
    ln_cnt      NUMBER            := 0;
    lv_db       VARCHAR2(   32);
    ld_start    DATE;
    ld_end      DATE;
    ln_recs     NUMBER;
    
    BEGIN
        -- get information to send status report
        lv_from := rqs_utils.get_ctrl_value('EMAIL_AUTO_FROM');
        lv_to   := rqs_utils.get_ctrl_value('EMAIL_AUTO_TO');
        lv_cc   := rqs_utils.get_ctrl_value('EMAIL_AUTO_CC');
        lv_bcc  := rqs_utils.get_ctrl_value('EMAIL_AUTO_BCC');

        SELECT UPPER(sys_context('USERENV', 'instance_name')) INTO lv_db FROM DUAL;
        SELECT start_time, end_time
          INTO ld_start, ld_end
          FROM report_autorun_log
         WHERE job_id = p_job_id;
         
        -- create report body    
        lv_body := '<html><head>';
        lv_body := lv_body || '<style type="text/css">';
        lv_body := lv_body || 'td { padding: 1px 5px 1px 0; vertical-align: top; }';
        lv_body := lv_body || 'th { padding: 0px 5px 2px 5px; }';
        lv_body := lv_body || '</style>'; 
        lv_body := lv_body || '</head><body>';
        
        -- run stats
        lv_body := lv_body || '<table> <tbody> ';
        lv_body := lv_body || '<tr> <td>System:</td> <td>' || lv_db || '</td> </tr> ';
        lv_body := lv_body || '<tr> <td>Job Id:</td> <td style="text-align: right;">' || p_job_id || '</td></tr> ';
        lv_body := lv_body || '<tr> <td>Start:</td> <td>' || TO_CHAR(ld_start, 'MM/DD/YYYY HH24:MI:SS') || '</td></tr> ';
        lv_body := lv_body || '<tr> <td>End:</td> <td>' || TO_CHAR(ld_end, 'MM/DD/YYYY HH24:MI:SS') || '</td></tr> ';
        lv_body := lv_body || '<tr> <td>Elapse Time:</td> <td style="text-align: right;">' || 
                                TO_CHAR(TRUNC((ld_end - ld_start)*24),'FM9900')||':'||
                                TO_CHAR(TRUNC(MOD((ld_end - ld_start)*24*60, 60)),'FM00')||':'||
                                TO_CHAR(MOD((ld_end - ld_start)*24*60*60,60),'FM00')
                           || '</td> </tr> ';
        lv_body := lv_body || '</tbody> </table> <br/> <br/> ';
        
        -- report stats
        lv_body := lv_body || ' <table> <thead> <tr> ';
        lv_body := lv_body || ' <th>Report Name</th> ';
        lv_body := lv_body || ' <th>Report Number</th> ';
        lv_body := lv_body || ' <th>Processed</th> ';
        lv_body := lv_body || ' <th>Completed</th> ';
        lv_body := lv_body || ' <th>Errors</th> ';
        lv_body := lv_body || ' <th>Retries</th> ';
        lv_body := lv_body || ' </tr></thead><tbody> ';
        
        for recs IN
                (SELECT report_name, report_number,  
                       count(report_number) processed, 
                       count(c.step_ind) COMPLETED, 
                       count(s.step_ind) "ERRORS",
                       sum(s1.retry_cnt) retrys
                  FROM report_def d
                  JOIN report_xref x USING (report_number)
                  LEFT OUTER JOIN report_queue_status s ON (x.seq = s.seq AND s.step_ind = 'E')
                  LEFT OUTER JOIN report_queue_status c ON (x.seq = c.seq AND c.step_ind = 'C')
                  JOIN report_queue_status s1 ON (x.seq = s1.seq)
                 WHERE job_id = p_job_id
                 GROUP BY report_name, report_number
                 ORDER BY report_name)
        LOOP        
            lv_body := lv_body || ' <tr> ';
            lv_body := lv_body || ' <td> ' || recs.report_name || '</td> ';
            lv_body := lv_body || ' <td style="text-align: right;">' || recs.report_number || '</td> ';
            lv_body := lv_body || ' <td style="text-align: right;">' || recs.processed || '</td> ';
            lv_body := lv_body || ' <td style="text-align: right;">' || recs.completed || '</td> ';
            lv_body := lv_body || ' <td style="text-align: right;">' || recs."ERRORS" || '</td> ';
            lv_body := lv_body || ' <td style="text-align: right;">' || recs.retrys || '</td> ';
            lv_body := lv_body || ' </tr> ';
            
            ln_cnt := ln_cnt + recs."ERRORS";                    
        END LOOP;
        
        IF (ln_cnt > 0) THEN
            IF (lv_bcc IS NOT NULL) THEN lv_bcc := lv_bcc || ';'; END IF;
            lv_bcc := lv_bcc || rqs_utils.get_ctrl_value('EMAIL_AUTO_ERROR');
        END IF;
        
        lv_body := lv_body || ' </tbody> </table> <br/>';
               
        -- build subject line
        lv_subject := 'Automated reports completed '; 
        IF (ln_cnt > 0) THEN lv_subject := lv_subject || 'with Errors '; END IF;
        lv_subject := lv_subject || 'for Job Id: ' || p_job_id || ' Completed';

        SELECT NVL(COUNT(seq), 0)
          INTO ln_recs
               FROM report_export_log l
              WHERE l.job_id = p_job_id
                AND L.STATUS_IND = 'C';

        IF (ln_recs > 0 ) THEN
            lv_body := lv_body || '<br/><hr/><b>Exported:</b><br/><br/> ';
            lv_body := lv_body || ' <table> <tbody> ';
            -- retrieve any reports which were exported
            FOR recs IN
                (SELECT NVL(report_name, (SELECT parameter_value 
                                            FROM report_parameters 
                                           WHERE report_number = seq 
                                             AND parameter_name = 'ID')) report_name, 
                        seq, 
                        l.url 
                   FROM report_export_log l
                   LEFT OUTER JOIN report_xref x USING (seq)
                   LEFT OUTER JOIN report_def d USING (report_number)
                  WHERE l.job_id = p_job_id
                    AND l.status_ind = 'C'
                  ORDER BY export_date)
            LOOP
                lv_body := lv_body || ' <tr>';
                lv_body := lv_body || ' <td>' || recs.report_name || '</td> ';
                lv_body := lv_body || ' <td>' || recs.seq || '</td> ';
                lv_body := lv_body || ' <td>' || recs.url || '</td> ';
                lv_body := lv_body || ' </tr> ';
                lv_body := lv_body || '';
            
            END LOOP;
                    
            lv_body := lv_body || '</tbody> </table> <br/>';
        END IF;

        SELECT NVL(COUNT(seq), 0)
          INTO ln_recs
          FROM report_xref x
          JOIN report_error_log e USING (seq)
         WHERE e.job_id = p_job_id
           AND log_type_ind = 'E';

        IF (ln_recs > 0 ) THEN
            lv_body := lv_body || '<br/><hr/><b>Errors:</b><br/><br/><table><tbody>';
            -- retrieve any errors for report
            FOR recs IN
                (SELECT report_name, seq, msg, error_trace, additional_data 
                   FROM report_def d
                   JOIN report_xref x USING (report_number)
                   JOIN report_error_log e USING (seq)
                  WHERE e.job_id = p_job_id
                    AND log_type_ind = 'E')
            LOOP
                IF (LENGTH(lv_body) < 28000) THEN
                    lv_body := lv_body || ' <tr>';
                    lv_body := lv_body || ' <td>' || recs.report_name || '</td> ';
                    lv_body := lv_body || ' <td>' || recs.seq || '</td> ';
                    lv_body := lv_body || ' <td>' || recs.msg || '</td> ';
                    lv_body := lv_body || ' </tr> ';
                    lv_body := lv_body || ' ';
                END IF;        
            END LOOP;
                    
            lv_body := lv_body || '</tbody> </table> ';
        END IF;
        lv_body := lv_body || ' </body> </html>';

        -- send report to selected people
        abcreports.rqs_email.SendEmail(p_fromAddress  => lv_from,
                            p_toAddress    => lv_to,
                            p_cc           => lv_cc,
                            p_bcc          => lv_bcc,
                            p_subject      => lv_subject,
                            p_body         => lv_body); 
                             
            UPDATE report_autorun_log
               SET report = lv_body
             WHERE job_id = p_job_id;
            COMMIT;
    END;  
              
--*****************************************************************************
--      RQS_AUTORUNREPORTS (Main Process)
--*****************************************************************************
    BEGIN
        DECLARE                        
            l_job_id            report_autorun_log.job_id%TYPE;
            ln_cnt              NUMBER;
            ld_start            DATE := SYSDATE;
            lt_parameters       t_parameters;
            ln_                 NUMBER;
            lv_status_msg       VARCHAR2(4000);
            ld_last_date        DATE;
            ln_error_cnt        NUMBER;
            ln_retry_cnt        NUMBER;
            
        BEGIN
            -- create log entry for currnet run
            INSERT INTO report_autorun_log (status_ind) VALUES(NULL)
              RETURNING job_id INTO l_job_id;
            COMMIT;
                  
            -- get list of automated reports available to be executed
            FOR reports IN 
                (SELECT report_number,     
                        report_name,   
                        process,       
                        cycle_ind,     
                        by_office_flg, 
                        data_format,
                        report_day,
                        finalize_id
                   FROM v_scheduled_reports
                  WHERE report_number = NVL(p_report_number, report_number)
                  ORDER BY report_number)
            LOOP
                -- create report parameters from report schedule data
                lt_parameters := t_parameters(XMLTYPE('<ROOT/>'));
                
                -- build standard parametes for the report
                lt_parameters.add_value('JOB_ID', l_job_id);
                lt_parameters.add_value('REPORT_NUMBER', reports.report_number);            
                lt_parameters.add_value('REPORT_NAME', reports.report_name);            
                lt_parameters.add_value('PROCESS', reports.process);            
                lt_parameters.add_value('CYCLE_IND', reports.cycle_ind);            
                lt_parameters.add_value('BY_OFFICE_FLG', reports.by_office_flg);            
                lt_parameters.add_value('DATA_FORMAT', reports.data_format);            
                lt_parameters.add_value('FINALIZE_ID', reports.finalize_id);            
                lt_parameters.add_value('REPORT_DAY', reports.report_day);            
                lt_parameters.add_value('OVERRIDE', UPPER(p_override));
                
                -- get the rest of the parameters for reports.  These value can
                --  override the standard paramters if required
                FOR parameter IN 
                    (SELECT parameter_name, 
                            parameter_value                     
                            FROM report_parameters de  
                           WHERE (parameter_type IN ('A', 'F'))
                             AND (report_number = 0 OR report_number = reports.report_number)
                             AND NOT EXISTS (SELECT * FROM report_parameters 
                                              WHERE de.report_number = 0 AND report_number = reports.report_number 
                                                AND (parameter_type IN ('A', 'F')) 
                                                AND parameter_name = de.parameter_name))
                LOOP
                    lt_parameters.upd_value(parameter.parameter_name,
                                            rqs_process_parameters.process(parameter.parameter_value, 
                                                                           lt_parameters));    
                                                                           
                                                                         
                END LOOP;  
               -- Begin
                       --      for count in 1.. lt_parameters loop
                        --     fetch cur_c into t_parameters;
                         --    EXIT WHEN cur_c%NOTFOUND;
     --     dbms_Output.put_Line('perameters: ' ||  t_parameters);
           
     --  end loop;  
    --   End;                                                 
                
                -- queue up the report(s) to be executed.
                create_queue_rec(p_parms      => lt_parameters, 
                                 p_job_id     => ln_, 
                                 p_status_msg => lv_status_msg); 
         --   dbms_Output.put_Line(lt_parameters);
                -- check if error in handling queueing
                
                -- remove any old reports over month old
                get_last_report_date(p_cycle             => reports.cycle_ind,
                                     p_report_day        => reports.report_day,
                                     p_last_report_date  => ld_last_date);
                DELETE report_xref
                 WHERE create_date < ld_last_date
                   AND report_number = reports.report_number;
                COMMIT;
                            
            END LOOP;
            
            -- get total number of reports being run
            SELECT NVL(COUNT(seq), 0)
              INTO ln_cnt
              FROM report_xref
             WHERE job_id = l_job_id;
             
            -- update table with count
            UPDATE report_autorun_log
               SET rpt_total = ln_cnt,
                   start_time = ld_start
             WHERE job_id = l_job_id;
            COMMIT;
            
            -- process queue
            rqs_process_request_id(l_job_id);
            
            SELECT COUNT(DISTINCT seq)
              INTO ln_error_cnt
              FROM report_xref x
             INNER JOIN report_queue_status s
             USING (seq)
             WHERE job_id = l_job_id
               AND step_ind = 'E'; 
 
            SELECT COUNT(seq)
              INTO ln_retry_cnt
              FROM report_xref x
             INNER JOIN report_queue_status s
             USING (seq)
             WHERE retry_cnt > 0
               AND job_id = l_job_id;
              
            -- update table with with end time
            UPDATE report_autorun_log
               SET end_time = SYSDATE,
                   rpt_errors = ln_error_cnt,
                   rpt_completed = ln_cnt - ln_error_cnt,
                   rpt_retry = ln_retry_cnt
             WHERE job_id = l_job_id;
            COMMIT;

            sendreport(l_job_id);
                        
        EXCEPTION
            WHEN OTHERS THEN
            rqs_utils.log(p_log_type          =>  'E',
                          p_job_id            =>  NULL,
                          p_seq               =>  NULL,
                          p_source            =>  'rqs_autorunreports',
                          p_msg               =>  SQLERRM,
                          p_error_trace       =>  dbms_utility.format_error_backtrace);

                lv_status_msg := 'RQS_AUTORUNREPORTS(EXCEPTION): ' 
                              || dbms_utility.format_error_backtrace
                              || ' :: ' || SQLERRM;
                          
                UPDATE report_autorun_log
                   SET status_ind = 'E',
                       report = lv_status_msg
                 WHERE job_id = l_job_id;
                COMMIT;                 
        END; -- main processing loop 
    
    END RQS_AUTORUNREPORTS;
/


CREATE OR REPLACE PUBLIC SYNONYM RQS_AUTORUNREPORTS FOR ABCREPORTS.RQS_AUTORUNREPORTS;


GRANT EXECUTE ON ABCREPORTS.RQS_AUTORUNREPORTS TO ABCREPORTS_ROLE;
