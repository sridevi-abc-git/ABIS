CREATE OR REPLACE FUNCTION ABCREPORTS.workloadsummary(p_parms IN OUT t_parameters, p_status_ind IN OUT VARCHAR2)
    RETURN BLOB
IS
    -- ****************************************************************************
    -- File:        workloadsummary.fnc
    -- Author:      Timothy J. Lord
    --
    -- $Rev: 277 $
    -- $Date: 2019-03-01 11:31:51 -0800 (Fri, 01 Mar 2019) $
    -- Last Changed By:  $Author: tlord $
    --
    -- Description:
    --
    --
    -- History:
    -------------------------------------------------------------------------------
    --    Date                  Comment
    --  02/16/2019  TJL 11362 - Removed POIC accepted from total
    --  02/25/2019  tjl 11362 - Added POIC to other total calculation
    --  03/01/2019  TJL 11362 - Changed query for ACCUSATIONS PART 1 & 2
    --  06/25/2020  TJL 21921 - Changed how priority applications are counted
    --  09/15/2020  TJL 21921 - Changed where revenue stream amounts come from
    --  03/23/2021  TJL 21921 - removed selected license types from query
    --  08/03/2021  TJL       - Change location where data for revenue is retrieve from
    -- ****************************************************************************
    g_switch   DATE := '01-AUG-18';  -- start date to start using docket notes
    g_max      DATE := TO_DATE('21990101', 'YYYYMMDD');

    --*****************************************************************************
    -- MULTI-PERIOD STATS COMPARISON
    -- Section 1
    --*****************************************************************************
    FUNCTION section1data(p_value        IN OUT XMLTYPE,
                          p_section_name IN     VARCHAR2,
                          p_start_date   IN     DATE,
                          p_end_date     IN     DATE,
                          p_status_msg   IN OUT VARCHAR2)
        RETURN BOOLEAN
    IS
        xml_temp   XMLTYPE;
    BEGIN
        SELECT XMLELEMENT(
                   EVALNAME (p_section_name),
                   xmlattributes(   TO_CHAR(p_start_date, 'MM/DD/YYYY')
                                 || '-'
                                 || TO_CHAR(p_end_date, 'MM/DD/YYYY') AS "DATES",
                                 FLOOR(MONTHS_BETWEEN(p_end_date, p_start_date)) + 1 AS "MONTHS"),
                   XMLFOREST(
                       (SELECT NVL(COUNT(a.objectid), 0)
                          FROM mart.application a
                         WHERE a.statusname <> 'NEW'
                           AND a.abc19apptype IS NOT NULL
                           AND a.haslicensetype79 = 'N'
                           AND a.haslicensetype84 = 'N'
                           AND TRUNC(a.enterapplicationcompleteddate) BETWEEN p_start_date AND p_end_date)
                           applicationsreceived,
                       ---------------------------------------------------------------------------------
                       (--  06/25/2020  TJL 21921 - Changed how priority applications are counted
                        WITH
                            applications
                            AS
                                (SELECT objectid,
                                        api.pkg_columnquery.VALUE(objectid, 'IsPriorityApplication')
                                            ispriorityapplication,
                                        api.pkg_columnquery.VALUE(objectid, 'StatusName')
                                            statusname
                                   FROM TABLE(
                                            CAST(
                                                api.pkg_simplesearch.castableobjectsbyindexrange(
                                                    a_objectdefname => 'j_application',
                                                    a_columnname => 'CreatedDate',
                                                    a_lowvalue  => TO_CHAR(p_start_date, 'YYYY-MM-DD'),
                                                    a_highvalue => TO_CHAR(p_end_date, 'YYYY-MM-DD')) AS api.udt_objectlist)))
                        SELECT COUNT(1)
                          FROM applications a
                         WHERE a.ispriorityapplication = 'Y'
                           AND a.statusname NOT IN ('NEW', 'VOIDED'))
                           pdapplicationsreceived,
                       --------------------------------------------------------------------------------
                       (SELECT COUNT(DISTINCT objectid)
                          FROM (SELECT p.objectid
                                  FROM TABLE(CAST(api.pkg_simplesearch.castableobjectsbyindexrange(
                                                      'j_Application',
                                                      'CreatedDate',
                                                      TO_CHAR(
                                                          CASE
                                                              WHEN p_start_date < g_switch THEN p_start_date
                                                              ELSE g_max
                                                          END,
                                                          'YYYY-MM-DD'),
                                                      TO_CHAR(
                                                          CASE
                                                              WHEN p_start_date >= g_switch THEN g_max
                                                              WHEN p_end_date >= g_switch THEN g_switch - 1
                                                              ELSE p_end_date
                                                          END,
                                                          'YYYY-MM-DD')) AS api.udt_objectlist)) p
                                       JOIN query.r_applicationprotestant r
                                       ON r.applicationjobid = p.objectid
                                UNION
                                SELECT r.toobjectid objectid
                                  FROM TABLE(CAST(api.pkg_simplesearch.castableobjectsbyindexrange(
                                                      'l_DocketNoteUserLog',
                                                      'logdate',
                                                      TO_CHAR(
                                                          CASE
                                                              WHEN p_start_date >= g_switch THEN p_start_date
                                                              WHEN p_end_date >= g_switch THEN g_switch
                                                              ELSE g_max
                                                          END,
                                                          'YYYY-MM-DD'),
                                                      TO_CHAR(
                                                          CASE
                                                              WHEN p_start_date >= g_switch THEN p_end_date
                                                              WHEN p_end_date >= g_switch THEN p_end_date
                                                              ELSE g_max
                                                          END,
                                                          'YYYY-MM-DD')) AS api.udt_objectlist)) o
                                       JOIN api.relationships r
                                       ON r.fromobjectid = o.objectid
                                      AND r.endpointid =
                                          api.pkg_configquery.endpointidforname('l_DocketNoteUserLog', 'Application')
                                 WHERE api.pkg_columnquery.VALUE(o.objectid, 'eventcode') = 'PRT01'))
                           applicationsprotested,
                       --------------------------------------------------------------------------------

                       (  -- count protest letters received
                        SELECT COUNT(objectid)
                          FROM (SELECT p.objectid
                                  FROM TABLE(CAST(api.pkg_simplesearch.castableobjectsbyindexrange(
                                                      'j_Application',
                                                      'CreatedDate',
                                                      TO_CHAR(
                                                          CASE
                                                              WHEN p_start_date < g_switch THEN p_start_date
                                                              ELSE g_max
                                                          END,
                                                          'YYYY-MM-DD'),
                                                      TO_CHAR(
                                                          CASE
                                                              WHEN p_start_date >= g_switch THEN g_max
                                                              WHEN p_end_date >= g_switch THEN g_switch - 1
                                                              ELSE p_end_date
                                                          END,
                                                          'YYYY-MM-DD')) AS api.udt_objectlist)) p
                                       JOIN query.r_applicationprotestant r
                                       ON r.applicationjobid = p.objectid
                                UNION ALL
                                SELECT r.toobjectid objectid
                                  FROM TABLE(CAST(api.pkg_simplesearch.castableobjectsbyindexrange(
                                                      'l_DocketNoteUserLog',
                                                      'logdate',
                                                      TO_CHAR(
                                                          CASE
                                                              WHEN p_start_date >= g_switch THEN p_start_date
                                                              WHEN p_end_date >= g_switch THEN g_switch
                                                              ELSE g_max
                                                          END,
                                                          'YYYY-MM-DD'),
                                                      TO_CHAR(
                                                          CASE
                                                              WHEN p_start_date >= g_switch THEN p_end_date
                                                              WHEN p_end_date >= g_switch THEN p_end_date
                                                              ELSE g_max
                                                          END,
                                                          'YYYY-MM-DD')) AS api.udt_objectlist)) o
                                       JOIN api.relationships r
                                       ON r.fromobjectid = o.objectid
                                      AND r.endpointid =
                                          api.pkg_configquery.endpointidforname('l_DocketNoteUserLog', 'Application')
                                 WHERE api.pkg_columnquery.VALUE(o.objectid, 'eventcode') = 'PRT01')) protestsrec,
                       --------------------------------------------------------------------------------

                       (SELECT NVL(COUNT(DISTINCT r.toobjectid), 0)
                          FROM TABLE(CAST(api.pkg_simplesearch.castableobjectsbyindexrange(
                                              'l_DocketNoteUserLog',
                                              'logdate',
                                              TO_CHAR(
                                                  CASE
                                                      WHEN p_start_date >= g_switch THEN p_start_date
                                                      WHEN p_end_date >= g_switch THEN g_switch
                                                      ELSE g_max
                                                  END,
                                                  'YYYY-MM-DD'),
                                              TO_CHAR(
                                                  CASE
                                                      WHEN p_start_date >= g_switch THEN p_end_date
                                                      WHEN p_end_date >= g_switch THEN p_end_date
                                                      ELSE g_max
                                                  END,
                                                  'YYYY-MM-DD')) AS api.udt_objectlist)) o
                               JOIN api.relationships r
                               ON r.fromobjectid = o.objectid
                              AND r.endpointid =
                                  api.pkg_configquery.endpointidforname('l_DocketNoteUserLog', 'Application')
                         WHERE api.pkg_columnquery.VALUE(o.objectid, 'eventcode') IN ('PRT12', 'PMC06')) propettotal,
                       --------------------------------------------------------------------------------
                       (SELECT SUM(withdrawnoriginal) + SUM(withdrawnpertoper)
                          FROM (SELECT SUM(CASE WHEN abc19original = 'Y' THEN 1 ELSE 0 END)
                                           withdrawnoriginal,
                                       SUM(CASE
                                               WHEN abc19original != 'Y'
                                                AND abc19pertoper = 'Y' THEN
                                                   1
                                               ELSE
                                                   0
                                           END)
                                           withdrawnpertoper
                                  FROM (SELECT a.abc19original, a.abc19pertoper
                                          FROM mart.districtapplicationreview d
                                               JOIN mart.application a
                                               ON a.objectid = d.jobid
                                         WHERE d.haslicensetype79 = 'N'
                                           AND d.haslicensetype84 = 'N'
                                           AND d.datecompleted BETWEEN p_start_date AND p_end_date
                                           AND d.outcome = 'Withdraw'
                                           AND a.enterapplicationcompleteddate IS NOT NULL
                                           AND d.objectid IN (  SELECT MIN(d1.objectid)
                                                                  FROM mart.districtapplicationreview d1
                                                                 WHERE d1.jobid = d.jobid
                                                              GROUP BY d1.jobid)
                                        UNION ALL
                                        SELECT a.abc19original, a.abc19pertoper
                                          FROM mart.withdrawapplication p
                                               JOIN mart.application a
                                               ON a.objectid = p.jobid
                                         WHERE a.haslicensetype79 = 'N'
                                           AND a.haslicensetype84 = 'N'
                                           AND p.datecompleted BETWEEN p_start_date AND p_end_date
                                           AND p.outcome IS NOT NULL
                                           AND a.enterapplicationcompleteddate IS NOT NULL
                                           AND EXISTS
                                                   (SELECT 1
                                                      FROM extension.jobstatuschange_t j
                                                     WHERE j.jobid = a.objectid
                                                       AND j.statusname = 'WTHDRN'
                                                       AND TRUNC(j.effectivestartdate) BETWEEN p_start_date
                                                                                           AND p_end_date)
                                           AND p.objectid IN (  SELECT MIN(p2.objectid)
                                                                  FROM mart.withdrawapplication p2
                                                                 WHERE p2.jobid = a.objectid
                                                              GROUP BY p2.jobid)
                                           AND NOT EXISTS
                                                   (SELECT 1
                                                      FROM mart.districtapplicationreview d
                                                     WHERE d.jobid = a.objectid
                                                       AND d.outcome IS NOT NULL)))) withdrawn,
                       --------------------------------------------------------------------------------

                       (SELECT NVL(COUNT(objectid), 0)
                          FROM (SELECT a.objectid
                                  FROM mart.districtapplicationreview d
                                       JOIN mart.application a
                                       ON a.objectid = d.jobid
                                 WHERE d.haslicensetype79 = 'N'
                                   AND a.droppartner = 'N'
                                   AND d.haslicensetype84 = 'N'
                                   AND d.datecompleted BETWEEN p_start_date AND p_end_date
                                   AND d.outcome = 'Deny With Division Review'
                                   AND d.objectid IN (  SELECT MIN(d1.objectid)
                                                          FROM mart.districtapplicationreview d1
                                                         WHERE d1.jobid = d.jobid
                                                      GROUP BY d1.jobid)
                                UNION ALL
                                SELECT a.objectid
                                  FROM mart.recorddirectordicision p
                                       JOIN mart.application a
                                       ON a.objectid = p.jobid
                                 WHERE a.haslicensetype79 = 'N'
                                   AND a.droppartner = 'N'
                                   AND a.haslicensetype84 = 'N'
                                   AND p.datecompleted BETWEEN p_start_date AND p_end_date
                                   AND p.outcome IS NOT NULL
                                   AND EXISTS
                                           (SELECT 1
                                              FROM extension.jobstatuschange_t j
                                             WHERE j.jobid = a.objectid
                                               AND j.statusname = 'DENIED'
                                               AND TRUNC(j.effectivestartdate) BETWEEN p_start_date AND p_end_date)
                                   AND p.objectid IN (  SELECT MIN(p2.objectid)
                                                          FROM mart.recorddirectordicision p2
                                                         WHERE p2.jobid = a.objectid
                                                      GROUP BY p2.jobid)
                                   AND NOT EXISTS
                                           (SELECT 1
                                              FROM mart.districtapplicationreview d
                                             WHERE d.jobid = a.objectid
                                               AND d.outcome IS NOT NULL))) apprecommenddenial,
                       --------------------------------------------------------------------------------

                       (SELECT NVL(COUNT(objectid), 0)
                          FROM (SELECT a.objectid
                                  FROM mart.districtapplicationreview d
                                       JOIN mart.application a
                                       ON a.objectid = d.jobid
                                 WHERE d.haslicensetype79 = 'N'
                                   AND d.haslicensetype84 = 'N'
                                   AND TRUNC(d.datecompleted) BETWEEN p_start_date AND p_end_date
                                   AND d.outcome IN
                                           ('224 Approval', 'Approve Application', 'Approve With Division Review')
                                   AND d.objectid IN (  SELECT MIN(d1.objectid)
                                                          FROM mart.districtapplicationreview d1
                                                         WHERE d1.jobid = d.jobid
                                                      GROUP BY d1.jobid)
                                   AND ((a.abc19original != 'Y'
                                     AND a.abc19pertoper = 'Y')
                                     OR a.abc19original = 'Y')
                                UNION ALL
                                SELECT a.objectid
                                  FROM mart.issuelicense p
                                       JOIN mart.application a
                                       ON a.objectid = p.jobid
                                 WHERE a.haslicensetype79 = 'N'
                                   AND a.haslicensetype84 = 'N'
                                   AND datecompleted BETWEEN p_start_date AND p_end_date
                                   AND p.outcome IS NOT NULL
                                   AND EXISTS
                                           (SELECT 1
                                              FROM extension.jobstatuschange_t j
                                             WHERE j.jobid = a.objectid
                                               AND j.statusname = 'ISSUED'
                                               AND TRUNC(j.effectivestartdate) BETWEEN p_start_date AND p_end_date)
                                   AND p.objectid IN (  SELECT MIN(p2.objectid)
                                                          FROM mart.issuelicense p2
                                                         WHERE p2.jobid = a.objectid
                                                      GROUP BY p2.jobid)
                                   AND NOT EXISTS
                                           (SELECT 1
                                              FROM mart.districtapplicationreview d
                                             WHERE d.jobid = a.objectid
                                               AND d.outcome IS NOT NULL)
                                   AND ((a.abc19original != 'Y'
                                     AND a.abc19pertoper = 'Y')
                                     OR a.abc19original = 'Y'))) apprecommendapproval,
                       --------------------------------------------------------------------------------

                       (SELECT NVL(COUNT(a.objectid), 0)
                          FROM mart.applictype a
                               JOIN mart.primaryandsecondaryapplictype psal
                               ON psal.primlictypeobjectid = a.objectid
                               JOIN mart.licensetypecategory ltc
                               ON ltc.objectid = psal.liccategoryobjectid
                         WHERE (a.status IN ('ISSUED')
                             OR psal.status IN ('ISSUED'))
                           AND ltc.licensetypecode NOT IN ('09',
                                                           '11',
                                                           '12',
                                                           '26',
                                                           '28',
                                                           '58',
                                                           '62',
                                                           '66',
                                                           '68',
                                                           '77',
                                                           '79',
                                                           '81',
                                                           '82',
                                                           '84')
                           AND (TRUNC(a.statusdatecorral) BETWEEN p_start_date AND p_end_date
                             OR TRUNC(psal.statusdate) BETWEEN p_start_date AND p_end_date)) permanentlicissued,
                       -------------------------------------------------------------------------------
                       (SELECT  -- application and license def ids
                               SUM(CASE
                                       WHEN r.defid = 338587
                                         OR r.defid = 325227 THEN
                                           1
                                       ELSE
                                           0
                                   END)
                          FROM (SELECT api.pkg_columnquery.numericvalue(r.jobid, 'objectdefid') defid
                                  FROM api.processes r
                                 WHERE r.processid IN
                                           (SELECT processid
                                              FROM query.p_processhearing ph
                                             WHERE TRUNC(ph.createddate) BETWEEN p_start_date AND p_end_date)) r)
                           licensehearings,
                       --------------------------------------------------------------------------------

                       (SELECT SUM(x.item) xxx
                          FROM (SELECT COUNT(licensetypecode) item
                                  FROM mart.onedaylicense d
                                       JOIN mart.onedaylicensetypecategoryrel r
                                       ON d.jobid = r.onedaylicensejobid
                                       JOIN mart.licensetypecategory lt
                                       ON lt.objectid = r.licensetypecategoryobjectid
                                 WHERE d.dateofeventfrom IS NOT NULL
                                   AND TO_DATE(d.completeddate) BETWEEN p_start_date AND p_end_date
                                   AND (licensetypecode BETWEEN 31 AND 34
                                     OR licensetypecode = 37)
                                UNION ALL
                                -- Catering AUTH
                                SELECT COUNT(d.jobid) item
                                  FROM mart.issuecaterereventauth d
                                 WHERE TO_DATE(d.datecompleted) BETWEEN p_start_date AND p_end_date
                                   AND d.outcome IS NOT NULL
                                   AND d.cateringorevent IS NOT NULL
                                   AND NVL((SELECT a.licenseexists
                                              FROM mart.applictype a
                                             WHERE a.applicationobjectid = d.jobid
                                               AND ROWNUM < 2),
                                           'N') = 'N') x) dailylicenses,
                       --------------------------------------------------------------------------------

                       (  (SELECT NVL(COUNT(DISTINCT (lt.objectid)), 0)
                             FROM mart.licensetype lt
                                  JOIN mart.primaryandsecondarylicencetype r
                                  ON r.licensetypeobjectid = lt.objectid
                                  JOIN mart.licensetypecategory ltc
                                  ON r.licensecetypecategoryobjectid = ltc.objectid
                                  JOIN extension.jobstatuschange j
                                  ON lt.objectid = j.jobid
                            WHERE r.primary IS NOT NULL
                              AND j.statusname IN ('ACTIVE',
                                                   'SUREND',
                                                   'SUSPEN',
                                                   'R64B',
                                                   'SLMSHD',
                                                   'REVPEN')
                              AND j.effectivestartdate = (SELECT MAX(jo.effectivestartdate)
                                                            FROM extension.jobstatuschange jo
                                                           WHERE jo.effectivestartdate <= p_end_date
                                                             AND jo.jobid = j.jobid))
                        +  --        union all
                          (SELECT NVL(COUNT(DISTINCT (lt2.objectid)), 0)
                             FROM mart.licensetype lt2  --primary
                                  JOIN mart.primaryandsecondarylicencetype x
                                  ON x.licensetypeobjectid = lt2.objectid
                                  JOIN sitespecific.sltstatuschange_t sc
                                  ON sc.relationshipid = x.relationshipid
                                  JOIN mart.licensetypecategory ltc2
                                  ON ltc2.objectid = x.licensecetypecategoryobjectid
                                  JOIN mart.licensetypecategoryrel plt
                                  ON plt.licensetypeobjectid = lt2.objectid
                            WHERE x.primary IS NULL  --secondary lt's only.
                              AND sc.statusname IN ('ACTIVE',
                                                    'SUREND',
                                                    'SUSPEN',
                                                    'R64B',
                                                    'SLSMSHD',
                                                    'REVPEN')
                              AND sc.effectivestartdate = (SELECT MAX(sc2.effectivestartdate)
                                                             FROM sitespecific.sltstatuschange_t sc2
                                                            WHERE sc2.relationshipid = x.relationshipid
                                                              AND sc2.effectivestartdate <= p_end_date))  -- LicenseTypes)
                                                                                                        )
                           activelicenses,
                       --------------------------------------------------------------------------------
                       -- II. Enforcement
                       --------------------------------------------------------------------------------
                       (SELECT NVL(COUNT(ei.objectid), 0)
                          FROM mart.conductenforcementinvestigatio ei
                               JOIN mart.investigation i
                               ON ei.jobid = i.objectid
                         WHERE TRUNC(ei.createddate) BETWEEN p_start_date AND p_end_date
                           AND ei.datecompleted IS NULL
                           AND i.investigationtype = 'COMPLAINT') pendcomplaintinvestigations,
                       --------------------------------------------------------------------------------

                       (  (SELECT NVL(COUNT(ei.objectid), 0)
                             FROM mart.conductenforcementinvestigatio ei
                                  JOIN mart.investigation i
                                  ON ei.jobid = i.objectid
                            WHERE TRUNC(ei.createddate) BETWEEN p_start_date AND p_end_date
                              AND ei.datecompleted IS NULL
                              AND i.investigationtype = 'ADMINISTRATIVE')
                        + (SELECT NVL(COUNT(ai.objectid), 0)
                             FROM mart.conductadmininvestigation ai
                                  JOIN mart.application a
                                  ON a.objectid = ai.jobid
                            WHERE TRUNC(ai.createddate) BETWEEN p_start_date AND p_end_date
                              AND ai.datecompleted IS NULL
                              AND a.abc19apptype IS NOT NULL
                              AND a.haslicensetype84 = 'N'
                              AND a.haslicensetype79 = 'N')) pendadmininvestigations,
                       (SELECT COUNT(investigationtype)
                          FROM mart.investigation i
                         WHERE i.investigationtype = 'COMPLAINT'
                           AND (SELECT TRUNC(t.effectivestartdate)
                                  FROM extension.jobstatuschange_t t
                                 WHERE t.jobid = i.objectid
                                   AND t.statusname = 'CLOSED'
                                   AND t.jobstatuschangeid = (SELECT MIN(t.jobstatuschangeid)
                                                                FROM extension.jobstatuschange_t t
                                                               WHERE t.jobid = i.objectid
                                                                 AND t.statusname = 'CLOSED')) BETWEEN p_start_date
                                                                                                   AND p_end_date
                           AND api.pkg_columnquery.VALUE(i.objectid, 'StatusName') <> 'CANCEL')
                           complaintinvestigations,
                       (SELECT COUNT(investigationtype)
                          FROM mart.investigation i
                         WHERE i.investigationtype = 'ADMINISTRATIVE'
                           AND (SELECT TRUNC(t.effectivestartdate)
                                  FROM extension.jobstatuschange_t t
                                 WHERE t.jobid = i.objectid
                                   AND t.statusname = 'CLOSED'
                                   AND t.jobstatuschangeid = (SELECT MIN(t.jobstatuschangeid)
                                                                FROM extension.jobstatuschange_t t
                                                               WHERE t.jobid = i.objectid
                                                                 AND t.statusname = 'CLOSED')) BETWEEN p_start_date
                                                                                                   AND p_end_date
                           AND api.pkg_columnquery.VALUE(i.objectid, 'StatusName') <> 'CANCEL') admininvestigations,
                       (SELECT COUNT(investigationtype)
                          FROM mart.investigation i
                         WHERE i.investigationtype = 'POLICE REPORT'
                           AND (SELECT TRUNC(t.effectivestartdate)
                                  FROM extension.jobstatuschange_t t
                                 WHERE t.jobid = i.objectid
                                   AND t.statusname = 'CLOSED'
                                   AND t.jobstatuschangeid = (SELECT MIN(t.jobstatuschangeid)
                                                                FROM extension.jobstatuschange_t t
                                                               WHERE t.jobid = i.objectid
                                                                 AND t.statusname = 'CLOSED')) BETWEEN p_start_date
                                                                                                   AND p_end_date
                           AND api.pkg_columnquery.VALUE(i.objectid, 'StatusName') <> 'CANCEL') policereportinv,
                       (SELECT COUNT(a.objectid) compd
                          FROM mart.licensingassignment a
                         WHERE TRUNC(a.datecompleted) BETWEEN p_start_date AND p_end_date
                           AND NVL(a.droppartner, 'N') = 'N'
                           AND NVL(a.haslicensetype79, 'N') = 'N'
                           AND NVL(a.haslicensetype84, 'N') = 'N') licassign,
                       (SELECT COUNT(investigationtype)
                          FROM mart.investigation i
                         WHERE i.investigationtype = 'TRACE'
                           AND (SELECT TRUNC(t.effectivestartdate)
                                  FROM extension.jobstatuschange_t t
                                 WHERE t.jobid = i.objectid
                                   AND t.statusname = 'CLOSED'
                                   AND t.jobstatuschangeid = (SELECT MIN(t.jobstatuschangeid)
                                                                FROM extension.jobstatuschange_t t
                                                               WHERE t.jobid = i.objectid
                                                                 AND t.statusname = 'CLOSED')) BETWEEN p_start_date
                                                                                                   AND p_end_date
                           AND api.pkg_columnquery.VALUE(i.objectid, 'StatusName') <> 'CANCEL') traceinvestigations,
                       --------------------------------------------------------------------------------
                       (SELECT COUNT(DISTINCT a.regnumber)
                          FROM mart.accusationviolation av
                               JOIN mart.violation v
                               ON v.objectid = av.violationobjectid
                               JOIN mart.accusation a
                               ON a.objectid = av.accusationobjectid
                               JOIN query.o_office o
                               ON o.objectid = a.officeid
                         WHERE av.accusationobjectid IN
                                   (SELECT DISTINCT a.objectid
                                      FROM mart.accusation a
                                     WHERE a.accusationregistereddate BETWEEN p_start_date AND p_end_date
                                       AND (a.casetype = 'ABC'
                                         OR a.casetype = 'BACKTRACK'))
                           AND v.code NOT IN ('G3')) accusationsreg,
                       --------------------------------------------------------------------------------
                       (SELECT NVL(SUM(  (CASE
                                              WHEN v.code IN ('C10',
                                                              'E1',
                                                              'E2',
                                                              'P2',
                                                              'P3',
                                                              'P7',
                                                              'S11',
                                                              'S12',
                                                              'S35',
                                                              'S31',
                                                              'U5',
                                                              'S18') THEN
                                                  1
                                              ELSE
                                                  0
                                          END)
                                       + (CASE WHEN v.code IN ('S13') THEN 1 ELSE 0 END)  -- MD - minor decoy
                                       + (CASE
                                              WHEN v.code IN ('C1',
                                                              'D16',
                                                              'P4',
                                                              'P42',
                                                              'P43',
                                                              'S16') THEN
                                                  1
                                              ELSE
                                                  0
                                          END)  -- OI- Obviously Intoxicated
                                       + (CASE
                                              WHEN v.code IN ('C3',
                                                              'F39',
                                                              'L9',
                                                              'O6',
                                                              'P11',
                                                              'P12',
                                                              'P21',
                                                              'P22',
                                                              'P32',
                                                              'P33',
                                                              'P34',
                                                              'P38',
                                                              'P41',
                                                              'P48',
                                                              'P49',
                                                              'P50',
                                                              'P51',
                                                              'P52',
                                                              'P54',
                                                              'P55',
                                                              'S24',
                                                              'S8') THEN
                                                  1
                                              ELSE
                                                  0
                                          END)  -- DR- Drugs
                                       + (CASE
                                              WHEN v.code IN ('C13',
                                                              'C16',
                                                              'C7',
                                                              'D6',
                                                              'G4',
                                                              'I7',
                                                              'L1',
                                                              'L3',
                                                              'P26',
                                                              'R5',
                                                              'S29') THEN
                                                  1
                                              ELSE
                                                  0
                                          END)  -- DP - Disorderly/Disruptive Premise
                                       + (CASE
                                              WHEN v.code IN ('D22',
                                                              'D7',
                                                              'D8',
                                                              'D9',
                                                              'E7',
                                                              'F10',
                                                              'F18',
                                                              'F24',
                                                              'F33',
                                                              'F34',
                                                              'F35',
                                                              'F38',
                                                              'F40',
                                                              'F41',
                                                              'G5',
                                                              'L4',
                                                              'L5') THEN
                                                  1
                                              ELSE
                                                  0
                                          END)  -- RO- ROSTF
                                       + (CASE
                                              WHEN v.code IN ('A5',
                                                              'B1',
                                                              'B2',
                                                              'D20',
                                                              'D3',
                                                              'M2',
                                                              'P35',
                                                              'P47',
                                                              'P53',
                                                              'P9',
                                                              'U6') THEN
                                                  1
                                              ELSE
                                                  0
                                          END)  -- WV - Weapons Violations
                                       + (CASE
                                              WHEN v.code IN ('I6',
                                                              'O1',
                                                              'P18',
                                                              'P19',
                                                              'P20',
                                                              'U1') THEN
                                                  1
                                              ELSE
                                                  0
                                          END)  -- SP - Stolen Property
                                       + (CASE
                                              WHEN v.code IN ('B4',
                                                              'G1',
                                                              'O3',
                                                              'P13',
                                                              'P14',
                                                              'P15') THEN
                                                  1
                                              ELSE
                                                  0
                                          END)  -- GA- Gambling
                                       + (CASE WHEN v.code IN ('P1') THEN 1 ELSE 0 END)  -- SD- Soliciting Drinks
                                       + (CASE
                                              WHEN v.code IN ('A3',
                                                              'A4',
                                                              'C19',
                                                              'S34') THEN
                                                  1
                                              ELSE
                                                  0
                                          END)  -- AH- After Hours
                                       + (CASE
                                              WHEN v.code IN ('A1',
                                                              'A15',
                                                              'C18',
                                                              'D4',
                                                              'D18',
                                                              'D21',
                                                              'E10',
                                                              'E3',
                                                              'E5',
                                                              'E8',
                                                              'F13',
                                                              'F16',
                                                              'F19',
                                                              'F2',
                                                              'F20',
                                                              'F21',
                                                              'F26',
                                                              'F29',
                                                              'F3',
                                                              'F30',
                                                              'F36',
                                                              'F4',
                                                              'F8',
                                                              'G6',
                                                              'I1',
                                                              'I10',
                                                              'I11',
                                                              'I12',
                                                              'I13',
                                                              'I3',
                                                              'I8',
                                                              'I9',
                                                              'P8',
                                                              'P10',
                                                              'P23',
                                                              'P56',
                                                              'R8',
                                                              'S14',
                                                              'S17',
                                                              'S19',
                                                              'S23',
                                                              'S25',
                                                              'S26',
                                                              'S27',
                                                              'S30',
                                                              'S4',
                                                              'S6',
                                                              'U3',
                                                              'V0',
                                                              'V4',
                                                              'V5',
                                                              'V7',
                                                              'B3',
                                                              'C20',
                                                              'E9',
                                                              'F32',
                                                              'F9',
                                                              'P39',
                                                              'P46',
                                                              'P56',
                                                              'R2',
                                                              'R3',
                                                              'S2',
                                                              'S21',
                                                              'S28',
                                                              'S30',
                                                              'S36',
                                                              'S5',
                                                              'U2',
                                                              'V1',
                                                              'V6',
                                                              'S9') THEN
                                                  1
                                              ELSE
                                                  0
                                          END)  -- BP- Business Practices
                                       + (CASE
                                              WHEN v.code IN ('C15',
                                                              'C4',
                                                              'G2',
                                                              'L7',
                                                              'P24',
                                                              'R1',
                                                              'T3') THEN
                                                  1
                                              ELSE
                                                  0
                                          END)  -- MT- Moral Turpitude
                                       + (CASE WHEN v.code IN ('P17') THEN 1 ELSE 0 END)  -- PR- Prostitution
                                       + (CASE WHEN v.code IN ('V2', 'V3', 'V11') THEN 1 ELSE 0 END)  -- VC- Violation of Conditions
                                       + (CASE
                                              WHEN v.code IN ('A10',
                                                              'A11',
                                                              'A12',
                                                              'A13',
                                                              'A14',
                                                              'A2',
                                                              'A6',
                                                              'A7',
                                                              'A8',
                                                              'A9',
                                                              'C0',
                                                              'C11',
                                                              'C12',
                                                              'C14',
                                                              'C17',
                                                              'C2',
                                                              'C5',
                                                              'C6',
                                                              'C8',
                                                              'C9',
                                                              'D1',
                                                              'D10',
                                                              'D11',
                                                              'D12',
                                                              'D13',
                                                              'D14',
                                                              'D15',
                                                              'D17',
                                                              'D19',
                                                              'D2',
                                                              'D23',
                                                              'D24',
                                                              'D5',
                                                              'E4',
                                                              'E6',
                                                              'F0',
                                                              'F1',
                                                              'F11',
                                                              'F12',
                                                              'F14',
                                                              'F15',
                                                              'F17',
                                                              'F22',
                                                              'F23',
                                                              'F25',
                                                              'F27',
                                                              'F28',
                                                              'F31',
                                                              'F37',
                                                              'F42',
                                                              'F43',
                                                              'F44',
                                                              'F5',
                                                              'G3',
                                                              'H1',
                                                              'H2',
                                                              'H3',
                                                              'H4',
                                                              'I2',
                                                              'I4',
                                                              'I5',
                                                              'L10',
                                                              'L2',
                                                              'L6',
                                                              'L8',
                                                              'M1',
                                                              'N1',
                                                              'N2',
                                                              'O2',
                                                              'O4',
                                                              'O5',
                                                              'P16',
                                                              'P25',
                                                              'P27',
                                                              'P28',
                                                              'P29',
                                                              'P30',
                                                              'P31',
                                                              'P36',
                                                              'P37',
                                                              'P40',
                                                              'P44',
                                                              'P45',
                                                              'P6',
                                                              'R4',
                                                              'R6',
                                                              'R7',
                                                              'S15',
                                                              'S22',
                                                              'S32',
                                                              'S33',
                                                              'S7',
                                                              'T1',
                                                              'T2',
                                                              'U2',
                                                              'U4',
                                                              'V10',
                                                              'V8',
                                                              'V9',
                                                              'F7',
                                                              'P5',
                                                              'S1',
                                                              'S3',
                                                              'S20') THEN
                                                  1
                                              ELSE
                                                  0
                                          END)),
                                   0)  -- OT- Other
                          FROM mart.accusationviolation av
                               JOIN mart.violation v
                               ON v.objectid = av.violationobjectid
                               JOIN mart.accusation a
                               ON a.objectid = av.accusationobjectid
                               JOIN query.o_office o
                               ON o.objectid = a.officeid
                         WHERE av.accusationobjectid IN
                                   (SELECT DISTINCT a.objectid
                                      FROM mart.accusation a
                                     WHERE a.accusationregistereddate BETWEEN p_start_date AND p_end_date
                                       AND (a.casetype = 'ABC'))
                           AND v.code NOT IN ('G3')) abcviolations,
                       --------------------------------------------------------------------------------

                       (SELECT NVL(SUM(  (CASE
                                              WHEN v.code IN ('C10',
                                                              'E1',
                                                              'E2',
                                                              'P2',
                                                              'P3',
                                                              'P7',
                                                              'S11',
                                                              'S12',
                                                              'S35',
                                                              'S31',
                                                              'U5',
                                                              'S18') THEN
                                                  1
                                              ELSE
                                                  0
                                          END)
                                       + (CASE WHEN v.code IN ('S13') THEN 1 ELSE 0 END)  -- MD - minor decoy
                                       + (CASE
                                              WHEN v.code IN ('C1',
                                                              'D16',
                                                              'P4',
                                                              'P42',
                                                              'P43',
                                                              'S16') THEN
                                                  1
                                              ELSE
                                                  0
                                          END)  -- OI- Obviously Intoxicated
                                       + (CASE
                                              WHEN v.code IN ('C3',
                                                              'F39',
                                                              'L9',
                                                              'O6',
                                                              'P11',
                                                              'P12',
                                                              'P21',
                                                              'P22',
                                                              'P32',
                                                              'P33',
                                                              'P34',
                                                              'P38',
                                                              'P41',
                                                              'P48',
                                                              'P49',
                                                              'P50',
                                                              'P51',
                                                              'P52',
                                                              'P54',
                                                              'P55',
                                                              'S24',
                                                              'S8') THEN
                                                  1
                                              ELSE
                                                  0
                                          END)  -- DR- Drugs
                                       + (CASE
                                              WHEN v.code IN ('C13',
                                                              'C16',
                                                              'C7',
                                                              'D6',
                                                              'G4',
                                                              'I7',
                                                              'L1',
                                                              'L3',
                                                              'P26',
                                                              'R5',
                                                              'S29') THEN
                                                  1
                                              ELSE
                                                  0
                                          END)  -- DP - Disorderly/Disruptive Premise
                                       + (CASE
                                              WHEN v.code IN ('D22',
                                                              'D7',
                                                              'D8',
                                                              'D9',
                                                              'E7',
                                                              'F10',
                                                              'F18',
                                                              'F24',
                                                              'F33',
                                                              'F34',
                                                              'F35',
                                                              'F38',
                                                              'F40',
                                                              'F41',
                                                              'G5',
                                                              'L4',
                                                              'L5') THEN
                                                  1
                                              ELSE
                                                  0
                                          END)  -- RO- ROSTF
                                       + (CASE
                                              WHEN v.code IN ('A5',
                                                              'B1',
                                                              'B2',
                                                              'D20',
                                                              'D3',
                                                              'M2',
                                                              'P35',
                                                              'P47',
                                                              'P53',
                                                              'P9',
                                                              'U6') THEN
                                                  1
                                              ELSE
                                                  0
                                          END)  -- WV - Weapons Violations
                                       + (CASE
                                              WHEN v.code IN ('I6',
                                                              'O1',
                                                              'P18',
                                                              'P19',
                                                              'P20',
                                                              'U1') THEN
                                                  1
                                              ELSE
                                                  0
                                          END)  -- SP - Stolen Property
                                       + (CASE
                                              WHEN v.code IN ('B4',
                                                              'G1',
                                                              'O3',
                                                              'P13',
                                                              'P14',
                                                              'P15') THEN
                                                  1
                                              ELSE
                                                  0
                                          END)  -- GA- Gambling
                                       + (CASE WHEN v.code IN ('P1') THEN 1 ELSE 0 END)  -- SD- Soliciting Drinks
                                       + (CASE
                                              WHEN v.code IN ('A3',
                                                              'A4',
                                                              'C19',
                                                              'S34') THEN
                                                  1
                                              ELSE
                                                  0
                                          END)  -- AH- After Hours
                                       + (CASE
                                              WHEN v.code IN ('A1',
                                                              'A15',
                                                              'C18',
                                                              'D4',
                                                              'D18',
                                                              'D21',
                                                              'E10',
                                                              'E3',
                                                              'E5',
                                                              'E8',
                                                              'F13',
                                                              'F16',
                                                              'F19',
                                                              'F2',
                                                              'F20',
                                                              'F21',
                                                              'F26',
                                                              'F29',
                                                              'F3',
                                                              'F30',
                                                              'F36',
                                                              'F4',
                                                              'F8',
                                                              'G6',
                                                              'I1',
                                                              'I10',
                                                              'I11',
                                                              'I12',
                                                              'I13',
                                                              'I3',
                                                              'I8',
                                                              'I9',
                                                              'P8',
                                                              'P10',
                                                              'P23',
                                                              'P56',
                                                              'R8',
                                                              'S14',
                                                              'S17',
                                                              'S19',
                                                              'S23',
                                                              'S25',
                                                              'S26',
                                                              'S27',
                                                              'S30',
                                                              'S4',
                                                              'S6',
                                                              'U3',
                                                              'V0',
                                                              'V4',
                                                              'V5',
                                                              'V7',
                                                              'B3',
                                                              'C20',
                                                              'E9',
                                                              'F32',
                                                              'F9',
                                                              'P39',
                                                              'P46',
                                                              'P56',
                                                              'R2',
                                                              'R3',
                                                              'S2',
                                                              'S21',
                                                              'S28',
                                                              'S30',
                                                              'S36',
                                                              'S5',
                                                              'U2',
                                                              'V1',
                                                              'V6',
                                                              'S9') THEN
                                                  1
                                              ELSE
                                                  0
                                          END)  -- BP- Business Practices
                                       + (CASE
                                              WHEN v.code IN ('C15',
                                                              'C4',
                                                              'G2',
                                                              'L7',
                                                              'P24',
                                                              'R1',
                                                              'T3') THEN
                                                  1
                                              ELSE
                                                  0
                                          END)  -- MT- Moral Turpitude
                                       + (CASE
                                              WHEN v.code IN ('A10',
                                                              'A11',
                                                              'A12',
                                                              'A13',
                                                              'A14',
                                                              'A2',
                                                              'A6',
                                                              'A7',
                                                              'A8',
                                                              'A9',
                                                              'C0',
                                                              'C11',
                                                              'C12',
                                                              'C14',
                                                              'C17',
                                                              'C2',
                                                              'C5',
                                                              'C6',
                                                              'C8',
                                                              'C9',
                                                              'D1',
                                                              'D10',
                                                              'D11',
                                                              'D12',
                                                              'D13',
                                                              'D14',
                                                              'D15',
                                                              'D17',
                                                              'D19',
                                                              'D2',
                                                              'D23',
                                                              'D24',
                                                              'D5',
                                                              'E4',
                                                              'E6',
                                                              'F0',
                                                              'F1',
                                                              'F11',
                                                              'F12',
                                                              'F14',
                                                              'F15',
                                                              'F17',
                                                              'F22',
                                                              'F23',
                                                              'F25',
                                                              'F27',
                                                              'F28',
                                                              'F31',
                                                              'F37',
                                                              'F42',
                                                              'F43',
                                                              'F44',
                                                              'F5',
                                                              'G3',
                                                              'H1',
                                                              'H2',
                                                              'H3',
                                                              'H4',
                                                              'I2',
                                                              'I4',
                                                              'I5',
                                                              'L10',
                                                              'L2',
                                                              'L6',
                                                              'L8',
                                                              'M1',
                                                              'N1',
                                                              'N2',
                                                              'O2',
                                                              'O4',
                                                              'O5',
                                                              'P16',
                                                              'P25',
                                                              'P27',
                                                              'P28',
                                                              'P29',
                                                              'P30',
                                                              'P31',
                                                              'P36',
                                                              'P37',
                                                              'P40',
                                                              'P44',
                                                              'P45',
                                                              'P6',
                                                              'R4',
                                                              'R6',
                                                              'R7',
                                                              'S15',
                                                              'S22',
                                                              'S32',
                                                              'S33',
                                                              'S7',
                                                              'T1',
                                                              'T2',
                                                              'U2',
                                                              'U4',
                                                              'V10',
                                                              'V8',
                                                              'V9',
                                                              'F7',
                                                              'P5',
                                                              'S1',
                                                              'S3',
                                                              'S20') THEN
                                                  1
                                              ELSE
                                                  0
                                          END)  -- OT- Other
                                       + (CASE
                                              WHEN a.casetype = 'BACKTRACK'
                                               AND v.code IN ('P17') THEN
                                                  1
                                              ELSE
                                                  0
                                          END)  -- PR- Prostitution
                                       + (CASE
                                              WHEN a.casetype = 'BACKTRACK'
                                               AND v.code IN ('V2', 'V3', 'V11') THEN
                                                  1
                                              ELSE
                                                  0
                                          END)),
                                   0)  -- VC- Violation of Conditions
                          FROM mart.accusationviolation av
                               JOIN mart.violation v
                               ON v.objectid = av.violationobjectid
                               JOIN mart.accusation a
                               ON a.objectid = av.accusationobjectid
                               JOIN query.o_office o
                               ON o.objectid = a.officeid
                         WHERE av.accusationobjectid IN
                                   (SELECT DISTINCT a.objectid
                                      FROM mart.accusation a
                                     WHERE a.accusationregistereddate BETWEEN p_start_date AND p_end_date
                                       AND (a.casetype = 'BACKTRACK'))
                           AND v.code NOT IN ('G3')) backtrackviolations,
                       --------------------------------------------------------------------------------

                       (-- Stipulation and Waver
                        SELECT COUNT(DISTINCT o.objectid) objectid
                          FROM TABLE(CAST(api.pkg_simplesearch.castableobjectsbyindexrange(
                                              'l_DocketNoteUserLog',
                                              'logdate',
                                              TO_CHAR(p_start_date, 'YYYY-MM-DD'),
                                              TO_CHAR(p_end_date, 'YYYY-MM-DD')) AS api.udt_objectlist)) o
                         WHERE api.pkg_columnquery.VALUE(o.objectid, 'eventcode') IN ('16',
                                                                                      'ACC06',
                                                                                      'ACC07',
                                                                                      'ACC08',
                                                                                      'ACC09',
                                                                                      'ACC10',
                                                                                      'ACC11')) swreceived,
                       --------------------------------------------------------------------------------

                       (--Number of Enforcement Hearings Held
                        SELECT SUM(objectid)
                          FROM (SELECT COUNT(DISTINCT o.objectid) objectid
                                  FROM TABLE(CAST(api.pkg_simplesearch.castableobjectsbyindexrange(
                                                      'l_DocketNoteUserLog',
                                                      'logdate',
                                                      TO_CHAR(
                                                          CASE
                                                              WHEN p_start_date >= g_switch THEN p_start_date
                                                              WHEN p_end_date >= g_switch THEN g_switch
                                                              ELSE g_max
                                                          END,
                                                          'YYYY-MM-DD'),
                                                      TO_CHAR(
                                                          CASE
                                                              WHEN p_start_date >= g_switch THEN p_end_date
                                                              WHEN p_end_date >= g_switch THEN p_end_date
                                                              ELSE g_max
                                                          END,
                                                          'YYYY-MM-DD')) AS api.udt_objectlist)) o
                                 WHERE api.pkg_columnquery.VALUE(o.objectid, 'eventcode') = 'ACC29')) processhearing,
                       --------------------------------------------------------------------------------

                       (--Number of Licensing Hearings Held Needs to be added to
                        SELECT COUNT(DISTINCT o.objectid) objectid
                          FROM TABLE(CAST(api.pkg_simplesearch.castableobjectsbyindexrange(
                                              'l_DocketNoteUserLog',
                                              'logdate',
                                              TO_CHAR(p_start_date, 'YYYY-MM-DD'),
                                              TO_CHAR(p_end_date, 'YYYY-MM-DD')) AS api.udt_objectlist)) o
                         WHERE api.pkg_columnquery.VALUE(o.objectid, 'eventcode') IN ('PMC09', 'PRT15'))
                           processhearingheld,
                       --------------------------------------------------------------------------------

                       (--Dismissed
                        SELECT COUNT(DISTINCT objectid)
                          FROM (SELECT etd.jobid objectid
                                  FROM mart.executetermsofdecision etd
                                 WHERE etd.outcome = 'Dismiss'
                                   AND TRUNC(etd.datecompleted) BETWEEN CASE
                                                                            WHEN p_start_date < g_switch THEN
                                                                                p_start_date
                                                                            ELSE
                                                                                g_max
                                                                        END
                                                                    AND CASE
                                                                            WHEN p_start_date >= g_switch THEN
                                                                                g_max
                                                                            WHEN p_end_date >= g_switch THEN
                                                                                g_switch - 1
                                                                            ELSE
                                                                                p_end_date
                                                                        END
                                UNION
                                SELECT r.toobjectid objectid
                                  FROM TABLE(CAST(api.pkg_simplesearch.castableobjectsbyindexrange(
                                                      'l_DocketNoteUserLog',
                                                      'logdate',
                                                      TO_CHAR(
                                                          CASE
                                                              WHEN p_start_date >= g_switch THEN p_start_date
                                                              WHEN p_end_date >= g_switch THEN g_switch
                                                              ELSE g_max
                                                          END,
                                                          'YYYY-MM-DD'),
                                                      TO_CHAR(
                                                          CASE
                                                              WHEN p_start_date >= g_switch THEN p_end_date
                                                              WHEN p_end_date >= g_switch THEN p_end_date
                                                              ELSE g_max
                                                          END,
                                                          'YYYY-MM-DD')) AS api.udt_objectlist)) o
                                       JOIN api.relationships r
                                       ON r.fromobjectid = o.objectid
                                      AND r.endpointid IN
                                              (api.pkg_configquery.endpointidforname('l_DocketNoteUserLog',
                                                                                     'Accusation'),
                                               api.pkg_configquery.endpointidforname('l_DocketNoteUserLog',
                                                                                     'License'),
                                               api.pkg_configquery.endpointidforname('l_DocketNoteUserLog',
                                                                                     'Application'))
                                 WHERE api.pkg_columnquery.VALUE(o.objectid, 'eventcode') = 'ACC24')) dismissed,
                       --------------------------------------------------------------------------------

                       (--Penalties Imposed Following Hearing
                        SELECT COUNT(objectid)
                          FROM (SELECT DISTINCT j.objectid
                                  FROM query.j_accusation j
                                       JOIN api.processes r
                                       ON j.objectid = r.jobid
                                       JOIN query.p_executetermsofdecision d
                                       ON d.objectid = r.processid
                                 WHERE swsigneddate IS NULL
                                   AND d.outcome IS NOT NULL
                                   AND TRUNC(d.createddate) BETWEEN CASE
                                                                        WHEN p_start_date < g_switch THEN
                                                                            p_start_date
                                                                        ELSE
                                                                            g_max
                                                                    END
                                                                AND CASE
                                                                        WHEN p_start_date >= g_switch THEN g_max
                                                                        WHEN p_end_date >= g_switch THEN g_switch - 1
                                                                        ELSE p_end_date
                                                                    END
                                UNION
                                SELECT DISTINCT r.toobjectid objectid
                                  FROM TABLE(CAST(api.pkg_simplesearch.castableobjectsbyindexrange(
                                                      'l_DocketNoteUserLog',
                                                      'logdate',
                                                      TO_CHAR(
                                                          CASE
                                                              WHEN p_start_date >= g_switch THEN p_start_date
                                                              WHEN p_end_date >= g_switch THEN g_switch
                                                              ELSE g_max
                                                          END,
                                                          'YYYY-MM-DD'),
                                                      TO_CHAR(
                                                          CASE
                                                              WHEN p_start_date >= g_switch THEN p_end_date
                                                              WHEN p_end_date >= g_switch THEN p_end_date
                                                              ELSE g_max
                                                          END,
                                                          'YYYY-MM-DD')) AS api.udt_objectlist)) o
                                       JOIN api.relationships r
                                       ON r.fromobjectid = o.objectid
                                      AND r.endpointid IN
                                              (api.pkg_configquery.endpointidforname('l_DocketNoteUserLog',
                                                                                     'Accusation'),
                                               api.pkg_configquery.endpointidforname('l_DocketNoteUserLog',
                                                                                     'License'),
                                               api.pkg_configquery.endpointidforname('l_DocketNoteUserLog',
                                                                                     'Application'))
                                 WHERE api.pkg_columnquery.VALUE(o.objectid, 'eventcode') = 'ACC42')) penalties,
                       --------------------------------------------------------------------------------

                       (--Accusations Sustained After Hearing
                        SELECT COUNT(objectid)
                          FROM (SELECT rad.jobid objectid
                                  FROM mart.recordappealdecision rad
                                 WHERE rad.outcome = 'Upheld'
                                   AND (SELECT j.jobtypeid
                                          FROM api.jobs j
                                         WHERE j.jobid = rad.jobid) =
                                       api.pkg_configquery.objectdefidforname('j_Accusation')
                                   AND TRUNC(rad.datecompleted) BETWEEN CASE
                                                                            WHEN p_start_date < g_switch THEN
                                                                                p_start_date
                                                                            ELSE
                                                                                g_max
                                                                        END
                                                                    AND CASE
                                                                            WHEN p_start_date >= g_switch THEN
                                                                                g_max
                                                                            WHEN p_end_date >= g_switch THEN
                                                                                g_switch - 1
                                                                            ELSE
                                                                                p_end_date
                                                                        END
                                UNION
                                SELECT r.toobjectid objectid
                                  FROM TABLE(CAST(api.pkg_simplesearch.castableobjectsbyindexrange(
                                                      'l_DocketNoteUserLog',
                                                      'logdate',
                                                      TO_CHAR(
                                                          CASE
                                                              WHEN p_start_date >= g_switch THEN p_start_date
                                                              WHEN p_end_date >= g_switch THEN g_switch
                                                              ELSE g_max
                                                          END,
                                                          'YYYY-MM-DD'),
                                                      TO_CHAR(
                                                          CASE
                                                              WHEN p_start_date >= g_switch THEN p_end_date
                                                              WHEN p_end_date >= g_switch THEN p_end_date
                                                              ELSE g_max
                                                          END,
                                                          'YYYY-MM-DD')) AS api.udt_objectlist)) o
                                       JOIN api.relationships r
                                       ON r.fromobjectid = o.objectid
                                      AND r.endpointid IN
                                              (api.pkg_configquery.endpointidforname('l_DocketNoteUserLog',
                                                                                     'Accusation'),
                                               api.pkg_configquery.endpointidforname('l_DocketNoteUserLog',
                                                                                     'License'),
                                               api.pkg_configquery.endpointidforname('l_DocketNoteUserLog',
                                                                                     'Application'))
                                 WHERE api.pkg_columnquery.VALUE(o.objectid, 'eventcode') = 'ACC33'))
                           accsustained))
          INTO xml_temp
          FROM DUAL;

        SELECT APPENDCHILDXML(p_value, 'SECTION_1', xml_temp) INTO p_value FROM DUAL;

        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS THEN
            p_status_msg   :=
                   'Section 1 Data: '
                || DBMS_UTILITY.format_error_backtrace
                || ' :: '
                || SQLERRM;

            RETURN FALSE;
    END section1data;

    --*****************************************************************************
    FUNCTION section1(p_value        IN OUT XMLTYPE,
                      p_start_date   IN     DATE,
                      p_end_date     IN     DATE,
                      p_status_msg   IN OUT VARCHAR2)
        RETURN BOOLEAN
    IS
        xml_data   XMLTYPE := xmltype('<SECTION_1 HEADING=" "></SECTION_1>');
        lb_ok      BOOLEAN := TRUE;
    BEGIN
        lb_ok   :=
            section1data(p_value     => xml_data,
                         p_section_name => 'SECTION_1_3',
                         p_start_date => p_start_date,
                         p_end_date  => p_end_date,
                         p_status_msg => p_status_msg);

        IF (lb_ok) THEN
            lb_ok   :=
                section1data(p_value     => xml_data,
                             p_section_name => 'SECTION_1_2',
                             p_start_date => ADD_MONTHS(p_start_date, -12),
                             p_end_date  => ADD_MONTHS(p_end_date, -12),
                             p_status_msg => p_status_msg);
        END IF;

        IF (lb_ok) THEN
            lb_ok   :=
                section1data(p_value     => xml_data,
                             p_section_name => 'SECTION_1_1',
                             p_start_date => ADD_MONTHS(p_start_date, -24),
                             p_end_date  => ADD_MONTHS(p_end_date, -24),
                             p_status_msg => p_status_msg);
        END IF;

        IF (lb_ok) THEN
            SELECT APPENDCHILDXML(p_value, '/WORKLOAD', (SELECT EXTRACT(xml_data, '/SECTION_1') FROM DUAL))
              INTO p_value
              FROM DUAL;
        END IF;

        RETURN lb_ok;
    EXCEPTION
        WHEN OTHERS THEN
            p_status_msg   :=
                   'Section 1: '
                || DBMS_UTILITY.format_error_backtrace
                || ' :: '
                || SQLERRM;

            RETURN FALSE;
    END section1;


    --*****************************************************************************
    -- REVENUE MISCELLANEOUS STATUS
    -- Section 2
    --*****************************************************************************
    FUNCTION section2(p_value        IN OUT XMLTYPE,
                      p_start_date   IN     DATE,
                      p_end_date     IN     DATE,
                      p_status_msg   IN OUT VARCHAR2)
        RETURN BOOLEAN
    IS
        xml_temp           XMLTYPE;
        procsecstart       DATE := SYSDATE;
        elapse             NUMBER;
        elapsetimestring   VARCHAR2(20);
    BEGIN
        --  08/03/2021  TJL       - Change location where data for revenue is retrieve from
        abcreports.f_utils.get_revenue(p_start_date, p_end_date);

        elapse   := SYSDATE - procsecstart;

        --        elapseTimeString :=  TO_CHAR(EXTRACT(HOUR FROM NUMTODSINTERVAL(elapse, 'DAY')), 'FM00') || ':'
        --                         ||  TO_CHAR(EXTRACT(MINUTE FROM NUMTODSINTERVAL(elapse, 'DAY')), 'FM00') || ':'
        --                         ||  TO_CHAR(EXTRACT(SECOND FROM NUMTODSINTERVAL(elapse, 'DAY')), 'FM00');
        --        rqs_utils.log(p_log_type          =>  'I',
        --                      p_job_id            =>  p_parms.get_value('JOB_ID'),
        --                      p_seq               =>  p_parms.get_value('SEQ'),
        --                      p_source            =>  'Workload Summary Report',
        --                      p_msg               =>  'Section 2.1 - ' || elapseTimeString,
        --                      p_additional_data   =>  NULL,
        --                      p_error_trace       =>  NULL);

        SELECT XMLELEMENT("SECTION_2",
                          xmlattributes('REVENUE' AS "HEADING"),
                          XMLFOREST(renewalsannuals,
                                    originalfees,
                                    transfer,
                                    dailylicenses,
                                    cateventpermits,
                                    cateventauth,
                                    other,
                                    total,
                                    poicaccepted,
                                    poiccount,
                                    numofprotestlettersrec,
                                    prodecadopt,
                                    prodecreject,
                                    suspensions,
                                    revocations,
                                    appealsfiled,
                                    actionsfiledpending,
                                    swatty))
                   info
          INTO xml_temp
          FROM (SELECT ROUND(renewalsannuals)
                           renewalsannuals,
                       originalfees,
                       transfer,
                       dailylicenses,
                       cateventpermits,
                       cateventauth,
                       ROUND(
                             gt
                           - (  renewalsannuals
                              + originalfees
                              + transfer
                              + dailylicenses
                              + cateventpermits
                              + cateventauth
                              + poicaccepted)
                           -- 02/25/2019 tjl 11362  Added POIC to other total calculation
                           + poicaccepted)
                           other,
                       ROUND(gt)
                           total,
                       ROUND(poicaccepted)
                           poicaccepted,
                       poiccount,
                       numofprotestlettersrec,
                       prodecadopt,
                       prodecreject,
                       suspensions,
                       revocations,
                       appealsfiled,
                       actionsfiledpending,
                       swatty
                  FROM (-- ***** Renewals *****************************************
                        SELECT (SELECT -nvl((  SUM(fd.earnedamount)
                                         - SUM(fd.ab_surcharge)
                                         - SUM(fd.dmv_surcharge_amt)
                                         - SUM(fd.bpu_fee)
                                         + SUM(fd.penalties)), 0)
                                  FROM abcreports.f_transactions f
                                       JOIN abcreports.f_transactions_rpt fd
                                       ON f.transactionid = fd.feeid
                                 WHERE fd.earnedamount < 0
                                   AND fd.servicechargeamount = 0
                                   AND ((fd.feeactivity IN ('REN', 'REN50', 'REN100')
                                     AND f.feelicensetypecode NOT IN ('26',
                                                               '28',
                                                               '29',
                                                               '58',
                                                               '77'))
                                     OR (fd.feeactivity IN ('ANN')
                                     AND f.feelicensetypecode NOT IN ('26', '28'))
                                     OR (fd.feeactivity IN ('AWF'))
                                     OR (fd.feeactivity IN ('DOR')
                                     AND f.feelicensetypecode NOT IN ('06',  -- 03/23/2021 TJL 21921 removed selected license types
                                                               '58',
                                                               '66',
                                                               '67',
                                                               '77')))
                                   AND fd.objectdefname NOT IN ('j_MiscellaneousFee'))
                                   renewalsannuals,
                               -- ***** Originals *****************************************
                               (WITH
                                    fd
                                    AS
                                        (SELECT api.pkg_columnquery.VALUE(f.jobid, 'PrimaryLicenseTypeCodes')
                                                    primarylicensetypecodes,
                                                fd.*
                                           FROM abcreports.f_transactions f
                                                JOIN abcreports.f_transactions_rpt fd
                                                ON f.transactionid = fd.feeid
                                          WHERE fd.earnedamount < 0
                                            AND fd.servicechargeamount = 0
                                            AND (fd.feeactivity IN ('APP', 'ORI')
                                             AND fd.objectdefname NOT IN ('j_MiscellaneousFee')))
                                SELECT -nvl((  SUM(fd.earnedamount)
                                         - SUM(fd.ab_surcharge)
                                         - SUM(fd.dmv_surcharge_amt)
                                         - SUM(fd.bpu_fee)), 0)
                                  FROM fd fd
                                 WHERE LENGTH(primarylicensetypecodes) > 2
                                    OR (INSTR(primarylicensetypecodes, '26') = 0
                                    AND INSTR(primarylicensetypecodes, '28') = 0))
                                   originalfees,
                               -- ***** Transfers *****************************************
                               (SELECT -nvl((  SUM(fd.earnedamount)
                                         - SUM(fd.ab_surcharge)
                                         - SUM(fd.dmv_surcharge_amt)
                                         - SUM(fd.bpu_fee)), 0)
                                  FROM abcreports.f_transactions f
                                       JOIN abcreports.f_transactions_rpt fd
                                       ON f.transactionid = fd.feeid
                                 WHERE fd.earnedamount < 0
                                   AND fd.servicechargeamount = 0
                                   AND fd.feeactivity IN ('CD8',
                                                          'DPR',
                                                          'FID',
                                                          'EXC',
                                                          'ICO',
                                                          'MBM',
                                                          'MBR',
                                                          'PER',
                                                          'PRM',
                                                          'STK',
                                                          'STM',
                                                          'PERRFT',
                                                          'PREMPREM',
                                                          'PRMFID',
                                                          'PRMMBR',
                                                          'PRMMBM',
                                                          'PRMRFT',
                                                          'PRMPER',
                                                          'PRMSTK',
                                                          'PRMSTM',
                                                          'UMBR',
                                                          'UMBM',
                                                          'USTK',
                                                          'USTM')
                                   AND fd.objectdefname NOT IN ('j_MiscellaneousFee'))
                                   transfer,
                               -- ***** Daily *****************************************

                               (SELECT -nvl((  SUM(fd.earnedamount)
                                         - SUM(fd.ab_surcharge)
                                         - SUM(fd.dmv_surcharge_amt)
                                         - SUM(fd.bpu_fee)),0)
                                  FROM abcreports.f_transactions f
                                       JOIN abcreports.f_transactions_rpt fd
                                       ON f.transactionid = fd.feeid
                                 WHERE fd.earnedamount < 0
                                   AND fd.servicechargeamount = 0
                                   AND fd.feeactivity IN ('ODL',
                                                          'SPD',
                                                          'TST',
                                                          'SDV')
                                   AND fd.objectdefname NOT IN ('j_MiscellaneousFee'))
                                   dailylicenses,
                               -- ***** cater Permits *****************************************
                               (WITH
                                    fd
                                    AS
                                        (SELECT api.pkg_columnquery.VALUE(f.jobid, 'PrimaryLicenseTypeCodes')
                                                    primarylicensetypecodes,
                                                fd.*,
                                                f.feelicensetypecode
                                           FROM abcreports.f_transactions f
                                                JOIN abcreports.f_transactions_rpt fd
                                                ON f.transactionid = fd.feeid
                                          WHERE fd.earnedamount < 0
                                            AND fd.servicechargeamount = 0
                                            AND f.feelicensetypecode IN ('58', '77')
                                            AND (fd.feeactivity IN ('REN',
                                                                    'REN50',
                                                                    'REN100',
                                                                    'DOR')
                                             AND fd.objectdefname NOT IN ('j_MiscellaneousFee')))
                                SELECT -nvl((  SUM(fd.earnedamount)
                                         - SUM(fd.ab_surcharge)
                                         - SUM(fd.dmv_surcharge_amt)
                                         - SUM(fd.bpu_fee)),0)
                                  FROM fd fd
                                 WHERE (fd.feelicensetypecode = '58'
                                    AND (INSTR(primarylicensetypecodes, '50') = 0
                                     AND INSTR(primarylicensetypecodes, '51') = 0
                                     AND INSTR(primarylicensetypecodes, '52') = 0))
                                    OR fd.feelicensetypecode = '77')
                                   cateventpermits,
                               -- ***** Cater Auth *****************************************
                               (SELECT -nvl((  SUM(fd.earnedamount)
                                         - SUM(fd.ab_surcharge)
                                         - SUM(fd.dmv_surcharge_amt)
                                         - SUM(fd.bpu_fee)), 0)
                                  FROM abcreports.f_transactions f
                                       JOIN abcreports.f_transactions_rpt fd
                                       ON f.transactionid = fd.feeid
                                 WHERE fd.earnedamount < 0
                                   AND fd.servicechargeamount = 0
                                   AND fd.feeactivity IN ('CATA', 'EPA')
                                   AND fd.objectdefname NOT IN ('j_MiscellaneousFee'))
                                   cateventauth,
                               -- ***** Grand Total *****************************************
                               (SELECT -nvl((  SUM(fd.earnedamount)
                                         - SUM(fd.ab_surcharge)
                                         - SUM(fd.dmv_surcharge_amt)
                                         - SUM(fd.bpu_fee)), 0)
                                  FROM abcreports.f_transactions f
                                       JOIN abcreports.f_transactions_rpt fd
                                       ON f.transactionid = fd.feeid
                                 WHERE fd.earnedamount < 0
                                   AND fd.feeactivity NOT IN ('POIC')
                                   AND fd.objectdefname NOT IN ('j_MiscellaneousFee'))
                                   gt,
                               -- ***** POIC Count *****************************************
                               (SELECT COUNT(fd.feeid)
                                  FROM abcreports.f_transactions f
                                       JOIN abcreports.f_transactions_rpt fd
                                       ON f.transactionid = fd.feeid
                                 WHERE fd.earnedamount < 0
                                   AND fd.servicechargeamount = 0
                                   AND fd.feeactivity IN ('POIC')
                                   AND fd.objectdefname NOT IN ('j_MiscellaneousFee'))
                                   poiccount,
                               -- ***** POID Amount *****************************************
                               (SELECT -nvl((  SUM(fd.earnedamount)
                                         - SUM(fd.ab_surcharge)
                                         - SUM(fd.dmv_surcharge_amt)
                                         - SUM(fd.bpu_fee)),0)
                                           adjustedamount
                                  FROM abcreports.f_transactions f
                                       JOIN abcreports.f_transactions_rpt fd
                                       ON f.transactionid = fd.feeid
                                 WHERE fd.earnedamount < 0
                                   AND fd.servicechargeamount = 0
                                   AND fd.feeactivity IN ('POIC')
                                   AND fd.objectdefname NOT IN ('j_MiscellaneousFee'))
                                   poicaccepted
                          FROM DUAL-- end of new section
                                   -- ****************************************************

                                   -- ****************************************************
                                   -- Old section not used any more
                                   --                        SELECT   -(sec761096surg
                                   --                               + (
                                   --                                     SELECT NVL(SUM(amount), 0)
                                   --                                       FROM sitespecific.allocationreportdetail_gt
                                   --                                      WHERE allocationcode = 'ANNFEES'
                                   --                                 )
                                   --                               + (
                                   --                                     SELECT NVL(SUM(amount), 0)
                                   --                                       FROM sitespecific.allocationreportdetail_gt
                                   --                                      WHERE allocationcode = 'ANNFEES2'
                                   --                                 )
                                   --                                   )renewalsannuals,
                                   --                               -sec954ori originalfees,
                                   --                               -(exchange + sec070tranfr) transfer,
                                   --                               -(
                                   --                                   SELECT NVL(SUM(amount), 0)
                                   --                                     FROM sitespecific.allocationreportdetail_gt
                                   --                                    WHERE allocationcode = 'TMPDAILY'
                                   --                                      AND SUBSTR(transcode, 1, 3) NOT IN ('IPT', 'TPT')
                                   --                               )
                                   --                                   dailylicenses,
                                   --                               -(caterrpermit + epapermit) cateventpermits,
                                   --                               -(epaauth583 + caterrauth583) cateventauth,
                                   --                               -   -- 02/16/2019 tjl 11362  Removed POIC accepted from total
                                   --                                (sec954ori + exchange + sec070tranfr + sec053bpu +
                                   --                                sec357out + orioosc + sec959srvsmg +  epaauth583 +
                                   --                                caterrauth583 +  epapermit + caterrpermit + manageq321 +
                                   --                                penalty + privware + replace + sec761096surg +
                                   --                                sec761096nonsurg + sec659tag + sec659rec + cond803 +
                                   --                                other + unclaim)
                                   --                                    gt,
                                   --                               (
                                   --                                   SELECT NVL(COUNT(amount), 0)
                                   --                                     FROM sitespecific.allocationreportdetail_gt
                                   --                                    WHERE allocationcode = 'POIC'
                                   --                               )
                                   --                                   poiccount,
                                   --                               -poic poicaccepted
                                   --                          FROM sitespecific.allocationreport_gt

                                   -- Old section end
                                   -- ****************************************************
                                   )
                       FULL JOIN (SELECT COUNT(DISTINCT (jobid)) numofprotestlettersrec
                                    FROM mart.registerprotest rp
                                   WHERE TRUNC(rp.datecompleted) BETWEEN p_start_date AND p_end_date
                                     AND rp.outcome = 'Register') a
                       ON 1 = 1  --AppMisc
                       LEFT OUTER JOIN (--Proposed Decisions Adopted
                                        SELECT COUNT(objectid) prodecadopt
                                          FROM (SELECT DISTINCT rdd.jobid objectid
                                                  FROM mart.recorddirectordicision rdd
                                                 WHERE TRUNC(rdd.datecompleted) BETWEEN CASE
                                                                                            WHEN p_start_date <
                                                                                                 g_switch THEN
                                                                                                p_start_date
                                                                                            ELSE
                                                                                                g_max
                                                                                        END
                                                                                    AND CASE
                                                                                            WHEN p_start_date >=
                                                                                                 g_switch THEN
                                                                                                g_max
                                                                                            WHEN p_end_date >=
                                                                                                 g_switch THEN
                                                                                                g_switch - 1
                                                                                            ELSE
                                                                                                p_end_date
                                                                                        END
                                                   AND rdd.outcome = 'Adopt'
                                                UNION
                                                SELECT r.toobjectid objectid
                                                  FROM TABLE(CAST(api.pkg_simplesearch.castableobjectsbyindexrange(
                                                                      'l_DocketNoteUserLog',
                                                                      'logdate',
                                                                      TO_CHAR(
                                                                          CASE
                                                                              WHEN p_start_date >= g_switch THEN
                                                                                  p_start_date
                                                                              WHEN p_end_date >= g_switch THEN
                                                                                  g_switch
                                                                              ELSE
                                                                                  g_max
                                                                          END,
                                                                          'YYYY-MM-DD'),
                                                                      TO_CHAR(
                                                                          CASE
                                                                              WHEN p_start_date >= g_switch THEN
                                                                                  p_end_date
                                                                              WHEN p_end_date >= g_switch THEN
                                                                                  p_end_date
                                                                              ELSE
                                                                                  g_max
                                                                          END,
                                                                          'YYYY-MM-DD')) AS api.udt_objectlist)) o
                                                       JOIN api.relationships r
                                                       ON r.fromobjectid = o.objectid
                                                      AND r.endpointid IN
                                                              (api.pkg_configquery.endpointidforname(
                                                                   'l_DocketNoteUserLog',
                                                                   'Accusation'),
                                                               api.pkg_configquery.endpointidforname(
                                                                   'l_DocketNoteUserLog',
                                                                   'License'),
                                                               api.pkg_configquery.endpointidforname(
                                                                   'l_DocketNoteUserLog',
                                                                   'Application'))
                                                 WHERE api.pkg_columnquery.VALUE(o.objectid, 'eventcode') IN
                                                           ('33', 'ACC39', 'PRT18'))) a2
                       ON 1 = 1
                       LEFT OUTER JOIN (--Proposed Decisions Rejected under 11517(c)
                                        SELECT COUNT(objectid) prodecreject
                                          FROM (SELECT rdd.jobid objectid
                                                  FROM mart.recorddirectordicision rdd
                                                 WHERE TRUNC(rdd.datecompleted) BETWEEN CASE
                                                                                            WHEN p_start_date <
                                                                                                 g_switch THEN
                                                                                                p_start_date
                                                                                            ELSE
                                                                                                g_max
                                                                                        END
                                                                                    AND CASE
                                                                                            WHEN p_start_date >=
                                                                                                 g_switch THEN
                                                                                                g_max
                                                                                            WHEN p_end_date >=
                                                                                                 g_switch THEN
                                                                                                g_switch - 1
                                                                                            ELSE
                                                                                                p_end_date
                                                                                        END
                                                   AND rdd.outcome = 'Reject'
                                                UNION
                                                SELECT r.toobjectid objectid
                                                  FROM TABLE(CAST(api.pkg_simplesearch.castableobjectsbyindexrange(
                                                                      'l_DocketNoteUserLog',
                                                                      'logdate',
                                                                      TO_CHAR(
                                                                          CASE
                                                                              WHEN p_start_date >= g_switch THEN
                                                                                  p_start_date
                                                                              WHEN p_end_date >= g_switch THEN
                                                                                  g_switch
                                                                              ELSE
                                                                                  g_max
                                                                          END,
                                                                          'YYYY-MM-DD'),
                                                                      TO_CHAR(
                                                                          CASE
                                                                              WHEN p_start_date >= g_switch THEN
                                                                                  p_end_date
                                                                              WHEN p_end_date >= g_switch THEN
                                                                                  p_end_date
                                                                              ELSE
                                                                                  g_max
                                                                          END,
                                                                          'YYYY-MM-DD')) AS api.udt_objectlist)) o
                                                       JOIN api.relationships r
                                                       ON r.fromobjectid = o.objectid
                                                      AND r.endpointid IN
                                                              (api.pkg_configquery.endpointidforname(
                                                                   'l_DocketNoteUserLog',
                                                                   'Accusation'),
                                                               api.pkg_configquery.endpointidforname(
                                                                   'l_DocketNoteUserLog',
                                                                   'License'),
                                                               api.pkg_configquery.endpointidforname(
                                                                   'l_DocketNoteUserLog',
                                                                   'Application'))
                                                 WHERE api.pkg_columnquery.VALUE(o.objectid, 'eventcode') IN
                                                           ('ACC31', 'PRT22'))) b
                       ON 1 = 1
                       LEFT OUTER JOIN (--Suspensions (Definition: OLS receives 122)
                                        SELECT COUNT(DISTINCT o.objectid) suspensions
                                          FROM TABLE(
                                                   CAST(api.pkg_simplesearch.castableobjectsbyindexrange(
                                                            'l_DocketNoteUserLog',
                                                            'logdate',
                                                            TO_CHAR(p_start_date, 'YYYY-MM-DD'),
                                                            TO_CHAR(p_end_date, 'YYYY-MM-DD')) AS api.udt_objectlist))
                                               o
                                         WHERE api.pkg_columnquery.VALUE(o.objectid, 'eventcode') IN ('34', 'ACC36'))
                                       c
                       ON 1 = 1
                       LEFT OUTER JOIN (--Revocations Including Those Stayed
                                        SELECT COUNT(objectid) revocations
                                          FROM (SELECT etd.jobid objectid
                                                  FROM mart.executetermsofdecision etd
                                                 WHERE TRUNC(etd.datecompleted) BETWEEN CASE
                                                                                            WHEN p_start_date <
                                                                                                 g_switch THEN
                                                                                                p_start_date
                                                                                            ELSE
                                                                                                g_max
                                                                                        END
                                                                                    AND CASE
                                                                                            WHEN p_start_date >=
                                                                                                 g_switch THEN
                                                                                                g_max
                                                                                            WHEN p_end_date >=
                                                                                                 g_switch THEN
                                                                                                g_switch - 1
                                                                                            ELSE
                                                                                                p_end_date
                                                                                        END
                                                   AND (etd.outcome = 'Revoked'
                                                     OR etd.outcome = 'Revocation Stayed')
                                                UNION
                                                SELECT r.toobjectid objectid
                                                  FROM TABLE(CAST(api.pkg_simplesearch.castableobjectsbyindexrange(
                                                                      'l_DocketNoteUserLog',
                                                                      'logdate',
                                                                      TO_CHAR(
                                                                          CASE
                                                                              WHEN p_start_date >= g_switch THEN
                                                                                  p_start_date
                                                                              WHEN p_end_date >= g_switch THEN
                                                                                  g_switch
                                                                              ELSE
                                                                                  g_max
                                                                          END,
                                                                          'YYYY-MM-DD'),
                                                                      TO_CHAR(
                                                                          CASE
                                                                              WHEN p_start_date >= g_switch THEN
                                                                                  p_end_date
                                                                              WHEN p_end_date >= g_switch THEN
                                                                                  p_end_date
                                                                              ELSE
                                                                                  g_max
                                                                          END,
                                                                          'YYYY-MM-DD')) AS api.udt_objectlist)) o
                                                       JOIN api.relationships r
                                                       ON r.fromobjectid = o.objectid
                                                      AND r.endpointid IN
                                                              (api.pkg_configquery.endpointidforname(
                                                                   'l_DocketNoteUserLog',
                                                                   'Accusation'),
                                                               api.pkg_configquery.endpointidforname(
                                                                   'l_DocketNoteUserLog',
                                                                   'License'),
                                                               api.pkg_configquery.endpointidforname(
                                                                   'l_DocketNoteUserLog',
                                                                   'Application'))
                                                 WHERE api.pkg_columnquery.VALUE(o.objectid, 'eventcode') = 'ACC34'))
                                       d
                       ON 1 = 1
                       LEFT OUTER JOIN (--Appeals Filed to Appeals Board
                                        SELECT COUNT(objectid) appealsfiled
                                          FROM (SELECT r.jobid objectid
                                                  FROM api.processes r
                                                 WHERE r.processid IN
                                                           (SELECT processid
                                                              FROM query.p_receivenoticeofappeal n
                                                             WHERE n.scheduledstartdate BETWEEN CASE
                                                                                                    WHEN p_start_date <
                                                                                                         g_switch THEN
                                                                                                        p_start_date
                                                                                                    ELSE
                                                                                                        g_max
                                                                                                END
                                                                                            AND CASE
                                                                                                    WHEN p_start_date >=
                                                                                                         g_switch THEN
                                                                                                        g_max
                                                                                                    WHEN p_end_date >=
                                                                                                         g_switch THEN
                                                                                                        g_switch - 1
                                                                                                    ELSE
                                                                                                        p_end_date
                                                                                                END)
                                                   AND outcome = 'Receive'
                                                UNION
                                                SELECT r.toobjectid objectid
                                                  FROM TABLE(CAST(api.pkg_simplesearch.castableobjectsbyindexrange(
                                                                      'l_DocketNoteUserLog',
                                                                      'logdate',
                                                                      TO_CHAR(
                                                                          CASE
                                                                              WHEN p_start_date >= g_switch THEN
                                                                                  p_start_date
                                                                              WHEN p_end_date >= g_switch THEN
                                                                                  g_switch
                                                                              ELSE
                                                                                  g_max
                                                                          END,
                                                                          'YYYY-MM-DD'),
                                                                      TO_CHAR(
                                                                          CASE
                                                                              WHEN p_start_date >= g_switch THEN
                                                                                  p_end_date
                                                                              WHEN p_end_date >= g_switch THEN
                                                                                  p_end_date
                                                                              ELSE
                                                                                  g_max
                                                                          END,
                                                                          'YYYY-MM-DD')) AS api.udt_objectlist)) o
                                                       JOIN api.relationships r
                                                       ON r.fromobjectid = o.objectid
                                                      AND r.endpointid IN
                                                              (api.pkg_configquery.endpointidforname(
                                                                   'l_DocketNoteUserLog',
                                                                   'Accusation'),
                                                               api.pkg_configquery.endpointidforname(
                                                                   'l_DocketNoteUserLog',
                                                                   'License'),
                                                               api.pkg_configquery.endpointidforname(
                                                                   'l_DocketNoteUserLog',
                                                                   'Application'))
                                                 WHERE api.pkg_columnquery.VALUE(o.objectid, 'eventcode') IN
                                                           ('APL01', 'APP01'))) d
                       ON 1 = 1
                       LEFT OUTER JOIN (--Court Actions Filed/Pending
                                        SELECT COUNT(DISTINCT o.objectid) actionsfiledpending
                                          FROM TABLE(
                                                   CAST(api.pkg_simplesearch.castableobjectsbyindexrange(
                                                            'l_DocketNoteUserLog',
                                                            'logdate',
                                                            TO_CHAR(p_start_date, 'YYYY-MM-DD'),
                                                            TO_CHAR(p_end_date, 'YYYY-MM-DD')) AS api.udt_objectlist))
                                               o
                                         WHERE api.pkg_columnquery.VALUE(o.objectid, 'eventcode') = 'APP16') e
                       ON 1 = 1
                       LEFT OUTER JOIN (-- Stipulation and Waiver Received After ATTY Assignment
                                        SELECT COUNT(DISTINCT o.objectid) swatty
                                          FROM TABLE(
                                                   CAST(api.pkg_simplesearch.castableobjectsbyindexrange(
                                                            'l_DocketNoteUserLog',
                                                            'logdate',
                                                            TO_CHAR(p_start_date, 'YYYY-MM-DD'),
                                                            TO_CHAR(p_end_date, 'YYYY-MM-DD')) AS api.udt_objectlist))
                                               o
                                         WHERE api.pkg_columnquery.VALUE(o.objectid, 'eventcode') IN ('16A', 'ACC16'))
                                       e
                       ON 1 = 1);

        SELECT APPENDCHILDXML(p_value, '/WORKLOAD', xml_temp) INTO p_value FROM DUAL;

        elapsetimestring   :=
               TO_CHAR(EXTRACT(HOUR FROM NUMTODSINTERVAL(elapse, 'DAY')), 'FM00')
            || ':'
            || TO_CHAR(EXTRACT(MINUTE FROM NUMTODSINTERVAL(elapse, 'DAY')), 'FM00')
            || ':'
            || TO_CHAR(EXTRACT(SECOND FROM NUMTODSINTERVAL(elapse, 'DAY')), 'FM00');
        rqs_utils.LOG(p_log_type  => 'I',
                      p_job_id    => p_parms.get_value('JOB_ID'),
                      p_seq       => p_parms.get_value('SEQ'),
                      p_source    => 'Workload Summary Report',
                      p_msg       =>   'Section 2.1 - '
                                    || elapsetimestring,
                      p_additional_data => NULL,
                      p_error_trace => NULL);

        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS THEN
            p_status_msg   :=
                   'Section 2: '
                || DBMS_UTILITY.format_error_backtrace
                || ' :: '
                || SQLERRM;

            RETURN FALSE;
    END section2;


    --*****************************************************************************
    -- APPLICATION AND LICENSING INVESTIGATIONS REPORT LAYOUT PART 1
    -- Section 3
    --*****************************************************************************
    FUNCTION section3(p_value        IN OUT XMLTYPE,
                      p_start_date   IN     DATE,
                      p_end_date     IN     DATE,
                      p_status_msg   IN OUT VARCHAR2)
        RETURN BOOLEAN
    IS
        xml_temp   XMLTYPE;
    BEGIN
          SELECT XMLELEMENT(
                     "SECTION_3",
                     xmlattributes('APPLICATION AND LICENSING INVESTIGATIONS' AS "HEADING"),
                     XMLAGG(
                         XMLELEMENT(
                             "OFFICE",
                             xmlattributes(
                                 CASE
                                     WHEN NVL(o.rqsexclude, 'N') NOT IN ('H', 'B') THEN
                                         UPPER(NVL(o.division, 'HEADQUARTERS'))
                                     ELSE
                                         'HEADQUARTERS'
                                 END
                                     AS "DIVISION",
                                 SUBSTR(o.officename, 1, 20) AS "OFFICENAME"),
                             XMLELEMENT("RECEIVED", NVL(received, 0)),
                             XMLELEMENT(
                                 "ORIGINAL",
                                 XMLELEMENT("PENDBEG", NVL(pendbegoriginal, 0)),
                                 XMLELEMENT("RECEIVED", NVL(receivedoriginal, 0)),
                                 XMLELEMENT(
                                     "COMPLETED",
                                     NVL(approvedoriginal, 0) + NVL(deniedoriginal, 0) + NVL(withdrawnoriginal, 0)),
                                 XMLELEMENT("APPROVED", NVL(approvedoriginal, 0)),
                                 XMLELEMENT("DENIED", NVL(deniedoriginal, 0)),
                                 XMLELEMENT("WITHDRAWN", NVL(withdrawnoriginal, 0)),
                                 XMLELEMENT("VOIDED", NVL(voidedoriginal, 0)),
                                 XMLELEMENT("NOCRDWDRN", NVL(nocreditwthdoriginal, 0)),
                                 XMLELEMENT(
                                     "PENDEND",
                                       NVL(pendbegoriginal, 0)
                                     + NVL(receivedoriginal, 0)
                                     - (NVL(approvedoriginal, 0) + NVL(deniedoriginal, 0) + NVL(withdrawnoriginal, 0))
                                     - NVL(voidedoriginal, 0))),
                             XMLELEMENT(
                                 "PERTOPER",
                                 XMLELEMENT("PENDBEG", NVL(pendbegpertoper, 0)),
                                 XMLELEMENT("RECEIVED", NVL(receivedpertoper, 0)),
                                 XMLELEMENT(
                                     "COMPLETED",
                                     NVL(approvedpertoper, 0) + NVL(deniedpertoper, 0) + NVL(withdrawnpertoper, 0)),
                                 XMLELEMENT("APPROVED", NVL(approvedpertoper, 0)),
                                 XMLELEMENT("DENIED", NVL(deniedpertoper, 0)),
                                 XMLELEMENT("WITHDRAWN", NVL(withdrawnpertoper, 0)),
                                 XMLELEMENT("VOIDED", NVL(voidedpertoper, 0)),
                                 XMLELEMENT("NOCRDWDRN", NVL(nocreditwthdpertoper, 0)),
                                 XMLELEMENT(
                                     "PENDEND",
                                       NVL(pendbegpertoper, 0)
                                     + NVL(receivedpertoper, 0)
                                     - (NVL(approvedpertoper, 0) + NVL(deniedpertoper, 0) + NVL(withdrawnpertoper, 0))
                                     - NVL(voidedpertoper, 0))))))
            INTO xml_temp
            FROM query.o_office o
                 ------------------------------------------------------------------------------------------------
                 -- Pending Begining
                 ------------------------------------------------------------------------------------------------
                 LEFT OUTER JOIN (  SELECT basefileofficeid,
                                           SUM(CASE WHEN abc19original = 'Y' THEN 1 ELSE 0 END)
                                               pendbegoriginal,
                                           SUM(CASE
                                                   WHEN abc19original != 'Y'
                                                    AND abc19pertoper = 'Y' THEN
                                                       1
                                                   ELSE
                                                       0
                                               END)
                                               pendbegpertoper
                                      FROM mart.application a
                                     WHERE a.haslicensetype79 = 'N'
                                       AND a.haslicensetype84 = 'N'
                                       AND TRUNC(a.enterapplicationcompleteddate) < p_start_date
                                       AND EXISTS
                                               (SELECT 1
                                                  FROM extension.jobstatuschange j
                                                 WHERE j.jobid = a.objectid
                                                   AND j.statusname IN ('PEND', 'APPLD', 'ISSUPD')
                                                   AND (TRUNC(j.effectivestartdate) < p_start_date
                                                    AND (j.effectiveenddate IS NULL
                                                      OR TRUNC(j.effectiveenddate) >= p_start_date)))
                                       AND (TRUNC(a.districtappreviewprocdate) >= p_start_date
                                         OR (TRUNC(a.districtappreviewprocdate) IS NULL
                                         AND EXISTS
                                                 (SELECT 1
                                                    FROM extension.jobstatuschange j
                                                   WHERE j.jobid = a.objectid
                                                     AND j.statusname IN ('PEND', 'APPLD', 'ISSUPD')
                                                     AND (TRUNC(j.effectivestartdate) < p_start_date
                                                      AND (j.effectiveenddate IS NULL
                                                        OR TRUNC(j.effectiveenddate) >= p_start_date)))
                                         AND NOT EXISTS
                                                 (SELECT 1
                                                    FROM extension.jobstatuschange j
                                                   WHERE j.jobid = a.objectid
                                                     AND j.statusname IN ('ISSUED',
                                                                          'DENIED',
                                                                          'WTHDRN',
                                                                          'VOIDED')
                                                     AND (TRUNC(j.effectivestartdate) < p_start_date
                                                      AND (j.effectiveenddate IS NULL
                                                        OR TRUNC(j.effectiveenddate) >= p_start_date)))))
                                  GROUP BY basefileofficeid) pendingbegining
                 ON pendingbegining.basefileofficeid = o.objectid
                 -------------------------------------------------------------------------------------------------------------
                 -- Received, Received Original, and Received Per to Per
                 -------------------------------------------------------------------------------------------------------------
                 LEFT OUTER JOIN (  SELECT a.basefileofficeid,
                                           SUM(CASE
                                                   WHEN a.abc19original = 'Y'
                                                     OR a.abc19pertoper = 'Y' THEN
                                                       1
                                                   ELSE
                                                       0
                                               END)
                                               received,
                                           SUM(CASE WHEN a.abc19original = 'Y' THEN 1 ELSE 0 END)
                                               receivedoriginal,
                                           SUM(CASE
                                                   WHEN a.abc19original != 'Y'
                                                    AND a.abc19pertoper = 'Y' THEN
                                                       1
                                                   ELSE
                                                       0
                                               END)
                                               receivedpertoper
                                      FROM mart.application a
                                     WHERE a.haslicensetype79 = 'N'
                                       AND a.haslicensetype84 = 'N'
                                       AND a.statusname <> 'NEW'
                                       AND a.abc19apptype IS NOT NULL
                                       AND TRUNC(enterapplicationcompleteddate) BETWEEN p_start_date AND p_end_date
                                  GROUP BY a.basefileofficeid) abcr
                 ON abcr.basefileofficeid = o.objectid
                 -------------------------------------------------------------------------------------------------------------
                 -- Approved Original and Per to Per
                 -------------------------------------------------------------------------------------------------------------
                 LEFT OUTER JOIN (  SELECT basefileofficeid,
                                           SUM(CASE WHEN abc19original = 'Y' THEN 1 ELSE 0 END)
                                               approvedoriginal,
                                           SUM(CASE
                                                   WHEN abc19original != 'Y'
                                                    AND abc19pertoper = 'Y' THEN
                                                       1
                                                   ELSE
                                                       0
                                               END)
                                               approvedpertoper
                                      FROM (SELECT a.basefileofficeid, a.abc19original, a.abc19pertoper
                                              FROM mart.districtapplicationreview d
                                                   JOIN mart.application a
                                                   ON a.objectid = d.jobid
                                             WHERE d.haslicensetype79 = 'N'
                                               AND d.haslicensetype84 = 'N'
                                               AND TRUNC(d.datecompleted) BETWEEN p_start_date AND p_end_date
                                               AND d.outcome IN
                                                       ('224 Approval',
                                                        'Approve Application',
                                                        'Approve With Division Review')
                                               AND d.objectid IN (  SELECT MIN(d1.objectid)
                                                                      FROM mart.districtapplicationreview d1
                                                                     WHERE d1.jobid = d.jobid
                                                                  GROUP BY d1.jobid)
                                            UNION ALL
                                            SELECT a.basefileofficeid, a.abc19original, a.abc19pertoper
                                              FROM mart.issuelicense p
                                                   JOIN mart.application a
                                                   ON a.objectid = p.jobid
                                             WHERE a.haslicensetype79 = 'N'
                                               AND a.haslicensetype84 = 'N'
                                               AND datecompleted BETWEEN p_start_date AND p_end_date
                                               AND p.outcome IS NOT NULL
                                               AND EXISTS
                                                       (SELECT 1
                                                          FROM extension.jobstatuschange_t j
                                                         WHERE j.jobid = a.objectid
                                                           AND j.statusname = 'ISSUED'
                                                           AND TRUNC(j.effectivestartdate) BETWEEN p_start_date
                                                                                               AND p_end_date)
                                               AND p.objectid IN (  SELECT MIN(p2.objectid)
                                                                      FROM mart.issuelicense p2
                                                                     WHERE p2.jobid = a.objectid
                                                                  GROUP BY p2.jobid)
                                               AND NOT EXISTS
                                                       (SELECT 1
                                                          FROM mart.districtapplicationreview d
                                                         WHERE d.jobid = a.objectid
                                                           AND d.outcome IS NOT NULL))
                                  GROUP BY basefileofficeid) approved
                 ON approved.basefileofficeid = o.objectid
                 -------------------------------------------------------------------------------------------------------------
                 -- Denied Original and Per to Per
                 -------------------------------------------------------------------------------------------------------------
                 LEFT OUTER JOIN (  SELECT basefileofficeid,
                                           SUM(CASE WHEN abc19original = 'Y' THEN 1 ELSE 0 END)
                                               deniedoriginal,
                                           SUM(CASE
                                                   WHEN abc19original != 'Y'
                                                    AND abc19pertoper = 'Y' THEN
                                                       1
                                                   ELSE
                                                       0
                                               END)
                                               deniedpertoper
                                      FROM (SELECT a.basefileofficeid, a.abc19original, a.abc19pertoper
                                              FROM mart.districtapplicationreview d
                                                   JOIN mart.application a
                                                   ON a.objectid = d.jobid
                                             WHERE d.haslicensetype79 = 'N'
                                               AND d.haslicensetype84 = 'N'
                                               AND d.datecompleted BETWEEN p_start_date AND p_end_date
                                               AND d.outcome = 'Deny With Division Review'
                                               AND d.objectid IN (  SELECT MIN(d1.objectid)
                                                                      FROM mart.districtapplicationreview d1
                                                                     WHERE d1.jobid = d.jobid
                                                                  GROUP BY d1.jobid)
                                            UNION ALL
                                            SELECT a.basefileofficeid, a.abc19original, a.abc19pertoper
                                              FROM mart.recorddirectordicision p
                                                   JOIN mart.application a
                                                   ON a.objectid = p.jobid
                                             WHERE a.haslicensetype79 = 'N'
                                               AND a.haslicensetype84 = 'N'
                                               AND p.datecompleted BETWEEN p_start_date AND p_end_date
                                               AND p.outcome IS NOT NULL
                                               AND EXISTS
                                                       (SELECT 1
                                                          FROM extension.jobstatuschange_t j
                                                         WHERE j.jobid = a.objectid
                                                           AND j.statusname = 'DENIED'
                                                           AND TRUNC(j.effectivestartdate) BETWEEN p_start_date
                                                                                               AND p_end_date)
                                               AND p.objectid IN (  SELECT MIN(p2.objectid)
                                                                      FROM mart.recorddirectordicision p2
                                                                     WHERE p2.jobid = a.objectid
                                                                  GROUP BY p2.jobid)
                                               AND NOT EXISTS
                                                       (SELECT 1
                                                          FROM mart.districtapplicationreview d
                                                         WHERE d.jobid = a.objectid
                                                           AND d.outcome IS NOT NULL))
                                  GROUP BY basefileofficeid) denied
                 ON denied.basefileofficeid = o.objectid
                 -------------------------------------------------------------------------------------------------------------
                 -- Withdrawn Original and Per to Per
                 -------------------------------------------------------------------------------------------------------------
                 LEFT OUTER JOIN (  SELECT basefileofficeid,
                                           SUM(CASE WHEN abc19original = 'Y' THEN 1 ELSE 0 END)
                                               withdrawnoriginal,
                                           SUM(CASE
                                                   WHEN abc19original != 'Y'
                                                    AND abc19pertoper = 'Y' THEN
                                                       1
                                                   ELSE
                                                       0
                                               END)
                                               withdrawnpertoper
                                      FROM (SELECT a.basefileofficeid, a.abc19original, a.abc19pertoper
                                              FROM mart.districtapplicationreview d
                                                   JOIN mart.application a
                                                   ON a.objectid = d.jobid
                                             WHERE d.haslicensetype79 = 'N'
                                               AND d.haslicensetype84 = 'N'
                                               AND d.datecompleted BETWEEN p_start_date AND p_end_date
                                               AND d.outcome = 'Withdraw'
                                               AND a.enterapplicationcompleteddate IS NOT NULL
                                               AND d.objectid IN (  SELECT MIN(d1.objectid)
                                                                      FROM mart.districtapplicationreview d1
                                                                     WHERE d1.jobid = d.jobid
                                                                  GROUP BY d1.jobid)
                                            UNION ALL
                                            SELECT a.basefileofficeid, a.abc19original, a.abc19pertoper
                                              FROM mart.withdrawapplication p
                                                   JOIN mart.application a
                                                   ON a.objectid = p.jobid
                                             WHERE a.haslicensetype79 = 'N'
                                               AND a.haslicensetype84 = 'N'
                                               AND p.datecompleted BETWEEN p_start_date AND p_end_date
                                               AND p.outcome IS NOT NULL
                                               AND a.enterapplicationcompleteddate IS NOT NULL
                                               AND EXISTS
                                                       (SELECT 1
                                                          FROM extension.jobstatuschange_t j
                                                         WHERE j.jobid = a.objectid
                                                           AND j.statusname = 'WTHDRN'
                                                           AND TRUNC(j.effectivestartdate) BETWEEN p_start_date
                                                                                               AND p_end_date)
                                               AND p.objectid IN (  SELECT MIN(p2.objectid)
                                                                      FROM mart.withdrawapplication p2
                                                                     WHERE p2.jobid = a.objectid
                                                                  GROUP BY p2.jobid)
                                               AND NOT EXISTS
                                                       (SELECT 1
                                                          FROM mart.districtapplicationreview d
                                                         WHERE d.jobid = a.objectid
                                                           AND d.outcome IS NOT NULL))
                                  GROUP BY basefileofficeid) withdrawn
                 ON withdrawn.basefileofficeid = o.objectid
                 -------------------------------------------------------------------------------------------------------------
                 -- Voided Original and Per to Per
                 -------------------------------------------------------------------------------------------------------------
                 LEFT OUTER JOIN (  SELECT basefileofficeid,
                                           SUM(CASE WHEN abc19original = 'Y' THEN 1 ELSE 0 END)
                                               voidedoriginal,
                                           SUM(CASE
                                                   WHEN abc19original != 'Y'
                                                    AND abc19pertoper = 'Y' THEN
                                                       1
                                                   ELSE
                                                       0
                                               END)
                                               voidedpertoper
                                      FROM mart.application a
                                     WHERE a.haslicensetype79 = 'N'
                                       AND a.haslicensetype84 = 'N'
                                       AND EXISTS
                                               (SELECT 1
                                                  FROM extension.jobstatuschange j
                                                 WHERE j.jobid = a.objectid
                                                   AND j.statusname = 'VOIDED'
                                                   AND j.effectivestartdate BETWEEN p_start_date AND p_end_date
                                                   AND (SELECT js2.statusname
                                                          FROM extension.jobstatuschange js2
                                                         WHERE js2.jobstatuschangeid =
                                                               (SELECT MAX(js.jobstatuschangeid)  -- Gets the previous status
                                                                  FROM extension.jobstatuschange js
                                                                 WHERE js.jobid = a.objectid
                                                                   AND js.jobstatuschangeid < j.jobstatuschangeid)) <>
                                                       'NEW')
                                  GROUP BY basefileofficeid) voided
                 ON voided.basefileofficeid = o.objectid
                 -------------------------------------------------------------------------------------------------------------
                 -- No Credit Withdrawan
                 -------------------------------------------------------------------------------------------------------------
                 LEFT OUTER JOIN (  SELECT basefileofficeid,
                                           SUM(CASE WHEN a.abc19original = 'Y' THEN 1 ELSE 0 END)
                                               nocreditwthdoriginal,
                                           SUM(CASE
                                                   WHEN a.abc19original != 'Y'
                                                    AND a.abc19pertoper = 'Y' THEN
                                                       1
                                                   ELSE
                                                       0
                                               END)
                                               nocreditwthdpertoper
                                      FROM mart.districtapplicationreview d
                                           JOIN mart.application a
                                           ON a.objectid = d.jobid
                                     WHERE d.haslicensetype79 = 'N'
                                       AND d.haslicensetype84 = 'N'
                                       AND d.datecompleted BETWEEN p_start_date AND p_end_date
                                       AND d.outcome != 'Withdraw'
                                       AND a.enterapplicationcompleteddate IS NOT NULL
                                       AND d.objectid IN (  SELECT MIN(d1.objectid)
                                                              FROM mart.districtapplicationreview d1
                                                             WHERE d1.jobid = d.jobid
                                                          GROUP BY d1.jobid)
                                       AND EXISTS
                                               (SELECT 1
                                                  FROM extension.jobstatuschange_t j
                                                 WHERE j.statusname = 'WTHDRN'
                                                   AND j.jobstatuschangeid =
                                                       (SELECT MAX(j.jobstatuschangeid)
                                                          FROM extension.jobstatuschange_t j
                                                         WHERE j.jobid = a.objectid
                                                           AND TRUNC(j.effectivestartdate) BETWEEN p_start_date
                                                                                               AND p_end_date))
                                       AND NOT EXISTS
                                               (SELECT 1
                                                  FROM extension.jobstatuschange_t j
                                                 WHERE j.statusname = 'ISSUED'
                                                   AND j.jobid = a.objectid)
                                  GROUP BY basefileofficeid) nocreditwthd
                 ON nocreditwthd.basefileofficeid = o.objectid
           WHERE o.isactive = 'Y'
        ORDER BY officename;

        -- add information to main report
        SELECT APPENDCHILDXML(p_value, '/WORKLOAD', (SELECT EXTRACT(xml_temp, '/SECTION_3') FROM DUAL))
          INTO p_value
          FROM DUAL;

        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS THEN
            p_status_msg   :=
                   'Section 3: '
                || DBMS_UTILITY.format_error_backtrace
                || ' :: '
                || SQLERRM;

            RETURN FALSE;
    END section3;


    --*****************************************************************************
    -- APPLICATION AND LICENSING INVESTIGATIONS REPORT LAYOUT PART 2
    -- Section 4
    --*****************************************************************************
    FUNCTION section4(p_value        IN OUT XMLTYPE,
                      p_start_date   IN     DATE,
                      p_end_date     IN     DATE,
                      p_status_msg   IN OUT VARCHAR2)
        RETURN BOOLEAN
    IS
        xml_temp   XMLTYPE;
    BEGIN
          SELECT XMLELEMENT(
                     "SECTION_4",
                     xmlattributes('APPLICATION AND LICENSING INVESTIGATIONS (continue)' AS "HEADING"),
                     XMLAGG(
                         XMLELEMENT(
                             "OFFICE",
                             XMLFOREST(
                                 SUBSTR(o.officename, 1, 20) officename,
                                 CASE
                                     WHEN NVL(o.rqsexclude, 'N') NOT IN ('H', 'B') THEN
                                         UPPER(NVL(o.division, 'HEADQUARTERS'))
                                     ELSE
                                         'HEADQUARTERS'
                                 END
                                     division,
                                 NVL(pri.priorityrecd, 0) priorityrecd,
                                 t.proapps,
                                 NVL(t2.regpro, 0) regpro,
                                 NVL(t3.regpet, 0) regpet,
                                 NVL(t2.regpro, 0) + NVL(t3.regpet, 0) totalpetpro)
                                 querydata)))
                     info
            INTO xml_temp
            FROM query.o_office o
                 LEFT OUTER JOIN (  SELECT api.pkg_columnquery.VALUE(p.objectid, 'BaseFileOfficeName') office,
                                           NVL(COUNT(DISTINCT p.objectid), 0)                      proapps
                                      FROM TABLE(CAST(api.pkg_simplesearch.castableobjectsbyindexrange(
                                                          'j_Application',
                                                          'CreatedDate',
                                                          TO_CHAR(p_start_date, 'YYYY-MM-DD'),
                                                          TO_CHAR(p_end_date, 'YYYY-MM-DD')) AS api.udt_objectlist)) p
                                           JOIN query.r_applicationprotestant r
                                           ON r.applicationjobid = p.objectid
                                  GROUP BY api.pkg_columnquery.VALUE(p.objectid, 'BaseFileOfficeName')
                                  ORDER BY office) t
                 ON o.officename = t.office
                 LEFT OUTER JOIN (  --Total Applications Registered/Protests
                                    SELECT api.pkg_columnquery.VALUE(r.toobjectid, 'BaseFileOfficeName') office,
                                           NVL(COUNT(DISTINCT r.toobjectid), 0)                      regpro
                                      FROM TABLE(CAST(api.pkg_simplesearch.castableobjectsbyindexrange(
                                                          'l_DocketNoteUserLog',
                                                          'logdate',
                                                          TO_CHAR(p_start_date, 'YYYY-MM-DD'),
                                                          TO_CHAR(p_end_date, 'YYYY-MM-DD')) AS api.udt_objectlist)) o
                                           JOIN api.relationships r
                                           ON r.fromobjectid = o.objectid
                                          AND r.endpointid =
                                              api.pkg_configquery.endpointidforname('l_DocketNoteUserLog', 'Application')
                                     WHERE api.pkg_columnquery.VALUE(o.objectid, 'eventcode') = 'PRT12'
                                  GROUP BY api.pkg_columnquery.VALUE(r.toobjectid, 'BaseFileOfficeName')
                                  ORDER BY office) t2
                 ON o.officename = t2.office
                 LEFT OUTER JOIN (  --Total Applications Registered/PET
                                    SELECT api.pkg_columnquery.VALUE(r.toobjectid, 'BaseFileOfficeName') office,
                                           NVL(COUNT(DISTINCT r.toobjectid), 0)                      regpet
                                      FROM TABLE(CAST(api.pkg_simplesearch.castableobjectsbyindexrange(
                                                          'l_DocketNoteUserLog',
                                                          'logdate',
                                                          TO_CHAR(p_start_date, 'YYYY-MM-DD'),
                                                          TO_CHAR(p_end_date, 'YYYY-MM-DD')) AS api.udt_objectlist)) o
                                           JOIN api.relationships r
                                           ON r.fromobjectid = o.objectid
                                          AND r.endpointid =
                                              api.pkg_configquery.endpointidforname('l_DocketNoteUserLog', 'Application')
                                     WHERE api.pkg_columnquery.VALUE(o.objectid, 'eventcode') = 'PMC06'
                                  GROUP BY api.pkg_columnquery.VALUE(r.toobjectid, 'BaseFileOfficeName')
                                  ORDER BY office) t3
                 ON o.officename = t3.office
                 LEFT OUTER JOIN (  SELECT d.office, COUNT(d.office) priorityrecd
                                      FROM (--  06/25/2020  TJL 21921 - Changed how priority applications are counted
                                            WITH
                                                applications
                                                AS
                                                    (SELECT objectid,
                                                            api.pkg_columnquery.VALUE(objectid, 'IsPriorityApplication')
                                                                ispriorityapplication,
                                                            api.pkg_columnquery.VALUE(objectid, 'StatusName')
                                                                statusname,
                                                            api.pkg_columnquery.VALUE(objectid, 'BaseFileOfficeCorral')
                                                                office
                                                       FROM TABLE(
                                                                CAST(
                                                                    api.pkg_simplesearch.castableobjectsbyindexrange(
                                                                        a_objectdefname =>
                                                                            'j_application',
                                                                        a_columnname =>
                                                                            'CreatedDate',
                                                                        a_lowvalue =>
                                                                            TO_CHAR(p_start_date, 'YYYY-MM-DD'),
                                                                        a_highvalue =>
                                                                            TO_CHAR(p_end_date, 'YYYY-MM-DD')) AS api.udt_objectlist)))
                                            SELECT office
                                              FROM applications a
                                             WHERE a.ispriorityapplication = 'Y'
                                               AND a.statusname NOT IN ('NEW', 'VOIDED')) d
                                  GROUP BY d.office
                                  ORDER BY d.office) pri
                 ON pri.office = o.office
           WHERE o.isactive = 'Y'
        ORDER BY officename;

        -- add information to main report
        SELECT APPENDCHILDXML(p_value, '/WORKLOAD', (SELECT EXTRACT(xml_temp, '/SECTION_4') FROM DUAL))
          INTO p_value
          FROM DUAL;

        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS THEN
            p_status_msg   :=
                   'Section 4: '
                || DBMS_UTILITY.format_error_backtrace
                || ' :: '
                || SQLERRM;

            RETURN FALSE;
    END section4;


    --*****************************************************************************
    -- ASSIGNMENTS (ABC-61)
    -- Section 5
    --*****************************************************************************
    FUNCTION section5(p_value        IN OUT XMLTYPE,
                      p_start_date   IN     DATE,
                      p_end_date     IN     DATE,
                      p_status_msg   IN OUT VARCHAR2)
        RETURN BOOLEAN
    IS
        xml_temp   XMLTYPE;
    BEGIN
          SELECT XMLELEMENT(
                     "SECTION_5",
                     xmlattributes('ASSIGNMENTS' AS "HEADING"),
                     XMLAGG(
                         XMLELEMENT(
                             "OFFICE",
                             XMLFOREST(
                                 SUBSTR(o.officename, 1, 20) officename,
                                 CASE
                                     WHEN NVL(o.rqsexclude, 'N') NOT IN ('H', 'B') THEN
                                         UPPER(NVL(o.division, 'HEADQUARTERS'))
                                     ELSE
                                         'HEADQUARTERS'
                                 END
                                     division,
                                 NVL(licasrecd.recd, 0) AS licensingreceived,
                                 NVL(licascompd.compd, 0) AS licensingcompleted,
                                 NVL(licaspend.pend, 0) AS licensingpendingending,
                                 NVL(recd.recdcomplaint, 0) AS investigationreceived,
                                 NVL(compd.compdcomplaint, 0) AS investigationcompleted,
                                 NVL(pend.pendcomplaint, 0) AS investigationpendingending,
                                 NVL(recd.recdadministrative, 0) AS administrativereceived,
                                 NVL(compd.compdministrative, 0) AS administrativecompleted,
                                 NVL(pend.pendministrative, 0) AS administrativependingending,
                                 NVL(recd.recdpolicereport, 0) AS policereportreceived,
                                 NVL(compd.compdpolicereport, 0) AS policereportcompleted,
                                 NVL(pend.pendpolicereport, 0) AS policereportpendingending,
                                 NVL(recd.recdtrace, 0) AS tracereceived,
                                 NVL(compd.compdtrace, 0) AS tracecompleted,
                                 NVL(pend.pendtrace, 0) AS tracependingending))))
                     section_3
            INTO xml_temp
            FROM query.o_office o
                 ------------------------------------------------------------------------------------------------
                 -- LICENSING Received
                 ------------------------------------------------------------------------------------------------
                 LEFT OUTER JOIN (  SELECT a.districtofficeidcorral, COUNT(a.objectid) recd
                                      FROM mart.licensingassignment a
                                     WHERE a.createddate BETWEEN p_start_date AND p_end_date
                                       AND NVL(a.droppartner, 'N') = 'N'
                                       AND NVL(a.haslicensetype79, 'N') = 'N'
                                       AND NVL(a.haslicensetype84, 'N') = 'N'
                                  GROUP BY a.districtofficeidcorral) licasrecd
                 ON licasrecd.districtofficeidcorral = o.objectid
                 LEFT OUTER JOIN (  SELECT a.districtofficeidcorral, COUNT(a.objectid) compd
                                      FROM mart.licensingassignment a
                                     WHERE TRUNC(a.datecompleted) BETWEEN p_start_date AND p_end_date
                                       AND NVL(a.droppartner, 'N') = 'N'
                                       AND NVL(a.haslicensetype79, 'N') = 'N'
                                       AND NVL(a.haslicensetype84, 'N') = 'N'
                                  GROUP BY a.districtofficeidcorral) licascompd
                 ON licascompd.districtofficeidcorral = o.objectid
                 LEFT OUTER JOIN (  SELECT a.districtofficeidcorral, COUNT(a.objectid) pend
                                      FROM mart.assignassignment a
                                           LEFT JOIN mart.closelicensingassignment c
                                           ON c.externalfilenum = a.externalfilenum
                                     WHERE NVL(a.droppartner, 'N') = 'N'
                                       AND NVL(a.haslicensetype79, 'N') = 'N'
                                       AND NVL(a.haslicensetype84, 'N') = 'N'
                                       AND TRUNC(a.createddate) <= p_end_date
                                       AND TRUNC(a.createddate) > TO_DATE('24-JUN-10')
                                       AND (TRUNC(a.datecompleted) > p_end_date
                                         OR a.datecompleted IS NULL
                                         OR c.datecompleted IS NULL
                                         OR TRUNC(c.datecompleted) > p_end_date)
                                  GROUP BY a.districtofficeidcorral) licaspend
                 ON licaspend.districtofficeidcorral = o.objectid
                 ------------------------------------------------------------------------------------------------
                 -- Complaints Received (Complaint Investigation, Administrative, Police Report)
                 ------------------------------------------------------------------------------------------------
                 LEFT OUTER JOIN (  SELECT i.investigationofficeobjectid,
                                           SUM(CASE WHEN investigationtype = 'COMPLAINT' THEN 1 ELSE 0 END)
                                               recdcomplaint,
                                           SUM(CASE WHEN investigationtype = 'ADMINISTRATIVE' THEN 1 ELSE 0 END)
                                               recdadministrative,
                                           SUM(CASE WHEN investigationtype = 'POLICE REPORT' THEN 1 ELSE 0 END)
                                               recdpolicereport,
                                           SUM(CASE WHEN investigationtype = 'TRACE' THEN 1 ELSE 0 END)
                                               recdtrace
                                      FROM mart.investigation i
                                     WHERE i.investigationtype IN ('COMPLAINT',
                                                                   'ADMINISTRATIVE',
                                                                   'POLICE REPORT',
                                                                   'TRACE')
                                       AND i.createddate BETWEEN p_start_date AND p_end_date
                                       AND api.pkg_columnquery.VALUE(i.objectid, 'StatusName') <> 'CANCEL'
                                  GROUP BY i.investigationofficeobjectid) recd
                 ON recd.investigationofficeobjectid = o.objectid
                 ------------------------------------------------------------------------------------------------
                 -- Completed Complaints (Complaint Investigation, Administrative, Police Report)
                 ------------------------------------------------------------------------------------------------
                 LEFT OUTER JOIN (  SELECT i.investigationofficeobjectid,
                                           SUM(CASE WHEN investigationtype = 'COMPLAINT' THEN 1 ELSE 0 END)
                                               compdcomplaint,
                                           SUM(CASE WHEN investigationtype = 'ADMINISTRATIVE' THEN 1 ELSE 0 END)
                                               compdministrative,
                                           SUM(CASE WHEN investigationtype = 'POLICE REPORT' THEN 1 ELSE 0 END)
                                               compdpolicereport,
                                           SUM(CASE WHEN investigationtype = 'TRACE' THEN 1 ELSE 0 END)
                                               compdtrace
                                      FROM mart.investigation i
                                     WHERE i.investigationtype IN ('COMPLAINT',
                                                                   'ADMINISTRATIVE',
                                                                   'POLICE REPORT',
                                                                   'TRACE')
                                       AND (SELECT TRUNC(t.effectivestartdate)
                                              FROM extension.jobstatuschange_t t
                                             WHERE t.jobid = i.objectid
                                               AND t.statusname = 'CLOSED'
                                               AND t.jobstatuschangeid = (SELECT MIN(t.jobstatuschangeid)
                                                                            FROM extension.jobstatuschange_t t
                                                                           WHERE t.jobid = i.objectid
                                                                             AND t.statusname = 'CLOSED')) BETWEEN p_start_date
                                                                                                               AND p_end_date
                                       AND api.pkg_columnquery.VALUE(i.objectid, 'StatusName') <> 'CANCEL'
                                  GROUP BY i.investigationofficeobjectid) compd
                 ON compd.investigationofficeobjectid = o.objectid
                 ------------------------------------------------------------------------------------------------
                 -- Pending Complaints (Complaint Investigation, Administrative, Police Report)
                 ------------------------------------------------------------------------------------------------
                 LEFT OUTER JOIN (  SELECT i.investigationofficeobjectid,
                                           SUM(CASE WHEN investigationtype = 'COMPLAINT' THEN 1 ELSE 0 END)
                                               pendcomplaint,
                                           SUM(CASE WHEN investigationtype = 'ADMINISTRATIVE' THEN 1 ELSE 0 END)
                                               pendministrative,
                                           SUM(CASE WHEN investigationtype = 'POLICE REPORT' THEN 1 ELSE 0 END)
                                               pendpolicereport,
                                           SUM(CASE WHEN investigationtype = 'TRACE' THEN 1 ELSE 0 END)
                                               pendtrace
                                      FROM mart.investigation i
                                     WHERE i.investigationtype IN ('COMPLAINT',
                                                                   'ADMINISTRATIVE',
                                                                   'POLICE REPORT',
                                                                   'TRACE')
                                       AND TRUNC(i.createddate) <= p_end_date
                                       AND (i.completeddate IS NULL
                                         OR (SELECT t.effectivestartdate
                                               FROM extension.jobstatuschange_t t
                                              WHERE t.jobid = i.objectid
                                                AND t.statusname = 'CLOSED'
                                                AND t.jobstatuschangeid = (SELECT MIN(t.jobstatuschangeid)
                                                                             FROM extension.jobstatuschange_t t
                                                                            WHERE t.jobid = i.objectid
                                                                              AND t.statusname = 'CLOSED')) > p_end_date)
                                       AND api.pkg_columnquery.VALUE(i.objectid, 'StatusName') <> 'CANCEL'
                                  GROUP BY i.investigationofficeobjectid) pend
                 ON pend.investigationofficeobjectid = o.objectid
           WHERE o.isactive = 'Y'
        ORDER BY officename;

        -- add information to main report
        SELECT APPENDCHILDXML(p_value, '/WORKLOAD', (SELECT EXTRACT(xml_temp, '/SECTION_5') FROM DUAL))
          INTO p_value
          FROM DUAL;

        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS THEN
            p_status_msg   :=
                   'Section 5: '
                || DBMS_UTILITY.format_error_backtrace
                || ' :: '
                || SQLERRM;

            RETURN FALSE;
    END section5;


    --*****************************************************************************
    -- ARRESTS
    -- Section 6
    --*****************************************************************************
    FUNCTION section6(p_value        IN OUT XMLTYPE,
                      p_start_date   IN     DATE,
                      p_end_date     IN     DATE,
                      p_status_msg   IN OUT VARCHAR2)
        RETURN BOOLEAN
    IS
        xml_temp   XMLTYPE;
    BEGIN
          -- Section 6 C.Arrests
          SELECT XMLELEMENT(
                     "SECTION_6",
                     xmlattributes('ARRESTS' AS "HEADING"),
                     XMLAGG(
                         XMLELEMENT(
                             "OFFICE",
                             XMLFOREST(
                                 SUBSTR(o.officename, 1, 20) officename,
                                 CASE
                                     WHEN NVL(o.rqsexclude, 'N') NOT IN ('H', 'B') THEN
                                         UPPER(NVL(o.division, 'HEADQUARTERS'))
                                     ELSE
                                         'HEADQUARTERS'
                                 END
                                     division,
                                 NVL(abc19monthlyheader.premisesvisitedlicensing, 0) premisesvisitedlicensing,
                                 NVL(abc19monthlyheader.premisesvisitedenforcement, 0) premisesvisitedenforcement,
                                 NVL(arrests.minorabc, 0) AS minorabc,
                                 NVL(arrests.otherabc, 0) AS otherabc,
                                 NVL(arrests.minorjoint, 0) AS minorjoint,
                                 NVL(arrests.otherjoint, 0) AS otherjoint,
                                 NVL(abc19monthlyheader.warningletterssent, 0) warningletterssent))))
            INTO xml_temp
            FROM query.o_office o
                 LEFT OUTER JOIN (  SELECT districtofficeobjectid              basefileofficeid,
                                           SUM(NVL(premisesvisitedlicensing, 0)) premisesvisitedlicensing,
                                           SUM(NVL(premisesvisitedenforcement, 0)) premisesvisitedenforcement,
                                           SUM(NVL(warningletterssent, 0))     warningletterssent
                                      FROM mart.abc19monthlyheader h
                                     WHERE (TO_DATE(   CASE
                                                           WHEN NVL(h.monthnumber, 1) < 10
                                                            AND NVL(h.monthnumber, 1) > 0 THEN
                                                                  '0'
                                                               || TO_CHAR(NVL(h.monthnumber, 1))
                                                           WHEN NVL(h.monthnumber, 1) = 0 THEN
                                                               '01'
                                                           ELSE
                                                               TO_CHAR(NVL(h.monthnumber, 11))
                                                       END
                                                    || CASE WHEN NVL(h.year, 0) = 0 THEN '2000' ELSE TO_CHAR(h.year) END,
                                                    'MMYYYY')) BETWEEN p_start_date
                                                                   AND p_end_date
                                  GROUP BY h.districtofficeobjectid) abc19monthlyheader
                 ON abc19monthlyheader.basefileofficeid = o.objectid
                 LEFT OUTER JOIN (  SELECT investigationofficeobjectid
                                               basefileofficeid,
                                           SUM(CASE
                                                   WHEN ac.minors = 'Y'
                                                    AND ac.casetype = 'ABC' THEN
                                                       1
                                                   ELSE
                                                       0
                                               END)
                                               minorabc,
                                           SUM(CASE
                                                   WHEN ac.minors = 'N'
                                                    AND ac.casetype = 'ABC' THEN
                                                       1
                                                   ELSE
                                                       0
                                               END)
                                               otherabc,
                                           SUM(CASE
                                                   WHEN ac.minors = 'Y'
                                                    AND ac.casetype NOT IN ('ABC', 'Backtrack') THEN
                                                       1
                                                   ELSE
                                                       0
                                               END)
                                               minorjoint,
                                           SUM(CASE
                                                   WHEN ac.minors = 'N'
                                                    AND ac.casetype NOT IN ('ABC', 'Backtrack') THEN
                                                       1
                                                   ELSE
                                                       0
                                               END)
                                               otherjoint
                                      FROM mart.arrestcitations ac
                                     WHERE ac.arrestdate BETWEEN p_start_date AND p_end_date
                                  GROUP BY ac.investigationofficeobjectid) arrests
                 ON arrests.basefileofficeid = o.objectid
           WHERE o.isactive = 'Y'
        ORDER BY officename;

        -- add information to main report
        SELECT APPENDCHILDXML(p_value, '/WORKLOAD', (SELECT EXTRACT(xml_temp, '/SECTION_6') FROM DUAL))
          INTO p_value
          FROM DUAL;

        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS THEN
            p_status_msg   :=
                   'Section 6: '
                || DBMS_UTILITY.format_error_backtrace
                || ' :: '
                || SQLERRM;

            RETURN FALSE;
    END section6;


    --*****************************************************************************
    -- ACCUSATIONS PART 1 & 2
    -- Section 7
    --*****************************************************************************
    FUNCTION section7(p_value        IN OUT XMLTYPE,
                      p_start_date   IN     DATE,
                      p_end_date     IN     DATE,
                      p_status_msg   IN OUT VARCHAR2)
        RETURN BOOLEAN
    IS
        xml_temp   XMLTYPE;
    BEGIN
          SELECT XMLELEMENT(
                     "SECTION_7",
                     xmlattributes('ACCUSATIONS REGISTERED BY COUNT' AS "HEADING"),
                     XMLAGG(
                         XMLELEMENT(
                             "OFFICE",
                             XMLFOREST(
                                 SUBSTR(officename, 1, 20) officename,
                                 CASE
                                     WHEN NVL(rqsexclude, 'N') NOT IN ('H', 'B') THEN
                                         UPPER(NVL(division, 'HEADQUARTERS'))
                                     ELSE
                                         'HEADQUARTERS'
                                 END
                                     division,
                                 --                       COUNT(v.code) totlreg,
                                 COUNT(DISTINCT regnumber) totlreg,
                                 SUM(CASE
                                         WHEN casetype = 'ABC'
                                          AND code IN ('C10',
                                                       'E1',
                                                       'E2',
                                                       'P2',
                                                       'P3',
                                                       'P7',
                                                       'S11',
                                                       'S12',
                                                       'S35',
                                                       'S31',
                                                       'U5',
                                                       'S18') THEN
                                             1
                                         ELSE
                                             0
                                     END) abcminor,  -- MV - minor violations
                                 SUM(CASE
                                         WHEN casetype = 'ABC'
                                          AND code IN ('S13') THEN
                                             1
                                         ELSE
                                             0
                                     END) abcdecoy,  -- MD - minor decoy
                                 SUM(CASE
                                         WHEN casetype = 'ABC'
                                          AND code IN ('C1',
                                                       'D16',
                                                       'P4',
                                                       'P42',
                                                       'P43',
                                                       'S16') THEN
                                             1
                                         ELSE
                                             0
                                     END) abcobvintoxicated,  -- OI- Obviously Intoxicated
                                 SUM(CASE
                                         WHEN casetype = 'ABC'
                                          AND code IN ('C3',
                                                       'F39',
                                                       'L9',
                                                       'O6',
                                                       'P11',
                                                       'P12',
                                                       'P21',
                                                       'P22',
                                                       'P32',
                                                       'P33',
                                                       'P34',
                                                       'P38',
                                                       'P41',
                                                       'P48',
                                                       'P49',
                                                       'P50',
                                                       'P51',
                                                       'P52',
                                                       'P54',
                                                       'P55',
                                                       'S24',
                                                       'S8') THEN
                                             1
                                         ELSE
                                             0
                                     END) abcdrugs,  -- DR- Drugs
                                 SUM(CASE
                                         WHEN casetype = 'ABC'
                                          AND code IN ('C13',
                                                       'C16',
                                                       'C7',
                                                       'D6',
                                                       'G4',
                                                       'I7',
                                                       'L1',
                                                       'L3',
                                                       'P26',
                                                       'R5',
                                                       'S29') THEN
                                             1
                                         ELSE
                                             0
                                     END) abcdisorderlyprem,  -- DP - Disorderly/Disruptive Premise
                                 SUM(CASE
                                         WHEN casetype = 'ABC'
                                          AND code IN ('D22',
                                                       'D7',
                                                       'D8',
                                                       'D9',
                                                       'E7',
                                                       'F10',
                                                       'F18',
                                                       'F24',
                                                       'F33',
                                                       'F34',
                                                       'F35',
                                                       'F38',
                                                       'F40',
                                                       'F41',
                                                       'G5',
                                                       'L4',
                                                       'L5') THEN
                                             1
                                         ELSE
                                             0
                                     END) abcrostf,  -- RO- ROSTF
                                 SUM(CASE
                                         WHEN casetype = 'ABC'
                                          AND code IN ('A5',
                                                       'B1',
                                                       'B2',
                                                       'D20',
                                                       'D3',
                                                       'M2',
                                                       'P35',
                                                       'P47',
                                                       'P53',
                                                       'P9',
                                                       'U6') THEN
                                             1
                                         ELSE
                                             0
                                     END) abcweaponsviolations,  -- WV - Weapons Violations
                                 SUM(CASE
                                         WHEN casetype = 'ABC'
                                          AND code IN ('I6',
                                                       'O1',
                                                       'P18',
                                                       'P19',
                                                       'P20',
                                                       'U1') THEN
                                             1
                                         ELSE
                                             0
                                     END) abcstolenproperty,  -- SP - Stolen Property
                                 SUM(CASE
                                         WHEN casetype = 'BACKTRACK'
                                          AND code IN ('C10',
                                                       'E1',
                                                       'E2',
                                                       'P2',
                                                       'P3',
                                                       'P7',
                                                       'S11',
                                                       'S12',
                                                       'S35',
                                                       'S31',
                                                       'U5',
                                                       'S18') THEN
                                             1
                                         ELSE
                                             0
                                     END) btminor,  -- MV - minor violations
                                 SUM(CASE
                                         WHEN casetype = 'BACKTRACK'
                                          AND code IN ('S13') THEN
                                             1
                                         ELSE
                                             0
                                     END) btdecoy,  -- MD - minor decoy
                                 SUM(CASE
                                         WHEN casetype = 'BACKTRACK'
                                          AND code IN ('C1',
                                                       'D16',
                                                       'P4',
                                                       'P42',
                                                       'P43',
                                                       'S16') THEN
                                             1
                                         ELSE
                                             0
                                     END) btobvintoxicated,  -- OI- Obviously Intoxicated
                                 SUM(CASE
                                         WHEN casetype = 'BACKTRACK'
                                          AND code IN ('C3',
                                                       'F39',
                                                       'L9',
                                                       'O6',
                                                       'P11',
                                                       'P12',
                                                       'P21',
                                                       'P22',
                                                       'P32',
                                                       'P33',
                                                       'P34',
                                                       'P38',
                                                       'P41',
                                                       'P48',
                                                       'P49',
                                                       'P50',
                                                       'P51',
                                                       'P52',
                                                       'P54',
                                                       'P55',
                                                       'S24',
                                                       'S8') THEN
                                             1
                                         ELSE
                                             0
                                     END) btdrugs,  -- DR- Drugs
                                 SUM(CASE
                                         WHEN casetype = 'BACKTRACK'
                                          AND code IN ('C13',
                                                       'C16',
                                                       'C7',
                                                       'D6',
                                                       'G4',
                                                       'I7',
                                                       'L1',
                                                       'L3',
                                                       'P26',
                                                       'R5',
                                                       'S29') THEN
                                             1
                                         ELSE
                                             0
                                     END) btdisorderlyprem,  -- DP - Disorderly/Disruptive Premise
                                 SUM(CASE
                                         WHEN casetype = 'BACKTRACK'
                                          AND code IN ('D22',
                                                       'D7',
                                                       'D8',
                                                       'D9',
                                                       'E7',
                                                       'F10',
                                                       'F18',
                                                       'F24',
                                                       'F33',
                                                       'F34',
                                                       'F35',
                                                       'F38',
                                                       'F40',
                                                       'F41',
                                                       'G5',
                                                       'L4',
                                                       'L5') THEN
                                             1
                                         ELSE
                                             0
                                     END) btrostf,  -- RO- ROSTF
                                 SUM(CASE
                                         WHEN casetype = 'BACKTRACK'
                                          AND code IN ('A5',
                                                       'B1',
                                                       'B2',
                                                       'D20',
                                                       'D3',
                                                       'M2',
                                                       'P35',
                                                       'P47',
                                                       'P53',
                                                       'P9',
                                                       'U6') THEN
                                             1
                                         ELSE
                                             0
                                     END) btweaponsviolations,  -- WV - Weapons Violations
                                 SUM(CASE
                                         WHEN casetype = 'BACKTRACK'
                                          AND code IN ('I6',
                                                       'O1',
                                                       'P18',
                                                       'P19',
                                                       'P20',
                                                       'U1') THEN
                                             1
                                         ELSE
                                             0
                                     END) btstolenproperty,  -- SP - Stolen Property
                                 SUM(CASE
                                         WHEN casetype = 'ABC'
                                          AND code IN ('B4',
                                                       'G1',
                                                       'O3',
                                                       'P13',
                                                       'P14',
                                                       'P15') THEN
                                             1
                                         ELSE
                                             0
                                     END) abcgambling,  -- GA- Gambling
                                 SUM(CASE
                                         WHEN casetype = 'ABC'
                                          AND code IN ('P1') THEN
                                             1
                                         ELSE
                                             0
                                     END) abcsolicitingdrinks,  -- SD- Soliciting Drinks
                                 SUM(CASE
                                         WHEN casetype = 'ABC'
                                          AND code IN ('A3',
                                                       'A4',
                                                       'C19',
                                                       'S34') THEN
                                             1
                                         ELSE
                                             0
                                     END) abcafterhours,  -- AH- After Hours
                                 SUM(CASE
                                         WHEN casetype = 'ABC'
                                          AND code IN ('A1',
                                                       'A15',
                                                       'C18',
                                                       'D4',
                                                       'D18',
                                                       'D21',
                                                       'E10',
                                                       'E3',
                                                       'E5',
                                                       'E8',
                                                       'F13',
                                                       'F16',
                                                       'F19',
                                                       'F2',
                                                       'F20',
                                                       'F21',
                                                       'F26',
                                                       'F29',
                                                       'F3',
                                                       'F30',
                                                       'F36',
                                                       'F4',
                                                       'F8',
                                                       'G6',
                                                       'I1',
                                                       'I10',
                                                       'I11',
                                                       'I12',
                                                       'I13',
                                                       'I3',
                                                       'I8',
                                                       'I9',
                                                       'P8',
                                                       'P10',
                                                       'P23',
                                                       'P56',
                                                       'R8',
                                                       'S14',
                                                       'S17',
                                                       'S19',
                                                       'S23',
                                                       'S25',
                                                       'S26',
                                                       'S27',
                                                       'S30',
                                                       'S4',
                                                       'S6',
                                                       'U3',
                                                       'V0',
                                                       'V4',
                                                       'V5',
                                                       'V7',
                                                       'B3',
                                                       'C20',
                                                       'E9',
                                                       'F32',
                                                       'F9',
                                                       'P39',
                                                       'P46',
                                                       'P56',
                                                       'R2',
                                                       'R3',
                                                       'S2',
                                                       'S21',
                                                       'S28',
                                                       'S30',
                                                       'S36',
                                                       'S5',
                                                       'U2',
                                                       'V1',
                                                       'V6',
                                                       'S9') THEN
                                             1
                                         ELSE
                                             0
                                     END) abcbp,  -- BP- Business Practices
                                 SUM(CASE
                                         WHEN casetype = 'ABC'
                                          AND code IN ('C15',
                                                       'C4',
                                                       'G2',
                                                       'L7',
                                                       'P24',
                                                       'R1',
                                                       'T3') THEN
                                             1
                                         ELSE
                                             0
                                     END) abcmoralturpitude,  -- MT- Moral Turpitude
                                 SUM(CASE
                                         WHEN casetype = 'ABC'
                                          AND code IN ('A10',
                                                       'A11',
                                                       'A12',
                                                       'A13',
                                                       'A14',
                                                       'A2',
                                                       'A6',
                                                       'A7',
                                                       'A8',
                                                       'A9',
                                                       'C0',
                                                       'C11',
                                                       'C12',
                                                       'C14',
                                                       'C17',
                                                       'C2',
                                                       'C5',
                                                       'C6',
                                                       'C8',
                                                       'C9',
                                                       'D1',
                                                       'D10',
                                                       'D11',
                                                       'D12',
                                                       'D13',
                                                       'D14',
                                                       'D15',
                                                       'D17',
                                                       'D19',
                                                       'D2',
                                                       'D23',
                                                       'D24',
                                                       'D5',
                                                       'E4',
                                                       'E6',
                                                       'F0',
                                                       'F1',
                                                       'F11',
                                                       'F12',
                                                       'F14',
                                                       'F15',
                                                       'F17',
                                                       'F22',
                                                       'F23',
                                                       'F25',
                                                       'F27',
                                                       'F28',
                                                       'F31',
                                                       'F37',
                                                       'F42',
                                                       'F43',
                                                       'F44',
                                                       'F5',
                                                       'G3',
                                                       'H1',
                                                       'H2',
                                                       'H3',
                                                       'H4',
                                                       'I2',
                                                       'I4',
                                                       'I5',
                                                       'L10',
                                                       'L2',
                                                       'L6',
                                                       'L8',
                                                       'M1',
                                                       'N1',
                                                       'N2',
                                                       'O2',
                                                       'O4',
                                                       'O5',
                                                       'P16',
                                                       'P25',
                                                       'P27',
                                                       'P28',
                                                       'P29',
                                                       'P30',
                                                       'P31',
                                                       'P36',
                                                       'P37',
                                                       'P40',
                                                       'P44',
                                                       'P45',
                                                       'P6',
                                                       'R4',
                                                       'R6',
                                                       'R7',
                                                       'S15',
                                                       'S22',
                                                       'S32',
                                                       'S33',
                                                       'S7',
                                                       'T1',
                                                       'T2',
                                                       'U2',
                                                       'U4',
                                                       'V10',
                                                       'V8',
                                                       'V9',
                                                       'F7',
                                                       'P5',
                                                       'S1',
                                                       'S3',
                                                       'S20') THEN
                                             1
                                         ELSE
                                             0
                                     END) abcother,  -- OT- Other
                                 SUM(CASE
                                         WHEN casetype = 'ABC'
                                          AND code IN ('P17') THEN
                                             1
                                         ELSE
                                             0
                                     END) abcprostitution,  -- PR- Prostitution
                                 SUM(CASE
                                         WHEN casetype = 'ABC'
                                          AND code IN ('V2', 'V3', 'V11') THEN
                                             1
                                         ELSE
                                             0
                                     END) abcviolationconditions,  -- VC- Violation of Conditions
                                 SUM(CASE
                                         WHEN casetype = 'BACKTRACK'
                                          AND code IN ('B4',
                                                       'G1',
                                                       'O3',
                                                       'P13',
                                                       'P14',
                                                       'P15') THEN
                                             1
                                         ELSE
                                             0
                                     END) btgambling,  -- GA- Gambling
                                 SUM(CASE
                                         WHEN casetype = 'BACKTRACK'
                                          AND code IN ('P1') THEN
                                             1
                                         ELSE
                                             0
                                     END) btsolicitingdrinks,  -- SD- Soliciting Drinks
                                 SUM(CASE
                                         WHEN casetype = 'BACKTRACK'
                                          AND code IN ('A3',
                                                       'A4',
                                                       'C19',
                                                       'S34') THEN
                                             1
                                         ELSE
                                             0
                                     END) btafterhours,  -- AH- After Hours
                                 SUM(CASE
                                         WHEN casetype = 'BACKTRACK'
                                          AND code IN ('A1',
                                                       'A15',
                                                       'C18',
                                                       'D4',
                                                       'D18',
                                                       'D21',
                                                       'E10',
                                                       'E3',
                                                       'E5',
                                                       'E8',
                                                       'F13',
                                                       'F16',
                                                       'F19',
                                                       'F2',
                                                       'F20',
                                                       'F21',
                                                       'F26',
                                                       'F29',
                                                       'F3',
                                                       'F30',
                                                       'F36',
                                                       'F4',
                                                       'F8',
                                                       'G6',
                                                       'I1',
                                                       'I10',
                                                       'I11',
                                                       'I12',
                                                       'I13',
                                                       'I3',
                                                       'I8',
                                                       'I9',
                                                       'P8',
                                                       'P10',
                                                       'P23',
                                                       'P56',
                                                       'R8',
                                                       'S14',
                                                       'S17',
                                                       'S19',
                                                       'S23',
                                                       'S25',
                                                       'S26',
                                                       'S27',
                                                       'S30',
                                                       'S4',
                                                       'S6',
                                                       'U3',
                                                       'V0',
                                                       'V4',
                                                       'V5',
                                                       'V7',
                                                       'B3',
                                                       'C20',
                                                       'E9',
                                                       'F32',
                                                       'F9',
                                                       'P39',
                                                       'P46',
                                                       'P56',
                                                       'R2',
                                                       'R3',
                                                       'S2',
                                                       'S21',
                                                       'S28',
                                                       'S30',
                                                       'S36',
                                                       'S5',
                                                       'U2',
                                                       'V1',
                                                       'V6',
                                                       'S9') THEN
                                             1
                                         ELSE
                                             0
                                     END) btbp,  -- BP- Business Practices
                                 SUM(CASE
                                         WHEN casetype = 'BACKTRACK'
                                          AND code IN ('C15',
                                                       'C4',
                                                       'G2',
                                                       'L7',
                                                       'P24',
                                                       'R1',
                                                       'T3') THEN
                                             1
                                         ELSE
                                             0
                                     END) btmoralturpitude,  -- MT- Moral Turpitude
                                 SUM(CASE
                                         WHEN casetype = 'BACKTRACK'
                                          AND code IN ('A10',
                                                       'A11',
                                                       'A12',
                                                       'A13',
                                                       'A14',
                                                       'A2',
                                                       'A6',
                                                       'A7',
                                                       'A8',
                                                       'A9',
                                                       'C0',
                                                       'C11',
                                                       'C12',
                                                       'C14',
                                                       'C17',
                                                       'C2',
                                                       'C5',
                                                       'C6',
                                                       'C8',
                                                       'C9',
                                                       'D1',
                                                       'D10',
                                                       'D11',
                                                       'D12',
                                                       'D13',
                                                       'D14',
                                                       'D15',
                                                       'D17',
                                                       'D19',
                                                       'D2',
                                                       'D23',
                                                       'D24',
                                                       'D5',
                                                       'E4',
                                                       'E6',
                                                       'F0',
                                                       'F1',
                                                       'F11',
                                                       'F12',
                                                       'F14',
                                                       'F15',
                                                       'F17',
                                                       'F22',
                                                       'F23',
                                                       'F25',
                                                       'F27',
                                                       'F28',
                                                       'F31',
                                                       'F37',
                                                       'F42',
                                                       'F43',
                                                       'F44',
                                                       'F5',
                                                       'G3',
                                                       'H1',
                                                       'H2',
                                                       'H3',
                                                       'H4',
                                                       'I2',
                                                       'I4',
                                                       'I5',
                                                       'L10',
                                                       'L2',
                                                       'L6',
                                                       'L8',
                                                       'M1',
                                                       'N1',
                                                       'N2',
                                                       'O2',
                                                       'O4',
                                                       'O5',
                                                       'P16',
                                                       'P25',
                                                       'P27',
                                                       'P28',
                                                       'P29',
                                                       'P30',
                                                       'P31',
                                                       'P36',
                                                       'P37',
                                                       'P40',
                                                       'P44',
                                                       'P45',
                                                       'P6',
                                                       'R4',
                                                       'R6',
                                                       'R7',
                                                       'S15',
                                                       'S22',
                                                       'S32',
                                                       'S33',
                                                       'S7',
                                                       'T1',
                                                       'T2',
                                                       'U2',
                                                       'U4',
                                                       'V10',
                                                       'V8',
                                                       'V9',
                                                       'F7',
                                                       'P5',
                                                       'S1',
                                                       'S3',
                                                       'S20') THEN
                                             1
                                         ELSE
                                             0
                                     END) btother,  -- OT- Other
                                 SUM(CASE
                                         WHEN casetype = 'BACKTRACK'
                                          AND code IN ('P17') THEN
                                             1
                                         ELSE
                                             0
                                     END) btprostitution,  -- PR- Prostitution
                                 SUM(CASE
                                         WHEN casetype = 'BACKTRACK'
                                          AND code IN ('V2', 'V3', 'V11') THEN
                                             1
                                         ELSE
                                             0
                                     END) btviolationconditions,  -- VC- Violation of Conditions
                                 SUM(  (CASE
                                            WHEN casetype = 'ABC'
                                             AND code IN ('C10',
                                                          'E1',
                                                          'E2',
                                                          'P2',
                                                          'P3',
                                                          'P7',
                                                          'S11',
                                                          'S12',
                                                          'S35',
                                                          'S31',
                                                          'U5',
                                                          'S18') THEN
                                                1
                                            ELSE
                                                0
                                        END)
                                     + (CASE
                                            WHEN casetype = 'ABC'
                                             AND code IN ('S13') THEN
                                                1
                                            ELSE
                                                0
                                        END)  -- MD - minor decoy
                                     + (CASE
                                            WHEN casetype = 'ABC'
                                             AND code IN ('C1',
                                                          'D16',
                                                          'P4',
                                                          'P42',
                                                          'P43',
                                                          'S16') THEN
                                                1
                                            ELSE
                                                0
                                        END)  -- OI- Obviously Intoxicated
                                     + (CASE
                                            WHEN casetype = 'ABC'
                                             AND code IN ('C3',
                                                          'F39',
                                                          'L9',
                                                          'O6',
                                                          'P11',
                                                          'P12',
                                                          'P21',
                                                          'P22',
                                                          'P32',
                                                          'P33',
                                                          'P34',
                                                          'P38',
                                                          'P41',
                                                          'P48',
                                                          'P49',
                                                          'P50',
                                                          'P51',
                                                          'P52',
                                                          'P54',
                                                          'P55',
                                                          'S24',
                                                          'S8') THEN
                                                1
                                            ELSE
                                                0
                                        END)  -- DR- Drugs
                                     + (CASE
                                            WHEN casetype = 'ABC'
                                             AND code IN ('C13',
                                                          'C16',
                                                          'C7',
                                                          'D6',
                                                          'G4',
                                                          'I7',
                                                          'L1',
                                                          'L3',
                                                          'P26',
                                                          'R5',
                                                          'S29') THEN
                                                1
                                            ELSE
                                                0
                                        END)  -- DP - Disorderly/Disruptive Premise
                                     + (CASE
                                            WHEN casetype = 'ABC'
                                             AND code IN ('D22',
                                                          'D7',
                                                          'D8',
                                                          'D9',
                                                          'E7',
                                                          'F10',
                                                          'F18',
                                                          'F24',
                                                          'F33',
                                                          'F34',
                                                          'F35',
                                                          'F38',
                                                          'F40',
                                                          'F41',
                                                          'G5',
                                                          'L4',
                                                          'L5') THEN
                                                1
                                            ELSE
                                                0
                                        END)  -- RO- ROSTF
                                     + (CASE
                                            WHEN casetype = 'ABC'
                                             AND code IN ('A5',
                                                          'B1',
                                                          'B2',
                                                          'D20',
                                                          'D3',
                                                          'M2',
                                                          'P35',
                                                          'P47',
                                                          'P53',
                                                          'P9',
                                                          'U6') THEN
                                                1
                                            ELSE
                                                0
                                        END)  -- WV - Weapons Violations
                                     + (CASE
                                            WHEN casetype = 'ABC'
                                             AND code IN ('I6',
                                                          'O1',
                                                          'P18',
                                                          'P19',
                                                          'P20',
                                                          'U1') THEN
                                                1
                                            ELSE
                                                0
                                        END)  -- SP - Stolen Property
                                     + (CASE
                                            WHEN casetype = 'ABC'
                                             AND code IN ('B4',
                                                          'G1',
                                                          'O3',
                                                          'P13',
                                                          'P14',
                                                          'P15') THEN
                                                1
                                            ELSE
                                                0
                                        END)  -- GA- Gambling
                                     + (CASE
                                            WHEN casetype = 'ABC'
                                             AND code IN ('P1') THEN
                                                1
                                            ELSE
                                                0
                                        END)  -- SD- Soliciting Drinks
                                     + (CASE
                                            WHEN casetype = 'ABC'
                                             AND code IN ('A3',
                                                          'A4',
                                                          'C19',
                                                          'S34') THEN
                                                1
                                            ELSE
                                                0
                                        END)  -- AH- After Hours
                                     + (CASE
                                            WHEN casetype = 'ABC'
                                             AND code IN ('A1',
                                                          'A15',
                                                          'C18',
                                                          'D4',
                                                          'D18',
                                                          'D21',
                                                          'E10',
                                                          'E3',
                                                          'E5',
                                                          'E8',
                                                          'F13',
                                                          'F16',
                                                          'F19',
                                                          'F2',
                                                          'F20',
                                                          'F21',
                                                          'F26',
                                                          'F29',
                                                          'F3',
                                                          'F30',
                                                          'F36',
                                                          'F4',
                                                          'F8',
                                                          'G6',
                                                          'I1',
                                                          'I10',
                                                          'I11',
                                                          'I12',
                                                          'I13',
                                                          'I3',
                                                          'I8',
                                                          'I9',
                                                          'P8',
                                                          'P10',
                                                          'P23',
                                                          'P56',
                                                          'R8',
                                                          'S14',
                                                          'S17',
                                                          'S19',
                                                          'S23',
                                                          'S25',
                                                          'S26',
                                                          'S27',
                                                          'S30',
                                                          'S4',
                                                          'S6',
                                                          'U3',
                                                          'V0',
                                                          'V4',
                                                          'V5',
                                                          'V7',
                                                          'B3',
                                                          'C20',
                                                          'E9',
                                                          'F32',
                                                          'F9',
                                                          'P39',
                                                          'P46',
                                                          'P56',
                                                          'R2',
                                                          'R3',
                                                          'S2',
                                                          'S21',
                                                          'S28',
                                                          'S30',
                                                          'S36',
                                                          'S5',
                                                          'U2',
                                                          'V1',
                                                          'V6',
                                                          'S9') THEN
                                                1
                                            ELSE
                                                0
                                        END)  -- BP- Business Practices
                                     + (CASE
                                            WHEN casetype = 'ABC'
                                             AND code IN ('C15',
                                                          'C4',
                                                          'G2',
                                                          'L7',
                                                          'P24',
                                                          'R1',
                                                          'T3') THEN
                                                1
                                            ELSE
                                                0
                                        END)  -- MT- Moral Turpitude
                                     + (CASE
                                            WHEN casetype = 'ABC'
                                             AND code IN ('P17') THEN
                                                1
                                            ELSE
                                                0
                                        END)  -- PR- Prostitution
                                     + (CASE
                                            WHEN casetype = 'ABC'
                                             AND code IN ('V2', 'V3', 'V11') THEN
                                                1
                                            ELSE
                                                0
                                        END)  -- VC- Violation of Conditions
                                     + (CASE
                                            WHEN casetype = 'ABC'
                                             AND code IN ('A10',
                                                          'A11',
                                                          'A12',
                                                          'A13',
                                                          'A14',
                                                          'A2',
                                                          'A6',
                                                          'A7',
                                                          'A8',
                                                          'A9',
                                                          'C0',
                                                          'C11',
                                                          'C12',
                                                          'C14',
                                                          'C17',
                                                          'C2',
                                                          'C5',
                                                          'C6',
                                                          'C8',
                                                          'C9',
                                                          'D1',
                                                          'D10',
                                                          'D11',
                                                          'D12',
                                                          'D13',
                                                          'D14',
                                                          'D15',
                                                          'D17',
                                                          'D19',
                                                          'D2',
                                                          'D23',
                                                          'D24',
                                                          'D5',
                                                          'E4',
                                                          'E6',
                                                          'F0',
                                                          'F1',
                                                          'F11',
                                                          'F12',
                                                          'F14',
                                                          'F15',
                                                          'F17',
                                                          'F22',
                                                          'F23',
                                                          'F25',
                                                          'F27',
                                                          'F28',
                                                          'F31',
                                                          'F37',
                                                          'F42',
                                                          'F43',
                                                          'F44',
                                                          'F5',
                                                          'G3',
                                                          'H1',
                                                          'H2',
                                                          'H3',
                                                          'H4',
                                                          'I2',
                                                          'I4',
                                                          'I5',
                                                          'L10',
                                                          'L2',
                                                          'L6',
                                                          'L8',
                                                          'M1',
                                                          'N1',
                                                          'N2',
                                                          'O2',
                                                          'O4',
                                                          'O5',
                                                          'P16',
                                                          'P25',
                                                          'P27',
                                                          'P28',
                                                          'P29',
                                                          'P30',
                                                          'P31',
                                                          'P36',
                                                          'P37',
                                                          'P40',
                                                          'P44',
                                                          'P45',
                                                          'P6',
                                                          'R4',
                                                          'R6',
                                                          'R7',
                                                          'S15',
                                                          'S22',
                                                          'S32',
                                                          'S33',
                                                          'S7',
                                                          'T1',
                                                          'T2',
                                                          'U2',
                                                          'U4',
                                                          'V10',
                                                          'V8',
                                                          'V9',
                                                          'F7',
                                                          'P5',
                                                          'S1',
                                                          'S3',
                                                          'S20') THEN
                                                1
                                            ELSE
                                                0
                                        END)) abc,  -- OT- Other
                                 SUM(  (CASE
                                            WHEN casetype = 'BACKTRACK'
                                             AND code IN ('C10',
                                                          'E1',
                                                          'E2',
                                                          'P2',
                                                          'P3',
                                                          'P7',
                                                          'S11',
                                                          'S12',
                                                          'S35',
                                                          'S31',
                                                          'U5',
                                                          'S18') THEN
                                                1
                                            ELSE
                                                0
                                        END)
                                     + (CASE
                                            WHEN casetype = 'BACKTRACK'
                                             AND code IN ('S13') THEN
                                                1
                                            ELSE
                                                0
                                        END)  -- MD - minor decoy
                                     + (CASE
                                            WHEN casetype = 'BACKTRACK'
                                             AND code IN ('C1',
                                                          'D16',
                                                          'P4',
                                                          'P42',
                                                          'P43',
                                                          'S16') THEN
                                                1
                                            ELSE
                                                0
                                        END)  -- OI- Obviously Intoxicated
                                     + (CASE
                                            WHEN casetype = 'BACKTRACK'
                                             AND code IN ('C3',
                                                          'F39',
                                                          'L9',
                                                          'O6',
                                                          'P11',
                                                          'P12',
                                                          'P21',
                                                          'P22',
                                                          'P32',
                                                          'P33',
                                                          'P34',
                                                          'P38',
                                                          'P41',
                                                          'P48',
                                                          'P49',
                                                          'P50',
                                                          'P51',
                                                          'P52',
                                                          'P54',
                                                          'P55',
                                                          'S24',
                                                          'S8') THEN
                                                1
                                            ELSE
                                                0
                                        END)  -- DR- Drugs
                                     + (CASE
                                            WHEN casetype = 'BACKTRACK'
                                             AND code IN ('C13',
                                                          'C16',
                                                          'C7',
                                                          'D6',
                                                          'G4',
                                                          'I7',
                                                          'L1',
                                                          'L3',
                                                          'P26',
                                                          'R5',
                                                          'S29') THEN
                                                1
                                            ELSE
                                                0
                                        END)  -- DP - Disorderly/Disruptive Premise
                                     + (CASE
                                            WHEN casetype = 'BACKTRACK'
                                             AND code IN ('D22',
                                                          'D7',
                                                          'D8',
                                                          'D9',
                                                          'E7',
                                                          'F10',
                                                          'F18',
                                                          'F24',
                                                          'F33',
                                                          'F34',
                                                          'F35',
                                                          'F38',
                                                          'F40',
                                                          'F41',
                                                          'G5',
                                                          'L4',
                                                          'L5') THEN
                                                1
                                            ELSE
                                                0
                                        END)  -- RO- ROSTF
                                     + (CASE
                                            WHEN casetype = 'BACKTRACK'
                                             AND code IN ('A5',
                                                          'B1',
                                                          'B2',
                                                          'D20',
                                                          'D3',
                                                          'M2',
                                                          'P35',
                                                          'P47',
                                                          'P53',
                                                          'P9',
                                                          'U6') THEN
                                                1
                                            ELSE
                                                0
                                        END)  -- WV - Weapons Violations
                                     + (CASE
                                            WHEN casetype = 'BACKTRACK'
                                             AND code IN ('I6',
                                                          'O1',
                                                          'P18',
                                                          'P19',
                                                          'P20',
                                                          'U1') THEN
                                                1
                                            ELSE
                                                0
                                        END)  -- SP - Stolen Property
                                     + (CASE
                                            WHEN casetype = 'BACKTRACK'
                                             AND code IN ('B4',
                                                          'G1',
                                                          'O3',
                                                          'P13',
                                                          'P14',
                                                          'P15') THEN
                                                1
                                            ELSE
                                                0
                                        END)  -- GA- Gambling
                                     + (CASE
                                            WHEN casetype = 'BACKTRACK'
                                             AND code IN ('P1') THEN
                                                1
                                            ELSE
                                                0
                                        END)  -- SD- Soliciting Drinks
                                     + (CASE
                                            WHEN casetype = 'BACKTRACK'
                                             AND code IN ('A3',
                                                          'A4',
                                                          'C19',
                                                          'S34') THEN
                                                1
                                            ELSE
                                                0
                                        END)  -- AH- After Hours
                                     + (CASE
                                            WHEN casetype = 'BACKTRACK'
                                             AND code IN ('A1',
                                                          'A15',
                                                          'C18',
                                                          'D4',
                                                          'D18',
                                                          'D21',
                                                          'E10',
                                                          'E3',
                                                          'E5',
                                                          'E8',
                                                          'F13',
                                                          'F16',
                                                          'F19',
                                                          'F2',
                                                          'F20',
                                                          'F21',
                                                          'F26',
                                                          'F29',
                                                          'F3',
                                                          'F30',
                                                          'F36',
                                                          'F4',
                                                          'F8',
                                                          'G6',
                                                          'I1',
                                                          'I10',
                                                          'I11',
                                                          'I12',
                                                          'I13',
                                                          'I3',
                                                          'I8',
                                                          'I9',
                                                          'P8',
                                                          'P10',
                                                          'P23',
                                                          'P56',
                                                          'R8',
                                                          'S14',
                                                          'S17',
                                                          'S19',
                                                          'S23',
                                                          'S25',
                                                          'S26',
                                                          'S27',
                                                          'S30',
                                                          'S4',
                                                          'S6',
                                                          'U3',
                                                          'V0',
                                                          'V4',
                                                          'V5',
                                                          'V7',
                                                          'B3',
                                                          'C20',
                                                          'E9',
                                                          'F32',
                                                          'F9',
                                                          'P39',
                                                          'P46',
                                                          'P56',
                                                          'R2',
                                                          'R3',
                                                          'S2',
                                                          'S21',
                                                          'S28',
                                                          'S30',
                                                          'S36',
                                                          'S5',
                                                          'U2',
                                                          'V1',
                                                          'V6',
                                                          'S9') THEN
                                                1
                                            ELSE
                                                0
                                        END)  -- BP- Business Practices
                                     + (CASE
                                            WHEN casetype = 'BACKTRACK'
                                             AND code IN ('C15',
                                                          'C4',
                                                          'G2',
                                                          'L7',
                                                          'P24',
                                                          'R1',
                                                          'T3') THEN
                                                1
                                            ELSE
                                                0
                                        END)  -- MT- Moral Turpitude
                                     + (CASE
                                            WHEN casetype = 'BACKTRACK'
                                             AND code IN ('A10',
                                                          'A11',
                                                          'A12',
                                                          'A13',
                                                          'A14',
                                                          'A2',
                                                          'A6',
                                                          'A7',
                                                          'A8',
                                                          'A9',
                                                          'C0',
                                                          'C11',
                                                          'C12',
                                                          'C14',
                                                          'C17',
                                                          'C2',
                                                          'C5',
                                                          'C6',
                                                          'C8',
                                                          'C9',
                                                          'D1',
                                                          'D10',
                                                          'D11',
                                                          'D12',
                                                          'D13',
                                                          'D14',
                                                          'D15',
                                                          'D17',
                                                          'D19',
                                                          'D2',
                                                          'D23',
                                                          'D24',
                                                          'D5',
                                                          'E4',
                                                          'E6',
                                                          'F0',
                                                          'F1',
                                                          'F11',
                                                          'F12',
                                                          'F14',
                                                          'F15',
                                                          'F17',
                                                          'F22',
                                                          'F23',
                                                          'F25',
                                                          'F27',
                                                          'F28',
                                                          'F31',
                                                          'F37',
                                                          'F42',
                                                          'F43',
                                                          'F44',
                                                          'F5',
                                                          'G3',
                                                          'H1',
                                                          'H2',
                                                          'H3',
                                                          'H4',
                                                          'I2',
                                                          'I4',
                                                          'I5',
                                                          'L10',
                                                          'L2',
                                                          'L6',
                                                          'L8',
                                                          'M1',
                                                          'N1',
                                                          'N2',
                                                          'O2',
                                                          'O4',
                                                          'O5',
                                                          'P16',
                                                          'P25',
                                                          'P27',
                                                          'P28',
                                                          'P29',
                                                          'P30',
                                                          'P31',
                                                          'P36',
                                                          'P37',
                                                          'P40',
                                                          'P44',
                                                          'P45',
                                                          'P6',
                                                          'R4',
                                                          'R6',
                                                          'R7',
                                                          'S15',
                                                          'S22',
                                                          'S32',
                                                          'S33',
                                                          'S7',
                                                          'T1',
                                                          'T2',
                                                          'U2',
                                                          'U4',
                                                          'V10',
                                                          'V8',
                                                          'V9',
                                                          'F7',
                                                          'P5',
                                                          'S1',
                                                          'S3',
                                                          'S20') THEN
                                                1
                                            ELSE
                                                0
                                        END)  -- OT- Other
                                     + (CASE
                                            WHEN casetype = 'BACKTRACK'
                                             AND code IN ('P17') THEN
                                                1
                                            ELSE
                                                0
                                        END)  -- PR- Prostitution
                                     + (CASE
                                            WHEN casetype = 'BACKTRACK'
                                             AND code IN ('V2', 'V3', 'V11') THEN
                                                1
                                            ELSE
                                                0
                                        END)) bt  -- VC- Violation of Conditions
                                                ))))
            INTO xml_temp
            --03/01/2019  TJL 11362 - Changed query for ACCUSATIONS PART 1 & 2
            FROM (SELECT o.officename,
                         o.division,
                         o.rqsexclude,
                         a.casetype,
                         a.regnumber,
                         v.code
                    FROM mart.accusationviolation av
                         JOIN mart.violation v
                         ON v.objectid = av.violationobjectid
                         JOIN mart.accusation a
                         ON a.objectid = av.accusationobjectid
                         JOIN query.o_office o
                         ON o.objectid = a.officeid
                   WHERE av.accusationobjectid IN
                             (SELECT DISTINCT a.objectid
                                FROM mart.accusation a
                               WHERE a.accusationregistereddate BETWEEN p_start_date AND p_end_date
                                 AND (a.casetype = 'ABC'
                                   OR a.casetype = 'BACKTRACK'))
                     AND v.code NOT IN ('G3')
                     AND o.isactive = 'Y'
                  UNION ALL
                  SELECT o.officename,
                         o.division,
                         o.rqsexclude,
                         NULL,
                         NULL,
                         NULL
                    FROM query.o_office o
                   WHERE o.isactive = 'Y')
        GROUP BY officename, division, rqsexclude;

        -- add information to main report
        SELECT APPENDCHILDXML(p_value, '/WORKLOAD', (SELECT EXTRACT(xml_temp, '/SECTION_7') FROM DUAL))
          INTO p_value
          FROM DUAL;

        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS THEN
            p_status_msg   :=
                   'Section 7: '
                || DBMS_UTILITY.format_error_backtrace
                || ' :: '
                || SQLERRM;

            RETURN FALSE;
    END section7;


    --*****************************************************************************
    -- MISCELLANEOUS
    -- Section 9
    --*****************************************************************************
    FUNCTION section9(p_value        IN OUT XMLTYPE,
                      p_start_date   IN     DATE,
                      p_end_date     IN     DATE,
                      p_status_msg   IN OUT VARCHAR2)
        RETURN BOOLEAN
    IS
        xml_temp   XMLTYPE;
    BEGIN
          SELECT XMLELEMENT(
                     "SECTION_9",
                     xmlattributes('MISCELLANEOUS' AS "HEADING"),
                     XMLAGG(
                         XMLELEMENT(
                             "OFFICE",
                             XMLFOREST(
                                 SUBSTR(o.officename, 1, 20) officename,
                                 CASE
                                     WHEN NVL(o.rqsexclude, 'N') NOT IN ('H', 'B') THEN
                                         UPPER(NVL(o.division, 'HEADQUARTERS'))
                                     ELSE
                                         'HEADQUARTERS'
                                 END
                                     division,
                                 NVL(tp.temppermit, 0) permit,
                                 NVL(xx.beerwine, 0) tempberrwine,
                                 NVL(xx.daily, 0) AS general,
                                 NVL(ca.catering, 0) AS catering))))
            INTO xml_temp
            FROM query.o_office o
                 LEFT OUTER JOIN (  -- Spec Daily Temp Beer/Wine (31-34)
                                    -- Daily On-Sale General     (37)
                                    SELECT x.districtofficeid,
                                           SUM(CASE WHEN x.licensetypecode BETWEEN 31 AND 34 THEN 1 ELSE 0 END) beerwine,
                                           SUM(CASE WHEN x.licensetypecode = 37 THEN 1 ELSE 0 END)          daily
                                      FROM (  SELECT districtofficeid,
                                                     CASE
                                                         WHEN licensetypecode BETWEEN 31 AND 34 THEN 31
                                                         ELSE TO_NUMBER(lt.licensetypecode)
                                                     END
                                                         licensetypecode
                                                FROM mart.onedaylicense d
                                                     JOIN mart.onedaylicensetypecategoryrel r
                                                     ON d.jobid = r.onedaylicensejobid
                                                     JOIN mart.licensetypecategory lt
                                                     ON lt.objectid = r.licensetypecategoryobjectid
                                               WHERE d.dateofeventfrom IS NOT NULL
                                                 AND TO_DATE(d.completeddate) BETWEEN p_start_date AND p_end_date
                                            ORDER BY districtofficeid) x
                                  GROUP BY x.districtofficeid
                                  ORDER BY 1) xx
                 ON xx.districtofficeid = o.objectid
                 LEFT OUTER JOIN (  -- Catering AUTH
                                    SELECT api.pkg_columnquery.VALUE(d.jobid, 'BaseFileOfficename') officename,
                                           COUNT(d.jobid)                                       catering
                                      FROM mart.issuecaterereventauth d
                                     WHERE TO_DATE(d.datecompleted) BETWEEN p_start_date AND p_end_date
                                       AND d.outcome IS NOT NULL
                                       AND d.cateringorevent IS NOT NULL
                                       AND NVL((SELECT a.licenseexists
                                                  FROM mart.applictype a
                                                 WHERE a.applicationobjectid = d.jobid
                                                   AND ROWNUM < 2),
                                               'N') = 'N'
                                  GROUP BY api.pkg_columnquery.VALUE(d.jobid, 'BaseFileOfficename')
                                  ORDER BY officename) ca
                 ON ca.officename = o.officename
                 LEFT OUTER JOIN (  -- Temporary permits
                                    SELECT t.investigationofficeobjectid basefileofficeid, COUNT(t.jobid) temppermit
                                      FROM mart.temporarypermit t
                                     WHERE TO_DATE(t.datecompleted) BETWEEN p_start_date AND p_end_date
                                  GROUP BY t.investigationofficeobjectid  -- a.basefileofficeid --to_number(api.pkg_columnquery.VALUE(a.objectid, 'BaseFileOfficeName')                 ORDER BY 1
                                                                        ) tp
                 ON tp.basefileofficeid = o.objectid
        ORDER BY o.officename;  -- add information to main report

        SELECT APPENDCHILDXML(p_value, '/WORKLOAD', (SELECT EXTRACT(xml_temp, '/SECTION_9') FROM DUAL))
          INTO p_value
          FROM DUAL;

        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS THEN
            p_status_msg   :=
                   'Section 9: '
                || DBMS_UTILITY.format_error_backtrace
                || ' :: '
                || SQLERRM;

            RETURN FALSE;
    END section9;
--*****************************************************************************
--*****************************************************************************
--      Workload Summary (Main Process)
--*****************************************************************************
--*****************************************************************************
BEGIN
    DECLARE
        ln_return_code     NUMBER;
        lv_status_msg      VARCHAR2(4000);
        lb_proc            BOOLEAN := TRUE;
        ld_start_date      DATE;
        ld_end_date        DATE;
        xml_value          XMLTYPE := xmltype('<WORKLOAD></WORKLOAD>');
        lxml_pi            XMLTYPE;
        ln_                NUMBER;
        blob_              BLOB;

        procstart          DATE := SYSDATE;
        procend            DATE;
        procsecstart       DATE;
        procsecend         DATE;
        elapse             NUMBER;
        elapsetimestring   VARCHAR2(20);
    BEGIN
        IF (p_parms.get_value('START_DATE') IS NOT NULL) THEN
            ld_start_date   := TRUNC(TO_DATE(p_parms.get_value('START_DATE'), 'MM/DD/YYYY'));
            ld_end_date     := TO_DATE(p_parms.get_value('END_DATE'), 'MM/DD/YYYY') + (1 - 1 / (24 * 60 * 60));
        ELSE
            lb_proc         := FALSE;
            lv_status_msg   := 'No report date found';
        END IF;

        lb_proc        := (lv_status_msg IS NULL);

        ----------------------------------------------------------------------
        -- build report
        ----------------------------------------------------------------------
        -- add report date
        SELECT APPENDCHILDXML(xml_value,
                              '/WORKLOAD',
                              xmltype(   '<REPORTDATES>'
                                      || TO_CHAR(ld_start_date, 'MM/DD/YYYY')
                                      || ' - '
                                      || TO_CHAR(ld_end_date, 'MM/DD/YYYY')
                                      || '</REPORTDATES>'))
          INTO xml_value
          FROM DUAL;

        procsecstart   := SYSDATE;

        -- Section 1
        IF (lb_proc) THEN
            -- MULTI-PERIOD STATS COMPARISON
            lb_proc   :=
                section1(xml_value,
                         ld_start_date,
                         ld_end_date,
                         lv_status_msg);
        END IF;

        elapse         := SYSDATE - procsecstart;
        elapsetimestring   :=
               TO_CHAR(EXTRACT(HOUR FROM NUMTODSINTERVAL(elapse, 'DAY')), 'FM00')
            || ':'
            || TO_CHAR(EXTRACT(MINUTE FROM NUMTODSINTERVAL(elapse, 'DAY')), 'FM00')
            || ':'
            || TO_CHAR(EXTRACT(SECOND FROM NUMTODSINTERVAL(elapse, 'DAY')), 'FM00');
        rqs_utils.LOG(p_log_type  => 'I',
                      p_job_id    => p_parms.get_value('JOB_ID'),
                      p_seq       => p_parms.get_value('SEQ'),
                      p_source    => 'Workload Summary Report',
                      p_msg       =>   'Section 1 - '
                                    || elapsetimestring,
                      p_additional_data => NULL,
                      p_error_trace => NULL);
        procsecstart   := SYSDATE;

        -- Section 2
        IF (lb_proc) THEN
            -- REVENUE MISCELLANEOUS STATUS
            lb_proc   :=
                section2(xml_value,
                         ld_start_date,
                         ld_end_date,
                         lv_status_msg);
        END IF;

        elapse         := SYSDATE - procsecstart;
        elapsetimestring   :=
               TO_CHAR(EXTRACT(HOUR FROM NUMTODSINTERVAL(elapse, 'DAY')), 'FM00')
            || ':'
            || TO_CHAR(EXTRACT(MINUTE FROM NUMTODSINTERVAL(elapse, 'DAY')), 'FM00')
            || ':'
            || TO_CHAR(EXTRACT(SECOND FROM NUMTODSINTERVAL(elapse, 'DAY')), 'FM00');
        rqs_utils.LOG(p_log_type  => 'I',
                      p_job_id    => p_parms.get_value('JOB_ID'),
                      p_seq       => p_parms.get_value('SEQ'),
                      p_source    => 'Workload Summary Report',
                      p_msg       =>   'Section 2 - '
                                    || elapsetimestring,
                      p_additional_data => NULL,
                      p_error_trace => NULL);
        procsecstart   := SYSDATE;

        -- Section 3
        IF (lb_proc) THEN
            -- APPLICATION AND LICENSING INVESTIGATIONS REPORT LAYOUT PART 1
            lb_proc   :=
                section3(xml_value,
                         ld_start_date,
                         ld_end_date,
                         lv_status_msg);
        END IF;

        elapse         := SYSDATE - procsecstart;
        elapsetimestring   :=
               TO_CHAR(EXTRACT(HOUR FROM NUMTODSINTERVAL(elapse, 'DAY')), 'FM00')
            || ':'
            || TO_CHAR(EXTRACT(MINUTE FROM NUMTODSINTERVAL(elapse, 'DAY')), 'FM00')
            || ':'
            || TO_CHAR(EXTRACT(SECOND FROM NUMTODSINTERVAL(elapse, 'DAY')), 'FM00');
        rqs_utils.LOG(p_log_type  => 'I',
                      p_job_id    => p_parms.get_value('JOB_ID'),
                      p_seq       => p_parms.get_value('SEQ'),
                      p_source    => 'Workload Summary Report',
                      p_msg       =>   'Section 3 - '
                                    || elapsetimestring,
                      p_additional_data => NULL,
                      p_error_trace => NULL);
        procsecstart   := SYSDATE;

        -- Section 4
        IF (lb_proc) THEN
            -- APPLICATION AND LICENSING INVESTIGATIONS PART 2
            lb_proc   :=
                section4(xml_value,
                         ld_start_date,
                         ld_end_date,
                         lv_status_msg);
        END IF;

        elapse         := SYSDATE - procsecstart;
        elapsetimestring   :=
               TO_CHAR(EXTRACT(HOUR FROM NUMTODSINTERVAL(elapse, 'DAY')), 'FM00')
            || ':'
            || TO_CHAR(EXTRACT(MINUTE FROM NUMTODSINTERVAL(elapse, 'DAY')), 'FM00')
            || ':'
            || TO_CHAR(EXTRACT(SECOND FROM NUMTODSINTERVAL(elapse, 'DAY')), 'FM00');
        rqs_utils.LOG(p_log_type  => 'I',
                      p_job_id    => p_parms.get_value('JOB_ID'),
                      p_seq       => p_parms.get_value('SEQ'),
                      p_source    => 'Workload Summary Report',
                      p_msg       =>   'Section 4 - '
                                    || elapsetimestring,
                      p_additional_data => NULL,
                      p_error_trace => NULL);
        procsecstart   := SYSDATE;

        -- Section 5
        IF (lb_proc) THEN
            -- ASSIGNMENTS (ABC-61)
            lb_proc   :=
                section5(xml_value,
                         ld_start_date,
                         ld_end_date,
                         lv_status_msg);
        END IF;

        elapse         := SYSDATE - procsecstart;
        elapsetimestring   :=
               TO_CHAR(EXTRACT(HOUR FROM NUMTODSINTERVAL(elapse, 'DAY')), 'FM00')
            || ':'
            || TO_CHAR(EXTRACT(MINUTE FROM NUMTODSINTERVAL(elapse, 'DAY')), 'FM00')
            || ':'
            || TO_CHAR(EXTRACT(SECOND FROM NUMTODSINTERVAL(elapse, 'DAY')), 'FM00');
        rqs_utils.LOG(p_log_type  => 'I',
                      p_job_id    => p_parms.get_value('JOB_ID'),
                      p_seq       => p_parms.get_value('SEQ'),
                      p_source    => 'Workload Summary Report',
                      p_msg       =>   'Section 5 - '
                                    || elapsetimestring,
                      p_additional_data => NULL,
                      p_error_trace => NULL);
        procsecstart   := SYSDATE;

        -- Section 6
        IF (lb_proc) THEN
            -- ARRESTS
            lb_proc   :=
                section6(xml_value,
                         ld_start_date,
                         ld_end_date,
                         lv_status_msg);
        END IF;

        elapse         := SYSDATE - procsecstart;
        elapsetimestring   :=
               TO_CHAR(EXTRACT(HOUR FROM NUMTODSINTERVAL(elapse, 'DAY')), 'FM00')
            || ':'
            || TO_CHAR(EXTRACT(MINUTE FROM NUMTODSINTERVAL(elapse, 'DAY')), 'FM00')
            || ':'
            || TO_CHAR(EXTRACT(SECOND FROM NUMTODSINTERVAL(elapse, 'DAY')), 'FM00');
        rqs_utils.LOG(p_log_type  => 'I',
                      p_job_id    => p_parms.get_value('JOB_ID'),
                      p_seq       => p_parms.get_value('SEQ'),
                      p_source    => 'Workload Summary Report',
                      p_msg       =>   'Section 6 - '
                                    || elapsetimestring,
                      p_additional_data => NULL,
                      p_error_trace => NULL);
        procsecstart   := SYSDATE;

        -- Section 7
        IF (lb_proc) THEN
            -- ACCUSATIONS PART 1 & 2
            lb_proc   :=
                section7(xml_value,
                         ld_start_date,
                         ld_end_date,
                         lv_status_msg);
        END IF;

        elapse         := SYSDATE - procsecstart;
        elapsetimestring   :=
               TO_CHAR(EXTRACT(HOUR FROM NUMTODSINTERVAL(elapse, 'DAY')), 'FM00')
            || ':'
            || TO_CHAR(EXTRACT(MINUTE FROM NUMTODSINTERVAL(elapse, 'DAY')), 'FM00')
            || ':'
            || TO_CHAR(EXTRACT(SECOND FROM NUMTODSINTERVAL(elapse, 'DAY')), 'FM00');
        rqs_utils.LOG(p_log_type  => 'I',
                      p_job_id    => p_parms.get_value('JOB_ID'),
                      p_seq       => p_parms.get_value('SEQ'),
                      p_source    => 'Workload Summary Report',
                      p_msg       =>   'Section 7 - '
                                    || elapsetimestring,
                      p_additional_data => NULL,
                      p_error_trace => NULL);
        procsecstart   := SYSDATE;

        -- Section 9
        IF (lb_proc) THEN
            -- MISCELLANEOUS
            lb_proc   :=
                section9(xml_value,
                         ld_start_date,
                         ld_end_date,
                         lv_status_msg);
        END IF;

        elapse         := SYSDATE - procsecstart;
        elapsetimestring   :=
               TO_CHAR(EXTRACT(HOUR FROM NUMTODSINTERVAL(elapse, 'DAY')), 'FM00')
            || ':'
            || TO_CHAR(EXTRACT(MINUTE FROM NUMTODSINTERVAL(elapse, 'DAY')), 'FM00')
            || ':'
            || TO_CHAR(EXTRACT(SECOND FROM NUMTODSINTERVAL(elapse, 'DAY')), 'FM00');
        rqs_utils.LOG(p_log_type  => 'I',
                      p_job_id    => p_parms.get_value('JOB_ID'),
                      p_seq       => p_parms.get_value('SEQ'),
                      p_source    => 'Workload Summary Report',
                      p_msg       =>   'Section 9 - '
                                    || elapsetimestring,
                      p_additional_data => NULL,
                      p_error_trace => NULL);

        elapse         := SYSDATE - procstart;
        elapsetimestring   :=
               TO_CHAR(EXTRACT(HOUR FROM NUMTODSINTERVAL(elapse, 'DAY')), 'FM00')
            || ':'
            || TO_CHAR(EXTRACT(MINUTE FROM NUMTODSINTERVAL(elapse, 'DAY')), 'FM00')
            || ':'
            || TO_CHAR(EXTRACT(SECOND FROM NUMTODSINTERVAL(elapse, 'DAY')), 'FM00');
        rqs_utils.LOG(p_log_type  => 'I',
                      p_job_id    => p_parms.get_value('JOB_ID'),
                      p_seq       => p_parms.get_value('SEQ'),
                      p_source    => 'Workload Summary Report',
                      p_msg       =>   'Total Time - '
                                    || elapsetimestring,
                      p_additional_data => NULL,
                      p_error_trace => NULL);

        IF (lb_proc) THEN
            p_status_ind   := 'F';

            SELECT XMLPI(NAME "xml-stylesheet", 'href="../Formats/WorkloadSummary.xslt" type="text/xsl"')
              INTO lxml_pi
              FROM DUAL;

            blob_          :=
                rqs_utils.clob2blob(   lxml_pi.getclobval()
                                    || xml_value.getclobval());
        ELSE
            p_status_ind   := 'E';
            blob_          := UTL_RAW.cast_to_raw(lv_status_msg);

            rqs_utils.LOG(p_log_type  => 'E',
                          p_job_id    => p_parms.get_value('JOB_ID'),
                          p_seq       => p_parms.get_value('SEQ'),
                          p_source    => 'Workload Summary Report',
                          p_msg       => lv_status_msg);
        END IF;

        RETURN blob_;
    EXCEPTION
        WHEN OTHERS THEN
            rqs_utils.LOG(p_log_type  => 'E',
                          p_job_id    => p_parms.get_value('JOB_ID'),
                          p_seq       => p_parms.get_value('SEQ'),
                          p_source    => 'ABC19 Yearly Report',
                          p_msg       => SQLERRM,
                          p_additional_data => NULL,
                          p_error_trace => DBMS_UTILITY.format_error_backtrace);

            p_status_ind   := 'E';

            RETURN UTL_RAW.cast_to_raw(   'ERROR: '
                                       || SQLERRM
                                       || CHR(10)
                                       || CHR(13)
                                       || 'TRACE: '
                                       || DBMS_UTILITY.format_error_backtrace);
    END;
END workloadsummary;
/


GRANT EXECUTE ON ABCREPORTS.WORKLOADSUMMARY TO ABCREPORTS_ROLE;
