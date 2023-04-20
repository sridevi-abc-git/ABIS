CREATE OR REPLACE PACKAGE BIZMOD_API.utl_licenseinfo
AS
    FUNCTION statusmatrix(a_status IN VARCHAR2)
        RETURN VARCHAR2;

    FUNCTION licensetypes(a_licensejobid IN api.pkg_definition.udt_id)
        RETURN CLOB;

    FUNCTION secondary(a_licensetypejobid IN api.pkg_definition.udt_id)
        RETURN CLOB;

    FUNCTION conditions_count(t_licensejobid NUMBER,
                              t_licensetypejobid NUMBER)
        RETURN VARCHAR2;

    FUNCTION legalentities(a_objectid IN api.pkg_definition.udt_id)
        RETURN CLOB;
END;
/


GRANT EXECUTE ON BIZMOD_API.UTL_LICENSEINFO TO ABC;

GRANT EXECUTE ON BIZMOD_API.UTL_LICENSEINFO TO BIZMOD_USER;
