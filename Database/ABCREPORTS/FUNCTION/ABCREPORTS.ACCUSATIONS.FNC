CREATE OR REPLACE FUNCTION ABCREPORTS.ACCUSATIONS(p_parms      IN OUT t_parameters,
                                                  p_status_ind IN OUT VARCHAR2) 
              RETURN BLOB IS 

-- ****************************************************************************
-- File:        accusations.fnc  
-- Author:      Timothy J. Lord
--
-- $Rev: 4273 $  
-- $Date: 2018-10-09 07:25:41 -0700 (Tue, 09 Oct 2018) $
-- Last Changed By:  $Author: TLord $
--
-- Description:    The Accusation report is for quering for accusation by
--                 date and district offices
--
-- 
-- History:
-------------------------------------------------------------------------------
--    Date                  Comment
-- 10/08/2018 TJL  15580    Initial Report Created 
--- ****************************************************************************

    ln_return_code                   NUMBER;
    lv_status_msg                    VARCHAR2(4000);
    lb_proc                          BOOLEAN := TRUE;
    office_id                        T_OFFICEOBJECT;
    ld_start_date                    DATE;
    ld_end_date                      DATE;
    xml_value                        XMLTYPE;
    lxml_pi                          XMLTYPE;
    ln_                              NUMBER;
    blob_                            BLOB;
    lv_district                      query.o_Office.isdistrict%TYPE;
    cur_recs                         SYS_REFCURSOR;
    lv_db                            VARCHAR2(12);
    lv_link                          VARCHAR2(400);
                
    BEGIN
        IF (p_parms.get_value('START_DATE') IS NOT NULL) THEN
            ld_start_date := TRUNC(TO_DATE(p_parms.get_value('START_DATE'), 'MM/DD/YYYY'));
            ld_end_date   := TO_DATE(p_parms.get_value('END_DATE'), 'MM/DD/YYYY') + (1 - 1/(24 * 60 * 60));
            p_parms.upd_value('REPORT_DATE', TO_CHAR(SYSDATE, 'MM/DD/YYYY HH:MI PM'));
                    
            -- get office id(s)
            office_id := rqs_utils.BuildOfficeList(p_parms.get_value('OFFICEOBJECTID'),
                                                   lv_status_msg);
            lb_proc := (lv_status_msg IS NULL);
                
            -- check if request is district or division request
            SELECT o.isdistrict
              INTO lv_district
              FROM query.o_Office o
             WHERE objectid = p_parms.get_value('OFFICEOBJECTID');
        ELSE
            lb_proc := FALSE;
            lv_status_msg := 'No report date found';
        END IF;
             
        IF (lb_proc) THEN
            -- build ABIS screen link with database selection
            select p.parameter_value
              into lv_link
              from abcreports.report_ctrl_parameters p
             where p.parameter_name = 'ABIS';
             
            lv_link := lv_link || 'Default.aspx?PossePresentation=Default|PosseObjectId='; --' || chr(38) || 'PosseObjectId=';
               
            ----------------------------------------------------------------------
            -- build report
            ----------------------------------------------------------------------
            SELECT 
              XMLELEMENT("ROOT",
                                    XMLATTRIBUTES(TO_CHAR(SYSDATE, 'MM/DD/YYYY') AS "REPORT_TAKEN", 
                                                  NVL(p_parms.get_value('REPORT_NAME'),'unknown') AS "REPORT_NAME",
                                                  TO_CHAR(ld_start_date, 'MM/DD/YYYY') || ' - ' || TO_CHAR(ld_end_date, 'MM/DD/YYYY') AS "REPORT_DATE"),
                  (SELECT DISTINCT
                        XMLAGG(XMLELEMENT
                                ("ACCUSATIONS",
                                    XMLATTRIBUTES(lv_link || a.objectid AS "URL", lv_link || a.licensejobid as "LICENSEJOBID"),
                                    XMLFOREST
                                       (
                                         officename,
                                         NVL(regnumber, ' ') regnumber,
                                         licensenumber,
                                         REGEXP_REPLACE(api.pkg_columnquery.value(a.licensejobid, 'PrimaryLicensee'), '[[:cntrl:]]', ' ') PrimaryLicensee, 
                                         TO_CHAR(a.createddate, 'MM/DD/YYYY') createddate,
                                         TO_CHAR(a.AccusationRegisteredDate, 'MM/DD/YYYY') RegisteredDate,
                                         STATUSNAME
                                       )
                                )
                        ORDER BY officename, licensenumber
                              )
                     FROM mart.accusation a
                    WHERE trunc(a.createddate) BETWEEN ld_start_date AND ld_end_date
                      AND a.officecode IN (SELECT o.officecode
                                             FROM TABLE(office_id) l
                                             JOIN query.o_office o
                                               ON (l.officeobjectid = o.objectid))
                      AND licensenumber IS NOT NULL
                ))
              INTO xml_value
              FROM DUAL;
                        
            IF (xml_value IS NULL) THEN
                xml_value := XMLTYPE('<ROOT></ROOT>');
            END IF;
        END IF;
        
        IF (lb_proc) THEN
            p_status_ind := 'F';
            
            SELECT XMLPI(NAME "xml-stylesheet", 'href="../Formats/accusations.xslt" type="text/xsl"') INTO lxml_pi FROM DUAL;
            blob_ := rqs_utils.clob2blob(lxml_pi.GETCLOBVAL() || xml_value.GETCLOBVAL());
        ELSE
            p_status_ind := 'E';
            blob_ := utl_raw.cast_to_raw(lv_status_msg);

            rqs_utils.log(p_log_type          =>  'E',
                          p_job_id            =>  p_parms.get_value('JOB_ID'),
                          p_seq               =>  p_parms.get_value('SEQ'),
                          p_source            =>  'Accusations Report',
                          p_msg               =>  lv_status_msg); 
        END IF;   
             
        RETURN blob_;
                    
            
    EXCEPTION
        WHEN OTHERS THEN
            rqs_utils.log(p_log_type          =>  'E',
                          p_job_id            =>  p_parms.get_value('JOB_ID'),
                          p_seq               =>  p_parms.get_value('SEQ'),
                          p_source            =>  'ABC19 Report',
                          p_msg               =>  SQLERRM,
                          p_additional_data   =>  NULL,
                          p_error_trace       =>  dbms_utility.format_error_backtrace); 

            p_status_ind := 'E';
                
            RETURN utl_raw.cast_to_raw('ERROR: ' || SQLERRM || CHR(10) || CHR(13) ||
                                       'TRACE: ' || dbms_utility.format_error_backtrace);
    END ACCUSATIONS;
/
