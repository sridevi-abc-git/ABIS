CREATE OR REPLACE FUNCTION BIZMOD_API.requestvalidation(a_packet IN CLOB, a_seq IN NUMBER)
RETURN CLOB
IS

----------------------------------------------------------------------------



---03/21/2022- Function to Validate licnse number and validation code



----------------------------------------------------------------------------
BEGIN
DECLARE
-- *****************************************************************************



-- *****************************************************************************
t_licensenumber VARCHAR2(10);
t_validationcode VARCHAR2(10);
t_invalidmessage VARCHAR2(50);
t_code VARCHAR2(10);
t_createddate DATE;
t_msg VARCHAR2(4000 BYTE);
t_skip BOOLEAN := FALSE;
t_comma BOOLEAN := FALSE;
t_packet CLOB := EMPTY_CLOB();
t_sqlerrm VARCHAR2(4000);
t_trace VARCHAR2(4000);
BEGIN
SELECT json_value(a_packet, '$.*.LICENSENUMBER') INTO t_licensenumber FROM DUAL;
SELECT json_value(a_packet, '$.*.VALIDATIONCODE') INTO t_validationcode FROM DUAL;
-- get license type job id
-- dbms_output.put_line('ValidationCode: ' || a_packet);
FOR lic
IN (SELECT ROWNUM
line,
o.objectid
jobid, api.pkg_columnquery.VALUE(o.objectid, 'StatusName')
statusname,
api.pkg_columnquery.datevalue(o.objectid, 'dup_ExpirationDate')
expirationdate
FROM TABLE(
CAST(
api.pkg_simplesearch.castableobjectsbyindex(
a_objectdefname => 'j_LicenseType',
a_columnname => 'dup_LicenseExternalFileNum',
a_value => t_licensenumber) AS api.udt_objectlist)) o)
LOOP

select (api.pkg_columnquery.VALUE(r.licensejobid, 'ValidationCode') ) into t_code from query.r_LicenseLicenseType r where r.LICENSETYPEJOBID = lic.jobid;
dbms_output.put_line('ValidationCode: ' || t_code);
CONTINUE WHEN (t_code != t_validationcode);

select (api.pkg_columnquery.datevalue(r.licensejobid, 'ValidationCodeCreatedDate') ) into t_createddate from query.r_LicenseLicenseType r where r.LICENSETYPEJOBID = lic.jobid;


-- CONTINUE WHEN lic.expirationdate IS NULL;
---- if ((select (api.pkg_columnquery.VALUE(r.licensejobid, 'ValidationCode') )
-- from query.r_LicenseLicenseType r where r.LICENSETYPEJOBID = lic.jobid) != t_validationcode) THEN
-- t_invalidmessage := 'Invalid Validationcode' ;
-- CONTINUE ;
-- end if;




-- do not process license types that are not activie
CONTINUE WHEN lic.statusname NOT IN ('ACTIVE',
'REVPEN',
'SUREND',
'R64B',
'SLMSHD',
'SUSPEN');



dbms_output.put_line('object id: ' || lic.jobid);
IF (NOT t_skip) THEN
t_packet :=
t_packet
|| '{"PACKET_TYPE":"REQUESTVALIDATION",';
t_packet :=
t_packet
|| '"DATA":{';
t_packet :=
t_packet
|| '"LICENSEJOBID":"'
|| api.pkg_columnquery.VALUE(lic.jobid, 'LicenseJobId')
|| '",';
t_packet :=
t_packet
|| '"LICENSENUMBER":"'
|| t_licensenumber
|| '",';
t_packet :=
t_packet
|| '"VALIDATIONCODE":"'
|| t_code
|| '",';
t_packet :=
t_packet
|| '"CREATEDDATE":"'
|| t_createddate
|| '",';
t_packet :=
t_packet
|| '"STATUS":"'
|| api.pkg_columnquery.VALUE(lic.jobid, 'StatusName')
|| '"';

t_skip := TRUE;




END IF;



-- get latest renewal fees
END LOOP;



IF t_packet = EMPTY_CLOB() THEN
-- IF t_invalidmessage is null THEN
t_packet := '{"PACKET_TYPE":"MESSAGE","DATA":{"MSGNO":"6","MSG":"License Number Not Found or Invalid validation code"}}';
-- ELSE
-- t_packet := '{"PACKET_TYPE":"MESSAGE","DATA":{"MSGNO":"1","MSG":" '||t_invalidmessage||'"}}';
-- END IF;
ELSE
t_packet :=
t_packet
|| '}}';
END IF;



RETURN REGEXP_REPLACE(t_packet, '[[:cntrl:]]', '');
EXCEPTION
WHEN OTHERS THEN
t_sqlerrm := SQLERRM;
t_trace := DBMS_UTILITY.format_error_backtrace;
t_msg :=
SUBSTR( t_sqlerrm
|| ' :: '
|| t_trace,
1,
3990);



UPDATE eservices_log_t
SET err = t_msg
WHERE seq = a_seq;



COMMIT;
RETURN '{"PACKET_TYPE":"MESSAGE","DATA":{"MSGNO":"5","MSG":"Oracle Exception","EXCEPTION":"'
|| REGEXP_REPLACE(t_sqlerrm, '[^[:print:]]', '')
|| '"}}';
END;
END requestvalidation;
/
