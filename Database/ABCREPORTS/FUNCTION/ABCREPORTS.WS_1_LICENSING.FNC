CREATE OR REPLACE FUNCTION ABCREPORTS.ws_1_licensing(
    p_parms        IN OUT t_parameters,
    p_status_ind   IN OUT VARCHAR2)
    RETURN BLOB
IS
    -- ****************************************************************************
    -- File:        WS_1_LICENSING.FNC
    -- Author:      Timothy J. Lord
    --
    -- Description:
    --
    --
    -- History:
    -------------------------------------------------------------------------------
    --    Date                  Comment
    --  09/13/2022  TJL   - Function created
    -- ****************************************************************************

    TYPE counts IS VARRAY(3) OF INTEGER;

    TYPE datarectyp IS RECORD(col_1 VARCHAR2(1),
                              col_2 VARCHAR2(500),
                              col_3 counts);

    TYPE datatabtyp IS TABLE OF datarectyp;

    g_switch       DATE := '01-AUG-18'; -- start date to start using docket notes
    g_max          DATE := TO_DATE('21990101', 'YYYYMMDD');


    FUNCTION get_section_data(p_data         IN OUT datatabtyp,
                              p_column       IN     NUMBER,
                              p_start_date   IN     DATE,
                              p_end_date     IN     DATE,
                              p_status_msg   IN OUT VARCHAR2)
        RETURN BOOLEAN
    IS
    BEGIN
        -- ******************************************************
        -- Permanent License Applications Received
        -- ******************************************************
        SELECT NVL(COUNT(a.objectid), 0)
          INTO p_data(1).col_3(p_column)
          FROM mart.application a
         WHERE a.statusname <> 'NEW'
           AND a.abc19apptype IS NOT NULL
           AND a.haslicensetype79 = 'N'
           AND a.haslicensetype84 = 'N'
           AND TRUNC(a.enterapplicationcompleteddate) BETWEEN p_start_date
                                                          AND p_end_date;

        -- ******************************************************
        -- Priority License Applications Received
        -- ******************************************************
        WITH
            applications
            AS
                (SELECT objectid,
                        api.pkg_columnquery.VALUE(objectid,
                                                  'IsPriorityApplication')
                            ispriorityapplication,
                        api.pkg_columnquery.VALUE(objectid, 'StatusName')
                            statusname
                   FROM TABLE(
                            CAST(
                                api.pkg_simplesearch.castableobjectsbyindexrange(
                                    a_objectdefname => 'j_application',
                                    a_columnname => 'CreatedDate',
                                    a_lowvalue  =>
                                        TO_CHAR(p_start_date,
                                                'YYYY-MM-DD'),
                                    a_highvalue =>
                                        TO_CHAR(p_end_date, 'YYYY-MM-DD'))
                                    AS api.udt_objectlist)))
        SELECT COUNT(1)
          INTO p_data(2).col_3(p_column)
          FROM applications a
         WHERE a.ispriorityapplication = 'Y'
           AND a.statusname NOT IN ('NEW', 'VOIDED');

        -- ******************************************************
        -- Applications Protested
        -- ******************************************************
        SELECT COUNT(DISTINCT objectid)
          INTO p_data(3).col_3(p_column)
          FROM (SELECT p.objectid
                  FROM TABLE(
                           CAST(api.pkg_simplesearch.castableobjectsbyindexrange(
                                    'j_Application',
                                    'CreatedDate',
                                    TO_CHAR(
                                        CASE
                                            WHEN p_start_date < g_switch
                                            THEN
                                                p_start_date
                                            ELSE
                                                g_max
                                        END,
                                        'YYYY-MM-DD'),
                                    TO_CHAR(
                                        CASE
                                            WHEN p_start_date >= g_switch
                                            THEN
                                                g_max
                                            WHEN p_end_date >= g_switch
                                            THEN
                                                g_switch - 1
                                            ELSE
                                                p_end_date
                                        END,
                                        'YYYY-MM-DD')) AS api.udt_objectlist))
                       p
                       JOIN query.r_applicationprotestant r
                           ON r.applicationjobid = p.objectid
                UNION
                SELECT r.toobjectid     objectid
                  FROM TABLE(
                           CAST(api.pkg_simplesearch.castableobjectsbyindexrange(
                                    'l_DocketNoteUserLog',
                                    'logdate',
                                    TO_CHAR(
                                        CASE
                                            WHEN p_start_date >= g_switch
                                            THEN
                                                p_start_date
                                            WHEN p_end_date >= g_switch
                                            THEN
                                                g_switch
                                            ELSE
                                                g_max
                                        END,
                                        'YYYY-MM-DD'),
                                    TO_CHAR(
                                        CASE
                                            WHEN p_start_date >= g_switch
                                            THEN
                                                p_end_date
                                            WHEN p_end_date >= g_switch
                                            THEN
                                                p_end_date
                                            ELSE
                                                g_max
                                        END,
                                        'YYYY-MM-DD')) AS api.udt_objectlist))
                       o
                       JOIN api.relationships r
                           ON r.fromobjectid = o.objectid
                          AND r.endpointid =
                              api.pkg_configquery.endpointidforname(
                                  'l_DocketNoteUserLog',
                                  'Application')
                 WHERE api.pkg_columnquery.VALUE(o.objectid, 'eventcode') =
                       'PRT01');

        -- ******************************************************
        -- Number of Protests Letters Received
        -- ******************************************************
        SELECT COUNT(objectid)
          INTO p_data(4).col_3(p_column)
          FROM (SELECT p.objectid
                  FROM TABLE(
                           CAST(api.pkg_simplesearch.castableobjectsbyindexrange(
                                    'j_Application',
                                    'CreatedDate',
                                    TO_CHAR(
                                        CASE
                                            WHEN p_start_date < g_switch
                                            THEN
                                                p_start_date
                                            ELSE
                                                g_max
                                        END,
                                        'YYYY-MM-DD'),
                                    TO_CHAR(
                                        CASE
                                            WHEN p_start_date >= g_switch
                                            THEN
                                                g_max
                                            WHEN p_end_date >= g_switch
                                            THEN
                                                g_switch - 1
                                            ELSE
                                                p_end_date
                                        END,
                                        'YYYY-MM-DD')) AS api.udt_objectlist))
                       p
                       JOIN query.r_applicationprotestant r
                           ON r.applicationjobid = p.objectid
                UNION ALL
                SELECT r.toobjectid     objectid
                  FROM TABLE(
                           CAST(api.pkg_simplesearch.castableobjectsbyindexrange(
                                    'l_DocketNoteUserLog',
                                    'logdate',
                                    TO_CHAR(
                                        CASE
                                            WHEN p_start_date >= g_switch
                                            THEN
                                                p_start_date
                                            WHEN p_end_date >= g_switch
                                            THEN
                                                g_switch
                                            ELSE
                                                g_max
                                        END,
                                        'YYYY-MM-DD'),
                                    TO_CHAR(
                                        CASE
                                            WHEN p_start_date >= g_switch
                                            THEN
                                                p_end_date
                                            WHEN p_end_date >= g_switch
                                            THEN
                                                p_end_date
                                            ELSE
                                                g_max
                                        END,
                                        'YYYY-MM-DD')) AS api.udt_objectlist))
                       o
                       JOIN api.relationships r
                           ON r.fromobjectid = o.objectid
                          AND r.endpointid =
                              api.pkg_configquery.endpointidforname(
                                  'l_DocketNoteUserLog',
                                  'Application')
                 WHERE api.pkg_columnquery.VALUE(o.objectid, 'eventcode') =
                       'PRT01');

        -- ******************************************************
        -- Applications Registered (Protest/Petition)
        -- ******************************************************
        SELECT NVL(COUNT(DISTINCT r.toobjectid), 0)
          INTO p_data(5).col_3(p_column)
          FROM TABLE(CAST(api.pkg_simplesearch.castableobjectsbyindexrange(
                              'l_DocketNoteUserLog',
                              'logdate',
                              TO_CHAR(
                                  CASE
                                      WHEN p_start_date >= g_switch
                                      THEN
                                          p_start_date
                                      WHEN p_end_date >= g_switch
                                      THEN
                                          g_switch
                                      ELSE
                                          g_max
                                  END,
                                  'YYYY-MM-DD'),
                              TO_CHAR(
                                  CASE
                                      WHEN p_start_date >= g_switch
                                      THEN
                                          p_end_date
                                      WHEN p_end_date >= g_switch
                                      THEN
                                          p_end_date
                                      ELSE
                                          g_max
                                  END,
                                  'YYYY-MM-DD')) AS api.udt_objectlist)) o
               JOIN api.relationships r
                   ON r.fromobjectid = o.objectid
                  AND r.endpointid =
                      api.pkg_configquery.endpointidforname(
                          'l_DocketNoteUserLog',
                          'Application')
         WHERE api.pkg_columnquery.VALUE(o.objectid, 'eventcode') IN
                   ('PRT12', 'PMC06');

        -- ******************************************************
        -- Number of Enforcement Hearings Held
        -- ******************************************************
        SELECT SUM(objectid)
          INTO p_data(6).col_3(p_column)
          FROM (SELECT COUNT(DISTINCT o.objectid)     objectid
                  FROM TABLE(
                           CAST(api.pkg_simplesearch.castableobjectsbyindexrange(
                                    'l_DocketNoteUserLog',
                                    'logdate',
                                    TO_CHAR(
                                        CASE
                                            WHEN p_start_date >= g_switch
                                            THEN
                                                p_start_date
                                            WHEN p_end_date >= g_switch
                                            THEN
                                                g_switch
                                            ELSE
                                                g_max
                                        END,
                                        'YYYY-MM-DD'),
                                    TO_CHAR(
                                        CASE
                                            WHEN p_start_date >= g_switch
                                            THEN
                                                p_end_date
                                            WHEN p_end_date >= g_switch
                                            THEN
                                                p_end_date
                                            ELSE
                                                g_max
                                        END,
                                        'YYYY-MM-DD')) AS api.udt_objectlist))
                       o
                 WHERE api.pkg_columnquery.VALUE(o.objectid, 'eventcode') =
                       'ACC29');

        -- ******************************************************
        -- Applications Withdrawn
        -- ******************************************************
        SELECT SUM(withdrawnoriginal) + SUM(withdrawnpertoper)
          INTO p_data(7).col_3(p_column)
          FROM (SELECT SUM(CASE WHEN abc19original = 'Y' THEN 1 ELSE 0 END)
                           withdrawnoriginal,
                       SUM(CASE
                               WHEN abc19original != 'Y'
                                AND abc19pertoper = 'Y'
                               THEN
                                   1
                               ELSE
                                   0
                           END)
                           withdrawnpertoper
                  FROM (SELECT a.abc19original, a.abc19pertoper
                          FROM mart.districtapplicationreview  d
                               JOIN mart.application a
                                   ON a.objectid = d.jobid
                         WHERE d.haslicensetype79 = 'N'
                           AND d.haslicensetype84 = 'N'
                           AND d.datecompleted BETWEEN p_start_date
                                                   AND p_end_date
                           AND d.outcome = 'Withdraw'
                           AND a.enterapplicationcompleteddate IS NOT NULL
                           AND d.objectid IN
                                   (  SELECT MIN(d1.objectid)
                                        FROM mart.districtapplicationreview d1
                                       WHERE d1.jobid = d.jobid
                                    GROUP BY d1.jobid)
                        UNION ALL
                        SELECT a.abc19original, a.abc19pertoper
                          FROM mart.withdrawapplication  p
                               JOIN mart.application a
                                   ON a.objectid = p.jobid
                         WHERE a.haslicensetype79 = 'N'
                           AND a.haslicensetype84 = 'N'
                           AND p.datecompleted BETWEEN p_start_date
                                                   AND p_end_date
                           AND p.outcome IS NOT NULL
                           AND a.enterapplicationcompleteddate IS NOT NULL
                           AND EXISTS
                                   (SELECT 1
                                      FROM extension.jobstatuschange_t j
                                     WHERE j.jobid = a.objectid
                                       AND j.statusname = 'WTHDRN'
                                       AND TRUNC(j.effectivestartdate) BETWEEN p_start_date
                                                                           AND p_end_date)
                           AND p.objectid IN
                                   (  SELECT MIN(p2.objectid)
                                        FROM mart.withdrawapplication p2
                                       WHERE p2.jobid = a.objectid
                                    GROUP BY p2.jobid)
                           AND NOT EXISTS
                                   (SELECT 1
                                      FROM mart.districtapplicationreview d
                                     WHERE d.jobid = a.objectid
                                       AND d.outcome IS NOT NULL)));

        -- ******************************************************
        -- Applications Recommended for Denial
        -- ******************************************************
        SELECT NVL(COUNT(objectid), 0)
          INTO p_data(8).col_3(p_column)
          FROM (SELECT a.objectid
                  FROM mart.districtapplicationreview  d
                       JOIN mart.application a ON a.objectid = d.jobid
                 WHERE d.haslicensetype79 = 'N'
                   AND a.droppartner = 'N'
                   AND d.haslicensetype84 = 'N'
                   AND d.datecompleted BETWEEN p_start_date AND p_end_date
                   AND d.outcome = 'Deny With Division Review'
                   AND d.objectid IN
                           (  SELECT MIN(d1.objectid)
                                FROM mart.districtapplicationreview d1
                               WHERE d1.jobid = d.jobid
                            GROUP BY d1.jobid)
                UNION ALL
                SELECT a.objectid
                  FROM mart.recorddirectordicision  p
                       JOIN mart.application a ON a.objectid = p.jobid
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
                               AND d.outcome IS NOT NULL));

        -- ******************************************************
        -- Applications Recommended for Approval
        -- ******************************************************
        SELECT NVL(COUNT(objectid), 0)
          INTO p_data(9).col_3(p_column)
          FROM (SELECT a.objectid
                  FROM mart.districtapplicationreview  d
                       JOIN mart.application a ON a.objectid = d.jobid
                 WHERE d.haslicensetype79 = 'N'
                   AND d.haslicensetype84 = 'N'
                   AND TRUNC(d.datecompleted) BETWEEN p_start_date
                                                  AND p_end_date
                   AND d.outcome IN
                           ('224 Approval',
                            'Approve Application',
                            'Approve With Division Review')
                   AND d.objectid IN
                           (  SELECT MIN(d1.objectid)
                                FROM mart.districtapplicationreview d1
                               WHERE d1.jobid = d.jobid
                            GROUP BY d1.jobid)
                   AND ((a.abc19original != 'Y'
                     AND a.abc19pertoper = 'Y')
                     OR a.abc19original = 'Y')
                UNION ALL
                SELECT a.objectid
                  FROM mart.issuelicense  p
                       JOIN mart.application a ON a.objectid = p.jobid
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
                               AND d.outcome IS NOT NULL)
                   AND ((a.abc19original != 'Y'
                     AND a.abc19pertoper = 'Y')
                     OR a.abc19original = 'Y'));


        -- ******************************************************
        -- Permanent Licenses Issued
        -- ******************************************************
        SELECT NVL(COUNT(a.objectid), 0)
          INTO p_data(10).col_3(p_column)
          FROM mart.applictype  a
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
             OR TRUNC(psal.statusdate) BETWEEN p_start_date AND p_end_date);

        -- ******************************************************
        -- Special Daily and Catering Authorizations
        -- ******************************************************
        SELECT SUM(item)
          INTO p_data(11).col_3(p_column)
          FROM (SELECT COUNT(licensetypecode)     item
                  FROM mart.onedaylicense  d
                       JOIN mart.onedaylicensetypecategoryrel r
                           ON d.jobid = r.onedaylicensejobid
                       JOIN mart.licensetypecategory lt
                           ON lt.objectid = r.licensetypecategoryobjectid
                 WHERE d.dateofeventfrom IS NOT NULL
                   AND TO_DATE(d.completeddate) BETWEEN p_start_date
                                                    AND p_end_date
                   AND (licensetypecode BETWEEN 31 AND 34
                     OR licensetypecode = 37)
                UNION ALL
                -- Catering AUTH
                SELECT COUNT(d.jobid)     item
                  FROM mart.issuecaterereventauth d
                 WHERE TO_DATE(d.datecompleted) BETWEEN p_start_date
                                                    AND p_end_date
                   AND d.outcome IS NOT NULL
                   AND d.cateringorevent IS NOT NULL
                   AND NVL((SELECT a.licenseexists
                              FROM mart.applictype a
                             WHERE a.applicationobjectid = d.jobid
                               AND ROWNUM < 2),
                           'N') = 'N');


        -- ******************************************************
        -- Active Permanent Licenses as of Report End Date
        -- ******************************************************
        SELECT SUM(cnt)
          INTO p_data(12).col_3(p_column)
          FROM (SELECT NVL(COUNT(DISTINCT (lt.objectid)), 0)     cnt
                  FROM mart.licensetype  lt
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
                   AND j.effectivestartdate =
                       (SELECT MAX(jo.effectivestartdate)
                          FROM extension.jobstatuschange jo
                         WHERE jo.effectivestartdate <= p_end_date
                           AND jo.jobid = j.jobid)
                UNION ALL
                (SELECT NVL(COUNT(DISTINCT (lt2.objectid)), 0)     cnt
                   FROM mart.licensetype  lt2                        --primary
                        JOIN mart.primaryandsecondarylicencetype x
                            ON x.licensetypeobjectid = lt2.objectid
                        JOIN sitespecific.sltstatuschange_t sc
                            ON sc.relationshipid = x.relationshipid
                        JOIN mart.licensetypecategory ltc2
                            ON ltc2.objectid =
                               x.licensecetypecategoryobjectid
                        JOIN mart.licensetypecategoryrel plt
                            ON plt.licensetypeobjectid = lt2.objectid
                  WHERE x.primary IS NULL               --secondary lt's only.
                    AND sc.statusname IN ('ACTIVE',
                                          'SUREND',
                                          'SUSPEN',
                                          'R64B',
                                          'SLSMSHD',
                                          'REVPEN')
                    AND sc.effectivestartdate =
                        (SELECT MAX(sc2.effectivestartdate)
                           FROM sitespecific.sltstatuschange_t sc2
                          WHERE sc2.relationshipid = x.relationshipid
                            AND sc2.effectivestartdate <= p_end_date)));

        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_status_msg :=
                'ws_1_licensing.get_data: '
                || DBMS_UTILITY.format_error_backtrace
                || ' :: '
                || SQLERRM;

            RETURN FALSE;
    END;


    FUNCTION get_data(p_value        IN OUT CLOB,
                      p_start_date   IN     DATE,
                      p_end_date     IN     DATE,
                      p_status_msg   IN OUT VARCHAR2)
        RETURN BOOLEAN
    IS
        TYPE descriptionstyp IS VARRAY(12) OF VARCHAR2(200);

        lb_ok          BOOLEAN := TRUE;
        l_data         datatabtyp := datatabtyp();

        lv_descriptions descriptionstyp
            := descriptionstyp(
                   'Permanent License Applications Received',
                   'Priority License Applications Received',
                   'Applications Protested',
                   'Number of Protests Letters Received',
                   'Applications Registered (Protest/Petition)',
                   'Number of Enforcement Hearings Held',
                   'Applications Withdrawn',
                   'Applications Recommended for Denial',
                   'Applications Recommended for Approval',
                   'Permanent Licenses Issued',
                   'Special Daily and Catering Authorizations',
                   'Active Permanent Licenses as of Report End Date');
    BEGIN
        FOR i IN 1 .. lv_descriptions.COUNT
        LOOP
            l_data.EXTEND;

            IF (i = 5
             OR i = 6)
            THEN
                l_data(l_data.COUNT).col_1 := '*';
            END IF;

            l_data(l_data.COUNT).col_2 := lv_descriptions(i);
            l_data(l_data.COUNT).col_3 := counts(0, 0, 0);
        END LOOP;

        lb_ok :=
            get_section_data(p_data      => l_data,
                             p_column    => 3,
                             p_start_date => p_start_date,
                             p_end_date  => p_end_date,
                             p_status_msg => p_status_msg);

        IF (lb_ok)
        THEN
            lb_ok :=
                get_section_data(
                    p_data      => l_data,
                    p_column    => 2,
                    p_start_date => ADD_MONTHS(p_start_date, -12),
                    p_end_date  => ADD_MONTHS(p_end_date, -12),
                    p_status_msg => p_status_msg);
        END IF;

        IF (lb_ok)
        THEN
            lb_ok :=
                get_section_data(
                    p_data      => l_data,
                    p_column    => 1,
                    p_start_date => ADD_MONTHS(p_start_date, -24),
                    p_end_date  => ADD_MONTHS(p_end_date, -24),
                    p_status_msg => p_status_msg);
        END IF;

        DBMS_LOB.append(
            p_value,
              '"","","'
              || TO_CHAR(ADD_MONTHS(p_start_date, -24), 'MM/DD/YYYY')
              || '-'
              || TO_CHAR(ADD_MONTHS(p_end_date, -24), 'MM/DD/YYYY')
              || '   '
              || (FLOOR(MONTHS_BETWEEN(ADD_MONTHS(p_end_date, -24), ADD_MONTHS(p_start_date, -24)))
            + 1)
            || ' MONTHS","'
              || TO_CHAR(ADD_MONTHS(p_start_date, -12), 'MM/DD/YYYY')
              || '-'
              || TO_CHAR(ADD_MONTHS(p_end_date, -12), 'MM/DD/YYYY')
              || '   '
              || (FLOOR(MONTHS_BETWEEN(ADD_MONTHS(p_end_date, -12), ADD_MONTHS(p_start_date, -12)))
            + 1)
            || ' MONTHS","'
              || TO_CHAR(p_start_date, 'MM/DD/YYYY')
              || '-'
              || TO_CHAR(p_end_date, 'MM/DD/YYYY')
              || '  '
              || (FLOOR(MONTHS_BETWEEN(p_end_date, p_start_date))
            + 1)
            || ' MONTHS"'
            || CHR(13)
            || CHR(10));


        FOR rec IN 1 .. l_data.COUNT
        LOOP
            DBMS_LOB.append(
                p_value,
                '"'
                || l_data(rec).col_1
                || '","'
                || l_data(rec).col_2
                || '",'
                || l_data(rec).col_3(1)
                || ','
                || l_data(rec).col_3(2)
                || ','
                || l_data(rec).col_3(3)
                || CHR(13)
                || CHR(10));
        END LOOP;

        DBMS_LOB.append(
            p_value,
            CHR(13)
            || CHR(10)
            ||CHR(13)
            || CHR(10)
            ||'"*","Due to the automation of this category, data prior to August 01, 2018 will not be reflected in this total.",'
            || CHR(13)
            || CHR(10));

        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_status_msg :=
                'ws_1_licensing.get_data: '
                || DBMS_UTILITY.format_error_backtrace
                || ' :: '
                || SQLERRM;

            RETURN FALSE;
    END;
--*****************************************************************************
--*****************************************************************************
--      Main Process
--*****************************************************************************
--*****************************************************************************


BEGIN
    DECLARE
        blob_          BLOB;
        lc_csv         CLOB;
        ld_start_date  DATE;
        ld_end_date    DATE;
        lv_status_msg  VARCHAR2(4000);
        lb_proc        BOOLEAN := TRUE;
    BEGIN
        DBMS_LOB.createtemporary(lob_loc     => lc_csv,
                                 cache       => TRUE,
                                 dur         => DBMS_LOB.session);

        IF (p_parms.get_value('START_DATE') IS NOT NULL)
        THEN
            ld_start_date :=
                TRUNC(TO_DATE(p_parms.get_value('START_DATE'), 'MM/DD/YYYY'));
            ld_end_date :=
                  TO_DATE(p_parms.get_value('END_DATE'), 'MM/DD/YYYY')
                + (1 - 1 / (24 * 60 * 60));
        ELSE
            lb_proc := FALSE;
            lv_status_msg := 'No report date found';
        END IF;

        p_parms.upd_value('REPORT_DATE',
                          TO_CHAR(SYSDATE, 'MM/DD/YYYY HH:MI PM'));

        lb_proc := (lv_status_msg IS NULL);

        lb_proc :=
            get_data(lc_csv,
                     ld_start_date,
                     ld_end_date,
                     lv_status_msg);

        IF (lb_proc)
        THEN
            p_status_ind := 'F';
            blob_ := rqs_utils.clob2blob(lc_csv);
        ELSE
            p_status_ind := 'E';
            blob_ := UTL_RAW.cast_to_raw(lv_status_msg);

            rqs_utils.LOG(p_log_type  => 'E',
                          p_job_id    => p_parms.get_value('JOB_ID'),
                          p_seq       => p_parms.get_value('SEQ'),
                          p_source    => 'Workload Summary Licensing Report',
                          p_msg       => lv_status_msg);
        END IF;

        RETURN blob_;
    EXCEPTION
        WHEN OTHERS
        THEN
            rqs_utils.LOG(
                p_log_type  => 'E',
                p_job_id    => p_parms.get_value('JOB_ID'),
                p_seq       => p_parms.get_value('SEQ'),
                p_source    => 'ws_1_licensing',
                p_msg       => SQLERRM,
                p_additional_data => NULL,
                p_error_trace => DBMS_UTILITY.format_error_backtrace);

            p_status_ind := 'E';

            RETURN UTL_RAW.cast_to_raw(
                       'ERROR: '
                       || SQLERRM
                       || CHR(10)
                       || CHR(13)
                       || 'TRACE: '
                       || DBMS_UTILITY.format_error_backtrace);
    END;
END;
/
