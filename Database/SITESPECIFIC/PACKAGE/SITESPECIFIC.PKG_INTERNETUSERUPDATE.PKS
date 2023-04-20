CREATE OR REPLACE PACKAGE SITESPECIFIC.pkg_internetuserupdate
AS
    -- **************************************************************************
    -- File:        PKG_INTERNETUSERUPDATE.PKS
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

    /*---------------------------------------------------------------------------
     * DESCRIPTION
     *   Routines used to manage internet users who do not have Oracle Logons.
     * Two user constants are defined. The first "NumberOfTries" defines how
     * many unsuccessful logon attempts are permitted before the user is locked
     * out. The second "TimeoutLength" defines the number of minutes the user
     * will be locked out for. If this constant is missing, a day is assumed.
     *-------------------------------------------------------------------------*/

    SUBTYPE udt_id IS api.pkg_definition.udt_id;

    /*---------------------------------------------------------------------------
     * Activate()
     *   Activate the user so that they can log on.
     *-------------------------------------------------------------------------*/
    PROCEDURE activate(a_userid        udt_id,
                       a_authenticationname VARCHAR2,
                       a_password      VARCHAR2);

    /*---------------------------------------------------------------------------
     * Inactivate()
     *   Inactivate the user so that they can no longer log on.
     *-------------------------------------------------------------------------*/
    PROCEDURE inactivate(a_userid udt_id, a_authenticationname VARCHAR2);

    /*---------------------------------------------------------------------------
     * Authenticate()
     *   Authenticate the user.
     *-------------------------------------------------------------------------*/
    PROCEDURE authenticate(a_userid        udt_id,
                           a_authenticationname VARCHAR2,
                           a_password      VARCHAR2,
                           a_connectstring VARCHAR2);

    /*---------------------------------------------------------------------------
     * ChangePassword()
     *   Change the user's password.
     *-------------------------------------------------------------------------*/
    PROCEDURE changepassword(a_userid        udt_id,
                             a_authenticationname VARCHAR2,
                             a_password      VARCHAR2);
END pkg_internetuserupdate;
/


GRANT EXECUTE ON SITESPECIFIC.PKG_INTERNETUSERUPDATE TO POSSEEXTENSIONS;
