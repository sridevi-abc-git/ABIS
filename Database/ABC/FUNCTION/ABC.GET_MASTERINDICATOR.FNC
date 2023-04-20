CREATE OR REPLACE FUNCTION ABC.get_masterindicator(lt_objectid NUMBER)
    -- **************************************************************************
    -- File:        GET_MASTERINDICATOR.FNC
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
    t_master   VARCHAR2(50);
BEGIN
    SELECT UNIQUE                                  --(select mlt.LicenseNumber
                  --                from mart.BranchLicenseType r
                  --                join mart.LicenseType mlt on mlt.ObjectId = r.MasterLicenseTypeJobId
                  --                where r.BranchLicenseTypeJobId = lt.ObjectId) MasterLicenseNumber
                  NVL2(r2.relationshipid, 'N', 'Y') master_ind
      -- nvl2(r2.RelationshipId,1,nvl(R.LICENSETYPECOUNT, 0)) Duplicate_count
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
END get_masterindicator;
/


GRANT EXECUTE ON ABC.GET_MASTERINDICATOR TO POSSEEXTENSIONS;

GRANT EXECUTE ON ABC.GET_MASTERINDICATOR TO PUBLIC;
