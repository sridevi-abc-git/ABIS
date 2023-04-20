CREATE OR REPLACE PACKAGE BODY ABCREPORTS.RQS_PROCESS_PARAMETERS AS
-- ****************************************************************************
-- File:        rqs_process_parameters.pkb  
-- Author:      Timothy J. Lord
--
-- $Rev: 3011 $  
-- $Date: 2016-09-15 15:11:14 -0700 (Thu, 15 Sep 2016) $
-- Last Changed By:  $Author: tlord $
--
-- Description:    
--
-- History:
-------------------------------------------------------------------------------
--    Date         Ticket     Comment
-- 09/18/2015 TJL           Initial package created
-- 09/15/2016 TJL  7213     added functions year and date_dash
-- ****************************************************************************
FUNCTION replace_tags(parameter_value IN VARCHAR2) RETURN VARCHAR2 IS

    lv_buf              VARCHAR2(4000) := parameter_value;
    lv_value            VARCHAR2(4000);

    BEGIN
        -- check if parameter calls replacement function
        IF (INSTR(parameter_value, '<<') > 0) THEN
            -- process each replacement found in parameter_value
            FOR rec IN 
                (SELECT str parameter_value
                   FROM (SELECT REGEXP_SUBSTR(str, '(<<.*>>)', 1, LEVEL) AS str
                           FROM (SELECT REGEXP_REPLACE(parameter_value, '(>>)',
                                                      '>>' || chr(13) || chr(10)) as str
                                   FROM DUAL             
                                ) 
                        CONNECT BY LEVEL <= LENGTH(REGEXP_REPLACE(str, '(<<.*>>)'))
                        ) 
                  WHERE REGEXP_LIKE(str, '(<<.*>>)')
                )
            LOOP
                CASE UPPER(rec.parameter_value)
                    WHEN '<<DATETIME>>' THEN
                        lv_value := TO_CHAR(SYSDATE, 'YYYYMMDDHH24MISS');
                        
                    ELSE
                        lv_value := rec.parameter_value;    
                END CASE;
            
                SELECT REPLACE(lv_buf, rec.parameter_value, lv_value)
                  INTO lv_buf FROM DUAL;

            END LOOP;
            
        END IF;
        
        return lv_buf;    
    EXCEPTION
        WHEN OTHERS THEN 
            rqs_utils.log(p_log_type          =>  'E',
                          p_job_id            =>  NULL,
                          p_seq               =>  NULL,
                          p_source            =>  'rqs_process_parameters.replace_tags',
                          p_msg               =>  SQLERRM,
                          p_additional_data   =>  parameter_value,
                          p_error_trace       =>  dbms_utility.format_error_backtrace);

        RETURN NULL;        
    END;                 
    
    
FUNCTION proc(parameter_value  IN VARCHAR2,
              p_parms          IN t_parameters) 
           RETURN VARCHAR2 IS

    l_parameters          t_parameters;           

    BEGIN
--            rqs_utils.log(p_log_type          =>  'T',
--                          p_job_id            =>  p_parms.get_value('JOB_ID'),
--                          p_seq               =>  p_parms.get_value('SEQ'),
--                          p_source            =>  'rqs_process_parameters.proc',
--                          p_msg               =>  parameter_value,
--                          p_error_trace       =>  NULL);
        l_parameters := p_parms;  
        return process(parameter_value, l_parameters);
    END;

FUNCTION process(parameter_value  IN VARCHAR2,
                 p_parms          IN OUT t_parameters) 
           RETURN VARCHAR2 IS
           
    lv_buf              VARCHAR2(4000);
    lv_value            VARCHAR2(4000);
    ln_cnt              NUMBER;
    lv_package_name     VARCHAR2(250);
    lv_function_name    VARCHAR2(250);
           
    BEGIN
        lv_buf := parameter_value;
--            rqs_utils.log(p_log_type          =>  'T',
--                          p_job_id            =>  p_parms.get_value('JOB_ID'),
--                          p_seq               =>  p_parms.get_value('SEQ'),
--                          p_source            =>  'rqs_process_parameters.process',
--                          p_msg               =>  lv_buf,
--                          p_error_trace       =>  NULL);
--        commit;
--        
        -- check if parameter calls replacement function
        IF (INSTR(parameter_value, '<<') > 0) THEN
            -- process each replacement found in parameter_value
            FOR rec IN 
                (SELECT str parameter_value
                   FROM (SELECT REGEXP_SUBSTR(str, '(<<.*>>)', 1, LEVEL) AS str
                           FROM (SELECT REGEXP_REPLACE(parameter_value, '(>>)',
                                                      '>>' || chr(13) || chr(10)) as str
                                   FROM DUAL             
                                ) 
                        CONNECT BY LEVEL <= LENGTH(REGEXP_REPLACE(str, '(<<.*>>)'))
                        ) 
                  WHERE REGEXP_LIKE(str, '(<<.*>>)')
                )
            LOOP
                -- split package name from function name
                SELECT * 
                  INTO lv_package_name, lv_function_name 
                  FROM
                    (
                    SELECT substr, a
                      FROM (
                        SELECT REGEXP_SUBSTR(str, '[^\. ]+', 1, LEVEL) AS substr, level a
                          FROM (
                            SELECT REGEXP_SUBSTR (rec.parameter_value, '[^<][^>]+', 1) || '.' AS str
                            FROM DUAL
                        )
                        CONNECT BY LEVEL <= LENGTH(REGEXP_REPLACE(str, '[^\.]+'))
                      )
                    )    
                 PIVOT (min(substr)
                   FOR a in ( 1 as pack, 2 as proc )
                 );

                -- check if exists
                SELECT NVL(COUNT(OWNER), 0)
                  INTO ln_cnt 
                  FROM ALL_PROCEDURES
                 WHERE OBJECT_TYPE    = 'PACKAGE'
--                   AND OWNER          = USER
                   AND OBJECT_NAME    = UPPER(lv_package_name)
                   AND PROCEDURE_NAME = UPPER(lv_function_name); 
                         
                BEGIN
                    IF (ln_cnt = 1) THEN
                        -- build function to call from parameters
                        lv_function_name := lv_package_name || '.' || lv_function_name;
                    ELSE
                        -- call default params function
                        lv_function_name := 'RQS_PROCESS_PARAMETERS.DEFAULT_FUNCTION';
                    END IF;
                    -- call function to process parameter
                    EXECUTE IMMEDIATE 'BEGIN :a := ' || lv_function_name || '(:b, :c); END;'
                      USING    OUT lv_value,
                            IN     lv_value, 
                            IN OUT p_parms;
                
                    -- replace tag with value
                    SELECT REPLACE(lv_buf, rec.parameter_value, lv_value)
                      INTO lv_buf FROM DUAL;

--            rqs_utils.log(p_log_type          =>  'T',
--                          p_job_id            =>  p_parms.get_value('JOB_ID'),
--                          p_seq               =>  p_parms.get_value('SEQ'),
--                          p_source            =>  'rqs_process_parameters.process',
--                          p_msg               =>  lv_buf || ' -- function: ' || lv_function_name || ' -- value: ' || lv_value,
--                          p_error_trace       =>  lv_package_name || ' ' || ln_cnt );

                END;
            END LOOP;        
        END IF;
         
        RETURN lv_buf; 
            
    EXCEPTION
        WHEN OTHERS THEN 
            rqs_utils.log(p_log_type          =>  'E',
                          p_job_id            =>  p_parms.get_value('JOB_ID'),
                          p_seq               =>  p_parms.get_value('SEQ'),
                          p_source            =>  'rqs_process_parameters.process',
                          p_msg               =>  SQLERRM,
                          p_error_trace       =>  dbms_utility.format_error_backtrace);
                                    
            lv_buf := 'ERROR: ' || SQLERRM || CHR(10) || CHR(13) 
                         || 'TRACE: ' || dbms_utility.format_error_backtrace;   

        RETURN NULL;        
    END;                 



FUNCTION DEFAULT_FUNCTION(p_value IN VARCHAR2, p_parms IN OUT t_parameters)
    RETURN VARCHAR2 IS
    
    lv_     VARCHAR2(4000);
    
    BEGIN
        SELECT REGEXP_REPLACE(p_value, '(<<)|(>>)', '%')
          INTO lv_
          FROM DUAL;
          
        RETURN lv_;
    END DEFAULT_FUNCTION;
    


FUNCTION start_date(p_value IN VARCHAR2, p_parms IN OUT t_parameters)
    RETURN VARCHAR2 IS
    
    lv_date         VARCHAR2(10);
                     
    BEGIN
        
        CASE p_parms.get_value('CYCLE_IND')

            WHEN 'D' THEN
                SELECT TO_CHAR(sysdate, 'MM/DD/YYYY')
                  INTO lv_date
                  FROM dual;
            
            WHEN 'W' THEN
                -- get date for begining of previous week
                SELECT TO_CHAR(TRUNC(sysdate - 7, 'DAY'), 'MM/DD/YYYY')
                  INTO lv_date
                  FROM dual;
                
            WHEN 'M' THEN
                SELECT TO_CHAR(trunc(trunc(sysdate,'MM') - 1,'MM'), 'MM/DD/YYYY')
                  INTO lv_date
                  FROM dual;

            WHEN 'Y' THEN
                SELECT TO_CHAR(trunc(trunc(sysdate,'YYYY') - 1, 'YYYY'), 'MM/DD/YYYY')
                  INTO lv_date
                  FROM dual;
                
            ELSE
                NULL;
        END CASE;

        RETURN lv_date;
    END start_date;
    




FUNCTION end_date(p_value IN VARCHAR2, p_parms IN OUT t_parameters)
    RETURN VARCHAR2 IS
    
    lv_date         VARCHAR2(10);
                     
    BEGIN
        
        CASE p_parms.get_value('CYCLE_IND')
            WHEN 'D' THEN
                SELECT TO_CHAR(sysdate, 'MM/DD/YYYY')
                  INTO lv_date
                  FROM dual;
            
            WHEN 'W' THEN
                -- get date for end of previous week
                SELECT TO_CHAR(TRUNC(sysdate - 7, 'DAY') + 6, 'MM/DD/YYYY')
                  INTO lv_date
                  FROM dual;
                
            WHEN 'M' THEN
                SELECT TO_CHAR(TRUNC(sysdate,'MM') - 1, 'MM/DD/YYYY')
                  INTO lv_date
                  FROM dual;
                
            ELSE
                NULL;
        END CASE;

        RETURN lv_date;
    END end_date;



FUNCTION datetime(p_value IN VARCHAR2, p_parms IN OUT t_parameters)
    RETURN VARCHAR2 IS
    
    lv_date         VARCHAR2(10);
                     
    BEGIN
        SELECT TO_CHAR(sysdate, 'YYYYMMDDHH24MISS')
          INTO lv_date
          FROM dual;
            
        RETURN lv_date;
    END datetime;



FUNCTION previous_year(p_value IN VARCHAR2, p_parms IN OUT t_parameters)
    RETURN VARCHAR2 IS
    
    lv_date         VARCHAR2(10);
                     
    BEGIN
        
        SELECT TO_CHAR(trunc(trunc(sysdate,'YYYY') - 1, 'YYYY'), 'YYYY')
          INTO lv_date
          FROM dual;
                
        RETURN lv_date;
    END previous_year;
    
FUNCTION report_date(p_value IN VARCHAR2, p_parms IN OUT t_parameters)
                RETURN VARCHAR2 IS
    
    BEGIN  
DBMS_OUTPUT.put_line(p_value || ' : ' || p_parms.get_value('REPORT_DATE'));                       
    
        return p_parms.get_value('REPORT_DATE');
    END;    
    
    
FUNCTION report_name(p_value IN VARCHAR2, p_parms IN OUT t_parameters)
                RETURN VARCHAR2 IS
    
    BEGIN
        return p_parms.get_value('REPORT_NAME');
    END;    

    
FUNCTION job_id(p_value IN VARCHAR2, p_parms IN OUT t_parameters)
                RETURN VARCHAR2 IS
    
    BEGIN
        return p_parms.get_value('JOB_ID');
    END;    
 
   
FUNCTION seq(p_value IN VARCHAR2, p_parms IN OUT t_parameters)
                RETURN VARCHAR2 IS
    
    BEGIN
        return p_parms.get_value('SEQ');
    END;    
    
FUNCTION year(p_value IN VARCHAR2, p_parms IN OUT t_parameters)
    RETURN VARCHAR2 IS
    
    lv_date         VARCHAR2(10);
                     
    BEGIN
        
        SELECT TO_CHAR(trunc(sysdate,'YYYY'), 'YYYY')
          INTO lv_date
          FROM dual;
                
        RETURN lv_date;
    END year;
    
    
FUNCTION date_dash(p_value IN VARCHAR2, p_parms IN OUT t_parameters)
    RETURN VARCHAR2 IS
    
    lv_date         VARCHAR2(10);
                     
    BEGIN
        
        SELECT TO_CHAR(sysdate,'MM-DD-YYYY')
          INTO lv_date
          FROM dual;
                
        RETURN lv_date;
    END date_dash;
    
    

END rqs_process_parameters;
/


CREATE OR REPLACE PUBLIC SYNONYM RQS_PROCESS_PARAMETERS FOR ABCREPORTS.RQS_PROCESS_PARAMETERS;


GRANT EXECUTE ON ABCREPORTS.RQS_PROCESS_PARAMETERS TO ABCREPORTS_ROLE;
