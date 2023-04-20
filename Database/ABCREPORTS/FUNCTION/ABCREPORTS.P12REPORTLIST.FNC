CREATE OR REPLACE FUNCTION ABCREPORTS.P12ReportList(p_parms      IN OUT t_parameters,
                                         p_status_ind IN OUT VARCHAR2) 
              RETURN BLOB IS

-- ****************************************************************************
-- File:        P12ReportList.fnc  
-- Author:      Timothy J. Lord
--
-- $Rev: 3874 $  
-- $Date: 2018-01-09 09:13:57 -0800 (Tue, 09 Jan 2018) $
-- Last Changed By:  $Author: tlord $
--
-- Description:      
--
-- Parameters: 
--
-- History:
-------------------------------------------------------------------------------
--    Date         Ticket     Comment
-- 06/24/2015 TJL   5945    Original file created
-- 07/10/2015 TJL   5945    Changed how data is created and added extra fields 
-- 09/27/2016 TJL   7213    Changed output from CLOB to BLOB 
-- 02/13/2017 TJL  11618    Removed first perprocess instruction 
-- 01/09/2018 TJL  14235    ReadableObjects was moved to Possedata when the 
--                          database was upgraded to 12C
-- ****************************************************************************

    qryCtx              DBMS_XMLGEN.ctxHandle;
    lxml_pi             XMLTYPE;
    lclob_result        CLOB;
    lclob_temp          CLOB;
    lv_msg              VARCHAR2(8096);
    lv_report_heading   VARCHAR2(200);
    ln_splitpnt1        NUMBER;
    ln_splitpnt2        NUMBER;
    ln_length           NUMBER;  
    ln_recs             NUMBER;
    
    BEGIN
        SELECT report_name
          INTO lv_report_heading
          FROM report_def
         WHERE report_number = TO_NUMBER(p_parms.get_value('REPORT_NUMBER'));

        qryCtx := DBMS_XMLGEN.newContext
              (
                'SELECT SUBSTR(api.pkg_ColumnQuery.VALUE(b.ObjectId, ''P12MasterLicenseNo''), 1, 50) P12MASTERLICENSENO,
                        TRIM(SUBSTR (api.pkg_ColumnQuery.VALUE (b.ObjectId, ''PrimaryLicensee''), 1, 50)) PRIMARYLICENSE,
                        api.pkg_ColumnQuery.VALUE (b.ObjectId, ''PrimarySLTCodesAndStatus'') PRIMARYSLTCODESANDSTATUS,
                        api.pkg_columnquery.VALUE(b.objectid, ''LicenseTypeCodes'') licensetypecodes,
                        api.pkg_columnquery.VALUE(b.objectid, ''PrimaryLicenseTypeCodes'') primarylicensetypecodes,

                        api.pkg_columnquery.numericvalue(b.objectid, ''BaseFileOfficeCodeCorral'') basefileofficecodecorral,
                          CASE WHEN TRIM(SUBSTR (api.pkg_ColumnQuery.VALUE (b.ObjectId, ''PrimaryLicensee''), 1, 1)) >= ''A'' THEN 2
                               ELSE 3 END 
                        pos                    
                   FROM possedata.ReadableObjects b
                   JOIN workflow.Jobs e 
                     ON e.JobId = b.ObjectId
                  WHERE b.ObjectDefId = 325227
                    AND api.pkg_ColumnQuery.VALUE (b.ObjectId, ''P12MasterLicenseNo'') = 
                            api.pkg_ColumnQuery.VALUE (b.ObjectId, ''LicenseNumber'')
                  ORDER BY pos, PrimaryLicense');

        DBMS_XMLGEN.setRowSetTag(qryCtx, 'ROOT');
        DBMS_XMLGEN.setRowTag(qryCtx, 'DATA');

        -- generate xml and return as clob value
        lclob_temp := DBMS_XMLGEN.getXML(qryCtx);
        ln_recs    := dbms_xmlgen.getNumRowsProcessed(qryCtx);
        DBMS_XMLGEN.closeContext(qryCtx);

        -- figure out split point to add processing instruction and root attributes
        ln_splitpnt1 := dbms_lob.instr(lclob_temp,'<ROOT>') - 1;
        ln_splitpnt2 := ln_splitpnt1 + 7;
        ln_length    := LENGTH(lclob_temp) - ln_splitpnt2;
        p_status_ind := 'F';   
         
        -- create processing instruction   
        SELECT XMLPI(NAME "xml-stylesheet", 'href="../Formats/P12ReportList.xslt" type="text/xsl"') 
          INTO lxml_pi 
          FROM DUAL;
        lclob_result := lxml_pi.getclobval();
        
        -- add root attributes for report control information
        dbms_lob.append(lclob_result,
                    '<ROOT REPORT_TAKEN="' || TO_CHAR(SYSDATE, 'MM/DD/YYYY HH:MI AM') 
                    || '" REPORT_NAME="' || NVL(lv_report_heading,'unknown') 
                    || '" RECORD_CNT="' || ln_recs || '">');
      
        -- copy rest of report data on end of results 
        dbms_lob.copy(lclob_result, lclob_temp, ln_length, LENGTH(lclob_result) + 1, ln_splitpnt2);
        
        RETURN rqs_utils.clob2blob(lclob_result);

    EXCEPTION
        WHEN OTHERS THEN
            rqs_utils.log(p_log_type          =>  'E',
                          p_job_id            =>  p_parms.get_value('JOB_ID'),
                          p_seq               =>  TO_NUMBER(p_parms.get_value('SEQ')),
                          p_source            =>  'P12ReportList',
                          p_msg               =>  SQLERRM,
                          p_error_trace       =>  dbms_utility.format_error_backtrace);             

            p_status_ind := 'E';
            RETURN utl_raw.cast_to_raw('ERROR: ' || SQLERRM || CHR(10) || CHR(13) ||
                                       'TRACE: ' || dbms_utility.format_error_backtrace);
            
    END P12ReportList;
/


GRANT EXECUTE ON ABCREPORTS.P12REPORTLIST TO ABCREPORTS_ROLE;
