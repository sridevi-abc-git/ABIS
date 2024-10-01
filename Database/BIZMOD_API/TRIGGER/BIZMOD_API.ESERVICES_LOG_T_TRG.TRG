CREATE OR REPLACE TRIGGER eservices_log_t_trg
    AFTER UPDATE OF err
    ON bizmod_api.eservices_log_t
	FOR EACH ROW
DECLARE
    t_body         VARCHAR2(32000);
BEGIN
    
        t_body :=
            'Process Job '
            || :new.request
            || ' Failed'
            || CHR(13)
            || 'Seq Id: '
            || CHR(9)
            || :new.seq
            || CHR(13)
            || 'Error:  '
            || CHR(13)
            || :new.err;
 
        bizmod_api.utl_licenseinfo.sendemail(
            a_process   => 'EMAIL_ERR',
            a_subject   => 'Request :  ' || :new.request || ' has Errors',
            a_body      => t_body);
  
END;
/
SHOW ERRORS;
