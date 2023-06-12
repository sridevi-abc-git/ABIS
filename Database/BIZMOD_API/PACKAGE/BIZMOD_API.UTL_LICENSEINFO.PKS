CREATE OR REPLACE PACKAGE BIZMOD_API.utl_licenseinfo
AS
    FUNCTION statusmatrix(a_status IN VARCHAR2)
        RETURN VARCHAR2;

    PROCEDURE clean(a_json IN OUT json_object_t);

    FUNCTION awfrequired(a_licensetypeobjectid in NUMBER)
        RETURN VARCHAR2;
END;
/
