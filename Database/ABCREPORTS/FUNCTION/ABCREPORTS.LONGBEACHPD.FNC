CREATE OR REPLACE FUNCTION ABCREPORTS.longbeachpd(p_parms      IN OUT t_parameters,
                                       p_status_ind IN OUT VARCHAR2) 
              RETURN BLOB IS
-- ****************************************************************************
-- File:        longbeachpd.fnc  
-- Author:      Timothy J. Lord
--
-- $Rev: 3044 $  
-- $Date: 2016-09-27 15:06:25 -0700 (Tue, 27 Sep 2016) $
-- Last Changed By:  $Author: tlord $
--
-- Description:    
--
-- 
-- History:
-------------------------------------------------------------------------------
--    Date                  Comment
-- 10/28/2015 TJL   8282    Updated for enhancement changes  
-- 09/27/2016 TJL   7213    Changed output from CLOB to BLOB  
-- ****************************************************************************

--*****************************************************************************
--     BUILD_TEMP (abcreports.long_beach_extract_tmp)
--*****************************************************************************
    PROCEDURE BUILD_TEMP IS
    
    BEGIN
        INSERT INTO abcreports.long_beach_extract_tmp r
                    (
                     licobjectid,
                     app_or_lic, 
                     licenseno,
                     type_status_code,
                     premgeocode,      
                     officenumber,     
                     premcensustract,  
                     primarydba,       
                     primarylicensee,  
                     premaddressline1, 
                     premaddressline2, 
                     premcity,         
                     premstate,        
                     premzip,          
                     mailaddressline1, 
                     mailaddressline2, 
                     mailcity,         
                     mailstate, 
                     mailzip, 
                     license_type_code,
                     status_date,       
                     next_issue_date,   
                     master_ind,        
                     term,             
                     duplicate_count,  
                     conditionlist,     
                     fee_code,         
                     type_original_issue_date,
                     transferredfrom,
                     transferredto 
                    )
             SELECT  licobjectid,
                     app_or_lic, 
                     licenseno,
                     type_status_code,
                     premgeocode,      
                     officenumber,     
                     premcensustract,  
                     primarydba,       
                     primarylicensee,  
                     premaddressline1, 
                     premaddressline2, 
                     premcity,         
                     premstate,        
                     premzip,          
                     mailaddressline1, 
                     mailaddressline2, 
                     mailcity,         
                     mailstate, 
                     mailzip, 
                     license_type_code,
                     status_date,       
                     next_issue_date,   
                     master_ind,        
                     term,             
                     duplicate_count,  
                     conditionlist,     
                     fee_code,         
                     type_original_issue_date,
                     transferredfrom,
                     transferredto 
               FROM  abc.rawdataextract_type d         
              WHERE  d.license_type_code NOT BETWEEN '30' and '39' 
                AND (UPPER (d.type_status_code) in 
                        ('ACTIVE', 'SLMSHD', 'SUSPEN', 'REVPEN', 
                         'SUREND', 'R64B', 'PEND','ISSUPD'))
                AND  d.licobjectid IN (
                              SELECT bl.jobobjectid 
                                FROM mart.businesslocations bl
                                JOIN mart.address ad on ad.objectid = bl.addressobjectid
                               WHERE ad.usacity = 'LONG BEACH');

        FOR x IN (SELECT t.licobjectid, COUNT(*) count1 
                    FROM abcreports.long_beach_extract_tmp t 
                   GROUP BY t.licobjectid
                   ORDER BY t.licobjectid)
        LOOP                 
            FOR i in 1..x.count1 
            LOOP
                UPDATE abcreports.long_beach_extract_tmp
                   SET recordseq=i
                 WHERE licobjectid=x.licobjectid
                   AND rownum=1
                   AND recordseq is null;
            END LOOP;
        END LOOP;
        
    END BUILD_TEMP;
    

    FUNCTION EXTRACT_150 RETURN CLOB IS

    CURSOR      cur_ IS
                  SELECT SUBSTR(TO_CHAR(NVL(d.filenum, 0), '09999999'), 2, 8) 
                          || RPAD(SUBSTR(NVL(d.recordtype, ' '), 1, 1), 1, ' ')
                          || RPAD(SUBSTR(NVL(d.recordseq, 0), 1, 2), 2, ' ')
                          || RPAD(SUBSTR(REPLACE(REPLACE(NVL(d.details, ' '), CHR(13), ' '), chr(10), ' '), 1, 139), 139, ' ')
                          || CHR(10)
                         rec
                    FROM abcreports.long_beach_data_extract d
                   WHERE type_ind = 'A'
                   ORDER BY d.filenum, d.recordtype, d.recordseq; 
    TYPE                rec_t   IS TABLE OF cur_%ROWTYPE;
                                      
    clob_               CLOB;
    rec_                rec_t;
    ln_length           NUMBER;
    inx                 NUMBER;
    
    BEGIN
        --*****************************************************************************
        --  Record Type A - Sequence 1
        --*****************************************************************************
        INSERT INTO abcreports.long_beach_data_extract
             SELECT DISTINCT  'A' type_ind,
                             SUBSTR(TO_CHAR(NVL(d.licenseno, 0), '09999999'), 2, 8) filenum,
                             'A' recordtype,
                             01 recordseq,
                                   RPAD(' ', 8)
                                || RPAD(' ', 11) -- File Status Date 11 Spaces  DD-MON-YYYY
                                || RPAD(SUBSTR(NVL(d.premgeocode, ' '), 1, 4), 4, ' ') -- GeoCode
                                || RPAD(SUBSTR(NVL(TO_CHAR(NVL(d.officenumber, ''), '00'), '  '),
                                               2, 2),
                                        2, ' ') -- DistOffice
                                || RPAD(SUBSTR(NVL(d.premcensustract, ' '), 1, 10), 10, ' ') -- CensusTract
                                || RPAD(TRANSLATE(SUBSTR(NVL(d.primarydba, ' '), 1, 50), ',', ' '),
                                        50, ' ') -- DBA
                                || RPAD(TRANSLATE(SUBSTR(NVL(d.primarylicensee, ' '), 1, 50), ',', ' '),
                                        50, ' ') -- Licensee
                                || RPAD(' ', 4) -- Filler 4 Spaces
                             details
                        FROM abcreports.long_beach_extract_tmp d;

        --*****************************************************************************
        --  Record Type A - Sequence 2
        --*****************************************************************************
        INSERT INTO abcreports.long_beach_data_extract
             SELECT DISTINCT  'A' type_ind,
                             SUBSTR(TO_CHAR(NVL(d.licenseno, 0), '09999999'), 2, 8) filenum,
                             'A' recordtype,
                             02 recordseq,
                                   RPAD(TRANSLATE(SUBSTR(NVL(d.premaddressline1, ' '), 1, 50),
                                                 ',', ' '),
                                        50, ' ')
                                || RPAD(TRANSLATE(SUBSTR(NVL(d.premaddressline2, ' '), 1, 50),
                                                   ',', ' '),
                                        50, ' ')
                                || RPAD(TRANSLATE(SUBSTR(NVL(d.premcity, ' '), 1, 25), ',', ' '),
                                        25, ' ')
                                || RPAD(SUBSTR(NVL(d.premstate, ' '), 1, 2), 2, ' ')
                                || RPAD(SUBSTR(NVL(d.premzip, ' '), 1, 10), 10, ' ')
                                || RPAD('', 4) -- Filler 4 Spaces
                             details
                        FROM abcreports.long_beach_extract_tmp d;

        --*****************************************************************************
        --  Record Type A - Sequence 3
        --*****************************************************************************
        INSERT INTO abcreports.long_beach_data_extract
             SELECT DISTINCT  'A' type_ind,
                             SUBSTR(TO_CHAR(NVL(d.licenseno, 0), '09999999'), 2, 8) filenum,
                             'A' recordtype,
                             03 recordseq,
                                   RPAD(TRANSLATE(SUBSTR(NVL(NVL(d.mailaddressline1, d.premaddressline1), ' '),
                                                         1, 50),
                                                  ',', ' '),
                                        50, ' ')
                                || RPAD(TRANSLATE(SUBSTR(NVL(NVL(d.mailaddressline2, d.premaddressline1), ' '),
                                                         1, 50),
                                                  ',', ' '),
                                        50, ' ')
                                || RPAD(TRANSLATE(SUBSTR(NVL(NVL(d.mailcity, d.premcity), ' '), 1, 25),
                                                  ',', ' '),
                                        25, ' ')
                                || RPAD(SUBSTR(NVL(NVL(d.mailstate, d.premstate), ' '), 1, 2), 2, ' ')
                                || RPAD(SUBSTR(NVL(NVL(d.mailzip, d.premzip), ' '), 1, 10), 10, ' ')
                                || RPAD(' ', 4) -- Filler 4 Spaces
                             details
               FROM abcreports.long_beach_extract_tmp d
              WHERE NVL(d.mailaddressline1, d.premaddressline1) IS NOT NULL;

        --*****************************************************************************
        --  Record Type B 
        --*****************************************************************************
        INSERT INTO abcreports.long_beach_data_extract
             SELECT DISTINCT 'A' type_ind,
                             SUBSTR(TO_CHAR(NVL(d.licenseno, 0), '09999999'), 2, 8) filenum,
                             'B' recordtype,
                             NULL recordseq,
                                  RPAD(SUBSTR(NVL(d.license_type_code, ' '), 1, 2), 2, ' ')
                               || RPAD(SUBSTR(NVL(d.type_status_code, ' '), 1, 8), 8, ' ')
                               || RPAD(NVL(TO_CHAR(d.status_date), ' '), 11, ' ')
                               || RPAD(NVL(TO_CHAR(d.next_issue_date), ' '), 11, ' ')
                               || RPAD(SUBSTR(NVL(d.master_ind, ' '), 1, 1), 1, ' ')
                               || RPAD(SUBSTR(NVL(d.term, ' '), 1, 2), 2, ' ')
                               || RPAD(SUBSTR(NVL(TO_CHAR(NVL(d.duplicate_count, ''), '000'), '   '),
                                              2, 3),
                                       3, ' ')
                               || RPAD(SUBSTR(NVL(d.conditionlist, ' '), 1, 40), 40, ' ')
                               || RPAD(SUBSTR(NVL(d.fee_code, ' '), 1, 8), 8, ' ')
                               || RPAD(NVL(TO_CHAR(d.type_original_issue_date), ' '), 11, ' ')
                               || RPAD(SUBSTR(NVL(d.transferredfrom, ' '), 1, 11), 11, ' ')
                               || RPAD(SUBSTR(NVL(d.transferredto, ' '), 1, 11), 11, ' ')
                               || RPAD(SUBSTR(NVL(d.app_or_lic, ' '), 1, 3), 3, ' ')
                               || RPAD(' ', 25)   -- Filler 39-3 (App or Lic)= 36 Spaces - 11 = 25(Transfer T0 )
                             details
                        FROM abcreports.long_beach_extract_tmp d
                       WHERE d.recordseq < 9
                       ORDER BY filenum, substr(details, 1, 2), substr(details, 36, 3);

        FOR x IN (
                SELECT DISTINCT t.filenum 
                  FROM abcreports.long_beach_data_extract T
                 WHERE RecordType IN ('B')
                 ORDER BY t.filenum
                )
        LOOP
            inx := 1;
            FOR REC IN (
                    SELECT rowid id
                      FROM abcreports.long_beach_data_extract 
                     WHERE filenum = x.filenum
                       AND RecordType IN ('B')
                       AND substr(details, 120, 3) = 'APP'
                     ORDER BY substr(details, 1 ,2), substr(details, 36, 3))
            LOOP
                UPDATE abcreports.long_beach_data_extract
                   SET recordseq = inx
                 WHERE ROWID = rec.id;
                                      
                 inx := inx + 1;
            END LOOP;
            
            inx := 1;
            FOR REC IN (
                    SELECT rowid id
                      FROM abcreports.long_beach_data_extract 
                     WHERE filenum = x.filenum
                       AND RecordType IN ('B')
                       AND substr(details, 120, 3) = 'LIC'
                     ORDER BY substr(details, 1 ,2), substr(details, 36, 3))
            LOOP
                UPDATE abcreports.long_beach_data_extract
                   SET recordseq = inx
                 WHERE ROWID = rec.id;
                                      
                 inx := inx + 1;
            END LOOP;
        END LOOP;

        --*****************************************************************************
        --  Record Type E - Holds 
        --*****************************************************************************
        INSERT INTO abcreports.long_beach_data_extract
             SELECT DISTINCT 'A' type_ind,
                             SUBSTR(TO_CHAR(NVL(licensenumber, 0), '09999999'), 2, 8) filenum,
                             'E' recordtype,
                             NULL recordseq,
                                   RPAD(SUBSTR(NVL(app_or_lic, ' '), 1, 3), 3, ' ')
                                || RPAD(NVL(TO_CHAR(holdcreateddate), ' '), 11, ' ')
                                || RPAD(TRANSLATE(SUBSTR(NVL(holdtype, ' '), 1, 100), ',', ' '),
                                        100, ' ')
                                || RPAD('', 25)  -- Filler 25 Spaces
                             details
                        FROM (
                             SELECT DISTINCT ap.licensenumber,
                                             --ap.objectid licobjectid,
                                             'APP' app_or_lic,
                                             --NULL recordseq,
                                             TO_CHAR(h.holdcreateddate, 'DD-MON-YYYY') holdcreateddate,
                                             h.holdtype
                                             --TO_CHAR(h.holdreleased, 'DD-MON-YYYY') holdreleaseddate,
                                             --UPPER(h.holdstatus) holdstatus
                               FROM mart.hold h
                                    JOIN mart.holdlicenserel r ON h.objectid = r.holdobjectid
                                    JOIN mart.application ap ON ap.objectid = r.applicobjectid
                              WHERE ap.licenseexists = 'N' -- Current Applications
                                AND h.holdreleased IS NULL --Active Holds
                                AND EXISTS
                                       (SELECT 'x'
                                          FROM abc.rawdataextract_type_temp d
                                         WHERE d.licobjectid = ap.objectid
                                           AND (UPPER(d.type_status_code) IN ('ACTIVE',
                                                                              'SLMSHD',
                                                                              'SUSPEN',
                                                                              'REVPEN',
                                                                              'SUREND',
                                                                              'R64B',
                                                                              'PEND',
                                                                              'ISSUPD'))
                                           AND d.premcity = 'LONG BEACH')
                             UNION ALL
                             SELECT DISTINCT l.externalfilenum licensenumber,
                                             --l.jobid licobjectid,
                                             'LIC' app_or_lic,
                                             --NULL recordseq,
                                             TO_CHAR(h.holdcreateddate, 'DD-MON-YYYY') holdcreateddate,
                                             h.holdtype
                                             --TO_CHAR(h.holdreleased, 'DD-MON-YYYY') holdreleaseddate,
                                             --UPPER(h.holdstatus) holdstatus
                                        FROM mart.hold h
                                        JOIN mart.holdlicenserel r ON h.objectid = r.holdobjectid
                                        JOIN mart.license l ON l.jobid = r.applicobjectid
                                       WHERE h.holdreleased IS NULL --Active Holds
                                         AND EXISTS
                                               (SELECT 'x'
                                                  FROM abc.rawdataextract_type_temp d
                                                 WHERE d.licobjectid = l.jobid
                                                   AND (UPPER(d.type_status_code) IN ('ACTIVE',
                                                                                      'SLMSHD',
                                                                                      'SUSPEN',
                                                                                      'REVPEN',
                                                                                      'SUREND',
                                                                                      'R64B',
                                                                                      'PEND',
                                                                                      'ISSUPD'))
                                               )
                                       ORDER BY licensenumber, holdcreateddate, holdtype);

        --*****************************************************************************
        --  Record Type F - Accusations
        --*****************************************************************************
        INSERT INTO abcreports.long_beach_data_extract
             SELECT DISTINCT 'A' type_ind,
                             SUBSTR(TO_CHAR(NVL(a.licensenumber, 0), '09999999'), 2, 8) filenum,
                             'F' recordtype,
                             NULL recordseq,
                                  SUBSTR(TO_CHAR(NVL(a.regnumber, 0), '0999999999'), 2, 10)
                               || RPAD(NVL(TO_CHAR(TO_CHAR(a.registeraccusationcompleteddat, 'DD-MON-YYYY')), ' '), 11, ' ')
                               || RPAD(SUBSTR(NVL(v.code, ' '), 1, 10), 10, ' ')
                               || RPAD(SUBSTR(NVL(a.statusname, ' '), 1, 10), 10, ' ')
                               || RPAD(SUBSTR(NVL(UPPER(d.outcome), ' '), 1, 20), 20, ' ')
                               || RPAD(NVL(TO_CHAR(d.suspensiondays), ' '), 4, ' ')
                               || RPAD(NVL(TO_CHAR(d.stayeddays), ' '), 4, ' ')
                               || RPAD(TRANSLATE(SUBSTR(NVL(TO_CHAR((SELECT p1.poicfee
                                                    FROM mart.processpoic p1
                                                   WHERE p1.objectid = p.objectid)), ' '), 1, 10),
                                                ',', ' '),
                                       10, ' ')
                               || RPAD(NVL(TO_CHAR(TO_CHAR(d.suspensionstartdate, 'DD-MON-YYYY')), ' '), 11, ' ')
                               || RPAD(NVL(TO_CHAR(TO_CHAR(d.suspensionenddate, 'DD-MON-YYYY')), ' '), 11, ' ')
                               || RPAD('', 38)   -- Filler 38 Spaces
                           details
               FROM mart.accusation a
               JOIN mart.executetermsofdecision d
                 ON d.objectid = (SELECT MAX(d1.objectid)
                                    FROM mart.executetermsofdecision d1
                                   WHERE d1.jobid = a.objectid
                                     AND d1.outcome IS NOT NULL)
               LEFT OUTER JOIN (SELECT MAX(r1.objectid) objectid, r1.jobid
                                  FROM mart.postsuspensionrevocation r1
                              GROUP BY r1.jobid) r
                 ON r.jobid = a.objectid
               LEFT OUTER JOIN (SELECT MAX(p1.objectid) objectid, p1.jobid
                                  FROM mart.processpoic p1
                              GROUP BY p1.jobid) p
                 ON p.jobid = a.objectid
               JOIN mart.accusationviolation av
                 ON av.accusationobjectid = a.objectid
               JOIN mart.violation v 
                 ON v.objectid = av.violationobjectid
               JOIN mart.licensetype lt 
                 ON lt.licensejobid = a.licensejobid
              WHERE a.statusname NOT IN ('CLOSED', 'DISMSD')
                AND EXISTS
                         (SELECT 'x'
                            FROM abcreports.long_beach_extract_tmp d
                           WHERE d.licobjectid = a.licensejobid
                             AND (UPPER(d.type_status_code) IN ('ACTIVE',
                                                                'SLMSHD',
                                                                'SUSPEN',
                                                                'REVPEN',
                                                                'SUREND',
                                                                'R64B',
                                                                'PEND',
                                                                'ISSUPD'))
                             AND d.premcity = 'LONG BEACH')
              ORDER BY filenum, substr(details, 1, 10), substr(details, 22, 10); --, a.regnumber, v.code;
    
        --*****************************************************************************
        --  Record Type G - Conditions
        --*****************************************************************************
        INSERT INTO abcreports.long_beach_data_extract
             SELECT DISTINCT 'A' type_ind,
                             SUBSTR(TO_CHAR(NVL(licensenumber, 0), '09999999'), 2, 8) filenum, 
                             'G' RecordType,
                             RECORDSEQ RecordSeq,
                                   rpad(substr(nvl(App_or_Lic ,' '),1,3),3,' ')
                                || rpad(substr(nvl(LICENSETYPECODE,' '),1,2),2,' ')
                                || rpad(substr(nvl(Condition_code,' '),1,2),2,' ')
                                || rpad(translate(substr(nvl(Condition_desc,' '),1,100),',',' '),100,' ')
                                || rpad(nvl(to_char(Condition_Date_Formatted),' '),11,' ')
                                || RPAD(' ', 21, ' ') --                     ' -- Filler 21 Spaces
                             Details
               from (
             SELECT DISTINCT x.licensenumber,
                             x.licensejobid,
                             x.licensetypecode,
                             'LIC' app_or_lic,
                             NULL recordseq,
                             x.condition_code,
                             x.condition_desc,
                             x.condition_end_date,
                             TO_CHAR(x.condition_end_date, 'DD-MON-YYYY')
                                 condition_date_formatted
               FROM (SELECT lt.licensejobid,
                            lt.objectid ltobjectid,
                            lt.licensenumber,
                            lt.licensetypecode,
                            'A' condition_code,
                            '23824 CITY/COUNTY OWNED PROPERTY, PERS-PERS ONLY'
                                condition_desc,
                            lt.conditionenddate condition_end_date
                       FROM mart.licensetype lt
                      WHERE lt.conda = 'Y'
                     UNION ALL
                     SELECT lt.licensejobid,
                            lt.objectid ltobjectid,
                            lt.licensenumber,
                            lt.licensetypecode,
                            'D' condition_code,
                            'PERS-PERS TRANSFER ONLY, PER SECTION 23817.5'
                                condition_desc,
                            lt.conditionenddate condition_end_date
                       FROM mart.licensetype lt
                      WHERE lt.condd = 'Y'
                     UNION ALL
                     SELECT lt.licensejobid,
                            lt.objectid ltobjectid,
                            lt.licensenumber,
                            lt.licensetypecode,
                            '7' condition_code,
                            'OPERATING RESTRICTIONS' condition_desc,
                            NULL condition_end_date
                       FROM mart.license l
                            JOIN mart.licensetype lt ON lt.licensejobid = l.jobid
                      WHERE lt.cond7 = 'Y'
                     UNION ALL
                     SELECT lt.licensejobid,
                            lt.objectid ltobjectid,
                            lt.licensenumber,
                            lt.licensetypecode,
                            '5' condition_code,
                            'PRIORITIES 1995 AND LATER, NO SALE 2 YEARS'
                                condition_desc,
                            lt.conditionenddate condition_end_date
                       FROM mart.licensetype lt
                            JOIN mart.license l ON l.jobid = lt.licensejobid
                      WHERE lt.cond5 = 'Y'
                     UNION ALL
                     SELECT lt.licensejobid,
                            lt.objectid ltobjectid,
                            lt.licensenumber,
                            lt.licensetypecode,
                            '2' condition_code,
                            'INTERCOUNTY PRIORITIES, NO SALE 5 YEARS' condition_desc,
                            lt.conditionenddate condition_end_date
                       FROM mart.licensetype lt
                            JOIN mart.license l ON l.jobid = lt.licensejobid
                      WHERE lt.cond2 = 'Y'
                     UNION ALL
                     SELECT lt.licensejobid,
                            lt.objectid ltobjectid,
                            lt.licensenumber,
                            lt.licensetypecode,
                            '8' condition_code,
                            'CODE 8 - SELF-INCORPORATION - HISTORICAL VALUE'
                                condition_desc,
                            lt.conditionenddate condition_end_date
                       FROM mart.licensetype lt
                      WHERE lt.cond8 = 'Y'
                     UNION ALL
                     SELECT lt.licensejobid,
                            lt.objectid ltobjectid,
                            lt.licensenumber,
                            lt.licensetypecode,
                            '9' condition_code,
                            'TIED HOUSE UNDERTAKINGS' condition_desc,
                            lt.conditionenddate condition_end_date
                       FROM mart.licensetype lt
                      WHERE lt.cond9 = 'Y'
                     UNION ALL
                     SELECT lt.licensejobid,
                            lt.objectid ltobjectid,
                            lt.licensenumber,
                            lt.licensetypecode,
                            '1C' condition_code,
                            'SEASONAL CONVERSIONS' condition_desc,
                            lt.conditionenddate condition_end_date
                       FROM mart.licensetype lt
                      WHERE lt.cond1c = 'Y'
                     UNION ALL
                     SELECT lt.licensejobid,
                            lt.objectid ltobjectid,
                            lt.licensenumber,
                            lt.licensetypecode,
                            'AV' condition_code,
                            'LIMITED ALIEN VERIFICATION DATE' condition_desc,
                            lt.conditionenddate condition_end_date
                       FROM mart.licensetype lt
                            JOIN mart.license l ON l.jobid = lt.licensejobid
                      WHERE l.condav = 'Y'
                     UNION ALL
                     SELECT lt.licensejobid,
                            lt.objectid ltobjectid,
                            lt.licensenumber,
                            lt.licensetypecode,
                            'I' condition_code,
                            'INTERNET SALES ONLY' condition_desc,
                            lt.conditionenddate condition_end_date
                       FROM mart.licensetype lt
                      WHERE lt.condi = 'Y') x
              WHERE EXISTS
                     (SELECT 'x'
                        FROM abc.rawdataextract_type_temp d
                       WHERE d.licobjectid = x.licensejobid
                         AND (UPPER(d.type_status_code) IN ('ACTIVE',
                                                            'SLMSHD',
                                                            'SUSPEN',
                                                            'REVPEN',
                                                            'SUREND',
                                                            'R64B',
                                                            'PEND',
                                                            'ISSUPD'))
                      )
                AND (TRUNC(x.condition_end_date) > TRUNC(SYSDATE) -- Current Holds
                 OR x.condition_end_date IS NULL)
              ORDER BY x.licensenumber, x.licensetypecode, x.condition_code
                    );                              

        FOR x IN (
                SELECT DISTINCT t.filenum 
                  FROM abcreports.long_beach_data_extract T
                 WHERE RecordType IN ('G')
                 ORDER BY t.filenum
                )
        LOOP
            inx := 1;
            FOR REC IN (
                    SELECT rowid id
                      FROM abcreports.long_beach_data_extract 
                     WHERE filenum = x.filenum
                       AND  RecordType IN ('G')
                     ORDER BY substr(details, 4, 3))
            LOOP
                UPDATE abcreports.long_beach_data_extract
                   SET recordseq = inx
                 WHERE ROWID = rec.id;
                                      
                 inx := inx + 1;
            END LOOP;
        END LOOP;

        FOR x IN (
                SELECT t.filenum, COUNT(*) count1 
                  FROM abcreports.long_beach_data_extract T
                 WHERE RecordType IN ('E','F')
                 GROUP BY t.RecordType, t.filenum
                 ORDER BY t.recordtype, t.filenum
                )
        LOOP
            FOR i IN 1..x.count1
            LOOP

                UPDATE abcreports.long_beach_data_extract
                   SET recordseq   = i
                 WHERE filenum = x.filenum
                   AND ROWNUM = 1
                   AND recordseq IS NULL;
            END LOOP;
        END LOOP;
        
        dbms_lob.createtemporary(clob_, TRUE);
        dbms_lob.writeappend(clob_, 25, '<BR>m_tape150_LBPD_UV<BR>');

        OPEN cur_;
        LOOP
        FETCH cur_ BULK COLLECT INTO rec_ LIMIT 1000;
            EXIT WHEN rec_.count = 0;

            ln_length := LENGTH(rec_(1).rec);
            FOR i in 1..rec_.COUNT
            LOOP 
                dbms_lob.writeappend(clob_, ln_length, rec_(i).rec);
            END LOOP;
        END LOOP;
        CLOSE cur_;
        
        RETURN clob_;    

    END EXTRACT_150;


--*****************************************************************************
--      PROCESS_3600  - Process temp tables into 3600
--*****************************************************************************
    FUNCTION EXTRACT_3600 RETURN CLOB IS
    CURSOR      cur_ IS
                  SELECT SUBSTR(NVL(d.filenum, 0), 1, 8) 
                          || RPAD(SUBSTR(NVL(d.recordtype, ' '), 1, 1), 1, ' ')
                          || TO_CHAR(d.recordseq, 'FM00')
                          || RPAD(SUBSTR(NVL(d.details, ' '), 1, 3589), 3589, ' ')
                          || CHR(10) rec
                    FROM abcreports.long_beach_data_extract d 
                   WHERE type_ind = 'B'
                   ORDER BY d.filenum, d.recordtype, d.recordseq; 
    TYPE        rec_t   IS TABLE OF cur_%ROWTYPE;
                                      
    clob_       CLOB;
    rec_        rec_t;
    ln_length   NUMBER;
    lv_msg          VARCHAR2(8196);
    
    BEGIN
        INSERT INTO abcreports.long_beach_data_extract d
             SELECT 'B' type_ind,
                    SUBSTR(TO_CHAR(NVL(cd.licensenumber, 0), '09999999'), 2, 8) filenum,
                    'R' recordtype, -- coded R for Restrictions
                    cd.recordseq recordseq,
                           RPAD(SUBSTR(NVL(cd.app_or_lic, ' '), 1, 3), 3, ' ')
                        || RPAD(SUBSTR(NVL(cd.conditioncode, ' '), 1, 20), 20, ' ')
                        || RPAD(Replace(
                                    Replace(
                                        Replace(cd.conditiontext, CHR(13)||chr(10), ' '), 
                                      ',', ' '),
                                   '  ', ' '),
                                3500, ' ')
                        || RPAD(' ', 21, ' ') -- Filler 21 Spaces
                    details
               FROM (                    
                     SELECT DISTINCT ap.licensenumber,
                                     ap.objectid licobjectid,
                                     'APP' app_or_lic,
                                     NULL recordseq,
                                     r.conditioncode,
                                     r.conditiontext, --length(ConditionText) ConditionLength,
                                     r.sort
                       FROM mart.applicationconditions r
                       JOIN mart.application ap ON ap.objectid = applicationjobid
                      WHERE ap.licenseexists = 'N' -- Current Applications
                        AND EXISTS
                               (SELECT 'x'
                                  FROM abcreports.long_beach_extract_tmp d
                                 WHERE d.licobjectid = ap.objectid
                                   AND (UPPER(d.type_status_code) IN ('ACTIVE',
                                                                      'SLMSHD',
                                                                      'SUSPEN',
                                                                      'REVPEN',
                                                                      'SUREND',
                                                                      'R64B',
                                                                      'PEND',
                                                                      'ISSUPD'))
                                   AND d.premcity = 'LONG BEACH')
                     UNION ALL
                     SELECT DISTINCT l.externalfilenum licensenumber,
                                     l.jobid licobjectid,
                                     'LIC' app_or_lic,
                                     NULL recordseq,
                                     r.conditioncode,
                                     r.conditiontext, -- length(ConditionText) ConditionLength,
                                     r.sort
                       FROM mart.licenseconditions r
                       JOIN mart.license l ON l.jobid = r.licensejobid
                      WHERE EXISTS
                               (SELECT 'x'
                                  FROM abcreports.long_beach_extract_tmp d
                                 WHERE d.licobjectid = l.jobid
                                   AND (UPPER(d.type_status_code) IN ('ACTIVE',
                                                                      'SLMSHD',
                                                                      'SUSPEN',
                                                                      'REVPEN',
                                                                      'SUREND',
                                                                      'R64B',
                                                                      'PEND',
                                                                      'ISSUPD'))
                                   AND d.premcity = 'LONG BEACH')
                      ORDER BY licensenumber, sort
                    ) cd;

        FOR x IN (SELECT t.filenum, COUNT(*) count1 
                    FROM abcreports.long_beach_data_extract T
                   WHERE type_ind = 'B'
                   GROUP BY t.filenum
                   ORDER BY t.filenum)
        LOOP
            FOR i IN 1..x.count1
            LOOP
                UPDATE abcreports.long_beach_data_extract
                   SET recordseq  = i
                 WHERE filenum = x.filenum
                   AND type_ind = 'B'
                   AND ROWNUM = 1
                   AND recordseq IS NULL;
            END LOOP;
        END LOOP;
          
        dbms_lob.createtemporary(clob_, TRUE);
        dbms_lob.writeappend(clob_, 26, '<BR>m_tape3600_LBPD_UV<BR>');
        
        OPEN cur_;
        LOOP
        FETCH cur_ BULK COLLECT INTO rec_ LIMIT 1000;
            EXIT WHEN rec_.count = 0;

            ln_length := LENGTH(rec_(1).rec);

            FOR i in 1..rec_.COUNT
            LOOP
                dbms_lob.writeappend(clob_, ln_length, rec_(i).rec);
            END LOOP;
        END LOOP;
        CLOSE cur_;

        RETURN clob_;    
          
    EXCEPTION
        WHEN OTHERS THEN
            rqs_utils.log(p_log_type          =>  'E',
                          p_job_id            =>  p_parms.get_value('JOB_ID'),
                          p_seq               =>  TO_NUMBER(p_parms.get_value('SEQ')),
                          p_source            =>  'Longbeach PD Repor',
                          p_msg               =>  SQLERRM,
                          p_error_trace       =>  dbms_utility.format_error_backtrace);             

           lv_msg := 'ERROR: ' || SQLERRM || CHR(10) || CHR(13) 
                  || 'TRACE: ' || dbms_utility.format_error_backtrace;
           p_status_ind := 'E';
           RETURN lv_msg;
    END EXTRACT_3600;



--*****************************************************************************
--*****************************************************************************
--      Long Beach PD Extract (Main Process)
--*****************************************************************************
--*****************************************************************************
    BEGIN
        DECLARE
            clob_           CLOB;
            clob_temp       CLOB;
   
        BEGIN  
            BUILD_TEMP;
            
            dbms_lob.createtemporary(clob_, TRUE);
            
            clob_temp := EXTRACT_150;
            dbms_lob.append(clob_, clob_temp);
            
            clob_temp := EXTRACT_3600;
            dbms_lob.append(clob_, clob_temp);

            p_status_ind := 'F';
            COMMIT;
            
            RETURN rqs_utils.clob2blob(clob_);

        EXCEPTION
            WHEN OTHERS THEN
                rqs_utils.log(p_log_type          =>  'E',
                              p_job_id            =>  p_parms.get_value('JOB_ID'),
                              p_seq               =>  TO_NUMBER(p_parms.get_value('SEQ')),
                              p_source            =>  'Longbeach PD Repor',
                              p_msg               =>  SQLERRM,
                              p_error_trace       =>  dbms_utility.format_error_backtrace);             

                p_status_ind := 'E';
                RETURN utl_raw.cast_to_raw('ERROR: ' || SQLERRM || CHR(10) || CHR(13) ||
                                           'TRACE: ' || dbms_utility.format_error_backtrace);
                
        END;
    END LONGBEACHPD;
/


GRANT EXECUTE ON ABCREPORTS.LONGBEACHPD TO ABCREPORTS_ROLE;
