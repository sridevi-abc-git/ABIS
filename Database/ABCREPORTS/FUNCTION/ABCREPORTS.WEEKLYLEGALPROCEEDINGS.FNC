CREATE OR REPLACE FUNCTION ABCREPORTS.WeeklyLegalProceedings(p_parms      IN OUT t_parameters,
                                                  p_status_ind IN OUT VARCHAR2) 
              RETURN BLOB IS

-- ****************************************************************************
-- File:        WeeklyLegalProceedings.fnc  
-- Author:      Timothy J. Lord
--
-- $Rev: 355 $  
-- $Date: 2019-09-03 12:58:51 -0700 (Tue, 03 Sep 2019) $
-- Last Changed By:  $Author: tlord $
--
-- Description:    
--
-- 
-- History:
-------------------------------------------------------------------------------
--    Date                  Comment
-- 10/28/2015 TJL   8282    Updated for enhancement changes
-- 04/26/2016 TJL			Added filter to description in Proceedings  
-- 09/27/2016 TJL   7213    Changed output from CLOB to BLOB  
-- 08/06/2018 TJL  15926    Removed Agency and mailing address from query
-- 08/28/2019 TJL           Added saving XML (blob) to an LQS Table
-- ****************************************************************************

    ld_start        DATE;
    ld_end          DATE;
    lv_msg          VARCHAR2(8096);
    lxml            XMLTYPE;
    lxml_pi         XMLTYPE;
    lblob           blob;
    lv_report_name  VARCHAR(150) := p_parms.get_value('REPORT_NAME');
    
    BEGIN
        ld_start := TO_DATE(p_parms.get_value('START_DATE'), 'MM/DD/YYYY');
        ld_end   := TO_DATE(p_parms.get_value('END_DATE'), 'MM/DD/YYYY');

--ld_start := TO_DATE('11/01/2013', 'MM/DD/YYYY');
--ld_end   := TO_DATE('11/30/2013', 'MM/DD/YYYY');

        SELECT XMLELEMENT("ROOT", XMLATTRIBUTES(TO_CHAR(SYSDATE, 'MM/DD/YYYY') AS "REPORT_TAKEN", 
                                                lv_report_name AS "REPORT_NAME",
                                                p_parms.get_value('START_DATE') AS "START_DATE",
                                                p_parms.get_value('END_DATE') AS "END_DATE"),
        (
        -- License information
        SELECT DISTINCT XMLAGG(
          XMLELEMENT("LicenseInfo", 
            XMLFOREST
             (jlc.licensenumber "LicenseNumber",
              jlc.statusname AS "Status",
                   (SELECT TO_CHAR(js.effectivestartdate, 'DD-MON-YYYY')
                      FROM extension.jobstatuschange_t js
                     WHERE js.jobid = jlc.jobid
                       AND js.mostrecent = 'Y') "StatusDate",
              jlc.basefileofficecodecorral "District",
              UPPER(jac.objectdefdescription) "Action",
              jac.regnumber "RegNumber",
              TO_CHAR(jac.accusationregistereddate, 'DD-MON-YYYY') "RegDate",
              jac.casetype "Case",
              CASE WHEN jac.statusname IN ('CLOSED','DISMSD')
                   THEN 'Y' ELSE 'N' END "Cleared",
              TO_CHAR(NVL(jac.cleareddate, jac.completeddate), 'DD-MON-YYYY') "ClearedDate",
              TO_CHAR(jac.createddate, 'DD-MON-YYYY') "RecvdDate",
              jlc.primarylicensee "Licensee",
              jlc.premaddress1line "PremAddress",
              jlc.premaddressgeocode "GeoCode",
              TO_CHAR(jlc.premaddresscensustract,'0000.00') "CensusTract",
              jlc.primarydba "DBA",
              jac.jobid
             ),
             (
                -- License Types
                SELECT XMLELEMENT("LicenseTypes",
                  XMLAGG(XMLELEMENT("LicenseType",
                    XMLFOREST
                     (jlt.licensetypecode "Type",
                      DECODE(NVL(jlc.jobid, ''),'', '',abc.get_lic_masterindicator(jlc.jobid)) "MI",
                      jlt.statusname "Status",
                      TO_CHAR((SELECT NVL(js.statusdate,js.effectivestartdate)
                                 FROM extension.jobstatuschange_t js
                                WHERE js.jobid = jlt.jobid
                                AND js.mostrecent = 'Y'), 'DD-MON-YYYY') "Date",
                      TO_CHAR(jlt.expirationdate,'DD-MON-YYYY') "Expires",
                      jlt.secondarylicensetypecount "Dups",
                      NVL('12',jlt.numberofmonthslicensednumber) "Term"
                     )) ORDER BY jlt.licensetypecode))
                  FROM query.r_licenseaccusations rla
                  LEFT OUTER JOIN query.j_license jlc
                    ON jlc.jobid = rla.licensejobid
                  LEFT OUTER JOIN query.r_licenselicensetype rlt
                    ON rlt.licensejobid = jlc.jobid
                  LEFT OUTER JOIN query.j_licensetype jlt
                    ON jlt.jobid = rlt.licensetypejobid
                 WHERE rla.accusationjobid = jac.jobid
             ),
        -- Charges
             (
                SELECT XMLELEMENT("Charges",
                  XMLAGG(XMLELEMENT("Descriptions",
                    XMLFOREST
                     (ov.description "Description"
                     )) ORDER BY description))
                  FROM query.r_accusationviolation rav
                  LEFT OUTER JOIN query.o_violation ov
                    ON ov.objectid = rav.violationobjectid
                 WHERE rav.accusationjobid = jac.jobid
             ),
        -- Proceedings
             (
                SELECT XMLELEMENT("Proceedings",
                  XMLAGG(XMLELEMENT("Proceeding",
                    XMLFOREST
                     (proceedingtype "ProceedingType",
                      proceedingdate "ProceedingDate",
                      status "Status",
                      statusdate "StatusDate",
                      decision "Decision",
                      poicamount "POICAmount",
                      description "ProceedingsDetails"
                     )
                   ))
                 ) a
                  FROM 
                  (SELECT
                      NVL(h.proceedingtype,'(None)') proceedingtype,
                      NVL(TO_CHAR(d.scheduledstartdate,'DD-MON-YYYY'),'DD-MON-YYYY') proceedingdate,
                      (SELECT jac.statusname FROM query.j_accusation jac WHERE jac.jobid = d.jobid) status,
                      TO_CHAR(d.datecompleted,'DD-MON-YYYY') statusdate,
                      UPPER(d.outcome) decision,
                      (SELECT jac.poicamount FROM query.j_accusation jac WHERE jac.jobid = d.jobid) poicamount,
                      regexp_replace(d.description, '([^[:print:]])','') description,
                      d.jobid
                    FROM query.p_executetermsofdecision d
                    LEFT OUTER JOIN query.p_processhearing h ON h.jobid = d.jobid
                   WHERE d.outcome IS NOT NULL
                     AND 
                      (
                       (h.processid = (SELECT MAX(h1.processid) FROM query.p_processhearing h1 WHERE h1.jobid = h.jobid) 
                         AND
                        d.processid = 
                         (SELECT MAX(d1.processid) FROM query.p_executetermsofdecision d1 WHERE d1.jobid = d.jobid AND d1.outcome IS NOT NULL) 
                       ) 
                         OR
                       (d.processid = 
                         (SELECT MAX(d1.processid) FROM query.p_executetermsofdecision d1 WHERE d1.jobid = d.jobid AND d1.outcome IS NOT NULL) 
                        AND
                          d.jobid NOT IN (SELECT h1.jobid FROM query.p_processhearing h1 WHERE h1.jobid = d.jobid) 
                       ) 
                      )
                UNION
                   SELECT
                      NVL(h.proceedingtype,'(None)') proceedingtype,
                      NVL(TO_CHAR(h.scheduledstartdate,'DD-MON-YYYY'),'MON DD, YYYY') proceedingdate,
                      (SELECT jac.statusname FROM query.j_accusation jac WHERE jac.jobid = h.jobid) status,
                      TO_CHAR(h.datecompleted,'DD-MON-YYYY') statusdate,
                      UPPER(d.outcome) decision,
                      (SELECT jac.poicamount FROM query.j_accusation jac WHERE jac.jobid = h.jobid) poicamount,
                      d.description,
                      h.jobid
                     FROM query.p_processhearing h
                     LEFT OUTER JOIN query.p_executetermsofdecision d ON d.jobid = h.jobid AND d.outcome IS NOT NULL
                    WHERE h.processid = (SELECT MAX(h1.processid) FROM query.p_processhearing h1 WHERE h1.jobid = h.jobid)
                      AND h.jobid NOT IN 
                        (SELECT d1.jobid 
                           FROM query.p_executetermsofdecision d1 
                          WHERE d1.jobid = h.jobid 
                            AND d1.outcome IS NOT NULL)
                  )
                 WHERE jobid = jac.jobid
             )
                                                                                                                                            
        )
          ORDER BY jlc.licensenumber, jac.regnumber
        )
          FROM query.j_accusation jac
          JOIN query.r_licenseaccusations rla
            ON rla.accusationjobid = jac.jobid
          JOIN query.j_license jlc
            ON jlc.jobid = rla.licensejobid
         WHERE (lv_report_name = 'Legal Actions Finalized' AND
                TRUNC(NVL(jac.cleareddate, jac.completeddate)) BETWEEN TRUNC(ld_start) AND TRUNC(ld_end) AND
                jac.statusname IN ('CLOSED', 'DISMSD'))
            OR (lv_report_name = 'Legal Actions Filed' AND
                TRUNC(jac.accusationregistereddate) BETWEEN TRUNC(ld_start) AND TRUNC(ld_end + 1) AND
                jac.statusname NOT IN ('CLOSED', 'DISMSD')) 
        ))
        INTO lxml
        FROM DUAL;
 
        -- add processing instruction to xml  
        SELECT XMLPI(NAME "xml-stylesheet", 'href="../Formats/WeeklyLegalProceedings.xslt" type="text/xsl"') INTO lxml_pi FROM DUAL;
          
        p_status_ind := 'C'; -- tjl 08/28/2019 changed 'F' to 'C' to not call formating process
          
        lblob := rqs_utils.clob2blob(lxml_pi.GETCLOBVAL() || lxml.GETCLOBVAL());
        
        -- 08/28/2019 tjl added
        insert into abclqs.lqs_reports_data (report_number,
                                             report_name,
                                             startdate,
                                             enddate,
                                             report_data)
                                  values (p_parms.get_value('REPORT_NUMBER'),
                                          lv_report_name,
                                          ld_start,
                                          ld_end,
                                          lblob);
                                          
        return lblob;

    EXCEPTION
        WHEN OTHERS THEN
            rqs_utils.log(p_log_type          =>  'E',
                          p_job_id            =>  p_parms.get_value('JOB_ID'),
                          p_seq               =>  TO_NUMBER(p_parms.get_value('SEQ')),
                          p_source            =>  'FinalLegalProceedings',
                          p_msg               =>  SQLERRM,
                          p_error_trace       =>  dbms_utility.format_error_backtrace);             
                                   
            p_status_ind := 'E';
            RETURN utl_raw.cast_to_raw('ERROR: ' || SQLERRM || CHR(10) || CHR(13) ||
                                       'TRACE: ' || dbms_utility.format_error_backtrace);
        
    END WeeklyLegalProceedings;
/


GRANT EXECUTE ON ABCREPORTS.WEEKLYLEGALPROCEEDINGS TO ABCREPORTS_ROLE;
