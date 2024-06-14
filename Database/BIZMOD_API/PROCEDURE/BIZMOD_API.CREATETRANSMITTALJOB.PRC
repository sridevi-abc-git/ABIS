CREATE OR REPLACE PROCEDURE BIZMOD_API.createtransmittaljob(
    a_seq          IN NUMBER,
    a_asofdate     IN DATE)
IS
    -- ****************************************************************************
    -- File:        BIZMOD_API.CREATETRANSMITTALJOB.PRC
    -- Author:      Timothy J. Lord
    --
    -- Purpose: Create transmittals for payments made
    --
    -- History:
    -------------------------------------------------------------------------------
    --            Date          Ticket      Comment
    --   1.0   01/16/2024  TJL BIZ-14091  Process created from e_payment.createtransmittal
    --                                          function.
    --   2.0   03/06/2024  TJL BIZ-14725  Corrected format problem in email body
    --   3.0.1 05/20/2024  TJL BIZ-15523  Change code to how transmittal are created from
    --                                      First Data Settlement file upload. Add voided
    --                                      payment filters.
    --   4.0   06/14/2024  TJL BIZ-15691  Corrected bug when there is more than one payment medium
    --                                      for ECheck (E-Check and Business E-Check) needed to be
    --                                      handle as one type.
    -- ************************************************************************
    t_transmittal  api.pkg_definition.udt_id;
    t_objectlist   api.udt_objectlist;
    t_sqlerrm      VARCHAR2(4000);
    t_backtrace    VARCHAR2(4000);
    t_processid    api.pkg_definition.udt_id;
    t_filename     VARCHAR2(512);
    t_packet       CLOB;
    t_paymentmethod VARCHAR2(40);

    t_transmittaldefid api.pkg_definition.udt_id;
    t_transmittalobjectid api.pkg_definition.udt_id;
    t_rel          api.pkg_definition.udt_id;
    t_info         VARCHAR2(4000);
    t_paymentamount NUMBER := 0;
    t_paymentcount NUMBER := 0;
    t_fd_paymentamount  NUMBER := 0;
    t_fd_payment_count NUMBER := 0;
BEGIN
    api.pkg_logicaltransactionupdate.resettransaction;
    ROLLBACK;

    -- 06/14/2024  TJL BIZ-15691
    WITH
        fd
        AS
            (SELECT fd.filename,
                    CASE fd.paymentmedium
                        WHEN 'Credit Card' THEN fd.paymentmedium
                        ELSE 'ECheck'
                    END    paymentmedium,
                    fd.paymentamount
               FROM bizmod_api.first_data_t fd
              WHERE fd.logseq = a_seq
                AND fd.abispayment = 'Y'
                AND fd.feeactivity NOT LIKE '%AWF%')
      SELECT fd.filename,
             fd.paymentmedium,
             SUM(fd.paymentamount),
             COUNT(1)
          INTO t_filename, t_paymentmethod, t_fd_paymentamount, t_fd_payment_count
        FROM fd
    GROUP BY fd.filename, fd.paymentmedium;  
    
    -- ************************************************************
    --  Create a list of payment for this transmittal
    -- ************************************************************
    SELECT api.udt_object(p.paymentobjectid)     paymentobjectid
      BULK COLLECT INTO t_objectlist
      FROM (SELECT DISTINCT p2.paymentobjectid
              FROM bizmod_api.e_payments_t  p2
                   JOIN bizmod_api.first_data_t fd
                       ON (p2.confirmationid = fd.confirmationnumber
                       AND fd.logseq = a_seq
                       AND fd.abispayment = 'Y')
             WHERE NVL(p2.paymentobjectid, 0) > 0
               AND p2.description NOT LIKE '%AWF%'
               AND api.pkg_columnquery.VALUE(p2.paymentobjectid,
                                             'PaymentPayeeRef') =
                   p2.confirmationid
               AND p2.transmittalbatch IS NULL
               AND api.pkg_columnquery.VALUE(p2.paymentobjectid,
                                             'Objectdefname') =
                   'o_Payment') p
           LEFT OUTER JOIN api.relationships rn
               ON rn.endpointid =
                  api.pkg_configquery.endpointidforname('j_Transmittal',
                                                        'Payment')
              AND rn.toobjectid = p.paymentobjectid
     WHERE rn.fromobjectid IS NULL;

    BEGIN
        -- *****************************************************************
        -- Create Transmittal job
        -- *****************************************************************
        -- check for last opened transmital not completed
        DBMS_OUTPUT.put_line('new transmittal');

        t_transmittaldefid :=
            api.pkg_configquery.objectdefidforname('j_Transmittal');
        t_transmittalobjectid := api.pkg_objectupdate.new(t_transmittaldefid);

        api.pkg_columnupdate.setvalue(t_transmittalobjectid,
                                      'TransmittalType',
                                      t_paymentmethod);
        api.pkg_columnupdate.setvalue(t_transmittalobjectid,
                                      'PaymentCount',
                                      1);
        api.pkg_columnupdate.setvalue(t_transmittalobjectid,
                                      'PaymentTotalAmount',
                                      1);

        api.pkg_logicaltransactionupdate.endtransaction;
        COMMIT;

        -- 3.0 05/20/2024 TJL
        -- ******************************************************************
        --  Remove unwanted Payments from transmittal
        -- ******************************************************************
        FOR rec
            IN (SELECT r.relationshipid
                  FROM api.relationships r
                 WHERE r.endpointid =
                       api.pkg_configquery.endpointidforname('j_Transmittal',
                                                             'Payment')
                   AND r.fromobjectid = t_transmittalobjectid)
        LOOP
            api.pkg_relationshipupdate.remove(rec.relationshipid);
        END LOOP;

        -- ******************************************************************
        --  Add Payments to transmittal
        -- ******************************************************************
        FOR rec IN (SELECT objectid FROM TABLE(t_objectlist))
        LOOP
            DBMS_OUTPUT.put_line('Pay ID: ' || rec.objectid);
            -- add new relationship (endpointid, fromobjectid, toobjectid)
            t_rel :=
                api.pkg_relationshipupdate.new(
                    api.pkg_configquery.endpointidforname('j_Transmittal',
                                                          'Payment'),
                    t_transmittalobjectid,
                    rec.objectid);
        END LOOP;

        SELECT SUM(
                   api.pkg_columnquery.numericvalue(toobjectid,
                                                    'PaymentAmount')),
               COUNT(1)
          INTO t_paymentamount, t_paymentcount
          FROM api.relationships r
         WHERE r.endpointid =
               api.pkg_configquery.endpointidforname('j_Transmittal',
                                                     'Payment')
           AND r.fromobjectid = t_transmittalobjectid;

        -- *********************************************************************
        -- Update transmittal information
        -- *********************************************************************
        api.pkg_columnupdate.setvalue(t_transmittalobjectid,
                                      'PaymentCount',
                                      t_paymentcount);
        api.pkg_columnupdate.setvalue(t_transmittalobjectid,
                                      'PaymentTotalAmount',
                                      t_paymentamount);

        api.pkg_logicaltransactionupdate.endtransaction;
        COMMIT;

        -- 09/06/2023 TJL BIZ-12648  Added
        -- *****************************************************************
        -- Find and process Prepare Transmittal
        -- *****************************************************************
        -- get processes
        SELECT processid
          INTO t_processid
          FROM api.processes p
         WHERE p.jobid = t_transmittalobjectid
           AND p.processtypeid =
               api.pkg_objectdefquery.idforname('p_PrepareTransmittal');

        -- set outcome to Complete (process will complete when COMMIT is executed.
        api.pkg_logicaltransactionupdate.starttransaction;
        api.pkg_columnupdate.setvalue(t_processid, 'Outcome', 'Sent to HQ');
        api.pkg_logicaltransactionupdate.endtransaction;
        COMMIT;
        -- end BIZ-12648

        -- *****************************************************************
        -- Casher the transmittal
        -- *****************************************************************
        api.pkg_logicaltransactionupdate.starttransaction;

        api.pkg_columnupdate.setvalue(t_transmittalobjectid,
                                      'CashieredDate',
                                      SYSDATE);
        api.pkg_columnupdate.setvalue(t_transmittalobjectid,
                                      'PaymentCountCashier',
                                      t_paymentcount);
        api.pkg_columnupdate.setvalue(t_transmittalobjectid,
                                      'BatchTotal',
                                      t_paymentamount);

        api.pkg_logicaltransactionupdate.endtransaction;
        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            t_sqlerrm := SUBSTR(SQLERRM, 1, 3990);
            t_backtrace :=
                SUBSTR(DBMS_UTILITY.format_error_backtrace, 1, 3990);

            api.pkg_logicaltransactionupdate.resettransaction;
            ROLLBACK;
            DBMS_OUTPUT.put_line(t_sqlerrm);

        -- remove all records from transmittal
        FOR rec
            IN (SELECT r.relationshipid
                  FROM api.relationships r
                 WHERE r.endpointid =
                       api.pkg_configquery.endpointidforname('j_Transmittal',
                                                             'Payment')
                   AND r.fromobjectid = t_transmittalobjectid)
        LOOP
            api.pkg_relationshipupdate.remove(rec.relationshipid);

            api.pkg_logicaltransactionupdate.endtransaction;
            COMMIT;
        END LOOP;
    END;

    FOR pm
        IN (SELECT r.toobjectid     transmittalobjectid,
                   t.objectid       paymentobjectid
              FROM TABLE(t_objectlist)  t
                   LEFT OUTER JOIN api.relationships r
                       ON r.endpointid =
                          api.pkg_configquery.endpointidforname(
                              'o_Payment',
                              'Transmittal')
                      AND r.fromobjectid = t.objectid)
    LOOP
        UPDATE bizmod_api.e_payments_t p
           SET p.transmittalbatch = NVL(pm.transmittalobjectid, -1),
               p.transmittalbatchdate =
                   api.pkg_columnquery.datevalue(pm.transmittalobjectid,
                                                 'CompletedDate')
         WHERE p.paymentobjectid = pm.paymentobjectid;
    END LOOP;

    t_info :=
        t_info
        || CHR(13)
        || CHR(9)
        || 'Settlement File Name: '
        || CHR(9)
        || t_filename
        || CHR(13)
        || CHR(9)
        || 'File Number: '
        || CHR(9)
        || RPAD(
               api.pkg_columnquery.VALUE(t_transmittalobjectid,
                                         'externalfilenum'),
               10,
               ' ')
        || CHR(13)
        || CHR(9)
        || RPAD(
               api.pkg_columnquery.VALUE(t_transmittalobjectid,
                                         'TransmittalType'),
               15,
               ' ')
        || CHR(13)
        || CHR(9)
        || 'Payment Count: '
        || LPAD(
               api.pkg_columnquery.VALUE(t_transmittalobjectid,
                                         'PaymentCount'),
               4,
               ' ')
        || CHR(9)
        || '(Expected: ' || t_fd_payment_count ||')'
        || CHR(13)
        || CHR(9)
        || 'Payment Total Amt: '
        || LPAD(
               TO_CHAR(
                   api.pkg_columnquery.VALUE(t_transmittalobjectid,
                                             'PaymentTotalAmount'),
                   'fm9G999G999D00'),
               10,
               ' ')
        || CHR(9)
        || '(Expected: ' || TO_CHAR(t_fd_paymentamount, 'fm9G999G999D00') ||')'
               
        || CHR(13);

    INSERT INTO bizmod_api.e_process_log_t(seq,
                                           processjob,
                                           info,
                                           errmsg,
                                           bktrace)
         VALUES (a_seq,
                 'CREATETRANSMITTALJOB',
                 t_info,
                 t_sqlerrm,
                 t_backtrace);

    COMMIT;

    -- Generate email of completion of first data processing
    bizmod_api.utl_licenseinfo.sendemail(
        a_subject   => 'Transmittal Job Completed',
        a_body      => t_info);
EXCEPTION
    WHEN NO_DATA_FOUND
    THEN
        NULL;
    WHEN OTHERS
    THEN
        t_sqlerrm := SUBSTR(SQLERRM, 1, 3990);
        t_backtrace := SUBSTR(DBMS_UTILITY.format_error_backtrace, 1, 3990);

        api.pkg_logicaltransactionupdate.resettransaction;
        ROLLBACK;

        INSERT INTO bizmod_api.e_process_log_t(seq,
                                               processjob,
                                               info,
                                               errmsg,
                                               bktrace)
             VALUES (a_seq,
                     'CREATETRANSMITTALJOB',
                     t_info,
                     t_sqlerrm,
                     t_backtrace);

        COMMIT;
END createtransmittaljob;
/


GRANT EXECUTE ON BIZMOD_API.CREATETRANSMITTALJOB TO POSSEEXTENSIONS;
