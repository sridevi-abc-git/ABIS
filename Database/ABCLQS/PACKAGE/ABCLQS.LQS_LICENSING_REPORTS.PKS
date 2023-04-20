CREATE OR REPLACE PACKAGE ABCLQS.LQS_LICENSING_REPORTS AS
-- ****************************************************************************
-- File:        LQS_LICENSING_REPORTS.pks        
-- Author:      Ning Wong
--
-- $Rev:  $  
-- $Date: 2019-08-28 12:47:57 -0700 (Wed, 28 Aug 2019) $
-- Last Changed By:  $Author: nwong $
--
-- Description: Weekly Finalized and Filed Legal Proceeding Reports   
--
-- 
-- History:
-------------------------------------------------------------------------------
--    Date                      Comment
-- 08/28/2019 NW   18927 Header for version tracking 
-- 09/26/2019 NW         Added Monthly Surrendered Licenses
-- 10/012019  NW         Added Licensed Importers Report
-- 11/20/2019 NW         Added List of dates for weekly Legal proceedings
-- ****************************************************************************

	PROCEDURE Finalized_Legal_Proceed
	( p_parameters IN  XMLTYPE
	, p_reportdata OUT BLOB
	, p_message    OUT VARCHAR);

	PROCEDURE Filed_Legal_Proceed
	( p_parameters IN  XMLTYPE
	, p_reportdata OUT BLOB
	, p_message    OUT VARCHAR);

	PROCEDURE Surrendered_Licenses
	( p_parameters IN  XMLTYPE
	, p_reportdata OUT BLOB
	, p_message    OUT VARCHAR);

	PROCEDURE Licensed_Importers
	( p_parameters IN  XMLTYPE
	, p_reportdata OUT BLOB
	, p_message    OUT VARCHAR);

	PROCEDURE Finalized_Legal_Date_List
	( p_parameters IN  XMLTYPE
	, p_reportdata OUT BLOB
	, p_message    OUT VARCHAR);

END LQS_LICENSING_REPORTS;
/
