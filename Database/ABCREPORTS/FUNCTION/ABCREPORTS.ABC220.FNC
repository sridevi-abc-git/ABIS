CREATE OR REPLACE FUNCTION ABCREPORTS.abc220(p_parms IN OUT t_parameters, p_status_ind IN OUT VARCHAR2)
    RETURN BLOB
IS
    -- ****************************************************************************
    -- File:        ABC220.FNC
    -- Author:      Timothy J. Lord
    --
    -- Description:
    --
    --
    -- History:
    -------------------------------------------------------------------------------
    --    Date                  Comment
    -- 03/24/2020 TJL  21116  Initial file create
    -- 01/26/2021 TJL  23967  Add fields to report (District Application Review
    --                          Date Completed, Days Pending)
    -- ****************************************************************************
    CURSOR query(
        p_start_date   IN DATE,
        p_end_date     IN DATE)
    IS
        WITH
            objects
            AS
                (SELECT a.objectid,
                        (SELECT p.processid
                           FROM api.processes p
                          WHERE p.processtypeid = api.pkg_configquery.objectdefidforname('p_AssignAppInvestigation')
                            AND p.jobid = a.objectid
                            AND ROWNUM = 1)
                            processid,
                        (SELECT p.processid  -- 23967 tjl 01/26/2021
                           FROM api.processes p
                          WHERE p.processtypeid =
                                api.pkg_configquery.objectdefidforname('p_DistrictApplicationReview')
                            AND p.jobid = a.objectid
                            AND ROWNUM = 1)
                            appreview
                   FROM mart.application a
                  WHERE a.haslicensetype79 = 'N'
                    AND a.haslicensetype84 = 'N'
                    AND a.statusname <> 'NEW'
                    AND a.abc19apptype IS NOT NULL
                    AND TRUNC(enterapplicationcompleteddate) BETWEEN p_start_date AND p_end_date)
          SELECT api.pkg_columnquery.datevalue(o.objectid, 'enterapplicationcompleteddate')
                     enterapplicationcompleteddate,
                 api.pkg_columnquery.VALUE(o.objectid, 'licensenumber')
                     licensenumber,
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
                     completeddate,
                 api.pkg_columnquery.VALUE(o.objectid, 'statusname')
                     applicationstatus,
                 api.pkg_columnquery.VALUE(o.processid, 'Outcome')
                     outcome,
                 -- 23967 tjl 01/26/2021 added
                 api.pkg_columnquery.datevalue(o.appreview, 'DateCompleted')
                     appreviewcompleted,
                   -- 23967 tjl 01/26/2021 added
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
                             || rec.enterapplicationcompleteddate
                             || '","'
                             || rec.licensenumber
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
                             || rec.appreviewcompleted  -- 23967 tjl 01/26/2021 added
                             || '","'
                             || rec.completeddate
                             || '","'
                             || rec.applicationstatus
                             || '","'
                             || rec.outcome
                             || '","'
                             || rec.dayspending  -- 23967 tjl 01/26/2021 added
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
                      p_source    => 'PRJUS750',
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
END abc220;
/
