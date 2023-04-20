CREATE OR REPLACE TRIGGER ABCREPORTS.REPORT_QUEUE_STATUS_BEFORE_TRG
BEFORE UPDATE
ON ABCREPORTS.REPORT_QUEUE_STATUS
REFERENCING NEW AS New OLD AS Old
FOR EACH ROW
BEGIN
    :new.update_date := sysdate;
    
    IF (:new.step_ind = 'R') THEN
        -- incrument retry count
        :new.retry_cnt := :old.retry_cnt + 1;
        IF (:new.retry_cnt > 2) THEN 
            :new.step_ind := 'E';
        END IF;
    END IF;          
           
END REPORT_QUEUE_STATUS_BEFORE_TRG;
/
