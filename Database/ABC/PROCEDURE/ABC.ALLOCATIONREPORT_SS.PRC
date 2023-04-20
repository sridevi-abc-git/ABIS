CREATE OR REPLACE PROCEDURE ABC.AllocationReport_ss(
    a_StartDate DATE,
    a_EndDate   DATE,
    a_debug     CHAR,
    a_run_id    NUMBER )
AS
  /******************************************************************************
  NAME:       ABC Allocation Report
  PURPOSE:    POSSE Allocation Report uses Oracle temporary tables, but this procedure uses physical tables to perform research on the calculation for any activity(revenue) code.
  BUSINESS:   Accounting uses this report to send amounts to other agencies like DMV, and Randy uses this report to find the reasons for fee increase
  Use parameters:
  A_STARTDATE   - Fiscal quarter start date with DD-MON-YY format eg. 01-JUL-17
  A_ENDDATE  - Fiscal quarter last date with DD-MON-YY format eg. 30-SEP-17
  A_DEBUG   - Y/N (Yes means will display dynamic messages in the output window(DBMS_OUTPUT) and No means suppresses all output messages)
  a_run_id   - Use different runid, if you want to run multiple times for the same date range
  Sample to Run:
  DECLARE
  A_STARTDATE DATE;
  A_ENDDATE DATE;
  A_DEBUG CHAR(200);
  a_run_id number;
  BEGIN
  A_STARTDATE := '01-OCT-17';
  A_ENDDATE := '31-DEC-17';
  A_DEBUG := 'N';
  a_run_id := 1; -- Use different runid, if you want to run multiple times for the same date range
  ALLOCATIONREPORT_SS(
  A_STARTDATE => A_STARTDATE,
  A_ENDDATE => A_ENDDATE,
  A_DEBUG => A_DEBUG,
  a_run_id => a_run_id
  );
  END;
  REVISIONS:
  Ver        Date        Author          Description
  ---------  ----------  --------------  ------------------------------------
  1.1        7/17/2018   Sheik           1.  POSSE Allocation Report
  ******************************************************************************/
  t_allocationcode      VARCHAR2(10);
  t_annualfees          NUMBER := 0;
  t_appealboard         NUMBER := 0;
  t_absurchargepct      NUMBER := 0;
  t_ABSurcharge_flag    NUMBER := 0; -- Sheik 12/24 To include the AB surcharge into staging table
  t_b11a1               NUMBER := 0;
  t_b11a1sur            NUMBER := 0;
  t_b11a2               NUMBER := 0;
  t_b11a2sur            NUMBER := 0;
  t_badmastercount      NUMBER := 0;
  t_badmastercount_flag NUMBER := 0; -- Sheik 12/24 To include the dmv surcharge into staging table
  t_otherDMVcount       NUMBER := 0; -- Sheik 12/18 To count the rest of the missing licenses
  t_otherDMVcount_flag  NUMBER := 0; -- Sheik 12/24 To include the dmv surcharge into staging table
  t_bpu2421count        NUMBER := 0;
  t_bpu2421count_flag   NUMBER := 0; -- Sheik 12/24 To include the dmv surcharge into staging table
  t_bpu2466count        NUMBER := 0;
  t_bpu2466count_flag   NUMBER := 0; -- Sheik 12/24 To include the dmv surcharge into staging table
  t_bpu52count          NUMBER := 0;
  t_bpu52count_flag     NUMBER := 0; -- Sheik 12/24 To include the dmv surcharge into staging table
  t_bpuamount           NUMBER := 0;
  t_bpu24surcharge      NUMBER := 0;
  t_bpu52surcharge      NUMBER := 0;
  t_caterrauth583       NUMBER := 0;
  t_caterrpermit        NUMBER := 0;
  t_clubcat             NUMBER := 0;
  t_clubcatsur          NUMBER := 0;
  t_cond803             NUMBER := 0;
  t_dishonored          NUMBER := 0;
  t_dmvfund             NUMBER := 0;
  t_dmvsurcharge        NUMBER := 0;
  t_epaauth583          NUMBER := 0;
  t_epapermit           NUMBER := 0;
  t_exchange            NUMBER := 0;
  t_expirationdate      DATE;
  t_feeactivity         VARCHAR2(10);
  t_feeamount           NUMBER := 0;
  t_feesurchargepct     NUMBER := 0;
  t_fingerprint         NUMBER := 0;
  t_lastamount          NUMBER := 0;
  t_lastrecord          VARCHAR2(100);
  t_manageq321          NUMBER := 0;
  t_oahsurchargepct     NUMBER := 0;
  t_offcount            NUMBER := 0;
  t_oncount             NUMBER := 0;
  t_offcount_flag       NUMBER := 0; -- Sheik 12/24 To include the dmv surcharge into staging table
  t_oncount_flag        NUMBER := 0; -- Sheik 12/24 To include the dmv surcharge into staging table
  t_oldb11a1            NUMBER := 0;
  t_oldb11a1sur         NUMBER := 0;
  t_oldclubcat          NUMBER := 0;
  t_oldclubcatsur       NUMBER := 0;
  t_orioosc             NUMBER := 0;
  t_other               NUMBER := 0;
  t_paidamount          NUMBER := 0;
  t_penalty             NUMBER := 0;
  t_penamount           NUMBER := 0;
  t_poic                NUMBER := 0;
  t_prevpaid            NUMBER := 0;
  t_privware            NUMBER := 0;
  t_relatedrecord       VARCHAR2(1);
  t_renamount           NUMBER := 0;
  t_replace             NUMBER := 0;
  t_seacount            NUMBER := 0;
  t_seacount_flag       NUMBER := 0; -- Sheik 12/24 To include the dmv surcharge into staging table
  t_sec070tranfr        NUMBER := 0;
  t_sec053bpu           NUMBER := 0;
  t_sec202              NUMBER := 0;
  t_sec203              NUMBER := 0;
  t_sec357out           NUMBER := 0;
  t_sec659rec           NUMBER := 0;
  t_sec659tag           NUMBER := 0;
  t_sec761096nonsurg    NUMBER := 0;
  t_sec761096surg       NUMBER := 0;
  t_sec954ori           NUMBER := 0;
  t_sec959srvsmg        NUMBER := 0;
  t_scheduleid api.pkg_definition.udt_id; --udt_Id;
  t_tempdaily  NUMBER := 0;
  t_unclaim    NUMBER := 0;
  t_unpaidren  NUMBER := 0;
  t_winesafety NUMBER := 0;
  v_row        NUMBER := 1;
  /*---------------------------------------------------------------------------
  * Types
  *-------------------------------------------------------------------------*/
  SUBTYPE udt_id
IS
  api.pkg_definition.udt_id;
  SUBTYPE udt_endpoint
IS
  api.pkg_definition.udt_endpoint;
  SUBTYPE udt_objectlist
IS
  api.udt_objectlist;
BEGIN
  dbms_output.put_line('Starting... ');
  -- DELETE from abc.AllocationReportDetail;
  -- delete from abc.AllocationReport;
  -- delete from abc.ALLOCATION_LICENSEFEE_DET;
  COMMIT;
  dbms_output.put_line('Deleted records from allocation tables');
  -- Set values for Surcharge Amounts
  -- t_dmvsurcharge    := 5; Sheik DMV fee increase
  t_bpu24surcharge  := 24;
  t_bpu52surcharge  := 52;
  t_feesurchargepct := 0.1;
  t_oahsurchargepct := 0.06;
  t_absurchargepct  := 0.03;
  FOR c IN
  (SELECT NVL( api.pkg_columnquery.numericvalue(ps.objectid, 'EarnedAmount'), 0) amount,
    api.pkg_columnquery.VALUE(ps.objectid, 'Converted') converted,
    api.pkg_columnquery.VALUE(ps.objectid, 'TransactionCode') description,
    api.pkg_columnquery.datevalue(f.objectid, 'RENExpirationDate') expirationdate,
    NVL(api.pkg_columnquery.VALUE(ps.objectid, 'FeeActivity'), 'UTR') feeactivity,
    api.pkg_columnquery.numericvalue(f.objectid, 'FeeId') feeid,
    api.pkg_columnquery.VALUE(ps.objectid, 'GallonageFeeCode') gallonagerange,
    api.pkg_columnquery.VALUE(ps.objectid, 'IsMaster') ismaster,
    api.pkg_columnquery.numericvalue(f.objectid, 'JobId') jobid,
    api.pkg_columnquery.VALUE( (api.pkg_columnquery.numericvalue(f.objectid, 'JobId')), 'LicenseNumber') licensenumber,
    NVL( api.pkg_columnquery.VALUE(ps.objectid, 'LicenseTypeCode'), 'NA') licensetypecode,
    api.pkg_columnquery.VALUE(ps.objectid, 'MasterLT') masterlt,
    api.pkg_columnquery.VALUE(ps.objectid, 'NumberOfMonthsLicensedFeeCode') numberofmonthslicensed,
    api.pkg_columnquery.VALUE(ps.objectid, 'PopulationRangeFeeCode') populationrange,
    api.pkg_columnquery.VALUE(pt.objectid, 'FeeScheduleDescriptionForGrid') ptdescription,
    api.pkg_columnquery.VALUE(ps.objectid, 'SecondaryCount') secondarycount,
    ft.transactionid,
    f.transactiondate transaction_dt,
    f.posteddate posted_dt,
    api.pkg_columnquery.VALUE(ps.objectid, 'dup_CreatedDate') created_dt
  FROM TABLE( CAST( api.pkg_simplesearch.castableobjectsbyindexrange( 'o_PaymentStatus', 'dup_CreatedDate', TO_CHAR(a_startdate, 'YYYY-MM-DD'), TO_CHAR(a_enddate, 'YYYY-MM-DD')) AS api.udt_objectlist)) ps
  JOIN api.objects o
  ON o.objectid = ps.objectid
  JOIN query.r_paymentstatuspaymenttrans pspt
  ON pspt.paymentstatusobjectid = o.objectid
  JOIN query.o_paymenttransactions pt
  ON pt.objectid = pspt.paymenttransactionobjectid
  JOIN api.feetransactions ft
  ON ft.transactionid = pt.transactionid
  JOIN api.fees af
  ON af.feeid = ft.feeid
  JOIN query.o_fee f
  ON f.objectid = api.pkg_simplesearch.objectbyindex('o_fee', 'FeeId', af.feeid)
  JOIN api.relationships r
  ON r.fromobjectid = f.objectid
  AND r.endpointid IN (api.pkg_configquery.endpointidforname( 'o_Fee', 'LicenseFeeSchedule'), api.pkg_configquery.endpointidforname( 'o_Fee', 'MiscFeeSchedule'))
  LEFT OUTER JOIN query.o_miscfeeschedule mfs
  ON mfs.objectid                                                = r.toobjectid
  WHERE (api.pkg_columnquery.VALUE(ps.objectid, 'Converted')     = 'N' -- not converted
  AND (mfs.code                                                 IS NULL
  OR mfs.code                                                    = 'UTR'))
  OR (api.pkg_columnquery.VALUE(ps.objectid, 'Converted')        = 'Y' --when it is converted
  AND api.pkg_columnquery.VALUE(ps.objectid, 'FeeActivity') NOT IN
    (SELECT m.code FROM query.o_miscfeeschedule m WHERE m.code <> 'UTR'
    ))
  )
  /*order by LicenseNumber,
  LicenseTypeCode,
  IsMaster,
  FeeActivity,
  api.pkg_ColumnQuery.DateValue(pt.ObjectId,
  'PaymentStatus'),
  Amount) */
  LOOP
    BEGIN
      -- Sheik 12/24 To include the dmv surcharge into staging table
      t_badmastercount_flag := 0;
      t_otherDMVcount_flag  := 0;
      t_bpu2421count_flag   := 0;
      t_bpu2466count_flag   := 0;
      t_bpu52count_flag     := 0;
      t_offcount_flag       := 0;
      t_oncount_flag        := 0;
      -- Sheik 1/2/2019 Adding AB Surcharge flag
      t_ABSurcharge_flag := 0;
      IF a_debug          = 'Y' THEN
        dbms_output.put_line('Processing row ' || v_row);
      END IF;
      INSERT
      INTO abc.allocation_licensefee_det VALUES
        (
          v_row,
          c.amount,
          c.converted,
          c.description,
          c.expirationdate,
          c.feeactivity,
          c.feeid,
          c.gallonagerange,
          c.ismaster,
          c.jobid,
          c.licensenumber,
          c.licensetypecode,
          c.masterlt,
          c.numberofmonthslicensed,
          c.populationrange,
          c.ptdescription,
          c.secondarycount,
          c.transactionid,
          c.transaction_dt,
          c.posted_dt,
          c.created_dt,
          a_startdate,
          a_enddate,
          a_run_id
        ); --to_date(c.created_dt,'YYYY-MM-DD HH:MI:SS'));
      -- to_date('2016-07-01', 'YYYY-MM-DD') ,to_date('2017-06-30','YYYY-MM-DD'));
      COMMIT;
      IF a_debug = 'Y' THEN
        dbms_output.put_line( 'Porcessing record Allocation_LicenseFee_det: Tansaction id  ' || c.transactionid);
        dbms_output.put_line( 'License number ' || c.licensenumber || ' License Type ' || c.licensetypecode);
        dbms_output.put_line('Job Id ' || c.jobid);
      END IF;
      -- 11/1/2018 Sheik DMV Surcharge Increases from $5 to $10 effective C fee code
      -- IF c.created_dt >= TO_DATE('01/01/2019','mm/dd/yyyy') THEN
      IF instr(c.description,' C') >1 THEN
        t_dmvsurcharge            := 10;
      ELSE
        t_dmvsurcharge := 5;
      END IF;
      IF c.feeactivity NOT LIKE 'REN%' OR c.converted = 'Y' THEN
        IF c.ptdescription                            = 'OVR' THEN
          t_other                                    := t_other + c.amount;
          t_allocationcode                           := 'OTHER';
        ELSIF c.ptdescription LIKE '%SRV' THEN
          t_sec959srvsmg   := t_sec959srvsmg + c.amount;
          t_allocationcode := 'SEC959';
        ELSIF c.feeactivity = 'CHK' THEN
          t_dishonored     := t_dishonored + c.amount;
          t_allocationcode := 'BADCHK';
        ELSIF c.feeactivity             IN ('SFP', 'FFP') THEN
          t_fingerprint    := t_fingerprint + c.amount;
          t_allocationcode := 'FNGRPRNT';
        ELSIF c.feeactivity     IN ('ORI', 'ANN') AND c.licensetypecode IN ('26', '28') THEN
          t_orioosc        := t_orioosc + c.amount;
          t_allocationcode := 'OOSC-ORI';
        ELSIF c.feeactivity = 'ORI' AND c.licensetypecode NOT IN ('26', '28') THEN
          t_sec954ori      := t_sec954ori                      + c.amount;
          t_allocationcode := 'SEC954';
        ELSIF c.feeactivity = 'UTR' THEN
          t_unclaim        := t_unclaim + c.amount;
          t_allocationcode := 'UNCLAM';
        ELSIF c.feeactivity IN ('POIC') THEN
          t_poic           := t_poic   + c.amount;
          t_allocationcode := 'POIC';
        ELSIF c.feeactivity = 'EXC' THEN
          t_exchange       := t_exchange + c.amount;
          t_allocationcode := 'EXCH';
        ELSIF c.feeactivity               IN ('PER', 'ICO', 'FID', 'STK', 'STM', 'PRM', 'CD8', 'DPR', 'MBR', 'MBM') THEN
          t_sec070tranfr   := t_sec070tranfr + c.amount;
          t_allocationcode := 'SEC070';
        ELSIF c.feeactivity = 'BPU' THEN
          t_sec053bpu      := t_sec053bpu + c.amount;
          t_allocationcode := 'SEC053';
        ELSIF c.feeactivity = 'CATA' THEN
          t_caterrauth583  := t_caterrauth583 + c.amount;
          t_allocationcode := 'CAUTH583';
        ELSIF c.feeactivity = 'EPA' THEN
          t_epaauth583     := t_epaauth583 + c.amount;
          t_allocationcode := 'CAUTH583';
        ELSIF c.feeactivity             IN ('CAT', 'CATC') THEN
          IF c.masterlt                 IN ('50', '51', '52') THEN
            t_clubcat          := t_clubcat    + c.amount;
            t_clubcatsur       := t_clubcatsur + (c.amount * t_absurchargepct);
            t_ABSurcharge_flag := 1; -- 1/2/2019 Sheik Added to track AB Surcharge
            t_allocationcode   := 'CLUBCAT';
          ELSE
            t_caterrpermit   := t_caterrpermit + c.amount;
            t_allocationcode := 'CATPERM';
          END IF;
        ELSIF c.feeactivity           IN ('MGR') THEN
          t_manageq321     := t_manageq321 + c.amount;
          t_allocationcode := 'MANQ321';
        ELSIF c.feeactivity = 'PEN' THEN
          t_penalty        := t_penalty + c.amount;
          t_allocationcode := 'PENALTY';
        ELSIF c.feeactivity       IN ('PRW') THEN
          t_privware       := t_privware + c.amount;
          t_allocationcode := 'PRIVWARE';
        ELSIF c.feeactivity     IN ('RPL') THEN
          t_replace        := t_replace + c.amount;
          t_allocationcode := 'REPLACE';
        ELSIF c.feeactivity         IN ('ODL', 'SPD', 'TPT', 'IPT', 'TST', 'SDV') THEN
          t_tempdaily                                   := t_tempdaily + c.amount;
          t_allocationcode                              := 'TMPDAILY';
        ELSIF c.feeactivity        IN ('AWF') OR (c.feeactivity = 'DOR' AND c.licensetypecode NOT IN ('06', '58', '66', '77')) THEN
          IF c.licensetypecode NOT IN ('26', '28', '29', '67') THEN
            t_b11a2            := t_b11a2      + c.amount;
            t_b11a2sur         := t_b11a2sur   + (c.amount * t_absurchargepct);
            t_ABSurcharge_flag := 1; -- 1/2/2019 Sheik Added to track AB Surcharge
            t_allocationcode   := 'b11a2';
          ELSE
            t_annualfees     := t_annualfees + c.amount;
            t_allocationcode := 'ANNFEES';
          END IF;
        ELSIF c.feeactivity = 'BKT' THEN
          t_sec659tag      := t_sec659tag + c.amount;
          t_allocationcode := 'BKT';
        ELSIF c.feeactivity = 'BKR' THEN
          t_sec659rec      := t_sec659rec + c.amount;
          t_allocationcode := 'BKR';
        ELSIF c.feeactivity     IN ('MOD') THEN
          t_cond803                                                             := t_cond803 + c.amount;
          t_allocationcode                                                      := 'COND803';
        ELSIF c.feeactivity IN ('ANN', 'REN') OR (c.feeactivity                  = 'DOR' AND c.licensetypecode IN ('06', '58', '66', '77')) THEN
          IF c.licensenumber || c.licensetypecode || c.feeactivity || c.ismaster = t_lastrecord AND ((c.amount < 0 AND t_lastamount < 0) OR (c.amount >= 0 AND t_lastamount >= 0)) THEN
            t_relatedrecord                                                     := 'Y';
          ELSE
            t_relatedrecord := 'N';
          END IF;
          -- sheik's debugging comment
          IF a_debug = 'Y' THEN
            dbms_output.put_line('still inside loop ');
          END IF;
          IF c.licensetypecode                          IN ('01', '02', '03', '23', '62') THEN
            IF ((c.ismaster              = 'Y' AND c.licensetypecode IN ('01', '03', '23')) OR (c.gallonagerange IS NOT NULL AND c.licensetypecode = '02') OR (c.licensetypecode = '62')) THEN
              IF t_relatedrecord         = 'N' THEN
                IF c.amount              < 0 THEN
                  t_badmastercount      := t_badmastercount + 1;
                  t_dmvfund             := t_dmvfund        - t_dmvsurcharge;
                  t_badmastercount_flag := 1; -- Sheik 12/24/18 To include the dmv surcharge into staging table
                ELSIF c.amount           > 0 THEN
                  t_badmastercount      := t_badmastercount - 1;
                  t_badmastercount_flag :=                  -1; -- Sheik 12/24/18 To include the dmv surcharge into staging table
                  -- TODO: By Sheik..check with BA that when amount is <0 then the dmvfund gets calculated, and when the amount is >0 then again it needs to be
                  -- recalculated as shown below
                  -- t_dmvfund        := t_dmvfund        + t_dmvsurcharge;
                END IF;
              END IF;
            END IF;
          ELSIF c.licensetypecode IN ('04', '05', '07', '13', '18', '27','74') THEN -- 11/30/2018 Sheik Adding missing LT 74
            IF t_relatedrecord     = 'N' THEN
              IF c.amount          < 0 THEN
                t_bpu52count      := t_bpu52count + 1;
                t_dmvfund         := t_dmvfund    - t_dmvsurcharge;
                t_bpu52count_flag := 1; -- Sheik 12/24/18 To include the dmv surcharge into staging table
                -- t_bpuamount   := t_bpuamount  + t_bpu52surcharge; Sheik  commenting this line
                t_bpuamount       := t_bpuamount - t_bpu52surcharge; -- Sheik  8/23/18 Store negative value bucket instead of positive number as per Randy
              ELSIF c.amount       > 0 THEN
                t_bpu52count      := t_bpu52count - 1;
                t_bpu52count_flag :=              -1; -- Sheik 12/24/18 To include the dmv surcharge into staging table
              END IF;
            END IF;
          ELSIF c.licensetypecode    = '21' THEN
            IF t_relatedrecord       = 'N' THEN
              IF c.amount            < 0 THEN
                t_bpu2421count      := t_bpu2421count + 1;
                t_dmvfund           := t_dmvfund      - t_dmvsurcharge;
                t_bpu2421count_flag := 1; -- Sheik 12/24/18 To include the dmv surcharge flag into staging table
                -- t_bpuamount      := t_bpuamount    + t_bpu24surcharge; Sheik  commenting this line
                t_bpuamount         := t_bpuamount - t_bpu24surcharge; -- Sheik  8/23/18 Store negative value bucket instead of positive number as per Randy
              ELSIF c.amount         > 0 THEN
                t_bpu2421count      := t_bpu2421count - 1;
                t_bpu2421count_flag :=                -1; -- Sheik 12/24/18 To include the dmv surcharge flag into staging table
              END IF;
            END IF;
          ELSIF c.licensetypecode    = '66' THEN
            IF t_relatedrecord       = 'N' THEN
              IF c.amount            < 0 THEN
                t_bpu2466count      := t_bpu2466count + 1;
                t_dmvfund           := t_dmvfund      - t_dmvsurcharge; -- Sheik 12/24/18 Adding this line
                t_bpu2466count_flag := 1;                               -- Sheik 12/24/18 To include the dmv surcharge flag into staging table
                -- t_bpuamount      := t_bpuamount    + t_bpu24surcharge;  Sheik  commenting this line
                t_bpuamount         := t_bpuamount - t_bpu24surcharge; -- Sheik  8/23/18 Store negative value bucket instead of positive number as per Randy
              ELSIF c.amount         > 0 THEN
                t_bpu2466count      := t_bpu2466count - 1;
                t_bpu2466count_flag :=                -1; -- Sheik 12/24/18 To include the dmv surcharge flag into staging table
              END IF;
            END IF;
            -- 12/6/18  Sheik adding below missing LT's 09, 11, 12, 74, 85, 87
          ELSIF c.licensetypecode IN ('06', '08', '10', '14', '15', '16', '17', '19', '20', '22', '24', '25', '09', '11', '12', '74', '85', '87') THEN
            IF t_relatedrecord   = 'N' THEN
              IF c.amount        < 0 THEN
                t_offcount      := t_offcount + 1;
                t_dmvfund       := t_dmvfund  - t_dmvsurcharge;
                t_offcount_flag := 1; -- Sheik 12/24/18 To include the dmv surcharge flag into staging table
                -- TODO: By Sheik..check with BA...why below line is missing for on, off and sea counts?
                -- t_bpuamount      := t_bpuamount    - t_bpu24surcharge; -- by sheik
              ELSIF c.amount     > 0 THEN
                t_offcount      := t_offcount - 1;
                t_offcount_flag :=            -1; -- Sheik 12/24/18 To include the dmv surcharge flag into staging table
              END IF;
            END IF;
            -- 11/30 Sheik adding below missing LT's 58 ,66 ,68 ,71 ,72 ,75 ,76 ,78 ,83
          ELSIF c.licensetypecode IN ('40', '41', '42', '43', '44', '45', '46', '47', '48', '50', '51', '52', '53', '54', '55', '56', '57', '61', '63', '64', '65', '69', '70', '58' ,'66' ,'68' ,'71' ,'72' ,'75' ,'76' ,'78' ,'83') THEN
            IF t_relatedrecord  = 'N' THEN
              IF c.amount       < 0 THEN
                t_oncount      := t_oncount + 1;
                t_dmvfund      := t_dmvfund - t_dmvsurcharge;
                t_oncount_flag := 1; -- Sheik 12/24/18 To include the dmv surcharge flag into staging table
              ELSIF c.amount    > 0 THEN
                t_oncount      := t_oncount - 1;
                t_oncount_flag :=           -1; -- Sheik 12/24/18 To include the dmv surcharge flag into staging table
              END IF;
            END IF;
          ELSIF c.licensetypecode IN ('49', '59', '60') THEN
            IF t_relatedrecord   = 'N' THEN
              IF c.amount        < 0 THEN
                t_seacount      := t_seacount + 1;
                t_dmvfund       := t_dmvfund  - t_dmvsurcharge;
                t_seacount_flag := 1; -- Sheik 12/24/18 To include the dmv surcharge flag into staging table
              ELSIF c.amount     > 0 THEN
                t_seacount      := t_seacount - 1;
                t_seacount_flag :=            -1; -- Sheik 12/24/18 To include the dmv surcharge flag into staging table
              END IF;
            END IF;
            -- 12/18/18 Sheik adding below lines to count all other license types
          ELSE
            IF t_relatedrecord        = 'N' THEN
              IF c.amount             < 0 THEN
                t_otherDMVcount      := t_otherDMVcount + 1;
                t_dmvfund            := t_dmvfund       - t_dmvsurcharge;
                t_otherDMVcount_flag := 1; -- Sheik 12/24/18 To include the dmv surcharge flag into staging table
              ELSIF c.amount          > 0 THEN
                t_otherDMVcount      := t_otherDMVcount - 1;
                t_otherDMVcount_flag :=                 -1; -- Sheik 12/24/18 To include the dmv surcharge flag into staging table
              END IF;
            END IF;
          END IF;
          IF c.licensetypecode          IN ('26', '28', '29', '67') THEN
            t_annualfees     := t_annualfees + c.amount;
            t_allocationcode := 'ANNFEES2';
          ELSIF c.licensetypecode IN ('58') THEN
            IF c.masterlt         IN ('50', '51', '52') THEN
              --
              -- only calc if the record is pre 2001 when the code was only 'ANN' and 'REN'
              --
              IF c.description              IN ('ANN', 'REN') THEN
                t_oldclubcat := t_oldclubcat + c.amount;
                --                  t_Sec202 := t_Sec202 + (c.Amount * t_FeeSurchargePct);
                --                  t_Sec203 := t_Sec203 + (c.Amount * t_OAHSurchargePct);
                t_oldclubcatsur    := t_oldclubcatsur + (c.amount * t_absurchargepct);
                t_ABSurcharge_flag := 1; -- 1/2/2019 Sheik Added to track AB Surcharge
                t_allocationcode   := 'CLUBCAT';
              ELSE
                t_clubcat          := t_clubcat    + c.amount;
                t_clubcatsur       := t_clubcatsur + (c.amount * t_absurchargepct);
                t_ABSurcharge_flag := 1; -- 1/2/2019 Sheik Added to track AB Surcharge
                t_allocationcode   := 'CLUBCAT';
              END IF;
            ELSE
              t_caterrpermit   := t_caterrpermit + c.amount;
              t_allocationcode := 'CATPERM';
            END IF;
          ELSIF c.licensetypecode     IN ('77') THEN
            t_epapermit      := t_epapermit + c.amount;
            t_allocationcode := 'CATPERM';
          ELSE
            --
            -- only calc if the record is pre 2001 when the code was only 'ANN' and 'REN'
            --
            IF c.description          IN ('ANN', 'REN') THEN
              t_oldb11a1 := t_oldb11a1 + c.amount;
              --               t_Sec202 := t_Sec202 + (c.Amount * t_FeeSurchargePct);
              --               t_Sec203 := t_Sec203 + (c.Amount * t_OAHSurchargePct);
              t_oldb11a1sur      := t_oldb11a1sur + (c.amount * t_absurchargepct);
              t_ABSurcharge_flag := 1; -- 1/2/2019 Sheik Added to track AB Surcharge
              t_allocationcode   := 'b11a1RAS';
            ELSE
              t_b11a1            := t_b11a1    + c.amount;
              t_b11a1sur         := t_b11a1sur + (c.amount * t_absurchargepct);
              t_ABSurcharge_flag := 1; -- 1/2/2019 Sheik Added to track AB Surcharge
              t_allocationcode   := 'b11a1RAS';
            END IF;
          END IF;
          /*elsif c.FeeActivity = 'WSF' then
          t_WineSafety := t_WineSafety + c.Amount;
          t_AllocationCode := 'WINESFTY';*/
        ELSE
          t_other          := t_other + c.amount;
          t_allocationcode := 'OTHER';
        END IF;
        INSERT
        INTO abc.allocationreportdetail
          (
            allocationcode,
            transcode,
            ltcode,
            amount,
            created_dt,
            jobid,
            licensenumber,
            transactionid,
            rpt_start_dt,
            rpt_end_dt,
            run_id,
            badmastercount_flag,
            otherDMVcount_flag,
            bpu2421count_flag,
            bpu2466count_flag,
            bpu52count_flag,
            offcount_flag,
            oncount_flag,
            ABSurcharge_flag
          )
          VALUES
          (
            t_allocationcode,
            CASE
              WHEN c.ptdescription LIKE '%SRV'
              OR c.ptdescription = 'OVR'
              THEN c.ptdescription
              WHEN c.feeactivity = 'ODL'
              THEN SUBSTR(c.description, 1, 3)
              ELSE NVL(c.description, 'NA')
            END,
            CASE
              WHEN c.feeactivity IN ('FFP', 'SFP')
              THEN 'NA'
              ELSE NVL( c.licensetypecode, NVL( api.pkg_columnquery.VALUE( c.jobid, 'ApplicableLicenseType'), 'NA'))
            END,
            c.amount,
            c.created_dt, --to_date(c.created_dt,'YYYY-MM-DD HH:MI:SS') ,
            c.jobid,
            c.licensenumber,
            c.transactionid,
            a_startdate,
            a_enddate,
            a_run_id,
            t_badmastercount_flag,
            t_otherDMVcount_flag,
            t_bpu2421count_flag,
            t_bpu2466count_flag,
            t_bpu52count_flag,
            t_offcount_flag,
            t_oncount_flag,
            t_ABSurcharge_flag
          );
        COMMIT;
      ELSIF c.feeactivity LIKE 'REN%' AND c.converted = 'N' THEN
        t_feeactivity                                := c.feeactivity;
        t_feeamount                                  := 0;
        t_prevpaid                                   := 0;
        t_unpaidren                                  := 0;
        t_renamount                                  := 0;
        t_penamount                                  := 0;
        IF c.ptdescription                            = 'OVR' THEN
          t_other                                    := t_other + c.amount;
          t_allocationcode                           := 'OTHER';
          INSERT
          INTO abc.allocationreportdetail
            (
              allocationcode,
              transcode,
              ltcode,
              amount,
              created_dt,
              jobid,
              licensenumber,
              transactionid,
              rpt_start_dt,
              rpt_end_dt,
              run_id,
              badmastercount_flag,
              otherDMVcount_flag,
              bpu2421count_flag,
              bpu2466count_flag,
              bpu52count_flag,
              offcount_flag,
              oncount_flag,
              ABSurcharge_flag
            )
            VALUES
            (
              t_allocationcode,
              c.ptdescription,
              CASE
                WHEN c.feeactivity IN ('FFP', 'SFP')
                THEN 'NA'
                ELSE NVL( c.licensetypecode, NVL( api.pkg_columnquery.VALUE( c.jobid, 'ApplicableLicenseType'), 'NA'))
              END,
              c.amount,
              c.created_dt, --to_date(c.created_dt,'YYYY-MM-DD HH:MI:SS') ,
              c.jobid,
              c.licensenumber,
              c.transactionid,
              a_startdate,
              a_enddate,
              a_run_id,
              t_badmastercount_flag,
              t_otherDMVcount_flag,
              t_bpu2421count_flag,
              t_bpu2466count_flag,
              t_bpu52count_flag,
              t_offcount_flag,
              t_oncount_flag,
              t_ABSurcharge_flag
            );
          COMMIT;
        ELSE
          t_expirationdate := c.expirationdate;
          -- if the Expiration Date from the Fee (RENExpirationDate) is null
          IF t_expirationdate IS NULL THEN
            -- if the fee is on a License Type Job, get the expirationdate from the job
            IF api.pkg_columnquery.VALUE(c.jobid, 'ObjectDefName') = 'j_LicenseType' THEN
              BEGIN
                SELECT DECODE( SUBSTR(c.description, -1), '9', TO_DATE( -- Final Date
                  TO_CHAR(                                              -- Day of month
                  LAST_DAY( '01-'
                  || TO_CHAR( LAST_DAY( api.pkg_columnquery.datevalue( c.jobid, 'ExpirationDate')), 'MON')
                  || '-2009'), 'DD') -- End Day of month
                  || '-'
                  || TO_CHAR( api.pkg_columnquery.datevalue( c.jobid, 'ExpirationDate'), 'MON') -- Month
                  || '-2009'                                                                    -- Year
                  ),                                                                            -- End Final Date
                  'A', TO_DATE(                                                                 -- Final Date
                  TO_CHAR(                                                                      -- Day of month
                  LAST_DAY( '01-'
                  || TO_CHAR( LAST_DAY( api.pkg_columnquery.datevalue( c.jobid, 'ExpirationDate')), 'MON')
                  || '-2010'), 'DD') -- End Day of month
                  || '-'
                  || TO_CHAR( api.pkg_columnquery.datevalue( c.jobid, 'ExpirationDate'), 'MON') -- Month
                  || '-2010'                                                                    -- Year
                  ),                                                                            -- End Final Date
                  LAST_DAY(SYSDATE))
                INTO t_expirationdate
                FROM DUAL;
              EXCEPTION
              WHEN OTHERS THEN
                t_expirationdate := LAST_DAY(SYSDATE);
              END;
              -- if the fee is on a License, get the ExpirationDate from the related LT where the LTCode = the Fee LT Code
            ELSIF api.pkg_columnquery.VALUE(c.jobid, 'ObjectDefName') = 'j_License' THEN
              BEGIN
                SELECT NVL( MAX( DECODE( SUBSTR(c.description, -1), '9', TO_DATE( -- Final Date
                  TO_CHAR(                                                        -- Day of month
                  LAST_DAY( '01-'
                  || TO_CHAR( LAST_DAY( api.pkg_columnquery.datevalue( llt.licensetypejobid, 'ExpirationDate')), 'MON')
                  || '-2009'), 'DD') -- End Day of month
                  || '-'
                  || TO_CHAR( api.pkg_columnquery.datevalue( llt.licensetypejobid, 'ExpirationDate'), 'MON') -- Month
                  || '-2009'                                                                                 -- Year
                  ),                                                                                         -- End Final Date
                  'A', TO_DATE(                                                                              -- Final Date
                  TO_CHAR(                                                                                   -- Day of month
                  LAST_DAY( '01-'
                  || TO_CHAR( LAST_DAY( api.pkg_columnquery.datevalue( llt.licensetypejobid, 'ExpirationDate')), 'MON')
                  || '-2010'), 'DD') -- End Day of month
                  || '-'
                  || TO_CHAR( api.pkg_columnquery.datevalue( llt.licensetypejobid, 'ExpirationDate'), 'MON') -- Month
                  || '-2010'                                                                                 -- Year
                  ))),                                                                                       -- End Final Date
                  LAST_DAY(SYSDATE))
                INTO t_expirationdate
                FROM query.j_license l
                JOIN query.r_licenselicensetype llt
                ON llt.licensejobid = l.jobid
                JOIN api.jobstatuses js
                ON js.jobtypeid                                                           = l.jobtypeid
                WHERE api.pkg_columnquery.VALUE( llt.licensetypejobid, 'LicenseTypeCode') = c.licensetypecode
                AND js.statustype NOT                                                    IN ('C', 'X');
              EXCEPTION
              WHEN OTHERS THEN
                t_expirationdate := LAST_DAY(SYSDATE);
              END;
            ELSE
              t_expirationdate := LAST_DAY(SYSDATE);
            END IF;
          END IF;
          sitespecific.pkg_fees.getltfeeamount( NULL, t_expirationdate, 'REN', NULL, c.licensetypecode, c.gallonagerange, NULL, c.numberofmonthslicensed, c.populationrange,
          CASE
          WHEN c.masterlt IS NOT NULL THEN
            'S'
          ELSE
            'P'
          END, c.secondarycount, NULL, t_feeamount, t_scheduleid);
          -- Round Fee Amount
          t_feeamount      := ROUND(t_feeamount);
          t_expirationdate := NULL;
          BEGIN
            SELECT SUM(ft.amount)
            INTO t_paidamount
            FROM api.feetransactions ft
            WHERE ft.feeid         = c.feeid
            AND ft.transactiontype = 'Pay'
            AND ft.transactionid  <= c.transactionid;
          EXCEPTION
          WHEN OTHERS THEN
            t_paidamount := 0;
          END;
          IF t_feeactivity = 'REN' THEN
            t_renamount   := c.amount;
          ELSIF t_feeactivity         IN ('REN50', 'REN100') THEN
            t_prevpaid  := t_paidamount + ABS(c.amount);
            t_unpaidren := t_feeamount  + t_prevpaid;
            -- Set the case for t_UnPaidREN
            IF c.amount    > 0 THEN
              t_unpaidren := -t_unpaidren;
            END IF;
            -- If the previous payments did not cover the whole original REN Fee
            IF (t_unpaidren    > 0 AND c.amount < 0) OR (t_unpaidren < 0 AND c.amount > 0) THEN
              IF ABS(c.amount) < ABS(t_unpaidren) THEN
                t_renamount   := c.amount;
              ELSE
                t_renamount :=             -t_unpaidren;
                t_penamount := t_unpaidren + c.amount;
              END IF;
            ELSE
              t_penamount := c.amount;
            END IF;
          END IF;
          IF t_renamount                                                          <> 0 THEN
            IF c.licensenumber || c.licensetypecode || c.feeactivity || c.ismaster = t_lastrecord AND ((c.amount < 0 AND t_lastamount < 0) OR (c.amount >= 0 AND t_lastamount >= 0)) THEN
              t_relatedrecord                                                     := 'Y';
            ELSE
              t_relatedrecord := 'N';
            END IF;
            IF c.licensetypecode                          IN ('01', '02', '03', '23', '62') THEN
              IF ((c.ismaster              = 'Y' AND c.licensetypecode IN ('01', '03', '23')) OR (c.gallonagerange IS NOT NULL AND c.licensetypecode = '02') OR (c.licensetypecode = '62')) THEN
                IF t_relatedrecord         = 'N' THEN
                  IF c.amount              < 0 THEN
                    t_badmastercount      := t_badmastercount + 1;
                    t_dmvfund             := t_dmvfund        - t_dmvsurcharge;
                    t_badmastercount_flag := 1; -- Sheik 12/24/18 To include the dmv surcharge into staging table
                  ELSIF c.amount           > 0 THEN
                    t_badmastercount      := t_badmastercount - 1;
                    t_badmastercount_flag :=                  -1; -- Sheik 12/24/18 To include the dmv surcharge into staging table
                    -- TODO: By Sheik..check with BA that when amount is <0 then the dmvfund gets calculated, and when the amount is >0 then again it needs to be
                    -- recalculated as shown below
                    -- t_dmvfund        := t_dmvfund        + t_dmvsurcharge;
                  END IF;
                END IF;
              END IF;
            ELSIF c.licensetypecode IN ('04', '05', '07', '13', '18', '27','74') THEN
              --11/29/18 Sheik adding 74
              IF t_relatedrecord     = 'N' THEN
                IF c.amount          < 0 THEN
                  t_bpu52count      := t_bpu52count + 1;
                  t_dmvfund         := t_dmvfund    - t_dmvsurcharge;
                  t_bpu52count_flag := 1; -- Sheik 12/24/18 To include the dmv surcharge into staging table
                  -- t_bpuamount   := t_bpuamount  + t_bpu52surcharge; Sheik  commenting this line
                  t_bpuamount       := t_bpuamount - t_bpu52surcharge; -- Sheik  8/23/18 Store negative value bucket instead of positive number as per Randy
                ELSIF c.amount       > 0 THEN
                  t_bpu52count      := t_bpu52count - 1;
                  t_bpu52count_flag :=              -1; -- Sheik 12/24/18 To include the dmv surcharge into staging table
                END IF;
              END IF;
            ELSIF c.licensetypecode    = '21' THEN
              IF t_relatedrecord       = 'N' THEN
                IF c.amount            < 0 THEN
                  t_bpu2421count      := t_bpu2421count + 1;
                  t_dmvfund           := t_dmvfund      - t_dmvsurcharge;
                  t_bpu2421count_flag := 1; -- Sheik 12/24/18 To include the dmv surcharge flag into staging table
                  -- t_bpuamount      := t_bpuamount    + t_bpu24surcharge; Sheik  commenting this line
                  t_bpuamount         := t_bpuamount - t_bpu24surcharge; -- Sheik  8/23/18 Store negative value bucket instead of positive number as per Randy
                ELSIF c.amount         > 0 THEN
                  t_bpu2421count      := t_bpu2421count - 1;
                  t_bpu2421count_flag :=                -1; -- Sheik 12/24/18 To include the dmv surcharge flag into staging table
                END IF;
              END IF;
            ELSIF c.licensetypecode    = '66' THEN
              IF t_relatedrecord       = 'N' THEN
                IF c.amount            < 0 THEN
                  t_bpu2466count      := t_bpu2466count + 1;
                  t_bpu2466count_flag := 1; -- Sheik 12/24/18 To include the dmv surcharge flag into staging table
                  -- t_bpuamount      := t_bpuamount    + t_bpu24surcharge;
                  t_bpuamount         := t_bpuamount - t_bpu24surcharge; -- Sheik  8/23/18 Store negative value bucket instead of positive number as per Randy
                ELSIF c.amount         > 0 THEN
                  t_bpu2466count      := t_bpu2466count - 1;
                  t_bpu2466count_flag :=                -1; -- Sheik 12/24/18 To include the dmv surcharge flag into staging table
                END IF;
              END IF;
            ELSIF c.licensetypecode IN ('06', '08', '10', '14', '15', '16', '17', '19', '20', '22', '24', '25','09','11','12','74','85','87') THEN
              --11/29/18 Sheik adding 09, 11, 12, 74, 85, 87
              IF t_relatedrecord   = 'N' THEN
                IF c.amount        < 0 THEN
                  t_offcount      := t_offcount + 1;
                  t_dmvfund       := t_dmvfund  - t_dmvsurcharge;
                  t_offcount_flag := 1; -- Sheik 12/24/18 To include the dmv surcharge flag into staging table
                ELSIF c.amount     > 0 THEN
                  t_offcount      := t_offcount - 1;
                  t_offcount_flag :=            -1; -- Sheik 12/24/18 To include the dmv surcharge flag into staging table
                END IF;
              END IF;
            ELSIF c.licensetypecode IN ('40', '41', '42', '43', '44', '45', '46', '47', '48', '50', '51', '52', '53', '54', '55', '56', '57', '61', '63', '64', '65', '69', '70','58','66','68','71','72','75','76','78','83') THEN
              -- 11/29/18 Sheik adding  58 ,66 ,68 ,71 ,72 ,75 ,76 ,78 ,83
              IF t_relatedrecord  = 'N' THEN
                IF c.amount       < 0 THEN
                  t_oncount      := t_oncount + 1;
                  t_dmvfund      := t_dmvfund - t_dmvsurcharge;
                  t_oncount_flag := 1; -- Sheik 12/24/18 To include the dmv surcharge flag into staging table
                ELSIF c.amount    > 0 THEN
                  t_oncount      := t_oncount - 1;
                  t_oncount_flag :=           -1; -- Sheik 12/24/18 To include the dmv surcharge flag into staging table
                END IF;
              END IF;
            ELSIF c.licensetypecode IN ('49', '59', '60') THEN
              IF t_relatedrecord   = 'N' THEN
                IF c.amount        < 0 THEN
                  t_seacount      := t_seacount + 1;
                  t_dmvfund       := t_dmvfund  - t_dmvsurcharge;
                  t_seacount_flag := 1; -- Sheik 12/24/18 To include the dmv surcharge flag into staging table
                ELSIF c.amount     > 0 THEN
                  t_seacount      := t_seacount - 1;
                  t_seacount_flag :=            -1; -- Sheik 12/24/18 To include the dmv surcharge flag into staging table
                END IF;
              END IF;
              -- 12/18/18 Sheik adding below lines to count all other license types
            ELSE
              IF t_relatedrecord        = 'N' THEN
                IF c.amount             < 0 THEN
                  t_otherDMVcount      := t_otherDMVcount + 1;
                  t_dmvfund            := t_dmvfund       - t_dmvsurcharge;
                  t_otherDMVcount_flag := 1; -- Sheik 12/24/18 To include the dmv surcharge flag into staging table
                ELSIF c.amount          > 0 THEN
                  t_otherDMVcount      := t_otherDMVcount - 1;
                  t_otherDMVcount_flag :=                 -1; -- Sheik 12/24/18 To include the dmv surcharge flag into staging table
                END IF;
              END IF;
            END IF;
            IF c.licensetypecode          IN ('26', '28', '29', '67') THEN
              t_annualfees     := t_annualfees + t_renamount;
              t_allocationcode := 'ANNFEES2';
            ELSIF c.licensetypecode IN ('58') THEN
              IF c.masterlt         IN ('50', '51', '52') THEN
                --
                -- only calc if the record is pre 2001 when the code was only 'ANN' and 'REN'
                --
                IF c.description = 'REN' THEN
                  t_oldclubcat  := t_oldclubcat + t_renamount;
                  --                   t_Sec202 := t_Sec202 + (t_RENAmount * t_FeeSurchargePct);
                  --                   t_Sec203 := t_Sec203 + (t_RENAmount * t_OAHSurchargePct);
                  t_oldclubcatsur    := t_oldclubcatsur + (t_renamount * t_absurchargepct);
                  t_ABSurcharge_flag := 1; -- 1/2/2019 Sheik Added to track AB Surcharge
                  t_allocationcode   := 'CLUBCAT';
                ELSE
                  t_clubcat          := t_clubcat    + t_renamount;
                  t_clubcatsur       := t_clubcatsur + (t_renamount * t_absurchargepct);
                  t_ABSurcharge_flag := 1; -- 1/2/2019 Sheik Added to track AB Surcharge
                  t_allocationcode   := 'CLUBCAT';
                END IF;
              ELSE
                t_caterrpermit   := t_caterrpermit + t_renamount;
                t_allocationcode := 'CATPERM';
              END IF;
            ELSIF c.licensetypecode     IN ('77') THEN
              t_epapermit      := t_epapermit + t_renamount;
              t_allocationcode := 'CATPERM';
            ELSE
              --
              -- only calc if the record is pre 2001 when the code was only 'ANN' and 'REN'
              --
              IF c.description = 'REN' THEN
                t_oldb11a1    := t_oldb11a1 + t_renamount;
                --                t_Sec202 := t_Sec202 + (t_RENAmount * t_FeeSurchargePct);
                --                t_Sec203 := t_Sec203 + (t_RENAmount * t_OAHSurchargePct);
                t_oldb11a1sur      := t_oldb11a1sur + (t_renamount * t_absurchargepct);
                t_ABSurcharge_flag := 1; -- 1/2/2019 Sheik Added to track AB Surcharge
                t_allocationcode   := 'b11a1RAS';
              ELSE
                t_b11a1            := t_b11a1    + t_renamount;
                t_b11a1sur         := t_b11a1sur + (t_renamount * t_absurchargepct);
                t_ABSurcharge_flag := 1; -- 1/2/2019 Sheik Added to track AB Surcharge
                t_allocationcode   := 'b11a1RAS';
              END IF;
            END IF;
            INSERT
            INTO abc.allocationreportdetail
              (
                allocationcode,
                transcode,
                ltcode,
                amount,
                created_dt,
                jobid,
                licensenumber,
                transactionid,
                rpt_start_dt,
                rpt_end_dt,
                run_id,
                badmastercount_flag,
                otherDMVcount_flag,
                bpu2421count_flag,
                bpu2466count_flag,
                bpu52count_flag,
                offcount_flag,
                oncount_flag,
                ABSurcharge_flag
              )
              VALUES
              (
                t_allocationcode,
                CASE
                  WHEN c.description LIKE '%0'
                  THEN NVL( REPLACE( c.description, SUBSTR( c.description, 1, INSTR( c.description, '0', -1)), 'REN '), 'NA')
                  ELSE NVL( REPLACE( c.description, SUBSTR( c.description, 1, INSTR( c.description, ' ')), 'REN '), 'NA')
                END,
                CASE
                  WHEN c.feeactivity IN ('FFP', 'SFP')
                  THEN 'NA'
                  ELSE NVL( c.licensetypecode, NVL( api.pkg_columnquery.VALUE( c.jobid, 'ApplicableLicenseType'), 'NA'))
                END,
                t_renamount,
                c.created_dt, --to_date(c.created_dt,'YYYY-MM-DD HH:MI:SS'),
                c.jobid,
                c.licensenumber,
                c.transactionid,
                a_startdate,
                a_enddate,
                a_run_id,
                t_badmastercount_flag,
                t_otherDMVcount_flag,
                t_bpu2421count_flag,
                t_bpu2466count_flag,
                t_bpu52count_flag,
                t_offcount_flag,
                t_oncount_flag,
                t_ABSurcharge_flag
              );
            COMMIT;
          END IF;
        END IF;
        IF t_penamount     <> 0 THEN
          t_penalty        := t_penalty + t_penamount;
          t_allocationcode := 'PENALTY';
          INSERT
          INTO allocationreportdetail
            (
              allocationcode,
              transcode,
              ltcode,
              amount,
              created_dt,
              jobid,
              licensenumber,
              transactionid,
              rpt_start_dt,
              rpt_end_dt,
              run_id,
              badmastercount_flag,
              otherDMVcount_flag,
              bpu2421count_flag,
              bpu2466count_flag,
              bpu52count_flag,
              offcount_flag,
              oncount_flag ,
              ABSurcharge_flag
            )
            VALUES
            (
              t_allocationcode,
              CASE
                WHEN c.description LIKE '%0'
                THEN NVL( REPLACE( c.description, SUBSTR( c.description, 1, INSTR( c.description, '0', -1)), 'PEN '), 'NA')
                ELSE NVL( REPLACE( c.description, SUBSTR( c.description, 1, INSTR( c.description, ' ')), 'PEN '), 'NA')
              END,
              CASE
                WHEN c.feeactivity IN ('FFP', 'SFP')
                THEN 'NA'
                ELSE NVL( c.licensetypecode, NVL( api.pkg_columnquery.VALUE( c.jobid, 'ApplicableLicenseType'), 'NA'))
              END,
              t_penamount,
              c.created_dt, --to_date(c.created_dt,'YYYY-MM-DD HH:MI:SS'),
              c.jobid,
              c.licensenumber,
              c.transactionid,
              a_startdate,
              a_enddate,
              a_run_id,
              t_badmastercount_flag,
              t_otherDMVcount_flag,
              t_bpu2421count_flag,
              t_bpu2466count_flag,
              t_bpu52count_flag,
              t_offcount_flag,
              t_oncount_flag,
              t_ABSurcharge_flag
            );
          COMMIT;
        END IF;
      END IF;
      -- END IF;
      t_lastrecord := c.licensenumber || c.licensetypecode || c.feeactivity || c.ismaster;
      t_lastamount := c.amount;
      IF a_debug    = 'Y' THEN
        dbms_output.put_line('processed record ' || v_row);
      END IF;
      -- dbms_Output.put_Line('Porcessed Tansaction id  '||c.TRANSACTIONID);
      -- dbms_Output.put_Line('License number '|| c.LICENSENUMBER);
      -- dbms_Output.put_Line('Job Id '||c.JOBID);
      v_row := v_row + 1;
    EXCEPTION
    WHEN NO_DATA_FOUND THEN
      dbms_output.put_line('Error no_data_found ');
      dbms_output.put_line(SQLCODE || SQLERRM);
    WHEN TOO_MANY_ROWS THEN
      dbms_output.put_line('TOO_MANY_ROWS');
      dbms_output.put_line(SQLCODE || SQLERRM);
    WHEN VALUE_ERROR THEN
      dbms_output.put_line('VALUE_ERROR');
      dbms_output.put_line(SQLCODE || SQLERRM);
    END;
  END LOOP;
  dbms_output.put_line('Finished processing all rows ');
  t_b11a1 := t_b11a1 - t_dmvfund - t_bpuamount;
  --t_Sec053BPU := t_Sec053BPU + t_BPUAmount;
  -- 02/27/2014  MMR  Per Kristine Okino in Accounting, calculate the column as follows
  -- to balance the BPU sums and render a negative sum.
  -- 08/30/2018 Sheik As per Randy, uncommenting below line that was commented in 2014
  t_Sec053BPU := t_Sec053BPU + t_BPUAmount;
  -- 08/30/2018 Sheik As per Randy, commenting below line that was commented in 2014
  -- t_sec053bpu     := ( (t_bpu52count * 52) + (t_bpu2421count * 24) + (t_bpu2466count * 24)) * -1;
  t_appealboard   := (t_clubcatsur + t_oldclubcatsur) + (t_b11a1sur + t_oldb11a1sur) + t_b11a2sur;
  t_sec761096surg := (t_b11a1      + t_oldb11a1 + t_b11a2 + t_clubcat + t_oldclubcat) - (
  /*t_Sec202 + t_Sec203 + */
  t_appealboard);
  t_sec761096nonsurg := t_tempdaily + t_annualfees;
  INSERT
  INTO abc.allocationreport
    (
      poic,
      sec954ori,
      sec202,
      sec203,
      exchange,
      sec070tranfr,
      sec053bpu,
      sec357out,
      orioosc,
      sec959srvsmg,
      caterrauth583,
      caterrpermit,
      manageq321,
      penalty,
      privware,
      REPLACE,
      sec761096surg,
      sec761096nonsurg,
      sec659tag,
      sec659rec,
      cond803,
      other,
      unclaim,
      appealboard,
      badmastercount,
      bpu52count,
      bpu2421count,
      bpu2466count,
      offcount,
      oncount,
      seacount,
      dmvfund,
      winesafety,
      dishonored,
      fingerprint,
      epapermit,
      epaauth583,
      rpt_start_dt,
      rpt_end_dt,
      b11a1 ,
      bpuamount ,
      clubcatsur ,
      oldclubcatsur ,
      b11a1sur ,
      oldb11a1sur ,
      b11a2sur ,
      oldb11a1 ,
      b11a2 ,
      clubcat ,
      oldclubcat ,
      run_id
    )
    VALUES
    (
      bankersround(t_poic),
      bankersround(t_sec954ori),
      bankersround(t_sec202),
      bankersround(t_sec203),
      bankersround(t_exchange),
      bankersround(t_sec070tranfr),
      bankersround(t_sec053bpu),
      bankersround(t_sec357out),
      bankersround(t_orioosc),
      bankersround(t_sec959srvsmg),
      bankersround(t_caterrauth583),
      bankersround(t_caterrpermit),
      bankersround(t_manageq321),
      bankersround(t_penalty),
      bankersround(t_privware),
      bankersround(t_replace),
      bankersround(t_sec761096surg),
      bankersround(t_sec761096nonsurg),
      bankersround(t_sec659tag),
      bankersround(t_sec659rec),
      bankersround(t_cond803),
      bankersround(t_other),
      bankersround(t_unclaim),
      bankersround(t_appealboard),
      bankersround(t_badmastercount),
      bankersround(t_bpu52count),
      bankersround(t_bpu2421count),
      bankersround(t_bpu2466count),
      bankersround(t_offcount),
      bankersround(t_oncount),
      bankersround(t_seacount),
      bankersround(t_dmvfund),
      bankersround(t_winesafety),
      bankersround(t_dishonored),
      bankersround(t_fingerprint),
      bankersround(t_epapermit),
      bankersround(t_epaauth583),
      a_startdate,
      a_enddate,
      t_b11a1 ,
      t_bpuamount ,
      t_clubcatsur ,
      t_oldclubcatsur ,
      t_b11a1sur ,
      t_oldb11a1sur ,
      t_b11a2sur ,
      t_oldb11a1 ,
      t_b11a2 ,
      t_clubcat ,
      t_oldclubcat ,
      a_run_id
    );
  dbms_output.put_line('Inserted row to AllocationReport');
  COMMIT;
EXCEPTION
WHEN NO_DATA_FOUND THEN
  dbms_output.put_line('Error no_data_found ');
  dbms_output.put_line(SQLCODE || SQLERRM);
WHEN TOO_MANY_ROWS THEN
  dbms_output.put_line('TOO_MANY_ROWS');
  dbms_output.put_line(SQLCODE || SQLERRM);
WHEN VALUE_ERROR THEN
  dbms_output.put_line('VALUE_ERROR');
  dbms_output.put_line(SQLCODE || SQLERRM);
END allocationreport_ss;
/
