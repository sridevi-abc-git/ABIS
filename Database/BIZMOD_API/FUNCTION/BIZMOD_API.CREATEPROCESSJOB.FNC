CREATE OR REPLACE FUNCTION BIZMOD_API.createprocessjob(
    a_packet       IN CLOB,
    a_seq          IN NUMBER)
    RETURN CLOB
IS
    -- ****************************************************************************
    -- File:        BIZMOD_API.CREATEPROCESSJOB.FNC
    -- Author:      Timothy J. Lord
    --
    -- Purpose :
    --
    -- History:
    -------------------------------------------------------------------------------
    --    Ver:     Date                       Comment
    --    1.0   09/12/2023  TJL BIZ-12467   Initial Function Created
    --    2.0   08/08/2024  TJL BIZ-16000   Change to new createjob procedure
    -- ****************************************************************************
    t_process      VARCHAR2(40);
BEGIN
    SELECT json_value(a_packet, '$.PROCESS') INTO t_process FROM DUAL;


    bizmod_api.utl_licenseinfo.createjob(a_procedure => t_process,
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
