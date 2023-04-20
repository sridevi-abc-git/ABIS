CREATE OR REPLACE PACKAGE ABCLQS.LQS AS
-- ****************************************************************************
-- File:        LQS.pks
-- Author:      Timothy J. Lord
--
-- $Rev: 35 $  
-- $Date: 2018-08-22 12:47:57 -0700 (Wed, 22 Aug 2018) $
-- Last Changed By:  $Author: tlord $
--
-- Description:    
--
-- 
-- History:
-------------------------------------------------------------------------------
--    Date                      Comment
-- 06/06/2017 TJL   11670   Initial package created
-- 09/01/2017 TJL   11670   Header for version tracking 
-- ****************************************************************************

FUNCTION clob2blob( 
  p_clob IN CLOB
) 
RETURN BLOB;

PROCEDURE LISTS ( 
  p_parameter IN  NUMBER, 
  p_data      OUT SYS_REFCURSOR, 
  p_message   OUT VARCHAR
);

PROCEDURE MAIN ( 
  p_parameters IN  XMLTYPE, 
  p_reportdata OUT BLOB, 
  p_message    OUT VARCHAR
);

END LQS;
/
