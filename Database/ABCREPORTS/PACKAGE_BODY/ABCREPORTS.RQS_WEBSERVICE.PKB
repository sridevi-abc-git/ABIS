CREATE OR REPLACE PACKAGE BODY ABCREPORTS.RQS_WEBSERVICE AS
-- ****************************************************************************
-- File:        rqs_webservice_v2.pkb  
-- Author:      Timothy J. Lord
--
-- $Rev$  
-- $Date$
-- Last Changed By:  $Author$
--
-- Description:    
--
-- 
-- History:
-------------------------------------------------------------------------------
--    Date                  Comment
-- 09/20/2015 TJL       Initial File created  
-- ****************************************************************************


PROCEDURE request(p_parms         IN  OUT t_parameters,
                  p_status_msg    OUT VARCHAR2,
                  p_error         OUT BOOLEAN) IS

--*****************************************************************************
--      RQS_WEBSERVICE (Main Process)
--*****************************************************************************
    l_http_request      UTL_HTTP.req;
    l_http_response     UTL_HTTP.resp;
    
    lv_url              VARCHAR2(100);
    lv_method           VARCHAR2(100);
    l_param_list        VARCHAR2(32767);
    ln_seq              NUMBER;
    
    BEGIN 
        ln_seq := p_parms.get_value('SEQ');
        
        -- get url and method to call from web service
        lv_method := p_parms.get_value('SERVICE');
        lv_url    := p_parms.get_value('URL'); 
        
        p_parms.del_value('URL');      
        p_parms.del_value('SERVICE');
 
        l_param_list := '{"request":"' || lv_method || '","data":"' || p_parms.get_json(TRUE) || '"}';
     
        rqs_utils.log(p_log_type          =>  'T',
                      p_job_id            =>  NULL,
                      p_seq               =>  ln_seq,
                      p_source            =>  'rqs_webservice.request',
                      p_msg               =>  'Starting web request',
                      p_additional_data   =>  'URL: ' || lv_url || CHR(13) || CHR(10) 
                                                                || CHR(13) || CHR(10) || 
                                              'PARMS: ' || l_param_list);
               
        BEGIN 
            -- service's input parameters 
            l_http_request := UTL_HTTP.begin_request (lv_url,
                                                      'POST',
                                                      'HTTP/1.1');                       
                                                      
            -- ...set header's attributes
            UTL_HTTP.set_header(l_http_request, 'Content-Type', 'application/json; charset=utf-8');
            UTL_HTTP.set_header(l_http_request, 'Content-Length', LENGTH(l_param_list));
                     
            -- ...set input parameters
            UTL_HTTP.write_text(l_http_request, l_param_list);
                             
            -- get Response and obtain received value
            l_http_response := UTL_HTTP.get_response(l_http_request);
                             
            UTL_HTTP.read_text(l_http_response, p_status_msg);
                     
            -- finalizing
            UTL_HTTP.end_response(l_http_response);
            rqs_utils.log(p_log_type          =>  'T',
                          p_job_id            =>  NULL,
                          p_seq               =>  ln_seq,
                          p_source            =>  'rqs_webservice.request',
                          p_msg               =>  'Response Message: ' || p_status_msg,
                          p_additional_data =>  'URL: ' || lv_url || CHR(13) || CHR(10) 
                                                                  || CHR(13) || CHR(10) || 
                                                'PARMS: ' || l_param_list);
                    
            IF ((INSTR(UPPER(p_status_msg), 'REQUEST ERROR') = 0) AND
                (INSTR(UPPER(p_status_msg), 'HTTP ERROR') = 0))
            THEN
                p_error := FALSE;
            ELSE
                UPDATE REPORT_QUEUE_STATUS
                   SET step_ind = 'E',
                       ora_status = 'E'
                 WHERE seq = ln_seq;
                COMMIT;
                
                rqs_utils.log(p_log_type          =>  'E',
                              p_job_id            =>  NULL,
                              p_seq               =>  ln_seq,
                              p_source            =>  'rqs_webservice.request',
                              p_msg               =>  p_status_msg,
                              p_additional_data =>  'URL: ' || lv_url || CHR(13) || CHR(10) 
                                                                      || CHR(13) || CHR(10) || 
                                                    'PARMS: ' || l_param_list);

                p_status_msg := 'Request Error: ' || p_status_msg || CHR(10) || CHR(13) 
                             || 'TRACE: ' || dbms_utility.format_error_backtrace;
                                 
                p_error      := TRUE; 
                
            END IF;

        EXCEPTION
            WHEN UTL_HTTP.end_of_body 
                THEN UTL_HTTP.end_response(l_http_response); 
                
                rqs_utils.log(p_log_type          =>  'E',
                              p_job_id            =>  NULL,
                              p_seq               =>  ln_seq,
                              p_source            =>  'rqs_webservice.request',
                              p_msg               =>  p_status_msg,
                              p_additional_data =>  'URL: ' || lv_url || CHR(13) || CHR(10) 
                                                                      || CHR(13) || CHR(10) || 
                                                    'PARMS: ' || l_param_list,
                         p_error_trace       =>  dbms_utility.format_error_backtrace);

                UPDATE REPORT_QUEUE_STATUS
                   SET step_ind = 'R',
                       ora_status = 'E'
                 WHERE seq = ln_seq;
                
                COMMIT; 
                
                p_error      := TRUE; 
        END; 
            
        COMMIT;
                
    EXCEPTION
        WHEN OTHERS THEN
            -- update error log record with response
            rqs_utils.log(p_log_type          =>  'E',
                          p_job_id            =>  NULL,
                          p_seq               =>  p_parms.get_value('SEQ'),
                          p_source            =>  'rqs_webservice.request',
                          p_msg               =>  SQLERRM,
                          p_additional_data   =>  'URL: ' || lv_url || CHR(13) || CHR(10) 
                                                                    || CHR(13) || CHR(10) || 
                                                  'PARMS: ' || l_param_list,
                          p_error_trace       =>  dbms_utility.format_error_backtrace);             
                                 
            p_status_msg := 'ERROR: ' || SQLERRM || CHR(10) || CHR(13) 
                         || 'TRACE: ' || dbms_utility.format_error_backtrace; 
            p_error      := TRUE; 

            UPDATE REPORT_QUEUE_STATUS
               SET step_ind = 'R',
                   ora_status = 'E'
             WHERE seq = ln_seq;
            COMMIT;
    END; 
END;
/


CREATE OR REPLACE PUBLIC SYNONYM RQS_WEBSERVICE FOR ABCREPORTS.RQS_WEBSERVICE;


GRANT EXECUTE ON ABCREPORTS.RQS_WEBSERVICE TO ABCREPORTS_ROLE;
