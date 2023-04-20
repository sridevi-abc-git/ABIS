CREATE OR REPLACE FUNCTION SITESPECIFIC.bankersround(
    a_number        NUMBER,
    a_digitsafterdecimal NUMBER := 2)
    RETURN NUMBER
IS
    -- **************************************************************************
    -- File:        BANKERSROUND.FNC
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
    t_digitsafterdecimal   NUMBER;
    t_remainder            NUMBER;
BEGIN
    t_digitsafterdecimal   := TRUNC(a_digitsafterdecimal);
    t_remainder            :=
          (a_number - TRUNC(a_number, t_digitsafterdecimal))
        * POWER(10, t_digitsafterdecimal + 1);

    IF ABS(t_remainder) < 5
    OR (ABS(t_remainder) = 5
    AND MOD(TRUNC(a_number * POWER(10, t_digitsafterdecimal)), 2) = 0) THEN
        RETURN TRUNC(a_number, t_digitsafterdecimal);
    ELSE
        RETURN ROUND(a_number, t_digitsafterdecimal);
    END IF;
END;
/


GRANT EXECUTE ON SITESPECIFIC.BANKERSROUND TO ABCREPORTS;
