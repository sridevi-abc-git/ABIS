CREATE OR REPLACE PACKAGE SITESPECIFIC.pkg_gis
IS
    -- **************************************************************************
    -- File:        PKG_GIS.pks
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

    /*------------------------------------------------------------------------*
     * Types
     *------------------------------------------------------------------------*/
    SUBTYPE udt_id IS api.pkg_definition.udt_id;

    /*------------------------------------------------------------------------*
     *  GeocodeAddress() -- PUBLIC
     *------------------------------------------------------------------------*/
    PROCEDURE geocodeaddress (a_objectid udt_id, a_asofdate DATE);

    FUNCTION callwebservice (a_operation VARCHAR2, a_parameters VARCHAR2)
        RETURN BOOLEAN;

    /*------------------------------------------------------------------------*
     *  AddAddressByGeocoding() -- PUBLIC
     *------------------------------------------------------------------------*/
    FUNCTION addaddressbygeocoding (a_jobid udt_id, a_asofdate DATE)
        RETURN BOOLEAN;

    /*------------------------------------------------------------------------*
     *  AddAddressAtLocation() -- PUBLIC
     *------------------------------------------------------------------------*/
    FUNCTION addaddresspointatlocation (a_jobid udt_id, a_asofdate DATE)
        RETURN BOOLEAN;

    /*------------------------------------------------------------------------*
     *  DeleteAddressPoint() -- PUBLIC
     *------------------------------------------------------------------------*/
    PROCEDURE deleteaddresspoint (a_objectid udt_id, a_asofdate DATE);

    /*------------------------------------------------------------------------*
     *  UpdatePointFromPLT() -- PUBLIC
     *------------------------------------------------------------------------*/
    PROCEDURE updatepointfromplt (a_objectid udt_id, a_asofdate DATE);

    /*------------------------------------------------------------------------*
     *  UpdatePointFromLT() -- PUBLIC
     *------------------------------------------------------------------------*/
    PROCEDURE updatepointfromlt (a_objectid udt_id, a_asofdate DATE);

    /*------------------------------------------------------------------------*
     *  AddGeocodedAddressFromRel() -- PUBLIC
     *------------------------------------------------------------------------*/
    PROCEDURE addgeocodedaddressfromrel (a_relationshipid   udt_id,
                                         a_asofdate         DATE);

    /*------------------------------------------------------------------------*
     *  DeleteGeocodedAddressFromRel() -- PUBLIC
     *------------------------------------------------------------------------*/
    PROCEDURE deletegeocodedaddressfromrel (a_relationshipid   udt_id,
                                            a_asofdate         DATE);
END pkg_gis;

/


GRANT EXECUTE ON SITESPECIFIC.PKG_GIS TO EXTENSION;

GRANT EXECUTE ON SITESPECIFIC.PKG_GIS TO POSSESYS;
