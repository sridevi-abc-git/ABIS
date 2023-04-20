CREATE OR REPLACE PROCEDURE ABC.applicationfeecalc(a_objectid      udt_id,
                                                   --                               a_AsOfDate date,
                                                   a_jobid         udt_id)
IS
    -- **************************************************************************
    -- File:        APPLICATIONFEECALC.PRC
    -- Author:      CX
    --
    -- $Rev$
    -- $Date$
    -- Last Changed By:  $Author$
    --
    -- Description:
    --
    --
    -- History:
    -----------------------------------------------------------------------------
    --    Date                  Comment
    -- 08/20/2018 TJL         Initial Check-in
    -- **************************************************************************

    TYPE feeactivity IS VARRAY(100) OF VARCHAR2(3);

    t_feeactivity        feeactivity := feeactivity();
    t_index              INTEGER;

    t_addprimarylt       VARCHAR2(1);
    t_addrenfee          VARCHAR2(1);
    t_applicationtype    VARCHAR2(40);
    t_createfee          VARCHAR2(1);
    t_createsfee         VARCHAR2(1);
    t_description        VARCHAR2(250);
    t_droppartner        VARCHAR2(1);
    t_feeid              udt_id;
    t_feeobjectid        udt_id;
    t_fidtransfer        VARCHAR2(1);
    t_glaccountid        udt_id;
    t_issuedate          DATE;
    t_ltexchange         VARCHAR2(1);
    t_lttype             VARCHAR2(1);
    t_membershiptrans    VARCHAR2(1);
    t_multiple           VARCHAR2(1);
    t_otherfeecode       VARCHAR2(50);
    t_pertoper           VARCHAR2(1);
    t_pfeeamount         NUMBER;
    t_pfeescheduleid     udt_id;
    t_populationrange    VARCHAR2(100);
    t_prmtoprm           VARCHAR2(1);
    t_relid              udt_id;
    t_s238268            VARCHAR2(1);
    t_sfeeamount         NUMBER;
    t_sfeescheduleid     udt_id;
    t_stocktransfer      VARCHAR2(1);
    t_transactionid      udt_id;
    t_transactionobjid   udt_id;
BEGIN
    -- Set t_ApplicationType to j_Application.ApplicationType
    t_applicationtype   :=
        api.pkg_columnquery.VALUE(a_jobid, 'ApplicationType');

    -- Set t_PerToPer to j_Application.PersonToPerson
    t_pertoper          := api.pkg_columnquery.VALUE(a_jobid, 'PersonToPerson');

    -- Set t_PrmToPrm to j_Application.PremiseToPremise
    t_prmtoprm          := api.pkg_columnquery.VALUE(a_jobid, 'PremiseToPremise');

    -- Set t_FidTransfer to j_Application.FiduciaryTransfer
    t_fidtransfer       :=
        api.pkg_columnquery.VALUE(a_jobid, 'FiduciaryTransfer');

    -- Set t_AddPrimaryLT to j_Application.AddPrimaryLicenseType
    t_addprimarylt      :=
        api.pkg_columnquery.VALUE(a_jobid, 'AddPrimaryLicenseType');

    -- Set t_LTExchange to j_Application.LicenseTypeExchange
    t_ltexchange        :=
        api.pkg_columnquery.VALUE(a_jobid, 'LicenseTypeExchange');

    -- Set t_DropPartner to j_Application.DropPartner
    t_droppartner       := api.pkg_columnquery.VALUE(a_jobid, 'DropPartner');

    -- Set t_StockTransfer to j_Application.StockTransfer
    t_stocktransfer     := api.pkg_columnquery.VALUE(a_jobid, 'StockTransfer');

    -- Set t_MembershipTrans to j_Application.MembershipTransfer
    t_membershiptrans   :=
        api.pkg_columnquery.VALUE(a_jobid, 'MembershipTransfer');

    -- Set t_Multiple to j_Application.MultipleStockMembershipTrans
    t_multiple          :=
        api.pkg_columnquery.VALUE(a_jobid, 'MultipleStockMembershipTrans');

    -- Set t_S238268 to j_Application.Section238268
    t_s238268           :=
        api.pkg_columnquery.VALUE(a_jobid, 'Section238268');

    -- If this is being run on the Issue License process
    IF api.pkg_columnquery.VALUE(a_objectid, 'ObjectDefName') =
       'p_IssueLicense' THEN
        -- Then set t_ReadyToIssueDate to p_IssueLicense.ReadyToIssueDate
        t_issuedate   :=
            api.pkg_columnquery.datevalue(a_objectid, 'ReadyToIssueDate');
    -- Else
    ELSE
        -- Set t_EstimatedIssueDate to j_Application.EstimatedIssueDate
        t_issuedate   :=
            api.pkg_columnquery.datevalue(a_jobid, 'EstimatedIssueDate');
    -- End If
    END IF;

    -- Set t_CreateFee initial value to 'Y'
    t_createfee         := 'Y';

    -- Set t_CreateSFee initial value to 'Y'
    t_createsfee        := 'Y';

    -- Set t_AddRenFee initial value to 'N'
    t_addrenfee         := 'N';

    -- Then set t_PopulationRange from the Premises Address
    BEGIN
        -- If the Application is not a change
        IF (t_applicationtype = 'Original')
        OR (t_applicationtype = 'Transfer'
        AND t_prmtoprm = 'Y') THEN
            -- then get the premises address Population Range
            SELECT addr.populationrange
              INTO t_populationrange
              FROM query.j_application  a
                   JOIN query.r_applicationpremaddr apa
                       ON a.jobid = apa.applicationjobid
                   JOIN query.o_address addr
                       ON addr.objectid = apa.addressobjectid
             WHERE a.jobid = a_jobid;
        -- Else if the Application is a change
        ELSIF t_applicationtype = 'Change' THEN
            -- Get the Population Range off the premises address on the related License
            SELECT ad.populationrange
              INTO t_populationrange
              FROM query.j_application  a
                   JOIN query.r_applicationlicense al
                       ON al.applicationjobid = a.jobid
                   JOIN query.j_license l ON l.jobid = al.licensejobid
                   JOIN query.r_licenseaddrpremises lap
                       ON lap.licensejobid = l.jobid
                   JOIN query.o_address ad
                       ON ad.objectid = lap.premisesobjectid
             WHERE a.jobid = a_jobid;
        -- Else if the Application is a transfer, but is NOT a Prem to Prem
        ELSIF t_applicationtype = 'Transfer'
          AND t_prmtoprm != 'Y' THEN
            -- then get the Population Range off the premises address on the License Transferring From
            SELECT ad.populationrange
              INTO t_populationrange
              FROM query.j_application  a
                   JOIN query.r_applicationlicensetransfer alt
                       ON alt.apptransferredtoobjectid = a.jobid
                   JOIN query.j_license l
                       ON l.jobid = alt.licensetransferredfromobjectid
                   JOIN query.r_licenseaddrpremises lap
                       ON lap.licensejobid = l.jobid
                   JOIN query.o_address ad
                       ON ad.objectid = lap.premisesobjectid
             WHERE a.jobid = a_jobid;
        -- End If
        END IF;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            api.pkg_errors.raiseerror(
                -20000,
                   'CA City related to the Premises Address related to the Application '
                || a_jobid
                || ', or related to the License related to this Application, cannot be found.');
    END;

    -- For LTs
    -- Get LT Code
    -- Get GallonageRange
    -- Get NumberOfMonthsLicensed
    -- Get IsBranch (If MasterLicenseType is not null)
    -- Get AddRenewalFee
    -- Get ManualFee LOOP:
    FOR x
        IN (SELECT plt.objectid
                       pltobjectid,
                   plt.licensetypecode,
                   ltc.gallonageapplies,
                   plt.gallonagerange,
                   NVL(plt.additionalmilliongallons, 0)
                       additionalmilliongallons,
                   NVL(plt.primarycount, 0)
                       primarycount,
                   plt.numberofmonthslicensedfeecode,
                   plt.isbranchs
                       isbranch, /* changed the select to the currect from case when plt.MasterLicenseType is not null then 'Y' else 'N' end*/
                   plt.conda,
                   plt.istransferred,
                   plt.addrenewalfee,
                   plt.manualfee,
                   plt.prioritydrawlicensetype,
                   ltc.populationapplies,
                   ltc.seasonalmonthsapply,
                   plt.secondaryltobjectids,
                   ltc.prioritydrawlicensetype
                       pdlt
              FROM query.r_appprimarylicensetype  aplt
                   JOIN query.o_primarylicensetype plt
                       ON aplt.licensetypeobjectid = plt.objectid
                   JOIN query.r_priltltcatprimary pltltc
                       ON plt.objectid = pltltc.primarylicensetypeobjectid
                   JOIN query.o_licensetypecategory ltc
                       ON pltltc.licensetypecategoryobjectid = ltc.objectid
             WHERE aplt.applicationobjectid = a_jobid)
    LOOP
        --******************************************************************
        --  12/29/2017 TJL
        --  new logic for creating fee codes
        --******************************************************************
        -- Set t_index to 0
        t_index   := 0;

        CASE t_applicationtype
            WHEN 'Original' THEN
                IF (x.isbranch = 'Y') THEN
                    t_index                  := t_index + 1;
                    t_feeactivity.EXTEND;
                    t_feeactivity(t_index)   := 'DOR';

                    -- if the LT is an 03, then add the ORI fee code
                    IF x.licensetypecode = '03' THEN
                        t_index                  := t_index + 1;
                        t_feeactivity.EXTEND;
                        t_feeactivity(t_index)   := 'ORI';
                    END IF;
                --                        END IF;
                ELSE                                           -- branch = 'N'
                    -- 01/08/2018  TJL   11172 and 14182
                    IF (x.prioritydrawlicensetype = 'N') THEN
                        -- Set t_FeeActivityType to 'ORI'
                        t_index                  := t_index + 1;
                        t_feeactivity.EXTEND;
                        t_feeactivity(t_index)   := 'ORI';
                    END IF;

                    -- 01/08/2018  TJL   11172 and 14182
                    -- No ANN fee if the LT = 80/67
                    --  this is handled by not having ANN fee records for 67 and 80
                    t_index                  := t_index + 1;
                    t_feeactivity.EXTEND;
                    t_feeactivity(t_index)   := 'ANN';

                    IF x.licensetypecode IN ('80', '67') THEN
                        -- Set t_FeeActivityType to 'DOR'
                        t_index                  := t_index + 1;
                        t_feeactivity.EXTEND;
                        t_feeactivity(t_index)   := 'DOR';
                    END IF;
                END IF;
            WHEN 'Transfer' THEN
                IF t_pertoper = 'Y' THEN
                    t_index                  := t_index + 1;
                    t_feeactivity.EXTEND;
                    t_feeactivity(t_index)   := 'PER';

                    IF (x.licensetypecode NOT IN ('80', '67'))
                   AND x.isbranch != 'Y' THEN
                        -- Set t_FeeActivityType to 'ANN'
                        t_index                  := t_index + 1;
                        t_feeactivity.EXTEND;
                        t_feeactivity(t_index)   := 'ANN';
                    ELSE
                        t_index                  := t_index + 1;
                        t_feeactivity.EXTEND;
                        t_feeactivity(t_index)   := 'DOR';
                    END IF;
                END IF;

                IF t_prmtoprm = 'Y' THEN
                    t_index                  := t_index + 1;
                    t_feeactivity.EXTEND;
                    t_feeactivity(t_index)   := 'PRM';
                END IF;

                IF t_fidtransfer = 'Y' THEN
                    t_index                  := t_index + 1;
                    t_feeactivity.EXTEND;
                    t_feeactivity(t_index)   := 'FID';
                END IF;

                IF t_droppartner = 'Y' THEN
                    t_index                  := t_index + 1;
                    t_feeactivity.EXTEND;
                    t_feeactivity(t_index)   := 'DPR';
                END IF;

                IF t_ltexchange = 'Y' THEN
                    t_index                  := t_index + 1;
                    t_feeactivity.EXTEND;
                    t_feeactivity(t_index)   := 'EXC';
                END IF;
            WHEN 'Change' THEN
                IF (t_addprimarylt = 'Y') THEN
                    t_index                  := t_index + 1;
                    t_feeactivity.EXTEND;
                    t_feeactivity(t_index)   := 'ORI';

                    t_index                  := t_index + 1;
                    t_feeactivity.EXTEND;
                    t_feeactivity(t_index)   := 'ANN';
                END IF;

                IF (t_stocktransfer = 'Y') THEN
                    t_index   := t_index + 1;
                    t_feeactivity.EXTEND;
                    t_feeactivity(t_index)   :=
                        CASE t_multiple WHEN 'N' THEN 'STK' ELSE 'STM' END;
                END IF;

                IF (t_membershiptrans = 'Y') THEN
                    t_index   := t_index + 1;
                    t_feeactivity.EXTEND;
                    t_feeactivity(t_index)   :=
                        CASE t_multiple WHEN 'N' THEN 'MBR' ELSE 'MBM' END;
                END IF;

                IF t_ltexchange = 'Y' THEN
                    t_index                  := t_index + 1;
                    t_feeactivity.EXTEND;
                    t_feeactivity(t_index)   := 'EXC';
                END IF;
            ELSE
                CONTINUE;
        END CASE;

        IF x.addrenewalfee = 'Y' THEN
            t_index                  := t_index + 1;
            t_feeactivity.EXTEND;
            t_feeactivity(t_index)   := 'REN';
            t_addrenfee              := 'Y';
        END IF;

        -- For each Applicable Fee Activity Type LOOP:
        FOR c IN 1 .. t_feeactivity.COUNT
        LOOP
            -- If FeeActivity is ORI abd LT is 47, remove Population Range
            /*if x.LicenseTypeCode = 47 and t_FeeActivity(c) = 'ORI' then
            t_PopulationRange := null;
            end if;*/

            -- Get the Other Fee Code if this is an ORI 47...
            IF x.licensetypecode = 47
           AND x.conda = 'Y'
           AND t_feeactivity(c) = 'ORI' THEN
                t_otherfeecode   := 'S23824';
            ELSIF x.licensetypecode = 47
              AND t_s238268 = 'Y'
              AND t_feeactivity(c) = 'ORI' THEN
                t_otherfeecode   := 'S23826.8';
            ELSE
                t_otherfeecode   := NULL;
            END IF;

            -- If IsBranch = 'Y'
            IF x.isbranch = 'Y' -- Then t_LTType := 'B'
                                THEN
                t_lttype   := 'B';
            -- Else
            ELSE
                -- Then t_LTType := 'P'
                t_lttype   := 'P';
            -- End If
            END IF;

            -- Get the GL Account Id for the Fee Activity Type
            BEGIN
                SELECT gl.glaccountid
                  INTO t_glaccountid
                  FROM api.glaccounts gl
                 WHERE gl.glaccount = t_feeactivity(c);
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    api.pkg_errors.raiseerror(
                        -20000,
                           'No GL Account exists for Fee Activity '
                        || t_feeactivity(c));
            END;

            -- Pass the fee amount into t_PFeeAmount, and the Fee Schedule Id into t_FeeScheduleId
            sitespecific.pkg_fees.getltfeeamount(
                a_jobid,
                t_issuedate,
                t_feeactivity(c),
                t_otherfeecode,
                x.licensetypecode,
                CASE
                    WHEN (x.pdlt = 'Y'
                       OR x.licensetypecode IN ('48', '72'))
                     AND -- Added py Pawan on 12/30/2016 to implement new LT 72
                         t_feeactivity(c) = 'ORI' THEN
                        NULL
                    WHEN x.gallonageapplies = 'Y'
                     AND t_feeactivity(c) != 'MOD' THEN
                        x.gallonagerange
                    ELSE
                        NULL
                END,
                x.additionalmilliongallons,
                CASE
                    WHEN (x.pdlt = 'Y'
                       OR x.licensetypecode IN ('48', '72'))
                     AND -- Added py Pawan on 12/30/2016 to implement new LT 72
                         t_feeactivity(c) = 'ORI' THEN
                        NULL
                    WHEN x.seasonalmonthsapply = 'Y' THEN
                        x.numberofmonthslicensedfeecode
                    ELSE
                        NULL
                END,
                CASE
                    WHEN (x.pdlt = 'Y'
                       OR x.licensetypecode IN ('48', '72'))
                     AND -- Added py Pawan on 12/30/2016 to implement new LT 72
                         t_feeactivity(c) = 'ORI' THEN
                        NULL
                    WHEN x.populationapplies = 'Y' THEN
                        t_populationrange
                    ELSE
                        NULL
                END,
                t_lttype,
                x.primarycount,
                NULL,
                t_pfeeamount,
                t_pfeescheduleid);

            -- For SecondaryLTs
            -- Get LT Code
            -- Get LT Count LOOP:
            FOR z
                IN (SELECT ltc.gallonageapplies,
                           ltc.licensetypecode,
                           sltc.licensetypecount,
                           ltc.populationapplies,
                           ltc.seasonalmonthsapply,
                           sltc.istransferred
                      FROM query.r_priltltcatsecondary  sltc
                           JOIN query.o_licensetypecategory ltc
                               ON sltc.licensetypecategoryobjectid =
                                  ltc.objectid
                     WHERE sltc.primarylicensetypeobjectid = x.pltobjectid)
            LOOP
                -- t_LTType := 'S'
                t_lttype   := 'S';

                -- then Pass the fee amount into t_SFeeAmount, and the Fee Schedule Id into t_FeeScheduleId
                sitespecific.pkg_fees.getltfeeamount(
                    a_jobid,
                    t_issuedate,
                    t_feeactivity(c),
                    NULL,
                    z.licensetypecode,
                    NULL,    -- Gallonage Range does not apply to Secondaries.
                    NULL,
                    CASE
                        WHEN (x.pdlt = 'Y'
                           OR x.licensetypecode IN ('48', '72'))
                         AND -- Added py Pawan on 12/30/2016 to implement new LT 72
                             t_feeactivity(c) = 'ORI' THEN
                            NULL
                        WHEN z.seasonalmonthsapply = 'Y' THEN
                            x.numberofmonthslicensedfeecode
                        ELSE
                            NULL
                    END,
                    CASE
                        WHEN (x.pdlt = 'Y'
                           OR x.licensetypecode IN ('48', '72'))
                         AND -- Added py Pawan on 12/30/2016 to implement new LT 72
                             t_feeactivity(c) = 'ORI' THEN
                            NULL
                        WHEN z.populationapplies = 'Y' THEN
                            t_populationrange
                        WHEN x.licensetypecode IN (50, 51, 52)
                         AND z.licensetypecode = 58 THEN
                            t_populationrange
                        ELSE
                            NULL
                    END,
                    t_lttype,
                    z.licensetypecount,
                    NULL,
                    t_sfeeamount,
                    t_sfeescheduleid);

                -- if the Fee Activity Code is either ORI or ANN or the SLT is Transferred and then don't create the secondary fee.
                IF (t_feeactivity(c) = 'ORI')
                OR (z.istransferred = 'N'
                AND x.istransferred = 'Y')
                OR (t_feeactivity(c) = 'ANN' /*and z.LicenseTypeCode <> x.LicenseTypeCode*/
                AND z.istransferred = 'N') THEN
                    NULL;
                ELSE
                    -- If Secondary LT Code = Primary LT Code
                    IF z.licensetypecode = x.licensetypecode THEN
                        -- Add the Primary Lt Fee Amount to the Secondary Fee Amount
                        t_sfeeamount    := t_sfeeamount + t_pfeeamount;

                        -- Get the Description for the fee
                        t_description   :=
                            api.pkg_columnquery.VALUE(t_pfeescheduleid,
                                                      'ProcedureDescription');

                        -- Set t_CreateFee to 'N' so that this fee will not be adjusted/re-created in some form later in the procedure
                        t_createfee     := 'N';

                        -- Check for Existing Fees and Adjust ones that need it
                        sitespecific.pkg_fees.checkexistingfees( --' - Primary, '|| -- out dated 2009_3_19
                            'N',
                            t_description,
                            x.addrenewalfee,
                            t_feeactivity(c),
                            NULL,
                            t_sfeeamount,
                            t_sfeescheduleid,
                            CASE
                                WHEN z.gallonageapplies = 'Y' THEN
                                    x.gallonagerange
                                ELSE
                                    NULL
                            END,
                            t_glaccountid,
                            'Y',
                            'Y',
                            a_jobid,
                            z.licensetypecode,
                            z.licensetypecount,
                            CASE
                                WHEN z.seasonalmonthsapply = 'Y' THEN
                                    x.numberofmonthslicensedfeecode
                                ELSE
                                    NULL
                            END,
                            CASE
                                WHEN z.populationapplies = 'Y' THEN
                                    t_populationrange
                                WHEN x.licensetypecode IN (50, 51, 52)
                                 AND z.licensetypecode = 58 THEN
                                    t_populationrange
                                ELSE
                                    NULL
                            END,
                            x.secondaryltobjectids,
                            t_createsfee,
                            t_feeid);

                        IF t_createsfee = 'Y'
                       AND t_sfeeamount >= 0 THEN
                            -- CreateFees. This will pass the api Fee Id into t_FeeId, and the POSSE Fee ObjectId into t_FeeObjectId
                            sitespecific.pkg_fees.newfee(t_feeid,
                                                         t_sfeeamount,
                                                         -- z.LicenseTypeCode||' - Primary, '|| -- out dated 2009_3_19
                                                         t_description,
                                                         t_glaccountid,
                                                         a_jobid,
                                                         NULL,
                                                         t_feeobjectid);
                            -- Relate Fee to Fee Schedule
                            t_relid        :=
                                api.pkg_relationshipupdate.new(
                                    api.pkg_configquery.endpointidforname(
                                        'o_Fee',
                                        'LicenseFeeSchedule'),
                                    t_feeobjectid,
                                    t_pfeescheduleid);
                            -- Set the relationship detail MasterLT
                            api.pkg_columnupdate.setvalue(t_relid,
                                                          'MasterLT',
                                                          x.licensetypecode);
                            -- Set the relationship detail IsMaster 'Y'
                            api.pkg_columnupdate.setvalue(t_relid,
                                                          'IsMaster',
                                                          'Y');
                            -- Set the relationship detail SecondaryCount to the count of secondary LTs
                            api.pkg_columnupdate.setvalue(t_relid,
                                                          'SecondaryCount',
                                                          z.licensetypecount);

                            -- t_CreateFee := 'N'
                            t_createsfee   := 'N';

                            -- Set the Quantity on the Fee Object
                            api.pkg_columnupdate.setvalue(t_feeobjectid,
                                                          'Quantity',
                                                          z.licensetypecount);
                        -- End If
                        END IF;
                    -- Else
                    ELSIF t_feeactivity(c) <> 'ANN' THEN
                        -- Get the Description for the fee
                        t_description   :=
                            api.pkg_columnquery.VALUE(t_sfeescheduleid,
                                                      'ProcedureDescription');

                        -- Check for Existing Fees and Adjust ones that need it
                        sitespecific.pkg_fees.checkexistingfees( --' - Secondary, '|| --out dated 2009_3_19
                            'N',
                            t_description,
                            x.addrenewalfee,
                            t_feeactivity(c),
                            NULL,
                            t_sfeeamount,
                            t_sfeescheduleid,
                            CASE
                                WHEN z.gallonageapplies = 'Y' THEN
                                    x.gallonagerange
                                ELSE
                                    NULL
                            END,
                            t_glaccountid,
                            'Y',
                            'N',
                            a_jobid,
                            z.licensetypecode,
                            z.licensetypecount,
                            CASE
                                WHEN z.seasonalmonthsapply = 'Y' THEN
                                    x.numberofmonthslicensedfeecode
                                ELSE
                                    NULL
                            END,
                            CASE
                                WHEN z.populationapplies = 'Y' THEN
                                    t_populationrange
                                WHEN x.licensetypecode IN (50, 51, 52)
                                 AND z.licensetypecode = 58 THEN
                                    t_populationrange
                                ELSE
                                    NULL
                            END,
                            x.secondaryltobjectids,
                            t_createsfee,
                            t_feeid);

                        IF t_createsfee = 'Y'
                       AND t_sfeeamount >= 0 THEN
                            -- CreateFees. This will pass the api Fee Id into t_FeeId, and the POSSE Fee ObjectId into t_FeeObjectId
                            sitespecific.pkg_fees.newfee(t_feeid,
                                                         t_sfeeamount,
                                                         --z.LicenseTypeCode||' - Secondary, ' || -- out dated 2009_3_19
                                                         t_description,
                                                         t_glaccountid,
                                                         a_jobid,
                                                         NULL,
                                                         t_feeobjectid);

                            -- Relate Fee to Fee Schedule
                            t_relid   :=
                                api.pkg_relationshipupdate.new(
                                    api.pkg_configquery.endpointidforname(
                                        'o_Fee',
                                        'LicenseFeeSchedule'),
                                    t_feeobjectid,
                                    t_sfeescheduleid);

                            -- Set the relationship detail MasterLT
                            api.pkg_columnupdate.setvalue(t_relid,
                                                          'MasterLT',
                                                          x.licensetypecode);
                            -- Set the relationship detail IsMaster to 'N'
                            api.pkg_columnupdate.setvalue(t_relid,
                                                          'IsMaster',
                                                          'N');
                            -- Set the relationship detail SecondaryCount to the count of secondary LTs
                            api.pkg_columnupdate.setvalue(t_relid,
                                                          'SecondaryCount',
                                                          z.licensetypecount);

                            -- Set the Quantity on the Fee Object
                            api.pkg_columnupdate.setvalue(t_feeobjectid,
                                                          'Quantity',
                                                          z.licensetypecount);
                        -- End If
                        END IF;
                    -- End If
                    END IF;
                -- End if not in ORI or ANN
                END IF;
            -- End Secondary LT Loop
            END LOOP;

            -- If t_CreateFee = 'Y'
            IF t_createfee = 'Y' THEN
                -- Get the Description for the fee
                t_description   :=
                    api.pkg_columnquery.VALUE(t_pfeescheduleid,
                                              'ProcedureDescription');

                -- Check for Existing Fees and Adjust ones that need it
                sitespecific.pkg_fees.checkexistingfees( --' - Primary, '|| --out dated 2009_3_19
                    'N',
                    t_description,
                    x.addrenewalfee,
                    t_feeactivity(c),
                    t_otherfeecode,
                    t_pfeeamount,
                    t_pfeescheduleid,
                    CASE
                        WHEN x.gallonageapplies = 'Y' THEN x.gallonagerange
                        ELSE NULL
                    END,
                    t_glaccountid,
                    'N',
                    CASE WHEN x.isbranch = 'Y' THEN 'N' ELSE 'Y' END,
                    --'Y', --IsMaster
                    a_jobid,
                    x.licensetypecode,
                    CASE
                        WHEN x.isbranch = 'Y' THEN 1
                        ELSE x.additionalmilliongallons + x.primarycount
                    END,
                    --x.AdditionalMillionGallons + x.primarycount, --LTCount
                    CASE
                        WHEN x.seasonalmonthsapply = 'Y' THEN
                            x.numberofmonthslicensedfeecode
                        ELSE
                            NULL
                    END,
                    CASE
                        WHEN x.licensetypecode = 47
                         AND t_feeactivity(c) = 'ORI' THEN
                            NULL
                        WHEN x.populationapplies = 'Y' THEN
                            t_populationrange
                        ELSE
                            NULL
                    END,
                    x.secondaryltobjectids,
                    t_createfee,
                    t_feeid);

                IF t_createfee = 'Y'
               AND t_pfeeamount >= 0 THEN
                    -- CreateFees. This will pass the api Fee Id into t_FeeId, and the POSSE Fee ObjectId into t_FeeObjectId
                    sitespecific.pkg_fees.newfee(t_feeid,
                                                 t_pfeeamount,
                                                 --x.LicenseTypeCode||' - Primary, '|| -- out dated 2009_3_19
                                                 t_description,
                                                 t_glaccountid,
                                                 a_jobid,
                                                 NULL,
                                                 t_feeobjectid);

                    -- Relate Fee to Fee Schedule
                    t_relid   :=
                        api.pkg_relationshipupdate.new(
                            api.pkg_configquery.endpointidforname(
                                'o_Fee',
                                'LicenseFeeSchedule'),
                            t_feeobjectid,
                            t_pfeescheduleid);

                    -- Set the relationship detail MasterLT to the License Type Code
                    api.pkg_columnupdate.setvalue(t_relid,
                                                  'MasterLT',
                                                  x.licensetypecode);

                    -- Set the relationship detail IsMaster to 'Y'
                    api.pkg_columnupdate.setvalue(
                        t_relid,
                        'IsMaster',
                        CASE WHEN x.isbranch = 'Y' THEN 'N' ELSE 'Y' END);

                    -- Set the relationship detail SecondaryCount to the count of secondary LTs
                    api.pkg_columnupdate.setvalue(
                        t_relid,
                        'SecondaryCount',
                        CASE
                            WHEN x.isbranch = 'Y' THEN 1
                            ELSE x.additionalmilliongallons + x.primarycount
                        END);
                -- End If
                END IF;
            -- End If
            END IF;

            -- If t_CreateFee = 'N'
            IF t_createfee = 'N' THEN
                -- t_CreateFee := 'Y'
                t_createfee   := 'Y';
            -- End If
            END IF;
        -- End Fee Activity Loop
        END LOOP;

        -- Remove the values from t_FeeActivity
        t_feeactivity.TRIM(t_feeactivity.COUNT);

        -- If this is not a Add Primary LT Change APP
        --If t_AddPrimaryLT != 'Y' then Changed by Pawan related to ticket 2131- add permit license type
        -- Loop through the Secondary LTs and add the DOR fees
        FOR z
            IN (SELECT ltc.gallonageapplies,
                       sltc.istransferred,
                       ltc.licensetypecode,
                       sltc.licensetypecount,
                       ltc.populationapplies,
                       ltc.seasonalmonthsapply
                  FROM query.r_priltltcatsecondary  sltc
                       JOIN query.o_licensetypecategory ltc
                           ON sltc.licensetypecategoryobjectid = ltc.objectid
                 WHERE sltc.primarylicensetypeobjectid = x.pltobjectid)
        LOOP
            IF z.istransferred = 'N'
            OR (z.istransferred = 'Y'
            AND z.licensetypecode <> x.licensetypecode
            AND (t_pertoper = 'Y'--or t_PrmToPrm = 'Y' --BA REMOVED UNDER CMAS III ISSUE 2271
                                 --or t_DropPartner = 'Y'--BA REMOVED UNDER CMAS III ISSUE 2271
                                 --or t_MembershipTrans = 'Y'--BA REMOVED UNDER CMAS III ISSUE 2271
                                 --or t_StockTransfer = 'Y'--BA REMOVED UNDER CMAS III ISSUE 2271
                                 )) THEN
                -- t_LTType := 'S'
                t_lttype   := 'S';

                -- Get the GL Account Id for the DOR Fee Activity Type
                BEGIN
                    SELECT gl.glaccountid
                      INTO t_glaccountid
                      FROM api.glaccounts gl
                     WHERE gl.glaccount = 'DOR';
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        api.pkg_errors.raiseerror(
                            -20000,
                            'No GL Account exists for Fee Activity ' || 'DOR');
                END;

                -- then Pass the fee amount into t_SFeeAmount, and the Fee Schedule Id into t_FeeScheduleId
                sitespecific.pkg_fees.getltfeeamount(
                    a_jobid,
                    t_issuedate,
                    'DOR',
                    NULL,
                    z.licensetypecode,
                    NULL,    -- Gallonage Range does not apply to Secondaries.
                    NULL,
                    CASE
                        WHEN z.seasonalmonthsapply = 'Y' THEN
                            x.numberofmonthslicensedfeecode
                        ELSE
                            NULL
                    END,
                    CASE
                        WHEN z.populationapplies = 'Y' THEN
                            t_populationrange
                        WHEN x.licensetypecode IN (50, 51, 52)
                         AND z.licensetypecode = 58 THEN
                            t_populationrange
                        ELSE
                            NULL
                    END,
                    t_lttype,
                    z.licensetypecount,
                    NULL,
                    t_sfeeamount,
                    t_sfeescheduleid);

                -- Get the Description for the fee
                t_description   :=
                    api.pkg_columnquery.VALUE(t_sfeescheduleid,
                                              'ProcedureDescription');

                -- Check for Existing Fees and Adjust ones that need it
                sitespecific.pkg_fees.checkexistingfees( --' - Secondary, '|| --out dated 2009_3_19
                    'N',
                    t_description,
                    x.addrenewalfee,
                    'DOR',
                    NULL,
                    t_sfeeamount,
                    t_sfeescheduleid,
                    NULL,    -- Gallonage Range does not apply to Secondaries.
                    t_glaccountid,
                    'Y',
                    'N',
                    a_jobid,
                    z.licensetypecode,
                    z.licensetypecount,
                    CASE
                        WHEN z.seasonalmonthsapply = 'Y' THEN
                            x.numberofmonthslicensedfeecode
                        ELSE
                            NULL
                    END,
                    CASE
                        WHEN z.populationapplies = 'Y' THEN
                            t_populationrange
                        WHEN x.licensetypecode IN (50, 51, 52)
                         AND z.licensetypecode = 58 THEN
                            t_populationrange
                        ELSE
                            NULL
                    END,
                    x.secondaryltobjectids,
                    t_createsfee,
                    t_feeid);

                IF t_createsfee = 'Y'
               AND t_sfeeamount >= 0 THEN
                    -- CreateFees. This will pass the api Fee Id into t_FeeId, and the POSSE Fee ObjectId into t_FeeObjectId
                    sitespecific.pkg_fees.newfee(t_feeid,
                                                 t_sfeeamount,
                                                 --z.LicenseTypeCode||' - Secondary, ' || -- out dated 2009_3_19
                                                 t_description,
                                                 t_glaccountid,
                                                 a_jobid,
                                                 NULL,
                                                 t_feeobjectid);
                    -- Relate Fee to Fee Schedule
                    t_relid   :=
                        api.pkg_relationshipupdate.new(
                            api.pkg_configquery.endpointidforname(
                                'o_Fee',
                                'LicenseFeeSchedule'),
                            t_feeobjectid,
                            t_sfeescheduleid);

                    -- Set the relationship detail MasterLT
                    api.pkg_columnupdate.setvalue(t_relid,
                                                  'MasterLT',
                                                  x.licensetypecode);
                    -- Set the relationship detail IsMaster to 'N'
                    api.pkg_columnupdate.setvalue(t_relid, 'IsMaster', 'N');
                    -- Set the relationship detail SecondaryCount to the count of secondary LTs
                    api.pkg_columnupdate.setvalue(t_relid,
                                                  'SecondaryCount',
                                                  z.licensetypecount);

                    -- Set the Quantity on the Fee Object
                    api.pkg_columnupdate.setvalue(t_feeobjectid,
                                                  'Quantity',
                                                  z.licensetypecount);
                -- End If
                END IF;
            END IF;
        -- End Secondary LT Loop
        END LOOP;
    -- End If Not Priority LT
    -- End If;changed by pawan

    -- End Primary LT Loop
    END LOOP;

    -- Loop through the existing fees and adjust ones that do not correspond to an existing LT to 0
    -- RyanL: Changed the select and where clause to be a subselect for performance (PIP Task 8.5)
    FOR c
        IN (SELECT f.feeid
                       feeid,
                   (  f.amount
                    + NVL((SELECT SUM(amount)
                             FROM api.feetransactions ft
                            WHERE ft.feeid = f.feeid),
                          0))
                       totalowing,
                   fs.objectid,
                   fs.licensetypecode
              FROM api.fees  f
                   JOIN sitespecific.feeschedule_t fs
                       ON fs.objectid =
                          sitespecific.pkg_fees.getlicfeeschedulobjid(
                              f.feeid)
             WHERE f.jobid = a_jobid
               AND fs.licensetypecode IS NOT NULL
               AND (  f.amount
                    + NVL((SELECT SUM(amount)
                             FROM api.feetransactions ft
                            WHERE ft.feeid = f.feeid),
                          0)) > 0
               AND (fs.licensetypecode NOT IN
                        (SELECT plt.licensetypecode
                           FROM query.j_application  a
                                JOIN query.r_appprimarylicensetype aplt
                                    ON a.jobid = aplt.applicationobjectid
                                JOIN query.o_primarylicensetype plt
                                    ON aplt.licensetypeobjectid =
                                       plt.objectid
                          WHERE a.jobid = a_jobid)
                AND fs.licensetypecode NOT IN
                        (SELECT ltc.licensetypecode
                           FROM query.j_application  a
                                JOIN query.r_appprimarylicensetype aplt
                                    ON a.jobid = aplt.applicationobjectid
                                JOIN query.o_primarylicensetype plt
                                    ON aplt.licensetypeobjectid =
                                       plt.objectid
                                JOIN query.r_priltltcatsecondary psec
                                    ON plt.objectid =
                                       psec.primarylicensetypeobjectid
                                JOIN query.o_licensetypecategory ltc
                                    ON psec.licensetypecategoryobjectid =
                                       ltc.objectid
                          WHERE a.jobid = a_jobid)))
    LOOP
        t_transactionid   :=
            api.pkg_feeupdate.adjust(
                c.feeid,
                ROUND(-c.totalowing),
                   api.pkg_columnquery.VALUE(c.objectid,
                                             'ProcedureDescription')
                || ', Removed',
                SYSDATE);

        -- Register the adjust transaction object
        t_transactionobjid   :=
            api.pkg_objectupdate.registerexternalobject('o_FeeTransactions',
                                                        t_transactionid);
    -- End Loop
    END LOOP;
END applicationfeecalc;
/
