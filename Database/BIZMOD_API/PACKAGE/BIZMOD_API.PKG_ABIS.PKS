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
    --     3.0.1  04/03/2028 TJL  BIZ-17503  Added common applications procedures
    --     4.0.0  07/17/2025 TJL  BIZ-18875  Added manual payment procedure
    --     5.0.0  08/19/2025 TJL  BIZ-19133  Added membership_stock_transfers procedure
    --     5.1.0  09/15/2025 TJL  BIZ-19212  Added fee_notification procedure.
    -- **************************************************************************
    PROCEDURE cateringnotifylsp(a_objectid     IN api.pkg_definition.udt_id,
                                a_asofdate     IN DATE);

    PROCEDURE newfee(a_objectid     IN api.pkg_definition.udt_id,
                     a_asofdate        DATE);

    PROCEDURE applicationsave(a_objectid     IN api.pkg_definition.udt_id,
                              a_asofdate     IN DATE,
                              a_jobid        IN api.pkg_definition.udt_id,
                              a_status       IN VARCHAR2 DEFAULT NULL);

    PROCEDURE manualpayment(a_objectid     IN api.pkg_definition.udt_id,
                            a_asofdate     IN DATE,
                            a_jobid        IN api.pkg_definition.udt_id);

    PROCEDURE fee_notification(a_objectid     IN api.pkg_definition.udt_id,
                               a_asofdate     IN DATE,
                               a_jobid        IN api.pkg_definition.udt_id);

    PROCEDURE add_secondary_license_types(
        a_primary_objectid IN api.pkg_definition.udt_id,
        a_licensetypecodeobjectid IN api.pkg_definition.udt_id,
        a_secondary_license_types IN CLOB);

    PROCEDURE add_primary_license_types(
        a_jobid        IN api.pkg_definition.udt_id,
        a_primarylicensetypes IN CLOB);

    PROCEDURE add_title(a_entityobjectid IN api.pkg_definition.udt_id,
                        a_legal_entity IN CLOB);

    PROCEDURE add_address(a_jobid        IN api.pkg_definition.udt_id,
                          a_address_type IN VARCHAR2,
                          a_address      IN CLOB);

    PROCEDURE copy_legal_entities(
        a_objectid     IN api.pkg_definition.udt_id,
        a_legal_entity IN CLOB);

    PROCEDURE add_attorney(a_jobid        IN api.pkg_definition.udt_id,
                           a_attorney     IN CLOB);

    PROCEDURE add_escrow(a_jobid        IN api.pkg_definition.udt_id,
                         a_escrow       IN CLOB);

    FUNCTION create_legalentity(a_parent       IN api.pkg_definition.udt_id,
                                a_child        IN api.pkg_definition.udt_id,
                                a_endpointid   IN api.pkg_definition.udt_id,
                                a_percentageofownership IN VARCHAR2,
                                a_ownertype    IN VARCHAR2,
                                a_title        IN VARCHAR2)
        RETURN api.pkg_definition.udt_id;

    PROCEDURE add_person(a_entityobjectid IN api.pkg_definition.udt_id,
                         a_person       IN CLOB);

    PROCEDURE add_company(a_entityobjectid IN api.pkg_definition.udt_id,
                          a_legal_entity IN CLOB);

    PROCEDURE membership_stock_transfers(
        a_jobid        IN api.pkg_definition.udt_id,
        a_legal_entities IN CLOB);

    PROCEDURE exchange_primary_license_types(
        a_jobid        IN api.pkg_definition.udt_id,
        a_primarylicensetypes IN CLOB);

END;
/


GRANT EXECUTE ON BIZMOD_API.PKG_ABIS TO PUBLIC;
