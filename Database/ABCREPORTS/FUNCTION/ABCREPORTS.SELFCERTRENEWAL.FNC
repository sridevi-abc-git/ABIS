CREATE OR REPLACE FUNCTION ABCREPORTS.SelfCertRenewal(p_parms IN OUT t_parameters, p_status_ind IN OUT VARCHAR2)
    RETURN BLOB
IS
    -- ****************************************************************************
    -- File:        SelfCertRenewalRpt.FNC
    -- Author:      Pawanjit Kaur
    --
    -- Description:
    --
    --
    -- History:
    -------------------------------------------------------------------------------
    --    Date                  Comment
    -- 05/26/2021  PK       Function created
    -- 7/13/2021   PK       WO 25604 - Issue with multiple renewal batch displaying in Self-Cert report
    -- 2/24/2022   PK       WO 27615 - [URGENT] RQS Covid Waiver self certify report populating incorrecttotals
    -- ****************************************************************************
    -- ************************************************************************
    --  Main process
    -- ************************************************************************
    lblob_csv       BLOB;
    ld_start        DATE;
    ld_end          DATE;
    lv_csv_row      VARCHAR2(8096);
   -- office_id       t_officeobject;
   -- lv_status_msg   VARCHAR2(4000);
BEGIN
    DBMS_LOB.createtemporary(lblob_csv, TRUE, DBMS_LOB.call);

    ld_start       := TO_DATE(p_parms.get_value('START_DATE'), 'MM/DD/YYYY');
    ld_end         := TO_DATE(p_parms.get_value('END_DATE'), 'MM/DD/YYYY');
   -- office_id      := rqs_utils.buildofficelist(p_parms.get_value('OFFICEOBJECTID'), lv_status_msg);

    p_parms.upd_value('REPORT_DATE', TO_CHAR(SYSDATE, 'MM/DD/YYYY HH:MI PM'));

    /* Formatted on 5/26/2021 3:05:00 PM (QP5 v5.313) */
FOR rec
IN (  SELECT    '"'
                     || api.pkg_columnquery.VALUE(ri.jobid, 'PrimaryLicensee')
                     || '","'
                     ||  (select distinct min(lb.EXTERNALFILENUM)  from sitespecific.LicBatchLicType_XRef_T x  join QUERY.J_LICENSEBATCH lb on lb.JOBID = x.LICENSEBATCHJOBID and lb.EXPIRATIONDATE = ri.EXPIRATIONDATE  )  --wo 25604
                     || '","'
                     ||  ri.paymentbatch
                     || '","'
                     ||  ri.Licensenumber
                     || '","'
                     ||  (SELECT SUM(ri1.totalowing) FROM abclqs.renewal_info ri1 WHERE ri1.licensenumber= ri.licensenumber AND ri1.expirationdate = ri.expirationdate)
                     || '","'
                     ||  CASE NVL(sc.eligible, 'N') WHEN 'N' THEN ri.totalowing  WHEN 'Y' THEN 0 ELSE NULL END
                     || '","'
                     ||  CASE (sc.ELIGIBLE) WHEN 'Y' THEN 'YES' WHEN 'N' THEN 'NO' ELSE NULL END
                     || '","'
                     ||  To_Char(sc.certificationdate, 'mm/dd/yyyy hh:mi:ss am')
                     || '","'
                     ||  sc.sname
                     || '","'
                     ||  sc.phonenumber
                     || '","'
                     ||  sc.emailaddress
                     || '","'
                     ||  ri.licensetypecode
                     || '","'
                     || CASE WHEN ri.primarysecondary = 'P' THEN 'M'|| CASE WHEN ri.secondarycount > 0 THEN'-' || TO_CHAR(ri.secondarycount, '"'|| 'FM''000''') ELSE   NULL END WHEN ri.primarysecondary != 'P' THEN '-'|| TO_CHAR(ri.secondarycount, 'FM000')  ELSE NULL  END -- licensetypes
                     || '","'
                     ||  ri.licensetypedescription
                     || '","'
                     ||  TO_CHAR(ri.expirationdate, 'DD-MON-YYYY')
                     || '","'
                     ||  (SELECT SUM(feeamount) FROM abclqs.renewal_info ri2 WHERE ri2.licensenumber = ri.licensenumber AND ri2.LICENSETYPECODE = ri.licensetypecode AND ri2.expirationdate = ri.expirationdate)  -- 2/24/2022 added expdate   PK       WO 27615
                     || '","'
                     || CASE NVL(sc.eligible, 'N') WHEN 'N' THEN ri.totalowing  WHEN 'Y' THEN 0 ELSE NULL END
--                     || (SELECT SUM(CASE NVL(ri2.eligible, 'N') WHEN 'N' THEN totalowing ELSE 0 END)
--                           FROM abclqs.renewal_info ri2
--                           WHERE ri2.licensenumber = ri.licensenumber AND ri2.LICENSETYPECODE = ri.licensetypecode)
                     || '"'
                         INFO
                    FROM abclqs.renewal_info ri 
                         JOIN ABC.SELF_CERTIFICATION sc ON ri.LICENSENUMBER = sc.LICENSENUMBER
                     AND ri.EXPIRATIONDATE = sc.EXPIRATIONDATE
                     AND ri.LICENSETYPECODE = sc.LICENSETYPECODE
                    --JOIN sitespecific.LicBatchLicType_XRef_T x ON x.LICENSETYPEJOBID = ri.JOBID
                   -- JOIN QUERY.J_LICENSEBATCH lb ON lb.JOBID = x.LICENSEBATCHJOBID
                     --   AND lb.EXPIRATIONDATE = ri.EXPIRATIONDATE
                        AND TRUNC(sc.certificationdate) BETWEEN ld_start AND ld_end
                   ORDER BY ri.Licensenumber, sc.certificationdate)
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
                      p_source    => 'SelfCertRenewal',
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
