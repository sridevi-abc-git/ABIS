CREATE OR REPLACE PACKAGE SITESPECIFIC.pkg_lookup
AS
    -- **************************************************************************
    -- File:        PKG_LOOKUP.PKS
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

    /*--------------------------------------------------------------------------
     * Types -- PUBLIC
     *------------------------------------------------------------------------*/
    SUBTYPE udt_id IS api.pkg_definition.udt_id;

    SUBTYPE udt_endpoint IS api.pkg_definition.udt_endpoint;

    SUBTYPE udt_objectlist IS api.udt_objectlist;

    SUBTYPE udt_idlist IS api.pkg_definition.udt_idlist;

    /*---------------------------------------------------------------------------
     * ListLicensees() -- PUBLIC
     *
     * This procedure is an example of as a method of finding values for a lookup.
     *   It will return all of the staff members in the Public access group.
     *
     * How to use:
     *   1. Configure a relationship to staff and a corresponding lookup detail.
     *   2. On the lookup detail configuration, specify
     *     "pkg_Lookup.ListStaffInAccessGroup" in the "Procedure" field under
     *     "Search By:"
     *-------------------------------------------------------------------------*/
    PROCEDURE listlicensees(a_object           udt_id,
                            a_relationshipdef  udt_id,
                            a_endpoint         udt_endpoint,
                            a_searchstring     VARCHAR2,
                            a_objects      OUT udt_objectlist);


    ----------------------------------------------------------------------------------------------------
    --  FindUsersForReminder() -- PUBLIC
    --  List all users for the same office as the person who created the Reminder object (if it already exists),
    --  or for the currently logged in user (if the Reminder object doesn't yet exist).
    --  Used for procedural lookup of detail o_Reminder.AssignedStaff
    ----------------------------------------------------------------------------------------------------

    PROCEDURE findusersforreminder(a_object           udt_id,
                                   a_relationshipdef  udt_id,
                                   a_endpoint         udt_endpoint,
                                   a_searchstring     VARCHAR2,
                                   a_relatedobjectids OUT udt_objectlist);

    ------------------------------------------------------------------------
    --FindJobFees
    --Find Fees for the Modify Fee Procedure
    --this lookup procedure will only work for a drop down Dynamic Detail.
    ------------------------------------------------------------------------

    PROCEDURE findjobfees(a_object           udt_id,
                          a_relationshipdef  udt_id,
                          a_endpoint         udt_endpoint,
                          a_searchstring     VARCHAR2,
                          a_objects      OUT udt_objectlist);

    ----------------------------------------------------------------------------------------------------
    --  FindLicenseTypeCategory() -- PUBLIC
    -- This will get all the LTCs related to a License as either Primaries or Secondaries.
    ----------------------------------------------------------------------------------------------------
    PROCEDURE findlicensetypecategory(a_object           udt_id,
                                      a_relationshipdef  udt_id,
                                      a_endpoint         udt_endpoint,
                                      a_searchstring     VARCHAR2,
                                      a_objects      OUT udt_objectlist);
END pkg_lookup;
/


GRANT EXECUTE ON SITESPECIFIC.PKG_LOOKUP TO POSSEEXTENSIONS;
