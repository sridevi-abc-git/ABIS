CREATE OR REPLACE PACKAGE SITESPECIFIC.pkg_relationship
AS
    -- **************************************************************************
    -- File:        PKG_RELATIONSHIP.PKS
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
     * RecentJobProcesses()
     * Written by: Andy Patterson (CXUSA)
     * Created on: 9/15/2015
     * This is a procedural relationship used to register external o_Process
     * objects and return those that were created within the last 12 months
     * or where the process is incomplete.
     *-------------------------------------------------------------------------*/
    PROCEDURE recentjobprocesses(a_objectid         udt_id,
                                 a_endpointid       udt_id,
                                 a_relatedobjectids OUT api.udt_objectlist);
END pkg_relationship;
/
