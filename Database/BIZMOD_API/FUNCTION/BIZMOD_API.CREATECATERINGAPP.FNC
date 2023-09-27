CREATE OR REPLACE FUNCTION BIZMOD_API.createcateringapp(
    a_packet       IN CLOB,
    a_seq          IN NUMBER)
    RETURN CLOB
IS
    -- ****************************************************************************
    -- File:        BIZMOD_API.CREATECATERINGAPP.FNC
    -- Author:      Timothy J. Lord
    --
    -- Purpose :
    --
    -- History:
    -------------------------------------------------------------------------------
    --    Ver:     Date                       Comment
    --    1.0   09/12/2023  TJL BIZ-12467   Initial Function Created
    -- ****************************************************************************
    t_process      VARCHAR2(40);
BEGIN
    FOR rec
        IN (SELECT *
              FROM JSON_TABLE(
                       a_packet,
                       '$'
                       COLUMNS(
                           packet_type VARCHAR2(1000) PATH '$.PACKET_TYPE',
                           NESTED PATH '$.DATA[*]'
                               COLUMNS(
                                   applicationtype VARCHAR2(4000)
                                       PATH '$.APPLICATIONTYPE',
                                   lsppaymentid VARCHAR2(4000)
                                       PATH '$.LSPPAYMENTID',
                                   licensenumber VARCHAR2(4000)
                                       PATH '$.LICENSENUMBER',
                                   applicationid VARCHAR2(4000)
                                       PATH '$.APPLICATIONID',
                                   eventstartdate DATE
                                       PATH '$.EVENTSTARTDATE',
                                   eventenddate DATE PATH '$.EVENTENDDATE',
                                   eventstarttime NUMBER
                                       PATH '$.EVENTSTARTTIME',
                                   eventendtime NUMBER PATH '$.EVENTENDTIME',
                                   expectedattendance NUMBER
                                       PATH '$.EXPECTEDATTENDANCE',
                                   publicevent VARCHAR2(4000)
                                       PATH '$.PUBLICEVENT',
                                   eventtype VARCHAR2(4000)
                                       PATH '$.EVENTTYPE',
                                   sponsoringorganization VARCHAR2(4000)
                                       PATH '$.SPONSORINGORGANIZATION',
                                   sponsoringorganizationaddress1 VARCHAR2(4000)
                                       PATH '$.SPONSORINGORGANIZATIONADDRESS1',
                                   sponsoringorganizationaddress2 VARCHAR2(4000)
                                       PATH '$.SPONSORINGORGANIZATIONADDRESS2',
                                   sponsoringorganizationcity VARCHAR2(4000)
                                       PATH '$.SPONSORINGORGANIZATIONCITY',
                                   sponsoringorganizationzip VARCHAR2(4000)
                                       PATH '$.SPONSORINGORGANIZATIONZIP',
                                   personinchargeofevent VARCHAR2(4000)
                                       PATH '$.PERSONINCHARGEOFEVENT',
                                   personinchargephonenumber VARCHAR2(4000)
                                       PATH '$.PERSONINCHARGEPHONENUMBER',
                                   eventlocationaddress1 VARCHAR2(4000)
                                       PATH '$.EVENTLOCATIONADDRESS1',
                                   eventlocationaddress2 VARCHAR2(4000)
                                       PATH '$.EVENTLOCATIONADDRESS2',
                                   eventlocationcity VARCHAR2(4000)
                                       PATH '$.EVENTLOCATIONCITY',
                                   eventlocationzip VARCHAR2(4000)
                                       PATH '$.EVENTLOCATIONZIP',
                                   specificlocation VARCHAR2(4000)
                                       PATH '$.SPECIFICLOCATION',
                                   totalamountdue NUMBER
                                       PATH '$.TOTALAMOUNTDUE',
                                   submitteddate DATE PATH '$.SUBMITTEDDATE'))))
    LOOP
        NULL;
    END LOOP;

    bizmod_api.createjob(a_procedure => t_process,
                         a_description => t_process,
                         a_argument1 => a_seq);

    RETURN json_object(
               'PACKET_TYPE' VALUE 'MESSAGE',
               'DATA' VALUE
                   json_object(
                       'MSGNO' VALUE '0',
                       'MSG' VALUE 'E-Services ' || t_process || ' Scheduled'));
END;
/
