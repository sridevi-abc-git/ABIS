CREATE OR REPLACE FORCE VIEW ABC.ABC61_DET
(INVESTIGATOR, LOGDATE, INVCOMMENTS, STARTTIME, ENDTIME, 
 OBJECTID)
BEQUEATH DEFINER
AS 
SELECT LIUL.USERNAME investigator,
      LIUL.LOGDATE logdate,
      LIUL.INVESTIGATORCOMMENTS invcomments,
      LIUL.STARTTIME starttime,
      LIUL.ENDTIME endtime,
      RIIUL.INVESTIGATIONJOBID objectid
FROM QUERY.L_INVESTIGATIONUSERLOG liul
JOIN QUERY.R_INVESTIGATIONINVUSERLOG riiul ON RIIUL.INVESTIGATIONUSERLOGLOGID = LIUL.USERLOGID
UNION
SELECT LRL.USERNAME investigator,
    LRL.LOGDATE logdate,
    LRL.COMMENTS invcomments,
    LRL.STARTTIME starttime,
    LRL.ENDTIME endtime,
    X.PROCESSID objectid
FROM QUERY.L_LRUSERLOG LRL
JOIN (SELECT
            CASE
                WHEN PR.PROCESSTYPEID IN (api.pkg_configquery.ObjectDefIdForName('p_ConductLicenseInvestigation'),
                                            api.pkg_configquery.ObjectDefIdForName('p_ConductAdminInvestigation')) THEN
                    PR.PROCESSID
                WHEN PR.PROCESSTYPEID = api.pkg_configquery.ObjectDefIdForName('p_AssignLicenseInvestigation') THEN
                    NVL((SELECT CLI2.PROCESSID
                        FROM QUERY.P_CONDUCTLICENSEINVESTIGATION CLI2
                            WHERE CLI2.ASSIGNPROCESSID = PR.PROCESSID),
                         PR.PROCESSID)
                WHEN PR.PROCESSTYPEID = api.pkg_configquery.ObjectDefIdForName('p_AssignAdminInvestigation') THEN
                    NVL((SELECT CAI2.PROCESSID
                        FROM QUERY.P_CONDUCTADMININVESTIGATION CAI2
                            WHERE CAI2.ASSIGNPROCESSID = PR.PROCESSID),
                         PR.PROCESSID)
                ELSE NULL
            END OBJECTID,
            PR.PROCESSID
        FROM API.PROCESSES PR) X ON X.OBJECTID = LRL.REFERENCEDOBJECTID;


GRANT SELECT ON ABC.ABC61_DET TO POSSEEXTENSIONS;
