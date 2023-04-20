CREATE OR REPLACE PACKAGE BODY SITESPECIFIC."PKG_BATCHTYPE"
IS
    -- **************************************************************************
    -- File:        PKG_BATCHTYPE.PKB
    -- Author:      CX
    --
    -- $Rev: 222 $
    -- $Date: 2019-01-23 09:52:07 -0800 (Wed, 23 Jan 2019) $
    -- Last Changed By:  $Author: tlord $
    --
    -- Description:
    --
    --
    -- History:
    -----------------------------------------------------------------------------
    --    Date                  Comment
    -- 08/16/2018 TJL         Initial Check-in
    -- 01/10/2019 TJL         WO16435 removed the = from test in how seasonal expiration
    --                                  date is caculated in procedures
    --                                  relatependingltstobatch, getbatchpenaltycandidates
    --          Note: numberofmonthslicensednumber returns 1 less than actual number of months
    -- 09/09/2020 TJL   WO 8924   Replaced getbatchpenaltycandidates procedure with new procedure
    -- 03/09/2021 NW    WO 24491  Added a query to check for records in r_producelicenseltcatsecondary 
	--                            to avoid expensive query that comes up empty. (Performance tuning)
	--                            Formatting
    -- 04/15/2021 TJL   WO 20712  Modified how renewal liceses are selected for produce license batch
    --                            in procedure relatependingltstobatch. Filtered out STK,STM,MBR,MBM and
    --                            licenses to be reinstated.
    -- 08/05/2021 TJL  WO 25899  truncated ready to issue date when testing if licenses should be
    --                            included in produce license batch for renewals (relatependingltstobatch)
    -- **************************************************************************

    t_newprocid        udt_id;
    g_newline          VARCHAR2(2)
                           :=    CHR(13)
                              || CHR(10);
    g_erroremailsent   CHAR(1) := 'N';

    /*------------------------------------------------------------------------*
     * Types declaration
     *------------------------------------------------------------------------*/
    SUBTYPE udt_idlist IS api.pkg_definition.udt_idlist;

    /* *********************************************************************************************
     * Create Notification Records
     ***********************************************************************************************/
    PROCEDURE emailerrororsuccess(
      a_toaddress     VARCHAR2,  --ToAddress
      a_subject       VARCHAR2,  --Subject
      a_body          VARCHAR2,  --Body
      a_priority      NUMBER,  --[priority] --1 means high priority
      a_ccaddress     VARCHAR2,  --[ccaddress]
      a_relatedobjectid NUMBER  --[relatedobjectid]
    )
    IS
      PRAGMA AUTONOMOUS_TRANSACTION;
      t_fromaddress   VARCHAR2(4000) := api.pkg_constantquery.VALUE('APPLICATIONSUPPORTEMAIL');
    BEGIN
      INSERT INTO extension.notifcations_t
      VALUES (
        a_relatedobjectid,
         t_fromaddress,
         a_toaddress,
         a_subject,
         a_body,
         a_ccaddress,
         NULL,
         NULL,
         NULL,
         SYSDATE,
         NULL,
         NULL
       );

      COMMIT;
    --exception when others then
    --  api.pkg_errors.RaiseError(-20000, 'EmailErrorOrSuccess Err:'||sqlerrm);

    END emailerrororsuccess;

    /* *********************************************************************************************
     * Create Relationships for Batch Type
     * Batch type can be one of seven values as follows:
     *  1. 'Produce Licenses'
     *  2. '1st Renewal Notices'
     *  3. '2nd Renewal Notices'
     *  4. 'Final Revocation Pending Letters'
     *  5. 'Auto Revoke License Types'
     *  6. '50% Penalty'
     *  7. '100% Penalty'
     *
     * When the Batch Type is 'Produce Licenses', this procedure creates relationships
     * from the passed in License Batch JobId to all the License Types where the licenseType
     * detail "IncludeInProduceLicenseBatch" is "Y".
     *
     * When the Batch type is '1st Renewal Notices' this procedure creates relationships from
     * the passed in License Batch JobId to all the License Types where the licenseType detail
     * 'IncludeIn1stRenewal' is 'Y' and the dup_RenewalDate is nominally 60 days in the future.
     *
     * When the Batch type is '2nd Renewal Notices' this procedure creates relationships from
     * the passed in License Batch JobId to all the License Types where the licenseType detail
     * 'IncludeIn2ndRenewal' is 'Y' and the dup_RenewalDate is nominally 50 days in the Past.
     *
     * When the Batch type is 'Final Revocation Pending Letters' this procedure creates relationships
     * from the passed in License Batch JobId to all the License Types where the licenseType detail
     * 'IncludeInRinalRevPending' is 'Y' and the dup_RenewalDate is nominally 80 days in the past.
     *
     * When the Batch type is 'Auto Revoke License Types' this procedure creates relationships
     * from the passed in License Batch JobId to all the License Types where the licenseType detail
     * 'IncludeInRevokeBatch' is 'Y' and the dup_RenewalDate is nominally 90 days in the past.
     *
     * When the Batch type is '50% Penalty' this procedure creates relationships
     * from the passed in License Batch JobId to all the License Types where the LicesneType details
     * 'ExperationDate' is priar to today's date.
     *
     * When the Batch type is '100% Penalty' this procedure creates relationships
     * from the passed in License Batch JobId to all the License Types where the LicesneType details
     * 'ExperationDate' is priar to today's date.
     ***********************************************************************************************/
    PROCEDURE relatependingltstobatch(a_jobid         udt_id,
                                      a_asofdate      DATE,
                                      a_batchtype     VARCHAR2,
                                      a_expirationdate DATE,
                                      a_color         VARCHAR2,
                                      a_dailyorrenewal VARCHAR2,
                                      a_licenseissuedate DATE,
                                      a_getbatchcandidates VARCHAR2)
    AS
        --type t_ObjectIdArray      is table of number(9);
        TYPE t_licnumberarray IS TABLE OF VARCHAR2(40);

        TYPE t_primlicarray IS TABLE OF VARCHAR2(50);

        --t_ObjectIds               t_ObjectIdArray;
        t_licensenumbers         t_licnumberarray;
        t_primarylicensees       t_primlicarray;

        t_objectidstemp          api.pkg_definition.udt_idlist;
        t_objectidsfull          api.pkg_definition.udt_idlist;
        t_objectidssort          api.pkg_definition.udt_idlist;
        t_renewalstatustags      VARCHAR2(4000);
        t_renewalstatusdesc      VARCHAR2(4000);
        t_secrenewalstatustags   VARCHAR2(4000);
        t_secrenewalstatusdesc   VARCHAR2(4000);
        t_statusdesc             VARCHAR2(4000);
        t_statustags             VARCHAR2(4000);
        t_chunksize              NUMBER := api.pkg_constantquery.VALUE('BATCHCHUNKSIZE');
        t_totalexpectedcount     NUMBER;
        t_totalproccount         NUMBER;
        t_lictypeid              NUMBER := api.pkg_configquery.objectdefidforname('j_LicenseType');
        t_processdefid           udt_id;
        t_processdesc            VARCHAR2(4000);
        t_processstatus          VARCHAR2(4000);
        t_subject                VARCHAR2(4000);
        t_body                   VARCHAR2(4000);
        t_toaddress              VARCHAR2(4000) := api.pkg_constantquery.VALUE('LICENSINGNOTIFICATIONEMAIL');
        t_ccaddress              VARCHAR2(4000) := api.pkg_constantquery.VALUE('APPLICATIONSUPPORTEMAIL');
        t_expirationdates        VARCHAR2(20);
    BEGIN
        /*
        Because of time constraints, the Logging report will no longer show the detailed section of the report.
        The processing of the chunks was changed, but the logging was not changed along with it to provide an accurate representation in the detailed status report.
        This procedure will log to the table, but the things it logs are not technically correct until all of the scheduled processes are complete.
        Given that the detailed side of the report was never part of the requirements, we will hide that part of the report and move on.
        */
        sitespecific.pkg_batchtype.batchlogging(a_jobid,
                                                NULL,
                                                'Begin Relate Pending LTs to Batch',
                                                NULL);
        --reset flag that an email or emails with an error(s) has been sent
        g_erroremailsent    := 'N';

        SELECT    ''''
               || concatlist2(sitespecific.udt_aggrstring(s.tag, ''', '''))
               || ''''
                   statustag,
                  ''''
               || concatlist2(sitespecific.udt_aggrstring(UPPER(s.description), ''','''))
               || ''''
                   statusdesc
          INTO t_statustags, t_statusdesc
          FROM api.statuses s
               JOIN api.jobstatuses js
               ON js.statusid = s.statusid
              AND js.jobtypeid = t_lictypeid
         WHERE js.statustype NOT IN ('C', 'X');

        SELECT    ''''
               || concatlist2(sitespecific.udt_aggrstring(s.tag, ''', '''))
               || ''''
                   statustag,
                  ''''
               || concatlist2(sitespecific.udt_aggrstring(UPPER(s.description), ''','''))
               || ''''
                   statusdesc
          INTO t_renewalstatustags, t_renewalstatusdesc
          FROM api.statuses s
               JOIN api.jobstatuses js
               ON js.statusid = s.statusid
              AND js.jobtypeid = t_lictypeid
         WHERE js.statustype NOT IN ('C', 'X')
           AND s.tag NOT IN ('PEND', 'REVPEN');

        SELECT    ''''
               || concatlist2(sitespecific.udt_aggrstring(s.tag, ''', '''))
               || ''''
                   statustag,
                  ''''
               || concatlist2(sitespecific.udt_aggrstring(UPPER(s.description), ''','''))
               || ''''
                   statusdesc
          INTO t_secrenewalstatustags, t_secrenewalstatusdesc
          FROM api.jobstatuses js
               JOIN api.statuses s
               ON s.statusid = js.statusid
         WHERE js.jobtypeid = t_lictypeid
           AND s.tag IN ('AUTREV', 'REVPEN');

        getprocesstypeforbatch(a_batchtype,
                               t_processdefid,
                               t_processdesc,
                               t_processstatus);
        t_expirationdates   := TO_CHAR(a_expirationdate, 'YYYY-MM-DD HH24:MI:SS');

        CASE a_batchtype
            --
            WHEN 'PRODUCE LICENSES' THEN
                IF a_dailyorrenewal = 'Daily' THEN
                    SELECT  /*+ cardinality (l 1) */
                           l.objectid
                      BULK COLLECT INTO t_objectidsfull
                      FROM TABLE(api.pkg_simplesearch.castableobjectsbyindexrange(
                                     'j_LicenseType',
                                     'dup_ReadyToIssueDateNumber',
                                     TO_NUMBER(TO_CHAR(a_licenseissuedate - 14, 'YYYYMMDD')),
                                     TO_NUMBER(TO_CHAR(a_licenseissuedate, 'YYYYMMDD')))) l
                           JOIN query.j_licensetype j
                           ON j.objectid = l.objectid
                           JOIN query.r_licensetypeltcatprimary ltcp
                           ON ltcp.licensetypejobid = j.objectid
                           JOIN query.o_licensetypecategory ltc
                           ON ltc.objectid = ltcp.licensetypecategoryobjectid
                          AND ltc.color = a_color
                     WHERE j.includeinproducelicensebatch = 'Y'
                       AND (j.statusname IN ('PEND')
                         OR (j.includeindailybatch = 'Y'
                         AND j.statusname IN (SELECT s.tag
                                                FROM api.statuses s
                                                     JOIN api.jobstatuses js
                                                     ON js.statusid = s.statusid
                                                    AND js.jobtypeid = t_lictypeid
                                               WHERE js.statustype NOT IN ('C', 'X')))
                         OR (j.statusname IN ('AUTREV', 'REVPEN')
                         AND j.reinstate = 'Y'))
                    UNION
                      SELECT  /*+ cardinality (l 1) */
                             l.objectid
                        FROM TABLE(
                                 api.pkg_simplesearch.castableobjectsbyindex('j_LicenseType',
                                                                             'dup_IncludeInProduceLicBatchSe',
                                                                             'Y')) l
                             JOIN query.j_licensetype j
                             ON j.objectid = l.objectid
                             JOIN query.r_licenselicensetype rllt
                             ON rllt.licensetypejobid = j.objectid
                             JOIN query.r_licensetypeltcatsecondary ltcs
                             ON ltcs.licensetypejobid = rllt.licensetypejobid
                            AND ltcs.includeinproducelicensebatch = 'Y'
                             JOIN query.o_licensetypecategory ltc
                             ON ltc.objectid = ltcs.licensetypecategoryobjectid
                            AND ltc.color = a_color
                             JOIN sitespecific.duplicate_t do
                             ON do.relationshipid = ltcs.relationshipid
                             JOIN query.o_duplicate dup
                             ON dup.relationshipid = do.relationshipid
                            AND dup.objectid = do.duplicateid
                       WHERE (UPPER(dup.status) = UPPER('Pending')
                          AND do.readytoissuedate BETWEEN (  TO_DATE(TO_CHAR(a_licenseissuedate, 'MM/DD/YYYY'),
                                                                     'MM/DD/YYYY')
                                                           - 14)
                                                      AND TO_DATE(   TO_CHAR(a_licenseissuedate, 'MM/DD/YYYY')
                                                                  || ' 235959',
                                                                  'MM/DD/YYYY HH24MISS'))
                          OR (j.includeindailybatch = 'Y'
                          AND ltcs.readytoissuedate BETWEEN (  TO_DATE(TO_CHAR(a_licenseissuedate, 'MM/DD/YYYY'),
                                                                       'MM/DD/YYYY')
                                                             - 14)
                                                        AND TO_DATE(   TO_CHAR(a_licenseissuedate, 'MM/DD/YYYY')
                                                                    || ' 235959',
                                                                    'MM/DD/YYYY HH24MISS')
                          AND (SELECT s.tag
                                 FROM api.jobstatuses js
                                      JOIN api.statuses s
                                      ON s.statusid = js.statusid
                                WHERE js.jobtypeid = t_lictypeid
                                  AND UPPER(s.description) = ltcs.status) IN (t_statustags)
                           OR ((SELECT s.tag
                                  FROM api.jobstatuses js
                                       JOIN api.statuses s
                                       ON s.statusid = js.statusid
                                 WHERE js.jobtypeid = t_lictypeid
                                   AND UPPER(s.description) = ltcs.status) IN ('AUTREV', 'REVPEN')
                           AND j.reinstate = 'Y'))
                    GROUP BY l.objectid;
                ELSE
                    -- Renewal
                    -- 04/15/2021 TJL   WO 20712  Changed query to filter out STK,STM,MBR,MBM and liceses to reinstate
                    SELECT  /*+ cardinality (l 1) */
                           l.objectid
                      BULK COLLECT INTO t_objectidsfull
                      FROM TABLE(
                               api.pkg_simplesearch.castableobjectsbyindex('j_LicenseType',
                                                                           'IncludeInProduceLicenseBatch',
                                                                           'Y')) l
                           JOIN query.j_licensetype j
                           ON j.objectid = l.objectid
                           JOIN query.r_licensetypeltcatprimary ltcp
                           ON ltcp.licensetypejobid = j.objectid
                           JOIN query.o_licensetypecategory ltc
                           ON ltc.objectid = ltcp.licensetypecategoryobjectid
                          AND ltc.color = a_color
                     WHERE ((j.statusname IN (SELECT s.tag
                                                FROM api.statuses s
                                                     JOIN api.jobstatuses js
                                                     ON js.statusid = s.statusid
                                                    AND js.jobtypeid = t_lictypeid
                                               WHERE js.statustype NOT IN ('C', 'X')
                                                 AND s.tag NOT IN ('PEND', 'REVPEN')))
                         AND j.reinstate = 'N')
                         AND j.typeofissuance NOT IN ('STK', 'STM', 'MBR', 'MBM')
                       AND TRUNC(j.readytoissuedate) <= TO_DATE(TO_CHAR(a_licenseissuedate, 'MM/DD/YYYY'), 'MM/DD/YYYY') -- 08/05/2021 TJL  WO 25899
                    UNION
                      SELECT  /*+ cardinality (l 1) */
                             l.objectid
                        FROM TABLE(
                                 api.pkg_simplesearch.castableobjectsbyindex('j_LicenseType',
                                                                             'dup_IncludeInProduceLicBatchSe',
                                                                             'Y')) l
                             JOIN query.j_licensetype j
                             ON j.objectid = l.objectid
                             JOIN query.r_licenselicensetype rllt
                             ON rllt.licensetypejobid = j.objectid
                             JOIN query.r_licensetypeltcatsecondary ltcs
                             ON ltcs.licensetypejobid = rllt.licensetypejobid
                            AND ltcs.includeinproducelicensebatch = 'Y'
                             JOIN query.o_licensetypecategory ltc
                             ON ltc.objectid = ltcs.licensetypecategoryobjectid
                            AND ltc.color = a_color
                             JOIN sitespecific.duplicate_t do
                             ON do.relationshipid = ltcs.relationshipid
                             JOIN query.o_duplicate dup
                             ON dup.relationshipid = do.relationshipid
                            AND dup.objectid = do.duplicateid
                       WHERE ltcs.includeinproducelicensebatch = 'Y'
                         AND (j.statusname IN (SELECT s.tag
                                                 FROM api.statuses s
                                                      JOIN api.jobstatuses js
                                                      ON js.statusid = s.statusid
                                                     AND js.jobtypeid = t_lictypeid
                                                WHERE js.statustype NOT IN ('C', 'X')
                                                  AND s.tag NOT IN ('PEND', 'REVPEN'))
                           AND j.reinstate = 'N')
                           AND j.typeofissuance NOT IN ('STK', 'STM', 'MBR', 'MBM')
                         AND trunc(ltcs.readytoissuedate) <= TO_DATE(TO_CHAR(a_licenseissuedate, 'MM/DD/YYYY'), 'MM/DD/YYYY') -- 08/05/2021 TJL  WO 25899
                    GROUP BY l.objectid;
                END IF;
            --
            WHEN '1ST RENEWAL NOTICES' THEN
                --first get License Types that expire on the specified expiration date that are not seasonal
                SELECT  /*+ cardinality (l 1) */
                       l.objectid
                  BULK COLLECT INTO t_objectidsfull
                  FROM TABLE(
                           api.pkg_simplesearch.castableobjectsbyindex('j_LicenseType',
                                                                       'dup_ExpirationDate',
                                                                       t_expirationdates)) l
                       JOIN query.j_licensetype j
                       ON j.objectid = l.objectid
                 WHERE j.includein1strenewal = 'Y'
                   AND j.statusname IN ('ACTIVE',
                                        'SUREND',
                                        'SUSPEN',
                                        'R64B')
                   AND j.dup_seasonstartmonthnumber IS NULL;

                --second get License Types that are seasonal that start the day after the specified expiration date
                SELECT  /*+ cardinality (l 1) */
                       l.objectid
                  BULK COLLECT INTO t_objectidstemp
                  FROM TABLE(api.pkg_simplesearch.castableobjectsbyindexrange('j_LicenseType',
                                                                              'dup_SeasonStartMonthNumber',
                                                                              1,
                                                                              12)) l
                       JOIN query.j_licensetype j
                       ON j.objectid = l.objectid
                 WHERE j.includein1strenewal = 'Y'
                   AND j.statusname IN ('ACTIVE',
                                        'SUREND',
                                        'SUSPEN',
                                        'R64B')
                   AND (TO_DATE(
                               LPAD(j.dup_seasonstartmonthnumber, 2, '00')
                            || '/01/'
                            || CASE
                                   WHEN   TO_NUMBER(TO_CHAR(j.dup_expirationdate, 'MM'))
                                        - (j.numberofmonthslicensednumber + 1) <  -- 01/10/2019 TJL 16435 removed = from test
                                        0 THEN
                                       NVL(j.expiringyear, '9999')
                                   ELSE
                                       NVL(j.expiringyear + 1, '9999')
                               END,
                            'MM/DD/YYYY')) =
                       a_expirationdate + 1;

                extension.pkg_collectionutils.append(t_objectidsfull, t_objectidstemp);

                --third get Secondary License types that expire on the specified expiration date that are not seasonal
                SELECT  /*+ cardinality (l 1) */
                       l.objectid
                  BULK COLLECT INTO t_objectidstemp
                  FROM TABLE(
                           api.pkg_simplesearch.castableobjectsbyindex('j_LicenseType',
                                                                       'dup_ExpirationDate',
                                                                       t_expirationdates)) l
                       JOIN query.j_licensetype j
                       ON j.objectid = l.objectid
                       JOIN query.r_licensetypeltcatsecondary r
                       ON r.licensetypejobid = j.objectid
                 WHERE j.dup_includein1strenewalsec = 'Y'
                   AND (SELECT s.tag
                          FROM api.jobstatuses js
                               JOIN api.statuses s
                               ON s.statusid = js.statusid
                         WHERE js.jobtypeid = api.pkg_configquery.objectdefidforname('j_LicenseType')
                           AND UPPER(s.description) = r.status) IN ('ACTIVE',
                                                                    'SUREND',
                                                                    'SUSPEN',
                                                                    'R64B')
                   AND r.includein1strenewal = 'Y'
                   AND j.dup_seasonstartmonthnumber IS NULL;

                extension.pkg_collectionutils.append(t_objectidsfull, t_objectidstemp);

                --fourth get Secondary License types that are seasonal that start the day after the specified expiration date
                SELECT  /*+ cardinality (l 1) */
                       l.objectid
                  BULK COLLECT INTO t_objectidstemp
                  FROM TABLE(api.pkg_simplesearch.castableobjectsbyindexrange('j_LicenseType',
                                                                              'dup_SeasonStartMonthNumber',
                                                                              1,
                                                                              12)) l
                       JOIN query.j_licensetype j
                       ON j.objectid = l.objectid
                       JOIN query.r_licensetypeltcatsecondary r
                       ON r.licensetypejobid = j.objectid
                 WHERE j.dup_includein1strenewalsec = 'Y'
                   AND (SELECT s.tag
                          FROM api.jobstatuses js
                               JOIN api.statuses s
                               ON s.statusid = js.statusid
                         WHERE js.jobtypeid = t_lictypeid
                           AND UPPER(s.description) = r.status) IN ('ACTIVE',
                                                                    'SUREND',
                                                                    'SUSPEN',
                                                                    'R64B')
                   AND r.includein1strenewal = 'Y'
                   AND (TO_DATE(
                               LPAD(j.dup_seasonstartmonthnumber, 2, '00')
                            || '/01/'
                            || CASE
                                   WHEN   TO_NUMBER(TO_CHAR(j.dup_expirationdate, 'MM'))
                                        - (j.numberofmonthslicensednumber + 1) <  -- 01/10/2019 TJL 16435 removed = from test
                                        0 THEN
                                       NVL(j.expiringyear, '9999')
                                   ELSE
                                       NVL(j.expiringyear + 1, '9999')
                               END,
                            'MM/DD/YYYY')) =
                       a_expirationdate + 1;

                extension.pkg_collectionutils.append(t_objectidsfull, t_objectidstemp);
            --
            WHEN '2ND RENEWAL NOTICES' THEN
                SELECT  /*+ cardinality (l 1) */
                       l.objectid
                  BULK COLLECT INTO t_objectidsfull
                  FROM TABLE(
                           api.pkg_simplesearch.castableobjectsbyindex('j_LicenseType',
                                                                       'dup_ExpirationDate',
                                                                       t_expirationdates)) l
                       JOIN query.j_licensetype j
                       ON j.objectid = l.objectid
                 WHERE j.includein2ndrenewal = 'Y'
                   AND j.dup_seasonstartmonthnumber IS NULL;

                --second get License Types that are seasonal that start the day after the specified expiration date
                SELECT  /*+ cardinality (l 1) */
                       l.objectid
                  BULK COLLECT INTO t_objectidstemp
                  FROM TABLE(api.pkg_simplesearch.castableobjectsbyindexrange('j_LicenseType',
                                                                              'dup_SeasonStartMonthNumber',
                                                                              1,
                                                                              12)) l
                       JOIN query.j_licensetype j
                       ON j.objectid = l.objectid
                 WHERE j.includein2ndrenewal = 'Y'
                   AND (TO_DATE(
                               LPAD(j.dup_seasonstartmonthnumber, 2, '00')
                            || '/01/'
                            || CASE
                                   WHEN   TO_NUMBER(TO_CHAR(j.dup_expirationdate, 'MM'))
                                        - (j.numberofmonthslicensednumber + 1) <  -- 01/10/2019 TJL 16435 removed = from test
                                        0 THEN
                                       NVL(j.expiringyear, '9999')
                                   ELSE
                                       NVL(j.expiringyear + 1, '9999')
                               END,
                            'MM/DD/YYYY')) =
                       a_expirationdate + 1;

                extension.pkg_collectionutils.append(t_objectidsfull, t_objectidstemp);

                --third get Secondary License types that expire on the specified expiration date that are not seasonal
                SELECT  /*+ cardinality (l 1) */
                       l.objectid
                  BULK COLLECT INTO t_objectidstemp
                  FROM TABLE(
                           api.pkg_simplesearch.castableobjectsbyindex('j_LicenseType',
                                                                       'dup_ExpirationDate',
                                                                       t_expirationdates)) l
                       JOIN query.j_licensetype j
                       ON j.objectid = l.objectid
                       JOIN query.r_licensetypeltcatsecondary r
                       ON r.licensetypejobid = j.objectid
                 WHERE j.dup_includein2ndrenewalsec = 'Y'
                   AND r.includein2ndrenewal = 'Y'
                   AND j.dup_seasonstartmonthnumber IS NULL;

                extension.pkg_collectionutils.append(t_objectidsfull, t_objectidstemp);

                --fourth get Secondary License types that are seasonal that start the day after the specified expiration date
                SELECT  /*+ cardinality (l 1) */
                       l.objectid
                  BULK COLLECT INTO t_objectidstemp
                  FROM TABLE(api.pkg_simplesearch.castableobjectsbyindexrange('j_LicenseType',
                                                                              'dup_SeasonStartMonthNumber',
                                                                              1,
                                                                              12)) l
                       JOIN query.j_licensetype j
                       ON j.objectid = l.objectid
                       JOIN query.r_licensetypeltcatsecondary r
                       ON r.licensetypejobid = j.objectid
                 WHERE j.dup_includein2ndrenewalsec = 'Y'
                   AND r.includein2ndrenewal = 'Y'
                   AND (TO_DATE(
                               LPAD(j.dup_seasonstartmonthnumber, 2, '00')
                            || '/01/'
                            || CASE
                                   WHEN   TO_NUMBER(TO_CHAR(j.dup_expirationdate, 'MM'))
                                        - (j.numberofmonthslicensednumber + 1) <  -- 01/10/2019 TJL 16435 removed = from test
                                        0 THEN
                                       NVL(j.expiringyear, '9999')
                                   ELSE
                                       NVL(j.expiringyear + 1, '9999')
                               END,
                            'MM/DD/YYYY')) =
                       a_expirationdate + 1;

                extension.pkg_collectionutils.append(t_objectidsfull, t_objectidstemp);
            --
            WHEN 'FINAL REVOCATION PENDING LETTERS' THEN
                --first get License Types that expire on the specified expiration date that are not seasonal
                SELECT  /*+ cardinality (l 1) */
                       l.objectid
                  BULK COLLECT INTO t_objectidsfull
                  FROM TABLE(
                           api.pkg_simplesearch.castableobjectsbyindex('j_LicenseType',
                                                                       'dup_ExpirationDate',
                                                                       t_expirationdates)) l
                       JOIN query.j_licensetype j
                       ON j.objectid = l.objectid
                 WHERE j.includeinfinalrevpending = 'Y'
                   AND j.statusname IN ('ACTIVE',
                                        'REVPEN',
                                        'R64B',
                                        'SUREND',
                                        'SUSPEN')
                   AND j.dup_seasonstartmonthnumber IS NULL;

                --second get License Types that are seasonal that start the day after the specified expiration date
                SELECT  /*+ cardinality (l 1) */
                       l.objectid
                  BULK COLLECT INTO t_objectidstemp
                  FROM TABLE(api.pkg_simplesearch.castableobjectsbyindexrange('j_LicenseType',
                                                                              'dup_SeasonStartMonthNumber',
                                                                              1,
                                                                              12)) l
                       JOIN query.j_licensetype j
                       ON j.objectid = l.objectid
                 WHERE j.includeinfinalrevpending = 'Y'
                   AND j.statusname IN ('ACTIVE',
                                        'REVPEN',
                                        'R64B',
                                        'SUREND',
                                        'SUSPEN')
                   AND (TO_DATE(
                               LPAD(j.dup_seasonstartmonthnumber, 2, '00')
                            || '/01/'
                            || CASE
                                   WHEN   TO_NUMBER(TO_CHAR(j.dup_expirationdate, 'MM'))
                                        - (j.numberofmonthslicensednumber + 1) <  -- 01/10/2019 TJL 16435 removed = from test
                                        0 THEN
                                       NVL(j.expiringyear, '9999')
                                   ELSE
                                       NVL(j.expiringyear + 1, '9999')
                               END,
                            'MM/DD/YYYY')) =
                       a_expirationdate + 1;

                extension.pkg_collectionutils.append(t_objectidsfull, t_objectidstemp);

                --third get Secondary License types that expire on the specified expiration date that are not seasonal
                SELECT  /*+ cardinality (l 1) */
                       l.objectid
                  BULK COLLECT INTO t_objectidstemp
                  FROM TABLE(
                           api.pkg_simplesearch.castableobjectsbyindex('j_LicenseType',
                                                                       'dup_ExpirationDate',
                                                                       t_expirationdates)) l
                       JOIN query.j_licensetype j
                       ON j.objectid = l.objectid
                       JOIN query.r_licensetypeltcatsecondary r
                       ON r.licensetypejobid = j.objectid
                 WHERE j.dup_includeinfinalrevpendinsec = 'Y'
                   AND (SELECT s.tag
                          FROM api.jobstatuses js
                               JOIN api.statuses s
                               ON s.statusid = js.statusid
                         WHERE js.jobtypeid = t_lictypeid
                           AND UPPER(s.description) = r.status) IN ('ACTIVE',
                                                                    'REVPEN',
                                                                    'R64B',
                                                                    'SUREND',
                                                                    'SUSPEN')
                   AND r.includeinfinalrevpending = 'Y'
                   AND j.dup_seasonstartmonthnumber IS NULL;

                extension.pkg_collectionutils.append(t_objectidsfull, t_objectidstemp);

                --fourth get Secondary License types that are seasonal that start the day after the specified expiration date
                SELECT  /*+ cardinality (l 1) */
                       l.objectid
                  BULK COLLECT INTO t_objectidstemp
                  FROM TABLE(api.pkg_simplesearch.castableobjectsbyindexrange('j_LicenseType',
                                                                              'dup_SeasonStartMonthNumber',
                                                                              1,
                                                                              12)) l
                       JOIN query.j_licensetype j
                       ON j.objectid = l.objectid
                       JOIN query.r_licensetypeltcatsecondary r
                       ON r.licensetypejobid = j.objectid
                 WHERE j.dup_includeinfinalrevpendinsec = 'Y'
                   AND (SELECT s.tag
                          FROM api.jobstatuses js
                               JOIN api.statuses s
                               ON s.statusid = js.statusid
                         WHERE js.jobtypeid = t_lictypeid
                           AND UPPER(s.description) = r.status) IN ('ACTIVE',
                                                                    'REVPEN',
                                                                    'R64B',
                                                                    'SUREND',
                                                                    'SUSPEN')
                   AND r.includeinfinalrevpending = 'Y'
                   AND (TO_DATE(
                               LPAD(j.dup_seasonstartmonthnumber, 2, '00')
                            || '/01/'
                            || CASE
                                   WHEN   TO_NUMBER(TO_CHAR(j.dup_expirationdate, 'MM'))
                                        - (j.numberofmonthslicensednumber + 1) <  -- 01/10/2019 TJL 16435 removed = from test
                                        0 THEN
                                       NVL(j.expiringyear, '9999')
                                   ELSE
                                       NVL(j.expiringyear + 1, '9999')
                               END,
                            'MM/DD/YYYY')) =
                       a_expirationdate + 1;

                extension.pkg_collectionutils.append(t_objectidsfull, t_objectidstemp);
            --
            WHEN 'AUTO REVOKE LICENSE TYPES' THEN
                --first get License Types that expire on the specified expiration date that are not seasonal
                SELECT  /*+ cardinality (l 1) */
                       l.objectid
                  BULK COLLECT INTO t_objectidsfull
                  FROM TABLE(
                           api.pkg_simplesearch.castableobjectsbyindex('j_LicenseType',
                                                                       'dup_ExpirationDate',
                                                                       t_expirationdates)) l
                       JOIN query.j_licensetype j
                       ON j.objectid = l.objectid
                 WHERE j.includeinrevokebatch = 'Y'
                   AND j.statusname IN ('ACTIVE',
                                        'REVPEN',
                                        'R64B',
                                        'SUREND',
                                        'SUSPEN')
                   AND j.dup_seasonstartmonthnumber IS NULL;

                --second get License Types that are seasonal that start the day after the specified expiration date
                SELECT  /*+ cardinality (l 1) */
                       l.objectid
                  BULK COLLECT INTO t_objectidstemp
                  FROM TABLE(api.pkg_simplesearch.castableobjectsbyindexrange('j_LicenseType',
                                                                              'dup_SeasonStartMonthNumber',
                                                                              1,
                                                                              12)) l
                       JOIN query.j_licensetype j
                       ON j.objectid = l.objectid
                 WHERE j.includeinrevokebatch = 'Y'
                   AND j.statusname IN ('ACTIVE',
                                        'REVPEN',
                                        'R64B',
                                        'SUREND',
                                        'SUSPEN')
                   AND (TO_DATE(
                               LPAD(j.dup_seasonstartmonthnumber, 2, '00')
                            || '/01/'
                            || CASE
                                   WHEN   TO_NUMBER(TO_CHAR(j.dup_expirationdate, 'MM'))
                                        - (j.numberofmonthslicensednumber + 1) <  -- 01/10/2019 TJL 16435 removed = from test
                                        0 THEN
                                       NVL(j.expiringyear, '9999')
                                   ELSE
                                       NVL(j.expiringyear + 1, '9999')
                               END,
                            'MM/DD/YYYY')) =
                       a_expirationdate + 1;

                extension.pkg_collectionutils.append(t_objectidsfull, t_objectidstemp);

                --third get Secondary License types that expire on the specified expiration date that are not seasonal
                SELECT  /*+ cardinality (l 1) */
                       l.objectid
                  BULK COLLECT INTO t_objectidstemp
                  FROM TABLE(
                           api.pkg_simplesearch.castableobjectsbyindex('j_LicenseType',
                                                                       'dup_ExpirationDate',
                                                                       t_expirationdates)) l
                       JOIN query.j_licensetype j
                       ON j.objectid = l.objectid
                       JOIN query.r_licensetypeltcatsecondary r
                       ON r.licensetypejobid = j.objectid
                 WHERE j.dup_includeinrevokebatchsec = 'Y'
                   AND (SELECT s.tag
                          FROM api.jobstatuses js
                               JOIN api.statuses s
                               ON s.statusid = js.statusid
                         WHERE js.jobtypeid = t_lictypeid
                           AND UPPER(s.description) = r.status) IN ('ACTIVE',
                                                                    'REVPEN',
                                                                    'R64B',
                                                                    'SUREND',
                                                                    'SUSPEN')
                   AND r.includeinrevokebatch = 'Y'
                   AND j.dup_seasonstartmonthnumber IS NULL;

                extension.pkg_collectionutils.append(t_objectidsfull, t_objectidstemp);

                --fourth get Secondary License types that are seasonal that start the day after the specified expiration date
                SELECT  /*+ cardinality (l 1) */
                       l.objectid
                  BULK COLLECT INTO t_objectidstemp
                  FROM TABLE(api.pkg_simplesearch.castableobjectsbyindexrange('j_LicenseType',
                                                                              'dup_SeasonStartMonthNumber',
                                                                              1,
                                                                              12)) l
                       JOIN query.j_licensetype j
                       ON j.objectid = l.objectid
                       JOIN query.r_licensetypeltcatsecondary r
                       ON r.licensetypejobid = j.objectid
                 WHERE j.dup_includeinrevokebatchsec = 'Y'
                   AND (SELECT s.tag
                          FROM api.jobstatuses js
                               JOIN api.statuses s
                               ON s.statusid = js.statusid
                         WHERE js.jobtypeid = t_lictypeid
                           AND UPPER(s.description) = r.status) IN ('ACTIVE',
                                                                    'REVPEN',
                                                                    'R64B',
                                                                    'SUREND',
                                                                    'SUSPEN')
                   AND r.includeinrevokebatch = 'Y'
                   AND (TO_DATE(
                               LPAD(j.dup_seasonstartmonthnumber, 2, '00')
                            || '/01/'
                            || CASE
                                   WHEN   TO_NUMBER(TO_CHAR(j.dup_expirationdate, 'MM'))
                                        - (j.numberofmonthslicensednumber + 1) <
                                        0 THEN
                                       NVL(j.expiringyear, '9999')
                                   ELSE
                                       NVL(j.expiringyear + 1, '9999')
                               END,
                            'MM/DD/YYYY')) =
                       a_expirationdate + 1;

                extension.pkg_collectionutils.append(t_objectidsfull, t_objectidstemp);
            --
            WHEN '50% PENALTY' THEN
                sitespecific.pkg_batchtype.getbatchpenaltycandidates(a_jobid,
                                                                     a_asofdate,
                                                                     a_expirationdate,
                                                                     'REN50');
            --
            WHEN '100% PENALTY' THEN
                sitespecific.pkg_batchtype.getbatchpenaltycandidates(a_jobid,
                                                                     a_asofdate,
                                                                     a_expirationdate,
                                                                     'REN100');
            ELSE
                api.pkg_errors.raiseerror(-20000, 'You must choose a Batch Type before Continuing.');
        END CASE;

        -- sort and add the records to the LicBatchLicType_XREF_t
        IF t_objectidsfull.COUNT() > 0 THEN
              SELECT  /*+ cardinality (lt 1) */
                     lt.COLUMN_VALUE, j.dup_primarylicensee, j.dup_licenseexternalfilenum
                BULK COLLECT INTO t_objectidssort, t_primarylicensees, t_licensenumbers
                FROM TABLE(t_objectidsfull) lt
                     JOIN query.j_licensetype j
                     ON j.objectid = lt.COLUMN_VALUE
            ORDER BY 2, 3, 1;

            --t_TotalExpectedCount := t_ObjectIds.Count();
            t_totalexpectedcount   := CEIL(t_objectidsfull.COUNT() / t_chunksize);

            t_totalproccount       := t_totalexpectedcount;
            --Set the counts on the job
            api.pkg_columnupdate.setvalue(a_jobid, 'ProcessCount', t_totalproccount);

            FORALL x IN t_objectidssort.FIRST .. t_objectidssort.LAST
                INSERT INTO licbatchlictype_xref_t
                     VALUES (a_jobid,
                             t_objectidssort(x),
                             serial_number.NEXTVAL,
                             NULL,
                             NULL,
                             'Y',
                             NULL);
        END IF;
    END relatependingltstobatch;

    /****************************************************************************
     * Scheduled Batch Processes
     * Distribute Batch items among scheduled-to-complete processes to break up
     *   the workload
     ***************************************************************************/
    PROCEDURE schedulebatchprocesses(a_objectid udt_id, a_asofdate DATE, a_jobid udt_id)
    IS
        t_jobid               udt_id;
        t_batchtype           VARCHAR2(100);
        t_processdefid        udt_id;
        t_processdesc         VARCHAR2(60);
        t_processstatus       VARCHAR2(30);
        t_recordcount         NUMBER;
        t_chunksize           NUMBER;
        t_processseries       udt_idlist;
        t_processid           udt_id;
        t_scheduleddatetime   DATE;
        t_baseincrement       NUMBER := 5 / 1440;  -- 5 minutes
        t_scheduleincrement   NUMBER := 1 / 1440;  -- 1 minute
        t_subject             VARCHAR2(4000);
        t_body                VARCHAR2(4000);
        t_toaddress           VARCHAR2(4000) := api.pkg_constantquery.VALUE('LICENSINGNOTIFICATIONEMAIL');
        t_ccaddress           VARCHAR2(4000) := api.pkg_constantquery.VALUE('APPLICATIONSUPPORTEMAIL');
        t_fromaddress         VARCHAR2(4000) := api.pkg_constantquery.VALUE('APPLICATIONSUPPORTEMAIL');
        t_emailid             udt_id;
    BEGIN
        t_jobid               := a_jobid;
        t_scheduleddatetime   := SYSDATE;

        t_batchtype           := api.pkg_columnquery.VALUE(t_jobid, 'BatchType');
        getprocesstypeforbatch(t_batchtype,
                               t_processdefid,
                               t_processdesc,
                               t_processstatus);


        -- Send an email notifying that the job has started processing
        t_subject             :=
               'BATCH: Relate Pending License Types Started for Job '
            || api.pkg_columnquery.VALUE(t_jobid, 'ExternalFileNum');
        t_body                :=
               'Relate Pending License Types for Batch Job '
            || api.pkg_columnquery.VALUE(t_jobid, 'ExternalFileNum')
            || ' has started processing.'
            || CHR(13)
            || CHR(10);
        t_body                :=
               t_body
            || 'Batch Job: '
            || api.pkg_columnquery.VALUE(t_jobid, 'ExternalFileNum')
            || CHR(13)
            || CHR(10)
            || CHR(13)
            || CHR(10);
        t_body                :=
               t_body
            || 'Type: '
            || t_batchtype
            || CHR(13)
            || CHR(10);
        t_body                :=
               t_body
            || 'Color: '
            || api.pkg_columnquery.VALUE(t_jobid, 'Color')
            || CHR(13)
            || CHR(10);
        t_body                :=
               t_body
            || 'Expiration Date: '
            || TO_CHAR(api.pkg_columnquery.datevalue(t_jobid, 'ExpirationDate'), 'mm/dd/yyyy')
            || CHR(13)
            || CHR(10);
        t_body                :=
               t_body
            || 'Created By: '
            || api.pkg_columnquery.VALUE(t_jobid, 'CreatedByUserName');
        t_emailid             :=
            extension.pkg_sendmail.send(t_fromaddress,  --fromaddress
                                        t_toaddress,  --ToAddress
                                        t_subject,  --Subject
                                        t_body,  --Body
                                        NULL,  --[Mimetype]
                                        1,  --[priority] --1 means high priority
                                        t_ccaddress,  --[ccaddress]
                                        NULL,  --[bccaddress]
                                        t_body,  --[message]
                                        NULL  --a_RelatedObjectId--[relatedobjectid]
                                            );


        --EmailErrorOrSuccess(t_ToAddress, t_Subject, t_Body, null, t_CCAddress, null);

        api.pkg_logicaltransactionupdate.endtransaction;
        COMMIT;


        IF t_batchtype IN ('50% PENALTY', '100% PENALTY') THEN
            -- Just create the Penalty Process
            t_processid          :=
                api.pkg_processupdate.new(t_jobid,
                                          t_processdefid,
                                          t_processdesc,
                                          NULL,
                                          NULL,
                                          NULL);
            t_processseries(1)   := t_processid;
        ELSE
            -- Chunking here
            t_chunksize   := api.pkg_constantquery.VALUE('BATCHCHUNKSIZE');

            SELECT COUNT(*)
              INTO t_recordcount
              FROM licbatchlictype_xref_t t
             WHERE t.licensebatchjobid = t_jobid;

            -- Create required to accomodate the number of items to be processed
            FOR i IN 1 .. CEIL(t_recordcount / t_chunksize)
            LOOP
                t_processid          :=
                    api.pkg_processupdate.new(t_jobid,
                                              t_processdefid,
                                              t_processdesc,
                                              NULL,
                                              NULL,
                                              NULL);
                t_processseries(i)   := t_processid;
            END LOOP;

            -- Assign sets of items to process
            -- SG: Fixing issue where chunking was breaking the sort of Primary Licensee, License #, LicenseTypeCode and dup_count
            --     I used the same sort here that is used when generating the Print Licenses
            FOR i
                IN (SELECT ROWID, CEIL(ROWNUM / t_chunksize) chunk
                      FROM (  SELECT t.ROWID,
                                     api.pkg_columnquery.VALUE(t.licensetypejobid, 'PrimaryLicensee')
                                         licensee,
                                     api.pkg_columnquery.VALUE(t.licensetypejobid, 'ExternalFileNum')
                                         licensenum,
                                     api.pkg_columnquery.VALUE(t.licensetypejobid, 'LICENSETYPECODE')
                                         lictypecode,
                                     NVL2(api.pkg_columnquery.VALUE(t.licensetypejobid, 'MasterLicenseNumber'),
                                          1,
                                          NVL(api.pkg_columnquery.VALUE(t.licensetypejobid, 'PrimaryCount'), NULL))
                                         dup_count
                                FROM sitespecific.licbatchlictype_xref_t t
                               WHERE licensebatchjobid = t_jobid
                            ORDER BY 2,
                                     3,
                                     4,
                                     5 NULLS FIRST))
            LOOP
                UPDATE licbatchlictype_xref_t
                   SET processid = t_processseries(i.chunk), tobeprocessedind = 'Y'
                 WHERE ROWID = i.ROWID;
            END LOOP;
        END IF;

        -- Schedule completion of processes series
        FOR i IN 1 .. t_processseries.COUNT
        LOOP
            pkg_sysschedule.schedulelicensebatchprocess(
                t_processseries(i),
                a_asofdate,
                t_scheduleddatetime + t_baseincrement + t_scheduleincrement * (i - 1),
                a_jobid,
                t_processstatus);
        END LOOP;
    END;

    /****************************************************************************
     * Monitor Batch Completion -- PRIVATE
     * If all processes on the job of the calling type are complete than create
     *   and complete a specific process
     ***************************************************************************/
    PROCEDURE monitorbatchcompletion(a_processid udt_id, a_asofdate DATE, a_jobid udt_id)
    IS
      t_processid     udt_id;
      t_subject       VARCHAR2(4000);
      t_body          VARCHAR2(4000);
      t_toaddress     VARCHAR2(4000) := api.pkg_constantquery.VALUE('LICENSINGNOTIFICATIONEMAIL');
      t_ccaddress     VARCHAR2(4000) := api.pkg_constantquery.VALUE('APPLICATIONSUPPORTEMAIL');
      t_fromaddress   VARCHAR2(4000) := api.pkg_constantquery.VALUE('APPLICATIONSUPPORTEMAIL');
      t_emailid       udt_id;
    BEGIN
      -- loop through sibling processes of the same type on the job
      FOR i IN (
        SELECT p2.outcome, jobid
        FROM api.processes p1
        JOIN api.processes p2 USING (jobid, processtypeid)
        WHERE p1.processid = a_processid
          AND p1.outcome IS NOT NULL
          AND p1.processid != p2.processid
      )
      LOOP
      IF i.outcome IS NULL THEN
        RETURN;
      END IF;
      END LOOP;

      -- If this code runs, all sibling processes of the same type are complete
      -- Complete the job
      t_processid := api.pkg_processupdate.new(
        a_jobid,
        api.pkg_configquery.objectdefidforname('p_CompleteBatchJob'),
        'Complete Batch Job',
        NULL,
        NULL,
        NULL
      );
      api.pkg_processupdate.complete(t_processid, 'Complete');

      t_subject   :=
        'BATCH: License Job '
        || api.pkg_columnquery.VALUE(a_jobid, 'ExternalFileNum')
        || ' Succeeded';
      t_body   := 'Job successfully completed.';


      t_emailid := extension.pkg_sendmail.send(
        t_fromaddress,  --fromaddress
        t_toaddress,  --ToAddress
        t_subject,  --Subject
        t_body,  --Body
        NULL,  --[Mimetype]
        1,  --[priority] --1 means high priority
        t_ccaddress,  --[ccaddress]
        NULL,  --[bccaddress]
        t_body,  --[message]
        a_jobid  --a_RelatedObjectId--[relatedobjectid]
      );
    
    --EmailErrorOrSuccess(t_ToAddress, t_Subject, t_Body, null, t_CCAddress, a_JobId);

    END;

    /****************************************************************************
     * Batch Process Completion
     * Send email report and trigger job completion if last batch process is
     *   complete
     ***************************************************************************/
    PROCEDURE batchprocesscompletion(
      a_processid udt_id, 
      a_asofdate DATE, 
      a_jobid udt_id
    )
    IS
      t_subject         VARCHAR2(4000);
      t_body            VARCHAR2(4000);
      t_toaddress       VARCHAR2(4000) := api.pkg_constantquery.VALUE('LICENSINGNOTIFICATIONEMAIL');
      t_ccaddress       VARCHAR2(4000) := api.pkg_constantquery.VALUE('APPLICATIONSUPPORTEMAIL');
      t_processtypeid   udt_id;
      t_rnum            udt_id;

    CURSOR c_siblingprocesses(a_processid udt_id) IS
      SELECT 
        ROW_NUMBER() OVER(PARTITION BY 1 ORDER   BY p2.processid)         rn,
        COUNT(*) OVER (PARTITION BY 1)                                  cnt,
        p2.processid,
        LAG(p2.processid, 1) OVER(PARTITION BY 1 ORDER BY p2.processid) priorprocessid,
        LAG(p2.outcome, 1) OVER(PARTITION BY 1 ORDER BY p2.processid)   prioroutcome
        FROM api.processes p1
      JOIN api.processes p2 USING (processtypeid, jobid)
      WHERE p1.processid = a_processid;
    BEGIN
      FOR i IN c_siblingprocesses(a_processid)
      LOOP
        IF i.processid = a_processid THEN
          t_subject   :=
            'BATCH: Process Chunk #'
            || i.rn
            || ' of '
            || i.cnt
            || ' '
            || api.pkg_columnquery.VALUE(a_jobid, 'ExternalFileNum')
            || ' Succeeded';
            t_body   := 'Chunk Complete';

          IF i.prioroutcome IS NULL AND i.rn != 1 THEN
            t_rnum   := i.rn - 1;
            t_body   :=
                 t_body
              || CHR(13)
              || CHR(10)
              || 'Prior Chunk #'
              || t_rnum
              || ' ('
              || i.priorprocessid
            || ') is incomplete';
          END IF;

          emailerrororsuccess(
            t_toaddress,
            t_subject,
            t_body,
            NULL,
            t_ccaddress,
            a_jobid
          );
          EXIT;  -- no need to continue the loop
        END IF;
        END LOOP;

        monitorbatchcompletion(a_processid, a_asofdate, a_jobid);
    END;

    /****************************************************************************
     * ScheduleBatchProcessing
     * Scheduled the procedure that initiates the batch processing
     ***************************************************************************/
    PROCEDURE schedulebatchprocessing(
      a_processid udt_id, 
      a_asofdate DATE, 
      a_jobid udt_id
    )
    IS
      t_scheduledatetime   DATE;
    BEGIN
      t_scheduledatetime   := api.pkg_columnquery.datevalue(a_processid, 'ScheduledDateTime');

      sitespecific.pkg_sysschedule.scheduleprocedure(
        a_processid,
        a_asofdate,
        'sitespecific.pkg_BatchType.ScheduleBatchProcesses',
        'Schedule Batch Processes',
        'POSSESYS',
        1,
        t_scheduledatetime
      );
    END;

    /* *********************************************************************************************
     * Auto Revoke License Types.
     * This process automatically revokes license types related to the license batch. An autoRevoke
     * Process is related to the license type jobs and then completed with an autorevoke status.
     * If all license types related to a license are autorevoked a revoke license process is related to
     * the license.
     ************************************************************************************************/
    PROCEDURE autorevokelts(a_processid udt_id, a_asofdate DATE, a_jobid udt_id)
    IS
        t_prevlicjobid        udt_id;
        t_ltcnt               INTEGER := 0;
        t_licautorevcnt       INTEGER := 0;
        t_licensejobids       udt_idlist;
        t_licensetypejobids   udt_idlist;
        t_ltsecondaryrelids   udt_idlist;
        t_subject             VARCHAR2(4000);
        t_body                VARCHAR2(4000);
        t_toaddress           VARCHAR2(4000) := api.pkg_constantquery.VALUE('LICENSINGNOTIFICATIONEMAIL');
        t_ccaddress           VARCHAR2(4000) := api.pkg_constantquery.VALUE('APPLICATIONSUPPORTEMAIL');
    BEGIN
        IF api.pkg_columnquery.VALUE(a_processid, 'ForceFailure') = 'Y' THEN
            api.pkg_errors.raiseerror(-20000, 'Failure forced by process checkbox');
        END IF;

          -- RyanL: Changed to bulk collect for performance (PIP Task 8.7)
          SELECT rllt.licensejobid, rllt.licensetypejobid
            BULK COLLECT INTO t_licensejobids, t_licensetypejobids
            FROM sitespecific.licbatchlictype_xref_t rltlb
                 JOIN query.r_licenselicensetype rllt
                 ON rllt.licensetypejobid = rltlb.licensetypejobid
           WHERE rltlb.licensebatchjobid = a_jobid
             --and rltlb.ToBeProcessedInd = 'Y'                -- added MMR 10-9-14
             AND rltlb.processid = a_processid  -- added AWP (CXUSA) 5/13/2016 to speed up batch and conform to new "chunking" of batch.
        ORDER BY 1, 2;

        FOR i IN 1 .. t_licensejobids.COUNT
        LOOP
            IF (t_prevlicjobid != t_licensejobids(i))
            OR (t_prevlicjobid IS NULL) THEN
                IF t_prevlicjobid IS NOT NULL THEN  -- if first time through set the t_prevlicjobid to the current license job value.
                    SELECT COUNT(*)  -- select count af all license types related to license
                      INTO t_ltcnt
                      FROM query.r_licenselicensetype rllt2
                     WHERE rllt2.licensejobid = t_prevlicjobid;

                    IF t_ltcnt = t_licautorevcnt THEN  -- all of the license types for the license autocompleted?
                        -- assign a revoke license process to the license job.
                        t_newprocid   :=
                            api.pkg_processupdate.new(t_prevlicjobid,
                                                      api.pkg_configquery.objectdefidforname('p_RevokeLicense'),
                                                      'Revoke License',
                                                      TRUNC(SYSDATE),
                                                      TRUNC(SYSDATE),
                                                      TRUNC(SYSDATE));
                    END IF;

                    t_licautorevcnt   := 0;
                END IF;

                t_prevlicjobid   := t_licensejobids(i);
            END IF;

            t_licautorevcnt   := t_licautorevcnt + 1;

            -- Reset the IncludeInRevokeBatch flag to 'N'
            api.pkg_columnupdate.setvalue(t_licensetypejobids(i), 'IncludeInRevokeBatch', 'N');

            -- Create the auto revoke process on the license type.
            t_newprocid       :=
                api.pkg_processupdate.new(t_licensetypejobids(i),
                                          api.pkg_configquery.objectdefidforname('p_AutoRevokeLicenseType'),
                                          'Automatically Revoke License Type',
                                          TRUNC(SYSDATE),
                                          TRUNC(SYSDATE),
                                          TRUNC(SYSDATE));
            -- Complete the auto revoke proces.
            api.pkg_processupdate.complete(t_newprocid, 'Auto Revoke');

            --HotFix22 Part one, loop through the Secondary License Types and reset the flags to 'N'
            -- RyanL: Changed to bulk collect for performance (PIP Task 8.7)
            SELECT slt.relationshipid
              BULK COLLECT INTO t_ltsecondaryrelids
              FROM query.r_licensetypeltcatsecondary slt
                   JOIN query.o_licensetypecategory ltc
                   ON ltc.objectid = slt.licensetypecategoryobjectid
             WHERE slt.licensetypejobid = t_licensetypejobids(i)
               AND slt.status IN ('ACTIVE',
                                  'SURRENDERED',
                                  'SUSPENDED',
                                  'RULE 64B',
                                  'REV PENDING');

            FOR j IN 1 .. t_ltsecondaryrelids.COUNT
            LOOP
                api.pkg_columnupdate.setvalue(t_ltsecondaryrelids(j), 'IncludeInRevokeBatch', 'N');
                api.pkg_columnupdate.setvalue(t_ltsecondaryrelids(j), 'Status', 'AUTO REVOKED');
            END LOOP;
        END LOOP;

        -- Make sure that we get the last license checked to see if it should be assigned a Revoke License process.
        SELECT COUNT(*)
          INTO t_ltcnt
          FROM query.r_licenselicensetype rllt2
         WHERE rllt2.licensejobid = t_prevlicjobid;

        IF t_ltcnt = t_licautorevcnt THEN
            -- assign a revoke license process to the license job.
            t_newprocid   :=
                api.pkg_processupdate.new(t_prevlicjobid,
                                          api.pkg_configquery.objectdefidforname('p_RevokeLicense'),
                                          'Revoke License',
                                          TRUNC(SYSDATE),
                                          TRUNC(SYSDATE),
                                          TRUNC(SYSDATE));
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            BEGIN
                t_subject          :=
                       'BATCH: Auto-Revoke Failed: JobID='
                    || api.pkg_columnquery.VALUE(a_jobid, 'ExternalFileNum');
                t_body             :=
                       'Batch Job FAILED: '
                    || SQLERRM;

                --set flag that an error message email has been sent for this job, do not send a "success" email
                g_erroremailsent   := 'Y';

                emailerrororsuccess(t_toaddress,  --ToAddress
                                    t_subject,  --Subject
                                    t_body,  --Body
                                    NULL,  --[priority] --1 means high priority
                                    t_ccaddress,  --[ccaddress]
                                    a_processid);
            END;

            RAISE;
    END autorevokelts;



    /* *************************************************************************************************
     * CreateSchedulerProcesses(Private) -Called below by ProduceLicenses
     * Running all licenses on a single batch process results in the process server having memory issues
     * This procedure splits up the batch onto multiple printing processes
     ***************************************************************************************************/
    PROCEDURE createschedulerprocesses(
      a_processid udt_id, 
      a_asofdate DATE, a_jobid udt_id
    )
    IS
      t_liccount             INTEGER := 0;
      t_batchreportlimit     INTEGER := 0;
      t_count                INTEGER := 1;
      t_printorder           INTEGER := 0;
      t_serialnum            INTEGER := 0;
      t_scheduleddate        DATE := api.pkg_columnquery.datevalue(a_jobid, 'ScheduledDateTime');
      t_licensebatchjobids   udt_idlist;
      t_licensetypejobids    udt_idlist;
      t_serialnumbers        udt_idlist;
    BEGIN
      --Removed looping since we're now creating one process per chunk. CT
      -- replaced 'Print' outcome with null so it stops at the PDF stage - MMR 10-09-14
      -- replaced null outcome with 'Print' so it doesn't stop at the PDF stage - YT 1-22-16
      -- Put null back instead of the 'Print' Outcome in order to go back to the production
      -- functionality where this outcome is set by Copy Details on creation of the process.
      sitespecific.pkg_sysschedule.scheduleprocess(
        a_processid,
        a_asofdate,
        'Y',
        'p_PrintLicenseBulk',
        NULL,
        1,
        SYSDATE
      );

      --end loop;

      --Get max print order to be set later
      SELECT MAX(xr.printorder) + 1 INTO t_printorder
        FROM sitespecific.licbatchlictype_xref_t xr
       WHERE xr.licensebatchjobid = a_jobid;

        --Make sure we have a print order. If we don't then set it to 1.
        IF t_printorder IS NULL THEN
          t_printorder   := 1;
        END IF;

      -- RyanL: Changed to bulk collect for performance (PIP Task 8.7)
      SELECT 
        xr.serialnumber, xr.licensetypejobid, xr.licensebatchjobid
        BULK COLLECT INTO t_serialnumbers, t_licensetypejobids, t_licensebatchjobids
      FROM sitespecific.licbatchlictype_xref_t xr
      WHERE xr.licensebatchjobid = a_jobid
        AND xr.tobeprocessedind = 'Y'
        AND xr.processid = a_processid
      ORDER BY xr.serialnumber, xr.licensetypejobid;

      FOR i IN 1 .. t_licensetypejobids.COUNT
      LOOP
        -- When ToBeProcessedInd = 'Y', it will update the print order
        UPDATE sitespecific.licbatchlictype_xref_t xr
        SET xr.printorder   = t_printorder
        WHERE xr.licensetypejobid = t_licensetypejobids(i)
          AND xr.tobeprocessedind = 'Y'
          AND xr.licensebatchjobid = t_licensebatchjobids(i)
          AND xr.processid = a_processid;

        -- also update the log  MMR 10-30-14
        UPDATE sitespecific.batch_tracking_log btl
        SET printorder = t_printorder, serialnumber = t_serialnumbers(i), logcomment = 'Part 1 - Processing'
        WHERE licensetypejobid = t_licensetypejobids(i)
          AND tobeprocessedind = '1'
          AND licensebatchjobid = t_licensebatchjobids(i);
      END LOOP;
    END createschedulerprocesses;

    /* ******************************************************************************************************
    * Schedule Produce Licenses
    * Schedule the Produce Licenses procedure onto a specific Process Server
    ************************************************************************************************/
    PROCEDURE scheduleproducelicenses(a_processid udt_id, a_asofdate DATE, a_jobid udt_id)
    IS
    BEGIN
        sitespecific.pkg_sysschedule.scheduleprocedure(a_processid,
                                                       a_asofdate,
                                                       'sitespecific.pkg_BatchType.ProduceLicenses',
                                                       'Produce Licenses',
                                                       'POSSESYS',
                                                       1,
                                                       SYSDATE);
    END;

    /* ******************************************************************************************************
     * Produce Licenses.
     * This process automatically relates and completes an Activate License Type process for each License Type
     * related to the batch job and relates and completes an Activate License process for each License related
     * to the license types as outlined below.

     * Also, the process will handle License Type Jobs which have been tagged for Reinstatement
     * after they have gone to Rev Pending or Auto Revoke status. Primary, Secondary, or both; as needed.
     * HQ inserts a Reinstate License Type process to "rescue" the LT; Produe Licenses then sets the
     * status back to what it was prior to Rev Pending or Auto Revoke.
     *
     * TYPE*   License         License  DoNotActivate    Include  Activat Activat    Set           Set
     *         Status          Type      Flag            In       License License   DoNotActivate  IncludeInProduceLicenseBatch
     *                         Status    Value           Batch             Type       To:          To:
     * ------------------------------------------------------------------------------------------------------
     * B        p                P        F                Y        Y        Y        N/C           N
     * B        P                P        T                Y        Y        N        N/C           N
     * B        P                A        F                Y        Y        N        N/C           N
     * B        P                A        T                Y        Y        N        N/C           N
     * B        p                RP       F                Y        Y        Y        N/C           N
     * B        P                RP       T                Y        Y        N        N/C           N
     * B        P                S        F                Y        Y        N        N/C           N
     * B        P                S        T                Y        Y        N        N/C           N
     * ------------------------------------------------------------------------------------------------------
     * B        H/SLMS-H         *        *                Y        N        N        N/C           N
     * ------------------------------------------------------------------------------------------------------
     * B        SUS              *        *                Y        N        N        N/C           N
     * -------------------------------------------------------------------------------------------------------
     * B        A                P        F                Y        Y        Y        N/C           N
     * B        A                P        T                Y        Y        N        N/C           N
     * B        A                A        F                Y        Y        N        N/C           N
     * B        A                A        T                Y        Y        N        N/C           N
     * B        A                RP       F                Y        Y        Y        N/C           N
     * B        A                RP       T                Y        Y        N        N/C           N
     * B        A                S        F                Y        Y        N        N/C           N
     * B        A                S        T                Y        Y        N        N/C           N
     * -------------------------------------------------------------------------------------------------------
     *
     * * M = Manual, B=Batch
     ************************************************************************************************/
    PROCEDURE producelicenses(a_processid udt_id, a_asofdate DATE, a_jobid udt_id)
    IS
        t_prevlicjobid                   udt_id;
        t_seasonstartdate                DATE;
        t_color                          VARCHAR2(10) := api.pkg_columnquery.VALUE(a_jobid, 'Color');
        t_dailyorrenewal                 VARCHAR2(10) := api.pkg_columnquery.VALUE(a_jobid, 'DailyOrRenewal');
        t_licenseissuedate               DATE := api.pkg_columnquery.datevalue(a_jobid, 'LICENSEISSUEDATE');
        t_statustags                     VARCHAR(4000);
        t_fromstat                       udt_id;
        t_effectiveenddate               DATE;
        t_effectivestartdate             DATE;
        t_jobstatuschangeid              udt_id;
        t_setbackstat                    extension.jobstatuschange.statusname%TYPE;
        t_relationshipid                 udt_id;
        t_setoutcome                     VARCHAR2(60);
        t_setstatus                      VARCHAR2(60);
        t_licensetypejobtypeid           udt_id := api.pkg_configquery.objectdefidforname('j_LicenseType');
        t_processid                      udt_id;
        t_transfromltid                  udt_id;
        t_recordsprocessed               NUMBER := 0;
        t_secondaryrecordsprocessed      NUMBER := 0;
        t_committhreshold                NUMBER := 25;
        t_batchdate                      DATE;
        t_duplicateid                    udt_id;
        t_subject                        VARCHAR2(4000);
        t_body                           VARCHAR2(4000);
        t_toaddress                      VARCHAR2(4000) := api.pkg_constantquery.VALUE('LICENSINGNOTIFICATIONEMAIL');
        t_ccaddress                      VARCHAR2(4000) := api.pkg_constantquery.VALUE('APPLICATIONSUPPORTEMAIL');
        t_errcount                       NUMBER := 0;

        TYPE lt_collection IS TABLE OF NUMBER;  -- INDEX BY BINARY_INTEGER;

        threshold_collection             lt_collection := lt_collection();
        processed_collection             lt_collection := lt_collection();
        l_counter                        NUMBER := 0;
        l_curr_ltjobid_rec               NUMBER;
        l_final_count                    NUMBER;
        l_exists                         NUMBER;
        t_licensejobids                  udt_idlist;
        t_licensetypejobids              udt_idlist;
        t_ltcatobjectids                 udt_idlist;
        t_reinstate                      VARCHAR2(1);
        t_donotactivate                  VARCHAR2(1);
        t_ltstatus                       VARCHAR2(30);
        t_licissuedate                   DATE;
        t_readytoissuedate               DATE;
        t_expirationdate                 DATE;
        t_ltissuedate                    DATE;
        t_numberofmonthslicensednumber   NUMBER;
        t_includeinproducelicensebatch   VARCHAR2(1);
        t_seasonstartmonthnumber         NUMBER;
        t_seasonalmonthsapply            VARCHAR2(1);
        t_ltcatcolor                     VARCHAR2(10);
    BEGIN
        pkg_debug.putline('******* Begin pkg_BatchType.ProduceLicenses *******');

        IF api.pkg_columnquery.VALUE(a_processid, 'ForceFailure') = 'Y' THEN
            api.pkg_errors.raiseerror(-20000, 'Failure forced by process checkbox.');
        END IF;

        -- RyanL: Changed to bulk collect for performance (PIP Task 8.7)
        SELECT  --/*+ GATHER_PLAN_STATISTICS */
               UNIQUE l.jobid, lt.jobid, ltc.objectid
          BULK COLLECT INTO t_licensejobids, t_licensetypejobids, t_ltcatobjectids
          FROM sitespecific.licbatchlictype_xref_t rltlb
               JOIN query.r_licenselicensetype rllt
               ON rllt.licensetypejobid = rltlb.licensetypejobid
               JOIN query.j_licensetype lt
               ON lt.jobid = rltlb.licensetypejobid
               JOIN query.j_license l
               ON l.jobid = rllt.licensejobid
               JOIN query.r_licensetypeltcatprimary rltltc
               ON rltltc.licensetypejobid = lt.jobid  --ObjectId
               JOIN query.o_licensetypecategory ltc
               ON ltc.objectid = rltltc.licensetypecategoryobjectid
         WHERE rltlb.licensebatchjobid = a_jobid
           AND rltlb.tobeprocessedind = 'Y'
           AND rltlb.processid = a_processid
           AND lt.statusid IN (SELECT s.statusid
                                 FROM api.statuses s
                                      JOIN api.jobstatuses js
                                      ON js.statusid = s.statusid
                                     AND js.jobtypeid = t_licensetypejobtypeid
                                WHERE js.statustype NOT IN ('C', 'X')
                                   OR (s.tag IN ('AUTREV', 'REVPEN')
                                   AND lt.reinstate = 'Y'));

        --Reset the batch flags
        -- pkg_BatchType.SetBatchFlagsOnBatchJobs(a_ProcessId,a_AsOfDate,a_JobId,'IncludeInProduceLicenseBatch');
        --As of 6/1/2010 this was moved from the beginning of the package to the center for each action that takes place the batch flags are modified.
        FOR i IN 1 .. t_licensejobids.COUNT
        LOOP
            t_reinstate                                          := api.pkg_columnquery.VALUE(t_licensetypejobids(i), 'Reinstate');
            t_donotactivate                                      := api.pkg_columnquery.VALUE(t_licensetypejobids(i), 'DoNotActivate');
            t_ltstatus                                           := api.pkg_columnquery.VALUE(t_licensetypejobids(i), 'StatusName');
            t_readytoissuedate                                   := api.pkg_columnquery.datevalue(t_licensetypejobids(i), 'ReadyToIssueDate');
            t_expirationdate                                     := api.pkg_columnquery.datevalue(t_licensetypejobids(i), 'dup_ExpirationDate');
            t_ltissuedate                                        := api.pkg_columnquery.datevalue(t_licensetypejobids(i), 'IssueDate');
            t_numberofmonthslicensednumber                       :=
                api.pkg_columnquery.numericvalue(t_licensetypejobids(i), 'NumberOfMonthsLicensedNumber');
            t_includeinproducelicensebatch                       :=
                api.pkg_columnquery.VALUE(t_licensetypejobids(i), 'IncludeInProduceLicenseBatch');
            t_seasonstartmonthnumber                             :=
                api.pkg_columnquery.numericvalue(t_licensetypejobids(i), 'SeasonStartMonthNumber');
            t_licissuedate                                       := api.pkg_columnquery.datevalue(t_licensejobids(i), 'IssueDate');
            t_seasonalmonthsapply                                := api.pkg_columnquery.VALUE(t_ltcatobjectids(i), 'SeasonalMonthsApply');
            t_ltcatcolor                                         := api.pkg_columnquery.VALUE(t_ltcatobjectids(i), 'Color');

            IF t_recordsprocessed MOD 100 = 0 THEN
                pkg_debug.putline(   '******* Processed '
                                  || t_recordsprocessed
                                  || ' records *******');
            END IF;

            --    api.pkg_errors.raiseerror(-20000,'Entered Main Cursor ');   ---------------
            t_recordsprocessed                                   := t_recordsprocessed + 1;

            IF t_reinstate <> 'Y' THEN  -- do work for NON-Reinstatement record
                -- grab the id of the current record for the batch log
                l_curr_ltjobid_rec   := t_licensetypejobids(i);

                IF (t_prevlicjobid != t_licensejobids(i)
                 OR t_prevlicjobid IS NULL)
               AND t_ltstatus != 'SUREND' THEN
                    t_newprocid      :=
                        api.pkg_processupdate.new(t_licensejobids(i),
                                                  api.pkg_configquery.objectdefidforname('p_BatchActivateLicense'),
                                                  'Batch Activate License',
                                                  TRUNC(SYSDATE),
                                                  TRUNC(SYSDATE),
                                                  TRUNC(SYSDATE));
                    --Set a column that will be used to determine which license types to Activate.
                    api.pkg_columnupdate.setvalue(t_newprocid, 'LicenseBatchJobId', a_jobid);
                    --Complete the Activate License proces.
                    api.pkg_processupdate.complete(t_newprocid, 'Batch Activate');
                    t_prevlicjobid   := t_licensejobids(i);

                    -- Set License IssueDate to current date if it is not already set.
                    IF t_licissuedate IS NULL THEN
                        api.pkg_columnupdate.setvalue(t_licensejobids(i), 'IssueDate', TRUNC(t_readytoissuedate));
                    END IF;
                END IF;

                t_seasonstartdate    :=
                    TRUNC(ADD_MONTHS(t_expirationdate, -(t_numberofmonthslicensednumber)), 'Month');

                -- not sure that if statement component IsBothDone and HasBothLicenseColors is necessary,
                --     or leftover from previous procedure logic. It may no longer be necessary,
                --     but we are leaving it in to avoid the regression testing removing it would necessitate.  -- cx 04.2010
                -- For Hotfix22 Part one produce license we are removing the IsBoth checks since we
                --     added batch flags to secondary relationships.
                --(t_ltstatus in ('PEND','REVPEN') or (t_IsBothDone = 'N' and t_HasBothLicenseColors = 'Y'))
                IF (t_includeinproducelicensebatch = 'Y'
                AND t_donotactivate = 'N'
                AND t_ltcatcolor = t_color
                AND ((TRUNC(t_readytoissuedate) BETWEEN (t_licenseissuedate - 14) AND t_licenseissuedate
                  AND t_dailyorrenewal = 'Daily')
                  OR (t_dailyorrenewal = 'Renewal'
                  AND TRUNC(t_readytoissuedate) <= t_licenseissuedate))) THEN
                    IF t_ltstatus = 'PEND' THEN
                        -- Activate license type
                        t_newprocid   :=
                            api.pkg_processupdate.new(
                                t_licensetypejobids(i),
                                api.pkg_configquery.objectdefidforname('p_ActivateLicenseType'),
                                'Activate License Type',
                                TRUNC(SYSDATE),
                                TRUNC(SYSDATE),
                                TRUNC(SYSDATE));
                        api.pkg_columnupdate.setvalue(t_newprocid, 'BatchActivate', 'Y');
                        -- Complete the Activate License Type proces.
                        api.pkg_processupdate.complete(t_newprocid, 'Activate');

                        -- Terminate the transfer from License Type
                        BEGIN
                            SELECT lt.jobid
                              INTO t_transfromltid
                              FROM sitespecific.licensetransfers_t t
                                   JOIN query.j_licensetype lt
                                   ON lt.objectid = t.transfromltjobid
                             WHERE t.transtoltjobid = t_licensetypejobids(i)
                               AND lt.statusname NOT IN ('CANCEL',
                                                         'SLMSRV',
                                                         'AUTREV',
                                                         'DEPREV',
                                                         'NREN',
                                                         'WTHDRN',
                                                         'DENIED',
                                                         'VOIDED')
                               AND t.actiontype IN ('CT', 'EX');

                            t_processid   :=
                                api.pkg_processupdate.new(
                                    t_transfromltid,
                                    api.pkg_configquery.objectdefidforname('p_TerminateLicenseType'),
                                    (   'License Type Terminated by System for Transfer Application'
                                     || api.pkg_columnquery.VALUE(t_licensejobids(i), 'LicenseNumber')),
                                    NULL,
                                    NULL,
                                    NULL);
                            api.pkg_processupdate.complete(t_processid, 'Cancel');
                        EXCEPTION
                            WHEN NO_DATA_FOUND THEN
                                NULL;  -- This License Type was not transferred
                        END;
                    END IF;

                    --HofFix22 Part One - for Produce License we are setting the Print Boolean for the License Report.
                    --Set the Print Detail for Secondary License Types.
                    api.pkg_columnupdate.setvalue(t_licensetypejobids(i), 'Print', 'Y');

                    --Earn the Payment Transactions.
                    sitespecific.pkg_fees.createltpaymentstatus(t_licensetypejobids(i), SYSDATE);

                    --HotFix22 Part One - Produce License we are setting the batch flags to first renewal.
                    --Set Batch Flags - First Renewal
                    sitespecific.pkg_batchtype.setbatchflags(a_lictypejobid => t_licensetypejobids(i),
                                                             a_includein1strenewal => 'Y');

                    -- Set License Type IssueDate if it is not already set.
                    --If License is not seasonal or, in the case of a seasonal, the current month is part of the season, then set issuedate to current date.
                    IF (t_ltissuedate IS NULL
                    AND t_seasonalmonthsapply = 'N')
                    OR (t_ltissuedate IS NULL
                    AND t_seasonalmonthsapply = 'Y'
                    AND TRUNC(t_expirationdate) >= TRUNC(SYSDATE)
                    AND TRUNC(t_seasonstartdate) <= TRUNC(SYSDATE)) THEN
                        --Set the Issue Date on the Primary License Type Job
                        api.pkg_columnupdate.setvalue(t_licensetypejobids(i), 'IssueDate', TRUNC(t_readytoissuedate));
                    --If SeasonalMonthsApply = 'Y' and the Month is in the future, then set IssueDate to the first day of that month.
                    ELSIF t_ltissuedate IS NULL
                      AND t_seasonstartmonthnumber > TO_NUMBER(TO_CHAR(SYSDATE, 'mm')) THEN
                        api.pkg_columnupdate.setvalue(t_licensetypejobids(i),
                                                      'IssueDate',
                                                      (TO_DATE((   '01'
                                                                || LPAD(t_seasonstartmonthnumber, 2, 0)
                                                                || (TO_CHAR(SYSDATE, 'yyyy'))),
                                                               'ddmmyyyy')));
                    --If SeasonalMonthsApply = 'Y' and the Month is in the past, then set IssueDate to the first day of that month next year.
                    ELSIF t_ltissuedate IS NULL
                      AND TO_NUMBER(TO_CHAR(t_expirationdate, 'mm')) < TO_NUMBER(TO_CHAR(SYSDATE, 'mm')) THEN
                        api.pkg_columnupdate.setvalue(t_licensetypejobids(i),
                                                      'IssueDate',
                                                      (TO_DATE((   '01'
                                                                || LPAD(t_seasonstartmonthnumber, 2, 0)
                                                                || (TO_CHAR(SYSDATE + INTERVAL '1' YEAR, 'yyyy'))),
                                                               'ddfmmmyyyy')));
                    ELSIF t_ltissuedate IS NULL
                      AND t_seasonstartmonthnumber <= TO_NUMBER(TO_CHAR(SYSDATE, 'mm'))
                      AND TO_NUMBER(TO_CHAR(t_expirationdate, 'mm')) >= TO_NUMBER(TO_CHAR(SYSDATE, 'mm')) THEN
                        api.pkg_columnupdate.setvalue(t_licensetypejobids(i), 'IssueDate', t_readytoissuedate);
                    -- If the IssueDate is already filled, then do nothing.
                    ELSE
                        NULL;
                    END IF;
                --else
                --This is now done on the outcome of the Print License process.
                --api.pkg_columnupdate.setvalue(t_LicenseTypeJobIds(i), 'Print', 'N');
                END IF;  --Include in ProduceLicenseBatch

                -- Activate Secondary License Types.
                FOR secondary IN (SELECT DISTINCT (slt.relationshipid)
                                                      relationshipid,
                                                  slt.includeinproducelicensebatch,
                                                  slt.includeindailybatch,  -- added (called in loop dup_l and dup_batchdate_1) to fix renewals in daily-batch not earning Issue # 2528 -- Gurpreet
                                                  slt.status,
                                                  slt.licensetypecount,
                                                  ltc.licensetypecode,
                                                  ltc.color,
                                                  slt.issuedate
                                                      sltissuedate,
                                                  ltc.seasonalmonthsapply,
                                                  (SELECT MAX(d.readytoissuedate)
                                                     FROM sitespecific.duplicate_t t
                                                          JOIN query.o_duplicate d
                                                          ON d.objectid = t.duplicateid
                                                    WHERE t.relationshipid = slt.relationshipid)
                                                      readytoissuedate  --max(do.ReadyToIssueDate)Readytoissuedate
                                    FROM query.r_licensetypeltcatsecondary slt
                                         JOIN sitespecific.licbatchlictype_xref_t ltlb
                                         ON ltlb.licensetypejobid = slt.licensetypejobid
                                         JOIN query.o_licensetypecategory ltc
                                         ON ltc.objectid = slt.licensetypecategoryobjectid
                                   --join query.o_duplicate do on do.ObjectId = slt.RelationshipId
                                   WHERE slt.licensetypejobid = t_licensetypejobids(i)
                                     AND ltlb.tobeprocessedind = 'Y'  -- added MMR 10-9-14
                                     AND ltlb.processid = a_processid  -- added AWP (CXUSA) 5/13/2016 to speed up batch and conform to new "chunking" of batch.
                                                                     -- group by 1,2,3,4,5,6,7,8
                                                                     --                        and ltlb.LicenseTypeJobId = t_LicenseTypeJobIds(i)
                                                                     --HotFix22 Part One Removed because we need to determine what get set in the loop not
                                                                     --and ltc.Color = t_Color
                                                                     --and slt.status in ('PENDING')
                                                                     )
                LOOP
                    IF t_secondaryrecordsprocessed MOD 100 = 0 THEN
                        pkg_debug.putline(   '******* Processed '
                                          || t_secondaryrecordsprocessed
                                          || ' secondary records *******');
                    END IF;

                    t_secondaryrecordsprocessed   := t_secondaryrecordsprocessed + 1;

                    IF (secondary.includeinproducelicensebatch = 'Y'
                    AND secondary.color = t_color
                    AND ((TRUNC(secondary.readytoissuedate) BETWEEN (t_licenseissuedate - 14) AND t_licenseissuedate
                      AND t_dailyorrenewal = 'Daily')
                      OR (t_dailyorrenewal = 'Renewal'
                      AND TRUNC(secondary.readytoissuedate) <= t_licenseissuedate))) THEN
                        --Set Status to Active
                        IF secondary.status IN ('PENDING')
                       AND t_dailyorrenewal = 'Daily' THEN
                            api.pkg_columnupdate.setvalue(secondary.relationshipid, 'Status', 'ACTIVE');
                        END IF;

                        IF t_dailyorrenewal = 'Daily'
                        OR (t_dailyorrenewal = 'Renewal'
                        AND secondary.status IN ('ACTIVE',
                                                 'SURRENDERED',
                                                 'RULE 64B',
                                                 'SLMS HOLD',
                                                 'SUSPENDED')) THEN
                            sitespecific.pkg_batchtype.setbatchflags(a_lictypejobid => secondary.relationshipid,
                                                                     a_includein1strenewal => 'Y');

                            -- Earn Payment Transactions
                            sitespecific.pkg_fees.createltpaymentstatus(t_licensetypejobids(i), SYSDATE);

                            --HotFix22 Part One Point Five.
                            -- Set Secondary License Type IssueDate if it is not already set.
                            --If License is not seasonal or, in the case of a seasonal, the current month is part of the season, then set issuedate to current date.
                            IF (secondary.sltissuedate IS NULL
                            AND secondary.seasonalmonthsapply = 'N')
                            OR (secondary.sltissuedate IS NULL
                            AND secondary.seasonalmonthsapply = 'Y'
                            AND TRUNC(t_expirationdate) >= TRUNC(SYSDATE)
                            AND TRUNC(t_seasonstartdate) <= TRUNC(SYSDATE)) THEN
                                --Set the Issue Date on the Primary License Type Job
                                api.pkg_columnupdate.setvalue(secondary.relationshipid,
                                                              'IssueDate',
                                                              TRUNC(secondary.readytoissuedate));
                            --If SeasonalMonthsApply = 'Y' and the Month is in the future, then set IssueDate to the first day of that month.
                            ELSIF secondary.sltissuedate IS NULL
                              AND t_seasonstartmonthnumber > TO_NUMBER(TO_CHAR(SYSDATE, 'mm')) THEN
                                api.pkg_columnupdate.setvalue(secondary.relationshipid,
                                                              'IssueDate',
                                                              (TO_DATE((   '01'
                                                                        || LPAD(t_seasonstartmonthnumber, 2, 0)
                                                                        || (TO_CHAR(SYSDATE, 'yyyy'))),
                                                                       'ddmmyyyy')));
                            --If SeasonalMonthsApply = 'Y' and the Month is in the past, then set IssueDate to the first day of that month next year.
                            ELSIF secondary.sltissuedate IS NULL
                              AND TO_NUMBER(TO_CHAR(t_expirationdate, 'mm')) < TO_NUMBER(TO_CHAR(SYSDATE, 'mm')) THEN
                                api.pkg_columnupdate.setvalue(
                                    secondary.relationshipid,
                                    'IssueDate',
                                    (TO_DATE((   '01'
                                              || LPAD(t_seasonstartmonthnumber, 2, 0)
                                              || (TO_CHAR(SYSDATE + INTERVAL '1' YEAR, 'yyyy'))),
                                             'ddfmmmyyyy')));
                            -- If the IssueDate is already filled, then do nothing.
                            ELSE
                                NULL;
                            END IF;

                            --Print the dups that are new if in a daily batch or the dups in renewal
                            FOR dup_l IN (SELECT qdup.batchdate, qdup.objectid
                                            FROM sitespecific.duplicate_t dup
                                                 JOIN query.o_duplicate qdup
                                                 ON qdup.objectid = dup.duplicateid
                                           WHERE dup.relationshipid = secondary.relationshipid)
                            LOOP
                                IF (dup_l.batchdate IS NULL
                                AND t_dailyorrenewal = 'Daily')
                                -- or (api.pkg_columnquery.Value(secondary.relationshipid,'IncludeInDailyBatch') = 'Y') then -- commented out (code above was reseting batch flag prior to this query) to added to fix renewals in daily-batch not earning Issue # 2528 -- Gurpreet
                                OR (secondary.includeindailybatch = 'Y') THEN  -- added to fix renewals in daily-batch not earning Issue # 2528 -- Gurpreet
                                    api.pkg_columnupdate.setvalue(dup_l.objectid, 'Print', 'Y');
                                -- api.pkg_columnupdate.SetValue(dup_l.objectid, 'BatchDate', t_LicenseIssueDate); -- moved to next loop (dup_batchdate_1) to set batch date after earning of fees. Issue # 2528  -- gurpreet
                                ELSIF dup_l.batchdate IS NOT NULL
                                  AND t_dailyorrenewal = 'Renewal' THEN
                                    api.pkg_columnupdate.setvalue(dup_l.objectid, 'Print', 'Y');
                                    api.pkg_columnupdate.setvalue(dup_l.objectid, 'BatchDate', TRUNC(SYSDATE));
                                END IF;

                                --Set Ready to Issue Date
                                --api.pkg_columnupdate.SetValue(dup_l.objectid, 'IssueDate', api.pkg_columnquery.DateValue(secondary.relationshipid, 'IssueDate'));
                                api.pkg_columnupdate.setvalue(dup_l.objectid,
                                                              'ReadyToIssueDate',
                                                              secondary.readytoissuedate);
                            END LOOP;

                            -- Earn Payment Transactions
                            sitespecific.pkg_fees.createltpaymentstatus(t_licensetypejobids(i), SYSDATE);  -- added earn fees imediately after setting the print flag for Issue # 2528 -- Gurpreet

                            -- set batchdate after earning of dup fees,  Issue # 2528 --- Gurpreet
                            --Print the dups that are new if in a daily batch or the dups in renewal
                            FOR dup_batchdate_1 IN (SELECT qdup.batchdate, qdup.objectid
                                                      FROM sitespecific.duplicate_t dup
                                                           JOIN query.o_duplicate qdup
                                                           ON qdup.objectid = dup.duplicateid
                                                     WHERE dup.relationshipid = secondary.relationshipid)
                            LOOP
                                IF (dup_batchdate_1.batchdate IS NULL
                                AND t_dailyorrenewal = 'Daily')
                                -- or (api.pkg_columnquery.Value(secondary.relationshipid,'IncludeInDailyBatch') = 'Y') then -- commented out (code above was reseting batch flag prior to this query) to added to fix renewals in daily-batch not earning Issue # 2528 -- Gurpreet
                                OR (secondary.includeindailybatch = 'Y') THEN  -- added to fix renewals in daily-batch not earning Issue # 2528 -- Gurpreet
                                    api.pkg_columnupdate.setvalue(dup_batchdate_1.objectid,
                                                                  'BatchDate',
                                                                  t_licenseissuedate);
                                END IF;
                            END LOOP;
                        --else
                        --This is now done on the outcome of the Print License process.
                        --api.pkg_columnupdate.setvalue(secondary.relationshipid, 'Print', 'N');
                        END IF;
                    END IF;
                END LOOP;

                -- Set Expiration Date
                IF (t_includeinproducelicensebatch = 'Y'
                AND t_donotactivate = 'N'
                AND t_ltcatcolor = t_color
                AND ((TRUNC(t_readytoissuedate) BETWEEN (t_licenseissuedate - 14) AND t_licenseissuedate
                  AND t_dailyorrenewal = 'Daily')
                  OR (t_dailyorrenewal = 'Renewal'
                  AND TRUNC(t_readytoissuedate) <= t_licenseissuedate))) THEN
                    --HotFix22 Expiration Date Advancing Part Four.
                    -- Advance the ExpirationDate on the License Type by one year
                    --sitespecific.pkg_LicenseType.SetExpMonthYear(a_ProcessId, sysdate, t_LicenseTypeJobIds(i));
                    /*
                      Changed this if statement to differentiate between renewal and daily on 07/11/2014 by Pawan Ticket- 4184 */
                    /*if t_ltissuedate is not null
                    and api.pkg_columnquery.value(t_LicenseTypeJobIds(i), 'IncludeInChangeAppBatch') = 'N' then
                      api.pkg_ColumnUpdate.SetValue(t_LicenseTypeJobIds(i), 'ExpiringYear', (api.pkg_ColumnQuery.NumericValue(t_LicenseTypeJobIds(i), 'ExpiringYear')+1));
                    end if;  */


                    -- updated for ticket 4184 - Pawan--10/12/2014
                    IF t_ltissuedate IS NOT NULL
                   AND t_dailyorrenewal = 'Renewal' THEN
                        --and api.pkg_columnquery.value(t_LicenseTypeJobIds(i), 'IncludeInChangeAppBatch') = 'N' then
                        api.pkg_columnupdate.setvalue(
                            t_licensetypejobids(i),
                            'ExpiringYear',
                            (api.pkg_columnquery.numericvalue(t_licensetypejobids(i), 'ExpiringYear') + 1));
                    END IF;

                    -- updated for ticket 4184 --Pawan--10/12/2014
                    IF t_ltissuedate IS NOT NULL
                   AND t_dailyorrenewal = 'Daily'
                   AND api.pkg_columnquery.VALUE(t_licensetypejobids(i), 'IncludeInChangeAppBatch') = 'N' THEN
                        api.pkg_columnupdate.setvalue(
                            t_licensetypejobids(i),
                            'ExpiringYear',
                            (api.pkg_columnquery.numericvalue(t_licensetypejobids(i), 'ExpiringYear') + 1));
                    END IF;

                    --------

                    --Added to set null expiration date values to the correct date
                    IF api.pkg_columnquery.numericvalue(t_licensetypejobids(i), 'ExpiringYear') IS NULL THEN
                        sitespecific.pkg_licensetype.setexpmonthyearbatch(NULL, t_licensetypejobids(i), NULL);
                    END IF;
                END IF;
            ELSE
                -------------------------------------------------
                -- do the reinstatement work
                -- first the Primary License Type, if needed
                -- then any of its Secondary LTs, as needed
                -------------------------------------------------
                IF t_ltcatcolor = t_color
               AND t_includeinproducelicensebatch = 'Y'
               -- This status check may seem redundant, but it could be that only the secondary needs Reinstatement
               AND t_ltstatus IN ('REVPEN', 'AUTREV') THEN
                    -- find the effectivestartdate for the License Type reinstate candidate
                    SELECT MAX(jsc.effectivestartdate)
                      INTO t_effectivestartdate
                      FROM extension.jobstatuschange jsc
                     WHERE jsc.jobid = t_licensetypejobids(i)
                       AND jsc.statusname IN ('REVPEN', 'AUTREV');

                    BEGIN
                        -- find the rel status that was just before ('REVPEN', 'AUTREV')
                        -- if no previous record exists, ACTIVE will be used
                        -- here is the record with the status to which the lic type job will be set

                        SELECT MAX(jsc.effectiveenddate)
                          INTO t_effectiveenddate
                          FROM extension.jobstatuschange jsc
                         WHERE jsc.jobid = t_licensetypejobids(i)
                           AND jsc.statustype = 'O'  -- intermediate status
                           AND jsc.statusname NOT IN ('REVPEN', 'AUTREV')
                           AND jsc.effectiveenddate <= t_effectivestartdate;

                        SELECT MAX(jsc.jobstatuschangeid)
                          INTO t_jobstatuschangeid
                          FROM extension.jobstatuschange jsc
                         WHERE jsc.jobid = t_licensetypejobids(i)
                           AND jsc.statustype = 'O'  -- intermediate status
                           AND jsc.statusname NOT IN ('REVPEN', 'AUTREV')
                           AND jsc.effectiveenddate = t_effectiveenddate;

                        SELECT jsc.statusname
                          INTO t_setbackstat
                          FROM extension.jobstatuschange jsc
                         WHERE jsc.jobstatuschangeid = t_jobstatuschangeid;
                    EXCEPTION
                        WHEN NO_DATA_FOUND THEN
                            t_setbackstat   := 'ACTIVE';
                    END;

                    SELECT s.description
                      INTO t_setoutcome
                      FROM api.statuses s
                     WHERE s.tag = t_setbackstat;

                    -- set the status of the Primary License Type back to what it was prior to REV
                    -- Create a change status process
                    t_newprocid     :=
                        api.pkg_processupdate.new(t_licensetypejobids(i),
                                                  api.pkg_configquery.objectdefidforname('p_ChangeStatus'),  -- a_ProcessType
                                                  'Batch Reinstate License Type',  -- a_Description
                                                  TRUNC(SYSDATE),  -- a_ScheduledStartDate
                                                  TRUNC(SYSDATE),  -- a_ScheduledEndDate
                                                  TRUNC(SYSDATE));  -- a_ActualStartDate
                    -- Complete the change status proces.
                    api.pkg_processupdate.complete(t_newprocid, t_setoutcome);
                    --HofFix22 Part One - for Produce License we are setting the Print Boolean for the License Report.
                    --Set the Print Detail for Secondary License Types.
                    api.pkg_columnupdate.setvalue(t_licensetypejobids(i), 'Print', 'Y');
                    -- earn payment statuses
                    sitespecific.pkg_fees.createltpaymentstatus(t_licensetypejobids(i), SYSDATE);

                    --Set EffectiveDate(StatusDate) for the Status of this Primary License Type
                    api.pkg_columnupdate.setvalue(t_licensetypejobids(i), 'StatusDate', TRUNC(SYSDATE));

                    --HotFix22 Part One - Produce License we are setting the batch flags to first renewal.
                    --Set Batch Flags - First Renewal
                    sitespecific.pkg_batchtype.setbatchflags(a_lictypejobid => t_licensetypejobids(i),
                                                             a_includein1strenewal => 'Y');

                    -- Set the Type Of Issuance column to Reinstatement.
                    --api.pkg_columnupdate.SetValue(t_LicenseTypeJobIds(i), 'TypeOfIssuance', 'RENEWAL'); Removed 5/24/2010
                    t_fromstat      := NULL;
                    t_setbackstat   := NULL;
                    t_newprocid     := NULL;
                    t_setoutcome    := NULL;
                END IF;  -- Primary LT needs reinstating

                -------------------------------------------------
                -- reinstate secondary lt
                -- any secondary that needs to be reinstated
                -- with the reinstated parent primary LT job
                -- that is currently in the main c cursor
                -------------------------------------------------
                /* for secreinstate in (select distinct (slt.relationshipid) sltrelid,
                                             slt.Status,
                                             ltc.Color
                                      from query.r_LicenseTypeLTCatSecondary slt
                                      join query.o_licensetypecategory ltc on ltc.ObjectId = slt.LicenseTypeCategoryObjectId
                                      join sitespecific.LicBatchLicType_Xref_t ltlb on ltlb.LicenseTypeJobId = slt.LicenseTypeJobId
                                     where slt.LicenseTypeJobId = t_LicenseTypeJobIds(i)
                                      -- and ltlb.ToBeProcessedInd = 'Y'                -- added MMR 10-9-14
                                       and ltc.Color = t_Color  -- Note Color as a qualifier here for Secondary LT
                                       and slt.IncludeInProduceLicenseBatch = 'Y'
                                       and slt.Status in ('AUTO REVOKED', 'REV PENDING')) loop  */
                -- per Don Rei (Cx),12-04-14  use the source code below
                FOR secreinstate IN (SELECT DISTINCT (slt.relationshipid) sltrelid, slt.status, ltc.color
                                       FROM sitespecific.licbatchlictype_xref_t ltlb
                                            JOIN query.r_licensetypeltcatsecondary slt
                                            ON slt.licensetypejobid = ltlb.licensetypejobid
                                            JOIN query.o_licensetypecategory ltc
                                            ON ltc.objectid = slt.licensetypecategoryobjectid
                                      WHERE ltlb.licensetypejobid = t_licensetypejobids(i)
                                        AND ltlb.licensebatchjobid = a_jobid
                                        -- and ltlb.ToBeProcessedInd = 'Y'                -- added MMR 10-9-14
                                        AND ltc.color = t_color  -- Note Color as a qualifier here for Secondary LT
                                        AND slt.includeinproducelicensebatch = 'Y'
                                        AND slt.status IN ('AUTO REVOKED', 'REV PENDING')
                                        AND ltlb.processid = a_processid  -- added AWP (CXUSA) 5/13/2016 to speed up batch and conform to new "chunking" of batch.
                                                                        )
                LOOP
                    -- find the changeid for the Secondary License Type reinstate candidate
                    SELECT MAX(slts.sltstatuschangeid)
                      INTO t_fromstat
                      FROM sitespecific.sltstatuschange_t slts
                     WHERE slts.relationshipid = secreinstate.sltrelid
                       AND slts.statusname IN ('REVPEN', 'AUTREV');

                    BEGIN
                        -- find the rel status that was just before ('AUTO REVOKED', 'REV PENDING')
                        -- here is the record with the status to which the sec lic type will be set
                        SELECT slts.statusname
                          INTO t_setbackstat
                          FROM sitespecific.sltstatuschange_t slts
                         WHERE slts.sltstatuschangeid = (SELECT MAX(slts.sltstatuschangeid)
                                                           FROM sitespecific.sltstatuschange_t slts
                                                          WHERE slts.relationshipid = secreinstate.sltrelid
                                                            AND slts.sltstatuschangeid < t_fromstat
                                                            AND slts.statustype = 'O'  -- intermediate status
                                                            AND slts.statusname NOT IN ('REVPEN', 'AUTREV'));
                    EXCEPTION
                        WHEN NO_DATA_FOUND THEN
                            t_setbackstat   := 'ACTIVE';  -- default to active if there is no previous record
                    END;

                    SELECT UPPER(s.description)
                      INTO t_setstatus
                      FROM api.statuses s
                     WHERE s.tag = t_setbackstat;

                    -- set the status of the Secondary License Type back to what it was prior to REV
                    -- A reminder that status for Secondary is simply a stored detail on the relationship
                    api.pkg_columnupdate.setvalue(secreinstate.sltrelid, 'Status', t_setstatus);
                    --Set EffectiveDate(StatusDate) for the Status of this Secondary License Type
                    api.pkg_columnupdate.setvalue(secreinstate.sltrelid, 'StatusDate', TRUNC(SYSDATE));
                    --HotFix22 Part One
                    sitespecific.pkg_batchtype.setbatchflags(a_lictypejobid => secreinstate.sltrelid,
                                                             a_includein1strenewal => 'Y');

                    FOR dup_r IN (SELECT t.duplicateid
                                    FROM sitespecific.duplicate_t t
                                   WHERE t.relationshipid = secreinstate.sltrelid)
                    LOOP
                        api.pkg_columnupdate.setvalue(dup_r.duplicateid, 'Print', 'Y');
                    END LOOP;

                    -- Earn Payment Transactions
                    sitespecific.pkg_fees.createltpaymentstatus(t_licensetypejobids(i), SYSDATE);

                    t_fromstat      := NULL;
                    t_setbackstat   := NULL;
                    t_setstatus     := NULL;
                END LOOP;  -- secreinstate cursor

                -- set Expiration Date
                IF t_ltcatcolor = t_color
               AND t_includeinproducelicensebatch = 'Y'
               -- This status check may seem redundant, but it could be that only the secondary needs Reinstatement
               AND t_ltstatus IN ('REVPEN', 'AUTREV') THEN
                    --HotFix22 Expiration Date Advancing Part Four.
                    -- Advance the ExpirationDate on the License Type by one year
                    --sitespecific.pkg_LicenseType.SetExpMonthYear(a_ProcessId, sysdate, t_LicenseTypeJobIds(i));
                    IF t_ltissuedate IS NOT NULL
                   AND api.pkg_columnquery.VALUE(t_licensetypejobids(i), 'IncludeInChangeAppBatch') = 'N' THEN
                        api.pkg_columnupdate.setvalue(
                            t_licensetypejobids(i),
                            'ExpiringYear',
                            (api.pkg_columnquery.numericvalue(t_licensetypejobids(i), 'ExpiringYear') + 1));
                    --      api.pkg_errors.RaiseError(-20001, 'ProduceLicense: ' || t_LicenseTypeJobIds(i) );
                    END IF;

                    --Added to set null expiration date values to the correct date
                    IF api.pkg_columnquery.numericvalue(t_licensetypejobids(i), 'ExpiringYear') IS NULL THEN
                        sitespecific.pkg_licensetype.setexpmonthyearbatch(NULL, t_licensetypejobids(i), NULL);
                    END IF;
                END IF;

                --   Reinstate flag should be set to 'N' if all the License Types for this License Type Job
                --   (both primary and secondary) have been reinstated that need to be reinstated.
                IF api.pkg_columnquery.VALUE(t_licensetypejobids(i), 'includeinproducelicensebatch') = 'N'
               AND api.pkg_columnquery.VALUE(t_licensetypejobids(i), 'IncludeInProdLicBatReinstatSec') = 'N' THEN
                    api.pkg_columnupdate.setvalue(t_licensetypejobids(i), 'Reinstate', 'N');
                END IF;
            END IF;  -- t_Reinstate <> 'Y'


            /* Log current Process for each row in a temp table for the report batchprocessreport.pbl -- added MMR 10-9-14
               The Log serial number and print order will be updated in CreateSchedulerProcesses  */

            -- to avoid creating duplicate records, first check if the record already exists (from a prior failed run) and if not, create it
            -- try an update, and if it fails, do the insert in the exception clause
            BEGIN
                SELECT COUNT(*)
                  INTO l_exists
                  FROM sitespecific.batch_tracking_log
                 WHERE tobeprocessedind = '1'
                   AND licensebatchjobid = a_jobid
                   AND licensetypejobid = t_licensetypejobids(i);

                --
                IF l_exists > 0 THEN
                    EXECUTE IMMEDIATE
                           'update sitespecific.Batch_Tracking_Log '
                        || ' set LogComment = ''Part 1 restarting '','
                        || '     TOBEPROCESSEDIND = ''1''  ,'
                        || '     PROCESSEDDATE = sysdate '
                        || ' where LICENSEBATCHJOBID = '
                        || a_jobid
                        || '   and LICENSETYPEJOBID = '
                        || t_licensetypejobids(i);
                ELSE
                    EXECUTE IMMEDIATE
                           'insert into  sitespecific.Batch_Tracking_Log '
                        || ' (LICENSEBATCHJOBID,       '
                        || '   LICENSETYPEJOBID,       '
                        || '   PROCESSEDDATE,          '
                        || '   TOBEPROCESSEDIND,       '
                        || '   LOGCOMMENT)             '
                        || 'values ( '
                        || a_jobid
                        || ' ,'
                        || t_licensetypejobids(i)
                        || ' ,'
                        || ''''
                        || SYSDATE
                        || ''''
                        || ' ,'
                        || '''1'''
                        || ' ,'
                        || '''Part 1 initiated'')';
                END IF;
            END;

            -- add the current row to the processing collection which only contains the threshold limit
            -- when the threshold is met, it willo need to update the Processed_Collection
            -- which holds the records for the entire batch
            threshold_collection.EXTEND();
            threshold_collection(threshold_collection.COUNT())   := t_licensetypejobids(i);

            IF MOD(t_recordsprocessed, t_committhreshold) = 0 THEN
                BEGIN
                    pkg_debug.putline('Calling api.pkg_logicaltransactionupdate.EndTransaction()');
                    pkg_debug.putline(   '          Unit: '
                                      || $$plsql_unit);
                    pkg_debug.putline(   '   Line number: '
                                      || $$plsql_line);
                    --api.pkg_logicaltransactionupdate.EndTransaction();
                    pkg_debug.putline('Returned from EndTransaction()');

                    --commit;
                    --added by Andy of Cx to resolve an error.
                    --api.pkg_LogicalTransactionUpdate.ResetTransaction;
                    -- Merge two collections - MMR
                    FOR c IN 1 .. threshold_collection.COUNT
                    LOOP
                        -- api.pkg_errors.raiseerror(-20000,'In collection loop');   ---------------
                        processed_collection.EXTEND();
                        processed_collection(processed_collection.COUNT())   := threshold_collection(c);
                    END LOOP;

                    -- clear out the threshold
                    threshold_collection.delete;
                EXCEPTION
                    WHEN OTHERS THEN
                        t_errcount   := t_errcount + threshold_collection.COUNT;

                        -- log the error message in the log table
                        EXECUTE IMMEDIATE
                               'update sitespecific.Batch_Tracking_Log '
                            || ' set LogComment = '
                            || 'ProduceLicense Commit threshold error: '
                            || ' where LICENSETYPEJOBID = '
                            || t_licensetypejobids(i)
                            || ';';

                        threshold_collection.delete;
                --api.pkg_LogicalTransactionUpdate.ResetTransaction;
                -- pkg_debug.putline('Commit Threshold Err: '||sqlerrm);
                END;
            END IF;
        END LOOP;  -- main cursor

        -- Process remainder records
        BEGIN
            pkg_debug.putline('Calling api.pkg_logicaltransactionupdate.EndTransaction()');
            pkg_debug.putline(   '          Unit: '
                              || $$plsql_unit);
            pkg_debug.putline(   '   Line number: '
                              || $$plsql_line);
            --api.pkg_logicaltransactionupdate.EndTransaction();
            pkg_debug.putline('Returned from EndTransaction()');

            --commit;
            --added by Andy of Cx to resolve an error.
            --api.pkg_LogicalTransactionUpdate.ResetTransaction;
            -- Merge two collections - MMR
            FOR c IN 1 .. threshold_collection.COUNT
            LOOP
                -- api.pkg_errors.raiseerror(-20000,'In collection loop');   ---------------
                processed_collection.EXTEND();
                processed_collection(processed_collection.COUNT())   := threshold_collection(c);
            END LOOP;

            -- clear out the threshold
            threshold_collection.delete;
        EXCEPTION
            WHEN OTHERS THEN
                BEGIN
                    -- log the error message in the log table
                    EXECUTE IMMEDIATE
                           'update sitespecific.Batch_Tracking_Log '
                        || ' set LogComment = '
                        || ' Commit threshold error: '
                        || ' where LICENSETYPEJOBID = '
                        || l_curr_ltjobid_rec
                        || ';';

                    t_subject          :=
                           'BATCH: ProduceLicense Failed: JobID='
                        || api.pkg_columnquery.VALUE(a_jobid, 'ExternalFileNum');
                    t_body             :=
                           'Batch Job FAILED in Partial Threshold of '
                        || threshold_collection.COUNT
                        || ' from total number of Processed Records'
                        || processed_collection.COUNT;

                    --set flag that an error message email has been sent for this job, do not send a "success" email
                    g_erroremailsent   := 'Y';
                    --dbms_output.put_line('send error email for processid: '|| a_ProcessId);
                    emailerrororsuccess(t_toaddress,  --ToAddress
                                        t_subject,  --Subject
                                        t_body,  --Body
                                        NULL,  --[priority] --1 means high priority
                                        t_ccaddress,  --[ccaddress]
                                        a_processid);
                END;

                threshold_collection.delete;
        END;

        BEGIN
            createschedulerprocesses(a_processid, a_asofdate, a_jobid);
        END;

        --api.pkg_errors.raiseerror(-20000,'Entered process select loop '||Threshold_Collection.count || ' - ' ||Processed_Collection.count);
        FOR x IN 1 .. processed_collection.COUNT
        LOOP
            --UPDATE the processed records
            l_counter   := l_counter + 1;

            EXECUTE IMMEDIATE
                   'update sitespecific.LicBatchLicType_Xref_t x set ProcessedDate = sysdate, '
                || ' ToBeProcessedInd = ''C'''
                ||  -- added MMR 10-9-14.  C = Completed, this is the indicator to send the email
                   ' where x.LicenseBatchJobId = '
                || a_jobid
                || '   and x.ToBeProcessedInd = ''Y'''
                || '   and x.Licensetypejobid = '
                || processed_collection(x);

            EXECUTE IMMEDIATE
                   'update sitespecific.Batch_Tracking_Log set ProcessedDate = sysdate, '
                || ' LogComment = ''Part 1 completed'', '
                || ' ToBeProcessedInd = ''2'''
                ||  --updating the log to step #2
                   ' where LicenseBatchJobId = '
                || a_jobid
                || '   and ToBeProcessedInd = ''1'''
                || '   and Licensetypejobid = '
                || processed_collection(x);
        --api.pkg_errors.raiseerror(-20000, 'In the Process Selection loop '||Threshold_Collection.count || ' - ' ||Processed_Collection.count); ---------------------
        END LOOP;

        -- pkg_debug.putline('******* End pkg_BatchType.ProduceLicenses *******');
        --api.pkg_errors.raiseerror(-20000,' counter done: '||l_counter||' Process License Completed');

        --success email logic is being set in the RelatePendingLTstoBatch procedure
        /*-- Send Successful Completion email
        If t_ErrCount = 0 then
          t_Subject := 'BATCH: Produce License Job '||a_JobID||' Part 1 - Succeeded';
          t_Body := 'Job successfully completed.';
        else
          t_Subject := 'BATCH: Produce License Job '||a_JobID||' Part 1  Succeeded with '||t_ErrCount||' Errors';
          t_Body := 'Job successfully completed with Errors.';
        end if;

        EmailErrorOrSuccess(t_ToAddress,--ToAddress
                             t_Subject,--Subject
                             t_Body,--Body
                             null,--[priority] --1 means high priority
                             t_CCAddress,--[ccaddress]
                             a_ProcessId);*/
        -- 11/3/14  MMR
        -- if there are no errors, then clear the indicator from "C"
        -- so that the index works more efficiently
        BEGIN
            SELECT (  (SELECT COUNT(*)
                         FROM sitespecific.batch_tracking_log l
                        WHERE licensebatchjobid = l_curr_ltjobid_rec)
                    - (SELECT COUNT(*)
                         FROM sitespecific.batch_tracking_log l
                        WHERE licensebatchjobid = l_curr_ltjobid_rec
                          AND l.tobeprocessedind = 'Y'))
                       unprocessed_recs
              INTO l_final_count
              FROM DUAL;

            IF l_final_count = 0 THEN
                -- all the processed records completed smoothly
                EXECUTE IMMEDIATE
                       'update sitespecific.LicBatchLicType_Xref_t x set ProcessedDate = sysdate, '
                    || ' ToBeProcessedInd = null '
                    ||  -- clear out when finished
                       ' where x.LicenseBatchJobId = '
                    || a_jobid
                    || '   and ToBeProcessedInd = ''C''';

                EXECUTE IMMEDIATE
                       'update  sitespecific.Batch_Tracking_Log  '
                    || ' set ToBeProcessedInd = null, '
                    ||  -- clear out when finished
                       '     LogComment = ''Process Completed successfully''    '
                    || ' where LicenseBatchJobId = '
                    || a_jobid
                    || '   and ToBeProcessedInd = ''2''';
            ELSE
                -- an error occurred someplace,which should raise an error, so do nothing here
                NULL;
            END IF;
        END;
    EXCEPTION
        WHEN OTHERS THEN
            BEGIN
                t_subject          :=
                       'BATCH: ProduceLicense Failed: JobID='
                    || api.pkg_columnquery.VALUE(a_jobid, 'ExternalFileNum');
                t_body             :=
                       'Batch Job FAILED: '
                    || SQLERRM;

                --set flag that an error message email has been sent for this job, do not send a "success" email
                g_erroremailsent   := 'Y';

                emailerrororsuccess(t_toaddress,  --ToAddress
                                    t_subject,  --Subject
                                    t_body,  --Body
                                    NULL,  --[priority] --1 means high priority
                                    t_ccaddress,  --[ccaddress]
                                    a_processid);
            END;

            RAISE;
    END producelicenses;


    /* ******************************************************************************************************
     * Activate Licenses.
     * This process is designed to be called for a manually related Activate License process (to a License).
     * This procedure automatically relates and completes an Activate License Type process as outlined by
     * the truth table below.
     *
     * TYPE*   License         License  DoNotActivate    Include  Activat Activat    Set           Set
     *         Status          Type      Flag            In       License License   DoNotActivate  IncludeInProduceLicenseBatch
     *                         Status    Value           Batch             Type       To:          To:
     * -------------------------------------------------------------------------------------------------------
     * M        P                P        F                N/A      Y        Y        N/C           N/C
     * M        P                P        T                N/A      Y        Y        F             N/C
     * M        P                A        F                N/A      Y        N        N/C           N/C
     * M        P                A        T                N/A      Y        N        F             N/C
     * M        P                RP       F                N/A      Y        N        N/C           N/C
     * M        P                RP       T                N/A      Y        N        N/C           N/C
     * M        P                S        F                N/A      Y        N        N/C           N/C
     * M        P                S        T                N/A      Y        N        N/C           N/C
     * --------------------------------------------------------------------------------------------------------
     * M        A                P        F                N/A      Y        Y        N/C           N/C
     * M        A                P        T                N/A      Y        Y        F             N/C
     * M        A                A        F                N/A      Y        N        N/C           N/C
     * M        A                A        T                N/A      Y        N        F             N/C
     * M        A                RP       F                N/A      Y        N        N/C           N/C
     * M        A                RP       T                N/A      Y        N        N/C           N/C
     * M        A                S        F                N/A      Y        N        N/C           N/C
     * M        A                S        T                N/A      Y        N        N/C           N/C
     * --------------------------------------------------------------------------------------------------------
     * M        SUS              *        *                N/A      Y        N        N/C           N/C
     * -------------------------------------------------------------------------------------------------------
     * M        H/SLMS-H         P        F                N/A      Y        Y        N/C           N/C
     * M        H/SLMS-H         P        T                N/A      Y        Y        F             N/C
     * M        H/SLMS-H         A        F                N/A      Y        N        N/C           N/C
     * M        H/SLMS-H         A        T                N/A      Y        N        F             N/C
     * M        H/SLMS-H         RP       F                N/A      Y        N        N/C           N/C
     * M        H/SLMS-H         RP       T                N/A      Y        N        N/C           N/C
     * M        H/SLMS-H         S        F                N/A      Y        N        N/C           N/C
     * M        H/SLMS-H         S        T                N/A      Y        N        N/C           N/C
     *
     *
     * * M = Manual, B=Batch
     ********************************************************************************************************/
    PROCEDURE activatelicense(
      a_processid udt_id, 
      a_asofdate DATE, 
      a_jobid udt_id
    )
    IS
      t_actlictyp     INTEGER := 0;
      t_setdonotact   INTEGER := 0;
    BEGIN
      FOR c IN (
        SELECT 
          l.statusname   l_statusname,
          rllt.licensetypejobid,
          jlt.statusname lt_statusname,
          jlt.donotactivate
        FROM query.r_licenselicensetype rllt
        JOIN query.j_licensetype jlt ON 
          jlt.jobid = rllt.licensetypejobid,
          query.j_license l
        WHERE rllt.licensejobid = a_jobid
          AND l.jobid = a_jobid)
        LOOP
          CASE
          WHEN (
            c.l_statusname IN (
              'PEND',
              'ACTIVE',
              'R64B',
              'SLMSHD'
            )
            AND c.lt_statusname = 'PEND'
            AND c.donotactivate = 'N'
          ) 
          THEN
            t_actlictyp     := 1;
            t_setdonotact   := 0;
          WHEN (
            c.l_statusname IN (
              'PEND',
              'ACTIVE',
              'R64B',
              'SLMSHD'
            )
            AND c.lt_statusname = 'PEND'
            AND c.donotactivate = 'Y') 
          THEN
            t_actlictyp     := 1;
            t_setdonotact   := 1;
          WHEN (
            c.l_statusname IN (
              'PEND',
              'ACTIVE',
              'R64B',
              'SLMSHD'
            )
            AND c.lt_statusname = 'ACTIVE'
            AND c.donotactivate = 'Y'
          ) 
          THEN
            t_actlictyp     := 0;
            t_setdonotact   := 1;
          ELSE
            t_actlictyp     := 0;
            t_setdonotact   := 0;
          END CASE;

          IF (t_actlictyp = 1) THEN
            -- Activate license type
            t_newprocid := api.pkg_processupdate.new(
              c.licensetypejobid,
              api.pkg_configquery.objectdefidforname('p_ActivateLicenseType'),
              'Activate License Type',
              TRUNC(SYSDATE),
              TRUNC(SYSDATE),
              TRUNC(SYSDATE)
            );
            -- Complete the Activate License proces.
            api.pkg_processupdate.complete(t_newprocid, 'Activate');
          END IF;

          -- Reset the DoNotActivate flags to 'N'
          IF (t_setdonotact = 1) THEN
            api.pkg_columnupdate.setvalue(c.licensetypejobid, 'DoNotActivate', 'N');
          END IF;
        END LOOP;
    END activatelicense;

    /*-------------------------------------------------
     -- ActivateSecondaryLicenseTypes()
     -- Upon completion of the Activate License Type process
     -- this will activate all secondary license types.
     -----------------------------------------------------*/

    PROCEDURE activatesecondarylicensetypes(
      a_processid udt_id, 
      a_asofdate DATE, 
      a_jobid udt_id
    )
    IS
    BEGIN
      IF api.pkg_columnquery.VALUE(a_processid, 'BatchActivate') = 'Y' THEN
        NULL;
      ELSE
        FOR c IN (
          SELECT slt.relationshipid, slt.status, slt.licensetypecount
          FROM query.r_licensetypeltcatsecondary slt
          WHERE slt.licensetypejobid = a_jobid
          AND slt.status NOT IN ('ACTIVE', 'SURRENDERED')
        )
        LOOP
          --Set Status to Active
          api.pkg_columnupdate.setvalue(c.relationshipid, 'Status', 'ACTIVE');
        END LOOP;
      END IF;
    END activatesecondarylicensetypes;

    /* *********************************************************************************************
     * Set Batch Flags On Batch Jobs.
     * This process automatically sets the batch flags appropriately on the following batch jobs,
     * "IncludeIn1stRenewal", "IncludeIn2ndRenewal", "IncludeInFinalRevPending".
     ************************************************************************************************/
    PROCEDURE setbatchflagsonbatchjobs(a_processid     udt_id,
                                       a_asofdate      DATE,
                                       a_jobid         udt_id,
                                       a_batchtype     VARCHAR)
    IS
        t_subject                        VARCHAR2(4000);
        t_body                           VARCHAR2(4000);
        t_toaddress                      VARCHAR2(4000) := api.pkg_constantquery.VALUE('LICENSINGNOTIFICATIONEMAIL');
        t_ccaddress                      VARCHAR2(4000) := api.pkg_constantquery.VALUE('APPLICATIONSUPPORTEMAIL');
        t_inclin1strenewal               CHAR DEFAULT 'N';
        t_inclin2ndrenewal               CHAR DEFAULT 'N';
        t_inclinfinalrevpending          CHAR DEFAULT 'N';
        t_inclinrevokebatch              CHAR DEFAULT 'N';
        t_includeinproducelicensebatch   CHAR DEFAULT 'N';
        t_includeindailybatch            CHAR DEFAULT 'N';
        t_isgreendone                    CHAR DEFAULT 'N';
        t_ispinkdone                     CHAR DEFAULT 'N';
        t_color                          VARCHAR2(10) := api.pkg_columnquery.VALUE(a_jobid, 'Color');
        t_recordsprocessed               NUMBER := 0;
        t_licensetypejobids              udt_idlist;
        t_hasboth                        VARCHAR2(1);
        t_isltgreendone                  VARCHAR2(1);
        t_isltpinkdone                   VARCHAR2(1);
    BEGIN
        pkg_debug.putline(   '******* Begin pkg_BatchType.SetBatchFlagsOnBatchJobs at '
                          || TO_CHAR(SYSTIMESTAMP, 'HH24:MI:SS.FF')
                          || '  *******');

        BEGIN
            IF api.pkg_columnquery.VALUE(a_processid, 'ForceFailure') = 'Y' THEN
                api.pkg_errors.raiseerror(-20000, 'Failure forced by process checkbox.');
            END IF;
        END;

        CASE a_batchtype
            /* when 'IncludeInProduceLicenseBatch' then if t_Color = 'Green'
                                         then t_IsGreenDone := 'Y';
                                         else t_IsPinkDone := 'Y'; end if;*/
            WHEN 'IncludeIn1stRenewal' THEN
                t_inclin2ndrenewal   := 'Y';
            WHEN 'IncludeIn2ndRenewal' THEN
                t_inclinfinalrevpending   := 'Y';
            WHEN 'IncludeInFinalRevPending' THEN
                t_inclinrevokebatch   := 'Y';
            ELSE
                NULL;
        END CASE;

          -- RyanL: Changed to bulk collect for performance (PIP Task 8.7)
          SELECT rllt.licensetypejobid
            BULK COLLECT INTO t_licensetypejobids
            FROM sitespecific.licbatchlictype_xref_t rltlb
                 JOIN query.r_licenselicensetype rllt
                 ON rllt.licensetypejobid = rltlb.licensetypejobid
           WHERE rltlb.licensebatchjobid = a_jobid
             AND rltlb.processid = a_processid
             AND rltlb.tobeprocessedind = 'Y'  -- added MMR 10-9-14
        ORDER BY rllt.licensejobid, rllt.licensetypejobid;

        FOR i IN 1 .. t_licensetypejobids.COUNT
        LOOP
            t_hasboth            := api.pkg_columnquery.VALUE(t_licensetypejobids(i), 'HasBothLicenseColors');
            t_isltgreendone      := api.pkg_columnquery.VALUE(t_licensetypejobids(i), 'IsGreenDone');
            t_isltpinkdone       := api.pkg_columnquery.VALUE(t_licensetypejobids(i), 'IsPinkDone');

            IF t_recordsprocessed MOD 100 = 0 THEN
                DBMS_OUTPUT.put_line(   '******* Processed '
                                     || t_recordsprocessed
                                     || ' records at '
                                     || TO_CHAR(SYSTIMESTAMP, 'HH24:MI:SS.FF')
                                     || '  *******');
            END IF;

            t_recordsprocessed   := t_recordsprocessed + 1;

            -- When Batch Type = Produce Licenses and Has Both License Colors related then
            -- Check to see if the Opposite type is not flagged if so then t_IncludeInProduceLicenses := Y
            IF a_batchtype = 'IncludeInProduceLicenseBatch'
           AND t_hasboth = 'Y'
           AND t_isltgreendone = 'N'
           AND t_isltpinkdone = 'N' THEN
                t_includeinproducelicensebatch   := 'Y';
                t_includeindailybatch            :=
                    api.pkg_columnquery.VALUE(t_licensetypejobids(i), 'IncludeInDailyBatch');
                t_inclin1strenewal               := 'N';

                IF t_color = 'Green' THEN
                    t_isgreendone   := 'Y';
                    t_ispinkdone    := 'N';
                ELSIF t_color = 'Pink' THEN
                    t_isgreendone   := 'N';
                    t_ispinkdone    := 'Y';
                END IF;
            ELSIF a_batchtype = 'IncludeInProduceLicenseBatch'
              AND t_hasboth = 'Y'
              AND (t_isltgreendone = 'Y'
                OR t_isltpinkdone = 'Y')
              AND (t_isltgreendone = 'N'
                OR t_isltpinkdone = 'N') THEN
                t_ispinkdone                     := 'Y';
                t_isgreendone                    := 'Y';
                t_inclin1strenewal               := 'Y';
                t_includeinproducelicensebatch   := 'N';
                t_includeindailybatch            := 'N';
            ELSIF a_batchtype = 'IncludeInProduceLicenseBatch'
              AND t_hasboth = 'N' THEN
                t_inclin1strenewal               := 'Y';
                t_includeinproducelicensebatch   := 'N';
                t_includeindailybatch            := 'N';

                IF t_color = 'Green' THEN
                    t_isgreendone   := 'Y';
                    t_ispinkdone    := 'N';
                ELSIF t_color = 'Pink' THEN
                    t_isgreendone   := 'N';
                    t_ispinkdone    := 'Y';
                END IF;
            END IF;

            -- Reset the batch flags
            pkg_batchtype.setbatchflags(t_licensetypejobids(i),
                                        a_includeinproducelicensebatch => t_includeinproducelicensebatch,
                                        a_includeindailybatch => t_includeindailybatch,
                                        a_includein1strenewal => t_inclin1strenewal,
                                        a_includein2ndrenewal => t_inclin2ndrenewal,
                                        a_includeinfinalrevpending => t_inclinfinalrevpending,
                                        a_includeinrevokebatch => t_inclinrevokebatch,
                                        a_isgreendone => t_isgreendone,
                                        a_ispinkdone => t_ispinkdone);

            FOR c_2 IN (SELECT slt.relationshipid,
                               slt.includein1strenewal,
                               slt.includein2ndrenewal,
                               slt.includeindailybatch,
                               slt.includeinfinalrevpending,
                               slt.includeinproducelicensebatch,
                               slt.includeinrevokebatch
                          FROM query.r_licensetypeltcatsecondary slt
                         WHERE slt.licensetypejobid = t_licensetypejobids(i)
                           AND ((slt.includein1strenewal = 'Y'
                             AND a_batchtype = 'IncludeIn1stRenewal')
                             OR (slt.includein2ndrenewal = 'Y'
                             AND a_batchtype = 'IncludeIn2ndRenewal')
                             OR (slt.includeinfinalrevpending = 'Y'
                             AND a_batchtype = 'IncludeInFinalRevPending'))
                           AND slt.status IN ('ACTIVE',
                                              'SURRENDERED',
                                              'RULE 64B',
                                              'SLMS HOLD',
                                              'SUSPENDED'))
            LOOP
                -- Reset the Secondary batch flags
                pkg_batchtype.setbatchflags(c_2.relationshipid,
                                            a_includeinproducelicensebatch => t_includeinproducelicensebatch,
                                            a_includeindailybatch => t_includeindailybatch,
                                            a_includein1strenewal => t_inclin1strenewal,
                                            a_includein2ndrenewal => t_inclin2ndrenewal,
                                            a_includeinfinalrevpending => t_inclinfinalrevpending,
                                            a_includeinrevokebatch => t_inclinrevokebatch,
                                            a_isgreendone => t_isgreendone,
                                            a_ispinkdone => t_ispinkdone);
            END LOOP;
        END LOOP;

        pkg_debug.putline(   '******* End pkg_BatchType.SetBatchFlagsOnBatchJobs at '
                          || TO_CHAR(SYSTIMESTAMP, 'HH24:MI:SS.FF')
                          || '  *******');
    EXCEPTION
        WHEN OTHERS THEN
            BEGIN
                t_subject          :=
                       'BATCH: Set Batch Flags on Batch Jobs Failed: JobID='
                    || api.pkg_columnquery.VALUE(a_jobid, 'ExternalFileNum');
                t_body             :=
                       'Batch Job FAILED: '
                    || SQLERRM;

                --set flag that an error message email has been sent for this job, do not send a "success" email
                g_erroremailsent   := 'Y';
                emailerrororsuccess(t_toaddress,  --ToAddress
                                    t_subject,  --Subject
                                    t_body,  --Body
                                    NULL,  --[priority] --1 means high priority
                                    t_ccaddress,  --[ccaddress]
                                    a_processid);
            END;

            RAISE;
    END setbatchflagsonbatchjobs;

    /* ***************************************************************************************************************
     * Set Batch Flags.
     * This process provides a shortcut to manually setting the batch flags, "IncludeInProduceLicenseBatch", "IncludeIn1stRenewal",
     * "IncludeIn2ndrenewal", "IncludeInFinalRevPending", and "IncludeInRevokeBatch". This process will default the
     * values to 'N' (in the above apecified order), only the 'Y' values need be specified using either positional or
     * named notation, only the License Type Jobid is required.
     *****************************************************************************************************************/
    PROCEDURE setbatchflags(
      a_lictypejobid  udt_id,
      a_includeinproducelicensebatch CHAR DEFAULT 'N',
      a_includeindailybatch CHAR DEFAULT 'N',
      a_includein1strenewal CHAR DEFAULT 'N',
      a_includein2ndrenewal CHAR DEFAULT 'N',
      a_includeinfinalrevpending CHAR DEFAULT 'N',
      a_includeinrevokebatch CHAR DEFAULT 'N',
      a_isgreendone   CHAR DEFAULT 'N',
      a_ispinkdone    CHAR DEFAULT 'N'
    )
    IS
    BEGIN
      api.pkg_columnupdate.setvalue(a_lictypejobid, 'IncludeInProduceLicenseBatch', a_includeinproducelicensebatch);
      api.pkg_columnupdate.setvalue(a_lictypejobid, 'IncludeInDailyBatch', a_includeindailybatch);
      api.pkg_columnupdate.setvalue(a_lictypejobid, 'IncludeIn1stRenewal', a_includein1strenewal);
      api.pkg_columnupdate.setvalue(a_lictypejobid, 'IncludeIn2ndRenewal', a_includein2ndrenewal);
      api.pkg_columnupdate.setvalue(a_lictypejobid, 'IncludeInFinalRevPending', a_includeinfinalrevpending);
      api.pkg_columnupdate.setvalue(a_lictypejobid, 'IncludeInRevokeBatch', a_includeinrevokebatch);

      IF api.pkg_columnquery.VALUE(a_lictypejobid, 'ObjectDefName') = 'j_LicenseType' THEN
        api.pkg_columnupdate.setvalue(a_lictypejobid, 'IsGreenDone', a_isgreendone);
        api.pkg_columnupdate.setvalue(a_lictypejobid, 'IsPinkDone', a_ispinkdone);
      END IF;
    END setbatchflags;

    /* ***************************************************************************************************************
     * Set Batch Flags Wrapper.
     * This Procedure provides a the functionality to call the SetBatchFlags procedure from Posse, without forcing other
     * functions to pass in a non-used Object Id and Date. Again just as with SetBatchFlags this process will default the
     * values to 'N' (in the above apecified order), only the 'Y' values need be specified using either positional or
     * named notation, only the ObjectID, AsOfDate, and License Type Jobid is required.
     *****************************************************************************************************************/

    PROCEDURE setbatchflagswrap(
      a_objectid      udt_id,
      a_asofdate      DATE,
      a_lictypejobid  udt_id,
      a_includeinproducelicensebatch CHAR DEFAULT 'N',
      a_includeindailybatch CHAR DEFAULT 'N',
      a_includein1strenewal CHAR DEFAULT 'N',
      a_includein2ndrenewal CHAR DEFAULT 'N',
      a_includeinfinalrevpending CHAR DEFAULT 'N',
      a_includeinrevokebatch CHAR DEFAULT 'N',
      a_isgreendone   CHAR DEFAULT 'N',
      a_ispinkdone    CHAR DEFAULT 'N'
    )
    IS
    BEGIN
      setbatchflags(
        a_lictypejobid,
        a_includeinproducelicensebatch,
        a_includeindailybatch,
        a_includein1strenewal,
        a_includein2ndrenewal,
        a_includeinfinalrevpending,
        a_includeinrevokebatch,
        a_isgreendone,
        a_ispinkdone
      );
    END setbatchflagswrap;

    PROCEDURE setserialnum(a_objectid udt_id)
    IS
      t_sequenceid    udt_id;
      t_serialnum     VARCHAR2(20);
      t_sequencenum   NUMBER;
    BEGIN
      SELECT serial_number.NEXTVAL INTO t_sequencenum FROM DUAL;

      api.pkg_columnupdate.setvalue(a_objectid, 'SerialNumber', t_sequencenum);
    END setserialnum;

    ----------------------------------------------------------------------------------------------------
    --  GetBatchPenaltyCandidates()     --Public
    --  This will relate License Type Candidates to the License Batch Job.
    --  09/09/2020 TJL   WO 8924   Replaced getbatchpenaltycandidates procedure with this procedure
    ----------------------------------------------------------------------------------------------------
    PROCEDURE getbatchpenaltycandidates(a_jobid         udt_id,
                                        a_asofdate      DATE,
                                        a_expirationdate DATE,
                                        a_ren50orren100 VARCHAR2)
    IS
        t_prioractivity   VARCHAR2(10);
    BEGIN
        IF a_ren50orren100 = 'REN50' THEN
            t_prioractivity   := 'REN';
        ELSIF a_ren50orren100 = 'REN100' THEN
            t_prioractivity   := 'REN50';
        END IF;

        FOR lic
            IN (WITH
                    obj
                    AS
                        (SELECT  /*+ materialize */
                                o.objectid
                                    jobid,
                                api.pkg_columnquery.VALUE(o.objectid, 'IncludeIn2ndRenewal')
                                    includein2ndrenewal,
                                api.pkg_columnquery.VALUE(o.objectid, 'IncludeInFinalRevPending')
                                    includeinfinalrevpending
                           FROM (SELECT objectid
                                   FROM TABLE(
                                            CAST(
                                                api.pkg_simplesearch.castableobjectsbyindex(
                                                    'j_LicenseType',
                                                    'dup_ExpirationDate',
                                                    TO_CHAR(a_expirationdate, 'YYYY-MM-DD')) AS api.udt_objectlist))
                                        o
                                 UNION
                                 SELECT objectid
                                   FROM TABLE(
                                            api.pkg_simplesearch.castableobjectsbyindex(
                                                'j_LicenseType',
                                                'dup_SeasonStartMonthNumber',
                                                TO_NUMBER(TO_CHAR(ADD_MONTHS(a_expirationdate, 1), 'mm')))) o) o
                          WHERE EXISTS
                                    (SELECT 1
                                       FROM api.jobstatuses js
                                            JOIN api.statuses s
                                            ON s.statusid = js.statusid
                                      WHERE js.jobtypeid = api.pkg_configquery.objectdefidforname('j_LicenseType')
                                        AND s.description IN ('Active',
                                                              'Surrendered',
                                                              'Rule 64B',
                                                              'SLMS Hold',
                                                              'Suspended',
                                                              'SLMS')
                                        AND s.description =
                                            api.pkg_columnquery.VALUE(o.objectid, 'StatusDescription')))
                SELECT o.jobid
                  FROM obj o
                 WHERE ((o.includein2ndrenewal = 'Y'
                     AND a_ren50orren100 = 'REN50')
                     OR (o.includeinfinalrevpending = 'Y'
                     AND a_ren50orren100 = 'REN100')))
        LOOP
            FOR info
                IN (SELECT DISTINCT jobid
                      FROM (  SELECT *
                                FROM (  SELECT SUBSTR(api.pkg_columnquery.VALUE(reo.objectid, 'Description'), 1, 2)
                                                   licensetypecode,
                                               REGEXP_SUBSTR(api.pkg_columnquery.VALUE(ffs.toobjectid, 'Description'),
                                                             '[^ ]+',
                                                             1,
                                                             1)
                                                   feescheduledescription,
                                               REGEXP_SUBSTR(f.description,
                                                             '[^ ]+',
                                                             1,
                                                             3)
                                                   feeactivity,
                                               f.feeid,
                                               f.jobid,
                                               f.transactiondate,
                                               f.amount + f.adjustedamount + f.paidamount
                                                   totalowing,
                                               RANK()
                                               OVER(
                                                   PARTITION BY f.jobid,
                                                                SUBSTR(
                                                                    api.pkg_columnquery.VALUE(reo.objectid,
                                                                                              'Description'),
                                                                    1,
                                                                    2),
                                                                REGEXP_SUBSTR(f.description,
                                                                              '[^ ]+',
                                                                              1,
                                                                              3)
                                                   ORDER BY f.transactiondate DESC)
                                                   AS r,
                                               f.description
                                          FROM api.fees f
                                               JOIN finance.transactions_t t
                                               ON t.transactionid = f.feeid
                                               JOIN api.registeredexternalobjects reo  -- RyanL: PIP Task 8.5
                                               ON reo.linkvalue = TO_CHAR(f.feeid)
                                              AND reo.objectdefid = api.pkg_configquery.objectdefidforname('o_Fee')
                                               JOIN api.relationships ffs
                                               ON ffs.fromobjectid = reo.objectid
                                              AND ffs.endpointid =
                                                  api.pkg_configquery.endpointidforname('o_Fee', 'LicenseFeeSchedule')
                                         WHERE f.jobid = lic.jobid
                                           AND TRUNC(t.transactiondate) BETWEEN ADD_MONTHS(a_expirationdate, -12)
                                                                            AND a_expirationdate
                                      ORDER BY f.transactiondate DESC) f2
                               WHERE f2.r = 1
                                 AND f2.feeactivity LIKE 'REN%'
                                 AND f2.feescheduledescription = t_prioractivity
                                 AND f2.totalowing > 0
                            ORDER BY f2.jobid))
            LOOP
                INSERT INTO licbatchlictype_xref_t(licensebatchjobid,
                                                   licensetypejobid,
                                                   serialnumber,
                                                   printorder,
                                                   processeddate,
                                                   tobeprocessedind)
                     VALUES (a_jobid,
                             info.jobid,
                             serial_number.NEXTVAL,
                             NULL,
                             NULL,
                             'Y');
            END LOOP;
        END LOOP;
    END getbatchpenaltycandidates;


    -- 09/09/2020 TJL   WO 8924  Old process left in for reference if needed    
    PROCEDURE getbatchpenaltycandidatesold(a_jobid         udt_id,
                                           a_asofdate      DATE,
                                           a_expirationdate DATE,
                                           a_ren50orren100 VARCHAR2)
    IS
        t_feeactivity              VARCHAR2(60);
        t_endpointid               udt_id;
        t_newrelid                 udt_id;

        t_prioractivity            VARCHAR2(60);
        t_priorprioractivity       VARCHAR2(10);
        t_checkexists              VARCHAR2(15);
        t_createfee                VARCHAR2(1);
        t_createsfee               VARCHAR2(1);
        t_feecount                 NUMBER;
        t_lictypeinlicbatchcount   NUMBER;
        t_expiringyear             NUMBER;
        t_primaryorsecondary       VARCHAR2(100);
        t_feeobjectdefid           udt_id := api.pkg_configquery.objectdefidforname('o_Fee');
        t_licensedefid             udt_id := api.pkg_configquery.objectdefidforname('j_LicenseType');
    --t_Count number := 0;
    --t_TotalExpectedCount      number(9) :=1;
    BEGIN
        --when it is a Ren 50% penalty type
        IF a_ren50orren100 = 'REN50' THEN
            -- t_FeeActivity := 'REN50';
            t_prioractivity        := 'REN';
            t_priorprioractivity   := NULL;
            t_checkexists          := 'REN50.REN100.';
        -- else when it is a Ren 100% penalty type
        ELSIF a_ren50orren100 = 'REN100' THEN
            --  t_FeeActivity := 'REN100';
            t_prioractivity        := 'REN50';
            t_priorprioractivity   := 'REN';
            t_checkexists          := 'REN100.';
        END IF;

        --
        BEGIN
            -- Set t_CreateFee initial value to 'Y'
            t_createfee    := 'Y';

            -- Set t_CreateSFee initial value to 'Y'
            t_createsfee   := 'Y';

            FOR x
                IN (SELECT x.objectid                                                              ltobjectid,
                           fs.licensetypecode,
                           api.pkg_columnquery.VALUE(x.objectid, 'LicenseTypeCode')                primaryltcode,
                           api.pkg_columnquery.VALUE(x.objectid, 'SecondaryLTCategoryObjectId')    sltobjectid,
                           api.pkg_columnquery.VALUE(x.objectid, 'MasterLicenseTypeDisplayFormat') mltdisplayformat
                      --bulk collect into t_ObjectIdsFull, t_ObjectIdsLTC, t_ObjectIdsPLT, t_ObjectIdsSLT, t_ObjectIdsMLT
                      FROM TABLE(
                               CAST(
                                   api.pkg_simplesearch.castableobjectsbyindex(
                                       'j_LicenseType',
                                       'dup_ExpirationDate',
                                       TO_CHAR(a_expirationdate, 'YYYY-MM-DD HH24:MI:SS')) AS api.udt_objectlist)) x
                           JOIN query.j_licensetype lt
                           ON lt.jobid = x.objectid
                           JOIN api.fees f
                           ON f.jobid = x.objectid
                           JOIN api.registeredexternalobjects reo
                           ON reo.linkvalue = TO_CHAR(f.feeid)
                          AND reo.objectdefid = t_feeobjectdefid
                           JOIN query.r_feelicensefeeschedule ffs
                           ON ffs.feeobjectid = reo.objectid
                           JOIN sitespecific.feeschedule_t fs
                           ON fs.objectid = ffs.licensefeescheduleid
                     WHERE EXISTS
                               (SELECT 1
                                  FROM api.jobstatuses js
                                       JOIN api.statuses s
                                       ON s.statusid = js.statusid
                                 WHERE js.jobtypeid = t_licensedefid
                                   AND s.description IN ('Active',
                                                         'Surrendered',
                                                         'Rule 64B',
                                                         'SLMS Hold',
                                                         'Suspended',
                                                         'SLMS')
                                   AND s.description = lt.statusdescription)
                       AND (  f.amount
                            + NVL((SELECT SUM(amount)
                                     FROM api.feetransactions ft
                                    WHERE ft.feeid = f.feeid),
                                  0)) > 0  -- RyanL: Changed to be a subselect for performance (PIP Task 8.5)
                       AND (fs.feeactivity = t_prioractivity
                         OR fs.feeactivity = t_priorprioractivity
                        AND t_priorprioractivity IS NOT NULL)
                       AND api.pkg_columnquery.VALUE(x.objectid, 'SeasonStartMonthNumber') IS NULL
                    UNION  -- Find Seasonals
                    SELECT x.objectid                                                              ltobjectid,
                           fs.licensetypecode,
                           api.pkg_columnquery.VALUE(x.objectid, 'LicenseTypeCode')                primaryltcode,
                           api.pkg_columnquery.VALUE(x.objectid, 'SecondaryLTCategoryObjectId')    sltobjectid,
                           api.pkg_columnquery.VALUE(x.objectid, 'MasterLicenseTypeDisplayFormat') mltdisplayformat
                      FROM TABLE(api.pkg_simplesearch.castableobjectsbyindexrange('j_LicenseType',
                                                                                  'dup_SeasonStartMonthNumber',
                                                                                  1,
                                                                                  12)) l
                           JOIN query.j_licensetype x
                           ON x.objectid = l.objectid
                           JOIN api.fees f
                           ON f.jobid = x.objectid
                           JOIN api.registeredexternalobjects reo
                           ON reo.linkvalue = TO_CHAR(f.feeid)
                          AND reo.objectdefid = t_feeobjectdefid
                           JOIN query.r_feelicensefeeschedule ffs
                           ON ffs.feeobjectid = reo.objectid
                           JOIN sitespecific.feeschedule_t fs
                           ON fs.objectid = ffs.licensefeescheduleid
                     WHERE EXISTS
                               (SELECT 1
                                  FROM api.jobstatuses js
                                       JOIN api.statuses s
                                       ON s.statusid = js.statusid
                                 WHERE js.jobtypeid = t_licensedefid
                                   AND s.description IN ('Active',
                                                         'Surrendered',
                                                         'Rule 64B',
                                                         'SLMS Hold',
                                                         'Suspended',
                                                         'SLMS')
                                   AND s.description = x.statusdescription)
                       AND (  f.amount
                            + NVL((SELECT SUM(amount)
                                     FROM api.feetransactions ft
                                    WHERE ft.feeid = f.feeid),
                                  0)) > 0  -- RyanL: Changed to be a subselect for performance (PIP Task 8.5)
                       AND (fs.feeactivity = t_prioractivity
                         OR fs.feeactivity = t_priorprioractivity
                        AND t_priorprioractivity IS NOT NULL)
                       AND (TO_DATE(
                                   LPAD(x.dup_seasonstartmonthnumber, 2, '00')
                                || '/01/'
                                || CASE
                                       WHEN   TO_NUMBER(TO_CHAR(x.dup_expirationdate, 'MM'))
                                            - (x.numberofmonthslicensednumber + 1) <  -- 01/10/2019 TJL 16435 removed = from test
                                            0 THEN
                                           NVL(x.expiringyear, '9999')
                                       ELSE
                                           NVL(x.expiringyear + 1, '9999')
                                   END,
                                'MM/DD/YYYY')) =
                           TO_DATE(a_expirationdate + 1)
                    UNION  -- Find LTs with no REN fees ever created, but should have been created
                    SELECT x.objectid                                                              ltobjectid,
                           api.pkg_columnquery.VALUE(x.objectid, 'LicenseTypeCode'),
                           api.pkg_columnquery.VALUE(x.objectid, 'LicenseTypeCode')                primaryltcode,
                           api.pkg_columnquery.VALUE(x.objectid, 'SecondaryLTCategoryObjectId')    sltobjectid,
                           api.pkg_columnquery.VALUE(x.objectid, 'MasterLicenseTypeDisplayFormat') mltdisplayformat
                      FROM TABLE(
                               CAST(
                                   api.pkg_simplesearch.castableobjectsbyindex(
                                       'j_LicenseType',
                                       'dup_ExpirationDate',
                                       TO_CHAR(a_expirationdate, 'YYYY-MM-DD HH24:MI:SS')) AS api.udt_objectlist)) x
                           JOIN query.j_licensetype lt
                           ON lt.jobid = x.objectid
                     WHERE NOT EXISTS
                               (SELECT 1
                                  FROM api.fees f
                                       JOIN api.registeredexternalobjects reo  -- RyanL: PIP Task 8.5
                                       ON reo.linkvalue = TO_CHAR(f.feeid)
                                      AND reo.objectdefid = t_feeobjectdefid
                                       JOIN query.r_feelicensefeeschedule ffs
                                       ON ffs.feeobjectid = reo.objectid
                                       JOIN sitespecific.feeschedule_t fs
                                       ON fs.objectid = ffs.licensefeescheduleid
                                 WHERE f.jobid = x.objectid
                                   AND fs.feeactivity LIKE '%REN%'
                                   AND api.pkg_columnquery.datevalue(reo.objectid, 'RENExpirationDate') =
                                       a_expirationdate)
                       AND EXISTS
                               (SELECT 1
                                  FROM api.jobstatuses js
                                       JOIN api.statuses s
                                       ON s.statusid = js.statusid
                                 WHERE js.jobtypeid = t_licensedefid
                                   AND s.description IN ('Active',
                                                         'Surrendered',
                                                         'Rule 64B',
                                                         'SLMS Hold',
                                                         'Suspended',
                                                         'SLMS')
                                   AND s.description = lt.statusdescription)
                       AND lt.dup_seasonstartmonthnumber IS NULL
                    UNION  -- Find Seasonal LTs with no REN fees ever created, but should have been created
                    SELECT x.objectid                                                              ltobjectid,
                           api.pkg_columnquery.VALUE(x.objectid, 'LicenseTypeCode'),
                           api.pkg_columnquery.VALUE(x.objectid, 'LicenseTypeCode')                primaryltcode,
                           api.pkg_columnquery.VALUE(x.objectid, 'SecondaryLTCategoryObjectId')    sltobjectid,
                           api.pkg_columnquery.VALUE(x.objectid, 'MasterLicenseTypeDisplayFormat') mltdisplayformat
                      FROM TABLE(api.pkg_simplesearch.castableobjectsbyindexrange('j_LicenseType',
                                                                                  'dup_SeasonStartMonthNumber',
                                                                                  1,
                                                                                  12)) l
                           JOIN query.j_licensetype x
                           ON x.objectid = l.objectid
                     WHERE NOT EXISTS
                               (SELECT 1
                                  FROM api.fees f
                                       JOIN api.registeredexternalobjects reo  -- RyanL: PIP Task 8.5
                                       ON reo.linkvalue = TO_CHAR(f.feeid)
                                      AND reo.objectdefid = t_feeobjectdefid
                                       JOIN query.r_feelicensefeeschedule ffs
                                       ON ffs.feeobjectid = reo.objectid
                                       JOIN sitespecific.feeschedule_t fs
                                       ON fs.objectid = ffs.licensefeescheduleid
                                 WHERE f.jobid = x.objectid
                                   AND fs.feeactivity LIKE '%REN%'
                                   AND api.pkg_columnquery.datevalue(reo.objectid, 'RENExpirationDate') =
                                       a_expirationdate)
                       AND EXISTS
                               (SELECT 1
                                  FROM api.jobstatuses js
                                       JOIN api.statuses s
                                       ON s.statusid = js.statusid
                                 WHERE js.jobtypeid = t_licensedefid
                                   AND s.description IN ('Active',
                                                         'Surrendered',
                                                         'Rule 64B',
                                                         'SLMS Hold',
                                                         'Suspended',
                                                         'SLMS')
                                   AND s.description = x.statusdescription)
                       AND (TO_DATE(
                                   LPAD(x.dup_seasonstartmonthnumber, 2, '00')
                                || '/01/'
                                || CASE
                                       WHEN   TO_NUMBER(TO_CHAR(x.dup_expirationdate, 'MM'))
                                            - (x.numberofmonthslicensednumber + 1) <  -- 01/10/2019 TJL 16435 removed = from test
                                            0 THEN
                                           NVL(x.expiringyear, '9999')
                                       ELSE
                                           NVL(x.expiringyear + 1, '9999')
                                   END,
                                'MM/DD/YYYY')) =
                           TO_DATE(a_expirationdate + 1))
            LOOP
                t_expiringyear   := api.pkg_columnquery.VALUE(x.ltobjectid, 'ExpiringYear');

                IF t_expiringyear IS NULL THEN
                    CONTINUE;
                END IF;

                --t_Count := t_Count + 1;
                IF x.mltdisplayformat IS NOT NULL
               AND x.licensetypecode = x.primaryltcode THEN
                    t_primaryorsecondary   := 'Primary';
                ELSIF x.sltobjectid IS NULL
                  AND x.licensetypecode = x.primaryltcode THEN
                    t_primaryorsecondary   := 'Primary';
                ELSIF x.sltobjectid IS NOT NULL THEN
                    BEGIN
                        SELECT CASE
                                   WHEN ltcs.licensetypecount > 0
                                    AND ltc.licensetypecode = x.primaryltcode THEN
                                       'Primary'
                                   WHEN ltcs.licensetypecount > 0 THEN
                                       'Secondary'
                                   ELSE
                                       'Primary'
                               END
                          INTO t_primaryorsecondary
                          FROM query.r_licensetypeltcatsecondary ltcs
                               JOIN query.o_licensetypecategory ltc
                               ON ltc.objectid = ltcs.licensetypecategoryobjectid
                         WHERE ltcs.licensetypejobid = x.ltobjectid
                           AND ltc.licensetypecode = x.licensetypecode
                           AND ltcs.status NOT IN ('CANCELED', 'NON-RENEWED');
                    EXCEPTION
                        WHEN NO_DATA_FOUND THEN
                            t_primaryorsecondary   := 'Primary';  --has canceled/nren secondaries.
                    END;
                END IF;

                SELECT COUNT(1)
                  INTO t_lictypeinlicbatchcount
                  FROM sitespecific.licbatchlictype_xref_t ltlb
                 WHERE ltlb.licensebatchjobid = a_jobid
                   AND ltlb.tobeprocessedind = 'Y'  -- added MMR 10-9-14
                   AND ltlb.licensetypejobid = x.ltobjectid;

                IF t_lictypeinlicbatchcount = 0 THEN
                    --Second Level Check
                    --GallonageApplies
                    --PopulationApplies
                    --SeasonalMonthsApply
                    IF t_primaryorsecondary = 'Primary' THEN
                        -- Check to see if there already exists a REN50 or REN100 fee
                        -- and if it was created with the past year
                        SELECT COUNT(1) feecount
                          INTO t_feecount
                          FROM api.fees f
                               JOIN api.registeredexternalobjects reo  -- RyanL: PIP Task 8.5
                               ON reo.linkvalue = TO_CHAR(f.feeid)
                              AND reo.objectdefid = t_feeobjectdefid
                               JOIN sitespecific.feeschedule_t fs
                               ON fs.objectid = sitespecific.pkg_fees.getlicfeeschedulobjid(f.feeid)
                         WHERE f.jobid = x.ltobjectid
                           AND fs.licensetypecode = x.primaryltcode
                           AND t_checkexists LIKE
                                      '%'
                                   || fs.feeactivity
                                   || '.'
                                   || '%'
                           AND NVL(
                                   api.pkg_columnquery.datevalue(reo.objectid, 'RENExpirationDate'),
                                   NVL(
                                       DECODE(
                                           SUBSTR(fs.description, -1),
                                           '9', TO_DATE(  -- Final Date
                                                       TO_CHAR(  -- Day of month
                                                           LAST_DAY(
                                                                  '01-'
                                                               || TO_CHAR(
                                                                      LAST_DAY(
                                                                          api.pkg_columnquery.datevalue(
                                                                              x.ltobjectid,
                                                                              'ExpirationDate')),
                                                                      'MON')
                                                               || '-2009'),
                                                           'DD')  -- End Day of month
                                                    || '-'
                                                    || TO_CHAR(
                                                           api.pkg_columnquery.datevalue(x.ltobjectid,
                                                                                         'ExpirationDate'),
                                                           'MON')  -- Month
                                                    || '-2009'  -- Year
                                                              ),  -- final date
                                           'A', TO_DATE(  -- Final Date
                                                       TO_CHAR(  -- Day of month
                                                           LAST_DAY(
                                                               TO_DATE(
                                                                      '01-'
                                                                   || TO_CHAR(
                                                                          LAST_DAY(
                                                                              api.pkg_columnquery.datevalue(
                                                                                  x.ltobjectid,
                                                                                  'ExpirationDate')),
                                                                          'MON')
                                                                   || '-2010',
                                                                   'DD-MON-YYYY')),
                                                           'DD')  -- End Day of month
                                                    || '-'
                                                    || TO_CHAR(
                                                           api.pkg_columnquery.datevalue(x.ltobjectid,
                                                                                         'ExpirationDate'),
                                                           'MON')  -- Month
                                                    || '-2010'  -- Year
                                                              )),  --final date
                                       LAST_DAY(SYSDATE))) =
                               a_expirationdate;


                        -- If the above select returns something then
                        IF t_feecount > 0 THEN
                            -- Set a_CreateFee to 'N'
                            t_createfee   := 'N';
                        -- End If
                        END IF;

                        IF t_createfee = 'Y' THEN
                            /*sitespecific.pkg_batchtype.BatchLogging(a_JobId,
                                                               a_JobId,
                                                               'Processing License: '|| x.LTObjectId,
                                                                t_TotalExpectedCount );*/

                            INSERT INTO licbatchlictype_xref_t(licensebatchjobid,
                                                               licensetypejobid,
                                                               serialnumber,
                                                               printorder,
                                                               processeddate,
                                                               tobeprocessedind)
                                 VALUES (a_jobid,
                                         x.ltobjectid,
                                         serial_number.NEXTVAL,
                                         NULL,
                                         NULL,
                                         'Y');  -- added last parameter for ToBeProcessed Indicator MMR 10-9-14
                        END IF;
                    ELSE  -- If It is not Primary then it is either Secondary Or Both
                        -- Check to see if there already exists a REN50 or REN100 fee
                        -- and if it was created with the past year
                        SELECT COUNT(1) feecount
                          INTO t_feecount
                          FROM api.fees f
                               JOIN feeschedule_t fs
                               ON fs.objectid = sitespecific.pkg_fees.getlicfeeschedulobjid(f.feeid)
                         WHERE f.jobid = x.ltobjectid
                           AND fs.licensetypecode = x.licensetypecode
                           AND t_checkexists LIKE
                                      '%'
                                   || fs.feeactivity
                                   || '.'
                                   || '%';

                        -- If the above select returns something then
                        IF t_feecount > 0 THEN
                            -- Set a_CreateFee to 'N'
                            t_createsfee   := 'N';
                        -- End If
                        END IF;

                        IF t_createsfee = 'Y' THEN  -- If Create S Fee = Y #1
                            /*sitespecific.pkg_batchtype.BatchLogging(a_JobId,
                                                               a_JobId,
                                                               'Processing License: '|| x.LTObjectId,
                                                                t_TotalExpectedCount );*/

                            INSERT INTO licbatchlictype_xref_t(licensebatchjobid,
                                                               licensetypejobid,
                                                               serialnumber,
                                                               printorder,
                                                               processeddate,
                                                               tobeprocessedind)
                                 VALUES (a_jobid,
                                         x.ltobjectid,
                                         serial_number.NEXTVAL,
                                         NULL,
                                         NULL,
                                         'Y');  -- added last parameter for ToBeProcessed Indicator MMR 10-9-14
                        END IF;
                    END IF;

                    IF t_createfee = 'N'
                    OR t_createsfee = 'N' THEN
                        t_createsfee   := 'Y';
                        t_createfee    := 'Y';
                    END IF;
                END IF;  -- End of already created
            END LOOP;
        --api.pkg_errors.RaiseError(-20000, 'Total Count: ' || t_Count || ' Expiry: ' || a_ExpirationDate );

        END;
    END getbatchpenaltycandidatesold;

    /*----------------------------------------------------------------------------------------------------
      --  CopyProduceLicenseTypes()     --Public
      --  Populates the License Types grid on the Produce Licenses process.
      ----------------------------------------------------------------------------------------------------*/

    PROCEDURE copyproducelicensetypes(a_objectid udt_id, a_asofdate DATE)
    IS
        t_jobid                         udt_id := api.pkg_columnquery.VALUE(a_objectid, 'Jobid');
        t_pendingltobjdefid             udt_id := api.pkg_configquery.objectdefidforname('o_PendingLicenseType');
        t_pendingsltobjdefid            udt_id := api.pkg_configquery.objectdefidforname('o_PendingSecondaryLicenseType');
        t_newrelid                      udt_id;
        t_newobjid                      udt_id;
        t_newsecobjid                   udt_id;
        t_licensetypejobids             udt_idlist;
        t_primaryltcobjectids           udt_idlist;
        t_ltcatsecondaryrelids          udt_idlist;
        t_licensetypecode               VARCHAR2(3);
        t_expirationdatefordisplay      DATE;
        t_licensetypecategoryobjectid   udt_id;
        t_licensetypecount              NUMBER;
        t_status                        VARCHAR2(100);
        t_statusdate                    DATE;
    BEGIN
        BEGIN
            toolbox.pkg_copy.copyrels(a_objectid, SYSDATE, 'JOB:r_LicenseLicenseType<R>r_ProduceLicensesLicenseType');
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                NULL;  -- when no data is found the relationships should not copy.
        END;

        BEGIN
            -- RyanL: Changed to bulk collect for performance (PIP Task 8.7)
            SELECT lt.jobid, plt.licensetypecategoryobjectid primaryltcobjid
              BULK COLLECT INTO t_licensetypejobids, t_primaryltcobjectids
              FROM query.r_licenselicensetype llt
                   JOIN query.j_licensetype lt
                   ON lt.jobid = llt.licensetypejobid
                   JOIN query.r_licensetypeltcatprimary plt
                   ON plt.licensetypejobid = lt.jobid
             WHERE llt.licensejobid = t_jobid;

            FOR i IN 1 .. t_licensetypejobids.COUNT
            LOOP
                t_licensetypecode            := api.pkg_columnquery.VALUE(t_licensetypejobids(i), 'LicenseTypeCode');
                t_expirationdatefordisplay   :=
                    api.pkg_columnquery.datevalue(t_licensetypejobids(i), 'ExpirationDateForDisplay');

                --Create the Pending License Type object has place holders for the secondary types
                t_newobjid                   := api.pkg_objectupdate.new(t_pendingltobjdefid);
                t_newrelid                   :=
                    api.pkg_relationshipupdate.new(
                        api.pkg_configquery.endpointidforname('p_ProduceLicenses', 'PendLicType'),
                        a_objectid,
                        t_newobjid);
                t_newrelid                   :=
                    api.pkg_relationshipupdate.new(
                        api.pkg_configquery.endpointidforname('o_PendingLicenseType', 'PendLTLicTypeCatPrimary'),
                        t_newobjid,
                        t_primaryltcobjectids(i));

                -- RyanL: Changed to bulk collect for performance (PIP Task 8.7)
                SELECT relationshipid
                  BULK COLLECT INTO t_ltcatsecondaryrelids
                  FROM query.r_licensetypeltcatsecondary r
                 WHERE r.licensetypejobid = t_licensetypejobids(i);

                FOR j IN 1 .. t_ltcatsecondaryrelids.COUNT
                LOOP
                    t_licensetypecategoryobjectid   :=
                        api.pkg_columnquery.VALUE(t_ltcatsecondaryrelids(j), 'LTCObjectID');
                    t_licensetypecount   := api.pkg_columnquery.VALUE(t_ltcatsecondaryrelids(j), 'LicenseTypeCount');
                    t_status             := api.pkg_columnquery.VALUE(t_ltcatsecondaryrelids(j), 'Status');
                    t_statusdate         := api.pkg_columnquery.datevalue(t_ltcatsecondaryrelids(j), 'StatusDate');

                    t_newsecobjid        := api.pkg_objectupdate.new(t_pendingsltobjdefid);
                    t_newrelid           :=
                        api.pkg_relationshipupdate.new(
                            api.pkg_configquery.endpointidforname('o_PendingLicenseType', 'LicTypeCatSecondary'),
                            t_newobjid,
                            t_newsecobjid);
                    t_newrelid           :=
                        api.pkg_relationshipupdate.new(
                            api.pkg_configquery.endpointidforname('o_PendingSecondaryLicenseType',
                                                                  'PendLicTypeCatSecondary'),
                            t_newsecobjid,
                            t_licensetypecategoryobjectid);
                    api.pkg_columnupdate.setvalue(t_newsecobjid, 'LicenseTypeCount', t_licensetypecount);
                    api.pkg_columnupdate.setvalue(t_newsecobjid, 'Status', t_status);
                    api.pkg_columnupdate.setvalue(t_newsecobjid, 'StatusDate', t_statusdate);
                    api.pkg_columnupdate.setvalue(t_newsecobjid, 'MasterLTCode', t_licensetypecode);
                    api.pkg_columnupdate.setvalue(t_newsecobjid, 'ExpirationDate', t_expirationdatefordisplay);
                END LOOP;
            END LOOP;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                NULL;  -- when no data is found the relationships should not copy.
        END;

        setserialnum(a_objectid);
    END copyproducelicensetypes;

    /*-------------------------------------------------
     -- SetFlagsforProduceLicenses()
     -- Resets the Produce License Batch flag when applicable.
     -----------------------------------------------------*/

    PROCEDURE setflagsforproducelicenses(a_objectid udt_id, a_asofdate DATE)
    IS
        t_color                          VARCHAR2(10) := api.pkg_columnquery.VALUE(a_objectid, 'Color');
        t_secondaryprint                 VARCHAR2(1);
        t_ispinkdone                     VARCHAR2(1);
        t_isgreendone                    VARCHAR2(1);
        t_inclin1strenewal               VARCHAR2(1) DEFAULT 'N';
        t_includeinproducelicensebatch   VARCHAR2(1) DEFAULT 'N';
        t_includeindailybatch            VARCHAR2(1) DEFAULT 'N';
        t_seasonstartdate                DATE;
        t_licensetypejobids              udt_idlist;
        t_primarylicensetyperelids       udt_idlist;
        t_ltcatobjectids                 udt_idlist;
        t_secondaryltrelids              udt_idlist;
        t_secondaryltcobjectids          udt_idlist;
        t_pendingsecondaryltobjectids    udt_idlist;
        t_readytoissuedate               DATE;
        t_expirationdate                 DATE;
        t_ltissuedate                    DATE;
        t_seasonstartmonthnumber         NUMBER;
        t_seasonalmonthsapply            VARCHAR2(1);
        t_sltissuedate                   DATE;
        t_sltseasonalmonthsapply         VARCHAR2(1);
    BEGIN
        -- RyanL: Changed to bulk collect for performance (PIP Task 8.7)
        SELECT lt.jobid, plt.relationshipid, ltc.objectid
          BULK COLLECT INTO t_licensetypejobids, t_primarylicensetyperelids, t_ltcatobjectids
          FROM query.r_producelicenseslicensetype plt
               JOIN query.j_licensetype lt
               ON lt.jobid = plt.licensetypejobid
               JOIN query.r_licensetypeltcatprimary ltplt
               ON ltplt.licensetypejobid = lt.jobid
               JOIN query.o_licensetypecategory ltc
               ON ltc.objectid = ltplt.licensetypecategoryobjectid
         WHERE plt.producelicprocessid = a_objectid;

        FOR i IN 1 .. t_licensetypejobids.COUNT
        LOOP
            t_expirationdate           := api.pkg_columnquery.datevalue(t_licensetypejobids(i), 'ExpirationDate');
            t_seasonstartdate          :=
                TRUNC(
                    ADD_MONTHS(
                        t_expirationdate,
                        -(api.pkg_columnquery.numericvalue(t_licensetypejobids(i), 'NumberOfMonthsLicensedNumber'))),
                    'Month');

            t_ltissuedate              := api.pkg_columnquery.datevalue(t_licensetypejobids(i), 'IssueDate');
            t_seasonalmonthsapply      := api.pkg_columnquery.VALUE(t_ltcatobjectids(i), 'SeasonalMonthsApply');
            t_seasonstartmonthnumber   :=
                api.pkg_columnquery.numericvalue(t_licensetypejobids(i), 'SeasonStartMonthNumber');
            t_readytoissuedate         := api.pkg_columnquery.datevalue(t_licensetypejobids(i), 'ReadyToIssueDate');

            -- Set the batch flags for the License Type Job
            IF api.pkg_columnquery.VALUE(t_primarylicensetyperelids(i), 'IsColor') = 'Y'
           AND api.pkg_columnquery.VALUE(t_primarylicensetyperelids(i), 'PrintLicense') = 'Y'
           AND api.pkg_columnquery.VALUE(t_licensetypejobids(i), 'IncludeInProduceLicenseBatch') = 'Y'
           AND t_color IS NOT NULL THEN
                pkg_batchtype.setbatchflags(t_licensetypejobids(i), a_includein1strenewal => 'Y');

                -- Set License Type IssueDate if it is not already set.
                -- If License is not seasonal or, in the case of a seasonal, the current month is part of the season, then set issuedate to current date.
                IF (t_ltissuedate IS NULL
                AND t_seasonalmonthsapply = 'N')
                OR (t_ltissuedate IS NULL
                AND t_seasonalmonthsapply = 'Y'
                AND TRUNC(t_expirationdate) >= TRUNC(SYSDATE)
                AND TRUNC(t_seasonstartdate) <= TRUNC(SYSDATE)) THEN
                    --Set the Issue Date on the Primary License Type Job
                    api.pkg_columnupdate.setvalue(t_licensetypejobids(i), 'IssueDate', TRUNC(t_readytoissuedate));
                --If SeasonalMonthsApply = 'Y' and the Month is in the future, then set IssueDate to the first day of that month.
                ELSIF t_ltissuedate IS NULL
                  AND t_seasonstartmonthnumber > TO_NUMBER(TO_CHAR(SYSDATE, 'mm')) THEN
                    api.pkg_columnupdate.setvalue(t_licensetypejobids(i),
                                                  'IssueDate',
                                                  (TO_DATE((   '01'
                                                            || LPAD(t_seasonstartmonthnumber, 2, 0)
                                                            || (TO_CHAR(SYSDATE, 'yyyy'))),
                                                           'ddmmyyyy')));
                --If SeasonalMonthsApply = 'Y' and the Month is in the past, then set IssueDate to the first day of that month next year.
                ELSIF t_ltissuedate IS NULL
                  AND TO_NUMBER(TO_CHAR(t_expirationdate, 'mm')) < TO_NUMBER(TO_CHAR(SYSDATE, 'mm')) THEN
                    api.pkg_columnupdate.setvalue(t_licensetypejobids(i),
                                                  'IssueDate',
                                                  (TO_DATE((   '01'
                                                            || LPAD(t_seasonstartmonthnumber, 2, 0)
                                                            || (TO_CHAR(SYSDATE + INTERVAL '1' YEAR, 'yyyy'))),
                                                           'ddfmmmyyyy')));
                -- If the IssueDate is already filled, then do nothing.
                END IF;

                --Earn the Payment Transactions.
                sitespecific.pkg_fees.createltpaymentstatus(t_licensetypejobids(i), SYSDATE);
            END IF;

            -- RyanL: Changed to bulk collect for performance (PIP Task 8.7)
            SELECT DISTINCT (slt.relationshipid), ltc.objectid, pslt.objectid
              BULK COLLECT INTO t_secondaryltrelids, t_secondaryltcobjectids, t_pendingsecondaryltobjectids
              FROM query.r_producelicenseslicensetype plt
                   JOIN query.j_licensetype lt
                   ON lt.jobid = plt.licensetypejobid
                   JOIN query.r_licensetypeltcatsecondary slt
                   ON slt.licensetypejobid = lt.jobid
                   JOIN query.o_licensetypecategory ltc
                   ON ltc.objectid = slt.licensetypecategoryobjectid
                   JOIN query.r_pslttoltc psltltc
                   ON psltltc.licensetypecategoryobjectid = ltc.objectid
                   JOIN query.o_pendingsecondarylicensetype pslt
                   ON pslt.objectid = psltltc.pendingsecondaryltobjectid
                   JOIN query.r_producelicenseltcatsecondary plslt
                   ON plslt.licensetypecategoryobjectid = psltltc.pendingsecondaryltobjectid
                  AND plslt.producelicnesesprocessid = plt.producelicprocessid
             WHERE plt.producelicprocessid = a_objectid;

            -- Set the Batch Flags for the Secondary License Types if any.
            FOR j IN 1 .. t_secondaryltrelids.COUNT
            LOOP
                t_sltissuedate   := api.pkg_columnquery.datevalue(t_secondaryltrelids(j), 'IssueDate');
                t_sltseasonalmonthsapply   :=
                    api.pkg_columnquery.VALUE(t_secondaryltcobjectids(j), 'SeasonalMonthsApply');

                IF api.pkg_columnquery.VALUE(t_secondaryltrelids(j), 'IncludeInProduceLicenseBatch') = 'Y'
               AND api.pkg_columnquery.VALUE(t_secondaryltcobjectids(j), 'Color') = t_color
               AND api.pkg_columnquery.VALUE(t_pendingsecondaryltobjectids(j), 'PrintLicense') = 'Y' THEN
                    --Set the Batch Flags
                    pkg_batchtype.setbatchflags(t_secondaryltrelids(j), a_includein1strenewal => 'Y');

                    --Set Status to Active
                    IF api.pkg_columnquery.VALUE(t_secondaryltrelids(j), 'Status') IN ('PENDING') THEN
                        api.pkg_columnupdate.setvalue(t_secondaryltrelids(j), 'Status', 'ACTIVE');
                    END IF;

                    --Set the batchdate on the duplicate objects to sysdate
                    FOR do IN (SELECT dt.duplicateid
                                 FROM sitespecific.duplicate_t dt
                                WHERE dt.relationshipid = t_secondaryltrelids(j))
                    LOOP
                        api.pkg_columnupdate.setvalue(do.duplicateid, 'BatchDate', TRUNC(SYSDATE));
                    END LOOP;

                    --If Issue Date is null then set it to the correct expiration date.
                    --HotFix22 Part One Point Five.
                    -- Set Secondary License Type IssueDate if it is not already set.
                    --If License is not seasonal or, in the case of a seasonal, the current month is part of the season, then set issuedate to current date.
                    IF (t_sltissuedate IS NULL
                    AND t_sltseasonalmonthsapply = 'N')
                    OR (t_sltissuedate IS NULL
                    AND t_sltseasonalmonthsapply = 'Y'
                    AND TRUNC(t_expirationdate) >= TRUNC(SYSDATE)
                    AND TRUNC(t_seasonstartdate) <= TRUNC(SYSDATE)) THEN
                        --Set the Issue Date on the Secondary License Types
                        api.pkg_columnupdate.setvalue(
                            t_secondaryltrelids(j),
                            'IssueDate',
                            TRUNC(api.pkg_columnquery.datevalue(t_secondaryltrelids(j), 'ReadyToIssueDate')));
                    --If SeasonalMonthsApply = 'Y' and the Month is in the future, then set IssueDate to the first day of that month.
                    ELSIF t_sltissuedate IS NULL
                      AND t_seasonstartmonthnumber > TO_NUMBER(TO_CHAR(SYSDATE, 'mm')) THEN
                        api.pkg_columnupdate.setvalue(t_secondaryltrelids(j),
                                                      'IssueDate',
                                                      (TO_DATE((   '01'
                                                                || LPAD(t_seasonstartmonthnumber, 2, 0)
                                                                || (TO_CHAR(SYSDATE, 'yyyy'))),
                                                               'ddmmyyyy')));
                    --If SeasonalMonthsApply = 'Y' and the Month is in the past, then set IssueDate to the first day of that month next year.
                    ELSIF t_sltissuedate IS NULL
                      AND TO_NUMBER(TO_CHAR(t_expirationdate, 'mm')) < TO_NUMBER(TO_CHAR(SYSDATE, 'mm')) THEN
                        api.pkg_columnupdate.setvalue(t_secondaryltrelids(j),
                                                      'IssueDate',
                                                      (TO_DATE((   '01'
                                                                || LPAD(t_seasonstartmonthnumber, 2, 0)
                                                                || (TO_CHAR(SYSDATE + INTERVAL '1' YEAR, 'yyyy'))),
                                                               'ddfmmmyyyy')));
                    -- If the IssueDate is already filled, then do nothing.
                    END IF;

                    --Set Duplicate Ready to Issue Date
                    FOR dup_l IN (SELECT qdup.batchdate, qdup.objectid
                                    FROM sitespecific.duplicate_t dup
                                         JOIN query.o_duplicate qdup
                                         ON qdup.objectid = dup.duplicateid
                                   WHERE dup.relationshipid = t_secondaryltrelids(j))
                    LOOP
                        --Set Ready to Issue Date
                        api.pkg_columnupdate.setvalue(
                            dup_l.objectid,
                            'IssueDate',
                            api.pkg_columnquery.datevalue(t_secondaryltrelids(j), 'IssueDate'));
                        api.pkg_columnupdate.setvalue(
                            dup_l.objectid,
                            'ReadyToIssueDate',
                            api.pkg_columnquery.datevalue(t_secondaryltrelids(j), 'IssueDate'));
                    END LOOP;
                END IF;
            END LOOP;

            -- Maintain Dup Columns
            api.pkg_columnupdate.setvalue(t_licensetypejobids(i), 'dup_IncludeIn1stRenewalSec', 'Y');
        END LOOP;
    END setflagsforproducelicenses;

    /*--------------------------------------------------------
    --SetPrintFlagForManualProduce()
    --Sets the print flag on the duplicate objects based on the
    --selected secondaries from the manual produce license process
    ----------------------------------------------------------*/
    PROCEDURE setprintflagformanualproduce(a_objectid udt_id, a_asofdate DATE)
    IS
      t_recordcount         NUMBER;

    BEGIN
		
      -- 3/9/2021 NW 24491 
      SELECT COUNT(1) INTO t_recordcount 
      FROM query.r_producelicenseltcatsecondary
      WHERE licensetypecategoryobjectid = a_objectid;
      
      IF t_recordcount = 0 THEN
        RETURN;
      END IF;
      
      FOR c IN (
        SELECT 
          do.duplicateid,
          do.PRINT,
          pslt.printlicense,
          pl.color  plcolor,
          ltc.color ltccolor
        FROM sitespecific.duplicate_t do
        JOIN query.r_licensetypeltcatsecondary lts ON lts.relationshipid = do.relationshipid
        JOIN query.j_licensetype lt ON lt.objectid = lts.licensetypejobid
        JOIN query.r_licenselicensetype llt	ON llt.licensetypejobid = lt.objectid
        JOIN query.j_license l ON l.objectid = llt.licensejobid
        JOIN query.p_producelicenses pl	ON pl.jobid = l.objectid
        JOIN query.r_producelicenseltcatsecondary pls	ON pls.producelicnesesprocessid = pl.objectid
        JOIN query.o_pendingsecondarylicensetype pslt	ON pslt.objectid = pls.licensetypecategoryobjectid
        JOIN query.r_pslttoltc r ON r.pendingsecondaryltobjectid = pslt.objectid
        JOIN query.o_licensetypecategory ltc ON ltc.objectid = lts.licensetypecategoryobjectid
        WHERE pls.licensetypecategoryobjectid = a_objectid 
          AND ltc.objectid = r.licensetypecategoryobjectid
      )
      LOOP
        IF c.plcolor = c.ltccolor THEN
          api.pkg_columnupdate.setvalue(c.duplicateid, 'Print', c.printlicense);
        END IF;
      END LOOP;
    END setprintflagformanualproduce;

    /*-------------------------------------------------
    -- LogTypeofIssuance ()
    -- Logs the type of issuance using License Type and Secondary License Type Ids
    --    on the print outcome of the Produce License Batch
    -----------------------------------------------------*/
    PROCEDURE logtypeofissuance(
      a_processid udt_id, 
      a_asofdate DATE
    )
    IS
      t_jobid               udt_id;
      t_color               VARCHAR2(10);
      t_currentprintorder   NUMBER(9);
      t_maxprintorder       NUMBER(9);
    BEGIN
      t_jobid   := api.pkg_columnquery.VALUE(a_processid, 'JobId');

      SELECT (COUNT(p.processid)) INTO t_currentprintorder
        FROM api.processes p
       WHERE p.jobid = t_jobid
         AND p.processid <= a_processid
         AND p.processtypeid = api.pkg_columnquery.VALUE(a_processid, 'ObjectDefId');

      SELECT MAX(t.printorder) INTO t_maxprintorder
        FROM sitespecific.batch_tracking_log t
       WHERE t.licensebatchjobid = t_jobid
         AND NVL(t.tobeprocessedind, 3) IN (1, 2, 3);  -- added MMR 10-30-14

      IF (t_currentprintorder = t_maxprintorder) THEN  --If we are the last Print License Bulk process based on the Print Order then Log Type of Issuance.
        SELECT color
          INTO t_color
          FROM query.j_licensebatch lb
         WHERE lb.jobid = t_jobid;

        INSERT INTO sitespecific.typeofissuancelog_t(
          objectid,
          objectdefid,
          typeofissuance,
          failed,
          faileddate,
          errormessage,
          jobid
        )
        ( 
          SELECT 
            lt.objectid    objectid,
            lt.objectdefid objectdefid,
            'RENEWAL',
            'N',
            NULL,
            NULL,
            t_jobid
          FROM query.j_licensebatch lb
          JOIN sitespecific.licbatchlictype_xref_t ltib ON ltib.licensebatchjobid = lb.jobid
          JOIN query.j_licensetype lt ON lt.objectid = ltib.licensetypejobid
          WHERE lt.PRINT = 'Y'
            AND lt.color = t_color
            AND lb.jobid = t_jobid
          --  and ltib.ToBeProcessedInd = 'Y'                -- added MMR 10-9-14
          /*and not exists (select 1 from sitespecific.typeofissuancelog_t l where l.objectid = lt.objectid)*/

          UNION
          SELECT 
            do.duplicateid  /*ltlcs.RelationshipId*/
            objectid,
            rd.relationshipdefid objectdefid,
            'RENEWAL',
            'N',
            NULL,
            NULL,
            t_jobid
          FROM query.j_licensebatch lb
          JOIN sitespecific.licbatchlictype_xref_t ltib ON ltib.licensebatchjobid = lb.jobid
          JOIN query.j_licensetype lt ON lt.objectid = ltib.licensetypejobid
          JOIN query.r_licensetypeltcatsecondary ltlcs ON ltlcs.licensetypejobid = lt.objectid
          JOIN sitespecific.duplicate_t do 
            ON  do.licensetypejobid = lt.jobid
            AND do.relationshipid = ltlcs.relationshipid
            AND do.licensetypecategoryobjectid = ltlcs.licensetypecategoryobjectid
          JOIN api.relationshipdefs rd    
            ON rd.name = ltlcs.objectdefname
            AND rd.fromobjectdefid = lt.objectdefid
          JOIN query.o_licensetypecategory ltc  ON ltc.objectid = ltlcs.licensetypecategoryobjectid
            WHERE do.PRINT = 'Y'
            AND ltc.color = t_color
            AND lb.jobid = t_jobid  -- and ltib.ToBeProcessedInd = 'Y'                -- added MMR 10-9-14
            /*and not exists (select 1 from sitespecific.typeofissuancelog_t l2 where l2.objectid = ltlcs.relationshipid)*/
         );
        END IF;
    END logtypeofissuance;

    /*-------------------------------------------------
    -- SetTypeofIssuance ()
    -- Sets the type of issuance on License Types and Secondary Relationships from the log table.
    --   This procedure is used by the dbms_Scheduler every evening.
    -----------------------------------------------------*/
    PROCEDURE settypeofissuance
    IS
      t_jobid          udt_id;
      t_color          VARCHAR2(10);
      t_error          VARCHAR2(200);
      t_objectdefid    udt_id;
      t_secondaryrel   udt_id;
    BEGIN
      FOR c IN (
        SELECT t.objectid
        FROM typeofissuancelog_t t
        WHERE t.failed = 'N'
          AND t.processeddate IS NULL
      )
      LOOP
        api.pkg_logicaltransactionupdate.resettransaction;

        BEGIN
          SELECT o.objectdefid INTO t_objectdefid
          FROM api.objects o
          WHERE o.objectid = c.objectid;
        EXCEPTION
          WHEN NO_DATA_FOUND THEN
            t_error   := 'Object No Longer Exists: ';
        END;

        BEGIN
          --If duplciate object skip setting the include in change app batch flag
          IF t_objectdefid != api.pkg_configquery.objectdefidforname('o_duplicate') THEN
            api.pkg_columnupdate.setvalue(c.objectid, 'IncludeInChangeAppBatch', 'N');
          END IF;

          --If duplciate object set the override TOI on secondary  REL
          IF t_objectdefid = api.pkg_configquery.objectdefidforname('o_duplicate') THEN
            SELECT t.relationshipid INTO t_secondaryrel
              FROM sitespecific.duplicate_t t
             WHERE t.duplicateid = c.objectid;

            api.pkg_columnupdate.setvalue(t_secondaryrel, 'SetDuplicates', 'N');
            api.pkg_columnupdate.setvalue(t_secondaryrel, 'TypeOfIssuance', 'RENEWAL');
          END IF;

          api.pkg_columnupdate.setvalue(c.objectid, 'TypeOfIssuance', 'RENEWAL');
          api.pkg_columnupdate.setvalue(c.objectid, 'Print', 'N');

          UPDATE typeofissuancelog_t t2
             SET t2.processeddate   = SYSDATE
           WHERE t2.objectid = c.objectid;
        EXCEPTION
          WHEN OTHERS THEN
            api.pkg_logicaltransactionupdate.resettransaction;
            t_error := SUBSTR(   
              t_error
               || c.objectid
               || ' '
               || SQLERRM,
              1,
              200
            );

          UPDATE typeofissuancelog_t t3
             SET t3.errormessage = t_error, t3.faileddate = SYSDATE, t3.failed = 'Y'
           WHERE t3.objectid = c.objectid;
        END;

        api.pkg_logicaltransactionupdate.endtransaction;
        COMMIT;
      END LOOP;
    END settypeofissuance;

    /*-------------------------------------------------
    -- SetDuplicatesTOI ()
    -- Set the type of issueance on the duplicate object when the
    -- type of issueance is updated on the override
    -----------------------------------------------------*/

    PROCEDURE setduplicatestoi(
      a_objectid udt_id, 
      a_asofdate DATE
    )
    IS
    BEGIN
      IF api.pkg_columnquery.VALUE(a_objectid, 'SetDuplicates') = 'N' THEN
        UPDATE sitespecific.duplicate_t t
           SET t.typeofissuance   = api.pkg_columnquery.VALUE(a_objectid, 'TypeOfIssuance')
         WHERE t.relationshipid = a_objectid;
      ELSE
        api.pkg_columnupdate.setvalue(a_objectid, 'SetDuplicates', 'N');
      END IF;
    END setduplicatestoi;

    /*-------------------------------------------------
     -- SetDuplciatesReadyToIssue ()
     -- Set the Ready to Issue Date on the duplicate object
     -- when the ready to issue date is updated on the override
     -----------------------------------------------------*/

    /*Set the Ready to Issue Date on the duplicate object when the ready to issue date is updated on the override*/

    PROCEDURE setduplciatesreadytoissue(
      a_objectid udt_id, 
      a_asofdate DATE
    )
    IS
    BEGIN
      FOR c IN (
        SELECT t.duplicateid, ltcs.readytoissuedate
          FROM duplicate_t t
          JOIN query.r_licensetypeltcatsecondary ltcs ON ltcs.relationshipid = t.relationshipid
        WHERE t.relationshipid = a_objectid)
      LOOP
        api.pkg_columnupdate.setvalue(c.duplicateid, 'ReadyToIssueDate', c.readytoissuedate);
      END LOOP;
    END setduplciatesreadytoissue;

    /*------------------
    -- SetREVPStatus()
    -- This will run on completion of the Send Final RevP Letters process on the License Batch job.
    -- It will loop through the LTs on the batch and set the status of any Active or Surrendered LT
    -- to Rev Pending.
    */
    ------------------

    PROCEDURE setrevpstatus(a_objectid udt_id, a_asofdate DATE, a_jobid udt_id)
    IS
      t_expirelictypeprocessdefid   udt_id;
      t_newprocid                   udt_id;
      t_status                      VARCHAR2(100);
      t_licensetypejobids           udt_idlist;
    BEGIN
      -- RyanL: Changed to bulk collect for performance (PIP Task 8.7)
      SELECT 
        ltc.licensetypejobid ltjobid
        BULK COLLECT INTO t_licensetypejobids
      FROM sitespecific.licbatchlictype_xref_t ltc
      JOIN query.j_licensetype lt ON ltc.licensetypejobid = lt.jobid
      WHERE ltc.licensebatchjobid = a_jobid
        AND ltc.tobeprocessedind = 'Y'  -- added MMR 10-9-14
        AND ltc.processid = a_objectid;  -- added AWP (CXUSA) 5/13/2016 to speed up batch and conform to new "chunking" of batch.

      -- loop through LTs on the batch job
      FOR i IN 1 .. t_licensetypejobids.COUNT
      LOOP
        -- get the status for the LT Job
        t_status   := api.pkg_columnquery.VALUE(t_licensetypejobids(i), 'StatusDescription');

        -- If the status of the LT is Active or Surrendered, create and complete the Expire LT process which sets the status to REVP
        IF t_status IN (
          'Active',
          'Surrendered',
          'Suspended',
          'Rule 64B'
        ) 
        THEN
          t_expirelictypeprocessdefid := api.pkg_configquery.objectdefidforname('p_ExpireLicenseType');
          t_newprocid := api.pkg_processupdate.new(
            t_licensetypejobids(i),
            t_expirelictypeprocessdefid,
            NULL,
            NULL,
            NULL,
            NULL
          );
          api.pkg_processupdate.complete(
            t_newprocid, 
            'Expire', 
            SYSDATE
          );
        END IF;
      END LOOP;
    END setrevpstatus;

    ------------------------------------------------------------------------
    PROCEDURE setrevpstatussecondaries(
      a_objectid udt_id, 
      a_asofdate DATE
    )
    IS
      t_jobid             udt_id;
      t_secondaryrelids   udt_idlist;
    BEGIN
      t_jobid   := api.pkg_columnquery.VALUE(a_objectid, 'JobId');

      -- RyanL: Changed to bulk collect for performance (PIP Task 8.7)
      SELECT 
        r.relationshipid
        BULK COLLECT INTO t_secondaryrelids
      FROM query.r_licensetypeltcatsecondary r
      WHERE r.licensetypejobid = t_jobid
        AND r.status IN (
        'ACTIVE',
        'SURRENDERED',
        'SUSPENDED',
        'RULE 64B'
      );

      --Loop thru secondaries and update the status to REV Pending
      FOR i IN 1 .. t_secondaryrelids.COUNT
      LOOP
        api.pkg_columnupdate.setvalue(t_secondaryrelids(i), 'Status', 'REV PENDING');
      END LOOP;
    END setrevpstatussecondaries;

    ---------------------------------------
    PROCEDURE deleteltfromactivebatches(
      a_objectid udt_id, 
      a_asofdate DATE
    )
    IS
      t_licensebatchjobids   udt_idlist;
    BEGIN
      IF api.pkg_columnquery.VALUE(a_objectid, 'DeleteFromActiveBatches') = 'N' THEN
        RETURN;
      END IF;

      -- RyanL: Changed to bulk collect for performance (PIP Task 8.7)
      SELECT lb.jobid
        BULK COLLECT INTO t_licensebatchjobids
      FROM sitespecific.licbatchlictype_xref_t lblt
      JOIN query.j_licensebatch lb ON lb.jobid = lblt.licensebatchjobid
       WHERE lb.statusdescription = 'In Progress'
         AND lblt.tobeprocessedind = 'Y'  -- added MMR 10-9-14
         AND lblt.licensetypejobid = a_objectid;

      FOR i IN 1 .. t_licensebatchjobids.COUNT
      LOOP
        DELETE FROM sitespecific.licbatchlictype_xref_t
        WHERE licensebatchjobid = t_licensebatchjobids(i)
        AND licensetypejobid = a_objectid;
      END LOOP;

      api.pkg_columnupdate.setvalue(a_objectid, 'DeleteFromActiveBatches', 'N');
    END deleteltfromactivebatches;

    /*---------------------------------------------------------------------------
     * GetProcessTypeForBatch() - PRIVATE
     *   Based on the batch type, return the process id that the LicenseBatch
     *   job would run
     *-------------------------------------------------------------------------*/
    PROCEDURE getprocesstypeforbatch(
      a_batchtype        VARCHAR2,
      a_processdefid OUT udt_id,
      a_processname  OUT VARCHAR2,
      a_processstatus OUT VARCHAR2
    )
    IS
      t_processname    VARCHAR2(4000);
      t_processdefid   udt_id;
    BEGIN
      CASE a_batchtype
      WHEN 'PRODUCE LICENSES' THEN
        t_processname     := 'p_ProduceLicenses';
        a_processname     := 'Produce Licenses';
        a_processstatus   := 'Produce';
      WHEN '1ST RENEWAL NOTICES' THEN
        t_processname     := 'p_Send1stRenewalNotices';
        a_processname     := '1st Renewal Notices';
        a_processstatus   := 'Send';
      WHEN '2ND RENEWAL NOTICES' THEN
        t_processname     := 'p_Send2ndRenewalNotices';
        a_processname     := '2nd Renewal Notices';
        a_processstatus   := 'Send';
      WHEN 'FINAL REVOCATION PENDING LETTERS' THEN
        t_processname     := 'p_SendFinalRevpLetters';
        a_processname     := 'Send Final Revoke Letters';
        a_processstatus   := 'Send';
      WHEN 'AUTO REVOKE LICENSE TYPES' THEN
        t_processname     := 'p_AutoRevokeLicenseType';
        a_processname     := 'Automatically Revoke License Type';
        a_processstatus   := 'Revoke';
      WHEN '50% PENALTY' THEN
        t_processname     := 'p_Assess50Penalty';
        a_processname     := 'Assess 50% Penalty';
        a_processstatus   := 'Assess';
      WHEN '100% PENALTY' THEN
        t_processname     := 'p_Assess100Penalty';
        a_processname     := 'Assess 100% Penalty';
        a_processstatus   := 'Assess';
      ELSE
        api.pkg_errors.raiseerror(-20000, 'Unexpected batch type.');
      END CASE;

      a_processdefid   := api.pkg_configquery.objectdefidforname(t_processname);
    END getprocesstypeforbatch;

    /* *********************************************************************************************
       * TESTLogging
       ***********************************************************************************************/
    /*procedure TESTLogging ( a_Message   varchar2
    ) is
      PRAGMA AUTONOMOUS_TRANSACTION;
    begin
     insert into sitespecific.loggingtest_t values(a_Message);
     commit;
    end testlogging;*/

    /**********************************************************************************************
     * BatchLogging
     ***********************************************************************************************/
    PROCEDURE batchlogging(
      a_jobid         udt_id,
      a_processid     udt_id,
      a_message       VARCHAR2,
      a_totalexpectedcount NUMBER
    )
    IS
      t_currtime   VARCHAR2(100);
      t_logrowid   NUMBER(9);

      PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
      t_currtime   := TO_CHAR(SYSDATE, 'MM-DD-YYYY HH:MI:SS AM');

      SELECT sitespecific.licensebatchlogging_s.NEXTVAL INTO t_logrowid FROM DUAL;

      INSERT INTO sitespecific.licensebatchlogging_t
      VALUES (
        t_logrowid,
        a_jobid,
        a_processid,
        t_currtime,
        a_message,
        a_totalexpectedcount
      );

      COMMIT;
    END batchlogging;

    /* *********************************************************************************************
     * Send Notification Records
     ***********************************************************************************************/
    PROCEDURE sendnotifications
    IS
      t_emailid   udt_id;
    BEGIN
      FOR x IN (
        SELECT 
          processid,
          fromaddress,
          toaddress,
          subject,
          body,
          ccaddress
        FROM extension.notifcations_t n
        WHERE n.sentdate IS NULL
      )
      LOOP
        t_emailid := extension.pkg_sendmail.send(
          x.fromaddress,  --fromaddress
          x.toaddress,  --ToAddress
          x.subject,  --Subject
          x.body,  --Body
          NULL,  --[Mimetype]
          1,  --[priority] --1 means high priority
          x.ccaddress,  --[ccaddress]
          NULL,  --[bccaddress]
          x.body,  --[message]
          NULL  --a_RelatedObjectId--[relatedobjectid]
        );

        UPDATE extension.notifcations_t
        SET sentdate   = SYSDATE
        WHERE processid = x.processid
          AND sentdate IS NULL;
      END LOOP;
    END sendnotifications;
END pkg_batchtype;
/


GRANT EXECUTE ON SITESPECIFIC.PKG_BATCHTYPE TO EXTENSION;

GRANT EXECUTE, DEBUG ON SITESPECIFIC.PKG_BATCHTYPE TO KAURP;

GRANT EXECUTE, DEBUG ON SITESPECIFIC.PKG_BATCHTYPE TO LORDT;

GRANT EXECUTE ON SITESPECIFIC.PKG_BATCHTYPE TO POSSEEXTENSIONS;
