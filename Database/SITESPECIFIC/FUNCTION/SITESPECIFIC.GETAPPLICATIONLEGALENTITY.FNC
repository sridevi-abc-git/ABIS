CREATE OR REPLACE FUNCTION SITESPECIFIC.getapplicationlegalentity(
    a_applicationjobid NUMBER,
    a_person        CHAR,
    a_count         NUMBER)
    RETURN VARCHAR
IS
    -- **************************************************************************
    -- File:        GETAPPLICATIONLEGALENTITY.FNC
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
        sitespecific.getapplicantlegalentityid(a_applicationjobid,
                                               a_person,
                                               a_count);
    t_formattedname   :=
        api.pkg_columnquery.VALUE(t_objectid, 'FormattedName');

    RETURN t_formattedname;
END getapplicationlegalentity;
/


GRANT EXECUTE ON SITESPECIFIC.GETAPPLICATIONLEGALENTITY TO POSSEEXTENSIONS;
