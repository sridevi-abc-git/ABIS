CREATE OR REPLACE FUNCTION ABC.get_app_masterindicator(
    p_applicationjobid IN NUMBER)
    RETURN VARCHAR
IS
    -- **************************************************************************
    -- File:        GET_APP_MASTERINDICATOR.FNC
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
    -- 08/22/2018 TJL         Initial Check-in
    -- **************************************************************************
    v_yes     VARCHAR2(1);
    l_check   NUMBER;
BEGIN
    BEGIN
        SELECT COUNT(*)
          INTO l_check
          FROM query.j_application  app
               JOIN query.r_appprimarylicensetype aplt
                   ON aplt.applicationobjectid = app.jobid
               JOIN query.o_primarylicensetype plt
                   ON plt.objectid = aplt.licensetypeobjectid
               JOIN query.r_priltltcatsecondary rpcs
                   ON rpcs.primarylicensetypeobjectid = plt.objectid
         WHERE app.jobid = p_applicationjobid;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            v_yes   := 'N';
        WHEN OTHERS THEN
            v_yes   := 'N';
    END;

    IF l_check > 0 THEN
        v_yes   := 'Y';
    ELSE
        v_yes   := 'N';
    END IF;

    RETURN (v_yes);
END;
/


GRANT EXECUTE ON ABC.GET_APP_MASTERINDICATOR TO POSSEEXTENSIONS;
