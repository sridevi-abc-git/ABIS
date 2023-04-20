CREATE OR REPLACE TYPE ABCREPORTS.t_parameter_rec AS OBJECT
(
  parameter_name     VARCHAR2( 500 BYTE),
  parameter_value    VARCHAR2(4000 BYTE)
);
/
