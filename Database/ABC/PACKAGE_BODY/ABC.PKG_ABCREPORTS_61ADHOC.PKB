CREATE OR REPLACE PACKAGE BODY ABC.pkg_AbcReports_61Adhoc
IS
-- **************************************************************************
-- File:        PKG_ABCREPORTS_61ADHOC.PKB
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
-- 04/30/2020 NW          Code Formatting Improvements
-- 05/04/2020 NW          WO 21009 Added AdministrativeType
-- 05/12/2025 PK          Resolved Issue 4772 
-- **************************************************************************

	g_golivedate   DATE := TO_DATE('24-MAY-2010', 'DD-MON-YYYY');

----------------------------------------------------------------
PROCEDURE Abc61AssignmentOverview(a_objectid udt_id)
----------------------------------------------------------------

IS
-- This is the parameter list for the Infomaker Report. Order is important.
	t_investigationnumber      VARCHAR2(15);
	t_InvestigationType        VARCHAR2(60);
	t_AdministrativeType       VARCHAR(100);   -- NW wo 21009
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
	t_objectids                api.udt_objectlist DEFAULT api.udt_objectlist();
	t_userobjectids            api.udt_objectlist DEFAULT api.udt_objectlist();
BEGIN
	BEGIN
		SELECT 
			o.investigationnumber,
			o.investigationtype,
			o.AdministrativeType,    -- NW wo 21009
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
		INTO
      t_investigationnumber,
			t_InvestigationType,
			t_AdministrativeType,  -- NW wo 21009
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
		FROM QUERY.O_Abc61AssignmentOverview  o
		LEFT OUTER JOIN QUERY.R_Abc61ao_Investigator r ON R.Abc61ao_objectid = O.objectid
		WHERE O.objectid = a_objectid;
	EXCEPTION
		WHEN NO_DATA_FOUND THEN
		api.pkg_errors.raiseerror(
		-20000,
		'ObjectId is not found in o_ABC61AssignmentOverview');
	END;

  t_objectids.delete;

  DELETE abc.abc61_t;
  DELETE abc.abc61_det_t;


  IF t_DistrictOffice IS NOT NULL THEN
    GetOfficeObjectid(
      t_districtoffice,
      t_officecode,
      t_office,
      t_officeid
    );

    IF t_OfficeId IS NULL THEN
      GOTO end61overview;
    END IF;
  END IF;

  IF t_county IS NOT NULL THEN
    GetCountyCode(t_county);

    IF t_county IS NULL THEN
      GOTO end61overview;
    END IF;
  END IF;

  IF t_ActiveOnly = 'Y'
    AND (t_completeddatefrom IS NOT NULL OR t_completeddateto IS NOT NULL) THEN
    GOTO end61overview;
  END IF;

  IF t_InvestigationType = 'LICENSING 61' THEN
    get61licassignments(
      a_objectid,
      t_investigationnumber,
      t_InvestigationType,
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
      NULL
    );

    get61admassignments(
      a_objectid,
      t_investigationnumber,
      t_InvestigationType,
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
      NULL
    );
  ELSIF t_InvestigationType IS NOT NULL THEN
    Get61EnfAssignments(   -- Inserts into ABC.abc61_t                        
      a_objectid,
      t_investigationnumber,
      t_InvestigationType,
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
      t_userobjectids
    );
  END IF;

  IF t_InvestigationType IS NULL AND t_departmentpriority IS NULL AND t_firstvisitdate IS NULL THEN
    get61licassignments(
      a_objectid,
      t_investigationnumber,
      t_InvestigationType,
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
      NULL
    );

    get61admassignments(
      a_objectid,
      t_investigationnumber,
      t_InvestigationType,
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
      NULL
    );

    Get61EnfAssignments(
      a_objectid,
      t_investigationnumber,
      t_InvestigationType,
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
      t_userobjectids
    );
  END IF;

<<end61overview>>

  --deleting other investigators that are shown on the report other than the one entered in the search criteria page
  --but do not delete if supervisor runs for all investigator where t_Investigator is null 06/10/2011 bee

  IF t_investigator IS NULL THEN
    NULL;
  ELSE
   --DELETE FROM abc.abc61_t WHERE assgndto <> t_investigator;   
     DELETE FROM abc.abc61_t WHERE assgndto NOT LIKE '%'||t_investigator||'%';  --   Resolved Issue 4772 Pawanjit Kaur on 05/08/2025           --original
    -- commit;  --take out in production
  END IF;

  IF t_investigator IS NULL THEN
    NULL;
  ELSE
    --deleting assgndto that is null
    DELETE FROM abc.abc61_t  WHERE assgndto IS NULL;
    -- commit;  --take out in production
  END IF;
  
  -- 5/21/2020 NW WO 21009 Add AdministrativeType
  IF  t_InvestigationType ='ADMINISTRATIVE' AND  t_AdministrativeType IS NOT NULL THEN
    DELETE FROM abc.abc61_t 
    WHERE AdministrativeType <> t_AdministrativeType
    OR AdministrativeType IS NULL;
--    COMMIT;
  END IF;


END Abc61AssignmentOverview;

-------------------------------------------------------------------
PROCEDURE GetOfficeObjectId(
-------------------------------------------------------------------
	a_districtoffice   VARCHAR2,
	a_officecode   OUT VARCHAR2,
	a_office       OUT VARCHAR2,
	a_objectid     OUT udt_id
)

IS

  t_tmpoffice   VARCHAR2(4000) := RTRIM(LTRIM(UPPER(a_districtoffice), '%'), '%');
  t_tmpofccd    VARCHAR2(2);

BEGIN
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

---------------------------------------------------
PROCEDURE GetCountyCode(a_county IN OUT VARCHAR2)
---------------------------------------------------
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
END GetCountyCode;

-------------------------------------------------
FUNCTION EnfCrewAssignment(a_objectid udt_id)
-------------------------------------------------
RETURN VARCHAR2
IS
  t_crew   VARCHAR2(1);
BEGIN
  BEGIN
    SELECT 'N'
      INTO t_crew
    FROM api.processassignments  pa
    JOIN api.processes pr ON pr.processid = pa.processid
    WHERE pr.processtypeid = api.pkg_configquery.objectdefidforname('p_ConductEnforcementInv')
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

-------------------------------------------------
FUNCTION LicCrewAssignment(a_objectid udt_id)
-------------------------------------------------
  RETURN VARCHAR2
IS
  t_crew   VARCHAR2(1);
BEGIN
  -- 3/20/14  MMR Per Anthony, the Assign License process will only be for one person,
  -- so this should always return a "N"
  t_crew := 'N';
RETURN (t_crew);
END LicCrewAssignment;

-----------------------------------------------------------
PROCEDURE Get61EnfAssignments (
-----------------------------------------------------------
/*
populates ABC.abc61_t with detail records for Informaker Report
*/
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
  a_objectids     api.udt_objectlist
)
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

  EXTENSION.pkg_cxproceduralsearch.initializesearch('j_Investigation');

  IF a_investigationnumber IS NOT NULL THEN
    EXTENSION.pkg_cxproceduralsearch.searchbyindex(
      'dup_InvestigationNumber',
      a_investigationnumber,
      NULL,
      FALSE
    );
  
    EXTENSION.pkg_cxproceduralsearch.filterobjects(
      'dup_LicenseNumber',
      a_licensenumber,
      NULL,
      FALSE
    );

    EXTENSION.pkg_cxproceduralsearch.filterobjects(
      'dup_Investigators',
      t_investigator,
      NULL,
      TRUE
    );

    EXTENSION.pkg_cxproceduralsearch.filterobjects(
      'dup_DepartmentPriority',
      a_departmentpriority,
      NULL,
      FALSE
    );
    
    EXTENSION.pkg_cxproceduralsearch.filterobjects(
      'InvestigationType',
      a_investigationtype,
      NULL,
      FALSE
    );
  END IF;

  IF a_licensenumber IS NOT NULL THEN
    EXTENSION.pkg_cxproceduralsearch.searchbyindex(
      'dup_LicenseNumber',
      a_licensenumber,
      NULL,
      FALSE
    );

    EXTENSION.pkg_cxproceduralsearch.filterobjects(
      'dup_Investigators',
      t_investigator,
      NULL,
      TRUE
    );

    EXTENSION.pkg_cxproceduralsearch.filterobjects(
      'dup_DepartmentPriority',
      a_departmentpriority,
      NULL,
      FALSE
    );

    EXTENSION.pkg_cxproceduralsearch.filterobjects(
      'InvestigationType',
      a_investigationtype,
      NULL,
      FALSE
    );
  END IF;

  IF a_investigator IS NOT NULL
    OR a_departmentpriority IS NOT NULL
    OR a_investigationtype IS NOT NULL THEN

    EXTENSION.pkg_cxproceduralsearch.searchbyindex(
      'dup_Investigators',
      t_investigator,
      NULL,
      TRUE
    );

    EXTENSION.pkg_cxproceduralsearch.searchbyindex(
      'dup_DepartmentPriority',
      a_departmentpriority,
      NULL,
      FALSE
    );

    EXTENSION.pkg_cxproceduralsearch.searchbyindex(
      'InvestigationType',
      a_investigationtype,
      NULL,
      FALSE
    );
  END IF;

  EXTENSION.pkg_cxproceduralsearch.searchbyrelatedindex(
    'Office',
    'OfficeCode',
    a_officecode,
    NULL,
    FALSE
  );

  IF a_createddatefrom IS NOT NULL OR a_createddateto IS NOT NULL THEN
    EXTENSION.pkg_cxproceduralsearch.searchbyjob(
      NULL,
      NULL,
      NULL,
      NULL,
      a_createddatefrom,
      a_createddateto,
      NULL,
      NULL,
      NULL,
      NULL
    );
  END IF;

  IF a_city IS NOT NULL THEN
    EXTENSION.pkg_cxproceduralsearch.searchbyrelatedindex(
      'PremisesAddress',
      'USACity',
      a_city,
      NULL,
      TRUE
    );
  END IF;

  IF a_county IS NOT NULL THEN
    EXTENSION.pkg_cxproceduralsearch.searchbyrelatedindex(
      'PremisesAddress',
      'dup_CountyCode',
      a_county,
      NULL,
      FALSE
    );
  END IF;

  EXTENSION.pkg_cxproceduralsearch.performsearch(
    t_enfobjectids,
    'and',
    'none'
  );

  IF t_enfobjectids.COUNT = 0 THEN
    GOTO end_get61enf;
  END IF;

  FOR i IN 1 .. t_enfobjectids.COUNT
  LOOP
    t_crew   := enfcrewassignment(t_enfobjectids(i).objectid);

    --insert into ning_enfobjectids (objectid) values (t_enfobjectids(i).objectid);
    --commit;

    IF a_includecrewassignments = 'N' AND t_crew = 'Y' THEN
      GOTO skip_job;
    END IF;

    -- check other criteria
    IF a_firstvisitdate IS NOT NULL THEN
      t_firstvisitdate := TO_DATE(
        api.pkg_columnquery.VALUE(t_enfobjectids(i).objectid,'FirstVisitDate' ),
        'YYYY-MM-DD HH24:MI:SS'
      );

      IF a_firstvisitdate <> NVL(t_firstvisitdate, TO_DATE('19000101', 'YYYYMMDD')) THEN
        GOTO skip_job;
      END IF;
    END IF;

    -- get details
    -- populate abc61
    INSERT INTO abc.abc61_t(
      rptobjectid,
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
      offccode,
      administrativetype
    )
    SELECT 
      a_objectid
      rptobjectid,
      primarylicensee
      subj,
      licensenumber
      licnum,
      assign_type
      itype,
      investigation_number
      invno,
      ( SELECT startdate
          FROM abc.v_all_61_enforcement sd
         WHERE sd.process_type = 'Assign'
           AND sd.job_id = t_enfobjectids(i).objectid
           AND ROWNUM = 1
      ) assgndate,
      process_id
      objectid,
      ( SELECT 
          CASE
            WHEN n.assignstaffname IS NULL THEN n.investigator
            WHEN n.assignstaffname != n.investigator THEN n.investigator
            ELSE n.assignstaffname
          END
          FROM abc.v_all_61_enforcement n
         WHERE n.process_type = 'Conduct'
           AND n.job_id = a.job_id
           AND n.investigation_number = a.investigation_number
           AND ROWNUM = 1
      ) assgndto,
      NULL priority,
      completeddate completeddt,
      premaddress1line premadd1,
      districtoffice offccode,
      administrativetype
    FROM abc.v_all_61_enforcement a
    WHERE process_type IN ('Conduct', 'Close') -- don't display Assign recs
      AND job_id = t_enfobjectids(i).objectid
      AND ( 
        ( NVL(a_activeonly, 'N') = 'Y' 
          AND completeddate IS NULL          -- ACTIVE RECORDS ONLY
          AND 0 = (
            SELECT COUNT(*)
              FROM abc.v_all_61_enforcement c
             WHERE c.process_type = 'Close'
               AND c.job_id = a.job_id
               AND completeddate IS NOT NULL
          )
        ) -- ignore the closed recs
        OR (
          NVL(a_activeonly, 'N') = 'N'
          AND (completeddate IS NULL OR process_type = 'Close')  -- ALL OTHER RECORDS - ACTIVE IND NOT SELECTED
        )
      )
      AND job_id = t_enfobjectids(i).objectid
      AND ( 
        ( a_completeddatefrom IS NOT NULL 
          AND completeddate IN ( 
            SELECT completeddate
              FROM abc.v_all_61_enforcement c
             WHERE c.process_type = 'Close'
               AND c.job_id = a.job_id
               AND TRUNC(completeddate) 
                 BETWEEN TRUNC(a_completeddatefrom) AND TRUNC(a_completeddateto)
          )
        )
        OR a_completeddatefrom IS NULL
      )
    ;

    <<skip_job>>
    NULL;
  END LOOP;

<<end_get61enf>>
  NULL;
  
END Get61EnfAssignments;

------------------------------------------
PROCEDURE Get61LicAssignments( 
-----------------------------Get61LICAssignments ------------------------------------------
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
        l_job_id             NUMBER;
    BEGIN
        EXTENSION.pkg_cxproceduralsearch.initializesearch('j_License');

        IF a_licensenumber IS NOT NULL THEN
            EXTENSION.pkg_cxproceduralsearch.searchbyindex('ExternalFileNum',
                                                           a_licensenumber,
                                                           NULL,
                                                           FALSE);
            EXTENSION.pkg_cxproceduralsearch.filterobjects(
                'dup_PremAddressUSCity',
                a_city,
                NULL,
                TRUE);
        ELSIF a_city IS NOT NULL THEN
            EXTENSION.pkg_cxproceduralsearch.searchbyrelatedindex('Premises',
                                                                  'USACity',
                                                                  a_city,
                                                                  NULL,
                                                                  TRUE);
        END IF;

        EXTENSION.pkg_cxproceduralsearch.searchbyrelatedindex(
            'LicenseToOffice',
            'OfficeCode',
            a_officecode,
            NULL,
            TRUE);

        IF a_county IS NOT NULL THEN
            EXTENSION.pkg_cxproceduralsearch.searchbyrelatedindex(
                'Premises',
                'dup_CountyCode',
                a_county,
                NULL,
                FALSE);
        END IF;

        EXTENSION.pkg_cxproceduralsearch.performsearch(t_objectlist,
                                                       'and',
                                                       'none');

        SELECT api.udt_object(cl.processid)
          BULK COLLECT INTO t_tempobjectlist
          FROM query.p_assignlicenseinvestigation  cl
               JOIN TABLE(t_objectlist) x ON x.objectid = cl.jobid;


        IF t_tempobjectlist.COUNT = 0 THEN
            GOTO end_here;
        -- end if;
        ELSE
            t_objectlist.delete;
            t_objectlist   := t_tempobjectlist;
            t_tempobjectlist.delete;
        END IF;


        IF a_investigationnumber IS NOT NULL THEN
            SELECT api.udt_object(cl.processid)
              BULK COLLECT INTO t_tempobjectlist
              FROM query.p_assignlicenseinvestigation cl
             WHERE cl.externalfilenum = a_investigationnumber;

            IF t_tempobjectlist.COUNT = 0 THEN
                GOTO end_here;
            END IF;

            EXTENSION.pkg_collectionutils.join(t_objectlist,
                                               t_tempobjectlist);

            IF t_objectlist.COUNT = 0 THEN
                GOTO end_here;
            END IF;

            t_tempobjectlist.delete;
        END IF;

        IF a_investigator IS NOT NULL
        OR a_createddatefrom IS NOT NULL
        OR a_createddateto IS NOT NULL THEN
            EXTENSION.pkg_cxproceduralsearch.initializesearch(
                'p_AssignLicenseInvestigation');
            EXTENSION.pkg_cxproceduralsearch.searchbysystemcolumn(
                'CreatedDate',
                a_createddatefrom,
                a_createddateto + 1);
            EXTENSION.pkg_cxproceduralsearch.performsearch(t_objectlist,
                                                           'and',
                                                           'and');

            IF t_objectlist.COUNT = 0 THEN
                GOTO end_here;
            END IF;
        END IF;

        FOR i IN 1 .. t_objectlist.COUNT
        LOOP
            t_crew   := liccrewassignment(t_objectlist(i).objectid);

            IF a_includecrewassignments = 'N'
           AND t_crew = 'Y' THEN
                GOTO skip_rec;
            END IF;

            -- populate abc61
            INSERT INTO abc.abc61_t(rptobjectid,
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
                       primarylicensee
                           subj,
                       licensenumber
                           licnum,
                       'LICENSING 61'
                           itype,
                       investigation_number
                           invno,
                       (SELECT startdate
                          FROM abc.v_all_61_licensing sd
                         WHERE sd.process_type = 'Assign'
                           AND sd.job_id = a.job_id
                           AND sd.assign_pid = t_objectlist(i).objectid)
                           assgndate,
                       process_id
                           objectid,
                       (SELECT CASE
                                   WHEN n.assignstaffname IS NULL THEN
                                       n.dup_licensingrepresentative
                                   WHEN n.assignstaffname !=
                                        n.dup_licensingrepresentative THEN
                                       n.dup_licensingrepresentative
                                   ELSE
                                       n.assignstaffname
                               END
                          FROM abc.v_all_61_licensing n
                         WHERE n.process_type = 'Conduct'
                           AND n.job_id = a.job_id
                           AND n.investigation_number =
                               a.investigation_number)
                           assgndto,
                       NULL
                           priority,
                       completeddate
                           completeddt,
                       premaddress1line
                           premadd1,
                       districtoffice
                           offccode
                  FROM abc.v_all_61_licensing a
                 WHERE process_type IN ('Conduct', 'Close') -- don't display Assign recs
                   AND ((NVL(a_activeonly, 'N') = 'Y'
                     AND completeddate IS NULL          -- ACTIVE RECORDS ONLY
                                              /* and 0 = (select count(*)
                                                          from ABC.V_ALL_61_LICENSING c
                                                           where c.process_type ='Close'
                                                             and c.job_id = a.job_id
                                                             and completeddate is not null)  -- make sure no Close record exists
                                            */
                                              )
                     OR ((NVL(a_activeonly, 'N') = 'N'
                      AND completeddate IS NULL) -- ALL OTHER RECORDS - ACTIVE IND NOT SELECTED
                      OR (NVL(a_activeonly, 'N') = 'N'
                      AND completeddate IS NOT NULL
                      AND process_type = 'Close')) --  ALL OTHER RECORDS - ACTIVE IND NOT SELECTED
                                                  )
                   AND job_id IN
                           (SELECT job_id
                              FROM abc.v_all_61_licensing b
                             WHERE assign_pid = t_objectlist(i).objectid)
                   AND investigation_number IN
                           (SELECT investigation_number
                              FROM abc.v_all_61_licensing c
                             WHERE c.investigation_number =
                                   a.investigation_number
                               AND assign_pid = t_objectlist(i).objectid)
                   AND ((a_completeddatefrom IS NOT NULL
                     AND completeddate IN
                             (SELECT completeddate
                                FROM abc.v_all_61_licensing c
                               WHERE c.process_type = 'Close'
                                 AND c.job_id = a.job_id
                                 AND TRUNC(completeddate) BETWEEN TRUNC(
                                                                      a_completeddatefrom)
                                                              AND TRUNC(
                                                                      a_completeddateto)))
                     --  and completeddate between a_CompletedDateFrom and a_CompletedDateto) )
                     OR a_completeddatefrom IS NULL);

           <<skip_rec>>
            NULL;
        END LOOP;

<<end_here>>
  -- t_TempObjectList.Delete;
  t_objectlist.delete;
END get61licassignments;

----------------------------------
PROCEDURE Get61AdmAssignments(
----------------------------------  
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
  a_objectids     api.udt_objectlist DEFAULT api.udt_objectlist()
)
IS
  t_investigator       VARCHAR2(60);

  t_objectlist         api.udt_objectlist DEFAULT api.udt_objectlist();
  t_activeobjectlist   api.udt_objectlist DEFAULT api.udt_objectlist();
  t_tempobjectlist     api.udt_objectlist DEFAULT api.udt_objectlist();
  t_completeddate      DATE;
  t_crew               VARCHAR2(1);
  l_inv                VARCHAR2(60);
  l_tempobjectlist     api.udt_objectlist DEFAULT api.udt_objectlist();
  l_objectlist         api.udt_objectlist DEFAULT api.udt_objectlist();
BEGIN
        EXTENSION.pkg_cxproceduralsearch.initializesearch('j_Application');
        EXTENSION.pkg_cxproceduralsearch.searchbyindex(
            'dup_BaseFileOfficeCorral',
            a_office,
            NULL,
            FALSE);

        IF a_licensenumber IS NOT NULL THEN
            EXTENSION.pkg_cxproceduralsearch.searchbyindex(
                'dup_LicenseNumber',
                a_licensenumber,
                NULL,
                FALSE);
            EXTENSION.pkg_cxproceduralsearch.filterobjects('dup_PremUSCity',
                                                           a_city,
                                                           NULL,
                                                           TRUE);
        ELSIF a_city IS NOT NULL THEN
            EXTENSION.pkg_cxproceduralsearch.searchbyrelatedindex('Premises',
                                                                  'USACity',
                                                                  a_city,
                                                                  NULL,
                                                                  TRUE);
        END IF;

        IF a_county IS NOT NULL THEN
            EXTENSION.pkg_cxproceduralsearch.searchbyrelatedindex(
                'Premises',
                'dup_CountyCode',
                a_county,
                NULL,
                FALSE);
        END IF;

        EXTENSION.pkg_cxproceduralsearch.performsearch(t_objectlist,
                                                       'and',
                                                       'none');

        SELECT api.udt_object(cl.processid)
          BULK COLLECT INTO t_tempobjectlist
          FROM query.p_assignadmininvestigation  cl
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
              FROM query.p_assignadmininvestigation cl
             WHERE cl.externalfilenum = a_investigationnumber;

            IF t_tempobjectlist.COUNT = 0 THEN
                GOTO end_here;
            END IF;

            EXTENSION.pkg_collectionutils.join(t_objectlist,
                                               t_tempobjectlist);

            IF t_objectlist.COUNT = 0 THEN
                GOTO end_here;
            END IF;

            t_tempobjectlist.delete;
        END IF;

        IF a_investigator IS NOT NULL
        OR a_createddatefrom IS NOT NULL
        OR a_createddateto IS NOT NULL THEN    --a_Investigator is not null or
            EXTENSION.pkg_cxproceduralsearch.initializesearch(
                'p_AssignAdminInvestigation');
            EXTENSION.pkg_cxproceduralsearch.searchbysystemcolumn(
                'CreatedDate',
                a_createddatefrom,
                a_createddateto + 1);
            EXTENSION.pkg_cxproceduralsearch.performsearch(t_objectlist,
                                                           'and',
                                                           'and');

            IF t_objectlist.COUNT = 0 THEN
                GOTO end_here;
            END IF;
        END IF;

        FOR i IN 1 .. t_objectlist.COUNT
        LOOP
            t_crew   := liccrewassignment(t_objectlist(i).objectid);

            IF a_includecrewassignments = 'N'
           AND t_crew = 'Y' THEN
                GOTO skip_rec;
            END IF;


            -- populate abc61
            INSERT INTO abc.abc61_t(rptobjectid,
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
                       primarylicensee
                           subj,
                       licensenumber
                           licnum,
                       'LICENSING 61'
                           itype,
                       investigation_number
                           invno,
                       (SELECT startdate
                          FROM abc.v_all_61_application sd
                         WHERE sd.process_type = 'Assign'
                           AND sd.job_id = a.job_id
                           AND sd.assign_pid = t_objectlist(i).objectid)
                           assgndate,
                       process_id
                           objectid,
                       (SELECT CASE
                                   WHEN n.assignstaffname IS NULL THEN
                                       n.dup_licensingrepresentative
                                   WHEN n.assignstaffname !=
                                        n.dup_licensingrepresentative THEN
                                       n.dup_licensingrepresentative
                                   ELSE
                                       n.assignstaffname
                               END
                          FROM abc.v_all_61_application n
                         WHERE n.process_type = 'Conduct'
                           AND n.job_id = a.job_id
                           AND n.investigation_number =
                               a.investigation_number)
                           assgndto,
                       NULL
                           priority,
                       completeddate
                           completeddt,
                       premaddress1line
                           premadd1,
                       districtoffice
                           offccode
                  FROM abc.v_all_61_application a
                 WHERE process_type IN ('Conduct', 'Close') -- don't display Assign recs
                   AND ((NVL(a_activeonly, 'N') = 'Y'
                     AND completeddate IS NULL)         -- ACTIVE RECORDS ONLY
                     /*and 0 = (select count(*)
                                        from ABC.V_ALL_61_APPLICATION c
                                         where c.process_type ='Close'
                                           and c.job_id = a.job_id
                                           and completeddate is not null) )  -- ignore the closed recs */
                     OR ((NVL(a_activeonly, 'N') = 'N'
                      AND completeddate IS NULL) -- ALL OTHER RECORDS - ACTIVE IND NOT SELECTED
                      OR (NVL(a_activeonly, 'N') = 'N'
                      AND completeddate IS NOT NULL
                      AND process_type = 'Close')) --  ALL OTHER RECORDS - ACTIVE IND NOT SELECTED
                                                  )
                   AND job_id IN
                           (SELECT job_id
                              FROM abc.v_all_61_application b
                             WHERE assign_pid = t_objectlist(i).objectid)
                   AND investigation_number IN
                           (SELECT investigation_number
                              FROM abc.v_all_61_application c
                             WHERE c.investigation_number =
                                   a.investigation_number
                               AND assign_pid = t_objectlist(i).objectid)
                   AND ((a_completeddatefrom IS NOT NULL
                     AND completeddate IN
                             (SELECT completeddate
                                FROM abc.v_all_61_application c
                               WHERE c.process_type = 'Close'
                                 AND c.job_id = a.job_id
                                 AND TRUNC(completeddate) BETWEEN TRUNC(
                                                                      a_completeddatefrom)
                                                              AND TRUNC(
                                                                      a_completeddateto)))
                     OR a_completeddatefrom IS NULL);

           <<skip_rec>>
            NULL;
        END LOOP;

       <<end_here>>
        t_objectlist.delete;
END Get61AdmAssignments;

----------------------------------------------------
FUNCTION getliccompleteddate(a_objectid udt_id)
----------------------------------------------------
RETURN DATE
IS
  t_completeddate         DATE;
  t_jobid                 udt_id;
  t_investigationnumber   VARCHAR2(15);
BEGIN
  BEGIN
    SELECT 
      TRUNC(p.datecompleted),
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

------------------------------------------------------------
FUNCTION getenfcompleteddate(a_objectid udt_id)
------------------------------------------------------------
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
END pkg_abcreports_61adhoc;
/


GRANT EXECUTE, DEBUG ON ABC.PKG_ABCREPORTS_61ADHOC TO KAURP;

GRANT EXECUTE ON ABC.PKG_ABCREPORTS_61ADHOC TO POSSEEXTENSIONS;
