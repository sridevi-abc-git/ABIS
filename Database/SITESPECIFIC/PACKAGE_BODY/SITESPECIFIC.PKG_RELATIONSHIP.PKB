CREATE OR REPLACE PACKAGE BODY SITESPECIFIC.pkg_relationship
AS
    -- **************************************************************************
    -- File:        PKG_RELATIONSHIP.PKB
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
    -- 08/16/2018 TJL         Initial Check-in
    -- **************************************************************************

    /*---------------------------------------------------------------------------
     * RecentJobProcesses() -- PUBLIC
     * Written by: Andy Patterson (CXUSA)
     * Created on: 9/15/2015
     * Modified on: 5/11/2017  by MikeM
     * This is a procedural relationship used to register external o_Process
     * objects and return those that were created within the last 12 months
     * or where the process is incomplete.
     *-------------------------------------------------------------------------*/
    PROCEDURE recentjobprocesses(a_objectid         udt_id,
                                 a_endpointid       udt_id,
                                 a_relatedobjectids OUT api.udt_objectlist)
    IS
        t_prcexdefid         udt_id
            := api.pkg_configquery.objectdefidforname('o_Process');
        t_processids         api.pkg_definition.udt_idlist;
        t_threshold          DATE := ADD_MONTHS(SYSDATE, -12);
        t_relatedobjectids   api.udt_objectlist;
    BEGIN
        a_relatedobjectids   := api.udt_objectlist();

        -- Tuned to use ScheduledStartDate when possible,
        -- CreatedDate comes from LogicalTransactions and is expensive.
        SELECT p.processid,
               api.udt_object((SELECT ro.objectid
                                 FROM api.registeredexternalobjects ro
                                WHERE ro.linkvalue = TO_CHAR(p.processid)
                                  AND ro.objectdefid = t_prcexdefid))
          BULK COLLECT INTO t_processids, a_relatedobjectids
          FROM api.processes p
         WHERE p.jobid = a_objectid
           AND (p.scheduledstartdate BETWEEN t_threshold AND SYSDATE
             OR p.outcome IS NULL)
        UNION ALL
        SELECT p.processid,
               api.udt_object((SELECT ro.objectid
                                 FROM api.registeredexternalobjects ro
                                WHERE ro.linkvalue = TO_CHAR(p.processid)
                                  AND ro.objectdefid = t_prcexdefid))
          FROM api.processes p
         WHERE p.jobid = a_objectid
           AND p.scheduledstartdate IS NULL
           AND p.createddate BETWEEN t_threshold AND SYSDATE
           AND p.outcome IS NOT NULL;

        -- Manually register any processes that need to be.
        FOR i IN 1 .. a_relatedobjectids.COUNT
        LOOP
            IF a_relatedobjectids(i).objectid IS NULL THEN
                a_relatedobjectids(i)   :=
                    api.udt_object(
                        api.pkg_objectupdate.registerexternalobject(
                            'o_Process',
                            t_processids(i)));
            END IF;
        END LOOP;
    END recentjobprocesses;
END pkg_relationship;
/
