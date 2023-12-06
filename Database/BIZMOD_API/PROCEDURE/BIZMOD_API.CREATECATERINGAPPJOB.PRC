CREATE OR REPLACE PROCEDURE BIZMOD_API.CREATECATERINGAPPJOB(a_seq IN NUMBER, a_asofdate IN DATE)
IS
    -- ****************************************************************************
    -- File:        BIZMOD_API.CREATECATERINGAPPJOB.PRC
    -- Author:      Joseph Stark
    --
    -- Purpose: Creates catering application in ABIS
    --
    -- History:
    -------------------------------------------------------------------------------
    --              Date           Ticket     Comment
    --   1.0     10/20/2023  JS  BIZ-12471    Initial process created
    --           12/06/2023 TJL  BIZ-12471    Added URL coding to call approiate LSP URL for database
    --                                          Added updating process log table
    --                                          Added exception handling for HTTP request failures
    -- ****************************************************************************
--************************
--Object Ids
--************************
  t_licobjid                       NUMBER(20);
  t_processid                      api.pkg_definition.udt_id;
  t_processdefid                   api.pkg_definition.udt_id;
  t_addressrelationship            api.pkg_definition.udt_id;
--*********
--Form Data
--*********
  t_packet                         CLOB;
  t_licensenumber                  VARCHAR2(20);
  t_lsppaymentid                   VARCHAR2(30);
  t_applicationid                  VARCHAR2(30);
  t_submitteddate                  DATE;
  t_cateringorevent                VARCHAR2(50):= '58 - Catering';
  t_dateofeventfrom                DATE;
  t_dateofeventto                  DATE;
  t_quantity                       NUMBER(4);
  t_publicevent                    VARCHAR2(5);
  t_withincitytimits               VARCHAR2(5);
  t_estimatedattendance            NUMBER(6);
  t_description                    VARCHAR2(4000);
  t_outcome                        VARCHAR2(40):= 'Create';
  t_eventstarttime                 VARCHAR2(40);
  t_beginservingalcoholampmtime    VARCHAR2(3);
  t_eventendtime                   VARCHAR2(40);
  t_stopservingalcoholampmtime     VARCHAR2(3);
  t_eventtype                      VARCHAR2(100);
  t_othereventtype                 VARCHAR2(100);
  t_sponsoringorganization         VARCHAR2(80);
  t_sponsoringorganizationmailing  VARCHAR2(80);
  t_sponsoringorganizationaddress1 VARCHAR2(80);
  t_sponsoringorganizationaddress2 VARCHAR2(80);
  t_sponsoringorganizationcity     VARCHAR2(80);
  t_sponsoringorganizationstate     VARCHAR2(80);
  t_sponsoringorganizationzip      VARCHAR2(10);
  t_personinchargeofevent          VARCHAR2(45);
  t_personinchargephonenumber      VARCHAR2(10);
  t_contactname                    VARCHAR2(45);
  t_contactphonenumber             VARCHAR2(10);
  t_contactemail                   VARCHAR2(45);
  t_eventlocationaddressline1      VARCHAR2(50);
  t_eventlocationaddressline2      VARCHAR2(50);
  t_eventlocationcity              VARCHAR2(50);
  t_eventlocationzip               VARCHAR2(10);
  t_specificLocation               VARCHAR2(80);
--*********
--Fee Data
--*********
  t_feeid                          NUMBER(20);
  t_feeobjid                       api.pkg_definition.udt_id;
  t_feetotal                       NUMBER(20);
  t_feedescription                 VARCHAR2(50);
  t_isscatobjid                    api.pkg_definition.udt_id;
--******************
--Address Object Ids
--******************
  t_cityobjectid                   api.pkg_definition.udt_id;
  t_cityendpointid                 api.pkg_definition.udt_id;
  t_addressobjectid                api.pkg_definition.udt_id;
  t_addrel                         api.pkg_definition.udt_id;
  t_cityrel                        api.pkg_definition.udt_id;
--*****
--Misc
--*****
  t_url                            VARCHAR2(1000)
        := '<<path>>/api/licensing/internal/catering/payments/<<lsppaymentid>>/fees'; -- TJL
  t_sqlerrm                        VARCHAR2(4000);
  t_trace                          VARCHAR2(4000);
  t_msg                            VARCHAR2(4000);
  t_results                        CLOB;
  t_response                       CLOB;
  t_output                         CLOB;
  t_count                          NUMBER;

BEGIN
--*****************
--Clear any errors
--*****************
  api.pkg_logicaltransactionupdate.resettransaction;
  ROLLBACK;

--***************
--Get data packet
--***************
SELECT PACKET
INTO t_packet
FROM BIZMOD_API.ESERVICES_LOG_T
WHERE SEQ = a_seq;

--**********************
--Extract data from JSON
--**********************

t_licensenumber:= JSON_VALUE(t_packet, '$.DATA.APPLICATION.LICENSENUMBER');
t_lsppaymentid:= JSON_VALUE(t_packet, '$.DATA.APPLICATION.LSPPAYMENTID');
t_applicationid:= JSON_VALUE(t_packet, '$.DATA.APPLICATION.APPLICATIONID');
t_dateofeventfrom:= TO_TIMESTAMP(JSON_VALUE(t_packet, '$.DATA.APPLICATION.EVENTSTARTDATE'), 'YYYY-MM-DD"T"HH24:MI:SS.ff3');
t_dateofeventto:= TO_TIMESTAMP(JSON_VALUE(t_packet, '$.DATA.APPLICATION.EVENTENDDATE'), 'YYYY-MM-DD"T"HH24:MI:SS.ff3');
t_eventstarttime:= TO_CHAR(TO_TIMESTAMP(JSON_VALUE(t_packet, '$.DATA.APPLICATION.EVENTSTARTTIME'), 'HH24:MI'), 'HH12MI');
t_beginservingalcoholampmtime:= TO_CHAR(TO_TIMESTAMP(JSON_VALUE(t_packet, '$.DATA.APPLICATION.EVENTSTARTTIME'), 'HH24:MI'), 'AM');
t_eventendtime:= TO_CHAR(TO_TIMESTAMP(JSON_VALUE(t_packet, '$.DATA.APPLICATION.EVENTENDTIME'), 'HH24:MI'), 'HH12MI');
t_stopservingalcoholampmtime:= TO_CHAR(TO_TIMESTAMP(JSON_VALUE(t_packet, '$.DATA.APPLICATION.EVENTENDTIME'), 'HH24:MI'), 'AM');
t_estimatedattendance:= JSON_VALUE(t_packet, '$.DATA.APPLICATION.EXPECTEDATTENDANCE');
t_publicevent:= JSON_VALUE(t_packet, '$.DATA.APPLICATION.PUBLICEVENT');
t_withincitytimits:= JSON_VALUE(t_packet, '$.DATA.APPLICATION.WITHINCITYLIMITS');
t_eventtype:= JSON_VALUE(t_packet, '$.DATA.APPLICATION.EVENTTYPE');
t_sponsoringorganization:= JSON_VALUE(t_packet, '$.DATA.APPLICATION.SPONSORINGORGANIZATION');
t_sponsoringorganizationaddress1:= JSON_VALUE(t_packet, '$.DATA.APPLICATION.SPONSORINGORGANIZATIONADDRESS1');
t_sponsoringorganizationaddress2:= JSON_VALUE(t_packet, '$.DATA.APPLICATION.SPONSORINGORGANIZATIONADDRESS2');
t_sponsoringorganizationcity:= JSON_VALUE(t_packet, '$.DATA.APPLICATION.SPONSORINGORGANIZATIONCITY');
t_sponsoringorganizationstate:= JSON_VALUE(t_packet, '$.DATA.APPLICATION.SPONSORINGORGANIZATIONSTATE');
t_sponsoringorganizationzip:= JSON_VALUE(t_packet, '$.DATA.APPLICATION.SPONSORINGORGANIZATIONZIP');
t_personinchargeofevent:= JSON_VALUE(t_packet, '$.DATA.APPLICATION.PERSONINCHARGEOFEVENT');
t_personinchargephonenumber:= REGEXP_REPLACE(JSON_VALUE(t_packet, '$.DATA.APPLICATION.PERSONINCHARGEPHONENUMBER'), '\D');
t_eventlocationaddressline1:= JSON_VALUE(t_packet, '$.DATA.APPLICATION.EVENTLOCATIONADDRESS1');
t_eventlocationaddressline2:= JSON_VALUE(t_packet, '$.DATA.APPLICATION.EVENTLOCATIONADDRESS2');
t_eventlocationcity:= JSON_VALUE(t_packet, '$.DATA.APPLICATION.EVENTLOCATIONCITY');
t_eventlocationzip:= JSON_VALUE(t_packet, '$.DATA.APPLICATION.EVENTLOCATIONZIP');
t_specificLocation:= JSON_VALUE(t_packet, '$.DATA.APPLICATION.SPECIFICLOCATION');
t_submitteddate:= TO_TIMESTAMP(JSON_VALUE(t_packet, '$.DATA.APPLICATION.SUBMITTEDDATE'), 'YYYY-MM-DD"T"HH24:MI:SS.ff3"Z"') - INTERVAL '8' HOUR;
t_quantity:= JSON_VALUE(t_packet, '$.DATA.APPLICATION.ANNUALEVENTSCOUNT');
--t_sponsoringorganizationmailing:= t_sponsoringorganizationaddress1 ||','|| t_sponsoringorganizationaddress2 ||','|| t_sponsoringorganizationcity ||','||t_sponsoringorganizationstate||','||t_sponsoringorganizationzip;
t_contactname:= JSON_VALUE(t_packet, '$.DATA.APPLICATION.CONTACTNAME');
t_contactphonenumber:= REGEXP_REPLACE(JSON_VALUE(t_packet, '$.DATA.APPLICATION.CONTACTPHONE'), '\D');
t_contactemail:= JSON_VALUE(t_packet, '$.DATA.APPLICATION.CONTACTEMAIL');

    -- 12/06/2023 TJL added updating url for different LSP environments
    t_url :=
        REPLACE(
            REPLACE(
                t_url,
                '<<path>>',
                CASE ora_database_name
                    WHEN 'ABISST1' THEN 'https://services-sb.abc.ca.gov'
                    WHEN 'ABISP1' THEN 'https://abcbiz.abc.ca.gov'
                    WHEN 'ABISQA1' THEN 'https://qa-01.abcbiz-qa.abc.ca.gov'
                    WHEN 'ABISD1' THEN 'https://qa-02.abcbiz-qa.abc.ca.gov'
                    ELSE 'https://unknown'
                END),
            '<<lsppaymentid>>',
            t_lsppaymentid);


--*************************
--Format Sponsoring Address
--*************************
IF (t_sponsoringorganizationaddress1 IS NULL)
THEN
t_sponsoringorganizationmailing:= NULL;
ELSE
t_sponsoringorganizationmailing:= t_sponsoringorganizationaddress1 ||','|| t_sponsoringorganizationaddress2 ||','|| t_sponsoringorganizationcity ||','||t_sponsoringorganizationstate||','||t_sponsoringorganizationzip;
END IF;

--*****************************
--Check for existing event type
--*****************************
SELECT COUNT(attributevalue)
INTO t_count
FROM api.domainlistofvalues
WHERE domainid = 305110
AND attributevalue = t_eventtype;
IF(t_count = 0)
THEN
  t_othereventtype:= t_eventtype;
  t_eventtype:='OTHER EVENT';
END IF;

--*********************
--Get or create address
--*********************
  BEGIN

  --**************************
  --Check for existing address
  --**************************

  SELECT objid
  INTO t_addressobjectid
  FROM(
    SELECT
      o.objectid objid,
      api.pkg_columnquery.VALUE(o.objectid, 'AddressLine2') addline2
    FROM TABLE(
      CAST(
        api.pkg_simplesearch.castableobjectsbyindex(
          a_objectdefname => 'o_Address',
          a_columnname => 'dup_UniqueAddress',
          a_value     => t_eventlocationaddressline1||'%'||t_eventlocationaddressline2||'%'||t_eventlocationcity||'%')
      AS api.udt_objectlist)) o)
  WHERE (addline2 IS NULL OR (addline2 = t_eventlocationaddressline2 AND t_eventlocationaddressline2 IS NOT NULL)) AND ROWNUM = 1;

    EXCEPTION 
      WHEN NO_DATA_FOUND THEN

    --******************
    --Get city object id
    --******************
      SELECT o.objectid
      INTO t_cityobjectid
      FROM TABLE(
      CAST(
        api.pkg_simplesearch.castableobjectsbyindex(
          a_objectdefname => 'o_CaCity',
          a_columnname => 'CityName',
          a_value     => t_eventlocationcity)
        AS api.udt_objectlist)) o;
      t_cityendpointid:= api.pkg_configquery.endpointidforname('o_Address','CACity');

    --******************
    --Create new address
    --******************
      t_addressobjectid:= api.pkg_objectupdate.new(api.pkg_configquery.objectdefidforname('o_Address'));

    --****************
    --Add address data
    --****************
      api.pkg_columnupdate.setvalue(t_addressobjectid, 'AddressLine1', t_eventlocationaddressline1);
      api.pkg_columnupdate.setvalue(t_addressobjectid, 'AddressLine2', t_eventlocationaddressline2);
      api.pkg_columnupdate.setvalue(t_addressobjectid, 'AddressLocation', 'In California');
      api.pkg_columnupdate.setvalue(t_addressobjectid, 'ZipCode', t_eventlocationzip);

    --***************************************************
    --Create relationship between address and city object
    --***************************************************
    t_cityrel:= api.pkg_relationshipupdate.new(
      a_EndPoint => t_cityendpointid, 
      a_FromObject => t_addressobjectid, 
      a_ToObject => t_cityobjectid);

    --*********
    --Save Data
    --*********
    api.pkg_logicaltransactionupdate.endtransaction;
    COMMIT;
  END;

--************************
--Get object id of license
--************************

  SELECT OBJECTID
  INTO t_licobjid
  FROM(
    SELECT 
      o.objectid,
      api.pkg_columnquery.VALUE(o.objectid, 'StatusName') Status,
      api.pkg_columnquery.VALUE(o.objectid, 'dup_SecondaryLTCodeWithCount') LicTypes
    FROM TABLE(
    CAST(
      api.pkg_simplesearch.castableobjectsbyindex(
        a_objectdefname => 'j_LicenseType',
        a_columnname => 'dup_LicenseExternalFileNum',
        a_value     => t_licensenumber)
    AS api.udt_objectlist)) o)
  WHERE STATUS = 'ACTIVE' AND LICTYPES LIKE '%58 (ACTIVE)%';

--**********************************
--Get id of p_CreateCatererEventAuth
--**********************************
  t_processdefid :=
    api.pkg_configquery.objectdefidforname(
      'p_CreateCatererEventAuth');

--*********************************
--Create new CreateCatererEventAuth
--*********************************
  t_processid :=
    api.pkg_processupdate.new(
      a_job       => t_licobjid,
      a_processtype => t_processdefid,
      a_description => 'Create Caterer Event Auth',
      a_scheduledstartdate => t_submitteddate,
      a_scheduledenddate => t_dateofeventfrom,
      a_actualstartdate => t_dateofeventfrom);

--*************************************
--Add data to to CreateCatererEventAuth
--*************************************
  api.pkg_columnupdate.setvalue(t_processid, 'CateringOrEvent', t_cateringorevent);
  api.pkg_columnupdate.setvalue(t_processid, 'DateOfEventFrom', t_dateofeventfrom);
  api.pkg_columnupdate.setvalue(t_processid, 'DateOfEventTo', t_dateofeventto);
  api.pkg_columnupdate.setvalue(t_processid, 'Quantity', t_quantity);
  api.pkg_columnupdate.setvalue(t_processid, 'PublicEvent', t_publicevent);
  api.pkg_columnupdate.setvalue(t_processid, 'EstimatedAttendance', t_estimatedattendance);
  api.pkg_columnupdate.setvalue(t_processid, 'Description', t_description);
  api.pkg_columnupdate.setvalue(t_processid, 'EventType', t_eventtype);
  api.pkg_columnupdate.setvalue(t_processid, 'OtherEventType', t_othereventtype);
  api.pkg_columnupdate.setvalue(t_processid, 'SponsoringOrganization', t_sponsoringorganization);
  api.pkg_columnupdate.setvalue(t_processid, 'SponsoringOrganizationMailing', t_sponsoringorganizationmailing);
  api.pkg_columnupdate.setvalue(t_processid, 'PersonInChargeOfEvent', t_personinchargeofevent);
  api.pkg_columnupdate.setvalue(t_processid, 'PersonInChargePhoneNumber', t_personinchargephonenumber);
  api.pkg_columnupdate.setvalue(t_processid, 'SpecificLocation', t_specificLocation);
  api.pkg_columnupdate.setvalue(t_processid, 'ScheduledStartDate', t_submitteddate);
  api.pkg_columnupdate.setvalue(t_processid, 'LSPId', t_applicationid);
  api.pkg_columnupdate.setvalue(t_processid, 'WithinCityLimits', t_withincitytimits);
  api.pkg_columnupdate.setvalue(t_processid, 'Timeyouwillbeginservingalcohol', t_eventstarttime);
  api.pkg_columnupdate.setvalue(t_processid, 'TimeYouWillStopServingAlcohol', t_eventendtime);
  api.pkg_columnupdate.setvalue(t_processid, 'BeginServingAlcoholAMPMTime', t_beginservingalcoholampmtime);
  api.pkg_columnupdate.setvalue(t_processid, 'StopServingAlcoholAMPMTime', t_stopservingalcoholampmtime);
  api.pkg_columnupdate.setvalue(t_processid, 'ContactName', t_contactname);
  api.pkg_columnupdate.setvalue(t_processid, 'ContactPhoneNumber', t_contactphonenumber);
  api.pkg_columnupdate.setvalue(t_processid, 'ContactEmail', t_contactemail);

--***************************
--Create address relationship
--***************************
  SELECT ENDPOINTID
  INTO t_addressrelationship
  FROM API.COLUMNDEFS
  WHERE OBJECTDEFNAME = 'p_CreateCatererEventAuth' AND NAME = 'EventLocationAddress4Lines';

  t_addrel:= api.pkg_relationshipupdate.new(
    a_EndPoint => t_addressrelationship, 
    a_FromObject => t_processid, 
    a_ToObject => t_addressobjectid);

--*********
--Save Data
--*********
  api.pkg_logicaltransactionupdate.endtransaction;
  COMMIT;

--*************
--Complete form
--*************
  DBMS_SESSION.sleep(3);
  api.pkg_columnupdate.setvalue(t_processid, 'Outcome', t_outcome);
  api.pkg_logicaltransactionupdate.endtransaction;
  COMMIT;


--*************************
--Retrieve fee information
--*************************
SELECT FEEID
INTO t_feeid
FROM API.FEES o 
JOIN api.processes p on p.LOGICALTRANSACTIONID = o.LOGICALTRANSACTIONID
WHERE p.processid = t_processid;

SELECT o.objectid
INTO t_feeobjid
FROM TABLE(
  CAST(
    api.pkg_simplesearch.castableobjectsbyindex(
      a_objectdefname => 'o_fee',
      a_columnname => 'feeid',
      a_value     => t_feeid)
    AS api.udt_objectlist)) o;

SELECT o.objectid
INTO t_isscatobjid
FROM TABLE(
  CAST(
    api.pkg_simplesearch.castableobjectsbyindex(
      a_objectdefname => 'p_IssueCatererEventAuth',
      a_columnname => 'LSPId',
      a_value     => t_applicationid)
  AS api.udt_objectlist)) o;

--**********************************
--Format data packet and use CallLSP
--**********************************
t_results := json_object('feeObjectId' VALUE t_feeobjid);

t_response:= bizmod_api.utl_licenseinfo.calllsp(a_seq, t_url, t_results);

    -- 12/06/2023 TJL add log update
    INSERT INTO bizmod_api.e_process_log_t(seq,
                                           processjob,
                                           info,
                                           errmsg,
                                           packet)
             VALUES (
                 a_seq,
                 'CREATECATERINGAPPJOB',
                 'Application Id: '
                 || t_applicationid
                 || CHR(13)
                 || 'p_IssueCatererEventAuth'
                 || t_isscatobjid
                 || CHR(13)
                 || 'URL: '
                 || t_url,
                 SUBSTR(t_response, 1, 3990),
                 t_results);

--********************
--Update eServices Log
--********************
UPDATE BIZMOD_API.ESERVICES_LOG_T
SET RESPONSE = t_results
WHERE SEQ = a_seq;
COMMIT;

--**************
--Error Handling
--**************
EXCEPTION
    -- 12/06/2023 TJL Added exception handling for HTTP failures and logging to 
    --  the process log table.
    WHEN UTL_HTTP.request_failed
    THEN
        t_sqlerrm :=
            'HTTP: ' || UTL_HTTP.get_detailed_sqlerrm || CHR(13) || SQLERRM;
        t_trace := DBMS_UTILITY.format_error_backtrace;

        INSERT INTO bizmod_api.e_process_log_t(seq,
                                               processjob,
                                               info,
                                               errmsg,
                                               bktrace)
                 VALUES (
                     a_seq,
                     'CREATECATERINGAPPJOB',
                     'Application Id: '
                     || t_applicationid
                     || CHR(13)
                 || 'p_IssueCatererEventAuth'
                 || t_isscatobjid
                 || CHR(13)
                 || 'URL: '
                 || t_url,
                     t_sqlerrm,
                     t_trace);

        UPDATE bizmod_api.eservices_log_t
           SET err = SUBSTR(t_sqlerrm || ' :: ' || t_trace, 1, 3990)
         WHERE seq = a_seq;

        COMMIT;
    WHEN OTHERS
    THEN
        t_sqlerrm := SQLERRM;
        t_trace := DBMS_UTILITY.format_error_backtrace;

        INSERT INTO bizmod_api.e_process_log_t(seq,
                                               processjob,
                                               info,
                                               errmsg,
                                               bktrace)
                 VALUES (
                     a_seq,
                     'CREATECATERINGAPPJOB',
                     'Application Id: '
                     || t_applicationid
                     || CHR(13)
                 || 'p_IssueCatererEventAuth'
                 || t_isscatobjid
                 || CHR(13)
                 || 'URL: '
                 || t_url,
                     t_sqlerrm,
                     t_trace);

        UPDATE bizmod_api.eservices_log_t
           SET err = SUBSTR(t_sqlerrm || ' :: ' || t_trace, 1, 3990)
         WHERE seq = a_seq;

  DBMS_SESSION.sleep(3);
        api.pkg_logicaltransactionupdate.endtransaction;
        COMMIT;

END;
/


GRANT EXECUTE ON BIZMOD_API.CREATECATERINGAPPJOB TO POSSEEXTENSIONS;
