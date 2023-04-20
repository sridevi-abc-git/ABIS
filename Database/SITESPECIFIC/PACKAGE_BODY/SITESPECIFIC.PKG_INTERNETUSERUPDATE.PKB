CREATE OR REPLACE PACKAGE BODY SITESPECIFIC.pkg_internetuserupdate
AS
    -- **************************************************************************
    -- File:        PKG_INTERNETUSERUPDATE.PKB
    -- Author:      CX
    --
    -- $Rev$
    -- $Date$
    -- Last Changed By:  $Author$
    --
    -- Description:
    --
    --
    -- History:
    -----------------------------------------------------------------------------
    --    Date                  Comment
    -- 08/16/2018 TJL         Initial Check-in
    -- **************************************************************************

    g_encryptionkey   CONSTANT VARCHAR2(8) := 'X7%s-<T9';

    /*---------------------------------------------------------------------------
     * Encrypt() -- PRIVATE
     *   Return the encrypted password.
     *-------------------------------------------------------------------------*/
    FUNCTION encrypt(a_password VARCHAR2)
        RETURN VARCHAR2
    IS
        t_clearpassword       VARCHAR2(4000);
        t_encryptedpassword   VARCHAR2(4000);
        t_padlength           NUMBER;
    BEGIN
        /* encrypt the password (which must exist), after padding to a multiple of
           8 bytes */
        IF a_password IS NULL THEN
            api.pkg_errors.clear();
            api.pkg_errors.raiseerror(-20000,
                                      'User must be given a password');
        END IF;

        t_padlength   := 8 - MOD(LENGTH(a_password), 8);

        IF t_padlength < 8 THEN
            t_clearpassword   :=
                RPAD(a_password, LENGTH(a_password) + t_padlength);
        ELSE
            t_clearpassword   := a_password;
        END IF;

        dbms_obfuscation_toolkit.desencrypt(
            input_string => t_clearpassword,
            key_string  => g_encryptionkey,
            encrypted_string => t_encryptedpassword);

        RETURN t_encryptedpassword;
    END;

    /*---------------------------------------------------------------------------
     * Activate() -- PUBLIC
     *-------------------------------------------------------------------------*/
    PROCEDURE activate(a_userid        udt_id,
                       a_authenticationname VARCHAR2,
                       a_password      VARCHAR2)
    IS
        t_encryptedpassword   VARCHAR2(4000);
    BEGIN
        t_encryptedpassword   := encrypt(a_password);

        INSERT INTO internetusers(userid,
                                  password,
                                  unsuccessfullogoncount,
                                  timeoutuntil)
             VALUES (a_userid,
                     t_encryptedpassword,
                     0,
                     SYSDATE);
    END;

    /*---------------------------------------------------------------------------
     * Inactivate() -- PUBLIC
     *-------------------------------------------------------------------------*/
    PROCEDURE inactivate(a_userid udt_id, a_authenticationname VARCHAR2)
    IS
    BEGIN
        DELETE FROM internetusers
              WHERE userid = a_userid;
    END;

    /*---------------------------------------------------------------------------
     * Authenticate() -- PUBLIC
     *-------------------------------------------------------------------------*/
    PROCEDURE authenticate(a_userid        udt_id,
                           a_authenticationname VARCHAR2,
                           a_password      VARCHAR2,
                           a_connectstring VARCHAR2)
    IS
        t_encryptedpassword        VARCHAR2(4000);
        t_unsuccessfullogoncount   NUMBER;
        t_tries                    NUMBER;
        t_timeout                  DATE;
        t_timeoutlength            NUMBER;
    BEGIN
        SELECT password, unsuccessfullogoncount, timeoutuntil
          INTO t_encryptedpassword, t_unsuccessfullogoncount, t_timeout
          FROM internetusers
         WHERE userid = a_userid;

        IF t_timeout > SYSDATE THEN
            api.pkg_errors.clear();
            api.pkg_errors.setargvalue('Operation', 'Check Timeout');
            api.pkg_errors.setargvalue('AuthenticationName',
                                       a_authenticationname);
            api.pkg_errors.setargvalue('Timeout',
                                       TO_CHAR(t_timeout, 'hh24:mi:ss'));
            api.pkg_errors.authenticationfailed();
        END IF;

        IF t_encryptedpassword != encrypt(a_password) THEN
            RAISE NO_DATA_FOUND;
        END IF;

        IF t_unsuccessfullogoncount > 0 THEN
            UPDATE internetusers
               SET unsuccessfullogoncount   = 0
             WHERE userid = a_userid;
        END IF;

        COMMIT;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            api.pkg_errors.clear();
            api.pkg_errors.setargvalue('Operation',
                                       'Find User/Check Password');
            api.pkg_errors.setargvalue('AuthenticationName',
                                       a_authenticationname);

            t_tries   :=
                TO_NUMBER(api.pkg_constantquery.VALUE('NumberOfTries'));

            IF t_tries > 0 THEN
                t_unsuccessfullogoncount   := t_unsuccessfullogoncount + 1;

                IF t_unsuccessfullogoncount >= t_tries THEN
                    t_unsuccessfullogoncount   := 0;
                    t_timeoutlength            :=
                        TO_NUMBER(
                            api.pkg_constantquery.VALUE('TimeoutLength'));

                    IF t_timeoutlength IS NULL THEN
                        t_timeoutlength   := 1440;                 /* 1 day */
                    END IF;

                    t_timeout                  :=
                        SYSDATE + t_timeoutlength / 1440;
                END IF;

                UPDATE internetusers
                   SET unsuccessfullogoncount   = t_unsuccessfullogoncount,
                       timeoutuntil             = t_timeout
                 WHERE userid = a_userid;

                COMMIT;
            END IF;

            api.pkg_errors.authenticationfailed();
    END;

    /*---------------------------------------------------------------------------
     * ChangePassword() -- PUBLIC
     *-------------------------------------------------------------------------*/
    PROCEDURE changepassword(a_userid        udt_id,
                             a_authenticationname VARCHAR2,
                             a_password      VARCHAR2)
    IS
        t_encryptedpassword   VARCHAR2(4000);
    BEGIN
        t_encryptedpassword   := encrypt(a_password);

        UPDATE internetusers
           SET password   = t_encryptedpassword
         WHERE userid = a_userid;
    END;
END pkg_internetuserupdate;
/


GRANT EXECUTE ON SITESPECIFIC.PKG_INTERNETUSERUPDATE TO POSSEEXTENSIONS;
