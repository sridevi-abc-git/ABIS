CREATE OR REPLACE FUNCTION BIZMOD_API.cateringupdate(a_packet       IN CLOB,
                                          a_seq          IN NUMBER)
    RETURN CLOB
IS
    -- ****************************************************************************
    -- File:        BIZMOD_API.CATERINGUPDATE.FNC
    -- Author:      Timothy J. Lord
    --
    -- Purpose :
    --
    -- History:
    -------------------------------------------------------------------------------
    --    Ver:     Date                       Comment
    --    1.0   08/31/2023  TJL BIZ-12467   Initial Function Created
    -- ****************************************************************************
    t_licensenumber VARCHAR2(10);
    
BEGIN


                bizmod_api.createjob(
                a_procedure => 'cateringupdatejob',
                a_description => 'Catering Application License Number: ' || t_licensenumber,
                a_argument1 => a_seq);

    return null;
END;
/
