CREATE OR REPLACE PROCEDURE BIZMOD_API.execute_jobs
IS
    /******************************************************************************
        File:       BIZMOD_API.EXECUTE_JOBS.PRC


        History:
        -------------------------------------------------------------------------------
                      Date          Ticket      Comment
           1.0.1   10/29/2025  TJL BIZ-19526  Initial Procedure Created
           2.0.0   11/24/2025  TJL BIZ-19701  Added support for boolean value
    ******************************************************************************/
    TYPE job_rec
        IS RECORD(seq bizmod_api.e_jobs_que_t.seq%TYPE,
                  schema_name bizmod_api.e_jobs_que_t.schema_name%TYPE,
                  procedure_name bizmod_api.e_jobs_que_t.procedure_name%TYPE,
                  application_id bizmod_api.e_jobs_que_t.application_id%TYPE,
                  job_parameters bizmod_api.e_jobs_que_t.job_parameters%TYPE,
                  repeat_cycle bizmod_api.e_jobs_que_t.repeat_cycle%TYPE,
                  schedule_time bizmod_api.e_jobs_que_t.schedule_time%TYPE,
                  process_arguments bizmod_api.process_arguments_tbl);

    TYPE job_tbl IS TABLE OF job_rec;

    CURSOR c_jobs IS
          SELECT j.seq,
                 j.schema_name,
                 j.procedure_name,
                 j.application_id,
                 j.job_parameters,
                 j.repeat_cycle,
                 j.schedule_time,
                 CAST(
                     MULTISET(
                         SELECT bizmod_api.process_arguments_rec(
                                    a.rn,
                                    a.argument_name,
                                    a.data_type,
                                    b.COLUMN_VALUE)
                           FROM (  SELECT DISTINCT
                                          position rn, argument_name, data_type
                                     FROM all_arguments
                                    WHERE owner = UPPER(j.schema_name)
                                      AND object_name =
                                          UPPER(
                                              NVL(REGEXP_SUBSTR(j.procedure_name,
                                                                '[^.]+',
                                                                1,
                                                                2),
                                                  j.procedure_name))
                                      AND data_level = 0
                                 ORDER BY position) a
                                JOIN
                                (SELECT COLUMN_VALUE, ROWNUM rn
                                   FROM TABLE(j.job_parameters)) b
                                    ON a.rn = b.rn)
                         AS bizmod_api.process_arguments_tbl)    AS process_arguments
            FROM bizmod_api.e_jobs_que_t j
           WHERE NVL(j.schedule_time, SYSDATE - 1) <= SYSDATE
        ORDER BY j.schedule_time;

    t_jobs         job_tbl;

    t_date_format  VARCHAR2(100) := 'MM/DD/YYYY HH24:MI:SS';
    t_sql_stmt     VARCHAR2(4000);
    t_sqlerrm      VARCHAR2(4000);
    t_trace        VARCHAR2(4000);
    c              PLS_INTEGER;
    n              PLS_INTEGER;
BEGIN
    --dbms_output.put_line('Starting exeute jobs');

    OPEN c_jobs;

    FETCH c_jobs BULK COLLECT INTO t_jobs;

    CLOSE c_jobs;

    FOR inx IN 1 .. t_jobs.COUNT
    LOOP
        BEGIN
            -- Construct the dynamic SQL statement
            t_sql_stmt :=
                'BEGIN '
                || t_jobs(inx).schema_name
                || '.'
                || t_jobs(inx).procedure_name
                || '(';

            FOR i IN 1 .. t_jobs(inx).process_arguments.COUNT
            LOOP
                IF (t_jobs(inx).process_arguments(i).prameter_value
                        IS NOT NULL)
                THEN
                    IF i > 1
                    THEN
                        t_sql_stmt := t_sql_stmt || ',';
                    END IF;

                    t_sql_stmt :=
                        t_sql_stmt
                        || t_jobs(inx).process_arguments(i).argument_name
                        || ' => :'
                        || t_jobs(inx).process_arguments(i).argument_name;
                END IF;
            END LOOP;

            t_sql_stmt := t_sql_stmt || '); END;';

            --dbms_output.put_line(t_sql_stmt);
            BEGIN
                -- Open a DBMS_SQL cursor
                c := DBMS_SQL.open_cursor;

                -- Parse the dynamic SQL statement
                DBMS_SQL.parse(c, t_sql_stmt, DBMS_SQL.native);

                -- Bind the parameters
                FOR i IN 1 .. t_jobs(inx).process_arguments.COUNT
                LOOP
                    IF (t_jobs(inx).process_arguments(i).prameter_value
                            IS NOT NULL)
                    THEN
                        CASE t_jobs(inx).process_arguments(i).data_type
                            WHEN 'NUMBER'
                            THEN
                                DBMS_SQL.bind_variable(
                                    c,
                                    ':'
                                    || t_jobs(inx).process_arguments(i).argument_name,
                                    TO_NUMBER(
                                        t_jobs(inx).process_arguments(i).prameter_value));
                            WHEN 'PL/SQL BOOLEAN'
                            THEN
                                DBMS_SQL.bind_variable(
                                    c,
                                    ':'
                                    || t_jobs(inx).process_arguments(i).argument_name,
                                    CASE t_jobs(inx).process_arguments(i).prameter_value
                                        WHEN 'TRUE'
                                        THEN
                                            TRUE
                                        ELSE
                                            FALSE
                                    END);
                            WHEN 'DATE'
                            THEN
                                DBMS_SQL.bind_variable(
                                    c,
                                    ':'
                                    || t_jobs(inx).process_arguments(i).argument_name,
                                    CASE
                                        WHEN validate_conversion(
                                                 t_jobs(inx).process_arguments(
                                                     i).prameter_value
                                                     AS TIMESTAMP) =
                                             1
                                        THEN
                                            CAST(
                                                TO_TIMESTAMP(
                                                    t_jobs(inx).process_arguments(
                                                        i).prameter_value)
                                                    AS DATE)
                                        WHEN validate_conversion(
                                                 t_jobs(inx).process_arguments(
                                                     i).prameter_value
                                                     AS TIMESTAMP WITH TIME ZONE) =
                                             1
                                        THEN
                                            CAST(
                                                TO_TIMESTAMP_TZ(
                                                    t_jobs(inx).process_arguments(
                                                        i).prameter_value)
                                                    AS DATE)
                                        WHEN validate_conversion(
                                                 t_jobs(inx).process_arguments(
                                                     i).prameter_value
                                                     AS DATE) =
                                             1
                                        THEN
                                            TO_DATE(
                                                t_jobs(inx).process_arguments(
                                                    i).prameter_value)
                                        WHEN validate_conversion(
                                                 t_jobs(inx).process_arguments(
                                                     i).prameter_value
                                                     AS DATE,
                                                 t_date_format) =
                                             1
                                        THEN
                                            TO_DATE(
                                                t_jobs(inx).process_arguments(
                                                    i).prameter_value,
                                                t_date_format)
                                        ELSE
                                            NULL
                                    END);
                            WHEN 'TIMESTAMP'
                            THEN
                                DBMS_SQL.bind_variable(
                                    c,
                                    ':'
                                    || t_jobs(inx).process_arguments(i).argument_name,
                                    CASE
                                        WHEN validate_conversion(
                                                 t_jobs(inx).process_arguments(
                                                     i).prameter_value
                                                     AS TIMESTAMP) =
                                             1
                                        THEN
                                            TO_TIMESTAMP(
                                                t_jobs(inx).process_arguments(
                                                    i).prameter_value)
                                        WHEN validate_conversion(
                                                 t_jobs(inx).process_arguments(
                                                     i).prameter_value
                                                     AS TIMESTAMP WITH TIME ZONE) =
                                             1
                                        THEN
                                            TO_TIMESTAMP_TZ(
                                                t_jobs(inx).process_arguments(
                                                    i).prameter_value)
                                        WHEN validate_conversion(
                                                 t_jobs(inx).process_arguments(
                                                     i).prameter_value
                                                     AS TIMESTAMP,
                                                 t_date_format) =
                                             1
                                        THEN
                                            TO_TIMESTAMP(
                                                t_jobs(inx).process_arguments(
                                                    i).prameter_value,
                                                t_date_format)
                                        WHEN validate_conversion(
                                                 t_jobs(inx).process_arguments(
                                                     i).prameter_value
                                                     AS DATE) =
                                             1
                                        THEN
                                            CAST(
                                                TO_DATE(
                                                    t_jobs(inx).process_arguments(
                                                        i).prameter_value)
                                                    AS TIMESTAMP)
                                        ELSE
                                            NULL
                                    END);
                            ELSE
                                DBMS_SQL.bind_variable(
                                    c,
                                    ':'
                                    || t_jobs(inx).process_arguments(i).argument_name,
                                    t_jobs(inx).process_arguments(i).prameter_value);
                        END CASE;
                    END IF;
                END LOOP;

                -- Execute the statement
                n := DBMS_SQL.execute(c);

                -- Close the cursor
                DBMS_SQL.close_cursor(c);
            EXCEPTION
                WHEN OTHERS
                THEN
                    t_sqlerrm := SQLERRM;
                    t_trace := DBMS_UTILITY.format_error_backtrace;

                    IF DBMS_SQL.is_open(c)
                    THEN
                        DBMS_SQL.close_cursor(c);
                    END IF;
            END;

            --            FOR job IN (SELECT * FROM TABLE(t_jobs(inx).process_arguments))
            --            LOOP
            --                DBMS_OUTPUT.put_line(
            --                    job.position
            --                    || '  argument_name: '
            --                    || job.argument_name
            --                    || '  data_type: '
            --                    || job.data_type
            --                    || '  parameter value: '
            --                    || job.prameter_value);
            --            END LOOP;
            --
            -- update job history table
            INSERT INTO bizmod_api.e_jobs_hist_t j(seq,
                                                   schema_name,
                                                   procedure_name,
                                                   application_id,
                                                   job_parameters,
                                                   repeat_cycle,
                                                   schedule_time,
                                                   errmsg,
                                                   bktrace)
                 VALUES (t_jobs(inx).seq,
                         t_jobs(inx).schema_name,
                         t_jobs(inx).procedure_name,
                         t_jobs(inx).application_id,
                         t_jobs(inx).job_parameters,
                         t_jobs(inx).repeat_cycle,
                         t_jobs(inx).schedule_time,
                         t_sqlerrm,
                         t_trace);

            -- check if this job is a recurring job
            IF (t_jobs(inx).repeat_cycle IS NULL)
            THEN
                DELETE bizmod_api.e_jobs_que_t j
                 WHERE j.seq = t_jobs(inx).seq;
            ELSE
                UPDATE bizmod_api.e_jobs_que_t j
                   SET j.schedule_time =
                             t_jobs(inx).schedule_time
                           + NUMTODSINTERVAL(t_jobs(inx).repeat_cycle,
                                             'HOUR'),
                       j.seq = bizmod_api.e_jobs_seq.NEXTVAL
                 WHERE j.seq = t_jobs(inx).seq;
            END IF;

            COMMIT;
        EXCEPTION
            WHEN OTHERS
            THEN
                IF DBMS_SQL.is_open(c)
                THEN
                    DBMS_SQL.close_cursor(c);
                END IF;

                RAISE;
        END;
    END LOOP;
EXCEPTION
    WHEN OTHERS
    THEN
        IF c_jobs%ISOPEN
        THEN
            CLOSE c_jobs;
        END IF;

        RAISE;
END;
/


GRANT EXECUTE ON BIZMOD_API.EXECUTE_JOBS TO ABC;

GRANT EXECUTE ON BIZMOD_API.EXECUTE_JOBS TO LORDT;

GRANT EXECUTE ON BIZMOD_API.EXECUTE_JOBS TO POSSEEXTENSIONS;
