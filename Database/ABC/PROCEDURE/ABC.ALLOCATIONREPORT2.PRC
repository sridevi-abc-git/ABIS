CREATE OR REPLACE PROCEDURE ABC.AllocationReport2(
    a_StartDate DATE,
    a_EndDate   DATE,
    a_debug     CHAR,
    a_run_id    NUMBER )
AS
  /******************************************************************************
  NAME:       ABC Allocation Report 2.0
  PURPOSE:    Generates Allocation Report
  BUSINESS:   Accounting uses this report to send funds to calculate General Fund, ABC Fund, Appeals Board and DMV
  Sample to Run:
  DECLARE
  A_STARTDATE DATE;
  A_ENDDATE DATE;
  A_DEBUG CHAR(200);
  a_run_id number;
  BEGIN
  A_STARTDATE := '02-JAN-19';   --Format 'DD-MON-YY'
  A_ENDDATE := '02-JAN-19';   --Format 'DD-MON-YY'
  A_DEBUG := 'N';
  a_run_id := 1; -- Use different runid, if you want to run multiple times for the same date range
  ALLOCATIONREPORT2(
  A_STARTDATE => A_STARTDATE,
  A_ENDDATE => A_ENDDATE,
  A_DEBUG => A_DEBUG,
  a_run_id => a_run_id
  );
  END;
  REVISIONS:
  Ver        Date        Author          Description
  ---------  ----------  --------------  ------------------------------------
  1.1        6/20/2019   Sheik           Allocation Report 2.0
  2.0        7/26/2019   Sheik 			 Fixing DMV,AB for the adjustments and secondaries
  ******************************************************************************/
  v_start_dtTime      DATE;
  v_Finish_dtTime     DATE;
  v_poic              NUMBER(15,2) := 0;
  v_new_app           NUMBER(15,2) := 0;
  v_transferfee       NUMBER(15,2) := 0;
  v_BPU               NUMBER(15,2) := 0;
  v_penalties         NUMBER(15,2) := 0;
  v_renewals          NUMBER(15,2) := 0;
  v_abcfunds          NUMBER(15,2) := 0;
  v_other             NUMBER(15,2) := 0;
  v_eventCat_Auth     NUMBER(15,2) := 0;
  v_eventCat_Permits  NUMBER(15,2) := 0;
  v_ab_surcharges     NUMBER(15,2) := 0;
  v_dmv_surcharges    NUMBER(15,2) := 0;
  v_dishonored        NUMBER(15,2) := 0;
  v_fingerprint       NUMBER(15,2) := 0;
  v_GrandTotal        NUMBER(15,2) := 0;
  t_penaltyAMT        NUMBER(15,2) := 0;
  t_lastamount        NUMBER       := 0;
  t_lastrecord        VARCHAR2(100);
  t_relatedrecord     VARCHAR2(1);
  t_BPU_FEE           NUMBER := 0;
  t_dmv_surcharge_amt NUMBER := 0;
  t_AB_SURCHARGE_PCT  NUMBER := 0;
  t_AB_SURCHARGE_AMT  NUMBER := 0;
  t_rounding_5 		  DATE := '01-OCT-19';
BEGIN
  -- Start date and time
  SELECT sysdate INTO v_start_dtTime FROM dual;
  --to_char(sysdate,'mm/dd/yyyy HH:MMAM')  into v_start_dtTime
  dbms_output.put_line('Starting at .. '||TO_CHAR(v_start_dtTime,'MM/DD/YY HH12:MM'));
  DELETE FROM abc.ALLOCATION_INITIALFETCH;
  DELETE
  FROM abc.ALLOCATIONREPORT_2;
  COMMIT;
  FOR c IN
  (SELECT rownum record_num,
    amount EarnedAmount,
    -- 7/24/9 adding below new_orig and new_ab
    CASE
     --WHEN dup_CreatedDate >= '01-JUL-19' 
	  WHEN transactiondate >= t_rounding_5 
      --THEN ( amount - (ROUND(((amount - dmv_surcharge_amt)*(ab_surcharge_pct/100))/5)*5) - dmv_surcharge_amt)
	    THEN round ( (amount - bpu_fee - dmv_surcharge_amt) / (1+(ab_surcharge_pct/100))/5)*5
      WHEN transactiondate < t_rounding_5
      THEN ( amount - bpu_fee - dmv_surcharge_amt ) / (1 + (ab_surcharge_pct/100)) 
    END new_orig,
    /*CASE
    WHEN dup_CreatedDate >= '01-JUL-19'
    THEN ROUND((( amount - (ROUND(((amount - dmv_surcharge_amt)*(ab_surcharge_pct/100))/5)*5) - dmv_surcharge_amt) - (dmv_surcharge_amt)*(ab_surcharge_pct/100)) * (ab_surcharge_pct/100)) /5)*5
    WHEN dup_CreatedDate < '01-JUL-19'
    THEN ((( amount - ((amount - dmv_surcharge_amt)*(ab_surcharge_pct/100)) - dmv_surcharge_amt) - (dmv_surcharge_amt)*(ab_surcharge_pct/100)) * (ab_surcharge_pct/100))
    END new_AB,*/
       /* CASE WHEN dup_CreatedDate >= '01-JUL-19' 
      THEN Round((((amount - dmv_surcharge_amt)*(ab_surcharge_pct/100))/5)*5)
      WHEN dup_CreatedDate < '01-JUL-19' 
        THEN ((amount - dmv_surcharge_amt)*(ab_surcharge_pct/100)) 
   END new_AB, */
   -- Orig -3% 
   -- 8/5/2019 changing from dup_CreatedDate to transactiondate
	CASE WHEN transactiondate >= t_rounding_5 and ( ptdescription like '%REN50%' OR ptdescription like '%REN100%')
	  THEN (round (( round((amount + NVL( api.pkg_columnquery.numericvalue(f_objectid, 'ADJUSTEDAMOUNT'), 0) - bpu_fee - dmv_surcharge_amt) / (1+(ab_surcharge_pct/100))) *(ab_surcharge_pct/100))  /5)*5 )
	  WHEN transactiondate >= t_rounding_5 and ( ptdescription NOT like '%REN50%' OR ptdescription NOT like '%REN100%')
	  THEN round(round (( round ((amount  - bpu_fee - dmv_surcharge_amt) / (1+(ab_surcharge_pct/100)) ) *(ab_surcharge_pct/100))  /5)*5 )
      WHEN transactiondate < t_rounding_5 and ( ptdescription like '%REN50%' OR ptdescription like '%REN100%')
  	  THEN  round(round (  (amount + NVL( api.pkg_columnquery.numericvalue(f_objectid, 'ADJUSTEDAMOUNT'), 0) - bpu_fee - dmv_surcharge_amt) / (1+(ab_surcharge_pct/100)) )  * (ab_surcharge_pct/100))
	  WHEN transactiondate < t_rounding_5 and ( ptdescription NOT like '%REN50%' OR ptdescription NOT like '%REN100%')
	  THEN round(round ((amount - bpu_fee - dmv_surcharge_amt) / (1+(ab_surcharge_pct/100)) ) * (ab_surcharge_pct/100))
    END new_AB,
    ab_surcharge_pct ,
    originalfee,
    bpu_fee,
    dmv_surcharge_amt,
    --Rounding nearest $5 using round(num/5)*5
	-- 8/5/2019 changing from dup_CreatedDate to transactiondate
    CASE
      WHEN transactiondate >= t_rounding_5
      THEN (ROUND((originalfee * (ab_surcharge_pct / 100))/5)*5)
      WHEN transactiondate < t_rounding_5
      THEN (originalfee * (ab_surcharge_pct / 100))
    END AS ab_surcharge_amt,
    api.pkg_columnquery.datevalue(pt_objectid, 'PaymentStatus') paymentstatus,
    dup_CreatedDate,
    api.pkg_columnquery.VALUE(ps_objectid, 'Converted') converted,
    api.pkg_columnquery.VALUE(ps_objectid, 'TransactionCode') description,
    api.pkg_columnquery.datevalue(f_objectid, 'RENExpirationDate') expirationdate,
    NVL(api.pkg_columnquery.VALUE(ps_objectid, 'FeeActivity'), 'UTR') feeactivity,
    gallonagerange, -- 7/23 api.pkg_columnquery.VALUE(ps_objectid, 'GallonageFeeCode') gallonagerange,
    api.pkg_columnquery.VALUE(ps_objectid, 'IsMaster') ismaster,
    api.pkg_columnquery.VALUE( (api.pkg_columnquery.numericvalue(f_objectid, 'JobId')), 'LicenseNumber') licensenumber,
    api.pkg_columnquery.VALUE(ps_objectid, 'LicenseTypeCode') licensetypecode,
    api.pkg_columnquery.VALUE(ps_objectid, 'MasterLT') masterlt,
    api.pkg_columnquery.VALUE(ps_objectid, 'NumberOfMonthsLicensedFeeCode') numberofmonthslicensed,
    api.pkg_columnquery.VALUE(ps_objectid, 'PopulationRangeFeeCode') populationrange,
    ptdescription,  --7/23 api.pkg_columnquery.VALUE(pt_objectid, 'FeeScheduleDescriptionForGrid') ptdescription,
    secondarycount, --7/23 api.pkg_columnquery.VALUE(ps_objectid, 'SecondaryCount') secondarycount,
    api.pkg_columnquery.numericvalue(f_objectid, 'FeeId') feeid,
    transactionid,
	transactiondate,
    api.pkg_columnquery.numericvalue(f_objectid, 'JobId') jobid,
    surchargecode,
    licensefeeschedid,
    pt_objectid ,
    f_objectid,
    SecondaryAmount,
		-- 8/5/2019 changing from dup_CreatedDate to transactiondate
		CASE WHEN transactiondate >= t_rounding_5 and ( ptdescription like '%REN50%' OR ptdescription like '%REN100%')
      /* --THEN ((Amount - ((amount + NVL( api.pkg_columnquery.numericvalue(f_objectid, 'ADJUSTEDAMOUNT'), 0) - dmv_surcharge_amt)*(ab_surcharge_pct/100)) + NVL( api.pkg_columnquery.numericvalue(f_objectid, 'ADJUSTEDAMOUNT'), 0) - dmv_surcharge_amt ) * (ab_surcharge_pct/100))
	  	  THEN Amount - ( (amount + NVL( api.pkg_columnquery.numericvalue(f_objectid, 'ADJUSTEDAMOUNT'), 0) - bpu_fee - dmv_surcharge_amt) / (1+(ab_surcharge_pct/100))  )
	  WHEN transactiondate >= t_rounding_5 and ( ptdescription NOT like '%REN50%' OR ptdescription NOT like '%REN100%')
      -- THEN ((amount - ((amount - dmv_surcharge_amt)*(ab_surcharge_pct/100))  - dmv_surcharge_amt ) * (ab_surcharge_pct/100))
	  THEN Amount - ( (amount  - bpu_fee - dmv_surcharge_amt) / (1+(ab_surcharge_pct/100)) )
      WHEN transactiondate < t_rounding_5 and ( ptdescription like '%REN50%' OR ptdescription like '%REN100%')
	  THEN Amount - (  (amount + NVL( api.pkg_columnquery.numericvalue(f_objectid, 'ADJUSTEDAMOUNT'), 0) - bpu_fee - dmv_surcharge_amt) / (1+(ab_surcharge_pct/100)) )	  
	  WHEN transactiondate < t_rounding_5 and ( ptdescription NOT like '%REN50%' OR ptdescription NOT like '%REN100%')
	  THEN Amount - (  (amount - bpu_fee - dmv_surcharge_amt) / (1+(ab_surcharge_pct/100)) ) */ 
	  
	  THEN (((amount + NVL( api.pkg_columnquery.numericvalue(f_objectid, 'ADJUSTEDAMOUNT'), 0) - bpu_fee - dmv_surcharge_amt) / (1+(ab_surcharge_pct/100))) *(ab_surcharge_pct/100))  
	  WHEN transactiondate >= t_rounding_5 and ( ptdescription NOT like '%REN50%' OR ptdescription NOT like '%REN100%')
	  THEN (((amount  - bpu_fee - dmv_surcharge_amt) / (1+(ab_surcharge_pct/100)) ) *(ab_surcharge_pct/100))  
      WHEN transactiondate < t_rounding_5 and ( ptdescription like '%REN50%' OR ptdescription like '%REN100%')
  	  THEN  (  (amount + NVL( api.pkg_columnquery.numericvalue(f_objectid, 'ADJUSTEDAMOUNT'), 0) - bpu_fee - dmv_surcharge_amt) / (1+(ab_surcharge_pct/100)) )  * (ab_surcharge_pct/100)
	  WHEN transactiondate < t_rounding_5 and ( ptdescription NOT like '%REN50%' OR ptdescription NOT like '%REN100%')
	  THEN (  (amount - bpu_fee - dmv_surcharge_amt) / (1+(ab_surcharge_pct/100)) ) * (ab_surcharge_pct/100)

    END  new_AB_B4Rounding 
    --BULK COLLECT INTO l_InitialFetch
  FROM
    (SELECT surchargecode,
      Amount,
      CASE
        WHEN gallonagerange = 'GL1M'
        THEN originalfee + (secondarycount * SecondaryAmount)
        ELSE originalfee
      END originalfee,
      NVL( (
      CASE
        WHEN ptdescription <> 'SRV'
        THEN bpu_fee
        ELSE 0
      END),0) bpu_fee,
      -- NVL(dmv_surcharge_amt,0) dmv_surcharge_amt,
      NVL((
      CASE
        WHEN ptdescription <> 'SRV'
        THEN dmv_surcharge_amt
        ELSE 0
      END),0) dmv_surcharge_amt,
      -- NVL(ab_surcharge_pct,0) ab_surcharge_pct,
      NVL((
      CASE
        WHEN ptdescription <> 'SRV'
        THEN ab_surcharge_pct
        ELSE 0
      END),0) ab_surcharge_pct,
      f_objectid,
      ps_objectid,
      pt_objectid,
      transactionid,
	  transactiondate,
      effectivedate,
      dup_CreatedDate,
      licensefeeschedid,
      SecondaryAmount,
      secondarycount,
      ptdescription,
      gallonagerange
    FROM
      (SELECT fs.surchargecode,
        NVL(fs.amount,0) Amount,
        -- ROUND( ( ( -fs.amount - NVL(bpu_fee, 0) - NVL(dmv_surcharge_amt, 0)) / (1 + (NVL(ab_surcharge_pct, 0) / 100))), 0) original,
        NVL( NVL(
        CASE
          WHEN to_number(api.pkg_columnquery.VALUE(licensefeeschedid, 'ORIGINALFEE')) = 0
          THEN to_number(api.pkg_columnquery.VALUE(licensefeeschedid, 'originalsecondaryfee'))
          ELSE to_number(api.pkg_columnquery.VALUE(licensefeeschedid, 'ORIGINALFEE'))
        END , to_number(api.pkg_columnquery.VALUE(licensefeeschedid, 'originalsecondaryfee')) ), 0) ORIGINALFEE,
        -- 7/24/2019 bpu_fee,
        CASE
          WHEN fs.amount < 0
          THEN bpu_fee * -1
          WHEN fs.amount > 0
          THEN bpu_fee
        END bpu_fee,
        -- 7/24/2019 dmv_surcharge_amt,
        CASE
          WHEN fs.amount < 0
          THEN dmv_surcharge_amt * -1
          WHEN fs.amount > 0
          THEN dmv_surcharge_amt
        END dmv_surcharge_amt,
        ab_surcharge_pct,
        api.pkg_columnquery.VALUE(ps_objectid, 'SecondaryCount') secondarycount,
        --penalty,
        f_objectid,
        ps_objectid,
        pt_objectid,
        transactionid,
		transactiondate,
        s.effectivedate,
        api.pkg_columnquery.datevalue(ps_objectid, 'dup_CreatedDate') dup_CreatedDate,
        licensefeeschedid,
        NVL(to_number(api.pkg_columnquery.VALUE(licensefeeschedid, 'originalsecondaryfee')) , 0) SecondaryAmount,
        api.pkg_columnquery.VALUE(pt_objectid, 'FeeScheduleDescriptionForGrid') ptdescription,
        api.pkg_columnquery.VALUE(ps_objectid, 'GallonageFeeCode') gallonagerange
      FROM
        (SELECT f.objectid f_objectid,
          ps.objectid ps_objectid,
          pt.objectid pt_objectid,
          ft.transactionid,
		  ft.transactiondate,
          f.licensefeeschedid,
          --NVL( api.pkg_columnquery.numericvalue(f.objectid, 'ADJUSTEDAMOUNT'), 0) penalty,
          NVL( api.pkg_columnquery.numericvalue(ps.objectid, 'EarnedAmount'), 0) amount,
          api.pkg_columnquery.VALUE(f.licensefeeschedid, 'surchargecode') surchargecode
          --api.pkg_columnquery.VALUE(f.licensefeeschedid, 'surchargecode') PRIMARYAMOUNT
          --FROM TABLE(CAST(api.pkg_simplesearch.castableobjectsbyindexrange( 'o_PaymentStatus', 'dup_CreatedDate', '2018-02-01', '2018-02-28') AS api.udt_objectlist)) ps
        FROM TABLE( CAST( api.pkg_simplesearch.castableobjectsbyindexrange( 'o_PaymentStatus', 'dup_CreatedDate', TO_CHAR(a_startdate, 'YYYY-MM-DD'), TO_CHAR(a_enddate, 'YYYY-MM-DD')) AS api.udt_objectlist)) ps
          -- JOIN api.objects o
          -- ON o.objectid = ps.objectid
        JOIN query.r_paymentstatuspaymenttrans pspt
        ON pspt.paymentstatusobjectid = ps.objectid --o.objectid
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
        ) fs
      LEFT OUTER JOIN sitespecific.feesurchargeschedule_t s
      ON (fs.surchargecode   = s.surchargecode)
      WHERE (s.effectivedate =
        (SELECT MAX(s2.effectivedate)
        FROM sitespecific.feesurchargeschedule_t s2
        WHERE s2.effectivedate <= transactiondate --api.pkg_columnquery.datevalue(ps_objectid, 'dup_CreatedDate')
        AND s.surchargecode     = s2.surchargecode
        )
      OR s.effectivedate IS NULL)
      )
    )
  ORDER BY LicenseNumber, -- Do not comment order by clause, because the logic is driven by related record logic
    LicenseTypeCode,
    IsMaster,
    FeeActivity,
    api.pkg_ColumnQuery.DateValue(pt_ObjectId,'PaymentStatus'),
    ABS(Amount) DESC
  ) -- Desc will work for REN50A with multiple payments
  LOOP
    IF c.licensenumber || c.licensetypecode || c.feeactivity || c.ismaster = t_lastrecord AND ((c.EarnedAmount < 0 AND t_lastamount < 0) OR (c.EarnedAmount >= 0 AND t_lastamount >= 0)) THEN
      t_relatedrecord := 'Y';
    ELSE
      t_relatedrecord := 'N';
    END IF;
    IF t_relatedrecord    = 'N' THEN
      t_AB_SURCHARGE_PCT := c.AB_SURCHARGE_PCT;
      --IF c.EarnedAmount      > 0 THEN
      t_dmv_surcharge_amt := c.dmv_surcharge_amt;
      t_bpu_fee           := c.bpu_fee;
      t_ab_surcharge_amt  := c.ab_surcharge_amt;
      -- t_penaltyAMT   := c.penaltyAMT;
      SELECT NVL( api.pkg_columnquery.numericvalue(c.f_objectid, 'ADJUSTEDAMOUNT'), 0)
      INTO t_penaltyAMT
      FROM dual;
      /*elsif c.EarnedAmount   < 0 THEN
      t_dmv_surcharge_amt := -c.dmv_surcharge_amt;
      t_bpu_fee           := -c.bpu_fee;
      t_ab_surcharge_amt  := -c.ab_surcharge_amt;
      -- t_penaltyAMT   := - c.penaltyAMT;
      SELECT NVL( api.pkg_columnquery.numericvalue(c.f_objectid, 'ADJUSTEDAMOUNT'), 0)
      INTO t_penaltyAMT
      FROM dual;
      END IF; */
    END IF;
    INSERT
    INTO abc.ALLOCATION_INITIALFETCH
      (
        RECORD_NUM,
        EARNEDAMOUNT,
        AB_SURCHARGE_PCT,
        ORIGINALFEE,
        BPU_FEE,
        DMV_SURCHARGE_AMT,
        AB_SURCHARGE_AMT,
        PAYMENTSTATUS,
        DUP_CREATEDDATE,
        CONVERTED,
        DESCRIPTION,
        EXPIRATIONDATE,
        FEEACTIVITY,
        GALLONAGERANGE,
        ISMASTER,
        LICENSENUMBER,
        LICENSETYPECODE,
        MASTERLT,
        NUMBEROFMONTHSLICENSED,
        POPULATIONRANGE,
        PTDESCRIPTION,
        SECONDARYCOUNT,
        FEEID,
        TRANSACTIONID,
        JOBID,
        SURCHARGECODE,
        LICENSEFEESCHEDID,
        PT_OBJECTID,
        F_OBJECTID,
        penaltyAMT,
        SecondaryAmount,
        new_orig,
        new_AB,
		new_AB_B4Rounding,
		transactiondate
      )
      VALUES
      (
        c.RECORD_NUM,
        c.EARNEDAMOUNT,
        t_AB_SURCHARGE_PCT, --c.AB_SURCHARGE_PCT,
        c.ORIGINALFEE,
        t_BPU_FEE,
        t_dmv_surcharge_amt,
        t_ab_surcharge_amt,
        c.PAYMENTSTATUS,
        c.DUP_CREATEDDATE,
        c.CONVERTED,
        c.DESCRIPTION,
        c.EXPIRATIONDATE,
        c.FEEACTIVITY,
        c.GALLONAGERANGE,
        c.ISMASTER,
        c.LICENSENUMBER,
        c.LICENSETYPECODE,
        c.MASTERLT,
        c.NUMBEROFMONTHSLICENSED,
        c.POPULATIONRANGE,
        c.PTDESCRIPTION,
        c.SECONDARYCOUNT,
        c.FEEID,
        c.TRANSACTIONID,
        c.JOBID,
        c.SURCHARGECODE,
        c.LICENSEFEESCHEDID,
        c.PT_OBJECTID,
        c.f_objectid,
        t_penaltyAMT,
        c.SecondaryAmount,
		c.new_orig,
        (
        CASE
          WHEN t_relatedrecord = 'Y'
          --THEN (c.EARNEDAMOUNT - (c.EARNEDAMOUNT * (c.AB_SURCHARGE_PCT/100) )) * (c.AB_SURCHARGE_PCT/100)
		  then round(round((  (c.EARNEDAMOUNT  ) / (1+(c.ab_surcharge_pct/100)) ) * (c.ab_surcharge_pct/100), 1))
          ELSE c.new_ab
        END ) ,
        (
        CASE
          WHEN t_relatedrecord = 'Y'
          -- THEN (c.EARNEDAMOUNT - (c.EARNEDAMOUNT * (c.AB_SURCHARGE_PCT/100) )) * (c.AB_SURCHARGE_PCT/100)
		  then (  (c.EARNEDAMOUNT  ) / (1+(c.ab_surcharge_pct/100)) ) * (c.ab_surcharge_pct/100)
          ELSE c.new_AB_B4Rounding
        END ) ,
		c.transactiondate
		
		);
    COMMIT;
    t_lastrecord        := c.licensenumber || c.licensetypecode || c.feeactivity || c.ismaster;
    t_lastamount        := c.EarnedAmount;
    t_BPU_FEE           := 0;
    t_dmv_surcharge_amt := 0;
    t_AB_SURCHARGE_AMT  := 0;
    t_penaltyAMT        := 0;
    t_AB_SURCHARGE_PCT  := 0;
  END LOOP;
  BEGIN
    -- Get General fund (POIC)
    SELECT NVL(SUM(EarnedAmount),0)
    INTO v_poic
    FROM abc.ALLOCATION_INITIALFETCH
    WHERE feeactivity = 'POIC'; -- and converted ='Y';
    UPDATE abc.ALLOCATION_INITIALFETCH
    SET bukt_poic     = 'Y'
    WHERE feeactivity = 'POIC';
    COMMIT;
    -- ABC Fund
    -- 7/24/19 SELECT (SUM(EarnedAmount) - NVL( SUM(dmv_surcharge_amt),0) - NVL(SUM(ab_surcharge_amt),0))
    SELECT (SUM(EarnedAmount) - NVL( SUM(dmv_surcharge_amt),0) - NVL(SUM(new_ab),0) - NVL( SUM(bpu_fee),0)) -- 8/8/19 including BP fee
    INTO v_abcfunds
    FROM
      ( SELECT * FROM abc.ALLOCATION_INITIALFETCH
      MINUS
      SELECT *
      FROM abc.ALLOCATION_INITIALFETCH
      WHERE feeactivity  = 'POIC'
      OR feeactivity     = 'CHK'         -- dishonored checks
      OR (feeactivity   IN ('SFP','FFP') -- finger prints
      AND ptdescription <> 'OVR')
      );
    UPDATE abc.ALLOCATION_INITIALFETCH
    SET bukt_ABCFund = 'Y'
    WHERE EXISTS
      ( SELECT * FROM abc.ALLOCATION_INITIALFETCH
      MINUS
      SELECT *
      FROM abc.ALLOCATION_INITIALFETCH
      WHERE feeactivity  = 'POIC'
      OR feeactivity     = 'CHK'         -- dishonored checks
      OR (feeactivity   IN ('SFP','FFP') -- finger prints
      AND ptdescription <> 'OVR')
      );
    /*
    -- Get New Applications
    SELECT SUM(EARNEDAMOUNT)
    INTO v_new_app
    FROM abc.ALLOCATION_INITIALFETCH
    WHERE feeactivity       IN ('ORI','APP','ANN') -- 2019 Brand new ANN added
    AND licensetypecode NOT IN ('26', '28')
    AND PTDESCRIPTION NOT LIKE '%SRV'; --and converted ='Y' ;
    Update abc.ALLOCATION_INITIALFETCH
    set bukt_NewApp = 'Y'
    where feeactivity       IN ('ORI','APP','ANN')
    AND licensetypecode NOT IN ('26', '28')
    AND PTDESCRIPTION NOT LIKE '%SRV';
    Commit;
    -- Get Transfers
    SELECT (SUM(EarnedAmount) - NVL(SUM(bpu_fee),0) - NVL( SUM(dmv_surcharge_amt),0) - NVL(SUM(ab_surcharge_amt),0))
    INTO v_transferfee
    FROM abc.ALLOCATION_INITIALFETCH
    WHERE feeactivity IN ('PER', 'ICO', 'FID', 'STK', 'STM', 'PRM', 'CD8', 'DPR', 'MBR', 'MBM', 'PRMPER')
    AND PTDESCRIPTION NOT LIKE '%SRV'; --and converted ='Y';
    Update abc.ALLOCATION_INITIALFETCH
    set bukt_Transfrs = 'Y'
    where feeactivity IN ('PER', 'ICO', 'FID', 'STK', 'STM', 'PRM', 'CD8', 'DPR', 'MBR', 'MBM', 'PRMPER')
    AND PTDESCRIPTION NOT LIKE '%SRV';
    Commit;
    -- Get BPU with surcharge
    SELECT SUM(BPU_FEE)
    INTO v_BPU
    FROM abc.ALLOCATION_INITIALFETCH
    WHERE PTDESCRIPTION NOT LIKE '%SRV%'
    AND PTDESCRIPTION NOT LIKE 'OVR';
    Update abc.ALLOCATION_INITIALFETCH
    set bukt_BPU = 'Y'
    where PTDESCRIPTION NOT LIKE '%SRV%'
    AND PTDESCRIPTION NOT LIKE 'OVR'
    AND BPU_FEE <> 0;
    Commit;
    -- Penalties
    SELECT SUM(PENALTYAMT)
    INTO v_penalties
    FROM abc.ALLOCATION_INITIALFETCH;
    Update abc.ALLOCATION_INITIALFETCH
    set bukt_Penalties = 'Y'
    where PENALTYAMT <> 0;
    Commit;
    -- Get Renewal
    SELECT (SUM(EarnedAmount) - NVL(SUM(bpu_fee),0) - NVL( SUM(dmv_surcharge_amt),0) - NVL(SUM(ab_surcharge_amt),0) - NVL(SUM(PENALTYAMT),0) )
    INTO v_renewals
    FROM abc.ALLOCATION_INITIALFETCH
    WHERE feeactivity LIKE 'REN%'
    AND PTDESCRIPTION NOT LIKE '%SRV'; --and converted ='Y';
    Update abc.ALLOCATION_INITIALFETCH
    set bukt_Renewal = 'Y'
    where feeactivity LIKE 'REN%'
    AND PTDESCRIPTION NOT LIKE '%SRV';
    Commit;
    -- other
    SELECT SUM(EarnedAmount)
    INTO v_other
    FROM abc.ALLOCATION_INITIALFETCH
    WHERE ptdescription IN ('OVR');
    Update abc.ALLOCATION_INITIALFETCH
    set bukt_Other = 'Y'
    where ptdescription IN ('OVR');
    Commit;
    -- Get Caterers/Event Authorization
    SELECT SUM(EarnedAmount)
    INTO v_eventCat_Auth
    FROM abc.ALLOCATION_INITIALFETCH
    WHERE feeactivity IN ('CATA','EPA')
    AND PTDESCRIPTION NOT LIKE '%SRV%'
    AND PTDESCRIPTION NOT LIKE 'OVR';
    Update abc.ALLOCATION_INITIALFETCH
    set bukt_Event_Auth = 'Y'
    where feeactivity IN ('CATA','EPA')
    AND PTDESCRIPTION NOT LIKE '%SRV%'
    AND PTDESCRIPTION NOT LIKE 'OVR';
    Commit;
    -- Daily Event permits Non-profit(including event renewals) ***TBD we need to exclude this from RENEWALS
    SELECT NVL(SUM(EarnedAmount),0)
    INTO v_eventCat_Permits
    FROM abc.ALLOCATION_INITIALFETCH
    WHERE (feeactivity   IN ( 'DOR') or feeactivity LIKE 'REN%')
    AND licensetypecode IN ('58','77')
    and masterlt NOT IN ('50', '51', '52')
    AND PTDESCRIPTION NOT LIKE '%SRV%'; --converted ='Y';
    Update abc.ALLOCATION_INITIALFETCH
    set bukt_Event_permits = 'Y'
    where (feeactivity   IN ( 'DOR') or feeactivity LIKE 'REN%')
    AND licensetypecode IN ('58','77')
    and masterlt NOT IN ('50', '51', '52')
    AND PTDESCRIPTION NOT LIKE '%SRV%';
    Commit;
    */
    -- Get Appeals Board
    -- 7/24/19 SELECT NVL(SUM(ab_surcharge_amt),0)
    SELECT NVL(SUM(new_ab),0)
    INTO v_ab_surcharges
    FROM abc.ALLOCATION_INITIALFETCH
    WHERE PTDESCRIPTION NOT LIKE '%SRV%'; --converted ='Y';
    UPDATE abc.ALLOCATION_INITIALFETCH
    SET bukt_AB_Surcharge = 'Y'
    WHERE PTDESCRIPTION NOT LIKE '%SRV%'
      -- AND ab_surcharge_amt <> 0;
    AND new_ab <> 0;
    COMMIT;
    -- Get DMV fund
    SELECT NVL(SUM(dmv_surcharge_amt),0)
    INTO v_dmv_surcharges
    FROM abc.ALLOCATION_INITIALFETCH
    WHERE PTDESCRIPTION NOT LIKE '%SRV%'; --converted ='Y';
    UPDATE abc.ALLOCATION_INITIALFETCH
    SET bukt_DMV = 'Y'
    WHERE PTDESCRIPTION NOT LIKE '%SRV%'
    AND dmv_surcharge_amt <> 0;
    COMMIT;
    -- Dishonored check charges
    SELECT NVL(SUM( earnedamount),0)
    INTO v_dishonored
    FROM abc.ALLOCATION_INITIALFETCH
    WHERE feeactivity = 'CHK';
    UPDATE abc.ALLOCATION_INITIALFETCH
    SET bukt_dishonored = 'Y'
    WHERE feeactivity   = 'CHK';
    COMMIT;
    -- Fingerprint fees
    SELECT NVL(SUM( earnedamount),0)
    INTO v_Fingerprint
    FROM abc.ALLOCATION_INITIALFETCH
    WHERE feeactivity IN ('SFP','FFP')
    AND ptdescription <> 'OVR';
    UPDATE abc.ALLOCATION_INITIALFETCH
    SET bukt_FingerPrints = 'Y'
    WHERE feeactivity    IN ('SFP','FFP')
    AND ptdescription    <> 'OVR';
    COMMIT;
    -- Grand total
    SELECT SUM(EarnedAmount)
    INTO v_GrandTotal
    FROM abc.ALLOCATION_INITIALFETCH;
    -- Finish time
    SELECT sysdate INTO v_Finish_dtTime FROM dual;
    -- Final report details
    INSERT
    INTO abc.ALLOCATIONREPORT_2
      (
        POIC,
        NEWAPPLICATION,
        TRANSFERS,
        BPU,
        PENALTIES,
        RENEWALS,
        OTHERS,
        EVENTCATGAUTH,
        EVENTCATGPERMTS,
        AB_SURCHARGE_AMT,
        DMV_SURCHARGE_AMT,
        DISHONORED,
        FINGERPRINTS,
        GRANDTOTAL,
        RPT_START_DT,
        RPT_END_DT,
        RUN_START_TIME,
        RUN_END_TIME,
        abcfunds
      )
      VALUES
      (
        v_poic,
        v_new_app,
        v_transferfee,
        v_BPU,
        v_penalties,
        v_renewals,
        v_other,
        v_eventCat_Auth,
        v_eventCat_Permits,
        v_ab_surcharges,
        v_dmv_surcharges,
        v_dishonored,
        v_fingerprint,
        v_GrandTotal,
        a_StartDate,
        a_EndDate,
        v_start_dtTime,
        v_Finish_dtTime,
        v_abcfunds
      );
    COMMIT;
  END;
  dbms_output.put_line('Done AllocationReport2' );
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
END AllocationReport2;
/
