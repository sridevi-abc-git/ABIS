CREATE OR REPLACE PROCEDURE SITESPECIFIC.tl_validateuser(
    a_authenticationname IN VARCHAR2,
    a_msg             OUT VARCHAR2)
IS
    -- **************************************************************************
    -- File:        TL_VALIDATEUSER.PRC
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

    ln_cnt   NUMBER;
BEGIN
    -- check if authorized to access trace lead or is a super user
    SELECT NVL(COUNT(*), 0)
      INTO ln_cnt
      FROM query.users
     WHERE LOWER(authenticationname) = a_authenticationname
       AND (LOWER(accessgroupdescriptions) LIKE '%internal%'
         OR LOWER(accessgroupdescriptions) LIKE '%super users%');

    IF (ln_cnt = 0) THEN
        -- user not found
        a_msg   := 'You are not authorized for this web application';
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        a_msg   := 'Error in validating user';
END;
/


GRANT EXECUTE ON SITESPECIFIC.TL_VALIDATEUSER TO POSSEEXTENSIONS;
