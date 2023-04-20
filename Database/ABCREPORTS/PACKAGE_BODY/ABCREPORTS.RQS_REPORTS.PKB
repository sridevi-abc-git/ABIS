CREATE OR REPLACE PACKAGE BODY ABCREPORTS.RQS_REPORTS AS
-- ****************************************************************************
-- File:        rqs_reports_v2.pkb
-- Author:      Timothy J. Lord
--
-- $Rev: 196 $
-- $Date: 2019-01-10 09:00:28 -0800 (Thu, 10 Jan 2019) $
-- Last Changed By:  $Author: tlord $
--
-- Description:
--
--
-- History:
-------------------------------------------------------------------------------
--    Date                  Comment
-- 09/20/2015 TJL       Initial File created
-- 02/08/2016 TJL 8952  Added filter for job id and report id to query in
--                      get_report_list.
-- 02/08/2016 TJL 8954  Added filter to prevent user from seeing reports not
--                      assigned to them.
-- 03/04/2014 TJL  9131 Added url parameter to upd_export_log, removed p_parameters
--                      parameter from save_report
-- ****************************************************************************

-- ****************************************************************************
--
-- ****************************************************************************
	PROCEDURE format_report(p_parms IN OUT t_parameters) IS

    l_response_text     VARCHAR2(32767);
    l_error             BOOLEAN;
    l_format            t_parameters;
    l_report_number     NUMBER;
    l_err_number        NUMBER;

    BEGIN
        IF (rqs_utils.get_ctrl_value('WND_SERVICE_PORT') IS NULL) THEN
            UPDATE REPORT_QUEUE_STATUS
               SET step_ind = 'W',
                   ora_status = 'W',
                   web_status = 'W'
             WHERE seq = p_parms.get_value('SEQ');
            COMMIT;

            -- build format parameters
            l_report_number := p_parms.get_value('REPORT_NUMBER');
            l_format := t_parameters(XMLTYPE('<ROOT/>'));
            l_format.add_value('SEQ', p_parms.get_value('SEQ'));
            l_format.add_value('REPORT_NUMBER', l_report_number);

            -- get format parameters
            FOR parameter IN
                (SELECT report_number, parameter_name, parameter_value
                   FROM report_parameters de
                  WHERE (parameter_type = 'F')
                    AND (report_number = 0 OR report_number = l_report_number)
                    AND NOT EXISTS (SELECT * FROM report_parameters
                                     WHERE de.report_number = 0 AND report_number = l_report_number
                                       AND (parameter_type = 'F')
                                       AND parameter_name = de.parameter_name
                                   )
                  ORDER BY de.report_number
                  )
            LOOP
                l_format.upd_value(parameter.parameter_name,
                                        rqs_process_parameters.process(parameter.parameter_value,
                                                                       l_format));
            END LOOP;

            -- add information from orginal parameters and override any that was passed
            --  from web site
            FOR rec IN
                (SELECT parameter_name, parameter_value
                   FROM TABLE(p_parms.recs))
            LOOP
                l_format.upd_value(rec.parameter_name,
                                   rec.parameter_value);
            END LOOP;

            rqs_utils.log(p_log_type          =>  'T',
                          p_job_id            =>  NULL,
                          p_seq               =>  p_parms.get_value('SEQ'),
                          p_source            =>  'rqs_reports.format_report',
                          p_msg               =>  'Calling rqs_webservice.request');

            rqs_webservice.request(l_format,
                                   l_response_text,
                                   l_error);
        ELSE
            wndservice(a_requestid => p_parms.get_value('SEQ'),
                       a_response  => l_response_text,
                       a_error     => l_err_number);

            l_error := (NVL(l_err_number, 0) != 0);
        END IF;

        IF (NOT l_error) THEN
            UPDATE REPORT_QUEUE_STATUS
               SET ora_status = 'C'
             WHERE seq = p_parms.get_value('SEQ');
            COMMIT;
         END IF;

    EXCEPTION
        WHEN OTHERS THEN
            -- log error
            rqs_utils.log(p_log_type          =>  'E',
                          p_job_id            =>  NULL,
                          p_seq               =>  TO_NUMBER(p_parms.get_value('SEQ')),
                          p_source            =>  'rqs_reports.format_report',
                          p_msg               =>  SQLERRM,
                          p_error_trace       =>  dbms_utility.format_error_backtrace);
    END format_report;


-- ****************************************************************************
--
-- ****************************************************************************
	PROCEDURE get_unformated_report(p_seq         IN  NUMBER,
                                p_data        OUT SYS_REFCURSOR,
                                p_status_msg  OUT VARCHAR2)
            IS
    BEGIN
        -- read report data
        OPEN p_data FOR
            SELECT r.data_format,
                   r.report_data,
                   NVL(q.report_parameters, qh.report_parameters) report_parameters
              FROM report_data_raw r
              LEFT OUTER JOIN report_queue q USING(seq)
              LEFT OUTER JOIN report_queue_history qh USING(seq)
             WHERE seq = p_seq;

    EXCEPTION
        WHEN OTHERS THEN
            rqs_utils.log(p_log_type          =>  'E',
                          p_job_id            =>  NULL,
                          p_seq               =>  p_seq,
                          p_source            =>  'rqs_reports.get_unformated_report',
                          p_msg               =>  SQLERRM,
                          p_error_trace       =>  dbms_utility.format_error_backtrace);

            p_status_msg := 'get_unformated_report(EXCEPTION): '
                         || dbms_utility.format_error_backtrace
                         || ' :: ' || SQLERRM;

    END get_unformated_report;


-- ****************************************************************************
--
-- ****************************************************************************
	PROCEDURE get_status(p_job_id         IN  NUMBER,
                     p_data           OUT VARCHAR2,
                     p_status_msg     OUT VARCHAR2)
            IS

    BEGIN
        -- read report data
        SELECT '[' ||
              LISTAGG('{"SEQ":"' || seq || '",' ||
                      '"OFFICENAME":"' || (SELECT attributevalue
                                             FROM possedata.ObjectColumnData d
                                            WHERE objectid = officeobjectid
                                              AND columndefid = 343998) || '",' ||
                      '"STEP_IND":"' || step_ind || '",' ||
                      '"ORA_STATUS":"' || ora_status || '",' ||
                      '"WEB_STATUS":"' || web_status || '",' ||
                      '"RETRY_CNT":"' || retry_cnt ||
                      '"}'  , ',')
                            WITHIN GROUP (ORDER BY seq) || ']' "status"
              INTO p_data
              FROM report_xref
             INNER JOIN report_queue_status
             USING (seq)
             WHERE job_id = p_job_id;

    EXCEPTION
        WHEN OTHERS THEN
            rqs_utils.log(p_log_type          =>  'E',
                          p_job_id            =>  p_job_id,
                          p_seq               =>  NULL,
                          p_source            =>  'rqs_reports.get_status',
                          p_msg               =>  SQLERRM,
                          p_error_trace       =>  dbms_utility.format_error_backtrace);

            p_status_msg := 'get_unformated_report(EXCEPTION): '
                         || dbms_utility.format_error_backtrace
                         || ' :: ' || SQLERRM;

    END get_status;




-- ****************************************************************************
--
-- ****************************************************************************
	PROCEDURE upd_status(p_seq          IN NUMBER,
                     p_step         IN VARCHAR2,
                     p_ora_status   IN VARCHAR2,
                     p_web_status   IN VARCHAR2,
                     p_message      IN VARCHAR2) IS

    BEGIN
        IF (p_step != 'T') THEN
            UPDATE report_queue_status
               SET step_ind     = NVL(p_step, step_ind),
                   ora_status   = NVL(p_ora_status, ora_status),
                   web_status   = NVL(p_web_status, web_status)
             WHERE seq = p_seq;
             COMMIT;
        END IF;

        IF ((p_step IN ('E', 'T')) AND (p_message IS NOT NULL)) THEN
            -- log the error message
            rqs_utils.log(p_log_type          =>  p_step,
                          p_job_id            =>  NULL,
                          p_seq               =>  p_seq,
                          p_source            =>  'WEB',
                          p_msg               =>  'Web message: ' || p_message,
                          p_additional_data   =>  'Step: ' || p_step || '  Web: ' || p_web_status);
        END IF;
    END upd_status;


-- ****************************************************************************
--
-- ****************************************************************************
	PROCEDURE cancel_report(p_job_id  IN NUMBER) IS

    BEGIN
        UPDATE report_queue_status
           SET cancel_flg     = 'Y'
         WHERE seq IN (SELECT seq
                         FROM report_xref
                        WHERE job_id = p_job_id);
        COMMIT;

    END cancel_report;


-- ****************************************************************************
--
-- ****************************************************************************
	PROCEDURE get_report_list(p_parameters IN  XMLTYPE,
                          p_data       OUT CLOB,
                          p_status_msg OUT VARCHAR2) IS

    office_ids                  T_OFFICEOBJECT;
    parameters                  t_parameters;
    lv_user_role                VARCHAR2(10);
    ln_oraclelogonid            VARCHAR2(32)        := NULL;
    ln_officeobjectid           NUMBER              := NULL;
    ln_cnt                      NUMBER              := 0;
    ld_start_date               DATE;
    ld_end_date                 DATE;
    ln_seq                      NUMBER;
    ln_job                      NUMBER;
    ln_report_number            NUMBER;

    BEGIN
        -- parse parameters
        parameters := t_parameters(p_parameters);

        -- check if user or other
        lv_user_role := parameters.get_value('USER_ROLE_IND');
        IF (lv_user_role = 'U') THEN
            SELECT oraclelogonid
              INTO ln_oraclelogonid
              FROM admin.users e
             WHERE userid = parameters.get_value('USEROBJECTID');
        END IF;

        -- get office list for user requesting report list
        ln_officeobjectid := parameters.get_value('OFFICEOBJECTID');
        IF (ln_officeobjectid IS NULL) THEN
            -- no office selected get all offices for user
            SELECT api.pkg_columnquery.VALUE(parameters.get_value('USEROBJECTID'), 'OfficeObjectId')
              INTO ln_officeobjectid
              FROM DUAL;
        END IF;

        -- get start and end dates for report selection
        ld_start_date := NVL(TO_DATE(parameters.get_value('START_DATE'), 'MM/DD/YYYY'),  TRUNC(SYSDATE - 7));
        ld_end_date := NVL(TO_DATE(parameters.get_value('END_DATE'), 'MM/DD/YYYY'),  TRUNC(SYSDATE));

        -- build office list to get reports from
        office_ids := rqs_utils.BuildOfficeList(ln_officeobjectid, p_status_msg);

        ln_job := parameters.get_value('JOB_ID');
        ln_seq := parameters.get_value('REPORT_ID');
        ln_report_number := parameters.get_value('REPORT_NUMBER');

        DBMS_LOB.CREATETEMPORARY(p_data, TRUE, dbms_lob.CALL);
        dbms_lob.append (p_data, '[');

        FOR rec IN
            (SELECT (SELECT userid FROM admin.users WHERE oraclelogonid = x.created_by) userobjectid,

                    job_id,
                    seq,
                    report_name,
                    r.create_date,
                    (SELECT attributevalue
                       FROM possedata.ObjectColumnData d
                      WHERE objectid = officeobjectid
                        AND columndefid = 343998) officeobjectid,
                    '' user_comment
               FROM reports r
              INNER JOIN report_xref x USING (seq)
              INNER JOIN report_def    USING (report_number)
              WHERE (
                          report_number = ln_report_number
                      OR (ln_report_number IS NULL
                          AND report_number IN (SELECT report_number
                                                  FROM user_reports
                                                 WHERE userobjectid = parameters.get_value('USEROBJECTID'))
                         )
                    )
                AND (x.created_by = NVL(ln_oraclelogonid, x.created_by)
                       OR
                     x.created_by = 'ABCREPORTS')
                AND web_flg = 'Y'
                AND officeobjectid IN (SELECT officeobjectid FROM TABLE(office_ids))
                AND TRUNC(r.create_date) BETWEEN ld_start_date AND ld_end_date
                AND (
                        seq = ln_seq
                     OR (ln_seq IS NULL AND seq IN (SELECT x2.seq
                                                      FROM report_xref x2
                                                     WHERE job_id = ln_job))
                     OR (ln_seq IS NULL AND ln_job IS NULL)
                    )
              ORDER BY job_id DESC, seq)
        LOOP
            IF (ln_cnt > 0) THEN dbms_lob.append (p_data, ','); END IF;

            dbms_lob.append (p_data,
                        '{"JOB_ID":"' || rec.job_id || '",' ||
                        '"SEQ":"' || rec.seq || '",' ||
                        '"REPORT_NAME":"' || rec.report_name || '",' ||
                        '"USER_COMMENT":"' || rec.user_comment || '",' ||
                        '"USER_NAME":"' || api.pkg_columnquery.VALUE(rec.userobjectid, 'FormattedUserName') || '",' ||
                        '"OFFICENAME":"' || rec.officeobjectid || '",' ||
                        '"REPORT_DATE":"' || TO_CHAR(rec.create_date, 'MM/DD/YYYY') || '"}');
            ln_cnt := ln_cnt + 1;
        END LOOP;

        dbms_lob.append (p_data, ']');

    EXCEPTION
        WHEN OTHERS THEN
            rqs_utils.log(p_log_type          =>  'E',
                          p_job_id            =>  NULL,
                          p_seq               =>  NULL,
                          p_source            =>  'rqs_reports.get_report_list',
                          p_msg               =>  SQLERRM,
                          p_error_trace       =>  dbms_utility.format_error_backtrace);

            p_status_msg := 'get_unformated_report(EXCEPTION): '
                         || dbms_utility.format_error_backtrace
                         || ' :: ' || SQLERRM;

    END get_report_list;


-- ****************************************************************************
--
-- ****************************************************************************
	PROCEDURE get_report(p_seq         IN  NUMBER,
                     p_data        OUT BLOB,
                     p_parameters  OUT VARCHAR2, -- output control parameters
                     p_data_format OUT VARCHAR2,
                     p_status_msg  OUT VARCHAR2)
            IS

    BEGIN
        -- get output parameters
        SELECT '{"REPORT_NAME":"' || ur.report_name || '",' ||
                (SELECT LISTAGG('"' || parameter_name || '":"' || parameter_value || '"', ',')
                            WITHIN GROUP (ORDER BY parameter_name) || '}' "parameters"
                  FROM report_parameters de
                 WHERE (parameter_type = 'O')
                   AND (report_number = 0 OR report_number = ur.report_number)
                   AND NOT EXISTS (SELECT * FROM report_parameters
                                    WHERE de.report_number = 0 AND report_number = ur.report_number
                                      AND (parameter_type = 'O')
                                      AND parameter_name = de.parameter_name
                                  )
               )
          INTO p_parameters
          FROM report_def ur
         INNER JOIN report_xref x
            ON (x.report_number = ur.report_number)
         WHERE seq = p_seq;

        -- read report data
        SELECT report_data, data_format
          INTO p_data, p_data_format
          FROM reports
         WHERE seq = p_seq;

    EXCEPTION
        WHEN OTHERS THEN
            rqs_utils.log(p_log_type          =>  'E',
                          p_job_id            =>  NULL,
                          p_seq               =>  p_seq,
                          p_source            =>  'rqs_reports.get_report',
                          p_msg               =>  SQLERRM,
                          p_error_trace       =>  dbms_utility.format_error_backtrace);

            p_status_msg := 'get_report(EXCEPTION): '
                         || dbms_utility.format_error_backtrace
                         || ' :: ' || SQLERRM;

    END get_report;

-- ****************************************************************************
--
-- ****************************************************************************
	PROCEDURE save_report(p_seq          IN  NUMBER,
                      p_data_format  IN  VARCHAR2,
                      p_report_data  IN  BLOB,
                      p_status_msg   OUT VARCHAR2)
            IS
    lv_temp        report_queue.report_parameters%TYPE;

    BEGIN
        -- add to reports table
        INSERT INTO reports (seq, data_format, report_data)
                     VALUES (p_seq, p_data_format, p_report_data);

    EXCEPTION
        WHEN OTHERS THEN
            rqs_utils.log(p_log_type          =>  'E',
                          p_job_id            =>  NULL,
                          p_seq               =>  p_seq,
                          p_source            =>  'rqs_reports.save_report',
                          p_msg               =>  SQLERRM,
                          p_error_trace       =>  dbms_utility.format_error_backtrace);

            p_status_msg := 'save_report(EXCEPTION): '
                         || dbms_utility.format_error_backtrace
                         || ' :: ' || SQLERRM;

    END save_report;


-- ****************************************************************************
--
-- ****************************************************************************
	PROCEDURE get_parameters(p_report_number    IN  NUMBER,
                         p_parameter_type   IN  VARCHAR2,
                         p_export_seq       IN  NUMBER,
                         p_data             OUT SYS_REFCURSOR,
                         p_status_msg       OUT VARCHAR2)
            IS

    BEGIN
        OPEN p_data FOR
            SELECT parameter_name,
                       rqs_process_parameters.proc(rqs_process_parameters.replace_tags(parameter_value),
                                                   t_parameters(XMLTYPE('<ROOT/>')))
                   parameter_value
              FROM report_parameters de
             WHERE (parameter_type = p_parameter_type)
               AND NVL(export_seq, NVL(p_export_seq, -1)) = NVL(p_export_seq, NVL(export_seq, -1))
               AND (report_number = 0 OR report_number = p_report_number)
               AND NOT EXISTS (SELECT * FROM report_parameters
                                WHERE de.report_number = 0 AND report_number = p_report_number
                                  AND (parameter_type = p_parameter_type)
                                  AND parameter_name = de.parameter_name
                              );

    EXCEPTION
        WHEN OTHERS THEN
            rqs_utils.log(p_log_type          =>  'E',
                          p_job_id            =>  NULL,
                          p_seq               =>  p_report_number,
                          p_source            =>  'rqs_reports.get_parameters',
                          p_msg               =>  SQLERRM,
                          p_additional_data   =>  'Parameter Type: ' || p_parameter_type,
                          p_error_trace       =>  dbms_utility.format_error_backtrace);

            p_status_msg := 'get_parameters(EXCEPTION): '
                         || dbms_utility.format_error_backtrace
                         || ' :: ' || SQLERRM;

    END get_parameters;




	PROCEDURE get_emailparameters(p_seq              IN  NUMBER,
                              p_report_process   IN  VARCHAR2,
                              p_report_number    IN  NUMBER,
                              p_officeobjectid   IN  NUMBER,
                              p_data             OUT VARCHAR2,
                              p_status_msg       OUT VARCHAR2)
            IS

    lt_parameters       t_parameters;
    lt_results          t_parameters;
    lv_parameters       report_queue.report_parameters%TYPE;

    BEGIN

        SELECT report_parameters
          INTO lv_parameters
          FROM (SELECT report_parameters
                  FROM report_queue
                 WHERE seq = p_seq
                        UNION
                SELECT report_parameters
                  FROM report_queue_history
                 WHERE seq = p_seq);

        lt_parameters := t_parameters(XMLTYPE(lv_parameters));
        lt_results    := t_parameters(XMLTYPE('<ROOT></ROOT>'));
--            rqs_utils.log(p_log_type          =>  'T',
--                          p_job_id            =>  NULL,
--                          p_seq               =>  NULL,
--                          p_source            =>  'rqs_reports.get_emailparameters',
--                          p_msg               =>  lv_parameters || ' -- ' || lt_parameters.get_value('REPORT_NAME'),
--                          p_additional_data   =>  p_seq || ' ' || p_report_process || ' ' || p_report_number || ' ' || p_officeobjectid,
--                          p_error_trace       =>  NULL);


        FOR rec IN
                     (SELECT parameter_name,
--                                rqs_process_parameters.proc(parameter_value,
--                                                            lt_parameters)
                            parameter_value
                       FROM report_email_parameters de
                      WHERE (((report_number = p_report_number) AND (officeobjectid = p_officeobjectid))
                         OR  ((report_number = p_report_number) AND (p_report_number != 0) AND (officeobjectid = 0))
                         OR  ((report_number = 0) AND (officeobjectid = p_officeobjectid) AND (p_officeobjectid != 0)))
                         OR
                            NOT EXISTS (SELECT * FROM report_email_parameters
                                         WHERE parameter_name = de.parameter_name
                                           AND (((report_number = p_report_number) AND (officeobjectid = p_officeobjectid))
                                            OR  ((report_number = p_report_number) AND (p_report_number != 0) AND (officeobjectid = 0))
                                            OR  ((report_number = 0) AND (officeobjectid = p_officeobjectid) AND (p_officeobjectid != 0))
                                            OR (de.officeobjectid != 0) OR (de.report_number != 0))
                                        )
                        AND report_process = p_report_process)
        LOOP
             lt_results.add_value(rec.parameter_name,
                                  rqs_process_parameters.proc(rec.parameter_value, lt_parameters));

--            rqs_utils.log(p_log_type          =>  'T',
--                          p_job_id            =>  NULL,
--                          p_seq               =>  NULL,
--                          p_source            =>  'rqs_reports.get_emailparameters',
--                          p_msg               =>  rec.parameter_name || ' ' || rec.parameter_value,
--                          p_additional_data   =>  p_seq || ' ' || p_report_process || ' ' || p_report_number || ' ' || p_officeobjectid,
--                          p_error_trace       =>  lt_results.get_value(rec.parameter_name));

        END LOOP;

        p_data := lt_results.get_json(FALSE);

--            rqs_utils.log(p_log_type          =>  'T',
--                          p_job_id            =>  NULL,
--                          p_seq               =>  NULL,
--                          p_source            =>  'rqs_reports.get_emailparameters',
--                          p_msg               =>  p_data,
--                          p_additional_data   =>  p_seq || ' ' || p_report_process || ' ' || p_report_number || ' ' || p_officeobjectid,
--                          p_error_trace       =>  NULL);

    EXCEPTION
        WHEN OTHERS THEN
            rqs_utils.log(p_log_type          =>  'E',
                          p_job_id            =>  NULL,
                          p_seq               =>  NULL,
                          p_source            =>  'rqs_reports.get_emailparameters',
                          p_msg               =>  SQLERRM,
                          p_additional_data   =>  'Report Number:' || p_report_number || '  Office object id: ' || p_officeobjectid,
                          p_error_trace       =>  dbms_utility.format_error_backtrace);

            p_status_msg := 'get_parameters(EXCEPTION): '
                         || dbms_utility.format_error_backtrace
                         || ' :: ' || SQLERRM;

    END get_emailparameters;


-- ****************************************************************************
-- Function:    report_defs()
--
-- Desctiption: report_defs is called to get the list of reports the selected
--              user can call.
--
-- Paremeters:  p_user_id    - ABIS object id for user
--
--              p_data       - List of available reports the user can request
--              p_status_msg - If error return's error message
--
-- ****************************************************************************
	PROCEDURE get_control_parameter(p_userobjectid IN  NUMBER,
                                p_data         OUT VARCHAR2,
                                p_status_msg   OUT VARCHAR2) IS

    lv_data         VARCHAR2(32000);
    lv_row          VARCHAR2(32000);

    BEGIN
        FOR rec IN
                (SELECT ur.report_number
                  FROM user_reports ur
                 INNER JOIN report_def d ON (d.report_number = ur.report_number)
                 WHERE userobjectid = p_userobjectid
                 ORDER BY d.report_name)
        LOOP
            SELECT '"INPUT_FIELDS":{' ||
                        LISTAGG('"' || parameter_name || '":"' || parameter_value || '"', ',')
                        WITHIN GROUP (ORDER BY parameter_name) || '}}' "parameters"
                            INTO lv_row
                            FROM report_parameters de
                           WHERE (parameter_type = 'W')
                             AND (report_number = 0 OR report_number = rec.report_number)
                             AND NOT EXISTS (SELECT * FROM report_parameters
                                              WHERE de.report_number = 0 AND report_number = rec.report_number
                                                AND (parameter_type = 'W')
                                                AND parameter_name = de.parameter_name);

            IF (lv_data IS NOT NULL) THEN
                lv_data := lv_data || ',';
            END IF;
            lv_data := lv_data || '{' || RQS_UTILS.report_info_json(rec.report_number)
                    || ',' || lv_row;

        END LOOP;

        p_data := '{"REPORTS":[' || lv_data || '], "OFFICE":' || rqs_utils.officelist(p_userobjectid) || ',' || rqs_utils.countylist || '}';

--        SELECT '{"REPORTS":[' || LISTAGG(
--                (SELECT '{' || RQS_UTILS.report_info_json(ur.report_number)
--                      || ',"INPUT_FIELDS":{' ||
--                        LISTAGG('"' || parameter_name || '":"' || parameter_value || '"', ',')
--                        WITHIN GROUP (ORDER BY parameter_name) || '}}' "parameters"
--                            FROM report_parameters de
--                           WHERE (parameter_type = 'W')
--                             AND (report_number = 0 OR report_number = ur.report_number)
--                             AND NOT EXISTS (SELECT * FROM report_parameters
--                                              WHERE de.report_number = 0 AND report_number = ur.report_number
--                                                AND (parameter_type = 'W')
--                                                AND parameter_name = de.parameter_name
--                                            )), ',')
--              WITHIN GROUP (ORDER BY ur.report_number) || '],"OFFICE":' || rqs_utils.officelist(p_userobjectid) || '}'  "report_number"
--          INTO p_data
--          FROM user_reports ur
--         INNER JOIN report_def d ON (d.report_number = ur.report_number)
--         WHERE userobjectid = p_userobjectid
--         ORDER BY ur.report_number;

    EXCEPTION
        WHEN OTHERS THEN
            p_status_msg := 'available_report_types(EXCEPTION): '
                         || dbms_utility.format_error_backtrace
                         || ' :: ' || SQLERRM;
    END get_control_parameter;



	PROCEDURE upd_export_log(p_job_id       NUMBER,
                         p_seq          NUMBER,
                         p_url          VARCHAR2,
                         p_export_id    NUMBER,
                         p_status_ind   VARCHAR2,
                         p_response     VARCHAR2,
                         p_error_msg    VARCHAR2) IS

    BEGIN
         INSERT INTO report_export_log (job_id,
                                        seq,
                                        url,
                                        export_id,
                                        status_ind,
                                        response,
                                        error_msg)
          VALUES (p_job_id,
                  p_seq,
                  p_url,
                  p_export_id,
                  p_status_ind,
                  p_response,
                  p_error_msg);

        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            rqs_utils.log(p_log_type          =>  'E',
                          p_job_id            =>  NULL,
                          p_seq               =>  p_seq,
                          p_source            =>  'rqs_reports.upd_export_log',
                          p_msg               =>  SQLERRM,
                          p_additional_data   =>  'Response: ' || p_response || ' - Error: ' || p_error_msg,
                          p_error_trace       =>  dbms_utility.format_error_backtrace);
    END upd_export_log;


	PROCEDURE upd_status(p_job_id       IN NUMBER,
                     p_finalize_id  IN NUMBER,
                     p_status       IN VARCHAR2,
                     p_msg          IN VARCHAR2) IS

    BEGIN
        UPDATE report_finalize_status
           SET status = p_status,
               msg    = p_msg
         WHERE id     = p_finalize_id
           AND job_id = p_job_id;

        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            rqs_utils.log(p_log_type          =>  'E',
                          p_job_id            =>  p_job_id,
                          p_seq               =>  p_finalize_id,
                          p_source            =>  'rqs_reports.upd_status',
                          p_msg               =>  SQLERRM,
                          p_additional_data   =>  p_msg,
                          p_error_trace       =>  dbms_utility.format_error_backtrace);
    END upd_status;



END RQS_REPORTS;
/


CREATE OR REPLACE PUBLIC SYNONYM RQS_REPORTS FOR ABCREPORTS.RQS_REPORTS;


GRANT EXECUTE ON ABCREPORTS.RQS_REPORTS TO ABCREPORTS_ROLE;

GRANT EXECUTE ON ABCREPORTS.RQS_REPORTS TO POSSEEXTENSIONS;
