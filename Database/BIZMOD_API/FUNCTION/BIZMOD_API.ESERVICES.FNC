CREATE OR REPLACE FUNCTION bizmod_api.eservices(a_packet IN CLOB)
    RETURN CLOB
IS
    -- ****************************************************************************
    -- File:        ESERVICES V2.FNC
    -- Author:      Timothy J. Lord
    --
    -- Purpose :
    --
    -- History:
    -------------------------------------------------------------------------------
    --    Date              Comment
    --  12/09/2022 TJL
    -- ****************************************************************************
    no_update      EXCEPTION;
    bad_json       EXCEPTION;
    t_response     CLOB;
    t_request      VARCHAR2(40);
    t_seq          NUMBER;
    t_msg          VARCHAR2(4000);
    t_sqlerrm      VARCHAR2(4000);
    t_trace        VARCHAR2(4000);
BEGIN
    INSERT INTO eservices_log_t(requestdate)
         VALUES (SYSTIMESTAMP)
      RETURNING seq
           INTO t_seq;

    IF (SQL%ROWCOUNT = 0)
    THEN
        RAISE no_update;
    END IF;

    COMMIT;

    SELECT json_value(a_packet, '$.PACKET_TYPE') INTO t_request FROM DUAL;

    -- ***********************************************************************
    -- Log the request
    -- ***********************************************************************
    UPDATE eservices_log_t
       SET request = t_request, packet = a_packet
     WHERE seq = t_seq
       LOG ERRORS INTO bizmod_api.err$_eservices_log_t
               ('UPDATE')
               REJECT LIMIT UNLIMITED;

    IF (SQL%ROWCOUNT = 0)
    THEN
        INSERT INTO err$_eservices_clob_t(seq, jsondata)
             VALUES (TO_CHAR(t_seq), a_packet);

        COMMIT;
        RAISE bad_json;
    END IF;

    COMMIT;

    -- ***********************************************************************
    --  Call the function to process the request
    -- ***********************************************************************
    EXECUTE IMMEDIATE 'BEGIN :a := ' || t_request || '(:b, :c); END;'
        USING OUT t_response, IN a_packet, IN t_seq;

    -- ***********************************************************************
    -- Log response
    -- ***********************************************************************
    UPDATE eservices_log_t
       SET response = t_response, responsedate = SYSTIMESTAMP
     WHERE seq = t_seq
       LOG ERRORS INTO bizmod_api.err$_eservices_log_t
               ('UPDATE')
               REJECT LIMIT UNLIMITED;

    IF (SQL%ROWCOUNT = 0)
    THEN
        INSERT INTO err$_eservices_clob_t(seq, jsondata)
             VALUES (TO_CHAR(t_seq), t_response);

        COMMIT;
        RAISE bad_json;
    END IF;

    COMMIT;

    RETURN t_response;
EXCEPTION
    WHEN no_update
    THEN
        RETURN json_object(
                   'PACKET_TYPE' VALUE 'MESSAGE',
                   'DATA' VALUE
                       json_object(
                           'MSGNO' VALUE '4',
                           'MSG' VALUE 'Database Not Available for Updating'));
    WHEN bad_json
    THEN
        UPDATE eservices_log_t
           SET err =
                   (SELECT ora_err_mesg$
                      FROM bizmod_api.err$_eservices_log_t
                     WHERE seq = t_seq)
         WHERE seq = t_seq;

        RETURN json_object(
                   'PACKET_TYPE' VALUE 'MESSAGE',
                   'DATA' VALUE
                       json_object('MSGNO' VALUE '11',
                                   'MSG' VALUE 'Invalid JSON'));
    WHEN OTHERS
    THEN
        t_sqlerrm := SQLERRM;
        t_trace := DBMS_UTILITY.format_error_backtrace;
        t_msg := SUBSTR(t_sqlerrm || ' :: ' || t_trace, 1, 3990);

        UPDATE eservices_log_t
           SET err = t_msg, responsedate = SYSTIMESTAMP
         WHERE seq = t_seq;

        COMMIT;

        RETURN json_object(
                   'PACKET_TYPE' VALUE 'MESSAGE',
                   'DATA' VALUE
                       json_object('MSGNO' VALUE '5',
                                   'MSG' VALUE 'Oracle Exception',
                                   'EXCEPTION' VALUE t_sqlerrm));
END eservices;
/