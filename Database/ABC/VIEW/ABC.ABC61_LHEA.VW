CREATE OR REPLACE FORCE VIEW ABC.ABC61_LHEA
(PREMADD, SUBJ, LICNUM, PDA, ITYPE, 
 INVNO, ASSGNDATE, ORIGIN, ORIGINTYPE, OFFC, 
 TYPECODE, CMPTYP, ADMINTYP, TTYPE, CMPDATE, 
 OBJECTID, ASSGNDTO, ASSGNINSTRUCTIONS, ABC61DATE, TYPE_DET)
BEQUEATH DEFINER
AS 
SELECT
    CASE
        WHEN PR.PROCESSTYPEID IN (api.pkg_configquery.ObjectDefIdForName('p_ConductLicenseInvestigation'),
                                    api.pkg_configquery.ObjectDefIdForName('p_AssignLicenseInvestigation')) THEN
            Api.pkg_columnquery.value(PR.JOBID,'PremisesAddress4Line')
        WHEN PR.PROCESSTYPEID IN (api.pkg_configquery.ObjectDefIdForName('p_ConductAdminInvestigation'),
                                    api.pkg_configquery.ObjectDefIdForName('p_AssignAdminInvestigation')) THEN
            Api.pkg_columnquery.value(PR.JOBID,'PremAddress4Line')
        ELSE NULL
    END premadd,
    Api.pkg_columnquery.value(PR.JOBID,'PrimaryLicensee') subj,
    Api.pkg_columnquery.value(PR.JOBID,'LicenseNumber') licnum,
    Api.pkg_columnquery.value(PR.JOBID,'PrimaryDba') pda,
    'LICENSING 61' itype,
    Api.pkg_columnquery.value(PR.PROCESSID,'ExternalFileNum') invno,
    CASE
        WHEN PR.PROCESSTYPEID = api.pkg_configquery.ObjectDefIdForName('p_ConductLicenseInvestigation') THEN
            (SELECT PR2.CREATEDDATE
                FROM QUERY.P_CONDUCTLICENSEINVESTIGATION CLI
                    JOIN API.PROCESSES PR2 ON PR2.PROCESSID = CLI.ASSIGNPROCESSID
                        WHERE CLI.PROCESSID = PR.PROCESSID)
        WHEN PR.PROCESSTYPEID = api.pkg_configquery.ObjectDefIdForName('p_ConductAdminInvestigation') THEN
            (SELECT PR3.CREATEDDATE
                FROM QUERY.P_CONDUCTADMININVESTIGATION CAI
                    JOIN API.PROCESSES PR3 ON PR3.PROCESSID = CAI.ASSIGNPROCESSID
                        WHERE CAI.PROCESSID = PR.PROCESSID)
        WHEN PR.PROCESSTYPEID IN (api.pkg_configquery.ObjectDefIdForName('p_AssignLicenseInvestigation'),
                                    api.pkg_configquery.ObjectDefIdForName('p_AssignAdminInvestigation')) THEN
            PR.CREATEDDATE
        ELSE NULL
    END assgndate,
    NULL origin,
    NULL origintype,
    CASE
        WHEN PR.PROCESSTYPEID IN (api.pkg_configquery.ObjectDefIdForName('p_ConductLicenseInvestigation'),
                                    api.pkg_configquery.ObjectDefIdForName('p_AssignLicenseInvestigation')) THEN
            Api.pkg_columnquery.value(PR.JOBID,'BaseFileOfficeName')
        WHEN PR.PROCESSTYPEID IN (api.pkg_configquery.ObjectDefIdForName('p_ConductAdminInvestigation'),
                                    api.pkg_configquery.ObjectDefIdForName('p_AssignAdminInvestigation')) THEN
            Api.pkg_columnquery.value(Api.pkg_columnquery.value(PR.PROCESSID,'InvestigationOfficeObjectId'),'OfficeName')
        ELSE NULL
    END offc,
    Api.pkg_columnquery.value(PR.JOBID,'UniqueLicenseTypeCodes') typecode,
    NULL cmptyp,
    NULL admintyp,
    NULL ttype,
    PR.CREATEDDATE  cmpdate,
    PR.PROCESSID objectid,
    Api.pkg_columnquery.value(PR.PROCESSID,'LicensingRepresentative') assgndto,
    Api.pkg_columnquery.value(PR.PROCESSID,'AssignmentInstructions') assgninstructions,
    PR.CREATEDDATE ABC61Date,
    CASE
        WHEN PR.PROCESSTYPEID IN (api.pkg_configquery.ObjectDefIdForName('p_ConductLicenseInvestigation'),
                                    api.pkg_configquery.ObjectDefIdForName('p_AssignLicenseInvestigation')) THEN
            Api.pkg_columnquery.value(PR.PROCESSID,'AdminTypes')
        WHEN PR.PROCESSTYPEID IN (api.pkg_configquery.ObjectDefIdForName('p_ConductAdminInvestigation'),
                                    api.pkg_configquery.ObjectDefIdForName('p_AssignAdminInvestigation')) THEN
            Api.pkg_columnquery.value(PR.PROCESSID,'LicensingAdminTypes')
        ELSE NULL
    END type_det
FROM API.PROCESSES PR
JOIN (SELECT
            CASE
                WHEN PR.PROCESSTYPEID IN (api.pkg_configquery.ObjectDefIdForName('p_ConductLicenseInvestigation'),
                                            api.pkg_configquery.ObjectDefIdForName('p_ConductAdminInvestigation')) THEN
                    PR.PROCESSID
                WHEN PR.PROCESSTYPEID = api.pkg_configquery.ObjectDefIdForName('p_AssignLicenseInvestigation') THEN
                    NVL((SELECT NULL
                        FROM QUERY.P_CONDUCTLICENSEINVESTIGATION CLI2
                            WHERE CLI2.ASSIGNPROCESSID = PR.PROCESSID),
                         PR.PROCESSID)
                WHEN PR.PROCESSTYPEID = api.pkg_configquery.ObjectDefIdForName('p_AssignAdminInvestigation') THEN
                    NVL((SELECT NULL
                        FROM QUERY.P_CONDUCTADMININVESTIGATION CAI2
                            WHERE CAI2.ASSIGNPROCESSID = PR.PROCESSID),
                         PR.PROCESSID)
                ELSE NULL
            END OBJECTID,
            PR.PROCESSID
        FROM API.PROCESSES PR) X ON X.OBJECTID = PR.PROCESSID
UNION
SELECT
    CASE
        WHEN JINV.ISUNLICENSEDINVESTIGATION = 'Y' THEN
            JINV.COMPLAINTADDRESS
        ELSE
            JINV.LICENSEPREMISEADDRESS4LINES
    END premadd,
    JINV.LICENSEPRIMARYLICENSEE subj,
    JINV.LICENSENUMBER licnum,
    JINV.LICENSEPRIMARYDBA pdba,
    JINV.INVESTIGATIONTYPE itype,
    JINV.INVESTIGATIONNUMBER invno,
    (SELECT PR.CREATEDDATE
     FROM API.PROCESSES PR
    WHERE PR.PROCESSID = JINV.ASSIGNPROCESSID ) assgndate,
    DECODE(UPPER(JINV.ORIGINTYPE),'ANONYMOUS',JINV.ORIGINTYPE,NVL(JINV.COMPLAINTCONTACTNAME,JINV.ORIGINTYPE)) origin,
    JINV.ORIGINTYPE origintype,
    UPPER(SUBSTR(JINV.INVESTIGATIONOFFICE,INSTR(JINV.INVESTIGATIONOFFICE,':',1)+2)) offc,
    JINV.LICENSETYPECODES typecode,
    JINV.COMPLAINTTYPE cmptyp,
    JINV.ADMINISTRATIVETYPE admintyp,
    JINV.TYPE ttype,
    JINV.COMPLAINTDATE cmpdate,
    JINV.JOBID objectid,
    (SELECT AI.ASSIGNMENTS61NAME
       FROM QUERY.P_ASSIGNINVESTIGATION AI
      WHERE AI.PROCESSID = JINV.ASSIGNPROCESSID ) assgndto,
    JINV.ASSIGNMENTDETAILSINSTRUCTIONS assgninstructions,
    JINV.CREATEDDATE ABC61Date,
    JINV.TYPE type_det
FROM QUERY.J_INVESTIGATION jinv;
