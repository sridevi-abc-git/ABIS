CREATE OR REPLACE package body ABC.pkg_ABCReports_61BAT is

  procedure ABC61BatchMultiPrint (
    a_ObjectId udt_Id
  ) is
    t_TakenOn date;
    t_SupervisorAssignedOn date;
    t_CommentsDate date;
    t_ActiveOnly char(1);
    t_InvestigationType varchar2(50);
    t_Investigator varchar2(60);
    t_UserId udt_id;
    t_ObjectIds api.udt_objectlist default api.udt_objectlist();
  begin
    begin
      select o.TakenOn,
             o.SupervisorAssignedOn,
             o.CommentsDate,
             o.ActiveOnly,
             o.InvestigationType,
             o.Investigator,
             r.userid
        into t_TakenOn,
             t_SupervisorAssignedOn,
             t_CommentsDate,
             t_ActiveOnly,
             t_InvestigationType,
             t_Investigator,
             t_UserId
        from query.o_abc61batchmultiprint o
       left outer join query.r_Abc61batchinvestigatorlr r on r.ABC61BatchObjectId = o.ObjectId
       where o.objectid = a_ObjectId;
    exception when no_data_found then
      api.pkg_errors.RaiseError(-20000,'Invalid ObjectId, not found in query.o_abc61batchmultiprint');
    end;

    if t_Investigator is not null then
      t_Investigator := '%'||t_Investigator;
    end if;

  /*
  NOTE: If the above criterea is not entered in the search object then t_ObjectIds will be
  null and the SQL that is written will have to search everything. But if there are values
  entered above then the SQL will just need to limit the object ids further.
  */

    delete ABC61_t;
    delete ABC61_Det_t;

    Populate61Batch (
                         a_ObjectId,
                         t_TakenOn,
                         t_SupervisorAssignedOn,
                         t_CommentsDate,
                         t_ActiveOnly,
                         t_InvestigationType,
                         t_Investigator,
                         t_UserId,
                         null);

  end ABC61BatchMultiPrint;

  procedure Populate61Batch (
    a_ObjectId udt_Id,
    a_TakenOn date,
    a_SupervisorAssignedOn date,
    a_CommentsDate date,
    a_ActiveOnly char,
    a_InvestigationType varchar2,
    a_Investigator varchar2,
    a_UserId udt_id,
    a_ObjectIds api.udt_objectlist
  )
  is
    t_ObjectIds api.udt_objectlist;

    t_SQL_enf varchar2(4000);
    t_SQL_lic varchar2(4000);
    t_filter1 varchar2(4000);
    t_filter2 varchar2(4000);
    t_SQL_enflog varchar2(4000);
    t_SQL_liclog varchar2(4000);

  begin
/*
    Enforcement Investigation
*/
    Get61ENFBatch (
            a_ObjectId,
            a_TakenOn,
            a_SupervisorAssignedOn,
            a_CommentsDate,
            a_ActiveOnly,
            a_InvestigationType,
            a_Investigator,
            a_UserId,
        null);
/*
    Licensing Investigation
*/
    if a_InvestigationType is null then
        Get61LICBatch (
            a_ObjectId,
            a_TakenOn,
            a_SupervisorAssignedOn,
            a_CommentsDate,
            a_ActiveOnly,
            a_InvestigationType,
            a_Investigator,
            a_UserId,
            null);
    end if;
/*
    LR/Investigator Logs
*/
    Get61LogBatch (
            a_ObjectId,
            a_TakenOn,
            a_SupervisorAssignedOn,
            a_CommentsDate,
            a_ActiveOnly,
            a_InvestigationType,
            a_Investigator,
            a_UserId,
        null);

  end Populate61Batch;

  procedure Get61ENFBatch (
    a_ObjectId udt_Id,
    a_TakenOn date,
    a_SupervisorAssignedOn date,
    a_CommentsDate date,
    a_ActiveOnly char,
    a_InvestigationType varchar2,
    a_Investigator varchar2,
    a_UserId udt_id,
    a_ObjectIds api.udt_objectlist
  )
  is

  begin
        INSERT INTO ABC.ABC61_T(rptobjectid,
                                        premadd,
                                        subj,
                                        licnum,
                                        pdba,
                                        itype,
                                        invno,
                                        assgndate,
                                        origin,
                                        origintype,
                                        offc,
                                        typecode,
                                        cmptyp,
                                        admintyp,
                                        ttype,
                                        cmpdate,
                                        objectid,
                                        assgndto,
                                        assgninstructions,
                                        abc61date,
                                        type_det,
                                        priority,
                                        completeddt,
                                        premadd1,
                                        offccode
           )
           SELECT a_ObjectId,
                  CASE
                     WHEN jinv.isunlicensedinvestigation = 'Y'
                        THEN jinv.complaintaddress
                     ELSE jinv.licensepremiseaddress4lines
                  END premadd,
                  jinv.licenseprimarylicensee subj, jinv.licensenumber licnum,
                  jinv.licenseprimarydba pdba, jinv.investigationtype itype,
                  jinv.investigationnumber invno,
                  NVL((SELECT pr.createddate
                     FROM api.processes pr
                    WHERE pr.processid = jinv.assignprocessid),
                  jinv.createddate) assgndate,
                  DECODE (UPPER (jinv.origintype),
                          'ANONYMOUS', jinv.origintype,
                          NVL (jinv.complaintcontactname, jinv.origintype)
                         ) origin,
                  jinv.origintype origintype,
                  UPPER (SUBSTR (jinv.investigationoffice,
                                 INSTR (jinv.investigationoffice, ':', 1) + 2
                                )
                        ) offc,
                  jinv.licensetypecodes typecode, jinv.complainttype cmptyp,
                  jinv.administrativetype admintyp, jinv.TYPE ttype,
                  jinv.complaintdate cmpdate, jinv.jobid objectid,
                  JINV.INVESTIGATORS assgndto,
                  jinv.assignmentdetailsinstructions assgninstructions,
                  jinv.createddate abc61date, jinv.TYPE type_det,
                  JINV.DEPARTMENTPRIORITY priority,
                  JINV.COMPLETEDDATE completeddt,
                  JINV.LICENSEPREMISEADDRESS1LINE premadd1,
                  SUBSTR(JINV.INVESTIGATIONOFFICECORRAL,1,2) offccode
        FROM QUERY.J_INVESTIGATION JINV
        -- Search Criteria
        WHERE (a_TakenOn IS NULL AND a_InvestigationType IS NULL AND a_Investigator IS NULL
           OR (a_TakenOn IS NOT NULL OR a_InvestigationType IS NOT NULL OR a_Investigator IS NOT NULL)
            AND EXISTS (
                SELECT 1
                    FROM table(Get61ENFObjectList(
                                                    a_TakenOn,
                                                    a_InvestigationType,
                                                    a_Investigator) ) x
                    WHERE x.objectid = JINV.JOBID) )
        -- Supervisor Assigned Date
        AND (a_SupervisorAssignedOn IS NULL
            OR a_SupervisorAssignedOn IS NOT NULL AND EXISTS (
                SELECT 1
                  FROM QUERY.P_ASSIGNINVESTIGATION AI
                 WHERE AI.PROCESSID = JINV.ASSIGNPROCESSID
                   AND TRUNC(AI.CREATEDDATE) =  a_SupervisorAssignedOn))
        -- Comments Date
        AND (a_CommentsDate IS NULL
            OR a_CommentsDate IS NOT NULL AND EXISTS (
                SELECT 1
                  FROM QUERY.L_INVESTIGATIONUSERLOG IL
                  JOIN QUERY.r_investigationinvuserlog R ON r.investigationuserloglogid = il.userlogid
                 WHERE R.INVESTIGATIONJOBID = JINV.JOBID
                   AND TRUNC(IL.LOGDATE) =  a_CommentsDate))
        AND a_ActiveOnly = 'Y' AND JINV.COMPLETEDDATE IS NULL;

  end Get61ENFBatch;

  procedure Get61LICBatch (
    a_ObjectId udt_Id,
    a_TakenOn date,
    a_SupervisorAssignedOn date,
    a_CommentsDate date,
    a_ActiveOnly char,
    a_InvestigationType varchar2,
    a_Investigator varchar2,
    a_UserId udt_id,
    a_ObjectIds api.udt_objectlist
  )
  is

  begin
        INSERT INTO ABC.ABC61_T(rptobjectid,
                                        premadd,
                                        subj,
                                        licnum,
                                        pdba,
                                        itype,
                                        invno,
                                        assgndate,
                                        origin,
                                        origintype,
                                        offc,
                                        typecode,
                                        cmptyp,
                                        admintyp,
                                        ttype,
                                        cmpdate,
                                        objectid,
                                        assgndto,
                                        assgninstructions,
                                        abc61date,
                                        type_det,
                                        priority,
                                        completeddt,
                                        premadd1,
                                        offccode
           )
        SELECT a_ObjectId,
              CASE
                 WHEN pr.processtypeid = api.pkg_configquery.objectdefidforname('p_ConductLicenseInvestigation') THEN
                        api.pkg_columnquery.VALUE (pr.jobid,'PremisesAddress4Line')
                 WHEN pr.processtypeid = api.pkg_configquery.objectdefidforname('p_ConductAdminInvestigation') THEN
                        api.pkg_columnquery.VALUE (pr.jobid, 'PremAddress4Line')
                 ELSE NULL
              END premadd,
              api.pkg_columnquery.VALUE (pr.jobid, 'PrimaryLicensee') subj,
              api.pkg_columnquery.VALUE (pr.jobid, 'LicenseNumber') licnum,
              api.pkg_columnquery.VALUE (pr.jobid, 'PrimaryDba') pdba,
              'LICENSING 61' itype,
              api.pkg_columnquery.VALUE (pr.processid, 'ExternalFileNum') invno,
              NVL(CASE
                 WHEN pr.processtypeid = api.pkg_configquery.objectdefidforname('p_ConductLicenseInvestigation') THEN
                        (SELECT pr2.createddate
                           FROM QUERY.p_conductlicenseinvestigation cli
                           JOIN api.processes pr2 ON pr2.processid = cli.assignprocessid
                          WHERE cli.processid = pr.processid)
                 WHEN pr.processtypeid = api.pkg_configquery.objectdefidforname('p_ConductAdminInvestigation') THEN
                        (SELECT pr3.createddate
                           FROM QUERY.p_conductadmininvestigation cai
                           JOIN api.processes pr3 ON pr3.processid = cai.assignprocessid
                          WHERE cai.processid = pr.processid)
                 ELSE NULL
              END,
              pr.createddate) assgndate,
              NULL origin,
              NULL origintype,
              CASE
                 WHEN pr.processtypeid = api.pkg_configquery.objectdefidforname('p_ConductLicenseInvestigation') THEN
                        api.pkg_columnquery.VALUE (pr.jobid,'BaseFileOfficeName')
                 WHEN pr.processtypeid = api.pkg_configquery.objectdefidforname('p_ConductAdminInvestigation') THEN
                        api.pkg_columnquery.VALUE(
                            api.pkg_columnquery.VALUE(pr.processid,'InvestigationOfficeObjectId'),
                            'OfficeName')
                 ELSE NULL
              END offc,
              api.pkg_columnquery.VALUE(pr.jobid,'UniqueLicenseTypeCodes') typecode,
              NULL cmptyp,
              NULL admintyp,
              NULL ttype,
              pr.createddate cmpdate,
              pr.processid objectid,
              Api.pkg_columnquery.value(PR.PROCESSID,'AssignedToName') assgndto,
              api.pkg_columnquery.VALUE(pr.processid,'AssignmentInstructions') assgninstructions,
              pr.createddate abc61date,
              CASE
                 WHEN pr.processtypeid = api.pkg_configquery.objectdefidforname('p_ConductLicenseInvestigation') THEN
                        api.pkg_columnquery.VALUE (pr.processid, 'AdminTypes')
                 WHEN pr.processtypeid = api.pkg_configquery.objectdefidforname('p_ConductAdminInvestigation') THEN
                        api.pkg_columnquery.VALUE (pr.processid,'LicensingAdminTypes')
                 ELSE NULL
              END type_det,
              NULL priority,
              PR.DATECOMPLETED completeddt,
              Api.pkg_columnquery.value(PR.JOBID,'PremAddress1Line') premadd1,
              CASE
                 WHEN pr.processtypeid = api.pkg_configquery.objectdefidforname('p_ConductLicenseInvestigation') THEN
                        SUBSTR(api.pkg_columnquery.VALUE (pr.processid, 'BaseFileOfficeCorral'),1,2)
                 WHEN pr.processtypeid = api.pkg_configquery.objectdefidforname('p_ConductAdminInvestigation') THEN
                        NVL(Api.pkg_columnquery.value(api.pkg_columnquery.VALUE (pr.processid,'InvestigationOfficeObjectid'),'OfficeCode'),
                            SUBSTR(api.pkg_columnquery.VALUE (pr.processid,'DistrictOfficeCorral'),1,2))
                 ELSE NULL
              END offccode
        FROM API.PROCESSES PR
        WHERE pr.processtypeid IN
                (api.pkg_configquery.objectdefidforname('p_ConductLicenseInvestigation'),
                    api.pkg_configquery.objectdefidforname('p_ConductAdminInvestigation') )
        -- Search Criteria
        AND (a_Investigator IS NULL
           OR a_Investigator IS NOT NULL AND EXISTS (
                SELECT 1
                  FROM table(Get61LICObjectList(a_Investigator) ) x
                 WHERE x.objectid = PR.PROCESSID) )
        -- Assigned On
        AND (a_SupervisorAssignedOn IS NULL
            OR a_SupervisorAssignedOn IS NOT NULL AND EXISTS (
                SELECT 1
                  FROM API.PROCESSES X
                 WHERE X.processtypeid IN
                                    (api.pkg_configquery.objectdefidforname('p_AssignLicenseInvestigation'),
                                        api.pkg_configquery.objectdefidforname('p_AssignAdminInvestigation') )
                   AND X.PROCESSID = api.pkg_columnquery.VALUE (PR.PROCESSID, 'AssignProcessId')
                   AND TRUNC(X.CREATEDDATE ) = a_SupervisorAssignedOn) )
        -- Comments Date
        AND (a_CommentsDate IS NULL
            OR a_CommentsDate IS NOT NULL AND EXISTS (
                SELECT 1
                  FROM QUERY.L_LRUSERLOG L
                 WHERE L.REFERENCEDOBJECTID = PR.PROCESSID
                   AND TRUNC(L.LOGDATE) = a_CommentsDate ) )
        -- Taken On
        AND (a_TakenOn IS NULL OR TRUNC(PR.CREATEDDATE) = a_TakenOn )
        -- Active
        AND a_ActiveOnly = 'Y' AND PR.DATECOMPLETED IS NULL;

  end Get61LICBatch;

  procedure Get61LogBatch (
    a_ObjectId udt_Id,
    a_TakenOn date,
    a_SupervisorAssignedOn date,
    a_CommentsDate date,
    a_ActiveOnly char,
    a_InvestigationType varchar2,
    a_Investigator varchar2,
    a_UserId udt_id,
    a_ObjectIds api.udt_objectlist
  )
    is

  begin
        -- Investigation Log
        INSERT INTO ABC.ABC61_DET_T(INVESTIGATOR,
                                    LOGDATE,
                                    INVCOMMENTS,
                                    STARTTIME,
                                    ENDTIME,
                                    OBJECTID,
                                    RPTOBJECTID
                                   )
        SELECT
              Api.pkg_columnquery.value(UL.USERLOGID,'UserName') investigator,
              UL.LOGDATE logdate,
              CASE
                  WHEN UL.USERLOGTYPEID = api.pkg_configquery.objectdefidforname('l_InvestigationUserLog') THEN
                      Api.pkg_columnquery.value(UL.USERLOGID,'InvestigatorComments')
                  WHEN UL.USERLOGTYPEID = api.pkg_configquery.objectdefidforname('l_LRUserLog') THEN
                      Api.pkg_columnquery.value(UL.USERLOGID,'Comments')
              END invcomments,
              Api.pkg_columnquery.value(UL.USERLOGID,'StartTime') starttime,
              Api.pkg_columnquery.value(UL.USERLOGID,'EndTime') endtime,
              UL.REFERENCEDOBJECTID objid,
              a_ObjectId
        FROM ABC.ABC61_T j
        JOIN (  SELECT UL.LOGDATE,NVL(UL.REFERENCEDOBJECTID,R.INVESTIGATIONJOBID) REFERENCEDOBJECTID,
                        UL.USERID, UL.USERLOGID, UL.USERLOGTYPEID
                  FROM API.USERLOGS UL
                  LEFT OUTER JOIN QUERY.r_investigationinvuserlog R ON r.investigationuserloglogid = UL.USERLOGID ) UL
                            ON UL.REFERENCEDOBJECTID = J.OBJECTID;

  end Get61LogBatch;

  function Get61ENFObjectList(
    a_TakenOn date,
    a_InvestigationType varchar2,
    a_Investigator varchar2
  ) return api.udt_ObjectList
    is
    t_Objectids  api.udt_ObjectList default api.udt_ObjectList();
  begin

    extension.pkg_cxproceduralsearch.InitializeSearch('j_Investigation');
    extension.pkg_cxproceduralsearch.SearchByJob(null, null, null, null, a_TakenOn , a_TakenOn, null, null, null,null);
    extension.pkg_cxproceduralsearch.SearchByIndex('InvestigationType', a_InvestigationType, null, false);
    extension.pkg_cxproceduralsearch.SearchByIndex('dup_Investigators', a_Investigator, null, true);
    extension.pkg_cxproceduralsearch.PerformSearch(t_ObjectIds, 'and', 'none');

    return t_Objectids;
  end Get61ENFObjectList;

  function Get61LICObjectList(
    a_Investigator varchar2
  ) return api.udt_ObjectList
    is
    t_Objectids  api.udt_ObjectList default api.udt_ObjectList();
  begin

    extension.pkg_cxproceduralsearch.InitializeSearch('p_ConductAdminInvestigation');
    extension.pkg_cxproceduralsearch.SearchByIndex('dup_LicensingRepresentative', a_Investigator, null, false);
    extension.pkg_cxproceduralsearch.PerformSearch(t_ObjectIds, 'and', 'or');

    extension.pkg_cxproceduralsearch.InitializeSearch('p_ConductLicenseInvestigation');
    extension.pkg_cxproceduralsearch.SearchByIndex('dup_LicensingRepresentative', a_Investigator, null, false);
    extension.pkg_cxproceduralsearch.PerformSearch(t_ObjectIds, 'and', 'or');

    return t_Objectids;

  end Get61LICObjectList;

end pkg_ABCReports_61BAT;

/


GRANT EXECUTE ON ABC.PKG_ABCREPORTS_61BAT TO POSSEEXTENSIONS;
