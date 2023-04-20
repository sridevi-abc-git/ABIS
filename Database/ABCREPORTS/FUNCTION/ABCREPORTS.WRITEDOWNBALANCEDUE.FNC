CREATE OR REPLACE FUNCTION ABCREPORTS.writedownbalancedue(p_parms IN OUT t_parameters, p_status_ind IN OUT VARCHAR2)
    RETURN BLOB
IS
    -- ****************************************************************************
    -- File:        WriteDownBalanceDue.fnc
    -- Author:      Timothy J. Lord
    --
    --
    -- Description:
    --
    --
    -- History:
    -------------------------------------------------------------------------------
    --    Date                  Comment
    -- 08/11/2020 TJL  20763   Function created
    -- 09/20/2021 TJL          Switch to using api.fees view to build report
    -- ****************************************************************************
    -- ************************************************************************
    --  Main process
    -- ************************************************************************
    office_id        t_officeobject;
    lv_status_msg    VARCHAR2(4000);
    lblob_csv        BLOB;
    ld_start         DATE;
    ld_end           DATE;
    lv_csv_row       VARCHAR2(8096);
    lv_report_name   VARCHAR(150) := p_parms.get_value('REPORT_NAME');
BEGIN
    DBMS_LOB.createtemporary(lblob_csv, TRUE, DBMS_LOB.call);

    ld_start    := TO_DATE(p_parms.get_value('START_DATE'), 'MM/DD/YYYY');
    ld_end      := TO_DATE(p_parms.get_value('END_DATE'), 'MM/DD/YYYY');

    p_parms.upd_value('REPORT_DATE', TO_CHAR(SYSDATE, 'MM/DD/YYYY HH:MI PM'));

    office_id   := rqs_utils.buildofficelist(p_parms.get_value('OFFICEOBJECTID'), lv_status_msg);

    DBMS_OUTPUT.put_line(   'report: '
                         || lv_report_name
                         || ' '
                         || ld_start
                         || '  '
                         || ld_end);

    FOR rec
        IN (WITH
                f
                AS
                    (  SELECT  /*+ materialize */
                              api.pkg_columnquery.numericvalue(
                                  f.jobid,
                                  CASE api.pkg_columnquery.VALUE(f.jobid, 'objectdefname')
                                      WHEN 'j_OneDayLicense' THEN 'DistrictOfficeId'
                                      ELSE 'BaseFileOfficeId'
                                  END)
                                  officeid,
                              api.pkg_columnquery.VALUE(f.jobid, 'objectdefname')
                                  objectdefname,
                              api.pkg_columnquery.VALUE(f.jobid, 'LicenseNumber')
                                  licensenumber,
                              f.description,
                              f.transactiondate,
                              f.paidamount,
                              (f.amount + f.adjustedamount)
                                  feeamount,
                              f.amount + f.adjustedamount + f.paidamount
                                  balancedue,
                              api.pkg_columnquery.VALUE(f.jobid, 'StatusName')
                                  status,
                              f.feeid
                         FROM api.fees f
                        WHERE f.transactiondate BETWEEN ld_start AND ld_end
                          AND f.amount + f.adjustedamount > -f.paidamount
                          AND f.paidamount < 0)
            SELECT    '"'
                   || api.pkg_columnquery.VALUE(f.officeid, 'OfficeName')
                   || '","'
                   || f.objectdefname  --f.externalfilenum
                   || '","'
                   || f.licensenumber
                   || '","'
                   || f.description
                   || '","'
                   || TO_CHAR(f.transactiondate, 'MM/DD/YYYY')
                   || '",'
                   || f.paidamount
                   || ','
                   || f.feeamount
                   || ','
                   || f.balancedue
                   || ',"'
                   || f.status
                   || '",'
                   || f.feeid
                       info
              FROM f
             WHERE ((f.objectdefname IN ('j_Application', 'j_OneDayLicense')
                 AND status IN ('ISSUED', 'RDISSU'))
                 OR (f.objectdefname IN ('j_License', 'j_LicenseType')
                 AND status IN ('ACTIVE',
                                'REVPEN',
                                'R64B',
                                'SLMSHD',
                                'SUREND',
                                'SUSPEN')))
               AND CASE
                       WHEN lv_report_name = 'Balance Due'
                        AND balancedue > 10 THEN
                           1
                       WHEN lv_report_name = 'Write Down'
                        AND balancedue BETWEEN 0 AND 10 THEN
                           1
                       ELSE
                           0
                   END = 1
               AND f.officeid IN (SELECT officeobjectid FROM TABLE(office_id)))
    LOOP
        lv_csv_row   :=
               REGEXP_REPLACE(rec.info, '[[:cntrl:]]', '')
            || CHR(13)
            || CHR(10);

        DBMS_LOB.append(lblob_csv, UTL_RAW.cast_to_raw(lv_csv_row));
    END LOOP;

    DBMS_OUTPUT.put_line('Done');

    COMMIT;
    RETURN lblob_csv;
EXCEPTION
    WHEN OTHERS THEN
        rqs_utils.LOG(p_log_type  => 'E',
                      p_job_id    => p_parms.get_value('JOB_ID'),
                      p_seq       => p_parms.get_value('SEQ'),
                      p_source    => 'WriteDownBalanceDue',
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
END writedownbalancedue;
/
