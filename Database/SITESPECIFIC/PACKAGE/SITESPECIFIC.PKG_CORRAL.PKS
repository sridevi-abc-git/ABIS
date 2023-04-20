CREATE OR REPLACE PACKAGE SITESPECIFIC.pkg_corral
IS
    -- **************************************************************************
    -- File:        PKG_CORRAL.pks
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
     * Description
     *   The package is a container for Corral related procedures.
     *-------------------------------------------------------------------------*/

    /*---------------------------------------------------------------------------
     * Types - PUBLIC
     *-------------------------------------------------------------------------*/
    SUBTYPE udt_id IS api.pkg_definition.udt_id;

    /*---------------------------------------------------------------------------
     * NotifyCorralForRelatedObjects() -- PUBLIC
     *  This procedure will queue ScheduledNotifyCorralForRelObj to run
     *  asynchronously.
     *-------------------------------------------------------------------------*/
    PROCEDURE notifycorralforrelatedobjects(a_objectid      udt_id,
                                            a_asofdate      DATE,
                                            a_endpointnames VARCHAR2);

    /*---------------------------------------------------------------------------
     * ScheduledNotifyCorralForRelObj() -- PUBLIC
     *  This procedure will call api.pkg_ObjectUpdate.NotifyExternalObjectModified
     * for the related objects specified by the end point names.  The end point
     * names can be passed in as a comma separated list of end point names.
     *-------------------------------------------------------------------------*/
    PROCEDURE schedulednotifycorralforrelobj(a_objectid      VARCHAR2,
                                             a_endpointnames VARCHAR2);
END pkg_corral;
/


GRANT EXECUTE ON SITESPECIFIC.PKG_CORRAL TO POSSEEXTENSIONS;

GRANT EXECUTE ON SITESPECIFIC.PKG_CORRAL TO PSERVERSYS;
