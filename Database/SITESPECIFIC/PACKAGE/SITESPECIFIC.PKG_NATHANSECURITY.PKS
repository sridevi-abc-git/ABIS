CREATE OR REPLACE PACKAGE SITESPECIFIC.pkg_nathansecurity
AS
    -- **************************************************************************
    -- File:        PKG_NATHANSECURITY.PKS
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
    *   Routines used to manipulate instance security.
    *-------------------------------------------------------------------------*/

    /*---------------------------------------------------------------------------
    * Types
    *-------------------------------------------------------------------------*/
    SUBTYPE udt_id IS api.pkg_definition.udt_id;

    PROCEDURE addofficeaccessgroup(g_object udt_id, a_asofdate DATE);

    PROCEDURE removeofficeaccessgroup(g_object udt_id, a_asofdate DATE);
END pkg_nathansecurity;
/
