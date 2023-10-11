CREATE OR REPLACE FUNCTION BIZMOD_API.eservices(
    a_packet       IN CLOB,
    a_filedata     IN BLOB DEFAULT NULL)
    RETURN CLOB
IS
    -- ****************************************************************************
    -- File:        BIZMOD_API.ESERVICES.FNC
    -- Author:      Timothy J. Lord
    --
    -- Purpose :
    --
    -- History:
    -------------------------------------------------------------------------------
    --    Ver:     Date          Ticket          Comment
    --          12/09/2022 TJL
    --    2.0   08/31/2023 TJL  BIZ-12458   Added default parameter to contain file data
    --                                      to be uploaded into ABIS.  Updated saving
    --                                      data in log files.
    --    3.0   09/21/2023 TJL  BIZ-12883   Change loging to log Process for requests when 
    --                                        request is CREATEPROCESSJOB
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
       SET request =
               CASE t_request
                   WHEN 'CREATEPROCESSJOB'
                   THEN
                       json_value(a_packet, '$.PROCESS')
                   ELSE
                       t_request
               END,
           packet = a_packet,
           filedata = a_filedata
     WHERE seq = t_seq
       LOG ERRORS INTO bizmod_api.err$_eservices_log_t
               ('UPDATE')
               REJECT LIMIT UNLIMITED;

    IF (SQL%ROWCOUNT = 0)
    THEN
        INSERT INTO err$_eservices_clob_t(seq, jsondata, filedata)
             VALUES (TO_CHAR(t_seq), a_packet, a_filedata);

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


GRANT EXECUTE ON BIZMOD_API.ESERVICES TO ABC;

GRANT EXECUTE ON BIZMOD_API.ESERVICES TO BIZMOD_USER;
