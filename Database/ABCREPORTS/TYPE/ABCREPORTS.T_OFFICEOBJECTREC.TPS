CREATE OR REPLACE TYPE ABCREPORTS.t_officeobjectrec AS OBJECT
(
    officeobjectid NUMBER,
    officename     VARCHAR2(100),
    officecode     VARCHAR2(3),

    CONSTRUCTOR FUNCTION t_officeobjectrec(p_officeobjectid IN NUMBER) RETURN SELF AS RESULT
);
/
