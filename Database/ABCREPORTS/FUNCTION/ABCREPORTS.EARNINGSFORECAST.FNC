CREATE OR REPLACE FUNCTION ABCREPORTS.earningsforecast(p_parms IN OUT t_parameters, p_status_ind IN OUT VARCHAR2)
    RETURN BLOB
IS
    -- ****************************************************************************
    -- File:        EarningsForecast.FNC
    -- Author:      Timothy J. Lord
    --
    -- $Rev$
    -- $Date$
    -- Last Changed By:  $Author$
    --
    -- Description:
    --
    --
    -- History:
    -------------------------------------------------------------------------------
    --    Date                  Comment
    -- 04/08/2020 TJL  21235  Initial file create
    -- ****************************************************************************
    FUNCTION getexpirationdate(a_jobid IN api.pkg_definition.udt_id, a_seasonal IN VARCHAR2)
        RETURN DATE
    IS
        t_expirationdate   DATE;
    BEGIN
        t_expirationdate   :=
            NVL(NVL(t_expirationdate, api.pkg_columnquery.datevalue(a_jobid, 'ExpirationDate')), SYSDATE);

        -- Get Seasonal Info
        IF a_seasonal = 'Y' THEN
            t_expirationdate   :=
                  TO_DATE(
                         LPAD(api.pkg_columnquery.VALUE(a_jobid, 'SeasonStartMonthnumber'), 2, '00')
                      || '/01/'
                      || CASE
                             WHEN (  TO_NUMBER(
                                         TO_CHAR(api.pkg_columnquery.datevalue(a_jobid, 'dup_ExpirationDate'), 'MM'))
                                   - (api.pkg_columnquery.numericvalue(a_jobid, 'NumberOfMonthsLicensedNumber') + 1)) <  -- 01/09/2019 TJL 16435 removed = from test
                                  0 THEN
                                 NVL(api.pkg_columnquery.numericvalue(a_jobid, 'ExpiringYear'), 9999)
                             ELSE
                                 NVL(api.pkg_columnquery.numericvalue(a_jobid, 'ExpiringYear') + 1, '9999')
                         END,
                      'MM/DD/YYYY')
                - 1;
        END IF;

        RETURN t_expirationdate;
    END;

    PROCEDURE get_surcharges(a_amount       IN     NUMBER,
                             a_transactiondate IN  DATE,
                             a_feescheduleobjectid IN NUMBER,
                             a_ltcount      IN     NUMBER,
                             a_originalfee     OUT NUMBER,
                             a_ab_surcharge    OUT NUMBER,
                             a_dmv_surcharge_amt   OUT NUMBER,
                             a_bpu_fee         OUT NUMBER)
    IS
        t_feesurchargescheduleobjectid   NUMBER := NULL;
        t_ab_surcharge_pct               NUMBER;
        t_amountbase                     NUMBER;
        t_roundingfactor                 NUMBER;
        t_amountbase_ttl                 NUMBER := 0;
        t_dmv                            NUMBER := 0;
        t_bpu                            NUMBER := 0;
        t_ab                             NUMBER := 0;
        t_amount                         NUMBER;
        t_lttype                         NUMBER;
        t_secondaryamount                NUMBER;
    BEGIN
        t_lttype              := api.pkg_columnquery.VALUE(a_feescheduleobjectid, 'LicenseTypeCode');
        t_secondaryamount     := api.pkg_columnquery.VALUE(a_feescheduleobjectid, 'SecondaryAmount');

        -- get the fee surcharge record for fee record
            WITH
                surcharge
                AS
                    (SELECT (SELECT objectid
                               FROM sitespecific.feesurchargeschedule_t fs
                              WHERE fs.surchargecode = api.pkg_columnquery.VALUE(f.objectid, 'surchargecode')
                                AND fs.effectivedate = (SELECT MAX(fs2.effectivedate)
                                                          FROM sitespecific.feesurchargeschedule_t fs2
                                                         WHERE fs2.surchargecode = fs.surchargecode
                                                           AND trunc(fs2.effectivedate) <= trunc(a_transactiondate)))
                                feesurchargescheduleobjectid
                       FROM sitespecific.feeschedule_t f
                      WHERE f.objectid = a_feescheduleobjectid)
            SELECT s.feesurchargescheduleobjectid
              INTO t_feesurchargescheduleobjectid
              FROM surcharge s;

        -- get rounding factor the AB Surcharge calculation
        t_roundingfactor      :=
            NVL(api.pkg_columnquery.numericvalue(t_feesurchargescheduleobjectid, 'roundingfactor'), 1);
        t_ab_surcharge_pct    :=
            NVL(api.pkg_columnquery.numericvalue(t_feesurchargescheduleobjectid, 'ab_surcharge_pct'), 0) / 100;

        a_bpu_fee             := 0;
        a_dmv_surcharge_amt   := 0;
        a_ab_surcharge        := 0;
        a_originalfee         := 0;
        t_amount              :=
            CASE
                WHEN t_lttype NOT IN ('02', '22') THEN
                    a_amount / CASE WHEN NVL(a_ltcount, 1) = 0 THEN 1 ELSE NVL(a_ltcount, 1) END
                ELSE
                    CASE
                        WHEN NVL(api.pkg_columnquery.VALUE(a_feescheduleobjectid, 'PrimaryAmount'), 0) != 0 THEN
                            api.pkg_columnquery.VALUE(a_feescheduleobjectid, 'PrimaryAmount')
                        ELSE
                            api.pkg_columnquery.VALUE(a_feescheduleobjectid, 'BranchAmount')
                    END
            END;

        FOR i IN 1 .. CASE WHEN NVL(a_ltcount, 1) = 0 THEN 1 ELSE NVL(a_ltcount, 1) END
        LOOP
            IF (t_lttype NOT IN ('02', '22')
             OR (t_lttype IN ('02', '22')
             AND i = 1)) THEN
                t_bpu   := NVL(api.pkg_columnquery.numericvalue(t_feesurchargescheduleobjectid, 'bpu_fee'), 0);
                t_dmv   :=
                    NVL(api.pkg_columnquery.numericvalue(t_feesurchargescheduleobjectid, 'dmv_surcharge_amt'), 0);
            ELSE
                t_amount   := t_secondaryamount;
                t_dmv      := 0;  -- only one dmv fee for 02
                t_bpu      := 0;
            END IF;

            t_amountbase          := t_amount - t_dmv - t_bpu;

            t_ab                  :=
                  ROUND((t_amountbase - (t_amountbase / (1 + t_ab_surcharge_pct))) / t_roundingfactor)
                * t_roundingfactor;

            a_bpu_fee             := a_bpu_fee + t_bpu;
            a_dmv_surcharge_amt   := a_dmv_surcharge_amt + t_dmv;
            a_ab_surcharge        := a_ab_surcharge + t_ab;
            a_originalfee         := a_originalfee + t_amountbase - t_ab;
        END LOOP;
    END;

    PROCEDURE updatereporttable(a_start_date IN DATE, a_end_date IN DATE)
    IS
        licrec                fn_forecast_rpt%ROWTYPE;
        slicrec               fn_forecast_rpt%ROWTYPE;
        t_populationapplies   VARCHAR2(1);
        t_seasonal            VARCHAR2(1);
        t_expiration_date     DATE;
        t_processed           NUMBER := 0;
            
    BEGIN
        BEGIN
            DELETE fn_forecast_rpt;

            FOR i IN 0 .. FLOOR(ABS(MONTHS_BETWEEN(a_start_date, a_end_date)))
            LOOP
                t_expiration_date   := ADD_MONTHS(TO_DATE(a_start_date), i);
                DBMS_OUTPUT.put_line(LAST_DAY(ADD_MONTHS(TO_DATE(a_start_date), i)));

                FOR job
                    IN (SELECT DISTINCT objectid
                          FROM (SELECT objectid
                                  FROM TABLE(
                                           CAST(
                                               api.pkg_simplesearch.castableobjectsbyindex(
                                                   a_objectdefname =>
                                                       'j_LicenseType',
                                                   a_columnname =>
                                                       'ExpiringMonth',
                                                   a_value => 
                                                       upper(to_char(t_expiration_date,'fmMonth'))) AS api.udt_objectlist))
--                                  FROM TABLE(
--                                           CAST(
--                                               api.pkg_simplesearch.castableobjectsbyindexrange(
--                                                   a_objectdefname =>
--                                                       'j_LicenseType',
--                                                   a_columnname =>
--                                                       'dup_expirationDate',
--                                                   a_lowvalue =>
--                                                       TO_CHAR(TRUNC(t_expiration_date, 'mm'), 'yyyy-mm-dd'),
--                                                   a_highvalue =>
--                                                       TO_CHAR(LAST_DAY(t_expiration_date), 'yyyy-mm-dd')) AS api.udt_objectlist))
--                                UNION
--                                SELECT objectid
--                                  FROM TABLE(CAST(api.pkg_simplesearch.castableobjectsbyindexrange(
--                                                      a_objectdefname =>
--                                                          'j_LicenseType',
--                                                      a_columnname =>
--                                                          'dup_expirationDate',
--                                                      a_lowvalue =>
--                                                          TO_CHAR(TRUNC(ADD_MONTHS(t_expiration_date, 12), 'mm'),
--                                                                  'yyyy-mm-dd'),
--                                                      a_highvalue =>
--                                                          TO_CHAR(LAST_DAY(ADD_MONTHS(t_expiration_date, 12)),
--                                                                  'yyyy-mm-dd')) AS api.udt_objectlist))
--                                UNION
--                                SELECT objectid
--                                  FROM TABLE(CAST(api.pkg_simplesearch.castableobjectsbyindexrange(
--                                                      a_objectdefname =>
--                                                          'j_LicenseType',
--                                                      a_columnname =>
--                                                          'dup_expirationDate',
--                                                      a_lowvalue =>
--                                                          TO_CHAR(TRUNC(ADD_MONTHS(t_expiration_date, -12), 'mm'),
--                                                                  'yyyy-mm-dd'),
--                                                      a_highvalue =>
--                                                          TO_CHAR(LAST_DAY(ADD_MONTHS(t_expiration_date, -12)),
--                                                                  'yyyy-mm-dd')) AS api.udt_objectlist))
))
                LOOP
                    CONTINUE WHEN api.pkg_columnquery.VALUE(job.objectid, 'statusname') NOT IN ('ACTIVE',
                                                                                                'R64B',
                                                                                                'SLMSHD', 
                                                                                                'SUSPEN', 
                                                                                                'REVPEN',
                                                                                                'SUREND');
                    t_processed                       := t_processed + 1;

                    SELECT api.pkg_columnquery.VALUE(r.toobjectid, 'populationapplies'),
                           api.pkg_columnquery.VALUE(r.toobjectid, 'seasonalmonthsapply')
                      INTO t_populationapplies, t_seasonal
                      FROM api.relationships r
                     WHERE r.fromobjectid = job.objectid  --a_jobid
                       AND r.endpointid = api.pkg_configquery.endpointidforname('j_LicenseType', 'LicTypeCatPrimary');

                    -- build record
                    licrec.jobid                      := job.objectid;  --a_jobid;
                    licrec.effectivedate              := getexpirationdate(licrec.jobid, t_seasonal);
                    licrec.licensenumber              := api.pkg_columnquery.VALUE(licrec.jobid, 'LicenseNumber');
                    licrec.ltcode                     := api.pkg_columnquery.VALUE(licrec.jobid, 'dup_LicenseTypeCode');
                    licrec.numberofmonthslicensed     :=
                        CASE t_seasonal
                            WHEN 'Y' THEN api.pkg_columnquery.VALUE(licrec.jobid, 'NumberOfMonthsLicensedFeeCode')
                            ELSE NULL
                        END;
                    licrec.populationrange            :=
                        CASE t_populationapplies
                            WHEN 'Y' THEN api.pkg_columnquery.VALUE(licrec.jobid, 'PopulationRangeFeeCode')
                            ELSE NULL
                        END;
                    licrec.gallonagerange             := api.pkg_columnquery.VALUE(licrec.jobid, 'GallonageRange');
                    licrec.additionalmilliongallons   :=
                        api.pkg_columnquery.VALUE(licrec.jobid, 'AdditionalMillionGallons');
                    licrec.ltcount                    := api.pkg_columnquery.VALUE(licrec.jobid, 'PrimaryCount');

                    licrec.feetype                    :=
                        CASE api.pkg_columnquery.VALUE(licrec.jobid, 'IsBranchPy') WHEN 'N' THEN 'P' ELSE 'B' END;
                    licrec.secondaryamount            := 0;

                    sitespecific.pkg_fees.getltfeeamount(
                        a_jobid     => licrec.jobid,
                        a_effectivedate => licrec.effectivedate,
                        a_feeactivitytype => 'REN',
                        a_otherfeecode => NULL,
                        a_ltcode    => licrec.ltcode,
                        a_gallonagerange => case licrec.feetype when 'P' then licrec.gallonagerange else NULL end,
                        a_additionalmilliongallons => licrec.additionalmilliongallons,
                        a_numberofmonthslicensed => licrec.numberofmonthslicensed,
                        a_populationrange => licrec.populationrange,
                        a_tier      => TO_CHAR(NULL),
                        a_feetype   => licrec.feetype,
                        a_ltcount   => licrec.ltcount,
                        a_asofdate  => TO_DATE(NULL),
                        a_feeamount => licrec.feeamount,
                        a_licensefeescheduleid => licrec.licensefeescheduleid);

                    licrec.scheduleorig               :=
                        api.pkg_columnquery.VALUE(
                            licrec.licensefeescheduleid,
                            CASE licrec.feetype
                                WHEN 'P' THEN
                                    CASE
                                        WHEN api.pkg_columnquery.VALUE(licrec.licensefeescheduleid, 'originalfee')
                                                 IS NULL THEN
                                            'originalsecondaryfee'
                                        ELSE
                                            'originalfee'
                                    END
                                ELSE
                                    'originalsecondaryfee'
                            END);

                    licrec.scheduleadjustedorig       :=
                        CASE
                            WHEN licrec.ltcode IN ('02', '22') THEN
                                  licrec.scheduleorig
                                + (NVL(
                                         licrec.additionalmilliongallons
                                       * api.pkg_columnquery.VALUE(licrec.licensefeescheduleid,
                                                                   'originalsecondaryfee'),
                                       0))
                            WHEN licrec.ltcode = '06' THEN
                                licrec.scheduleorig * (NVL(licrec.ltcount, 0) + 1)
                            ELSE
                                CASE
                                    WHEN NVL(licrec.ltcount, 1) = 0 THEN licrec.scheduleorig
                                    ELSE licrec.scheduleorig * NVL(licrec.ltcount, 1)
                                END
                        END;

                    get_surcharges(
                        a_amount =>
                            licrec.feeamount,
                        a_transactiondate =>
                            licrec.effectivedate,
                        a_feescheduleobjectid =>
                            licrec.licensefeescheduleid,
                        a_ltcount =>
                            CASE
                                WHEN licrec.ltcode IN ('02', '22') THEN NVL(licrec.additionalmilliongallons, 0) + 1
                                WHEN licrec.ltcode = '06' THEN NVL(licrec.ltcount, 0) + 1
                                WHEN licrec.ltcode IN ('67', '80') THEN 1
                                ELSE licrec.ltcount
                            END,
                        a_originalfee =>
                            licrec.originalfee,
                        a_ab_surcharge =>
                            licrec.abfee,
                        a_dmv_surcharge_amt =>
                            licrec.dmvfee,
                        a_bpu_fee =>
                            licrec.bpufee);

                    INSERT INTO fn_forecast_rpt
                    VALUES licrec;

                    IF (api.pkg_columnquery.VALUE(licrec.jobid, 'HasSecondary') = 'Y') THEN
                        FOR rec
                            IN (SELECT TRIM(REGEXP_SUBSTR(str,
                                                          '[^ ]+',
                                                          1,
                                                          1))
                                           secondarytype,
                                       NVL(REGEXP_SUBSTR(str,
                                                         '\[([^]]+)\]',
                                                         1,
                                                         1,
                                                         NULL,
                                                         1),
                                           '1')
                                           secondarycount,
                                       REGEXP_SUBSTR(str, '[^ ]+$')
                                           status
                                  FROM (WITH
                                            data
                                            AS
                                                (SELECT api.pkg_columnquery.VALUE(licrec.jobid,
                                                                                  'SecondaryLTCodeCountAndStatus')
                                                            str
                                                   FROM DUAL)
                                            SELECT TRIM(REGEXP_SUBSTR(str,
                                                                      '[^,]+',
                                                                      1,
                                                                      LEVEL))
                                                       str
                                              FROM data
                                        CONNECT BY REGEXP_SUBSTR(str,
                                                                 '[^,]+',
                                                                 1,
                                                                 LEVEL)
                                                       IS NOT NULL))
                        LOOP
                            CONTINUE WHEN rec.status NOT IN ('ACTIVE', 'R64B');
                            slicrec                        := licrec;

                            BEGIN
                                SELECT api.pkg_columnquery.VALUE(r.toobjectid, 'populationapplies'),
                                       api.pkg_columnquery.VALUE(r.toobjectid, 'seasonalmonthsapply')
                                  INTO t_populationapplies, t_seasonal
                                  FROM api.relationships r
                                 WHERE r.fromobjectid = licrec.jobid
                                   AND r.endpointid =
                                       api.pkg_configquery.endpointidforname('j_LicenseType', 'LicTypeCatSecondary')
                                   AND api.pkg_columnquery.VALUE(r.toobjectid, 'licensetypecode') = rec.secondarytype
                                   AND ROWNUM = 1;

                                slicrec.populationrange   :=
                                    CASE
                                        WHEN t_populationapplies = 'Y'
                                          OR (licrec.ltcode IN (50, 51, 52)
                                          AND rec.secondarytype = 58) THEN
                                            licrec.populationrange
                                        ELSE
                                            NULL
                                    END;

                                slicrec.numberofmonthslicensed   :=
                                    CASE t_seasonal WHEN 'Y' THEN licrec.numberofmonthslicensed ELSE NULL END;
                            EXCEPTION
                                WHEN NO_DATA_FOUND THEN
                                    NULL;
                            END;

                            slicrec.licensefeescheduleid   := NULL;
                            slicrec.feeamount              := 0;
                            slicrec.ltcode                 := NVL(rec.secondarytype, licrec.ltcode);
                            slicrec.ltcount                := NVL(rec.secondarycount, licrec.ltcount);
                            slicrec.feetype                := 'S';


                            sitespecific.pkg_fees.getltfeeamount(
                                a_jobid     => slicrec.jobid,
                                a_effectivedate => slicrec.effectivedate,
                                a_feeactivitytype => 'REN',
                                a_otherfeecode => NULL,
                                a_ltcode    => slicrec.ltcode,
                                a_gallonagerange => NULL,  --slicrec.GallonageRange,
                                a_additionalmilliongallons => NULL,  --slicrec.AdditionalMillionGallons,
                                a_numberofmonthslicensed => slicrec.numberofmonthslicensed,
                                a_populationrange => slicrec.populationrange,
                                a_tier      => TO_CHAR(NULL),
                                a_feetype   => slicrec.feetype,
                                a_ltcount   => slicrec.ltcount,
                                a_asofdate  => TO_DATE(NULL),
                                a_feeamount => slicrec.secondaryamount,
                                a_licensefeescheduleid => slicrec.licensefeescheduleid);

                            slicrec.scheduleorig           :=
                                api.pkg_columnquery.VALUE(slicrec.licensefeescheduleid, 'originalsecondaryfee');
                            slicrec.scheduleadjustedorig   := slicrec.scheduleorig * NVL(slicrec.ltcount, 1);

                            get_surcharges(a_amount    => slicrec.secondaryamount,
                                           a_transactiondate => slicrec.effectivedate,
                                           a_feescheduleobjectid => slicrec.licensefeescheduleid,
                                           a_ltcount   => slicrec.ltcount,
                                           a_originalfee => slicrec.originalfee,
                                           a_ab_surcharge => slicrec.abfee,
                                           a_dmv_surcharge_amt => slicrec.dmvfee,
                                           a_bpu_fee   => slicrec.bpufee);

                            INSERT INTO fn_forecast_rpt
                            VALUES slicrec;
                        END LOOP;
                    END IF;
                END LOOP;
            END LOOP;

            DBMS_OUTPUT.put_line(   'Processed: '
                                 || t_processed);
        END;
    END;
    -- ************************************************************************
    --  Main process
    -- ************************************************************************
BEGIN
    DECLARE
        lv_status_msg   VARCHAR2(8096);
        lblob_csv       BLOB;
        ld_start        DATE;
        ld_end          DATE;
        lv_csv_row      VARCHAR2(8096);
        lv_report_name  VARCHAR(150) := p_parms.get_value('REPORT_NAME');

    BEGIN
        DBMS_LOB.createtemporary(lblob_csv, TRUE, DBMS_LOB.call);
        
        IF (p_parms.get_value('REPORT_DATE') IS NOT NULL) THEN
            ld_start   := trunc(TO_DATE(p_parms.get_value('REPORT_DATE'), 'MM/DD/YYYY'), 'mm');
            ld_end     := last_day(ld_start);
            p_parms.upd_value('START_DATE', TO_CHAR(ld_start, 'MM/DD/YYYY'));
        else
            ld_start   := TO_DATE(p_parms.get_value('START_DATE'), 'MM/DD/YYYY');
            ld_end     := TO_DATE(p_parms.get_value('END_DATE'), 'MM/DD/YYYY');
        end if;
        p_parms.upd_value('REPORT_DATE', TO_CHAR(SYSDATE, 'MM/DD/YYYY HH:MI PM'));

        -- adjust to previous month to get to expiration date, date entered is first renewal date
        ld_start := add_months(ld_start, -1);
        ld_end := add_months(ld_end, -1);
        
        updatereporttable(a_start_date => ld_start, a_end_date => ld_end);

        if (upper(lv_report_name) = 'EARNINGS FORECAST') then
        FOR rec IN (SELECT      '"' ||   ltcode
                                || '",'
                                || originalfee
                                || ','
                                || abfee
                                || ','
                                || dmvfee
                                || ','
                                || bpufee
                                || ','
                                || to_char(feeamount
                              + secondaryamount
                              + branchamount)
                           || ','
                           || primarycount
                           || ','
                           || secondarycount
                           || ','
                           || branchcount
                           || ','
                           || feeamount
                           || ','
                           || secondaryamount
                           || ','
                           || branchamount
                           || CHR(13)
                           || CHR(10)
                               info
                      FROM (  SELECT ltcode,
                                     COUNT(CASE WHEN feetype = 'P' THEN ltcode ELSE NULL END) primarycount,
                                     SUM(CASE WHEN feetype = 'S' THEN ltcount ELSE 0 END)   secondarycount,
                                     COUNT(CASE WHEN feetype = 'B' THEN ltcode ELSE NULL END) branchcount,
                                     SUM(CASE WHEN feetype = 'P' THEN feeamount ELSE 0 END) feeamount,
                                     SUM(secondaryamount)                                   secondaryamount,
                                     SUM(CASE WHEN feetype = 'B' THEN feeamount ELSE 0 END) branchamount,
                                     SUM(originalfee)                                       originalfee,
                                     SUM(abfee)                                             abfee,
                                     SUM(dmvfee)                                            dmvfee,
                                     SUM(bpufee)                                            bpufee
                                FROM fn_forecast_rpt rpt
                            GROUP BY ltcode
                            ORDER BY rpt.ltcode))
        LOOP
            lv_csv_row   := rec.info;

            DBMS_LOB.append(lblob_csv, UTL_RAW.cast_to_raw(lv_csv_row));
        END LOOP;
        else
        FOR rec IN (SELECT JOBID                   
                           || ','
                           || LICENSENUMBER           
                           || ',"'
                           || EFFECTIVEDATE           
                           || '","'
                           || LTCODE                  
                           || '","'
                           || GALLONAGERANGE          
                           || '",'
                           || ADDITIONALMILLIONGALLONS
                           || ','
                           || NUMBEROFMONTHSLICENSED  
                           || ',"'
                           || POPULATIONRANGE         
                           || '","'
                           || FEETYPE                 
                           || '",'
                           || LTCOUNT                 
                           || ','
                           || LICENSEFEESCHEDULEID    
                           || ','
                           || FEEAMOUNT               
                           || ','
                           || SCHEDULEORIG            
                           || ','
                           || SCHEDULEADJUSTEDORIG    
                           || ','
                           || SECONDARYAMOUNT         
                           || ','
                           || ORIGINALFEE             
                           || ','
                           || ABFEE                   
                           || ','
                           || DMVFEE                  
                            || ','
                            || BPUFEE                  
                           || CHR(13)
                           || CHR(10) info
                                FROM fn_forecast_rpt rpt
                            ORDER BY rpt.ltcode)
        LOOP
            lv_csv_row   := rec.info;

            DBMS_LOB.append(lblob_csv, UTL_RAW.cast_to_raw(lv_csv_row));
        END LOOP;

        end if;
        commit;
        RETURN lblob_csv;
    EXCEPTION
        WHEN OTHERS THEN
            rqs_utils.LOG(p_log_type  => 'E',
                          p_job_id    => p_parms.get_value('JOB_ID'),
                          p_seq       => p_parms.get_value('SEQ'),
                          p_source    => 'EarnedForecast',
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
END;
/
