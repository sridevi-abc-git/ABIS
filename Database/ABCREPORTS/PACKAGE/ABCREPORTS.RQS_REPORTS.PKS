CREATE OR REPLACE PACKAGE ABCREPORTS.RQS_REPORTS AS
-- ****************************************************************************
-- File:        rqs_reports_v2.pks  
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

PROCEDURE format_report(p_parms IN OUT t_parameters);

PROCEDURE get_unformated_report(p_seq         IN  NUMBER,
                                p_data        OUT SYS_REFCURSOR, 
                                p_status_msg  OUT VARCHAR2);

PROCEDURE get_status(p_job_id         IN  NUMBER,
                     p_data           OUT VARCHAR2, 
                     p_status_msg     OUT VARCHAR2);
                                                     
PROCEDURE upd_status(p_seq          IN NUMBER,
                     p_step         IN VARCHAR2,
                     p_ora_status   IN VARCHAR2,
                     p_web_status   IN VARCHAR2,
                     p_message      IN VARCHAR2);

PROCEDURE cancel_report(p_job_id  IN NUMBER);

PROCEDURE get_report_list(p_parameters IN  XMLTYPE,
                          p_data       OUT CLOB,
                          p_status_msg OUT VARCHAR2);
                     
PROCEDURE get_report(p_seq         IN  NUMBER,
                     p_data        OUT BLOB,
                     p_parameters  OUT VARCHAR2, -- output control parameters
                     p_data_format OUT VARCHAR2,
                     p_status_msg  OUT VARCHAR2);

PROCEDURE save_report(p_seq          IN  NUMBER,
                      p_data_format  IN  VARCHAR2,
                      p_report_data  IN  BLOB,
                      p_status_msg   OUT VARCHAR2);

PROCEDURE get_parameters(p_report_number    IN  NUMBER,
                         p_parameter_type   IN  VARCHAR2,
                         p_export_seq       IN  NUMBER,
                         p_data             OUT SYS_REFCURSOR,                             
                         p_status_msg       OUT VARCHAR2);
                         
PROCEDURE get_emailparameters(p_seq              IN  NUMBER,
                              p_report_process   IN  VARCHAR2,
                              p_report_number    IN  NUMBER,
                              p_officeobjectid   IN  NUMBER,
                              p_data             OUT VARCHAR2,                             
                              p_status_msg       OUT VARCHAR2);
 
 PROCEDURE get_control_parameter(p_userobjectid IN  NUMBER,
                                p_data         OUT VARCHAR2,
                                p_status_msg   OUT VARCHAR2);
                                
PROCEDURE upd_export_log(p_job_id       NUMBER,
                         p_seq          NUMBER,
                         p_url          VARCHAR2,
                         p_export_id    NUMBER,                      
                         p_status_ind   VARCHAR2,
                         p_response     VARCHAR2,
                         p_error_msg    VARCHAR2);

PROCEDURE upd_status(p_job_id       IN NUMBER,
                     p_finalize_id  IN NUMBER,
                     p_status       IN VARCHAR2,
                     p_msg          IN VARCHAR2);

                         
END RQS_REPORTS;
/


CREATE OR REPLACE PUBLIC SYNONYM RQS_REPORTS FOR ABCREPORTS.RQS_REPORTS;


GRANT EXECUTE ON ABCREPORTS.RQS_REPORTS TO ABCREPORTS_ROLE;

GRANT EXECUTE ON ABCREPORTS.RQS_REPORTS TO POSSEEXTENSIONS;
