CREATE OR REPLACE PACKAGE ABCLQS.LQS_REPORTS AS
-- ****************************************************************************
-- File:        LQS_REPORTS.pks        
-- Author:      Sheik Sulthan
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
-- 09/01/2017 TJL   11670   Header for version tracking 
-- ****************************************************************************

	PROCEDURE LQS_SEARCH_DAILY(p_parameters IN  XMLTYPE,
                                       p_reportdata OUT BLOB,
                                       p_message    OUT VARCHAR);
	FUNCTION clob2blob(p_clob IN CLOB) RETURN BLOB;			

	PROCEDURE LQS_SEARCH_ADHOC( p_parameters IN  XMLTYPE,
                                p_reportdata OUT BLOB,
                                p_message    OUT VARCHAR);

	PROCEDURE LQS_BusAddr(p_parameters IN  XMLTYPE,
	   p_reportdata OUT BLOB,
	   p_message    OUT VARCHAR);
	   
	PROCEDURE LQS_LicenseeOrCompany(p_parameters IN  XMLTYPE,
	   p_reportdata OUT BLOB,
	   p_message    OUT VARCHAR);	   
	   
	PROCEDURE LQS_DBA(p_parameters IN  XMLTYPE,
                                       p_reportdata OUT BLOB,
                                       p_message    OUT VARCHAR);	   

END LQS_REPORTS;
/
