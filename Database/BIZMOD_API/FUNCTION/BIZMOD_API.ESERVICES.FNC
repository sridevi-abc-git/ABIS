CREATE OR REPLACE FUNCTION BIZMOD_API.eservices(a_packet IN CLOB)
    RETURN CLOB
IS
    no_update    EXCEPTION;
    t_response   CLOB;
    t_request    VARCHAR2(40);
    t_seq        NUMBER;
    t_msg        VARCHAR2(4000);
    t_sqlerrm    VARCHAR2(4000);
    t_trace      VARCHAR2(4000);
BEGIN
    INSERT INTO eservices_log_t(requestdate)
         VALUES (SYSTIMESTAMP)
      RETURNING seq
           INTO t_seq;

    IF (SQL%ROWCOUNT = 0) THEN
        RAISE no_update;
    END IF;

    COMMIT;

    SELECT json_value(a_packet, '$.PACKET_TYPE') INTO t_request FROM DUAL;

    -- ***********************************************************************
    -- Log the request
    -- ***********************************************************************
    UPDATE eservices_log_t
       SET request = t_request, packet = a_packet
     WHERE seq = t_seq;

    COMMIT;

    -- ***********************************************************************
    --  Call the function to process the request
    -- ***********************************************************************
    EXECUTE IMMEDIATE
           'BEGIN :a := '
        || t_request
        || '(:b, :c); END;'
        USING OUT t_response, IN a_packet, IN t_seq;

    -- ***********************************************************************
    -- Log response
    -- ***********************************************************************
    UPDATE eservices_log_t
       SET response = t_response, responsedate = SYSTIMESTAMP
     WHERE seq = t_seq;

    COMMIT;

    RETURN t_response;
EXCEPTION
    WHEN no_update THEN
        RETURN '{"PACKET_TYPE":"MESSAGE","DATA":{"MSGNO":"4","MSG":"Database Not Available for Updating"}}';
    WHEN OTHERS THEN
        t_sqlerrm   := sqlerrm;
        t_trace     := DBMS_UTILITY.format_error_backtrace;
        t_msg       :=
            SUBSTR(   t_sqlerrm
                   || ' :: '
                   || t_trace,
                   1,
                   3990);

        UPDATE eservices_log_t
           SET err = t_msg, responsedate = SYSTIMESTAMP
         WHERE seq = t_seq;

        COMMIT;

        RETURN    '{"PACKET_TYPE":"MESSAGE","DATA":{"MSGNO":"5","MSG":"Oracle Exception", "EXCEPTION":"'
               || REGEXP_REPLACE(t_sqlerrm, '[^[:print:]]', '')
               || '"}}';
END eservices;
/


GRANT EXECUTE ON BIZMOD_API.ESERVICES TO ABC;

GRANT EXECUTE ON BIZMOD_API.ESERVICES TO BIZMOD_USER;
