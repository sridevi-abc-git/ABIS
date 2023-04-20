CREATE OR REPLACE TYPE BODY ABCREPORTS.t_officeobjectrec AS
        CONSTRUCTOR FUNCTION t_officeobjectrec(p_officeobjectid IN NUMBER) RETURN SELF AS RESULT
    AS
 BEGIN
    SELECT o.objectid, o.officename, o.officecode
      INTO officeobjectid, officename, officecode
      FROM query.o_office o
     WHERE o.objectid = p_officeobjectid;

    RETURN;
 END;
END;
/
