CREATE OR REPLACE FUNCTION ABCREPORTS.covid19(p_parms IN OUT t_parameters, p_status_ind IN OUT VARCHAR2)
    RETURN BLOB
IS
    -- ****************************************************************************
    -- File:        COVID19.FNC
    -- Author:      Timothy J. Lord
    --
    -- Description:
    --
    --
    -- History:
    -------------------------------------------------------------------------------
    --    Date                  Comment
    -- 06/04/2020 TJL  21707   File created
    -- ****************************************************************************
    -- ************************************************************************
    --  Main process
    -- ************************************************************************
    lblob_csv       BLOB;
    ld_start        DATE;
    ld_end          DATE;
    lv_csv_row      VARCHAR2(8096);
    office_id       t_officeobject;
    lv_status_msg   VARCHAR2(4000);
BEGIN
    DBMS_LOB.createtemporary(lblob_csv, TRUE, DBMS_LOB.call);

    ld_start       := TO_DATE(p_parms.get_value('START_DATE'), 'MM/DD/YYYY');
    ld_end         := TO_DATE(p_parms.get_value('END_DATE'), 'MM/DD/YYYY');
    office_id      := rqs_utils.buildofficelist(p_parms.get_value('OFFICEOBJECTID'), lv_status_msg);

    p_parms.upd_value('REPORT_DATE', TO_CHAR(SYSDATE, 'MM/DD/YYYY HH:MI PM'));

    FOR rec
        IN (  SELECT    '"'
                     || api.pkg_columnquery.VALUE(f.jobid, 'BaseFileOfficeName')
                     || '","'
                     || TO_CHAR(f.transactiondate, 'mm/dd/yyyy')
                     --"Transaction Date"
                     || '","'
                     || api.pkg_columnquery.VALUE(
                            f.jobid,
                            CASE api.pkg_columnquery.VALUE(f.jobid, 'ObjectDefName')
                                WHEN 'j_License' THEN 'LicenseTypeCodes'
                                WHEN 'j_Application' THEN 'PrimaryLicenseTypeCodes'
                                ELSE 'LicenseTypeCode'
                            END)  -- licensetypes
                     || '","'
                     || api.pkg_columnquery.VALUE(f.jobid, 'LicenseNumber')
                     || '","'
                     || api.pkg_columnquery.VALUE(f.jobid, 'PrimaryLicensee')
                     || '","'
                     || api.pkg_columnquery.VALUE(f.jobid, 'PremAddress2Lines')
                     || '","'
                     || CASE WHEN f.paidamount != 0 THEN 'PAID' ELSE '' END
                     || '"'
                         info
                FROM api.fees f
                     JOIN TABLE(office_id) o
                     ON o.officeobjectid = api.pkg_columnquery.VALUE(f.jobid, 'BaseFileOfficeId')
               WHERE f.description LIKE '%COVID19'
                 AND f.amount + f.adjustedamount != 0
                 AND TRUNC(f.transactiondate) BETWEEN ld_start AND ld_end
            ORDER BY o.officename, f.transactiondate)
    LOOP
        lv_csv_row   :=
               REGEXP_REPLACE(rec.info, '[[:cntrl:]]', '')
            || CHR(13)
            || CHR(10);

        DBMS_LOB.append(lblob_csv, UTL_RAW.cast_to_raw(lv_csv_row));
    END LOOP;

    p_status_ind   := 'F';

    RETURN lblob_csv;
EXCEPTION
    WHEN OTHERS THEN
        rqs_utils.LOG(p_log_type  => 'E',
                      p_job_id    => p_parms.get_value('JOB_ID'),
                      p_seq       => p_parms.get_value('SEQ'),
                      p_source    => 'LicenseStatusChange',
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
END;
/
