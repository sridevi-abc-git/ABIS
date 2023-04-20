CREATE OR REPLACE FUNCTION ABC.gen_firstrenewal_penalty(
    a_feeschedid   IN api.pkg_definition.udt_id,
    a_ismaster     IN VARCHAR2)
    RETURN NUMBER
IS
    -- **************************************************************************
    -- File:        GEN_FIRSTRENEWAL_PENALTY.FNC
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
    -- 08/21/2018 TJL         Initial Check-in
    -- **************************************************************************
    v_penalty   NUMBER := 0;
BEGIN
    BEGIN
        SELECT DECODE(a_ismaster,
                      'Y', f2.primaryamount - f.primaryamount,
                      f2.secondaryamount - f.secondaryamount)
                   penaltyamt
          INTO v_penalty
          FROM sitespecific.feeschedule_t  f
               JOIN sitespecific.feeschedule_t f2
                   ON f2.licensetypecode = f.licensetypecode
                  AND f2.feeactivity = f.feeactivity || '50'
                  AND f2.description = REPLACE(f.description, 'REN', 'REN50')
                  AND api.pkg_columnquery.VALUE(f2.objectid, 'FeeCode') =
                      api.pkg_columnquery.VALUE(f.objectid, 'FeeCode')
         WHERE f.objectid = a_feeschedid;
    END;

    RETURN v_penalty;
END gen_firstrenewal_penalty;
/


GRANT EXECUTE ON ABC.GEN_FIRSTRENEWAL_PENALTY TO POSSEEXTENSIONS;
