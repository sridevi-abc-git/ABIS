CREATE OR REPLACE FUNCTION ABCREPORTS.PendActiveLicDataExport(p_parms      IN OUT t_parameters,
                                                   p_status_ind IN OUT VARCHAR2) 
              RETURN BLOB IS 
-- ****************************************************************************
-- File:        PendActiveLicDataExport.fnc  
-- Author:      Timothy J. Lord
--
-- $Rev: 4218 $  
-- $Date: 2018-08-06 14:38:34 -0700 (Mon, 06 Aug 2018) $
-- Last Changed By:  $Author: tlord $
--
-- Description:    
--
-- 
-- History:
-------------------------------------------------------------------------------
--    Date                  Comment
-- 10/28/2015 TJL   8282    Updated for enhancement changes
-- 09/27/2016 TJL   7213    Changed output from CLOB to BLOB 
-- 08/06/2018 TJL  15926    Removed the following fields:
--                            Fee Codes
--                            Duplicate Counts
--                            District / Office Code
--                            Mail Street Address 1
--                            Mail Street Address 2
--                            Mail City
--                            Mail State
--                            Mail Zip
-- ****************************************************************************
              
    CURSOR cur_data IS SELECT RPAD(SUBSTR(NVL(d.license_type_code,' '),1,2),2,' ') ||
                              SUBSTR(TO_CHAR(NVL(d.licenseno,0),'09999999'),2,8) ||
                              RPAD(SUBSTR(NVL(d.app_or_lic ,' '),1,3),3,' ') ||
                              RPAD(SUBSTR(NVL(d.type_status_code,' '),1,8),8,' ') ||
                              RPAD(NVL(TO_CHAR(d.type_original_issue_date),' '),11,' ') ||
                              RPAD(NVL(TO_CHAR(d.next_issue_date),' '),11,' ') ||
                              RPAD(SUBSTR(NVL(NULL,' '),1,8),8,' ') ||                              -- d.fee_code        08/06/2018 TJL  15926 
                              RPAD(SUBSTR (NVL(TO_CHAR(NVL(NULL,''),'000'), '   '),2,3),3,' ') ||   -- d.duplicate_count 08/06/2018 TJL  15926 
                              RPAD(SUBSTR(NVL(d.master_ind,' '),1,1),1,' ') ||
                              RPAD(SUBSTR(NVL(d.term,' '),1,2),2,' ') ||
                              RPAD(SUBSTR(NVL(d.premgeocode,' '),1,4),4,' ') ||
                              RPAD(SUBSTR (NVL(TO_CHAR(NVL(NULL,''),'00'), '  '),2,2),2,' ') ||       -- d.officenumber   08/06/2018 TJL  15926 
                              RPAD(TRANSLATE(SUBSTR(NVL(d.primarylicensee,' '),1,50),',' || CHR(13) || CHR(10) || CHR(9),'   '),50,' ') ||
                              RPAD(TRANSLATE(SUBSTR(NVL(d.premaddressline1,' '),1,50),',' || CHR(13) || CHR(10) || CHR(9),'   '),50,' ') ||
                              RPAD(TRANSLATE(SUBSTR(NVL(d.premaddressline2,' '),1,50),',' || CHR(13) || CHR(10) || CHR(9),'   '),50,' ') ||
                              RPAD(TRANSLATE(SUBSTR(NVL(d.premcity,' '),1,25),',' || CHR(13) || CHR(10) || CHR(9),'   '),25,' ') ||
                              RPAD(SUBSTR(NVL(d.premstate,' '),1,2),2,' ') ||
                              RPAD(SUBSTR(NVL(d.premzip,' '),1,10),10,' ') ||
                              RPAD(TRANSLATE(SUBSTR(NVL(d.primarydba,' '),1,50),',' || CHR(13) || CHR(10) || CHR(9),'   '),50,' ') ||
                              RPAD(TRANSLATE(SUBSTR(NVL(NULL,' '),1,50),',' || CHR(13) || CHR(10) || CHR(9),'   '),50,' ') ||       -- d.mailaddressline1 08/06/2018 TJL  15926 
                              RPAD(TRANSLATE(SUBSTR(NVL(NULL,' '),1,50),',' || CHR(13) || CHR(10) || CHR(9),'   '),50,' ') ||       -- d.mailaddressline2 08/06/2018 TJL  15926 
                              RPAD(TRANSLATE(SUBSTR(NVL(NULL,' '),1,25),',' || CHR(13) || CHR(10) || CHR(9),'   '),25,' ') ||       -- d.mailcity         08/06/2018 TJL  15926 
                              RPAD(SUBSTR(NVL(NULL,' '),1,2),2,' ') ||                  -- d.mailstate 08/06/2018 TJL  15926 
                              RPAD(SUBSTR(NVL(NULL,' '),1,10),10,' ') ||                -- d.mailzip   08/06/2018 TJL  15926 
                              RPAD(TRANSLATE(SUBSTR(NVL(d.premcountyname,' '),1,16),',' || CHR(13) || CHR(10) || CHR(9),'   '),16,' ') ||
                              RPAD(SUBSTR(NVL(d.premcensustract,' '),1,7),7,' ') ||
                              CHR(13) || CHR(10) rpt_data
                         FROM abc.rawdataextract_type d
                        WHERE d.license_type_code NOT BETWEEN '30' AND '39'
                          AND (UPPER (d.type_status_code) IN ('ACTIVE', 'SLMSHD', 'SUSPEN', 'REVPEN', 'SUREND', 'R64B', 'PEND','ISSUPD'))
                        ORDER BY licenseno, d.license_type_code, d.app_or_lic;    
    
    lblob_data      BLOB;
    lv_msg          VARCHAR2(8196);
            
    BEGIN
        -- create clob to save report data in.
        dbms_lob.createtemporary(lblob_data, TRUE);
       
        FOR rec IN cur_data
        LOOP
            dbms_lob.writeappend(lblob_data, LENGTH(rec.rpt_data), utl_raw.cast_to_raw(rec.rpt_data));
        END LOOP;
    
        p_status_ind := 'F';
        
        RETURN lblob_data;
        
    EXCEPTION
        WHEN OTHERS THEN
            rqs_utils.log(p_log_type          =>  'E',
                          p_job_id            =>  p_parms.get_value('JOB_ID'),
                          p_seq               =>  p_parms.get_value('SEQ'),
                          p_source            =>  'PendActiveLicDataExport',
                          p_msg               =>  SQLERRM,
                          p_additional_data   =>  NULL,
                          p_error_trace       =>  dbms_utility.format_error_backtrace); 

            lv_msg  := 'ERROR: ' || SQLERRM || CHR(10) || CHR(13) 
                    || 'TRACE: ' || dbms_utility.format_error_backtrace;
            p_status_ind := 'E';
            RETURN  utl_raw.cast_to_raw(lv_msg);
    END PendActiveLicDataExport;
/


GRANT EXECUTE ON ABCREPORTS.PENDACTIVELICDATAEXPORT TO ABCREPORTS_ROLE;
