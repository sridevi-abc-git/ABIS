CREATE OR REPLACE TRIGGER ABC.err$_self_certification_trg
    AFTER INSERT
    ON ABC.ERR$_SELF_CERTIFICATION 
    FOR EACH ROW
DECLARE
    t_to     VARCHAR2(4000);
    t_from   VARCHAR2(512);
    t_cc     VARCHAR2(4000);
    t_bcc    VARCHAR2(4000);
BEGIN
    FOR rec IN (SELECT ep.parametername, ep.parametervalue
                  FROM abc.email_parameters ep
                 WHERE ep.app = 'SELFCERT')
    LOOP
        CASE rec.parametername
            WHEN 'TO' THEN
                t_to   := rec.parametervalue;
            WHEN 'FROM' THEN
                t_from   := rec.parametervalue;
            WHEN 'CC' THEN
                t_cc   := rec.parametervalue;
            WHEN 'BCC' THEN
                t_bcc   := rec.parametervalue;
            ELSE
                NULL;
        END CASE;
    END LOOP;

    sitespecific.pkg_tlemail.sendemail(p_fromaddress => t_from,
                                       p_toaddress => t_to,
                                       p_cc        => t_cc,
                                       p_bcc       => t_bcc,
                                       p_subject   => 'Error: Updating SELF_CERTIFICATION table',
                                       p_body      =>   'License Number '
                                                     || CHR(9)
                                                     || :new.licensenumber
                                                     || CHR(13)
                                                     || CHR(10)
                                                     || 'License type'
                                                     || CHR(9)
                                                     || CHR(9)
                                                     || :new.licensetypecode
                                                     || CHR(13)
                                                     || CHR(10)
                                                     || 'ERROR'
                                                     || CHR(9)
                                                     || CHR(9)
                                                     || CHR(9)
                                                     || :new.ora_err_mesg$);
EXCEPTION
    WHEN OTHERS THEN
        NULL;
END;
/
