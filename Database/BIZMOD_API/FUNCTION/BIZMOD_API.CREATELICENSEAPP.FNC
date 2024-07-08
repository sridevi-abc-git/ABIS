CREATE OR REPLACE FUNCTION BIZMOD_API.CREATELICENSEAPP(a_packet       IN CLOB,
                                                       a_seq          IN NUMBER)
        RETURN CLOB
    IS
    -- ****************************************************************************
    -- File:        BIZMOD_API.CREATELICENSEAPP.PRC
    -- Author:      Timothy J. Lord
    --
    -- Purpose :
    --
    -- History:
    -------------------------------------------------------------------------------
    --          Date                         Comment
    --   1.1  05/02/2024  TJL  BIZ-15804  Initial Package Created
    -- ****************************************************************************
    t_json_obj     json_object_t := json_object_t();
    t_json_arr     json_array_t := json_array_t();
    t_json_failure json_object_t := json_object_t();
    t_json_data    json_object_t := json_object_t();
    t_process      VARCHAR2(40) := 'CREATELICENSEAPP';
    t_packet       CLOB;
    t_sqlerrm      VARCHAR2(4000);
    t_trace        VARCHAR2(4000);
    t_msg          VARCHAR2(4000 BYTE);

BEGIN

    IF (t_json_arr.get_size() = 0)
    THEN
        bizmod_api.utl_licenseinfo.createjob(a_procedure => 'CREATELICENSEAPPJOB',
                             a_description => 'Create License Application',
                             a_argument1 => a_seq);

        t_json_data.put('MSGNO', '0');
        t_json_data.put('MSG', 'E-Services ' || t_process || ' Scheduled');
    ELSE
        t_msg :=
            'License Application Validation Failed: ('
            || a_seq
            || ') '
            || REPLACE(t_json_arr.TO_CLOB, '"', '');

        t_json_data.put('MSGNO', '17');
        t_json_data.put('MSG', t_msg);
    END IF;

    t_json_obj.put('PACKET_TYPE', 'MESSAGE');
    t_json_obj.put('DATA', t_json_data);
    utl_licenseinfo.clean(a_json => t_json_obj);

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
