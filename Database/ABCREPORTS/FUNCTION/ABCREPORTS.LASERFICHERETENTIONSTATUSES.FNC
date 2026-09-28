CREATE OR REPLACE FUNCTION ABCREPORTS.LaserficheRetentionStatuses RETURN NUMBER IS
--tmpVar NUMBER;
/******************************************************************************
   NAME:       LaserficheRetentionStatuses
   PURPOSE:    

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0        9/28/2026   SSoundararajan       1. Created this function.

   NOTES:

   Automatically available Auto Replace Keywords:
      Object Name:     LaserficheRetentionStatuses
      Sysdate:         9/28/2026
      Date and Time:   9/28/2026, 10:59:09 AM, and 9/28/2026 10:59:09 AM
      Username:        SSoundararajan (set in TOAD Options, Procedure Editor)
      Table Name:       (set in the "New PL/SQL Object" dialog)

******************************************************************************/
 
    --  Main process
    -- ************************************************************************
    lblob_csv    BLOB;
    ld_start     DATE;
    ld_end       DATE;
    lv_csv_row   VARCHAR2(8096);
BEGIN
    DBMS_LOB.createtemporary(lblob_csv, TRUE, DBMS_LOB.call);

    ld_start   := TO_DATE(p_parms.get_value('START_DATE'), 'MM/DD/YYYY');
    ld_end     := TO_DATE(p_parms.get_value('END_DATE'), 'MM/DD/YYYY');

    p_parms.upd_value('REPORT_DATE', TO_CHAR(SYSDATE, 'MM/DD/YYYY HH:MI PM'));

    FOR rec
        IN (WITH
                jsc
                AS
                    (SELECT *
                       FROM (SELECT y.*, CASE def WHEN 'j_Application' THEN 'App' ELSE 'Lic' END licapp
                               FROM (  SELECT jobid,
                                              api.pkg_columnquery.VALUE(jsc.jobid, 'ObjectDefName')
                                                  def,
                                              api.pkg_columnquery.VALUE(jsc.jobid, 'LicenseTypeCode')
                                                  ltcode,
                                              'Primary'
                                                  staticlabel,
                                              jsc.effectivestartdate,
                                              (SELECT statusname
                                                 FROM extension.jobstatuschange_t ssh2
                                                WHERE ssh2.jobstatuschangeid =
                                                      (SELECT MAX(x.jobstatuschangeid)
                                                         FROM extension.jobstatuschange_t x
                                                        WHERE x.jobid = jsc.jobid
                                                          AND x.effectiveenddate = jsc.effectivestartdate))
                                                  fromstatus,
                                              jsc.statusname
                                                  tostatus
                                         FROM extension.jobstatuschange_t jsc
                                        WHERE TRUNC(jsc.effectivestartdate) BETWEEN ld_start AND ld_end
                                          AND jsc.statusname NOT IN ('ACTIVE')  -- CHANGES MADE FOR NON ACTIVE STATUS
                                     ORDER BY jsc.jobid, effectivestartdate) y
                              WHERE def IN ('j_LicenseType', 'o_PrimaryLicenseType')
                             UNION
                             SELECT CASE api.pkg_columnquery.VALUE(slt.fromobjectid, 'ObjectDefName')
                                        WHEN 'o_PrimaryLicenseType' THEN
                                            api.pkg_columnquery.numericvalue(slt.fromobjectid, 'ApplicationObjectId')
                                        ELSE
                                            slt.fromobjectid
                                    END
                                        jobid,
                                    NULL
                                        def,
                                    api.pkg_columnquery.VALUE(slt.toobjectid, 'LicenseTypeCode')
                                        sltcode,
                                    'Secondary'
                                        staticlabel,
                                    slt.effectivestartdate,
                                    (SELECT statusname
                                       FROM sitespecific.sltstatuschange_t ssh2
                                      WHERE ssh2.sltstatuschangeid =
                                            (SELECT MAX(x.sltstatuschangeid)
                                               FROM sitespecific.sltstatuschange_t x
                                              WHERE x.relationshipid = slt.relationshipid
                                                AND x.effectiveenddate = slt.effectivestartdate))
                                        fromstatus,
                                    slt.statusname
                                        tostatus,
                                    CASE api.pkg_columnquery.VALUE(slt.fromobjectid, 'ObjectDefName')
                                        WHEN 'o_PrimaryLicenseType' THEN 'App'
                                        ELSE 'Lic'
                                    END
                                        licapp
                               FROM sitespecific.sltstatuschange_t slt
                              WHERE TRUNC(slt.effectivestartdate) BETWEEN ld_start AND ld_end
                                AND slt.statusname NOT IN ('ACTIVE')))  -- Changes made by sri for non active status.
            SELECT    license_num
                   || ',"'
                   || license_type_code
                   || '","'
                   || fromstatus
                   || '","'
                   || tostatus                  
               
                       info
              FROM (SELECT LPAD(licensenumber, 6)                                       license_num,
                           jsc.ltcode                                                   license_type_code,
                           jsc.fromstatus,
                           jsc.tostatus
                         
                      FROM mart.licensetype lt
                           JOIN jsc
                           ON jsc.jobid = lt.objectid
                    UNION
                    SELECT LPAD(licensenumber, 6)                          license_num,
                           jsc.ltcode                                      license_type_code,
                           jsc.fromstatus,
                           jsc.tostatus
                          
                      FROM mart.applictype a
                           JOIN jsc
                           ON jsc.jobid = a.objectid
                    ORDER BY
                        1,
                        6,
                        2,
                        7,
                        5))
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
                      p_source    => 'LaserficheRetentionStatuses',
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
