CREATE OR REPLACE FUNCTION ABCREPORTS.NEWLICENSEAPPLICATIONS(p_parms        IN OUT t_parameters,
                                      p_status_ind   IN OUT VARCHAR2)
    RETURN BLOB
IS
    /**************************************************************************
        File:   ABCREPORTS.NEWLICENSEAPPLICATIONS.FNC

        Description:

     History:
    -----------------------------------------------------------------------------
      Ver:       Date           Ticket        Comment
       1.0   11/25/2024 TJL  BIZ-16697   Initial Function Created
    **************************************************************************/
    lblob_csv      BLOB;
    lv_status_msg                    VARCHAR2(4000);
    office_id                        T_OFFICEOBJECT;
BEGIN
    DBMS_LOB.createtemporary(lblob_csv, TRUE, DBMS_LOB.call);
    p_parms.upd_value('REPORT_DATE', TO_CHAR(SYSDATE, 'MM/DD/YYYY HH:MI PM'));
    
    -- get office id(s)
    office_id := rqs_utils.BuildOfficeList(p_parms.get_value('OFFICEOBJECTID'), lv_status_msg);
                                           
    -- SELECT officename into office_name from query.o_office where objectid = p_parms.get_value('OFFICEOBJECTID');

    FOR rec
        IN (  SELECT --distinct
                     '"'
                     || api.pkg_columnquery.VALUE(la.jobid, 'BaseFileOfficeName')
                     || '","'
                     || TO_CHAR(
                            api.pkg_columnquery.datevalue(la.jobid,
                                                          'CreatedDate'),'MM/DD/YYYY')
                     || '","'
                     || api.pkg_columnquery.VALUE(la.jobid, 'LicenseNumber')
                     || '","'
                     || api.pkg_columnquery.VALUE(la.jobid, 'LSPId')
                     || '","'                                 
                     ||(select sum(amount+paidamount) from api.fees where jobid = la.jobid)
                     || '","'
                     || api.pkg_columnquery.VALUE(la.jobid,
                                                  'PrimaryLicenseTypeCodes')
                     || '","'
                     || api.pkg_columnquery.VALUE(la.jobid, 'ApplicationType')
                     || '","'
                     || NVL(
                            api.pkg_columnquery.VALUE(la.jobid,
                                                      'ApplicantPerson'),
                            api.pkg_columnquery.VALUE(la.jobid,
                                                      'ApplicantCompany'))
                     || '","'
                     || api.pkg_columnquery.VALUE(la.jobid, 'PremAddressLine1')
                     || '","'
                     || api.pkg_columnquery.VALUE(la.jobid, 'PremAddressLine2')
                     || '","'
                     || api.pkg_columnquery.VALUE(la.jobid, 'PremUSCity')
                     || '","'
                     || api.pkg_columnquery.VALUE(la.jobid, 'PremAddressState')
                     || '","'
                     || api.pkg_columnquery.VALUE(la.jobid, 'PremZipCode')
                      || '","'
                     || (select AssignedStaff from query.p_enterapplication where jobid = la.jobid)
                    
                     || '"'
                     || CHR(13)
                     || CHR(10)    info
                FROM bizmod_api.license_app_t la,  query.o_office off
                WHERE la.statusname IN ('NEW', 'POSTED') 
                and api.pkg_columnquery.VALUE(la.jobid, 'BaseFileOfficeName') = off.OFFICENAME
                and off.officecode IN (SELECT o.officecode
                                             FROM TABLE(office_id) l
                                             JOIN query.o_office o
                                               ON (l.officeobjectid = o.objectid))
               
            ORDER BY api.pkg_columnquery.datevalue(la.jobid, 'CreatedDate'))
    LOOP
        DBMS_LOB.append(lblob_csv, UTL_RAW.cast_to_raw(rec.info));
    END LOOP;

    COMMIT;
    RETURN lblob_csv;
EXCEPTION
    WHEN OTHERS
    THEN
        rqs_utils.LOG(p_log_type  => 'E',
                      p_job_id    => p_parms.get_value('JOB_ID'),
                      p_seq       => p_parms.get_value('SEQ'),
                      p_source    => 'New Report',
                      p_msg       => SQLERRM,
                      p_additional_data => NULL,
                      p_error_trace => DBMS_UTILITY.format_error_backtrace);

        p_status_ind := 'E';

        RETURN UTL_RAW.cast_to_raw(
                   'ERROR: '
                   || SQLERRM
                   || CHR(10)
                   || CHR(13)
                   || 'TRACE: '
                   || DBMS_UTILITY.format_error_backtrace);
END;
/