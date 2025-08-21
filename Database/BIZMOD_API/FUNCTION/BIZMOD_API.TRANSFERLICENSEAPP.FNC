CREATE OR REPLACE FUNCTION BIZMOD_API.transferlicenseapp(
    a_packet       IN CLOB,
    a_seq          IN NUMBER)
    RETURN CLOB
IS
    -- ****************************************************************************
    -- File:        BIZMOD_API.TRANSFERLICENSEAPP.PRC
    -- Author:      Timothy J. Lord
    --
    -- Purpose :
    --
    -- History:
    -------------------------------------------------------------------------------
    --             Date                         Comment
    --   1.0.0  06/03/2025  TJL  BIZ-18536  Initial Package Created
    -- ****************************************************************************
    t_json_obj     json_object_t := json_object_t();
    t_json_data    json_object_t := json_object_t();
    t_process      VARCHAR2(40) := 'TRANSFERLICENSEAPPJOB';
    t_packet       CLOB;
    t_sqlerrm      VARCHAR2(4000);
    t_trace        VARCHAR2(4000);
    t_msg          VARCHAR2(4000 BYTE);
BEGIN
    bizmod_api.utl_licenseinfo.createjob(
        a_procedure => t_process,
        a_description => 'Transfer License Application',
        a_argument1 => a_seq);

    t_json_data.put('MSGNO', '0');
    t_json_data.put('MSG', 'E-Services ' || t_process || ' Scheduled');


    t_json_obj.put('PACKET_TYPE', 'MESSAGE');
    t_json_obj.put('DATA', t_json_data);
    bizmod_api.utl_licenseinfo.clean(a_json => t_json_obj);

    RETURN t_json_obj.TO_CLOB;
EXCEPTION
    WHEN OTHERS
    THEN
        t_sqlerrm := SQLERRM;
        t_trace := DBMS_UTILITY.format_error_backtrace;
        t_msg := SUBSTR(t_sqlerrm || CHR(13) || t_trace, 1, 3990);


        UPDATE bizmod_api.eservices_log_t
           SET err = t_msg
         WHERE seq = a_seq;

        COMMIT;

        t_packet :=
            json_object(
                'PACKET_TYPE' VALUE 'MESSAGE',
                'DATA' VALUE
                    json_object('MSGNO' VALUE 5,
                                'MSG' VALUE 'Oracle Exception',
                                'EXCEPTION' VALUE t_sqlerrm));

        RETURN t_packet;
END;
/
