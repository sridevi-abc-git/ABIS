CREATE OR REPLACE PROCEDURE BIZMOD_API.EXECUTE_JOBS
IS
    /******************************************************************************
        File:       BIZMOD_API.EXECUTE_JOBS.PRC


        History:
        -------------------------------------------------------------------------------
                      Date          Ticket      Comment
           1.0.0   10/29/2025  TJL BIZ-19526  Initial Procedure Created

    ******************************************************************************/
    TYPE job_rec IS RECORD(seq bizmod_api.e_jobs_t.seq%TYPE,
                           schema_name bizmod_api.e_jobs_t.schema_name%TYPE,
                           procedure_name bizmod_api.e_jobs_t.procedure_name%TYPE,
                           repeat_cycle bizmod_api.e_jobs_t.repeat_cycle%TYPE,
                           args bizmod_api.e_jobs_t.args%TYPE,
                           schedule_time bizmod_api.e_jobs_t.schedule_time%TYPE,
                           job_parms bizmod_api.job_parms_tbl);

    TYPE job_tbl IS TABLE OF job_rec;

    CURSOR c_jobs IS
        SELECT j.seq,
               j.schema_name,
               j.procedure_name,
               j.repeat_cycle,
               j.args,
               j.schedule_time,
               CAST(
                   MULTISET(
                       SELECT bizmod_api.job_parms_rec(a.rn,
                                            a.argument_name,
                                            a.COLUMN_VALUE,
                                            b.COLUMN_VALUE)
                         FROM (  SELECT position      rn,
                                        argument_name,
                                        data_type     COLUMN_VALUE
                                   FROM all_arguments
                                  WHERE owner = UPPER(j.schema_name)
                                    AND object_name = UPPER(j.procedure_name)
                                    AND data_level = 0
                               ORDER BY position) a
                              LEFT OUTER JOIN
                              (SELECT COLUMN_VALUE, ROWNUM rn
                                 FROM TABLE(j.args)) b
                                  ON a.rn = b.rn)
                       AS bizmod_api.job_parms_tbl)    AS job_parms
          FROM bizmod_api.e_jobs_t j
         WHERE NVL(j.schedule_time, SYSDATE - 1) <= SYSDATE
           AND NVL(j.processed, 'N') = 'N';

    t_jobs         job_tbl;

    t_sql_stmt     VARCHAR2(4000);
    c              PLS_INTEGER;
    n              PLS_INTEGER;
BEGIN
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

            FOR i IN 1 .. t_jobs(inx).job_parms.COUNT
            LOOP
                t_sql_stmt :=
                    t_sql_stmt
                    || t_jobs(inx).job_parms(i).argument_name
                    || ' => :'
                    || t_jobs(inx).job_parms(i).argument_name;

                IF i < t_jobs(inx).job_parms.COUNT
                THEN
                    t_sql_stmt := t_sql_stmt || ',';
                END IF;
            END LOOP;

            t_sql_stmt := t_sql_stmt || '); END;';

            -- Open a DBMS_SQL cursor
            c := DBMS_SQL.open_cursor;

            -- Parse the dynamic SQL statement
            DBMS_SQL.parse(c, t_sql_stmt, DBMS_SQL.native);

            -- Bind the parameters
            FOR i IN 1 .. t_jobs(inx).job_parms.COUNT
            LOOP
                CASE t_jobs(inx).job_parms(i).data_type
                    WHEN 'NUMBER'
                    THEN
                        DBMS_SQL.bind_variable(
                            c,
                            ':' || t_jobs(inx).job_parms(i).argument_name,
                            TO_NUMBER(
                                t_jobs(inx).job_parms(i).prameter_value));
                    WHEN 'DATE'
                    THEN
                        DBMS_SQL.bind_variable(
                            c,
                            ':' || t_jobs(inx).job_parms(i).argument_name,
                            TO_DATE(t_jobs(inx).job_parms(i).prameter_value,
                                    'MM/DD/YYYY HH24:MI:SS'));
                    ELSE
                        DBMS_SQL.bind_variable(
                            c,
                            ':' || t_jobs(inx).job_parms(i).argument_name,
                            t_jobs(inx).job_parms(i).prameter_value);
                END CASE;
            END LOOP;

            -- Execute the statement
            n := DBMS_SQL.execute(c);

            -- Close the cursor
            DBMS_SQL.close_cursor(c);

            FOR job IN (SELECT * FROM TABLE(t_jobs(inx).job_parms))
            LOOP
                DBMS_OUTPUT.put_line(
                    job.position
                    || '  argument_name: '
                    || job.argument_name
                    || '  data_type: '
                    || job.data_type
                    || '  parameter value: '
                    || job.prameter_value);
            END LOOP;

            -- update processed  as completed
            UPDATE bizmod_api.e_jobs_t j
               SET j.processed = 'Y', j.completed_time = SYSTIMESTAMP
             WHERE j.seq = t_jobs(inx).seq;

            -- check if this job is a recurring job
            IF (t_jobs(inx).repeat_cycle IS NOT NULL)
            THEN
                -- insert the job to run again
                INSERT INTO bizmod_api.e_jobs_t j(schema_name,
                                      procedure_name,
                                      repeat_cycle,
                                      args,
                                      schedule_time)
                         VALUES (
                                    t_jobs(inx).schema_name,
                                    t_jobs(inx).procedure_name,
                                    t_jobs(inx).repeat_cycle,
                                    t_jobs(inx).args,
                                      t_jobs(inx).schedule_time
                                    + NUMTODSINTERVAL(
                                          t_jobs(inx).repeat_cycle,
                                          'HOUR'));
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


GRANT EXECUTE ON BIZMOD_API.EXECUTE_JOBS TO POSSEEXTENSIONS;
