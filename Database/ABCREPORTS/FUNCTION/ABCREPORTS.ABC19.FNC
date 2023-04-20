CREATE OR REPLACE FUNCTION ABCREPORTS.ABC19(p_parms      IN OUT t_parameters,
                                 p_status_ind IN OUT VARCHAR2) 
              RETURN BLOB IS 

-- ****************************************************************************
-- File:        abc19.fnc  
-- Author:      Timothy J. Lord
--
-- $Rev: 3920 $  
-- $Date: 2018-01-23 08:54:28 -0800 (Tue, 23 Jan 2018) $
-- Last Changed By:  $Author: tlord $
--
-- Description:    
--
-- 
-- History:
-------------------------------------------------------------------------------
--    Date                  Comment
-- 10/28/2015 TJL   8282    Updated for enhancement changes 
-- 12/09/2015 TJL   7739    Added type 84 filter 
-- 02/23/2016 TJL   9006    Corrected where clause in Section 16-19 for office
-- 03/14/2016 TJL   9207    Made sure that start date is always the first of the month
-- 07/26/2016 TJL   9837    Section 9 change complete count query to match select
--                          criteria of section 9 detail query.
-- 09/06/2016 TJL  10540    Corrected miss place closing parenthesis ")" in report 
--                          section "WithdrawnPerToPer" and corrected logging of
--                          the error message.
-- 09/27/2016 TJL   7213    Changed output from CLOB to BLOB  
-- 01/16/2018 TJL  14162    Added column for Notices of Violations
-- ****************************************************************************

--*****************************************************************************
--  Section 6
--*****************************************************************************                       
FUNCTION COURTESTYABC211(p_value         IN OUT XMLTYPE,
                         p_district_list IN     T_OFFICEOBJECT,
                         p_start_date    IN     DATE,
                         p_end_date      IN     DATE, 
                         p_status_msg    IN OUT VARCHAR2) RETURN BOOLEAN IS
 
    lb_proc         BOOLEAN := TRUE;
    xml_temp        XMLTYPE;
    cur_recs        SYS_REFCURSOR;

    BEGIN
        OPEN cur_recs FOR
                  'SELECT a.basefileofficename, COUNT(a.objectid) courtesycount
                    FROM mart.application a
                   WHERE a.intakeofficeid IN (SELECT officeobjectid FROM TABLE(:p_office))
                     AND TRUNC(a.enterapplicationcompleteddate, ''MONTH'') = TRUNC(:p_date, ''MONTH'')
                     AND a.abc19apptype = ''Courtesy''
                     AND a.haslicensetype79 = ''N''
                     AND a.haslicensetype84 = ''N''
                GROUP BY a.basefileofficename'
             USING p_district_list, p_start_date;
        xml_temp := rqs_utils.cursor_to_xml(p_cursor      => cur_recs,
                                            p_rowset_name => 'TEMP',
                                            p_row_name    => 'COURTESTYABC211',
                                            p_status_msg  => p_status_msg); 

        lb_proc := (p_status_msg IS NULL);

        IF (lb_proc) THEN
            -- added abc220 information to main report
            SELECT APPENDCHILDXML(p_value, '/ABC19',
                                 (SELECT EXTRACT(xml_temp, '/TEMP/COURTESTYABC211') 
                                    FROM DUAL))
              INTO p_value
              FROM DUAL;
        END IF;
        
        RETURN lb_proc;
    
    EXCEPTION
        WHEN OTHERS THEN
            p_status_msg := 'COURTESTYABC211(EXCEPTION): ' 
                  || dbms_utility.format_error_backtrace
                  || ' :: ' || SQLERRM;
            
            RETURN FALSE;
    END COURTESTYABC211;


--*****************************************************************************
--  Section 7
--*****************************************************************************                       
FUNCTION TAKENABC211(p_value         IN OUT XMLTYPE,
                         p_district_list IN     T_OFFICEOBJECT,
                         p_start_date    IN     DATE,
                         p_end_date      IN     DATE, 
                         p_status_msg    IN OUT VARCHAR2) RETURN BOOLEAN IS
 
    lb_proc         BOOLEAN := TRUE;
    xml_temp        XMLTYPE;
    cur_recs        SYS_REFCURSOR;

    BEGIN
        OPEN cur_recs FOR
                  'SELECT a.intakeoffice basefileoffice,
                         COUNT(a.objectid) courtesycount,
                         2 sortorder
                    FROM mart.application a
                   WHERE a.basefileofficeid IN (SELECT officeobjectid FROM TABLE( :a))
                     AND TRUNC(a.enterapplicationcompleteddate, ''MONTH'') = TRUNC( :b, ''MONTH'')
                     AND a.abc19apptype = ''Courtesy''
                     AND a.haslicensetype79 = ''N''
                     AND a.haslicensetype84 = ''N''
                     AND (a.abc19pertoper = ''Y''
                       OR a.abc19original = ''Y'')
                GROUP BY a.intakeoffice
                UNION
                  SELECT a.intakeoffice basefileoffice,
                         COUNT(a.objectid) courtesycount,
                         1 sortorder
                    FROM mart.application a
                   WHERE a.intakeofficeid IN (SELECT officeobjectid FROM TABLE( :a))
                     AND TRUNC(a.enterapplicationcompleteddate, ''MONTH'') = TRUNC( :b, ''MONTH'')
                     AND a.abc19apptype = ''Local''
                     AND a.haslicensetype79 = ''N''
                     AND a.haslicensetype84 = ''N''
                     AND (a.abc19pertoper = ''Y''
                       OR a.abc19original = ''Y'')
                GROUP BY a.intakeoffice
                ORDER BY sortorder'    
             USING p_district_list, p_start_date, p_district_list, p_start_date;
        xml_temp := rqs_utils.cursor_to_xml(p_cursor      => cur_recs,
                                            p_rowset_name => 'TEMP',
                                            p_row_name    => 'TAKENABC211',
                                            p_status_msg  => p_status_msg); 

        lb_proc := (p_status_msg IS NULL);

        IF (lb_proc) THEN
            -- added abc220 information to main report
            SELECT APPENDCHILDXML(p_value, '/ABC19',
                                 (SELECT EXTRACT(xml_temp, '/TEMP/TAKENABC211') 
                                    FROM DUAL))
              INTO p_value
              FROM DUAL;
        END IF;
        
        RETURN lb_proc;
    
    
    EXCEPTION
        WHEN OTHERS THEN
            p_status_msg := 'COURTESTYABC211(EXCEPTION): ' 
                  || dbms_utility.format_error_backtrace
                  || ' :: ' || SQLERRM;
            
            RETURN FALSE;
    END TAKENABC211;


--*****************************************************************************
--  Section 8
--*****************************************************************************                       
FUNCTION ABC220(p_value         IN OUT XMLTYPE,
                p_district_list IN     T_OFFICEOBJECT,
                p_start_date    IN     DATE,
                p_end_date      IN     DATE, 
                p_status_msg    IN OUT VARCHAR2) RETURN BOOLEAN IS

    rec             T_ABC220REC := T_ABC220REC();
    lb_proc         BOOLEAN := TRUE;
    xml_temp        XMLTYPE;
    cur_recs        SYS_REFCURSOR;
    tbl_220         T_ABC220TBL := T_ABC220TBL();
    
    BEGIN
        ------------------------------------------------------------------------------------------------
        -- PendBegOriginal 
        ------------------------------------------------------------------------------------------------       
        SELECT NVL(COUNT(a.ObjectId), 0) PendBegOriginal 
          INTO rec.PENDBEGORIGINAL
          FROM mart.application a
         WHERE basefileofficeid IN (SELECT officeobjectid FROM TABLE(p_district_list))
           AND (a.ABC19Original = 'Y' OR a.AddPrimaryLicenseType = 'Y')
           AND a.HasLicenseType79 = 'N'
           AND a.HasLicensetype84 = 'N'
           AND TRUNC(a.EnterApplicationCompletedDate) < TRUNC(p_start_date)
           AND EXISTS (SELECT 1
                        FROM extension.JobStatusChange j
                       WHERE j.JobId = a.ObjectId
                         AND j.StatusName in ('PEND','APPLD','ISSUPD')
                         AND (TRUNC(j.EffectiveStartDate) < TRUNC(p_start_date)
                              AND (j.EffectiveEndDate is null
                                   OR TRUNC(j.EffectiveEndDate) >= TRUNC(NVL(p_end_date, p_start_date))
                                  )
                             )
                     )
           AND (TRUNC(a.DistrictAppReviewProcDate) >= TRUNC(NVL(p_end_date, p_start_date))
               OR (TRUNC(a.DistrictAppReviewProcDate) IS NULL
                  AND EXISTS (SELECT 1
                                FROM extension.JobStatusChange j
                               WHERE j.JobId = a.ObjectId
                                 AND j.StatusName in ('PEND','APPLD','ISSUPD')
                                 AND (TRUNC(j.EffectiveStartDate) < TRUNC(p_start_date)
                                     AND (j.EffectiveEndDate IS NULL
                                         OR TRUNC(j.EffectiveEndDate) >= TRUNC(NVL(p_end_date, p_start_date))
                                         )
                                     )
                             )
                  AND NOT EXISTS (SELECT 1
                                    FROM extension.JobStatusChange j
                                   WHERE j.JobId = a.ObjectId
                                     AND j.StatusName in ('ISSUED', 'DENIED', 'WTHDRN', 'VOIDED')
                                     AND (TRUNC(j.EffectiveStartDate) < TRUNC(p_start_date)
                                         AND (j.EffectiveEndDate IS NULL
                                             OR TRUNC(j.EffectiveEndDate) >= TRUNC(NVL(p_end_date, p_start_date))
                                             )
                                         )
                                 )
                  )
               );
        
        -------------------------------------------------------------------------------------------------------------
        --  PendBegPerToPer
        -------------------------------------------------------------------------------------------------------------
        SELECT NVL(COUNT(a.ObjectId), 0) PendBegPerToPer 
          INTO rec.PENDBEGPERTOPER
          FROM mart.application a
         WHERE basefileofficeid IN (SELECT officeobjectid FROM TABLE(p_district_list))
           AND a.ABC19PerToPer = 'Y'
           AND a.HasLicenseType79 = 'N'
           AND a.HasLicensetype84 = 'N'
           AND TRUNC(a.EnterApplicationCompletedDate) < TRUNC(p_start_date)
           AND EXISTS (SELECT 1
                        FROM extension.JobStatusChange j
                       WHERE j.JobId = a.ObjectId
                         AND j.StatusName in ('PEND','APPLD','ISSUPD')
                         AND (TRUNC(j.EffectiveStartDate) < TRUNC(p_start_date)
                              AND (j.EffectiveEndDate is null
                                   OR TRUNC(j.EffectiveEndDate) >= TRUNC(NVL(p_end_date, p_start_date))
                                  )
                             )
                     )
           AND (TRUNC(a.DistrictAppReviewProcDate) >= TRUNC(NVL(p_end_date, p_start_date))
               OR (TRUNC(a.DistrictAppReviewProcDate) IS NULL
                  AND EXISTS (SELECT 1
                                FROM extension.JobStatusChange j
                               WHERE j.JobId = a.ObjectId
                                 AND j.StatusName in ('PEND','APPLD','ISSUPD')
                                 AND (TRUNC(j.EffectiveStartDate) < TRUNC(p_start_date)
                                     AND (j.EffectiveEndDate IS NULL
                                         OR TRUNC(j.EffectiveEndDate) >= TRUNC(NVL(p_end_date, p_start_date))
                                         )
                                     )
                             )
                  AND NOT EXISTS (SELECT 1
                                    FROM extension.JobStatusChange j
                                   WHERE j.JobId = a.ObjectId
                                     AND j.StatusName in ('ISSUED', 'DENIED', 'WTHDRN', 'VOIDED')
                                     AND (TRUNC(j.EffectiveStartDate) < TRUNC(p_start_date)
                                         AND (j.EffectiveEndDate IS NULL
                                             OR TRUNC(j.EffectiveEndDate) >= TRUNC(NVL(p_end_date, p_start_date))
                                             )
                                         )
                                 )
                  )
               )
           AND a.ABC19Original != 'Y';
        
        -------------------------------------------------------------------------------------------------------------
        -- ReceivedOriginal
        -------------------------------------------------------------------------------------------------------------
        SELECT NVL(COUNT(a.ObjectId), 0) ReceivedOriginal 
          INTO rec.receivedoriginal
          FROM mart.application a
         WHERE basefileofficeid IN (SELECT officeobjectid FROM TABLE(p_district_list))
           AND a.ABC19Original = 'Y'
           AND a.HasLicenseType79 = 'N'
           AND a.HasLicensetype84 = 'N'
           AND a.StatusName <> 'NEW'
           AND TRUNC(EnterApplicationCompletedDate, 'MONTH') = TRUNC(p_start_date, 'MONTH');

        -------------------------------------------------------------------------------------------------------------
        -- ReceivedPerToPer
        -------------------------------------------------------------------------------------------------------------
        SELECT NVL(COUNT(a.ObjectId), 0) ReceivedOriginal 
          INTO rec.receivedpertoper
          FROM mart.application a
         WHERE basefileofficeid IN (SELECT officeobjectid FROM TABLE(p_district_list))
           AND a.ABC19PerToPer = 'Y'
           AND a.HasLicenseType79 = 'N'
           AND a.HasLicensetype84 = 'N'
           AND a.StatusName <> 'NEW'
           AND TRUNC(EnterApplicationCompletedDate, 'MONTH') = TRUNC(p_start_date, 'MONTH')
           AND a.ABC19Original <> 'Y';

        -------------------------------------------------------------------------------------------------------------
        -- APPROVEDORIGINAL
        -------------------------------------------------------------------------------------------------------------
        SELECT COUNT(ObjectId)
          INTO rec.approvedoriginal
          FROM
             (SELECT d.ObjectId
              FROM mart.districtapplicationreview d
              JOIN mart.application a ON a.objectid = d.jobid
             WHERE d.districtofficeid IN (SELECT officeobjectid FROM TABLE(p_district_list))
               AND TRUNC(d.DateCompleted, 'MONTH') = TRUNC(p_start_date, 'MONTH')
               AND d.Outcome in ('224 Approval', 'Approve Application', 'Approve With Division Review')
               AND (a.ABC19Original = 'Y' or a.AddPrimaryLicenseType = 'Y')
               AND d.HasLicenseType79 = 'N'
               AND d.HasLicensetype84 = 'N'
               AND d.ObjectId IN (SELECT MIN(d1.ObjectId)
                                    FROM mart.districtapplicationreview d1
                                   WHERE d1.JobId = d.JobId
                                   GROUP BY d1.JobId)
            UNION
            SELECT p.ObjectId
              FROM mart.issuelicense p
              JOIN mart.application a ON a.objectid = p.jobid
             WHERE basefileofficeid IN (SELECT officeobjectid FROM TABLE(p_district_list))
               AND TRUNC(DateCompleted, 'MONTH') = TRUNC(p_start_date, 'MONTH')
               AND p.Outcome IS NOT NULL
               AND (a.ABC19Original = 'Y' or a.AddPrimaryLicenseType = 'Y')
               AND a.HasLicenseType79 = 'N'
               AND a.HasLicensetype84 = 'N'
               AND EXISTS (SELECT 1 
                             FROM extension.jobstatuschange_t j 
                            WHERE j.jobid = a.objectid
                              AND j.statusname = 'ISSUED'
                              AND TRUNC(j.effectivestartdate, 'MONTH') = TRUNC(p.DateCompleted, 'MONTH')
                          )
               AND p.ObjectId in (SELECT MIN(p2.ObjectId)
                                    FROM mart.issuelicense p2
                                   WHERE p2.JobId = a.objectid
                                   GROUP BY p2.JobId)
               AND NOT EXISTS (SELECT 1
                                 FROM mart.districtapplicationreview d
                                WHERE d.jobid = a.objectid
                                  AND d.outcome is not null));
       
        -------------------------------------------------------------------------------------------------------------
        -- ApprovedPerToPer
        -------------------------------------------------------------------------------------------------------------
        SELECT COUNT(ObjectId)
          INTO rec.ApprovedPerToPer
          FROM
               (SELECT d.ObjectId
                  FROM mart.districtapplicationreview d
                 WHERE d.districtofficeid IN (SELECT officeobjectid FROM TABLE(p_district_list))
                   AND TRUNC(d.DateCompleted, 'MONTH') = TRUNC(p_start_date, 'MONTH')
                   AND d.Outcome IN ('224 Approval', 'Approve Application', 'Approve With Division Review')
                   AND d.ABC19PerToPer = 'Y'
                   AND d.HasLicenseType79 = 'N'
                   AND d.HasLicensetype84 = 'N'
                   AND d.ABC19Original <> 'Y'
                   AND d.ObjectId IN (SELECT MIN(d1.ObjectId)
                                        FROM mart.districtapplicationreview d1
                                       WHERE d1.JobId = d.JobId
                                       GROUP BY d1.JobId)
               UNION
               SELECT p.ObjectId
                 FROM mart.issuelicense p
                 JOIN mart.application a ON a.objectid = p.jobid
                WHERE basefileofficeid IN (SELECT officeobjectid FROM TABLE(p_district_list))
                  AND TRUNC(p.DateCompleted, 'MONTH') = TRUNC(p_start_date, 'MONTH')
                  AND p.Outcome is not null
                  AND a.ABC19PerToPer = 'Y'
                  AND a.ABC19Original <> 'Y'
                  AND a.HasLicenseType79 = 'N'
                  AND a.HasLicensetype84 = 'N'
                  AND EXISTS (SELECT 1 
                                FROM extension.jobstatuschange_t j 
                               WHERE j.jobid = a.objectid
                                 AND j.statusname = 'ISSUED'
                                 AND TRUNC(j.effectivestartdate, 'MONTH') = TRUNC(p.DateCompleted, 'MONTH')
                             )
                  AND p.ObjectId IN (SELECT min(p2.ObjectId)
                                       FROM mart.issuelicense p2
                                      WHERE p2.JobId = a.objectid
                                      GROUP BY p2.JobId)
                  AND NOT EXISTS (SELECT 1
                                    FROM mart.districtapplicationreview d
                                   WHERE d.jobid = a.objectid
                                     AND d.outcome IS NOT NULL));
              
        -------------------------------------------------------------------------------------------------------------
        -- DeniedOriginal
        -------------------------------------------------------------------------------------------------------------
        SELECT COUNT(ObjectId)
          INTO rec.deniedoriginal
          FROM
            (SELECT d.ObjectId
               FROM mart.districtapplicationreview d
               JOIN mart.application a ON a.objectid = d.jobid
              WHERE d.districtofficeid IN (SELECT officeobjectid FROM TABLE(p_district_list))
                AND TRUNC(d.DateCompleted, 'MONTH') = TRUNC(p_start_date, 'MONTH')
                AND d.Outcome = 'Deny With Division Review'
                AND (a.ABC19Original = 'Y' OR a.AddPrimaryLicenseType = 'Y')
                AND d.HasLicenseType79 = 'N'
                AND d.HasLicensetype84 = 'N'
                AND d.ObjectId IN (SELECT MIN(d1.ObjectId)
                                     FROM mart.districtapplicationreview d1
                                    WHERE d1.JobId = d.JobId
                                    GROUP BY d1.JobId )
            UNION
            SELECT p.ObjectId
              FROM mart.RECORDDIRECTORDICISION p
              JOIN mart.application a ON a.objectid = p.jobid
             WHERE a.basefileofficeid IN (SELECT officeobjectid FROM TABLE(p_district_list))
               AND TRUNC(p.DateCompleted, 'MONTH') = TRUNC(p_start_date, 'MONTH')
               AND p.Outcome IS NOT NULL
               AND a.ABC19Original = 'Y'
               AND a.HasLicenseType79 = 'N'
               AND a.HasLicensetype84 = 'N'
               AND EXISTS (SELECT 1 
                             FROM extension.jobstatuschange_t j 
                            WHERE j.jobid = a.objectid
                              AND j.statusname = 'DENIED'
                              AND TRUNC(j.effectivestartdate, 'MONTH') = TRUNC(p.DateCompleted, 'MONTH')
                          )
               AND p.ObjectId IN (SELECT MIN(p2.ObjectId)
                                    FROM mart.RECORDDIRECTORDICISION p2
                                   WHERE p2.JobId = a.objectid
                                   GROUP BY p2.JobId)
               AND NOT EXISTS (SELECT 1
                                 FROM mart.districtapplicationreview d
                                WHERE d.jobid = a.objectid
                                  AND d.outcome IS NOT NULL));

        -------------------------------------------------------------------------------------------------------------
        -- DeniedPerToPer
        -------------------------------------------------------------------------------------------------------------
        SELECT COUNT(ObjectId)
          INTO rec.deniedpertoper
          FROM
            (SELECT d.ObjectId
               FROM mart.districtapplicationreview d
              WHERE d.districtofficeid IN (SELECT officeobjectid FROM TABLE(p_district_list))
                AND TRUNC(d.DateCompleted, 'MONTH') = TRUNC(p_start_date, 'MONTH')
                AND d.Outcome = 'Deny With Division Review'
                AND d.ABC19PerToPer = 'Y'
                AND d.HasLicenseType79 = 'N'
                AND d.HasLicensetype84 = 'N'
                AND d.ABC19Original <> 'Y'
                AND d.ObjectId IN (SELECT MIN(d1.ObjectId)
                                     FROM mart.districtapplicationreview d1
                                    WHERE d1.JobId = d.JobId
                                    GROUP BY d1.JobId)
            UNION
            SELECT p.ObjectId
              FROM mart.RECORDDIRECTORDICISION p
              JOIN mart.application a ON a.objectid = p.jobid
             WHERE a.basefileofficeid IN (SELECT officeobjectid FROM TABLE(p_district_list))
               AND TRUNC(p.DateCompleted, 'MONTH') = TRUNC(p_start_date, 'MONTH')
               AND p.Outcome is not null
               AND a.ABC19PerToPer = 'Y'
               AND a.ABC19Original <> 'Y' 
               AND a.HasLicenseType79 = 'N'
               AND a.HasLicensetype84 = 'N'
               AND EXISTS (SELECT 1 
                             FROM extension.jobstatuschange_t j 
                            WHERE j.jobid = a.objectid
                              AND j.statusname = 'DENIED'
                              AND TRUNC(j.effectivestartdate, 'MONTH') = TRUNC(p.DateCompleted, 'MONTH')
                          )
               AND p.ObjectId IN (SELECT MIN(p2.ObjectId)
                                    FROM mart.RECORDDIRECTORDICISION p2
                                   WHERE p2.JobId = a.objectid
                                   GROUP BY p2.JobId)
               AND NOT EXISTS (SELECT 1
                                 FROM mart.districtapplicationreview d
                                WHERE d.jobid = a.objectid
                                  AND d.outcome is not null));

        -------------------------------------------------------------------------------------------------------------
        -- WithdrawnOriginal
        -------------------------------------------------------------------------------------------------------------
        SELECT COUNT(ObjectId)
          INTO rec.withdrawnoriginal
          FROM
            (SELECT d.ObjectId
               FROM mart.districtapplicationreview d
               JOIN mart.application a on a.objectid = d.jobid
              WHERE d.districtofficeid IN (SELECT officeobjectid FROM TABLE(p_district_list))
                AND TRUNC(d.DateCompleted, 'MONTH') = TRUNC(p_start_date, 'MONTH')
                AND d.Outcome = 'Withdraw'
                AND a.enterapplicationcompleteddate IS NOT NULL 
                AND (a.ABC19Original = 'Y' OR a.AddPrimaryLicenseType = 'Y')
                AND d.HasLicenseType79 = 'N'
                AND d.HasLicensetype84 = 'N'
                AND d.ObjectId IN (SELECT MIN(d1.ObjectId)
                                     FROM mart.districtapplicationreview d1
                                    WHERE d1.JobId = d.JobId
                                    GROUP BY d1.JobId)
            UNION
            select p.ObjectId
              FROM mart.withdrawapplication p
              JOIN mart.application a on a.objectid = p.jobid
             WHERE a.basefileofficeid IN (SELECT officeobjectid FROM TABLE(p_district_list))
               AND TRUNC(p.DateCompleted, 'MONTH') = TRUNC(p_start_date, 'MONTH')
               AND p.Outcome is not null
               AND a.enterapplicationcompleteddate IS NOT NULl  
               AND a.ABC19Original = 'Y'
               AND a.HasLicenseType79 = 'N'
               AND a.HasLicensetype84 = 'N'
               AND EXISTS (SELECT 1 
                             FROM extension.jobstatuschange_t j 
                            WHERE j.jobid = a.objectid
                              AND j.statusname = 'WTHDRN'
                              AND TRUNC(j.EffectiveStartDate, 'MONTH') = TRUNC(p.DateCompleted, 'MONTH')
                          )
               AND p.ObjectId IN (SELECT MIN(p2.ObjectId)
                                    FROM mart.withdrawapplication p2
                                    WHERE p2.JobId = a.objectId
                                    GROUP BY p2.JobId)
               AND NOT EXISTS (SELECT 1
                                 FROM mart.districtapplicationreview d
                                WHERE d.jobid = a.objectid
                                  AND d.outcome IS NOT NULl));

        -------------------------------------------------------------------------------------------------------------
        -- WithdrawnPerToPer
        -------------------------------------------------------------------------------------------------------------
        SELECT COUNT(ObjectId)
          INTO rec.WithdrawnPerToPer
          FROM
            (SELECT d.ObjectId
               FROM mart.districtapplicationreview d
               JOIN mart.application a ON a.objectid = d.jobid
              WHERE d.districtofficeid IN (SELECT officeobjectid FROM TABLE(p_district_list))
                AND TRUNC(d.DateCompleted, 'MONTH') = TRUNC(p_start_date, 'MONTH')
                AND d.Outcome = 'Withdraw'
                AND a.enterapplicationcompleteddate IS NOT NULL
                AND d.ABC19PerToPer = 'Y'
                AND d.HasLicenseType79 = 'N'
                AND d.HasLicensetype84 = 'N'
                AND d.ABC19Original <> 'Y'
                AND d.ObjectId in (SELECT MIN(d1.ObjectId)
                                     FROM mart.districtapplicationreview d1
                                    WHERE d1.JobId = d.JobId
                                    GROUP BY d1.JobId)
            UNION      
            SELECT p.ObjectId
              FROM mart.withdrawapplication p
              JOIN mart.application a on a.objectid = p.jobid
             WHERE a.basefileofficeid IN (SELECT officeobjectid FROM TABLE(p_district_list))
               AND TRUNC(p.DateCompleted, 'MONTH') = TRUNC(p_start_date, 'MONTH')
               AND p.Outcome is not null
               AND a.enterapplicationcompleteddate  is not null     ----added by Pawan 5/16/2013
               AND a.ABC19PerToPer = 'Y'
               AND a.ABC19Original <> 'Y'
               AND a.HasLicenseType79 = 'N'
               AND a.HasLicensetype84 = 'N'
               AND EXISTS (SELECT 1 
                             FROM extension.jobstatuschange_t j 
                            WHERE j.jobid = a.objectid
                              AND j.statusname = 'WTHDRN'
                              AND TRUNC(j.EffectiveStartDate, 'MONTH') = TRUNC(p.DateCompleted, 'MONTH')
                          )
               AND p.ObjectId IN (SELECT MIN(p2.ObjectId)
                                    FROM mart.withdrawapplication p2
                                   WHERE p2.JobId = a.objectId
                                   GROUP BY p2.JobId)
               AND NOT EXISTS (SELECT 1
                                 FROM MART.DISTRICTAPPLICATIONREVIEW D
                                WHERE D.JOBID = A.OBJECTID
                                  AND d.outcome IS NOT NULL));

        -------------------------------------------------------------------------------------------------------------
        -- VoidedOriginal
        -------------------------------------------------------------------------------------------------------------
        SELECT COUNT(a.ObjectId)
          INTO rec.voidedoriginal
          FROM mart.application a
         WHERE basefileofficeid IN (SELECT officeobjectid FROM TABLE(p_district_list))
           AND (a.ABC19Original = 'Y' OR a.AddPrimaryLicenseType = 'Y')
           AND a.HasLicenseType79 = 'N'
           AND a.HasLicensetype84 = 'N'
           AND EXISTS (SELECT 1
                         FROM extension.JobStatusChange j
                        WHERE j.JobId = a.ObjectId
                          AND j.StatusName = 'VOIDED'
                          AND TRUNC(j.EffectiveStartDate, 'MONTH') = TRUNC(p_start_date, 'MONTH')
                          AND (SELECT js2.statusname
                                 FROM extension.jobstatuschange js2
                                WHERE js2.jobstatuschangeid = (SELECT MAX(js.jobstatuschangeid) -- Gets the previous status
                                                                 FROM extension.jobstatuschange js
                                                                WHERE js.jobid = a.objectid
                                                                  AND js.jobstatuschangeid < j.jobstatuschangeid)
                              ) <> 'NEW');

        -------------------------------------------------------------------------------------------------------------
        -- VoidedPerToPer
        -------------------------------------------------------------------------------------------------------------
        SELECT COUNT(a.ObjectId)
          INTO rec.voidedpertoper
          FROM mart.application a
         WHERE basefileofficeid IN (SELECT officeobjectid FROM TABLE(p_district_list))
           AND a.ABC19PerToPer = 'Y'
           AND a.ABC19Original <> 'Y'
           AND a.HasLicenseType79 = 'N'
           AND a.HasLicensetype84 = 'N'
           AND EXISTS (SELECT 1
                         FROM extension.JobStatusChange j
                        WHERE j.JobId = a.ObjectId
                          AND j.StatusName = 'VOIDED'
                          AND TRUNC(j.EffectiveStartDate, 'MONTH') = TRUNC(p_start_date, 'MONTH')
                          AND (SELECT js2.statusname
                                 FROM extension.jobstatuschange js2
                                WHERE js2.jobstatuschangeid = (SELECT MAX(js.jobstatuschangeid) -- Gets the previous status
                                                                 FROM extension.jobstatuschange js
                                                                WHERE js.jobid = a.objectid
                                                                  AND js.jobstatuschangeid < j.jobstatuschangeid)
                              ) <> 'NEW');

--------------------------------------------------------------------------------------------------------------------
-- abc-61 licenses
--------------------------------------------------------------------------------------------------------------------
        -------------------------------------------------------------------------------------------------------------
        -- PendingBeginning
        -------------------------------------------------------------------------------------------------------------
        SELECT COUNT(a.objectid)
          INTO rec.pendingbeginning
          FROM mart.assignassignment a
               LEFT JOIN mart.closelicensingassignment c
                   ON c.externalfilenum = a.externalfilenum
         WHERE a.districtofficeidcorral IN (SELECT officeobjectid FROM TABLE(p_district_list))
           AND NVL(a.droppartner, 'N') = 'N'
           AND NVL(a.haslicensetype79, 'N') = 'N'
           AND NVL(a.HasLicensetype84, 'N') = 'N'
           AND TRUNC(a.createddate) < TRUNC(p_start_date)
           AND TRUNC(a.createddate) > TO_DATE('06/24/2010', 'MM/DD/YYYY')
           AND (TRUNC(a.datecompleted) >= TRUNC(p_start_date)
            OR a.datecompleted IS NULL
            OR c.datecompleted IS NULL
            OR TRUNC(c.datecompleted) >= TRUNC(p_start_date));

        -------------------------------------------------------------------------------------------------------------
        -- Received
        -------------------------------------------------------------------------------------------------------------
        SELECT COUNT(a.objectid)
          INTO rec.received
          FROM mart.assignassignment a
         WHERE a.districtofficeidcorral IN (SELECT officeobjectid FROM TABLE(p_district_list))
           AND NVL(a.droppartner, 'N') = 'N'
           AND NVL(a.haslicensetype79, 'N') = 'N'
           AND NVL(a.HasLicensetype84, 'N') = 'N'
           AND TRUNC(a.createddate, 'MONTH') = TRUNC(p_start_date, 'MONTH');

        -------------------------------------------------------------------------------------------------------------
        -- Completed
        -------------------------------------------------------------------------------------------------------------
        SELECT COUNT(a.objectid)
          INTO rec.completed
          FROM mart.closelicensingassignment a
          JOIN mart.assignassignment c ON a.externalfilenum =  c.externalfilenum
         WHERE a.districtofficeidcorral IN (SELECT officeobjectid FROM TABLE(p_district_list))
           AND NVL(a.droppartner, 'N') = 'N'
           AND NVL(a.haslicensetype79, 'N') = 'N'
           AND NVL(a.HasLicensetype84, 'N') = 'N'
           AND TRUNC(a.datecompleted, 'MONTH') = TRUNC(p_start_date, 'MONTH');

---------------------------------------------------------------------------------------------------------------------
        
        IF (lb_proc) THEN  
        
            rec.COMPLETEDORIGINAL := NVL(rec.APPROVEDORIGINAL, 0)
                                   + NVL(rec.DENIEDORIGINAL, 0) 
                                   + NVL(rec.WITHDRAWNORIGINAL, 0);
            rec.COMPLETEDPERTOPER := NVL(rec.APPROVEDPERTOPER, 0) 
                                   + NVL(rec.DENIEDPERTOPER, 0) 
                                   + NVL(rec.WITHDRAWNPERTOPER, 0);
            rec.PENDENDORIGINAL   := NVL(rec.PENDBEGORIGINAL, 0) 
                                   + NVL(rec.RECEIVEDORIGINAL, 0) 
                                   - NVL(rec.COMPLETEDORIGINAL, 0) 
                                   - NVL(rec.VOIDEDORIGINAL, 0);
            rec.PENDENDPERTOPER   := NVL(rec.PENDBEGPERTOPER, 0) 
                                   + NVL(rec.RECEIVEDPERTOPER, 0) 
                                   - NVL(rec.COMPLETEDPERTOPER, 0) 
                                   - NVL(rec.VOIDEDPERTOPER, 0);
           
            -- sum totals from queries
            rec.PENDBEGTTL   := NVL(rec.PENDBEGORIGINAL, 0) + NVL(rec.PENDBEGPERTOPER, 0);       
            rec.RECEIVEDTTL  := NVL(rec.RECEIVEDORIGINAL, 0) + NVL(rec.RECEIVEDPERTOPER, 0);       
            rec.COMPLETEDTTL := NVL(rec.COMPLETEDORIGINAL, 0) + NVL(rec.COMPLETEDPERTOPER, 0);       
            rec.APPROVEDTTL  := NVL(rec.APPROVEDORIGINAL, 0) + NVL(rec.APPROVEDPERTOPER, 0);       
            rec.DENIEDTTL    := NVL(rec.DENIEDORIGINAL, 0) + NVL(rec.DENIEDPERTOPER, 0);       
            rec.WITHDRAWNTTL := NVL(rec.WITHDRAWNORIGINAL, 0) + NVL(rec.WITHDRAWNPERTOPER, 0);       
            rec.VOIDEDTTL    := NVL(rec.VOIDEDORIGINAL, 0) + NVL(rec.VOIDEDPERTOPER, 0);       
            rec.PENDENDTTL   := NVL(rec.PENDENDORIGINAL, 0) + NVL(rec.PENDENDPERTOPER, 0);
            
            rec.ABC61TTL     := NVL(rec.PENDINGBEGINNING, 0) + NVL(rec.RECEIVED, 0) - NVL(rec.COMPLETED, 0);  
       
        END IF;
        
        IF (lb_proc) THEN
            -- update xml with counts
            tbl_220.extend(1);
            tbl_220(1) := rec;
            OPEN cur_recs FOR SELECT * FROM TABLE(tbl_220);
            
            xml_temp := rqs_utils.cursor_to_xml(p_cursor      => cur_recs,
                                                p_rowset_name => 'TEMP',
                                                p_row_name    => 'ABC220',
                                                p_status_msg  => p_status_msg); 

            lb_proc := (p_status_msg IS NULL);
        END IF;

        IF (lb_proc) THEN
            -- added abc220 information to main report
            SELECT APPENDCHILDXML(p_value, '/ABC19',
                                 (SELECT EXTRACT(xml_temp, '/TEMP/ABC220') 
                                    FROM DUAL))
              INTO p_value
              FROM DUAL;
        END IF;
        
        RETURN lb_proc;
 
    EXCEPTION
        WHEN OTHERS THEN
            p_status_msg := 'ABC220(EXCEPTION): ' 
                  || dbms_utility.format_error_backtrace
                  || ' :: ' || SQLERRM;
            
            RETURN FALSE;
    END ABC220;    
     

 

--*****************************************************************************
--  Section 10
--*****************************************************************************                       
FUNCTION COUNTABC211(p_value         IN OUT XMLTYPE,
                         p_district_list IN     T_OFFICEOBJECT,
                         p_start_date    IN     DATE,
                         p_end_date      IN     DATE, 
                         p_status_msg    IN OUT VARCHAR2) RETURN BOOLEAN IS
 
    lb_proc         BOOLEAN := TRUE;
    xml_temp        XMLTYPE;
    ln_             NUMBER;
    
    BEGIN
        SELECT COUNT(*)
          INTO ln_
          FROM (SELECT a.objectid
                  FROM mart.application a
                 WHERE a.abc19apptype = 'Courtesy'
                   AND a.intakeofficeid IN (SELECT officeobjectid FROM TABLE( p_district_list))
                   AND TRUNC(a.enterapplicationcompleteddate, 'MONTH') =
                           TRUNC(p_start_date, 'MONTH')
                   AND a.haslicensetype79 = 'N'
                   AND a.haslicensetype84 = 'N'
                UNION
                SELECT objectid
                  FROM mart.application a
                 WHERE a.abc19apptype = 'Local'
                   AND a.intakeofficeid IN (SELECT officeobjectid FROM TABLE( p_district_list))
                   AND TRUNC(a.enterapplicationcompleteddate, 'MONTH') =
                           TRUNC(p_start_date, 'MONTH')
                   AND a.haslicensetype79 = 'N'
                   AND a.haslicensetype84 = 'N');
           
        SELECT APPENDCHILDXML(p_value, '/ABC19', 
                              XMLTYPE('<COUNTABC211>' 
                                || TO_CHAR(ln_) 
                                || '</COUNTABC211>'))
          INTO p_value
          FROM DUAL;

        RETURN lb_proc;
    
    EXCEPTION
        WHEN OTHERS THEN
            p_status_msg := 'COUNTABC211(EXCEPTION): ' 
                  || dbms_utility.format_error_backtrace
                  || ' :: ' || SQLERRM;
            
            RETURN FALSE;
    END COUNTABC211;


--*****************************************************************************
--  Section 12
--*****************************************************************************                       
FUNCTION ASSIGNMENTS_ABC61(p_value         IN OUT XMLTYPE,
                           p_district_list IN     T_OFFICEOBJECT,
                           p_start_date    IN     DATE,
                           p_status_msg    IN OUT VARCHAR2) RETURN BOOLEAN IS

    rec             T_ABC61REC := T_ABC61REC();
    lb_proc         BOOLEAN := TRUE;
    xml_temp        XMLTYPE;
    cur_recs        SYS_REFCURSOR;
    tbl_61          T_ABC61TBL := T_ABC61TBL();
    
    BEGIN
        ------------------------------------------------------------------------------------------------
        -- PendBegCOMPLAINT 
        ------------------------------------------------------------------------------------------------       
        SELECT NVL(COUNT(i.objectid), 0)
          INTO rec.pendbegcomplaint
          FROM mart.investigation i
         WHERE i.investigationtype = 'COMPLAINT'
           AND TRUNC(i.createddate) < TRUNC(p_start_date)
           AND (i.completeddate IS NULL
                OR (SELECT TRUNC(t.effectivestartdate)
                      FROM extension.jobstatuschange_t t
                     WHERE t.jobid = i.objectid
                       AND t.statusname = 'CLOSED'
                       AND t.jobstatuschangeid = (SELECT MIN(t.jobstatuschangeid)
                                                    FROM extension.jobstatuschange_t t
                                                   WHERE t.jobid = i.objectid
                                                     AND t.statusname = 'CLOSED'
                                                 )
                   ) >= TRUNC(p_start_date, 'MONTH')
               )
           AND api.pkg_columnquery.VALUE(i.objectid, 'StatusName') <> 'CANCEL'
           AND i.investigationofficeobjectid IN (SELECT officeobjectid FROM TABLE(p_district_list));  
                                                    
        ------------------------------------------------------------------------------------------------
        --  PENDBEGADMINISTRATION
        ------------------------------------------------------------------------------------------------       
        SELECT NVL(COUNT(i.objectid), 0)
          INTO rec.pendbegadministration
          FROM mart.investigation i
         WHERE i.investigationtype = 'ADMINISTRATIVE'
           AND TRUNC(i.createddate) < TRUNC(p_start_date)
           AND (i.completeddate IS NULL
                OR (SELECT TRUNC(t.effectivestartdate)
                      FROM extension.jobstatuschange_t t
                     WHERE t.jobid = i.objectid
                       AND t.statusname = 'CLOSED'
                       AND t.jobstatuschangeid = (SELECT MIN(t.jobstatuschangeid)
                                                    FROM extension.jobstatuschange_t t
                                                   WHERE t.jobid = i.objectid
                                                     AND t.statusname = 'CLOSED'
                                                 )
                   ) >= TRUNC(p_start_date, 'MONTH')
               )
           AND api.pkg_columnquery.VALUE(i.objectid, 'StatusName') <> 'CANCEL'
           AND i.investigationofficeobjectid IN (SELECT officeobjectid FROM TABLE(p_district_list));

        ------------------------------------------------------------------------------------------------
        -- PENDBEGPOLICEREPORT
        ------------------------------------------------------------------------------------------------
        SELECT NVL(COUNT(i.objectid), 0)
          INTO rec.pendbegpolicereport
          FROM mart.investigation i
         WHERE i.investigationtype = 'POLICE REPORT'
           AND TRUNC(i.createddate) < TRUNC(p_start_date)
           AND (i.completeddate IS NULL
                OR (SELECT TRUNC(t.effectivestartdate)
                      FROM extension.jobstatuschange_t t
                     WHERE t.jobid = i.objectid
                       AND t.statusname = 'CLOSED'
                       AND t.jobstatuschangeid = (SELECT MIN(t.jobstatuschangeid)
                                                    FROM extension.jobstatuschange_t t
                                                   WHERE t.jobid = i.objectid
                                                     AND t.statusname = 'CLOSED'
                                                 )
                   ) >= TRUNC(p_start_date, 'MONTH')
               )
           AND api.pkg_columnquery.VALUE(i.objectid, 'StatusName') <> 'CANCEL'
           AND i.investigationofficeobjectid IN (SELECT officeobjectid FROM TABLE(p_district_list));

        ------------------------------------------------------------------------------------------------
        -- PENDBEGTRACE
        ------------------------------------------------------------------------------------------------
        SELECT NVL(COUNT(i.objectid), 0)
          INTO rec.pendbegtrace
          FROM mart.investigation i
         WHERE i.investigationtype = 'TRACE'
           AND TRUNC(i.createddate) < TRUNC(p_start_date)
           AND (i.completeddate IS NULL
                OR (SELECT TRUNC(t.effectivestartdate)
                      FROM extension.jobstatuschange_t t
                     WHERE t.jobid = i.objectid
                       AND t.statusname = 'CLOSED'
                       AND t.jobstatuschangeid = (SELECT MIN(t.jobstatuschangeid)
                                                    FROM extension.jobstatuschange_t t
                                                   WHERE t.jobid = i.objectid
                                                     AND t.statusname = 'CLOSED'
                                                 )
                   ) >= TRUNC(p_start_date, 'MONTH')
               )
           AND api.pkg_columnquery.VALUE(i.objectid, 'StatusName') <> 'CANCEL'
           AND i.investigationofficeobjectid IN (SELECT officeobjectid FROM TABLE(p_district_list));


        ------------------------------------------------------------------------------------------------
        -- ReceivedCOMPLAINT
        ------------------------------------------------------------------------------------------------
        SELECT NVL(COUNT(i.objectid), 0)
          INTO rec.receivedcomplaint
          FROM mart.investigation i
         WHERE i.investigationtype = 'COMPLAINT'
           AND TRUNC(i.createddate, 'MONTH') = TRUNC(p_start_date, 'MONTH')
           AND api.pkg_columnquery.VALUE(i.objectid, 'StatusName') <> 'CANCEL'
           AND i.investigationofficeobjectid IN (SELECT officeobjectid FROM TABLE(p_district_list));


        ------------------------------------------------------------------------------------------------
        -- RECEIVEDADMINISTRATION
        ------------------------------------------------------------------------------------------------
        SELECT NVL(COUNT(i.objectid), 0)
          INTO rec.receivedadministration
          FROM mart.investigation i
         WHERE i.investigationtype = 'ADMINISTRATIVE'
           AND TRUNC(i.createddate, 'MONTH') = TRUNC(p_start_date, 'MONTH')
           AND api.pkg_columnquery.VALUE(i.objectid, 'StatusName') <> 'CANCEL'
           AND i.investigationofficeobjectid IN (SELECT officeobjectid FROM TABLE(p_district_list));

        ------------------------------------------------------------------------------------------------
        -- RECEIVEDPOLICEREPORT
        ------------------------------------------------------------------------------------------------
        SELECT NVL(COUNT(i.objectid), 0)
          INTO rec.receivedpolicereport
          FROM mart.investigation i
         WHERE i.investigationtype = 'POLICE REPORT'
           AND TRUNC(i.createddate, 'MONTH') = TRUNC(p_start_date, 'MONTH')
           AND api.pkg_columnquery.VALUE(i.objectid, 'StatusName') <> 'CANCEL'
           AND i.investigationofficeobjectid IN (SELECT officeobjectid FROM TABLE(p_district_list));

        ------------------------------------------------------------------------------------------------
        -- RECEIVEDTRACE
        ------------------------------------------------------------------------------------------------
        SELECT NVL(COUNT(i.objectid), 0)
          INTO rec.receivedtrace
          FROM mart.investigation i
         WHERE i.investigationtype = 'TRACE'
           AND TRUNC(i.createddate, 'MONTH') = TRUNC(p_start_date, 'MONTH')
           AND api.pkg_columnquery.VALUE(i.objectid, 'StatusName') <> 'CANCEL'
           AND i.investigationofficeobjectid IN (SELECT officeobjectid FROM TABLE(p_district_list));

        ------------------------------------------------------------------------------------------------
        -- COMPLETEDCOMPLAINT
        ------------------------------------------------------------------------------------------------
        SELECT NVL(COUNT(i.objectid), 0)
          INTO rec.completedcomplaint
          FROM mart.investigation i
         WHERE i.investigationtype = 'COMPLAINT'
           AND (SELECT TRUNC(t.effectivestartdate, 'MONTH')
                  FROM extension.jobstatuschange_t t
                 WHERE t.jobid = i.objectid
                   AND t.statusname = 'CLOSED'
                   AND t.jobstatuschangeid = (SELECT MIN(t.jobstatuschangeid)
                                                FROM extension.jobstatuschange_t t
                                               WHERE t.jobid = i.objectid
                                                 AND t.statusname = 'CLOSED'
                                             )
               ) = TRUNC(p_start_date, 'MONTH')
           AND api.pkg_columnquery.VALUE(i.objectid, 'StatusName') <> 'CANCEL'
           AND i.investigationofficeobjectid IN (SELECT officeobjectid FROM TABLE(p_district_list));

        ------------------------------------------------------------------------------------------------
        -- COMPLETEDADMINISTRATION
        ------------------------------------------------------------------------------------------------
        SELECT NVL(COUNT(i.objectid), 0)
          INTO rec.completedadministration
          FROM mart.investigation i
         WHERE i.investigationtype = 'ADMINISTRATIVE'
           AND (SELECT TRUNC(t.effectivestartdate, 'MONTH')
                  FROM extension.jobstatuschange_t t
                 WHERE t.jobid = i.objectid
                   AND t.statusname = 'CLOSED'
                   AND t.jobstatuschangeid = (SELECT MIN(t.jobstatuschangeid)
                                                FROM extension.jobstatuschange_t t
                                               WHERE t.jobid = i.objectid
                                                 AND t.statusname = 'CLOSED'
                                             )
               ) = TRUNC(p_start_date, 'MONTH')
           AND api.pkg_columnquery.VALUE(i.objectid, 'StatusName') <> 'CANCEL'
           AND i.investigationofficeobjectid IN (SELECT officeobjectid FROM TABLE(p_district_list));

        ------------------------------------------------------------------------------------------------
        -- COMPLETEDPOLICEREPORT
        ------------------------------------------------------------------------------------------------
        SELECT NVL(COUNT(i.objectid), 0)
          INTO rec.completedpolicereport
          FROM mart.investigation i
         WHERE i.investigationtype = 'POLICE REPORT'
           AND (SELECT TRUNC(t.effectivestartdate, 'MONTH')
                  FROM extension.jobstatuschange_t t
                 WHERE t.jobid = i.objectid
                   AND t.statusname = 'CLOSED'
                   AND t.jobstatuschangeid = (SELECT MIN(t.jobstatuschangeid)
                                                FROM extension.jobstatuschange_t t
                                               WHERE t.jobid = i.objectid
                                                 AND t.statusname = 'CLOSED'
                                             )
               ) = TRUNC(p_start_date, 'MONTH')
           AND api.pkg_columnquery.VALUE(i.objectid, 'StatusName') <> 'CANCEL'
           AND i.investigationofficeobjectid IN (SELECT officeobjectid FROM TABLE(p_district_list));

        ------------------------------------------------------------------------------------------------
        -- COMPLETEDTRACE
        ------------------------------------------------------------------------------------------------
        SELECT NVL(COUNT(i.objectid), 0)
          INTO rec.completedtrace
          FROM mart.investigation i
         WHERE i.investigationtype = 'TRACE'
           AND (SELECT TRUNC(t.effectivestartdate, 'MONTH')
                  FROM extension.jobstatuschange_t t
                 WHERE t.jobid = i.objectid
                   AND t.statusname = 'CLOSED'
                   AND t.jobstatuschangeid = (SELECT MIN(t.jobstatuschangeid)
                                                FROM extension.jobstatuschange_t t
                                               WHERE t.jobid = i.objectid
                                                 AND t.statusname = 'CLOSED'
                                             )
               ) = TRUNC(p_start_date, 'MONTH')
           AND api.pkg_columnquery.VALUE(i.objectid, 'StatusName') <> 'CANCEL'
           AND i.investigationofficeobjectid IN (SELECT officeobjectid FROM TABLE(p_district_list));

        -- sum total records
        rec.PENDENDCOMPLAINT      := rec.PENDBEGCOMPLAINT 
                                   + rec.RECEIVEDCOMPLAINT 
                                   - rec.COMPLETEDCOMPLAINT;
        rec.PENDENDADMINISTRATION := rec.PENDBEGADMINISTRATION 
                                   + rec.RECEIVEDADMINISTRATION 
                                   - rec.COMPLETEDADMINISTRATION;
        rec.PENDENDPOLICEREPORT   := rec.PENDBEGPOLICEREPORT 
                                   + rec.RECEIVEDPOLICEREPORT 
                                   - rec.COMPLETEDPOLICEREPORT;
        rec.PENDENDTRACE          := rec.PENDBEGTRACE 
                                   + rec.RECEIVEDTRACE 
                                   - rec.COMPLETEDTRACE;


        ------------------------------------------------------------------------------------------------
        -- Section 13 
        ------------------------------------------------------------------------------------------------
        ------------------------------------------------------------------------------------------------
        -- MINORABC
        ------------------------------------------------------------------------------------------------
        SELECT COUNT(ac.objectid)
          INTO rec.minorabc
          FROM mart.arrestcitations ac
         WHERE ac.minors = 'Y'
           AND ac.casetype = 'ABC'
           AND TRUNC(ac.arrestdate, 'MONTH') = TRUNC(p_start_date, 'MONTH')
           AND ac.investigationofficeobjectid IN (SELECT officeobjectid FROM TABLE(p_district_list));

        ------------------------------------------------------------------------------------------------
        -- OtherABC
        ------------------------------------------------------------------------------------------------
        SELECT COUNT(ac.objectid)
          INTO rec.otherabc
          FROM mart.arrestcitations ac
         WHERE ac.minors = 'N'
           AND ac.casetype = 'ABC'
           AND TRUNC(ac.arrestdate, 'MONTH') = TRUNC(p_start_date, 'MONTH')
           AND ac.investigationofficeobjectid IN (SELECT officeobjectid FROM TABLE(p_district_list));

         ------------------------------------------------------------------------------------------------
        -- MINORJOINT
        ------------------------------------------------------------------------------------------------
        SELECT COUNT(ac.objectid)
          INTO rec.minorjoint
          FROM mart.arrestcitations ac
         WHERE ac.minors = 'Y'
           AND ac.casetype NOT IN ('ABC', 'Backtrack')
           AND TRUNC(ac.arrestdate, 'MONTH') = TRUNC(p_start_date, 'MONTH')
           AND ac.investigationofficeobjectid IN (SELECT officeobjectid FROM TABLE(p_district_list));

        ------------------------------------------------------------------------------------------------
        -- OTHERJOINT
        ------------------------------------------------------------------------------------------------
        SELECT COUNT(ac.objectid)
          INTO rec.otherjoint
          FROM mart.arrestcitations ac
         WHERE ac.minors = 'N'
           AND ac.casetype NOT IN ('ABC', 'Backtrack')
           AND TRUNC(ac.arrestdate, 'MONTH') = TRUNC(p_start_date, 'MONTH')
           AND ac.investigationofficeobjectid IN (SELECT officeobjectid FROM TABLE(p_district_list));
           
        -- sum records
        rec.TOTALABC   := rec.MINORABC + rec.OTHERABC;
        rec.TOTALJOINT := rec.MINORJOINT + rec.OTHERJOINT;
        

        IF (lb_proc) THEN
            -- update xml with counts
            tbl_61.extend(1);
            tbl_61(1) := rec;
            OPEN cur_recs FOR SELECT * FROM TABLE(tbl_61);
            
            xml_temp := rqs_utils.cursor_to_xml(p_cursor      => cur_recs,
                                                p_rowset_name => 'TEMP',
                                                p_row_name    => 'ABC61',
                                                p_status_msg  => p_status_msg); 

            lb_proc := (p_status_msg IS NULL);
        END IF;


        SELECT APPENDCHILDXML(p_value, '/ABC19', 
                              (SELECT EXTRACT(xml_temp, '/TEMP/ABC61') 
                                 FROM DUAL)
                             )
          INTO p_value
          FROM DUAL;

        RETURN lb_proc;
    
    EXCEPTION
        WHEN OTHERS THEN
            p_status_msg := 'ASSIGNMENTS_ABC61(EXCEPTION): ' 
                  || dbms_utility.format_error_backtrace
                  || ' :: ' || SQLERRM;
            
            RETURN FALSE;
    END ASSIGNMENTS_ABC61;    
     

--*****************************************************************************
--      Sections 16,17,18, and 19
--*****************************************************************************
FUNCTION SECTIONS16TO19(p_value         IN OUT XMLTYPE,
                        p_district_list IN     T_OFFICEOBJECT,
                        p_start_date    IN     DATE,
                        p_program_type  IN     VARCHAR2,
                        p_row_set       IN     VARCHAR2,
                        p_status_msg    IN OUT VARCHAR2) RETURN BOOLEAN IS

    xml_temp        XMLTYPE;
    cur_recs        SYS_REFCURSOR;
    lb_proc         BOOLEAN := TRUE;

    BEGIN
        OPEN cur_recs FOR 
                SELECT d.operationdate operationdate,
                       d.agencydistrictofficeeventname agencydistrictofficeeventname,
                       d.numberofpremisescontacted numberofpremisescontacted,
                       d.numberofviolations numberofviolations,
                       d.numberofpersonscontacted,      
                       d.totalstaffhours totalstaffhours,
                       d.numberofarrests numberofarrests
                  FROM mart.abc19programdetail d
                 WHERE d.year = TO_NUMBER(TO_CHAR(p_start_date, 'YYYY'))
                   AND d.monthnumber = TO_NUMBER(TO_CHAR(p_start_date, 'MM'))
                   AND d.programtype = p_program_type
                   AND substr(d.districtoffice ,1,(instr(d.districtoffice,' ')-1)) IN (SELECT o.officecode
                                                            FROM TABLE(p_district_list) l
                                                            JOIN query.o_office o
                                                              ON (l.officeobjectid = o.objectid))
                 ORDER BY d.operationdate;
          
                        
        xml_temp := rqs_utils.cursor_to_xml(p_cursor      => cur_recs,
                                            p_rowset_name => 'TEMP',
                                            p_row_name    => p_row_set,
                                            p_status_msg  => p_status_msg); 

        lb_proc := (p_status_msg IS NULL);

        SELECT APPENDCHILDXML(p_value, '/ABC19', 
                              (SELECT EXTRACT(xml_temp, '/TEMP/' || p_row_set) 
                                 FROM DUAL)
                             )
          INTO p_value
          FROM DUAL;

        return lb_proc;

    EXCEPTION
        WHEN OTHERS THEN
            p_status_msg := 'SECTIONS16TO19(EXCEPTION): ' 
                  || dbms_utility.format_error_backtrace
                  || ' :: ' || SQLERRM;
            
            RETURN FALSE;
    END SECTIONS16TO19;
    
--*****************************************************************************
--      ABC19 (Main Process)
--*****************************************************************************
    BEGIN
        DECLARE
            ln_return_code                   NUMBER;
            lv_status_msg                    VARCHAR2(4000);
            lb_proc                          BOOLEAN := TRUE;
            office_id                        T_OFFICEOBJECT;
            ld_start_date                    DATE;
            ld_end_date                      DATE;
            ln_premisesvisitedlicensing      NUMBER;    
            ln_premisesvisitedenforcement    NUMBER;
            ln_appointmentwaittimeindays     NUMBER;
            ln_numberofmailinsawaitingin     NUMBER;
            ln_policereportsreceived         NUMBER; 
            ln_warningletterssent            NUMBER;
            ln_noticeofviolations            NUMBER;
            xml_value                        XMLTYPE := XMLTYPE('<ABC19></ABC19>');
            lxml_pi                          XMLTYPE;
            ln_                              NUMBER;
            blob_                            BLOB;
            lv_district                      query.o_Office.isdistrict%TYPE;
                
        BEGIN
            IF (p_parms.get_value('REPORT_DATE') IS NOT NULL) THEN
                ld_start_date := TRUNC(TO_DATE(p_parms.get_value('REPORT_DATE'), 'MM/DD/YYYY'), 'MONTH');
                ld_end_date   := ld_start_date;
            ELSE
                lb_proc := FALSE;
                lv_status_msg := 'No report date found';
            END IF;
                    
            -- get office id(s)
            office_id := rqs_utils.BuildOfficeList(p_parms.get_value('OFFICEOBJECTID'),
                                                   lv_status_msg);
            lb_proc := (lv_status_msg IS NULL);
                
            -- check if request is district or division request
            SELECT o.isdistrict
              INTO lv_district
              FROM query.o_Office o
             WHERE objectid = p_parms.get_value('OFFICEOBJECTID');
             
            ----------------------------------------------------------------------
            -- build report
            ----------------------------------------------------------------------
            -- Section 1    (office)
            IF (lb_proc) THEN
                SELECT APPENDCHILDXML(xml_value, '/ABC19', 
                                      XMLTYPE('<OFFICE DISTRICT_FLG="' || lv_district || '">' 
                                        || office 
                                        || '</OFFICE>'))
                  INTO xml_value
                  FROM query.o_office 
                  where objectid = p_parms.get_value('OFFICEOBJECTID');
                  
            END IF;    

            -- Section 2    (month / year)
            IF (lb_proc) THEN
                SELECT APPENDCHILDXML(xml_value, '/ABC19', 
                                      XMLTYPE('<MONTHYEAR>' 
                                        || TO_CHAR(ld_start_date, 'MM/YYYY') 
                                        || '</MONTHYEAR>'))
                  INTO xml_value
                  FROM DUAL;
            END IF;    
            
            -- Section 3    (visited - licensing>
            -- Section 4    (visted - enforcement)
            -- Section 5a   (wait time)
            -- Section 5b   (mail-ins)
            -- Section 14   (Police Reports)
            -- Section 15   (letters sent)            
            IF (lb_proc) THEN
                SELECT NVL(COUNT(*), 0)
                  INTO ln_
                  FROM mart.abc19monthlyheader h
                 WHERE h.districtofficeobjectid IN (SELECT officeobjectid FROM TABLE(office_id))
                   AND h.year = TO_NUMBER(TO_CHAR(ld_start_date, 'YYYY'))
                   AND h.monthnumber = TO_NUMBER(TO_CHAR(ld_start_date, 'MM'));

                IF (ln_ > 0) THEN                      
                    SELECT SUM(NVL(premisesvisitedlicensing, 0)),   
                           SUM(NVL(premisesvisitedenforcement, 0)), 
                           ROUND(AVG(NVL(appointmentwaittimeindays, 0))),  
                           SUM(NVL(numberofmailinsawaitinginput, 0)),
                           SUM(NVL(policereportsreceived, 0)), -- 14
                           SUM(NVL(warningletterssent, 0)), -- 15a
                           SUM(NVL(noticeofviolations, 0))  -- 15b
                      INTO ln_premisesvisitedlicensing,    
                           ln_premisesvisitedenforcement,  
                           ln_appointmentwaittimeindays,   
                           ln_numberofmailinsawaitingin,
                           ln_policereportsreceived,
                           ln_warningletterssent,
                           ln_noticeofviolations   
                      FROM mart.abc19monthlyheader h
                     WHERE h.districtofficeobjectid IN (SELECT officeobjectid FROM TABLE(office_id))
                       AND h.year = TO_NUMBER(TO_CHAR(ld_start_date, 'YYYY'))
                       AND h.monthnumber = TO_NUMBER(TO_CHAR(ld_start_date, 'MM'));
                ELSE
                    ln_premisesvisitedlicensing   := 0; 
                    ln_premisesvisitedenforcement := 0;
                    ln_appointmentwaittimeindays  := 0;
                    ln_numberofmailinsawaitingin  := 0;
                    ln_policereportsreceived      := 0;
                    ln_warningletterssent         := 0;
                    ln_noticeofviolations         := 0;
                END IF;

                SELECT APPENDCHILDXML(xml_value, '/ABC19', 
                                      XMLTYPE('<S3_5B><PREMISESVISITEDLICENSING>' 
                                        || TO_CHAR(ln_premisesvisitedlicensing) 
                                        || '</PREMISESVISITEDLICENSING>'
                                        || '<PREMISESVISITEDENFORCEMENT>' 
                                        || TO_CHAR(ln_premisesvisitedenforcement) 
                                        || '</PREMISESVISITEDENFORCEMENT>'
                                        || '<APPOINTMENTWAITTIMEINDAYS>' 
                                        || TO_CHAR(ln_appointmentwaittimeindays) 
                                        || '</APPOINTMENTWAITTIMEINDAYS>'
                                        || '<NUMBEROFMAILINSAWAITINGIN>' 
                                        || TO_CHAR(ln_numberofmailinsawaitingin) 
                                        || '</NUMBEROFMAILINSAWAITINGIN>'
                                        || '<POLICEREPORTSRECEIVED>'
                                        || TO_CHAR(ln_policereportsreceived)
                                        || '</POLICEREPORTSRECEIVED>'
                                        || '<WARNINGLETTERSSENT>'
                                        || TO_CHAR(ln_warningletterssent)
                                        || '</WARNINGLETTERSSENT>'
                                        || '<NOTICEOFVIOLATIONS>'
                                        || TO_CHAR(ln_noticeofviolations)
                                        || '</NOTICEOFVIOLATIONS>'
                                        || '</S3_5B>'
                                        ))
                  INTO xml_value
                  FROM DUAL;
            END IF;         
                
            -- Section 6    (Courtesy abc-211)
--            IF (lv_district = 'N') THEN
                IF (lb_proc) THEN
                    lb_proc := COURTESTYABC211(xml_value, office_id, ld_start_date, ld_end_date, lv_status_msg);
                END IF;
                    
                -- Section 7    (abc-211 for this office division?)
                IF (lb_proc) THEN
                    lb_proc := TAKENABC211(xml_value, office_id, ld_start_date, ld_end_date, lv_status_msg);
                END IF;
--            END IF;    
            -- Section 8    (abc220)
            -- Section 9    (abc-61 Licensing Assignments)
            IF (lb_proc) THEN
                lb_proc := ABC220(xml_value, office_id, ld_start_date, ld_end_date, lv_status_msg);
            END IF;
                
            -- Section 10   (abc 211 Received)
            IF (lb_proc) THEN
                lb_proc := COUNTABC211(xml_value, office_id, ld_start_date, ld_end_date, lv_status_msg);
            END IF;
                
            -- Section 12, 13  (abc-61 Assignments) (Arrests/Citations)
            IF (lb_proc) THEN
                lb_proc := ASSIGNMENTS_ABC61(xml_value, office_id, ld_start_date, lv_status_msg);
            END IF;
                    
            -- Section 14, 15  (Police Reports) (letters sent)
            --    ( see section 3-5 ) 
            
            -- Section 16 - 19      
            -- Section 16   (Minor Decoy - on sale)
            IF (lb_proc) THEN
                lb_proc := SECTIONS16TO19(xml_value, office_id, ld_start_date, 'Minor Decoy Program - On Sale', 'MDP_ONSALE', lv_status_msg);
            END IF;
                    
            -- Section 17   (Minor decoy - off sale)
            IF (lb_proc) THEN
                lb_proc := SECTIONS16TO19(xml_value, office_id, ld_start_date, 'Minor Decoy Program - Off Sale', 'MDP_OFFSALE', lv_status_msg);
            END IF;
                    
            -- Section 18   (Sholder tap)
            IF (lb_proc) THEN
                lb_proc := SECTIONS16TO19(xml_value, office_id, ld_start_date, 'Shoulder Tap Program', 'STP', lv_status_msg);
            END IF;
                    
            -- Section 19   (task forces ...)
            IF (lb_proc) THEN
                lb_proc := SECTIONS16TO19(xml_value, office_id, ld_start_date, 'Task Forces, Special Events and IMPACT', 'TF_SE_IM', lv_status_msg);
            END IF;
                
            IF (lb_proc) THEN
                p_status_ind := 'F';
                
                SELECT XMLPI(NAME "xml-stylesheet", 'href="../Formats/ABC19.xslt" type="text/xsl"') INTO lxml_pi FROM DUAL;
                blob_ := rqs_utils.clob2blob(lxml_pi.GETCLOBVAL() || xml_value.GETCLOBVAL());
            ELSE
                p_status_ind := 'E';
                blob_ := utl_raw.cast_to_raw(lv_status_msg);

                rqs_utils.log(p_log_type          =>  'E',
                              p_job_id            =>  p_parms.get_value('JOB_ID'),
                              p_seq               =>  p_parms.get_value('SEQ'),
                              p_source            =>  'ABC19 Report',
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
        END;
    END ABC19;
/


GRANT EXECUTE ON ABCREPORTS.ABC19 TO ABCREPORTS_ROLE;
