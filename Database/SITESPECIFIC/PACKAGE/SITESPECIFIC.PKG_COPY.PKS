CREATE OR REPLACE PACKAGE SITESPECIFIC."PKG_COPY"
IS
    -- **************************************************************************
    -- File:        PKG_COPY.pks
    -- Author:      LOREN
    --
    -- $Rev$
    -- $Date$
    -- Last Changed By:  $Author$
    --
    -- Description:    Copy details
    --
    --
    -- History:
    -----------------------------------------------------------------------------
    --    Date                  Comment
    -- 08/16/2018 TJL         Initial Check-in
    -- **************************************************************************

    SUBTYPE udt_id IS api.pkg_definition.udt_id;

    ----------------------------------------------------------------------------------------------------
    --  CopyStoredObjectDetails() -- PUBLIC
    -- Copy stored details from one object to another, where the column names are the same.
    ----------------------------------------------------------------------------------------------------
    PROCEDURE copystoredobjectdetails(a_fromobjectid  udt_id,
                                      a_toobjectid    udt_id);

    ----------------------------------------------------------------------------------------------------
    --  CopyStoredObjectDetailsException() -- PUBLIC
    -- Copy stored details from one object to another, where the column names are the same. This allows
    -- the user to add an exception for a detail that should not be copied.
    ----------------------------------------------------------------------------------------------------

    PROCEDURE copystoredobjdetailsexception(a_fromobjectid  udt_id,
                                            a_toobjectid    udt_id,
                                            a_exception     VARCHAR2);

    ----------------------------------------------------------------------------------------------------
    --  RemoveNonUpgradePLTs() -- PUBLIC
    --  This also the rel to the PLTs that are not marked for upgrade on a Priority Application
    ----------------------------------------------------------------------------------------------------

    PROCEDURE removenonupgradeplts(a_objectid      udt_id,
                                   a_asofdate      DATE,
                                   a_jobid         udt_id);

    ----------------------------------------------------------------------------------------------------
    --  CopyPriorityLicenseTypes() -- PUBLIC
    --  This will copy the Priority License Type rels to the normal rels
    ----------------------------------------------------------------------------------------------------

    PROCEDURE copyprioritylicensetyperels(a_objectid      udt_id,
                                          a_asofdate      DATE,
                                          a_jobid         udt_id);

    ----------------------------------------------------------------------------------------------------
    --  CopyUpgradeRelationship() -- PUBLIC
    --  This will copy the Upgrading from License to either the License Transferring From rel or
    --   the License rel.
    ----------------------------------------------------------------------------------------------------

    PROCEDURE copyupgraderelationship(a_objectid udt_id, a_asofdate DATE);

    ----------------------------------------------------------------------------------------------------
    --  CopyUpgradeRelationship() -- PUBLIC
    --  This will copy the Status from the Primary License Type on to the realtionship
    --  between the primary and the catagory, run on contructor of the relationship and on
    --  status change
    ----------------------------------------------------------------------------------------------------

    PROCEDURE copyprimarylicensetypestatus(a_objectid      udt_id,
                                           a_asofdate      DATE);
END pkg_copy;
/
