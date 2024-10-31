CREATE OR REPLACE PACKAGE BIZMOD_API.pkg_abis
AS
    -- **************************************************************************
    -- File:        BIZMOD_API.PKG_ABIS.PKS
    -- Author:      Timothy J. Lord
    --
    -- History:
    -----------------------------------------------------------------------------
    --    Ver:     Date                       Comment
    --     1.1   07/01/2024  TJL BIZ-15808  Move and renamed package from
    --                          (BIZ-15812)   SITESPECIFIC.PKG_CATERING and added
    --                                        new procedures and functions to support
    --                                        License Applications
    --     2.0    09/30/2024 BN   BIZ-16397  ERROR notification to LSP
    -- **************************************************************************
    PROCEDURE cateringnotifylsp(a_objectid     IN api.pkg_definition.udt_id,
                                a_asofdate     IN DATE);

    PROCEDURE newfee(a_objectid     IN api.pkg_definition.udt_id,
                     a_asofdate        DATE);

    PROCEDURE applicationsave(a_objectid     IN api.pkg_definition.udt_id,
                              a_asofdate     IN DATE,
                              a_jobid        IN api.pkg_definition.udt_id,
                              a_status       IN VARCHAR2 DEFAULT NULL);
--    PROCEDURE applicationsave(a_objectid     IN api.pkg_definition.udt_id,
--                              a_asofdate     IN DATE,
--                              a_jobid        IN VARCHAR2);
END;
/


GRANT EXECUTE ON BIZMOD_API.PKG_ABIS TO PUBLIC;
