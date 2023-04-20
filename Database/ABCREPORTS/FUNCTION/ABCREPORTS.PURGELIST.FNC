CREATE OR REPLACE FUNCTION ABCREPORTS.purgelist(p_parms      IN OUT t_parameters,
                                     p_status_ind IN OUT VARCHAR2) 
              RETURN BLOB IS 
-- ****************************************************************************
-- File:        purgelist.fnc  
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

    CURSOR      query(p_report_year IN NUMBER) IS
        SELECT  JLT.LICENSEEXTERNALFILENUM Licensenumber,
                api.pkg_columnquery.Value(rllt.LICENSEJOBID, 'StatusName') Lic_App_Status,
                JLT.licensetypecode LICENSETYPECODE, 
                JLT.STATUSNAME Type_Status,
                to_date(substr(JS.STATUSDATE,1, decode(instr(JS.STATUSDATE,' '),0,9)) ,'DD-MON-RR') Status_date, 
                JLT.LICENSEENAMESLETTER PRIMARYLICENSEE,
                abc.GETMART_CNCT_LICTYPSTATCODE  (JLT.LICENSEJOBID) licensetypes_status 
        FROM query.r_licenselicensetype RLLT
                join query.j_licensetype JLT on JLT.jobid = RLLT.licensetypejobid
                join extension.jobstatuschange JS on JS.jobid = JLT.ObjectId
        Where JS.STATUSNAME in ('AUTREV', 'CANCEL','NREN')
                and abc.GETMART_CNCT_LICTYPSTATCODE  (JLT.LICENSEJOBID)  not like '%ACT%'
                and to_char(to_date(JS.STATUSDATE,'DD-MON-RRRR'),'RRRR') = to_char(p_report_year - 2)
                AND JS.MOSTRECENT = 'Y'
        UNION ALL
        -----------  Applications -------
        select A.LICENSENUMBER,
               A.STATUSNAME Lic_App_Status, 
               L.LICENSETYPECODE, 
               L.Status Type_Status, 
               trunc(to_date(L.STATUSDATE,'RRRR-MM-DD HH24:MI:SS')) Status_date,
               A.PRIMARYLICENSEE,
               ' '  licensetypes_status
        from MART.APPLICATION a
        join MART.APPLICTYPE l on L.APPLICATIONOBJECTID = A.OBJECTID
        where to_char(to_date(L.STATUSDATE,'RRRR-MM-DD HH24:MI:SS'),'RRRR') = to_char(p_report_year - 3)  
        and A.STATUSNAME in ('DENIED') 
        UNION ALL
        select A.LICENSENUMBER,
               A.STATUSNAME Lic_App_Status, 
               L.LICENSETYPECODE, 
               L.Status TypeStatus, 
               trunc(to_date(L.STATUSDATE,'RRRR-MM-DD HH24:MI:SS')) Status_date,
               A.PRIMARYLICENSEE,
               ' '  licensetypes_status
        from MART.APPLICATION a
        join MART.APPLICTYPE l on L.APPLICATIONOBJECTID = A.OBJECTID
        where to_char(to_date(L.STATUSDATE,'RRRR-MM-DD HH24:MI:SS'),'RRRR') = to_char(p_report_year - 2)  
        and A.STATUSNAME in ('WTHDRN') 
        and not exists (select distinct ml.ExternalFileNum
                        from MART.LICENSE ml
                        where ml.ExternalFileNum = A.LICENSENUMBER
                        )
        UNION ALL
        select A.LICENSENUMBER,
               A.STATUSNAME Lic_App_Status, 
               L.LICENSETYPECODE, 
               L.Status TypeStatus, 
               trunc(to_date(L.STATUSDATE,'RRRR-MM-DD HH24:MI:SS')) Status_date, 
               A.PRIMARYLICENSEE,
               ' '  licensetypes_status
        from MART.APPLICATION a
        join MART.APPLICTYPE l on L.APPLICATIONOBJECTID = A.OBJECTID
        where to_char(to_date(L.STATUSDATE,'RRRR-MM-DD HH24:MI:SS'),'RRRR') = to_char(p_report_year - 2)  
        and A.STATUSNAME in ('VOIDED') 
        and not exists (select distinct ml.ExternalFileNum 
                        from MART.LICENSE ml
                        where ml.ExternalFileNum = A.LICENSENUMBER
                        );
    
    ln_report_year  NUMBER;
    lblob_csv       BLOB;
    lv_csv_row      VARCHAR2(8096);
    
    BEGIN
        DBMS_LOB.CREATETEMPORARY(lblob_csv, TRUE, dbms_lob.CALL);

        ln_report_year := TO_NUMBER(p_parms.get_value('YEAR'));
        
        FOR rec IN query(ln_report_year)
        LOOP
            lv_csv_row := '"' || rec.Licensenumber || '",'
                    || '"' || rec.Lic_App_Status || '",'
                    || rec.LICENSETYPECODE || ',' 
                    || '"' || rec.Type_Status || '",'
                    || '"' || rec.Status_date || '",' 
                    || '"' || rec. PRIMARYLICENSEE || '",'
                    || '"' || rec.licensetypes_status || '"' 
                    || CHR(13) || CHR(10);
                
            dbms_lob.append (lblob_csv, utl_raw.cast_to_raw(lv_csv_row)); 
        END LOOP;

        RETURN lblob_csv;

    EXCEPTION
        WHEN OTHERS THEN
            rqs_utils.log(p_log_type          =>  'E',
                          p_job_id            =>  p_parms.get_value('JOB_ID'),
                          p_seq               =>  p_parms.get_value('SEQ'),
                          p_source            =>  'Purge List Report',
                          p_msg               =>  SQLERRM,
                          p_additional_data   =>  NULL,
                          p_error_trace       =>  dbms_utility.format_error_backtrace); 

            p_status_ind := 'E';
            RETURN utl_raw.cast_to_raw('ERROR: ' || SQLERRM || CHR(10) || CHR(13) ||
                                       'TRACE: ' || dbms_utility.format_error_backtrace);
            
    END PURGELIST;
/


GRANT EXECUTE ON ABCREPORTS.PURGELIST TO ABCREPORTS_ROLE;
