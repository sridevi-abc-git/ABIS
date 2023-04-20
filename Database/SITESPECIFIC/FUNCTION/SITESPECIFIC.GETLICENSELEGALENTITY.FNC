CREATE OR REPLACE FUNCTION SITESPECIFIC.getlicenselegalentity(
    a_licensejobid  NUMBER,
    a_person        CHAR,
    a_count         NUMBER)
    RETURN VARCHAR
IS
    -- **************************************************************************
    -- File:        GETLICENSELEGALENTITY.FNC
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
    t_formattedname   VARCHAR2(250);
    t_objectid        NUMBER;
BEGIN
    t_objectid   :=
        sitespecific.getlicenselegalentityid(a_licensejobid,
                                             a_person,
                                             a_count);
    t_formattedname   :=
        api.pkg_columnquery.VALUE(t_objectid, 'FormattedName');

    RETURN t_formattedname;
END getlicenselegalentity;
/


GRANT EXECUTE ON SITESPECIFIC.GETLICENSELEGALENTITY TO POSSEEXTENSIONS;
