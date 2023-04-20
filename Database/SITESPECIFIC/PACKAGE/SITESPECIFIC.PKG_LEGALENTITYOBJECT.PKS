CREATE OR REPLACE PACKAGE SITESPECIFIC.pkg_legalentityobject
IS
    -- **************************************************************************
    -- File:        PKG_LEGALENTITYOBJECT.PKS
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

    -- Author  : Michael Froese
    -- Created : 9/9/2016 8:55:10 8:55:10
    -- Purpose : Post-verify management assistance

    -- Public type declarations
    SUBTYPE udt_id IS api.pkg_definition.udt_id;

    PROCEDURE postverify(a_objectid udt_id, a_asofdate DATE);

    PROCEDURE maintainhierarchydata(a_objectid udt_id);

    PROCEDURE markprocessed(a_objectid udt_id);

    PROCEDURE verifymanagement(a_objectid udt_id, a_asofdate DATE);

    PROCEDURE updatehierarchyonly(a_objectid udt_id);

    PROCEDURE replacerootrel(a_nodeobjectid udt_id, a_rootobjectid udt_id);
END pkg_legalentityobject;

/


GRANT EXECUTE ON SITESPECIFIC.PKG_LEGALENTITYOBJECT TO POSSEEXTENSIONS;
