CREATE OR REPLACE FUNCTION ABCREPORTS.ABC19Section12Detail(p_parms      IN OUT t_parameters,
                                                p_status_ind IN OUT VARCHAR2) 
              RETURN BLOB IS
-- ****************************************************************************
-- File:        ABC19Section12Detail.fnc  
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
-- 05/16/2015 TJL   7250    Original file created
-- 09/14/2015 TJL   8156    Corrected bug for missing Licensee information.
--                          Added processing instruction and change heading
--                          location.
-- 09/27/2016 TJL   7213    Changed output from CLOB to BLOB  
-- ****************************************************************************

    lv_msg              VARCHAR2(12000) := NULL;
    ln_return_code      NUMBER;
    offices_id          t_officeobject;
    ld_start_date       DATE;
    lblob               BLOB;
    lxml                XMLTYPE;
    lv_report_heading   VARCHAR2(200);
    lxml_pi             XMLTYPE;
    
    BEGIN 
--        SELECT parameter_value
--          INTO lv_report_heading
--          FROM report_parameters
--         WHERE report_number = TO_NUMBER(p_parms.get_value('REPORT_NUMBER'))
--           AND parameter_type = 'F'
--           AND parameter_name = 'HEADING';

        lv_report_heading := p_parms.get_value('REPORT_NAME');
                    
        IF (p_parms.get_value('REPORT_DATE') IS NOT NULL) THEN
            -- make sure day of month is the first  
            ld_start_date := TRUNC(TO_DATE(p_parms.get_value('REPORT_DATE'), 'MM/DD/YYYY'), 'MM');
        ELSE
            lv_msg := 'Report Date: No report date found';
        END IF; 
        
        offices_id := rqs_utils.BuildOfficeList(p_parms.get_value('OFFICEOBJECTID'),
                                                lv_msg);

        IF (lv_msg IS NOT NULL) THEN
            rqs_utils.log(p_log_type          =>  'E',
                          p_job_id            =>  p_parms.get_value('JOB_ID'),
                          p_seq               =>  TO_NUMBER(p_parms.get_value('SEQ')),
                          p_source            =>  'ABC19Section12Detail',
                          p_msg               =>  lv_msg);             
         END IF;
        
        SELECT XMLELEMENT("ROOT",
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
                                     investigationnumber,
                                     investigationtype,
                                     TO_CHAR(createddate, 'MM/DD/YYYY') createddate,
                                     TO_CHAR(completeddate, 'MM/DD/YYYY') completeddate
                                    )
                            )
                          )
                 FROM
                    (SELECT '04 Pending Beginning Complaint' Name,
                            'Pending Beginning Complaint' description,
                            J.LICENSENUMBER,
                            J.PRIMARYLICENSEE,
                            J.INVESTIGATIONNUMBER,
                            I.INVESTIGATIONTYPE,
                            I.CREATEDDATE,
                            I.COMPLETEDDATE                                     --count(i.ObjectId)
                       FROM mart.investigation i
                       JOIN QUERY.J_INVESTIGATION j ON J.JOBID = I.OBJECTID
                      WHERE i.InvestigationType = 'COMPLAINT'
                        AND TRUNC (i.CreatedDate) < ld_start_date
                        AND (i.CompletedDate IS NULL
                             OR (SELECT TRUNC (t.EffectiveStartDate)
                                   FROM extension.jobstatuschange_t t
                                  WHERE t.jobid = i.ObjectId
                                    AND t.StatusName = 'CLOSED'
                                    AND t.JobStatusChangeId =
                                          (SELECT MIN (t.JobStatusChangeId)
                                             FROM extension.jobstatuschange_t t
                                            WHERE t.jobid = i.ObjectId
                                              AND t.StatusName = 'CLOSED')) 
                                >= ld_start_date)
                        AND api.pkg_columnquery.VALUE (i.objectid, 'StatusName') <> 'CANCEL'
                        AND i.investigationofficeobjectid IN (SELECT officeobjectid FROM TABLE(offices_id))
                UNION ALL
                    SELECT '01 Pending Beginning Adminstrative' Name,
                           'Pending Beginning Adminstrative' description,
                           J.LICENSENUMBER,
                           J.PRIMARYLICENSEE,
                           J.INVESTIGATIONNUMBER,
                           I.INVESTIGATIONTYPE,
                           I.CREATEDDATE,
                           I.COMPLETEDDATE                                     --count(i.ObjectId)
                      FROM mart.investigation i
                      JOIN QUERY.J_INVESTIGATION j ON J.JOBID = I.OBJECTID
                     WHERE i.InvestigationType = 'ADMINISTRATIVE'
                       AND TRUNC (i.CreatedDate) < ld_start_date
                       AND (i.CompletedDate IS NULL
                            OR (SELECT TRUNC (t.EffectiveStartDate)
                                  FROM extension.jobstatuschange_t t
                                     WHERE t.jobid = i.ObjectId
                                       AND t.StatusName = 'CLOSED'
                                       AND t.JobStatusChangeId =
                                                  (SELECT MIN (t.JobStatusChangeId)
                                                     FROM extension.jobstatuschange_t t
                                                    WHERE t.jobid = i.ObjectId
                                                      AND t.StatusName = 'CLOSED')) >= ld_start_date)
                       AND api.pkg_columnquery.VALUE (i.objectid, 'StatusName') <> 'CANCEL'
                       AND i.investigationofficeobjectid IN (SELECT officeobjectid FROM TABLE(offices_id))
                UNION ALL
                    SELECT '07 Pending Beginning Report Assigned for Inv' Name,
                           'Pending Beginning Report Assigned for Inv' description,
                           J.LICENSENUMBER,
                           J.PRIMARYLICENSEE,
                           J.INVESTIGATIONNUMBER,
                           I.INVESTIGATIONTYPE,
                           I.CREATEDDATE,
                           I.COMPLETEDDATE                                     --count(i.ObjectId)
                      FROM mart.investigation i
                      JOIN QUERY.J_INVESTIGATION j ON J.JOBID = I.OBJECTID
                     WHERE i.InvestigationType = 'POLICE REPORT'
                       AND TRUNC(i.CreatedDate) < ld_start_date
                       AND (i.CompletedDate IS NULL
                            OR (SELECT TRUNC(t.EffectiveStartDate)
                                  FROM extension.jobstatuschange_t t
                                 WHERE t.jobid = i.ObjectId
                                   AND t.StatusName = 'CLOSED'
                                   AND t.JobStatusChangeId =
                                            (SELECT MIN (t.JobStatusChangeId)
                                               FROM extension.jobstatuschange_t t
                                              WHERE t.jobid = i.ObjectId
                                                AND t.StatusName = 'CLOSED')) >= ld_start_date)
                       AND api.pkg_columnquery.VALUE (i.objectid, 'StatusName') <> 'CANCEL'
                       AND i.investigationofficeobjectid IN (SELECT officeobjectid FROM TABLE(offices_id))
                UNION ALL
                        SELECT '10 Pending Beginning TRACE' Name,
                               'Pending Beginning TRACE' description,
                               J.LICENSENUMBER,
                               J.PRIMARYLICENSEE,
                               J.INVESTIGATIONNUMBER,
                               I.INVESTIGATIONTYPE,
                               I.CREATEDDATE,
                               I.COMPLETEDDATE                                     --count(i.ObjectId)
                          FROM mart.investigation i
                          JOIN QUERY.J_INVESTIGATION j ON J.JOBID = I.OBJECTID
                         WHERE i.InvestigationType = 'TRACE'
                           AND TRUNC (i.CreatedDate) < ld_start_date
                           AND (i.CompletedDate IS NULL
                                OR (SELECT TRUNC(t.EffectiveStartDate)
                                      FROM extension.jobstatuschange_t t
                                     WHERE t.jobid = i.ObjectId
                                       AND t.StatusName = 'CLOSED'
                                       AND t.JobStatusChangeId =
                                                (SELECT MIN (t.JobStatusChangeId)
                                                   FROM extension.jobstatuschange_t t
                                                  WHERE t.jobid = i.ObjectId
                                                    AND t.StatusName = 'CLOSED')) >= ld_start_date)
                           AND api.pkg_columnquery.VALUE (i.objectid, 'StatusName') <> 'CANCEL'
                           AND i.investigationofficeobjectid IN (SELECT officeobjectid FROM TABLE(offices_id))
           
                UNION ALL       
                    -- RECEIVED
                    SELECT '05 Received Complaint Investigations' Name,
                           'Received Complaint Investigations' description,
                           J.LICENSENUMBER,
                           J.PRIMARYLICENSEE,
                           J.INVESTIGATIONNUMBER,
                           I.INVESTIGATIONTYPE,
                           I.CREATEDDATE,
                           I.COMPLETEDDATE                                     --count(i.ObjectId)
                      FROM mart.investigation i
                      JOIN QUERY.J_INVESTIGATION j ON J.JOBID = I.OBJECTID
                     WHERE i.InvestigationType = 'COMPLAINT'
                       AND api.pkg_columnquery.VALUE (i.objectid, 'StatusName') <> 'CANCEL'
                       AND TRUNC(i.CreatedDate, 'MM') = ld_start_date
                       AND i.investigationofficeobjectid IN (SELECT officeobjectid FROM TABLE(offices_id))
                UNION ALL
                    SELECT '02 Received Administrative' Name,
                           'Received Administrative' description,
                           J.LICENSENUMBER,
                           J.PRIMARYLICENSEE,
                           J.INVESTIGATIONNUMBER,
                           I.INVESTIGATIONTYPE,
                           I.CREATEDDATE,
                           I.COMPLETEDDATE                                     --count(i.ObjectId)
                      FROM mart.investigation i
                      JOIN QUERY.J_INVESTIGATION j ON J.JOBID = I.OBJECTID
                     WHERE i.InvestigationType = 'ADMINISTRATIVE'
                       AND api.pkg_columnquery.VALUE (i.objectid, 'StatusName') <> 'CANCEL'
                       AND TRUNC(i.CreatedDate, 'MM') = ld_start_date
                       AND i.investigationofficeobjectid IN (SELECT officeobjectid FROM TABLE(offices_id))
                UNION ALL
                    SELECT '08 Received Report Assigned for Inv' Name,
                           'Received Report Assigned for Inv' description,
                           J.LICENSENUMBER,
                           J.PRIMARYLICENSEE,
                           J.INVESTIGATIONNUMBER,
                           I.INVESTIGATIONTYPE,
                           I.CREATEDDATE,
                           I.COMPLETEDDATE                                     --count(i.ObjectId)
                      FROM mart.investigation i
                      JOIN QUERY.J_INVESTIGATION j ON J.JOBID = I.OBJECTID
                     WHERE i.InvestigationType = 'POLICE REPORT'
                       AND api.pkg_columnquery.VALUE (i.objectid, 'StatusName') <> 'CANCEL'
                       AND TRUNC(i.CreatedDate, 'MM') = ld_start_date
                       AND i.investigationofficeobjectid IN (SELECT officeobjectid FROM TABLE(offices_id))
                UNION ALL
                    SELECT '11 ReceivedTRACE' Name,
                           'Received TRACE' description,
                           J.LICENSENUMBER,
                           J.PRIMARYLICENSEE,
                           J.INVESTIGATIONNUMBER,
                           I.INVESTIGATIONTYPE,
                           I.CREATEDDATE,
                           I.COMPLETEDDATE                                     --count(i.ObjectId)
                      FROM mart.investigation i
                      JOIN QUERY.J_INVESTIGATION j ON J.JOBID = I.OBJECTID
                     WHERE i.InvestigationType = 'TRACE'
                       AND api.pkg_columnquery.VALUE (i.objectid, 'StatusName') <> 'CANCEL'
                       AND TRUNC(i.CreatedDate, 'MM') = ld_start_date
                       AND i.investigationofficeobjectid IN (SELECT officeobjectid FROM TABLE(offices_id))
                UNION ALL
                    --COMPLETED
                    SELECT '06 Completed Complaint Investigations' Name,
                           'Completed Complaint Investigations' description,
                           J.LICENSENUMBER,
                           J.PRIMARYLICENSEE,
                           J.INVESTIGATIONNUMBER,
                           I.INVESTIGATIONTYPE,
                           I.CREATEDDATE,
                           I.COMPLETEDDATE                                     --count(i.ObjectId)
                      FROM mart.investigation i
                      JOIN QUERY.J_INVESTIGATION j ON J.JOBID = I.OBJECTID
                     -- from mart.investigation i
                     WHERE i.InvestigationType = 'COMPLAINT'
                       AND (SELECT TRUNC(t.EffectiveStartDate, 'MM')
                              FROM extension.jobstatuschange_t t
                             WHERE t.jobid = i.ObjectId
                               AND t.StatusName = 'CLOSED'
                               AND t.JobStatusChangeId =
                                       (SELECT MIN (t.JobStatusChangeId)
                                          FROM extension.jobstatuschange_t t
                                         WHERE t.jobid = i.ObjectId
                                           AND t.StatusName = 'CLOSED')) = ld_start_date
                       AND api.pkg_columnquery.VALUE (i.objectid, 'StatusName') <> 'CANCEL'
                       AND i.investigationofficeobjectid IN (SELECT officeobjectid FROM TABLE(offices_id))
                UNION ALL
                    SELECT '03 Completed Administrative' Name,
                           'Completed Administrative' description,
                           J.LICENSENUMBER,
                           J.PRIMARYLICENSEE,
                           J.INVESTIGATIONNUMBER,
                           I.INVESTIGATIONTYPE,
                           I.CREATEDDATE,
                           I.COMPLETEDDATE                                     --count(i.ObjectId)
                      FROM mart.investigation i
                      JOIN QUERY.J_INVESTIGATION j ON J.JOBID = I.OBJECTID
                     WHERE i.InvestigationType = 'ADMINISTRATIVE'
                       AND (SELECT TRUNC(t.EffectiveStartDate, 'MM')
                              FROM extension.jobstatuschange_t t
                             WHERE t.jobid = i.ObjectId
                               AND t.StatusName = 'CLOSED'
                               AND t.JobStatusChangeId =
                                        (SELECT MIN (t.JobStatusChangeId)
                                           FROM extension.jobstatuschange_t t
                                          WHERE t.jobid = i.ObjectId
                                            AND t.StatusName = 'CLOSED')) = ld_start_date
                       AND api.pkg_columnquery.VALUE (i.objectid, 'StatusName') <> 'CANCEL'
                       AND i.investigationofficeobjectid IN (SELECT officeobjectid FROM TABLE(offices_id))
                UNION ALL
                    SELECT '09 Completed Report Assigned for Inv' Name,
                           'Completed Report Assigned for Inv' description,
                           J.LICENSENUMBER,
                           J.PRIMARYLICENSEE,
                           J.INVESTIGATIONNUMBER,
                           I.INVESTIGATIONTYPE,
                           I.CREATEDDATE,
                           I.COMPLETEDDATE                                     --count(i.ObjectId)
                      FROM mart.investigation i
                      JOIN QUERY.J_INVESTIGATION j ON J.JOBID = I.OBJECTID
                     WHERE i.InvestigationType = 'POLICE REPORT'
                       AND (SELECT TRUNC(t.EffectiveStartDate, 'MM')
                              FROM extension.jobstatuschange_t t
                             WHERE t.jobid = i.ObjectId
                               AND t.StatusName = 'CLOSED'
                               AND t.JobStatusChangeId =
                                       (SELECT MIN (t.JobStatusChangeId)
                                          FROM extension.jobstatuschange_t t
                                         WHERE t.jobid = i.ObjectId
                                           AND t.StatusName = 'CLOSED')) = ld_start_date
                       AND api.pkg_columnquery.VALUE (i.objectid, 'StatusName') <> 'CANCEL'
                       AND i.investigationofficeobjectid IN (SELECT officeobjectid FROM TABLE(offices_id))
                UNION ALL
                    SELECT '12 Completed TRACE' Name,
                           'Completed TRACE' description,
                           J.LICENSENUMBER,
                           J.PRIMARYLICENSEE,
                           J.INVESTIGATIONNUMBER,
                           I.INVESTIGATIONTYPE,
                           I.CREATEDDATE,
                           I.COMPLETEDDATE                                     --count(i.ObjectId)
                      FROM mart.investigation i
                      JOIN QUERY.J_INVESTIGATION j ON J.JOBID = I.OBJECTID
                     WHERE i.InvestigationType = 'TRACE'
                       AND (SELECT TRUNC(t.EffectiveStartDate, 'MM')
                              FROM extension.jobstatuschange_t t
                             WHERE t.jobid = i.ObjectId
                               AND t.StatusName = 'CLOSED'
                               AND t.JobStatusChangeId =
                                      (SELECT MIN (t.JobStatusChangeId)
                                         FROM extension.jobstatuschange_t t
                                        WHERE t.jobid = i.ObjectId
                                          AND t.StatusName = 'CLOSED')) = ld_start_date
                           AND api.pkg_columnquery.VALUE (i.objectid, 'StatusName') <> 'CANCEL'
                           AND i.investigationofficeobjectid IN (SELECT officeobjectid FROM TABLE(offices_id))

                     ORDER BY name, createddate, licensenumber
            )))
          INTO lxml
          FROM DUAL;
       
        -- add processing instruction to xml  
        SELECT XMLPI(NAME "xml-stylesheet", 'href="../Formats/ABC19Section12Detail.xslt" type="text/xsl"') INTO lxml_pi FROM DUAL;
          
        lblob := rqs_utils.clob2blob(lxml_pi.GETCLOBVAL() || lxml.GETCLOBVAL());
        p_status_ind := 'F';
          
        RETURN lblob;

    EXCEPTION
        WHEN OTHERS THEN
            rqs_utils.log(p_log_type          =>  'E',
                          p_job_id            =>  p_parms.get_value('JOB_ID'),
                          p_seq               =>  TO_NUMBER(p_parms.get_value('SEQ')),
                          p_source            =>  'ABC19Section12Detail',
                          p_msg               =>  SQLERRM,
                          p_error_trace       =>  dbms_utility.format_error_backtrace);             
                                    
            p_status_ind := 'E';
            RETURN utl_raw.cast_to_raw('ERROR: ' || SQLERRM || CHR(10) || CHR(13) ||
                                       'TRACE: ' || dbms_utility.format_error_backtrace);
        
    END ABC19Section12Detail;
/


GRANT EXECUTE ON ABCREPORTS.ABC19SECTION12DETAIL TO ABCREPORTS_ROLE;
