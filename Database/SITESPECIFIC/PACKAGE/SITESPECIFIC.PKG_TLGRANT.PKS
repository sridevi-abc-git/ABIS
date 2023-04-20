CREATE OR REPLACE PACKAGE SITESPECIFIC.pkg_tlgrant
IS
    -- **************************************************************************
    -- File:        PKG_TLGRANT.PKS
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

    /******************************************************************
    getLicenseInformation is run on LicenseTRacker Object supplied license number
    confirm that it is a valid license and get the following DBA, Prem Address
    ******************************************************************/
    PROCEDURE getlicenseinformation(a_objectid      udt_id,
                                    a_asofdate      DATE,
                                    a_licensenumber VARCHAR2);
END pkg_tlgrant;
/
