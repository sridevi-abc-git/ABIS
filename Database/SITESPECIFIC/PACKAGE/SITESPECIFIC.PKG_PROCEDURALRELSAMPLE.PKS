CREATE OR REPLACE PACKAGE SITESPECIFIC.pkg_proceduralrelsample
AS
    -- **************************************************************************
    -- File:        PKG_PROCEDURALRELSAMPLE.PKS
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
     *   Routines used to traverse relationships using procedures.
     *-------------------------------------------------------------------------*/

    /*---------------------------------------------------------------------------
     * Types
     *-------------------------------------------------------------------------*/
    SUBTYPE udt_id IS api.pkg_definition.udt_id;

    /*---------------------------------------------------------------------------
     * Sample()
     *   Sample method for traversing a procedural relationship. It simply adds
     * the effective user to the list of related objects.
     *-------------------------------------------------------------------------*/
    PROCEDURE primaryltstatuses(a_objectid         udt_id,
                                a_endpointid       udt_id,
                                a_relatedobjectids OUT api.udt_objectlist);

    PROCEDURE secondaryltstatuses(a_objectid         udt_id,
                                  a_endpointid       udt_id,
                                  a_relatedobjectids OUT api.udt_objectlist);

    PROCEDURE appprimaryltstatuses(a_objectid         udt_id,
                                   a_endpointid       udt_id,
                                   a_relatedobjectids OUT api.udt_objectlist);

    PROCEDURE appsecondaryltstatuses(
        a_objectid         udt_id,
        a_endpointid       udt_id,
        a_relatedobjectids OUT api.udt_objectlist);

    PROCEDURE ltprimaryltstatuses(a_objectid         udt_id,
                                  a_endpointid       udt_id,
                                  a_relatedobjectids OUT api.udt_objectlist);

    PROCEDURE ltsecondaryltstatuses(
        a_objectid         udt_id,
        a_endpointid       udt_id,
        a_relatedobjectids OUT api.udt_objectlist);
END pkg_proceduralrelsample;
/
