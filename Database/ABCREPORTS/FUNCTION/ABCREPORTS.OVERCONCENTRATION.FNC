CREATE OR REPLACE FUNCTION ABCREPORTS.overconcentration(
	p_parms IN OUT 
	t_parameters, 
	p_status_ind IN OUT VARCHAR2
)
	RETURN BLOB
IS
    -- ****************************************************************************
    -- File:        OVERCONCENTRATION.FNC
    -- Author:      Timothy J. Lord
    --
    -- $Rev$
    -- $Date$
    -- Last Changed By:  $Author$
    --
    -- Description:
    --
    --
    -- History:
    -------------------------------------------------------------------------------
    --    Date                  Comment
    -- 01/28/2020 TJL   20244   Initial File created
    -- 09/23/2021 NW    26193   Census Tracrs for 2020 were redistricted by US Census Bureau
    -- 02/24/2022 NW    27566   San Joaquin tract 52.18 doesn't appear because it is a new tract
    -- 03/08/2022 NW            Show zeros instead of blanks
    -- ****************************************************************************

CURSOR querySummary(
	p_county       IN VARCHAR2,
	p_censustract  IN VARCHAR2
)
IS
WITH lic AS(  
	SELECT
    (
      SELECT countyname
      FROM mart.cacounty
      WHERE countycode = lt.premaddresscountycode
    ) countyname,
    LT2.licensecensustract	censustract,
    COUNT(
      DISTINCT CASE
      WHEN lt.licensetypecode NOT IN ('20', '21', '85') THEN lt.licensejobid
      ELSE NULL
      END
    ) onsaleexisting,
    COUNT(
      DISTINCT CASE
      WHEN lt.licensetypecode IN ('20', '21', '85') THEN lt.licensejobid
      ELSE NULL
      END
    )offsaleexisting
	FROM mart.licensetype lt
	JOIN QUERY.J_LICENSETYPE LT2 ON LT2.OBJECTID = lt.OBJECTID
	WHERE lt.licensetypecode IN (
		'20',	'21', '85',
		'40',	'41',	'42',	'47',	'48',	'49',
		'50',	'51',	'52',	'57',	'59',
		'60',	'61',	'63',	'64',	'65',	'67',	'69',
		'70',	'71',	'72',	'75',	'76',	'78',
		'80',	'83', '87',	'88',
		'99'
	)
	AND (
		( lt.conda = 'N' AND 
			lt.licensetypecode IN ('47', '48')
		)
		OR (
			lt.condg = 'N' AND 
			lt.licensetypecode IN ('20', '21', '85')
		)
		OR (
			lt.licensetypecode NOT IN (
				'47',
				'48',
				'20',
				'21',
				'85'
			)
		)
	)
	AND lt.statusname IN (
		'ACTIVE',
		'SUREND',
		'SUSPEN',
		'R64B',
		'SLMSHD',
		'REVPEN'
	)
	AND TO_CHAR(lt2.licensecensustract, 'FM000000.00') = TO_CHAR(NVL(p_censustract, lt2.licensecensustract), 'FM000000.00')
	AND lt.premaddresscountycode = NVL(p_county, lt.premaddresscountycode)
	GROUP BY lt.premaddresscountycode, lt2.licensecensustract
) -- LIC
SELECT 
	C.countyname,
	C.censustract,
	C.onsaleallow,
	NVL(L.onsaleexisting,0) onsaleexisting,
	C.offsaleallow,
	NVL(L.offsaleexisting,0) offsaleexisting

FROM abcreports.censustract C 
LEFT JOIN lic L ON L.countyname = C.countyname AND L.censustract = C.censustract
WHERE C.COUNTYCODE = NVL(p_county, C.COUNTYCODE)
  AND C.CENSUSTRACT = NVL(p_censustract, C.CENSUSTRACT)

-- Add this union for licenses we have but not listed in the censustract table from US Census Bureau
UNION
SELECT 
	l.countyname,
	l.censustract,
	c.onsaleallow,
	l.onsaleexisting,
	c.offsaleallow,
	l.offsaleexisting
FROM lic l
LEFT JOIN CensusTract C	ON C.countyname = L.countyname AND C.censustract = L.censustract
WHERE C.countyname IS NULL 
ORDER BY 1, 2;


------------------------------------------------------------------------------------------------
CURSOR queryDetail(
------------------------------------------------------------------------------------------------

	p_county       IN VARCHAR2,
	p_censustract  IN VARCHAR2
)
IS
WITH lic AS (  
	SELECT 
    (
      SELECT countyname
      FROM mart.cacounty
      WHERE countycode = lt.premaddresscountycode
    )	countyname,
    lt2.licensecensustract censustract,
    CASE 
    WHEN lt.licensetypecode NOT IN ('20', '21', '85') THEN 'On Sale' 
    ELSE 'Off Sale' 
    END onsaleoffsale,
    lt.licensenumber,
    lt.licensetypecode,
    lt.statusname,
    lt.primarylicensee,
    lt.premaddress1stof2lines || ' ' || lt.premaddress2ndof2lines PremiseAddress
	FROM mart.licensetype lt
	JOIN QUERY.J_LICENSETYPE LT2 ON LT2.OBJECTID = lt.OBJECTID
	WHERE lt.licensetypecode IN (
		'40',	'41',	'42',	'47',	'48',	'49',
		'50',	'51',	'52',	'57',	'59',
		'60',	'61',	'63',	'64',	'65',	'67',	'69',
		'70',	'71',	'72',	'75',	'76',	'78',
		'80',	'83',	'87',	'88',
		'99',
		'20', '21',
		'85'
	)
	AND (
		(
			lt.conda = 'N'	AND 
			lt.licensetypecode IN ('47', '48')
		)
		OR (
			lt.condg = 'N' AND lt.licensetypecode IN ('20', '21', '85')
		)
		OR (
			lt.licensetypecode NOT IN (
				'47',	'48',
				'20',	'21',
				'85'
			)
		)
	)
	AND lt.statusname IN (
		'ACTIVE',
		'SUREND',
		'SUSPEN',
		'R64B',
		'SLMSHD',
		'REVPEN'
	)
	AND TO_CHAR(lt2.licensecensustract, 'FM000000.00') = TO_CHAR(NVL(p_censustract, lt2.licensecensustract), 'FM000000.00')
  AND lt.premaddresscountycode = NVL(p_county, lt.premaddresscountycode)
	ORDER BY lt.premaddresscountycode, lt2.licensecensustract
)
SELECT 
	l.countyname,
	l.censustract,
	c.onsaleallow,
	c.offsaleallow,
	l.onsaleoffsale,
	l.licensenumber,
	l.licensetypecode,
	l.statusname,
	l.primarylicensee,
	l.PremiseAddress                 
FROM lic l
-- nw WO 26193
-- JOIN abcreports.censustract c ON l.countyname = c.countyname AND	l.censustract = c.censustract
LEFT JOIN abcreports.censustract c ON l.countyname = c.countyname AND	l.censustract = c.censustract

ORDER BY l.countyname, l.censustract, l.onsaleoffsale desc, l.licensenumber;

lblob_csv        BLOB;
lv_csv_row       VARCHAR2(8096);
lv_report_name   VARCHAR(150) := p_parms.get_value('REPORT_NAME');

BEGIN
--    rqs_utils.LOG(p_log_type  => 'T',
--                  p_job_id    => p_parms.get_value('JOB_ID'),
--                  p_seq       => p_parms.get_value('SEQ'),
--                  p_source    => 'OVERCONCENTRATION',
--                  p_msg       => 'Starting Over Concentration (Summary)',
--                  p_additional_data =>   'County: '
--                                      || p_parms.get_value('COUNTIES')
--                                      || '  Censustract: '
--                                      || p_parms.get_value('CENSUSTRACT'));
--
DBMS_LOB.createtemporary(lblob_csv, TRUE, DBMS_LOB.call);

p_parms.upd_value('REPORT_DATE', TO_CHAR(SYSDATE, 'MM/DD/YYYY HH:MI PM'));

IF (UPPER(lv_report_name) = 'OVER-CONCENTRATION (SUMMARY)') THEN
	FOR rec IN querysummary(p_parms.get_value('COUNTIES'), p_parms.get_value('CENSUSTRACT'))
	LOOP
		lv_csv_row   :=
			'"'
			|| rec.countyname
			|| '",'
			|| rec.censustract
			|| ','
			|| rec.onsaleallow
			|| ','
			|| rec.onsaleexisting
			|| ','
			|| rec.offsaleallow
			|| ','
			|| rec.offsaleexisting
			|| CHR(13)
			|| CHR(10);
		DBMS_LOB.append(lblob_csv, UTL_RAW.cast_to_raw(lv_csv_row));
	END LOOP;
ELSE
	FOR rec IN querydetail(p_parms.get_value('COUNTIES'), p_parms.get_value('CENSUSTRACT'))
	LOOP
		lv_csv_row   :=
		'"'
		|| rec.countyname
		|| '",'
		|| rec.censustract
		|| ','
		|| rec.onsaleallow
		|| ','
		|| rec.offsaleallow
		|| ',"'
		|| rec.onsaleoffsale
		|| '","'
		|| rec.licensenumber
		|| '","'
		|| rec.licensetypecode
		|| '","'
		|| rec.statusname
		|| '","'
		|| REGEXP_REPLACE(rec.primarylicensee, '[[:cntrl:]]', ' ') 
		|| '","'
		|| REGEXP_REPLACE(rec.PremiseAddress, '[[:cntrl:]]', ' ')                 
		|| '"'
		|| CHR(13)
		|| CHR(10);
		DBMS_LOB.append(lblob_csv, UTL_RAW.cast_to_raw(lv_csv_row));
	END LOOP;
END IF;

RETURN lblob_csv;
EXCEPTION
WHEN OTHERS THEN
	rqs_utils.LOG(
		p_log_type  => 'E',
		p_job_id    => p_parms.get_value('JOB_ID'),
		p_seq       => p_parms.get_value('SEQ'),
		p_source    => 'OVERCONCENTRATION',
		p_msg       => SQLERRM,
		p_additional_data => NULL,
		p_error_trace => DBMS_UTILITY.format_error_backtrace
	);

	p_status_ind   := 'E';
RETURN UTL_RAW.cast_to_raw(   'ERROR: '
|| SQLERRM
|| CHR(10)
|| CHR(13)
|| 'TRACE: '
|| DBMS_UTILITY.format_error_backtrace);
END overconcentration;
/
