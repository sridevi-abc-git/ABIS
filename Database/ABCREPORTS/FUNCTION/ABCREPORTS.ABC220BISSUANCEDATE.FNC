CREATE OR REPLACE FUNCTION ABCREPORTS.abc220BIssuanceDate(p_parms IN OUT t_parameters, p_status_ind IN OUT VARCHAR2)
    RETURN BLOB
IS
    -- ****************************************************************************
    -- File:        ABC220BIssuanceDate.FNC
    -- Author:      Pawanjit Kaur
    --
    -- Description:
    --
    --
    -- History:
    -------------------------------------------------------------------------------
    --    Date                  Comment
    -- 11/29/2023 PK  34004  Initial file create 34004 - New RQS Report - ABC220B (Issuance Date)
    -- 02/06/2024 PK  Added Application number- External file num. Pawan on 02/06/2024

    -- ****************************************************************************
    CURSOR query(
        p_start_date   IN DATE,
        p_end_date     IN DATE)
    IS
        WITH
            objects
            AS
               (SELECT a.applicationobjectid objectid, a.STATUS status,
                        (SELECT p.processid
                           FROM api.processes p
                          WHERE p.processtypeid = api.pkg_configquery.objectdefidforname('p_AssignAppInvestigation')
                            AND p.jobid = a.applicationobjectid-- a.objectid
                            AND ROWNUM = 1)
                            processid,
                        (SELECT p.processid  
                           FROM api.processes p
                          WHERE p.processtypeid =
                                api.pkg_configquery.objectdefidforname('p_DistrictApplicationReview')
                            AND p.jobid = a.applicationobjectid-- a.objectid
                            AND ROWNUM = 1)
                            appreview,
                       (SELECT p.processid 
                           FROM api.processes p
                          WHERE p.processtypeid =
                                api.pkg_configquery.objectdefidforname('p_ConductAppInvestigation')
                            AND p.jobid = a.applicationobjectid --a.objectid
                            AND ROWNUM = 1) condappprocess
                  FROM mart.applictype  a
               JOIN mart.primaryandsecondaryapplictype psal
                   ON psal.primlictypeobjectid = a.objectid
               JOIN mart.licensetypecategory ltc
                   ON ltc.objectid = psal.liccategoryobjectid
         WHERE (a.status IN ('ISSUED','PENDING', 'WITHDRAWN', 'DENIED')
             OR psal.status IN ('ISSUED','PENDING', 'WITHDRAWN', 'DENIED'))
                        AND ltc.licensetypecode NOT IN ('09',
                                           '11',
                                           '12',
                                           '26',
                                           '28',
                                           '58',
                                           '62',
                                           '66',
                                           '68',
                                           '77',
                                           '79',
                                           '81',
                                           '82',
                                           '84')
           AND (TRUNC(a.statusdatecorral) BETWEEN p_start_date AND p_end_date
             OR TRUNC(psal.statusdate) BETWEEN p_start_date AND p_end_date))
          SELECT api.pkg_columnquery.datevalue(o.objectid, 'enterapplicationcompleteddate')
                     enterapplicationdate,
                 api.pkg_columnquery.VALUE(o.objectid, 'licensenumber')
                     licensenumber,
                 api.pkg_columnquery.VALUE(o.objectid, 'Externalfilenum')
                     Applicationnumber,    
                 api.pkg_columnquery.VALUE(o.condappprocess, 'AssignedToList')
                    AssignedToCompletedBy,    
                 api.pkg_columnquery.VALUE(o.objectid, 'BaseFileOfficeName')
                     basefileofficename,
                 api.pkg_columnquery.VALUE(o.objectid, 'PrimaryApplicant')
                     primaryapplicant,
                 api.pkg_columnquery.VALUE(o.objectid, 'PremisesAddress')
                     premisesaddress,
                 api.pkg_columnquery.VALUE(o.objectid, 'PrimaryLicenseTypeCodes')
                     licensetypes,
                 api.pkg_columnquery.VALUE(o.objectid, 'ApplicationType')
                     applicationtype,
                    SUBSTR(
                           CASE
                               WHEN api.pkg_columnquery.VALUE(o.objectid, 'PremiseToPremise') = 'Y' THEN
                                   ', Premise to Premise'
                               ELSE
                                   NULL
                           END
                        || CASE
                               WHEN api.pkg_columnquery.VALUE(o.objectid, 'PersonToPerson') = 'Y' THEN
                                   ', Person To Person'
                               ELSE
                                   NULL
                           END
                        || CASE
                               WHEN api.pkg_columnquery.VALUE(o.objectid, 'FiduciaryTransfer') = 'Y' THEN
                                   ', Fiduciary Transfer'
                               ELSE
                                   NULL
                           END
                        || CASE
                               WHEN api.pkg_columnquery.VALUE(o.objectid, 'StockTransfer') = 'Y' THEN
                                   ', Stock Transfer'
                               ELSE
                                   NULL
                           END
                        || CASE
                               WHEN api.pkg_columnquery.VALUE(o.objectid, 'MembershipTransfer') = 'Y' THEN
                                   ', Membership Transfer'
                               ELSE
                                   NULL
                           END,
                        3)
                 || api.pkg_columnquery.VALUE(o.objectid, 'PriorityApplicationType')
                     transfertype,
                 api.pkg_columnquery.datevalue(o.objectid, 'CompletedDate')
                     Applicationcompleteddate,
                 o.status
                     applicationstatus,
                 api.pkg_columnquery.VALUE(o.processid, 'Outcome')
                     outcome,
                 api.pkg_columnquery.datevalue(o.appreview, 'DateCompleted')
                     appreviewcompleted,
                 trunc(api.pkg_columnquery.datevalue(o.appreview, 'DateCompleted'))
                            - trunc(api.pkg_columnquery.datevalue(o.objectid, 'enterapplicationcompleteddate'))
                     dayspending
            FROM objects o
        ORDER BY basefileofficename, licensetypes;

    lv_status_msg   VARCHAR2(8096);
    lblob_csv       BLOB;
    ld_start        DATE;
    ld_end          DATE;
    lv_csv_row      VARCHAR2(8096);
BEGIN
    DBMS_LOB.createtemporary(lblob_csv, TRUE, DBMS_LOB.call);

    ld_start   := TO_DATE(p_parms.get_value('START_DATE'), 'MM/DD/YYYY');
    ld_end     := TO_DATE(p_parms.get_value('END_DATE'), 'MM/DD/YYYY');
    p_parms.upd_value('REPORT_DATE', TO_CHAR(SYSDATE, 'MM/DD/YYYY HH:MI PM'));


    IF (lv_status_msg IS NULL) THEN
        p_parms.upd_value('REPORT_DATE', TO_CHAR(SYSDATE, 'MM/DD/YYYY HH:MI PM'));

        FOR rec IN query(ld_start, ld_end)
        LOOP
            lv_csv_row   :=
                   TRANSLATE(   '"'
                             || rec.enterapplicationdate
                             || '","'
                             || rec.licensenumber
                             || '","'
                             || rec.Applicationnumber
                             || '","'
                             || rec.basefileofficename
                             || '","'
                             || rec.primaryapplicant
                             || '","'
                             || rec.premisesaddress
                             || '","'
                             || rec.licensetypes
                             || '","'
                             || rec.applicationtype
                             || '","'
                             || rec.transfertype
                             || '","'
                             || rec.appreviewcompleted  
                             || '","'
                             || rec.Applicationcompleteddate
                             || '","'
                             || rec.applicationstatus
                             || '","'
                             || rec.AssignedToCompletedBy 
                             || '","'
                             || rec.outcome
                             || '","'
                             || rec.dayspending  
                             || '",',
                                CHR(9)
                             || CHR(10)
                             || CHR(13),
                             '   ')
                || CHR(13)
                || CHR(10);

            DBMS_LOB.append(lblob_csv, UTL_RAW.cast_to_raw(lv_csv_row));
        END LOOP;
    ELSE
        DBMS_LOB.append(lblob_csv, UTL_RAW.cast_to_raw(lv_status_msg));
        p_status_ind   := 'E';
    END IF;

    RETURN lblob_csv;
EXCEPTION
    WHEN OTHERS THEN
        rqs_utils.LOG(p_log_type  => 'E',
                      p_job_id    => p_parms.get_value('JOB_ID'),
                      p_seq       => p_parms.get_value('SEQ'),
                      p_source    => 'ABC220B',
                      p_msg       => SQLERRM,
                      p_additional_data => NULL,
                      p_error_trace => DBMS_UTILITY.format_error_backtrace);

        p_status_ind   := 'E';

        RETURN UTL_RAW.cast_to_raw(   'ERROR: '
                                   || SQLERRM
                                   || CHR(10)
                                   || CHR(13)
                                   || 'TRACE: '
                                   || DBMS_UTILITY.format_error_backtrace);
END abc220BIssuanceDate;
/
