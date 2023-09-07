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
    -- ****************************************************************************

    FUNCTION statusmatrix(a_status IN VARCHAR2)
        RETURN VARCHAR2;

    PROCEDURE clean(a_json IN OUT json_object_t);

    FUNCTION awfrequired(a_licensetypeobjectid in NUMBER)
        RETURN NUMBER;
        
    FUNCTION get_awfreninfo(a_fiscalend IN DATE, a_jobid IN NUMBER)
        RETURN NUMBER;
                             
END;
/


GRANT EXECUTE ON BIZMOD_API.UTL_LICENSEINFO TO ABC;

GRANT EXECUTE ON BIZMOD_API.UTL_LICENSEINFO TO BIZMOD_USER;
