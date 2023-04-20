CREATE OR REPLACE FUNCTION ABCREPORTS.ABC19Section8Detail(
                                 p_parms      IN OUT t_parameters,
                                 p_status_ind IN OUT VARCHAR2) 
              RETURN BLOB IS

    lv_msg              VARCHAR2(12000) := NULL;
    ln_return_code      NUMBER;
    office_ids          T_OFFICEOBJECT;
    ld_start_date       DATE;
    lblob               BLOB;
    lxml                XMLTYPE;
    lv_report_heading   VARCHAR2(200);
    lxml_pi             XMLTYPE;
    
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
                                     --TO_CHAR(createdDate, 'MM/DD/YYYY') createdDate,
                                     TO_CHAR(ENTERAPPLICATIONCOMPLETEDDATE, 'MM/DD/YYYY') createdDate, --ENTERAPPLICATIONCOMPLETEDDATE,
                                     STATUSNAME,
                                     BASEFILEOFFICENAME,
                                     TO_CHAR(datecompleted, 'MM/DD/YYYY') datecompleted
                                    )
                            )
                          )
                 FROM
                    (SELECT '03 ApprovedOriginal' Name,
                            'Approved Original' description,
                            A.LICENSENUMBER,
                            A.PRIMARYLICENSEE,
                            A.CREATEDDATE,
                            A.ENTERAPPLICATIONCOMPLETEDDATE,
                            A.STATUSNAME,
                            A.BASEFILEOFFICENAME,
                            d.DATECOMPLETED
                       FROM mart.districtapplicationreview d
                       JOIN mart.application a ON a.objectid = d.jobid
                      WHERE d.Outcome IN ('224 Approval',
                                          'Approve Application',
                                          'Approve With Division Review')
                        AND (a.ABC19Original = 'Y' OR a.AddPrimaryLicenseType = 'Y')
                        AND d.HasLicenseType79 = 'N'
                        AND d.haslicensetype84 = 'N'
                        AND d.districtofficeid IN (SELECT officeobjectid FROM TABLE(office_ids))
                        AND TRUNC(d.DateCompleted, 'MM') = ld_start_date
                        AND d.ObjectId IN (SELECT MIN (d1.ObjectId)
                                             FROM mart.districtapplicationreview d1
                                            WHERE d1.JobId = d.JobId
                                            GROUP BY d1.JobId) 
                UNION ALL
                     SELECT '03 ApprovedOriginal' Name,
                            'Approved Original' description,
                            A.LICENSENUMBER,
                            A.PRIMARYLICENSEE,
                            A.CREATEDDATE,
                            A.ENTERAPPLICATIONCOMPLETEDDATE,
                            A.STATUSNAME,
                            A.BASEFILEOFFICENAME,                               -- count(d.ObjectId)
                            p.DATECOMPLETED                               -- count(d.ObjectId)
                       FROM mart.issuelicense p 
                       JOIN mart.application a ON a.objectid = p.jobid
                      WHERE p.Outcome IS NOT NULL
                        AND (a.ABC19Original = 'Y' OR a.AddPrimaryLicenseType = 'Y')
                        AND a.HasLicenseType79 = 'N'
                        AND a.haslicensetype84 = 'N'
                        AND a.BaseFileOfficeid IN (SELECT officeobjectid FROM TABLE(office_ids))
                        AND TRUNC(p.DateCompleted, 'MM') = ld_start_date
                        AND EXISTS
                                  (SELECT 1
                                     FROM extension.jobstatuschange_t j
                                    WHERE j.jobid = a.objectid
                                      AND j.statusname = 'ISSUED'
                                      AND TRUNC(j.effectivestartdate, 'MM') = TRUNC(p.DateCompleted, 'MM'))
                        AND p.ObjectId IN (SELECT MIN (p2.ObjectId)
                                             FROM mart.issuelicense p2
                                            WHERE p2.JobId = a.objectid
                                            GROUP BY p2.JobId)
                        AND NOT EXISTS
                                  (SELECT 1
                                     FROM mart.districtapplicationreview d
                                    WHERE d.jobid = a.objectid AND d.outcome IS NOT NULL) --) ApprovedOriginal,
                UNION ALL
                     SELECT '09 ApprovedPerToPer' Name,
                            'Approved Per to Per' description,
                            A.LICENSENUMBER,
                            A.PRIMARYLICENSEE,
                            A.CREATEDDATE,
                            A.ENTERAPPLICATIONCOMPLETEDDATE,
                            A.STATUSNAME,
                            A.BASEFILEOFFICENAME,
                            d.DATECOMPLETED 
                       FROM mart.districtapplicationreview d
                       JOIN mart.application a ON a.objectid = d.jobid
                     WHERE d.Outcome IN ('224 Approval',
                                             'Approve Application',
                                             'Approve With Division Review')
                           AND d.ABC19PerToPer = 'Y'
                           AND d.HasLicenseType79 = 'N'
                           AND d.haslicensetype84 = 'N'
                           AND d.ABC19Original <> 'Y'
                           AND TRUNC(d.DateCompleted, 'MM') = ld_start_date
                           AND d.districtofficeid IN (SELECT officeobjectid FROM TABLE(office_ids))
                           AND d.ObjectId IN (SELECT MIN (d1.ObjectId)
                                                FROM mart.districtapplicationreview d1
                                               WHERE d1.JobId = d.JobId
                                               GROUP BY d1.JobId)                               --)
                UNION ALL
                    SELECT '09 ApprovedPerToPer' Name,
                            'Approved Per to Per' description,
                            A.LICENSENUMBER,
                            A.PRIMARYLICENSEE,
                            A.CREATEDDATE,
                            A.ENTERAPPLICATIONCOMPLETEDDATE,
                            A.STATUSNAME,
                            A.BASEFILEOFFICENAME,
                            p.DATECOMPLETED
                       FROM mart.issuelicense p
                            JOIN mart.application a ON a.objectid = p.jobid
                            JOIN extension.jobstatuschange_t j ON j.jobid = a.objectid
                     WHERE p.Outcome IS NOT NULL
                       AND a.ABC19PerToPer = 'Y'
                       AND a.ABC19Original <> 'Y'
                       AND a.HasLicenseType79 = 'N'
                       AND a.haslicensetype84 = 'N'
                       AND TRUNC(p.DateCompleted, 'MM') = ld_start_date
                       AND a.BaseFileOfficeid IN (SELECT officeobjectid FROM TABLE(office_ids))
                       AND EXISTS
                                  (SELECT 1
                                     FROM extension.jobstatuschange_t j
                                    WHERE j.jobid = a.objectid
                                      AND j.statusname = 'ISSUED'
                                      AND TRUNC(j.effectivestartdate, 'MM') = TRUNC(p.DateCompleted, 'MM'))
                       AND p.ObjectId IN (SELECT MIN (p2.ObjectId)
                                            FROM mart.issuelicense p2
                                           WHERE p2.JobId = a.objectid
                                           GROUP BY p2.JobId)
                       AND NOT EXISTS
                                  (SELECT 1
                                     FROM mart.districtapplicationreview d
                                    WHERE d.jobid = a.objectid AND d.outcome IS NOT NULL)
                                    
                UNION ALL               
                    -- PENDING BEGINNING COMBINED
                    SELECT '01 PendBegOriginal' Name,
                            'Pending Beginning Original' description,
                           A.LICENSENUMBER,
                           A.PRIMARYLICENSEE,
                           A.CREATEDDATE,
                           A.ENTERAPPLICATIONCOMPLETEDDATE,
                           A.STATUSNAME,
                           A.BASEFILEOFFICENAME,                               -- count(d.ObjectId)
                           a.DistrictAppReviewProcDate DATECOMPLETED
                      FROM mart.application a
                     WHERE (a.ABC19Original = 'Y' OR a.AddPrimaryLicenseType = 'Y')
                       AND a.HasLicenseType79 = 'N'
                       AND a.haslicensetype84 = 'N'
                       AND a.BaseFileOfficeid IN (SELECT officeobjectid FROM TABLE(office_ids))
                       AND TRUNC (a.EnterApplicationCompletedDate) < ld_start_date
                       AND EXISTS
                                  (SELECT 1
                                     FROM extension.JobStatusChange j
                                    WHERE j.JobId = a.ObjectId
                                      AND j.StatusName IN ('PEND', 'APPLD', 'ISSUPD')
                                      AND (TRUNC(j.EffectiveStartDate) < ld_start_date
                                           AND (j.EffectiveEndDate IS NULL
                                                OR TRUNC (j.EffectiveEndDate) >= ld_start_date)))
                       AND (TRUNC(a.DistrictAppReviewProcDate) >= ld_start_date
                            OR (TRUNC(a.DistrictAppReviewProcDate) IS NULL
                                AND EXISTS
                                           (SELECT 1
                                              FROM extension.JobStatusChange j
                                             WHERE j.JobId = a.ObjectId
                                               AND j.StatusName IN ('PEND', 'APPLD', 'ISSUPD')
                                               AND (TRUNC(j.EffectiveStartDate) < ld_start_date
                                                      AND (j.EffectiveEndDate IS NULL
                                                           OR TRUNC (j.EffectiveEndDate) >= ld_start_date)))
                                AND NOT EXISTS
                                           (SELECT 1
                                              FROM extension.JobStatusChange j
                                             WHERE j.JobId = a.ObjectId
                                               AND j.StatusName IN ('ISSUED',
                                                                    'DENIED',
                                                                    'WTHDRN',
                                                                     'VOIDED')
                                               AND (TRUNC(j.EffectiveStartDate) < ld_start_date
                                                    AND (j.EffectiveEndDate IS NULL
                                                         OR TRUNC(j.EffectiveEndDate) >= ld_start_date))))) --) PendBegOriginal
                UNION ALL
                    SELECT '07 PendBegPerToPer' Name,
                            'Pending Beginning Per to Per' description,
                           A.LICENSENUMBER,
                            A.PRIMARYLICENSEE,
                           A.CREATEDDATE,
                           A.ENTERAPPLICATIONCOMPLETEDDATE,
                           A.STATUSNAME,
                           A.BASEFILEOFFICENAME,
                           a.DistrictAppReviewProcDate DATECOMPLETED
                      FROM mart.application a
                     WHERE a.ABC19PerToPer = 'Y'
                           AND a.HasLicenseType79 = 'N'
                           AND a.haslicensetype84 = 'N'
                           AND a.BaseFileOfficeid IN (SELECT officeobjectid FROM TABLE(office_ids))
                           AND TRUNC (a.EnterApplicationCompletedDate) < ld_start_date
                           AND EXISTS
                                  (SELECT 1
                                     FROM extension.JobStatusChange j
                                    WHERE j.JobId = a.ObjectId
                                      AND j.StatusName IN ('PEND', 'APPLD', 'ISSUPD')
                                      AND (TRUNC (j.EffectiveStartDate) < ld_start_date
                                           AND (j.EffectiveEndDate IS NULL
                                                OR TRUNC (j.EffectiveEndDate) >= ld_start_date)))
                           AND (TRUNC (a.DistrictAppReviewProcDate) >= ld_start_date
                                OR (TRUNC (a.DistrictAppReviewProcDate) IS NULL
                                    AND EXISTS
                                           (SELECT 1
                                              FROM extension.JobStatusChange j
                                             WHERE j.JobId = a.ObjectId
                                               AND j.StatusName IN ('PEND', 'APPLD', 'ISSUPD')
                                               AND (TRUNC(j.EffectiveStartDate) < ld_start_date
                                                    AND (j.EffectiveEndDate IS NULL
                                                         OR TRUNC (j.EffectiveEndDate) >= ld_start_date)))
                                 AND NOT EXISTS
                                               (SELECT 1
                                                  FROM extension.JobStatusChange j
                                                 WHERE j.JobId = a.ObjectId
                                                   AND j.StatusName IN ('ISSUED',
                                                                        'DENIED',
                                                                        'WTHDRN',
                                                                        'VOIDED')
                                                   AND (TRUNC (j.EffectiveStartDate) < ld_start_date
                                                        AND (j.EffectiveEndDate IS NULL
                                                             OR TRUNC (j.EffectiveEndDate) >= ld_start_date)))))
                           AND a.ABC19Original <> 'Y'                          --) PendBegPerToPer
                UNION ALL
                    -- RECIEVED CCMBINED
                    SELECT '02 ReceivedOriginal' Name,
                            'Received Original' description,
                           A.LICENSENUMBER,
                            A.PRIMARYLICENSEE,
                           A.CREATEDDATE,
                           A.ENTERAPPLICATIONCOMPLETEDDATE,
                           A.STATUSNAME,
                           A.BASEFILEOFFICENAME,                               -- count(d.ObjectId)
                           a.DistrictAppReviewProcDate DATECOMPLETED
                      FROM mart.application a
                     WHERE a.ABC19Original = 'Y'
                       AND a.HasLicenseType79 = 'N'
                       AND a.haslicensetype84 = 'N'
                       AND a.StatusName <> 'NEW'
                       AND a.BaseFileOfficeid IN (SELECT officeobjectid FROM TABLE(office_ids))
                       AND TRUNC (a.EnterApplicationCompletedDate, 'MM') = ld_start_date  --) ReceivedOriginal,
                UNION ALL
                    SELECT '08 ReceivedPerToPer' Name,
                            'Received Per to Per' description,
                           A.LICENSENUMBER,
                            A.PRIMARYLICENSEE,
                           A.CREATEDDATE,
                           A.ENTERAPPLICATIONCOMPLETEDDATE,
                           A.STATUSNAME,
                           A.BASEFILEOFFICENAME,                               -- count(d.ObjectId)
                           a.DistrictAppReviewProcDate DATECOMPLETED
                      FROM mart.application a
                     WHERE a.ABC19PerToPer = 'Y'
                       AND a.HasLicenseType79 = 'N'
                       AND a.haslicensetype84 = 'N'
                       AND a.StatusName <> 'NEW'
                       AND a.BaseFileOfficeid IN (SELECT officeobjectid FROM TABLE(office_ids))
                       AND TRUNC (a.EnterApplicationCompletedDate, 'MM') = ld_start_date
                       AND a.ABC19Original <> 'Y'                         --) ReceivedPerToPer
                UNION ALL
                    --VOIDED COMBINED
                    SELECT '06 VoidedOriginal' Name,
                            'Voided Original' description,
                           A.LICENSENUMBER,
                            A.PRIMARYLICENSEE,
                           A.CREATEDDATE,
                           A.ENTERAPPLICATIONCOMPLETEDDATE,
                           A.STATUSNAME,
                           A.BASEFILEOFFICENAME,                               -- count(d.ObjectId)
                           a.DistrictAppReviewProcDate DATECOMPLETED                                --count(a.ObjectId)
                      FROM mart.application a
                     WHERE (a.ABC19Original = 'Y' OR a.AddPrimaryLicenseType = 'Y')
                       AND a.HasLicenseType79 = 'N'
                       AND a.haslicensetype84 = 'N'
                       AND a.BaseFileOfficeid IN (SELECT officeobjectid FROM TABLE(office_ids))
                       AND EXISTS
                                  (SELECT 1
                                     FROM extension.JobStatusChange j
                                    WHERE j.JobId = a.ObjectId
                                      AND j.StatusName = 'VOIDED'
                                      AND TRUNC(j.EffectiveStartDate, 'MM') = ld_start_date
                                      AND (SELECT js2.statusname
                                             FROM extension.jobstatuschange js2
                                            WHERE js2.jobstatuschangeid =
                                                     (SELECT MAX (js.jobstatuschangeid) -- Gets the previous status
                                                        FROM extension.jobstatuschange js
                                                        WHERE js.jobid = a.objectid
                                                          AND js.jobstatuschangeid < j.jobstatuschangeid)
                                          ) <> 'NEW')                        --) VoidedOriginal,
                UNION ALL
                    SELECT '12 VoidedPerToPer' Name,
                            'Voided Per to Per' description,
                           A.LICENSENUMBER,
                            A.PRIMARYLICENSEE,
                           A.CREATEDDATE,
                           A.ENTERAPPLICATIONCOMPLETEDDATE,
                           A.STATUSNAME,
                           A.BASEFILEOFFICENAME,                               -- count(d.ObjectId)
                           a.DistrictAppReviewProcDate DATECOMPLETED                                --count(a.ObjectId)
                      FROM mart.application a
                     WHERE  a.ABC19PerToPer = 'Y'
                           AND a.ABC19Original <> 'Y'
                           AND a.HasLicenseType79 = 'N'
                           AND a.haslicensetype84 = 'N'
                           AND a.BaseFileOfficeid IN (SELECT officeobjectid FROM TABLE(office_ids))
                           AND EXISTS
                                  (SELECT 1
                                     FROM extension.JobStatusChange j
                                    WHERE j.JobId = a.ObjectId
                                      AND j.StatusName = 'VOIDED'
                                      AND TRUNC(j.EffectiveStartDate, 'MM') = ld_start_date
                                      AND (SELECT js2.statusname
                                             FROM extension.jobstatuschange js2
                                             WHERE js2.jobstatuschangeid =
                                                      (SELECT MAX (js.jobstatuschangeid) -- Gets the previous status
                                                         FROM extension.jobstatuschange js
                                                         WHERE js.jobid = a.objectid
                                                           AND js.jobstatuschangeid < j.jobstatuschangeid)
                                          ) <> 'NEW')                         --) VoidedPerToPer
                UNION ALL
                    --WITHDRAWN COMBINED
                    SELECT '05 WithdrawnOriginal' Name,
                            'Withdrawn Original' description,
                           A.LICENSENUMBER,
                            A.PRIMARYLICENSEE,
                           A.CREATEDDATE,
                           A.ENTERAPPLICATIONCOMPLETEDDATE,
                           A.STATUSNAME,
                           A.BASEFILEOFFICENAME,
                           D.DATECOMPLETED                                    -- count(d.ObjectId)
                      FROM mart.districtapplicationreview d
                           JOIN mart.application a ON a.objectid = d.jobid
                     WHERE  d.Outcome = 'Withdraw'
                           AND A.ENTERAPPLICATIONCOMPLETEDDATE IS NOT NULL
                           AND (a.ABC19Original = 'Y' OR a.AddPrimaryLicenseType = 'Y')
                           AND d.HasLicenseType79 = 'N'
                           AND d.haslicensetype84 = 'N'
                           AND d.districtofficeid IN (SELECT officeobjectid FROM TABLE(office_ids))
                           AND TRUNC(d.DateCompleted, 'MM') = ld_start_date
                           AND d.ObjectId IN (SELECT MIN (d1.ObjectId)
                                                FROM mart.districtapplicationreview d1
                                               WHERE d1.JobId = d.JobId
                                               GROUP BY d1.JobId)
                UNION ALL
                    SELECT '05 WithdrawnOriginal' Name,
                            'Withdrawn Original' description,
                           A.LICENSENUMBER,
                            A.PRIMARYLICENSEE,
                           A.CREATEDDATE,
                           A.ENTERAPPLICATIONCOMPLETEDDATE,
                           A.STATUSNAME,
                           A.BASEFILEOFFICENAME,
                           P.DATECOMPLETED                                     --count(p.ObjectId)
                      FROM mart.withdrawapplication p
                           JOIN mart.application a ON a.objectid = p.jobid
                     WHERE p.Outcome IS NOT NULL
                           AND A.ENTERAPPLICATIONCOMPLETEDDATE IS NOT NULL
                           AND a.ABC19Original = 'Y'
                           AND a.HasLicenseType79 = 'N'
                           AND a.haslicensetype84 = 'N'
                           AND a.BaseFileOfficeid IN (SELECT officeobjectid FROM TABLE(office_ids))
                           AND TRUNC(p.DateCompleted, 'MM') = ld_start_date
                           AND EXISTS
                                  (SELECT 1
                                     FROM extension.jobstatuschange_t j
                                    WHERE j.jobid = a.objectid
                                      AND j.statusname = 'WTHDRN'
                                      AND TRUNC(j.effectivestartdate, 'MM') = TRUNC(p.DateCompleted, 'MM'))
                           AND p.ObjectId IN (SELECT MIN (p2.ObjectId)
                                                FROM mart.withdrawapplication p2
                                               WHERE p2.JobId = a.objectId
                                               GROUP BY p2.JobId)
                           AND NOT EXISTS
                                  (SELECT 1
                                     FROM mart.districtapplicationreview d
                                    WHERE d.jobid = a.objectid 
                                      AND d.outcome IS NOT NULL) --) WithdrawnOriginal,
                UNION ALL
                    SELECT '11 WithdrawnPerToPer' Name,
                            'Withdrawn Per to Per' description,
                           A.LICENSENUMBER,
                            A.PRIMARYLICENSEE,
                           A.CREATEDDATE,
                           A.ENTERAPPLICATIONCOMPLETEDDATE,
                           A.STATUSNAME,
                           A.BASEFILEOFFICENAME,
                           D.DATECOMPLETED                                    -- count(d.ObjectId)
                      FROM mart.districtapplicationreview d
                           JOIN mart.application a ON a.objectid = d.jobid
                     WHERE d.Outcome = 'Withdraw'
                       AND A.ENTERAPPLICATIONCOMPLETEDDATE IS NOT NULL
                       AND d.ABC19PerToPer = 'Y'
                       AND d.HasLicenseType79 = 'N'
                       AND d.haslicensetype84 = 'N'
                       AND d.districtofficeid IN (SELECT officeobjectid FROM TABLE(office_ids))
                       AND TRUNC(d.DateCompleted, 'MM') = ld_start_date
                       AND  d.ABC19Original <> 'Y'
                       AND d.ObjectId IN (SELECT MIN (d1.ObjectId)
                                            FROM mart.districtapplicationreview d1
                                           WHERE d1.JobId = d.JobId
                                           GROUP BY d1.JobId)
                UNION ALL
                    SELECT '11 WithdrawnPerToPer' Name,
                            'Withdrawn Per to Per' description,
                           A.LICENSENUMBER,
                            A.PRIMARYLICENSEE,
                           A.CREATEDDATE,
                           A.ENTERAPPLICATIONCOMPLETEDDATE,
                           A.STATUSNAME,
                           A.BASEFILEOFFICENAME,
                           p.DATECOMPLETED                                     --count(p.ObjectId)
                      FROM mart.withdrawapplication p
                           JOIN mart.application a ON a.objectid = p.jobid
                     WHERE p.Outcome IS NOT NULL
                           AND A.ENTERAPPLICATIONCOMPLETEDDATE IS NOT NULL
                           AND a.ABC19PerToPer = 'Y'
                           AND a.ABC19Original <> 'Y'
                           AND a.HasLicenseType79 = 'N'
                           AND a.haslicensetype84 = 'N'
                           AND a.BaseFileOfficeid IN (SELECT officeobjectid FROM TABLE(office_ids))
                           AND TRUNC(p.DateCompleted, 'MM') = ld_start_date
                           AND EXISTS
                                  (SELECT 1
                                     FROM extension.jobstatuschange_t j
                                    WHERE j.jobid = a.objectid
                                      AND j.statusname = 'WTHDRN'
                                      AND TRUNC(j.effectivestartdate, 'MM') = TRUNC(p.DateCompleted, 'MM'))
                           AND p.ObjectId IN (SELECT MIN (p2.ObjectId)
                                                FROM mart.withdrawapplication p2
                                               WHERE p2.JobId = a.objectId
                                               GROUP BY p2.JobId)
                           AND NOT EXISTS
                                  (SELECT 1
                                     FROM mart.districtapplicationreview d
                                    WHERE d.jobid = a.objectid AND d.outcome IS NOT NULL) --) WithdrawnPerToPer,
                           
                     ORDER BY name, enterapplicationcompleteddate, basefileofficename, licensenumber
            )))
          INTO lxml
          FROM DUAL;
        
        -- add processing instruction to xml  
        SELECT XMLPI(NAME "xml-stylesheet", 'href="../Formats/ABC19Section8Detail.xslt" type="text/xsl"') INTO lxml_pi FROM DUAL;
          
        lblob := rqs_utils.clob2blob(lxml_pi.GETCLOBVAL() || lxml.GETCLOBVAL());
        p_status_ind := 'F';
          
        RETURN lblob;

    EXCEPTION
        WHEN OTHERS THEN
            rqs_utils.log(p_log_type          =>  'E',
                          p_job_id            =>  NULL,
                          p_seq               =>  TO_NUMBER(p_parms.get_value('SEQ')),
                          p_source            =>  'ABC19Section8Detail',
                          p_msg               =>  SQLERRM,
                          p_error_trace       =>  dbms_utility.format_error_backtrace);             
        
            p_status_ind := 'E';
            
            RETURN utl_raw.cast_to_raw('ERROR: ' || SQLERRM || CHR(10) || CHR(13) ||
                                       'TRACE: ' || dbms_utility.format_error_backtrace);
        
    END ABC19Section8Detail;
/


GRANT EXECUTE ON ABCREPORTS.ABC19SECTION8DETAIL TO ABCREPORTS_ROLE;
