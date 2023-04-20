CREATE OR REPLACE FUNCTION SITESPECIFIC.pendingcountydraw(
    a_objectid      api.pkg_definition.udt_id,                         --19031
    a_retailtype    VARCHAR2,                    --null, 'Off-Sale', 'On-Sale'
    a_prioritydrawlt VARCHAR2                                            --'Y'
                             )
    RETURN NUMBER
IS
    -- ***************************************************************************
    -- File:        PENDINGCOUNTYDRAW.FNC
    -- Author:
    --
    -- $Rev: 4198 $
    -- $Date: 2018-07-19 11:58:51 -0700 (Thu, 19 Jul 2018) $
    -- Last Changed By $Author: pkaur $
    --
    -- Purpose :
    --
    -- History:
    -------------------------------------------------------------------------------
    --    Date         Ticket     Comment
    --  07/19/2018 PK           Initial Package Created
    --  07/19/2018 PK  WO 15744 Improve performance of Prepare for Priority Applications job
    --
    ------------------------------------------------------------------------------
    t_drawcount   NUMBER := 0;
    t_jobtypeid   api.pkg_definition.udt_id;
BEGIN
    t_jobtypeid   := api.pkg_configquery.objectdefidforname('j_application');

    SELECT COUNT(DISTINCT applicationjobid)
      INTO t_drawcount
      FROM (WITH
                applist
                AS
                    (SELECT rpa.applicationjobid
                       FROM query.r_applicationpremaddr rpa
                      WHERE EXISTS
                                (SELECT 1
                                   FROM query.r_addresscounty  ac
                                        JOIN query.o_address a
                                            ON a.objectid =
                                               ac.addressobjectid
                                  WHERE ac.countyobjectid = a_objectid
                                    AND ac.addressobjectid =
                                        rpa.addressobjectid)
                     UNION ALL
                     SELECT rac.applicationjobid
                       FROM query.r_applicationcounty rac
                      WHERE rac.countyobjectid = a_objectid)
            SELECT al.applicationjobid
              FROM applist  al
                   JOIN query.j_application a
                       ON a.objectid = al.applicationjobid
                   JOIN api.statuses s ON s.statusid = a.statusid
                   JOIN api.jobstatuses js ON js.statusid = s.statusid
             WHERE js.statustype IN ('I', 'O')
               AND js.jobtypeid = t_jobtypeid
               AND EXISTS
                       (SELECT 1
                          FROM query.o_licensetypecategory  ltc
                               JOIN query.r_priltltcatprimary pltc
                                   ON ltc.objectid =
                                      pltc.licensetypecategoryobjectid
                               JOIN query.r_appprimarylicensetype rplt
                                   ON rplt.licensetypeobjectid =
                                      pltc.primarylicensetypeobjectid
                         WHERE rplt.applicationobjectid = al.applicationjobid
                           AND ltc.retailtype = a_retailtype
                           AND ltc.prioritydrawlicensetype = a_prioritydrawlt))
           ids;


    RETURN t_drawcount;
END;
/


GRANT EXECUTE ON SITESPECIFIC.PENDINGCOUNTYDRAW TO POSSEEXTENSIONS;
