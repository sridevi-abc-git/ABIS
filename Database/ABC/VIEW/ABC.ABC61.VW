CREATE OR REPLACE FORCE VIEW ABC.ABC61
(PREMADD, SUBJ, LICNUM, PDBA, ITYPE, 
 INVNO, ASSGNDATE, ORIGIN, ORIGINTYPE, OFFC, 
 TYPECODE, CMPTYP, ADMINTYP, TTYPE, CMPDATE, 
 OBJECTID, ASSGNDTO, ASSGNINSTRUCTIONS, ABC61DATE, TYPE_DET)
BEQUEATH DEFINER
AS 
SELECT CASE
               WHEN pr.processtypeid IN
                        (api.pkg_configquery.objectdefidforname(
                             'p_ConductLicenseInvestigation'),
                         api.pkg_configquery.objectdefidforname(
                             'p_AssignLicenseInvestigation')) THEN
                   api.pkg_columnquery.VALUE(pr.jobid,
                                             'PremisesAddress4Line')
               WHEN pr.processtypeid IN
                        (api.pkg_configquery.objectdefidforname(
                             'p_ConductAdminInvestigation'),
                         api.pkg_configquery.objectdefidforname(
                             'p_AssignAdminInvestigation')) THEN
                   api.pkg_columnquery.VALUE(pr.jobid, 'PremAddress4Line')
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
                        api.pkg_configquery.objectdefidforname(
                            'p_ConductLicenseInvestigation') THEN
                       (SELECT pr2.createddate
                          FROM query.p_conductlicenseinvestigation  cli
                               JOIN api.processes pr2
                                   ON pr2.processid = cli.assignprocessid
                         WHERE cli.processid = pr.processid)
                   WHEN pr.processtypeid =
                        api.pkg_configquery.objectdefidforname(
                            'p_ConductAdminInvestigation') THEN
                       (SELECT pr3.createddate
                          FROM query.p_conductadmininvestigation  cai
                               JOIN api.processes pr3
                                   ON pr3.processid = cai.assignprocessid
                         WHERE cai.processid = pr.processid)
                   WHEN pr.processtypeid IN
                            (api.pkg_configquery.objectdefidforname(
                                 'p_AssignLicenseInvestigation'),
                             api.pkg_configquery.objectdefidforname(
                                 'p_AssignAdminInvestigation')) THEN
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
                        (api.pkg_configquery.objectdefidforname(
                             'p_ConductLicenseInvestigation'),
                         api.pkg_configquery.objectdefidforname(
                             'p_AssignLicenseInvestigation')) THEN
                   api.pkg_columnquery.VALUE(pr.jobid, 'BaseFileOfficeName')
               WHEN pr.processtypeid IN
                        (api.pkg_configquery.objectdefidforname(
                             'p_ConductAdminInvestigation'),
                         api.pkg_configquery.objectdefidforname(
                             'p_AssignAdminInvestigation')) THEN
                   api.pkg_columnquery.VALUE(
                       api.pkg_columnquery.VALUE(
                           pr.processid,
                           'InvestigationOfficeObjectId'),
                       'OfficeName')
               ELSE
                   NULL
           END
               offc,
           api.pkg_columnquery.VALUE(pr.jobid, 'UniqueLicenseTypeCodes')
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
           api.pkg_columnquery.VALUE(pr.processid, 'LicensingRepresentative')
               assgndto,
           api.pkg_columnquery.VALUE(pr.processid, 'AssignmentInstructions')
               assgninstructions,
           pr.createddate
               abc61date,
           CASE
               WHEN pr.processtypeid IN
                        (api.pkg_configquery.objectdefidforname(
                             'p_ConductLicenseInvestigation'),
                         api.pkg_configquery.objectdefidforname(
                             'p_AssignLicenseInvestigation')) THEN
                   api.pkg_columnquery.VALUE(pr.processid, 'AdminTypes')
               WHEN pr.processtypeid IN
                        (api.pkg_configquery.objectdefidforname(
                             'p_ConductAdminInvestigation'),
                         api.pkg_configquery.objectdefidforname(
                             'p_AssignAdminInvestigation')) THEN
                   api.pkg_columnquery.VALUE(pr.processid,
                                             'LicensingAdminTypes')
               ELSE
                   NULL
           END
               type_det
      FROM api.processes  pr
           JOIN
           (SELECT CASE
                       WHEN pr.processtypeid IN
                                (api.pkg_configquery.objectdefidforname(
                                     'p_ConductLicenseInvestigation'),
                                 api.pkg_configquery.objectdefidforname(
                                     'p_ConductAdminInvestigation')) THEN
                           pr.processid
                       WHEN pr.processtypeid =
                            api.pkg_configquery.objectdefidforname(
                                'p_AssignLicenseInvestigation') THEN
                           NVL(
                               (SELECT NULL
                                  FROM query.p_conductlicenseinvestigation
                                       cli2
                                 WHERE cli2.assignprocessid = pr.processid),
                               pr.processid)
                       WHEN pr.processtypeid =
                            api.pkg_configquery.objectdefidforname(
                                'p_AssignAdminInvestigation') THEN
                           NVL((SELECT NULL
                                  FROM query.p_conductadmininvestigation cai2
                                 WHERE cai2.assignprocessid = pr.processid),
                               pr.processid)
                       ELSE
                           NULL
                   END
                       objectid,
                   pr.processid
              FROM api.processes pr) x
               ON x.objectid = pr.processid
    UNION
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
      FROM query.j_investigation jinv;


GRANT SELECT ON ABC.ABC61 TO POSSEEXTENSIONS;
