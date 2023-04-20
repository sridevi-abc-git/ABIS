CREATE OR REPLACE FUNCTION ABC.getmart_masterindi(lt_objectid NUMBER)
    RETURN VARCHAR2
IS
    -- **************************************************************************
    -- File:        GETMART_MASTERINDI.FNC
    -- Author:      CX
    --
    -- $Rev$
    -- $Date$
    -- Last Changed By:  $Author$
    --
    -- Description:
    --      Returns the Master Indicator for License Types 02
    --      pass in mart.licensetype ObjectId (mart.licensetype:ObjectId)
    --
    --
    -- History:
    -----------------------------------------------------------------------------
    --    Date                  Comment
    -- 08/22/2018 TJL         Initial Check-in
    -- **************************************************************************
    t_data   VARCHAR2(10);
BEGIN
    SELECT NVL2(r2.relationshipid, 'N', 'Y') master_ind
      INTO t_data
      FROM mart.licensetype  lt
           JOIN mart.primaryandsecondarylicencetype r
               ON lt.objectid = r.licensetypeobjectid
           JOIN mart.licensetypecategory ltc
               ON r.licensecetypecategoryobjectid = ltc.objectid
           LEFT OUTER JOIN mart.branchlicensetype r2
               ON r2.branchlicensetypejobid = lt.objectid
     WHERE lt.objectid = lt_objectid;

    RETURN t_data;
END getmart_masterindi;
/


GRANT EXECUTE ON ABC.GETMART_MASTERINDI TO POSSEEXTENSIONS;

GRANT EXECUTE ON ABC.GETMART_MASTERINDI TO PUBLIC;
