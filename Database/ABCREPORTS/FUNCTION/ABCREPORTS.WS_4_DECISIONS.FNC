CREATE OR REPLACE FUNCTION ABCREPORTS.ws_4_decisions(
    p_parms        IN OUT t_parameters,
    p_status_ind   IN OUT VARCHAR2)
    RETURN BLOB
IS
    -- ****************************************************************************
    -- File:        WS_4_DECISIONS.FNC
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

    FUNCTION get_data(p_value        IN OUT CLOB,
                      p_start_date   IN     DATE,
                      p_end_date     IN     DATE,
                      p_status_msg   IN OUT VARCHAR2)
        RETURN BOOLEAN
    IS
        g_switch       DATE := '01-AUG-18'; -- start date to start using docket notes
        g_max          DATE := TO_DATE('21990101', 'YYYYMMDD');

        ln_value       NUMBER;
    BEGIN
        --Proposed Decisions Adopted
        SELECT COUNT(objectid)     prodecadopt
          INTO ln_value
          FROM (SELECT DISTINCT rdd.jobid     objectid
                  FROM mart.recorddirectordicision rdd
                 WHERE TRUNC(rdd.datecompleted) BETWEEN CASE
                                                            WHEN p_start_date <
                                                                 g_switch
                                                            THEN
                                                                p_start_date
                                                            ELSE
                                                                g_max
                                                        END
                                                    AND CASE
                                                            WHEN p_start_date >=
                                                                 g_switch
                                                            THEN
                                                                g_max
                                                            WHEN p_end_date >=
                                                                 g_switch
                                                            THEN
                                                                g_switch - 1
                                                            ELSE
                                                                p_end_date
                                                        END
                   AND rdd.outcome = 'Adopt'
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
                           ('33', 'ACC39', 'PRT18'));

        DBMS_LOB.append(
            p_value,
            '"","Proposed Decisions Adopted",'
            || NVL(ln_value, 0)
            || CHR(13)
            || CHR(10));


        --Proposed Decisions Rejected under 11517(c)
        SELECT COUNT(objectid)     prodecreject
          INTO ln_value
          FROM (SELECT rdd.jobid     objectid
                  FROM mart.recorddirectordicision rdd
                 WHERE TRUNC(rdd.datecompleted) BETWEEN CASE
                                                            WHEN p_start_date <
                                                                 g_switch
                                                            THEN
                                                                p_start_date
                                                            ELSE
                                                                g_max
                                                        END
                                                    AND CASE
                                                            WHEN p_start_date >=
                                                                 g_switch
                                                            THEN
                                                                g_max
                                                            WHEN p_end_date >=
                                                                 g_switch
                                                            THEN
                                                                g_switch - 1
                                                            ELSE
                                                                p_end_date
                                                        END
                   AND rdd.outcome = 'Reject'
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
                           ('ACC31', 'PRT22'));

        DBMS_LOB.append(
            p_value,
            '"","Proposed Decisions Rejected Under Section 11517(c)",'
            || NVL(ln_value, 0)
            || CHR(13)
            || CHR(10));

        --Suspensions (Definition: OLS receives 122)
        SELECT COUNT(DISTINCT o.objectid)     suspensions
          INTO ln_value
          FROM TABLE(
                   CAST(
                       api.pkg_simplesearch.castableobjectsbyindexrange(
                           'l_DocketNoteUserLog',
                           'logdate',
                           TO_CHAR(p_start_date, 'YYYY-MM-DD'),
                           TO_CHAR(p_end_date, 'YYYY-MM-DD'))
                           AS api.udt_objectlist)) o
         WHERE api.pkg_columnquery.VALUE(o.objectid, 'eventcode') IN
                   ('34', 'ACC36');

        DBMS_LOB.append(
            p_value,
            '"","Suspensions",'
            || NVL(ln_value, 0)
            || CHR(13)
            || CHR(10));

        --Revocations Including Those Stayed
        SELECT COUNT(objectid)     revocations
          INTO ln_value
          FROM (SELECT etd.jobid     objectid
                  FROM mart.executetermsofdecision etd
                 WHERE TRUNC(etd.datecompleted) BETWEEN CASE
                                                            WHEN p_start_date <
                                                                 g_switch
                                                            THEN
                                                                p_start_date
                                                            ELSE
                                                                g_max
                                                        END
                                                    AND CASE
                                                            WHEN p_start_date >=
                                                                 g_switch
                                                            THEN
                                                                g_max
                                                            WHEN p_end_date >=
                                                                 g_switch
                                                            THEN
                                                                g_switch - 1
                                                            ELSE
                                                                p_end_date
                                                        END
                   AND (etd.outcome = 'Revoked'
                     OR etd.outcome = 'Revocation Stayed')
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
                 WHERE api.pkg_columnquery.VALUE(o.objectid, 'eventcode') =
                       'ACC34');

        DBMS_LOB.append(
            p_value,
            '"","Revocations Including Those Stayed",'
            || NVL(ln_value, 0)
            || CHR(13)
            || CHR(10));


        --Appeals Filed to Appeals Board
        SELECT COUNT(objectid)     appealsfiled
          INTO ln_value
          FROM (SELECT r.jobid     objectid
                  FROM api.processes r
                 WHERE r.processid IN
                           (SELECT processid
                              FROM query.p_receivenoticeofappeal n
                             WHERE n.scheduledstartdate BETWEEN CASE
                                                                    WHEN p_start_date <
                                                                         g_switch
                                                                    THEN
                                                                        p_start_date
                                                                    ELSE
                                                                        g_max
                                                                END
                                                            AND CASE
                                                                    WHEN p_start_date >=
                                                                         g_switch
                                                                    THEN
                                                                        g_max
                                                                    WHEN p_end_date >=
                                                                         g_switch
                                                                    THEN
                                                                          g_switch
                                                                        - 1
                                                                    ELSE
                                                                        p_end_date
                                                                END)
                   AND outcome = 'Receive'
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
                           ('APL01', 'APP01'));

        DBMS_LOB.append(
            p_value,
            '"","APPEALS FILED TO APPEALS BOARD",'
            || NVL(ln_value, 0)
            || CHR(13)
            || CHR(10));

        --Court Actions Filed/Pending
        SELECT COUNT(DISTINCT o.objectid)     actionsfiledpending
          INTO ln_value
          FROM TABLE(
                   CAST(
                       api.pkg_simplesearch.castableobjectsbyindexrange(
                           'l_DocketNoteUserLog',
                           'logdate',
                           TO_CHAR(p_start_date, 'YYYY-MM-DD'),
                           TO_CHAR(p_end_date, 'YYYY-MM-DD'))
                           AS api.udt_objectlist)) o
         WHERE api.pkg_columnquery.VALUE(o.objectid, 'eventcode') = 'APP16';

        DBMS_LOB.append(
            p_value,
            '"*","COURT ACTIONS FILED/PENDING",'
            || NVL(ln_value, 0)
            || CHR(13)
            || CHR(10));

        -- Stipulation and Waiver Received After ATTY Assignment
        SELECT COUNT(DISTINCT o.objectid)     swatty
          INTO ln_value
          FROM TABLE(
                   CAST(
                       api.pkg_simplesearch.castableobjectsbyindexrange(
                           'l_DocketNoteUserLog',
                           'logdate',
                           TO_CHAR(p_start_date, 'YYYY-MM-DD'),
                           TO_CHAR(p_end_date, 'YYYY-MM-DD'))
                           AS api.udt_objectlist)) o
         WHERE api.pkg_columnquery.VALUE(o.objectid, 'eventcode') IN
                   ('16A', 'ACC16');

        DBMS_LOB.append(
            p_value,
            '"","Stip and Waiver Received after ATTY Assignment",'
            || NVL(ln_value, 0)
            || CHR(13)
            || CHR(10)
            || CHR(13)
            || CHR(10));
            
        DBMS_LOB.append(
            p_value,
            '"*","Due to the automation of this category, data prior to August 01, 2018 will not be reflected in this total.",'
            || CHR(13)
            || CHR(10));


        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_status_msg :=
                'ws_4_decisions.get_data: '
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
                          p_source    => 'Workload Summary Decisions Report',
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
                p_source    => 'ws_4_decisions',
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
