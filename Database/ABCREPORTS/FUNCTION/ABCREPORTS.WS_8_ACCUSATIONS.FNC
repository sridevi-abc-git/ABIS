CREATE OR REPLACE FUNCTION ABCREPORTS.ws_8_accusations(
    p_parms        IN OUT t_parameters,
    p_status_ind   IN OUT VARCHAR2)
    RETURN BLOB
IS
    -- ****************************************************************************
    -- File:        WS_8_ACCUSATIONS.FNC
    -- Author:      Timothy J. Lord
    --
    -- Description:
    --      Accusations Registered by Count
    --
    -- History:
    -------------------------------------------------------------------------------
    --    Date                  Comment
    --  09/02/2022  TJL   - Function created
    -- ****************************************************************************

    FUNCTION get_data(p_value        IN OUT CLOB,
                      p_start_date   IN     DATE,
                      p_end_date     IN     DATE,
                      p_status_msg   IN OUT VARCHAR2)
        RETURN BOOLEAN
    IS
        ln_totlreg     NUMBER := 0;
        ln_abcminor    NUMBER := 0;
        ln_abcdecoy    NUMBER := 0;
        ln_abcobvintoxicated NUMBER := 0;
        ln_abcdrugs    NUMBER := 0;
        ln_abcdisorderlyprem NUMBER := 0;
        ln_abcrostf    NUMBER := 0;
        ln_abcweaponsviolations NUMBER := 0;
        ln_abcstolenproperty NUMBER := 0;
        ln_abcgambling NUMBER := 0;
        ln_abcsolicitingdrinks NUMBER := 0;
        ln_abcafterhours NUMBER := 0;
        ln_abcbp       NUMBER := 0;
        ln_abcmoralturpitude NUMBER := 0;
        ln_abcprostitution NUMBER := 0;
        ln_abcviolationconditions NUMBER := 0;
        ln_abcother    NUMBER := 0;
        ln_abc NUMBER := 0;

        ln_btminor     NUMBER := 0;
        ln_btdecoy     NUMBER := 0;
        ln_btobvintoxicated NUMBER := 0;
        ln_btdrugs     NUMBER := 0;
        ln_btdisorderlyprem NUMBER := 0;
        ln_btrostf     NUMBER := 0;
        ln_btweaponsviolations NUMBER := 0;
        ln_btstolenproperty NUMBER := 0;
        ln_btgambling  NUMBER := 0;
        ln_btsolicitingdrinks NUMBER := 0;
        ln_btafterhours NUMBER := 0;
        ln_btbp        NUMBER := 0;
        ln_btmoralturpitude NUMBER := 0;
        ln_btprostitution NUMBER := 0;
        ln_btviolationconditions NUMBER := 0;
        ln_btother     NUMBER := 0;
        ln_bt NUMBER := 0;

        ln_totlreg_ttl NUMBER := 0;
        ln_abcminor_ttl NUMBER := 0;
        ln_abcdecoy_ttl NUMBER := 0;
        ln_abcobvintoxicated_ttl NUMBER := 0;
        ln_abcdrugs_ttl NUMBER := 0;
        ln_abcdisorderlyprem_ttl NUMBER := 0;
        ln_abcrostf_ttl NUMBER := 0;
        ln_abcweaponsviolations_ttl NUMBER := 0;
        ln_abcstolenproperty_ttl NUMBER := 0;
        ln_abcgambling_ttl NUMBER := 0;
        ln_abcsolicitingdrinks_ttl NUMBER := 0;
        ln_abcafterhours_ttl NUMBER := 0;
        ln_abcbp_ttl   NUMBER := 0;
        ln_abcmoralturpitude_ttl NUMBER := 0;
        ln_abcprostitution_ttl NUMBER := 0;
        ln_abcviolationconditions_ttl NUMBER := 0;
        ln_abcother_ttl NUMBER := 0;
        ln_abc_ttl NUMBER := 0;
        
        ln_btminor_ttl NUMBER := 0;
        ln_btdecoy_ttl NUMBER := 0;
        ln_btobvintoxicated_ttl NUMBER := 0;
        ln_btdrugs_ttl NUMBER := 0;
        ln_btdisorderlyprem_ttl NUMBER := 0;
        ln_btrostf_ttl NUMBER := 0;
        ln_btweaponsviolations_ttl NUMBER := 0;
        ln_btstolenproperty_ttl NUMBER := 0;
        ln_btgambling_ttl NUMBER := 0;
        ln_btsolicitingdrinks_ttl NUMBER := 0;
        ln_btafterhours_ttl NUMBER := 0;
        ln_btbp_ttl    NUMBER := 0;
        ln_btmoralturpitude_ttl NUMBER := 0;
        ln_btprostitution_ttl NUMBER := 0;
        ln_btviolationconditions_ttl NUMBER := 0;
        ln_btother_ttl NUMBER := 0;
        ln_bt_ttl NUMBER := 0;
    BEGIN
        FOR rec
            IN (WITH
                    info
                    AS
                        (  SELECT UPPER(SUBSTR(officename, 1, 20))
                                      officename,
                                  CASE
                                      WHEN NVL(rqsexclude, 'N') NOT IN
                                               ('H', 'B')
                                      THEN
                                          UPPER(
                                              NVL(division, 'HEADQUARTERS'))
                                      ELSE
                                          'HEADQUARTERS'
                                  END
                                      division,
                                  COUNT(DISTINCT regnumber)
                                      totlreg,
                                  SUM(CASE
                                          WHEN casetype = 'ABC'
                                           AND code IN ('C10',
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
                                      abcminor,       -- MV - minor violations
                                  SUM(CASE
                                          WHEN casetype = 'ABC'
                                           AND code IN ('S13')
                                          THEN
                                              1
                                          ELSE
                                              0
                                      END)
                                      abcdecoy,            -- MD - minor decoy
                                  SUM(CASE
                                          WHEN casetype = 'ABC'
                                           AND code IN ('C1',
                                                        'D16',
                                                        'P4',
                                                        'P42',
                                                        'P43',
                                                        'S16')
                                          THEN
                                              1
                                          ELSE
                                              0
                                      END)
                                      abcobvintoxicated, -- OI- Obviously Intoxicated
                                  SUM(CASE
                                          WHEN casetype = 'ABC'
                                           AND code IN ('C3',
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
                                      END)
                                      abcdrugs,                   -- DR- Drugs
                                  SUM(CASE
                                          WHEN casetype = 'ABC'
                                           AND code IN ('C13',
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
                                      END)
                                      abcdisorderlyprem, -- DP - Disorderly/Disruptive Premise
                                  SUM(CASE
                                          WHEN casetype = 'ABC'
                                           AND code IN ('D22',
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
                                      END)
                                      abcrostf,                   -- RO- ROSTF
                                  SUM(CASE
                                          WHEN casetype = 'ABC'
                                           AND code IN ('A5',
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
                                      END)
                                      abcweaponsviolations, -- WV - Weapons Violations
                                  SUM(CASE
                                          WHEN casetype = 'ABC'
                                           AND code IN ('I6',
                                                        'O1',
                                                        'P18',
                                                        'P19',
                                                        'P20',
                                                        'U1')
                                          THEN
                                              1
                                          ELSE
                                              0
                                      END)
                                      abcstolenproperty, -- SP - Stolen Property
                                  SUM(CASE
                                          WHEN casetype = 'BACKTRACK'
                                           AND code IN ('C10',
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
                                      btminor,        -- MV - minor violations
                                  SUM(CASE
                                          WHEN casetype = 'BACKTRACK'
                                           AND code IN ('S13')
                                          THEN
                                              1
                                          ELSE
                                              0
                                      END)
                                      btdecoy,             -- MD - minor decoy
                                  SUM(CASE
                                          WHEN casetype = 'BACKTRACK'
                                           AND code IN ('C1',
                                                        'D16',
                                                        'P4',
                                                        'P42',
                                                        'P43',
                                                        'S16')
                                          THEN
                                              1
                                          ELSE
                                              0
                                      END)
                                      btobvintoxicated, -- OI- Obviously Intoxicated
                                  SUM(CASE
                                          WHEN casetype = 'BACKTRACK'
                                           AND code IN ('C3',
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
                                      END)
                                      btdrugs,                    -- DR- Drugs
                                  SUM(CASE
                                          WHEN casetype = 'BACKTRACK'
                                           AND code IN ('C13',
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
                                      END)
                                      btdisorderlyprem, -- DP - Disorderly/Disruptive Premise
                                  SUM(CASE
                                          WHEN casetype = 'BACKTRACK'
                                           AND code IN ('D22',
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
                                      END)
                                      btrostf,                    -- RO- ROSTF
                                  SUM(CASE
                                          WHEN casetype = 'BACKTRACK'
                                           AND code IN ('A5',
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
                                      END)
                                      btweaponsviolations, -- WV - Weapons Violations
                                  SUM(CASE
                                          WHEN casetype = 'BACKTRACK'
                                           AND code IN ('I6',
                                                        'O1',
                                                        'P18',
                                                        'P19',
                                                        'P20',
                                                        'U1')
                                          THEN
                                              1
                                          ELSE
                                              0
                                      END)
                                      btstolenproperty, -- SP - Stolen Property
                                  SUM(CASE
                                          WHEN casetype = 'ABC'
                                           AND code IN ('B4',
                                                        'G1',
                                                        'O3',
                                                        'P13',
                                                        'P14',
                                                        'P15')
                                          THEN
                                              1
                                          ELSE
                                              0
                                      END)
                                      abcgambling,             -- GA- Gambling
                                  SUM(CASE
                                          WHEN casetype = 'ABC'
                                           AND code IN ('P1')
                                          THEN
                                              1
                                          ELSE
                                              0
                                      END)
                                      abcsolicitingdrinks, -- SD- Soliciting Drinks
                                  SUM(CASE
                                          WHEN casetype = 'ABC'
                                           AND code IN ('A3',
                                                        'A4',
                                                        'C19',
                                                        'S34')
                                          THEN
                                              1
                                          ELSE
                                              0
                                      END)
                                      abcafterhours,        -- AH- After Hours
                                  SUM(CASE
                                          WHEN casetype = 'ABC'
                                           AND code IN ('A1',
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
                                      END)
                                      abcbp,         -- BP- Business Practices
                                  SUM(CASE
                                          WHEN casetype = 'ABC'
                                           AND code IN ('C15',
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
                                      END)
                                      abcmoralturpitude, -- MT- Moral Turpitude
                                  SUM(CASE
                                          WHEN casetype = 'ABC'
                                           AND code IN ('A10',
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
                                      END)
                                      abcother,                   -- OT- Other
                                  SUM(CASE
                                          WHEN casetype = 'ABC'
                                           AND code IN ('P17')
                                          THEN
                                              1
                                          ELSE
                                              0
                                      END)
                                      abcprostitution,     -- PR- Prostitution
                                  SUM(CASE
                                          WHEN casetype = 'ABC'
                                           AND code IN ('V2', 'V3', 'V11')
                                          THEN
                                              1
                                          ELSE
                                              0
                                      END)
                                      abcviolationconditions, -- VC- Violation of Conditions
                                  SUM(CASE
                                          WHEN casetype = 'BACKTRACK'
                                           AND code IN ('B4',
                                                        'G1',
                                                        'O3',
                                                        'P13',
                                                        'P14',
                                                        'P15')
                                          THEN
                                              1
                                          ELSE
                                              0
                                      END)
                                      btgambling,              -- GA- Gambling
                                  SUM(CASE
                                          WHEN casetype = 'BACKTRACK'
                                           AND code IN ('P1')
                                          THEN
                                              1
                                          ELSE
                                              0
                                      END)
                                      btsolicitingdrinks, -- SD- Soliciting Drinks
                                  SUM(CASE
                                          WHEN casetype = 'BACKTRACK'
                                           AND code IN ('A3',
                                                        'A4',
                                                        'C19',
                                                        'S34')
                                          THEN
                                              1
                                          ELSE
                                              0
                                      END)
                                      btafterhours,         -- AH- After Hours
                                  SUM(CASE
                                          WHEN casetype = 'BACKTRACK'
                                           AND code IN ('A1',
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
                                      END)
                                      btbp,          -- BP- Business Practices
                                  SUM(CASE
                                          WHEN casetype = 'BACKTRACK'
                                           AND code IN ('C15',
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
                                      END)
                                      btmoralturpitude, -- MT- Moral Turpitude
                                  SUM(CASE
                                          WHEN casetype = 'BACKTRACK'
                                           AND code IN ('A10',
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
                                      END)
                                      btother,                    -- OT- Other
                                  SUM(CASE
                                          WHEN casetype = 'BACKTRACK'
                                           AND code IN ('P17')
                                          THEN
                                              1
                                          ELSE
                                              0
                                      END)
                                      btprostitution,      -- PR- Prostitution
                                  SUM(CASE
                                          WHEN casetype = 'BACKTRACK'
                                           AND code IN ('V2', 'V3', 'V11')
                                          THEN
                                              1
                                          ELSE
                                              0
                                      END)
                                      btviolationconditions -- VC- Violation of Conditions
                             FROM (SELECT o.officename,
                                          o.division,
                                          o.rqsexclude,
                                          a.casetype,
                                          a.regnumber,
                                          v.code
                                     FROM mart.accusationviolation av
                                          JOIN mart.violation v
                                              ON v.objectid =
                                                 av.violationobjectid
                                          JOIN mart.accusation a
                                              ON a.objectid =
                                                 av.accusationobjectid
                                          JOIN query.o_office o
                                              ON o.objectid = a.officeid
                                    WHERE av.accusationobjectid IN
                                              (SELECT DISTINCT a.objectid
                                                 FROM mart.accusation a
                                                WHERE a.accusationregistereddate BETWEEN p_start_date
                                                                                     AND p_end_date
                                                  AND (a.casetype = 'ABC'
                                                    OR a.casetype = 'BACKTRACK'))
                                      AND v.code NOT IN ('G3')
                                      AND o.isactive = 'Y'
                                   UNION ALL
                                   SELECT o.officename,
                                          o.division,
                                          o.rqsexclude,
                                          NULL,
                                          NULL,
                                          NULL
                                     FROM query.o_office o
                                    WHERE o.isactive = 'Y')
                         GROUP BY officename, division, rqsexclude)
                  SELECT info.*,
                         (  NVL(abcminor, 0)          -- MV - minor violations
                          + NVL(abcdecoy, 0)               -- MD - minor decoy
                          + NVL(abcobvintoxicated, 0) -- OI - Obviously Intoxicated
                          + NVL(abcdrugs, 0)                     -- DR - Drugs
                          + NVL(abcdisorderlyprem, 0) -- DP - Disorderly/Disruptive Premise
                          + NVL(abcrostf, 0)                     -- RO - ROSTF
                          + NVL(abcweaponsviolations, 0) -- WV - Weapons Violations
                          + NVL(abcstolenproperty, 0)  -- SP - Stolen Property
                          + NVL(abcgambling, 0)               -- GA - Gambling
                          + NVL(abcsolicitingdrinks, 0) -- SD - Soliciting Drinks
                          + NVL(abcafterhours, 0)          -- AH - After Hours
                          + NVL(abcbp, 0)           -- BP - Business Practices
                          + NVL(abcmoralturpitude, 0)  -- MT - Moral Turpitude
                          + NVL(abcprostitution, 0)       -- PR - Prostitution
                          + NVL(abcviolationconditions, 0) -- VC - Violation of Conditions
                          + NVL(abcother, 0))                                  abc,
                         (  NVL(btminor, 0)           -- MV - minor violations
                          + NVL(btdecoy, 0)                -- MD - minor decoy
                          + NVL(btobvintoxicated, 0) -- OI - Obviously Intoxicated
                          + NVL(btdrugs, 0)                      -- DR - Drugs
                          + NVL(btdisorderlyprem, 0) -- DP - Disorderly/Disruptive Premise
                          + NVL(btrostf, 0)                      -- RO - ROSTF
                          + NVL(btweaponsviolations, 0) -- WV - Weapons Violations
                          + NVL(btstolenproperty, 0)   -- SP - Stolen Property
                          + NVL(btgambling, 0)                -- GA - Gambling
                          + NVL(btsolicitingdrinks, 0) -- SD - Soliciting Drinks
                          + NVL(btafterhours, 0)           -- AH - After Hours
                          + NVL(btbp, 0)            -- BP - Business Practices
                          + NVL(btmoralturpitude, 0)   -- MT - Moral Turpitude
                          + NVL(btprostitution, 0)        -- PR - Prostitution
                          + NVL(btviolationconditions, 0) -- VC - Violation of Conditions
                          + NVL(btother, 0))                                   bt,
                         LEAD(info.division, 1, NULL)
                             OVER (ORDER BY info.division, info.officename)    div_next
                    FROM info
                ORDER BY info.division, officename)
        LOOP
            IF (dbms_lob.getlength(p_value) = 0)
            THEN
                -- add first two header lines
                DBMS_LOB.append(
                    p_value,
                    '" '
                    || '","Total Accusations Registered","Minor Violations","Minor Violations","Minor Decoy","Minor Decoy",'
                    || '"Obviously Intoxicated","Obviously Intoxicated","Drugs","Drugs","Disorderly / Disruptive Premise","Disorderly / Disruptive Premise",'
                    || '"ROSTF","ROSTF","Weapons Violations","Weapons Violations",'
                    || '"Stolen Property","Stolen Property","Gambling","Gambling","Soliciting Drinks","Soliciting Drinks","After Hours","After Hours",'
                    || '"Business Practices","Business Practices","Moral Turpitude","Moral Turpitude","Prostitution","Prostitution",'
                    || '"Violation of Conditions","Violation of Conditions","Other","Other","Total Violations","Total Violations"'
                    || CHR(13)
                    || CHR(10));

                DBMS_LOB.append(
                    p_value,
                    '"'
                    || rec.division
                    || '","","ABC","BT","ABC","BT","ABC","BT","ABC","BT","ABC","BT","ABC","BT","ABC","BT","ABC","BT","ABC","BT","ABC","BT",'
                    || '"ABC","BT","ABC","BT","ABC","BT","ABC","BT","ABC","BT","ABC","BT","ABC","BT"'
                    || CHR(13)
                    || CHR(10));
            END IF;

            DBMS_LOB.append(
                p_value,
                '"'
                || rec.officename
                || '",'
                || NVL(rec.totlreg, 0)         -- Total Accusations Registered
                || ','
                || NVL(rec.abcminor, 0)               -- MV - minor violations
                || ','
                || NVL(rec.btminor, 0)                -- MV - minor violations
                || ','
                || NVL(rec.abcdecoy, 0)                    -- MD - minor decoy
                || ','
                || NVL(rec.btdecoy, 0)                     -- MD - minor decoy
                || ','
                || NVL(rec.abcobvintoxicated, 0) -- OI - Obviously Intoxicated
                || ','
                || NVL(rec.btobvintoxicated, 0)  -- OI - Obviously Intoxicated
                || ','
                || NVL(rec.abcdrugs, 0)                          -- DR - Drugs
                || ','
                || NVL(rec.btdrugs, 0)                           -- DR - Drugs
                || ','
                || NVL(rec.abcdisorderlyprem, 0) -- DP - Disorderly/Disruptive Premise
                || ','
                || NVL(rec.btdisorderlyprem, 0) -- DP - Disorderly/Disruptive Premise
                || ','
                || NVL(rec.abcrostf, 0)                          -- RO - ROSTF
                || ','
                || NVL(rec.btrostf, 0)                           -- RO - ROSTF
                || ','
                || NVL(rec.abcweaponsviolations, 0) -- WV - Weapons Violations
                || ','
                || NVL(rec.btweaponsviolations, 0)  -- WV - Weapons Violations
                || ','
                || NVL(rec.abcstolenproperty, 0)       -- SP - Stolen Property
                || ','
                || NVL(rec.btstolenproperty, 0)        -- SP - Stolen Property
                || ','
                || NVL(rec.abcgambling, 0)                    -- GA - Gambling
                || ','
                || NVL(rec.btgambling, 0)                     -- GA - Gambling
                || ','
                || NVL(rec.abcsolicitingdrinks, 0)   -- SD - Soliciting Drinks
                || ','
                || NVL(rec.btsolicitingdrinks, 0)    -- SD - Soliciting Drinks
                || ','
                || NVL(rec.abcafterhours, 0)               -- AH - After Hours
                || ','
                || NVL(rec.btafterhours, 0)                -- AH - After Hours
                || ','
                || NVL(rec.abcbp, 0)                -- BP - Business Practices
                || ','
                || NVL(rec.btbp, 0)                 -- BP - Business Practices
                || ','
                || NVL(rec.abcmoralturpitude, 0)       -- MT - Moral Turpitude
                || ','
                || NVL(rec.btmoralturpitude, 0)        -- MT - Moral Turpitude
                || ','
                || NVL(rec.abcprostitution, 0)            -- PR - Prostitution
                || ','
                || NVL(rec.btprostitution, 0)             -- PR - Prostitution
                || ','
                || NVL(rec.abcviolationconditions, 0) -- VC - Violation of Conditions
                || ','
                || NVL(rec.btviolationconditions, 0) -- VC - Violation of Conditions
                || ','
                || NVL(rec.abcother, 0)                          -- OT - Other
                || ','
                || NVL(rec.btother, 0)                           -- OT - Other
                || ','
                || NVL(rec.abc, 0)                         -- total violations
                || ','
                || NVL(rec.bt, 0)                          -- total violations
                || CHR(13)
                || CHR(10));



            -- add to division totals
            ln_totlreg := ln_totlreg + NVL(rec.totlreg, 0);

            ln_abcminor := ln_abcminor + NVL(rec.abcminor, 0); -- MV - minor violations
            ln_abcdecoy := ln_abcdecoy + NVL(rec.abcdecoy, 0); -- MD - minor decoy
            ln_abcobvintoxicated :=
                ln_abcobvintoxicated + NVL(rec.abcobvintoxicated, 0); -- OI - Obviously Intoxicated
            ln_abcdrugs := ln_abcdrugs + NVL(rec.abcdrugs, 0);   -- DR - Drugs
            ln_abcdisorderlyprem :=
                ln_abcdisorderlyprem + NVL(rec.abcdisorderlyprem, 0); -- DP - Disorderly/Disruptive Premise
            ln_abcrostf := ln_abcrostf + NVL(rec.abcrostf, 0);   -- RO - ROSTF
            ln_abcweaponsviolations :=
                ln_abcweaponsviolations + NVL(rec.abcweaponsviolations, 0); -- WV - Weapons Violations
            ln_abcstolenproperty :=
                ln_abcstolenproperty + NVL(rec.abcstolenproperty, 0); -- SP - Stolen Property
            ln_abcgambling := ln_abcgambling + NVL(rec.abcgambling, 0); -- GA - Gambling
            ln_abcsolicitingdrinks :=
                ln_abcsolicitingdrinks + NVL(rec.abcsolicitingdrinks, 0); -- SD - Soliciting Drinks
            ln_abcafterhours := ln_abcafterhours + NVL(rec.abcafterhours, 0); -- AH - After Hours
            ln_abcbp := ln_abcbp + NVL(rec.abcbp, 0); -- BP - Business Practices
            ln_abcmoralturpitude :=
                ln_abcmoralturpitude + NVL(rec.abcmoralturpitude, 0); -- MT - Moral Turpitude
            ln_abcprostitution :=
                ln_abcprostitution + NVL(rec.abcprostitution, 0); -- PR - Prostitution
            ln_abcviolationconditions :=
                  ln_abcviolationconditions
                + NVL(rec.abcviolationconditions, 0); -- VC - Violation of Conditions
            ln_abcother := ln_abcother + NVL(rec.abcother, 0);   -- OT - Other
            ln_abc := ln_abc + nvl(rec.abc, 0);
            
            ln_btminor := ln_btminor + NVL(rec.btminor, 0); -- MV - minor violations
            ln_btdecoy := ln_btdecoy + NVL(rec.btdecoy, 0); -- MD - minor decoy
            ln_btobvintoxicated :=
                ln_btobvintoxicated + NVL(rec.btobvintoxicated, 0); -- OI - Obviously Intoxicated
            ln_btdrugs := ln_btdrugs + NVL(rec.btdrugs, 0);      -- DR - Drugs
            ln_btdisorderlyprem :=
                ln_btdisorderlyprem + NVL(rec.btdisorderlyprem, 0); -- DP - Disorderly/Disruptive Premise
            ln_btrostf := ln_btrostf + NVL(rec.btrostf, 0);      -- RO - ROSTF
            ln_btweaponsviolations :=
                ln_btweaponsviolations + NVL(rec.btweaponsviolations, 0); -- WV - Weapons Violations
            ln_btstolenproperty :=
                ln_btstolenproperty + NVL(rec.btstolenproperty, 0); -- SP - Stolen Property
            ln_btgambling := ln_btgambling + NVL(rec.btgambling, 0); -- GA - Gambling
            ln_btsolicitingdrinks :=
                ln_btsolicitingdrinks + NVL(rec.btsolicitingdrinks, 0); -- SD - Soliciting Drinks
            ln_btafterhours := ln_btafterhours + NVL(rec.btafterhours, 0); -- AH - After Hours
            ln_btbp := ln_btbp + NVL(rec.btbp, 0);  -- BP - Business Practices
            ln_btmoralturpitude :=
                ln_btmoralturpitude + NVL(rec.btmoralturpitude, 0); -- MT - Moral Turpitude
            ln_btprostitution :=
                ln_btprostitution + NVL(rec.btprostitution, 0); -- PR - Prostitution
            ln_btviolationconditions :=
                ln_btviolationconditions + NVL(rec.btviolationconditions, 0); -- VC - Violation of Conditions
            ln_btother := ln_btother + NVL(rec.btother, 0);      -- OT - Other
            ln_bt := ln_bt + nvl(rec.bt, 0);
            
            -- add to statewide totals
            ln_totlreg_ttl := ln_totlreg_ttl + NVL(rec.totlreg, 0);
            ln_abcminor_ttl := ln_abcminor_ttl + NVL(rec.abcminor, 0); -- MV - minor violations
            ln_abcdecoy_ttl := ln_abcdecoy_ttl + NVL(rec.abcdecoy, 0); -- MD - minor decoy
            ln_abcobvintoxicated_ttl :=
                ln_abcobvintoxicated_ttl + NVL(rec.abcobvintoxicated, 0); -- OI - Obviously Intoxicated
            ln_abcdrugs_ttl := ln_abcdrugs_ttl + NVL(rec.abcdrugs, 0); -- DR - Drugs
            ln_abcdisorderlyprem_ttl :=
                ln_abcdisorderlyprem_ttl + NVL(rec.abcdisorderlyprem, 0); -- DP - Disorderly/Disruptive Premise
            ln_abcrostf_ttl := ln_abcrostf_ttl + NVL(rec.abcrostf, 0); -- RO - ROSTF
            ln_abcweaponsviolations_ttl :=
                  ln_abcweaponsviolations_ttl
                + NVL(rec.abcweaponsviolations, 0); -- WV - Weapons Violations
            ln_abcstolenproperty_ttl :=
                ln_abcstolenproperty_ttl + NVL(rec.abcstolenproperty, 0); -- SP - Stolen Property
            ln_abcgambling_ttl :=
                ln_abcgambling_ttl + NVL(rec.abcgambling, 0); -- GA - Gambling
            ln_abcsolicitingdrinks_ttl :=
                ln_abcsolicitingdrinks_ttl + NVL(rec.abcsolicitingdrinks, 0); -- SD - Soliciting Drinks
            ln_abcafterhours_ttl :=
                ln_abcafterhours_ttl + NVL(rec.abcafterhours, 0); -- AH - After Hours
            ln_abcbp_ttl := ln_abcbp_ttl + NVL(rec.abcbp, 0); -- BP - Business Practices
            ln_abcmoralturpitude_ttl :=
                ln_abcmoralturpitude_ttl + NVL(rec.abcmoralturpitude, 0); -- MT - Moral Turpitude
            ln_abcprostitution_ttl :=
                ln_abcprostitution_ttl + NVL(rec.abcprostitution, 0); -- PR - Prostitution
            ln_abcviolationconditions_ttl :=
                  ln_abcviolationconditions_ttl
                + NVL(rec.abcviolationconditions, 0); -- VC - Violation of Conditions
            ln_abcother_ttl := ln_abcother_ttl + NVL(rec.abcother, 0); -- OT - Other
            ln_abc_ttl := ln_abc_ttl + nvl(rec.abc, 0);
            
            ln_btminor_ttl := ln_btminor_ttl + NVL(rec.btminor, 0); -- MV - minor violations
            ln_btdecoy_ttl := ln_btdecoy_ttl + NVL(rec.btdecoy, 0); -- MD - minor decoy
            ln_btobvintoxicated_ttl :=
                ln_btobvintoxicated_ttl + NVL(rec.btobvintoxicated, 0); -- OI - Obviously Intoxicated
            ln_btdrugs_ttl := ln_btdrugs_ttl + NVL(rec.btdrugs, 0); -- DR - Drugs
            ln_btdisorderlyprem_ttl :=
                ln_btdisorderlyprem_ttl + NVL(rec.btdisorderlyprem, 0); -- DP - Disorderly/Disruptive Premise
            ln_btrostf_ttl := ln_btrostf_ttl + NVL(rec.btrostf, 0); -- RO - ROSTF
            ln_btweaponsviolations_ttl :=
                ln_btweaponsviolations_ttl + NVL(rec.btweaponsviolations, 0); -- WV - Weapons Violations
            ln_btstolenproperty_ttl :=
                ln_btstolenproperty_ttl + NVL(rec.btstolenproperty, 0); -- SP - Stolen Property
            ln_btgambling_ttl := ln_btgambling_ttl + NVL(rec.btgambling, 0); -- GA - Gambling
            ln_btsolicitingdrinks_ttl :=
                ln_btsolicitingdrinks_ttl + NVL(rec.btsolicitingdrinks, 0); -- SD - Soliciting Drinks
            ln_btafterhours_ttl :=
                ln_btafterhours_ttl + NVL(rec.btafterhours, 0); -- AH - After Hours
            ln_btbp_ttl := ln_btbp_ttl + NVL(rec.btbp, 0); -- BP - Business Practices
            ln_btmoralturpitude_ttl :=
                ln_btmoralturpitude_ttl + NVL(rec.btmoralturpitude, 0); -- MT - Moral Turpitude
            ln_btprostitution_ttl :=
                ln_btprostitution_ttl + NVL(rec.btprostitution, 0); -- PR - Prostitution
            ln_btviolationconditions_ttl :=
                  ln_btviolationconditions_ttl
                + NVL(rec.btviolationconditions, 0); -- VC - Violation of Conditions
            ln_btother_ttl := ln_btother_ttl + NVL(rec.btother, 0); -- OT - Other
            ln_bt_ttl := ln_bt_ttl + nvl(rec.bt, 0);


            -- check if next record is the next division or last record
            --   Add division totals to report and rest division totals
            IF (rec.division != NVL(rec.div_next, 'END'))
            THEN
                -- output division totals
                DBMS_LOB.append(
                    p_value,
                    '"    '
                    || UPPER(rec.division)
                    || ' TOTALS",'
                    || ln_totlreg
                    || ','
                    || ln_abcminor
                    || ','
                    || ln_btminor
                    || ','
                    || ln_abcdecoy
                    || ','
                    || ln_btdecoy
                    || ','
                    || ln_abcobvintoxicated
                    || ','
                    || ln_btobvintoxicated
                    || ','
                    || ln_abcdrugs
                    || ','
                    || ln_btdrugs
                    || ','
                    || ln_abcdisorderlyprem
                    || ','
                    || ln_btdisorderlyprem
                    || ','
                    || ln_abcrostf
                    || ','
                    || ln_btrostf
                    || ','
                    || ln_abcweaponsviolations
                    || ','
                    || ln_btweaponsviolations
                    || ','
                    || ln_abcstolenproperty
                    || ','
                    || ln_btstolenproperty
                    || ','
                    || ln_abcgambling
                    || ','
                    || ln_btgambling
                    || ','
                    || ln_abcsolicitingdrinks
                    || ','
                    || ln_btsolicitingdrinks
                    || ','
                    || ln_abcafterhours
                    || ','
                    || ln_btafterhours
                    || ','
                    || ln_abcbp
                    || ','
                    || ln_btbp
                    || ','
                    || ln_abcmoralturpitude
                    || ','
                    || ln_btmoralturpitude
                    || ','
                    || ln_abcprostitution
                    || ','
                    || ln_btprostitution
                    || ','
                    || ln_abcviolationconditions
                    || ','
                    || ln_btviolationconditions
                    || ','
                    || ln_abcother
                    || ','
                    || ln_btother
                    || ','
                    || ln_abc
                    || ','
                    || ln_bt
                    || CHR(13)
                    || CHR(10));

                -- clear division totals
                ln_totlreg := 0;
                ln_abcminor := 0;
                ln_abcdecoy := 0;
                ln_abcobvintoxicated := 0;
                ln_abcdrugs := 0;
                ln_abcdisorderlyprem := 0;
                ln_abcrostf := 0;
                ln_abcweaponsviolations := 0;
                ln_abcstolenproperty := 0;
                ln_abcgambling := 0;
                ln_abcsolicitingdrinks := 0;
                ln_abcafterhours := 0;
                ln_abcbp := 0;
                ln_abcmoralturpitude := 0;
                ln_abcprostitution := 0;
                ln_abcviolationconditions := 0;
                ln_abcother := 0;
                ln_abc := 0;
                
                ln_btminor := 0;
                ln_btdecoy := 0;
                ln_btobvintoxicated := 0;
                ln_btdrugs := 0;
                ln_btdisorderlyprem := 0;
                ln_btrostf := 0;
                ln_btweaponsviolations := 0;
                ln_btstolenproperty := 0;
                ln_btgambling := 0;
                ln_btsolicitingdrinks := 0;
                ln_btafterhours := 0;
                ln_btbp := 0;
                ln_btmoralturpitude := 0;
                ln_btprostitution := 0;
                ln_btviolationconditions := 0;
                ln_btother := 0;
                ln_bt := 0;

                IF (rec.div_next IS NOT NULL)
                THEN
                    -- add next column headers
                    DBMS_LOB.append(
                        p_value,
                           CHR(13)
                        || CHR(10)
                        || '" '
                        || '","Total Accusations Registered","Minor Violations","Minor Violations","Minor Decoy","Minor Decoy",'
                        || '"Obviously Intoxicated","Obviously Intoxicated","Drugs","Drugs","Disorderly / Disruptive Premise","Disorderly / Disruptive Premise",'
                        || '"ROSTF","ROSTF","Weapons Violations","Weapons Violations",'
                        || '"Stolen Property","Stolen Property","Gambling","Gambling","Soliciting Drinks","Soliciting Drinks","After Hours","After Hours",'
                        || '"Business Practices","Business Practices","Moral Turpitude","Moral Turpitude","Prostitution","Prostitution",'
                        || '"Violation of Conditions","Violation of Conditions","Other","Other","Total Violations","Total Violations"'
                        || CHR(13)
                        || CHR(10));

                    DBMS_LOB.append(
                        p_value,
                        '"'
                        || rec.div_next
                        || '","","ABC","BT","ABC","BT","ABC","BT","ABC","BT","ABC","BT","ABC","BT","ABC","BT","ABC","BT","ABC","BT","ABC","BT",'
                        || '"ABC","BT","ABC","BT","ABC","BT","ABC","BT","ABC","BT","ABC","BT","ABC","BT"'
                        || CHR(13)
                        || CHR(10));
                END IF;
            END IF;
        END LOOP;


        DBMS_LOB.append(
            p_value,
            CHR(13)
            || CHR(10)
            || '"    STATEWIDE TOTALS",'
            || ln_totlreg_ttl
            || ','
            || ln_abcminor_ttl
            || ','
            || ln_btminor_ttl
            || ','
            || ln_abcdecoy_ttl
            || ','
            || ln_btdecoy_ttl
            || ','
            || ln_abcobvintoxicated_ttl
            || ','
            || ln_btobvintoxicated_ttl
            || ','
            || ln_abcdrugs_ttl
            || ','
            || ln_btdrugs_ttl
            || ','
            || ln_abcdisorderlyprem_ttl
            || ','
            || ln_btdisorderlyprem_ttl
            || ','
            || ln_abcrostf_ttl
            || ','
            || ln_btrostf_ttl
            || ','
            || ln_abcweaponsviolations_ttl
            || ','
            || ln_btweaponsviolations_ttl
            || ','
            || ln_abcstolenproperty_ttl
            || ','
            || ln_btstolenproperty_ttl
            || ','
            || ln_abcgambling_ttl
            || ','
            || ln_btgambling_ttl
            || ','
            || ln_abcsolicitingdrinks_ttl
            || ','
            || ln_btsolicitingdrinks_ttl
            || ','
            || ln_abcafterhours_ttl
            || ','
            || ln_btafterhours_ttl
            || ','
            || ln_abcbp_ttl
            || ','
            || ln_btbp_ttl
            || ','
            || ln_abcmoralturpitude_ttl
            || ','
            || ln_btmoralturpitude_ttl
            || ','
            || ln_abcprostitution_ttl
            || ','
            || ln_btprostitution_ttl
            || ','
            || ln_abcviolationconditions_ttl
            || ','
            || ln_btviolationconditions_ttl
            || ','
            || ln_abcother_ttl
            || ','
            || ln_btother_ttl
            || ','
            || ln_abc_ttl
            || ','
            || ln_bt_ttl
            || CHR(13)
            || CHR(10));

        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_status_msg :=
                'ws_8_accusations.get_data: '
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

            rqs_utils.LOG(p_log_type  => 'E',
                          p_job_id    => p_parms.get_value('JOB_ID'),
                          p_seq       => p_parms.get_value('SEQ'),
                          p_source    => 'Workload Summary Report',
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
                p_source    => 'ws_8_accusations',
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
