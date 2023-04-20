CREATE OR REPLACE PACKAGE SITESPECIFIC.pkg_security
IS
    -- **************************************************************************
    -- File:        PKG_SECURITY.PKS
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

    /*------------------------------------------------------------------------*
    * Types declaration
    *------------------------------------------------------------------------*/
    SUBTYPE udt_id IS api.pkg_definition.udt_id;

    /*-------------------------------------------------------------------------------
    * Procedure AddAccessGroup()
    *   Runs on relationship between User and external object Access Groups
    *   to add the user to the access group selected
    *-----------------------------------------------------------------------------*/
    PROCEDURE addaccessgroup(a_relationshipid udt_id, a_asofdate DATE);

    /*-------------------------------------------------------------------------------
    * Procedure RemoveAccessGroup()
    *   Runs on relationship between User and external object Access Groups
    *   to remove the user from the access group
    *-----------------------------------------------------------------------------*/
    PROCEDURE removeaccessgroup(a_relationshipid udt_id, a_asofdate DATE);

    ----------------------------------------------------------------------------------------------------
    --  AssignByAccessGroup() -- PUBLIC
    --  This will assign any users that are in the access group specified in the Assign By Access Group
    --  detail and is also related to the Accusation Office
    ----------------------------------------------------------------------------------------------------

    PROCEDURE assignbyaccessgroup(a_objectid      udt_id,
                                  a_asofdate      DATE,
                                  a_jobid         udt_id);

    /*-------------------------------------------------------------------------------
    * Procedure AddOfficeAccessGroup()
    *   Runs on relationship between User and Office
    *   to add the user to the access group with the same name as the office
    *-----------------------------------------------------------------------------*/

    PROCEDURE addofficeaccessgroup(g_object udt_id, a_asofdate DATE);

    /*-------------------------------------------------------------------------------
    * Procedure RemoveOfficeAccessGroup()
    *   Runs on relationship between User and Office
    *   to remove the user from the access group with the same name as the office
    *-----------------------------------------------------------------------------*/

    PROCEDURE removeofficeaccessgroup(g_object udt_id, a_asofdate DATE);

    /*---------------------------------------------------------------------------
     * InactiveUser() -- PUBLIC
     *-------------------------------------------------------------------------*/
    PROCEDURE inactiveuser(a_objectid      udt_id,
                           a_asofdate      DATE,
                           a_active        VARCHAR2);
END;
/
