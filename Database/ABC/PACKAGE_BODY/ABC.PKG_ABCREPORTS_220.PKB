CREATE OR REPLACE PACKAGE BODY ABC.pkg_abcreports_220
IS
    -- **************************************************************************
    -- File:        PKG_ABCREPORTS_220.PKB
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
    -- 07/27/2020 TJL  22224  Modified logic to allow LR reports without an office
    --                          being required.
    -- **************************************************************************

    PROCEDURE abc220assignmentoverview(a_objectid udt_id)
    IS
        t_investigatorlr      VARCHAR2(60);
        t_userid              udt_id;
        t_createddatefrom     DATE;
        t_createddateto       DATE;
        t_completeddatefrom   DATE;
        t_completeddateto     DATE;
        t_licensenumber       VARCHAR2(40);
        t_districtoffice      VARCHAR2(1000);
        t_officenamefmt       VARCHAR2(1000);
        t_officefmt           VARCHAR2(1000);
        t_licensee            VARCHAR2(1000);
        t_activeonly          CHAR(1);
        t_sql1                VARCHAR2(4000);
        t_sql2                VARCHAR2(4000);
        t_tmp                 VARCHAR2(4000);
        t_emp                 VARCHAR2(1000);
        t_fromdate            DATE;
        t_thrudate            DATE;
        t_result              VARCHAR2(1000);
        t_comments            VARCHAR2(1000);
        t_plicensee           VARCHAR2(1000);
        t_licnum              VARCHAR2(40);
        t_statustype          VARCHAR2(1);
        t_assignjobids        api.udt_objectlist DEFAULT api.udt_objectlist();
        t_appjobids           api.udt_objectlist DEFAULT api.udt_objectlist();
        t_cmpl220jobids       api.udt_objectlist DEFAULT api.udt_objectlist();
        t_p_applid            api.udt_objectlist DEFAULT api.udt_objectlist(); --xxxxxxxxxx
    BEGIN
        --
        DELETE abc.abc220log_t;

        BEGIN
            SELECT o.investigatorlr,
                   r.userid,
                   o.createddatefrom,
                   o.createddateto,
                   o.completeddatefrom,
                   o.completeddateto,
                   o.licensenumber,
                   o.districtoffice,
                   o.licensee,
                   o.activeonly
              INTO t_investigatorlr,
                   t_userid,
                   t_createddatefrom,
                   t_createddateto,
                   t_completeddatefrom,
                   t_completeddateto,
                   t_licensenumber,
                   t_districtoffice,
                   t_licensee,
                   t_activeonly
              FROM query.o_abc220assignmentoverview  o
                   LEFT OUTER JOIN query.r_abc220ao_investigatorlr r
                       ON r.abc220ao_objectid = o.objectid
             WHERE o.objectid = a_objectid;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                api.pkg_errors.raiseerror(
                    -20000,
                    'Invalid Object Id, not found in query.o_abc220assignmentoverview');
        END;

        IF t_activeonly = 'Y'
       AND (t_completeddatefrom IS NOT NULL
         OR t_completeddateto IS NOT NULL) THEN
            GOTO end220report;
        END IF;

        -- ********************************************************************
        -- 07/27/2020 TJL  22224 change logic flow
        IF t_districtoffice IS NOT NULL THEN
            getoffice(t_districtoffice, t_officenamefmt, t_officefmt);

            IF t_districtoffice IS NULL THEN
                GOTO end220report;
            END IF;

            get220appjoblist(t_createddatefrom,
                             t_createddateto,
                             t_officefmt,
                             t_licensenumber,
                             t_licensee,
                             t_appjobids,
                             t_p_applid                                --xxxxxxxxx
                                       );

            IF t_appjobids.COUNT = 0 THEN
                GOTO end220report;
            END IF;
        END IF;

        IF t_investigatorlr IS NOT NULL THEN
            getuserassignments(t_investigatorlr,
                               t_officenamefmt,
                               t_officefmt,
                               t_assignjobids);

            IF t_assignjobids.COUNT = 0 THEN
                GOTO end220report;
            END IF;

            IF t_appjobids.COUNT != 0 THEN
                extension.pkg_collectionutils.join(t_appjobids, t_assignjobids);
            else
                t_appjobids := t_assignjobids;
            END IF;
        END IF;
        -- End of logic changes
        -- ********************************************************************

        IF t_appjobids.COUNT = 0 THEN
            GOTO end220report;
        END IF;

        IF t_completeddatefrom IS NOT NULL
        OR t_completeddateto IS NOT NULL THEN
            getdistrevlist(t_completeddatefrom,
                           t_completeddateto,
                           t_cmpl220jobids);

            IF t_cmpl220jobids.COUNT = 0 THEN
                GOTO end220report;
            END IF;

            extension.pkg_collectionutils.join(t_appjobids, t_cmpl220jobids);
        END IF;

        IF t_activeonly = 'Y' THEN
            getactivelist(t_appjobids);

            IF t_appjobids.COUNT = 0 THEN
                GOTO end220report;
            END IF;
        END IF;

        FOR i IN 1 .. t_appjobids.COUNT
        LOOP
            getassignedemp(t_appjobids(i).objectid, t_emp);
            t_thrudate   := getthrudate(t_appjobids(i).objectid);
            t_result     := get220result(t_appjobids(i).objectid);

            BEGIN
                SELECT statustype
                  INTO t_statustype
                  FROM api.jobstatuses  js
                       JOIN api.jobs a ON js.statusid = a.statusid
                 WHERE js.jobtypeid =
                       api.pkg_configquery.objectdefidforname(
                           'j_Application')
                   AND a.jobid = t_appjobids(i).objectid;
            END;

            BEGIN
                ---select j.createddate, j.LicenseNumber, dup_PrimaryLicensee,
                --12/17/2012 Changed Created date to Enter application date -- PK

                SELECT j.enterapplicationcompleteddate,
                       j.licensenumber,
                       dup_primarylicensee,
                       CASE
                           WHEN t_statustype = 'C'
                            AND t_thrudate IS NULL THEN
                               j.completeddate
                           ELSE
                               t_thrudate
                       END
                           thrudate,
                       CASE
                           WHEN t_statustype = 'C'
                            AND t_result IS NULL THEN
                               j.statusdescription
                           ELSE
                               t_result
                       END
                           result
                  INTO t_fromdate,
                       t_licnum,
                       t_plicensee,
                       t_thrudate,
                       t_result
                  FROM query.j_application j
                 WHERE j.jobid = t_appjobids(i).objectid;
            EXCEPTION
                WHEN OTHERS THEN
                    t_fromdate    := NULL;
                    t_licnum      := NULL;
                    t_plicensee   := NULL;
            END;

            BEGIN
                SELECT pr.comments comments
                  INTO t_comments
                  FROM query.p_conductappinvestigation pr
                 WHERE pr.jobid = t_assignjobids(i).objectid;
            EXCEPTION
                WHEN OTHERS THEN
                    t_comments   := NULL;
            END;

            IF t_activeonly = 'Y'
           AND t_thrudate IS NOT NULL THEN
                NULL;
            ELSE
                INSERT INTO abc.abc220log_t(from_date,
                                            thru_date,
                                            emp,
                                            result,
                                            active,
                                            licensee,
                                            comments,
                                            objectid,
                                            licnum)
                     VALUES (t_fromdate,
                             t_thrudate,
                             t_emp,
                             t_result,
                             DECODE(t_thrudate, NULL, 'Y', 'N'),
                             t_plicensee,
                             t_comments,
                             t_appjobids(i).objectid,
                             t_licnum);
            END IF;
        END LOOP;

       <<end220report>>
        NULL;
    END abc220assignmentoverview;

    PROCEDURE getoffice(a_districtoffice   VARCHAR2,
                        a_officename   OUT VARCHAR2,
                        a_office       OUT VARCHAR2)
    IS
        t_tmpoffice   VARCHAR2(1000)
                          := RTRIM(LTRIM(UPPER(a_districtoffice), '%'), '%');
        t_tmpofccd    VARCHAR2(2);
        t_strchk      NUMBER;
        t_objectid    udt_id;
    BEGIN
        --
        BEGIN
            SELECT REGEXP_INSTR(UPPER(a_districtoffice), '[A-Z0-9]')
              INTO t_strchk
              FROM DUAL;

            IF t_strchk = 0 THEN
                GOTO endgetoffice;
            END IF;
        EXCEPTION
            WHEN OTHERS THEN
                GOTO endgetoffice;
        END;

        BEGIN
            SELECT objectid
              INTO t_objectid
              FROM (SELECT objectid
                      FROM TABLE(
                               CAST(
                                   api.pkg_simplesearch.castableobjectsbyindex(
                                       'o_Office',
                                       'OfficeCode',
                                       t_tmpoffice) AS api.udt_objectlist))
                    UNION ALL
                    SELECT objectid
                      FROM TABLE(
                               CAST(
                                   api.pkg_simplesearch.castableobjectsbyindex(
                                       'o_Office',
                                       'OfficeName',
                                       t_tmpoffice) AS api.udt_objectlist))
                    UNION ALL
                    SELECT objectid
                      FROM TABLE(
                               CAST(
                                   api.pkg_simplesearch.castableobjectsbyindex(
                                       'o_Office',
                                       'dup_Office',
                                       t_tmpoffice) AS api.udt_objectlist)));

            --
            IF t_objectid IS NOT NULL THEN
                GOTO endgetoffice;
            END IF;
        EXCEPTION
            WHEN OTHERS THEN
                NULL;
        END;

        --
        BEGIN
            IF INSTR(a_districtoffice, '%') = 0 THEN
                t_tmpoffice   := '%' || UPPER(a_districtoffice) || '%';
            ELSE
                t_tmpoffice   := UPPER(a_districtoffice);
            END IF;

            SELECT objectid
              INTO t_objectid
              FROM query.o_office ofc
             WHERE dup_office LIKE UPPER(t_tmpoffice);
        EXCEPTION
            WHEN OTHERS THEN
                NULL;
        END;

        IF t_objectid IS NOT NULL THEN
            GOTO endgetoffice;
        END IF;

        --
        t_tmpofccd     :=
            TO_CHAR(REGEXP_REPLACE(a_districtoffice, '[^(0-9)]', ''));
        t_tmpoffice    :=
            TRIM(REGEXP_REPLACE(UPPER(a_districtoffice), '[^A-Z ]', ' '));

        --
        FOR x
            IN (SELECT objectid,
                       officecode,
                       officename,
                       officenameabbreviation,
                       TRIM(REGEXP_REPLACE(officename, '[^A-Z ]', ' '))
                           officename2
                  FROM query.o_office ofc)
        LOOP
            IF (t_tmpofccd = x.officecode
             OR t_tmpofccd IS NULL)
           AND (t_tmpoffice IS NULL
             OR t_tmpoffice = x.officenameabbreviation
             OR x.officename2 = t_tmpoffice
             OR x.officename2 LIKE '%' || t_tmpoffice || '%') THEN
                t_objectid   := x.objectid;
                GOTO endgetoffice;
            END IF;
        END LOOP;

       <<endgetoffice>>
        a_officename   := api.pkg_columnquery.VALUE(t_objectid, 'OfficeName');
        a_office       := api.pkg_columnquery.VALUE(t_objectid, 'Office');
    END getoffice;

    FUNCTION get220result(a_objectid udt_id)
        RETURN api.processes.outcome%TYPE
    IS
        t_outcome   api.processes.outcome%TYPE := NULL;
    BEGIN
        BEGIN
            FOR x
                IN (  SELECT p.processid,
                             api.pkg_columnquery.VALUE(p.processid, 'Outcome')
                                 outcome
                        FROM api.processes p
                       WHERE p.processtypeid IN
                                 (api.pkg_configquery.objectdefidforname(
                                      'p_IssueLicense'),
                                  api.pkg_configquery.objectdefidforname(
                                      'p_WithdrawApplication'),
                                  api.pkg_configquery.objectdefidforname(
                                      'p_DistrictApplicationReview'),
                                  api.pkg_configquery.objectdefidforname(
                                      'p_DivisionAppModReview'),
                                  api.pkg_configquery.objectdefidforname(
                                      'p_ConductAppInvestigation'))
                         AND p.jobid = a_objectid
                    ORDER BY p.processid DESC)
            LOOP
                IF x.outcome IS NOT NULL THEN
                    t_outcome   := x.outcome;
                    GOTO return_outcome;
                END IF;
            END LOOP;
        EXCEPTION
            WHEN OTHERS THEN
                NULL;
        END;

       <<return_outcome>>
        RETURN t_outcome;
    END get220result;

    PROCEDURE get220appjoblist(a_createddatefrom  DATE,
                               a_createddateto    DATE,
                               a_districtoffice   VARCHAR2,
                               a_licensenumber    VARCHAR2,
                               a_licensee         VARCHAR2,
                               a_appjoblist   OUT api.udt_objectlist,
                               a_projoblist   OUT api.udt_objectlist --xxxxxxxxx
                                                                    )
    IS
        t_appjobids         api.udt_objectlist;
        t_projobids         api.udt_objectlist;                    --xxxxxxxxx
        t_condctappjobids   api.udt_objectlist;
    BEGIN
        t_appjobids         := api.udt_objectlist();
        t_projobids         := api.udt_objectlist();               --xxxxxxxxx
        t_condctappjobids   := api.udt_objectlist();

        IF a_createddatefrom IS NOT NULL THEN                 --xxxxxxxxxxxxxx
            extension.pkg_cxproceduralsearch.initializesearch(
                'j_Application');
            -- extension.pkg_cxproceduralsearch.SearchBySystemColumn('CreatedDate', a_CreatedDateFrom, a_CreatedDateTo+1);
            -- replaced by enter application complete date -- 12/19/2012 --PK
            --  extension.pkg_cxproceduralsearch.SearchBySystemColumn('EnterApplicationCompletedDate', a_CreatedDateFrom, a_CreatedDateTo+1);
            extension.pkg_cxproceduralsearch.searchbyindex(
                'dup_LicenseNumber',
                a_licensenumber,
                NULL,
                TRUE);
            extension.pkg_cxproceduralsearch.searchbyindex(
                'dup_PrimaryLicensee',
                a_licensee,
                NULL,
                TRUE);
            extension.pkg_cxproceduralsearch.searchbyindex(
                'dup_BaseFileOfficeCorral',
                a_districtoffice,
                NULL,
                TRUE);
            extension.pkg_cxproceduralsearch.performsearch(t_appjobids,
                                                           'and',
                                                           'or');

            extension.pkg_cxproceduralsearch.initializesearch(
                'p_EnterApplication');
            extension.pkg_cxproceduralsearch.searchbysystemcolumn(
                'CreatedDate',
                a_createddatefrom,
                a_createddateto + 1);
            extension.pkg_cxproceduralsearch.performsearch(t_projobids,
                                                           'and',
                                                           'or');

            BEGIN
                SELECT api.udt_object(a.jobid)
                  BULK COLLECT INTO a_appjoblist
                  FROM api.jobs  a
                       JOIN api.jobstatuses js
                           ON js.jobtypeid = a.jobtypeid
                          AND js.statusid = a.statusid
                 WHERE a.jobid IN (SELECT * FROM TABLE(t_appjobids))
                   AND js.statustype <> 'X';

                t_appjobids   := a_appjoblist;
                a_appjoblist.delete;
            END;

            BEGIN
                SELECT api.udt_object(p.jobid)
                  BULK COLLECT INTO a_projoblist
                  FROM api.processes  p
                       JOIN api.jobs a ON p.jobid = a.jobid
                       JOIN api.jobstatuses js
                           ON js.jobtypeid = a.jobtypeid
                          AND js.statusid = a.statusid
                 WHERE p.processid IN (SELECT * FROM TABLE(t_projobids))
                   -- and P.PROCESSTYPEID = api.pkg_configquery.ObjectDefIdForName('p_EnterApplication')
                   AND js.statustype <> 'X';

                --    t_AppJobids := a_AppJobList;
                --    a_AppJobList.delete;
                t_projobids   := a_projoblist;
                a_projoblist.delete;
            END;

            extension.pkg_collectionutils.join(t_appjobids, t_projobids);
        ELSE                                                  ---xxxxxxxxxxxxx
            extension.pkg_cxproceduralsearch.initializesearch(
                'j_Application');
            extension.pkg_cxproceduralsearch.searchbysystemcolumn(
                'CreatedDate',
                a_createddatefrom,
                a_createddateto + 1);
            extension.pkg_cxproceduralsearch.searchbyindex(
                'dup_LicenseNumber',
                a_licensenumber,
                NULL,
                TRUE);
            extension.pkg_cxproceduralsearch.searchbyindex(
                'dup_PrimaryLicensee',
                a_licensee,
                NULL,
                TRUE);
            extension.pkg_cxproceduralsearch.searchbyindex(
                'dup_BaseFileOfficeCorral',
                a_districtoffice,
                NULL,
                TRUE);
            extension.pkg_cxproceduralsearch.performsearch(t_appjobids,
                                                           'and',
                                                           'or');

            /*
            extension.pkg_cxproceduralsearch.InitializeSearch('p_EnterApplication');
            extension.pkg_cxproceduralsearch.SearchBySystemColumn('CreatedDate', a_CreatedDateFrom, a_CreatedDateTo+1);
            extension.pkg_cxproceduralsearch.PerformSearch(t_ProJobids, 'and', 'or'); */

            BEGIN
                SELECT api.udt_object(a.jobid)
                  BULK COLLECT INTO a_appjoblist
                  FROM api.jobs  a
                       JOIN api.jobstatuses js
                           ON js.jobtypeid = a.jobtypeid
                          AND js.statusid = a.statusid
                 WHERE a.jobid IN (SELECT * FROM TABLE(t_appjobids))
                   AND js.statustype <> 'X';

                t_appjobids   := a_appjoblist;
                a_appjoblist.delete;
            END;
        /*
       begin
             select api.udt_object(p.jobid)
             bulk collect into a_ProJobList
             from API.PROCESSES p
             join api.jobs a on P.JOBID = A.JOBID
            join api.jobstatuses js on js.JobTypeId = a.jobtypeid
              and js.StatusId = a.StatusId
             where P.processid in (select * from table(t_ProJobids))
           -- and P.PROCESSTYPEID = api.pkg_configquery.ObjectDefIdForName('p_EnterApplication')
               and js.StatusType <> 'X';
             --    t_AppJobids := a_AppJobList;
             --    a_AppJobList.delete;
             t_ProJobids := a_ProJobList;
             a_ProJobList.delete;
           end;

                EXTENSION.PKG_COLLECTIONUTILS.join(t_AppJobids, t_ProJobids); */

        ---xxxxxxxx
        END IF;

        FOR i IN 1 .. t_appjobids.COUNT
        LOOP
            FOR x IN (SELECT ea.jobid
                        FROM query.p_enterapplication ea
                       WHERE ea.jobid = t_appjobids(i).objectid
                         AND ea.datecompleted IS NOT NULL)
            LOOP
                t_condctappjobids.EXTEND(1);
                t_condctappjobids(t_condctappjobids.COUNT)   :=
                    api.udt_object(x.jobid);
            END LOOP;
        END LOOP;

        a_appjoblist        := t_condctappjobids;
    END get220appjoblist;

    PROCEDURE getdistrevlist(a_completeddatefrom DATE,
                             a_completeddateto  DATE,
                             a_distrevlist  OUT api.udt_objectlist)
    IS
        t_drprocids   api.udt_objectlist;
        t_tempids     api.udt_objectlist;
    BEGIN
        t_drprocids   := api.udt_objectlist();
        t_tempids     := api.udt_objectlist();

        extension.pkg_cxproceduralsearch.initializesearch(
            'p_DistrictApplicationReview');
        extension.pkg_cxproceduralsearch.searchbysystemcolumn(
            'DateCompleted',
            a_completeddatefrom,
            a_completeddateto + 1);
        extension.pkg_cxproceduralsearch.performsearch(t_drprocids,
                                                       'and',
                                                       'or');

        IF t_drprocids.COUNT = 0 THEN
            a_distrevlist   := api.udt_objectlist();
        ELSE
            FOR i IN 1 .. t_drprocids.COUNT
            LOOP
                FOR x IN (SELECT pr.jobid
                            FROM query.p_districtapplicationreview pr
                           WHERE pr.processid = t_drprocids(i).objectid)
                LOOP
                    t_tempids.EXTEND(1);
                    t_tempids(t_tempids.COUNT)   := api.udt_object(x.jobid);
                END LOOP;
            END LOOP;

            IF t_tempids.COUNT = 0 THEN
                a_distrevlist   := api.udt_objectlist();
            ELSE
                a_distrevlist   := t_tempids;
            END IF;
        END IF;
    END getdistrevlist;

    PROCEDURE getactivelist(a_appjobids IN OUT api.udt_objectlist)
    IS
        t_count    NUMBER := 0;
        t_tmpids   api.udt_objectlist DEFAULT api.udt_objectlist();
    BEGIN
        FOR i IN 1 .. a_appjobids.COUNT
        LOOP
            BEGIN
                SELECT COUNT(1)
                  INTO t_count
                  FROM query.p_districtapplicationreview x
                 WHERE x.jobid = a_appjobids(i).objectid
                   AND x.datecompleted IS NOT NULL;
            EXCEPTION
                WHEN OTHERS THEN
                    NULL;
            END;

            IF t_count = 0 THEN
                t_tmpids.EXTEND(1);
                t_tmpids(t_tmpids.COUNT)   :=
                    api.udt_object(a_appjobids(i).objectid);
            END IF;
        END LOOP;

        a_appjobids.delete;
        a_appjobids   := t_tmpids;
        t_tmpids.delete;
    END getactivelist;


    PROCEDURE getuserassignments(a_investigatorlr   VARCHAR2,
                                 a_districtofficename VARCHAR2,
                                 a_districtoffice   VARCHAR2,
                                 a_appjoblist   OUT api.udt_objectlist)
    IS
        t_userlist    api.udt_objectlist DEFAULT api.udt_objectlist();
        t_appjobids   api.udt_objectlist DEFAULT api.udt_objectlist();
    BEGIN
        FOR x
            IN (SELECT users.userid
                  FROM query.users  users
                       JOIN
                       TABLE(
                           CAST(
                               api.pkg_simplesearch.castableobjectsbyindex(
                                   'Users',
                                   'Name',
                                   a_investigatorlr || '%') AS api.udt_objectlist))
                       search
                           ON search.objectid = users.userid)
        LOOP
            t_userlist.EXTEND(1);
            t_userlist(t_userlist.COUNT)   := api.udt_object(x.userid);
        END LOOP;

        FOR i IN 1 .. t_userlist.COUNT
        LOOP
            FOR c
                IN (SELECT p.jobid
                      FROM api.processtypes  pt
                           JOIN api.processes p
                               ON p.processtypeid = pt.processtypeid
                           JOIN api.processassignments pa
                               ON pa.processid = p.processid
                     WHERE pt.processtypeid =
                           api.pkg_configquery.objectdefidforname(
                               'p_ConductAppInvestigation')
                       AND pa.userid = t_userlist(i).objectid)
            LOOP
                t_appjobids.EXTEND(1);
                t_appjobids(t_appjobids.COUNT)   := api.udt_object(c.jobid);
            END LOOP;
        END LOOP;

        a_appjoblist   := t_appjobids;
    END getuserassignments;

    PROCEDURE getassignedemp(a_objectid udt_id, a_emp OUT VARCHAR2)
    IS
        t_emp   VARCHAR2(1000) := NULL;
    --
    BEGIN
        BEGIN
            FOR x
                IN (SELECT DISTINCT us.name
                      FROM api.processtypes  pt
                           JOIN api.processes p
                               ON p.processtypeid = pt.processtypeid
                           JOIN api.processassignments pa
                               ON pa.processid = p.processid
                           JOIN api.users us ON us.userid = pa.userid
                     WHERE pt.processtypeid =
                           api.pkg_configquery.objectdefidforname(
                               'p_ConductAppInvestigation')
                       AND p.jobid = a_objectid)
            LOOP
                IF t_emp IS NULL THEN
                    t_emp   := x.name;
                ELSE
                    t_emp   := t_emp || ' / ' || x.name;
                END IF;
            END LOOP;
        EXCEPTION
            WHEN OTHERS THEN
                t_emp   := NULL;
        END;

        a_emp   := t_emp;
    END getassignedemp;

    FUNCTION getthrudate(a_objectid udt_id)
        RETURN DATE
    IS
        t_date   DATE;
    --
    BEGIN
        BEGIN
            SELECT dar.datecompleted
              INTO t_date
              FROM query.p_districtapplicationreview dar
             WHERE dar.jobid = a_objectid;
        EXCEPTION
            WHEN TOO_MANY_ROWS THEN
                BEGIN
                    SELECT datecompleted
                      INTO t_date
                      FROM (  SELECT dar.datecompleted
                                FROM query.p_districtapplicationreview dar
                               WHERE dar.jobid = a_objectid
                            ORDER BY dar.processid DESC)
                     WHERE ROWNUM = 1;
                EXCEPTION
                    WHEN OTHERS THEN
                        t_date   := NULL;
                END;
            WHEN OTHERS THEN
                t_date   := NULL;
        END;

        RETURN t_date;
    END getthrudate;
END pkg_abcreports_220;
/


GRANT EXECUTE ON ABC.PKG_ABCREPORTS_220 TO POSSEEXTENSIONS;
