CREATE OR REPLACE PACKAGE BODY ABC.pkg_abcreports
IS
    -- **************************************************************************
    -- File:        PKG_ABCREPORTS.PKB
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

    PROCEDURE abc229bulk(a_objectid udt_id)
    IS
        t_createddatefrom     DATE;
        t_createddateto       DATE;
        t_completeddatefrom   DATE;
        t_completeddateto     DATE;
        t_activeonly          CHAR(1);
        t_commentsdate        DATE;
        t_investigatorlr      VARCHAR2(60);
        t_userid              udt_id;
    BEGIN
        BEGIN
            SELECT o.createddatefrom,
                   o.createddateto,
                   o.completeddatefrom,
                   o.completeddateto,
                   o.activeonly,
                   o.commentsdate,
                   o.investigatorlr,
                   r.userid
              INTO t_createddatefrom,
                   t_createddateto,
                   t_completeddatefrom,
                   t_completeddateto,
                   t_activeonly,
                   t_commentsdate,
                   t_investigatorlr,
                   t_userid
              FROM query.o_abc229bulk  o
                   LEFT OUTER JOIN query.r_abc229bulkinvestigatorlr r
                       ON r.abc229bulkobjectid = o.objectid
             WHERE o.objectid = a_objectid;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                api.pkg_errors.raiseerror(-20000, '');
        END;
    /*
      --Sample SQL--
      Select a.Jobid
        from query.j_Application a
        join query.p_assignappinvestigation aai on aai.JobId = a.jobid
        join query.p_conductappinvestigation cai on cai.Jobid = a.JobId
        left outer Join query.r_ApplicationInvestigationLog ail on ail.ApplicationJobId = a.JobId
        left outer Join query.l_lruserlog il on il.ObjectId = ail.InvestigationUserLogId
       where ((trunc(aai.CreatedDate) between :t_CreatedDateFrom
                               and nvl(t_CreateddateTo, sysdate)) or t_CreatedDateFrom is null)
         and (((trunc(cai.DateCompleted) between t_CompletedDateFrom
                                 and nvl(t_CompletedDateTo, sysdate)) or t_CompletedDateFrom is null and cai.DateCompleted is not null)
          or (t_ActiveOnly = 'N' and cai.createddate is not null and cai.DateCompleted is null))
         and (trunc(il.LogDate) between t_CommentsDate and t_CommentsDate
          or t_CommentsDate is null)
        and (aai.LicensingRep = t_LicensingRep or t_LicensingRep is null)
    */


    --delete ABC229Bulk_gt;
    --commit;
    --insert into ABC229Bulk_gt ()
    --select
    END abc229bulk;

    PROCEDURE abc220assignmentoverview(a_objectid udt_id)
    IS
        t_investigatorlr      VARCHAR2(60);
        t_userid              udt_id;
        t_createddatefrom     DATE;
        t_createddateto       DATE;
        t_completeddatefrom   DATE;
        t_completeddateto     DATE;
        t_licensenumber       VARCHAR2(6);
        t_districtoffice      VARCHAR2(60);
        t_licensee            VARCHAR2(100);
        t_activeonly          CHAR(1);
        t_appjobids           api.udt_objectlist DEFAULT api.udt_objectlist();
    BEGIN
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
                api.pkg_errors.raiseerror(-20000, '');
        END;

        extension.pkg_cxproceduralsearch.initializesearch('j_Application');
        extension.pkg_cxproceduralsearch.searchbyindex('dup_LicenseNumber',
                                                       t_licensenumber,
                                                       NULL,
                                                       TRUE);
        extension.pkg_cxproceduralsearch.searchbyindex(
            'dup_BaseFileOfficeCorral',
            t_districtoffice,
            NULL,
            TRUE);
        extension.pkg_cxproceduralsearch.searchbyindex(
            'dup_PrimaryLicenseeSearch',
            t_licensee,
            NULL,
            TRUE);
        extension.pkg_cxproceduralsearch.performsearch(t_appjobids,
                                                       'and',
                                                       'or');

        FOR c IN 1 .. t_appjobids.COUNT
        LOOP                    -- for testing purposes only remove once done.
            dbms_output.put_line(t_appjobids(c).objectid);
        END LOOP;
    /*
    NOTE: If the above criterea is not entered in the search object then t_ObjectIds will be
    null and the SQL that is written will have to search everything. But if there are values
    entered above then the SQL will just need to limit the object ids further.
    */

    /*
    -- SQL Criteria, Conduct Application Investigation
      Investigator/LR, CreatedDate, DateCompleted, Active Only
    --Sample SQL--
     join query.p_conductappinvestigation cai on cai.Jobid = c.appjobid
    where cai.investigator/LR = t_investigator
      and cai.CreatedDate between t_CreateddateFrom and t_CreatedDateTo
      and (cai.DateCompleted between...
       or t_ActiveOnly = 'N' and Createddate is not null)
    */


    --delete ABC61AssignmentOverview_gt;
    --commit;
    --insert into ABC61AssignmentOverview_gt ()
    --select
    END abc220assignmentoverview;

    PROCEDURE abc61batchmultiprint(a_objectid udt_id)
    IS
        t_takenon                DATE;
        t_supervisorassignedon   DATE;
        t_commentsdate           DATE;
        t_activeonly             CHAR(1);
        t_investigationtype      VARCHAR2(50);
        t_investigator           VARCHAR2(60);
        t_userid                 udt_id;
        t_objectids              api.udt_objectlist
                                     DEFAULT api.udt_objectlist();
    BEGIN
        BEGIN
            SELECT o.takenon,
                   o.supervisorassignedon,
                   o.commentsdate,
                   o.activeonly,
                   o.investigationtype,
                   o.investigator,
                   r.userid
              INTO t_takenon,
                   t_supervisorassignedon,
                   t_commentsdate,
                   t_activeonly,
                   t_investigationtype,
                   t_investigator,
                   t_userid
              FROM query.o_abc61batchmultiprint  o
                   LEFT OUTER JOIN query.r_abc61batchinvestigatorlr r
                       ON r.abc61batchobjectid = o.objectid
             WHERE o.objectid = a_objectid;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                api.pkg_errors.raiseerror(-20000, '');
        END;

        IF t_investigator IS NOT NULL THEN
            t_investigator   := '%' || t_investigator;
        END IF;

        extension.pkg_cxproceduralsearch.initializesearch('j_Investigation');
        extension.pkg_cxproceduralsearch.searchbyjob(NULL,
                                                     NULL,
                                                     NULL,
                                                     NULL,
                                                     t_takenon,
                                                     t_takenon,
                                                     NULL,
                                                     NULL,
                                                     NULL,
                                                     NULL);
        extension.pkg_cxproceduralsearch.searchbyindex('InvestigationType',
                                                       t_investigationtype,
                                                       NULL,
                                                       FALSE);
        extension.pkg_cxproceduralsearch.searchbyindex('dup_Investigators',
                                                       t_investigator,
                                                       NULL,
                                                       TRUE);
        extension.pkg_cxproceduralsearch.performsearch(t_objectids,
                                                       'and',
                                                       'none');

        IF t_investigationtype IS NULL THEN
            extension.pkg_cxproceduralsearch.initializesearch(
                'p_ConductAdminInvestigation');
            extension.pkg_cxproceduralsearch.searchbyindex(
                'dup_LicensingRepresentative',
                t_investigator,
                NULL,
                FALSE);
            extension.pkg_cxproceduralsearch.performsearch(t_objectids,
                                                           'and',
                                                           'or');

            extension.pkg_cxproceduralsearch.initializesearch(
                'p_ConductLicenseInvestigation');
            extension.pkg_cxproceduralsearch.searchbyindex(
                'dup_LicensingRepresentative',
                t_investigator,
                NULL,
                FALSE);
            extension.pkg_cxproceduralsearch.performsearch(t_objectids,
                                                           'and',
                                                           'or');
        END IF;

        /*
      NOTE: If the above criterea is not entered in the search object then t_ObjectIds will be
      null and the SQL that is written will have to search everything. But if there are values
      entered above then the SQL will just need to limit the object ids further.
      */

        /*
        -- SQL Criteria, Assign Enforcement investigation
          CompletedDate
        -- SQL Criteria, Assign Admin Investigation
          CreatedDate, DateCompleted
        -- SQL Criteria, Assign License Investigation
          CreatedDate, DateCompleted
        -- SQL Criteria, Investigation Job
          CommentsDate
        -- SQL Criteria, Conduct License Investigation
          CommentsDate, ActiveOnly
        -- SQL Criteria, Conduct Admin Investigation
          CommentsDate, ActiveOnly
        -- SQL Criteria, Conduct Enforcement Investigation
          ActiveOnly
        */

        FOR c IN 1 .. t_objectids.COUNT
        LOOP                    -- for testing purposes only remove once done.
            dbms_output.put_line(t_objectids(c).objectid);
        END LOOP;
    --delete ABC61BatchMultiPrint_gt;
    --commit;
    --insert into ABC61BatchMultiPrint_gt ()
    --select
    END abc61batchmultiprint;

    PROCEDURE abc61assignmentoverview(a_objectid udt_id)
    IS
        t_investigationnumber      VARCHAR2(15);
        t_investigationtype        VARCHAR2(60);
        t_investigator             VARCHAR2(60);
        t_includecrewassignments   CHAR(1);
        t_firstvisitdate           DATE;
        t_activeonly               CHAR(1);
        t_licensenumber            VARCHAR2(6);
        t_departmentpriority       CHAR(1);
        t_createddatefrom          DATE;
        t_createddateto            DATE;
        t_completeddatefrom        DATE;
        t_completeddateto          DATE;
        t_city                     VARCHAR2(100);
        t_county                   VARCHAR2(100);
        t_districtoffice           VARCHAR2(60);
        t_userid                   udt_id;
        t_objectids                api.udt_objectlist
                                       DEFAULT api.udt_objectlist();
    BEGIN
        BEGIN
            SELECT o.investigationnumber,
                   o.investigationtype,
                   o.investigator,
                   r.userid,
                   o.includecrewassignments,
                   o.firstvisitdate,
                   o.activeonly,
                   o.licensenumber,
                   o.departmentpriority,
                   o.createddatefrom,
                   o.createddateto,
                   o.completeddatefrom,
                   o.completeddateto,
                   o.city,
                   o.county,
                   o.districtoffice
              INTO t_investigationnumber,
                   t_investigationtype,
                   t_investigator,
                   t_userid,
                   t_includecrewassignments,
                   t_firstvisitdate,
                   t_activeonly,
                   t_licensenumber,
                   t_departmentpriority,
                   t_createddatefrom,
                   t_createddateto,
                   t_completeddatefrom,
                   t_completeddateto,
                   t_city,
                   t_county,
                   t_districtoffice
              FROM query.o_abc61assignmentoverview  o
                   LEFT OUTER JOIN query.r_abc61ao_investigator r
                       ON r.abc61ao_objectid = o.objectid
             WHERE o.objectid = a_objectid;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                api.pkg_errors.raiseerror(-20000, '');
        END;

        t_objectids.delete;

        extension.pkg_cxproceduralsearch.initializesearch('j_Investigation');
        extension.pkg_cxproceduralsearch.searchbyindex(
            'dup_InvestigationNumber',
            t_investigationnumber,
            NULL,
            TRUE);
        extension.pkg_cxproceduralsearch.searchbyindex('InvestigationType',
                                                       t_investigationtype,
                                                       NULL,
                                                       FALSE);
        extension.pkg_cxproceduralsearch.searchbyindex('dup_LicenseNumber',
                                                       t_licensenumber,
                                                       NULL,
                                                       TRUE);
        extension.pkg_cxproceduralsearch.searchbyindex(
            'dup_DepartmentPriority',
            t_departmentpriority,
            NULL,
            TRUE);
        extension.pkg_cxproceduralsearch.searchbyjob(NULL,
                                                     NULL,
                                                     NULL,
                                                     NULL,
                                                     t_createddatefrom,
                                                     t_createddateto,
                                                     NULL,
                                                     NULL,
                                                     t_completeddatefrom,
                                                     t_completeddateto);
        extension.pkg_cxproceduralsearch.performsearch(t_objectids,
                                                       'and',
                                                       'none');

        IF t_investigationtype IS NULL
       AND t_departmentpriority IS NULL THEN
            extension.pkg_cxproceduralsearch.initializesearch(
                'p_ConductAdminInvestigation');
            extension.pkg_cxproceduralsearch.searchbysystemcolumn(
                'CreatedDate',
                t_createddatefrom,
                t_createddateto,
                FALSE);
            extension.pkg_cxproceduralsearch.searchbysystemcolumn(
                'DateCompleted',
                t_completeddatefrom,
                t_completeddateto,
                FALSE);
            extension.pkg_cxproceduralsearch.performsearch(t_objectids,
                                                           'and',
                                                           'or');

            extension.pkg_cxproceduralsearch.initializesearch(
                'p_ConductLicenseInvestigation');
            extension.pkg_cxproceduralsearch.searchbysystemcolumn(
                'CreatedDate',
                t_createddatefrom,
                t_createddateto,
                FALSE);
            extension.pkg_cxproceduralsearch.searchbysystemcolumn(
                'DateCompleted',
                t_completeddatefrom,
                t_completeddateto,
                FALSE);
            extension.pkg_cxproceduralsearch.performsearch(t_objectids,
                                                           'and',
                                                           'or');
        END IF;

        /*
        NOTE: If the above criterea is not entered in the search object then t_ObjectIds will be
        null and the SQL that is written will have to search everything. But if there are values
        entered above then the SQL will just need to limit the object ids further.
        */

        /*
        --Criteria that will need to be coded in the SQL
        Investigator, IncludeCrewAssignments, FirstVisitDate,
        City, Count, Active Only, investigationoffice

        --Also the p_ConductAdminInvestigation/ConductLicense... needs to be coded for in the SQL, criteria includes:
        BaseFileOfficeName

        */

        FOR c IN 1 .. t_objectids.COUNT
        LOOP                    -- for testing purposes only remove once done.
            dbms_output.put_line(t_objectids(c).objectid);
        END LOOP;
    --delete ABC220AssignmentOverview_gt;
    --commit;
    --insert into ABC220AssignmentOverview_gt ()
    --select
    END abc61assignmentoverview;
END pkg_abcreports;
/


GRANT EXECUTE ON ABC.PKG_ABCREPORTS TO POSSEEXTENSIONS;
