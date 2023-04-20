CREATE OR REPLACE PROCEDURE ABC.tl_sendconfirmationemail(
    a_objectid      api.pkg_definition.udt_id,
    a_asofdate      DATE,
    a_fromaddresscolname VARCHAR2,
    a_toaddresscolname VARCHAR2,
    a_ccaddresscolname VARCHAR2,
    a_bccaddresscolname VARCHAR2,
    a_subjectcolname VARCHAR2,
    a_bodycolname   VARCHAR2,
    a_documentidcolname VARCHAR2,
    a_documentendpointname VARCHAR2,
    a_bodyishtml    VARCHAR2 DEFAULT 'N')
IS
    -- ****************************************************************************
    -- File:        TL_SENDCONFIRMATIONEMAIL.PRC
    -- Author:      Timothy J. Lord
    --
    -- $Rev: 3100 $
    -- $Date: 2016-10-27 15:09:12 -0700 (Thu, 27 Oct 2016) $
    -- Last Changed By $Author: tlord $
    --
    -- Description:
    --
    -- History:
    -------------------------------------------------------------------------------
    --    Date                  Comment
    -- 10/10/2016 TJL  10759  Add SendEmail procedure
    -- 10/26/2022 PK   Changed DB name to ABISP1    IF (UPPER(lv_db_name) != 'ABCPROD') THEN to correct emails we are getting everyday.
    -- ****************************************************************************
    PROCEDURE sendemail(a_objectid      api.pkg_definition.udt_id,
                        p_fromaddress   VARCHAR2,
                        p_toaddress     VARCHAR2,
                        p_subject       VARCHAR2,
                        p_body          VARCHAR2,
                        p_file_name     VARCHAR2,
                        p_clob          CLOB,
                        p_encoding      VARCHAR2 DEFAULT 'text/plain',
                        p_mimetype      VARCHAR2 DEFAULT 'text/plain')
    IS
        gc_newline            CONSTANT CHAR(2) := CHR(13) || CHR(10);

        boundary              CONSTANT VARCHAR2(256)
                                           := '-----7D81B75CCC90D2974F7A1CBD' ;
        first_boundary        CONSTANT VARCHAR2(256)
                                           := '--' || boundary || gc_newline ;
        last_boundary         CONSTANT VARCHAR2(256)
            := '--' || boundary || '--' || gc_newline ;

        multipart_mime_type   CONSTANT VARCHAR2(256)
            := 'multipart/mixed; boundary="' || boundary || '"' ;

        TYPE t_recp IS TABLE OF VARCHAR(512);

        CURSOR cur_rcpt(p_to IN VARCHAR2)
        IS
                SELECT REGEXP_SUBSTR(p_to,
                                     '[^;]+',
                                     1,
                                     LEVEL)
                           txt
                  FROM DUAL
            CONNECT BY REGEXP_SUBSTR(p_to,
                                     '[^;]+',
                                     1,
                                     LEVEL)
                           IS NOT NULL;

        l_conn                         utl_smtp.connection;
        lv_host                        VARCHAR2(512); -- := '134.186.202.119';
        v_len                          INTEGER;
        v_index                        INTEGER;
        v_file_type                    VARCHAR2(50);
        v_body                         VARCHAR2(32000) := p_body;
        lv_db_name                     VARCHAR2(100);
        l_rcpt                         t_recp;
        t_emailid                      api.pkg_definition.udt_id;
    BEGIN
        IF (p_toaddress IS NULL) THEN
            RETURN;
        END IF;

        IF (p_file_name IS NOT NULL) THEN
            SELECT CASE LOWER(REGEXP_SUBSTR(p_file_name, '\.[^\.]*$'))
                       WHEN 'doc' THEN 'application/msword'
                       WHEN 'xls' THEN 'application/excel'
                       WHEN 'xlsx' THEN 'application/excel'
                       WHEN 'pdf' THEN 'application/pdf'
                       WHEN 'zip' THEN 'application/zip'
                       WHEN 'bmp' THEN 'image/bmp'
                       WHEN 'jpg' THEN 'image/jpg'
                       WHEN 'jpeg' THEN 'image/jpg'
                       WHEN 'gif' THEN 'image/gif'
                       WHEN 'htm' THEN 'text/html'
                       WHEN 'html' THEN 'text/html'
                       WHEN 'txt' THEN 'text/plain'
                       WHEN 'log' THEN 'text/plain'
                       WHEN 'csv' THEN 'text/plain'
                       WHEN 'text' THEN 'text/plain'
                       ELSE 'text/plain'
                   END
                       CASE
              INTO v_file_type
              FROM DUAL;
        ELSE
            v_file_type   := p_mimetype;
        END IF;

        OPEN cur_rcpt(p_toaddress);

        FETCH cur_rcpt BULK COLLECT INTO l_rcpt LIMIT 30;

        CLOSE cur_rcpt;

        SELECT VALUE
          INTO lv_host
          FROM api.constants
         WHERE name = 'SMTPSERVER';

        SELECT SYS_CONTEXT('userenv', 'instance_name')
          INTO lv_db_name
          FROM DUAL;

        IF (UPPER(lv_db_name) != 'ABISP1') THEN
            v_body   :=
                   '*** This is a test sent from: '
                || lv_db_name
                || ' *** '
                || utl_tcp.crlf
                || utl_tcp.crlf
                || v_body;
        END IF;

        l_conn   := utl_smtp.open_connection(lv_host, 25);
        utl_smtp.helo(l_conn, lv_host);

        utl_smtp.mail(l_conn, p_fromaddress);

        -- loop through the to address list
        FOR inx IN 1 .. l_rcpt.COUNT
        LOOP
            utl_smtp.rcpt(l_conn, l_rcpt(inx));
        END LOOP;

        utl_smtp.open_data(l_conn);
        utl_smtp.write_data(l_conn,
                            'From: ' || p_fromaddress || utl_tcp.crlf);
        utl_smtp.write_data(l_conn, 'To: ' || p_toaddress || utl_tcp.crlf);
        utl_smtp.write_data(l_conn, 'Subject: ' || p_subject || utl_tcp.crlf);

        utl_smtp.write_data(
            l_conn,
            'Content-Type: ' || multipart_mime_type || utl_tcp.crlf);

        utl_smtp.write_data(l_conn, utl_tcp.crlf);
        utl_smtp.write_data(l_conn, first_boundary);
        utl_smtp.write_data(l_conn,
                            'Content-Type: ' || p_mimetype || utl_tcp.crlf);
        utl_smtp.write_data(l_conn, utl_tcp.crlf);
        utl_smtp.write_data(l_conn, v_body || utl_tcp.crlf);
        utl_smtp.write_data(l_conn, utl_tcp.crlf);

        IF (p_clob IS NOT NULL
        AND p_file_name IS NOT NULL) THEN
            utl_smtp.write_data(l_conn, first_boundary);
            utl_smtp.write_data(
                l_conn,
                'Content-Type: ' || v_file_type || utl_tcp.crlf);

            -- Set up attachment header
            utl_smtp.write_data(
                l_conn,
                   'Content-Disposition: attachment; filename="'
                || p_file_name
                || '"'
                || utl_tcp.crlf);

            utl_smtp.write_data(
                l_conn,
                'Content-Transfer-Encoding: ' || p_encoding || utl_tcp.crlf);
            utl_smtp.write_data(l_conn, utl_tcp.crlf);

            -- Write attachment contents
            v_len     := dbms_lob.getlength(p_clob);
            v_index   := 1;

            WHILE v_index <= v_len
            LOOP
                utl_smtp.write_data(l_conn,
                                    dbms_lob.SUBSTR(p_clob, 32000, v_index));
                v_index   := v_index + 32000;
            END LOOP;

            -- End attachment
            utl_smtp.write_data(l_conn, utl_tcp.crlf);
        END IF;

        utl_smtp.write_data(l_conn, last_boundary);

        utl_smtp.close_data(l_conn);
        utl_smtp.quit(l_conn);

        api.pkg_logicaltransactionupdate.starttransaction;

        t_emailid   :=
            api.pkg_objectupdate.new(
                api.pkg_configquery.objectdefidforname('o_Email'));

        INSERT INTO extension.emails(emailid,
                                     fromaddress,
                                     toaddress,
                                     subject,
                                     body,
                                     ccaddress,
                                     bccaddress,
                                     MESSAGE,
                                     relatedobjectid,
                                     createddate,
                                     sentdate)
             VALUES (t_emailid,
                     p_fromaddress,
                     p_toaddress,
                     p_subject,
                     p_body,
                     NULL,
                     NULL,
                     NULL,
                     a_objectid,
                     SYSDATE,
                     SYSDATE);

        api.pkg_logicaltransactionupdate.endtransaction;
        COMMIT;
    END sendemail;
BEGIN
    DECLARE
    BEGIN
        sendemail(
            a_objectid =>
                a_objectid,
            p_fromaddress =>
                api.pkg_columnquery.VALUE(a_objectid, a_fromaddresscolname),
            p_toaddress =>
                api.pkg_columnquery.VALUE(a_objectid, a_toaddresscolname),
            p_subject =>
                api.pkg_columnquery.VALUE(a_objectid, a_subjectcolname),
            p_body =>
                api.pkg_columnquery.VALUE(a_objectid, a_bodycolname),
            p_file_name =>
                NULL,
            p_clob =>
                NULL);
    END;
END;
/


GRANT EXECUTE ON ABC.TL_SENDCONFIRMATIONEMAIL TO POSSEEXTENSIONS;
