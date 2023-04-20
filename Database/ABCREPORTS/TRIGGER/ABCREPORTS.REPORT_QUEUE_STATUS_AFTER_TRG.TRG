CREATE OR REPLACE TRIGGER ABCREPORTS.REPORT_QUEUE_STATUS_AFTER_TRG
AFTER UPDATE
ON ABCREPORTS.REPORT_QUEUE_STATUS
REFERENCING NEW AS New OLD AS Old
FOR EACH ROW
BEGIN
    IF (:new.step_ind IN ('E', 'C')) OR
       (:old.step_ind = 'Q' AND :new.CANCEL_FLG = 'Y') THEN
        INSERT INTO report_queue_history
                (seq, report_parameters, created_by, create_date)
           SELECT seq, report_parameters, created_by, NVL(start_time, SYSDATE)
             FROM report_queue
            WHERE seq = :old.seq;

        -- delete queue record on report completion        
        DELETE report_queue WHERE seq = :old.seq;
    END IF; 
    
    IF (:new.ora_status = 'P') THEN
        UPDATE report_queue 
           SET start_time = SYSDATE
         WHERE seq = :old.seq;    
    END IF;

END REPORT_QUEUE_STATUS_AFTER_TRG;
/
