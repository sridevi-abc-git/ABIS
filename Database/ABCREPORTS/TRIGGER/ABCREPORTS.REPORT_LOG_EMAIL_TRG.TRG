CREATE OR REPLACE TRIGGER ABCREPORTS.REPORT_LOG_EMAIL_TRG
AFTER INSERT
ON ABCREPORTS.REPORT_ERROR_LOG
REFERENCING NEW AS New OLD AS Old
FOR EACH ROW
WHEN (
new.log_type_ind IN ('E')
      )
BEGIN
    DECLARE
        lb_log      BOOLEAN       := (UPPER(NVL(RQS_UTILS.GET_CTRL_VALUE('EMAIL_LOG_ERRORS'), 'N')) IN ('Y', 'T'));
        lv_filter   VARCHAR2(500) := NVL(RQS_UTILS.GET_CTRL_VALUE('EMAIL_LOG_FILTERS'), '.');
        lv_body     VARCHAR2(8000);
         
    BEGIN

        IF (lb_log AND (REGEXP_INSTR(:new.msg, lv_filter, 1, 1, 0, 'i') > 0)) THEN
            lv_body := 
                '<table>
                    <tr><td>System:</td><td>'       || sys_context('userenv','db_name') || '</td></tr>
                    <tr><td>Source:</td><td>'       || :new.src                         || '</td></tr>
                    <tr><td>Seq:</td><td>'          || :new.seq                         || '</td></tr>
                    <tr><td>Additional: </td><td>'  || :new.additional_data             || '</td></tr>
                    <tr style="vertical-align:top;"><td>Message:</td><td>'     || :new.msg      || '</td></tr>            
                </table>';
            
            RQS_EMAIL.SendEmail(p_fromAddress  => 'ITServiceDesk@abc.ca.gov',
                                p_toAddress    => RQS_UTILS.GET_CTRL_VALUE('EMAIL_LOG_TO'),
                                p_cc           => RQS_UTILS.GET_CTRL_VALUE('EMAIL_LOG_CC'),
                                p_bcc          => RQS_UTILS.GET_CTRL_VALUE('EMAIL_LOG_BCC'),
                                p_subject      => 'ERROR LOG FROM ' || sys_context('userenv','db_name'),
                                p_body         => REPLACE(lv_body,  CHR(13) || CHR(10), '<br/>'),
                                p_file_name    => NULL,
                                p_clob         => NULL);
        END IF;
    END;    

EXCEPTION WHEN OTHERS THEN NULL; 
    
END REPORT_LOG_EMAIL_TRG;
/
