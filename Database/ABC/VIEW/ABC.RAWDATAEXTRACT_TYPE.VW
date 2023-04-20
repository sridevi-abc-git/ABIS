CREATE OR REPLACE FORCE VIEW ABC.RAWDATAEXTRACT_TYPE
(TYPE_ID, LICOBJECTID, APP_OR_LIC, LICENSENO, OFFICENUMBER, 
 PRIMARYLICENSEE, PRIMARYDBA, CENSUSTRACT, GEOCODE, OFFICENAME, 
 OFFICEDIVISION, PREMADDRESSLINE1, PREMADDRESSLINE2, PREMADDRESSLINE3, PREMCITY, 
 PREMSTATE, PREMZIP, PREMCENSUSTRACT, PREMGEOCODE, PREMCOUNTYCODE, 
 PREMCOUNTYNAME, MAILADDRESSLINE1, MAILADDRESSLINE2, MAILADDRESSLINE3, MAILCITY, 
 MAILSTATE, MAILZIP, LICENSE_TYPE_CODE, LICENSE_TYPE_NAME, TYPE_STATUS_CODE, 
 STATUS_DATE, NEXT_ISSUE_DATE, TERM, MASTER_IND, DUPLICATE_COUNT, 
 FEE_CODE, TYPE_ORIGINAL_ISSUE_DATE, TRANSFERREDFROM, TRANSFERREDTO, CONDITIONLIST)
BEQUEATH DEFINER
AS 
SELECT 
  lt.objectid license_types_eid,
  lt.licensejobid job_obj_id,
  'LIC' app_or_lic,
  lt.licensenumber,
  lt.basefileofficecode,
  lt.primarylicensee,
  lt.primarydba,
  lt.licensecensustract
  censustract,
  lt.licensegeocode
  geocode,
  ( SELECT UPPER (o.officename)
    FROM mart.office  mo
    JOIN mart.license l ON l.basefileofficeid = mo.objectid
    JOIN QUERY.o_office o ON mo.objectid = o.objectid
    WHERE l.jobid = lt.licensejobid
  ) officename,
  ( SELECT UPPER (o.division)
    FROM mart.office  mo
    JOIN mart.license l ON l.basefileofficeid = mo.objectid
    JOIN QUERY.o_office o ON mo.objectid = o.objectid
    WHERE l.jobid = lt.licensejobid
  ) officediv,
  -- Prem Address --
  abc.getmart_premaddline1 (lt.licensejobid)  premaddressline1,
  abc.getmart_premaddline2 (lt.licensejobid)  premaddressline2,
  abc.getmart_premaddline3 (lt.licensejobid)  premaddressline3,
  abc.getmart_premcity (lt.licensejobid)      premcity,
  abc.getmart_premstate (lt.licensejobid)     premstate,
  abc.getmart_premzip (lt.licensejobid)       premzip,
  abc.getmart_premcensustract (lt.licensejobid)  premcensustract,
  abc.getmart_premgeocode (lt.licensejobid)   premgeocode,
  abc.getmart_premcountycode (lt.licensejobid)  premcountycode,
  abc.getmart_premcountyname (lt.licensejobid)  premcountyname,
  -- Mail Address --
  abc.getmart_mailaddline1 (lt.licensejobid)  mailaddressline1,
  abc.getmart_mailaddline2 (lt.licensejobid)  mailaddressline2,
  abc.getmart_mailaddline3 (lt.licensejobid)  mailaddressline3,
  abc.getmart_mailcity (lt.licensejobid)    mailcity,
  abc.getmart_mailstate (lt.licensejobid)   mailstate,
  abc.getmart_mailzip (lt.licensejobid)     mailzip,
  ltc.licensetypecode
  license_type_code,
  ltc.licensetypename
  license_type_name,
  NVL (
    DECODE (
      INITCAP (r.status),
      'Active', 'ACTIVE',
      'Auto Revoked', 'AUTREV',
      'Canceled', 'CANCEL',
      'Department Revoked', 'DEPREV',
      'Issued', 'ISSUED',
      'Issue Pending', 'ISSUPD',
      'Non-Renewed', 'NREN',
      'Pending', 'PEND',
      'Ready To Issue', 'RDISSU',
      'Rev Pending', 'REVPEN',
      'Rule 64B', 'R64B',
      'SLMS Hold', 'SLMSHD',
      'SLMS Revoked', 'SLMSRV',
      'Surrendered', 'SUREND',
      'Suspended', 'SUSPEN',
      'Withdrawn', 'WTHDRN'
    ),
    lt.statusname
  ) type_status_code,
  --to_char(lt.STATUSDATECORRAL, 'DD-MON-YYYY') Status_Date,
  TO_CHAR( NVL(r.effectivedate, lt.statusdatecorral), 'DD-MON-YYYY' ) status_date,
  TO_CHAR (lt.expirationdate, 'DD-MON-YYYY') next_issue_date, 
  NVL (
    '12',
    DECODE (
      lt.numberofmonthslicensed,
      '1 MONTH', 1,
      '2 MONTHS', 2,
      '3 MONTHS', 3,
      '4 MONTHS', 4,
      '5 MONTHS', 5,
      '6 MONTHS', 6,
      '7 MONTHS', 7,
      '8 MONTHS', 8,
      '9 MONTHS', 9
    )
  ) term,
  --r.Primary Master_ind,
  DECODE (r.licensetypecount, NULL, 'Y', 'N') master_ind,
  r.licensetypecount duplicate_count,
  lt.feeschedulecode fee_code,
  TO_CHAR (lt.issuedate, 'DD-MON-YYYY') type_original_issue_date,
  lt.transferredfrom,
  lt.transferredto,
  lt.conditionlist
FROM mart.licensetype  lt
JOIN mart.primaryandsecondarylicencetype r
  ON lt.objectid = r.licensetypeobjectid
JOIN mart.licensetypecategory ltc
  ON r.licensecetypecategoryobjectid = ltc.objectid
/* To Disgard Orphand Records (License Types) */
WHERE lt.licensejobid IS NOT NULL

-- Temporary Permits 
UNION ALL
SELECT 
  lt.objectid
  license_types_eid,
  lt.licensejobid
  job_obj_id,
  'LIC' app_or_lic,
  lt.licensenumber,
  lt.basefileofficecode,
  lt.primarylicensee,
  lt.primarydba,
  lt.licensecensustract
  censustract,
  lt.licensegeocode
  geocode,
  (SELECT UPPER (o.officename)
  FROM mart.office  mo
  JOIN mart.license l ON l.basefileofficeid = mo.objectid
  JOIN QUERY.o_office o ON mo.objectid = o.objectid
  WHERE l.jobid = lt.licensejobid)
  officename,
  (SELECT UPPER (o.division)
  FROM mart.office  mo
  JOIN mart.license l ON l.basefileofficeid = mo.objectid
  JOIN QUERY.o_office o ON mo.objectid = o.objectid
  WHERE l.jobid = lt.licensejobid)
  officediv,
  -- Prem Address --
  abc.getmart_premaddline1 (lt.licensejobid)  premaddressline1,
  abc.getmart_premaddline2 (lt.licensejobid)  premaddressline2,
  abc.getmart_premaddline3 (lt.licensejobid)  premaddressline3,
  abc.getmart_premcity (lt.licensejobid)  premcity,
  abc.getmart_premstate (lt.licensejobid)  premstate,
  abc.getmart_premzip (lt.licensejobid)  premzip,
  abc.getmart_premcensustract (lt.licensejobid)  premcensustract,
  abc.getmart_premgeocode (lt.licensejobid)  premgeocode,
  abc.getmart_premcountycode (lt.licensejobid)  premcountycode,
  abc.getmart_premcountyname (lt.licensejobid)  premcountyname,
  -- Mail Address --
  abc.getmart_mailaddline1 (lt.licensejobid)  mailaddressline1,
  abc.getmart_mailaddline2 (lt.licensejobid)  mailaddressline2,
  abc.getmart_mailaddline3 (lt.licensejobid)  mailaddressline3,
  abc.getmart_mailcity (lt.licensejobid)  mailcity,
  abc.getmart_mailstate (lt.licensejobid)  mailstate,
  abc.getmart_mailzip (lt.licensejobid)  mailzip,
  '30'  license_type_code,
  'Temporary Permit'  license_type_name,
  DECODE (
    (TRUNC (tp.effectiveto))
    - (TRUNC (SYSDATE))
    - ABS ((TRUNC (tp.effectiveto)) - (TRUNC (SYSDATE))),
    0, 'ISSUED',
    'EXPIRED'
  ) type_status_code,
  TO_CHAR (tp.datecompleted, 'DD-MON-YYYY')  status_date,
  TO_CHAR (tp.effectiveto, 'DD-MON-YYYY')  next_issue_date,
  '4'  term,
  NULL  master_ind,
  NULL  duplicate_count,
  NULL  fee_code,
  TO_CHAR (tp.effectivefrom, 'DD-MON-YYYY')  type_original_issue_date,
  NULL  transferredfrom,
  NULL  transferredto,
  NULL  conditionlist
FROM mart.licensetype  lt
JOIN mart.temporarypermit tp ON tp.jobid = lt.licensejobid
  
-- APPLICATIONS --
UNION ALL
SELECT 
  a.objectid
  license_types_eid,
  a.applicationobjectid
  job_obj_id,
  'APP'  app_or_lic,
  a.licensenumber,
  a.basefileofficecode,
  a.primarylicensee,
  a.primarydba,
  a.applicationcensustract
  censustract,
  a.applicationgeocode
  geocode,
  (SELECT UPPER (o.officename)
  FROM mart.office  mo
  JOIN mart.application l ON l.basefileofficeid = mo.objectid
  JOIN QUERY.o_office o ON mo.objectid = o.objectid
  WHERE l.objectid = a.applicationobjectid)
  officename,
  ( SELECT UPPER (o.division)
    FROM mart.office  mo
    JOIN mart.application l ON l.basefileofficeid = mo.objectid
    JOIN QUERY.o_office o ON mo.objectid = o.objectid
    WHERE l.objectid = a.applicationobjectid
  ) officediv,
  -- Prem Address --
  abc.getmart_premaddline1 (a.applicationobjectid)  premaddressline1,
  abc.getmart_premaddline2 (a.applicationobjectid)  premaddressline2,
  abc.getmart_premaddline3 (a.applicationobjectid)  premaddressline3,
  abc.getmart_premcity (a.applicationobjectid)  premcity,
  abc.getmart_premstate (a.applicationobjectid)  premstate,
  abc.getmart_premzip (a.applicationobjectid)  premzip,
  abc.getmart_premcensustract (a.applicationobjectid)  premcensustract,
  abc.getmart_premgeocode (a.applicationobjectid)  premgeocode,
  abc.getmart_premcountycode (a.applicationobjectid)  premcountycode,
  abc.getmart_premcountyname (a.applicationobjectid)  premcountyname,
  -- Mail Address --
  abc.getmart_mailaddline1 (a.applicationobjectid)  mailaddressline1,
  abc.getmart_mailaddline2 (a.applicationobjectid)  mailaddressline2,
  abc.getmart_mailaddline3 (a.applicationobjectid)  mailaddressline3,
  abc.getmart_mailcity (a.applicationobjectid)  mailcity,
  abc.getmart_mailstate (a.applicationobjectid)  mailstate,
  abc.getmart_mailzip (a.applicationobjectid)  mailzip,
  ltc.licensetypecode  license_type_code,
  ltc.licensetypename  license_type_name,
  NVL (
    DECODE (
      pslt.status,
      UPPER ('Active'), 'ACTIVE',
      UPPER ('Auto Revoked'), 'AUTREV',
      UPPER ('Canceled'), 'CANCEL',
      UPPER ('Denied'), 'DENIED',
      UPPER ('Department Revoked'), 'DEPREV',
      UPPER ('Issued'), 'ISSUED',
      UPPER ('Issue Pending'), 'ISSUPD',
      UPPER ('Non-Renewed'), 'NREN',
      UPPER ('Pending'), 'PEND',
      UPPER ('Ready To Issue'), 'RDISSU',
      UPPER ('Rev Pending'), 'REVPEN',
      UPPER ('Rule 64B'), 'R64B',
      UPPER ('SLMS Hold'), 'SLMSHD',
      UPPER ('SLMS Revoked'), 'SLMSRV',
      UPPER ('Surrendered'), 'SUREND',
      UPPER ('Suspended'), 'SUSPEN',
      UPPER ('Voided'), 'VOIDED',
      UPPER ('Withdrawn'), 'WTHDRN'
    ),
    DECODE (
      a.status,
      UPPER ('Active'), 'ACTIVE',
      UPPER ('Auto Revoked'), 'AUTREV',
      UPPER ('Canceled'), 'CANCEL',
      UPPER ('Denied'), 'DENIED',
      UPPER ('Department Revoked'), 'DEPREV',
      UPPER ('Issued'), 'ISSUED',
      UPPER ('Issue Pending'), 'ISSUPD',
      UPPER ('Non-Renewed'), 'NREN',
      UPPER ('Pending'), 'PEND',
      UPPER ('Ready To Issue'), 'RDISSU',
      UPPER ('Rev Pending'), 'REVPEN',
      UPPER ('Rule 64B'), 'R64B',
      UPPER ('SLMS Hold'), 'SLMSHD',
      UPPER ('SLMS Revoked'), 'SLMSRV',
      UPPER ('Surrendered'), 'SUREND',
      UPPER ('Suspended'), 'SUSPEN',
      UPPER ('Voided'), 'VOIDED',
      UPPER ('Withdrawn'), 'WTHDRN'
    )
  ) type_status_code,
  TO_CHAR (a.statusdatecorral, 'DD-MON-YYYY')  status_date,
  NULL  next_issue_date,
  NVL (
    '12',
    DECODE (
      a.numberofmonthslicensed,
      '1 MONTH', 1,
      '2 MONTHS', 2,
      '3 MONTHS', 3,
      '4 MONTHS', 4,
      '5 MONTHS', 5,
      '6 MONTHS', 6,
      '7 MONTHS', 7,
      '8 MONTHS', 8,
      '9 MONTHS', 9
    )
  ) term,
  DECODE (
    a.IsBranchS,
    'Y', 'N',
    DECODE (pslt.ObjectDefName, 'r_PriLTLTCatPrimary', 'Y', 'N')
  ) master_ind,
  pslt.licensetypecount  duplicate_count,
  a.feeschedulecode  fee_code,
  NULL  type_orginal_issue_date,
  a.transferfromltfilenum  transferredfrom,
  NULL  transferredto,
  a.conditionlist
FROM mart.applictype  a
JOIN mart.primaryandsecondaryapplictype pslt
  ON a.objectid = pslt.primlictypeobjectid
JOIN mart.licensetypecategory ltc
  ON pslt.liccategoryobjectid = ltc.objectid
WHERE     a.status NOT IN ('ISSUED')
/* To Disgard Orphand Records (Application License Types) */
AND a.applicationobjectid IS NOT NULL
/* To Disgard Primary Types with Applicatioin with specific Statuses:  Example if Application if Voided all types should be Voided as well. */
AND NOT EXISTS (
  SELECT 'x'
  FROM mart.applictype  a2
   JOIN mart.primaryandsecondaryapplictype pslt2
     ON a2.objectid = pslt2.primlictypeobjectid
   JOIN mart.licensetypecategory ltc2
     ON pslt2.liccategoryobjectid = ltc2.objectid
  WHERE a2.objectid = a.objectid
  AND (    
    a2.status IN ('ACTIVE', 'PENDING', 'ISSUE PENDING')
    AND a2.applicationstatus IN ('WTHDRN','VOIDED','DENIED','PRVOID')
  )
)
/* To Disgard Secondary Types with Applicatioin with specific Statuses: */
AND NOT EXISTS ( 
  SELECT 'x'
  FROM mart.applictype  a3
  JOIN mart.primaryandsecondaryapplictype pslt3
    ON a3.objectid = pslt3.primlictypeobjectid
  JOIN mart.licensetypecategory ltc3
    ON pslt3.liccategoryobjectid = ltc3.objectid
  WHERE a3.objectid = a.objectid
  AND ( 
    pslt3.status IN ('ACTIVE', 'PENDING', 'ISSUE PENDING')
    AND a3.applicationstatus IN ('WTHDRN','VOIDED','DENIED','PRVOID')
  )
)
                                     
-- TEMPORARY PERMITS APPLICATIONS --
UNION ALL
SELECT 
  a.objectid
  license_types_eid,
  a.applicationobjectid job_obj_id,
  'APP' app_or_lic,
  a.licensenumber,
  a.basefileofficecode,
  a.primarylicensee,
  a.primarydba,
  a.applicationcensustract censustract,
  a.applicationgeocode geocode,
  ( 
    SELECT UPPER (o.officename)
    FROM mart.office  mo
    JOIN mart.application l ON l.basefileofficeid = mo.objectid
    JOIN QUERY.o_office o ON mo.objectid = o.objectid
    WHERE l.objectid = a.applicationobjectid
  ) officename,
  ( 
    SELECT UPPER (o.division)
    FROM mart.office  mo
    JOIN mart.application l ON l.basefileofficeid = mo.objectid
    JOIN QUERY.o_office o ON mo.objectid = o.objectid
    WHERE l.objectid = a.applicationobjectid
  ) officediv,
  -- Prem Address --
  abc.getmart_premaddline1 (a.applicationobjectid)  premaddressline1,
  abc.getmart_premaddline2 (a.applicationobjectid)  premaddressline2,
  abc.getmart_premaddline3 (a.applicationobjectid)  premaddressline3,
  abc.getmart_premcity (a.applicationobjectid)  premcity,
  abc.getmart_premstate (a.applicationobjectid)  premstate,
  abc.getmart_premzip (a.applicationobjectid)  premzip,
  abc.getmart_premcensustract (a.applicationobjectid)  premcensustract,
  abc.getmart_premgeocode (a.applicationobjectid)  premgeocode,
  abc.getmart_premcountycode (a.applicationobjectid)  premcountycode,
  abc.getmart_premcountyname (a.applicationobjectid)  premcountyname,
  -- Mail Address --
  abc.getmart_mailaddline1 (a.applicationobjectid)  mailaddressline1,
  abc.getmart_mailaddline2 (a.applicationobjectid)  mailaddressline2,
  abc.getmart_mailaddline3 (a.applicationobjectid)  mailaddressline3,
  abc.getmart_mailcity (a.applicationobjectid)  mailcity,
  abc.getmart_mailstate (a.applicationobjectid)  mailstate,
  abc.getmart_mailzip (a.applicationobjectid)  mailzip,
  '30'  license_type_code,
  'Temporary Permit'  license_type_name,
  DECODE (
    (TRUNC (tp.effectiveto))
    - (TRUNC (SYSDATE))
    - ABS ((TRUNC (tp.effectiveto)) - (TRUNC (SYSDATE))),
    0, 'ISSUED',
    'EXPIRED'
  )  type_status_code,
  TO_CHAR (tp.datecompleted, 'DD-MON-YYYY')  status_date,
  NULL  next_issue_date,
  '4'  term,
  NULL  master_ind,
  NULL  duplicate_count,
  NULL  fee_code,
  TO_CHAR (tp.effectivefrom, 'DD-MON-YYYY')  type_orginal_issue_date,
  NULL  transferredfrom,
  NULL  transferredto,
  NULL  conditionlist
FROM mart.applictype  a
JOIN mart.temporarypermit tp ON tp.jobid = a.applicationobjectid
WHERE a.applicationstatus NOT IN ('ISSUED');


GRANT SELECT ON ABC.RAWDATAEXTRACT_TYPE TO POSSEEXTENSIONS;

GRANT SELECT ON ABC.RAWDATAEXTRACT_TYPE TO PUBLIC;
