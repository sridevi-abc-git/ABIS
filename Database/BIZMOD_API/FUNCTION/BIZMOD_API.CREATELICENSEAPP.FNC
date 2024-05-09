CREATE OR REPLACE FUNCTION BIZMOD_API.CREATELICENSEAPP(a_packet       IN CLOB,
                                                           a_seq          IN NUMBER)
        RETURN CLOB
    IS
    -- ****************************************************************************
    -- File:        BIZMOD_API.CREATELICENSEAPP.PRC
    -- Author:      Timothy J. Lord
    --
    -- Purpose :
    --
    -- History:
    -------------------------------------------------------------------------------
    --          Date                         Comment
    --   1.0  05/02/2024  TJL  BIZ-15444  Initial Package Created
    -- ****************************************************************************

BEGIN

        bizmod_api.createjob(a_procedure => 'CREATELICENSEAPPJOB',
                             a_description => 'Create License Application',
                             a_argument1 => a_seq);
return null;
END;
/
