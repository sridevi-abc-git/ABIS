CREATE OR REPLACE FUNCTION BIZMOD_API.changelicenseapp(
    a_packet       IN CLOB,
    a_seq          IN NUMBER)
    RETURN CLOB
IS
    -- ****************************************************************************
    -- File:        BIZMOD_API.CHANGELICENSEAPP.PRC
    -- Author:      Timothy J. Lord
    --
    -- Purpose :
    --
    -- History:
    -------------------------------------------------------------------------------
    --             Date                         Comment
    --   1.0.0  04/03/2025  TJL  BIZ-17503  Initial Package Created
    --   2.0.0  10/02/2025  TJL             Added check for duplicate applications and
    --                                        Fixed typo 
    -- ****************************************************************************
    t_json_obj     json_object_t := json_object_t();
    t_json_data    json_object_t := json_object_t();
    t_process      VARCHAR2(40) := 'CHANGELICENSEAPPJOB';
    t_lspid        number;
    t_count        number;
    t_packet       CLOB;
    t_sqlerrm      VARCHAR2(4000);
    t_trace        VARCHAR2(4000);
    t_msg          VARCHAR2(4000 BYTE);
BEGIN
    t_lspid := json_value(a_packet, '$.DATA.LSPAPPLICATIONID');

            SELECT COUNT(*)
            INTO t_count
            FROM bizmod_api.license_app_t la
            WHERE la.lspid = t_lspid;

            IF (t_count > 0)
            THEN
    t_json_data.put('MSGNO', '-1');
    t_json_data.put('MSG', 'Duplicate LSP Appication Id: ' || t_lspid);
    t_json_obj.put('PACKET_TYPE', 'MESSAGE');
    t_json_obj.put('DATA', t_json_data);
            else 

        
    bizmod_api.utl_licenseinfo.createjob(
        a_procedure => t_process,
        a_description => 'Change License Application LSP ID: ' || t_lspid,
        a_argument1 => a_seq);

    t_json_data.put('MSGNO', '0');
    t_json_data.put('MSG', 'E-Services ' || t_process || ' Scheduled');

    t_json_obj.put('PACKET_TYPE', 'MESSAGE');
    t_json_obj.put('DATA', t_json_data);
    bizmod_api.utl_licenseinfo.clean(a_json => t_json_obj);
    
            END IF;

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
