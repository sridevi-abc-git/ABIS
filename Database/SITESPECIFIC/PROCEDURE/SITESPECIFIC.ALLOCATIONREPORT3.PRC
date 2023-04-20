CREATE OR REPLACE PROCEDURE SITESPECIFIC.AllocationReport3(
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
  A_STARTDATE := '29-JUL-19';   --Format 'DD-MON-YY'
  A_ENDDATE := '30-JUL-19';   --Format 'DD-MON-YY'
  A_DEBUG := 'N';
  a_run_id := 1; -- Use different runid, if you want to run multiple times for the same date range
  ALLOCATIONREPORT3(
  A_STARTDATE => A_STARTDATE,
  A_ENDDATE => A_ENDDATE,
  A_DEBUG => A_DEBUG,
  a_run_id => a_run_id
  );
  END;
  REVISIONS:
  Ver        Date        Author          Description
  ---------  ----------  --------------  ------------------------------------
  1.1        06/20/2019   Sheik          Allocation Report 2.0
  2.0        07/26/2019   Sheik 		 Fixing DMV,AB for the adjustments and secondaries
  2.1		 08/12/2019   Sheik			 Grouping multiple payments to avoid wrong AB Calculations	
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
  dbms_output.put_line('Starting at .. '||TO_CHAR(v_start_dtTime,'MM/DD/YY HH12:MM'));
  DELETE FROM abc.ALLOCATION_INITIALFETCH3;
  DELETE FROM abc.ALLOCATIONREPORT_3;
  DELETE FROM abc.ALLOCATION_Grouped3;
  COMMIT;
  
  FOR c IN
  (SELECT rownum record_num,
    amount EarnedAmount,
    ab_surcharge_pct ,
    -- originalfee,
	case when amount < 0 
		then ORIGINALFEE * -1 
		when amount >= 0 then ORIGINALFEE
	end originalfee,
    bpu_fee,
    dmv_surcharge_amt,
    api.pkg_columnquery.datevalue(pt_objectid, 'PaymentStatus') paymentstatus,
    dup_CreatedDate,
    api.pkg_columnquery.VALUE(ps_objectid, 'Converted') converted,
    api.pkg_columnquery.VALUE(ps_objectid, 'TransactionCode') description,
    api.pkg_columnquery.datevalue(f_objectid, 'RENExpirationDate') expirationdate,
    NVL(api.pkg_columnquery.VALUE(ps_objectid, 'FeeActivity'), 'UTR') feeactivity,
    gallonagerange, 
    api.pkg_columnquery.VALUE(ps_objectid, 'IsMaster') ismaster,
    api.pkg_columnquery.VALUE( (api.pkg_columnquery.numericvalue(f_objectid, 'JobId')), 'LicenseNumber') licensenumber,
    api.pkg_columnquery.VALUE(ps_objectid, 'LicenseTypeCode') licensetypecode,
    api.pkg_columnquery.VALUE(ps_objectid, 'MasterLT') masterlt,
    api.pkg_columnquery.VALUE(ps_objectid, 'NumberOfMonthsLicensedFeeCode') numberofmonthslicensed,
    api.pkg_columnquery.VALUE(ps_objectid, 'PopulationRangeFeeCode') populationrange,
    ptdescription,  
    secondarycount, 
    feeid,
    transactionid,
	transactiondate,
    jobid, 
    surchargecode,
    licensefeeschedid,
    pt_objectid ,
    f_objectid,
    SecondaryAmount,
	NVL( api.pkg_columnquery.numericvalue(f_objectid, 'ADJUSTEDAMOUNT'), 0) penaltyAMT
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

      NVL((
      CASE
        WHEN ptdescription <> 'SRV'
        THEN dmv_surcharge_amt
        ELSE 0
      END),0) dmv_surcharge_amt,

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
      -- SecondaryAmount,
	  CASE
          WHEN amount < 0
          THEN SecondaryAmount * -1
          WHEN amount > 0
          THEN SecondaryAmount
        END SecondaryAmount,
      secondarycount,
      ptdescription,
      gallonagerange,
	  feeid,
	  jobid
    FROM
      (SELECT fs.surchargecode,
        fs.amount Amount,
        NVL( NVL(
        CASE
          WHEN to_number(api.pkg_columnquery.VALUE(licensefeeschedid, 'ORIGINALFEE')) = 0
          THEN to_number(api.pkg_columnquery.VALUE(licensefeeschedid, 'originalsecondaryfee'))
          ELSE to_number(api.pkg_columnquery.VALUE(licensefeeschedid, 'ORIGINALFEE'))
        END , to_number(api.pkg_columnquery.VALUE(licensefeeschedid, 'originalsecondaryfee')) ), 0) ORIGINALFEE,
        CASE
          WHEN fs.amount < 0
          THEN bpu_fee * -1
          WHEN fs.amount > 0
          THEN bpu_fee
        END bpu_fee,
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
        api.pkg_columnquery.VALUE(ps_objectid, 'GallonageFeeCode') gallonagerange,
		api.pkg_columnquery.numericvalue(f_objectid, 'FeeId') feeid, 
		    api.pkg_columnquery.numericvalue(f_objectid, 'JobId') jobid 
      FROM
        (SELECT f.objectid f_objectid,
          ps.objectid ps_objectid,
          pt.objectid pt_objectid,
          ft.transactionid,
		  ft.transactiondate,
          f.licensefeeschedid,
          NVL( api.pkg_columnquery.numericvalue(ps.objectid, 'EarnedAmount'), 0) amount,
          api.pkg_columnquery.VALUE(f.licensefeeschedid, 'surchargecode') surchargecode
          -- FROM TABLE(CAST(api.pkg_simplesearch.castableobjectsbyindexrange( 'o_PaymentStatus', 'dup_CreatedDate', '2018-02-01', '2018-02-28') AS api.udt_objectlist)) ps
		  FROM TABLE( CAST( api.pkg_simplesearch.castableobjectsbyindexrange( 'o_PaymentStatus', 'dup_CreatedDate', TO_CHAR(a_startdate, 'YYYY-MM-DD'), TO_CHAR(a_enddate, 'YYYY-MM-DD')) AS api.udt_objectlist)) ps
        JOIN query.r_paymentstatuspaymenttrans pspt
        ON pspt.paymentstatusobjectid = ps.objectid 
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
     -- and rownum < 10
      )
    )
    
  ORDER BY LicenseNumber, 
    LicenseTypeCode,
    IsMaster,
    FeeActivity,
    api.pkg_ColumnQuery.DateValue(pt_ObjectId,'PaymentStatus'),
    ABS(Amount) DESC
  ) 
  LOOP
	 
    INSERT
    INTO abc.ALLOCATION_INITIALFETCH3
      (
        RECORD_NUM,
        EARNEDAMOUNT,
        AB_SURCHARGE_PCT,
        ORIGINALFEE,
        BPU_FEE,
        DMV_SURCHARGE_AMT,
        --AB_SURCHARGE_AMT,
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
		transactiondate
      )
      VALUES
      (
        c.RECORD_NUM,
        c.EARNEDAMOUNT,
        c.AB_SURCHARGE_PCT, 
		/*case when c.earnedamount < 0 
		then c.ORIGINALFEE * -1 
		when c.earnedamount >= 0 then c.ORIGINALFEE
		end, */
		--c.ORIGINALFEE,
		case when 	c.SECONDARYCOUNT > 0 and 
		c.PTDESCRIPTION <> 'SRV' and 
		--c.feeactivity <> 'DOR' and 
		c.PTDESCRIPTION NOT LIKE '%DOR%' and
		c.MASTERLT = c.LICENSETYPECODE and 
		c.SURCHARGECODE IS NOT NULL
		then c.ORIGINALFEE + (c.SECONDARYCOUNT * c.SECONDARYAMOUNT)  --+ (c.SECONDARYCOUNT * c.DMV_SURCHARGE_AMT )
		else c.ORIGINALFEE
		end,
        c.BPU_FEE,
       -- c.dmv_surcharge_amt,
	   	case when 	c.SECONDARYCOUNT > 0 and 
		c.PTDESCRIPTION <> 'SRV' and 
		--c.feeactivity <> 'DOR' and 
		c.PTDESCRIPTION NOT LIKE '%DOR%' and
		c.MASTERLT = c.LICENSETYPECODE and 
		c.SURCHARGECODE IS NOT NULL
		then (c.SECONDARYCOUNT * c.DMV_SURCHARGE_AMT ) + c.DMV_SURCHARGE_AMT 
		else c.DMV_SURCHARGE_AMT
		end,
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
        c.penaltyAMT,
        c.SecondaryAmount,
		c.transactiondate
		);
    COMMIT;

  END LOOP;
  
	-- Group all multiple payments to one single record
	insert into 	abc.ALLOCATION_Grouped3
	(RECORD_NUM , 
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
	PENALTYAMT,
	BUKT_POIC,
	BUKT_NEWAPP,
	BUKT_TRANSFRS,
	BUKT_BPU, 
	BUKT_PENALTIES,
	BUKT_RENEWAL,
	BUKT_OTHER,
	BUKT_EVENT_AUTH,
	BUKT_EVENT_PERMITS,
	BUKT_AB_SURCHARGE,
	BUKT_DMV,
	BUKT_DISHONORED,
	BUKT_FINGERPRINTS,
	BUKT_ABCFUND,
	SECONDARYAMOUNT, 
	NEW_ORIG,
	NEW_AB,
	NEW_AB_B4ROUNDING, 
	TRANSACTIONDATE)
	select l2.RECORD_NUM , 
	l1.EARNEDAMOUNT, 
	l2.AB_SURCHARGE_PCT,
	l2.ORIGINALFEE ,
	/* case when 	l2.SECONDARYCOUNT > 0 and 
				l2.PTDESCRIPTION <> 'SRV' and 
				l2.MASTERLT = l2.LICENSETYPECODE and 
				l2.SURCHARGECODE IS NOT NULL
		 then l2.ORIGINALFEE + (l2.SECONDARYCOUNT * l2.SECONDARYAMOUNT) + (l2.SECONDARYCOUNT * l2.DMV_SURCHARGE_AMT )
	else l2.ORIGINALFEE
	end ORIGINALFEE,	*/ 
	case when l1.EARNEDAMOUNT = 0 then 0 
	else l2.BPU_FEE 
	end BPU_FEE,
	case when l1.EARNEDAMOUNT = 0 then 0
	else l2.DMV_SURCHARGE_AMT
	end DMV_SURCHARGE_AMT,
	--CASE WHEN transactiondate >= '01-OCT-19' then round( l2.ORIGINALFEE * (l2.ab_surcharge_pct/100) /5)*5 
	--else round( l2.ORIGINALFEE * (l2.ab_surcharge_pct/100) )  
	CASE WHEN transactiondate >= '01-OCT-19' and l1.EARNEDAMOUNT <> 0 then round( l2.ORIGINALFEE * (l2.ab_surcharge_pct/100) /5)*5 
		 when l1.EARNEDAMOUNT = 0 then 0
		 else round( l2.ORIGINALFEE * (l2.ab_surcharge_pct/100) )  
	end AB_SURCHARGE_AMT, 
	l2.PAYMENTSTATUS,
	DUP_CREATEDDATE,
	CONVERTED,
	DESCRIPTION,
	EXPIRATIONDATE,
	l2.FEEACTIVITY,
	GALLONAGERANGE,
	l2.ISMASTER,
	l2.LICENSENUMBER,
	l2.LICENSETYPECODE,
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
	PENALTYAMT,
	BUKT_POIC,
	BUKT_NEWAPP,
	BUKT_TRANSFRS,
	BUKT_BPU, 
	BUKT_PENALTIES,
	BUKT_RENEWAL,
	BUKT_OTHER,
	BUKT_EVENT_AUTH,
	BUKT_EVENT_PERMITS,
	BUKT_AB_SURCHARGE,
	BUKT_DMV,
	BUKT_DISHONORED,
	BUKT_FINGERPRINTS,
	BUKT_ABCFUND,
	SECONDARYAMOUNT, 
	NEW_ORIG,
	NEW_AB,
	NEW_AB_B4ROUNDING, 
	TRANSACTIONDATE 
	from 	ALLOCATION_INITIALFETCH3 l2,
	(select LicenseNumber,
	LicenseTypeCode,
	IsMaster,
	FeeActivity,
	PaymentStatus,
	min(RECORD_NUM) record_num,
	sum(EarnedAmount) earnedamount
	from ALLOCATION_INITIALFETCH3
	group by LicenseNumber,
	LicenseTypeCode,
	IsMaster,
	FeeActivity,
	PaymentStatus) l1
	where l1.record_num = l2.record_num
	order by l1.record_num;
 
  BEGIN
    -- Get General fund (POIC)
    SELECT NVL(SUM(EarnedAmount),0)
    INTO v_poic
    FROM abc.ALLOCATION_Grouped3
    WHERE feeactivity = 'POIC'; -- and converted ='Y';
    UPDATE abc.ALLOCATION_Grouped3
    SET bukt_poic     = 'Y'
    WHERE feeactivity = 'POIC';
    COMMIT;
    -- ABC Fund
    SELECT (SUM(EarnedAmount) - NVL( SUM(dmv_surcharge_amt),0) - NVL(SUM(new_ab),0) - NVL( SUM(bpu_fee),0)) 
    INTO v_abcfunds
    FROM
      ( SELECT * FROM abc.ALLOCATION_Grouped3
      MINUS
      SELECT *
      FROM abc.ALLOCATION_Grouped3
      WHERE feeactivity  = 'POIC'
      OR feeactivity     = 'CHK'         -- dishonored checks
      OR (feeactivity   IN ('SFP','FFP') -- finger prints
      AND ptdescription <> 'OVR')
      );
    UPDATE abc.ALLOCATION_Grouped3
    SET bukt_ABCFund = 'Y'
    WHERE EXISTS
      ( SELECT * FROM abc.ALLOCATION_Grouped3
      MINUS
      SELECT *
      FROM abc.ALLOCATION_Grouped3
      WHERE feeactivity  = 'POIC'
      OR feeactivity     = 'CHK'         -- dishonored checks
      OR (feeactivity   IN ('SFP','FFP') -- finger prints
      AND ptdescription <> 'OVR')
      );

    SELECT NVL(SUM(new_ab),0)
    INTO v_ab_surcharges
    FROM abc.ALLOCATION_Grouped3
    WHERE PTDESCRIPTION NOT LIKE '%SRV%'; --converted ='Y';
    UPDATE abc.ALLOCATION_Grouped3
    SET bukt_AB_Surcharge = 'Y'
    WHERE PTDESCRIPTION NOT LIKE '%SRV%'
      -- AND ab_surcharge_amt <> 0;
    AND new_ab <> 0;
    COMMIT;
    -- Get DMV fund
    SELECT NVL(SUM(dmv_surcharge_amt),0)
    INTO v_dmv_surcharges
    FROM abc.ALLOCATION_Grouped3
    WHERE PTDESCRIPTION NOT LIKE '%SRV%'; --converted ='Y';
    UPDATE abc.ALLOCATION_Grouped3
    SET bukt_DMV = 'Y'
    WHERE PTDESCRIPTION NOT LIKE '%SRV%'
    AND dmv_surcharge_amt <> 0;
    COMMIT;
    -- Dishonored check charges
    SELECT NVL(SUM( earnedamount),0)
    INTO v_dishonored
    FROM abc.ALLOCATION_Grouped3
    WHERE feeactivity = 'CHK';
    UPDATE abc.ALLOCATION_Grouped3
    SET bukt_dishonored = 'Y'
    WHERE feeactivity   = 'CHK';
    COMMIT;
    -- Fingerprint fees
    SELECT NVL(SUM( earnedamount),0)
    INTO v_Fingerprint
    FROM abc.ALLOCATION_Grouped3
    WHERE feeactivity IN ('SFP','FFP')
    AND ptdescription <> 'OVR';
    UPDATE abc.ALLOCATION_Grouped3
    SET bukt_FingerPrints = 'Y'
    WHERE feeactivity    IN ('SFP','FFP')
    AND ptdescription    <> 'OVR';
    COMMIT;
    -- Grand total
    SELECT SUM(EarnedAmount)
    INTO v_GrandTotal
    FROM abc.ALLOCATION_Grouped3;
    -- Finish time
    SELECT sysdate INTO v_Finish_dtTime FROM dual;
    -- Final report details
    INSERT
    INTO abc.ALLOCATIONREPORT_3
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
END AllocationReport3;
/
