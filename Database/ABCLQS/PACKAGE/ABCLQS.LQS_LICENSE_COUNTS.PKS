CREATE OR REPLACE PACKAGE ABCLQS.LQS_LICENSE_COUNTS AS
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
-- 
-- History:
-------------------------------------------------------------------------------
--    Date                      Comment
-- 10/10/2019 NW   Yearly   Refactored for ADA compliance, added as-of date parameter  
-- ****************************************************************************

PROCEDURE Wholesale_by_County	( 
  p_parameters IN  XMLTYPE, 
  p_reportdata OUT BLOB, 
  p_message    OUT VARCHAR
);

PROCEDURE STATE_TOTALS( 
  p_parameters IN  XMLTYPE, 
  p_reportdata OUT BLOB, 
  p_message    OUT VARCHAR
);

PROCEDURE RETAIL_BY_COUNTY( 
  p_parameters IN  XMLTYPE, 
  p_reportdata OUT BLOB, 
  p_message    OUT VARCHAR
);

PROCEDURE RETAIL_BY_GEOCODE( 
  p_parameters IN  XMLTYPE, 
  p_reportdata OUT BLOB, 
  p_message    OUT VARCHAR
);

END LQS_LICENSE_COUNTS;
/
