CREATE OR REPLACE FUNCTION ABCREPORTS.CDTFAextract(
  p_parms IN OUT t_parameters, 
  p_status_ind IN OUT VARCHAR2
)
  RETURN BLOB
IS
-- ****************************************************************************
-- File:        CDTFAEXTRACT.fnc
-- Author:      Timothy J. Lord
--
-- $Rev: 423 $
-- $Date: 2020-03-20 11:15:38 -0700 (Fri, 20 Mar 2020) $
-- Last Changed By:  $Author: TLord $
--
-- Description: This function creates a daily extract for California Department
--              of Tax and Fee Administration (CDTFA).  It contains information
--              on new licenses, suspended licenses, and surrendered licenses.
--              Fields will be piped delimited in extracted records.
--
-- History:
-------------------------------------------------------------------------------
--    Date                      Comment
-- 08/31/2017 TJL   13031   Initial file created
-- 04/12/2018 TJL   15113   Added filtering out CRLF in extracted columns
-- 09/14/2018 TJL   16307   Added code to check that previous day was sent and
--                          if not, add previous days data to current data.
--                          This fix only applies to daily extract.
-- 01/08/2020 TJL   20316   Change data selection date to be previous date
--                          instead of current date. Report runs at midnight
--                          so current date will not have data in MART.
-- 02/11/2020 TJL   20316   Re-wrote how start and end dates are calculated.
-- 03/02/2020 TJL   20316   Added pending licenses to extract.
-- 01/19/2022  PK   27313   Daily ABC License file to CDTFA
-- 04/19/2022  NW   28102   CDTFA says it has missing/empty address fields 
-- ****************************************************************************

CURSOR cur_data(
  p_start_date   IN DATE,
  p_end_date     IN DATE
)
IS
WITH CDTFA AS (      

  -- Q1 Licenses
  SELECT DISTINCT 
    LT.LICENSEJOBID OBJECTID,
    LT.objectid TYPEOBJECTID,
    TO_CHAR(LT.issuedate, 'MM/DD/YYYY') ORIG_ISS_DATE,
    TO_CHAR(LT.expirationdate, 'MM/DD/YYYY') EXPIR_DATE,
    NULL AMOUNTDUE,
    ltc.LICENSETYPECODE,
    LT.STATUSNAME, -- changes to Lt.statusname from statusname Pawan
    NVL(r.effectivedate, LT.statusdatecorral) STATUS_DAT,
    'LIC' APPLIC,
    RP.PREMISESOBJECTID PREMISESOBJECTID,  
    NVL(RM.MAOBJECTID,RP.PREMISESOBJECTID) MAILINGOBJECTID
    
  FROM MART.licensetype LT
  JOIN MART.primaryandsecondarylicencetype r  ON LT.objectid = r.licensetypeobjectid
  JOIN MART.licensetypecategory ltc ON r.licensecetypecategoryobjectid = ltc.objectid
  JOIN EXTENSION.jobstatuschange s  ON s.jobid = LT.ObjectId -- added these 3 lines and commented below line--Pawan
  
  LEFT JOIN QUERY.R_LICENSEADDRPREMISES RP ON RP.LICENSEJOBID=LT.LICENSEJOBID 
  LEFT JOIN QUERY.R_LICENSEADDRMAILING RM ON RM.LICENSEJOBID=LT.LICENSEJOBID 

  WHERE 1=1 
    AND TRUNC(s.statusdate) BETWEEN p_start_date AND p_end_date
    AND LT.statusname NOT IN ('REVPEN','SUREND')
    AND LT.StatusName <> LT.FromStatus

  UNION ALL
  -- Q2 Licneses
  SELECT DISTINCT 
    LT.LICENSEJOBID OBJECTID,
    lt.objectid  typeobjectid,
    TO_CHAR(tp.effectivefrom, 'MM/DD/YYYY')  orig_iss_date,
    TO_CHAR(tp.effectiveto, 'MM/DD/YYYY')  expir_date,
    NULL AMOUNTDUE,
    '30',
    CASE 
      (TRUNC(tp.effectiveto))
      - (TRUNC(SYSDATE))
      - ABS((TRUNC(tp.effectiveto)) - (TRUNC(SYSDATE)))
    WHEN 0 THEN
      'Issued-Temp.'
    ELSE
      'Expired'
    END STATUSNAME,
    NULL STATUS_DAT,
    'LIC' APPLIC,
    RP.PREMISESOBJECTID PREMISESOBJECTID,  
    NVL(RM.MAOBJECTID,RP.PREMISESOBJECTID) MAILINGOBJECTID

  FROM mart.licensetype LT
  JOIN mart.temporarypermit TP ON TP.jobid = LT.licensejobid
  LEFT JOIN QUERY.R_LICENSEADDRPREMISES RP ON RP.LICENSEJOBID=LT.LICENSEJOBID 
  LEFT JOIN QUERY.R_LICENSEADDRMAILING RM ON RM.LICENSEJOBID=LT.LICENSEJOBID 
  WHERE TRUNC(tp.effectivefrom) BETWEEN p_start_date AND p_end_date

  UNION ALL
  -- Q3 Licenses
  SELECT DISTINCT 
    lt.licensejobid                                         objectid,
    lt.objectid                                             typeobjectid,
    TO_CHAR(lt.issuedate, 'MM/DD/YYYY')                     orig_iss_date,
    TO_CHAR(lt.expirationdate, 'MM/DD/YYYY')                expir_date,
    CASE WHEN lt.amountdue < 0 THEN 0 ELSE lt.amountdue END amountdue,
    lt.licensetypecode,
    lt.statusdescription                                    statusname,
    NVL(r.effectivedate, lt.statusdatecorral)               status_dat,
    'LIC'                                                   applic,
    RP.PREMISESOBJECTID PREMISESOBJECTID,  
    NVL(RM.MAOBJECTID,RP.PREMISESOBJECTID) MAILINGOBJECTID

  FROM mart.licensetype lt
  JOIN mart.primaryandsecondarylicencetype r ON lt.objectid = r.licensetypeobjectid
  JOIN mart.licensetypecategory ltc ON r.licensecetypecategoryobjectid = ltc.objectid
  LEFT JOIN QUERY.R_LICENSEADDRPREMISES RP ON RP.LICENSEJOBID=LT.LICENSEJOBID 
  LEFT JOIN QUERY.R_LICENSEADDRMAILING RM ON RM.LICENSEJOBID=LT.LICENSEJOBID 

  WHERE (
    (
      ( ltc.licensetypecode IN ('20', '21') OR ltc.licensetypecode BETWEEN '40' AND '80')
      AND lt.statusname = 'SUREND'
    )
    OR lt.statusname = 'REVPEN'
  )
    AND TRUNC(NVL(r.effectivedate, lt.statusdatecorral))BETWEEN p_start_date AND p_end_date


  UNION ALL
  -- Q4 Applications
  SELECT distinct 
  A.APPLICATIONOBJECTID  objectid,
  a.objectid  typeobjectid,
  TO_CHAR(tp.effectivefrom, 'MM/DD/YYYY')  orig_iss_date,
  TO_CHAR(tp.effectiveto, 'MM/DD/YYYY')  expir_date,
  NULL  amountdue,
  '30'  licensetypecode,
  CASE   
    (TRUNC(tp.effectiveto))
    - (TRUNC(SYSDATE))
    - ABS((TRUNC(tp.effectiveto)) - (TRUNC(SYSDATE)))
  WHEN 0 THEN
    'Issued-Temp.'
  ELSE
    'Expired'
  END  STATUSNAME,
  NULL STATUS_DAT,
  'APP'  APPLIC,
  RP.ADDRESSOBJECTID PREMOBJECTID,  
  NVL(RM.ADDRESSOBJECTID,RP.ADDRESSOBJECTID ) MAILINGOBJECTID    
  
  FROM mart.applictype A
  JOIN mart.temporarypermit TP ON tp.jobid = a.applicationobjectid
  
  LEFT JOIN QUERY.R_APPLICATIONPREMADDR RP ON RP.APPLICATIONJOBID=A.APPLICATIONOBJECTID
  LEFT JOIN QUERY.R_APPLICATIONMAILADDR RM ON RM.APPLICATIONJOBID=A.APPLICATIONOBJECTID
  
  WHERE 1=1
  AND TRUNC(tp.effectivefrom) BETWEEN p_start_date AND p_end_date
    AND a.licenseexists = 'N'
    
  UNION ALL
  -- Q5 Applications
  SELECT DISTINCT 
    a.objectid objectid, 
    a.objectid typeobjectid,
    NULL orig_iss_date,
    NULL expir_date,
    NULL amountdue,
    ltc.licensetypecode,
    a.status statusname,
    TO_Date(substr(a.statusdate,1,10), 'YYYY-MM-DD')  STATUS_DAT,
    'APP' APPLIC,
    RP.ADDRESSOBJECTID PREMOBJECTID,  
    NVL(RM.ADDRESSOBJECTID,RP.ADDRESSOBJECTID ) MAILINGOBJECTID    

  FROM Mart.Applictype A 
  JOIN mart.primaryandsecondaryapplictype pslt ON a.ObjectId = pslt.PRIMLICTYPEOBJECTID 
  JOIN mart.licensetypecategory ltc ON pslt.LICCATEGORYOBJECTID = ltc.ObjectId 
  JOIN extension.jobstatuschange s ON s.jobid = a.ObjectId -- added this join--Pawan
  LEFT JOIN QUERY.R_APPLICATIONPREMADDR RP ON RP.APPLICATIONJOBID=A.APPLICATIONOBJECTID
  LEFT JOIN QUERY.R_APPLICATIONMAILADDR RM ON RM.APPLICATIONJOBID=A.APPLICATIONOBJECTID

  WHERE a.status not in ('ISSUED','VOIDED','NEW')  -- added New to it by Pawan on 01/20/2022 as per cdtfa
  AND trunc(a.STATUSDATECORRAL) BETWEEN p_start_date AND p_end_date
    
)
SELECT  REPLACE( REPLACE(
  -- Column 1 - License Number
  API.PKG_COLUMNQUERY.VALUE(a.objectid, 'licensenumber')  || '|'  ||    
  -- Column 2 - MI (master Y/N)  
  CASE NVL(
      NVL(API.PKG_COLUMNQUERY.VALUE(a.typeobjectid, 'SecondaryLicenseTypeCount'),
      API.PKG_COLUMNQUERY.VALUE(a.objectid, 'SecondaryCount')),
      0
    )
  WHEN '0' THEN
    'Y'
  ELSE
    'N'
  END  || '|' ||  
  -- Column 3 - Status
  statusname  || '|'  ||  
  -- Colunm 4 - Type
  licensetypecode  || '|'  ||  
  -- Column 5 - Type Status Date
  to_char(status_dat, 'MM/DD/YYYY')  || '|'  ||  
  -- Column 6 - Dup
  NVL( 
    NVL(
      API.PKG_COLUMNQUERY.VALUE(a.typeobjectid, 'SecondaryLicenseTypeCount'),
      API.PKG_COLUMNQUERY.VALUE(a.objectid, 'SecondaryCount')    
    ), 0
  )  || '|'  ||  
  -- Column 7 - Original Issue Date
  orig_iss_date  || '|'  ||  
  -- Column 8 - Expiration Date
  expir_date  || '|'  ||  
  -- Column 9 - Primary Owner's Name
  API.PKG_COLUMNQUERY.VALUE(a.objectid, 'PrimaryLicensee')  || '|'  ||  
  -- Column 10 - DBA
  API.PKG_COLUMNQUERY.VALUE(a.objectid, 'PrimaryDBA')  || '|'  ||

  -- Column 11 - Premise Street Address 1
  API.PKG_COLUMNQUERY.VALUE(PremisesObjectid, 'ADDRESSLINE1') || '|'  ||
  -- Column 12 - Premise Street Address 2
  API.PKG_COLUMNQUERY.VALUE(PremisesObjectid, 'ADDRESSLINE2') || '|'  ||  
  -- Column 13 - Premises City
  API.PKG_COLUMNQUERY.VALUE(PremisesObjectid, 'CACITY') || '|'  ||  
  -- Column 14 - Premises State
  API.PKG_COLUMNQUERY.VALUE(PremisesObjectid, 'USASTATECODE') || '|'  ||  
  -- Column 15 - Premises Zipcode
  API.PKG_COLUMNQUERY.VALUE(PremisesObjectid, 'ZIPCODE') || '|'  ||


  -- Column 16 - Mailing Address 1
  API.PKG_COLUMNQUERY.VALUE(MailingObjectId, 'ADDRESSLINE1') || '|'  ||  
  -- Column 17 - Mail Address 2
  API.PKG_COLUMNQUERY.VALUE(MailingObjectId, 'ADDRESSLINE2') || '|'  ||
  -- Column 18 - Mailing City
  API.PKG_COLUMNQUERY.VALUE(MailingObjectId, 'USACITY') || '|'  ||
  -- Column 19 - Mailing State
  API.PKG_COLUMNQUERY.VALUE(MailingObjectId, 'USASTATECODE') || '|'  ||
  -- Column 20 - Mailing Zipcode
  API.PKG_COLUMNQUERY.VALUE(MailingObjectId, 'ZIPCODE') || '|'  ||

  -- Column 21 - Action
  API.PKG_COLUMNQUERY.VALUE(a.typeobjectid, 'IssueType')  || '|'  ||  
  -- Column 22 - Conditions
  API.PKG_COLUMNQUERY.VALUE(a.typeobjectid, 'ConditionList')  || '|'  ||  
  -- Column 23 - Escrow Company
  API.PKG_COLUMNQUERY.VALUE(a.objectid, 'EscrowCompanyName')  || '|'  ||  
  -- Column 24 - Escrow Address (address, city, state, zip)
  REGEXP_REPLACE(
    API.PKG_COLUMNQUERY.VALUE(a.objectid, 'EscrowAddress'),
    '[[:cntrl:]]',  ' '
  )  || '|'  ||  
  -- Column 25 - District Code
  API.PKG_COLUMNQUERY.VALUE(a.objectid, 'BaseFileOfficeCodeCorral')  || '|'  ||  
  -- Column 26 - Geo Code
  NVL(
    API.PKG_COLUMNQUERY.VALUE(a.typeobjectid, 'LicenseGeoCode'),
    API.PKG_COLUMNQUERY.VALUE(a.typeobjectid, 'ApplicationGeoCode')
  )  || '|'  ||  
  -- Column 27 - Amount Due
  amountdue  || '|'  ||  
  -- Column 28 - License or Application
  applic  || '|'  ||  
  -- Column 29 - Fee Codes
  API.PKG_COLUMNQUERY.VALUE(a.typeobjectid, 'feeschedulecode')  || '|'  ||  
  -- Column 30 - Term in # of Months
  SUBSTR(NVL(
    API.PKG_COLUMNQUERY.VALUE(a.typeobjectid, 'numberofmonthslicensed'), '
    12'
  ),  1,  2 )  || '|'  ||
  -- Column 31 - Premise County
  API.PKG_COLUMNQUERY.VALUE(PremisesObjectid, 'COUNTYNAME') 
  ,  CHR(13),  ''  ),  CHR(10),  '')  || CHR(13)  || CHR(10)  
  
  RPT_DATA
  
FROM CDTFA A;
--WHERE ROWNUM < 20


  lblob_data      BLOB;
  lv_msg          VARCHAR2(8196);
  ld_start_date   DATE;
  ld_end_date     DATE;

BEGIN
  -- ********************************************************************
  -- 02/11/2020 TJL   20316 new code
  -- ********************************************************************

  IF (p_parms.get_value('START_DATE') IS NOT NULL) THEN
    ld_start_date   := TO_DATE(p_parms.get_value('START_DATE'), 'MM/DD/YYYY');
    ld_end_date     := NVL(TO_DATE(p_parms.get_value('END_DATE'), 'MM/DD/YYYY'), ld_start_date);
  ELSE
    ld_end_date   := TRUNC((SYSDATE - 1) - TO_NUMBER(NVL(p_parms.get_value('DAYS_BACK'), 1)));

    -- get date of last report was exported adjusted for next start date
    SELECT   
      CASE
      WHEN TRUNC(NVL(MAX(l.export_date), SYSDATE - 1)) >= TRUNC(SYSDATE - 1) THEN TRUNC(SYSDATE - 1)
      ELSE TRUNC(NVL(MAX(l.export_date), SYSDATE - 1))
      END
      - NVL(p_parms.get_value('DAYS_BACK'), 1)
      INTO ld_start_date
    FROM abcreports.report_export_log l
    JOIN abcreports.report_xref x USING (seq)
    WHERE x.report_number = 1002
      AND l.status_ind = 'C';

    p_parms.add_value('START_DATE', TO_CHAR(ld_start_date, 'MM/DD/YYYY'));
    p_parms.add_value('END_DATE', TO_CHAR(ld_end_date, 'MM/DD/YYYY'));
  END IF;

    -- 02/11/2020 TJL   20316 new End
    -- ********************************************************************

    -- create clob to save report data in.
    DBMS_LOB.createtemporary(lblob_data, TRUE);

    FOR rec IN cur_data(TRUNC(ld_start_date), TRUNC(ld_end_date))
    LOOP
        DBMS_LOB.writeappend(lblob_data, LENGTH(rec.rpt_data), UTL_RAW.cast_to_raw(rec.rpt_data));
    END LOOP;

    p_status_ind   := 'F';

    RETURN lblob_data;
EXCEPTION
  WHEN OTHERS THEN
      rqs_utils.LOG(p_log_type  => 'E',
                    p_job_id    => p_parms.get_value('JOB_ID'),
                    p_seq       => p_parms.get_value('SEQ'),
                    p_source    => 'CDTFAEXTRACT',
                    p_msg       => SQLERRM,
                    p_additional_data => NULL,
                    p_error_trace => DBMS_UTILITY.format_error_backtrace);

      lv_msg         :=
             'ERROR: '
          || SQLERRM
          || CHR(10)
          || CHR(13)
          || 'TRACE: '
          || DBMS_UTILITY.format_error_backtrace;
      p_status_ind   := 'E';
      RETURN UTL_RAW.cast_to_raw(lv_msg);
END cdtfaextract;
/
