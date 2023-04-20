CREATE OR REPLACE FUNCTION ABCREPORTS.ws_7_arrests(
    p_parms        IN OUT t_parameters,
    p_status_ind   IN OUT VARCHAR2)
    RETURN BLOB
IS
    -- ****************************************************************************
    -- File:        WS_7_ARRESTS.FNC
    -- Author:      Timothy J. Lord
    --
    -- Description:
    --          Arrests and Citations
    --
    --
    -- History:
    -------------------------------------------------------------------------------
    --    Date                  Comment
    --  09/07/2022  TJL   - Function created
    -- ****************************************************************************

    FUNCTION get_data(p_value        IN OUT CLOB,
                      p_start_date   IN     DATE,
                      p_end_date     IN     DATE,
                      p_status_msg   IN OUT VARCHAR2)
        RETURN BOOLEAN
    IS
        ln_premisesvisitedlicensing NUMBER := 0;
        ln_premisesvisitedenforcement NUMBER := 0;
        ln_minorabc    NUMBER := 0;
        ln_minorjoint  NUMBER := 0;
        ln_otherabc    NUMBER := 0;
        ln_otherjoint  NUMBER := 0;
        ln_abc         NUMBER := 0;
        ln_joint       NUMBER := 0;
        ln_warningletterssent NUMBER := 0;

        ln_previsitedlicensing_ttl NUMBER := 0;
        ln_previsitedenforcement_ttl NUMBER := 0;
        ln_minorabc_ttl NUMBER := 0;
        ln_minorjoint_ttl NUMBER := 0;
        ln_otherabc_ttl NUMBER := 0;
        ln_otherjoint_ttl NUMBER := 0;
        ln_abc_ttl     NUMBER := 0;
        ln_joint_ttl   NUMBER := 0;
        ln_warningletterssent_ttl NUMBER := 0;
    BEGIN
        FOR rec
            IN (WITH
                    info
                    AS
                        (SELECT UPPER(SUBSTR(officename, 1, 20))
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
                                NVL(
                                    abc19monthlyheader.premisesvisitedlicensing,
                                    0)
                                    premisesvisitedlicensing,
                                NVL(
                                    abc19monthlyheader.premisesvisitedenforcement,
                                    0)
                                    premisesvisitedenforcement,
                                NVL(arrests.minorabc, 0)
                                    AS minorabc,
                                NVL(arrests.otherabc, 0)
                                    AS otherabc,
                                NVL(arrests.minorjoint, 0)
                                    AS minorjoint,
                                NVL(arrests.otherjoint, 0)
                                    AS otherjoint,
                                NVL(abc19monthlyheader.warningletterssent, 0)
                                    warningletterssent
                           FROM query.o_office  o
                                LEFT OUTER JOIN
                                (  SELECT districtofficeobjectid
                                              basefileofficeid,
                                          SUM(NVL(premisesvisitedlicensing, 0))
                                              premisesvisitedlicensing,
                                          SUM(
                                              NVL(premisesvisitedenforcement,
                                                  0))
                                              premisesvisitedenforcement,
                                          SUM(NVL(warningletterssent, 0))
                                              warningletterssent
                                     FROM mart.abc19monthlyheader h
                                    WHERE (TO_DATE(
                                               CASE
                                                   WHEN NVL(h.monthnumber, 1) <
                                                        10
                                                    AND NVL(h.monthnumber, 1) >
                                                        0
                                                   THEN
                                                       '0'
                                                       || TO_CHAR(
                                                              NVL(
                                                                  h.monthnumber,
                                                                  1))
                                                   WHEN NVL(h.monthnumber, 1) =
                                                        0
                                                   THEN
                                                       '01'
                                                   ELSE
                                                       TO_CHAR(
                                                           NVL(h.monthnumber,
                                                               11))
                                               END
                                               || CASE
                                                      WHEN NVL(h.year, 0) = 0
                                                      THEN
                                                          '2000'
                                                      ELSE
                                                          TO_CHAR(h.year)
                                                  END,
                                               'MMYYYY')) BETWEEN p_start_date
                                                              AND p_end_date
                                 GROUP BY h.districtofficeobjectid)
                                abc19monthlyheader
                                    ON abc19monthlyheader.basefileofficeid =
                                       o.objectid
                                LEFT OUTER JOIN
                                (  SELECT investigationofficeobjectid
                                              basefileofficeid,
                                          SUM(CASE
                                                  WHEN ac.minors = 'Y'
                                                   AND ac.casetype = 'ABC'
                                                  THEN
                                                      1
                                                  ELSE
                                                      0
                                              END)
                                              minorabc,
                                          SUM(CASE
                                                  WHEN ac.minors = 'N'
                                                   AND ac.casetype = 'ABC'
                                                  THEN
                                                      1
                                                  ELSE
                                                      0
                                              END)
                                              otherabc,
                                          SUM(
                                              CASE
                                                  WHEN ac.minors = 'Y'
                                                   AND ac.casetype NOT IN
                                                           ('ABC', 'Backtrack')
                                                  THEN
                                                      1
                                                  ELSE
                                                      0
                                              END)
                                              minorjoint,
                                          SUM(
                                              CASE
                                                  WHEN ac.minors = 'N'
                                                   AND ac.casetype NOT IN
                                                           ('ABC', 'Backtrack')
                                                  THEN
                                                      1
                                                  ELSE
                                                      0
                                              END)
                                              otherjoint
                                     FROM mart.arrestcitations ac
                                    WHERE ac.arrestdate BETWEEN p_start_date
                                                            AND p_end_date
                                 GROUP BY ac.investigationofficeobjectid)
                                arrests
                                    ON arrests.basefileofficeid = o.objectid
                          WHERE o.isactive = 'Y')
                  SELECT i.*,
                         minorabc + otherabc                             abc,
                         otherjoint + minorjoint                         joint,
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
                    '" ","PREMISES VISITED","PREMISES VISITED","MINORS","MINORS","OTHERS","OTHERS","TOTAL","TOTAL","TOTAL WARNING LTRS SENT"'
                    || CHR(13)
                    || CHR(10));

                DBMS_LOB.append(
                    p_value,
                    '"'
                    || rec.division
                    || '","LICENSING","ENFORCEMENT","ABC","JT","ABC","JT","ABC","JT"," "'
                    || CHR(13)
                    || CHR(10));
            END IF;

            DBMS_LOB.append(
                p_value,
                '"'
                || rec.officename
                || '",'
                || rec.premisesvisitedlicensing
                || ','
                || rec.premisesvisitedenforcement
                || ','
                || rec.minorabc
                || ','
                || rec.minorjoint
                || ','
                || rec.otherabc
                || ','
                || rec.otherjoint
                || ','
                || rec.abc
                || ','
                || rec.joint
                || ','
                || rec.warningletterssent
                || CHR(13)
                || CHR(10));


            -- add to division totals
            ln_premisesvisitedlicensing :=
                ln_premisesvisitedlicensing + rec.premisesvisitedlicensing;
            ln_premisesvisitedenforcement :=
                  ln_premisesvisitedenforcement
                + rec.premisesvisitedenforcement;
            ln_minorabc := ln_minorabc + rec.minorabc;
            ln_minorjoint := ln_minorjoint + rec.minorjoint;
            ln_otherabc := ln_otherabc + rec.otherabc;
            ln_otherjoint := ln_otherjoint + rec.otherjoint;
            ln_abc := ln_abc + rec.abc;
            ln_joint := ln_joint + rec.joint;
            ln_warningletterssent :=
                ln_warningletterssent + rec.warningletterssent;


            -- add to statewide totals
            ln_previsitedlicensing_ttl :=
                ln_previsitedlicensing_ttl + rec.premisesvisitedlicensing;
            ln_previsitedenforcement_ttl :=
                ln_previsitedenforcement_ttl + rec.premisesvisitedenforcement;
            ln_minorabc_ttl := ln_minorabc_ttl + rec.minorabc;
            ln_minorjoint_ttl := ln_minorjoint_ttl + rec.minorjoint;
            ln_otherabc_ttl := ln_otherabc_ttl + rec.otherabc;
            ln_otherjoint_ttl := ln_otherjoint_ttl + rec.otherjoint;
            ln_abc_ttl := ln_abc_ttl + rec.abc;
            ln_joint_ttl := ln_joint_ttl + rec.joint;
            ln_warningletterssent_ttl :=
                ln_warningletterssent_ttl + rec.warningletterssent;

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
                    || ln_premisesvisitedlicensing
                    || ','
                    || ln_premisesvisitedenforcement
                    || ','
                    || ln_minorabc
                    || ','
                    || ln_minorjoint
                    || ','
                    || ln_otherabc
                    || ','
                    || ln_otherjoint
                    || ','
                    || ln_abc
                    || ','
                    || ln_joint
                    || ','
                    || ln_warningletterssent
                    || CHR(13)
                    || CHR(10));

                -- clear division totals
                ln_premisesvisitedlicensing := 0;
                ln_premisesvisitedenforcement := 0;
                ln_minorabc := 0;
                ln_minorjoint := 0;
                ln_otherabc := 0;
                ln_otherjoint := 0;
                ln_abc := 0;
                ln_joint := 0;
                ln_warningletterssent := 0;


                IF (rec.div_next IS NOT NULL)
                THEN
                    -- add next column headers
                    DBMS_LOB.append(
                        p_value,
                        CHR(13)
                        || CHR(10)
                        || '" ","PREMISES VISITED","PREMISES VISITED","MINORS","MINORS","OTHERS","OTHERS","TOTAL","TOTAL","TOTAL WARNING LTRS SENT"'
                        || CHR(13)
                        || CHR(10));

                    DBMS_LOB.append(
                        p_value,
                        '"'
                        || rec.div_next
                        || '","LICENSING","ENFORCEMENT","ABC","JT","ABC","JT","ABC","JT"," "'
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
            || ln_previsitedlicensing_ttl
            || ','
            || ln_previsitedenforcement_ttl
            || ','
            || ln_minorabc_ttl
            || ','
            || ln_minorjoint_ttl
            || ','
            || ln_otherabc_ttl
            || ','
            || ln_otherjoint_ttl
            || ','
            || ln_abc_ttl
            || ','
            || ln_joint_ttl
            || ','
            || ln_warningletterssent_ttl
            || CHR(13)
            || CHR(10));


        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_status_msg :=
                'ws_7_arrests.get_data: '
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
                          p_source    => 'Workload Summary Arrests Report',
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
                p_source    => 'ws_7_arrests',
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
