CREATE OR REPLACE PROCEDURE ABC.LQS_SEARCH_ADHOC
-----------------------------------------------------------
( p_parameters IN  XMLTYPE
, p_reportdata OUT BLOB
, p_message    OUT VARCHAR )
IS
	CURSOR cur_parameters(p_data IN XMLTYPE) IS
	SELECT 
		rpttype,
		city, 
		license_type,
		county,
		census_tract,
		zipcode,
		Statewide
	FROM XMLTable('/*' 
		PASSING p_data
		COLUMNS
		rpttype      		VARCHAR2(10)    PATH 'RPTTYPE',
		city           	VARCHAR2(4000)  PATH 'CITY',
		license_type   	VARCHAR2(10) 	  PATH 'LICENSETYPE',
		county					VARCHAR2(4000)  PATH 'COUNTY',
		census_tract		VARCHAR2(10)   	PATH 'CENSUS',
		zipcode					VARCHAR2(10)		PATH 'ZIPCODE',
		statewide				VARCHAR2(10) 		PATH 'STATEWIDE'
	);    

	rec_parameters    cur_parameters%ROWTYPE;

	cur_recs        	SYS_REFCURSOR;
	lxml_pi         	XMLTYPE;
	retval          	XMLTYPE := xmltype('<ROOT></ROOT>');
	ctx             	dbms_xmlgen.ctxHandle;

BEGIN    

-- By City
-- By County
-- By Census Tract
-- By County and Census Tract
-- By Zip Code
-- Statewide

  NULL;
END;
/
