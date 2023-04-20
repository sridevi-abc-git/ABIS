CREATE OR REPLACE FUNCTION ABCREPORTS.ws_9_miscellaneous(
    p_parms        IN OUT t_parameters,
    p_status_ind   IN OUT VARCHAR2)
    RETURN BLOB
IS
    -- ****************************************************************************
    -- File:        WS_9_MISCELLANEOUS.FNC
    -- Author:      Timothy J. Lord
    --
    -- Description:
    --
    --
    -- History:
    -------------------------------------------------------------------------------
    --    Date                  Comment
    --  08/31/2022  TJL   - Function created
    -- ****************************************************************************

    FUNCTION get_data(p_value        IN OUT CLOB,
                      p_start_date   IN     DATE,
                      p_end_date     IN     DATE,
                      p_status_msg   IN OUT VARCHAR2)
        RETURN BOOLEAN
    IS
        ln_permit      NUMBER := 0;
        ln_tempberrwine NUMBER := 0;
        ln_general     NUMBER := 0;
        ln_catering    NUMBER := 0;
        ln_permit_ttl  NUMBER := 0;
        ln_tempberrwine_ttl NUMBER := 0;
        ln_general_ttl NUMBER := 0;
        ln_catering_ttl NUMBER := 0;
    BEGIN
        FOR rec
            IN (WITH
                    info
                    AS
                        (  SELECT UPPER(SUBSTR(o.officename, 1, 20))    officename,
                                  CASE
                                      WHEN NVL(o.rqsexclude, 'N') NOT IN
                                               ('H', 'B')
                                      THEN
                                          UPPER(
                                              NVL(o.division, 'HEADQUARTERS'))
                                      ELSE
                                          'HEADQUARTERS'
                                  END                            division,
                                  NVL(tp.temppermit, 0)          permit,
                                  NVL(xx.beerwine, 0)            tempberrwine,
                                  NVL(xx.daily, 0)               AS general,
                                  NVL(ca.catering, 0)            AS catering
                             FROM query.o_office o
                                  LEFT OUTER JOIN
                                  (       -- Spec Daily Temp Beer/Wine (31-34)
                                             -- Daily On-Sale General     (37)
                                    SELECT x.districtofficeid,
                                           SUM(
                                               CASE
                                                   WHEN x.licensetypecode BETWEEN 31
                                                                              AND 34
                                                   THEN
                                                       1
                                                   ELSE
                                                       0
                                               END)    beerwine,
                                           SUM(
                                               CASE
                                                   WHEN x.licensetypecode = 37
                                                   THEN
                                                       1
                                                   ELSE
                                                       0
                                               END)    daily
                                      FROM (  SELECT districtofficeid,
                                                     CASE
                                                         WHEN licensetypecode BETWEEN 31
                                                                                  AND 34
                                                         THEN
                                                             31
                                                         ELSE
                                                             TO_NUMBER(
                                                                 lt.licensetypecode)
                                                     END    licensetypecode
                                                FROM mart.onedaylicense d
                                                     JOIN
                                                     mart.onedaylicensetypecategoryrel
                                                     r
                                                         ON d.jobid =
                                                            r.onedaylicensejobid
                                                     JOIN
                                                     mart.licensetypecategory lt
                                                         ON lt.objectid =
                                                            r.licensetypecategoryobjectid
                                               WHERE d.dateofeventfrom IS NOT NULL
                                                 AND TO_DATE(d.completeddate) BETWEEN p_start_date
                                                                                  AND p_end_date
                                            ORDER BY districtofficeid) x
                                  GROUP BY x.districtofficeid
                                  ORDER BY 1) xx
                                      ON xx.districtofficeid = o.objectid
                                  LEFT OUTER JOIN
                                  (                           -- Catering AUTH
                                     SELECT api.pkg_columnquery.VALUE(
                                                d.jobid,
                                                'BaseFileOfficename')
                                                officename,
                                            COUNT(d.jobid)
                                                catering
                                       FROM mart.issuecaterereventauth d
                                      WHERE TO_DATE(d.datecompleted) BETWEEN p_start_date
                                                                         AND p_end_date
                                        AND d.outcome IS NOT NULL
                                        AND d.cateringorevent IS NOT NULL
                                        AND NVL(
                                                (SELECT a.licenseexists
                                                   FROM mart.applictype a
                                                  WHERE a.applicationobjectid =
                                                        d.jobid
                                                    AND ROWNUM < 2),
                                                'N') =
                                            'N'
                                   GROUP BY api.pkg_columnquery.VALUE(
                                                d.jobid,
                                                'BaseFileOfficename')
                                   ORDER BY officename) ca
                                      ON ca.officename = o.officename
                                  LEFT OUTER JOIN
                                  (                       -- Temporary permits
                                     SELECT t.investigationofficeobjectid
                                                basefileofficeid,
                                            COUNT(t.jobid)
                                                temppermit
                                       FROM mart.temporarypermit t
                                      WHERE TO_DATE(t.datecompleted) BETWEEN p_start_date
                                                                         AND p_end_date
                                   GROUP BY t.investigationofficeobjectid -- a.basefileofficeid --to_number(api.pkg_columnquery.VALUE(a.objectid, 'BaseFileOfficeName')                 ORDER BY 1
                                                                         ) tp
                                      ON tp.basefileofficeid = o.objectid
                         ORDER BY division, officename)
                  SELECT ROWNUM                                                line,
                         info.*,
                         LEAD(info.division, 1, NULL)
                             OVER (ORDER BY info.division, info.officename)    div_next
                    FROM info
                ORDER BY info.division, officename)
        LOOP
            --dbms_output.put_line(rec.officename || ' :: ' || rec.division || ' -> ' || rec.div_next);
            IF (rec.line = 1)
            THEN
                -- add first header line
                DBMS_LOB.append(
                    p_value,
                    '"'
                    || rec.division
                    || '","TEMP/INTR''M RET PERMIT","SPEC DAILY TEMP BEER/WINE","DAILY ON-SALE GENERAL","CATERING AUTH"'
                    || CHR(13)
                    || CHR(10));
            END IF;

            DBMS_LOB.append(
                p_value,
                '"'
                || rec.officename
                || '",'
                || rec.permit
                || ','
                || rec.tempberrwine
                || ','
                || rec.general
                || ','
                || rec.catering
                || CHR(13)
                || CHR(10));

            -- add to division totals
            ln_permit := ln_permit + rec.permit;
            ln_tempberrwine := ln_tempberrwine + rec.tempberrwine;
            ln_general := ln_general + rec.general;
            ln_catering := ln_catering + rec.catering;

            -- add to statewide totals
            ln_permit_ttl := ln_permit_ttl + rec.permit;
            ln_tempberrwine_ttl := ln_tempberrwine_ttl + rec.tempberrwine;
            ln_general_ttl := ln_general_ttl + rec.general;
            ln_catering_ttl := ln_catering_ttl + rec.catering;

            -- check if next record is the next division or last record
            --   Add division totals to report and rest division totals
            IF (rec.division != NVL(rec.div_next, 'END'))
            THEN
                DBMS_LOB.append(
                    p_value,
                    '"    '
                    || UPPER(rec.division)
                    || ' TOTALS",'
                    || ln_permit
                    || ','
                    || ln_tempberrwine
                    || ','
                    || ln_general
                    || ','
                    || ln_catering
                    || CHR(13)
                    || CHR(10));

                ln_permit := 0;
                ln_tempberrwine := 0;
                ln_general := 0;
                ln_catering := 0;

                IF (rec.div_next IS NOT NULL)
                THEN
                    -- add next header
                    DBMS_LOB.append(
                        p_value,
                        CHR(13)
                        || CHR(10)
                        || '"'
                        || rec.div_next
                        || '","TEMP/INTR''M RET PERMIT","SPEC DAILY TEMP BEER/WINE","DAILY ON-SALE GENERAL","CATERING AUTH"'
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
            || ln_permit_ttl
            || ','
            || ln_tempberrwine_ttl
            || ','
            || ln_general_ttl
            || ','
            || ln_catering_ttl
            || CHR(13)
            || CHR(10));
        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_status_msg :=
                'ws_9_miscellaneous.get_data: '
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
        
        p_parms.upd_value('REPORT_DATE', TO_CHAR(SYSDATE, 'MM/DD/YYYY HH:MI PM'));
        p_parms.upd_value('ENHANCED', 'Y');

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
                p_source    => 'ws_9_miscellaneous',
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
