CREATE OR REPLACE FUNCTION ABCREPORTS.licensestatuschange(p_parms IN OUT t_parameters, p_status_ind IN OUT VARCHAR2)
    RETURN BLOB
IS
    -- ****************************************************************************
    -- File:        LicenseStatusChange.FNC
    -- Author:      Timothy J. Lord
    --
    -- $Rev$
    -- $Date$
    -- Last Changed By:  $Author$
    --
    -- Description:
    --
    --
    -- History:
    -------------------------------------------------------------------------------
    --    Date                  Comment
    -- 04/21/2020 TJL  21366   Function created
    -- ****************************************************************************
    -- ************************************************************************
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
                                          AND jsc.statusname NOT IN ('ISSUED', 'VOIDED')
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
                                AND slt.statusname NOT IN ('ISSUED', 'VOIDED')))
            SELECT    license_num
                   || ',"'
                   || license_type_code
                   || '","'
                   || fromstatus
                   || '","'
                   || tostatus
                   || '","'
                   || effectivedate
                   || '","'
                   || app_or_lic
                   || '","'
                   || staticlabel
                   || '",'
                   || case staticlabel when 'Secondary' then dup_count else null end
                   || ',"'
                   || orig_iss_date
                   || '","'
                   || expir_date
                   || '","'
                   || dba
                   || '","'
                   || primary_owner
                   || '","'
                   || prem_addr
                   || '","'
                   || prem_csz
                   || '","'
                   || transfer_to
                   || '","'
                   || transfer_from
                   || '",'
                   || district_code
                   || ','
                   || geo_code
                       info
              FROM (SELECT LPAD(licensenumber, 6)                                       license_num,
                           jsc.ltcode                                                   license_type_code,
                           jsc.fromstatus,
                           jsc.tostatus,
                           jsc.effectivestartdate                                       effectivedate,
                           'LIC'                                                        app_or_lic,
                           jsc.staticlabel,
                           lt.secondarylicensetypecount                                 dup_count,
                           TO_CHAR(lt.issuedate, 'MM/DD/YYYY')                          orig_iss_date,
                           TO_CHAR(lt.expirationdate, 'MM/DD/YYYY')                     expir_date,
                           REGEXP_REPLACE(lt.primarydba, '[[:cntrl:]]', '')             dba,
                           lt.primarylicensee                                           primary_owner,
                           REGEXP_REPLACE(lt.premaddress1stof2lines, '[[:cntrl:]]', '') prem_addr,
                           REGEXP_REPLACE(lt.premaddress2ndof2lines, '[[:cntrl:]]', '') prem_csz,
                           lt.transferredto                                             transfer_to,
                           lt.transferredfrom                                           transfer_from,
                           lt.basefileofficecode                                        district_code,
                           lt.licensegeocode                                            geo_code
                      FROM mart.licensetype lt
                           JOIN jsc
                           ON jsc.jobid = lt.objectid
                    UNION
                    SELECT LPAD(licensenumber, 6)                          license_num,
                           jsc.ltcode                                      license_type_code,
                           jsc.fromstatus,
                           jsc.tostatus,
                           jsc.effectivestartdate                          effectivedate,
                           'APP'                                           app_or_lic,
                           jsc.staticlabel,
                           a.secondarycount                                dup_count,
                           NULL                                            orig_iss_date,
                           NULL                                            expir_date,
                           REGEXP_REPLACE(a.primarydba, '[[:cntrl:]]', '') dba,
                           a.primarylicensee                               primary_owner,
                           a.premaddressline1                              prem_addr,
                           a.premaddressline2                              prem_csz,
                           NULL                                            transfer_to,
                           a.transferfrom                                  transfer_from,
                           a.basefileofficecode                            district_code,
                           a.applicationgeocode                            geo_code
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
