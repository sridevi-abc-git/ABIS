CREATE OR REPLACE FUNCTION ABCREPORTS.PRIORITYAPPLICATIONS(p_parms      IN OUT t_parameters,
                                                           p_status_ind IN OUT VARCHAR2) 
              RETURN BLOB IS 
-- ****************************************************************************
-- File:        PRIORITYAPPLICATIONS.fnc  
-- Author:      Timothy J. Lord
--
-- $Rev$  
-- $Date$
-- Last Changed By:  $Author$
--
-- Description:    
--
-- 
-- History:
-------------------------------------------------------------------------------
--    Date                  Comment
-- 07/03/2017 TJL   12508   Initial file create 
-- 09/15/2020 TJL   21922   Changed how the data is selected for new fees that 
--                            were added. 'ORI' no longer used.
-- ****************************************************************************
    lblob_csv       BLOB;
    t_start_date    DATE;
    t_end_date      DATE;
    t_applicationjobid   NUMBER;
    t_currfeeobjid       NUMBER := 0;
    t_csv_row            VARCHAR2(8096);
    t_87                BOOLEAN := false;

    BEGIN 
        DBMS_LOB.CREATETEMPORARY(lblob_csv, TRUE, dbms_lob.CALL);

        t_start_date := TO_DATE(p_parms.get_value('START_DATE'), 'MM/DD/YYYY');
        t_end_date   := TO_DATE(p_parms.get_value('END_DATE'), 'MM/DD/YYYY');
        p_parms.upd_value('REPORT_DATE', TO_CHAR(SYSDATE, 'MM/DD/YYYY HH:MI PM'));

    FOR payment
        IN (-- get all payments made for this day
            SELECT p.objectid paymentobjectid, api.pkg_columnquery.numericvalue(p.objectid, 'PaymentId') paymentid
              FROM TABLE(CAST(api.pkg_simplesearch.castableobjectsbyindexrange(
                                  'o_Payment',
                                  'PaymentDateStored',
                                  TO_CHAR(t_start_date
                                                              , 'YYYY-MM-DD'),
                                  TO_CHAR(t_end_date
                                                              , 'YYYY-MM-DD')) AS api.udt_objectlist)) p)
    LOOP
        FOR paymenttransactions
            IN (  SELECT DISTINCT api.pkg_columnquery.VALUE(pt.objectid, 'FeeObjId') feeobjid
                    FROM TABLE(
                             CAST(
                                 api.pkg_simplesearch.castableobjectsbyindex('o_paymenttransactions',
                                                                             'paymentid',
                                                                             payment.paymentid) AS api.udt_objectlist))
                         pt
                ORDER BY feeobjid)
        LOOP
            CONTINUE WHEN NVL(REGEXP_SUBSTR(api.pkg_columnquery.VALUE(paymenttransactions.feeobjid, 'Description'),
                                            '[^ ]+',
                                            1,
                                            3),
                              'X') NOT IN ('APP', 'ICO')
                       OR paymenttransactions.feeobjid = t_currfeeobjid;

            t_currfeeobjid       := paymenttransactions.feeobjid;
            t_applicationjobid   := api.pkg_columnquery.VALUE(paymenttransactions.feeobjid, 'jobid');
            t_87 := (instr(api.pkg_columnquery.value(t_applicationjobid, 'PrimaryLicenseTypeCodes'), '87') > 0); 
            CONTINUE WHEN api.pkg_columnquery.VALUE(t_applicationjobid, 'IsPriorityApplication') = 'N'
                        and not t_87;
            CONTINUE WHEN to_char(t_start_date, 'yyyy') != to_char(api.pkg_columnquery.datevalue(t_applicationjobid, 'CreatedDate'), 'YYYY');

            t_csv_row := '"' ||
                   api.pkg_columnquery.VALUE(t_applicationjobid, 'CountyName')  --api.pkg_columnquery.VALUE(payment.paymentobjectid, 'TransmittalOffice')
                || '","'
                ||   api.pkg_columnquery.VALUE(t_applicationjobid, 'IntakeOfficeCorral')  --api.pkg_columnquery.VALUE(payment.paymentobjectid, 'TransmittalOffice')
                || '",'
                || LPAD(api.pkg_columnquery.VALUE(payment.paymentobjectid, 'OfficeCode'), 2, '0')
                || ',"'
                || TO_CHAR(api.pkg_columnquery.datevalue(payment.paymentobjectid, 'PaymentDateStored'), 'MM/DD/YY')
                || '","'
                || api.pkg_columnquery.VALUE(payment.paymentobjectid, 'LicenseNumber')
                || '","'
                || api.pkg_columnquery.VALUE(t_applicationjobid, 'PrimaryApplicant')
                || '","'
                || REGEXP_SUBSTR(api.pkg_columnquery.VALUE(t_applicationjobid, 'PrimaryLicenseTypeCodesPend'),
                                 '[^()]+',
                                 1,
                                 2)
                || '","'
                || api.pkg_columnquery.VALUE(t_applicationjobid, 'PrimaryLicenseTypeCodes')  --NVL(api.pkg_columnquery.VALUE(api.pkg_columnquery.numericvalue(paymenttransactions.FeeObjId, 'LicenseFeeSchedId'), 'LicenseTypeCode'),'N/A')
                || '","'
                || api.pkg_columnquery.VALUE(paymenttransactions.feeobjid, 'Description')
                || '",'
                || NVL(api.pkg_columnquery.numericvalue(paymenttransactions.feeobjid, 'SecondaryCount'), 0)
                || ','
                || api.pkg_columnquery.VALUE(payment.paymentobjectid, 'ReceiptNumber')  --receiptnumber,
                || ','
                || api.pkg_columnquery.numericvalue(
                       api.pkg_columnquery.numericvalue(payment.paymentobjectid, 'ReceiptPaymentId'),
                       'PaymentAmountSummed'  --receiptamount
                                             );
                                             
        t_csv_row   :=
               REGEXP_REPLACE(t_csv_row, '[[:cntrl:]]', '')
            || CHR(13)
            || CHR(10);

                           
                dbms_lob.append (lblob_csv, utl_raw.cast_to_raw(t_csv_row)); 
            END LOOP;
        end loop;
        RETURN lblob_csv;
        
    EXCEPTION
        WHEN OTHERS THEN
            rqs_utils.log(p_log_type          =>  'E',
                          p_job_id            =>  p_parms.get_value('JOB_ID'),
                          p_seq               =>  p_parms.get_value('SEQ'),
                          p_source            =>  'PRJUS750',
                          p_msg               =>  SQLERRM,
                          p_additional_data   =>  NULL,
                          p_error_trace       =>  dbms_utility.format_error_backtrace); 
                                    
            p_status_ind := 'E';
            
                RETURN utl_raw.cast_to_raw('ERROR: ' || SQLERRM || CHR(10) || CHR(13) ||
                                           'TRACE: ' || dbms_utility.format_error_backtrace);
            
    END PRIORITYAPPLICATIONS;
/
