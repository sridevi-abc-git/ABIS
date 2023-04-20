CREATE OR REPLACE FUNCTION SITESPECIFIC."COUNTYDRAW"(
    a_countyobjectid api.pkg_definition.udt_id,                        --19031
    a_conda         VARCHAR2,                                            --'Y'
    a_retailtype    VARCHAR2,                    --null, 'Off-Sale', 'On-Sale'
    a_prioritydrawlt VARCHAR2,                                           --'Y'
    a_onsaleprioritydrawcou VARCHAR2                                     --'Y'
                                    )
    RETURN NUMBER
IS
    -- **************************************************************************
    -- File:        COUNTYDRAW.FNC
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
    t_drawcount   NUMBER := 0;
BEGIN
    SELECT COUNT(DISTINCT rlap.licensejobid) licensejobid
      INTO t_drawcount
      FROM query.r_addresscounty  ac
           JOIN query.r_licenseaddrpremises rlap
               ON rlap.premisesobjectid = ac.addressobjectid
     WHERE ac.countyobjectid = a_countyobjectid
       AND EXISTS
               (SELECT 1
                  FROM mart.license  l
                       JOIN mart.licenselicensetyperel ltr
                           ON ltr.licensejobid = l.jobid
                       JOIN query.j_licensetype lt
                           ON lt.objectid = ltr.licensetypejobid
                       JOIN mart.licensetypecategoryrel rplc
                           ON rplc.licensetypeobjectid = lt.objectid
                       JOIN mart.licensetypecategory ltc
                           ON ltc.objectid = rplc.licensetypecategoryid
                 WHERE l.jobid = rlap.licensejobid
                   AND EXISTS
                           (SELECT 1
                              FROM api.jobstatuses js
                             WHERE js.jobtypeid = lt.jobtypeid
                               AND js.statusid = lt.statusid
                               AND js.statustype IN ('I', 'O'))
                   AND (lt.conda = a_conda
                     OR a_conda IS NULL)
                   AND (ltc.retailtype = a_retailtype
                     OR a_retailtype IS NULL)
                   AND ltc.prioritydrawlicensetype = a_prioritydrawlt
                   AND (api.pkg_columnquery.VALUE(
                            ltc.objectid,
                            'IncludeInOnSalePriorityDrawCou') =
                        a_onsaleprioritydrawcou
                     OR a_onsaleprioritydrawcou IS NULL));

    RETURN t_drawcount;
END;
/


GRANT EXECUTE ON SITESPECIFIC.COUNTYDRAW TO POSSEEXTENSIONS;
