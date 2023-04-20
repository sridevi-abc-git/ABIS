CREATE OR REPLACE FUNCTION ABCREPORTS.pendingtransmittals(p_parms      IN OUT t_parameters,
                                               p_status_ind IN OUT VARCHAR2) 
              RETURN BLOB IS 
-- ****************************************************************************
-- File:        pendingtransmittals.fnc  
-- Author:      Timothy J. Lord
--
-- $Rev: 3044 $  
-- $Date: 2016-09-27 15:06:25 -0700 (Tue, 27 Sep 2016) $
-- Last Changed By:  $Author: tlord $
--
-- Description:    
--
-- 
-- History:
-------------------------------------------------------------------------------
--    Date                  Comment
-- 10/28/2015 TJL   8282    Updated for enhancement changes 
-- 03/11/2016 TJL   9202    Modified cursor where clause to match Posse where clause
-- 03/21/2016 TJL   9069    Added checking for not a change record
-- 09/27/2016 TJL   7213    Changed output from CLOB to BLOB  
-- ****************************************************************************

    CURSOR      query(p_offices IN T_OFFICEOBJECT) IS
       SELECT p.objectid,
               p.payeereference paymentid,
               p.paymentdatestored, 
               p.cabinincomeind,
               p.paymentamount, 
               p.paymentmethodcode, 
               rp.receiptnumber, 
               rp.datecompleted, 
               p.office, 
               p.licensenumber, 
               FLOOR(SYSDATE - p.paymentdatestored) daysprior
          FROM query.o_payment p
               JOIN query.r_generatereceiptpayment r ON r.paymentobjectid = p.objectid
               JOIN query.p_receiptpayments rp ON rp.objectid = r.generatereceiptprocessid
         WHERE p.objectid IN 
               (SELECT p.objectid
                  FROM query.r_PaymentOffice x
                  JOIN query.o_payment p ON p.objectid = x.PaymentObjectId
                  JOIN query.r_generatereceiptpayment r ON r.paymentobjectid = p.objectid
                  JOIN query.p_receiptpayments rp ON rp.objectid = r.generatereceiptprocessid
                 WHERE r.paymentobjectid  >= (SELECT MIN(d.PaymentObjectId)
                                                FROM  Sitespecific.PendingTransmittal_Temp d)
                   AND rp.datecompleted IS NOT NULL
                   AND p.isvoidedflag = 'N'
                   AND UPPER(p.cabinincomeind) != 'C'
                   AND NOT EXISTS (SELECT 1
                        FROM query.r_transmittalpayment rt
                        WHERE rt.paymentobjectid = p.objectid)
                   AND x.officeobjectid IN (SELECT officeobjectid FROM TABLE(p_offices))
               )
         ORDER BY office;

    office_id       t_officeobject := NULL;
    lv_status_msg   VARCHAR2(8096);
    lblob_csv       BLOB;
    lv_csv_row      VARCHAR2(8096);
    lb_send_email   BOOLEAN         := FALSE;
    
BEGIN
    DBMS_LOB.CREATETEMPORARY(lblob_csv, TRUE, dbms_lob.CALL);
    office_id := rqs_utils.BuildOfficeList(p_parms.get_value('OFFICEOBJECTID'),
                                                   lv_status_msg);

    IF (lv_status_msg IS NULL) THEN 
        p_parms.upd_value('REPORT_DATE', TO_CHAR(SYSDATE, 'MM/DD/YYYY HH:MI PM'));
        
        FOR rec IN query(office_id)
        LOOP
            lv_csv_row := rec.objectid || ','
                       || rec.paymentid || ','
                       || '"' || TO_CHAR(rec.paymentdatestored, 'MM/DD/YYYY') || '",'
                       || '"' ||rec.cabinincomeind || '",'
                       || rec.paymentamount || ',' 
                       || '"' || rec.paymentmethodcode || '",'
                       || rec.receiptnumber || ','  
                       || '"' || TO_CHAR(rec.datecompleted, 'MM/DD/YYYY') || '",'
                       || '"' || rec.office || '",'
                       || '"' || rec.licensenumber || '",'
                       || FLOOR(SYSDATE - rec.paymentdatestored) 
                       || CHR(13) || CHR(10);   
                       
            dbms_lob.append (lblob_csv, utl_raw.cast_to_raw(lv_csv_row)); 
            
            IF (FLOOR(SYSDATE - rec.paymentdatestored) > 4) THEN lb_send_email := TRUE; END IF;          

        END LOOP;
        
        IF (NOT lb_send_email AND p_parms.get_value('SOURCE') = 'AUTO') THEN
            p_parms.upd_value('EMAIL_NOTIFICATION', 'NO');
        END IF; 
    ELSE
        dbms_lob.append (lblob_csv, utl_raw.cast_to_raw(lv_status_msg));
        p_status_ind := 'E';
    END IF;
    
    RETURN lblob_csv;

 EXCEPTION
    WHEN OTHERS THEN
        rqs_utils.log(p_log_type          =>  'E',
                      p_job_id            =>  p_parms.get_value('JOB_ID'),
                      p_seq               =>  p_parms.get_value('SEQ'),
                      p_source            =>  'Pending Transmittals Report',
                      p_msg               =>  SQLERRM,
                      p_additional_data   =>  NULL,
                      p_error_trace       =>  dbms_utility.format_error_backtrace); 

        p_status_ind := 'E';
        RETURN utl_raw.cast_to_raw('ERROR: ' || SQLERRM || CHR(10) || CHR(13) ||
                                   'TRACE: ' || dbms_utility.format_error_backtrace);
        
END PENDINGTRANSMITTALS;
/


GRANT EXECUTE ON ABCREPORTS.PENDINGTRANSMITTALS TO ABCREPORTS_ROLE;
