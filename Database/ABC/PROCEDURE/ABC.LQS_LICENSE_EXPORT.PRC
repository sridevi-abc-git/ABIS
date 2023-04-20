CREATE OR REPLACE PROCEDURE ABC.LQS_LICENSE_EXPORT 
IS
BEGIN

DELETE FROM ABCLQS.ALL_LICENSES;
COMMIT;

INSERT INTO ABCLQS.ALL_LICENSES
SELECT
  license_type_code
, licenseno
, App_or_Lic
, Type_status_code
, Type_original_issue_date
, Next_issue_date
, Fee_code
, Duplicate_count
, Master_ind
, Term
, premgeocode
, officenumber
, PrimaryLicensee
, premaddressline1
, premaddressline2
, premcity
, premstate
, premzip
, PrimaryDBA
, mailaddressline1
, mailaddressline2
, mailcity
, mailstate
, mailzip
, PremCountyName
, PremCensusTract
, sysdate process_date
FROM ABC.RAWDATAEXTRACT_TYPE D
WHERE LICENSE_TYPE_CODE NOT BETWEEN '30' AND '39' 
AND UPPER(TYPE_STATUS_CODE) IN ('ACTIVE', 'SLMSHD', 'SUSPEN', 'REVPEN', 'SUREND', 'R64B', 'PEND','ISSUPD');

/*
INSERT INTO ABCLQS.REPORT_LOG ( PROCESS_DATE, LQS_REPORT_ID, REPORT_NAME) VALUES (SYSDATE,24,'LICENSES_CSV');--
INSERT INTO ABC.REPORT_LOG ( PROCESS_DATE, LQS_REPORT_ID, REPORT_NAME) VALUES (SYSDATE,24,'LICENSES_CSV');
*/

COMMIT;

END;
-- SELECT * FROM ABCLQS.ALL_LICENSES
--select * from abclqs.report_log; 
/*
EXEC LQS_LICENSE_EXPORT
SELECT * FROM ABCLQS.REPORT_LOG
*/
/
