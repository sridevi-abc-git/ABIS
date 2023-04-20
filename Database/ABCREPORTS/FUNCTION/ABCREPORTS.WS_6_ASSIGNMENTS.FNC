CREATE OR REPLACE FUNCTION ABCREPORTS.ws_6_assignments(
    p_parms        IN OUT t_parameters,
    p_status_ind   IN OUT VARCHAR2)
    RETURN BLOB
IS
    -- ****************************************************************************
    -- File:        WS_6_ASSIGNMENTS.FNC
    -- Author:      Timothy J. Lord
    --
    -- Description:
    --              ASSIGNMENTS (ABC-61)
    --
    -- History:
    -------------------------------------------------------------------------------
    --    Date                  Comment
    --  09/08/2022  TJL   - Function created
    -- ****************************************************************************

    FUNCTION get_data(p_value        IN OUT CLOB,
                      p_start_date   IN     DATE,
                      p_end_date     IN     DATE,
                      p_status_msg   IN OUT VARCHAR2)
        RETURN BOOLEAN
    IS
        ln_licensingreceived NUMBER := 0;
        ln_licensingcompleted NUMBER := 0;
        ln_licensingpendingending NUMBER := 0;
        ln_investigationreceived NUMBER := 0;
        ln_investigationcompleted NUMBER := 0;
        ln_investigationpendingending NUMBER := 0;
        ln_administrativereceived NUMBER := 0;
        ln_administrativecompleted NUMBER := 0;
        ln_administrativependingending NUMBER := 0;
        ln_policereportreceived NUMBER := 0;
        ln_policereportcompleted NUMBER := 0;
        ln_policereportpendingending NUMBER := 0;
        ln_tracereceived NUMBER := 0;
        ln_tracecompleted NUMBER := 0;
        ln_tracependingending NUMBER := 0;

        ln_licensingreceived_ttl NUMBER := 0;
        ln_licensingcompleted_ttl NUMBER := 0;
        ln_licensingpendingending_ttl NUMBER := 0;
        ln_investreceived_ttl NUMBER := 0;
        ln_investcompleted_ttl NUMBER := 0;
        ln_investpendingending_ttl NUMBER := 0;
        ln_adminreceived_ttl NUMBER := 0;
        ln_admincompleted_ttl NUMBER := 0;
        ln_adminpendingending_ttl NUMBER := 0;
        ln_policereportreceived_ttl NUMBER := 0;
        ln_policereportcompleted_ttl NUMBER := 0;
        ln_policereppendingending_ttl NUMBER := 0;
        ln_tracereceived_ttl NUMBER := 0;
        ln_tracecompleted_ttl NUMBER := 0;
        ln_tracependingending_ttl NUMBER := 0;
    BEGIN
        FOR rec
            IN (WITH
                    info
                    AS
                        (  SELECT UPPER(SUBSTR(officename, 1, 20))
                                      officename,
                                  CASE
                                      WHEN NVL(rqsexclude, 'N') NOT IN
                                               ('H', 'B')
                                      THEN
                                          UPPER(NVL(division, 'HEADQUARTERS'))
                                      ELSE
                                          'HEADQUARTERS'
                                  END
                                      division,
                                  NVL(licasrecd.recd, 0)
                                      AS licensingreceived,
                                  NVL(licascompd.compd, 0)
                                      AS licensingcompleted,
                                  NVL(licaspend.pend, 0)
                                      AS licensingpendingending,
                                  NVL(recd.recdcomplaint, 0)
                                      AS investigationreceived,
                                  NVL(compd.compdcomplaint, 0)
                                      AS investigationcompleted,
                                  NVL(pend.pendcomplaint, 0)
                                      AS investigationpendingending,
                                  NVL(recd.recdadministrative, 0)
                                      AS administrativereceived,
                                  NVL(compd.compdministrative, 0)
                                      AS administrativecompleted,
                                  NVL(pend.pendministrative, 0)
                                      AS administrativependingending,
                                  NVL(recd.recdpolicereport, 0)
                                      AS policereportreceived,
                                  NVL(compd.compdpolicereport, 0)
                                      AS policereportcompleted,
                                  NVL(pend.pendpolicereport, 0)
                                      AS policereportpendingending,
                                  NVL(recd.recdtrace, 0)
                                      AS tracereceived,
                                  NVL(compd.compdtrace, 0)
                                      AS tracecompleted,
                                  NVL(pend.pendtrace, 0)
                                      AS tracependingending
                             FROM query.o_office o
                                  ------------------------------------------------------------------------------------------------
                                  -- LICENSING Received
                                  ------------------------------------------------------------------------------------------------
                                  LEFT OUTER JOIN
                                  (  SELECT a.districtofficeidcorral,
                                            COUNT(a.objectid)     recd
                                       FROM mart.licensingassignment a
                                      WHERE a.createddate BETWEEN p_start_date
                                                              AND p_end_date
                                        AND NVL(a.droppartner, 'N') = 'N'
                                        AND NVL(a.haslicensetype79, 'N') = 'N'
                                        AND NVL(a.haslicensetype84, 'N') = 'N'
                                   GROUP BY a.districtofficeidcorral) licasrecd
                                      ON licasrecd.districtofficeidcorral =
                                         o.objectid
                                  LEFT OUTER JOIN
                                  (  SELECT a.districtofficeidcorral,
                                            COUNT(a.objectid)     compd
                                       FROM mart.licensingassignment a
                                      WHERE TRUNC(a.datecompleted) BETWEEN p_start_date
                                                                       AND p_end_date
                                        AND NVL(a.droppartner, 'N') = 'N'
                                        AND NVL(a.haslicensetype79, 'N') = 'N'
                                        AND NVL(a.haslicensetype84, 'N') = 'N'
                                   GROUP BY a.districtofficeidcorral)
                                  licascompd
                                      ON licascompd.districtofficeidcorral =
                                         o.objectid
                                  LEFT OUTER JOIN
                                  (  SELECT a.districtofficeidcorral,
                                            COUNT(a.objectid)     pend
                                       FROM mart.assignassignment a
                                            LEFT JOIN
                                            mart.closelicensingassignment c
                                                ON c.externalfilenum =
                                                   a.externalfilenum
                                      WHERE NVL(a.droppartner, 'N') = 'N'
                                        AND NVL(a.haslicensetype79, 'N') = 'N'
                                        AND NVL(a.haslicensetype84, 'N') = 'N'
                                        AND TRUNC(a.createddate) <= p_end_date
                                        AND TRUNC(a.createddate) >
                                            TO_DATE('24-JUN-10')
                                        AND (TRUNC(a.datecompleted) > p_end_date
                                          OR a.datecompleted IS NULL
                                          OR c.datecompleted IS NULL
                                          OR TRUNC(c.datecompleted) > p_end_date)
                                   GROUP BY a.districtofficeidcorral) licaspend
                                      ON licaspend.districtofficeidcorral =
                                         o.objectid
                                  ------------------------------------------------------------------------------------------------
                                  -- Complaints Received (Complaint Investigation, Administrative, Police Report)
                                  ------------------------------------------------------------------------------------------------
                                  LEFT OUTER JOIN
                                  (  SELECT i.investigationofficeobjectid,
                                            SUM(
                                                CASE
                                                    WHEN investigationtype =
                                                         'COMPLAINT'
                                                    THEN
                                                        1
                                                    ELSE
                                                        0
                                                END)    recdcomplaint,
                                            SUM(
                                                CASE
                                                    WHEN investigationtype =
                                                         'ADMINISTRATIVE'
                                                    THEN
                                                        1
                                                    ELSE
                                                        0
                                                END)    recdadministrative,
                                            SUM(
                                                CASE
                                                    WHEN investigationtype =
                                                         'POLICE REPORT'
                                                    THEN
                                                        1
                                                    ELSE
                                                        0
                                                END)    recdpolicereport,
                                            SUM(
                                                CASE
                                                    WHEN investigationtype =
                                                         'TRACE'
                                                    THEN
                                                        1
                                                    ELSE
                                                        0
                                                END)    recdtrace
                                       FROM mart.investigation i
                                      WHERE i.investigationtype IN
                                                ('COMPLAINT',
                                                 'ADMINISTRATIVE',
                                                 'POLICE REPORT',
                                                 'TRACE')
                                        AND i.createddate BETWEEN p_start_date
                                                              AND p_end_date
                                        AND api.pkg_columnquery.VALUE(
                                                i.objectid,
                                                'StatusName') <>
                                            'CANCEL'
                                   GROUP BY i.investigationofficeobjectid) recd
                                      ON recd.investigationofficeobjectid =
                                         o.objectid
                                  ------------------------------------------------------------------------------------------------
                                  -- Completed Complaints (Complaint Investigation, Administrative, Police Report)
                                  ------------------------------------------------------------------------------------------------
                                  LEFT OUTER JOIN
                                  (  SELECT i.investigationofficeobjectid,
                                            SUM(
                                                CASE
                                                    WHEN investigationtype =
                                                         'COMPLAINT'
                                                    THEN
                                                        1
                                                    ELSE
                                                        0
                                                END)    compdcomplaint,
                                            SUM(
                                                CASE
                                                    WHEN investigationtype =
                                                         'ADMINISTRATIVE'
                                                    THEN
                                                        1
                                                    ELSE
                                                        0
                                                END)    compdministrative,
                                            SUM(
                                                CASE
                                                    WHEN investigationtype =
                                                         'POLICE REPORT'
                                                    THEN
                                                        1
                                                    ELSE
                                                        0
                                                END)    compdpolicereport,
                                            SUM(
                                                CASE
                                                    WHEN investigationtype =
                                                         'TRACE'
                                                    THEN
                                                        1
                                                    ELSE
                                                        0
                                                END)    compdtrace
                                       FROM mart.investigation i
                                      WHERE i.investigationtype IN
                                                ('COMPLAINT',
                                                 'ADMINISTRATIVE',
                                                 'POLICE REPORT',
                                                 'TRACE')
                                        AND (SELECT TRUNC(t.effectivestartdate)
                                               FROM extension.jobstatuschange_t t
                                              WHERE t.jobid = i.objectid
                                                AND t.statusname = 'CLOSED'
                                                AND t.jobstatuschangeid =
                                                    (SELECT MIN(
                                                                t.jobstatuschangeid)
                                                       FROM extension.jobstatuschange_t
                                                            t
                                                      WHERE t.jobid = i.objectid
                                                        AND t.statusname =
                                                            'CLOSED')) BETWEEN p_start_date
                                                                           AND p_end_date
                                        AND api.pkg_columnquery.VALUE(
                                                i.objectid,
                                                'StatusName') <>
                                            'CANCEL'
                                   GROUP BY i.investigationofficeobjectid)
                                  compd
                                      ON compd.investigationofficeobjectid =
                                         o.objectid
                                  ------------------------------------------------------------------------------------------------
                                  -- Pending Complaints (Complaint Investigation, Administrative, Police Report)
                                  ------------------------------------------------------------------------------------------------
                                  LEFT OUTER JOIN
                                  (  SELECT i.investigationofficeobjectid,
                                            SUM(
                                                CASE
                                                    WHEN investigationtype =
                                                         'COMPLAINT'
                                                    THEN
                                                        1
                                                    ELSE
                                                        0
                                                END)    pendcomplaint,
                                            SUM(
                                                CASE
                                                    WHEN investigationtype =
                                                         'ADMINISTRATIVE'
                                                    THEN
                                                        1
                                                    ELSE
                                                        0
                                                END)    pendministrative,
                                            SUM(
                                                CASE
                                                    WHEN investigationtype =
                                                         'POLICE REPORT'
                                                    THEN
                                                        1
                                                    ELSE
                                                        0
                                                END)    pendpolicereport,
                                            SUM(
                                                CASE
                                                    WHEN investigationtype =
                                                         'TRACE'
                                                    THEN
                                                        1
                                                    ELSE
                                                        0
                                                END)    pendtrace
                                       FROM mart.investigation i
                                      WHERE i.investigationtype IN
                                                ('COMPLAINT',
                                                 'ADMINISTRATIVE',
                                                 'POLICE REPORT',
                                                 'TRACE')
                                        AND TRUNC(i.createddate) <= p_end_date
                                        AND (i.completeddate IS NULL
                                          OR (SELECT t.effectivestartdate
                                                FROM extension.jobstatuschange_t
                                                     t
                                               WHERE t.jobid = i.objectid
                                                 AND t.statusname = 'CLOSED'
                                                 AND t.jobstatuschangeid =
                                                     (SELECT MIN(
                                                                 t.jobstatuschangeid)
                                                        FROM extension.jobstatuschange_t
                                                             t
                                                       WHERE t.jobid = i.objectid
                                                         AND t.statusname =
                                                             'CLOSED')) >
                                             p_end_date)
                                        AND api.pkg_columnquery.VALUE(
                                                i.objectid,
                                                'StatusName') <>
                                            'CANCEL'
                                   GROUP BY i.investigationofficeobjectid) pend
                                      ON pend.investigationofficeobjectid =
                                         o.objectid
                            WHERE o.isactive = 'Y'
                         ORDER BY officename)
                  SELECT i.*,
                         LEAD(i.division, 1, NULL)
                             OVER (ORDER BY i.division, i.officename)    div_next
                    FROM info i
                ORDER BY division, officename)
        LOOP
            IF (DBMS_LOB.getlength(p_value) = 0)
            THEN
                -- add first two header lines
                DBMS_LOB.append(
                    p_value,
                    '" ",'
                    || '"LICENSING ASSIGNMENTS (ABC-61)","LICENSING ASSIGNMENTS (ABC-61)","LICENSING ASSIGNMENTS (ABC-61)",'
                    || '"COMPLAINT INVESTIGATION ASSIGNMENTS (ABC-61)","COMPLAINT INVESTIGATION ASSIGNMENTS (ABC-61)","COMPLAINT INVESTIGATION ASSIGNMENTS (ABC-61)",'
                    || '"ADMINISTRATION ASSIGNMENTS (ABC-61)","ADMINISTRATION ASSIGNMENTS (ABC-61)","ADMINISTRATION ASSIGNMENTS (ABC-61)",'
                    || '"POLICE REPORTS ASSIGNED FOR INVESTIGATION (ABC-61)","POLICE REPORTS ASSIGNED FOR INVESTIGATION (ABC-61)","POLICE REPORTS ASSIGNED FOR INVESTIGATION (ABC-61)",'
                    || '"TRACE ASSIGNMENTS (ABC-61)","TRACE ASSIGNMENTS (ABC-61)","TRACE ASSIGNMENTS (ABC-61)"'
                    || CHR(13)
                    || CHR(10));

                DBMS_LOB.append(
                    p_value,
                    '"'
                    || rec.division
                    || '",'
                    || '"REC''D","COMP''D","PEND''G",'
                    || '"REC''D","COMP''D","PEND''G",'
                    || '"REC''D","COMP''D","PEND''G",'
                    || '"REC''D","COMP''D","PEND''G",'
                    || '"REC''D","COMP''D","PEND''G"'
                    || CHR(13)
                    || CHR(10));
            END IF;

            DBMS_LOB.append(
                p_value,
                '"'
                || rec.officename
                || '",'
                || rec.licensingreceived
                || ','
                || rec.licensingcompleted
                || ','
                || rec.licensingpendingending
                || ','
                || rec.investigationreceived
                || ','
                || rec.investigationcompleted
                || ','
                || rec.investigationpendingending
                || ','
                || rec.administrativereceived
                || ','
                || rec.administrativecompleted
                || ','
                || rec.administrativependingending
                || ','
                || rec.policereportreceived
                || ','
                || rec.policereportcompleted
                || ','
                || rec.policereportpendingending
                || ','
                || rec.tracereceived
                || ','
                || rec.tracecompleted
                || ','
                || rec.tracependingending
                || CHR(13)
                || CHR(10));


            -- add to division totals
            ln_licensingreceived :=
                ln_licensingreceived + rec.licensingreceived;
            ln_licensingcompleted :=
                ln_licensingcompleted + rec.licensingcompleted;
            ln_licensingpendingending :=
                ln_licensingpendingending + rec.licensingpendingending;
            ln_investigationreceived :=
                ln_investigationreceived + rec.investigationreceived;
            ln_investigationcompleted :=
                ln_investigationcompleted + rec.investigationcompleted;
            ln_investigationpendingending :=
                  ln_investigationpendingending
                + rec.investigationpendingending;
            ln_administrativereceived :=
                ln_administrativereceived + rec.administrativereceived;
            ln_administrativecompleted :=
                ln_administrativecompleted + rec.administrativecompleted;
            ln_administrativependingending :=
                  ln_administrativependingending
                + rec.administrativependingending;
            ln_policereportreceived :=
                ln_policereportreceived + rec.policereportreceived;
            ln_policereportcompleted :=
                ln_policereportcompleted + rec.policereportcompleted;
            ln_policereportpendingending :=
                ln_policereportpendingending + rec.policereportpendingending;
            ln_tracereceived := ln_tracereceived + rec.tracereceived;
            ln_tracecompleted := ln_tracecompleted + rec.tracecompleted;
            ln_tracependingending :=
                ln_tracependingending + rec.tracependingending;


            -- add to statewide totals
            ln_licensingreceived_ttl :=
                ln_licensingreceived_ttl + rec.licensingreceived;
            ln_licensingcompleted_ttl :=
                ln_licensingcompleted_ttl + rec.licensingcompleted;
            ln_licensingpendingending_ttl :=
                ln_licensingpendingending_ttl + rec.licensingpendingending;
            ln_investreceived_ttl :=
                ln_investreceived_ttl + rec.investigationreceived;
            ln_investcompleted_ttl :=
                ln_investcompleted_ttl + rec.investigationcompleted;
            ln_investpendingending_ttl :=
                ln_investpendingending_ttl + rec.investigationpendingending;
            ln_adminreceived_ttl :=
                ln_adminreceived_ttl + rec.administrativereceived;
            ln_admincompleted_ttl :=
                ln_admincompleted_ttl + rec.administrativecompleted;
            ln_adminpendingending_ttl :=
                ln_adminpendingending_ttl + rec.administrativependingending;
            ln_policereportreceived_ttl :=
                ln_policereportreceived_ttl + rec.policereportreceived;
            ln_policereportcompleted_ttl :=
                ln_policereportcompleted_ttl + rec.policereportcompleted;
            ln_policereppendingending_ttl :=
                ln_policereppendingending_ttl + rec.policereportpendingending;
            ln_tracereceived_ttl := ln_tracereceived_ttl + rec.tracereceived;
            ln_tracecompleted_ttl :=
                ln_tracecompleted_ttl + rec.tracecompleted;
            ln_tracependingending_ttl :=
                ln_tracependingending_ttl + rec.tracependingending;

            -- check if next record is the next division or last record
            --   Add division totals to report and rest division totals
            IF (rec.division != NVL(rec.div_next, 'END'))
            THEN
                -- output division totals
                DBMS_LOB.append(
                    p_value,
                    '"    '
                    || UPPER(rec.division)
                    || ' TOTALS",'
                    || ln_licensingreceived
                    || ','
                    || ln_licensingcompleted
                    || ','
                    || ln_licensingpendingending
                    || ','
                    || ln_investigationreceived
                    || ','
                    || ln_investigationcompleted
                    || ','
                    || ln_investigationpendingending
                    || ','
                    || ln_administrativereceived
                    || ','
                    || ln_administrativecompleted
                    || ','
                    || ln_administrativependingending
                    || ','
                    || ln_policereportreceived
                    || ','
                    || ln_policereportcompleted
                    || ','
                    || ln_policereportpendingending
                    || ','
                    || ln_tracereceived
                    || ','
                    || ln_tracecompleted
                    || ','
                    || ln_tracependingending
                    || CHR(13)
                    || CHR(10));

                -- clear division totals
                ln_licensingreceived := 0;
                ln_licensingcompleted := 0;
                ln_licensingpendingending := 0;
                ln_investigationreceived := 0;
                ln_investigationcompleted := 0;
                ln_investigationpendingending := 0;
                ln_administrativereceived := 0;
                ln_administrativecompleted := 0;
                ln_administrativependingending := 0;
                ln_policereportreceived := 0;
                ln_policereportcompleted := 0;
                ln_policereportpendingending := 0;
                ln_tracereceived := 0;
                ln_tracecompleted := 0;
                ln_tracependingending := 0;

                IF (rec.div_next IS NOT NULL)
                THEN
                    -- add next column headers
                    DBMS_LOB.append(
                        p_value,
                        CHR(13)
                        || CHR(10)
                        || '" ",'
                        || '"LICENSING ASSIGNMENTS (ABC-61)","LICENSING ASSIGNMENTS (ABC-61)","LICENSING ASSIGNMENTS (ABC-61)",'
                        || '"COMPLAINT INVESTIGATION ASSIGNMENTS (ABC-61)","COMPLAINT INVESTIGATION ASSIGNMENTS (ABC-61)","COMPLAINT INVESTIGATION ASSIGNMENTS (ABC-61)",'
                        || '"ADMINISTRATION ASSIGNMENTS (ABC-61)","ADMINISTRATION ASSIGNMENTS (ABC-61)","ADMINISTRATION ASSIGNMENTS (ABC-61)",'
                        || '"POLICE REPORTS ASSIGNED FOR INVESTIGATION (ABC-61)","POLICE REPORTS ASSIGNED FOR INVESTIGATION (ABC-61)","POLICE REPORTS ASSIGNED FOR INVESTIGATION (ABC-61)",'
                        || '"TRACE ASSIGNMENTS (ABC-61)","TRACE ASSIGNMENTS (ABC-61)","TRACE ASSIGNMENTS (ABC-61)"'
                        || CHR(13)
                        || CHR(10));

                    DBMS_LOB.append(
                        p_value,
                        '"'
                        || rec.div_next
                        || '",'
                        || '"REC''D","COMP''D","PEND''G",'
                        || '"REC''D","COMP''D","PEND''G",'
                        || '"REC''D","COMP''D","PEND''G",'
                        || '"REC''D","COMP''D","PEND''G",'
                        || '"REC''D","COMP''D","PEND''G"'
                        || CHR(13)
                        || CHR(10));
                END IF;
            END IF;
        END LOOP;

        DBMS_LOB.append(
            p_value,
            CHR(13)
            || CHR(10)
            || '"    STATEWIDE TOTALS",'
            || ln_licensingreceived_ttl
            || ','
            || ln_licensingcompleted_ttl
            || ','
            || ln_licensingpendingending_ttl
            || ','
            || ln_investreceived_ttl
            || ','
            || ln_investcompleted_ttl
            || ','
            || ln_investpendingending_ttl
            || ','
            || ln_adminreceived_ttl
            || ','
            || ln_admincompleted_ttl
            || ','
            || ln_adminpendingending_ttl
            || ','
            || ln_policereportreceived_ttl
            || ','
            || ln_policereportcompleted_ttl
            || ','
            || ln_policereppendingending_ttl
            || ','
            || ln_tracereceived_ttl
            || ','
            || ln_tracecompleted_ttl
            || ','
            || ln_tracependingending_ttl
            || CHR(13)
            || CHR(10));

        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_status_msg :=
                'ws_6_assignments.get_data: '
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
                          p_source    => 'Workload Summary Report',
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
                p_source    => 'ws_6_assignments',
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
