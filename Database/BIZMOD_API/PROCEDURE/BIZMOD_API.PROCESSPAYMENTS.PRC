CREATE OR REPLACE PROCEDURE BIZMOD_API.processpayments(
    a_processid    api.pkg_definition.udt_id,
    a_asofdate     DATE)
IS
    -- ****************************************************************************
    -- File:        PROCESSPAYMENTS.PRC
    -- Author:      Timothy J. Lord
    --
    -- Purpose :
    --
    -- History:
    -------------------------------------------------------------------------------
    --    Date           Ticket     Comment
    --  05/31/2023 TJL            Initial Procedure Created
    --  12/20/2023 TJL            Added Logging
    --  01/18/2024 TJL  BIZ-14091   Change process called for transmittal and AWF Batches removed emailing
    -- ****************************************************************************
    t_body         VARCHAR2(32000);
    t_error        VARCHAR2(4000);
    t_paidcount    NUMBER := 0;
    t_results      CLOB;
    t_transmittal  api.udt_objectlist;
    t_awfbatch     NUMBER;
    t_msg          VARCHAR2(4000);
    t_seq          NUMBER;
    t_to           VARCHAR2(4000);
    t_from         VARCHAR2(4000);
    t_cc           VARCHAR2(4000);
    t_bcc          VARCHAR2(4000);
BEGIN

                bizmod_api.createjob(
                    a_procedure => 'CREATEAWFPAYMENTSJOB',
                    a_description => 'Create AWF Payment Batch',
                    a_argument1 => '1');

                bizmod_api.createjob(a_procedure => 'CREATETRANSMITTALJOB',
                                     a_description => 'Create Transmittals');

    -- Call transmittal job to create a transmittal batch from first data processing
--    t_transmittal := e_payment.createtransmittal;
--
--    -- process any AWF payments that need to be made
--    begin
--    t_awfbatch := bizmod_api.e_payment.createawfpayments(1);
--    exception when others then
--    
--    null;
--    END;
----    t_body := 'Process Cleared Payments Job Completed' || CHR(10) || CHR(13);
--    t_body := 'Payments Processed' || CHR(13);
--
--    IF (t_transmittal.COUNT > 0)
--    THEN
--        t_body :=
--            t_body
--            || 'Transmittal Batch(es): '
--            || CHR(13);
--
--        FOR rec IN (SELECT objectid FROM TABLE(t_transmittal))
--        LOOP
--            t_body :=
--                t_body
--                || CHR(9)
--                || api.pkg_columnquery.VALUE(rec.objectid, 'externalfilenum')
--                || CHR(13);
--        END LOOP;
--    END IF;
--
--    -- Generate email of completion of first data processing
--    SELECT pto,
--           pfrom,
--           pcc,
--           pbcc
--      INTO t_to,
--           t_from,
--           t_cc,
--           t_bcc
--      FROM (SELECT m.parametername, m.parametervalue
--              FROM abc.email_parameters m
--             WHERE app = 'EPAYMENT')
--           PIVOT (MAX(parametervalue)
--                 FOR parametername
--                 IN ('TO' pto, 'FROM' pfrom, 'CC' pcc, 'BCC' pbcc));
--
--    IF (t_from IS NOT NULL)
--    THEN
--        sitespecific.pkg_tlemail.sendemail(
--            p_fromaddress => t_from,
--            p_toaddress => t_to,
--            p_cc        => t_cc,
--            p_bcc       => t_bcc,
--            p_subject   => 'Cleared Payment Job Completed',
--            p_body      => t_body,
--            p_mimetype  => 'text/plain');
--    END IF;
END;
/


GRANT EXECUTE ON BIZMOD_API.PROCESSPAYMENTS TO ABC;

GRANT EXECUTE ON BIZMOD_API.PROCESSPAYMENTS TO POSSEDBA;

GRANT EXECUTE ON BIZMOD_API.PROCESSPAYMENTS TO POSSEEXTENSIONS;
