CREATE OR REPLACE PACKAGE SITESPECIFIC.pkg_userupdate
AS
    -- **************************************************************************
    -- File:        PKG_USERUPDATE.PKS
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
     * DESCRIPTION
     *   Routines used to manipulate Oracle users.
     *-------------------------------------------------------------------------*/

    /*---------------------------------------------------------------------------
     * Types
     *-------------------------------------------------------------------------*/
    SUBTYPE udt_id IS api.pkg_definition.udt_id;

    /*---------------------------------------------------------------------------
     * Activate()
     *   Activate the user so that they can log on.
     *-------------------------------------------------------------------------*/
    PROCEDURE activate(a_user          udt_id,
                       a_oraclelogon   VARCHAR2,
                       a_password      VARCHAR2);

    /*---------------------------------------------------------------------------
     * Inactivate()
     *   Inactivate the user so that they can no longer log on.
     *-------------------------------------------------------------------------*/
    PROCEDURE inactivate(a_user udt_id, a_oraclelogon VARCHAR2);

    /*---------------------------------------------------------------------------
     * Authenticate()
     *   Authenticate the user.
     *-------------------------------------------------------------------------*/
    PROCEDURE authenticate(a_user          udt_id,
                           a_oraclelogon   VARCHAR2,
                           a_password      VARCHAR2,
                           a_connectstring VARCHAR2);

    /*---------------------------------------------------------------------------
     * ChangePassword()
     *   Change the user's password.
     *-------------------------------------------------------------------------*/
    PROCEDURE changepassword(a_user          udt_id,
                             a_oraclelogon   VARCHAR2,
                             a_password      VARCHAR2);

    /*---------------------------------------------------------------------------
     * ModifyOracleLogon()
     *   Modify the logon of the user.
     *-------------------------------------------------------------------------*/
    PROCEDURE modifyoraclelogon(a_user          udt_id,
                                a_origoraclelogon VARCHAR2,
                                a_neworaclelogon VARCHAR2,
                                a_password      VARCHAR2);

    /*----------------------------------------------------------
     * SetDefaultOffice()     --Public
     *---------------------------------------------------------*/

    PROCEDURE setdefaultoffice(a_objectid udt_id, a_asofdate DATE);

    /*-----------------------------------------------------------
    --  ValidateInactiveOffice() - PUBLIC
    --  This will raise an error if a user tries to de-activate an
    --  Office (uncheck the IsActive checkbox) and there are users
    --  related to the office.
    */
    -----------------------------------------------------------
    PROCEDURE validateinactiveoffice(a_objectid udt_id, a_asofdate DATE);
END pkg_userupdate;
/
