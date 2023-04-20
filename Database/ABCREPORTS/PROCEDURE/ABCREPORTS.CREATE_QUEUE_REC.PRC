CREATE OR REPLACE PROCEDURE ABCREPORTS.create_queue_rec(p_parms      IN OUT t_parameters, 
                                             p_job_id        OUT NUMBER, 
                                             p_status_msg    OUT VARCHAR2) IS
-- ****************************************************************************
-- File:        create_queue_rec.prc  
-- Author:      Timothy J. Lord
--
-- $Rev: 3045 $  
-- $Date: 2016-09-27 15:09:44 -0700 (Tue, 27 Sep 2016) $
-- Last Changed By:  $Author: tlord $
--
-- Description: RQS_SCHEDULE is called to schedule a manual report to run    
--
-- Parameters:  p_parms       - .
--              p_parms_id    - Id of the parms record for scheduled job
--              p_status_msg  - error message if it fails to schedule job
--
-- Dependences: t_parameters
--
-- History:
-------------------------------------------------------------------------------
--    Date         Ticket     Comment
-- 09/16/2014 TJL           Original file created
-- 02/08/2016 TJL   8968    Modified how date is calculate for month and year
-- 04/05/2016 TJL   9346    Corrected date test for last run report date.
-- 09/22/2016 TJL   7213    Added processing parameter finialize id
-- ****************************************************************************

    PROCEDURE get_report_dates(p_cycle             IN  VARCHAR2,
                               p_report_day        IN  NUMBER,
                               p_report_date       OUT DATE,
                               p_last_report_date  OUT DATE) IS

    BEGIN

        CASE p_cycle
            WHEN 'D' THEN 
                p_report_date       := SYSDATE;
                p_last_report_date  := SYSDATE;
                
            WHEN 'W' THEN
                -- create start date week back for miss report check
                p_report_date       := TRUNC(sysdate, 'DAY') + p_report_day;
                p_last_report_date  := TRUNC(sysdate, 'DAY') - 7 + p_report_day;
                
                IF (TRUNC(SYSDATE) >= p_report_date) THEN
                    p_report_date       := p_report_date + 7;
                    p_last_report_date  := p_last_report_date + 7;
                END IF;
                
            WHEN 'M' THEN
                -- create start date month back for report check
                p_report_date       := TRUNC(TRUNC(SYSDATE,'MM'),'MM') + p_report_day - 1;
                p_last_report_date  := TRUNC(TRUNC(SYSDATE,'MM') - 1,'MM') + p_report_day - 1;
                
                IF (TRUNC(SYSDATE) >= p_report_date) THEN
                    p_report_date       := ADD_MONTHS(p_report_date, 1);
                    p_last_report_date  := ADD_MONTHS(p_last_report_date, 1);
                END IF;
                
            WHEN 'Y' THEN
                -- create start date year back for report check
                p_report_date       := TRUNC(TRUNC(SYSDATE,'YEAR'),'YEAR') + p_report_day - 1;
                p_last_report_date  := TRUNC(TRUNC(SYSDATE,'YEAR') - 1,'YEAR') + p_report_day - 1;
                
                IF (TRUNC(SYSDATE) >= p_report_date) THEN
                    p_report_date       := ADD_MONTHS(p_report_date, 1);
                    p_last_report_date  := ADD_MONTHS(p_last_report_date, 1);
                END IF;
                
            WHEN 'F' THEN
                p_report_date       := ADD_MONTHS(TRUNC(ADD_MONTHS(TRUNC(SYSDATE,'MM'), + 6), 'YEAR'), 6);                       
                p_last_report_date  := ADD_MONTHS(TRUNC(ADD_MONTHS(TRUNC(SYSDATE,'MM'), -6), 'YEAR'), 6);                       
            
                IF (TRUNC(SYSDATE) >= p_report_date) THEN
                    p_report_date       := ADD_MONTHS(p_report_date, 12);
                    p_last_report_date  := ADD_MONTHS(p_last_report_date, 12);
                END IF;
                
            ELSE
                p_report_date       := SYSDATE;
                p_last_report_date  := SYSDATE;
        END CASE;
    
    END get_report_dates;
    
    FUNCTION run_report(p_report_number     IN  NUMBER,
                        p_officeobjectid    IN  NUMBER,
                        p_report_date       IN  DATE,
                        p_last_report_date  IN  DATE)
             RETURN BOOLEAN
    IS
    
        lb_run      BOOLEAN := FALSE;
        ln_cnt      NUMBER;
        
    BEGIN
        IF (TRUNC(p_report_date) = TRUNC(SYSDATE)) THEN
            -- check if report date is already run today  
            SELECT COUNT(SEQ)
              INTO ln_cnt
              FROM REPORTS d
             INNER JOIN REPORT_XREF x
             USING (SEQ)
             INNER JOIN report_autorun_log l
             USING (JOB_ID)
             WHERE x.report_number = p_report_number
               AND x.officeobjectid = p_officeobjectid
               AND TRUNC(d.create_date) = TRUNC(p_report_date);
               
            lb_run := (NVL(ln_cnt, 0) = 0);
        
        END IF;
        
--        lb_run := (TRUNC(p_report_date) = TRUNC(SYSDATE));
        
        -- check if the report is missed if not report date
        IF (NOT lb_run AND (TRUNC(p_report_date) != TRUNC(SYSDATE))) THEN
            SELECT COUNT(SEQ)
              INTO ln_cnt
              FROM REPORTS d
             INNER JOIN REPORT_XREF x
             USING (SEQ)
             INNER JOIN report_autorun_log l
             USING (JOB_ID)
             WHERE x.report_number = p_report_number
               AND x.officeobjectid = p_officeobjectid
               AND (TRUNC(d.create_date) BETWEEN TRUNC(p_last_report_date) AND TRUNC(p_report_date)
                    OR TRUNC(d.create_date) > p_report_date);
               
            lb_run := (NVL(ln_cnt, 0) = 0);
                 
        END IF; 
        
        RETURN lb_run;
    END run_report;
                                  
--*****************************************************************************
--       (Main Process)
--*****************************************************************************
    BEGIN    
        DECLARE 
            ln_sequence         REPORT_XREF.SEQ%TYPE;
            lv_by_office_flg    VARCHAR2(1);
            office              T_OFFICEOBJECT;
            lb_automated        BOOLEAN;
            lb_add              BOOLEAN         := FALSE;
            ld_report_date      DATE;
            ld_last_report_date DATE;
            ln_report_number    NUMBER;
            ln_officeobjectid   NUMBER;
            ln_count            NUMBER;
            
    BEGIN
        -- figure out if this is a web request or an automated report
        lb_automated := (p_parms.get_value('JOB_ID') IS NOT NULL);
        lv_by_office_flg := NVL(p_parms.get_value('BY_OFFICE_FLG'), 'N');
        
        IF (lb_automated) THEN
            p_job_id := p_parms.get_value('JOB_ID'); 
            
            -- indicate report is was from the RQS Automation
            p_parms.upd_value('SOURCE', 'AUTO');
            
            ln_officeobjectid := NVL(p_parms.get_value('OFFICEOBJECTID'), '5554');
            ln_report_number  := p_parms.get_value('REPORT_NUMBER');
            
            -- For automated reports use headquartes to use as a base unless overrided
            p_parms.upd_value('OFFICEOBJECTID', ln_officeobjectid);
            
            get_report_dates(p_cycle             => p_parms.get_value('CYCLE_IND'),
                             p_report_day        => p_parms.get_value('REPORT_DAY'),
                             p_report_date       => ld_report_date,
                             p_last_report_date  => ld_last_report_date);      
           
            IF (lv_by_office_flg != 'Y') THEN
                -- check if report is to be run
                lb_add := run_report(p_report_number     => p_parms.get_value('REPORT_NUMBER'),
                                     p_officeobjectid    => p_parms.get_value('OFFICEOBJECTID'),
                                     p_report_date       => ld_report_date,
                                     p_last_report_date  => ld_last_report_date);
                
                lb_add := ((NVL(p_parms.get_value('OVERRIDE'), 'N') = 'Y') OR lb_add);
            END IF;
        ELSE
            lb_add := (lv_by_office_flg != 'Y');
            p_job_id := report_autorun_log_seq.NEXTVAL;
            
            -- update job_id 
            p_parms.upd_value('JOB_ID', p_job_id); 
            
            -- indicate report is was from WEB
            p_parms.upd_value('SOURCE', 'WEB');
        END IF;
        
        -- create new sequence record
        IF (lb_add) THEN
            
            INSERT INTO report_xref (job_id, report_number, officeobjectid)
                        VALUES (p_job_id, 
                                p_parms.get_value('REPORT_NUMBER'),
                                p_parms.get_value('OFFICEOBJECTID'))
                   RETURNING SEQ INTO ln_sequence;

            -- add sequence to parameters
            p_parms.upd_value('SEQ', ln_sequence);
                                    
            -- create queue record
            INSERT INTO report_queue (seq, report_parameters)
                        VALUES (ln_sequence, p_parms.get_xml);
                        
            -- check if finialize should be run after reports have completed
            IF (p_parms.get_value('FINALIZE_ID') IS NOT NULL) THEN
                -- check if already been added
                SELECT NVL(count(id), 0)
                  INTO ln_count
                  FROM report_finalize_status
                 WHERE id = p_parms.get_value('FINALIZE_ID')
                   AND job_id = p_parms.get_value('JOB_ID');

                IF (ln_count = 0) THEN
                  INSERT INTO report_finalize_status
                         (job_id, id)
                  VALUES (p_parms.get_value('JOB_ID'), p_parms.get_value('FINALIZE_ID'));
                END IF;            
            END IF;                            
        END IF; 
        
        -- check parms to see if single or group of reports by office (parameter - GROUP)
        IF (lv_by_office_flg = 'Y') THEN
            -- retrieve list of offices for selected division or headquartes office id 
            office := rqs_utils.BuildOfficeList(p_parms.get_value('OFFICEOBJECTID'),
                                                p_status_msg);
            IF (p_status_msg IS NULL) THEN                                                   
                FOR rec IN  
                    (SELECT officeobjectid FROM TABLE(office))
                LOOP            
                    -- update parameter list with new office number and job id
                    p_parms.upd_value('OFFICEOBJECTID', rec.officeobjectid);
                    
                    IF (lb_automated) THEN
                        -- check if report is to be run
                        lb_add := run_report(p_report_number     => p_parms.get_value('REPORT_NUMBER'),
                                             p_officeobjectid    => p_parms.get_value('OFFICEOBJECTID'),
                                             p_report_date       => ld_report_date,
                                             p_last_report_date  => ld_last_report_date);

                        lb_add := ((NVL(p_parms.get_value('OVERRIDE'), 'N') = 'Y') OR lb_add);
                    ELSE
                        lb_add := TRUE;
                    END IF;
                    
                    IF (lb_add) THEN                    
                        INSERT INTO report_xref (job_id, report_number, officeobjectid)
                                    VALUES (p_job_id, 
                                            p_parms.get_value('REPORT_NUMBER'),
                                            p_parms.get_value('OFFICEOBJECTID'))
                               RETURNING SEQ INTO ln_sequence;
                                    
                        -- add sequence to parameters
                        p_parms.upd_value('SEQ', ln_sequence);
                                    
                        -- create queue record
                        INSERT INTO report_queue (seq, report_parameters)
                                    VALUES (ln_sequence, p_parms.get_xml);    
                    END IF;
                    
                    ln_officeobjectid := rec.officeobjectid;
                    
                END LOOP; 
            ELSE
                ROLLBACK;
            END IF;          
        END IF;            

        COMMIT;    
    EXCEPTION
        WHEN OTHERS THEN 
            ROLLBACK;
            rqs_utils.log(p_log_type          =>  'E',
                          p_job_id            =>  p_job_id,
                          p_seq               =>  NULL,
                          p_source            =>  'create_queue_rec',
                          p_msg               =>  SQLERRM,
                          p_error_trace       =>  dbms_utility.format_error_backtrace);
                                    
            p_status_msg := 'ERROR: ' || SQLERRM || CHR(10) || CHR(13) 
                         || 'TRACE: ' || dbms_utility.format_error_backtrace;
    END;
END;
/


GRANT EXECUTE ON ABCREPORTS.CREATE_QUEUE_REC TO ABCREPORTS_ROLE;
