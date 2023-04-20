CREATE OR REPLACE PACKAGE BODY SITESPECIFIC."PKG_ENFORCEMENT"
IS
    -- **************************************************************************
    -- File:        PKG_ENFORCEMENT.pkb
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

    ----------------------------------------------------------------------------------------------------
    --  CreateAccusation() -- PUBLIC
    --  Used by Raise Accusation outcome of the Close Investigation process on the Investigation job.
    -- 01/31/2023 PK          Changed assignconductinv to resolve problem after Objectid have been moved to new gap
    -- 03/29/2023 PK          WO 31538 'HoldType', 'H '||chr(38)||' L PROTEST'); --'||chr(38)||' An ampersand 
    ----------------------------------------------------------------------------------------------------
    PROCEDURE createaccusation(a_objectid udt_id, a_asofdate DATE)
    IS
        t_accobjid   udt_id;
        t_relid      udt_id;
        t_invobjid   udt_id;
        t_ofcobjid   udt_id;
    BEGIN
        t_accobjid   :=
            api.pkg_objectupdate.new(
                api.pkg_configquery.objectdefidforname('j_Accusation'));

        -- Relate Investigation to Accusation
        BEGIN
            SELECT jobid
              INTO t_invobjid
              FROM api.processes
             WHERE processid = a_objectid;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                api.pkg_errors.raiseerror(
                    -20000,
                    ' Investigation Job not found. ' || SQLERRM);
        END;

        t_relid   :=
            api.pkg_relationshipupdate.new(
                api.pkg_configquery.endpointidforname(
                    'j_Accusation',
                    'CreatedByInvestigation'),
                t_accobjid,
                t_invobjid);
        -- Set IsCreatedProcedurally on the rel to Y
        api.pkg_columnupdate.setvalue(t_relid, 'IsCreatedProcedurally', 'Y');

        -- Relate Office to Accusation
        BEGIN
            SELECT r.officeobjectid
              INTO t_ofcobjid
              FROM query.r_investigationoffice r
             WHERE r.investigationjobid = t_invobjid;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                api.pkg_errors.raiseerror(-20000,
                                          ' Office not found. ' || SQLERRM);
        END;

        t_relid   :=
            api.pkg_relationshipupdate.new(
                api.pkg_configquery.endpointidforname('j_Accusation',
                                                      'DefaultOffice'),
                t_accobjid,
                t_ofcobjid);
    END createaccusation;

    /*---------------------------------------------------
    Create Accusation File Number
    ---------------------------------------------------*/
    PROCEDURE createaccusationfilenumber(a_objectid      udt_id,
                                         a_asofdate      DATE,
                                         a_jobid         udt_id)
    IS
        t_externalfilenum   VARCHAR2(40);
        t_sequenceid        udt_id;
    BEGIN
        BEGIN
            SELECT sequenceid
              INTO t_sequenceid
              FROM api.sequences
             WHERE description = 'Reg Number';
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                api.pkg_errors.raiseerror(-20000,
                                          'Reg Number sequence not found.');
        END;

        t_externalfilenum   :=
            api.pkg_utils.generateexternalfilenum('{YY}[000000]',
                                                  t_sequenceid);

        api.pkg_jobupdate.setexternalfilenum(a_jobid, t_externalfilenum);
    END createaccusationfilenumber;


    /*---------------------------------------------------
    Create Application Reg. Number
    ---------------------------------------------------*/
    PROCEDURE createapplicationregnumber(a_objectid      udt_id,
                                         a_asofdate      DATE,
                                         a_jobid         udt_id)
    IS
        t_externalfilenum   VARCHAR2(40);
        t_sequenceid        udt_id;
        t_regnumber         VARCHAR2(60);
        t_jobname           VARCHAR2(100);
        t_jobdefid          udt_id;
    BEGIN
        SELECT o.objectdefid
          INTO t_jobdefid
          FROM api.objects o
         WHERE o.objectid = a_jobid;

        SELECT od.name
          INTO t_jobname
          FROM api.objectdefs od
         WHERE od.objectdefid = t_jobdefid;

        IF t_jobname = 'j_Application' THEN
            BEGIN
                SELECT sequenceid
                  INTO t_sequenceid
                  FROM api.sequences
                 WHERE description = 'Reg Number';
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    api.pkg_errors.raiseerror(
                        -20000,
                        'Reg Number sequence not found.');
            END;

            BEGIN
                SELECT a.regnumber
                  INTO t_regnumber
                  FROM query.j_application a
                 WHERE a.objectid = a_jobid;
            END;

            IF t_regnumber IS NULL THEN
                t_externalfilenum   :=
                    api.pkg_utils.generateexternalfilenum('{YY}[000000]',
                                                          t_sequenceid);
                api.pkg_columnupdate.setvalue(a_jobid,
                                              'RegNumber',
                                              t_externalfilenum);
            END IF;
        END IF;
    END createapplicationregnumber;

    /*---------------------------------------------------
    Create Reg Protest Reg. Number
    ---------------------------------------------------*/
    PROCEDURE createregprotestregnumber(a_objectid      udt_id,
                                        a_asofdate      DATE,
                                        a_jobid         udt_id)
    IS
        t_externalfilenum   VARCHAR2(40);
        t_sequenceid        udt_id;
        t_regnumber         VARCHAR2(60);
        t_jobname           VARCHAR2(100);
        t_jobdefid          udt_id;
        t_jobid             udt_id;
    BEGIN
        SELECT jobid
          INTO t_jobid
          FROM api.processes p
         WHERE p.processid = a_objectid;

        SELECT jobtypeid
          INTO t_jobdefid
          FROM api.jobs j
         WHERE j.jobid = t_jobid;

        SELECT od.name
          INTO t_jobname
          FROM api.objectdefs od
         WHERE od.objectdefid = t_jobdefid;

        IF t_jobname = 'j_License' THEN
            BEGIN
                SELECT sequenceid
                  INTO t_sequenceid
                  FROM api.sequences
                 WHERE description = 'Reg Number';
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    api.pkg_errors.raiseerror(
                        -20000,
                        'Reg Number sequence not found.');
            END;

            t_externalfilenum   :=
                api.pkg_utils.generateexternalfilenum('{YY}[000000]',
                                                      t_sequenceid);

            t_regnumber   :=
                api.pkg_columnquery.VALUE(a_objectid, 'RegNumber');

            IF t_regnumber IS NULL THEN
                api.pkg_columnupdate.setvalue(a_objectid,
                                              'RegNumber',
                                              t_externalfilenum);
            END IF;
        END IF;
    END createregprotestregnumber;

    /*---------------------------------------------------
    Create Reg Denial Hearing Reg. Number
    ---------------------------------------------------*/
    PROCEDURE createdenialhearingregnumber(a_objectid      udt_id,
                                           a_asofdate      DATE)
    IS
        t_externalfilenum   VARCHAR2(40);
        t_sequenceid        udt_id;
        t_regnumber         VARCHAR2(60);
        t_jobid             udt_id;
    BEGIN
        BEGIN
            SELECT sequenceid
              INTO t_sequenceid
              FROM api.sequences
             WHERE description = 'Reg Number';
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                api.pkg_errors.raiseerror(-20000,
                                          'Reg Number sequence not found.');
        END;

        t_regnumber   := api.pkg_columnquery.VALUE(a_objectid, 'RegNumber');

        t_jobid       := api.pkg_columnquery.VALUE(a_objectid, 'JobId');

        IF t_regnumber IS NULL
       AND api.pkg_columnquery.VALUE(t_jobid, 'ObjectDefName') =
           'j_Application'
       AND api.pkg_columnquery.VALUE(t_jobid, 'RegNumer') IS NULL THEN
            t_externalfilenum   :=
                api.pkg_utils.generateexternalfilenum('{YY}[000000]',
                                                      t_sequenceid);
            api.pkg_columnupdate.setvalue(t_jobid,
                                          'RegNumber',
                                          t_externalfilenum);
            api.pkg_columnupdate.setvalue(a_objectid,
                                          'RegNumber',
                                          t_externalfilenum);
        -- If the job is not an App, only set the process RegNumber:
        ELSIF t_regnumber IS NULL
          AND api.pkg_columnquery.VALUE(t_jobid, 'ObjectDefName') <>
              'j_Application' THEN
            t_externalfilenum   :=
                api.pkg_utils.generateexternalfilenum('{YY}[000000]',
                                                      t_sequenceid);
            api.pkg_columnupdate.setvalue(a_objectid,
                                          'RegNumber',
                                          t_externalfilenum);
        END IF;
    END createdenialhearingregnumber;

    ---------------------------------------------------------------------------
    -- ChooseInvestigator() -- PUBLIC
    ---------------------------------------------------------------------------
    PROCEDURE chooseinvestigator(a_object           udt_id,
                                 a_relationshipdef  udt_id,
                                 a_endpoint         udt_endpoint,
                                 a_searchstring     VARCHAR2,
                                 a_objects      OUT udt_objectlist)
    IS
        t_accessgroupid   udt_id;
        t_officeobjid     udt_id;
    BEGIN
        a_objects   := api.udt_objectlist();


        IF a_searchstring IS NULL THEN
            /* Being used as a Drop Down */

            t_officeobjid   :=
                api.pkg_columnquery.VALUE(a_object,
                                          'InvestigationOfficeObjectId');

            BEGIN
                SELECT accessgroupid
                  INTO t_accessgroupid
                  FROM api.accessgroups
                 WHERE description =
                       api.pkg_columnquery.VALUE(a_object, 'AccessGroup');
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    api.pkg_errors.raiseerror(
                        '-20000',
                           'Cannot find AccessGroupIds for users in the Access Group specified in detail on '
                        || a_object);
            END;

            FOR c
                IN (SELECT                    -- Investigators for this Office
                           DISTINCT r1.toobjectid
                      FROM api.relationships  r1
                           JOIN api.accessgroupusers ag
                               ON ag.userid = r1.toobjectid
                     WHERE r1.fromobjectid = t_officeobjid
                       AND ag.accessgroupid = t_accessgroupid)
            LOOP
                a_objects.EXTEND(1);
                a_objects(a_objects.COUNT)   := api.udt_object(c.toobjectid);
            END LOOP;                         -- Investigators for this Office
        END IF;                                    --if a_SearchString is null
    END chooseinvestigator;

    ----------------------------------------------------------------
    PROCEDURE assignconductinv(a_object        udt_id,
                               a_asofdate      DATE,
                               a_jobid         udt_id)
    IS
        t_accessgroupid         udt_id;
        t_conductinvprocessid   udt_id;
        t_crew                  VARCHAR2(1);
        t_officeobjid           udt_id;
        t_prioraclelogonid      VARCHAR2(25);
    BEGIN
        t_officeobjid   :=
            api.pkg_columnquery.VALUE(a_object,
                                      'InvestigationOfficeObjectId');

        -- find the ProcessId for the Conduct Investigation process
        BEGIN
       ---- 01/31/2023 PK          Changed assignconductinv to resolve problem after Objectid have been moved to new gap
        SELECT p2.PROCESSID
            INTO t_conductinvprocessid
            FROM (SELECT MAX (p.createddate) Maxcreateddate
                    FROM api.processes p
                    WHERE jobid = a_jobid
                    AND processtypeid IN
                       (api.pkg_objectdefquery.idforname (
                            'p_ConductEnforcementInv'),
                        api.pkg_objectdefquery.idforname (
                            'p_ConductAppInvestigation'),
                        api.pkg_objectdefquery.idforname (
                            'p_ConductAdminInvestigation'),
                        api.pkg_objectdefquery.idforname (
                            'p_ConductLicenseInvestigation'))) x
                    JOIN api.processes p2 ON p2.CREATEDDATE = x.Maxcreateddate
                        WHERE p2.jobid = a_jobid;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                api.pkg_errors.raiseerror(
                    -20000,
                    'Problem finding Conduct Investigation Process ID. ');
        END;

        -- Only Enforcement process has Crew detail
        t_crew   := NVL(api.pkg_columnquery.VALUE(a_object, 'Crew'), 'N');

        IF t_crew = 'N' THEN
            -- Find the Primary Investigator selected for the Investigation
            BEGIN
                SELECT u.oraclelogonid
                  INTO t_prioraclelogonid
                  FROM api.relationships  r
                       JOIN api.users u ON u.userid = r.toobjectid
                 WHERE r.fromobjectid = a_object
                   AND r.endpointid IN
                           (api.pkg_configquery.endpointidforname(
                                'p_AssignInvestigation',
                                'Investigator'),
                            api.pkg_configquery.endpointidforname(
                                'p_AssignAppInvestigation',
                                'LicensingRep'),
                            api.pkg_configquery.endpointidforname(
                                'p_AssignLicenseInvestigation',
                                'LicensingRep'),
                            api.pkg_configquery.endpointidforname(
                                'p_PrepHearingMemoServeSubpoena',
                                'LicensingRep'),
                            api.pkg_configquery.endpointidforname(
                                'p_AssignAdminInvestigation',
                                'LicensingRep'));

                api.pkg_processupdate.assign(t_conductinvprocessid,
                                             t_prioraclelogonid);
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    api.pkg_errors.raiseerror(
                        -20000,
                        'Problem Assigning Investigator or Licensing Representative.');
            END;
        -- Assign to all Investigators in office to Investigation
        ELSIF t_crew = 'Y' THEN
            SELECT accessgroupid
              INTO t_accessgroupid
              FROM api.accessgroups
             WHERE description =
                   api.pkg_columnquery.VALUE(a_object, 'AccessGroup');

            FOR c
                IN (SELECT u.oraclelogonid
                      FROM api.relationships  r1
                           JOIN api.users u ON u.userid = r1.toobjectid
                           JOIN api.accessgroupusers ag
                               ON ag.userid = r1.toobjectid
                     WHERE r1.endpointid =
                           api.pkg_configquery.endpointidforname('o_Office',
                                                                 'User')
                       AND r1.fromobjectid = t_officeobjid
                       AND ag.accessgroupid = t_accessgroupid)
            LOOP
                api.pkg_processupdate.assign(t_conductinvprocessid,
                                             c.oraclelogonid);
            END LOOP;            -- Users (Investigators) assigned the process
        END IF;                                                        -- Crew
    END assignconductinv;

    -------------------------------------------------------------
    PROCEDURE assignclose(a_object udt_id, a_asofdate DATE)
    IS
        t_prioraclelogonid   VARCHAR2(25);
        t_active             VARCHAR2(1);
    BEGIN
        BEGIN
            SELECT u.oraclelogonid, u.active
              INTO t_prioraclelogonid, t_active
              FROM api.users u
             WHERE u.oraclelogonid =
                   api.pkg_columnquery.VALUE(a_object,
                                             'AssignmentCompletedBy');
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                --api.pkg_errors.RaiseError(-20000, 'There is no Assignment Completed By');
                t_prioraclelogonid   := NULL;
        END;

        BEGIN
            IF t_prioraclelogonid IS NOT NULL
           AND t_active = 'Y' THEN
                -- Can only assign active users
                api.pkg_processupdate.assign(a_object, t_prioraclelogonid);
            ELSIF t_prioraclelogonid IS NOT NULL
              AND t_active = 'N' THEN
                -- If user is inactive then assign to Supervisor of the same default office
                FOR c
                    IN (SELECT u.oraclelogonid
                          FROM query.users  u
                               JOIN api.accessgroupusers agu
                                   ON agu.userid = u.userid
                               JOIN api.accessgroups ag
                                   ON ag.accessgroupid = agu.accessgroupid
                         WHERE ag.description = 'Supervisor'
                           AND u.active = 'Y'
                           AND u.office =
                               (SELECT u2.office
                                  FROM query.users u2
                                 WHERE u2.oraclelogonid = t_prioraclelogonid))
                LOOP
                    api.pkg_processupdate.assign(a_object, c.oraclelogonid);
                END LOOP;
            END IF;
        EXCEPTION
            WHEN OTHERS THEN
                FOR c
                    IN (SELECT u.oraclelogonid
                          FROM query.users  u
                               JOIN api.accessgroupusers agu
                                   ON agu.userid = u.userid
                               JOIN api.accessgroups ag
                                   ON ag.accessgroupid = agu.accessgroupid
                         WHERE ag.description = 'Supervisor'
                           AND u.active = 'Y'
                           AND u.office =
                               (SELECT u2.office
                                  FROM query.users u2
                                 WHERE u2.oraclelogonid = t_prioraclelogonid))
                LOOP
                    api.pkg_processupdate.assign(a_object, c.oraclelogonid);
                END LOOP;
        END;
    END assignclose;

    /*--------------------------------------
      This relationship gets the Prior Accusations from a License
    */
    --------------------------------------

    PROCEDURE prioraccusations(a_objectid         udt_id,
                               a_endpointid       udt_id,
                               a_relatedobjectids OUT api.udt_objectlist)
    IS
        t_accusationids   udt_id;
    BEGIN
        a_relatedobjectids   := api.udt_objectlist();

        FOR c
            IN (SELECT il.licensejobid
                  FROM query.r_createdbyinvestaccusation  ci
                       JOIN query.r_licenseinvestigation il
                           ON il.investigationjobid = ci.investigationjobid
                 WHERE ci.accusationjobid = a_objectid)
        LOOP
            FOR d
                IN (SELECT oa.accusationjobid
                      FROM query.r_licenseinvestigation  oi
                           JOIN query.r_createdbyinvestaccusation oa
                               ON oa.investigationjobid =
                                  oi.investigationjobid
                     WHERE oi.licensejobid = c.licensejobid
                       AND oa.accusationjobid < a_objectid)
            LOOP
                a_relatedobjectids.EXTEND(1);
                a_relatedobjectids(a_relatedobjectids.COUNT)   :=
                    api.udt_object(d.accusationjobid);
            END LOOP;
        END LOOP;
    END;

    /*--------------------------------------
     This is supposed to Create a Hold with Hold object of type "H and L Protest" placed by the signed
     on user and relate that Hold object to the Register Protest process and the Application Job.
    */
    --------------------------------------

    PROCEDURE newhlhold(a_objectid      udt_id,
                        a_asofdate      DATE,
                        a_jobid         udt_id,
                        a_lastupdatebyusername VARCHAR2)
    IS
        t_holddefid       udt_id;
        t_holdid          udt_id;
        t_rpendpointid    udt_id;
        t_jobendpointid   udt_id;
        t_relid           udt_id;
        t_jobtypeid       udt_id;
    BEGIN
        --Create Hold Object and assign values to Hold Type and Created By
        t_holddefid   := api.pkg_configquery.objectdefidforname('o_Hold');
        t_holdid      := api.pkg_objectupdate.new(t_holddefid);
        api.pkg_columnupdate.setvalue(t_holdid, 'HoldType', 'H '||chr(38)||' L PROTEST'); --'||chr(38)||' An ampersand  -- By Pawan 03/29/2023
        api.pkg_columnupdate.setvalue(t_holdid,
                                      'HoldComment',
                                      'Auto-Created H '||chr(38)||' L Hold');
        api.pkg_columnupdate.setvalue(t_holdid,
                                      'CreatedBy',
                                      a_lastupdatebyusername);

        SELECT j.jobtypeid
          INTO t_jobtypeid
          FROM api.jobs j
         WHERE j.jobid = a_jobid;

        IF t_jobtypeid =
           api.pkg_configquery.objectdefidforname('j_Application') THEN
            t_jobendpointid   :=
                api.pkg_configquery.endpointidforname('j_Application',
                                                      'Hold');
        ELSIF t_jobtypeid =
              api.pkg_configquery.objectdefidforname('j_License') THEN
            t_jobendpointid   :=
                api.pkg_configquery.endpointidforname('j_License', 'Hold');
        END IF;

        t_rpendpointid   :=
            api.pkg_configquery.endpointidforname('p_RegisterProtest',
                                                  'Hold');

        --Relate Hold to Application/License and Register Protest
        t_relid       :=
            api.pkg_relationshipupdate.new(t_jobendpointid,
                                           a_jobid,
                                           t_holdid);
        t_relid       :=
            api.pkg_relationshipupdate.new(t_rpendpointid,
                                           a_objectid,
                                           t_holdid);
    END newhlhold;

    /*--------------------------------------
       When the Record Director Decision process is completed this will enters the Current Date
       into any null Hold Released fields on any Hold objects that are attached to any completed Register Protest
       processes on the Application job.
    */
    --------------------------------------

    PROCEDURE releasehlhold(a_objectid      udt_id,
                            a_asofdate      DATE,
                            a_jobid         udt_id,
                            a_currentdate   DATE)
    IS
        t_holdid   DATE;
    BEGIN
        FOR c IN (SELECT rp.objectid
                    FROM query.p_registerprotest rp
                   WHERE rp.outcome = 'Register'
                     AND rp.jobid = a_jobid)
        LOOP
            FOR i IN (SELECT rph.holdobjectid
                        FROM query.r_registerprotesthold rph
                       WHERE rph.registerprotestprocessid = c.objectid)
            LOOP
                SELECT h.holdreleased
                  INTO t_holdid
                  FROM query.o_hold h
                 WHERE h.objectid = i.holdobjectid;

                IF t_holdid IS NULL THEN
                    api.pkg_columnupdate.setvalue(i.holdobjectid,
                                                  'HoldReleased',
                                                  a_currentdate);
                END IF;
            END LOOP;
        END LOOP;
    END releasehlhold;

    ------------------------------------------------------
    --  SuspendOrRevokeLT() -- PUBLIC
    --   Suspend or Revoke LTs and SLTs for an Accusation
    ------------------------------------------------------
    PROCEDURE suspendorrevokelt(a_processid     udt_id,
                                a_asofdate      DATE,
                                a_jobid         udt_id,
                                a_outcome       VARCHAR2)
    IS
        t_ltprocessid                 udt_id;
        t_revokeltprocesstypeid       udt_id;
        t_changestatusprocesstypeid   udt_id;
    BEGIN
        t_revokeltprocesstypeid   :=
            api.pkg_configquery.objectdefidforname('p_RevokeLicenseType');
        t_changestatusprocesstypeid   :=
            api.pkg_configquery.objectdefidforname('p_ChangeStatus');

        -- Loop through the LTs related to the Accusation thtought it's Investigations and Suspend or Revoke them along with the SLTs
        FOR c
            IN (SELECT UNIQUE
                       (lt.jobid) ltjobid,
                       lt.statusname,
                       lt.includeinrevokebatch
                  FROM query.r_createdbyinvestaccusation  r
                       JOIN query.r_investigationlicensetype ilt
                           ON ilt.investigationjobid = r.investigationjobid
                       JOIN query.j_licensetype lt
                           ON lt.jobid = ilt.licensetypejobid
                 WHERE r.accusationjobid = a_jobid
                   AND lt.statusname NOT IN ('CANCEL',
                                             'SLMSRV',
                                             'AUTREV',
                                             'DEPREV',
                                             'NREN',
                                             'WTHDRN',
                                             'DENIED',
                                             'VOIDED'))
        LOOP
            IF a_outcome = 'Revoke' THEN
                t_ltprocessid   :=
                    api.pkg_processupdate.new(
                        c.ltjobid,
                        t_revokeltprocesstypeid,
                        'License Type Revoked as a result of an Accusation job.',
                        NULL,
                        NULL,
                        NULL);
                api.pkg_processupdate.complete(t_ltprocessid, 'Dept Revoke');
            ELSIF a_outcome = 'Suspend' THEN
                t_ltprocessid   :=
                    api.pkg_processupdate.new(
                        c.ltjobid,
                        t_changestatusprocesstypeid,
                        'License Type Suspended as a result of an Accusation job.',
                        NULL,
                        NULL,
                        NULL);
                api.pkg_processupdate.complete(t_ltprocessid, 'Suspended');
            END IF;

            FOR s
                IN (SELECT slt.relationshipid,
                           slt.status,
                           slt.includeinrevokebatch
                      FROM query.r_licensetypeltcatsecondary slt
                     WHERE slt.licensetypejobid = c.ltjobid
                       AND slt.status <> 'CANCELED')
            LOOP
                IF a_outcome = 'Revoke' THEN
                    api.pkg_columnupdate.setvalue(s.relationshipid,
                                                  'Status',
                                                  'DEPARTMENT REVOKED');
                ELSIF a_outcome = 'Suspend' THEN
                    api.pkg_columnupdate.setvalue(s.relationshipid,
                                                  'Status',
                                                  'SUSPENDED');
                END IF;
            END LOOP;
        END LOOP;
    END suspendorrevokelt;

    PROCEDURE activatesuspendedlicense(a_processid     udt_id,
                                       a_asofdate      DATE,
                                       a_jobid         udt_id)
    IS
        t_licensejobid                udt_id;
        t_newprocessid                udt_id;
        t_fromstat                    udt_id;
        t_suspenddate                 DATE;
        t_setstatus                   VARCHAR2(30);
        t_changestatusprocesstypeid   udt_id
            := api.pkg_configquery.objectdefidforname('p_ChangeStatus');
        t_setbackstat                 extension.jobstatuschange.statusname%TYPE;
        t_producelic                  VARCHAR2(1);
        t_firstrenewal                VARCHAR2(1);
        t_secondrenewal               VARCHAR2(1);
        t_finalrevp                   VARCHAR2(1);
        t_autorev                     VARCHAR2(1);
    BEGIN
        --loop through the LT's
        FOR x
            IN (SELECT UNIQUE (j.jobid) jobid
                  FROM query.r_createdbyinvestaccusation  i
                       JOIN query.r_licenseinvestigation l
                           ON l.investigationjobid = i.investigationjobid
                       JOIN query.r_licenselicensetype lt
                           ON lt.licensejobid = l.licensejobid
                       JOIN api.jobs j ON j.jobid = lt.licensetypejobid
                 WHERE i.accusationjobid = a_jobid
                   AND j.statusid IN (SELECT s.statusid
                                        FROM api.statuses s
                                       WHERE s.tag = 'SUSPEN'))
        LOOP
            t_fromstat        := NULL;
            t_setbackstat     := NULL;
            t_setstatus       := NULL;
            t_suspenddate     := NULL;
            t_producelic      := 'N';
            t_firstrenewal    := 'N';
            t_secondrenewal   := 'N';
            t_finalrevp       := 'N';
            t_autorev         := 'N';

            BEGIN
                SELECT MAX(psr.calcsuspensionenddate)
                  INTO t_suspenddate
                  FROM query.j_licensetype  lt
                       JOIN query.r_investigationlicensetype ilt
                           ON ilt.licensetypejobid = lt.jobid
                       JOIN query.r_createdbyinvestaccusation cia
                           ON cia.investigationjobid = ilt.investigationjobid
                       JOIN query.p_postsuspensionrevocation psr
                           ON psr.jobid = cia.accusationjobid
                 WHERE lt.jobid = x.jobid
                   AND psr.outcome IS NOT NULL;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    NULL;
            END;

            IF TRUNC(SYSDATE) >= t_suspenddate THEN
                SELECT MAX(jsc.jobstatuschangeid)
                  INTO t_fromstat
                  FROM extension.jobstatuschange jsc
                 WHERE jsc.jobid = x.jobid
                   AND jsc.statusname IN ('SUSPEN');

                BEGIN
                    -- find the rel status that was just before ('SUSPEN')
                    -- if no previous record exists, ACTIVE will be used
                    SELECT jsc.statusname
                      INTO t_setbackstat
                      FROM extension.jobstatuschange jsc
                     WHERE jsc.jobstatuschangeid =
                           (SELECT MAX(jsc.jobstatuschangeid)
                              FROM extension.jobstatuschange jsc
                             WHERE jsc.jobid = x.jobid
                               AND jsc.jobstatuschangeid < t_fromstat
                               AND jsc.statustype = 'O'
                               AND jsc.statusname NOT IN ('SUSPEN'));
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        t_setbackstat   := 'ACTIVE';
                END;

                SELECT s.description
                  INTO t_setstatus
                  FROM api.statuses s
                 WHERE s.tag = t_setbackstat;

                t_newprocessid   :=
                    api.pkg_processupdate.new(
                        x.jobid,
                        t_changestatusprocesstypeid,
                        'System Automated Status Change on Close Out Penalty of Accusation',
                        NULL,
                        NULL,
                        NULL);
                api.pkg_processupdate.complete(t_newprocessid, t_setstatus);
                api.pkg_columnupdate.setvalue(x.jobid,
                                              'StatusDate',
                                              TRUNC(SYSDATE));

                -- Reset the Batch Flags
                BEGIN
                    SELECT CASE
                               WHEN lb.batchtype = 'PRODUCE LICENSES' THEN
                                   'Y'
                               ELSE
                                   'N'
                           END
                               firstrenewal,
                           CASE
                               WHEN lb.batchtype = '1ST RENEWAL NOTICES'
                                 OR lb.batchtype = '50% PENALTY' THEN
                                   'Y'
                               ELSE
                                   'N'
                           END
                               secondrenewal,
                           CASE
                               WHEN lb.batchtype = '2ND RENEWAL NOTICES'
                                 OR lb.batchtype = '100% PENALTY' THEN
                                   'Y'
                               ELSE
                                   'N'
                           END
                               finalrevp,
                           CASE
                               WHEN lb.batchtype =
                                    'FINAL REVOCATION PENDING LETTERS' THEN
                                   'Y'
                               ELSE
                                   'N'
                           END
                               autorev
                      INTO t_firstrenewal,
                           t_secondrenewal,
                           t_finalrevp,
                           t_autorev
                      FROM sitespecific.licbatchlictype_xref_t  r
                           JOIN query.j_licensebatch lb
                               ON lb.jobid = r.licensebatchjobid
                     WHERE r.licensetypejobid = x.jobid
                       AND lb.completeddate IS NOT NULL
                       AND lb.jobid =
                           (SELECT MAX(j.jobid)
                              FROM sitespecific.licbatchlictype_xref_t  r1
                                   JOIN query.j_licensebatch j
                                       ON j.jobid = r1.licensebatchjobid
                             WHERE r1.licensetypejobid = x.jobid
                               AND j.completeddate IS NOT NULL);
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        t_producelic   := 'Y';
                END;

                -- Based on batch type, update batch flags to correct values
                pkg_batchtype.setbatchflags(x.jobid,
                                            t_producelic,
                                            t_producelic,
                                            t_firstrenewal,
                                            t_secondrenewal,
                                            t_finalrevp,
                                            t_autorev);

                --loop through suspended secondary lt's
                FOR z IN (SELECT r.relationshipid
                            FROM query.r_licensetypeltcatsecondary r
                           WHERE r.licensetypejobid = x.jobid
                             AND r.status IN (SELECT UPPER(s.description)
                                                FROM api.statuses s
                                               WHERE s.tag = 'SUSPEN'))
                LOOP
                    t_fromstat      := NULL;
                    t_setbackstat   := NULL;
                    t_setstatus     := NULL;

                    SELECT MAX(slts.sltstatuschangeid)
                      INTO t_fromstat
                      FROM sitespecific.sltstatuschange_t slts
                     WHERE slts.relationshipid = z.relationshipid
                       AND slts.statusname IN ('SUSPEN');

                    BEGIN
                        SELECT slts.statusname
                          INTO t_setbackstat
                          FROM sitespecific.sltstatuschange_t slts
                         WHERE slts.sltstatuschangeid =
                               (SELECT MAX(slts.sltstatuschangeid)
                                  FROM sitespecific.sltstatuschange_t slts
                                 WHERE slts.relationshipid = z.relationshipid
                                   AND slts.sltstatuschangeid < t_fromstat
                                   AND slts.statustype = 'O'
                                   AND slts.statusname NOT IN ('SUSPEN'));
                    EXCEPTION
                        WHEN NO_DATA_FOUND THEN
                            t_setbackstat   := 'ACTIVE';
                    END;

                    SELECT UPPER(s.description)
                      INTO t_setstatus
                      FROM api.statuses s
                     WHERE s.tag = t_setbackstat;

                    api.pkg_columnupdate.setvalue(z.relationshipid,
                                                  'Status',
                                                  t_setstatus);
                    api.pkg_columnupdate.setvalue(z.relationshipid,
                                                  'StatusDate',
                                                  TRUNC(SYSDATE));
                    -- Based on batch type, update batch flags to correct values
                    pkg_batchtype.setbatchflags(z.relationshipid,
                                                t_producelic,
                                                t_producelic,
                                                t_firstrenewal,
                                                t_secondrenewal,
                                                t_finalrevp,
                                                t_autorev);
                END LOOP;
            END IF;
        END LOOP;
    END activatesuspendedlicense;

    PROCEDURE searchforexpiredsuspensions
    IS
        t_copprocessid   udt_id;
        t_newprocessid   udt_id;
        t_fromdate       DATE;
        t_transid        udt_id;
    BEGIN
        BEGIN
            SELECT MAX(logdate)
              INTO t_fromdate
              FROM sitespecific.suspensionendlog_t;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                t_fromdate   := TRUNC(SYSDATE - 1);
        END;

        api.pkg_logicaltransactionupdate.resettransaction;
        api.pkg_logicaltransactionupdate.starttransaction;

        FOR c
            IN (SELECT j.jobid
                  FROM TABLE(
                           CAST(
                               api.pkg_simplesearch.castableobjectsbyindexrange(
                                   'p_PostSuspensionRevocation',
                                   'dup_CalcSuspensionEndDate',
                                   TO_CHAR(t_fromdate, 'YYYY-MM-DD'),
                                   TO_CHAR(TRUNC(SYSDATE), 'YYYY-MM-DD')) AS api.udt_objectlist))
                       t
                       JOIN api.processes p ON p.processid = t.objectid
                       JOIN api.jobs j ON j.jobid = p.jobid
                 WHERE p.datecompleted IS NOT NULL)
        LOOP
            BEGIN
                SELECT MAX(p2.processid)
                  INTO t_copprocessid
                  FROM api.processes  p2
                       JOIN api.processtypes pt
                           ON pt.processtypeid = p2.processtypeid
                 WHERE p2.jobid = c.jobid
                   AND pt.name = 'p_CloseOutPenalty';
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    t_copprocessid   := NULL;
            END;

            IF t_copprocessid IS NULL THEN
                t_newprocessid   :=
                    api.pkg_processupdate.new(
                        c.jobid,
                        api.pkg_configquery.objectdefidforname(
                            'p_CloseOutPenalty'),
                        'System Generated on Suspension End',
                        NULL,
                        NULL,
                        NULL);
            END IF;
        END LOOP;

        INSERT INTO sitespecific.suspensionendlog_t(logdate)
             VALUES (TRUNC(SYSDATE));

        api.pkg_logicaltransactionupdate.endtransaction;
        COMMIT;
    END searchforexpiredsuspensions;

    ---------------------------------------------------------------------------------------------------------------------------
    -- CreateInvFromPrepHearing() - PUBLIC
    -- This creates the Investigation job, Conduct Enforcement Investigation process from the Prep Hearing Memo/Serve Supoenas
    -- process on the Accusation job.
    ---------------------------------------------------------------------------------------------------------------------------
    PROCEDURE createinvfromprephearing(a_objectid      udt_id,
                                       a_asofdate      DATE,
                                       a_jobid         udt_id)
    IS
        t_investigationid          udt_id;
        t_invjobtypeid             udt_id;
        t_conductinvid             udt_id;
        t_conductprocesstypeid     udt_id;
        t_relid                    udt_id;
        t_invtoaccendpointid       udt_id;
        t_invduedate               DATE;
        t_assignmentinstructions   VARCHAR2(4000);
        t_licensejobid             udt_id;
        t_licinvendpointid         udt_id;
        t_sysdecisiontypeid        udt_id;
        t_sysdecisionid            udt_id;
        t_applicableltid           udt_id;
        t_applicableltendpointid   udt_id;
        t_investigatorid           udt_id;
        t_userendpointid           udt_id;
        t_assignmentcompletedby    VARCHAR2(4000);
        t_assignprocessid          udt_id;
        t_defid                    udt_id;
        t_appinvendpointid         udt_id;
    BEGIN
        --Create Investigation Job
        BEGIN
            SELECT j.jobtypeid
              INTO t_invjobtypeid
              FROM api.jobtypes j
             WHERE j.name = 'j_Investigation';
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                api.pkg_errors.raiseerror(
                    '-20000',
                    'JobTypeId cannot be found for j_Investigation');
        END;

        t_investigationid   :=
            api.pkg_jobupdate.new(t_invjobtypeid, NULL, NULL);

        --Create and complete System Decision process to change Investigation status to Assigned
        BEGIN
            SELECT p.processtypeid
              INTO t_sysdecisiontypeid
              FROM api.processtypes p
             WHERE p.name = 'p_SystemDecision';
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                api.pkg_errors.raiseerror(
                    '-20000',
                    'ProcessTypeId cannot be found for p_SystemDecision');
        END;

        t_sysdecisionid   :=
            api.pkg_processupdate.new(t_investigationid,
                                      t_sysdecisiontypeid,
                                      NULL,
                                      NULL,
                                      NULL,
                                      NULL);
        api.pkg_processupdate.complete(t_sysdecisionid, 'Assigned');

        --Create Conduct Enforcement Investigation process
        BEGIN
            SELECT p.processtypeid
              INTO t_conductprocesstypeid
              FROM api.processtypes p
             WHERE p.name = 'p_ConductEnforcementInv';
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                api.pkg_errors.raiseerror(
                    '-20000',
                    'ProcessTypeId cannot be found for p_ConductEnforcementInv');
        END;

        t_conductinvid   :=
            api.pkg_processupdate.new(t_investigationid,
                                      t_conductprocesstypeid,
                                      NULL,
                                      NULL,
                                      NULL,
                                      NULL);


        --Create Created By Accusation relationship
        BEGIN
            SELECT rd.toendpointid
              INTO t_invtoaccendpointid
              FROM api.relationshipdefs rd
             WHERE rd.name = 'r_InvestigationCreatedByAcc'
               AND rd.fromendpointname = 'CreatedByAccusation';
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                api.pkg_errors.raiseerror(
                    '-20000',
                    'FromEndpointId cannot be found for r_InvestigationCreatedByAcc where From Endpoint Name is CreatedByAccusation');
        END;

        t_relid   :=
            api.pkg_relationshipupdate.new(t_invtoaccendpointid,
                                           a_jobid,
                                           t_investigationid);

        --Copy License rel from Accusation to new Investigation
        t_licensejobid   :=
            api.pkg_columnquery.VALUE(a_jobid, 'LicenseJobId');

        --get the defid of the related object  license or application
        SELECT o.objectdefid
          INTO t_defid
          FROM api.objects o
         WHERE o.objectid = t_licensejobid;

        --if it is a license set the endpointid as the license
        IF t_defid = api.pkg_configquery.objectdefidforname('j_License') THEN --it is a License
            t_licinvendpointid   :=
                api.pkg_configquery.endpointidforname('j_Investigation',
                                                      'License');
        ELSE                                            --it is an Application
            t_appinvendpointid   :=
                api.pkg_configquery.endpointidforname('j_Investigation',
                                                      'Application');
        END IF;

        IF t_licensejobid IS NOT NULL THEN
            t_relid   :=
                api.pkg_relationshipupdate.new(
                    NVL(t_licinvendpointid, t_appinvendpointid),
                    t_investigationid,
                    t_licensejobid);
        END IF;

        --Copy Applicable License Type rel from original Investigation to the new Investigation
        t_applicableltid   :=
            api.pkg_columnquery.VALUE(a_jobid, 'ApplicableLTId');

        BEGIN
            SELECT rd.toendpointid
              INTO t_applicableltendpointid
              FROM api.relationshipdefs rd
             WHERE rd.name = 'r_InvestigationLicenseType'
               AND rd.fromendpointname = 'Investigation';
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                api.pkg_errors.raiseerror(
                    '-20000',
                    'Cannot find From Endpoint Id from r_InvestigationLicenseType when From Endpoint Name is Investigation');
        END;

        IF t_applicableltid IS NOT NULL THEN
            t_relid   :=
                api.pkg_relationshipupdate.new(t_applicableltendpointid,
                                               t_investigationid,
                                               t_applicableltid);
        END IF;

        --Copy Investigator Relationship to Conduct Enf. Investigation process
        t_investigatorid   :=
            api.pkg_columnquery.VALUE(a_objectid, 'LRObjectId');

        BEGIN
            SELECT rd.toendpointid
              INTO t_userendpointid
              FROM api.relationshipdefs rd
             WHERE rd.name = 'r_ConductEnfInvPriInvestigator'
               AND rd.fromendpointname = 'ConductEnfInvestigation';
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                api.pkg_errors.raiseerror(
                    '-20000',
                    'Cannot find To End Point Id from r_ConductEnfInvPriInvestigator with From Endpoint Name of ConductEnfInvestigation');
        END;

        t_relid   :=
            api.pkg_relationshipupdate.new(t_userendpointid,
                                           t_conductinvid,
                                           t_investigatorid);

        --Assign Investigator to Conduct process
        sitespecific.pkg_enforcement.assignconductinv(a_objectid,
                                                      a_asofdate,
                                                      t_investigationid);

        --Copy Details from Accusation and process to Investigation and Conduct process
        BEGIN
            t_invduedate   :=
                api.pkg_columnquery.datevalue(a_objectid,
                                              'InvestigationDueDate');

            IF t_invduedate IS NOT NULL THEN
                api.pkg_columnupdate.setvalue(t_conductinvid,
                                              'InvestigationDueDate',
                                              t_invduedate);
            END IF;
        END;

        BEGIN
            t_assignmentinstructions   :=
                api.pkg_columnquery.VALUE(a_objectid,
                                          'AssignmentInstructions');

            IF t_assignmentinstructions IS NOT NULL THEN
                api.pkg_columnupdate.setvalue(t_conductinvid,
                                              'AssignmentInstructions',
                                              t_assignmentinstructions);
            END IF;
        END;

        t_assignmentcompletedby   :=
            api.pkg_columnquery.VALUE(a_objectid, 'AssignmentCompletedBy');

        IF t_assignmentcompletedby IS NOT NULL THEN
            api.pkg_columnupdate.setvalue(t_conductinvid,
                                          'AssignmentCompletedBy',
                                          t_assignmentcompletedby);
        END IF;

        -- Set detail used in conjuction with Reminder created for this investigation.
        api.pkg_columnupdate.setvalue(t_conductinvid,
                                      'AssignProcessID',
                                      a_objectid);

        --Set Investigation Type to "Administrative"
        api.pkg_columnupdate.setvalue(t_investigationid,
                                      'InvestigationType',
                                      'ADMINISTRATIVE');
    END createinvfromprephearing;

    ---------------------------------------------------------------------------------------------------------------------------
    -- CreateInvFromPostSuspRev() - PUBLIC
    -- This creates the Investigation job, Assign Enforcement Investigation process from the Post Suspension/Revocation
    -- process on the Accusation job.
    ---------------------------------------------------------------------------------------------------------------------------
    PROCEDURE createinvfrompostsusprev(a_objectid      udt_id,
                                       a_asofdate      DATE,
                                       a_jobid         udt_id)
    IS
        t_indefsusp                VARCHAR2(1);
        t_investigationid          udt_id;
        t_invjobtypeid             udt_id;
        t_assigninvid              udt_id;
        t_assignprocesstypeid      udt_id;
        t_relid                    udt_id;
        t_invtoaccendpointid       udt_id;
        t_licensejobid             udt_id;
        t_createdbyinvid           udt_id;
        t_licinvendpointid         udt_id;
        t_applicableltid           udt_id;
        t_applicableltendpointid   udt_id;
        t_defid                    udt_id;
        t_appinvendpointid         udt_id;
        t_licbasefileofficeid      udt_id;
        t_suspdays                 NUMBER;
    BEGIN
        BEGIN
            SELECT p.suspensiondays, p.indefinitesuspension
              INTO t_suspdays, t_indefsusp
              FROM query.p_executetermsofdecision p
             WHERE p.jobid = a_jobid
               AND p.processid = (SELECT MAX(x.processid)
                                    FROM query.p_executetermsofdecision x
                                   WHERE x.jobid = a_jobid);
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                NULL;
        END;

        IF t_suspdays > 0
        OR t_indefsusp = 'Y' THEN
            --Create Investigation Job and Assign Inv. Process
            BEGIN
                SELECT j.jobtypeid
                  INTO t_invjobtypeid
                  FROM api.jobtypes j
                 WHERE j.name = 'j_Investigation';
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    api.pkg_errors.raiseerror(
                        '-20000',
                        'JobTypeId cannot be found for j_Investigation');
            END;

            t_investigationid   :=
                api.pkg_jobupdate.new(t_invjobtypeid, NULL, NULL);

            BEGIN
                SELECT p.processtypeid
                  INTO t_assignprocesstypeid
                  FROM api.processtypes p
                 WHERE p.name = 'p_AssignInvestigation';
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    api.pkg_errors.raiseerror(
                        '-20000',
                        'ProcessTypeId cannot be found for p_AssignInvestigation');
            END;

            t_assigninvid   :=
                api.pkg_processupdate.new(t_investigationid,
                                          t_assignprocesstypeid,
                                          NULL,
                                          NULL,
                                          NULL,
                                          NULL);

            --Create Created By Accusation relationship
            BEGIN
                SELECT rd.toendpointid
                  INTO t_invtoaccendpointid
                  FROM api.relationshipdefs rd
                 WHERE rd.name = 'r_InvestigationCreatedByAcc'
                   AND rd.fromendpointname = 'CreatedByAccusation';
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    api.pkg_errors.raiseerror(
                        '-20000',
                        'FromEndpointId cannot be found for r_InvestigationCreatedByAcc where From Endpoint Name is CreatedByAccusation');
            END;

            t_relid   :=
                api.pkg_relationshipupdate.new(t_invtoaccendpointid,
                                               a_jobid,
                                               t_investigationid);

            --Copy License rel from Accusation to new Investigation
            t_licensejobid   :=
                api.pkg_columnquery.VALUE(a_jobid, 'LicenseJobId');

            --get the defid of the related object  license or application
            SELECT o.objectdefid
              INTO t_defid
              FROM api.objects o
             WHERE o.objectid = t_licensejobid;

            --if it is a license set the endpointid as the license
            IF t_defid = api.pkg_configquery.objectdefidforname('j_License') THEN --it is a License
                t_licinvendpointid   :=
                    api.pkg_configquery.endpointidforname('j_Investigation',
                                                          'License');
            ELSE                                        --it is an Application
                t_appinvendpointid   :=
                    api.pkg_configquery.endpointidforname('j_Investigation',
                                                          'Application');
            END IF;

            IF t_licensejobid IS NOT NULL THEN
                t_relid   :=
                    api.pkg_relationshipupdate.new(
                        NVL(t_licinvendpointid, t_appinvendpointid),
                        t_investigationid,
                        t_licensejobid);
                t_licbasefileofficeid   :=
                    api.pkg_columnquery.VALUE(t_licensejobid,
                                              'BaseFileOfficeId');

                IF t_licbasefileofficeid IS NOT NULL THEN
                    t_relid   :=
                        api.pkg_relationshipupdate.new(
                            api.pkg_configquery.endpointidforname(
                                'j_Investigation',
                                'Office'),
                            t_investigationid,
                            t_licbasefileofficeid);
                END IF;
            END IF;

            --Copy Applicable License Type rel from original Investigation to the new Investigation
            t_applicableltid   :=
                api.pkg_columnquery.VALUE(a_jobid, 'ApplicableLTId');

            BEGIN
                SELECT rd.toendpointid
                  INTO t_applicableltendpointid
                  FROM api.relationshipdefs rd
                 WHERE rd.name = 'r_InvestigationLicenseType'
                   AND rd.fromendpointname = 'Investigation';
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    api.pkg_errors.raiseerror(
                        '-20000',
                        'Cannot find From Endpoint Id from r_InvestigationLicenseType when From Endpoint Name is Investigation');
            END;

            IF t_applicableltid IS NOT NULL THEN
                t_relid   :=
                    api.pkg_relationshipupdate.new(t_applicableltendpointid,
                                                   t_investigationid,
                                                   t_applicableltid);
            END IF;

            --Set Investigation Type to "Administrative"
            api.pkg_columnupdate.setvalue(t_investigationid,
                                          'InvestigationType',
                                          'ADMINISTRATIVE');
        END IF;
    END createinvfrompostsusprev;

    ---------------------------------------------------------------------------------------------------------------------------
    -- CreateInvFromProcessPOIC() - PUBLIC
    -- This creates the Investigation job, Assign Enforcement Investigation process from the Process POIC
    -- process on the Accusation job.
    ---------------------------------------------------------------------------------------------------------------------------
    PROCEDURE createinvfromprocesspoic(a_objectid      udt_id,
                                       a_asofdate      DATE,
                                       a_jobid         udt_id)
    IS
        t_investigationid          udt_id;
        t_invjobtypeid             udt_id;
        t_assigninvid              udt_id;
        t_assignprocesstypeid      udt_id;
        t_relid                    udt_id;
        t_invtoaccendpointid       udt_id;
        t_licensejobid             udt_id;
        t_createdbyinvid           udt_id;
        t_licinvendpointid         udt_id;
        t_applicableltid           udt_id;
        t_applicableltendpointid   udt_id;
        t_poicauditrequired        VARCHAR2(1);
        t_defid                    udt_id;
        t_appinvendpointid         udt_id;
        t_poicauditinvobjid        udt_id;
    BEGIN
        t_poicauditrequired   :=
            api.pkg_columnquery.VALUE(a_objectid, 'POICAuditRequired');
        t_poicauditinvobjid   :=
            api.pkg_columnquery.VALUE(a_objectid, 'CreatedAuditObjectId');

        IF t_poicauditrequired = 'Y'
       AND t_poicauditinvobjid IS NULL THEN
            --Create Investigation Job and Assign Inv. Process
            BEGIN
                SELECT j.jobtypeid
                  INTO t_invjobtypeid
                  FROM api.jobtypes j
                 WHERE j.name = 'j_Investigation';
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    api.pkg_errors.raiseerror(
                        '-20000',
                        'JobTypeId cannot be found for j_Investigation');
            END;

            t_investigationid   :=
                api.pkg_jobupdate.new(t_invjobtypeid, NULL, NULL);

            --Set the Created Audit Object Id on the process
            api.pkg_columnupdate.setvalue(a_objectid,
                                          'CreatedAuditObjectId',
                                          t_investigationid);

            BEGIN
                SELECT p.processtypeid
                  INTO t_assignprocesstypeid
                  FROM api.processtypes p
                 WHERE p.name = 'p_AssignInvestigation';
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    api.pkg_errors.raiseerror(
                        '-20000',
                        'ProcessTypeId cannot be found for p_AssignInvestigation');
            END;

            t_assigninvid   :=
                api.pkg_processupdate.new(t_investigationid,
                                          t_assignprocesstypeid,
                                          NULL,
                                          NULL,
                                          NULL,
                                          NULL);

            --Create Created By Accusation relationship
            BEGIN
                SELECT rd.toendpointid
                  INTO t_invtoaccendpointid
                  FROM api.relationshipdefs rd
                 WHERE rd.name = 'r_InvestigationCreatedByAcc'
                   AND rd.fromendpointname = 'CreatedByAccusation';
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    api.pkg_errors.raiseerror(
                        '-20000',
                        'FromEndpointId cannot be found for r_InvestigationCreatedByAcc where From Endpoint Name is CreatedByAccusation');
            END;

            t_relid   :=
                api.pkg_relationshipupdate.new(t_invtoaccendpointid,
                                               a_jobid,
                                               t_investigationid);

            --Copy License rel from Accusation to new Investigation
            t_licensejobid   :=
                api.pkg_columnquery.VALUE(a_jobid, 'LicenseJobId');

            --get the defid of the related object  license or application
            SELECT o.objectdefid
              INTO t_defid
              FROM api.objects o
             WHERE o.objectid = t_licensejobid;

            --if it is a license set the endpointid as the license
            IF t_defid = api.pkg_configquery.objectdefidforname('j_License') THEN --it is a License
                t_licinvendpointid   :=
                    api.pkg_configquery.endpointidforname('j_Investigation',
                                                          'License');
            ELSE                                        --it is an Application
                t_appinvendpointid   :=
                    api.pkg_configquery.endpointidforname('j_Investigation',
                                                          'Application');
            END IF;

            IF t_licensejobid IS NOT NULL THEN
                t_relid   :=
                    api.pkg_relationshipupdate.new(
                        NVL(t_licinvendpointid, t_appinvendpointid),
                        t_investigationid,
                        t_licensejobid);
            END IF;

            --Copy Applicable License Type rel from original Investigation to the new Investigation
            t_applicableltid   :=
                api.pkg_columnquery.VALUE(a_jobid, 'ApplicableLTId');

            BEGIN
                SELECT rd.toendpointid
                  INTO t_applicableltendpointid
                  FROM api.relationshipdefs rd
                 WHERE rd.name = 'r_InvestigationLicenseType'
                   AND rd.fromendpointname = 'Investigation';
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    api.pkg_errors.raiseerror(
                        '-20000',
                        'Cannot find From Endpoint Id from r_InvestigationLicenseType when From Endpoint Name is Investigation');
            END;

            IF t_applicableltid IS NOT NULL THEN
                t_relid   :=
                    api.pkg_relationshipupdate.new(t_applicableltendpointid,
                                                   t_investigationid,
                                                   t_applicableltid);
            END IF;

            --Set Investigation Type to "Administrative"
            api.pkg_columnupdate.setvalue(t_investigationid,
                                          'InvestigationType',
                                          'ADMINISTRATIVE');

            --Set Administrative Type to "Poic Audits"
            api.pkg_columnupdate.setvalue(t_investigationid,
                                          'AdministrativeType',
                                          'POIC AUDITS');
        END IF;
    END createinvfromprocesspoic;

    /*--------------------------------------------------
    --  ValidateAccRel() - PUBLIC
    --  This runs on constructor of r_CreatedByInvestAccusation
    --  and validates that the Accusation is related to the License
    --  in the Investigation.
    */
    --------------------------------------------------

    PROCEDURE validateaccrel(a_objectid udt_id, a_asofdate DATE)
    IS
        t_accusationjobid         udt_id;
        t_investigationjobid      udt_id;
        t_iscreatedprocedurally   VARCHAR2(1) := 'N';
        t_licensejobid            udt_id;
        t_acclicensejobid         udt_id;
    BEGIN
        t_iscreatedprocedurally   :=
            api.pkg_columnquery.VALUE(a_objectid, 'IsCreatedProcedurally');

        IF t_iscreatedprocedurally = 'N' THEN
            -- Get the InvestigationJobId
            BEGIN
                SELECT r.investigationjobid
                  INTO t_investigationjobid
                  FROM query.r_createdbyinvestaccusation r
                 WHERE r.relationshipid = a_objectid;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    NULL;
            END;

            -- Get the LicenseJobId from the rel
            BEGIN
                SELECT r.toobjectid
                  INTO t_licensejobid
                  FROM api.relationships r
                 WHERE r.fromobjectid = t_investigationjobid
                   AND r.endpointid IN
                           (api.pkg_configquery.endpointidforname(
                                'j_Investigation',
                                'License'),
                            api.pkg_configquery.endpointidforname(
                                'j_Investigation',
                                'Application'));
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    NULL;
            END;

            -- Get the AccusationJobId from the rel
            BEGIN
                SELECT MAX(il.toobjectid)
                  INTO t_acclicensejobid
                  FROM query.r_createdbyinvestaccusation  r
                       JOIN query.r_createdbyinvestaccusation ia
                           ON ia.accusationjobid = r.accusationjobid
                       JOIN api.relationships il
                           ON il.fromobjectid = ia.investigationjobid
                          AND il.endpointid IN
                                  (api.pkg_configquery.endpointidforname(
                                       'j_Investigation',
                                       'License'),
                                   api.pkg_configquery.endpointidforname(
                                       'j_Investigation',
                                       'Application'))
                 WHERE r.relationshipid = a_objectid;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    NULL;
            END;

            --   t_AccLicenseJobId := api.pkg_ColumnQuery.NumericValue(t_AccusationJobId, 'dup_LicenseJobId');

            IF t_licensejobid != t_acclicensejobid THEN
                api.pkg_errors.raiseerror(
                    -20000,
                    'You must enter an Accusation that is related to the License on this Investigation.');
            END IF;
        END IF;
    END validateaccrel;
END pkg_enforcement;
/


GRANT EXECUTE ON SITESPECIFIC.PKG_ENFORCEMENT TO POSSEEXTENSIONS;
