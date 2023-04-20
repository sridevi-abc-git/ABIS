CREATE OR REPLACE PACKAGE BODY SITESPECIFIC."PKG_SCHEDULE"
IS
    -- **************************************************************************
    -- File:        PKG_SCHEDULE.PKB
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

    PROCEDURE createreminderprocess
    IS
        t_processobjid   udt_id;
        t_jobid          udt_id;
        t_newprocessid   udt_id;
        t_lastrundate    DATE;
        t_userid         udt_id;
        t_userlogon      VARCHAR2(30);
    BEGIN
        SELECT last_run_date
          INTO t_lastrundate
          FROM sitespecific.reminder_log;

        api.pkg_logicaltransactionupdate.resettransaction;
        api.pkg_logicaltransactionupdate.starttransaction;

        FOR c
            IN (SELECT rdate.objectid reminderobjid,
                       reminderdescription,
                       reminderdate,
                       lastupdatebyuseroraclelogon
                  FROM TABLE(
                           CAST(
                               api.pkg_simplesearch.castableobjectsbyindexrange(
                                   'o_Reminder',
                                   'ReminderDate',
                                   TO_CHAR(
                                       t_lastrundate - 1,
                                       api.pkg_definition.gc_dateformat) -- Minus one to grab Reminders created same date as last run date
                                                                        ,
                                   TO_CHAR(
                                       SYSDATE,
                                       api.pkg_definition.gc_dateformat)) AS api.udt_objectlist))
                       rdate
                       JOIN
                       TABLE(
                           CAST(
                               api.pkg_simplesearch.castableobjectsbyindex(
                                   'o_Reminder',
                                   'NeedsToBeProcessed',
                                   'Y') AS api.udt_objectlist)) need
                           ON need.objectid = rdate.objectid
                       JOIN query.o_reminder r ON r.objectid = rdate.objectid)
        LOOP
            -- Find the User releated to this Reminder (if Assignment OverRide was used)
            BEGIN
                SELECT toobjectid
                  INTO t_userid
                  FROM api.relationships
                 WHERE fromobjectid = c.reminderobjid
                   AND endpointid =
                       api.pkg_configquery.endpointidforname('o_Reminder',
                                                             'Users');
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    NULL;
            END;

            -- Find the Process to which this Reminder belongs
            SELECT MAX(toobjectid)
              INTO t_processobjid
              FROM api.relationships
             WHERE fromobjectid = c.reminderobjid
               AND endpointid <>
                   api.pkg_configquery.endpointidforname('o_Reminder',
                                                         'Users');


            -- Find the Job to which the Process belongs
            t_jobid   := api.pkg_columnquery.VALUE(t_processobjid, 'JobId');


            -- Create new Reminder Process
            t_newprocessid   :=
                api.pkg_processupdate.new(
                    t_jobid,
                    api.pkg_configquery.objectdefidforname('p_Reminder'),
                    NULL,
                    NULL,
                    NULL,
                    NULL);

            api.pkg_columnupdate.setvalue(t_newprocessid,
                                          'Description',
                                          c.reminderdescription);

            api.pkg_columnupdate.setvalue(t_newprocessid,
                                          'ScheduledStartDate',
                                          TRUNC(c.reminderdate));



            IF t_userid IS NOT NULL THEN
                SELECT u.oraclelogonid
                  INTO t_userlogon
                  FROM api.users u
                 WHERE u.userid = t_userid;
            ELSE
                t_userlogon   := c.lastupdatebyuseroraclelogon;
            END IF;

            api.pkg_processupdate.assign(t_newprocessid, t_userlogon);

            api.pkg_columnupdate.setvalue(c.reminderobjid,
                                          'NeedsToBeProcessed',
                                          'N');
        END LOOP;

        UPDATE sitespecific.reminder_log
           SET last_run_date   = SYSDATE;


        api.pkg_logicaltransactionupdate.endtransaction;

        COMMIT;
    END createreminderprocess;

    ----start of system generated reminders

    PROCEDURE createsupervisorreminder(a_object udt_id, a_asofdate DATE)
    IS
        t_assignedby           udt_id;
        t_completedby          VARCHAR2(30);
        t_endpointname         VARCHAR2(40);
        t_newrelid             udt_id;
        t_objectdefid          udt_id;
        t_reminderdetailname   VARCHAR2(40);
        t_reminderobjid        udt_id;
    BEGIN
        -- Which Assign process
        t_objectdefid   := api.pkg_columnquery.VALUE(a_object, 'ObjectDefId');


        IF t_objectdefid =
           api.pkg_objectdefquery.idforname('p_AssignAdminInvestigation') THEN
            t_reminderdetailname   := 'AssignAdminInvProcessID';
            t_endpointname         := 'AssignAdminInv';
        ELSIF t_objectdefid =
              api.pkg_objectdefquery.idforname('p_AssignAppInvestigation') THEN
            t_reminderdetailname   := 'AssignAppInvProcessID';
            t_endpointname         := 'AssignAppInv';
        ELSIF t_objectdefid =
              api.pkg_objectdefquery.idforname('p_AssignInvestigation') THEN
            t_reminderdetailname   := 'AssignEnfInvProcessID';
            t_endpointname         := 'AssignEnfInv';
        ELSIF t_objectdefid =
              api.pkg_objectdefquery.idforname(
                  'p_AssignLicenseInvestigation') THEN
            t_reminderdetailname   := 'AssignLicInvProcessID';
            t_endpointname         := 'AssignLicInv';
        ELSIF t_objectdefid =
              api.pkg_objectdefquery.idforname(
                  'p_PrepHearingMemoServeSubpoena') THEN
            t_reminderdetailname   := 'AssignMemoSubpoenaProcessID';
            t_endpointname         := 'AssignCondAdminInvMemoSubpoena';
        END IF;


        -- Who completed the Assign Process
        SELECT completedby
          INTO t_completedby
          FROM api.processes
         WHERE processid = a_object;

        SELECT userid
          INTO t_assignedby
          FROM api.users
         WHERE oraclelogonid = t_completedby;


        -- Create Reminder Object and populate details
        t_reminderobjid   :=
            api.pkg_objectupdate.new(
                api.pkg_configquery.objectdefidforname('o_Reminder'),
                SYSDATE);

        IF t_reminderdetailname = 'AssignMemoSubpoenaProcessID' THEN
            api.pkg_columnupdate.setvalue(
                t_reminderobjid,
                'ReminderDescription',
                'Check status of Hearing Memo and Subpoena.');
        ELSE
            api.pkg_columnupdate.setvalue(t_reminderobjid,
                                          'ReminderDescription',
                                          'Investigation Past Due.');
        END IF;

        api.pkg_columnupdate.setvalue(
            t_reminderobjid,
            'ReminderDate',
            TRUNC(
                  api.pkg_columnquery.datevalue(a_object,
                                                'InvestigationDueDate')
                + 1));

        api.pkg_columnupdate.setvalue(t_reminderobjid,
                                      t_reminderdetailname,
                                      a_object);

        -- Relate (Assign) the Reminder Object to the User who completed the Assign Process
        t_newrelid      :=
            api.pkg_relationshipupdate.new(
                api.pkg_configquery.endpointidforname('o_Reminder', 'Users'),
                t_reminderobjid,
                t_assignedby);

        -- Relate the Reminder Object to the Process
        t_newrelid      :=
            api.pkg_relationshipupdate.new(
                api.pkg_configquery.endpointidforname('o_Reminder',
                                                      t_endpointname),
                t_reminderobjid,
                a_object);
    END createsupervisorreminder;

    PROCEDURE deletesupervisorreminder(a_object udt_id, a_asofdate DATE)
    IS
        t_objectdefid          udt_id;
        t_reminderobjid        udt_id;
        t_reminderdetailname   VARCHAR2(40);
        t_assignprocessid      udt_id;
        t_objectid             udt_id;
    BEGIN
        IF TRUNC(api.pkg_columnquery.datevalue(a_object, 'datecompleted')) --TODO Loren debug 10.03
                                                                           --if trunc(sysdate)
                                                                           <=
           api.pkg_columnquery.datevalue(a_object, 'InvestigationDueDate') THEN -- Which process is involved
            t_objectdefid   :=
                api.pkg_columnquery.VALUE(a_object, 'ObjectDefId');
            t_assignprocessid   :=
                api.pkg_columnquery.VALUE(a_object, 'AssignProcessID');

            IF t_objectdefid =
               api.pkg_objectdefquery.idforname('p_ConductAppInvestigation') THEN
                t_reminderdetailname   := 'AssignAppInvProcessID';
            ELSIF t_objectdefid =
                  api.pkg_objectdefquery.idforname(
                      'p_ConductLicenseInvestigation') THEN
                t_reminderdetailname   := 'AssignLicInvProcessID';
            --     elsif
            --      t_ObjectDefId = api.pkg_objectdefquery.IdForName('p_PrepHearingMemoServeSubpoena')
            --      t_ObjectDefId = api.pkg_objectdefquery.IdForName('p_ConductEnforcementInv')
            --      then t_ReminderDetailName := 'AssignMemoSubpoenaProcessID';
            END IF;

            --   if t_ReminderDetailName in ('AssignAppInvProcessID', 'AssignLicInvProcessID', 'AssignMemoSubpoenaProcessID')
            IF t_reminderdetailname IN
                   ('AssignAppInvProcessID', 'AssignLicInvProcessID') THEN
                FOR c
                    IN (SELECT objectid
                          FROM TABLE(
                                   CAST(
                                       api.pkg_simplesearch.castableobjectsbyindex(
                                           'o_Reminder',
                                           t_reminderdetailname,
                                           t_assignprocessid) AS api.udt_objectlist)))
                LOOP
                    api.pkg_objectupdate.remove(c.objectid, SYSDATE);
                END LOOP;
            END IF;

            IF -- p_ConductAdminInvestigation might be related to one of two reminders
               t_objectdefid =
               api.pkg_objectdefquery.idforname(
                   'p_ConductAdminInvestigation') THEN
                FOR c
                    IN (SELECT objectid
                          FROM TABLE(
                                   CAST(
                                       api.pkg_simplesearch.castableobjectsbyindex(
                                           'o_Reminder',
                                           'AssignAdminInvProcessId',
                                           t_assignprocessid) AS api.udt_objectlist))
                               obj1
                        UNION
                        SELECT objectid
                          FROM TABLE(
                                   CAST(
                                       api.pkg_simplesearch.castableobjectsbyindex(
                                           'o_Reminder',
                                           'AssignMemoSubpoenaProcessID',
                                           t_assignprocessid) AS api.udt_objectlist))
                               obj2)
                LOOP
                    api.pkg_objectupdate.remove(c.objectid, SYSDATE);
                END LOOP;
            END IF;                    -- identify p_ConductAdminInvestigation

            IF -- p_ConductEnforcementInv might be related to one of two reminders
               t_objectdefid =
               api.pkg_objectdefquery.idforname('p_ConductEnforcementInv') THEN
                FOR c
                    IN (SELECT objectid
                          FROM TABLE(
                                   CAST(
                                       api.pkg_simplesearch.castableobjectsbyindex(
                                           'o_Reminder',
                                           'AssignEnfInvProcessID',
                                           t_assignprocessid) AS api.udt_objectlist))
                               obj1
                        UNION
                        SELECT objectid
                          FROM TABLE(
                                   CAST(
                                       api.pkg_simplesearch.castableobjectsbyindex(
                                           'o_Reminder',
                                           'AssignMemoSubpoenaProcessID',
                                           t_assignprocessid) AS api.udt_objectlist))
                               obj2)
                LOOP
                    api.pkg_objectupdate.remove(c.objectid, SYSDATE);
                END LOOP;
            END IF;                        -- identify p_ConductEnforcementInv
        END IF;                                        -- completion date test

        -- below is for when the procedure is run on update of the Investigation job when FirstVisitDate is not null
        IF api.pkg_columnquery.datevalue(a_object, 'FirstVisitDate')
               IS NOT NULL THEN
            t_assignprocessid   :=
                api.pkg_columnquery.VALUE(a_object, 'AssignProcessID');

            FOR c
                IN (SELECT objectid
                      FROM TABLE(
                               CAST(
                                   api.pkg_simplesearch.castableobjectsbyindex(
                                       'o_Reminder',
                                       'AssignEnfInvProcessID',
                                       t_assignprocessid) AS api.udt_objectlist))
                           obj1)
            LOOP
                api.pkg_objectupdate.remove(c.objectid, SYSDATE);
            END LOOP;
        END IF;
    END deletesupervisorreminder;

    PROCEDURE createtransferreminder(a_object        udt_id,
                                     a_asofdate      DATE,
                                     a_jobid         udt_id)
    IS
        t_apptype             VARCHAR(20);
        t_completedby         VARCHAR(20);
        t_licrepid            udt_id;
        t_newrelid            udt_id;
        t_reminderobjid       udt_id;
        t_userid              udt_id;
        t_persontoperson      CHAR(1);
        t_fiduciarytransfer   CHAR(1);
        t_droppartner         CHAR(1);
    BEGIN
        SELECT applicationtype,
               persontoperson,
               fiduciarytransfer,
               droppartner
          INTO t_apptype,
               t_persontoperson,
               t_fiduciarytransfer,
               t_droppartner
          FROM query.j_application
         WHERE objectid = a_jobid;

        IF t_apptype = 'Transfer'
       AND (t_persontoperson = 'Y'
         OR t_fiduciarytransfer = 'Y'
         OR t_droppartner = 'Y') THEN
            SELECT completedby
              INTO t_completedby
              FROM api.processes
             WHERE jobid = a_jobid
               AND processid = a_object;

            SELECT userid
              INTO t_userid
              FROM api.users
             WHERE oraclelogonid = t_completedby;

            -- Lic Rep assigned the Investigation
            SELECT toobjectid
              INTO t_licrepid
              FROM api.relationships
             WHERE fromobjectid = a_object
               AND endpointid =
                   api.pkg_configquery.endpointidforname(
                       'p_AssignAppInvestigation',
                       'LicensingRep');


            -- Create Reminder Object for Supervisor and populate details
            t_reminderobjid   :=
                api.pkg_objectupdate.new(
                    api.pkg_configquery.objectdefidforname('o_Reminder'),
                    SYSDATE);

            api.pkg_columnupdate.setvalue(
                t_reminderobjid,
                'ReminderDescription',
                'Check Transfer of Ownership Application status.');

            api.pkg_columnupdate.setvalue(
                t_reminderobjid,
                'ReminderDate',
                  TRUNC(
                      api.pkg_columnquery.datevalue(a_object,
                                                    'datecompleted'))
                + 60);

            api.pkg_columnupdate.setvalue(t_reminderobjid,
                                          'AssignTxfrInvProcessID',
                                          a_object);

            -- Relate (Assign) the Reminder Object to the User who completed the Assign Process
            t_newrelid   :=
                api.pkg_relationshipupdate.new(
                    api.pkg_configquery.endpointidforname('o_Reminder',
                                                          'Users'),
                    t_reminderobjid,
                    t_userid);


            -- Create Reminder Object for LR and populate details
            t_reminderobjid   :=
                api.pkg_objectupdate.new(
                    api.pkg_configquery.objectdefidforname('o_Reminder'),
                    SYSDATE);

            api.pkg_columnupdate.setvalue(
                t_reminderobjid,
                'ReminderDescription',
                'Check Transfer of Ownership Application status.');

            api.pkg_columnupdate.setvalue(
                t_reminderobjid,
                'ReminderDate',
                  TRUNC(
                      api.pkg_columnquery.datevalue(a_object,
                                                    'datecompleted'))
                + 60);

            api.pkg_columnupdate.setvalue(t_reminderobjid,
                                          'AssignTxfrInvProcessID',
                                          a_object);

            -- Relate (Assign) the Reminder Object to the LR assigned the Transfer Investigation
            t_newrelid   :=
                api.pkg_relationshipupdate.new(
                    api.pkg_configquery.endpointidforname('o_Reminder',
                                                          'Users'),
                    t_reminderobjid,
                    t_licrepid);

            -- Relate the Reminder Object to the Process
            t_newrelid   :=
                api.pkg_relationshipupdate.new(
                    api.pkg_configquery.endpointidforname('o_Reminder',
                                                          'AssignAppInv'),
                    t_reminderobjid,
                    a_object);
        END IF;                                               -- Transfer test
    END createtransferreminder;


    PROCEDURE deletetransferreminder(a_object        udt_id,
                                     a_asofdate      DATE,
                                     a_jobid         udt_id)
    IS
        t_reminderobjid            udt_id;
        t_assigntxfrinvprocessid   udt_id;
    BEGIN
        -- The first Assign process is associated with system generated reminders.
        SELECT MIN(objectid)
          INTO t_assigntxfrinvprocessid
          FROM query.p_assignappinvestigation
         WHERE jobid = a_jobid;

        IF TRUNC(api.pkg_columnquery.datevalue(a_object, 'datecompleted')) -- License Issue Date
                                                                           <=
             TRUNC(
                 api.pkg_columnquery.datevalue(t_assigntxfrinvprocessid,
                                               'datecompleted'))
           + 60                                               -- Reminder Date
                THEN
            FOR c
                IN (SELECT r.objectid
                      FROM TABLE(
                               CAST(
                                   api.pkg_simplesearch.castableobjectsbyindex(
                                       'o_Reminder',
                                       'AssignTxfrInvProcessID',
                                       t_assigntxfrinvprocessid) AS api.udt_objectlist))
                           r)
            LOOP
                api.pkg_objectupdate.remove(c.objectid, SYSDATE);
            END LOOP;
        END IF;
    END deletetransferreminder;


    PROCEDURE createoriginalappreminder(a_object        udt_id,
                                        a_asofdate      DATE,
                                        a_jobid         udt_id)
    IS
        t_completedby     VARCHAR(20);
        t_licrepid        udt_id;
        t_newrelid        udt_id;
        t_reminderobjid   udt_id;
        t_userid          udt_id;
    BEGIN
        IF api.pkg_columnquery.VALUE(a_jobid, 'ApplicationType') = 'Original' THEN
            SELECT completedby
              INTO t_completedby
              FROM api.processes
             WHERE jobid = a_jobid
               AND processid = a_object;

            SELECT userid
              INTO t_userid
              FROM api.users
             WHERE oraclelogonid = t_completedby;

            -- Lic Rep assigned the Investigation
            SELECT toobjectid
              INTO t_licrepid
              FROM api.relationships
             WHERE fromobjectid = a_object
               AND endpointid =
                   api.pkg_configquery.endpointidforname(
                       'p_AssignAppInvestigation',
                       'LicensingRep');

            -- Create Reminder Object for Supervisor and populate details
            t_reminderobjid   :=
                api.pkg_objectupdate.new(
                    api.pkg_configquery.objectdefidforname('o_Reminder'),
                    SYSDATE);

            api.pkg_columnupdate.setvalue(
                t_reminderobjid,
                'ReminderDescription',
                'Check status of Original Application.');

            api.pkg_columnupdate.setvalue(
                t_reminderobjid,
                'ReminderDate',
                  TRUNC(
                      api.pkg_columnquery.datevalue(a_object,
                                                    'datecompleted'))
                + 70);

            api.pkg_columnupdate.setvalue(t_reminderobjid,
                                          'AssignOrigInvProcessID',
                                          a_object);

            -- Relate (Assign) the Reminder Object to the User who completed the Assign Process
            t_newrelid   :=
                api.pkg_relationshipupdate.new(
                    api.pkg_configquery.endpointidforname('o_Reminder',
                                                          'Users'),
                    t_reminderobjid,
                    t_userid);

            -- Create Reminder Object for LR and populate details
            t_reminderobjid   :=
                api.pkg_objectupdate.new(
                    api.pkg_configquery.objectdefidforname('o_Reminder'),
                    SYSDATE);

            api.pkg_columnupdate.setvalue(
                t_reminderobjid,
                'ReminderDescription',
                'Check status of Original Application.');

            api.pkg_columnupdate.setvalue(
                t_reminderobjid,
                'ReminderDate',
                  TRUNC(
                      api.pkg_columnquery.datevalue(a_object,
                                                    'datecompleted'))
                + 70);

            api.pkg_columnupdate.setvalue(t_reminderobjid,
                                          'AssignOrigInvProcessID',
                                          a_object);

            -- Relate (Assign) the Reminder Object to the LR assigned the Original Investigation
            t_newrelid   :=
                api.pkg_relationshipupdate.new(
                    api.pkg_configquery.endpointidforname('o_Reminder',
                                                          'Users'),
                    t_reminderobjid,
                    t_licrepid);

            -- Relate the Reminder Object to the Process
            t_newrelid   :=
                api.pkg_relationshipupdate.new(
                    api.pkg_configquery.endpointidforname('o_Reminder',
                                                          'AssignAppInv'),
                    t_reminderobjid,
                    a_object);
        END IF;                                               -- Original test
    END createoriginalappreminder;


    PROCEDURE deleteoriginalappreminder(a_object        udt_id,
                                        a_asofdate      DATE,
                                        a_jobid         udt_id)
    IS
        t_assignoriginvprocessid   udt_id;
    BEGIN
        -- The first Assign process is associated with system generated reminders.
        SELECT MIN(objectid)
          INTO t_assignoriginvprocessid
          FROM query.p_assignappinvestigation
         WHERE jobid = a_jobid;

        IF TRUNC(api.pkg_columnquery.datevalue(a_object, 'datecompleted')) -- License Issue Date
                                                                           -- 10.03 debug datecompleted should be created? issue? date of process
                                                                           <=
             TRUNC(
                 api.pkg_columnquery.datevalue(t_assignoriginvprocessid,
                                               'CreatedDate'))
           + 70                                               -- Reminder Date
                THEN
            FOR c
                IN (SELECT r.objectid
                      FROM TABLE(
                               CAST(
                                   api.pkg_simplesearch.castableobjectsbyindex(
                                       'o_Reminder',
                                       'AssignOrigInvProcessID',
                                       t_assignoriginvprocessid) AS api.udt_objectlist))
                           r)
            LOOP
                api.pkg_objectupdate.remove(c.objectid, SYSDATE);
            END LOOP;
        END IF;
    END deleteoriginalappreminder;

    /*---------------------------------------------------------------------------
     * RemoveLegalEntity() - PRIVATE
     *  Recursively remove Legal Entities that are no longer related to any Applications
     *  or Licenses to prevent data duplication. The function returns either true or false
     *  indicating whether it was able to remove the Legal Entity, stop propagation of function
     *  on failure.
     *-------------------------------------------------------------------------*/
    FUNCTION removelegalentity(a_legalentityid udt_id,
                               a_parentlegalentities api.udt_objectlist)
        RETURN BOOLEAN
    IS
        t_parentlelist           api.udt_objectlist;
        t_personlecount          NUMBER;
        t_companylecount         NUMBER;
        t_companyodlcount        NUMBER;
        t_othercount             NUMBER;
        t_removeleresult         BOOLEAN;
        t_relationshipid         udt_id;
        t_applicanttoappep       udt_id
            := api.pkg_configquery.endpointidforname('o_LegalEntity',
                                                     'AppApplication');
        t_licenseetolicep        udt_id
            := api.pkg_configquery.endpointidforname('o_LegalEntity',
                                                     'LegalEntityLicense');
        t_osmtoappep             udt_id
            := api.pkg_configquery.endpointidforname('o_LegalEntity',
                                                     'OSMApplication');
        t_osmletolicep           udt_id
            := api.pkg_configquery.endpointidforname('o_LegalEntity',
                                                     'OSMLicense');
        t_p12aparenttoholderep   udt_id
            := api.pkg_configquery.endpointidforname('o_LegalEntity',
                                                     'P12AParent');
        t_p12letoappep           udt_id
            := api.pkg_configquery.endpointidforname('o_LegalEntity',
                                                     'P12Application');
        t_p12aholdertoparentep   udt_id
            := api.pkg_configquery.endpointidforname('o_LegalEntity',
                                                     'P12AStockholder');
        t_p12letolicep           udt_id
            := api.pkg_configquery.endpointidforname('o_LegalEntity',
                                                     'P12License');
        t_primp12leappep         udt_id
            := api.pkg_configquery.endpointidforname('o_LegalEntity',
                                                     'PrimaryP12Application');
        t_primp12lelicep         udt_id
            := api.pkg_configquery.endpointidforname('o_LegalEntity',
                                                     'PrimaryP12License');
    BEGIN
        --FOLLOWING LINE IS TEMP TESTING CODE
        dbms_output.put_line(a_legalentityid);

        IF sitespecific.pkg_utils.doesobjectexist(a_legalentityid) THEN
            -- Copy over the list, and append the current Legal Entity
            t_parentlelist   := a_parentlegalentities;
            t_parentlelist.EXTEND;
            t_parentlelist(t_parentlelist.COUNT)   :=
                api.udt_object(a_legalentityid);

            -- In order for a Legal Entity to be deleted, certain criteria must be met:
            -- 1) the related Person / Company must be related to another Legal Entity
            -- 2) OR the related Company must be related to a One Day License.

            -- Count of Person to Legal Entity
            SELECT COUNT(1)
              INTO t_personlecount
              FROM query.r_legalentityperson  lep
                   JOIN (SELECT lep2.personobjectid
                           FROM query.r_legalentityperson lep2
                          WHERE lep2.legalentityobjectid = a_legalentityid) p
                       ON lep.personobjectid = p.personobjectid
             WHERE lep.legalentityobjectid != a_legalentityid;

            -- Count of Company to Legal Entity
            SELECT COUNT(1)
              INTO t_companylecount
              FROM query.r_legalentitycompany  lec
                   JOIN (SELECT lec2.companyobjectid
                           FROM query.r_legalentitycompany lec2
                          WHERE lec2.legalentityobjectid = a_legalentityid) c
                       ON lec.companyobjectid = c.companyobjectid
             WHERE lec.legalentityobjectid != a_legalentityid;

            -- Count of Company to One Day License
            SELECT COUNT(1)
              INTO t_companyodlcount
              FROM query.r_legalentitycompany  lec
                   JOIN query.r_companyonedaylicense codl
                       ON lec.companyobjectid = codl.companyobjectid
             WHERE lec.legalentityobjectid = a_legalentityid;

            -- Count of other relationships to the Legal Entity
            SELECT COUNT(1)
              INTO t_othercount
              FROM api.relationships r
             WHERE r.fromobjectid = a_legalentityid
               AND r.endpointid IN (t_applicanttoappep,
                                    t_licenseetolicep,
                                    t_osmtoappep,
                                    t_osmletolicep,
                                    t_p12aparenttoholderep,
                                    t_p12letoappep,
                                    t_p12aholdertoparentep,
                                    t_p12letolicep,
                                    t_primp12leappep,
                                    t_primp12lelicep);

            -- If the related person or company have no other relationships or a One Day License OR the Legal Entity does have any of the listed EndPoints,
            -- do not delete the Legal Entity, return false and stop removal.
            IF t_personlecount + t_companylecount + t_companyodlcount = 0
            OR t_othercount > 0 THEN
                api.pkg_columnupdate.setvalue(a_legalentityid,
                                              'ShouldDelete',
                                              'N');
                RETURN FALSE;
            END IF;

            -- Recurse through all related Legal Entities, if removal of one of these
            -- returns false, then return false to stop all removal.
            FOR le
                IN (SELECT r.toobjectid objectid
                      FROM api.relationships r
                     WHERE r.fromobjectid = a_legalentityid
                       AND api.pkg_columnquery.VALUE(r.toobjectid,
                                                     'ObjectDefName') =
                           'o_LegalEntity'
                       AND NOT EXISTS
                               (SELECT 1
                                  FROM TABLE(a_parentlegalentities) ple
                                 WHERE ple.objectid = r.toobjectid))
            LOOP
                -- Before removing a Legal Entity, make sure we haven't already removed it.
                IF pkg_utils.doesobjectexist(le.objectid) THEN
                    t_removeleresult   :=
                        removelegalentity(le.objectid, t_parentlelist);

                    IF NOT t_removeleresult THEN
                        api.pkg_columnupdate.setvalue(a_legalentityid,
                                                      'ShouldDelete',
                                                      'N');
                        RETURN FALSE;
                    END IF;
                END IF;
            END LOOP;

            -- We should have returned from all recursive calls at this point, and can now attempt
            -- to remove the Person / Company relationships / objects and the Legal Entity stored
            -- relationships, and finally the Legal Entity object.

            -- Remove Person / Company relationships and the objects themselves
            FOR pc
                IN (SELECT lep.personobjectid objectid
                      FROM query.r_legalentityperson lep
                     WHERE lep.legalentityobjectid = a_legalentityid
                       AND NOT EXISTS
                               (SELECT 1
                                  FROM api.relationships r
                                 WHERE r.fromobjectid = lep.personobjectid
                                   AND r.toobjectid != a_legalentityid)
                    UNION ALL
                    SELECT lec.companyobjectid objectid
                      FROM query.r_legalentitycompany lec
                     WHERE lec.legalentityobjectid = a_legalentityid
                       AND NOT EXISTS
                               (SELECT 1
                                  FROM api.relationships r
                                 WHERE r.fromobjectid = lec.companyobjectid
                                   AND r.toobjectid != a_legalentityid))
            LOOP
                SELECT r.relationshipid
                  INTO t_relationshipid
                  FROM api.relationships r
                 WHERE r.fromobjectid = pc.objectid
                   AND r.toobjectid = a_legalentityid;

                -- Before removing anything, we need to make sure it still exists...
                IF sitespecific.pkg_utils.doesobjectexist(t_relationshipid) THEN
                    api.pkg_relationshipupdate.remove(t_relationshipid);
                END IF;

                IF sitespecific.pkg_utils.doesobjectexist(pc.objectid) THEN
                    api.pkg_objectupdate.remove(pc.objectid);
                END IF;
            END LOOP;

            -- Remove stored relationships to the Legal Entity, followed by the Legal Entity object.
            -- BUT, don't remove any parent Legal Entities.
            FOR sr IN (SELECT r.relationshipid
                         FROM api.relationships r
                        WHERE r.fromobjectid = a_legalentityid
                          AND NOT EXISTS
                                  (SELECT 1
                                     FROM TABLE(a_parentlegalentities) ple
                                    WHERE ple.objectid = r.toobjectid))
            LOOP
                IF sitespecific.pkg_utils.doesobjectexist(sr.relationshipid) THEN
                    api.pkg_relationshipupdate.remove(sr.relationshipid);
                END IF;
            END LOOP;

            -- Remove the Legal Entity and return true for successful deletion
            IF sitespecific.pkg_utils.doesobjectexist(a_legalentityid) THEN
                api.pkg_objectupdate.remove(a_legalentityid);
            END IF;

            RETURN TRUE;
        ELSE
            RETURN FALSE;
        END IF;
    END removelegalentity;

    /*---------------------------------------------------------------------------
     * CleanLegalEntities() - PUBLIC
     *  Run by the Process Server, removes orphaned Legal Entities that are no longer
     *  related to any Applications or Licenses to prevent duplicate data from appearing
     *  in searches for Legal Entities.
     *-------------------------------------------------------------------------*/
    PROCEDURE cleanlegalentities(a_rows NUMBER DEFAULT 1000)
    IS
        t_removeleresult   BOOLEAN;
    BEGIN
        -- Find Legal Entities that are marked for deletion, this value is set by
        -- sitespecific.pkg_LegalEntity.MarkForDeletion
        FOR le
            IN (SELECT s.objectid
                  FROM TABLE(
                           api.pkg_simplesearch.castableobjectsbyindex(
                               'o_LegalEntity',
                               'ShouldDelete',
                               'Y')) s
                 WHERE ROWNUM <= a_rows)
        --WHERE CLAUSE ABOVE IS TEMPORARY AND SHOULD BE REMOVED.
        LOOP
            t_removeleresult   :=
                removelegalentity(le.objectid, api.udt_objectlist());
        END LOOP;
    END cleanlegalentities;

    PROCEDURE createenfinvreminder(a_object        udt_id,
                                   a_asofdate      DATE,
                                   a_jobid         udt_id)
    IS
        t_completedby     VARCHAR(20);
        t_newrelid        udt_id;
        t_priority        query.p_assigninvestigation.departmentpriority%TYPE;
        t_reminderobjid   udt_id;
        t_userid          udt_id;
    BEGIN
        t_priority   :=
            api.pkg_columnquery.VALUE(a_object, 'DepartmentPriority');

        IF t_priority IS NOT NULL THEN
            SELECT completedby
              INTO t_completedby
              FROM api.processes
             WHERE jobid = a_jobid
               AND processid = a_object;

            SELECT userid
              INTO t_userid
              FROM api.users
             WHERE oraclelogonid = t_completedby;

            -- Create Reminder Object and populate details
            t_reminderobjid   :=
                api.pkg_objectupdate.new(
                    api.pkg_configquery.objectdefidforname('o_Reminder'),
                    SYSDATE);
            api.pkg_columnupdate.setvalue(
                t_reminderobjid,
                'ReminderDescription',
                'Check Complaint Investigation status.');

            IF t_priority = '1' THEN
                api.pkg_columnupdate.setvalue(t_reminderobjid,
                                              'ReminderDate',
                                              TRUNC(SYSDATE + 30));
            ELSIF t_priority = '2' THEN
                api.pkg_columnupdate.setvalue(t_reminderobjid,
                                              'ReminderDate',
                                              TRUNC(SYSDATE + 45));
            ELSIF t_priority = '3' THEN
                api.pkg_columnupdate.setvalue(t_reminderobjid,
                                              'ReminderDate',
                                              TRUNC(SYSDATE) + 60);
            ELSIF t_priority = '4' THEN
                api.pkg_columnupdate.setvalue(t_reminderobjid,
                                              'ReminderDate',
                                              TRUNC(SYSDATE + 75));
            END IF;                                                -- Priority

            api.pkg_columnupdate.setvalue(t_reminderobjid,
                                          'AssignPriEnfInvProcessID',
                                          a_object);

            -- Relate (Assign) the Reminder Object to the User who completed the Assign Process
            t_newrelid   :=
                api.pkg_relationshipupdate.new(
                    api.pkg_configquery.endpointidforname('o_Reminder',
                                                          'Users'),
                    t_reminderobjid,
                    t_userid);

            -- Relate the Reminder Object to the Process
            t_newrelid   :=
                api.pkg_relationshipupdate.new(
                    api.pkg_configquery.endpointidforname('o_Reminder',
                                                          'AssignEnfInv'),
                    t_reminderobjid,
                    a_object);
        END IF;                                    -- DepartmentPriority value
    END createenfinvreminder;

    PROCEDURE deleteenfinvreminder(a_object        udt_id,
                                   a_asofdate      DATE,
                                   a_jobid         udt_id)
    IS
        t_assignprienfinvprocessid   udt_id;
        t_reminderdate               DATE;
        t_reminderobjid              udt_id;
    BEGIN
        -- The first Assign process is associated with system generated reminders.
        BEGIN
            SELECT MIN(objectid)
              INTO t_assignprienfinvprocessid
              FROM query.p_assigninvestigation
             WHERE jobid = a_jobid;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                api.pkg_errors.raiseerror(
                    '-20000',
                    'Did not find Assign Inv process. Jobid: ' || a_jobid);
        END;

        BEGIN
            SELECT r.objectid,
                   api.pkg_columnquery.datevalue(r.objectid, 'ReminderDate')
                       reminderdate
              INTO t_reminderobjid, t_reminderdate
              FROM TABLE(
                       CAST(
                           api.pkg_simplesearch.castableobjectsbyindex(
                               'o_Reminder',
                               'AssignPriEnfInvProcessID',
                               t_assignprienfinvprocessid) AS api.udt_objectlist))
                   r;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RETURN; -- Nothing to do; Reminder is only created when Department Priority is populated.
        END;

        IF TRUNC(api.pkg_columnquery.datevalue(a_object, 'datecompleted')) -- Inv Comp Date
                                                                           --        <= trunc(t_ReminderDate)
                                                                           <=
           t_reminderdate THEN
            api.pkg_objectupdate.remove(t_reminderobjid, SYSDATE); -- Reminder Date
        END IF;
    END deleteenfinvreminder;

    PROCEDURE createpremexpanreminder(a_object        udt_id,
                                      a_asofdate      DATE,
                                      a_jobid         udt_id)
    IS
        t_assignlicinvprocessid   udt_id;
        t_completedby             VARCHAR(20);
        t_newrelid                udt_id;
        t_reminderobjid           udt_id;
        t_userid                  udt_id;
    BEGIN
        IF api.pkg_columnquery.VALUE(a_object, 'AdminTypes') =
           'PREMISES EXPANSION REQUEST' THEN
            SELECT completedby
              INTO t_completedby
              FROM api.processes
             WHERE jobid = a_jobid
               AND processid = a_object;


            SELECT userid
              INTO t_userid
              FROM api.users
             WHERE oraclelogonid = t_completedby;

            -- Create Reminder Object for Supervisor and populate details
            t_reminderobjid   :=
                api.pkg_objectupdate.new(
                    api.pkg_configquery.objectdefidforname('o_Reminder'),
                    SYSDATE);

            api.pkg_columnupdate.setvalue(
                t_reminderobjid,
                'ReminderDescription',
                'Check Premises Expansion Investigation.');

            api.pkg_columnupdate.setvalue(t_reminderobjid,
                                          'ReminderDate',
                                          TRUNC(SYSDATE + 10));

            api.pkg_columnupdate.setvalue(t_reminderobjid,
                                          'AssignLicInvProcessID',
                                          a_object);

            -- Relate (Assign) the Reminder Object to the User who completed the Assign Process
            t_newrelid   :=
                api.pkg_relationshipupdate.new(
                    api.pkg_configquery.endpointidforname('o_Reminder',
                                                          'Users'),
                    t_reminderobjid,
                    t_userid);

            -- Relate the Reminder Object to the Process
            t_newrelid   :=
                api.pkg_relationshipupdate.new(
                    api.pkg_configquery.endpointidforname('o_Reminder',
                                                          'AssignLicInv'),
                    t_reminderobjid,
                    a_object);
        END IF;                                             -- Admin Type test
    END createpremexpanreminder;


    /* procedure CreateInterimRetailReminder (
       a_Object       udt_ID,
       a_AsOfDate     date
     ) is
     t_LicRepId       udt_id;
     t_NewRelId       udt_id;
     t_ReminderObjId  udt_id;
     begin

     -- Lic Rep assigned the Interim Retail Permit
     select ToObjectId into t_LicRepId
     from api.relationships
     where FromObjectId = a_Object
     and EndPointId = api.pkg_configquery.EndPointIdForName('o_TemporaryPermit', 'LicensingRepTempPermit') ;

     -- Create Reminder Object for LR and populate details
     t_ReminderObjId :=  api.pkg_objectupdate.New(
                             api.pkg_ConfigQuery.ObjectDefIdForName('o_Reminder')
                             ,sysdate);

       api.pkg_columnupdate.SetValue(t_ReminderObjId
                                    ,'ReminderDescription'
                                    ,'Interim Retail Permit expiring.');

       api.pkg_columnupdate.SetValue(t_ReminderObjId
                                      ,'ReminderDate'
                                      ,trunc(api.pkg_columnquery.DateValue(a_Object,'EffectiveTo'))-10);

       api.pkg_columnupdate.SetValue(t_ReminderObjId
                                    ,'IssInterimRetailProcessID'
                                    ,a_Object);

     -- Relate (Assign) the Reminder Object to the LR assigned the Interim Retail
       t_NewRelId := api.pkg_relationshipupdate.New(
                         api.pkg_configquery.EndPointIdForName('o_Reminder', 'Users')
                        ,t_ReminderObjId
                        ,t_LicRepId);

     -- Relate the Reminder Object to the Temporary Permit Object
       t_NewRelId := api.pkg_relationshipupdate.New(
                         api.pkg_configquery.EndPointIdForName('o_Reminder', 'TempPermitRemind')
                        ,t_ReminderObjId
                        ,a_Object);

    end CreateInterimRetailReminder;  */

    PROCEDURE createtemppermitreminder(a_objectid udt_id, a_asofdate DATE)
    IS
        t_licrepid        udt_id;
        t_appjobid        NUMBER(9);
        t_newrelid        udt_id;
        t_newtemprelid    udt_id;
        t_reminderobjid   udt_id;
        t_type            VARCHAR2(100);
    BEGIN
        BEGIN
            -- Lic Rep assigned the Temp Permit
            SELECT toobjectid
              INTO t_licrepid
              FROM api.relationships
             WHERE fromobjectid = a_objectid
               AND endpointid =
                   api.pkg_configquery.endpointidforname(
                       'o_TemporaryPermit',
                       'LicensingRepTempPermit');
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                SELECT lt.createdby
                  INTO t_licrepid
                  FROM api.objects  o
                       JOIN api.logicaltransactions lt
                           ON lt.logicaltransactionid =
                              o.logicaltransactionid
                 WHERE o.objectid = a_objectid;
        END;

        -- Create Reminder Object for LR and populate details
        t_reminderobjid   :=
            api.pkg_objectupdate.new(
                api.pkg_configquery.objectdefidforname('o_Reminder'),
                SYSDATE);

        api.pkg_columnupdate.setvalue(t_reminderobjid,
                                      'ReminderDescription',
                                      'Temporary Permit expiring.');

        api.pkg_columnupdate.setvalue(
            t_reminderobjid,
            'ReminderDate',
              TRUNC(api.pkg_columnquery.datevalue(a_objectid, 'EffectiveTo'))
            - 10);


        t_type   := api.pkg_columnquery.VALUE(a_objectid, 'Type');

        IF t_type = 'Temporary Permit' THEN
            api.pkg_columnupdate.setvalue(t_reminderobjid,
                                          'IssTempPermitProcessID',
                                          a_objectid);
        ELSE
            api.pkg_columnupdate.setvalue(t_reminderobjid,
                                          'IssInterimRetailProcessID',
                                          a_objectid);
        END IF;

        -- Relate (Assign) the Reminder Object to the LR assigned the Original Investigation
        t_newrelid   :=
            api.pkg_relationshipupdate.new(
                api.pkg_configquery.endpointidforname('o_Reminder', 'Users'),
                t_reminderobjid,
                t_licrepid);


        t_appjobid   :=
            api.pkg_columnquery.VALUE(a_objectid, 'ApplicationJobId');

        IF t_appjobid IS NULL THEN
            api.pkg_errors.raiseerror(
                -20000,
                'Error: Temporary Permit has no Application');
        END IF;

        -- Relate the Temporary Permit Object to the Application Job
        t_newtemprelid   :=
            api.pkg_relationshipupdate.new(
                api.pkg_configquery.endpointidforname('o_Reminder',
                                                      'ReminderApplication'),
                t_reminderobjid,
                t_appjobid);
    END createtemppermitreminder;

    ----end of system generated reminders

    PROCEDURE insertlessthanzerobalancelog
    IS
        t_transid   NUMBER(9, 0);
    BEGIN
        t_transid   := api.pkg_logicaltransactionupdate.currenttransaction;

        INSERT INTO sitespecific.lessthanzerobalancelog(logicaltransactionid,
                                                        runstartdate)
            SELECT logicaltransactionid, createddate
              FROM api.logicaltransactions
             WHERE logicaltransactionid = t_transid;

        api.pkg_logicaltransactionupdate.endtransaction;
        COMMIT;
    END insertlessthanzerobalancelog;

    PROCEDURE synclessthanzerobalance
    IS
        t_amount                 NUMBER(11, 2);
        t_ovr                    NUMBER(11, 2);
        err_msg                  VARCHAR2(3950);
        t_logicaltransactionid   NUMBER(9, 0);
        t_lastrunstartdate       DATE;
        t_currentdate            DATE := TRUNC(SYSDATE);
        t_ptobjectlist           api.udt_objectlist;
    BEGIN
        --remove applications which have resulted in Licenses
        DELETE FROM sitespecific.lessthanzerobalance l
              WHERE EXISTS
                        (SELECT 1
                           FROM query.r_applicationlicense r
                          WHERE r.applicationjobid = l.jobid);

        COMMIT;

        --add new job ids
        INSERT INTO sitespecific.lessthanzerobalance(jobid)
            SELECT x.jobid
              FROM (SELECT l.jobid
                      FROM query.j_license l
                     WHERE l.objectdeftypeid = 2
                    UNION ALL
                    SELECT a.jobid
                      FROM query.j_application a
                     WHERE a.objectdeftypeid = 2
                       AND NOT EXISTS
                               (SELECT 1
                                  FROM query.r_applicationlicense r
                                 WHERE r.applicationjobid = a.jobid)) x
             WHERE NOT EXISTS
                       (SELECT 1
                          FROM sitespecific.lessthanzerobalance l
                         WHERE l.jobid = x.jobid);

        COMMIT;

        BEGIN
            SELECT MAX(l.logicaltransactionid)
              INTO t_logicaltransactionid
              FROM sitespecific.lessthanzerobalancelog l;

            SELECT TRUNC(l.runstartdate)
              INTO t_lastrunstartdate
              FROM sitespecific.lessthanzerobalancelog l
             WHERE l.logicaltransactionid = t_logicaltransactionid;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                api.pkg_errors.raiseerror(
                    -20000,
                    'There is no record of when the last synchronization occured.');
        END;

        --identify jobs with new Payment Transactions since the last sync, update lastupdated to null as they need to be re-synched.
        UPDATE sitespecific.lessthanzerobalance l
           SET l.needsprocessing   = 'Y'
         WHERE l.jobid IN
                   (SELECT DISTINCT f.jobid
                      FROM api.feetransactions  ft
                           JOIN api.fees f ON f.feeid = ft.feeid
                           JOIN api.paymenttransactions pt
                               ON pt.transactionid = ft.transactionid
                     WHERE ft.transactiondate > t_lastrunstartdate);

        COMMIT;

        --identify jobs with new Payment Status objects since the last log, updated last updated to null
        UPDATE sitespecific.lessthanzerobalance l
           SET l.needsprocessing   = 'Y'
         WHERE l.jobid IN
                   (SELECT  /*+ CARDINALITY(x 500)*/
                           DISTINCT l.jobid
                      FROM TABLE(
                               CAST(
                                   api.pkg_simplesearch.castableobjectsbyindexrange(
                                       'o_PaymentStatus',
                                       'dup_CreatedDate',
                                       TO_CHAR(
                                           t_lastrunstartdate,
                                           'YYYY-MM-DD HH24:MI:SS'),
                                       TO_CHAR(
                                           t_currentdate + 1,
                                           'YYYY-MM-DD HH24:MI:SS')) AS api.udt_objectlist))
                           x
                           JOIN query.r_paymentstatuspaymenttrans r
                               ON r.paymentstatusobjectid = x.objectid
                           JOIN query.o_paymenttransactions opt
                               ON opt.objectid = r.paymenttransactionobjectid
                           JOIN api.feetransactions ft
                               ON ft.transactionid = opt.transactionid
                           JOIN api.fees f ON f.feeid = ft.feeid
                           JOIN query.j_license l
                               ON l.externalfilenum =
                                  api.pkg_columnquery.VALUE(f.jobid,
                                                            'LicenseNumber'));

        COMMIT;

        UPDATE sitespecific.lessthanzerobalance l
           SET l.needsprocessing   = 'Y'
         WHERE l.jobid IN
                   (SELECT  /*+ CARDINALITY(x 500)*/
                           DISTINCT f.jobid
                      FROM TABLE(
                               CAST(
                                   api.pkg_simplesearch.castableobjectsbyindexrange(
                                       'o_PaymentStatus',
                                       'dup_CreatedDate',
                                       TO_CHAR(
                                           t_lastrunstartdate,
                                           'YYYY-MM-DD HH24:MI:SS'),
                                       TO_CHAR(
                                           t_currentdate + 1,
                                           'YYYY-MM-DD HH24:MI:SS')) AS api.udt_objectlist))
                           x
                           JOIN query.r_paymentstatuspaymenttrans r
                               ON r.paymentstatusobjectid = x.objectid
                           JOIN query.o_paymenttransactions opt
                               ON opt.objectid = r.paymenttransactionobjectid
                           JOIN api.feetransactions ft
                               ON ft.transactionid = opt.transactionid
                           JOIN api.fees f ON f.feeid = ft.feeid
                           JOIN query.j_application l ON l.jobid = f.jobid);

        COMMIT;

        --insert new log record.
        insertlessthanzerobalancelog;

        --perform the sync on the necessary jobs.
        FOR x IN (SELECT jobid
                    FROM sitespecific.lessthanzerobalance
                   WHERE needsprocessing = 'Y')
        LOOP
            t_amount   := NULL;
            t_ovr      := NULL;

            BEGIN
                sitespecific.pkg_reports.accountinghistoryreport(x.jobid);

                SELECT SUM(g.amount)
                  INTO t_amount
                  FROM sitespecific.accountinghistoryreport_gt g;

                IF t_amount < 0 THEN
                    sitespecific.pkg_reports.getpaytransforacchist(
                        x.jobid,
                        NULL,
                        t_ptobjectlist);

                    SELECT SUM(y.overpaymentamount)
                      INTO t_ovr
                      FROM (SELECT CASE
                                       WHEN api.pkg_columnquery.VALUE(
                                                x.objectid,
                                                'IsOverpayment') =
                                            'Y' THEN
                                           CASE
                                               WHEN api.pkg_columnquery.VALUE(
                                                        x.objectid,
                                                        'CABINAmtType') =
                                                    'V' THEN
                                                   0
                                               ELSE
                                                   ft.amount * -1
                                           END
                                       ELSE
                                           0
                                   END
                                       overpaymentamount
                              FROM TABLE(t_ptobjectlist)  x
                                   JOIN query.o_paymenttransactions qpt
                                       ON qpt.objectid = x.objectid
                                   JOIN api.feetransactions ft
                                       ON ft.transactionid =
                                          qpt.transactionid
                            UNION
                            SELECT CASE
                                       WHEN api.pkg_columnquery.VALUE(
                                                x.objectid,
                                                'IsOverpayment') =
                                            'Y' THEN
                                           api.pkg_columnquery.numericvalue(
                                               r.paymentstatusobjectid,
                                               'EarnedAmount')
                                       ELSE
                                           0
                                   END
                                       overpaymentamount
                              FROM TABLE(t_ptobjectlist)  x
                                   JOIN query.r_paymentstatuspaymenttrans r
                                       ON r.paymenttransactionobjectid =
                                          x.objectid) y;
                END IF;

                UPDATE sitespecific.lessthanzerobalance
                   SET balance           = t_amount,
                       ovr               = t_ovr,
                       lastupdated       = SYSDATE,
                       errormsg          = NULL,
                       needsprocessing   = 'N'
                 WHERE jobid = x.jobid;
            EXCEPTION
                WHEN OTHERS THEN
                    err_msg   := SQLERRM;

                    UPDATE sitespecific.lessthanzerobalance
                       SET lastupdated = SYSDATE, errormsg = err_msg
                     WHERE jobid = x.jobid;
            END;

            COMMIT;
        END LOOP;
    END synclessthanzerobalance;
END pkg_schedule;
/


GRANT EXECUTE ON SITESPECIFIC.PKG_SCHEDULE TO POSSEEXTENSIONS;
