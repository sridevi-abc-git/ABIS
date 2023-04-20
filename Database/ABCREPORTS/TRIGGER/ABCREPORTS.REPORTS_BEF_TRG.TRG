CREATE OR REPLACE TRIGGER ABCREPORTS.REPORTS_BEF_TRG
BEFORE INSERT
ON ABCREPORTS.REPORTS
REFERENCING NEW AS New OLD AS Old
FOR EACH ROW
BEGIN
    DECLARE
    ln_cnt      NUMBER;
    
    BEGIN
        -- remove old record if one exists
        SELECT NVL(COUNT(seq), 0)
          INTO ln_cnt
          FROM reports
         WHERE seq = :new.seq;  
         
        IF (ln_cnt = 1) THEN
            DELETE reports WHERE seq = :new.seq;
        END IF;
    END;
               
END REPORTS_BEF_TRG;
/
