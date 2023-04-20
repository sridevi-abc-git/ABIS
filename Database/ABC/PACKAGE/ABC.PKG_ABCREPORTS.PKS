CREATE OR REPLACE PACKAGE ABC.pkg_abcreports
AS
    -- **************************************************************************
    -- File:        PKG_ABCREPORTS.PKS
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
    * Types
    *-------------------------------------------------------------------------*/
    SUBTYPE udt_id IS api.pkg_definition.udt_id;

    SUBTYPE udt_endpoint IS api.pkg_definition.udt_endpoint;

    SUBTYPE udt_objectlist IS api.udt_objectlist;

    PROCEDURE abc229bulk(a_objectid udt_id);

    PROCEDURE abc220assignmentoverview(a_objectid udt_id);

    PROCEDURE abc61batchmultiprint(a_objectid udt_id);

    PROCEDURE abc61assignmentoverview(a_objectid udt_id);
END pkg_abcreports;
/


GRANT EXECUTE ON ABC.PKG_ABCREPORTS TO POSSEEXTENSIONS;
