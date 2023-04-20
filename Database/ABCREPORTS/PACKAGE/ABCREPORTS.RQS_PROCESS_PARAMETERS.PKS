CREATE OR REPLACE PACKAGE ABCREPORTS.RQS_PROCESS_PARAMETERS AS
-- ****************************************************************************
-- File:        rqs_process_parameters.pks  
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
-- ****************************************************************************
FUNCTION replace_tags(parameter_value IN VARCHAR2) RETURN VARCHAR2;

FUNCTION proc(parameter_value  IN VARCHAR2,
              p_parms          IN t_parameters) 
           RETURN VARCHAR2;

FUNCTION process(parameter_value  IN VARCHAR2,
                 p_parms          IN OUT t_parameters) 
           RETURN VARCHAR2;

FUNCTION DEFAULT_FUNCTION(p_value IN VARCHAR2, p_parms IN OUT t_parameters)
    RETURN VARCHAR2;
               
FUNCTION start_date(p_value IN VARCHAR2, p_parms IN OUT t_parameters)
    RETURN VARCHAR2;
    
FUNCTION end_date(p_value IN VARCHAR2, p_parms IN OUT t_parameters)
    RETURN VARCHAR2;

FUNCTION datetime(p_value IN VARCHAR2, p_parms IN OUT t_parameters)
    RETURN VARCHAR2;

FUNCTION previous_year(p_value IN VARCHAR2, p_parms IN OUT t_parameters)
    RETURN VARCHAR2;
    
FUNCTION report_date(p_value IN VARCHAR2, p_parms IN OUT t_parameters)
    RETURN VARCHAR2;
    
FUNCTION report_name(p_value IN VARCHAR2, p_parms IN OUT t_parameters)
    RETURN VARCHAR2;
    
FUNCTION job_id(p_value IN VARCHAR2, p_parms IN OUT t_parameters)
    RETURN VARCHAR2;
    
FUNCTION seq(p_value IN VARCHAR2, p_parms IN OUT t_parameters)
    RETURN VARCHAR2;
    
FUNCTION year(p_value IN VARCHAR2, p_parms IN OUT t_parameters)
    RETURN VARCHAR2;
    
FUNCTION date_dash(p_value IN VARCHAR2, p_parms IN OUT t_parameters)
    RETURN VARCHAR2;
    
            
END rqs_process_parameters;
/


CREATE OR REPLACE PUBLIC SYNONYM RQS_PROCESS_PARAMETERS FOR ABCREPORTS.RQS_PROCESS_PARAMETERS;


GRANT EXECUTE ON ABCREPORTS.RQS_PROCESS_PARAMETERS TO ABCREPORTS_ROLE;
