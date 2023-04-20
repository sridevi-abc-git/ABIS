CREATE OR REPLACE PACKAGE ABCLQS.PP_STREAMS AS
-- ****************************************************************************
-- File:        PP_STREAMS.pks        
-- Author:      Ning Wong
--
-- $Rev:  $  
-- $Date: $
-- Last Changed By:  $Author: nwong $
--
-- Description: Price Posting Extracts
--
-- Reports:
--  LEGAL_ENTITY_CSV
--
-- History:
-------------------------------------------------------------------------------
--    Date                      Comment
-- 02/27/2020   NW   Add Price Posting Legal Entities CSV Extract (Report 27)
-- ****************************************************************************

PROCEDURE LEGAL_ENTITY_CSV ( 
  p_parameters IN  XMLTYPE, 
  p_reportdata OUT BLOB, 
  p_message    OUT VARCHAR
);

PROCEDURE LEGAL_ENTITY_XML ( 
  p_parameters IN  XMLTYPE, 
  p_reportdata OUT BLOB, 
  p_message    OUT VARCHAR
);

END PP_STREAMS;
/
