CREATE OR REPLACE FUNCTION ABCREPORTS.Protested220Issued(p_parms IN OUT t_parameters, p_status_ind IN OUT VARCHAR2)
    RETURN BLOB
IS
    -- ****************************************************************************
    -- File:        Protested220Issued.fnc
    -- Author:      Timothy J. Lord
    --
    --
    -- Description:
    --
    --
    -- History:
    -------------------------------------------------------------------------------
    --    Date                  Comment
    -- 04/29/2020 TJL  20763   Function created
    -- ****************************************************************************
    -- ************************************************************************
    --  Main process
    -- ************************************************************************
    office_id       T_OFFICEOBJECT;
    lv_status_msg   VARCHAR2(4000);
    lblob_csv       BLOB;
    ld_start        DATE;
    ld_end          DATE;
    lv_csv_row      VARCHAR2(8096);
BEGIN
    DBMS_LOB.createtemporary(lblob_csv, TRUE, DBMS_LOB.call);

    ld_start   := TO_DATE(p_parms.get_value('START_DATE'), 'MM/DD/YYYY');
    ld_end     := TO_DATE(p_parms.get_value('END_DATE'), 'MM/DD/YYYY');

    p_parms.upd_value('REPORT_DATE', TO_CHAR(SYSDATE, 'MM/DD/YYYY HH:MI PM'));

    office_id := rqs_utils.BuildOfficeList(p_parms.get_value('OFFICEOBJECTID'), lv_status_msg);
    
    FOR rec
        IN (  SELECT    api.pkg_columnquery.VALUE(s.jobid, 'LicenseNumber')
                     || ',"'
                     || TO_CHAR(s.effectivestartdate, 'MM/DD/YYYY')
                     || '","'
                     || api.pkg_columnquery.VALUE(s.jobid, 'BaseFileOfficeName')
                     || '","'
                     || api.pkg_columnquery.VALUE(s.jobid, 'ApplicationTypeDisplay')
                     || '","'
                     || TRIM(
                            SUBSTR(
                                   CASE
                                       WHEN api.pkg_columnquery.VALUE(s.jobid, 'PremiseToPremise') = 'Y' THEN
                                           ',PremiseToPremise'
                                       ELSE
                                           NULL
                                   END
                                || CASE
                                       WHEN api.pkg_columnquery.VALUE(s.jobid, 'PersonToPerson') = 'Y' THEN
                                           ',PersonToPerson'
                                       ELSE
                                           NULL
                                   END
--                                || CASE
--                                       WHEN api.pkg_columnquery.VALUE(s.jobid, 'FiduciaryTransfer') = 'Y' THEN
--                                           ',FiduciaryTransfer'
--                                       ELSE
--                                           NULL
--                                   END
--                                || CASE
--                                       WHEN api.pkg_columnquery.VALUE(s.jobid, 'StockTransfer') = 'Y' THEN
--                                           ',StockTransfer'
--                                       ELSE
--                                           NULL
--                                   END
--                                || CASE
--                                       WHEN api.pkg_columnquery.VALUE(s.jobid, 'MembershipTransfer') = 'Y' THEN
--                                           ',MembershipTransfer'
--                                       ELSE
--                                           NULL
--                                   END
--                                || CASE
--                                       WHEN api.pkg_columnquery.VALUE(s.jobid, 'StockTransfer') = 'Y' THEN
--                                           ',StockTransfer'
--                                       ELSE
--                                           NULL
--                                   END
--                                || CASE
--                                       WHEN api.pkg_columnquery.VALUE(s.jobid, 'MembershipTransfer') = 'Y' THEN
--                                           ',MembershipTransfer'
--                                       ELSE
--                                           NULL
--                                   END
                                || ' ',
                                2))
                     || '"'
                         info
                FROM (WITH
                          status
                          AS
                              (SELECT x.jobid,
                                      TRUNC(x.effectivestartdate)                       effectivestartdate,
                                      api.pkg_columnquery.VALUE(x.jobid, 'ObjectDefName') obj
                                 FROM extension.jobstatuschange_t x
                                WHERE x.mostrecent = 'Y'
                                  AND x.statusname = 'ISSUED'
                                  AND x.effectivestartdate BETWEEN ld_start AND ld_end)
                      SELECT api.pkg_columnquery.VALUE(r.toobjectid, 'SelectedForReporting') selectedforreporting,
                             s.effectivestartdate,
                             s.jobid,
                             api.pkg_columnquery.VALUE(s.jobid, 'BaseFileOfficeId') BaseFileOfficeId,
                             api.pkg_columnquery.VALUE(s.jobid, 'ApplicationTypeDisplay') ApplicationType,
                             api.pkg_columnquery.VALUE(s.jobid, 'PremiseToPremise') Prem
                        FROM status s
                             JOIN api.relationships r
                             ON (r.endpointid = api.pkg_configquery.endpointidforname('j_Application', 'Protestant')
                             AND r.fromobjectid = s.jobid)
                       WHERE obj = 'j_Application') s
               WHERE s.selectedforreporting = 'Y'
                 and s.BaseFileOfficeId IN (SELECT officeobjectid FROM TABLE(office_id))
                 and case when upper(s.ApplicationType) = 'ORIGINAL' OR s.prem = 'Y' THEN 'Y' else 'N' END = 'Y'
            GROUP BY s.jobid, s.effectivestartdate
            ORDER BY s.jobid)
    LOOP
        lv_csv_row   :=
               REGEXP_REPLACE(rec.info, '[[:cntrl:]]', '')
            || CHR(13)
            || CHR(10);

        DBMS_LOB.append(lblob_csv, UTL_RAW.cast_to_raw(lv_csv_row));
    END LOOP;

    COMMIT;
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
