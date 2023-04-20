CREATE OR REPLACE TYPE ABCREPORTS.t_parameters AS OBJECT
(
    recs    t_parameter_tbl, 
    
    CONSTRUCTOR FUNCTION t_parameters(p IN XMLTYPE) RETURN SELF AS RESULT,
    MEMBER FUNCTION  get_value(p_name  IN VARCHAR2) RETURN VARCHAR2,
    MEMBER PROCEDURE add_value(p_name  IN VARCHAR2,
                               p_value IN VARCHAR2),
    MEMBER PROCEDURE upd_value(p_name  IN VARCHAR2,
                               p_value IN VARCHAR2),
    MEMBER PROCEDURE del_value(p_name  IN VARCHAR2),
    MEMBER FUNCTION  get_xml RETURN VARCHAR2,
    MEMBER FUNCTION  get_json(p_escape IN BOOLEAN) RETURN VARCHAR2
);
/


CREATE OR REPLACE PUBLIC SYNONYM T_PARAMETERS FOR ABCREPORTS.T_PARAMETERS;
