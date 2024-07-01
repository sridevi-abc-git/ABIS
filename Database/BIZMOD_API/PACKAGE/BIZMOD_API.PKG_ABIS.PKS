CREATE OR REPLACE PACKAGE BIZMOD_API.PKG_ABIS
AS
    -- **************************************************************************
    -- File:        BIZMOD_API.PKG_ABIS.PKS
    -- Author:      Timothy J. Lord
    --
    -- History:
    -----------------------------------------------------------------------------
    --    Ver:     Date                       Comment
    --     1.0   11/01/2023  TJL BIZ-12802  Initial Package Created
    --     3.0   07/01/2024  TJL BIZ-15444  Move and renamed package from 
    --                                        SITESPECIFIC.PKG_CATERING and added
    --                                        new procedures and functions to support
    --                                        License Applications
    -- **************************************************************************
    PROCEDURE cateringnotifylsp(a_objectid api.pkg_definition.udt_id, a_asofdate DATE);

    PROCEDURE newfee(a_objectid IN api.pkg_definition.udt_id, a_asofdate DATE);
END;
/
