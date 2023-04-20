CREATE OR REPLACE FUNCTION ABCREPORTS.ABC19Section9Detail(p_parms      IN OUT t_parameters,
                                               p_status_ind IN OUT VARCHAR2) 
              RETURN BLOB IS
-- ****************************************************************************
-- File:        ABC19Section9Detail.fnc  
-- Author:      Timothy J. Lord
--
-- $Rev: 3044 $  
-- $Date: 2016-09-27 15:06:25 -0700 (Tue, 27 Sep 2016) $
-- Last Changed By:  $Author: tlord $
--
-- Description:      
--
-- Parameters: 
--
-- History:
-------------------------------------------------------------------------------
--    Date         Ticket     Comment
-- 10/18/2015  TJL  8282   Modified for RQS Enhancement Changes
-- 01/06/2016  TJL  7739   Added type 84 filter 
-- 09/27/2016 TJL   7213    Changed output from CLOB to BLOB  
-- ****************************************************************************

    lv_msg          VARCHAR2(12000) := NULL;
    ln_return_code  NUMBER;
    office_ids      T_OFFICEOBJECT;
    ld_start_date   DATE;
    lblob           BLOB;
    lxml            XMLTYPE;
    lv_report_heading   VARCHAR2(200);
    lxml_pi         XMLTYPE;
    
    BEGIN 
        IF (p_parms.get_value('REPORT_DATE') IS NOT NULL) THEN
            -- make sure day of month is the first  
            ld_start_date := TRUNC(TO_DATE(p_parms.get_value('REPORT_DATE'), 'MM/DD/YYYY'), 'MM');
        ELSE
            lv_msg := 'Report Date: No report date found';
        END IF; 
        
        office_ids := rqs_utils.BuildOfficeList(p_parms.get_value('OFFICEOBJECTID'),
                                               lv_msg);

        SELECT 
          XMLELEMENT("ROOT",
                                XMLATTRIBUTES(TO_CHAR(SYSDATE, 'MM/DD/YYYY') AS "REPORT_TAKEN", 
                                              NVL(p_parms.get_value('REPORT_NAME'),'unknown') AS "REPORT_NAME",
                                              TO_CHAR(ld_start_date, 'MM/DD/YYYY') AS "REPORT_DATE"),
               XMLELEMENT("HEADER",                                               
                    XMLATTRIBUTES(TO_CHAR(SYSDATE, 'MM/DD/YYYY') AS "REPORT_TAKEN", 
                                              NVL(p_parms.get_value('REPORT_NAME'),'unknown') AS "REPORT_NAME",
                                              TO_CHAR(ld_start_date, 'MM/DD/YYYY') AS "REPORT_DATE")),
              (SELECT DISTINCT
                    XMLAGG(XMLELEMENT
                            ("LICENSEINFO", 
                                XMLATTRIBUTES(name AS "TYPE", description AS "DESCRIPTION"),
                                XMLFOREST
                                    (licensenumber,
                                     primarylicensee,
                                     externalfilenum,
                                     districtofficecorral,
                                     TO_CHAR(createddate, 'MM/DD/YYYY') assign_create_date,
                                     TO_CHAR(close_inv_completed_date, 'MM/DD/YYYY') close_inv_completed_date 
                                    )
                            )
                          )
                 FROM 
                     (SELECT 'PendBeg' name,
                             'Pending Beginning' description,
                             TO_CHAR(p.jobexternalfilenum) licensenumber,
                                (SELECT primarylicensee FROM mart.license WHERE externalfilenum=p.jobexternalfilenum
                                    UNION
                                 SELECT primarylicensee FROM mart.application WHERE externalfilenum=p.jobexternalfilenum)
                             primarylicensee,
                             p.externalfilenum,
                             p.districtofficecorral,
                             p.createddate,
                             c.datecompleted close_inv_completed_date
                        FROM mart.assignassignment p
                        LEFT JOIN mart.closelicensingassignment c
                          ON c.externalfilenum = p.externalfilenum
                       WHERE NVL (p.droppartner, 'N') = 'N'
                         AND NVL (p.haslicensetype79, 'N') = 'N'
                         AND NVL (p.haslicensetype84, 'N') = 'N'
                         AND p.districtofficeidcorral IN (SELECT officeobjectid FROM TABLE(office_ids))
                         AND TRUNC (p.createddate) < ld_start_date
                         AND TRUNC (p.createddate) > TO_DATE ('06/24/2010', 'MM/DD/YYYY')
                         AND (
                                  TRUNC (p.datecompleted) >= ld_start_date
                               OR p.datecompleted IS NULL
                               OR c.datecompleted IS NULL
                               OR TRUNC (c.datecompleted) >= ld_start_date
                             )

                      UNION ALL
                      SELECT 'Received' name,
                             'Received' description,
                             pa.jobexternalfilenum licensenumber,
                                (SELECT primarylicensee FROM mart.license WHERE externalfilenum=pa.jobexternalfilenum
                                    UNION
                                 SELECT primarylicensee FROM mart.application WHERE externalfilenum=pa.jobexternalfilenum)
                             primarylicensee,
                             externalfilenum,
                             pa.districtofficecorral,
                             pa.createddate,
                             pa.datecompleted
                        FROM mart.assignassignment pa
                       WHERE NVL (pa.droppartner, 'N') = 'N'
                         AND NVL (pa.haslicensetype79, 'N') = 'N'
                         AND NVL (pa.haslicensetype84, 'N') = 'N'
                         AND pa.districtofficeidcorral IN (SELECT officeobjectid FROM TABLE(office_ids))
                         AND TRUNC(pa.createddate, 'MM') = ld_start_date

                      UNION ALL
                      SELECT 'Completed' name,
                             'Completed' description,
                             TO_CHAR(jobexternalfilenum) licensenumber,
                                (SELECT primarylicensee FROM mart.license WHERE externalfilenum=jobexternalfilenum
                                    UNION
                                 SELECT primarylicensee FROM mart.application WHERE TO_CHAR(externalfilenum)=TO_CHAR(jobexternalfilenum))
                             primarylicensee,
                             c.externalfilenum,
                             c.districtofficecorral,
                             a.createddate,
                             c.datecompleted                                                 --,null
                        FROM mart.closelicensingassignment c
                        JOIN mart.assignassignment a ON a.externalfilenum =  c.externalfilenum
                       WHERE NVL (a.droppartner, 'N') = 'N'
                         AND NVL (a.haslicensetype79, 'N') = 'N'
                         AND NVL (a.haslicensetype84, 'N') = 'N'
                         AND a.districtofficeidcorral IN (SELECT officeobjectid FROM TABLE(office_ids))
                         AND TRUNC(C.datecompleted, 'MM') = ld_start_date
                        ORDER BY name, createddate, districtofficecorral, licensenumber
                     )
              )
            )
          INTO lxml
          FROM DUAL;
          
       -- add processing instruction to xml  
        SELECT XMLPI(NAME "xml-stylesheet", 'href="../Formats/ABC19Section9Detail.xslt" type="text/xsl"') INTO lxml_pi FROM DUAL;
          
        lblob := rqs_utils.clob2blob(lxml_pi.GETCLOBVAL() || lxml.GETCLOBVAL());
        p_status_ind := 'F';
          
        RETURN lblob;

    EXCEPTION
        WHEN OTHERS THEN
            rqs_utils.log(p_log_type          =>  'E',
                          p_job_id            =>  p_parms.get_value('JOB_ID'),
                          p_seq               =>  TO_NUMBER(p_parms.get_value('SEQ')),
                          p_source            =>  'ABC19Section9Detail',
                          p_msg               =>  SQLERRM,
                          p_error_trace       =>  dbms_utility.format_error_backtrace);             
        
            p_status_ind := 'E';
            RETURN utl_raw.cast_to_raw('ERROR: ' || SQLERRM || CHR(10) || CHR(13) ||
                                       'TRACE: ' || dbms_utility.format_error_backtrace);
        
    END ABC19Section9Detail;
/


GRANT EXECUTE ON ABCREPORTS.ABC19SECTION9DETAIL TO ABCREPORTS_ROLE;
