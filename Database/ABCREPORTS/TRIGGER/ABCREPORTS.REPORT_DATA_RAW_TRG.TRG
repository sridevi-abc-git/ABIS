CREATE OR REPLACE TRIGGER ABCREPORTS.REPORT_DATA_RAW_TRG
BEFORE INSERT
ON ABCREPORTS.REPORT_DATA_RAW
REFERENCING NEW AS New OLD AS Old
FOR EACH ROW
BEGIN
    DECLARE
    ln_cnt      NUMBER;
    
    BEGIN
        -- remove old record if one exists
        SELECT NVL(COUNT(seq), 0)
          INTO ln_cnt
          FROM report_data_raw
         WHERE seq = :new.seq;  
         
        IF (ln_cnt = 1) THEN
            DELETE report_data_raw WHERE seq = :new.seq;
        END IF;
    END;
               
END REPORT_DATA_RAW_TRG;
/
