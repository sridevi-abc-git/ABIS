CREATE OR REPLACE FUNCTION ABCREPORTS.cateringapplications(
    p_parms        IN OUT t_parameters,
    p_status_ind   IN OUT VARCHAR2)
    RETURN BLOB
IS
    -- ****************************************************************************
    -- File:        CATERINGAPPLICATIONS.FNC
    -- Author:      Timothy J. Lord
    --
    -- Description:
    --      This function is used to generate a csv report of Catering Application
    --      between to dates
    --
    -- History:
    -------------------------------------------------------------------------------
    --    Ver:     Date                       Comment
    --          11/15/2023  TJL BIZ-13555  Initial Package Created
    -- ****************************************************************************
    CURSOR query(p_start_date IN DATE, p_end_date IN DATE)
    IS
        SELECT api.pkg_columnquery.datevalue(o.objectid, 'DateOfEventFrom')
                   eventstartdate,
               api.pkg_columnquery.datevalue(o.objectid, 'DateOfEventTo')
                   eventenddate,
               api.pkg_columnquery.VALUE(o.objectid,
                                         'EventLocAddressObjectId')
                   address,
               api.pkg_columnquery.VALUE(o.objectid, 'ContactName')
                   contactperson,
               api.pkg_columnquery.numericvalue(o.objectid,
                                                'EstimatedAttendance')
                   attendance,
               api.pkg_columnquery.numericvalue(o.objectid, 'Days')
                   numberofdays,
               api.pkg_columnquery.VALUE(o.objectid, 'PublicEvent')
                   publicorprivate,
               api.pkg_columnquery.VALUE(o.objectid, 'AssignedTo')
                   assignedto,
               o.objectid
                   processapplicationid,
               api.pkg_columnquery.datevalue(o.objectid, 'CreatedDate')
                   cateringauthorizationapplicationcreatedate
--               api.pkg_columnquery.VALUE(o.objectid, 'LicenseNumber')
--                   licensenumber
          FROM TABLE(
                   CAST(
                       api.pkg_simplesearch.castableobjectsbyindexrange(
                           a_objectdefname => 'p_IssueCatererEventAuth',
                           a_columnname => 'dup_CreatedDate', 
                           a_lowvalue  =>
                               TO_CHAR(p_start_date, 'yyyy-mm-dd'),
                           a_highvalue =>
                               TO_CHAR(p_end_date, 'yyyy-mm-dd'))
                           AS api.udt_objectlist)) o;


    lv_status_msg  VARCHAR2(8096);
    lblob_csv      BLOB;
    ld_start       DATE;
    ld_end         DATE;
    lv_csv_row     VARCHAR2(8096);
BEGIN
    DBMS_LOB.createtemporary(lblob_csv, TRUE, DBMS_LOB.call);

    ld_start := TO_DATE(p_parms.get_value('START_DATE'), 'MM/DD/YYYY');
    ld_end := TO_DATE(p_parms.get_value('END_DATE'), 'MM/DD/YYYY');
    p_parms.upd_value('REPORT_DATE', TO_CHAR(SYSDATE, 'MM/DD/YYYY HH:MI PM'));

    FOR rec IN query(ld_start, ld_end)
    LOOP
        lv_csv_row :=
            TRANSLATE(
                '"'
                || rec.eventstartdate
                || '","'
                || rec.eventenddate
                || '","'
                || api.pkg_columnquery.VALUE(rec.address, 'AddressLine1')
                || ', '
                || api.pkg_columnquery.VALUE(rec.address, 'AddressLine2')
                || CASE
                       WHEN api.pkg_columnquery.VALUE(rec.address,
                                                      'AddressLine2')
                                IS NULL
                       THEN
                           ' '
                       ELSE
                           ', '
                   END
                || api.pkg_columnquery.VALUE(rec.address, 'CACity')
                || ', '
                || api.pkg_columnquery.VALUE(rec.address, 'USAState')
                || ', '
                || api.pkg_columnquery.VALUE(rec.address, 'ZipCode')
                || '","'
                || rec.contactperson
                || '",'
                || rec.attendance
                || ','
                || rec.numberofdays
                || ',"'
                || rec.publicorprivate
                || '","'
                || rec.assignedto
                || '",'
                || rec.processapplicationid
                || ',"'
                || rec.cateringauthorizationapplicationcreatedate
--                || '","'
--                || rec.licensenumber
                || '",',
                CHR(9) || CHR(10) || CHR(13),
                '   ')
            || CHR(13)
            || CHR(10);

        DBMS_LOB.append(lblob_csv, UTL_RAW.cast_to_raw(lv_csv_row));
    END LOOP;

    RETURN lblob_csv;
EXCEPTION
    WHEN OTHERS
    THEN
        rqs_utils.LOG(p_log_type  => 'E',
                      p_job_id    => p_parms.get_value('JOB_ID'),
                      p_seq       => p_parms.get_value('SEQ'),
                      p_source    => 'CATERINGAPPLICATIONS',
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
END cateringapplications;
/
