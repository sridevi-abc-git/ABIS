CREATE OR REPLACE PACKAGE BIZMOD_API.utl_licenseinfo
AS
    -- ****************************************************************************
    -- File:        BIZMOD_API.UTL_LICENSEINFO.PKS
    -- Author:      Timothy J. Lord
    --
    -- Purpose:
    --
    -- History:
    -------------------------------------------------------------------------------
    --   VER:      Date           Ticket     Comment
    --   2.1    07/25/2023  TJL  BIZ-12102    Added procedure get_awfreninfo
    --   4.0    10/18/2023  TJL  BIZ-12887    Added new function to allow ABIS to send information to LSP
    --                                          HTTPS endpoints. Function CALLLSP
    --   4.1    12/07/2023  TJL  BIZ-12802    Removed old CALLLSP function
    -- ****************************************************************************

    FUNCTION calllsp(a_url           IN VARCHAR2,
                     a_method        IN VARCHAR2,
                     a_content       IN CLOB,
                     a_file          IN BLOB)
        RETURN CLOB;

    FUNCTION statusmatrix(a_status IN VARCHAR2)
        RETURN VARCHAR2;

    PROCEDURE clean(a_json IN OUT json_object_t);

    FUNCTION awfrequired(a_licensetypeobjectid IN NUMBER)
        RETURN NUMBER;

    FUNCTION get_awfreninfo(a_fiscalend IN DATE, a_jobid IN NUMBER)
        RETURN NUMBER;
END;
/


GRANT EXECUTE ON BIZMOD_API.UTL_LICENSEINFO TO ABC;

GRANT EXECUTE ON BIZMOD_API.UTL_LICENSEINFO TO BIZMOD_USER;

GRANT EXECUTE ON BIZMOD_API.UTL_LICENSEINFO TO SITESPECIFIC;
