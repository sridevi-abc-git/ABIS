CREATE OR REPLACE TRIGGER BIZMOD_API.E_PROCESS_LOG_T_TRG
    AFTER INSERT
    ON BIZMOD_API.E_PROCESS_LOG_T
    FOR EACH ROW
DECLARE
    t_body         VARCHAR2(32000);
    t_to           VARCHAR2(4000);
    t_from         VARCHAR2(4000);
    t_cc           VARCHAR2(4000);
    t_bcc          VARCHAR2(4000);
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

        SELECT pto,
               pfrom,
               pcc,
               pbcc
          INTO t_to,
               t_from,
               t_cc,
               t_bcc
          FROM (SELECT m.parametername, m.parametervalue
                  FROM abc.email_parameters m
                 WHERE app = 'EPAYMENT_ERR')
               PIVOT (MAX(parametervalue)
                     FOR parametername
                     IN ('TO' pto, 'FROM' pfrom, 'CC' pcc, 'BCC' pbcc));

        IF (t_from IS NOT NULL)
        THEN
            sitespecific.pkg_tlemail.sendemail(
                p_fromaddress => t_from,
                p_toaddress => t_to,
                p_cc        => t_cc,
                p_bcc       => t_bcc,
                p_subject   => 'Process Job ' || :new.processjob,
                p_body      => t_body,
                p_mimetype  => 'text/plain');
        END IF;
    END IF;
EXCEPTION
    WHEN OTHERS
    THEN
        NULL;
END;
/
