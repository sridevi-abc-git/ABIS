CREATE OR REPLACE FUNCTION ABCREPORTS.ws_5_investigations(
    p_parms        IN OUT t_parameters,
    p_status_ind   IN OUT VARCHAR2)
    RETURN BLOB
IS
    -- ****************************************************************************
    -- File:        WS_5_INVESTIGATIONS.FNC
    -- Author:      Timothy J. Lord
    --
    -- Description:
    --              APPLICATION AND LICENSING INVESTIGATIONS
    --
    -- History:
    -------------------------------------------------------------------------------
    --    Date                  Comment
    --  09/12/2022  TJL   - Function created
    -- ****************************************************************************

    FUNCTION get_data(p_value        IN OUT CLOB,
                      p_start_date   IN     DATE,
                      p_end_date     IN     DATE,
                      p_status_msg   IN OUT VARCHAR2)
        RETURN BOOLEAN
    IS
        lc_trans       CLOB;
        -- Originals
        ln_received    NUMBER := 0;
        ln_receivedoriginal NUMBER := 0;
        ln_completedoriginal NUMBER := 0;
        ln_approvedoriginal NUMBER := 0;
        ln_deniedoriginal NUMBER := 0;
        ln_withdrawnoriginal NUMBER := 0;
        ln_voidedoriginal NUMBER := 0;
        ln_nocreditwthdoriginal NUMBER := 0;
        ln_pendoriginal NUMBER := 0;

        -- Transfers
        ln_receivedpertoper NUMBER := 0;
        ln_completedpertoper NUMBER := 0;
        ln_approvedpertoper NUMBER := 0;
        ln_deniedpertoper NUMBER := 0;
        ln_withdrawnpertoper NUMBER := 0;
        ln_voidedpertoper NUMBER := 0;
        ln_nocreditwthdpertoper NUMBER := 0;
        ln_pendingpertoper NUMBER := 0;

        -- Protests
        ln_priorityrecd NUMBER := 0;
        ln_proapps     NUMBER := 0;
        ln_regpro      NUMBER := 0;
        ln_regpet      NUMBER := 0;
        ln_totalpetpro NUMBER := 0;

        -----------------------------------------
        -- Originals State Totals
        ln_received_ttl NUMBER := 0;
        ln_receivedoriginal_ttl NUMBER := 0;
        ln_completedoriginal_ttl NUMBER := 0;
        ln_approvedoriginal_ttl NUMBER := 0;
        ln_deniedoriginal_ttl NUMBER := 0;
        ln_withdrawnoriginal_ttl NUMBER := 0;
        ln_voidedoriginal_ttl NUMBER := 0;
        ln_nocreditwthdoriginal_ttl NUMBER := 0;
        ln_pendoriginal_ttl NUMBER := 0;

        -- Transfers State Totals
        ln_receivedpertoper_ttl NUMBER := 0;
        ln_completedpertoper_ttl NUMBER := 0;
        ln_approvedpertoper_ttl NUMBER := 0;
        ln_deniedpertoper_ttl NUMBER := 0;
        ln_withdrawnpertoper_ttl NUMBER := 0;
        ln_voidedpertoper_ttl NUMBER := 0;
        ln_nocreditwthdpertoper_ttl NUMBER := 0;
        ln_pendingpertoper_ttl NUMBER := 0;

        -- Protests State Totals
        ln_priorityrecd_ttl NUMBER := 0;
        ln_proapps_ttl NUMBER := 0;
        ln_regpro_ttl  NUMBER := 0;
        ln_regpet_ttl  NUMBER := 0;
        ln_totalpetpro_ttl NUMBER := 0;
        lv_heading_orig VARCHAR2(4000)
            := '"TOTAL APPLICATIONS REC''D(211''S)",'
               || '"ORIGINALS (220''S) RECEIVED","ORIGINALS (220''S) COMP''D","ORIGINALS (220''S) APPROVED","ORIGINALS (220''S) DENIED",'
               || '"ORIGINALS (220''S) WITHDRAWN","ORIGINALS (220''S) VOIDED","ORIGINALS (220''S) NO CREDIT WD","ORIGINALS (220''S) PENDING"';
        lv_heading_trans VARCHAR2(4000)
            := '" ",'
               || '"TRANSFERS (220''S) RECEIVED","TRANSFERS (220''S) COMP''D","TRANSFERS (220''S) APPROVED","TRANSFERS (220''S) DENIED",'
               || '"TRANSFERS (220''S) WITHDRAWN","TRANSFERS (220''S) VOIDED","TRANSFERS (220''S) NO CREDIT WD","TRANSFERS (220''S) PENDING"';
        lv_heading_prot VARCHAR2(4000) := '"PRIORITY RECEIVED","PROTESTED APPLICATIONS","PROTESTS FILED","PETITION FILED","PETITION / PROTEST"';
    BEGIN
        DBMS_LOB.createtemporary(lob_loc     => lc_trans,
                                 cache       => TRUE,
                                 dur         => DBMS_LOB.session);


        -- Application and Licensing Investigations
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
                                  NVL(received, 0)
                                      received,
                                  NVL(pendbegoriginal, 0)
                                      pendbegoriginal,
                                  NVL(receivedoriginal, 0)
                                      receivedoriginal,
                                  NVL(approvedoriginal, 0)
                                      approvedoriginal,
                                  NVL(deniedoriginal, 0)
                                      deniedoriginal,
                                  NVL(withdrawnoriginal, 0)
                                      withdrawnoriginal,
                                  NVL(voidedoriginal, 0)
                                      voidedoriginal,
                                  NVL(nocreditwthdoriginal, 0)
                                      nocreditwthdoriginal,
                                  NVL(pendbegpertoper, 0)
                                      pendbegpertoper,
                                  NVL(receivedpertoper, 0)
                                      receivedpertoper,
                                  NVL(approvedpertoper, 0)
                                      approvedpertoper,
                                  NVL(deniedpertoper, 0)
                                      deniedpertoper,
                                  NVL(withdrawnpertoper, 0)
                                      withdrawnpertoper,
                                  NVL(voidedpertoper, 0)
                                      voidedpertoper,
                                  NVL(nocreditwthdpertoper, 0)
                                      nocreditwthdpertoper
                             FROM query.o_office o
                                  ------------------------------------------------------------------------------------------------
                                  -- Pending Begining
                                  ------------------------------------------------------------------------------------------------
                                  LEFT OUTER JOIN
                                  (  SELECT basefileofficeid,
                                            SUM(
                                                CASE
                                                    WHEN abc19original =
                                                         'Y'
                                                    THEN
                                                        1
                                                    ELSE
                                                        0
                                                END)    pendbegoriginal,
                                            SUM(CASE
                                                    WHEN abc19original != 'Y'
                                                     AND abc19pertoper = 'Y'
                                                    THEN
                                                        1
                                                    ELSE
                                                        0
                                                END)    pendbegpertoper
                                       FROM mart.application a
                                      WHERE a.haslicensetype79 = 'N'
                                        AND a.haslicensetype84 = 'N'
                                        AND TRUNC(
                                                a.enterapplicationcompleteddate) <
                                            p_start_date
                                        AND EXISTS
                                                (SELECT 1
                                                   FROM extension.jobstatuschange
                                                        j
                                                  WHERE j.jobid = a.objectid
                                                    AND j.statusname IN
                                                            ('PEND',
                                                             'APPLD',
                                                             'ISSUPD')
                                                    AND (TRUNC(
                                                             j.effectivestartdate) <
                                                         p_start_date
                                                     AND (j.effectiveenddate
                                                              IS NULL
                                                       OR TRUNC(
                                                              j.effectiveenddate) >=
                                                          p_start_date)))
                                        AND (TRUNC(a.districtappreviewprocdate) >=
                                             p_start_date
                                          OR (TRUNC(a.districtappreviewprocdate)
                                                  IS NULL
                                          AND EXISTS
                                                  (SELECT 1
                                                     FROM extension.jobstatuschange
                                                          j
                                                    WHERE j.jobid = a.objectid
                                                      AND j.statusname IN
                                                              ('PEND',
                                                               'APPLD',
                                                               'ISSUPD')
                                                      AND (TRUNC(
                                                               j.effectivestartdate) <
                                                           p_start_date
                                                       AND (j.effectiveenddate
                                                                IS NULL
                                                         OR TRUNC(
                                                                j.effectiveenddate) >=
                                                            p_start_date)))
                                          AND NOT EXISTS
                                                  (SELECT 1
                                                     FROM extension.jobstatuschange
                                                          j
                                                    WHERE j.jobid = a.objectid
                                                      AND j.statusname IN
                                                              ('ISSUED',
                                                               'DENIED',
                                                               'WTHDRN',
                                                               'VOIDED')
                                                      AND (TRUNC(
                                                               j.effectivestartdate) <
                                                           p_start_date
                                                       AND (j.effectiveenddate
                                                                IS NULL
                                                         OR TRUNC(
                                                                j.effectiveenddate) >=
                                                            p_start_date)))))
                                   GROUP BY basefileofficeid) pendingbegining
                                      ON pendingbegining.basefileofficeid =
                                         o.objectid
                                  -------------------------------------------------------------------------------------------------------------
                                  -- Received, Received Original, and Received Per to Per
                                  -------------------------------------------------------------------------------------------------------------
                                  LEFT OUTER JOIN
                                  (  SELECT a.basefileofficeid,
                                            SUM(
                                                CASE
                                                    WHEN a.abc19original =
                                                         'Y'
                                                      OR a.abc19pertoper =
                                                         'Y'
                                                    THEN
                                                        1
                                                    ELSE
                                                        0
                                                END)    received,
                                            SUM(
                                                CASE
                                                    WHEN a.abc19original =
                                                         'Y'
                                                    THEN
                                                        1
                                                    ELSE
                                                        0
                                                END)    receivedoriginal,
                                            SUM(CASE
                                                    WHEN a.abc19original != 'Y'
                                                     AND a.abc19pertoper = 'Y'
                                                    THEN
                                                        1
                                                    ELSE
                                                        0
                                                END)    receivedpertoper
                                       FROM mart.application a
                                      WHERE a.haslicensetype79 = 'N'
                                        AND a.haslicensetype84 = 'N'
                                        AND a.statusname <> 'NEW'
                                        AND a.abc19apptype IS NOT NULL
                                        AND TRUNC(enterapplicationcompleteddate) BETWEEN p_start_date
                                                                                     AND p_end_date
                                   GROUP BY a.basefileofficeid) abcr
                                      ON abcr.basefileofficeid = o.objectid
                                  -------------------------------------------------------------------------------------------------------------
                                  -- Approved Original and Per to Per
                                  -------------------------------------------------------------------------------------------------------------
                                  LEFT OUTER JOIN
                                  (  SELECT basefileofficeid,
                                            SUM(
                                                CASE
                                                    WHEN abc19original =
                                                         'Y'
                                                    THEN
                                                        1
                                                    ELSE
                                                        0
                                                END)    approvedoriginal,
                                            SUM(CASE
                                                    WHEN abc19original != 'Y'
                                                     AND abc19pertoper = 'Y'
                                                    THEN
                                                        1
                                                    ELSE
                                                        0
                                                END)    approvedpertoper
                                       FROM (SELECT a.basefileofficeid,
                                                    a.abc19original,
                                                    a.abc19pertoper
                                               FROM mart.districtapplicationreview
                                                    d
                                                    JOIN mart.application a
                                                        ON a.objectid = d.jobid
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
                                                             FROM mart.districtapplicationreview
                                                                  d1
                                                            WHERE d1.jobid =
                                                                  d.jobid
                                                         GROUP BY d1.jobid)
                                             UNION ALL
                                             SELECT a.basefileofficeid,
                                                    a.abc19original,
                                                    a.abc19pertoper
                                               FROM mart.issuelicense p
                                                    JOIN mart.application a
                                                        ON a.objectid = p.jobid
                                              WHERE a.haslicensetype79 = 'N'
                                                AND a.haslicensetype84 = 'N'
                                                AND datecompleted BETWEEN p_start_date
                                                                      AND p_end_date
                                                AND p.outcome IS NOT NULL
                                                AND EXISTS
                                                        (SELECT 1
                                                           FROM extension.jobstatuschange_t
                                                                j
                                                          WHERE j.jobid =
                                                                a.objectid
                                                            AND j.statusname =
                                                                'ISSUED'
                                                            AND TRUNC(
                                                                    j.effectivestartdate) BETWEEN p_start_date
                                                                                              AND p_end_date)
                                                AND p.objectid IN
                                                        (  SELECT MIN(p2.objectid)
                                                             FROM mart.issuelicense
                                                                  p2
                                                            WHERE p2.jobid =
                                                                  a.objectid
                                                         GROUP BY p2.jobid)
                                                AND NOT EXISTS
                                                        (SELECT 1
                                                           FROM mart.districtapplicationreview
                                                                d
                                                          WHERE d.jobid =
                                                                a.objectid
                                                            AND d.outcome
                                                                    IS NOT NULL))
                                   GROUP BY basefileofficeid) approved
                                      ON approved.basefileofficeid = o.objectid
                                  -------------------------------------------------------------------------------------------------------------
                                  -- Denied Original and Per to Per
                                  -------------------------------------------------------------------------------------------------------------
                                  LEFT OUTER JOIN
                                  (  SELECT basefileofficeid,
                                            SUM(
                                                CASE
                                                    WHEN abc19original =
                                                         'Y'
                                                    THEN
                                                        1
                                                    ELSE
                                                        0
                                                END)    deniedoriginal,
                                            SUM(CASE
                                                    WHEN abc19original != 'Y'
                                                     AND abc19pertoper = 'Y'
                                                    THEN
                                                        1
                                                    ELSE
                                                        0
                                                END)    deniedpertoper
                                       FROM (SELECT a.basefileofficeid,
                                                    a.abc19original,
                                                    a.abc19pertoper
                                               FROM mart.districtapplicationreview
                                                    d
                                                    JOIN mart.application a
                                                        ON a.objectid = d.jobid
                                              WHERE d.haslicensetype79 = 'N'
                                                AND d.haslicensetype84 = 'N'
                                                AND d.datecompleted BETWEEN p_start_date
                                                                        AND p_end_date
                                                AND d.outcome =
                                                    'Deny With Division Review'
                                                AND d.objectid IN
                                                        (  SELECT MIN(d1.objectid)
                                                             FROM mart.districtapplicationreview
                                                                  d1
                                                            WHERE d1.jobid =
                                                                  d.jobid
                                                         GROUP BY d1.jobid)
                                             UNION ALL
                                             SELECT a.basefileofficeid,
                                                    a.abc19original,
                                                    a.abc19pertoper
                                               FROM mart.recorddirectordicision p
                                                    JOIN mart.application a
                                                        ON a.objectid = p.jobid
                                              WHERE a.haslicensetype79 = 'N'
                                                AND a.haslicensetype84 = 'N'
                                                AND p.datecompleted BETWEEN p_start_date
                                                                        AND p_end_date
                                                AND p.outcome IS NOT NULL
                                                AND EXISTS
                                                        (SELECT 1
                                                           FROM extension.jobstatuschange_t
                                                                j
                                                          WHERE j.jobid =
                                                                a.objectid
                                                            AND j.statusname =
                                                                'DENIED'
                                                            AND TRUNC(
                                                                    j.effectivestartdate) BETWEEN p_start_date
                                                                                              AND p_end_date)
                                                AND p.objectid IN
                                                        (  SELECT MIN(p2.objectid)
                                                             FROM mart.recorddirectordicision
                                                                  p2
                                                            WHERE p2.jobid =
                                                                  a.objectid
                                                         GROUP BY p2.jobid)
                                                AND NOT EXISTS
                                                        (SELECT 1
                                                           FROM mart.districtapplicationreview
                                                                d
                                                          WHERE d.jobid =
                                                                a.objectid
                                                            AND d.outcome
                                                                    IS NOT NULL))
                                   GROUP BY basefileofficeid) denied
                                      ON denied.basefileofficeid = o.objectid
                                  -------------------------------------------------------------------------------------------------------------
                                  -- Withdrawn Original and Per to Per
                                  -------------------------------------------------------------------------------------------------------------
                                  LEFT OUTER JOIN
                                  (  SELECT basefileofficeid,
                                            SUM(
                                                CASE
                                                    WHEN abc19original =
                                                         'Y'
                                                    THEN
                                                        1
                                                    ELSE
                                                        0
                                                END)    withdrawnoriginal,
                                            SUM(CASE
                                                    WHEN abc19original != 'Y'
                                                     AND abc19pertoper = 'Y'
                                                    THEN
                                                        1
                                                    ELSE
                                                        0
                                                END)    withdrawnpertoper
                                       FROM (SELECT a.basefileofficeid,
                                                    a.abc19original,
                                                    a.abc19pertoper
                                               FROM mart.districtapplicationreview
                                                    d
                                                    JOIN mart.application a
                                                        ON a.objectid = d.jobid
                                              WHERE d.haslicensetype79 = 'N'
                                                AND d.haslicensetype84 = 'N'
                                                AND d.datecompleted BETWEEN p_start_date
                                                                        AND p_end_date
                                                AND d.outcome = 'Withdraw'
                                                AND a.enterapplicationcompleteddate
                                                        IS NOT NULL
                                                AND d.objectid IN
                                                        (  SELECT MIN(d1.objectid)
                                                             FROM mart.districtapplicationreview
                                                                  d1
                                                            WHERE d1.jobid =
                                                                  d.jobid
                                                         GROUP BY d1.jobid)
                                             UNION ALL
                                             SELECT a.basefileofficeid,
                                                    a.abc19original,
                                                    a.abc19pertoper
                                               FROM mart.withdrawapplication p
                                                    JOIN mart.application a
                                                        ON a.objectid = p.jobid
                                              WHERE a.haslicensetype79 = 'N'
                                                AND a.haslicensetype84 = 'N'
                                                AND p.datecompleted BETWEEN p_start_date
                                                                        AND p_end_date
                                                AND p.outcome IS NOT NULL
                                                AND a.enterapplicationcompleteddate
                                                        IS NOT NULL
                                                AND EXISTS
                                                        (SELECT 1
                                                           FROM extension.jobstatuschange_t
                                                                j
                                                          WHERE j.jobid =
                                                                a.objectid
                                                            AND j.statusname =
                                                                'WTHDRN'
                                                            AND TRUNC(
                                                                    j.effectivestartdate) BETWEEN p_start_date
                                                                                              AND p_end_date)
                                                AND p.objectid IN
                                                        (  SELECT MIN(p2.objectid)
                                                             FROM mart.withdrawapplication
                                                                  p2
                                                            WHERE p2.jobid =
                                                                  a.objectid
                                                         GROUP BY p2.jobid)
                                                AND NOT EXISTS
                                                        (SELECT 1
                                                           FROM mart.districtapplicationreview
                                                                d
                                                          WHERE d.jobid =
                                                                a.objectid
                                                            AND d.outcome
                                                                    IS NOT NULL))
                                   GROUP BY basefileofficeid) withdrawn
                                      ON withdrawn.basefileofficeid =
                                         o.objectid
                                  -------------------------------------------------------------------------------------------------------------
                                  -- Voided Original and Per to Per
                                  -------------------------------------------------------------------------------------------------------------
                                  LEFT OUTER JOIN
                                  (  SELECT basefileofficeid,
                                            SUM(
                                                CASE
                                                    WHEN abc19original =
                                                         'Y'
                                                    THEN
                                                        1
                                                    ELSE
                                                        0
                                                END)    voidedoriginal,
                                            SUM(CASE
                                                    WHEN abc19original != 'Y'
                                                     AND abc19pertoper = 'Y'
                                                    THEN
                                                        1
                                                    ELSE
                                                        0
                                                END)    voidedpertoper
                                       FROM mart.application a
                                      WHERE a.haslicensetype79 = 'N'
                                        AND a.haslicensetype84 = 'N'
                                        AND EXISTS
                                                (SELECT 1
                                                   FROM extension.jobstatuschange
                                                        j
                                                  WHERE j.jobid = a.objectid
                                                    AND j.statusname = 'VOIDED'
                                                    AND j.effectivestartdate BETWEEN p_start_date
                                                                                 AND p_end_date
                                                    AND (SELECT js2.statusname
                                                           FROM extension.jobstatuschange
                                                                js2
                                                          WHERE js2.jobstatuschangeid =
                                                                (SELECT MAX(
                                                                            js.jobstatuschangeid) -- Gets the previous status
                                                                   FROM extension.jobstatuschange
                                                                        js
                                                                  WHERE js.jobid =
                                                                        a.objectid
                                                                    AND js.jobstatuschangeid <
                                                                        j.jobstatuschangeid)) <>
                                                        'NEW')
                                   GROUP BY basefileofficeid) voided
                                      ON voided.basefileofficeid = o.objectid
                                  -------------------------------------------------------------------------------------------------------------
                                  -- No Credit Withdrawan
                                  -------------------------------------------------------------------------------------------------------------
                                  LEFT OUTER JOIN
                                  (  SELECT basefileofficeid,
                                            SUM(
                                                CASE
                                                    WHEN a.abc19original =
                                                         'Y'
                                                    THEN
                                                        1
                                                    ELSE
                                                        0
                                                END)    nocreditwthdoriginal,
                                            SUM(CASE
                                                    WHEN a.abc19original != 'Y'
                                                     AND a.abc19pertoper = 'Y'
                                                    THEN
                                                        1
                                                    ELSE
                                                        0
                                                END)    nocreditwthdpertoper
                                       FROM mart.districtapplicationreview d
                                            JOIN mart.application a
                                                ON a.objectid = d.jobid
                                      WHERE d.haslicensetype79 = 'N'
                                        AND d.haslicensetype84 = 'N'
                                        AND d.datecompleted BETWEEN p_start_date
                                                                AND p_end_date
                                        AND d.outcome != 'Withdraw'
                                        AND a.enterapplicationcompleteddate
                                                IS NOT NULL
                                        AND d.objectid IN
                                                (  SELECT MIN(d1.objectid)
                                                     FROM mart.districtapplicationreview
                                                          d1
                                                    WHERE d1.jobid = d.jobid
                                                 GROUP BY d1.jobid)
                                        AND EXISTS
                                                (SELECT 1
                                                   FROM extension.jobstatuschange_t
                                                        j
                                                  WHERE j.statusname = 'WTHDRN'
                                                    AND j.jobstatuschangeid =
                                                        (SELECT MAX(
                                                                    j.jobstatuschangeid)
                                                           FROM extension.jobstatuschange_t
                                                                j
                                                          WHERE j.jobid =
                                                                a.objectid
                                                            AND TRUNC(
                                                                    j.effectivestartdate) BETWEEN p_start_date
                                                                                              AND p_end_date))
                                        AND NOT EXISTS
                                                (SELECT 1
                                                   FROM extension.jobstatuschange_t
                                                        j
                                                  WHERE j.statusname = 'ISSUED'
                                                    AND j.jobid = a.objectid)
                                   GROUP BY basefileofficeid) nocreditwthd
                                      ON nocreditwthd.basefileofficeid =
                                         o.objectid
                            WHERE o.isactive = 'Y'
                         ORDER BY officename)
                  SELECT i.*,
                           i.approvedoriginal
                         + i.deniedoriginal
                         + i.withdrawnoriginal                           completedoriginal,
                           i.pendbegoriginal
                         + i.receivedoriginal
                         - (  i.approvedoriginal
                            + i.deniedoriginal
                            + i.withdrawnoriginal)
                         - i.voidedoriginal                              pendoriginal,
                           -- transfers
                           i.approvedpertoper
                         + i.deniedpertoper
                         + i.withdrawnpertoper                           completedpertoper,
                           i.pendbegpertoper
                         + i.receivedpertoper
                         - (  i.approvedpertoper
                            + i.deniedpertoper
                            + i.withdrawnpertoper)
                         - i.voidedpertoper                              pendingpertoper,
                         LEAD(i.division, 1, NULL)
                             OVER (ORDER BY i.division, i.officename)    div_next
                    FROM info i
                ORDER BY division, officename)
        LOOP
            IF (DBMS_LOB.getlength(p_value) = 0)
            THEN
                -- add header line
                DBMS_LOB.append(
                    p_value,
                    '"'
                    || rec.division
                    || '",'
                    || lv_heading_orig
                    || CHR(13)
                    || CHR(10));

                DBMS_LOB.append(
                    lc_trans,
                    CHR(13)
                    || CHR(10)
                    || '"'
                    || rec.division
                    || '",'
                    || lv_heading_trans
                    || CHR(13)
                    || CHR(10));
            END IF;

            DBMS_LOB.append(
                p_value,
                '"'
                || rec.officename
                || '",'
                || rec.received
                || ','
                || rec.receivedoriginal
                || ','
                || rec.completedoriginal
                || ','
                || rec.approvedoriginal
                || ','
                || rec.deniedoriginal
                || ','
                || rec.withdrawnoriginal
                || ','
                || rec.voidedoriginal
                || ','
                || rec.nocreditwthdoriginal
                || ','
                || rec.pendoriginal
                || CHR(13)
                || CHR(10));

            DBMS_LOB.append(
                lc_trans,
                '"'
                || rec.officename
                || '",,'
                || rec.receivedpertoper
                || ','
                || rec.completedpertoper
                || ','
                || rec.approvedpertoper
                || ','
                || rec.deniedpertoper
                || ','
                || rec.withdrawnpertoper
                || ','
                || rec.voidedpertoper
                || ','
                || rec.nocreditwthdpertoper
                || ','
                || rec.pendingpertoper
                || CHR(13)
                || CHR(10));

            -- add to division totals
            -- Originals
            ln_received := ln_received + rec.received;
            ln_receivedoriginal := ln_receivedoriginal + rec.receivedoriginal;
            ln_completedoriginal :=
                ln_completedoriginal + rec.completedoriginal;
            ln_approvedoriginal := ln_approvedoriginal + rec.approvedoriginal;
            ln_deniedoriginal := ln_deniedoriginal + rec.deniedoriginal;
            ln_withdrawnoriginal :=
                ln_withdrawnoriginal + rec.withdrawnoriginal;
            ln_voidedoriginal := ln_voidedoriginal + rec.voidedoriginal;
            ln_nocreditwthdoriginal :=
                ln_nocreditwthdoriginal + rec.nocreditwthdoriginal;
            ln_pendoriginal := ln_pendoriginal + rec.pendoriginal;

            -- Transfers
            ln_receivedpertoper := ln_receivedpertoper + rec.receivedpertoper;
            ln_completedpertoper :=
                ln_completedpertoper + rec.completedpertoper;
            ln_approvedpertoper := ln_approvedpertoper + rec.approvedpertoper;
            ln_deniedpertoper := ln_deniedpertoper + rec.deniedpertoper;
            ln_withdrawnpertoper :=
                ln_withdrawnpertoper + rec.withdrawnpertoper;
            ln_voidedpertoper := ln_voidedpertoper + rec.voidedpertoper;
            ln_nocreditwthdpertoper :=
                ln_nocreditwthdpertoper + rec.nocreditwthdpertoper;
            ln_pendingpertoper := ln_pendingpertoper + rec.pendingpertoper;



            -- add to statewide totals
            -- Originals State Totals
            ln_received_ttl := ln_received_ttl + rec.received;
            ln_receivedoriginal_ttl :=
                ln_receivedoriginal_ttl + rec.receivedoriginal;
            ln_completedoriginal_ttl :=
                ln_completedoriginal_ttl + rec.completedoriginal;
            ln_approvedoriginal_ttl :=
                ln_approvedoriginal_ttl + rec.approvedoriginal;
            ln_deniedoriginal_ttl :=
                ln_deniedoriginal_ttl + rec.deniedoriginal;
            ln_withdrawnoriginal_ttl :=
                ln_withdrawnoriginal_ttl + rec.withdrawnoriginal;
            ln_voidedoriginal_ttl :=
                ln_voidedoriginal_ttl + rec.voidedoriginal;
            ln_nocreditwthdoriginal_ttl :=
                ln_nocreditwthdoriginal_ttl + rec.nocreditwthdoriginal;
            ln_pendoriginal_ttl := ln_pendoriginal_ttl + rec.pendoriginal;

            -- Transfers State Totals
            ln_receivedpertoper_ttl :=
                ln_receivedpertoper_ttl + rec.receivedpertoper;
            ln_completedpertoper_ttl :=
                ln_completedpertoper_ttl + rec.completedpertoper;
            ln_approvedpertoper_ttl :=
                ln_approvedpertoper_ttl + rec.approvedpertoper;
            ln_deniedpertoper_ttl :=
                ln_deniedpertoper_ttl + rec.deniedpertoper;
            ln_withdrawnpertoper_ttl :=
                ln_withdrawnpertoper_ttl + rec.withdrawnpertoper;
            ln_voidedpertoper_ttl :=
                ln_voidedpertoper_ttl + rec.voidedpertoper;
            ln_nocreditwthdpertoper_ttl :=
                ln_nocreditwthdpertoper_ttl + rec.nocreditwthdpertoper;
            ln_pendingpertoper_ttl :=
                ln_pendingpertoper_ttl + rec.pendingpertoper;


            -- check if next record is the next division or last record
            --   Add division totals to report and rest division totals
            IF (rec.division != NVL(rec.div_next, 'END'))
            THEN
                -- output division totals originals
                DBMS_LOB.append(
                    p_value,
                    '"    '
                    || UPPER(rec.division)
                    || ' TOTALS",'
                    || ln_received
                    || ','
                    || ln_receivedoriginal
                    || ','
                    || ln_completedoriginal
                    || ','
                    || ln_approvedoriginal
                    || ','
                    || ln_deniedoriginal
                    || ','
                    || ln_withdrawnoriginal
                    || ','
                    || ln_voidedoriginal
                    || ','
                    || ln_nocreditwthdoriginal
                    || ','
                    || ln_pendoriginal
                    || CHR(13)
                    || CHR(10));

                -- output division totals transfers
                DBMS_LOB.append(
                    lc_trans,
                    '"    '
                    || UPPER(rec.division)
                    || ' TOTALS",,'
                    || ln_receivedpertoper
                    || ','
                    || ln_completedpertoper
                    || ','
                    || ln_approvedpertoper
                    || ','
                    || ln_deniedpertoper
                    || ','
                    || ln_withdrawnpertoper
                    || ','
                    || ln_voidedpertoper
                    || ','
                    || ln_nocreditwthdpertoper
                    || ','
                    || ln_pendingpertoper
                    || CHR(13)
                    || CHR(10));

                -- clear division totals
                -- Originals
                ln_received := 0;
                ln_receivedoriginal := 0;
                ln_completedoriginal := 0;
                ln_approvedoriginal := 0;
                ln_deniedoriginal := 0;
                ln_withdrawnoriginal := 0;
                ln_voidedoriginal := 0;
                ln_nocreditwthdoriginal := 0;
                ln_pendoriginal := 0;

                -- Transfers
                ln_receivedpertoper := 0;
                ln_completedpertoper := 0;
                ln_approvedpertoper := 0;
                ln_deniedpertoper := 0;
                ln_withdrawnpertoper := 0;
                ln_voidedpertoper := 0;
                ln_nocreditwthdpertoper := 0;
                ln_pendingpertoper := 0;

                IF (rec.div_next IS NOT NULL)
                THEN
                    -- add next column headers
                    -- add header line
                    DBMS_LOB.append(
                        p_value,
                        CHR(13)
                        || CHR(10)
                        || '"'
                        || rec.div_next
                        || '",'
                        || lv_heading_orig
                        || CHR(13)
                        || CHR(10));

                    DBMS_LOB.append(
                        lc_trans,
                        CHR(13)
                        || CHR(10)
                        || '"'
                        || rec.div_next
                        || '",'
                        || lv_heading_trans
                        || CHR(13)
                        || CHR(10));
                END IF;
            END IF;
        END LOOP;

        -- Statewide Totals
        DBMS_LOB.append(
            p_value,
            CHR(13)
            || CHR(10)
            || '"    STATEWIDE TOTALS",'
            || ln_received_ttl
            || ','
            || ln_receivedoriginal_ttl
            || ','
            || ln_completedoriginal_ttl
            || ','
            || ln_approvedoriginal_ttl
            || ','
            || ln_deniedoriginal_ttl
            || ','
            || ln_withdrawnoriginal_ttl
            || ','
            || ln_voidedoriginal_ttl
            || ','
            || ln_nocreditwthdoriginal_ttl
            || ','
            || ln_pendoriginal_ttl
            || CHR(13)
            || CHR(10)
            || CHR(13)
            || CHR(10));

        DBMS_LOB.append(
            lc_trans,
            CHR(13)
            || CHR(10)
            || '"    STATEWIDE TOTALS",,'
            || ln_receivedpertoper_ttl
            || ','
            || ln_completedpertoper_ttl
            || ','
            || ln_approvedpertoper_ttl
            || ','
            || ln_deniedpertoper_ttl
            || ','
            || ln_withdrawnpertoper_ttl
            || ','
            || ln_voidedpertoper_ttl
            || ','
            || ln_nocreditwthdpertoper_ttl
            || ','
            || ln_pendingpertoper_ttl
            || CHR(13)
            || CHR(10)
            || CHR(13)
            || CHR(10));


        DBMS_LOB.append(p_value, lc_trans);

        -------------------------------------------------------
        -- Protests
        -------------------------------------------------------
            -- add header line
            DBMS_LOB.append(
                p_value,
                CHR(13)
                || CHR(10)
                || '"HEADQUARTERS",'
                || lv_heading_prot
                || CHR(13)
                || CHR(10));

        FOR rec
            IN (WITH
                    info
                    AS
                        (SELECT SUBSTR(officename, 1, 20)    officename,
                                CASE
                                    WHEN NVL(rqsexclude, 'N') NOT IN
                                             ('H', 'B')
                                    THEN
                                        UPPER(NVL(division, 'HEADQUARTERS'))
                                    ELSE
                                        'HEADQUARTERS'
                                END                          division,
                                NVL(pri.priorityrecd, 0)     priorityrecd,
                                NVL(t.proapps,0)             proapps,
                                NVL(t2.regpro, 0)            regpro,
                                NVL(t3.regpet, 0)            regpet
                           FROM query.o_office  o
                                LEFT OUTER JOIN
                                (  SELECT api.pkg_columnquery.VALUE(
                                              p.objectid,
                                              'BaseFileOfficeName')             office,
                                          NVL(COUNT(DISTINCT p.objectid), 0)    proapps
                                     FROM TABLE(
                                              CAST(
                                                  api.pkg_simplesearch.castableobjectsbyindexrange(
                                                      'j_Application',
                                                      'CreatedDate',
                                                      TO_CHAR(p_start_date,
                                                              'YYYY-MM-DD'),
                                                      TO_CHAR(p_end_date,
                                                              'YYYY-MM-DD'))
                                                      AS api.udt_objectlist)) p
                                          JOIN query.r_applicationprotestant r
                                              ON r.applicationjobid =
                                                 p.objectid
                                 GROUP BY api.pkg_columnquery.VALUE(
                                              p.objectid,
                                              'BaseFileOfficeName')
                                 ORDER BY office) t
                                    ON o.officename = t.office
                                LEFT OUTER JOIN
                                (     --Total Applications Registered/Protests
                                   SELECT api.pkg_columnquery.VALUE(
                                              r.toobjectid,
                                              'BaseFileOfficeName')               office,
                                          NVL(COUNT(DISTINCT r.toobjectid), 0)    regpro
                                     FROM TABLE(
                                              CAST(
                                                  api.pkg_simplesearch.castableobjectsbyindexrange(
                                                      'l_DocketNoteUserLog',
                                                      'logdate',
                                                      TO_CHAR(p_start_date,
                                                              'YYYY-MM-DD'),
                                                      TO_CHAR(p_end_date,
                                                              'YYYY-MM-DD'))
                                                      AS api.udt_objectlist)) o
                                          JOIN api.relationships r
                                              ON r.fromobjectid = o.objectid
                                             AND r.endpointid =
                                                 api.pkg_configquery.endpointidforname(
                                                     'l_DocketNoteUserLog',
                                                     'Application')
                                    WHERE api.pkg_columnquery.VALUE(
                                              o.objectid,
                                              'eventcode') =
                                          'PRT12'
                                 GROUP BY api.pkg_columnquery.VALUE(
                                              r.toobjectid,
                                              'BaseFileOfficeName')
                                 ORDER BY office) t2
                                    ON o.officename = t2.office
                                LEFT OUTER JOIN
                                (          --Total Applications Registered/PET
                                   SELECT api.pkg_columnquery.VALUE(
                                              r.toobjectid,
                                              'BaseFileOfficeName')               office,
                                          NVL(COUNT(DISTINCT r.toobjectid), 0)    regpet
                                     FROM TABLE(
                                              CAST(
                                                  api.pkg_simplesearch.castableobjectsbyindexrange(
                                                      'l_DocketNoteUserLog',
                                                      'logdate',
                                                      TO_CHAR(p_start_date,
                                                              'YYYY-MM-DD'),
                                                      TO_CHAR(p_end_date,
                                                              'YYYY-MM-DD'))
                                                      AS api.udt_objectlist)) o
                                          JOIN api.relationships r
                                              ON r.fromobjectid = o.objectid
                                             AND r.endpointid =
                                                 api.pkg_configquery.endpointidforname(
                                                     'l_DocketNoteUserLog',
                                                     'Application')
                                    WHERE api.pkg_columnquery.VALUE(
                                              o.objectid,
                                              'eventcode') =
                                          'PMC06'
                                 GROUP BY api.pkg_columnquery.VALUE(
                                              r.toobjectid,
                                              'BaseFileOfficeName')
                                 ORDER BY office) t3
                                    ON o.officename = t3.office
                                LEFT OUTER JOIN
                                (  SELECT office, COUNT(1) priorityrecd
                                     FROM (SELECT objectid,
                                                  api.pkg_columnquery.VALUE(
                                                      objectid,
                                                      'IsPriorityApplication')
                                                      ispriorityapplication,
                                                  api.pkg_columnquery.VALUE(
                                                      objectid,
                                                      'StatusName')
                                                      statusname,
                                                  api.pkg_columnquery.VALUE(
                                                      objectid,
                                                      'BaseFileOfficeCorral')
                                                      office
                                             FROM TABLE(
                                                      CAST(
                                                          api.pkg_simplesearch.castableobjectsbyindexrange(
                                                              a_objectdefname =>
                                                                  'j_application',
                                                              a_columnname =>
                                                                  'CreatedDate',
                                                              a_lowvalue  =>
                                                                  TO_CHAR(
                                                                      p_start_date,
                                                                      'YYYY-MM-DD'),
                                                              a_highvalue =>
                                                                  TO_CHAR(
                                                                      p_end_date,
                                                                      'YYYY-MM-DD'))
                                                              AS api.udt_objectlist))
                                                  o) a
                                    WHERE a.ispriorityapplication = 'Y'
                                      AND a.statusname NOT IN ('NEW', 'VOIDED')
                                 GROUP BY office) pri
                                    ON pri.office = o.office)
                  SELECT i.*,
                         regpro + regpet                                 totalpetpro,
                         LEAD(i.division, 1, NULL)
                             OVER (ORDER BY i.division, i.officename)    div_next
                    FROM info i
                ORDER BY division, officename)
        LOOP
            DBMS_LOB.append(
                p_value,
                '"'
                || rec.officename
                || '",'
                || rec.priorityrecd
                || ','
                || rec.proapps
                || ','
                || rec.regpro
                || ','
                || rec.regpet
                || ','
                || rec.totalpetpro
                || CHR(13)
                || CHR(10));


            -- add to division totals (Protests)
            ln_priorityrecd := ln_priorityrecd + rec.priorityrecd;
            ln_proapps := ln_proapps + rec.proapps;
            ln_regpro := ln_regpro + rec.regpro;
            ln_regpet := ln_regpet + rec.regpet;
            ln_totalpetpro := ln_totalpetpro + rec.totalpetpro;

            -- add to statewide totals (Protests)
            ln_priorityrecd_ttl := ln_priorityrecd_ttl + rec.priorityrecd;
            ln_proapps_ttl := ln_proapps_ttl + rec.proapps;
            ln_regpro_ttl := ln_regpro_ttl + rec.regpro;
            ln_regpet_ttl := ln_regpet_ttl + rec.regpet;
            ln_totalpetpro_ttl := ln_totalpetpro_ttl + rec.totalpetpro;



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
                    || ln_priorityrecd
                    || ','
                    || ln_proapps
                    || ','
                    || ln_regpro
                    || ','
                    || ln_regpet
                    || ','
                    || ln_totalpetpro
                    || CHR(13)
                    || CHR(10));

                -- clear division totals (Protests)
                ln_priorityrecd := 0;
                ln_proapps := 0;
                ln_regpro := 0;
                ln_regpet := 0;
                ln_totalpetpro := 0;


                IF (rec.div_next IS NOT NULL)
                THEN
                    -- add next column headers
                    DBMS_LOB.append(
                        p_value,
                        CHR(13)
                        || CHR(10)
                        || '"'
                        || rec.div_next
                        || '",'
                        || lv_heading_prot
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
            || ln_priorityrecd_ttl
            || ','
            || ln_proapps_ttl
            || ','
            || ln_regpro_ttl
            || ','
            || ln_regpet_ttl
            || ','
            || ln_totalpetpro_ttl
            || CHR(13)
            || CHR(10));


        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_status_msg :=
                'ws_5_investigations.get_data: '
                || DBMS_UTILITY.format_error_backtrace
                || ':: '
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

            rqs_utils.LOG(
                p_log_type  => 'E',
                p_job_id    => p_parms.get_value('JOB_ID'),
                p_seq       => p_parms.get_value('SEQ'),
                p_source    => 'Workload Summary Investigations Report',
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
                p_source    => 'ws_5_investigations',
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
