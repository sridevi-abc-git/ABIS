CREATE OR REPLACE PACKAGE BODY SITESPECIFIC.pkg_userupdate
AS
    -- **************************************************************************
    -- File:        PKG_USERUPDATE.PKB
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
    -- 08/20/2018 TJL         Initial Check-in
    -- **************************************************************************

    /*---------------------------------------------------------------------------
     * FailIfConnected() -- PRIVATE
     *   Raise an error if the user is currently connected to the database.
     *-------------------------------------------------------------------------*/
    PROCEDURE failifconnected(a_oraclelogon VARCHAR2)
    IS
        t_temp   PLS_INTEGER;
    BEGIN
        SELECT COUNT(*)
          INTO t_temp
          FROM v$session
         WHERE username = a_oraclelogon;

        IF t_temp > 0 THEN
            api.pkg_errors.clear();
            api.pkg_errors.setargvalue('OracleLogon', a_oraclelogon);
            api.pkg_errors.raiseerror(
                -20000,
                'User {OracleLogon} is currently connected');
        END IF;
    END;

    /*---------------------------------------------------------------------------
     * OracleLogonExists() -- PRIVATE
     *   Return a boolean indicating if the oracle logon exists on the database.
     *-------------------------------------------------------------------------*/
    FUNCTION oraclelogonexists(a_oraclelogon VARCHAR2)
        RETURN BOOLEAN
    IS
        t_temp   PLS_INTEGER;
    BEGIN
        SELECT COUNT(*)
          INTO t_temp
          FROM dba_users
         WHERE username = a_oraclelogon;

        RETURN (t_temp > 0);
    END;

    /*---------------------------------------------------------------------------
     * Activate() -- PUBLIC
     *-------------------------------------------------------------------------*/
    PROCEDURE activate(a_user          udt_id,
                       a_oraclelogon   VARCHAR2,
                       a_password      VARCHAR2)
    IS
        t_defaulttablespace     VARCHAR2(4000);
        t_temporarytablespace   VARCHAR2(4000);
        t_sql                   VARCHAR2(4000);
    BEGIN
        /* make sure the user does not exist */
        IF oraclelogonexists(a_oraclelogon) THEN
            api.pkg_errors.clear();
            api.pkg_errors.setargvalue('OracleLogonId', a_oraclelogon);
            api.pkg_errors.raiseerror(-20000,
                                      'User {OracleLogonId} already exists');
        END IF;

        /* determine the options for creating the user */
        t_defaulttablespace   :=
            api.pkg_constantquery.VALUE('DefaultTablespace');
        t_temporarytablespace   :=
            api.pkg_constantquery.VALUE('TemporaryTablespace');

        /* generate SQL to execute */
        IF a_password IS NULL THEN
            api.pkg_errors.raiseerror(-20000, 'A password must be supplied');
        END IF;

        t_sql   :=
               'create user '
            || a_oraclelogon
            || ' identified by "'
            || a_password
            || '"';

        IF t_defaulttablespace IS NOT NULL THEN
            t_sql   := t_sql || ' default tablespace ' || t_defaulttablespace;
        END IF;

        IF t_temporarytablespace IS NOT NULL THEN
            t_sql   :=
                t_sql || ' temporary tablespace ' || t_temporarytablespace;
        END IF;

        /* execute the SQL to create the user */
        EXECUTE IMMEDIATE t_sql;

        EXECUTE IMMEDIATE 'grant create session to ' || a_oraclelogon;

        EXECUTE IMMEDIATE 'grant posseextensions to ' || a_oraclelogon;
    END;

    /*---------------------------------------------------------------------------
     * Inactivate() -- PUBLIC
     *-------------------------------------------------------------------------*/
    PROCEDURE inactivate(a_user udt_id, a_oraclelogon VARCHAR2)
    IS
    BEGIN
        IF NOT oraclelogonexists(a_oraclelogon) THEN
            RETURN;
        END IF;

        failifconnected(a_oraclelogon);

        EXECUTE IMMEDIATE 'drop user ' || a_oraclelogon;
    END;

    /*---------------------------------------------------------------------------
     * Authenticate() -- PUBLIC
     *-------------------------------------------------------------------------*/
    PROCEDURE authenticate(a_user          udt_id,
                           a_oraclelogon   VARCHAR2,
                           a_password      VARCHAR2,
                           a_connectstring VARCHAR2)
    IS
        t_error       VARCHAR2(4000);
        t_operation   VARCHAR2(100);
        t_name        VARCHAR2(100);
        t_created     BOOLEAN;
        t_junk        PLS_INTEGER;
    BEGIN
        BEGIN
            t_name   := 'test' || USERENV('sessionid');

            EXECUTE IMMEDIATE 'drop database link ' || t_name;
        EXCEPTION
            WHEN OTHERS THEN
                NULL;
        END;

        BEGIN
            t_name      := 'test' || USERENV('sessionid');

            EXECUTE IMMEDIATE
                   'create database link '
                || t_name
                || ' connect to '
                || a_oraclelogon
                || ' identified by "'
                || a_password
                || '" using '''
                || a_connectstring
                || '''';

            t_created   := TRUE;
        EXCEPTION
            WHEN OTHERS THEN
                t_error       := SQLERRM;
                t_operation   := 'Create link';
        END;

        /* NOTE: the commit and close_database_link() call is needed in 10g but
           will cause no trouble in other versions */
        BEGIN
            IF t_created THEN
                EXECUTE IMMEDIATE
                       'begin select count(*) into :p_Result from '
                    || 'user_tables@'
                    || t_name
                    || ' where rownum <= 1; end;'
                    USING OUT t_junk;

                COMMIT;
                dbms_session.close_database_link(t_name);
            END IF;
        EXCEPTION
            WHEN OTHERS THEN
                t_error       := SQLERRM;
                t_operation   := 'Query link';
        END;

        BEGIN
            IF t_created THEN
                EXECUTE IMMEDIATE 'drop database link ' || t_name;
            END IF;
        EXCEPTION
            WHEN OTHERS THEN
                t_error       := SQLERRM;
                t_operation   := 'Drop link';
        END;

        IF t_error IS NOT NULL THEN
            api.pkg_errors.clear();
            api.pkg_errors.setargvalue('OriginalError', t_error);
            api.pkg_errors.setargvalue('Operation', t_operation);
            api.pkg_errors.setargvalue('LinkName', t_name);
            api.pkg_errors.setargvalue('OracleLogonId', a_oraclelogon);
            api.pkg_errors.setargvalue('ConnectString', a_connectstring);
            api.pkg_Errors.Authenticationfailed();
        END IF;
    END;

    /*---------------------------------------------------------------------------
     * ChangePassword() -- PUBLIC
     *-------------------------------------------------------------------------*/
    PROCEDURE changepassword(a_user          udt_id,
                             a_oraclelogon   VARCHAR2,
                             a_password      VARCHAR2)
    IS
    BEGIN
        IF NOT oraclelogonexists(a_oraclelogon) THEN
            api.pkg_errors.clear();
            api.pkg_errors.setargvalue('OracleLogonId', a_oraclelogon);
            api.pkg_errors.raiseerror(-20000,
                                      'User {OracleLogonId} does not exist');
        END IF;

        EXECUTE IMMEDIATE
               'alter user '
            || a_oraclelogon
            || ' identified by "'
            || a_password
            || '"';
    END;

    /*---------------------------------------------------------------------------
     * ModifyOracleLogon() -- PUBLIC
     *-------------------------------------------------------------------------*/
    PROCEDURE modifyoraclelogon(a_user          udt_id,
                                a_origoraclelogon VARCHAR2,
                                a_neworaclelogon VARCHAR2,
                                a_password      VARCHAR2)
    IS
    BEGIN
        inactivate(a_user, a_origoraclelogon);
        activate(a_user, a_neworaclelogon, a_password);
    END;

    /*----------------------------------------------------------
   * SetDefaultOffice()     --Public
   * This will set the default office for the user when an office is related to the user and the default is not set.
   * note: this is run on constructor of the Rel for (Secondary)Offices
   *---------------------------------------------------------*/

    PROCEDURE setdefaultoffice(a_objectid udt_id, a_asofdate DATE)
    IS
        t_insertedofficeid   udt_id;
        t_defaultofficeid    udt_id;
        t_userid             udt_id;
        t_userendpointid     udt_id
            := api.pkg_configquery.endpointidforname('Users', 'Office');
        t_newrelid           udt_id;
    BEGIN
        SELECT ro.officeobjectid, rod.officeobjectid, u.objectid
          INTO t_insertedofficeid, t_defaultofficeid, t_userid
          FROM query.r_usersecondaryoffice  ro
               JOIN query.users u ON u.objectid = ro.userobjectid
               LEFT OUTER JOIN query.r_officeuser rod
                   ON rod.userobjectid = u.objectid
         WHERE ro.relationshipid = a_objectid;


        IF t_defaultofficeid IS NULL THEN
            t_newrelid   :=
                api.pkg_relationshipupdate.new(t_userendpointid,
                                               t_userid,
                                               t_insertedofficeid,
                                               a_asofdate);
        END IF;
    END setdefaultoffice;


    /*-----------------------------------------------------------
    --  ValidateInactiveOffice() - PUBLIC
    --  This will raise an error if a user tries to de-activate an
    --  Office (uncheck the IsActive checkbox) and there are users
    --  related to the office.
    */
    -----------------------------------------------------------
    PROCEDURE validateinactiveoffice(a_objectid udt_id, a_asofdate DATE)
    IS
        t_hasusers   VARCHAR2(1) := 'N';
        t_users      VARCHAR2(4000);
    BEGIN
        BEGIN
            SELECT UNIQUE ('Y')
              INTO t_hasusers
              FROM query.r_officeuser  ou
                   JOIN query.users u ON ou.userobjectid = u.objectid
             WHERE ou.officeobjectid = a_objectid;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                NULL;
        END;

        BEGIN
            SELECT UNIQUE ('Y')
              INTO t_hasusers
              FROM query.r_usersecondaryoffice  so
                   JOIN query.users u ON so.userobjectid = u.objectid
             WHERE so.officeobjectid = a_objectid;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                NULL;
        END;

        IF api.pkg_columnquery.VALUE(a_objectid, 'IsActive') = 'N'
       AND t_hasusers = 'Y' THEN
            BEGIN
                SELECT concatlist(username)
                  INTO t_users
                  FROM (SELECT UNIQUE (u.name) username
                          FROM query.users  u
                               LEFT OUTER JOIN query.r_usersecondaryoffice so
                                   ON u.objectid = so.userobjectid
                               LEFT OUTER JOIN query.r_officeuser ou
                                   ON u.objectid = ou.userobjectid
                         WHERE so.officeobjectid = a_objectid
                            OR ou.officeobjectid = a_objectid);
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    NULL;
            END;

            api.pkg_errors.raiseerror(
                -20000,
                   'An inactive Office cannot be related to Users. The following Users are related to this Office: '
                || t_users
                || '.');
        END IF;
    END validateinactiveoffice;
END pkg_userupdate;
/
