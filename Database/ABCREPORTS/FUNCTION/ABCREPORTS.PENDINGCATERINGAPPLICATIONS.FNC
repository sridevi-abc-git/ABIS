CREATE OR REPLACE FUNCTION ABCREPORTS.pendingcateringapplications(
    p_parms        IN OUT t_parameters,
    p_status_ind   IN OUT VARCHAR2)
    RETURN BLOB
IS
    -- ****************************************************************************
    -- File:        ABCREPORTS.PENDINGCATERINGAPPLICATIONS.FNC
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
    --          12/05/2023  TJL BIZ-13827  Add support to select report by office
    --    2.0   12/12/2023  TJL BIZ-13933  Changed name to PENDINGCATERINGAPPLICATIONS
    --                                       and only return application that have not
    --                                       been completed.
    --    2.1   01/12/2024  TJL BIZ-14128  Removed by office filter and date selection
    --                                       reange. Added additional fields.
    -- ****************************************************************************
    CURSOR query IS
          SELECT (SELECT qd.officename
                    FROM query.o_office qd
                   WHERE qd.officecode =
                         LPAD(
                             api.pkg_columnquery.VALUE(
                                 api.pkg_columnquery.numericvalue(o.objectid,
                                                                  'JobId'),
                                 'District'),
                             2,
                             '0'))
                     officename,
                 api.pkg_columnquery.VALUE(o.objectid, 'LicenseNumber')
                     licensenumber,
                 api.pkg_columnquery.VALUE(o.objectid, 'LSPId')
                     lspapplicationid,
                 api.pkg_columnquery.datevalue(o.objectid, 'DateOfEventFrom')
                     eventstartdate,
                 api.pkg_columnquery.datevalue(o.objectid, 'DateOfEventTo')
                     eventenddate,
                 api.pkg_columnquery.VALUE(o.objectid, 'EventType')
                     eventtype,
                 api.pkg_columnquery.VALUE(o.objectid, 'OtherEventType')
                     othereventtype,
                 api.pkg_columnquery.VALUE(o.objectid,
                                           'SponsoringOrganization')
                     sponsoringorganization,
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
                 (SELECT assignedstaff
                    FROM query.p_issuecaterereventauth i
                   WHERE i.objectid = o.objectid)
                     assignedstaff,
                 api.pkg_columnquery.datevalue(o.objectid, 'CreatedDate')
                     cateringauthorizationapplicationcreatedate
            FROM TABLE(
                     CAST(
                         api.pkg_simplesearch.castableobjectsbyindexrange(
                             a_objectdefname => 'p_IssueCatererEventAuth',
                             a_columnname => 'dup_CreatedDate',
                             a_lowvalue  =>
                                 TO_CHAR(SYSDATE - 75, 'yyyy-mm-dd'),
                             a_highvalue =>
                                 TO_CHAR(SYSDATE + 1, 'yyyy-mm-dd'))
                             AS api.udt_objectlist)) o
           WHERE api.pkg_columnquery.VALUE(o.objectid, 'Outcome') IS NULL
             AND api.pkg_columnquery.VALUE(o.objectid, 'CateringOrEvent') =
                 '58 - Catering'
        ORDER BY eventstartdate;

    lv_status_msg  VARCHAR2(8096);
    lblob_csv      BLOB;
    lv_offices     VARCHAR2(1000);
    lv_csv_row     VARCHAR2(8096);
BEGIN
    DBMS_LOB.createtemporary(lblob_csv, TRUE, DBMS_LOB.call);

    p_parms.upd_value('REPORT_DATE', TO_CHAR(SYSDATE, 'MM/DD/YYYY HH:MI PM'));

    FOR rec IN query
    LOOP
        -- get offices for assigned user
        SELECT LISTAGG(DISTINCT o.officenameabbreviation, ', ')
                   WITHIN GROUP (ORDER BY o.officenameabbreviation)
          INTO lv_offices
          FROM query.o_office o
         WHERE o.objectid IN
                   (WITH
                        data
                        AS
                            (SELECT officeidlist     str
                               FROM query.users -- admin.users
                              WHERE oraclelogonid = rec.assignedstaff)
                        SELECT TRIM(REGEXP_SUBSTR(str,
                                                  '[^,]+',
                                                  1,
                                                  LEVEL))    str
                          FROM data
                    CONNECT BY REGEXP_SUBSTR(str,
                                             '[^,]+',
                                             1,
                                             LEVEL)
                                   IS NOT NULL);

        lv_csv_row :=
            TRANSLATE(
                '"'
                || rec.officename
                || '","'
                || rec.licensenumber
                || '",'
                || rec.lspapplicationid
                || ',"'
                || rec.eventstartdate
                || '","'
                || rec.eventenddate
                || '","'
                || rec.eventtype
                || '","'
                || rec.othereventtype
                || '","'
                || rec.sponsoringorganization
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
                || rec.assignedstaff
                || '","'
                || lv_offices ---AssignedUserOffices
                || '","'
                || rec.cateringauthorizationapplicationcreatedate
                || '","',
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
END pendingcateringapplications;
/
