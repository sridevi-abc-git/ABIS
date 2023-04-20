CREATE OR REPLACE PACKAGE SITESPECIFIC.pkg_reprintlicenses
AS
    -- **************************************************************************
    -- File:        PKG_REPRINTLICENSES.PKS
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

    /*--------------------------
    -- ManualProduceLicense() PUBLIC
    -- This will load a GTT for the Green and Pink License Report
    ---------------------------*/
    PROCEDURE manualproducelicense_fix(a_objectid udt_id);
END pkg_reprintlicenses;
/
