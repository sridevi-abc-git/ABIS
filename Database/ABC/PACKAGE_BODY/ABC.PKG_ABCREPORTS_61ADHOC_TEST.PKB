CREATE OR REPLACE PACKAGE BODY ABC.pkg_abcreports_61adhoc_test
IS
    -- **************************************************************************
    -- File:        PKG_ABCREPORTS_61ADHOC_TEST.PKB
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

    g_golivedate   DATE := TO_DATE('24-MAY-2010', 'DD-MON-YYYY');

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
        t_officeid                 udt_id;
        t_officecode               VARCHAR2(10);
        t_office                   VARCHAR2(100);
        t_userid                   udt_id;
        t_objectids                api.udt_objectlist
                                       DEFAULT api.udt_objectlist();
        t_userobjectids            api.udt_objectlist
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
             WHERE o.objectid = a_objectid; --59389586; --created/received -- 57427086 completed; --a_ObjectId;  --objectid from ABIS ABC61 assignment overview search screen
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                api.pkg_errors.raiseerror(
                    -20000,
                    'ObjectId is not found in o_ABC61AssignmentOverview');
        END;

        t_objectids.delete;

        DELETE abc.abc61_t_test;

        COMMIT;

        DELETE abc.abc61_det_t_test;

        COMMIT;

        DELETE abc.test_id;

        COMMIT;

        INSERT INTO abc.test_id
             VALUES ('1 FIRST');

        COMMIT;

        IF t_districtoffice IS NOT NULL THEN
            getofficeobjectid(t_districtoffice,
                              t_officecode,
                              t_office,
                              t_officeid);

            IF t_officeid IS NULL THEN
                --  insert into abc.test_id values ('B0'); commit;
                GOTO end61overview;
            END IF;
        END IF;

        IF t_county IS NOT NULL THEN
            getcountycode(t_county);

            IF t_county IS NULL THEN
                --       insert into abc.test_id values ('B00'); commit;
                GOTO end61overview;
            END IF;
        END IF;

        IF t_activeonly = 'Y'
       AND (t_completeddatefrom IS NOT NULL
         OR t_completeddateto IS NOT NULL) THEN
            --      insert into abc.test_id values ('B000'); commit;
            GOTO end61overview;
        END IF;

        --TESTING ONLY.................

        INSERT INTO abc.test_id
             VALUES ('2 SECOND..before call functions..');

        COMMIT;
        -- get Enforcement assignments
        get61enfassignments(a_objectid,
                            t_investigationnumber,
                            t_investigationtype,
                            t_investigator,
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
                            t_officecode,
                            t_userid,
                            t_userobjectids);

        INSERT INTO abc.test_id
             VALUES ('3 after first call function...Get61ENFAssignments');

        COMMIT;

        IF t_investigationtype IS NULL
       AND t_departmentpriority IS NULL
       AND t_firstvisitdate IS NULL THEN
            INSERT INTO abc.test_id
                VALUES('4 t_InvestigationType is null...Get61LICAssignments');

            COMMIT;
            get61licassignments(a_objectid,
                                t_investigationnumber,
                                t_investigationtype,
                                t_investigator,
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
                                t_officecode,
                                t_userid,
                                NULL);

            INSERT INTO abc.test_id
                VALUES('5 t_InvestigationType is null...Get61ADMAssignments');

            COMMIT;
            get61admassignments(a_objectid,
                                t_investigationnumber,
                                t_investigationtype,
                                t_investigator,
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
                                t_office,
                                t_userid,
                                NULL);
        END IF;

        INSERT INTO abc.test_id
             VALUES ('6 t_InvestigationType is null...done insert');

        COMMIT;

       <<end61overview>>
        COMMIT;                                 -- to be removed after testing
        NULL;

        INSERT INTO abc.test_id
             VALUES ('7 t_Investigator=' || t_investigator);

        COMMIT;

        --deleting other investigators that are shown on the report other than the one entered in the search criteria page
        --but do not delete if supervisor runs for all investigator where t_Investigator is null

        IF t_investigator IS NULL THEN
            NULL;
        ELSE
            DELETE FROM abc.abc61_t_test
                  WHERE assgndto <> t_investigator;                 --original

            --where  ASSGNDTO <> decode(t_Investigator,null,ASSGNDTO,t_Investigator);

            COMMIT;
        END IF;

        IF t_investigator IS NULL THEN
            NULL;
        ELSE
            --deleting assgndto that is null
            DELETE FROM abc.abc61_t_test
                  WHERE assgndto IS NULL;

            COMMIT;
        END IF;

        INSERT INTO abc.test_id
             VALUES ('8 Yes! last......');

        COMMIT;
    END abc61assignmentoverview;

    PROCEDURE getofficeobjectid(a_districtoffice   VARCHAR2,
                                a_officecode   OUT VARCHAR2,
                                a_office       OUT VARCHAR2,
                                a_objectid     OUT udt_id)
    IS
        t_tmpoffice   VARCHAR2(4000)
                          := RTRIM(LTRIM(UPPER(a_districtoffice), '%'), '%');
        t_tmpofccd    VARCHAR2(2);
    BEGIN
        --
        BEGIN
            SELECT objectid
              INTO a_objectid
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
            IF a_objectid IS NOT NULL THEN
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
              INTO a_objectid
              FROM query.o_office ofc
             WHERE dup_office LIKE UPPER(t_tmpoffice);
        EXCEPTION
            WHEN OTHERS THEN
                NULL;
        END;

        IF a_objectid IS NOT NULL THEN
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
                a_objectid   := x.objectid;
                GOTO endgetoffice;
            END IF;
        END LOOP;

       <<endgetoffice>>
        a_officecode   := api.pkg_columnquery.VALUE(a_objectid, 'OfficeCode');
        a_office       := api.pkg_columnquery.VALUE(a_objectid, 'Office');
    END getofficeobjectid;

    PROCEDURE getcountycode(a_county IN OUT VARCHAR2)
    IS
        t_tmpcounty   VARCHAR2(4000)
                          := RTRIM(LTRIM(UPPER(a_county), '%'), '%');
        t_tmpcntycd   VARCHAR2(2);
        t_objectid    udt_id;
    BEGIN
        --
        BEGIN
            SELECT objectid
              INTO t_objectid
              FROM (SELECT objectid
                      FROM TABLE(
                               CAST(
                                   api.pkg_simplesearch.castableobjectsbyindex(
                                       'o_CaCounty',
                                       'CountyCode',
                                       a_county) AS api.udt_objectlist))
                    UNION ALL
                    SELECT objectid
                      FROM TABLE(
                               CAST(
                                   api.pkg_simplesearch.castableobjectsbyindex(
                                       'o_CaCounty',
                                       'CountyName',
                                       a_county) AS api.udt_objectlist))
                    UNION ALL
                    SELECT objectid
                      FROM TABLE(
                               CAST(
                                   api.pkg_simplesearch.castableobjectsbyindex(
                                       'o_CaCounty',
                                       'dup_County',
                                       a_county) AS api.udt_objectlist)));

            --
            IF t_objectid IS NOT NULL THEN
                GOTO endgetcounty;
            END IF;
        EXCEPTION
            WHEN OTHERS THEN
                NULL;
        END;

        --
        BEGIN
            IF INSTR(a_county, '%') = 0 THEN
                t_tmpcntycd   := '%' || UPPER(a_county) || '%';
            ELSE
                t_tmpcntycd   := UPPER(a_county);
            END IF;

            SELECT objectid
              INTO t_objectid
              FROM query.o_cacounty cc
             WHERE dup_county LIKE UPPER(t_tmpcntycd);
        EXCEPTION
            WHEN OTHERS THEN
                NULL;
        END;

        IF t_objectid IS NOT NULL THEN
            GOTO endgetcounty;
        END IF;

        --
        t_tmpcntycd   := TO_CHAR(REGEXP_REPLACE(a_county, '[^(0-9)]', ''));
        t_tmpcounty   :=
            TRIM(REGEXP_REPLACE(UPPER(a_county), '[^A-Z ]', ' '));

        --
        FOR x
            IN (SELECT objectid,
                       countycode,
                       countyname,
                       TRIM(REGEXP_REPLACE(countyname, '[^A-Z ]', ' '))
                           countyname2
                  FROM query.o_cacounty ofc)
        LOOP
            IF (t_tmpcntycd = x.countycode
             OR t_tmpcntycd IS NULL)
           AND (t_tmpcounty IS NULL
             OR x.countyname2 = t_tmpcounty
             OR x.countyname2 LIKE '%' || t_tmpcounty || '%') THEN
                t_objectid   := x.objectid;
                GOTO endgetcounty;
            END IF;
        END LOOP;

       <<endgetcounty>>
        a_county      := api.pkg_columnquery.VALUE(t_objectid, 'CountyCode');
    END getcountycode;

    FUNCTION enfcrewassignment(a_objectid udt_id)
        RETURN VARCHAR2
    IS
        t_crew   VARCHAR2(1);
    BEGIN
        BEGIN
            SELECT 'N'
              INTO t_crew
              FROM api.processassignments  pa
                   JOIN api.processes pr ON pr.processid = pa.processid
             WHERE pr.processtypeid =
                   api.pkg_configquery.objectdefidforname(
                       'p_ConductEnforcementInv')
               AND pr.jobid = a_objectid
               AND pa.assignedto <> 'CONV';
        EXCEPTION
            WHEN TOO_MANY_ROWS THEN
                t_crew   := 'Y';
            WHEN OTHERS THEN
                t_crew   := NULL;
        END;

        RETURN (t_crew);
    END enfcrewassignment;

    FUNCTION liccrewassignment(a_objectid udt_id)
        RETURN VARCHAR2
    IS
        t_crew   VARCHAR2(1);
    BEGIN
        BEGIN
            SELECT 'N'
              INTO t_crew
              FROM api.processassignments pa
             WHERE pa.processid = a_objectid
               AND pa.assignedto <> 'CONV';
        EXCEPTION
            WHEN TOO_MANY_ROWS THEN
                t_crew   := 'Y';
            WHEN OTHERS THEN
                t_crew   := NULL;
        END;

        RETURN (t_crew);
    END liccrewassignment;

    PROCEDURE get61enfassignments(a_objectid      udt_id,
                                  a_investigationnumber VARCHAR2,
                                  a_investigationtype VARCHAR2,
                                  a_investigator  VARCHAR2,
                                  a_includecrewassignments CHAR,
                                  a_firstvisitdate DATE,
                                  a_activeonly    CHAR,
                                  a_licensenumber VARCHAR2,
                                  a_departmentpriority CHAR,
                                  a_createddatefrom DATE,
                                  a_createddateto DATE,
                                  a_completeddatefrom DATE,
                                  a_completeddateto DATE,
                                  a_city          VARCHAR2,
                                  a_county        VARCHAR2,
                                  a_officecode    VARCHAR2,
                                  a_userid        udt_id,
                                  a_objectids     api.udt_objectlist)
    IS
        t_assignmentdate   DATE;
        t_completeddate    DATE;
        t_crew             VARCHAR2(1);
        t_firstvisitdate   DATE;
        t_enfobjectids     api.udt_objectlist DEFAULT api.udt_objectlist();
        t_enfjoblist       api.udt_objectlist DEFAULT api.udt_objectlist();
        t_activeids        api.udt_objectlist DEFAULT api.udt_objectlist();
        t_investigator     VARCHAR2(100);
        t_test             VARCHAR2(1);
    BEGIN
        IF a_investigator IS NOT NULL THEN
            t_investigator   := '%' || a_investigator;
        END IF;

        extension.pkg_cxproceduralsearch.initializesearch('j_Investigation');

        IF a_investigationnumber IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyindex(
                'dup_InvestigationNumber',
                a_investigationnumber,
                NULL,
                FALSE);
            extension.pkg_cxproceduralsearch.filterobjects(
                'dup_LicenseNumber',
                a_licensenumber,
                NULL,
                FALSE);
            extension.pkg_cxproceduralsearch.filterobjects(
                'dup_Investigators',
                t_investigator,
                NULL,
                TRUE);
            extension.pkg_cxproceduralsearch.filterobjects(
                'dup_DepartmentPriority',
                a_departmentpriority,
                NULL,
                FALSE);
            extension.pkg_cxproceduralsearch.filterobjects(
                'InvestigationType',
                a_investigationtype,
                NULL,
                FALSE);
        ELSIF a_licensenumber IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyindex(
                'dup_LicenseNumber',
                a_licensenumber,
                NULL,
                FALSE);
            extension.pkg_cxproceduralsearch.filterobjects(
                'dup_Investigators',
                t_investigator,
                NULL,
                TRUE);
            extension.pkg_cxproceduralsearch.filterobjects(
                'dup_DepartmentPriority',
                a_departmentpriority,
                NULL,
                FALSE);
            extension.pkg_cxproceduralsearch.filterobjects(
                'InvestigationType',
                a_investigationtype,
                NULL,
                FALSE);
        ELSIF a_investigator IS NOT NULL
           OR a_departmentpriority IS NOT NULL
           OR a_investigationtype IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyindex(
                'dup_Investigators',
                t_investigator,
                NULL,
                TRUE);
            extension.pkg_cxproceduralsearch.searchbyindex(
                'dup_DepartmentPriority',
                a_departmentpriority,
                NULL,
                FALSE);
            extension.pkg_cxproceduralsearch.searchbyindex(
                'InvestigationType',
                a_investigationtype,
                NULL,
                FALSE);
        END IF;

        extension.pkg_cxproceduralsearch.searchbyrelatedindex('Office',
                                                              'OfficeCode',
                                                              a_officecode,
                                                              NULL,
                                                              FALSE);

        IF a_createddatefrom IS NOT NULL
        OR a_createddateto IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyjob(NULL,
                                                         NULL,
                                                         NULL,
                                                         NULL,
                                                         a_createddatefrom,
                                                         a_createddateto,
                                                         NULL,
                                                         NULL,
                                                         NULL,
                                                         NULL);
        END IF;

        IF a_city IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyrelatedindex(
                'PremisesAddress',
                'USACity',
                a_city,
                NULL,
                TRUE);
        END IF;

        IF a_county IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyrelatedindex(
                'PremisesAddress',
                'dup_CountyCode',
                a_county,
                NULL,
                FALSE);
        END IF;

        extension.pkg_cxproceduralsearch.performsearch(t_enfobjectids,
                                                       'and',
                                                       'none');

        IF t_enfobjectids.COUNT = 0 THEN
            --insert into abc.test_id values ('B2'); commit;
            GOTO end_get61enf;
        END IF;

        -- get active job list
        IF a_activeonly = 'Y' THEN
            SELECT api.udt_object(j.jobid)
              BULK COLLECT INTO t_activeids
              FROM query.j_investigation  j
                   JOIN TABLE(t_enfobjectids) x ON x.objectid = j.jobid
             WHERE j.completeddate IS NULL;

            IF t_activeids.COUNT = 0 THEN
                -- insert into abc.test_id values ('B23'); commit;
                GOTO end_get61enf;
            END IF;

            t_enfobjectids.delete;
            t_enfobjectids   := t_activeids;
        END IF;

        -- insert into abc.test_id values ('B3'); commit;
        FOR i IN 1 .. t_enfobjectids.COUNT
        LOOP
            -- check of assignment is not floating
            BEGIN
                SELECT                                              --distinct
                       'Y'
                  INTO t_test        --added distinct for too_many_rows return
                  FROM query.p_conductenforcementinv cei
                 WHERE cei.jobid = t_enfobjectids(i).objectid;
            --  insert into abc.test_id values ('B4'); commit;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    BEGIN
                        SELECT                                      --distinct
                               'Y'
                          INTO t_test
                          FROM query.p_assigninvestigation ai
                         WHERE ai.jobid = t_enfobjectids(i).objectid;
                    --  insert into abc.test_id values ('B5'); commit;
                    EXCEPTION
                        WHEN TOO_MANY_ROWS THEN
                            NULL;
                        --  insert into abc.test_id values ('B6'); commit;
                        WHEN OTHERS THEN
                            GOTO skip_job;
                    END;
                WHEN TOO_MANY_ROWS THEN
                    NULL;
                --  insert into abc.test_id values ('B7'); commit;
                --dbms_output.put_line('t_ENFObjectids(i)...'||t_ENFObjectids(i).objectid);
                WHEN OTHERS THEN
                    GOTO skip_job;
            END;

            t_completeddate   :=
                getenfcompleteddate(t_enfobjectids(i).objectid);

            IF a_completeddatefrom IS NOT NULL
            OR a_completeddateto IS NOT NULL THEN
                IF t_completeddate IS NULL THEN
                    --  insert into abc.test_id values ('B8'); commit;
                    GOTO skip_job;
                ELSIF t_completeddate <
                      NVL(a_completeddatefrom,
                          TO_DATE('19000101', 'YYYYMMDD'))
                   OR t_completeddate > NVL(a_completeddateto, SYSDATE) THEN
                    -- insert into abc.test_id values ('B9'); commit;
                    GOTO skip_job;
                END IF;
            END IF;

            t_crew   := enfcrewassignment(t_enfobjectids(i).objectid);

            IF a_includecrewassignments = 'N'
           AND t_crew = 'Y' THEN
                --  insert into abc.test_id values ('B10'); commit;
                GOTO skip_job;
            END IF;

            -- check other criteria
            IF a_firstvisitdate IS NOT NULL THEN
                t_firstvisitdate   :=
                    TO_DATE(
                        api.pkg_columnquery.VALUE(t_enfobjectids(i).objectid,
                                                  'FirstVisitDate'),
                        'YYYY-MM-DD HH24:MI:SS');

                IF a_firstvisitdate <>
                   NVL(t_firstvisitdate, TO_DATE('19000101', 'YYYYMMDD')) THEN
                    --  insert into abc.test_id values ('B11'); commit;
                    GOTO skip_job;
                END IF;
            END IF;

            INSERT INTO abc.test_id
                VALUES('2.1 inside function..Get61ENFAssignments before INSERT');

            COMMIT;

            -- get details
            -- populate abc61
            INSERT INTO abc.abc61_t_test(rptobjectid,
                                         subj,
                                         licnum,
                                         itype,
                                         invno,
                                         assgndate,
                                         objectid,
                                         assgndto,
                                         priority,
                                         completeddt,
                                         premadd1,
                                         offccode)
                SELECT a_objectid
                           rptobjectid,
                       jinv.licenseprimarylicensee
                           subj,
                       jinv.licensenumber
                           licnum,
                       jinv.investigationtype
                           itype,
                       jinv.investigationnumber
                           invno,
                       jinv.createddate
                           assgndate,
                       jinv.jobid
                           objectid,
                       DECODE(t_crew,
                              'N', jinv.dup_investigators,
                              NULL, NULL,
                              'CREW')
                           assgndto,
                       jinv.departmentpriority
                           priority,
                       t_completeddate
                           completeddt,
                       jinv.licensepremiseaddress1line
                           premadd1,
                       a_officecode
                           offccode
                  FROM query.j_investigation jinv
                 WHERE jinv.jobid = t_enfobjectids(i).objectid;

            -- INSERT INTO ABC.ABC61_T_TEST(rptobjectid) values (11111);
            COMMIT;

            INSERT INTO abc.test_id
                VALUES('2.2 inside function..Get61ENFAssignments done INSERT');

            COMMIT;

           <<skip_job>>
            NULL;
        END LOOP;

       <<end_get61enf>>
        --insert into abc.test_id values ('last....'); commit;
        NULL;
    END get61enfassignments;

    PROCEDURE get61licassignments(
        a_objectid      udt_id,
        a_investigationnumber VARCHAR2,
        a_investigationtype VARCHAR2,
        a_investigator  VARCHAR2,
        a_includecrewassignments CHAR,
        a_firstvisitdate DATE,
        a_activeonly    CHAR,
        a_licensenumber VARCHAR2,
        a_departmentpriority CHAR,
        a_createddatefrom DATE,
        a_createddateto DATE,
        a_completeddatefrom DATE,
        a_completeddateto DATE,
        a_city          VARCHAR2,
        a_county        VARCHAR2,
        a_officecode    VARCHAR2,
        a_userid        udt_id,
        a_objectids     api.udt_objectlist DEFAULT api.udt_objectlist())
    IS
        t_investigator       VARCHAR2(60);
        t_objectlist         api.udt_objectlist DEFAULT api.udt_objectlist();
        t_activeobjectlist   api.udt_objectlist DEFAULT api.udt_objectlist();
        t_tempobjectlist     api.udt_objectlist DEFAULT api.udt_objectlist();
        t_completeddate      DATE;
        t_crew               VARCHAR2(1);
        t_id                 VARCHAR2(100);
    BEGIN
        extension.pkg_cxproceduralsearch.initializesearch('j_License');

        IF a_licensenumber IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyindex('ExternalFileNum',
                                                           a_licensenumber,
                                                           NULL,
                                                           FALSE);
            extension.pkg_cxproceduralsearch.filterobjects(
                'dup_PremAddressUSCity',
                a_city,
                NULL,
                TRUE);
        ELSIF a_city IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyrelatedindex('Premises',
                                                                  'USACity',
                                                                  a_city,
                                                                  NULL,
                                                                  TRUE);
        END IF;

        extension.pkg_cxproceduralsearch.searchbyrelatedindex(
            'LicenseToOffice',
            'OfficeCode',
            a_officecode,
            NULL,
            TRUE);

        IF a_county IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyrelatedindex(
                'Premises',
                'dup_CountyCode',
                a_county,
                NULL,
                FALSE);
        END IF;

        extension.pkg_cxproceduralsearch.performsearch(t_objectlist,
                                                       'and',
                                                       'none');

        SELECT api.udt_object(cl.processid)
          BULK COLLECT INTO t_tempobjectlist
          FROM query.p_conductlicenseinvestigation  cl
               JOIN TABLE(t_objectlist) x ON x.objectid = cl.jobid;

        --testing purpose only........ create table abc.test_id as select tt.objectid from abc.abc61_t_test tt
        -- select * from abc.test_id

        INSERT INTO abc.test_id
            VALUES(' 4.0 inside function..Get61LICAssignments before INSERT');

        COMMIT;

        IF t_tempobjectlist.COUNT = 0 THEN
            INSERT INTO abc.test_id
                 VALUES ('4.1 inside function..Get61LICAssignments NO LIC61');

            COMMIT;
            GOTO end_here;
        ELSE
            t_objectlist.delete;
            t_objectlist   := t_tempobjectlist;
            t_tempobjectlist.delete;
        END IF;

        --  insert into abc.test_id values ('a_InvestigationNumber'||'='||a_InvestigationNumber); commit;

        IF a_investigationnumber IS NOT NULL THEN
            --   insert into abc.test_id values ('x3'); commit;
            SELECT api.udt_object(cl.processid)
              BULK COLLECT INTO t_tempobjectlist
              FROM query.p_conductlicenseinvestigation cl
             WHERE cl.externalfilenum = a_investigationnumber;

            IF t_tempobjectlist.COUNT = 0 THEN
                INSERT INTO abc.test_id
                    VALUES('4.11 inside function..Get61LICAssignments NO LIC61');

                COMMIT;
                GOTO end_here;
            END IF;

            extension.pkg_collectionutils.join(t_objectlist,
                                               t_tempobjectlist);

            IF t_objectlist.COUNT = 0 THEN
                INSERT INTO abc.test_id
                    VALUES('4.12 inside function..Get61LICAssignments NO LIC61');

                COMMIT;
                GOTO end_here;
            END IF;

            t_tempobjectlist.delete;
        END IF;

        --insert into abc.test_id values ('x1...x1'); commit;
        IF a_activeonly = 'Y' THEN
            SELECT api.udt_object(cl.processid)
              BULK COLLECT INTO t_tempobjectlist
              FROM query.p_conductlicenseinvestigation  cl
                   JOIN TABLE(t_objectlist) x ON x.objectid = cl.processid
             WHERE cl.datecompleted IS NULL;

            extension.pkg_collectionutils.append(t_activeobjectlist,
                                                 t_tempobjectlist);
            t_tempobjectlist.delete;

            SELECT api.udt_object(cl.processid)
              BULK COLLECT INTO t_tempobjectlist
              FROM query.p_closeinvestigation  ci
                   JOIN query.p_conductlicenseinvestigation cl
                       ON cl.jobid = ci.jobid
                      AND cl.externalfilenum = ci.externalfilenum
                   JOIN TABLE(t_objectlist) x ON x.objectid = cl.processid
             WHERE ci.datecompleted IS NULL;

            extension.pkg_collectionutils.append(t_activeobjectlist,
                                                 t_tempobjectlist);
            t_tempobjectlist.delete;

            IF t_activeobjectlist.COUNT = 0 THEN
                INSERT INTO abc.test_id
                    VALUES('4.13 inside function..Get61LICAssignments NO LIC61');

                COMMIT;
                GOTO end_here;
            END IF;

            t_objectlist.delete;
            t_objectlist   := t_activeobjectlist;
            t_activeobjectlist.delete;
        END IF;

        IF a_investigator IS NOT NULL
        OR a_createddatefrom IS NOT NULL
        OR a_createddateto IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.initializesearch(
                'p_ConductLicenseInvestigation');
            extension.pkg_cxproceduralsearch.searchbyindex(
                'dup_LicensingRepresentative',
                a_investigator,
                NULL,
                FALSE);
            extension.pkg_cxproceduralsearch.searchbysystemcolumn(
                'CreatedDate',
                a_createddatefrom,
                a_createddateto + 1);
            extension.pkg_cxproceduralsearch.performsearch(t_objectlist,
                                                           'and',
                                                           'and');

            IF t_objectlist.COUNT = 0 THEN
                INSERT INTO abc.test_id
                    VALUES('4.14 inside function..Get61LICAssignments NO LIC61');

                COMMIT;
                GOTO end_here;
            END IF;
        END IF;

        FOR i IN 1 .. t_objectlist.COUNT
        LOOP
            t_completeddate   :=
                getliccompleteddate(t_objectlist(i).objectid);

            IF a_completeddatefrom IS NOT NULL
            OR a_completeddateto IS NOT NULL THEN
                IF t_completeddate IS NULL THEN
                    --       insert into abc.test_id values ('x8'); commit;
                    GOTO skip_rec;
                ELSIF t_completeddate <
                      NVL(a_completeddatefrom,
                          TO_DATE('19000101', 'YYYYMMDD'))
                   OR t_completeddate > NVL(a_completeddateto, SYSDATE) THEN
                    --              insert into abc.test_id values ('x9'); commit;
                    GOTO skip_rec;
                END IF;
            END IF;

            t_crew   := liccrewassignment(t_objectlist(i).objectid);

            IF a_includecrewassignments = 'N'
           AND t_crew = 'Y' THEN
                --     insert into abc.test_id values ('x10'); commit;
                GOTO skip_rec;
            END IF;

            INSERT INTO abc.test_id
                VALUES(' 4.2 inside function..Get61LICAssignments before INSERT');

            COMMIT;

            -- populate abc61
            INSERT INTO abc.abc61_t_test(rptobjectid,
                                         subj,
                                         licnum,
                                         itype,
                                         invno,
                                         assgndate,
                                         objectid,
                                         assgndto,
                                         priority,
                                         completeddt,
                                         premadd1,
                                         offccode)
                SELECT a_objectid
                           rptobjectid,
                       pr.primarylicensee
                           subj,
                       pr.licensenumber
                           licnum,
                       'LICENSING 61'
                           itype,
                       pr.externalfilenum
                           invno,
                       pr.createddate
                           assgndate,
                       pr.processid
                           objectid,
                       --DECODE(t_Crew,
                       --'N', PR.dup_LicensingRepresentative,
                       --NULL, NULL,
                       --'CREW'
                       --) assgndto,
                       DECODE(
                           t_crew,
                           'N',              --PR.dup_LicensingRepresentative,
                                CASE --replaced PR.dup_LicensingRepresentative wth this CASE 12/14/2011 Bee
                                    WHEN getuseroralogonid(
                                             pr.dup_licensingrepresentative) <>
                                         pr.assignedstaff
                                     AND pr.assignedstaff IS NOT NULL THEN
                                        NVL(getusername(pr.assignedstaff),
                                            pr.dup_licensingrepresentative)
                                    ELSE
                                        pr.dup_licensingrepresentative
                                END,
                           NULL, NULL,
                           'CREW')
                           assgndto,
                       NULL
                           priority,
                       t_completeddate
                           completeddt,                    --PR.DATECOMPLETED,
                       pr.premaddress1line
                           premadd1,
                       SUBSTR(pr.basefileofficecorral, 1, 2)
                           offccode
                  FROM query.p_conductlicenseinvestigation pr
                 WHERE pr.processid = t_objectlist(i).objectid;

            COMMIT;

            INSERT INTO abc.test_id
                VALUES('4.2 inside function..Get61LICAssignments done INSERT');

            COMMIT;

           <<skip_rec>>
            NULL;
        END LOOP;

       <<end_here>>
        t_objectlist.delete;
    END get61licassignments;

    PROCEDURE get61admassignments(
        a_objectid      udt_id,
        a_investigationnumber VARCHAR2,
        a_investigationtype VARCHAR2,
        a_investigator  VARCHAR2,
        a_includecrewassignments CHAR,
        a_firstvisitdate DATE,
        a_activeonly    CHAR,
        a_licensenumber VARCHAR2,
        a_departmentpriority CHAR,
        a_createddatefrom DATE,
        a_createddateto DATE,
        a_completeddatefrom DATE,
        a_completeddateto DATE,
        a_city          VARCHAR2,
        a_county        VARCHAR2,
        a_office        VARCHAR2,
        a_userid        udt_id,
        a_objectids     api.udt_objectlist DEFAULT api.udt_objectlist())
    IS
        t_investigator       VARCHAR2(60);
        t_objectlist         api.udt_objectlist DEFAULT api.udt_objectlist();
        t_activeobjectlist   api.udt_objectlist DEFAULT api.udt_objectlist();
        t_tempobjectlist     api.udt_objectlist DEFAULT api.udt_objectlist();
        t_completeddate      DATE;
        t_crew               VARCHAR2(1);
    BEGIN
        extension.pkg_cxproceduralsearch.initializesearch('j_Application');
        extension.pkg_cxproceduralsearch.searchbyindex(
            'dup_BaseFileOfficeCorral',
            a_office,
            NULL,
            FALSE);

        IF a_licensenumber IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyindex('ExternalFileNum',
                                                           a_licensenumber,
                                                           NULL,
                                                           FALSE);
            extension.pkg_cxproceduralsearch.filterobjects('dup_PremUSCity',
                                                           a_city,
                                                           NULL,
                                                           TRUE);
        ELSIF a_city IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyrelatedindex('Premises',
                                                                  'USACity',
                                                                  a_city,
                                                                  NULL,
                                                                  TRUE);
        END IF;

        IF a_county IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.searchbyrelatedindex(
                'Premises',
                'dup_CountyCode',
                a_county,
                NULL,
                FALSE);
        END IF;

        extension.pkg_cxproceduralsearch.performsearch(t_objectlist,
                                                       'and',
                                                       'none');

        SELECT api.udt_object(cl.processid)
          BULK COLLECT INTO t_tempobjectlist
          FROM query.p_conductadmininvestigation  cl
               JOIN TABLE(t_objectlist) x ON x.objectid = cl.jobid;

        IF t_tempobjectlist.COUNT = 0 THEN
            GOTO end_here;
        ELSE
            t_objectlist.delete;
            t_objectlist   := t_tempobjectlist;
            t_tempobjectlist.delete;
        END IF;

        IF a_investigationnumber IS NOT NULL THEN
            SELECT api.udt_object(cl.processid)
              BULK COLLECT INTO t_tempobjectlist
              FROM query.p_conductadmininvestigation cl
             WHERE cl.externalfilenum = a_investigationnumber;

            IF t_tempobjectlist.COUNT = 0 THEN
                GOTO end_here;
            END IF;

            extension.pkg_collectionutils.join(t_objectlist,
                                               t_tempobjectlist);

            IF t_objectlist.COUNT = 0 THEN
                GOTO end_here;
            END IF;

            t_tempobjectlist.delete;
        END IF;

        IF a_activeonly = 'Y' THEN
            SELECT api.udt_object(cl.processid)
              BULK COLLECT INTO t_tempobjectlist
              FROM query.p_conductadmininvestigation  cl
                   JOIN TABLE(t_objectlist) x ON x.objectid = cl.processid
             WHERE cl.datecompleted IS NULL;

            extension.pkg_collectionutils.append(t_activeobjectlist,
                                                 t_tempobjectlist);
            t_tempobjectlist.delete;

            SELECT api.udt_object(cl.processid)
              BULK COLLECT INTO t_tempobjectlist
              FROM query.p_closeinvestigation  ci
                   JOIN query.p_conductlicenseinvestigation cl
                       ON cl.jobid = ci.jobid
                      AND cl.externalfilenum = ci.externalfilenum
                   JOIN TABLE(t_objectlist) x ON x.objectid = cl.processid
             WHERE ci.datecompleted IS NULL;

            extension.pkg_collectionutils.append(t_activeobjectlist,
                                                 t_tempobjectlist);
            t_tempobjectlist.delete;

            IF t_activeobjectlist.COUNT = 0 THEN
                GOTO end_here;
            END IF;

            t_objectlist.delete;
            t_objectlist   := t_activeobjectlist;
            t_activeobjectlist.delete;
        END IF;

        IF a_investigator IS NOT NULL
        OR a_createddatefrom IS NOT NULL
        OR a_createddateto IS NOT NULL THEN
            extension.pkg_cxproceduralsearch.initializesearch(
                'p_ConductAdminInvestigation');
            extension.pkg_cxproceduralsearch.searchbyindex(
                'dup_LicensingRepresentative',
                a_investigator,
                NULL,
                FALSE);
            extension.pkg_cxproceduralsearch.searchbysystemcolumn(
                'CreatedDate',
                a_createddatefrom,
                a_createddateto + 1);
            extension.pkg_cxproceduralsearch.performsearch(t_objectlist,
                                                           'and',
                                                           'and');

            IF t_objectlist.COUNT = 0 THEN
                GOTO end_here;
            END IF;
        END IF;

        FOR i IN 1 .. t_objectlist.COUNT
        LOOP
            t_completeddate   :=
                getliccompleteddate(t_objectlist(i).objectid);

            IF a_completeddatefrom IS NOT NULL
            OR a_completeddateto IS NOT NULL THEN
                IF t_completeddate IS NULL THEN
                    GOTO skip_rec;
                ELSIF t_completeddate <
                      NVL(a_completeddatefrom,
                          TO_DATE('19000101', 'YYYYMMDD'))
                   OR t_completeddate > NVL(a_completeddateto, SYSDATE) THEN
                    GOTO skip_rec;
                END IF;
            END IF;

            t_crew   := liccrewassignment(t_objectlist(i).objectid);

            IF a_includecrewassignments = 'N'
           AND t_crew = 'Y' THEN
                GOTO skip_rec;
            END IF;

            -- populate abc61
            INSERT INTO abc.test_id
                VALUES('5.1 inside function..Get61ADMAssignments before INSERT');

            COMMIT;

            INSERT INTO abc.abc61_t_test(rptobjectid,
                                         subj,
                                         licnum,
                                         itype,
                                         invno,
                                         assgndate,
                                         objectid,
                                         assgndto,
                                         priority,
                                         completeddt,
                                         premadd1,
                                         offccode)
                SELECT a_objectid
                           rptobjectid,
                       pr.primarylicensee
                           subj,
                       api.pkg_columnquery.VALUE(pr.jobid, 'LicenseNumber')
                           licnum,
                       'LICENSING 61'
                           itype,
                       pr.externalfilenum
                           invno,
                       pr.createddate
                           assgndate,
                       pr.processid
                           objectid,
                       DECODE(t_crew,
                              'N', pr.dup_licensingrepresentative,
                              NULL, NULL,
                              'CREW')
                           assgndto,
                       NULL
                           priority,
                       t_completeddate
                           completeddt,                    --PR.DATECOMPLETED,
                       api.pkg_columnquery.VALUE(pr.jobid,
                                                 'PremisesAddress1Line')
                           premadd1,
                       SUBSTR(pr.basefileofficecorral, 1, 2)
                           offccode
                  FROM query.p_conductadmininvestigation pr
                 WHERE pr.processid = t_objectlist(i).objectid;

            COMMIT;

            INSERT INTO abc.test_id
                VALUES('5.2 inside function..Get61ADMAssignments done INSERT');

            COMMIT;

           <<skip_rec>>
            NULL;
        END LOOP;

       <<end_here>>
        t_objectlist.delete;
    END get61admassignments;

    FUNCTION getliccompleteddate(a_objectid udt_id)
        RETURN DATE
    IS
        t_completeddate         DATE;
        t_jobid                 udt_id;
        t_investigationnumber   VARCHAR2(15);
    BEGIN
        BEGIN
            SELECT TRUNC(p.datecompleted),
                   p.jobid,
                   api.pkg_columnquery.VALUE(p.processid, 'ExternalFileNum')
              INTO t_completeddate, t_jobid, t_investigationnumber
              FROM api.processes p
             WHERE p.processid = a_objectid;

            IF t_completeddate >= g_golivedate THEN
                BEGIN
                    SELECT TRUNC(ci.datecompleted)
                      INTO t_completeddate
                      FROM query.p_closeinvestigation ci
                     WHERE ci.jobid = t_jobid
                       AND ci.externalfilenum = t_investigationnumber;
                EXCEPTION
                    WHEN TOO_MANY_ROWS THEN
                        BEGIN
                            SELECT TRUNC(MIN(ci.datecompleted))
                              INTO t_completeddate
                              FROM query.p_closeinvestigation ci
                             WHERE ci.jobid = t_jobid
                               AND ci.externalfilenum = t_investigationnumber;
                        END;
                    WHEN OTHERS THEN
                        NULL;
                END;
            END IF;
        EXCEPTION
            WHEN OTHERS THEN
                NULL;
        END;

        RETURN (t_completeddate);
    END getliccompleteddate;

    FUNCTION getenfcompleteddate(a_objectid udt_id)
        RETURN DATE
    IS
        t_completeddate   DATE;
    BEGIN
        BEGIN
            SELECT TRUNC(ci.datecompleted)
              INTO t_completeddate
              FROM query.p_closeinvestigation ci
             WHERE ci.jobid = a_objectid;
        EXCEPTION
            WHEN TOO_MANY_ROWS THEN
                BEGIN
                    SELECT TRUNC(MIN(ci.datecompleted))
                      INTO t_completeddate
                      FROM query.p_closeinvestigation ci
                     WHERE ci.jobid = a_objectid;
                END;
            WHEN OTHERS THEN
                NULL;
        END;

        RETURN (t_completeddate);
    END getenfcompleteddate;
END pkg_abcreports_61adhoc_test;
/
