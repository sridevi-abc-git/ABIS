CREATE OR REPLACE TRIGGER ABCREPORTS.report_autorun_log_trg
BEFORE INSERT OR UPDATE
ON ABCREPORTS.REPORT_AUTORUN_LOG
REFERENCING NEW AS new OLD AS old
FOR EACH ROW
BEGIN
    IF INSERTING THEN
        :new.job_id     := report_autorun_log_seq.NEXTVAL;
        :new.user_login := USER;
        :new.start_time := SYSDATE;
    END IF;

END report_autorun_log_trg;
/
