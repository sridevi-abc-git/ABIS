CREATE OR REPLACE FUNCTION ABCREPORTS.revocations(p_parms      IN OUT t_parameters,
                                       p_status_ind IN OUT VARCHAR2) 
              RETURN BLOB IS
-- ****************************************************************************
-- File:        revocations.fnc  
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
-- 09/27/2016 TJL   7213    Changed output from CLOB to BLOB  
-- ****************************************************************************

    CURSOR      query(p_start_date IN DATE, p_end_date IN DATE) IS
         SELECT ac.licensetypeandnumber lic_type_and_num, 
                ac.regnumber, 
                ac.statusname accusation_status,  
                ac.officename district, 
                psr.scheduledstartdate, 
                psr.outcome, 
                psr.postingdate
           FROM query.p_postsuspensionrevocation psr
           JOIN query.j_accusation ac on ac.objectid = psr.jobid
          WHERE psr.outcome = 'Revoke'  
            AND psr.postingdate BETWEEN p_start_date AND p_end_date
          ORDER BY lic_type_and_num;
        
    lv_msg          VARCHAR2(8096);
    lblob_csv       BLOB;
    ld_start        DATE;
    ld_end          DATE;
    lv_csv_row      VARCHAR2(8096);
    
    BEGIN
        DBMS_LOB.CREATETEMPORARY(lblob_csv, TRUE, dbms_lob.CALL);

        ld_start := TO_DATE(p_parms.get_value('START_DATE'), 'MM/DD/YYYY');
        ld_end   := TO_DATE(p_parms.get_value('END_DATE'), 'MM/DD/YYYY');
        p_parms.upd_value('REPORT_DATE', TO_CHAR(SYSDATE, 'MM/DD/YYYY HH:MI PM'));
        
        FOR rec IN query(ld_start, ld_end)
        LOOP
            lv_csv_row := '"' || rec.lic_type_and_num || '",'
                       || rec.regnumber || ',' 
                       || '"' || rec.accusation_status || '",'
                       || '"' || rec.district || '",'  
                       || '"' || TO_CHAR(rec.scheduledstartdate, 'MM/DD/YYYY') || '",'
                       || '"' || rec.outcome || '",' 
                       || '"' || TO_CHAR(rec.postingdate, 'MM/DD/YYYY') || '"' 
                       || CHR(13) || CHR(10);
            dbms_lob.append (lblob_csv, utl_raw.cast_to_raw(lv_csv_row));
        END LOOP;

        RETURN lblob_csv;

    EXCEPTION
        WHEN OTHERS THEN
            rqs_utils.log(p_log_type          =>  'E',
                          p_job_id            =>  p_parms.get_value('JOB_ID'),
                          p_seq               =>  p_parms.get_value('SEQ'),
                          p_source            =>  'Revocation',
                          p_msg               =>  SQLERRM,
                          p_additional_data   =>  NULL,
                          p_error_trace       =>  dbms_utility.format_error_backtrace); 

            p_status_ind := 'E';
            RETURN utl_raw.cast_to_raw('ERROR: ' || SQLERRM || CHR(10) || CHR(13) ||
                                       'TRACE: ' || dbms_utility.format_error_backtrace);
        
    END REVOCATIONS;
/


GRANT EXECUTE ON ABCREPORTS.REVOCATIONS TO ABCREPORTS_ROLE;
