CREATE OR REPLACE FUNCTION ABCREPORTS.ws_2_enforcement(
    p_parms        IN OUT t_parameters,
    p_status_ind   IN OUT VARCHAR2)
    RETURN BLOB
IS
    -- ****************************************************************************
    -- File:        WS_2_ENFORCEMENT.FNC
    -- Author:      Timothy J. Lord
    --
    -- Description:
    --
    --
    -- History:
    -------------------------------------------------------------------------------
    --    Date                  Comment
    --  09/13/2022  TJL   - Function created
    -- ****************************************************************************

    TYPE counts IS VARRAY(3) OF INTEGER;

    TYPE datarectyp IS RECORD(col_1 VARCHAR2(1),
                              col_2 VARCHAR2(500),
                              col_3 counts);

    TYPE datatabtyp IS TABLE OF datarectyp;

    g_switch       DATE := '01-AUG-18'; -- start date to start using docket notes
    g_max          DATE := TO_DATE('21990101', 'YYYYMMDD');


    FUNCTION get_section_data(p_data         IN OUT datatabtyp,
                              p_column       IN     NUMBER,
                              p_start_date   IN     DATE,
                              p_end_date     IN     DATE,
                              p_status_msg   IN OUT VARCHAR2)
        RETURN BOOLEAN
    IS
    BEGIN
        -- ***********************************************************
        -- (2) Complaint Investigation Assignments Completed
        -- ***********************************************************
        -- COMPLAINTINVESTIGATIONS
        SELECT COUNT(investigationtype)
          INTO p_data(2).col_3(p_column)
          FROM mart.investigation i
         WHERE i.investigationtype = 'COMPLAINT'
           AND (SELECT TRUNC(t.effectivestartdate)
                  FROM extension.jobstatuschange_t t
                 WHERE t.jobid = i.objectid
                   AND t.statusname = 'CLOSED'
                   AND t.jobstatuschangeid =
                       (SELECT MIN(t.jobstatuschangeid)
                          FROM extension.jobstatuschange_t t
                         WHERE t.jobid = i.objectid
                           AND t.statusname = 'CLOSED')) BETWEEN p_start_date
                                                             AND p_end_date
           AND api.pkg_columnquery.VALUE(i.objectid, 'StatusName') <>
               'CANCEL';


        -- ***********************************************************
        -- (3) Administrative Assignments Completed
        -- ***********************************************************
        -- ADMININVESTIGATIONS
        SELECT COUNT(investigationtype)
          INTO p_data(3).col_3(p_column)
          FROM mart.investigation i
         WHERE i.investigationtype = 'ADMINISTRATIVE'
           AND (SELECT TRUNC(t.effectivestartdate)
                  FROM extension.jobstatuschange_t t
                 WHERE t.jobid = i.objectid
                   AND t.statusname = 'CLOSED'
                   AND t.jobstatuschangeid =
                       (SELECT MIN(t.jobstatuschangeid)
                          FROM extension.jobstatuschange_t t
                         WHERE t.jobid = i.objectid
                           AND t.statusname = 'CLOSED')) BETWEEN p_start_date
                                                             AND p_end_date
           AND api.pkg_columnquery.VALUE(i.objectid, 'StatusName') <>
               'CANCEL';


        -- ***********************************************************
        -- (4) TRACE Assignments Completed
        -- ***********************************************************
        -- TRACEINVESTIGATIONS
        SELECT COUNT(investigationtype)
          INTO p_data(4).col_3(p_column)
          FROM mart.investigation i
         WHERE i.investigationtype = 'TRACE'
           AND (SELECT TRUNC(t.effectivestartdate)
                  FROM extension.jobstatuschange_t t
                 WHERE t.jobid = i.objectid
                   AND t.statusname = 'CLOSED'
                   AND t.jobstatuschangeid =
                       (SELECT MIN(t.jobstatuschangeid)
                          FROM extension.jobstatuschange_t t
                         WHERE t.jobid = i.objectid
                           AND t.statusname = 'CLOSED')) BETWEEN p_start_date
                                                             AND p_end_date
           AND api.pkg_columnquery.VALUE(i.objectid, 'StatusName') <>
               'CANCEL';


        -- ***********************************************************
        -- (5) Police Reports Assigned for Investigation (ABC-61)
        -- ***********************************************************
        -- POLICEREPORTINV
        SELECT COUNT(investigationtype)
          INTO p_data(5).col_3(p_column)
          FROM mart.investigation i
         WHERE i.investigationtype = 'POLICE REPORT'
           AND (SELECT TRUNC(t.effectivestartdate)
                  FROM extension.jobstatuschange_t t
                 WHERE t.jobid = i.objectid
                   AND t.statusname = 'CLOSED'
                   AND t.jobstatuschangeid =
                       (SELECT MIN(t.jobstatuschangeid)
                          FROM extension.jobstatuschange_t t
                         WHERE t.jobid = i.objectid
                           AND t.statusname = 'CLOSED')) BETWEEN p_start_date
                                                             AND p_end_date
           AND api.pkg_columnquery.VALUE(i.objectid, 'StatusName') <>
               'CANCEL';


        -- ***********************************************************
        -- (6) Accusations Registered
        -- ***********************************************************
        -- ACCUSATIONSREG ?? second line?
        SELECT COUNT(DISTINCT a.regnumber)
          INTO p_data(6).col_3(p_column)
          FROM mart.accusationviolation  av
               JOIN mart.violation v ON v.objectid = av.violationobjectid
               JOIN mart.accusation a ON a.objectid = av.accusationobjectid
               JOIN query.o_office o ON o.objectid = a.officeid
         WHERE av.accusationobjectid IN
                   (SELECT DISTINCT a.objectid
                      FROM mart.accusation a
                     WHERE a.accusationregistereddate BETWEEN p_start_date
                                                          AND p_end_date
                       AND (a.casetype = 'ABC'
                         OR a.casetype = 'BACKTRACK'))
           AND v.code NOT IN ('G3');


        -- ***********************************************************
        -- (7) Violation Counts Filed by Source
        -- ***********************************************************
        -- NONE
        p_data(7).col_3(p_column) := NULL;



        -- ***********************************************************
        -- (9) Violation Counts from ABC Investigations
        -- ***********************************************************
        -- ABCVIOLATIONS
        SELECT NVL(
                   SUM(
                         (CASE
                              WHEN v.code IN ('C10',
                                              'E1',
                                              'E2',
                                              'P2',
                                              'P3',
                                              'P7',
                                              'S11',
                                              'S12',
                                              'S35',
                                              'S31',
                                              'U5',
                                              'S18')
                              THEN
                                  1
                              ELSE
                                  0
                          END)
                       + (CASE WHEN v.code IN ('S13') THEN 1 ELSE 0 END) -- MD - minor decoy
                       + (CASE
                              WHEN v.code IN ('C1',
                                              'D16',
                                              'P4',
                                              'P42',
                                              'P43',
                                              'S16')
                              THEN
                                  1
                              ELSE
                                  0
                          END)                    -- OI- Obviously Intoxicated
                       + (CASE
                              WHEN v.code IN ('C3',
                                              'F39',
                                              'L9',
                                              'O6',
                                              'P11',
                                              'P12',
                                              'P21',
                                              'P22',
                                              'P32',
                                              'P33',
                                              'P34',
                                              'P38',
                                              'P41',
                                              'P48',
                                              'P49',
                                              'P50',
                                              'P51',
                                              'P52',
                                              'P54',
                                              'P55',
                                              'S24',
                                              'S8')
                              THEN
                                  1
                              ELSE
                                  0
                          END)                                    -- DR- Drugs
                       + (CASE
                              WHEN v.code IN ('C13',
                                              'C16',
                                              'C7',
                                              'D6',
                                              'G4',
                                              'I7',
                                              'L1',
                                              'L3',
                                              'P26',
                                              'R5',
                                              'S29')
                              THEN
                                  1
                              ELSE
                                  0
                          END)           -- DP - Disorderly/Disruptive Premise
                       + (CASE
                              WHEN v.code IN ('D22',
                                              'D7',
                                              'D8',
                                              'D9',
                                              'E7',
                                              'F10',
                                              'F18',
                                              'F24',
                                              'F33',
                                              'F34',
                                              'F35',
                                              'F38',
                                              'F40',
                                              'F41',
                                              'G5',
                                              'L4',
                                              'L5')
                              THEN
                                  1
                              ELSE
                                  0
                          END)                                    -- RO- ROSTF
                       + (CASE
                              WHEN v.code IN ('A5',
                                              'B1',
                                              'B2',
                                              'D20',
                                              'D3',
                                              'M2',
                                              'P35',
                                              'P47',
                                              'P53',
                                              'P9',
                                              'U6')
                              THEN
                                  1
                              ELSE
                                  0
                          END)                      -- WV - Weapons Violations
                       + (CASE
                              WHEN v.code IN ('I6',
                                              'O1',
                                              'P18',
                                              'P19',
                                              'P20',
                                              'U1')
                              THEN
                                  1
                              ELSE
                                  0
                          END)                         -- SP - Stolen Property
                       + (CASE
                              WHEN v.code IN ('B4',
                                              'G1',
                                              'O3',
                                              'P13',
                                              'P14',
                                              'P15')
                              THEN
                                  1
                              ELSE
                                  0
                          END)                                 -- GA- Gambling
                       + (CASE WHEN v.code IN ('P1') THEN 1 ELSE 0 END) -- SD- Soliciting Drinks
                       + (CASE
                              WHEN v.code IN ('A3',
                                              'A4',
                                              'C19',
                                              'S34')
                              THEN
                                  1
                              ELSE
                                  0
                          END)                              -- AH- After Hours
                       + (CASE
                              WHEN v.code IN ('A1',
                                              'A15',
                                              'C18',
                                              'D4',
                                              'D18',
                                              'D21',
                                              'E10',
                                              'E3',
                                              'E5',
                                              'E8',
                                              'F13',
                                              'F16',
                                              'F19',
                                              'F2',
                                              'F20',
                                              'F21',
                                              'F26',
                                              'F29',
                                              'F3',
                                              'F30',
                                              'F36',
                                              'F4',
                                              'F8',
                                              'G6',
                                              'I1',
                                              'I10',
                                              'I11',
                                              'I12',
                                              'I13',
                                              'I3',
                                              'I8',
                                              'I9',
                                              'P8',
                                              'P10',
                                              'P23',
                                              'P56',
                                              'R8',
                                              'S14',
                                              'S17',
                                              'S19',
                                              'S23',
                                              'S25',
                                              'S26',
                                              'S27',
                                              'S30',
                                              'S4',
                                              'S6',
                                              'U3',
                                              'V0',
                                              'V4',
                                              'V5',
                                              'V7',
                                              'B3',
                                              'C20',
                                              'E9',
                                              'F32',
                                              'F9',
                                              'P39',
                                              'P46',
                                              'P56',
                                              'R2',
                                              'R3',
                                              'S2',
                                              'S21',
                                              'S28',
                                              'S30',
                                              'S36',
                                              'S5',
                                              'U2',
                                              'V1',
                                              'V6',
                                              'S9')
                              THEN
                                  1
                              ELSE
                                  0
                          END)                       -- BP- Business Practices
                       + (CASE
                              WHEN v.code IN ('C15',
                                              'C4',
                                              'G2',
                                              'L7',
                                              'P24',
                                              'R1',
                                              'T3')
                              THEN
                                  1
                              ELSE
                                  0
                          END)                          -- MT- Moral Turpitude
                       + (CASE WHEN v.code IN ('P17') THEN 1 ELSE 0 END) -- PR- Prostitution
                       + (CASE
                              WHEN v.code IN ('V2', 'V3', 'V11') THEN 1
                              ELSE 0
                          END)                  -- VC- Violation of Conditions
                       + (CASE
                              WHEN v.code IN ('A10',
                                              'A11',
                                              'A12',
                                              'A13',
                                              'A14',
                                              'A2',
                                              'A6',
                                              'A7',
                                              'A8',
                                              'A9',
                                              'C0',
                                              'C11',
                                              'C12',
                                              'C14',
                                              'C17',
                                              'C2',
                                              'C5',
                                              'C6',
                                              'C8',
                                              'C9',
                                              'D1',
                                              'D10',
                                              'D11',
                                              'D12',
                                              'D13',
                                              'D14',
                                              'D15',
                                              'D17',
                                              'D19',
                                              'D2',
                                              'D23',
                                              'D24',
                                              'D5',
                                              'E4',
                                              'E6',
                                              'F0',
                                              'F1',
                                              'F11',
                                              'F12',
                                              'F14',
                                              'F15',
                                              'F17',
                                              'F22',
                                              'F23',
                                              'F25',
                                              'F27',
                                              'F28',
                                              'F31',
                                              'F37',
                                              'F42',
                                              'F43',
                                              'F44',
                                              'F5',
                                              'G3',
                                              'H1',
                                              'H2',
                                              'H3',
                                              'H4',
                                              'I2',
                                              'I4',
                                              'I5',
                                              'L10',
                                              'L2',
                                              'L6',
                                              'L8',
                                              'M1',
                                              'N1',
                                              'N2',
                                              'O2',
                                              'O4',
                                              'O5',
                                              'P16',
                                              'P25',
                                              'P27',
                                              'P28',
                                              'P29',
                                              'P30',
                                              'P31',
                                              'P36',
                                              'P37',
                                              'P40',
                                              'P44',
                                              'P45',
                                              'P6',
                                              'R4',
                                              'R6',
                                              'R7',
                                              'S15',
                                              'S22',
                                              'S32',
                                              'S33',
                                              'S7',
                                              'T1',
                                              'T2',
                                              'U2',
                                              'U4',
                                              'V10',
                                              'V8',
                                              'V9',
                                              'F7',
                                              'P5',
                                              'S1',
                                              'S3',
                                              'S20')
                              THEN
                                  1
                              ELSE
                                  0
                          END)),
                   0)                                             -- OT- Other
          INTO p_data(9).col_3(p_column)
          FROM mart.accusationviolation  av
               JOIN mart.violation v ON v.objectid = av.violationobjectid
               JOIN mart.accusation a ON a.objectid = av.accusationobjectid
               JOIN query.o_office o ON o.objectid = a.officeid
         WHERE av.accusationobjectid IN
                   (SELECT DISTINCT a.objectid
                      FROM mart.accusation a
                     WHERE a.accusationregistereddate BETWEEN p_start_date
                                                          AND p_end_date
                       AND (a.casetype = 'ABC'))
           AND v.code NOT IN ('G3');


        -- ***********************************************************
        -- (10) Violation Counts from Backtrack Investigation
        -- ***********************************************************
        -- BACKTRACKVIOLATIONS
        SELECT NVL(SUM(  (CASE
                              WHEN v.code IN ('C10',
                                              'E1',
                                              'E2',
                                              'P2',
                                              'P3',
                                              'P7',
                                              'S11',
                                              'S12',
                                              'S35',
                                              'S31',
                                              'U5',
                                              'S18')
                              THEN
                                  1
                              ELSE
                                  0
                          END)
                       + (CASE WHEN v.code IN ('S13') THEN 1 ELSE 0 END) -- MD - minor decoy
                       + (CASE
                              WHEN v.code IN ('C1',
                                              'D16',
                                              'P4',
                                              'P42',
                                              'P43',
                                              'S16')
                              THEN
                                  1
                              ELSE
                                  0
                          END)                    -- OI- Obviously Intoxicated
                       + (CASE
                              WHEN v.code IN ('C3',
                                              'F39',
                                              'L9',
                                              'O6',
                                              'P11',
                                              'P12',
                                              'P21',
                                              'P22',
                                              'P32',
                                              'P33',
                                              'P34',
                                              'P38',
                                              'P41',
                                              'P48',
                                              'P49',
                                              'P50',
                                              'P51',
                                              'P52',
                                              'P54',
                                              'P55',
                                              'S24',
                                              'S8')
                              THEN
                                  1
                              ELSE
                                  0
                          END)                                    -- DR- Drugs
                       + (CASE
                              WHEN v.code IN ('C13',
                                              'C16',
                                              'C7',
                                              'D6',
                                              'G4',
                                              'I7',
                                              'L1',
                                              'L3',
                                              'P26',
                                              'R5',
                                              'S29')
                              THEN
                                  1
                              ELSE
                                  0
                          END)           -- DP - Disorderly/Disruptive Premise
                       + (CASE
                              WHEN v.code IN ('D22',
                                              'D7',
                                              'D8',
                                              'D9',
                                              'E7',
                                              'F10',
                                              'F18',
                                              'F24',
                                              'F33',
                                              'F34',
                                              'F35',
                                              'F38',
                                              'F40',
                                              'F41',
                                              'G5',
                                              'L4',
                                              'L5')
                              THEN
                                  1
                              ELSE
                                  0
                          END)                                    -- RO- ROSTF
                       + (CASE
                              WHEN v.code IN ('A5',
                                              'B1',
                                              'B2',
                                              'D20',
                                              'D3',
                                              'M2',
                                              'P35',
                                              'P47',
                                              'P53',
                                              'P9',
                                              'U6')
                              THEN
                                  1
                              ELSE
                                  0
                          END)                      -- WV - Weapons Violations
                       + (CASE
                              WHEN v.code IN ('I6',
                                              'O1',
                                              'P18',
                                              'P19',
                                              'P20',
                                              'U1')
                              THEN
                                  1
                              ELSE
                                  0
                          END)                         -- SP - Stolen Property
                       + (CASE
                              WHEN v.code IN ('B4',
                                              'G1',
                                              'O3',
                                              'P13',
                                              'P14',
                                              'P15')
                              THEN
                                  1
                              ELSE
                                  0
                          END)                                 -- GA- Gambling
                       + (CASE WHEN v.code IN ('P1') THEN 1 ELSE 0 END) -- SD- Soliciting Drinks
                       + (CASE
                              WHEN v.code IN ('A3',
                                              'A4',
                                              'C19',
                                              'S34')
                              THEN
                                  1
                              ELSE
                                  0
                          END)                              -- AH- After Hours
                       + (CASE
                              WHEN v.code IN ('A1',
                                              'A15',
                                              'C18',
                                              'D4',
                                              'D18',
                                              'D21',
                                              'E10',
                                              'E3',
                                              'E5',
                                              'E8',
                                              'F13',
                                              'F16',
                                              'F19',
                                              'F2',
                                              'F20',
                                              'F21',
                                              'F26',
                                              'F29',
                                              'F3',
                                              'F30',
                                              'F36',
                                              'F4',
                                              'F8',
                                              'G6',
                                              'I1',
                                              'I10',
                                              'I11',
                                              'I12',
                                              'I13',
                                              'I3',
                                              'I8',
                                              'I9',
                                              'P8',
                                              'P10',
                                              'P23',
                                              'P56',
                                              'R8',
                                              'S14',
                                              'S17',
                                              'S19',
                                              'S23',
                                              'S25',
                                              'S26',
                                              'S27',
                                              'S30',
                                              'S4',
                                              'S6',
                                              'U3',
                                              'V0',
                                              'V4',
                                              'V5',
                                              'V7',
                                              'B3',
                                              'C20',
                                              'E9',
                                              'F32',
                                              'F9',
                                              'P39',
                                              'P46',
                                              'P56',
                                              'R2',
                                              'R3',
                                              'S2',
                                              'S21',
                                              'S28',
                                              'S30',
                                              'S36',
                                              'S5',
                                              'U2',
                                              'V1',
                                              'V6',
                                              'S9')
                              THEN
                                  1
                              ELSE
                                  0
                          END)                       -- BP- Business Practices
                       + (CASE
                              WHEN v.code IN ('C15',
                                              'C4',
                                              'G2',
                                              'L7',
                                              'P24',
                                              'R1',
                                              'T3')
                              THEN
                                  1
                              ELSE
                                  0
                          END)                          -- MT- Moral Turpitude
                       + (CASE
                              WHEN v.code IN ('A10',
                                              'A11',
                                              'A12',
                                              'A13',
                                              'A14',
                                              'A2',
                                              'A6',
                                              'A7',
                                              'A8',
                                              'A9',
                                              'C0',
                                              'C11',
                                              'C12',
                                              'C14',
                                              'C17',
                                              'C2',
                                              'C5',
                                              'C6',
                                              'C8',
                                              'C9',
                                              'D1',
                                              'D10',
                                              'D11',
                                              'D12',
                                              'D13',
                                              'D14',
                                              'D15',
                                              'D17',
                                              'D19',
                                              'D2',
                                              'D23',
                                              'D24',
                                              'D5',
                                              'E4',
                                              'E6',
                                              'F0',
                                              'F1',
                                              'F11',
                                              'F12',
                                              'F14',
                                              'F15',
                                              'F17',
                                              'F22',
                                              'F23',
                                              'F25',
                                              'F27',
                                              'F28',
                                              'F31',
                                              'F37',
                                              'F42',
                                              'F43',
                                              'F44',
                                              'F5',
                                              'G3',
                                              'H1',
                                              'H2',
                                              'H3',
                                              'H4',
                                              'I2',
                                              'I4',
                                              'I5',
                                              'L10',
                                              'L2',
                                              'L6',
                                              'L8',
                                              'M1',
                                              'N1',
                                              'N2',
                                              'O2',
                                              'O4',
                                              'O5',
                                              'P16',
                                              'P25',
                                              'P27',
                                              'P28',
                                              'P29',
                                              'P30',
                                              'P31',
                                              'P36',
                                              'P37',
                                              'P40',
                                              'P44',
                                              'P45',
                                              'P6',
                                              'R4',
                                              'R6',
                                              'R7',
                                              'S15',
                                              'S22',
                                              'S32',
                                              'S33',
                                              'S7',
                                              'T1',
                                              'T2',
                                              'U2',
                                              'U4',
                                              'V10',
                                              'V8',
                                              'V9',
                                              'F7',
                                              'P5',
                                              'S1',
                                              'S3',
                                              'S20')
                              THEN
                                  1
                              ELSE
                                  0
                          END)                                    -- OT- Other
                       + (CASE
                              WHEN a.casetype = 'BACKTRACK'
                               AND v.code IN ('P17')
                              THEN
                                  1
                              ELSE
                                  0
                          END)                             -- PR- Prostitution
                       + (CASE
                              WHEN a.casetype = 'BACKTRACK'
                               AND v.code IN ('V2', 'V3', 'V11')
                              THEN
                                  1
                              ELSE
                                  0
                          END)),
                   0)                           -- VC- Violation of Conditions
          INTO p_data(10).col_3(p_column)
          FROM mart.accusationviolation  av
               JOIN mart.violation v ON v.objectid = av.violationobjectid
               JOIN mart.accusation a ON a.objectid = av.accusationobjectid
               JOIN query.o_office o ON o.objectid = a.officeid
         WHERE av.accusationobjectid IN
                   (SELECT DISTINCT a.objectid
                      FROM mart.accusation a
                     WHERE a.accusationregistereddate BETWEEN p_start_date
                                                          AND p_end_date
                       AND (a.casetype = 'BACKTRACK'))
           AND v.code NOT IN ('G3');


        -- ***********************************************************
        -- (11) Disposition of Accusations
        -- ***********************************************************
        -- NONE
        p_data(11).col_3(p_column) := NULL;


        -- ***********************************************************
        -- (12) Stipulation and Waiver
        -- ***********************************************************
        -- SWRECEIVED
        SELECT COUNT(DISTINCT o.objectid)     objectid
          INTO p_data(12).col_3(p_column)
          FROM TABLE(
                   CAST(
                       api.pkg_simplesearch.castableobjectsbyindexrange(
                           'l_DocketNoteUserLog',
                           'logdate',
                           TO_CHAR(p_start_date, 'YYYY-MM-DD'),
                           TO_CHAR(p_end_date, 'YYYY-MM-DD'))
                           AS api.udt_objectlist)) o
         WHERE api.pkg_columnquery.VALUE(o.objectid, 'eventcode') IN
                   ('16',
                    'ACC06',
                    'ACC07',
                    'ACC08',
                    'ACC09',
                    'ACC10',
                    'ACC11');


        -- ***********************************************************
        -- (13) Dismissed Accusations
        -- ***********************************************************
        -- DISMISSED
        SELECT COUNT(DISTINCT objectid)
          INTO p_data(13).col_3(p_column)
          FROM (SELECT etd.jobid     objectid
                  FROM mart.executetermsofdecision etd
                 WHERE etd.outcome = 'Dismiss'
                   AND TRUNC(etd.datecompleted) BETWEEN CASE
                                                            WHEN p_start_date <
                                                                 g_switch
                                                            THEN
                                                                p_start_date
                                                            ELSE
                                                                g_max
                                                        END
                                                    AND CASE
                                                            WHEN p_start_date >=
                                                                 g_switch
                                                            THEN
                                                                g_max
                                                            WHEN p_end_date >=
                                                                 g_switch
                                                            THEN
                                                                g_switch - 1
                                                            ELSE
                                                                p_end_date
                                                        END
                UNION
                SELECT r.toobjectid     objectid
                  FROM TABLE(
                           CAST(api.pkg_simplesearch.castableobjectsbyindexrange(
                                    'l_DocketNoteUserLog',
                                    'logdate',
                                    TO_CHAR(
                                        CASE
                                            WHEN p_start_date >= g_switch
                                            THEN
                                                p_start_date
                                            WHEN p_end_date >= g_switch
                                            THEN
                                                g_switch
                                            ELSE
                                                g_max
                                        END,
                                        'YYYY-MM-DD'),
                                    TO_CHAR(
                                        CASE
                                            WHEN p_start_date >= g_switch
                                            THEN
                                                p_end_date
                                            WHEN p_end_date >= g_switch
                                            THEN
                                                p_end_date
                                            ELSE
                                                g_max
                                        END,
                                        'YYYY-MM-DD')) AS api.udt_objectlist))
                       o
                       JOIN api.relationships r
                           ON r.fromobjectid = o.objectid
                          AND r.endpointid IN
                                  (api.pkg_configquery.endpointidforname(
                                       'l_DocketNoteUserLog',
                                       'Accusation'),
                                   api.pkg_configquery.endpointidforname(
                                       'l_DocketNoteUserLog',
                                       'License'),
                                   api.pkg_configquery.endpointidforname(
                                       'l_DocketNoteUserLog',
                                       'Application'))
                 WHERE api.pkg_columnquery.VALUE(o.objectid, 'eventcode') =
                       'ACC24');


        -- ***********************************************************
        -- (14) Number of Licensing Hearings Held
        -- ***********************************************************
        -- PROCESSHEARINGHELD
        SELECT COUNT(DISTINCT o.objectid)     objectid
          INTO p_data(14).col_3(p_column)
          FROM TABLE(
                   CAST(
                       api.pkg_simplesearch.castableobjectsbyindexrange(
                           'l_DocketNoteUserLog',
                           'logdate',
                           TO_CHAR(p_start_date, 'YYYY-MM-DD'),
                           TO_CHAR(p_end_date, 'YYYY-MM-DD'))
                           AS api.udt_objectlist)) o
         WHERE api.pkg_columnquery.VALUE(o.objectid, 'eventcode') IN
                   ('PMC09', 'PRT15');


        -- ***********************************************************
        -- (15) Penalties Imposed as a Result of a Hearing
        -- ***********************************************************
        -- PENALTIES
        SELECT COUNT(objectid)
          INTO p_data(15).col_3(p_column)
          FROM (SELECT DISTINCT j.objectid
                  FROM query.j_accusation  j
                       JOIN api.processes r ON j.objectid = r.jobid
                       JOIN query.p_executetermsofdecision d
                           ON d.objectid = r.processid
                 WHERE swsigneddate IS NULL
                   AND d.outcome IS NOT NULL
                   AND TRUNC(d.createddate) BETWEEN CASE
                                                        WHEN p_start_date <
                                                             g_switch
                                                        THEN
                                                            p_start_date
                                                        ELSE
                                                            g_max
                                                    END
                                                AND CASE
                                                        WHEN p_start_date >=
                                                             g_switch
                                                        THEN
                                                            g_max
                                                        WHEN p_end_date >=
                                                             g_switch
                                                        THEN
                                                            g_switch - 1
                                                        ELSE
                                                            p_end_date
                                                    END
                UNION
                SELECT DISTINCT r.toobjectid     objectid
                  FROM TABLE(
                           CAST(api.pkg_simplesearch.castableobjectsbyindexrange(
                                    'l_DocketNoteUserLog',
                                    'logdate',
                                    TO_CHAR(
                                        CASE
                                            WHEN p_start_date >= g_switch
                                            THEN
                                                p_start_date
                                            WHEN p_end_date >= g_switch
                                            THEN
                                                g_switch
                                            ELSE
                                                g_max
                                        END,
                                        'YYYY-MM-DD'),
                                    TO_CHAR(
                                        CASE
                                            WHEN p_start_date >= g_switch
                                            THEN
                                                p_end_date
                                            WHEN p_end_date >= g_switch
                                            THEN
                                                p_end_date
                                            ELSE
                                                g_max
                                        END,
                                        'YYYY-MM-DD')) AS api.udt_objectlist))
                       o
                       JOIN api.relationships r
                           ON r.fromobjectid = o.objectid
                          AND r.endpointid IN
                                  (api.pkg_configquery.endpointidforname(
                                       'l_DocketNoteUserLog',
                                       'Accusation'),
                                   api.pkg_configquery.endpointidforname(
                                       'l_DocketNoteUserLog',
                                       'License'),
                                   api.pkg_configquery.endpointidforname(
                                       'l_DocketNoteUserLog',
                                       'Application'))
                 WHERE api.pkg_columnquery.VALUE(o.objectid, 'eventcode') =
                       'ACC42');


        -- ***********************************************************
        -- (16) Accusations Sustained After Hearing
        -- ***********************************************************
        -- ACCSUSTAINED
        SELECT COUNT(objectid)
          INTO p_data(16).col_3(p_column)
          FROM (SELECT rad.jobid     objectid
                  FROM mart.recordappealdecision rad
                 WHERE rad.outcome = 'Upheld'
                   AND (SELECT j.jobtypeid
                          FROM api.jobs j
                         WHERE j.jobid = rad.jobid) =
                       api.pkg_configquery.objectdefidforname('j_Accusation')
                   AND TRUNC(rad.datecompleted) BETWEEN CASE
                                                            WHEN p_start_date <
                                                                 g_switch
                                                            THEN
                                                                p_start_date
                                                            ELSE
                                                                g_max
                                                        END
                                                    AND CASE
                                                            WHEN p_start_date >=
                                                                 g_switch
                                                            THEN
                                                                g_max
                                                            WHEN p_end_date >=
                                                                 g_switch
                                                            THEN
                                                                g_switch - 1
                                                            ELSE
                                                                p_end_date
                                                        END
                UNION
                SELECT r.toobjectid     objectid
                  FROM TABLE(
                           CAST(api.pkg_simplesearch.castableobjectsbyindexrange(
                                    'l_DocketNoteUserLog',
                                    'logdate',
                                    TO_CHAR(
                                        CASE
                                            WHEN p_start_date >= g_switch
                                            THEN
                                                p_start_date
                                            WHEN p_end_date >= g_switch
                                            THEN
                                                g_switch
                                            ELSE
                                                g_max
                                        END,
                                        'YYYY-MM-DD'),
                                    TO_CHAR(
                                        CASE
                                            WHEN p_start_date >= g_switch
                                            THEN
                                                p_end_date
                                            WHEN p_end_date >= g_switch
                                            THEN
                                                p_end_date
                                            ELSE
                                                g_max
                                        END,
                                        'YYYY-MM-DD')) AS api.udt_objectlist))
                       o
                       JOIN api.relationships r
                           ON r.fromobjectid = o.objectid
                          AND r.endpointid IN
                                  (api.pkg_configquery.endpointidforname(
                                       'l_DocketNoteUserLog',
                                       'Accusation'),
                                   api.pkg_configquery.endpointidforname(
                                       'l_DocketNoteUserLog',
                                       'License'),
                                   api.pkg_configquery.endpointidforname(
                                       'l_DocketNoteUserLog',
                                       'Application'))
                 WHERE api.pkg_columnquery.VALUE(o.objectid, 'eventcode') =
                       'ACC33');

        -- ***********************************************************
        -- (1) Total Number of Investigations (ABC-61) Completed
        -- ***********************************************************
        -- COMPLAINTINVESTIGATIONS + ADMININVESTIGATIONS + TRACEINVESTIGATIONS + POLICEREPORTINV"
        p_data(1).col_3(p_column) :=
              p_data(2).col_3(p_column)
            + p_data(3).col_3(p_column)
            + p_data(4).col_3(p_column)
            + p_data(5).col_3(p_column);

        -- ***********************************************************
        -- (8) Total Violation Counts Filed
        -- ***********************************************************
        -- ABCVIOLATIONS + BACKTRACKVIOLATIONS
        p_data(8).col_3(p_column) :=
            p_data(9).col_3(p_column) + p_data(10).col_3(p_column);


        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_status_msg :=
                'ws_2_enforcement.get_data: '
                || DBMS_UTILITY.format_error_backtrace
                || ' :: '
                || SQLERRM;

            RETURN FALSE;
    END;


    FUNCTION get_data(p_value        IN OUT CLOB,
                      p_start_date   IN     DATE,
                      p_end_date     IN     DATE,
                      p_status_msg   IN OUT VARCHAR2)
        RETURN BOOLEAN
    IS
        TYPE descriptionstyp IS VARRAY(16) OF VARCHAR2(200);

        lb_ok          BOOLEAN := TRUE;
        l_data         datatabtyp := datatabtyp();

        lv_descriptions descriptionstyp
            := descriptionstyp(
                   'Total Number of Investigations (ABC-61) Completed',
                   '     Complaint Investigation Assignments Complete',
                   '     Administrative Assignments Completed',
                   '     TRACE Assignments Completed',
                   '     Police Reports Assigned for Investigation (ABC-61)',
                   'Accusations Registered',
                   'Violation Counts Filed by Source',
                   '     Total Violation Counts Filed',
                   '     Violation Counts from ABC Investigations',
                   '     Violation Counts from Backtrack Investigations',
                   'Disposition of Accusations',
                   '     Stipulation and Waive',
                   '     Dismissed Accusations',
                   '     Number of Licensing Hearings Held',
                   '     Penalties Imposed as a Result of a Hearing',
                   '     Accusations Sustained After Hearing');
    BEGIN
        FOR i IN 1 .. lv_descriptions.COUNT
        LOOP
            l_data.EXTEND;

            IF (i = 14)
            THEN
                l_data(l_data.COUNT).col_1 := '*';
            END IF;

            l_data(l_data.COUNT).col_2 := lv_descriptions(i);
            l_data(l_data.COUNT).col_3 := counts(0, 0, 0);
        END LOOP;

        lb_ok :=
            get_section_data(p_data      => l_data,
                             p_column    => 3,
                             p_start_date => p_start_date,
                             p_end_date  => p_end_date,
                             p_status_msg => p_status_msg);

        IF (lb_ok)
        THEN
            lb_ok :=
                get_section_data(
                    p_data      => l_data,
                    p_column    => 2,
                    p_start_date => ADD_MONTHS(p_start_date, -12),
                    p_end_date  => ADD_MONTHS(p_end_date, -12),
                    p_status_msg => p_status_msg);
        END IF;

        IF (lb_ok)
        THEN
            lb_ok :=
                get_section_data(
                    p_data      => l_data,
                    p_column    => 1,
                    p_start_date => ADD_MONTHS(p_start_date, -24),
                    p_end_date  => ADD_MONTHS(p_end_date, -24),
                    p_status_msg => p_status_msg);
        END IF;

        DBMS_LOB.append(
            p_value,
            '"","","'
            || TO_CHAR(ADD_MONTHS(p_start_date, -24), 'MM/DD/YYYY')
            || '-'
            || TO_CHAR(ADD_MONTHS(p_end_date, -24), 'MM/DD/YYYY')
            || '   '
            || (  FLOOR(
                      MONTHS_BETWEEN(ADD_MONTHS(p_end_date, -24),
                                     ADD_MONTHS(p_start_date, -24)))
                + 1)
            || ' MONTHS","'
            || TO_CHAR(ADD_MONTHS(p_start_date, -12), 'MM/DD/YYYY')
            || '-'
            || TO_CHAR(ADD_MONTHS(p_end_date, -12), 'MM/DD/YYYY')
            || '   '
            || (  FLOOR(
                      MONTHS_BETWEEN(ADD_MONTHS(p_end_date, -12),
                                     ADD_MONTHS(p_start_date, -12)))
                + 1)
            || ' MONTHS","'
            || TO_CHAR(p_start_date, 'MM/DD/YYYY')
            || '-'
            || TO_CHAR(p_end_date, 'MM/DD/YYYY')
            || '  '
            || (FLOOR(MONTHS_BETWEEN(p_end_date, p_start_date)) + 1)
            || ' MONTHS"'
            || CHR(13)
            || CHR(10));


        FOR rec IN 1 .. l_data.COUNT
        LOOP
            DBMS_LOB.append(
                p_value,
                '"'
                || l_data(rec).col_1
                || '","'
                || l_data(rec).col_2
                || '",'
                || l_data(rec).col_3(1)
                || ','
                || l_data(rec).col_3(2)
                || ','
                || l_data(rec).col_3(3)
                || CHR(13)
                || CHR(10));
        END LOOP;

        DBMS_LOB.append(
            p_value,
            CHR(13)
            || CHR(10)
            || CHR(13)
            || CHR(10)
            || '"*","Due to the automation of this category, data prior to August 01, 2018 will not be reflected in this total.",'
            || CHR(13)
            || CHR(10));

        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_status_msg :=
                'ws_1_licensing.get_data: '
                || DBMS_UTILITY.format_error_backtrace
                || ' :: '
                || SQLERRM;

            RETURN FALSE;
    END;
--*****************************************************************************
--*****************************************************************************
--      Main Process
--*****************************************************************************
--*****************************************************************************


BEGIN
    DECLARE
        blob_          BLOB;
        lc_csv         CLOB;
        ld_start_date  DATE;
        ld_end_date    DATE;
        lv_status_msg  VARCHAR2(4000);
        lb_proc        BOOLEAN := TRUE;
    BEGIN
        DBMS_LOB.createtemporary(lob_loc     => lc_csv,
                                 cache       => TRUE,
                                 dur         => DBMS_LOB.session);

        IF (p_parms.get_value('START_DATE') IS NOT NULL)
        THEN
            ld_start_date :=
                TRUNC(TO_DATE(p_parms.get_value('START_DATE'), 'MM/DD/YYYY'));
            ld_end_date :=
                  TO_DATE(p_parms.get_value('END_DATE'), 'MM/DD/YYYY')
                + (1 - 1 / (24 * 60 * 60));
        ELSE
            lb_proc := FALSE;
            lv_status_msg := 'No report date found';
        END IF;

        p_parms.upd_value('REPORT_DATE',
                          TO_CHAR(SYSDATE, 'MM/DD/YYYY HH:MI PM'));

        lb_proc := (lv_status_msg IS NULL);

        lb_proc :=
            get_data(lc_csv,
                     ld_start_date,
                     ld_end_date,
                     lv_status_msg);

        IF (lb_proc)
        THEN
            p_status_ind := 'F';
            blob_ := rqs_utils.clob2blob(lc_csv);
        ELSE
            p_status_ind := 'E';
            blob_ := UTL_RAW.cast_to_raw(lv_status_msg);

            rqs_utils.LOG(
                p_log_type  => 'E',
                p_job_id    => p_parms.get_value('JOB_ID'),
                p_seq       => p_parms.get_value('SEQ'),
                p_source    => 'Workload Summary Enforcement Report',
                p_msg       => lv_status_msg);
        END IF;

        RETURN blob_;
    EXCEPTION
        WHEN OTHERS
        THEN
            rqs_utils.LOG(
                p_log_type  => 'E',
                p_job_id    => p_parms.get_value('JOB_ID'),
                p_seq       => p_parms.get_value('SEQ'),
                p_source    => 'ws_2_enforcement',
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
END;
/
