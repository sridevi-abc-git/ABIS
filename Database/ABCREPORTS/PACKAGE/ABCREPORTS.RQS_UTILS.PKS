CREATE OR REPLACE PACKAGE ABCREPORTS.RQS_UTILS AS
-- ****************************************************************************
-- File:        rqs_utils_v2.pks  
-- Author:      Timothy J. Lord
--
-- $Rev: 196 $  
-- $Date: 2019-01-10 09:00:28 -0800 (Thu, 10 Jan 2019) $
-- Last Changed By:  $Author: tlord $
--
-- Description: RQS_UTILS package specifications   
--
-- 
-- History:
-------------------------------------------------------------------------------
--    Date                  Comment
-- 09/16/2015 TJL       Initial File created  
-- ****************************************************************************

TYPE t_parms_tbl IS TABLE OF VARCHAR2(4000) INDEX BY VARCHAR2(100);

FUNCTION BuildOfficeList(p_office_object_id IN     NUMBER,
                         p_status_msg       IN OUT VARCHAR2) 
             RETURN t_officeobject;

FUNCTION BuildOfficeCodeList(p_office IN VARCHAR2) 
             RETURN t_officeobject;
                   
PROCEDURE log(p_log_type          IN  VARCHAR2,
              p_job_id            IN  VARCHAR2,
              p_seq               IN  VARCHAR2,
              p_source            IN  VARCHAR2,
              p_msg               IN  VARCHAR2,
              p_additional_data   IN  VARCHAR2 := NULL,
              p_error_trace       IN  VARCHAR2 := NULL);
                  
FUNCTION get_ctrl_value(p_name IN VARCHAR2) RETURN VARCHAR2;                  

FUNCTION officelist(p_userobjectid IN NUMBER) RETURN VARCHAR2;

FUNCTION countylist RETURN VARCHAR2;

FUNCTION cursor_to_xml (p_cursor        IN     SYS_REFCURSOR,
                        p_rowset_name   IN     VARCHAR2,
                        p_row_name      IN     VARCHAR2,
                        p_status_msg    IN OUT VARCHAR2) RETURN XMLTYPE;
                        
PROCEDURE userinfo(p_oracleLogonId  IN  VARCHAR2,
                   p_connection     IN  VARCHAR2,
                   p_data           OUT VARCHAR2,
                   p_status_msg     OUT VARCHAR2);

PROCEDURE search(p_search        IN  XMLTYPE,
                 p_data          OUT SYS_REFCURSOR,
                 p_status_msg    OUT VARCHAR2);

PROCEDURE available_reports(p_userobjectid  IN  NUMBER,
                            p_data          OUT SYS_REFCURSOR,
                            p_status_msg    OUT VARCHAR2);


PROCEDURE upduser(p_userobjectid  IN  NUMBER,
                  p_user_role     IN  VARCHAR2,
                  p_report_list   IN  XMLTYPE,
                  p_status_msg    OUT VARCHAR2,
                  p_return_code   OUT NUMBER);
                                                                 
FUNCTION report_info_json(p_report_number IN NUMBER) RETURN VARCHAR2;

PROCEDURE GetSocketInfo(p_data OUT NUMBER);

FUNCTION clob2blob(p_clob IN CLOB) RETURN BLOB;
                                                                                                                                                                                                 
END RQS_UTILS;
/


CREATE OR REPLACE PUBLIC SYNONYM RQS_UTILS FOR ABCREPORTS.RQS_UTILS;


GRANT EXECUTE ON ABCREPORTS.RQS_UTILS TO ABCREPORTS_ROLE;
