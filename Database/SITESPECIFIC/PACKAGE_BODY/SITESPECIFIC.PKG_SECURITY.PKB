CREATE OR REPLACE PACKAGE BODY SITESPECIFIC.pkg_security
IS
    -- **************************************************************************
    -- File:        PKG_SECURITY.PKB
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
    /*-------------------------------------------------------------------------------
    * Procedure AddAccessGroup()
    *   Runs on relationship between User and external object Access Groups
    *   to add the user to the access group selected
    *-----------------------------------------------------------------------------*/
    PROCEDURE addaccessgroup(a_relationshipid udt_id, a_asofdate DATE)
    IS
        t_accessgroupid   udt_id;
        t_userid          udt_id;
        t_exists          CHAR(1);
    BEGIN
        -- Get the Access Group Id and the User Id
        SELECT accessgroupid accessgroupid, toobjectid userid
          INTO t_accessgroupid, t_userid
          FROM api.relationships  re
               JOIN api.users us ON us.userid = re.toobjectid
               JOIN query.o_accessgroups ag ON ag.objectid = re.fromobjectid
         WHERE re.relationshipid = a_relationshipid;

        -- Check if the user is already in the access group
        -- In normal workflow we should get no data found here...
        BEGIN
            SELECT 'Y'
              INTO t_exists
              FROM api.accessgroupusers
             WHERE accessgroupid = t_accessgroupid
               AND userid = t_userid;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                t_exists   := 'N';
        END;

        -- Add the user to the access group
        IF t_exists = 'N' THEN
            api.pkg_userupdate.addtoaccessgroup(t_userid, t_accessgroupid);
        END IF;
    END;

    /*-------------------------------------------------------------------------------
    * Procedure RemoveAccessGroup()
    *   Runs on relationship between User and external object Access Groups
    *   to remove the user from the access group
    *-----------------------------------------------------------------------------*/
    PROCEDURE removeaccessgroup(a_relationshipid udt_id, a_asofdate DATE)
    IS
        t_accessgroupid   udt_id;
        t_userid          udt_id;
        t_exists          CHAR(1);
    BEGIN
        -- Get the Access Group Id and the User Id
        SELECT accessgroupid accessgroupid, toobjectid userid
          INTO t_accessgroupid, t_userid
          FROM api.relationships  re
               JOIN api.users us ON us.userid = re.toobjectid
               JOIN query.o_accessgroups ag ON ag.objectid = re.fromobjectid
         WHERE re.relationshipid = a_relationshipid;

        -- Check if the user is already in the access group
        BEGIN
            SELECT 'Y'
              INTO t_exists
              FROM api.accessgroupusers
             WHERE accessgroupid = t_accessgroupid
               AND userid = t_userid;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                t_exists   := 'N';
        END;

        -- Add the user to the access group
        IF t_exists = 'Y' THEN
            api.pkg_userupdate.removefromaccessgroup(t_userid,
                                                     t_accessgroupid);
        END IF;
    END;

    ----------------------------------------------------------------------------------------------------
    --  AssignByAccessGroup() -- PUBLIC
    --  This will assign any users that are in the access group specified in the Assign By Access Group
    --  detail and is also related to the Accusation Office
    ----------------------------------------------------------------------------------------------------
    PROCEDURE assignbyaccessgroup(a_objectid      udt_id,
                                  a_asofdate      DATE,
                                  a_jobid         udt_id)
    IS
        t_accessgroupid         udt_id;
        t_officeobjid           udt_id;
        t_officetype            VARCHAR2(100);
        t_jobname               VARCHAR2(100);
        t_processname           VARCHAR2(50);
        t_createdbyaccid        udt_id;
        t_division              VARCHAR2(100);
        t_assignbyaccessgroup   VARCHAR2(100);
        t_divisionofficeid      udt_id;
        t_jobstatustag          VARCHAR2(6);
    BEGIN
        BEGIN
            SELECT jt.name, s.tag
              INTO t_jobname, t_jobstatustag
              FROM api.jobtypes  jt
                   JOIN api.jobs j
                       ON j.jobid = a_jobid
                      AND j.jobtypeid = jt.jobtypeid
                   JOIN api.statuses s ON s.statusid = j.statusid;

            IF t_jobname = 'j_Application'
           AND t_jobstatustag = 'NEW' THEN
                t_officetype   := 'IntakeOfficeId';
            ELSIF t_jobname = 'j_Application' THEN
                t_officetype   := 'BaseFileOfficeId';
            ELSIF t_jobname = 'j_Accusation' THEN
                t_officetype   := 'OfficeId';
            ELSIF t_jobname = 'j_License' THEN
                t_officetype   := 'BaseFileOfficeId';
            ELSIF t_jobname = 'j_Investigation' THEN
                t_officetype   := 'InvestigationOfficeObjectId';
            ELSE
                t_officetype   := 'OfficeId';
            END IF;

            t_officeobjid   :=
                api.pkg_columnquery.VALUE(a_jobid, t_officetype);
        END;

        --Get the Object Def Name of the process
        t_processname   :=
            api.pkg_columnquery.VALUE(a_objectid, 'ObjectDefName');

        --Get the Access Group Description that this process will be assigned to
        t_assignbyaccessgroup   :=
            api.pkg_columnquery.VALUE(a_objectid, 'AssignByAccessGroup');

        BEGIN
            SELECT i.accusationjobid
              INTO t_createdbyaccid
              FROM query.r_investigationcreatedbyacc i
             WHERE i.investigationjobid = a_jobid;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                t_createdbyaccid   := NULL; --api.pkg_errors.RaiseError('-20000', 'Cannot find the Created By Accusation Id on '||a_JobId);
        END;

        -- Get the Access group Id
        BEGIN
            SELECT accessgroupid
              INTO t_accessgroupid
              FROM api.accessgroups
             WHERE description = t_assignbyaccessgroup;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                api.pkg_errors.raiseerror(
                    -20000,
                    'Problem with Assign Access Group detail on process.');
        END;

        --Get the division type from the Office on the job
        t_division   := api.pkg_columnquery.VALUE(t_officeobjid, 'Division');

        -- Assign to all members of specified access group in office to the process
        IF t_assignbyaccessgroup = 'Division'
       AND t_division IS NOT NULL THEN
            --Get the OfficeObjectId from the Division Office
            BEGIN
                SELECT o.objectid
                  INTO t_divisionofficeid
                  FROM TABLE(
                           CAST(
                               api.pkg_simplesearch.castableobjectsbyindex(
                                   'o_Office',
                                   'OfficeName',
                                   UPPER(t_division) || ' DIVISION') AS api.udt_objectlist))
                       o;
            EXCEPTION
                WHEN TOO_MANY_ROWS THEN
                    api.pkg_errors.raiseerror(
                        -20000,
                           'There cannot be more than one Division office identified as '
                        || UPPER(t_division)
                        || ' DIVISION');
                WHEN NO_DATA_FOUND THEN
                    api.pkg_errors.raiseerror(
                        -20000,
                           'There must be one Division office identified as '
                        || UPPER(t_division)
                        || ' DIVISION');
            END;

            FOR c
                IN (SELECT u.oraclelogonid
                      FROM api.relationships  r1
                           JOIN api.users u ON u.userid = r1.toobjectid
                           JOIN api.accessgroupusers ag
                               ON ag.userid = r1.toobjectid
                     WHERE r1.endpointid =
                           api.pkg_configquery.endpointidforname('o_Office',
                                                                 'User')
                       AND r1.fromobjectid = t_divisionofficeid
                       AND ag.accessgroupid = t_accessgroupid
                       AND u.active = 'Y')
            LOOP
                api.pkg_processupdate.assign(a_objectid, c.oraclelogonid);
            END LOOP;
        ELSE
            IF t_processname != 'p_AssignInvestigation'
            OR (t_processname = 'p_AssignInvestigation'
            AND t_createdbyaccid IS NOT NULL) THEN
                FOR c
                    IN (SELECT u.oraclelogonid
                          FROM api.relationships  r1
                               JOIN api.users u ON u.userid = r1.toobjectid
                               JOIN api.accessgroupusers ag
                                   ON ag.userid = r1.toobjectid
                         WHERE r1.endpointid =
                               api.pkg_configquery.endpointidforname(
                                   'o_Office',
                                   'User')
                           AND r1.fromobjectid = t_officeobjid
                           AND ag.accessgroupid = t_accessgroupid
                           AND u.active = 'Y')
                LOOP
                    api.pkg_processupdate.assign(a_objectid, c.oraclelogonid);
                END LOOP;
            END IF;
        END IF;
    END assignbyaccessgroup;

    /*---------------------------------------------------------------------------
    * AddOfficeAccessGroup() -- PUBLIC
    *-------------------------------------------------------------------------*/
    PROCEDURE addofficeaccessgroup(g_object udt_id, a_asofdate DATE)
    IS
        t_userobjectid            udt_id;
        t_accessgroupid           udt_id;
        t_existingaccessgroupid   udt_id;
    BEGIN
        SELECT o.userobjectid
          INTO t_userobjectid
          FROM query.r_usersecondaryoffice o
         WHERE o.relationshipid = g_object;

        SELECT a.accessgroupid
          INTO t_accessgroupid
          FROM api.accessgroups a
         WHERE a.description = (api.pkg_columnquery.VALUE(
                                    (SELECT o.officeobjectid
                                       FROM query.r_usersecondaryoffice o
                                      WHERE o.relationshipid = g_object),
                                    'OfficeName'));

        BEGIN
            SELECT au.accessgroupid
              INTO t_existingaccessgroupid
              FROM api.users  u
                   JOIN api.accessgroupusers au ON au.userid = u.userid
             WHERE au.accessgroupid = t_accessgroupid
               AND u.userid = t_userobjectid;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                api.pkg_userupdate.addtoaccessgroup(t_userobjectid,
                                                    t_accessgroupid);
        END;
    END addofficeaccessgroup;

    /*---------------------------------------------------------------------------
    * RemoveOfficeAccessGroup() -- PUBLIC
    *-------------------------------------------------------------------------*/
    PROCEDURE removeofficeaccessgroup(g_object udt_id, a_asofdate DATE)
    IS
        t_userobjectid    udt_id;
        t_accessgroupid   udt_id;
    BEGIN
        SELECT o.userobjectid
          INTO t_userobjectid
          FROM query.r_usersecondaryoffice o
         WHERE o.relationshipid = g_object;

        SELECT a.accessgroupid
          INTO t_accessgroupid
          FROM api.accessgroups a
         WHERE a.description = api.pkg_columnquery.VALUE(
                                   (SELECT o.officeobjectid
                                      FROM query.r_usersecondaryoffice o
                                     WHERE o.relationshipid = g_object),
                                   'OfficeName');

        api.pkg_userupdate.removefromaccessgroup(t_userobjectid,
                                                 t_accessgroupid);
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            NULL;
    END removeofficeaccessgroup;

    /*---------------------------------------------------------------------------
     * InactiveUser() -- PUBLIC
     *-------------------------------------------------------------------------*/
    PROCEDURE inactiveuser(a_objectid      udt_id,
                           a_asofdate      DATE,
                           a_active        VARCHAR2)
    IS
        t_userobjectid   udt_id;
    BEGIN
        IF a_active = 'N' THEN
            FOR c
                IN (SELECT a.*
                      FROM api.users  u
                           JOIN api.accessgroupusers au
                               ON au.userid = u.userid
                           JOIN api.accessgroups a
                               ON a.accessgroupid = au.accessgroupid
                     WHERE u.userid = a_objectid
                       AND a.description NOT IN ('Public', 'Read Only')
                       AND a.description IN ('Super Users',
                                             'District',
                                             'Supervisor',
                                             'Investigator',
                                             'Hearing ',
                                             'Division',
                                             'Legal',
                                             'Executive',
                                             'HQ Licensing',
                                             'Applicant',
                                             'Licensing Representative',
                                             'HQ Accounting'))
            LOOP
                api.pkg_userupdate.removefromaccessgroup(a_objectid,
                                                         c.accessgroupid);
            END LOOP;
        END IF;
    END inactiveuser;
END;
/
