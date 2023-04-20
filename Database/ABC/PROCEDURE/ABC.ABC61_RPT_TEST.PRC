CREATE OR REPLACE PROCEDURE ABC.abc61_rpt_test(
    a_objectid      api.pkg_definition.udt_id)
AS
    -- **************************************************************************
    -- File:        ABC61_RPT_TEST.PRC
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
    t_conductlicenseinvestigation   api.pkg_definition.udt_id
        := api.pkg_configquery.objectdefidforname(
               'p_ConductLicenseInvestigation');
    t_assignlicenseinvestigation    api.pkg_definition.udt_id
        := api.pkg_configquery.objectdefidforname(
               'p_AssignLicenseInvestigation');
    t_conductadmininvestigation     api.pkg_definition.udt_id
        := api.pkg_configquery.objectdefidforname(
               'p_ConductAdminInvestigation');
    t_assignadmininvestigation      api.pkg_definition.udt_id
        := api.pkg_configquery.objectdefidforname(
               'p_AssignAdminInvestigation');
    t_investigation                 api.pkg_definition.udt_id
        := api.pkg_configquery.objectdefidforname('j_Investigation');
    t_objecttypeid                  api.pkg_definition.udt_id;
BEGIN
    --delete from abc61_t;
    DELETE FROM abc.abc61_individual_t_test;

    DELETE FROM abc.abc61_det_individual_t_test;

    COMMIT;

    BEGIN
        SELECT o.objectdefid
          INTO t_objecttypeid
          FROM api.objects o
         WHERE o.objectid = a_objectid;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            t_objecttypeid   := NULL;
    END;

    IF t_objecttypeid = t_investigation THEN
        INSERT INTO abc.abc61_individual_t_test(premadd,
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
                                                type_det)
            SELECT CASE
                       WHEN jinv.isunlicensedinvestigation = 'Y' THEN
                           jinv.complaintaddress
                       ELSE
                           jinv.licensepremiseaddress4lines
                   END
                       premadd,
                   jinv.licenseprimarylicensee
                       subj,
                   jinv.licensenumber
                       licnum,
                   jinv.licenseprimarydba
                       pdba,
                   jinv.investigationtype
                       itype,
                   jinv.investigationnumber
                       invno,
                   NVL((SELECT pr.createddate
                          FROM api.processes pr
                         WHERE pr.processid = jinv.assignprocessid),
                       jinv.createddate)
                       assgndate,
                   DECODE(UPPER(jinv.origintype),
                          'ANONYMOUS', jinv.origintype,
                          NVL(jinv.complaintcontactname, jinv.origintype))
                       origin,
                   jinv.origintype
                       origintype,
                   UPPER(
                       SUBSTR(jinv.investigationoffice,
                              INSTR(jinv.investigationoffice, ':', 1) + 2))
                       offc,
                   jinv.licensetypecodes
                       typecode,
                   jinv.complainttype
                       cmptyp,
                   jinv.administrativetype
                       admintyp,
                   jinv.TYPE
                       ttype,
                   jinv.complaintdate
                       cmpdate,
                   jinv.jobid
                       objectid,
                   jinv.investigators
                       assgndto,
                   jinv.assignmentdetailsinstructions
                       assgninstructions,
                   jinv.createddate
                       abc61date,
                   jinv.TYPE
                       type_det
              FROM query.j_investigation jinv
             WHERE jinv.jobid = a_objectid;

        INSERT INTO abc61_det_individual_t_test(investigator,
                                                logdate,
                                                invcomments,
                                                starttime,
                                                endtime,
                                                objectid)
            SELECT liul.username             investigator,
                   liul.logdate              logdate,
                   liul.investigatorcomments invcomments,
                   liul.starttime            starttime,
                   liul.endtime              endtime,
                   riiul.investigationjobid  objectid
              FROM query.r_investigationinvuserlog  riiul
                   JOIN query.l_investigationuserlog liul
                       ON liul.userlogid = riiul.investigationuserloglogid
             WHERE riiul.investigationjobid = a_objectid;
    ELSE
        INSERT INTO abc.abc61_individual_t_test(premadd,
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
                                                type_det)
            SELECT CASE
                       WHEN pr.processtypeid IN
                                (t_conductlicenseinvestigation,
                                 t_assignlicenseinvestigation) THEN
                           api.pkg_columnquery.VALUE(pr.jobid,
                                                     'PremisesAddress4Line')
                       WHEN pr.processtypeid IN
                                (t_conductadmininvestigation,
                                 t_assignadmininvestigation) THEN
                           api.pkg_columnquery.VALUE(pr.jobid,
                                                     'PremAddress4Line')
                       ELSE
                           NULL
                   END
                       premadd,
                   api.pkg_columnquery.VALUE(pr.jobid, 'PrimaryLicensee')
                       subj,
                   api.pkg_columnquery.VALUE(pr.jobid, 'LicenseNumber')
                       licnum,
                   api.pkg_columnquery.VALUE(pr.jobid, 'PrimaryDba')
                       pdba,
                   'LICENSING 61'
                       itype,
                   api.pkg_columnquery.VALUE(pr.processid, 'ExternalFileNum')
                       invno,
                   NVL(
                       CASE
                           WHEN pr.processtypeid =
                                t_conductlicenseinvestigation THEN
                               (SELECT pr2.createddate
                                  FROM query.p_conductlicenseinvestigation
                                       cli
                                       JOIN api.processes pr2
                                           ON pr2.processid =
                                              cli.assignprocessid
                                 WHERE cli.processid = pr.processid)
                           WHEN pr.processtypeid =
                                t_conductadmininvestigation THEN
                               (SELECT pr3.createddate
                                  FROM query.p_conductadmininvestigation  cai
                                       JOIN api.processes pr3
                                           ON pr3.processid =
                                              cai.assignprocessid
                                 WHERE cai.processid = pr.processid)
                           WHEN pr.processtypeid IN
                                    (t_assignlicenseinvestigation,
                                     t_assignadmininvestigation) THEN
                               pr.createddate
                           ELSE
                               NULL
                       END,
                       pr.createddate)
                       assgndate,
                   NULL
                       origin,
                   NULL
                       origintype,
                   CASE
                       WHEN pr.processtypeid IN
                                (t_conductlicenseinvestigation,
                                 t_assignlicenseinvestigation) THEN
                           api.pkg_columnquery.VALUE(pr.jobid,
                                                     'BaseFileOfficeName')
                       WHEN pr.processtypeid IN
                                (t_conductadmininvestigation,
                                 t_assignadmininvestigation) THEN
                           api.pkg_columnquery.VALUE(
                               api.pkg_columnquery.VALUE(
                                   pr.processid,
                                   'InvestigationOfficeObjectId'),
                               'OfficeName')
                       ELSE
                           NULL
                   END
                       offc,
                   api.pkg_columnquery.VALUE(pr.jobid,
                                             'UniqueLicenseTypeCodes')
                       typecode,
                   NULL
                       cmptyp,
                   NULL
                       admintyp,
                   NULL
                       ttype,
                   pr.createddate
                       cmpdate,
                   pr.processid
                       objectid,
                   --Api.pkg_columnquery.value(PR.PROCESSID,'LicensingRepresentative') assgndto, --original code, take out by Bee 12/20/2011
                   CASE                 --this is the new code by bee 12/20/11
                       WHEN getuseroralogonid(
                                api.pkg_columnquery.VALUE(
                                    pr.processid,
                                    'LicensingRepresentative')) <>
                            pr.assignedstaff
                        AND pr.assignedstaff IS NOT NULL THEN
                           NVL(
                               getusername(pr.assignedstaff),
                               api.pkg_columnquery.VALUE(
                                   pr.processid,
                                   'LicensingRepresentative'))
                       ELSE
                           api.pkg_columnquery.VALUE(
                               pr.processid,
                               'LicensingRepresentative')
                   END
                       assgndto,
                   api.pkg_columnquery.VALUE(pr.processid,
                                             'AssignmentInstructions')
                       assgninstructions,
                   pr.createddate
                       abc61date,
                   CASE
                       WHEN pr.processtypeid IN
                                (t_conductlicenseinvestigation,
                                 t_assignlicenseinvestigation) THEN
                           api.pkg_columnquery.VALUE(pr.processid,
                                                     'AdminTypes')
                       WHEN pr.processtypeid IN
                                (t_conductadmininvestigation,
                                 t_assignadmininvestigation) THEN
                           api.pkg_columnquery.VALUE(pr.processid,
                                                     'LicensingAdminTypes')
                       ELSE
                           NULL
                   END
                       type_det
              FROM api.processes pr
             WHERE pr.processid = a_objectid
               AND pr.processtypeid IN (t_conductlicenseinvestigation,
                                        t_conductadmininvestigation,
                                        t_assignlicenseinvestigation,
                                        t_assignadmininvestigation); --is this really needed?;

        INSERT INTO abc61_det_individual_t_test(investigator,
                                                logdate,
                                                invcomments,
                                                starttime,
                                                endtime,
                                                objectid)
            SELECT lrl.username  investigator,
                   lrl.logdate   logdate,
                   lrl.comments  invcomments,
                   lrl.starttime starttime,
                   lrl.endtime   endtime,
                   p.processid   objectid
              FROM api.processes  p
                   JOIN query.l_lruserlog lrl
                       ON lrl.referencedobjectid = p.processid
             WHERE p.processid = a_objectid
               AND p.processtypeid IN
                       (t_conductlicenseinvestigation,
                        t_conductadmininvestigation)
            UNION
            SELECT lrl.username  investigator,
                   lrl.logdate   logdate,
                   lrl.comments  invcomments,
                   lrl.starttime starttime,
                   lrl.endtime   endtime,
                   p.processid   objectid
              FROM query.p_assignlicenseinvestigation  a
                   JOIN query.p_conductlicenseinvestigation p
                       ON p.processid = a.assignprocessid
                   JOIN query.l_lruserlog lrl
                       ON lrl.referencedobjectid = p.processid
             WHERE a.processid = a_objectid
            UNION
            SELECT lrl.username  investigator,
                   lrl.logdate   logdate,
                   lrl.comments  invcomments,
                   lrl.starttime starttime,
                   lrl.endtime   endtime,
                   p.processid   objectid
              FROM query.p_assignadmininvestigation  a
                   JOIN query.p_conductadmininvestigation p
                       ON p.processid = a.assignprocessid
                   JOIN query.l_lruserlog lrl
                       ON lrl.referencedobjectid = p.processid
             WHERE a.processid = a_objectid;
    END IF;
END abc61_rpt_test;
/
