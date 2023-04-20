CREATE OR REPLACE PACKAGE BODY SITESPECIFIC.pkg_prioritydraw
AS
    -- **************************************************************************
    -- File:        PKG_PRIORITYDRAW.PKB
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

    gc_countypreprelendpoint     udt_id
        := api.pkg_configquery.endpointidforname('o_CaCounty', 'Application');
    gc_countymanagerelendpoint   udt_id
        := api.pkg_configquery.endpointidforname(
               'o_CaCounty',
               'ManagePriorityApplications');
    gc_priorityappjobtypeid      udt_id
        := api.pkg_configquery.objectdefidforname('j_PrepareForPriorityApp');
    gc_prioritymanagejobtypeid   udt_id
        := api.pkg_configquery.objectdefidforname(
               'j_ManagePriorityApplications');

    /*---------------------------------------------------------------------------
    * CreateCountyRels() PUBLIC
    *  This procedure finds all of the County objects and relates them to a
    *  Prepare for Priority Applications Job.
    *-------------------------------------------------------------------------*/
    PROCEDURE createcountyrels(a_objectid udt_id, a_asofdate DATE)
    IS
        t_relationshipid   udt_id;

        CURSOR counties
        IS
            SELECT objectid FROM query.o_cacounty;
    BEGIN
        FOR c IN counties
        LOOP
            t_relationshipid   :=
                api.pkg_relationshipupdate.new(gc_countypreprelendpoint,
                                               c.objectid,
                                               a_objectid);
            api.pkg_columnupdate.removevalue(c.objectid, 'OffSaleRatio');
            api.pkg_columnupdate.removevalue(c.objectid, 'OffSale');
            api.pkg_columnupdate.removevalue(c.objectid,
                                             'PendingOffSaleGeneral');
            api.pkg_columnupdate.removevalue(c.objectid,
                                             'TotalOffSaleActive');
            api.pkg_columnupdate.removevalue(c.objectid,
                                             'TotalOffSaleAvailable');
            api.pkg_columnupdate.removevalue(c.objectid,
                                             'TenPercentOfOffSaleActive');
            api.pkg_columnupdate.removevalue(c.objectid, 'OffSaleOriginal');
            api.pkg_columnupdate.removevalue(c.objectid,
                                             'OffSaleInterCounty');
            api.pkg_columnupdate.removevalue(c.objectid, 'OnSaleRatio');
            api.pkg_columnupdate.removevalue(c.objectid, 'OnSale');
            api.pkg_columnupdate.removevalue(c.objectid,
                                             'PendingOnSaleGeneral');
            api.pkg_columnupdate.removevalue(c.objectid, 'CodeA');
            api.pkg_columnupdate.removevalue(c.objectid, 'TotalOnSaleActive');
            api.pkg_columnupdate.removevalue(c.objectid,
                                             'TotalOnSaleAvailable');
            api.pkg_columnupdate.removevalue(c.objectid,
                                             'TenPercentOfOnSaleActive');
            api.pkg_columnupdate.removevalue(c.objectid, 'OnSaleOriginal');
            api.pkg_columnupdate.removevalue(c.objectid, 'OnSaleIntercounty');
        END LOOP;
    END createcountyrels;

    /*---------------------------------------------------------------------------
    * CreateManagePriorityAppSubjobs()
    *  This procedure creates a subjob for each County attached to a
    *  Prepare for Priority Applications job
    *-------------------------------------------------------------------------*/
    PROCEDURE createmanagepriorityappsubjobs(a_objectid      udt_id,
                                             a_asofdate      DATE,
                                             a_jobid         udt_id)
    IS
        t_jobid             udt_id;
        t_newrelid          udt_id;
        t_sequenceid        udt_id;
        t_externalfilenum   VARCHAR2(11);

        CURSOR counties
        IS
            SELECT co.objectid,
                   co.county,
                   co.countycode,
                   co.onsaleoriginal,
                   co.onsaleintercounty,
                   co.offsaleoriginal,
                   co.offsaleintercounty,
                   co.prioritydrawingdate
              FROM query.o_cacounty co
             WHERE (co.onsaleoriginal > 0
                 OR co.onsaleintercounty > 0
                 OR co.offsaleoriginal > 0
                 OR co.offsaleintercounty > 0);
    BEGIN
        FOR c IN counties
        LOOP
            t_jobid   :=
                api.pkg_jobupdate.new(gc_prioritymanagejobtypeid,
                                      c.county,
                                      NULL,
                                      a_jobid);

            SELECT sequenceid
              INTO t_sequenceid
              FROM api.sequences
             WHERE description = 'Manage Priority Applications';

            t_externalfilenum   :=
                api.pkg_utils.generateexternalfilenum('-{YYYY}-[000]',
                                                      t_sequenceid);

            api.pkg_jobupdate.setexternalfilenum(
                t_jobid,
                c.countycode || t_externalfilenum);

            api.pkg_columnupdate.setvalue(t_jobid,
                                          'OriginalOnSaleCount',
                                          c.onsaleoriginal);

            api.pkg_columnupdate.setvalue(t_jobid,
                                          'IntercountyOnSaleCount',
                                          c.onsaleintercounty);

            api.pkg_columnupdate.setvalue(t_jobid,
                                          'OriginalOffSaleCount',
                                          c.offsaleoriginal);

            api.pkg_columnupdate.setvalue(t_jobid,
                                          'IntercountyOffSaleCount',
                                          c.offsaleintercounty);

            api.pkg_columnupdate.setvalue(t_jobid,
                                          'DrawingDate',
                                          c.prioritydrawingdate);

            t_newrelid   :=
                api.pkg_relationshipupdate.new(gc_countymanagerelendpoint,
                                               c.objectid,
                                               t_jobid);
        END LOOP;
    END createmanagepriorityappsubjobs;

    /**********************************************
    -- RelatePDApplications()
    -- This is run on completion of the Relate PD Applications process on the Manage Priority Applications job. This gets all the PD
    -- Applications from the County related to the Manage job. The procedure gets the Applications related to the County through the
    -- Base File Office relationship.
    **********************************************/
    PROCEDURE relatepdapplications(a_objectid      udt_id,
                                   a_asofdate      DATE,
                                   a_jobid         udt_id)
    IS
        t_endpointid   udt_id;
        t_countyid     udt_id;
        t_relid        udt_id;
    BEGIN
        BEGIN
            SELECT mc.cacountyobjectid
              INTO t_countyid
              FROM query.r_managepriorityappscounty mc
             WHERE mc.managepriorityappsjobid = a_jobid;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                api.pkg_errors.raiseerror(
                    -20000,
                    'There is no County related to job ' || a_jobid);
        END;

        t_endpointid   :=
            api.pkg_configquery.endpointidforname(
                'j_ManagePriorityApplications',
                'PriorityApplication');

        FOR i
            IN (SELECT DISTINCT a.jobid
                  FROM query.o_cacounty  cc
                       JOIN query.r_applicationcounty r
                           ON r.countyobjectid = cc.objectid
                       JOIN query.j_application a
                           ON a.jobid = r.applicationjobid
                 WHERE cc.objectid = t_countyid
                   AND a.ispriorityapplication = 'Y'
                   AND a.statusid IN (SELECT js.statusid
                                        FROM api.jobstatuses js
                                       WHERE js.jobtypeid = a.jobtypeid
                                         AND js.statustype IN ('I', 'O'))
                   AND NOT EXISTS
                           (SELECT 1
                              FROM query.r_managepriorityappsapp x
                             WHERE x.applicationjobid = a.jobid)
                   AND NOT EXISTS
                           (SELECT 1
                              FROM query.r_applicationpremaddr ra
                             WHERE ra.applicationjobid = a.jobid)
                UNION
                SELECT a.jobid
                  FROM query.o_cacounty  cc
                       JOIN query.r_cacountycacity ca
                           ON ca.cacountyobjectid = cc.objectid
                       JOIN query.r_addresscacity ac
                           ON ac.cacityobjectid = ca.cacityobjectid
                       JOIN query.r_applicationpremaddr ra
                           ON ra.addressobjectid = ac.addressobjectid
                       JOIN query.j_application a
                           ON a.jobid = ra.applicationjobid
                 WHERE cc.objectid = t_countyid
                   AND a.ispriorityapplication = 'Y'
                   AND a.statusid IN (SELECT js.statusid
                                        FROM api.jobstatuses js
                                       WHERE js.jobtypeid = a.jobtypeid
                                         AND js.statustype IN ('I', 'O'))
                   AND NOT EXISTS
                           (SELECT 1
                              FROM query.r_managepriorityappsapp x
                             WHERE x.applicationjobid = a.jobid)
                   AND NOT EXISTS
                           (SELECT 1
                              FROM query.r_alternatepremisescounty y
                             WHERE y.addressobjectid = ac.addressobjectid)
                UNION
                SELECT a.jobid
                  FROM query.o_cacounty  cc
                       JOIN query.r_alternatepremisescounty apc
                           ON apc.cacountyobjectid = cc.objectid
                       JOIN query.r_applicationpremaddr ra
                           ON ra.addressobjectid = apc.addressobjectid
                       JOIN query.j_application a
                           ON a.jobid = ra.applicationjobid
                 WHERE cc.objectid = t_countyid
                   AND a.ispriorityapplication = 'Y'
                   AND a.statusid IN (SELECT js.statusid
                                        FROM api.jobstatuses js
                                       WHERE js.jobtypeid = a.jobtypeid
                                         AND js.statustype IN ('I', 'O'))
                   AND NOT EXISTS
                           (SELECT 1
                              FROM query.r_managepriorityappsapp x
                             WHERE x.applicationjobid = a.jobid))
        LOOP
            t_relid   :=
                api.pkg_relationshipupdate.new(t_endpointid,
                                               a_jobid,
                                               i.jobid);
        END LOOP;
    END relatepdapplications;

    /**********************************************
     -- RelatePDApplication()
     -- This is run on the creation of the Application to County
     -- relationship to automatically relate the Priority Draw Application
     -- to the Manage Job
     **********************************************/
    PROCEDURE relatepdapplication(a_relationshipid udt_id, a_asofdate DATE)
    IS
        t_applicationjobid   udt_id;
        t_countyid           udt_id;
        t_deleterelid        udt_id;
        t_endpointid         udt_id;
        t_managejobid        udt_id;
        t_relid              udt_id;
    BEGIN
        SELECT ac.countyobjectid, ac.applicationjobid
          INTO t_countyid, t_applicationjobid
          FROM query.r_applicationcounty ac
         WHERE ac.relationshipid = a_relationshipid;

        BEGIN
            SELECT mpaa.relationshipid
              INTO t_deleterelid
              FROM query.r_managepriorityappsapp mpaa
             WHERE mpaa.applicationjobid = t_applicationjobid;

            api.pkg_relationshipupdate.remove(t_deleterelid);
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                NULL;
        END;

        BEGIN
            SELECT MAX(mc.managepriorityappsjobid)
              INTO t_managejobid
              FROM query.r_managepriorityappscounty mc
             WHERE mc.cacountyobjectid = t_countyid;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                api.pkg_errors.raiseerror(
                    -20000,
                       'There is no Manage Priority Application Job related to this County.'
                    || t_countyid);
        END;

        t_endpointid   :=
            api.pkg_configquery.endpointidforname(
                'j_ManagePriorityApplications',
                'PriorityApplication');

        t_relid   :=
            api.pkg_relationshipupdate.new(t_endpointid,
                                           t_managejobid,
                                           t_applicationjobid);
    END relatepdapplication;

    PROCEDURE updatepltstatus(a_objectid      udt_id,
                              a_asofdate      DATE,
                              a_jobid         udt_id,
                              a_newstatus     VARCHAR2)
    IS
        t_currentstatus   VARCHAR2(30);
    BEGIN
        t_currentstatus   :=
            api.pkg_columnquery.VALUE(a_objectid, 'JobStatus');

        IF t_currentstatus = 'Withdrawn' THEN
            FOR c
                IN (SELECT plt.objectid pltobjectid
                      FROM query.r_appprimarylicensetype  r
                           JOIN query.o_primarylicensetype plt
                               ON plt.objectid = r.licensetypeobjectid
                     WHERE r.applicationobjectid = a_jobid
                       AND plt.status = 'WITHDRAWN')
            LOOP
                api.pkg_columnupdate.setvalue(c.pltobjectid,
                                              'Status',
                                              a_newstatus);

                FOR slt
                    IN (SELECT slt.relationshipid,
                               slt.sstatus,
                               slt.statusdate
                          FROM query.r_priltltcatsecondary slt
                         WHERE slt.primarylicensetypeobjectid = c.pltobjectid
                           AND slt.status = 'WITHDRAWN')
                LOOP
                    api.pkg_columnupdate.setvalue(slt.relationshipid,
                                                  'SStatus',
                                                  UPPER(a_newstatus));
                END LOOP;
            END LOOP;
        END IF;
    END updatepltstatus;

    /********************************************************************************************************
    - ManageDeleteRel is called on the Manage priority application job to delete the base relationship for the
    - filtered relationships in the grid
    ********************************************************************************************************/

    PROCEDURE managedeleterel(a_jobid         udt_id,
                              a_asofdate      DATE,
                              a_managejobid   udt_id)
    IS
        t_relationshipid   udt_id;
    BEGIN
        SELECT r.relationshipid
          INTO t_relationshipid
          FROM query.r_managepriorityappsapp r
         WHERE r.applicationjobid = a_jobid
           AND r.managepriorityappsjobid = a_managejobid;

        api.pkg_relationshipupdate.remove(t_relationshipid, SYSDATE);
    END managedeleterel;

    /*********************************************************************************************************
    - CreateReviewAppOnManageJob, Runs on the completion of the Relate PD applications process to
    - kick off the seprate workflows for the priority draw catagories
    **********************************************************************************************************/

    PROCEDURE createreviewapponmanagejob(a_processid udt_id, a_asofdate DATE)
    IS
        t_jobid             udt_id;
        t_newprocessdef     VARCHAR2(30);
        t_newprocessdefid   udt_id;
        t_newprocessid      udt_id;
        t_processdef        VARCHAR2(30);
    BEGIN
        t_jobid           := api.pkg_columnquery.VALUE(a_processid, 'JobId');

        t_newprocessdef   := 'p_ReviewApplications';

        SELECT pt.processtypeid
          INTO t_newprocessdefid
          FROM api.processtypes pt
         WHERE pt.name = t_newprocessdef;

        -- Loop through the priority draw catagories, creating a unique process for each one, and setting the Description of that process to
        -- the priority draw catagory

        FOR c
            IN (SELECT dl.attributevalue
                  FROM api.domains  d
                       JOIN api.domainlistofvalues dl
                           ON dl.domainid = d.domainid
                 WHERE d.name = 'Priority Draw Catagory')
        LOOP
            t_newprocessid   :=
                api.pkg_processupdate.new(t_jobid,
                                          t_newprocessdefid,
                                          c.attributevalue,
                                          NULL,
                                          NULL,
                                          NULL);

            api.pkg_columnupdate.setvalue(t_newprocessid,
                                          'PriorityDrawCatagory',
                                          c.attributevalue);
        END LOOP;
    END createreviewapponmanagejob;

    /*********************************************************************************************************
    - CreateProcessesOnManageJob, Runs on the completion of the Review Appliaction process to
    - kick off the next process as part of the catagories workflow
    **********************************************************************************************************/

    PROCEDURE createprocessesonmanagejob(a_processid udt_id, a_asofdate DATE)
    IS
        t_attributevalue    VARCHAR2(100);
        t_jobid             udt_id;
        t_newprocessdef     VARCHAR2(30);
        t_newprocessdefid   udt_id;
        t_newprocessid      udt_id;
        t_outcome           VARCHAR2(40);
        t_processdef        VARCHAR2(30);
    BEGIN
        t_jobid     := api.pkg_columnquery.VALUE(a_processid, 'JobId');
        t_outcome   := api.pkg_columnquery.VALUE(a_processid, 'Outcome');

        SELECT pt.name
          INTO t_processdef
          FROM api.processes  p
               JOIN api.processtypes pt ON pt.processtypeid = p.processtypeid
         WHERE p.processid = a_processid;

        -- Select the new process to kick off in the unigue workflow for the priority draw catagory, as well set the description to be in
        -- line with the catagory.

        IF t_processdef = 'p_ReviewApplications'
       AND t_outcome = 'Draw' THEN
            t_newprocessdef   := 'p_DrawAndEnterResults';
        ELSE
            t_newprocessdef   := 'p_NotifyApplicantsOfResults';
        END IF;

        SELECT pt.processtypeid
          INTO t_newprocessdefid
          FROM api.processtypes pt
         WHERE pt.name = t_newprocessdef;

        t_attributevalue   :=
            api.pkg_columnquery.VALUE(a_processid, 'PriorityDrawCatagory');

        t_newprocessid   :=
            api.pkg_processupdate.new(t_jobid,
                                      t_newprocessdefid,
                                      t_attributevalue,
                                      NULL,
                                      NULL,
                                      NULL);

        api.pkg_columnupdate.setvalue(t_newprocessid,
                                      'PriorityDrawCatagory',
                                      t_attributevalue);
    END createprocessesonmanagejob;

    /*********************************************************************************************************
    - RaiseErrRankAndStatus is run on the No-Draw outcome of Review Appplications and the Complete outcome
    - of Draw and Enter Results processes, detarmining the the error based on catagory
    **********************************************************************************************************/

    PROCEDURE raiseerrrankandstatus(a_processid udt_id, a_asofdate DATE)
    IS
        t_prioritydrawcatagory   VARCHAR2(100);
        t_filterboolean          VARCHAR2(30);
        t_countname              VARCHAR2(30);
        t_count                  NUMBER(5);
        t_raiseerror             VARCHAR2(1);
        t_jobid                  udt_id;
        t_relationshipcount      NUMBER(5);
    BEGIN
        t_prioritydrawcatagory   :=
            api.pkg_columnquery.VALUE(a_processid, 'PriorityDrawCatagory');

        t_jobid   := api.pkg_columnquery.VALUE(a_processid, 'JobId');

        IF t_prioritydrawcatagory = 'On Sale Original' THEN
            t_filterboolean   := 'OriginalOnSaleGeneral';
            t_countname       := 'OriginalOnSaleGeneralCount';
        ELSIF t_prioritydrawcatagory = 'Off Sale Original' THEN
            t_filterboolean   := 'OriginalOffSaleGeneral';
            t_countname       := 'OriginalOffSaleGeneralCount';
        ELSIF t_prioritydrawcatagory = 'On Sale Intercounty' THEN
            t_filterboolean   := 'IntercountyOnSaleGeneral';
            t_countname       := 'IntercountyOnSaleGeneralCount';
        ELSE
            t_filterboolean   := 'IntercountyOffSaleGeneral';
            t_countname       := 'IntercountyOffSaleGeneralCount';
        END IF;

        t_relationshipcount   :=
            api.pkg_columnquery.numericvalue(t_jobid, t_countname);

        SELECT COUNT(*)
          INTO t_count
          FROM query.r_managepriorityappsapp  ma
               JOIN query.j_application a ON a.jobid = ma.applicationjobid
         WHERE api.pkg_columnquery.VALUE(a.jobid, t_filterboolean) = 'Y'
           AND ma.managepriorityappsjobid = t_jobid
           AND a.priorityrank IS NOT NULL;

        IF t_count <> t_relationshipcount THEN
            api.pkg_errors.raiseerror(
                -20000,
                   'You must enter a value for all Rank and Priority Status columns on related '
                || t_prioritydrawcatagory
                || ' Applications.');
        END IF;

        SELECT COUNT(*)
          INTO t_count
          FROM query.r_managepriorityappsapp  ma
               JOIN query.j_application a ON a.jobid = ma.applicationjobid
         WHERE api.pkg_columnquery.VALUE(a.jobid, t_filterboolean) = 'Y'
           AND ma.managepriorityappsjobid = t_jobid
           AND a.prioritystatus IS NOT NULL;

        IF t_count <> t_relationshipcount THEN
            api.pkg_errors.raiseerror(
                -20000,
                   'You must enter a value for all Rank and Priority Status columns on related '
                || t_prioritydrawcatagory
                || ' Applications.');
        END IF;
    END raiseerrrankandstatus;
END pkg_prioritydraw;
/
