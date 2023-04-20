CREATE OR REPLACE PROCEDURE ABCREPORTS.rqs_process_request_id(
    p_job_id       IN VARCHAR,
    p_override     IN VARCHAR := 'N')
IS
    -- ****************************************************************************
    -- File:        rqs_process_request_id_v2.prc
    -- Author:      Timothy J. Lord
    --
    -- $Rev: 354 $
    -- $Date: 2019-09-03 12:57:55 -0700 (Tue, 03 Sep 2019) $
    -- Last Changed By:  $Author: tlord $
    --
    -- Description: The RQS_PROCESS_REQUEST_ID is the procedure which controls the creation
    --              of a selected report.  This procedure can be scheduled as a
    --              job or executed directly.
    --
    -- Parameters:  p_job_id - Parameter job ID for the report(s) to be created.
    --
    -- Dependences:
    --
    -- History:
    -------------------------------------------------------------------------------
    --    Date                      Comment
    -- 09/19/2015 TJL           Original file created
    -- 03/04/2016 TJL   9131 Change how hung report is determined.
    -- 01/10/2019 TJL  17103 Change report pending cursor to a record array.
    -- 08/28/2019 TJL        Added checking to not format report for return status of 'C'
    -------------------------------------------------------------------------------

    PROCEDURE process(p_parms IN OUT t_parameters)
    IS
        lblob_data      BLOB;
        ln_seq          NUMBER;
        lv_status_ind   VARCHAR2(1);
    BEGIN
        ln_seq   := p_parms.get_value('SEQ');
        rqs_utils.LOG(p_log_type  => 'T',
                      p_job_id    => NULL,
                      p_seq       => ln_seq,
                      p_source    => 'rqs_process_request_id.process',
                      p_msg       => 'Process start',
                      p_additional_data => p_parms.get_value('PROCESS'));

        -- call report function to generate a reporet statement or report
        EXECUTE IMMEDIATE
               'BEGIN :a := '
            || p_parms.get_value('PROCESS')
            || '(:b, :c); END;'
            USING OUT lblob_data, IN OUT p_parms, IN OUT lv_status_ind;

        rqs_utils.LOG(p_log_type  => 'T',
                      p_job_id    => NULL,
                      p_seq       => ln_seq,
                      p_source    => 'rqs_process_request_id.process',
                      p_msg       => 'Report generated: ' || lv_status_ind);

        -- update info record with any changes made to parameter
        UPDATE report_queue
           SET report_parameters   = p_parms.get_xml
         WHERE seq = ln_seq;

        CASE NVL(lv_status_ind, 'F') 
        WHEN 'E' THEN
            -- update status as faital error
            UPDATE report_queue_status
               SET step_ind = 'E', ora_status = 'E'
             WHERE seq = ln_seq;
            COMMIT;
        -- 08/28/2019 TJL Add testing for C status    
        WHEN 'C' THEN
            -- no error save report data
            INSERT INTO report_data_raw(seq, data_format, report_data)
                     VALUES (ln_seq,
                             p_parms.get_value('DATA_FORMAT'),
                             lblob_data);
            UPDATE report_queue_status
               SET step_ind = 'C', ora_status = 'C'
             WHERE seq = ln_seq;
            COMMIT;
            
        ELSE
            -- no error save report data
            INSERT INTO report_data_raw(seq, data_format, report_data)
                     VALUES (ln_seq,
                             p_parms.get_value('DATA_FORMAT'),
                             lblob_data);
            COMMIT;
            rqs_reports.format_report(p_parms);
        END case;    
--        END IF;

    EXCEPTION
        WHEN OTHERS THEN
            rqs_utils.LOG(
                p_log_type  => 'E',
                p_job_id    => NULL,
                p_seq       => TO_NUMBER(p_parms.get_value('SEQ')),
                p_source    => 'rqs_process_request_id.process',
                p_msg       => SQLERRM,
                p_error_trace => dbms_utility.format_error_backtrace);

            UPDATE report_queue_status
               SET step_ind = 'E', ora_status = 'E'
             WHERE seq = ln_seq;

            COMMIT;
    END process;
-------------------------------------------------------------------------------

--*****************************************************************************
--      RQS_PROCESS_REQUEST_ID (Main Process)
--*****************************************************************************
BEGIN
    DECLARE
        -- 01/10/2019 TJL  17103 add types and seqs variable
        TYPE r_parms IS RECORD
        (
            seq NUMBER,
            parameters t_parameters,
            start_time DATE,
            update_date DATE,
            step_ind VARCHAR2(1)
        );

        TYPE t_parms IS TABLE OF r_parms;

        seqs              t_parms;
        ln_seq            NUMBER;
        ln_cnt            NUMBER;
        lv_cancel_flg     report_queue_status.cancel_flg%TYPE;
        l_response_text   VARCHAR2(32767);
        l_err_number      NUMBER;
        
    BEGIN
        rqs_utils.LOG(p_log_type  => 'T',
                      p_job_id    => p_job_id,
                      p_seq       => NULL,
                      p_source    => 'rqs_process_request_id',
                      p_msg       => 'Starting Process');

        -- get report(s)to process
        -- 01/10/2019 TJL  17103 removed cursor and added bulk collect
        SELECT seq,
               t_parameters(xmltype(report_parameters)),
               NULL,
               NULL,
               NULL
          BULK COLLECT INTO seqs
          FROM v_report_pending
         WHERE job_id = p_job_id;

        -- 01/10/2019 TJL  17103 loop through array for processing parameters
        FOR i IN 1 .. seqs.COUNT
        LOOP
            ln_seq   := seqs(i).seq;

            -- check if report has been canceled
            SELECT NVL(cancel_flg, 'N')
              INTO lv_cancel_flg
              FROM report_queue_status
             WHERE seq = seqs(i).seq;

            EXIT WHEN lv_cancel_flg = 'Y';

            -- update status to indicate start of process
            UPDATE report_queue_status
               SET step_ind = 'P', ora_status = 'P', web_status = NULL
             WHERE seq = seqs(i).seq;

            COMMIT;
            -- call process to build report
            process(seqs(i).parameters);
        END LOOP;

        -- wait for report(s) to complete
        LOOP
            -- check if all reports have completed
            -- 01/10/2019 TJL  17103 loop through array for processing parameters
            SELECT seq,
                   t_parameters(xmltype(report_parameters)),
                   start_time,
                   update_date,
                   step_ind
              BULK COLLECT INTO seqs
              FROM report_queue
                   INNER JOIN report_xref USING (seq)
                   INNER JOIN report_queue_status USING (seq)
             WHERE job_id = p_job_id
               AND step_ind NOT IN ('C', 'E');

            EXIT WHEN seqs.COUNT = 0;

            FOR i IN 1 .. seqs.COUNT
            LOOP
                ln_seq   := seqs(i).seq;

                -- error report if not completed in 6 hours
                IF ((seqs(i).update_date + INTERVAL '6' HOUR) < SYSDATE)
                OR SYSDATE > TRUNC(SYSDATE) + INTERVAL '23' HOUR THEN
                    -- update status for error
                    UPDATE report_queue_status
                       SET step_ind   = 'E'
                     WHERE seq = seqs(i).seq;

                    rqs_utils.LOG(
                        p_log_type =>
                            'E',
                        p_job_id =>
                            p_job_id,
                        p_seq =>
                            seqs(i).seq,
                        p_source =>
                            'rqs_process_request_id',
                        p_msg =>
                            'Report not completed in 6 hour time limit or time passed 11:00 PM',
                        p_error_trace =>
                            'Hung report handler');
                    COMMIT;
                    CONTINUE;
                END IF;

                IF (lv_cancel_flg = 'Y') THEN
                    -- update status to indicate start of process
                    UPDATE report_queue_status
                       SET step_ind   = 'E'
                     WHERE seq = seqs(i).seq;

                    COMMIT;
                    CONTINUE;
                ELSE
                    CONTINUE WHEN seqs(i).step_ind != 'R';

                    -- check if raw data was successfully created
                    SELECT NVL(COUNT(seq), 0)
                      INTO ln_cnt
                      FROM report_data_raw
                     WHERE seq = seqs(i).seq;

                    -- update status to indicate start of process
                    UPDATE report_queue_status
                       SET step_ind = 'P', ora_status = 'P'
                     WHERE seq = seqs(i).seq;

                    COMMIT;

                    IF (ln_cnt = 0) THEN
                        -- call process to build report
                        process(seqs(i).parameters);
                    ELSE
                        rqs_reports.format_report(seqs(i).parameters);
                    END IF;
                END IF;
            END LOOP;

            -- sleep to give reports and retry reports to process
            dbms_lock.sleep(10);
        END LOOP;

        -- check to see if any finalize processes need to be run
        FOR rec IN (SELECT id
                      FROM report_finalize_status
                     WHERE job_id = p_job_id)
        LOOP
            -- call the window service to finalize the report(s)
            wndservice(a_requestid => rec.id,
                       a_response  => l_response_text,
                       a_error     => l_err_number);

            IF (NVL(l_err_number, 0) != 0) THEN
                -- update status with error code
                UPDATE report_finalize_status
                   SET msg = l_response_text, status = 'E'
                 WHERE job_id = p_job_id
                   AND id = rec.id;
            END IF;
        END LOOP;

        -- wait for finalize processes to end
        LOOP
            SELECT NVL(COUNT(id), 0)
              INTO ln_cnt
              FROM report_finalize_status
             WHERE job_id = p_job_id
               AND status NOT IN ('C', 'E')
               AND update_date < SYSDATE + 4 / 24;

            EXIT WHEN ln_cnt = 0;

            -- sleep to give reports and retry reports to process
            dbms_lock.sleep(10);
        END LOOP;

        -- remove all canceled reports for this job
        DELETE report_xref
         WHERE job_id IN
                   (SELECT DISTINCT job_id
                      FROM report_queue_status
                           INNER JOIN report_xref USING (seq)
                     WHERE NVL(cancel_flg, 'N') = 'Y'
                       AND job_id = p_job_id);
    EXCEPTION
        WHEN OTHERS THEN
            rqs_utils.LOG(
                p_log_type  => 'E',
                p_job_id    => NULL,
                p_seq       => ln_seq,
                p_source    => 'rqs_process_request_id',
                p_msg       => SQLERRM,
                p_error_trace => dbms_utility.format_error_backtrace);

            UPDATE report_queue_status
               SET step_ind = 'E', ora_status = 'E'
             WHERE seq = ln_seq;

            COMMIT;
    END;                                               -- main processing loop
END rqs_process_request_id;
/


GRANT EXECUTE ON ABCREPORTS.RQS_PROCESS_REQUEST_ID TO ABCREPORTS_ROLE;
