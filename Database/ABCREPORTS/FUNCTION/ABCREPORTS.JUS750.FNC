CREATE OR REPLACE FUNCTION ABCREPORTS.jus750(p_parms      IN OUT t_parameters,
                                  p_status_ind IN OUT VARCHAR2) 
              RETURN BLOB IS 
-- ****************************************************************************
-- File:        jus750.fnc  
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
-- 02/25/2016 TJL   9057    Updated query to add grouping by office
-- 09/27/2016 TJL   7213    Changed output from CLOB to BLOB  
-- ****************************************************************************

    office_id           t_officeobject := NULL;
    ld_report_date      DATE;
    lv_status_msg       VARCHAR2(8096);
    lblob               BLOB;
    lxml                XMLTYPE;
    lxml_pi             XMLTYPE;
    lv_report_heading   VARCHAR2(200);
    
    BEGIN 
    
        office_id := rqs_utils.BuildOfficeList(p_parms.get_value('OFFICEOBJECTID'),
                                               lv_status_msg);
    
        ld_report_date := TO_DATE(p_parms.get_value('REPORT_DATE'), 'MM/DD/YYYY');
        SELECT report_name
          INTO lv_report_heading
          FROM report_def
         WHERE report_number = TO_NUMBER(p_parms.get_value('REPORT_NUMBER'));

        SELECT XMLELEMENT("ROOT",
                                XMLATTRIBUTES(TO_CHAR(SYSDATE, 'MM/DD/YYYY HH:MI AM') AS "REPORT_TAKEN", 
                                              NVL(lv_report_heading,'unknown') AS "REPORT_NAME",
                                              TO_CHAR(ld_report_date, 'MM/DD/YYYY') AS "REPORT_DATE"),
              (SELECT XMLAGG (XMLELEMENT("OFFICE", 
                                XMLATTRIBUTES((SELECT displayformat FROM query.o_office WHERE objectid = offid.officeobjectid) AS "OFFICENAME",
                                              (SELECT orinumber FROM query.o_office WHERE objectid = offid.officeobjectid)  AS "ORINUMBER"),                           
              (SELECT DISTINCT
                    XMLAGG(XMLELEMENT
                            ("DATA", 
                                XMLFOREST
                                    (
                i.abcreportnumber abcreportnum,
                  ac.lastname
                       || NVL2(ac.lastname, ', ', ac.lastname)
                       || ac.firstname
                       || ' '
                       || ac.middlename
                   formattedname,
               ac.race race,
               TO_CHAR(ac.birthdate, 'MM/DD/YYYY') birthdate,
               TO_CHAR(CASE
                       WHEN ac.birthdate > ADD_MONTHS(ac.arrestdate, -(18 * 12)) THEN 'Y'
                       ELSE ' '
                   END)
                   juvenile,
               ac.gender gender,
               TO_CHAR(ac.arrestdate, 'MM/DD/YYYY') arrestdate,
               ac.violationlevel violationlevel,
               ac.charges charges,
               NULL LUO,
               ac.violationstatus violationstatus,
               NULL LAWENFDISPQ,               
               ac.arrestinginvestigator arrestinginvestigator,
               
               api.pkg_columnquery.VALUE((api.pkg_securityquery.effectiveuserid),
                                         'Name')
                   currentuser,
                  (
               SUBSTR(
                      api.pkg_columnquery.VALUE(
                          (api.pkg_securityquery.effectiveuserid),
                          'OfficePhoneNumber'),
                      1,
                      3)
                  ) 
               || SUBSTR(
                      api.pkg_columnquery.VALUE(
                          (api.pkg_securityquery.effectiveuserid),
                          'OfficePhoneNumber'),
                      4,
                      3)
               || '-'
               || SUBSTR(
                      api.pkg_columnquery.VALUE(
                          (api.pkg_securityquery.effectiveuserid),
                          'OfficePhoneNumber'),
                      7,
                      4)
                   formattednumber,
               ac.lastname,
               ac.firstname,
               ac.middlename
               )
               ) ORDER BY o.displayformat, i.abcreportnumber
               )
          FROM query.o_office o
               LEFT OUTER JOIN query.r_investigationoffice io
                   ON io.officeobjectid = o.objectid
               LEFT OUTER JOIN query.j_investigation i
                   ON i.jobid = io.investigationjobid
               LEFT OUTER JOIN query.r_investigationarrestcitation iac
                   ON iac.investigationjobid = i.jobid
               LEFT OUTER JOIN query.o_arrestcitation ac
                   ON ac.objectid = iac.arrestcitationobjectid
         WHERE o.OBJECTID = offid.officeobjectid
           AND ac.casetype != 'JOINT'
           AND (ac.arrestdate BETWEEN TRUNC(ld_report_date, 'month')
                                  AND LAST_DAY(ld_report_date)
                OR ac.arrestdate IS NULL)
           AND NOT (AC.LastName IS NULL AND AC.CitationNumber IS NULL AND I.AbcReportNumber IS NULL) 
           AND EXISTS
                   (SELECT 1
                      FROM query.r_investigationarrestcitation r
                     WHERE r.investigationjobid = i.jobid)
         )
         ))
         FROM TABLE(office_id) offid
         ) 
         )
         INTO lxml
         FROM DUAL;

       -- add processing instruction to xml  
        SELECT XMLPI(NAME "xml-stylesheet", 'href="../Formats/jus750.xslt" type="text/xsl"') INTO lxml_pi FROM DUAL;
          
        lblob := rqs_utils.clob2blob(lxml_pi.GETCLOBVAL() || lxml.GETCLOBVAL());
        p_status_ind := 'F';
        
        RETURN lblob;
        
    EXCEPTION
        WHEN OTHERS THEN
            rqs_utils.log(p_log_type          =>  'E',
                          p_job_id            =>  p_parms.get_value('JOB_ID'),
                          p_seq               =>  p_parms.get_value('SEQ'),
                          p_source            =>  'JUS750',
                          p_msg               =>  SQLERRM,
                          p_additional_data   =>  NULL,
                          p_error_trace       =>  dbms_utility.format_error_backtrace); 
                                    
            p_status_ind := 'E';
            
                RETURN utl_raw.cast_to_raw('ERROR: ' || SQLERRM || CHR(10) || CHR(13) ||
                                           'TRACE: ' || dbms_utility.format_error_backtrace);
            
    END JUS750;
/


GRANT EXECUTE ON ABCREPORTS.JUS750 TO ABCREPORTS_ROLE;
