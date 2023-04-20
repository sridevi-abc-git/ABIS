CREATE OR REPLACE PACKAGE SITESPECIFIC.pkg_tllead
AS
    -- **************************************************************************
    -- File:        PKG_TLLEAD.PKS
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

    SUBTYPE udt_id IS api.pkg_definition.udt_id;

    PROCEDURE createregistrationconfirmid(a_objectid udt_id, a_asofdate DATE);

    PROCEDURE createstudentregistration(a_objectid udt_id, a_asofdate DATE);
END pkg_tllead;
/
