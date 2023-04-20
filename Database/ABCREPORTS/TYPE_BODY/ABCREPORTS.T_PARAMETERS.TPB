CREATE OR REPLACE TYPE BODY ABCREPORTS.t_parameters IS
    CONSTRUCTOR FUNCTION t_parameters(p IN XMLTYPE) RETURN SELF AS RESULT
            IS

    BEGIN
        recs := t_parameter_tbl();
        SELECT t_parameter_rec (VALUE(t).getrootelement(),
                                EXTRACT(VALUE(t), '*/text()'))
          BULK COLLECT INTO recs
          FROM XMLTABLE('/*/*' PASSING p) t;
    
        RETURN;
    END;

    MEMBER FUNCTION get_value(p_name IN VARCHAR2) RETURN VARCHAR2
            IS
    val  VARCHAR2(4000) := NULL;

    BEGIN
        FOR inx IN recs.FIRST .. recs.LAST
        LOOP
            IF (UPPER(recs(inx).parameter_name) = UPPER(p_name)) THEN
                val := recs(inx).parameter_value;
                IF (LENGTH(val) = 0) THEN val := NULL; END IF;                
                EXIT;
            END IF;
        END LOOP;

        RETURN val;
    END;

   MEMBER PROCEDURE add_value(p_name  IN VARCHAR2,
                              p_value IN VARCHAR2)
   IS

   BEGIN
        recs.EXTEND(1);
        recs(recs.COUNT) := t_parameter_rec(p_name, p_value);
   END;

    MEMBER PROCEDURE upd_value(p_name  IN VARCHAR2,
                               p_value IN VARCHAR2)
            IS
    lb_found    BOOLEAN := FALSE;
                
    BEGIN
        FOR inx IN recs.FIRST .. recs.LAST
        LOOP
            IF (UPPER(recs(inx).parameter_name) = UPPER(p_name)) THEN
                recs(inx).parameter_value := p_value;
                lb_found := TRUE;
                EXIT;
            END IF;
        END LOOP;
        
        IF (NOT lb_found) THEN
            add_value(p_name, p_value); 
        END IF;
    END;

                               
    MEMBER PROCEDURE del_value(p_name  IN VARCHAR2)
            IS
    BEGIN
        FOR inx IN recs.FIRST .. recs.LAST
        LOOP
            IF (UPPER(recs(inx).parameter_name) = UPPER(p_name)) THEN
--                recs.DELETE(inx);
                recs(inx).parameter_value := NULL;                  
                EXIT;
            END IF;
        END LOOP;
    END;

    MEMBER FUNCTION get_xml RETURN VARCHAR2 IS
    
    lxml        XMLTYPE;
    
    BEGIN
         SELECT XMLELEMENT("ROOT",
            XMLAGG(
                XMLELEMENT(EVALNAME(parameter_name), parameter_value)
                )
            )
         INTO lxml   
         FROM TABLE(recs) WHERE parameter_value IS NOT NULL;
    
        return lxml.GETSTRINGVAL();
    END;

    MEMBER FUNCTION  get_json(p_escape IN BOOLEAN) RETURN VARCHAR2 IS
    
    ljson       VARCHAR(32000);
    
    BEGIN
        IF (p_escape) THEN
            SELECT '{' || LISTAGG('\"' || parameter_name || '\":\"' || REPLACE(parameter_value, '"', '\"') || '\"', ',')
              WITHIN GROUP (ORDER BY parameter_name, parameter_value) || '}'
              INTO ljson
              FROM TABLE(recs) WHERE parameter_value IS NOT NULL;
        ELSE
        SELECT '{' || LISTAGG('"' || parameter_name || '":"' || REPLACE(parameter_value, '"', '\"') || '"', ',')
              WITHIN GROUP (ORDER BY parameter_name, parameter_value) || '}'
              INTO ljson
              FROM TABLE(recs) WHERE parameter_value IS NOT NULL;
        END IF;          
        RETURN ljson;    
    END;
END;
/


CREATE OR REPLACE PUBLIC SYNONYM T_PARAMETERS FOR ABCREPORTS.T_PARAMETERS;
