CREATE OR REPLACE FUNCTION ABCREPORTS.jus750(p_parms IN OUT t_parameters, p_status_ind IN OUT VARCHAR2)
    RETURN BLOB
IS
    -- ****************************************************************************
    -- File:        JUS750.FNC
    -- Author:      Pawanjit Kaur
    --
    -- Description:
    --
    --
    -- History:
    -------------------------------------------------------------------------------
    --    Date                  Comment
    -- 06/15/2023 PK  31462   Report function created
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
        IN (  SELECT   
                   '"' 
                 || i.abcreportnumber
                 || '","'
                 || ac.lastname
                       || NVL2(ac.lastname, ', ', ac.lastname)
                       || ac.firstname
                       || ' '
                       || ac.middlename
                 
                 || '","'
                 || ac.race
                 || '","'
               || TO_CHAR(ac.birthdate, 'MM/DD/YYYY')
               || '","'
               ||TO_CHAR(CASE
                       WHEN ac.birthdate > ADD_MONTHS(ac.arrestdate, -(18 * 12)) THEN 'Y'
                       ELSE ' '
                   END)
               || '","'   
               || ac.gender
               || '","'
               || TO_CHAR(ac.arrestdate, 'MM/DD/YYYY') 
               || '","'
               || ac.violationlevel 
               || '","'
               || ac.charges
               || '","'
               ||ac.violationstatus
               || '","'             
               ||ac.arrestinginvestigator 
               || '","'
               || o.ORINUMBER
               || '","'
               || o.DISPLAYFORMAT
                 || '"'
                         info
                 
             
          FROM query.o_office o
               LEFT OUTER JOIN query.r_investigationoffice io
                   ON io.officeobjectid = o.objectid
               LEFT OUTER JOIN query.j_investigation i
                   ON i.jobid = io.investigationjobid
               LEFT OUTER JOIN query.r_investigationarrestcitation iac
                   ON iac.investigationjobid = i.jobid
               LEFT OUTER JOIN query.o_arrestcitation ac
                   ON ac.objectid = iac.arrestcitationobjectid
         WHERE o.OBJECTID IN (SELECT o.objectid
                                             FROM TABLE(office_id) l
                                             JOIN query.o_office o
                                              ON (l.officeobjectid = o.objectid))
           AND ac.casetype != 'JOINT'
           AND ( TRUNC (ac.arrestdate)  BETWEEN ld_start AND ld_end
                OR ac.arrestdate IS NULL)
           AND NOT (AC.LastName IS NULL AND AC.CitationNumber IS NULL AND I.AbcReportNumber IS NULL) 
           AND EXISTS
                  (SELECT 1
                     FROM query.r_investigationarrestcitation r
                    WHERE r.investigationjobid = i.jobid)
        
             ORDER BY i.abcreportnumber,  o.DISPLAYFORMAT)
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
                      p_source    => 'jus750',
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


GRANT EXECUTE ON ABCREPORTS.JUS750 TO ABCREPORTS_ROLE;
