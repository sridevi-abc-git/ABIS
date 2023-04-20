CREATE OR REPLACE FUNCTION ABC.get_dupcount(lt_objectid NUMBER)
    -- **************************************************************************
    -- File:        GET_DUPCOUNT.FNC
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

    -- Returns the Master License Number for Branch Licenses
    -- For both Applicatoin or License,
    -- pass in mart.licensetype Object ID

    RETURN NUMBER
IS
    t_master   NUMBER;
BEGIN
    SELECT UNIQUE                                  --(select mlt.LicenseNumber
           --                from mart.BranchLicenseType r
           --                join mart.LicenseType mlt on mlt.ObjectId = r.MasterLicenseTypeJobId
           --                where r.BranchLicenseTypeJobId = lt.ObjectId) MasterLicenseNumber
           --    nvl2(r2.RELATIONSHIPID,'N','Y') Master_ind
           NVL2(r2.relationshipid, 1, NVL(r.licensetypecount, 0))
               duplicate_count
      INTO t_master
      FROM mart.licensetype  lt
           JOIN mart.primaryandsecondarylicencetype r
               ON lt.objectid = r.licensetypeobjectid
           JOIN mart.licensetypecategory ltc
               ON r.licensecetypecategoryobjectid = ltc.objectid
           LEFT OUTER JOIN mart.branchlicensetype r2
               ON r2.branchlicensetypejobid = lt.objectid
     WHERE lt.objectid = lt_objectid;

    RETURN t_master;
END get_dupcount;
/


GRANT EXECUTE ON ABC.GET_DUPCOUNT TO POSSEEXTENSIONS;

GRANT EXECUTE ON ABC.GET_DUPCOUNT TO PUBLIC;
