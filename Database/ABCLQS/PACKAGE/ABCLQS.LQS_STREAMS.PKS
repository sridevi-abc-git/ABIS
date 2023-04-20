CREATE OR REPLACE PACKAGE ABCLQS.LQS_STREAMS AS
-- ****************************************************************************
-- File:        LQS_LICENSE_COUNTS.pks        
-- Author:      Ning Wong
--
-- $Rev:  $  
-- $Date: $
-- Last Changed By:  $Author: nwong $
--
-- Description: License Count Reports (Formerly Yearly)   
--
-- Reports:
--  LICENSES_CSV
--  LICENSES_Fixed_Width
--  LQS_ADHOC
--
-- History:
-------------------------------------------------------------------------------
--    Date                      Comment
-- 11/12/2019   NW   Create License Extracts   
-- 12/10/2019   NW   Refactor LQS Adhoc
-- ****************************************************************************

PROCEDURE LICENSES_CSV ( 
  p_parameters IN  XMLTYPE,
  p_reportdata OUT BLOB,
  p_message    OUT VARCHAR
);


PROCEDURE LICENSES_Fixed_Width( 
  p_parameters IN  XMLTYPE,
  p_reportdata OUT BLOB,
  p_message    OUT VARCHAR
);

PROCEDURE LQS_ADHOC( 
  p_parameters IN  XMLTYPE, 
  p_reportdata OUT BLOB, 
  p_message    OUT VARCHAR
);

END LQS_STREAMS;
/
