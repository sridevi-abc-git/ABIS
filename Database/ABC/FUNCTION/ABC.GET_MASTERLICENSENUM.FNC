CREATE OR REPLACE FUNCTION ABC.get_masterlicensenum(lt_objectid NUMBER)
    -- **************************************************************************
    -- File:        GET_MASTERLICENSENUM.FNC
    -- Author:      CX
    --
    -- $Rev$
    -- $Date$
    -- Last Changed By:  $Author$
    --
    -- Description:
    --      Returns the Master License Number for Branch Licenses
    --      For both Applicatoin or License,
    --      pass in mart.licensetype Object ID
    --
    --
    -- History:
    -----------------------------------------------------------------------------
    --    Date                  Comment
    -- 08/22/2018 TJL         Initial Check-in
    -- **************************************************************************


    RETURN VARCHAR2
IS
    t_mlicensenum   VARCHAR2(50);
BEGIN
    SELECT UNIQUE
           (SELECT mlt.licensenumber
              FROM mart.branchlicensetype  r
                   JOIN mart.licensetype mlt
                       ON mlt.objectid = r.masterlicensetypejobid
             WHERE r.branchlicensetypejobid = lt.objectid)
               masterlicensenumber
      -- nvl2(r2.RELATIONSHIPID,'N','Y') Master_ind,
      -- nvl2(r2.RelationshipId,1,nvl(R.LICENSETYPECOUNT, 0)) Duplicate_count
      INTO t_mlicensenum
      FROM mart.licensetype  lt
           JOIN mart.primaryandsecondarylicencetype r
               ON lt.objectid = r.licensetypeobjectid
           JOIN mart.licensetypecategory ltc
               ON r.licensecetypecategoryobjectid = ltc.objectid
           LEFT OUTER JOIN mart.branchlicensetype r2
               ON r2.branchlicensetypejobid = lt.objectid
     WHERE lt.objectid = lt_objectid;

    RETURN t_mlicensenum;
END get_masterlicensenum;
/


GRANT EXECUTE ON ABC.GET_MASTERLICENSENUM TO POSSEEXTENSIONS;

GRANT EXECUTE ON ABC.GET_MASTERLICENSENUM TO PUBLIC;
