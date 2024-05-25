CREATE OR REPLACE TRIGGER BIZMOD_API.E_PROCESS_LOG_T_TRG
    AFTER INSERT
    ON bizmod_api.e_process_log_t
    FOR EACH ROW
DECLARE
    t_body         VARCHAR2(32000);
BEGIN
    IF (:new.errmsg IS NOT NULL)
    THEN
        t_body :=
            'Process Job '
            || :new.processjob
            || ' Failed'
            || CHR(13)
            || 'Log Id: '
            || :new.logid
            || CHR(13)
            || :new.info
            || CHR(13)
            || 'Error:  '
            || :new.errmsg
            || CHR(13)
            || 'Trace:  '
            || :new.bktrace;

        bizmod_api.utl_licenseinfo.sendemail(
            a_process   => 'EMAIL_ERR',
            a_subject   => 'Process Job ' || :new.processjob || ' has Errors',
            a_body      => t_body);
    END IF;
EXCEPTION
    WHEN OTHERS
    THEN
        NULL;
END;
/
