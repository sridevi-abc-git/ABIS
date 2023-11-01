CREATE OR REPLACE PACKAGE SITESPECIFIC.pkg_catering
AS
    -- **************************************************************************
    -- File:        PSITESPECIFIC.PKG_CATERING.PKS
    -- Author:      Timothy J. Lord
    --
    -- History:
    -----------------------------------------------------------------------------
    --    Ver:     Date                       Comment
    --     1.0   11/01/2023  TJL BIZ-12802  Initial Package Created
    -- **************************************************************************
    PROCEDURE cateringnotifylsp(a_objectid udt_id, a_asofdate DATE);
    
END;
/
