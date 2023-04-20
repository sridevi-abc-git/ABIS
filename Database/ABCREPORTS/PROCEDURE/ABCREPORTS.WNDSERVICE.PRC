CREATE OR REPLACE PROCEDURE ABCREPORTS.wndservice(a_requestid IN  NUMBER,
                                       a_response  OUT VARCHAR2,
                                       a_error     OUT NUMBER)
    IS
-- ****************************************************************************
-- File:        wndservice.prc
-- Author:      Timothy J. Lord
--
-- $Rev: 3045 $
-- $Date: 2016-09-27 15:09:44 -0700 (Tue, 27 Sep 2016) $
-- Last Changed By:  $Author: tlord $
--
-- Description:
--
--
-- History:
-------------------------------------------------------------------------------
--    Date                  Comment
-- 04/27/2016 TJL       Initial procedure created
--
-- ****************************************************************************

    t_host          VARCHAR2(  500);
    t_port          NUMBER;
    t_process       VARCHAR2(10000);
    t_out           VARCHAR2(10000);
    t_in            VARCHAR2(10000);
    t_connection    UTL_TCP.connection;
    t_return        PLS_INTEGER;
    t_wait          PLS_INTEGER;
    t_report        NUMBER;
    t_retry         NUMBER := 0;
    l_format        t_parameters;
    t_job_id        NUMBER;
    
    BEGIN
        -- get host and port number from configuration table
        BEGIN
            t_host := abcreports.rqs_utils.get_ctrl_value('WND_SERVICE_HOST');
            IF (t_host IS NULL) THEN
                a_response  := a_response || CHR(10) || CHR(13)
                            || 'Missing Host configuration.';
                a_error     := -1;  
            END IF;
        END;

        BEGIN 
            t_port := abcreports.rqs_utils.get_ctrl_value('WND_SERVICE_PORT');
            IF (t_port IS NULL) THEN
                a_response  := a_response || CHR(10) || CHR(13)
                            || 'Missing Port configuration.';
                a_error     := -1;  
            END IF;
        END;

        BEGIN
            t_wait := abcreports.rqs_utils.get_ctrl_value('WND_SERVICE_TIMEOUT');
            IF (t_wait IS NULL) THEN
                t_wait := 10; -- default wait timeout
            END IF;
        END;

        IF (a_requestid < 0) 
        THEN
            BEGIN
                l_format := t_parameters(XMLTYPE('<ROOT/>'));
                SELECT parameter_value
                  INTO  t_out
                  FROM abcreports.report_parameters de
                 WHERE (parameter_type = 'UPD')
                   AND parameter_name = 'SERVICE'
                   AND report_number = a_requestid;
                
                SELECT MAX(job_id)
                  INTO t_job_id 
                  FROM report_finalize_status 
                 WHERE id = a_requestid; 
                  
                SELECT '{' || 
                      LISTAGG('"' || parameter_name || '":"' || rqs_process_parameters.proc(parameter_value, l_format) || 
                              '"'  , ',')
                                    WITHIN GROUP (ORDER BY parameter_value) ||
                      ',"JOB_ID":"' || t_job_id || '",' ||              
                      '"FINALIZE_ID":"' || a_requestid || '"' ||              
                             '}' "values" 
                  INTO t_process
                  FROM abcreports.report_parameters de
                 WHERE (parameter_type = 'UPD')
                   AND parameter_name != 'SERVICE'
                   AND report_number = a_requestid;
                
                t_out := t_out || ';' || t_process;
                    
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    a_response  := a_response || CHR(10) || CHR(13)
                                || 'Missing report process information.';
                    a_error     := -1; 
                    
                    rqs_utils.log(p_log_type          =>  'E',
                                  p_job_id            =>  NULL,
                                  p_seq               =>  a_requestid,
                                  p_source            =>  'wndservice',
                                  p_msg               =>  a_response,
                                  p_additional_data   =>  'HOST: ' || t_host || CHR(13) || CHR(10) || 
                                                          'PORT: ' || t_port,
                                  p_error_trace       =>  DBMS_UTILITY.format_error_backtrace);
            END;
        ELSE
            -- get process to call from report defs table
            BEGIN
                -- get report number of request id  
                SELECT report_number
                  INTO t_report
                  FROM abcreports.report_xref x
                 WHERE x.seq = a_requestid;
               
                -- get process to call  
                SELECT parameter_value
                  INTO t_process
                  FROM abcreports.report_parameters de
                 WHERE (parameter_type = 'F')
                   AND UPPER(de.parameter_name) = 'SERVICE'
                   AND (report_number = 0 OR report_number = t_report)
                   AND NOT EXISTS (SELECT * FROM report_parameters r
                                     WHERE r.report_number = 0 AND r.report_number = t_report
                                       AND (parameter_type = 'F')
                                       AND parameter_name = de.parameter_name
                                   );

                t_out := t_process || ';' || a_requestid;
                
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    a_response  := a_response || CHR(10) || CHR(13)
                                || 'Missing report process information.';
                    a_error     := -1; 
                    
                    rqs_utils.log(p_log_type          =>  'E',
                                  p_job_id            =>  NULL,
                                  p_seq               =>  a_requestid,
                                  p_source            =>  'wndservice',
                                  p_msg               =>  a_response,
                                  p_additional_data   =>  'HOST: ' || t_host || CHR(13) || CHR(10) || 
                                                          'PORT: ' || t_port,
                                  p_error_trace       =>  DBMS_UTILITY.format_error_backtrace);
                END;
        END IF;
        
        IF (a_error IS NULL) THEN
            -- open connection and send request
            LOOP
                BEGIN
                    EXIT WHEN t_retry > 3;
                    t_connection := UTL_TCP.open_connection(remote_host => t_host,
                                                            remote_port => t_port);
                    EXIT;  -- exit loop on connection                                        
                EXCEPTION
                    WHEN OTHERS THEN
                        IF (t_retry = 0) THEN
                            rqs_utils.log(p_log_type          =>  'E',
                                          p_job_id            =>  NULL,
                                          p_seq               =>  a_requestid,
                                          p_source            =>  'wndservice',
                                          p_msg               =>  SQLERRM,
                                          p_additional_data   =>  'HOST: ' || t_host || CHR(13) || CHR(10) || 
                                                                  'PORT: ' || t_port || CHR(13) || CHR(10) || 
                                                                  'WAIT: ' || t_wait,
                                          p_error_trace       =>  DBMS_UTILITY.format_error_backtrace);
                        END IF;
                        t_retry := t_retry + 1;
                END;
            END LOOP;                                                            
           
            IF (t_retry < 3) THEN
                t_return := UTL_TCP.write_line(t_connection, t_out);
                 
                -- wait for response
                IF (UTL_TCP.available(t_connection, t_wait) > 0) THEN
                    t_return := UTL_TCP.read_line(t_connection, t_in);

                    -- make sure data was received
                    IF (t_return = 0) THEN
                        a_error := -1;
                        a_response := 'No response data received from WndService';

                        rqs_utils.log(p_log_type          =>  'E',
                                      p_job_id            =>  NULL,
                                      p_seq               =>  a_requestid,
                                      p_source            =>  'wndservice',
                                      p_msg               =>  a_response,
                                      p_additional_data   =>  'HOST: ' || t_host || CHR(13) || CHR(10) || 
                                                              'PORT: ' || t_port,
                                      p_error_trace       =>  NULL);
                    ELSE
                        a_response := t_in;
                    END IF;
                ELSE
                    a_error := -1;
                    a_response := '(Timeout) No response data received from WndService';

                    rqs_utils.log(p_log_type          =>  'E',
                                  p_job_id            =>  NULL,
                                  p_seq               =>  a_requestid,
                                  p_source            =>  'wndservice',
                                  p_msg               =>  a_response,
                                  p_additional_data   =>  'HOST: ' || t_host || CHR(13) || CHR(10) || 
                                                          'PORT: ' || t_port,
                                  p_error_trace       =>  NULL);
                END IF;

                UTL_TCP.close_connection(t_connection); 
                
                -- check if response is an error
                IF (UPPER(SUBSTR(a_response, 0, 5)) = '$ERR$') THEN
                    a_error := -1;
                    a_response := SUBSTR(a_response, 6);
                    
                    rqs_utils.log(p_log_type          =>  'E',
                                  p_job_id            =>  NULL,
                                  p_seq               =>  a_requestid,
                                  p_source            =>  'wndservice',
                                  p_msg               =>  a_response,
                                  p_additional_data   =>  'HOST: ' || t_host || CHR(13) || CHR(10) || 
                                                          'PORT: ' || t_port,
                                  p_error_trace       =>  NULL);
                    
                END IF;
                
            ELSE
                a_error := -1;
                a_response := 'No response received from WndService';

                rqs_utils.log(p_log_type          =>  'E',
                              p_job_id            =>  NULL,
                              p_seq               =>  a_requestid,
                              p_source            =>  'wndservice',
                              p_msg               =>  a_response,
                              p_additional_data   =>  'HOST: ' || t_host || CHR(13) || CHR(10) || 
                                                      'PORT: ' || t_port || CHR(13) || CHR(10) || 
                                                      'WAIT: ' || t_wait,
                              p_error_trace       =>  NULL);
            END IF;
        END IF;
        
        IF (a_error IS NOT NULL) THEN
            UPDATE REPORT_QUEUE_STATUS
               SET step_ind = CASE WHEN t_retry > 3 THEN 'R' ELSE 'E' END,
                   ora_status = 'E'
             WHERE seq = a_requestid;
            COMMIT;
        END IF;
        
    EXCEPTION
        WHEN OTHERS THEN
            a_response  := a_response || CHR(10) || CHR(13)
                        || 'ERROR: ' || SQLERRM || CHR(10) || CHR(13)
                        || 'TRACE: ' || DBMS_UTILITY.format_error_backtrace;
            a_error     := -1;

            -- check if connection is open
            IF (t_connection.remote_host IS NOT NULL) THEN
                UTL_TCP.close_connection(t_connection);
            END IF;

            UPDATE REPORT_QUEUE_STATUS
               SET step_ind = 'E',
                   ora_status = 'E'
             WHERE seq = a_requestid;
            COMMIT;

            rqs_utils.log(p_log_type          =>  'E',
                          p_job_id            =>  NULL,
                          p_seq               =>  a_requestid,
                          p_source            =>  'wndservice',
                          p_msg               =>  SQLERRM,
                          p_additional_data   =>  'HOST: ' || t_host || CHR(13) || CHR(10) || 
                                                  'PORT: ' || t_port,
                          p_error_trace       =>  DBMS_UTILITY.format_error_backtrace);

    END;
/
