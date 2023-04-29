CREATE OR REPLACE PACKAGE BODY SITESPECIFIC."PKG_REPORTS"
IS
  -- **************************************************************************
  -- File:        PKG_REPORTS.PKB
  -- Author:      ANDREWP
  --
  -- $Rev: 394 $
  -- $Date: 2020-01-10 09:25:04 -0800 (Fri, 10 Jan 2020) $
  -- Last Changed By:  $Author: TLord $
  --
  -- Description:
  --
  --
  -- History:
  -----------------------------------------------------------------------------
  --    Date                  Comment
  -- 04/01/2018 AP          Package Created
  -- 08/20/2018 TJL         Initial Check-in
  -- 09/11/2018 SSu         v.1 As per Randy, uncommenting below line that was commented in 2014
  -- 09/11/2018 SSu         v.2 As per Randy, Changing signs in BPUAmount calculation from + to -
  -- 10/29/2018 SSu     Updating Allocation logic to clear previous run's data on the same session
  -- 11/01/2018 SSu         WO#16948 Update DMV charge $10 or $5 based on the Fee description C and adding few missing license types into DMV buckets
  -- 01/03/2019 PK          WO16291 Type 21 issued pursuant to Section 23433 BandP Update License to print New condition G
  -- 01/03/2019 SSu     WO#16948 Adding LT 88 into Allocation report DMV calculation
  -- 01/10/2019 TJL         WO 16435 removed the = from test in how seasonal expiration date is caculated in procedure printlicensebatch
  -- 01/14/2019 SSu         WO#17107 License to print new condition M
  -- 01/24/2019 SSu     WO#17178 Issue Type is NULL in the printed license for the secondary licenses
  -- 02/14/2019 TJL         WO 16435 Corrected the efective date that is printed on licenses
  --                          for seasonal secondary license types.
  -- 02/28/2019 SSu     WO#16948 Include dups into badmaster or multimaster count
  -- 06/23/2019 SSu         Added a new proecedure Allocation Report version 2
  -- 07/30/2019 SSu     Fixing AB and DMV calculations in AllocationReport2
  -- 08/17/2019 PK          WO17111 Valid From Date in Pink license Batch
  -- 07/30/2019 SSu     Fixing AB and DMV calculations in AllocationReport2
  -- 08/22/2019 SSu    Fixing AB rounding to 5 issue
  -- 09/28/2019 SSu    2.1 Grouping multiple payments to avoid wrong AB Calculations
  -- 10/29/2019 SSu    2.1 Fee increase change impacts and fixes
  -- 12/10/2019 TJL  20023  Added printing of Section Code at end of Conditions
  -- 10/02/2020 TJL  22891 Added check to pervent divide by 0 error in allocationreport2
  -- 04/28/2023 PK     WO31613 - Additional Condition Code Request Condition E - COND E (Section 24072.3 - type 75 exchange to 47)
  -- **************************************************************************
  /**************************************************************************
  * Global variables declared
  * g_OwnerLineLength is the length in charaters that the Lines in the nested
  * data window for the license report are limited to
  ***************************************************************************/
  g_ownerlinelength INTEGER := 35;
  ---------------------------------------------------------------------------
  -- ChooseInvestigator() -- PUBLIC
  ---------------------------------------------------------------------------
  PROCEDURE chooseinvestigatorlr(
      a_object udt_id,
      a_relationshipdef udt_id,
      a_endpoint udt_endpoint,
      a_searchstring VARCHAR2,
      a_objects OUT udt_objectlist)
  IS
    t_accessgroupid udt_id;
  BEGIN
    a_objects         := api.udt_objectlist();
    IF a_searchstring IS NULL THEN
      --Being used as a Drop Down
      FOR c IN
      (SELECT -- ALL Investigators and LR's
        DISTINCT ag.userid
      FROM api.accessgroups a
      JOIN api.accessgroupusers ag
      ON ag.accessgroupid  = a.accessgroupid
      WHERE a.description IN ('Investigator', 'Licensing Representative')
      )
      LOOP
        a_objects.EXTEND(1);
        a_objects(a_objects.COUNT) := api.udt_object(c.userid);
      END LOOP;
    END IF;
  END chooseinvestigatorlr;
/*------------------------------------------------------------------------
**Function Fee Earned Summary Message
** The purpose of this function is to display an error message on a report
** when certain criteria are met.
**-------------------------------------------------------------------------*/
  FUNCTION feeearnedsummarymessage(
      a_jobid udt_id,
      a_licensetypecode VARCHAR2,
      a_ismaster        VARCHAR2,
      a_secondarycount  NUMBER,
      a_jobtypeid udt_id)
    RETURN NUMBER
  IS
    t_message      NUMBER;
    t_raiseerrflag BOOLEAN;
  BEGIN
    --BEAUTIFY--
    t_raiseerrflag       := TRUE;
    IF a_licensetypecode IS NULL THEN
      t_message          := NULL;
    ELSIF a_ismaster      = 'Y' --when the licensetype is a primary and job is of specific type check that the primary still exists on the job.
      THEN
      -- for each fee where IsMaster = Y check to see that the FS LTCode exists as a primary.
      CASE
      WHEN a_jobtypeid = api.pkg_configquery.objectdefidforname('j_Application') --when app
        THEN
        --then loop through primary apps
        FOR c IN
        (SELECT api.pkg_columnquery.VALUE( rc.toobjectid, 'LicenseTypeCode') ltc
        FROM api.relationships r
        JOIN api.relationships rc
        ON rc.fromobjectid                                               = r.toobjectid
        AND rc.endpointid                                                = api.pkg_configquery.endpointidforname( 'o_PrimaryLicenseType', 'LicTypeCatPrimary')
        WHERE r.fromobjectid                                             = a_jobid
        AND r.endpointid                                                 = api.pkg_configquery.endpointidforname( 'j_Application', 'PrimaryLicenseType')
        AND api.pkg_columnquery.VALUE( rc.toobjectid, 'LicenseTypeCode') = a_licensetypecode
        )
        LOOP
          CASE
          WHEN a_secondarycount > 0 --when there are secondarys of this type make sure that they still exist.
            THEN
            FOR x IN
            (SELECT s.licensetypecount ltcount
            FROM api.relationships r
            JOIN query.r_priltltcatsecondary s
            ON s.primarylicensetypeobjectid = r.toobjectid
            WHERE r.fromobjectid            = a_jobid
            AND r.endpointid                = api.pkg_configquery.endpointidforname( 'j_Application', 'PrimaryLicenseType')
            AND c.ltc                       = api.pkg_columnquery.VALUE( s.licensetypecategoryobjectid, 'LicenseTypeCode')
            )
            LOOP
              IF a_secondarycount = x.ltcount THEN
                t_raiseerrflag   := FALSE;
                EXIT;
              END IF;
            END LOOP;
          ELSE
            IF a_licensetypecode = c.ltc THEN
              t_raiseerrflag    := FALSE;
              EXIT;
            ELSE
              NULL;
            END IF;
          END CASE;
        END LOOP;
        CASE
        WHEN t_raiseerrflag = TRUE THEN
          t_message        := 3;
        ELSE
          NULL;
        END CASE;
      WHEN a_jobtypeid = api.pkg_configquery.objectdefidforname('j_License') THEN
        --loop through prim LicTypes from License
        FOR c IN
        (SELECT api.pkg_columnquery.VALUE( r.toobjectid, 'LicenseTypeCode') ltc
        FROM api.relationships r
        WHERE r.fromobjectid                                            = a_jobid
        AND r.endpointid                                                = api.pkg_configquery.endpointidforname( 'j_License', 'LicenseType')
        AND api.pkg_columnquery.VALUE( r.toobjectid, 'LicenseTypeCode') = a_licensetypecode
        )
        LOOP
          CASE
          WHEN a_secondarycount > 0 --when there are secondarys of this type make sure that they still exist.
            THEN
            FOR x IN
            (SELECT lt.licensetypecount ltcount
            FROM api.relationships r
            JOIN query.r_licensetypeltcatsecondary lt
            ON lt.licensetypejobid = r.toobjectid
            WHERE r.fromobjectid   = a_jobid
            AND r.endpointid       = api.pkg_configquery.endpointidforname( 'j_License', 'LicenseType')
            AND c.ltc              = api.pkg_columnquery.VALUE( lt.licensetypecategoryobjectid, 'LicenseTypeCode')
            )
            LOOP
              IF a_secondarycount = x.ltcount THEN
                t_raiseerrflag   := FALSE;
                EXIT;
              END IF;
            END LOOP;
          ELSE
            IF a_licensetypecode = c.ltc THEN
              t_raiseerrflag    := FALSE;
              EXIT;
            ELSE
              NULL;
            END IF;
          END CASE;
        END LOOP;
        CASE
        WHEN t_raiseerrflag = TRUE THEN
          t_message        := 3;
        ELSE
          NULL;
        END CASE;
      WHEN a_jobtypeid = api.pkg_configquery.objectdefidforname('j_LicenseType') THEN
        --loop through prim LicTypes from LT
        FOR c IN
        (SELECT api.pkg_columnquery.VALUE( r.toobjectid, 'LicenseTypeCode') ltc
        FROM api.relationships r
        WHERE r.fromobjectid = a_jobid
        AND r.endpointid     = api.pkg_configquery.endpointidforname( 'j_LicenseType', 'LicTypeCatPrimary')
        )
        LOOP
          CASE
          WHEN a_secondarycount > 0 --when there are secondarys of this type make sure that they still exist.
            THEN
            FOR x IN
            (SELECT api.pkg_columnquery.VALUE( r.relationshipid, 'LicenseTypeCount') ltcount
            FROM api.relationships r
            WHERE r.fromobjectid = a_jobid
            AND r.endpointid     = api.pkg_configquery.endpointidforname( 'j_LicenseType', 'LicTypeCatSecondary')
            AND c.ltc            = api.pkg_columnquery.VALUE( r.toobjectid, 'LicenseTypeCode')
            )
            LOOP
              IF a_secondarycount = x.ltcount THEN
                t_raiseerrflag   := FALSE;
                EXIT;
              END IF;
            END LOOP;
          ELSE
            IF a_licensetypecode = c.ltc THEN
              t_raiseerrflag    := FALSE;
              EXIT;
            ELSE
              NULL;
            END IF;
          END CASE;
        END LOOP;
        CASE
        WHEN t_raiseerrflag = TRUE THEN
          t_message        := 3;
        ELSE
          NULL;
        END CASE;
      WHEN a_jobtypeid = api.pkg_configquery.objectdefidforname( 'j_OneDayLicense') ---CHECK THE NUMBER OF LTS
        THEN
        --loop through prim LicTypes from ODL
        FOR c IN
        (SELECT api.pkg_columnquery.VALUE( r.toobjectid, 'LicenseTypeCode') ltc
        FROM api.relationships r
        WHERE r.fromobjectid                                            = a_jobid
        AND r.endpointid                                                = api.pkg_configquery.endpointidforname( 'j_OneDayLicense', 'LicenseTypeCategory')
        AND api.pkg_columnquery.VALUE( r.toobjectid, 'LicenseTypeCode') = a_licensetypecode
        )
        LOOP
          CASE
          WHEN a_secondarycount > 0 THEN
            FOR x IN
            (SELECT o.licensetypecount ltcount
            FROM query.r_onedaylicenseltcategory o
            WHERE o.onedaylicensejobid = a_jobid
            AND c.ltc                  = api.pkg_columnquery.VALUE( o.licensetypecategoryobjectid, 'LicenseTypeCode')
            )
            LOOP
              IF a_secondarycount = x.ltcount THEN
                t_raiseerrflag   := FALSE;
                EXIT;
              END IF;
            END LOOP;
          ELSE
            IF a_licensetypecode = c.ltc THEN
              t_raiseerrflag    := FALSE;
              EXIT;
            ELSE
              NULL;
            END IF;
          END CASE;
        END LOOP;
        CASE
        WHEN t_raiseerrflag = TRUE THEN
          t_message        := 3;
        ELSE
          NULL;
        END CASE;
      ELSE
        NULL;
      END CASE;
    ELSIF a_secondarycount > 0 --loop through secondaries and see if a_LicenseTypeCode != the LTs there.
      --Check that the secondary Counts match!
      THEN
      CASE
      WHEN a_jobtypeid = api.pkg_configquery.objectdefidforname('j_Application') --when app
        THEN
        FOR c IN
        (SELECT api.pkg_columnquery.VALUE( c.toobjectid, 'LicenseTypeCode') ltc
        FROM api.relationships r
        JOIN api.relationships c
        ON c.fromobjectid    = r.toobjectid
        AND c.endpointid     = api.pkg_configquery.endpointidforname( 'o_PrimaryLicenseType', 'LicTypeCatSecondary')
        WHERE r.fromobjectid = a_jobid
        AND r.endpointid     = api.pkg_configquery.endpointidforname( 'j_Application', 'PrimaryLicenseType')
        )
        LOOP
          ------Secondaries
          FOR x IN
          (SELECT s.licensetypecount ltcount
          FROM api.relationships r
          JOIN query.r_priltltcatsecondary s
          ON s.primarylicensetypeobjectid = r.toobjectid
          WHERE r.fromobjectid            = a_jobid
          AND r.endpointid                = api.pkg_configquery.endpointidforname( 'j_Application', 'PrimaryLicenseType')
          AND c.ltc                       = api.pkg_columnquery.VALUE( s.licensetypecategoryobjectid, 'LicenseTypeCode')
          )
          LOOP
            -------Possible no_data_found error
            -------limit by LT code.
            CASE
            WHEN a_licensetypecode = c.ltc AND a_secondarycount = x.ltcount THEN
              t_raiseerrflag      := FALSE;
              EXIT;
            ELSE
              NULL;
            END CASE;
          END LOOP;
        END LOOP;
        CASE
        WHEN t_raiseerrflag = TRUE THEN
          t_message        := 3;
        ELSE
          NULL;
        END CASE;
      WHEN a_jobtypeid = api.pkg_configquery.objectdefidforname('j_License') -- when Lic
        THEN
        FOR c IN
        (SELECT api.pkg_columnquery.VALUE( c.toobjectid, 'LicenseTypeCode') ltc
        FROM api.relationships r
        JOIN api.relationships c
        ON c.fromobjectid    = r.toobjectid
        AND c.endpointid     = api.pkg_configquery.endpointidforname( 'j_LicenseType', 'LicTypeCatSecondary')
        WHERE r.fromobjectid = a_jobid
        AND r.endpointid     = api.pkg_configquery.endpointidforname( 'j_License', 'LicenseType')
        )
        LOOP
          ------Secondaries
          FOR x IN
          (SELECT lt.licensetypecount ltcount
          FROM api.relationships r
          JOIN query.r_licensetypeltcatsecondary lt
          ON lt.licensetypejobid = r.toobjectid
          WHERE r.fromobjectid   = a_jobid
          AND r.endpointid       = api.pkg_configquery.endpointidforname( 'j_License', 'LicenseType')
          AND c.ltc              = api.pkg_columnquery.VALUE( lt.licensetypecategoryobjectid, 'LicenseTypeCode')
          )
          LOOP
            CASE
            WHEN a_licensetypecode = c.ltc AND a_secondarycount = x.ltcount THEN
              t_raiseerrflag      := FALSE;
              EXIT;
            ELSE
              NULL;
            END CASE;
          END LOOP;
        END LOOP;
        CASE
        WHEN t_raiseerrflag = TRUE THEN
          t_message        := 3;
        ELSE
          NULL;
        END CASE;
      WHEN a_jobtypeid = api.pkg_configquery.objectdefidforname('j_LicenseType') -- when LT
        THEN
        FOR c IN
        (SELECT api.pkg_columnquery.VALUE( r.toobjectid, 'LicenseTypeCode') ltc
        FROM api.relationships r
        WHERE r.fromobjectid = a_jobid
        AND r.endpointid     = api.pkg_configquery.endpointidforname( 'j_LicenseType', 'LicTypeCatSecondary')
        )
        LOOP
          ---Secondaries
          FOR x IN
          (SELECT api.pkg_columnquery.VALUE( r.relationshipid, 'LicenseTypeCount') ltcount
          FROM api.relationships r
          WHERE r.fromobjectid = a_jobid
          AND r.endpointid     = api.pkg_configquery.endpointidforname( 'j_LicenseType', 'LicTypeCatSecondary')
          AND c.ltc            = api.pkg_columnquery.VALUE( r.toobjectid, 'LicenseTypeCode')
          )
          LOOP
            CASE
            WHEN a_licensetypecode = c.ltc AND a_secondarycount = x.ltcount THEN
              t_raiseerrflag      := FALSE;
              EXIT;
            ELSE
              NULL;
            END CASE;
          END LOOP;
        END LOOP;
        CASE
        WHEN t_raiseerrflag = TRUE THEN
          t_message        := 3;
        ELSE
          NULL;
        END CASE;
      ELSE
        NULL;
      END CASE;
    END IF;
    RETURN t_message;
  END feeearnedsummarymessage;
-------------------------------------
--
-------------------------------------
  PROCEDURE revenuereport(
      a_startdate DATE,
      a_enddate   DATE)
  IS
    t_amount           NUMBER := 0;
    t_renamount        NUMBER := 0;
    t_penamount        NUMBER := 0;
    t_bkr              NUMBER := 0;
    t_bkt              NUMBER := 0;
    t_caterersclubs    NUMBER := 0;
    t_cateventauth     NUMBER := 0;
    t_cateventpermit   NUMBER := 0;
    t_dishonoredchecks NUMBER := 0;
    t_expirationdate   DATE;
    t_feeactivity      VARCHAR2(10);
    t_feeamount        NUMBER := 0;
    t_fingerprintfees  NUMBER := 0;
    t_increasefees     NUMBER := 0;
    t_licensefees      NUMBER := 0;
    t_mgr              NUMBER := 0;
    t_miscovrpm        NUMBER := 0;
    t_mod              NUMBER := 0;
    t_other            NUMBER := 0;
    t_paidamount       NUMBER := 0;
    t_unpaidren        NUMBER := 0;
    t_penalties        NUMBER := 0;
    t_poic             NUMBER := 0;
    t_prevpaid         NUMBER := 0;
    t_prw              NUMBER := 0;
    t_replacements     NUMBER := 0;
    t_revenuecode      VARCHAR2(20);
    t_s70              NUMBER := 0;
    t_scheduleid udt_id;
    t_servicechrg NUMBER := 0;
    t_transfers   NUMBER := 0;
    t_winesafety  NUMBER := 0;
  BEGIN
    DELETE revenuereportdetail_gt;
    FOR c IN
    (SELECT NVL( api.pkg_columnquery.numericvalue(ps.objectid, 'EarnedAmount'), 0) amount,
      api.pkg_columnquery.VALUE(ps.objectid, 'Converted') converted,
      api.pkg_columnquery.VALUE(ps.objectid, 'TransactionCode') description,
      api.pkg_columnquery.datevalue(f.objectid, 'RENExpirationDate') expirationdate,
      NVL( api.pkg_columnquery.VALUE(ps.objectid, 'FeeActivity'), mfs.code) feeactivity,
      ft.feeid,
      api.pkg_columnquery.numericvalue(f.objectid, 'Amount') feeamount,
      api.pkg_columnquery.VALUE(ps.objectid, 'GallonageRangeFeeCode') gallonagerange,
      api.pkg_columnquery.numericvalue(f.objectid, 'JobId') jobid,
      api.pkg_columnquery.VALUE(ps.objectid, 'LicenseTypeCode') licensetypecode,
      api.pkg_columnquery.VALUE(ps.objectid, 'SecondaryCount') secondarycount,
      api.pkg_columnquery.VALUE(ps.objectid, 'MasterLT') masterlt,
      api.pkg_columnquery.VALUE( ps.objectid, 'NumberOfMonthsLicensedFeeCode') numberofmonthslicensed,
      api.pkg_columnquery.numericvalue(f.objectid, 'PaidAmount') paidamount,
      api.pkg_columnquery.VALUE(ps.objectid, 'PopulationRangeFeeCode') populationrange,
      api.pkg_columnquery.VALUE( pt.objectid, 'FeeScheduleDescriptionForGrid') ptdescription,
      ft.transactionid
    FROM TABLE( CAST( api.pkg_simplesearch.castableobjectsbyindexrange( 'o_PaymentStatus', 'dup_CreatedDate', TO_CHAR(a_startdate, 'YYYY-MM-DD'), TO_CHAR(a_enddate, 'YYYY-MM-DD')) AS api.udt_objectlist)) ps
    JOIN api.objects o
    ON o.objectid = ps.objectid
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
    )
    LOOP
      IF c.feeactivity NOT LIKE 'REN%' OR c.converted = 'Y' THEN
        IF c.ptdescription                            = 'OVR' THEN
          t_other                                    := t_other + c.amount;
          t_revenuecode                              := 'OTHER';
        ELSIF c.ptdescription LIKE '%SRV' THEN
          t_servicechrg := t_servicechrg + c.amount;
          t_revenuecode := 'SRVCHG';
          /* Elsif c.FeeActivity = '70S' then
          t_s70 := t_s70 + c.Amount;
          t_RevenueCode := '70S';*/
        ELSIF c.feeactivity                                                                                                                                                                         IN ('REN', 'ORI', 'ANN', 'ICF', 'DOR', 'ODL', 'SPD', 'TPT', 'IPT', 'AWF', 'TST', 'SDV') AND (c.licensetypecode NOT IN ('58', '77') OR c.licensetypecode IS NULL) THEN
          t_licensefees                                                                                                                                                             := t_licensefees + c.amount;
          t_revenuecode                                                                                                                                                             := 'LICFEE';
        ELSIF c.feeactivity               IN ('CATA', 'EPA') THEN
          t_cateventauth := t_cateventauth + c.amount;
          t_revenuecode  := 'CAUTH583';
        ELSIF c.feeactivity                                                              IN ('REN', 'ORI', 'ANN', 'ICF', 'DOR', 'ODL', 'TPT') AND c.licensetypecode IN ('58', '77') THEN
          IF c.masterlt                                                                  IN ('50', '51', '52') AND c.licensetypecode = '58' THEN
            t_caterersclubs                                            := t_caterersclubs + c.amount;
            t_revenuecode                                              := 'CLUBCAT';
          ELSIF (c.masterlt NOT                                                           IN ('50', '51', '52') OR c.masterlt    IS NULL) AND c.licensetypecode = '58' THEN
            t_cateventpermit                                           := t_cateventpermit + c.amount;
            t_revenuecode                                              := 'CATPERM';
          ELSIF c.licensetypecode                                       = '77' THEN
            t_cateventpermit                                           := t_cateventpermit + c.amount;
            t_revenuecode                                              := 'CATPERM';
          END IF;
        ELSIF c.feeactivity = 'MGR' THEN
          t_mgr            := t_mgr + c.amount;
          t_revenuecode    := 'MANQ321';
        ELSIF c.feeactivity = 'PEN' THEN
          t_penalties      := t_penalties + c.amount;
          t_revenuecode    := 'PENALTY';
        ELSIF c.feeactivity = 'PRW' THEN
          t_prw            := t_prw + c.amount;
          t_revenuecode    := 'PRIVWARE';
        ELSIF c.feeactivity = 'UTR' THEN
          t_miscovrpm      := t_miscovrpm + c.amount;
          t_revenuecode    := 'UNCLAIM';
        ELSIF c.feeactivity = 'POIC' THEN
          t_poic           := t_poic + c.amount;
          t_revenuecode    := 'POIC';
        ELSIF c.feeactivity = 'MOD' THEN
          t_mod            := t_mod + c.amount;
          t_revenuecode    := 'COND803';
        ELSIF c.feeactivity = 'RPL' THEN
          t_replacements   := t_replacements + c.amount;
          t_revenuecode    := 'REPLACE';
        ELSIF c.feeactivity = 'CD8' THEN
          t_increasefees   := t_increasefees + c.amount;
          t_revenuecode    := 'FEEINC';
        ELSIF c.feeactivity         IN ('EXC', 'PER', 'ICO', 'FID', 'STK', 'STM', 'PRM', 'MBR', 'DPR', 'MBM') THEN
          t_transfers      := t_transfers + c.amount;
          t_revenuecode    := 'XFER';
        ELSIF c.feeactivity = 'BKT' THEN
          t_bkt            := t_bkt + c.amount;
          t_revenuecode    := 'BKT';
        ELSIF c.feeactivity = 'BKR' THEN
          t_bkr            := t_bkr + c.amount;
          t_revenuecode    := 'BKR';
        ELSIF c.feeactivity = 'CHK' THEN
          -- TODO: Dishonored Checks
          t_dishonoredchecks := t_dishonoredchecks + c.amount;
          t_revenuecode      := 'BADCHK';
        ELSIF c.feeactivity                     IN ('FFP', 'SFP') THEN
          t_fingerprintfees := t_fingerprintfees + c.amount;
          t_revenuecode     := 'FNGRPRNT';
        ELSE
          t_other       := t_other + c.amount;
          t_revenuecode := 'OTHER';
        END IF;
        INSERT
        INTO revenuereportdetail_gt
          (
            revenuecode,
            transcode,
            ltcode,
            amount
          )
          VALUES
          (
            t_revenuecode,
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
            c.amount
          );
      ELSIF c.feeactivity LIKE 'REN%' AND c.converted = 'N' THEN
        t_feeactivity                                := c.feeactivity;
        t_feeamount                                  := 0;
        t_prevpaid                                   := 0;
        t_unpaidren                                  := 0;
        t_renamount                                  := 0;
        t_penamount                                  := 0;
        IF c.ptdescription                            = 'OVR' THEN
          t_other                                    := t_other + c.amount;
          t_revenuecode                              := 'OTHER';
          INSERT
          INTO revenuereportdetail_gt
            (
              revenuecode,
              transcode,
              ltcode,
              amount
            )
            VALUES
            (
              t_revenuecode,
              c.ptdescription,
              CASE
                WHEN c.feeactivity IN ('FFP', 'SFP')
                THEN 'NA'
                ELSE NVL( c.licensetypecode, NVL( api.pkg_columnquery.VALUE( c.jobid, 'ApplicableLicenseType'), 'NA'))
              END,
              c.amount
            );
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
          IF t_renamount                                                   <> 0 THEN
            IF (c.licensetypecode NOT                                                      IN ('58', '77') OR c.licensetypecode IS NULL) THEN
              t_licensefees                                                := t_licensefees + t_renamount;
              t_revenuecode                                                := 'LICFEE';
            ELSIF c.licensetypecode                                                              IN ('58', '77') THEN
              IF c.masterlt                                                                      IN ('50', '51', '52') AND c.licensetypecode = '58' THEN
                t_caterersclubs                                                := t_caterersclubs + t_renamount;
                t_revenuecode                                                  := 'CLUBCAT';
              ELSIF (c.masterlt NOT                                                               IN ('50', '51', '52') OR c.masterlt        IS NULL) AND c.licensetypecode = '58' THEN
                t_cateventpermit                                               := t_cateventpermit + t_renamount;
                t_revenuecode                                                  := 'CATPERM';
              ELSIF c.licensetypecode                                           = '77' THEN
                t_cateventpermit                                               := t_cateventpermit + t_renamount;
                t_revenuecode                                                  := 'CATPERM';
              END IF;
            END IF;
            INSERT
            INTO revenuereportdetail_gt
              (
                revenuecode,
                transcode,
                ltcode,
                amount
              )
              VALUES
              (
                t_revenuecode,
                NVL( REPLACE( c.description, SUBSTR( c.description, 1, INSTR(c.description, ' ')), 'REN '), 'NA'),
                CASE
                  WHEN c.feeactivity IN ('FFP', 'SFP')
                  THEN 'NA'
                  ELSE NVL( c.licensetypecode, NVL( api.pkg_columnquery.VALUE( c.jobid, 'ApplicableLicenseType'), 'NA'))
                END,
                t_renamount
              );
          END IF;
          IF t_penamount  <> 0 THEN
            t_penalties   := t_penalties + t_penamount;
            t_revenuecode := 'PENALTY';
            INSERT
            INTO revenuereportdetail_gt
              (
                revenuecode,
                transcode,
                ltcode,
                amount
              )
              VALUES
              (
                t_revenuecode,
                NVL( REPLACE( c.description, SUBSTR( c.description, 1, INSTR(c.description, ' ')), 'PEN '), 'NA'),
                CASE
                  WHEN c.feeactivity IN ('FFP', 'SFP')
                  THEN 'NA'
                  ELSE NVL( c.licensetypecode, NVL( api.pkg_columnquery.VALUE( c.jobid, 'ApplicableLicenseType'), 'NA'))
                END,
                t_penamount
              );
          END IF;
        END IF;
      END IF;
    END LOOP;
    INSERT
    INTO revenuereport_gt
      (
        bkr,
        bkt,
        caterersclubs,
        cateventauth,
        cateventpermit,
        dishonoredchecks,
        fingerprintfees,
        increasefees,
        licensefees,
        mgr,
        miscovrpm,
        MOD,
        other,
        penalties,
        poic,
        prw,
        replacements,
        servicechrg,
        transfers,
        winesafety,
        s70
      )
      VALUES
      (
        t_bkr,
        t_bkt,
        t_caterersclubs,
        t_cateventauth,
        t_cateventpermit,
        t_dishonoredchecks,
        t_fingerprintfees,
        t_increasefees,
        t_licensefees,
        t_mgr,
        t_miscovrpm,
        t_mod,
        t_other,
        t_penalties,
        t_poic,
        t_prw,
        t_replacements,
        t_servicechrg,
        t_transfers,
        t_winesafety,
        t_s70
      );
  END revenuereport;
---------------------------
--
----------------------------
  PROCEDURE allocationreport
    (
      a_startdate DATE,
      a_enddate   DATE
    )
  IS
    t_allocationcode   VARCHAR2(10);
    t_annualfees       NUMBER := 0;
    t_appealboard      NUMBER := 0;
    t_absurchargepct   NUMBER := 0;
    t_b11a1            NUMBER := 0;
    t_b11a1sur         NUMBER := 0;
    t_b11a2            NUMBER := 0;
    t_b11a2sur         NUMBER := 0;
    t_badmastercount   NUMBER := 0;
    t_bpu2421count     NUMBER := 0;
    t_bpu2466count     NUMBER := 0;
    t_bpu52count       NUMBER := 0;
    t_bpuamount        NUMBER := 0;
    t_bpu24surcharge   NUMBER := 0;
    t_bpu52surcharge   NUMBER := 0;
    t_caterrauth583    NUMBER := 0;
    t_caterrpermit     NUMBER := 0;
    t_clubcat          NUMBER := 0;
    t_clubcatsur       NUMBER := 0;
    t_cond803          NUMBER := 0;
    t_dishonored       NUMBER := 0;
    t_dmvfund          NUMBER := 0;
    t_dmvsurcharge     NUMBER := 0;
    t_epaauth583       NUMBER := 0;
    t_epapermit        NUMBER := 0;
    t_exchange         NUMBER := 0;
    t_expirationdate   DATE;
    t_feeactivity      VARCHAR2(10);
    t_feeamount        NUMBER := 0;
    t_feesurchargepct  NUMBER := 0;
    t_fingerprint      NUMBER := 0;
    t_lastamount       NUMBER := 0;
    t_lastrecord       VARCHAR2(100);
    t_manageq321       NUMBER := 0;
    t_oahsurchargepct  NUMBER := 0;
    t_offcount         NUMBER := 0;
    t_oncount          NUMBER := 0;
    t_oldb11a1         NUMBER := 0;
    t_oldb11a1sur      NUMBER := 0;
    t_oldclubcat       NUMBER := 0;
    t_oldclubcatsur    NUMBER := 0;
    t_orioosc          NUMBER := 0;
    t_other            NUMBER := 0;
    t_paidamount       NUMBER := 0;
    t_penalty          NUMBER := 0;
    t_penamount        NUMBER := 0;
    t_poic             NUMBER := 0;
    t_prevpaid         NUMBER := 0;
    t_privware         NUMBER := 0;
    t_relatedrecord    VARCHAR2(1);
    t_renamount        NUMBER := 0;
    t_replace          NUMBER := 0;
    t_seacount         NUMBER := 0;
    t_sec070tranfr     NUMBER := 0;
    t_sec053bpu        NUMBER := 0;
    t_sec202           NUMBER := 0;
    t_sec203           NUMBER := 0;
    t_sec357out        NUMBER := 0;
    t_sec659rec        NUMBER := 0;
    t_sec659tag        NUMBER := 0;
    t_sec761096nonsurg NUMBER := 0;
    t_sec761096surg    NUMBER := 0;
    t_sec954ori        NUMBER := 0;
    t_sec959srvsmg     NUMBER := 0;
    t_scheduleid udt_id;
    t_tempdaily  NUMBER := 0;
    t_unclaim    NUMBER := 0;
    t_unpaidren  NUMBER := 0;
    t_winesafety NUMBER := 0;
  BEGIN
    --DELETE allocationreportdetail_gt; --10/26/2018 sheik - commenting this line
    EXECUTE immediate 'truncate table allocationreportdetail_gt'; --10/26/2018 sheik - Cleans report data before a new run
    EXECUTE immediate 'truncate table allocationreport_gt';       --10/26/2018 sheik - Cleans report data before a new run
    -- Set values for Surcharge Amounts
    t_dmvsurcharge    := 5;
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
        NVL( api.pkg_columnquery.VALUE(ps.objectid, 'FeeActivity'), 'UTR') feeactivity,
        api.pkg_columnquery.numericvalue(f.objectid, 'FeeId') feeid,
        api.pkg_columnquery.VALUE(ps.objectid, 'GallonageFeeCode') gallonagerange,
        api.pkg_columnquery.VALUE(ps.objectid, 'IsMaster') ismaster,
        api.pkg_columnquery.numericvalue(f.objectid, 'JobId') jobid,
        api.pkg_columnquery.VALUE( (api.pkg_columnquery.numericvalue(f.objectid, 'JobId')), 'LicenseNumber') licensenumber,
        api.pkg_columnquery.VALUE(ps.objectid, 'LicenseTypeCode') licensetypecode,
        api.pkg_columnquery.VALUE(ps.objectid, 'MasterLT') masterlt,
        api.pkg_columnquery.VALUE( ps.objectid, 'NumberOfMonthsLicensedFeeCode') numberofmonthslicensed,
        api.pkg_columnquery.VALUE(ps.objectid, 'PopulationRangeFeeCode') populationrange,
        api.pkg_columnquery.VALUE( pt.objectid, 'FeeScheduleDescriptionForGrid') ptdescription,
        api.pkg_columnquery.VALUE(ps.objectid, 'SecondaryCount') secondarycount,
        ft.transactionid
        -- api.pkg_columnquery.VALUE(ps.objectid, 'dup_CreatedDate') created_dt
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
      ORDER BY licensenumber,
        licensetypecode,
        ismaster,
        feeactivity,
        api.pkg_columnquery.datevalue(pt.objectid, 'PaymentStatus'),
        amount
    )
    LOOP
      -- 11/1/2018 WO#16948 Sheik DMV Surcharge Increases from $5 to $10 effective C fee code
      IF instr
        (
          c.description,' C'
        )
                        >1 THEN
        t_dmvsurcharge := 10;
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
            t_clubcat        := t_clubcat    + c.amount;
            t_clubcatsur     := t_clubcatsur + (c.amount * t_absurchargepct);
            t_allocationcode := 'CLUBCAT';
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
            t_b11a2          := t_b11a2      + c.amount;
            t_b11a2sur       := t_b11a2sur   + (c.amount * t_absurchargepct);
            t_allocationcode := 'b11a2';
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
        ELSIF c.feeactivity IN ('ANN', 'REN') OR (c.feeactivity                  = 'DOR' AND c.licensetypecode IN ('06', '58', '66', '77')) THEN --TBD: Sheik 1/7/18 We need to include 47, 88 and any other that applies DOR, and also include in the DMV bucket
          IF c.licensenumber || c.licensetypecode || c.feeactivity || c.ismaster = t_lastrecord AND ((c.amount < 0 AND t_lastamount < 0) OR (c.amount >= 0 AND t_lastamount >= 0)) THEN
            t_relatedrecord                                                     := 'Y';
          ELSE
            t_relatedrecord := 'N';
          END IF;
          IF c.licensetypecode IN ('01', '02', '03', '23', '62') THEN
            /* IF ((c.ismaster = 'Y'
            AND c.licensetypecode IN ('01', '03', '23'))
            OR (c.gallonagerange IS NOT NULL
            AND c.licensetypecode = '02')
            OR (c.licensetypecode = '62')) THEN */
            IF t_relatedrecord    = 'N' THEN
              IF c.amount         < 0 THEN
                t_badmastercount := t_badmastercount + 1;
                t_dmvfund        := t_dmvfund        - t_dmvsurcharge;
              ELSIF c.amount      > 0 THEN
                t_badmastercount := t_badmastercount - 1;
              END IF;
            END IF;
            -- END IF;
          ELSIF c.licensetypecode IN ('04', '05', '07', '13', '18', '27', '74') THEN -- 11/30/2018 WO#16948 Sheik Adding missing LT 74
            IF t_relatedrecord = 'N' THEN
              IF c.amount      < 0 THEN
                t_bpu52count  := t_bpu52count + 1;
                t_dmvfund     := t_dmvfund    - t_dmvsurcharge;
                -- t_bpuamount   := t_bpuamount  + t_bpu52surcharge; Sheik  commenting this line
                t_bpuamount  := t_bpuamount - t_bpu52surcharge; -- Sheik  8/23/18 Store negative value bucket instead of positive number as per Randy
              ELSIF c.amount  > 0 THEN
                t_bpu52count := t_bpu52count - 1;
              END IF;
            END IF;
          ELSIF c.licensetypecode = '21' THEN
            IF t_relatedrecord    = 'N' THEN
              IF c.amount         < 0 THEN
                t_bpu2421count   := t_bpu2421count + 1;
                t_dmvfund        := t_dmvfund      - t_dmvsurcharge;
                -- t_bpuamount      := t_bpuamount    + t_bpu24surcharge; Sheik  commenting this line
                t_bpuamount    := t_bpuamount - t_bpu24surcharge; -- Sheik  8/23/18 Store negative value bucket instead of positive number as per Randy
              ELSIF c.amount    > 0 THEN
                t_bpu2421count := t_bpu2421count - 1;
              END IF;
            END IF;
          ELSIF c.licensetypecode = '66' THEN
            IF t_relatedrecord    = 'N' THEN
              IF c.amount         < 0 THEN
                t_bpu2466count   := t_bpu2466count + 1;
                -- t_bpuamount      := t_bpuamount    + t_bpu24surcharge;  Sheik  commenting this line
                t_bpuamount    := t_bpuamount - t_bpu24surcharge; -- Sheik  8/23/18 Store negative value bucket instead of positive number as per Randy
              ELSIF c.amount    > 0 THEN
                t_bpu2466count := t_bpu2466count - 1;
              END IF;
            END IF;
            -- 11/30 WO#16948 Sheik adding below missing LT's 09, 11, 12, 74, 85, 87
          ELSIF c.licensetypecode IN ('06', '08', '10', '14', '15', '16', '17', '19', '20', '22', '24', '25', '09', '11', '12', '74', -- TBD: Sheik 1/3/19 - 74 has been added in t_bpu52Count
            '85', '87') THEN
            IF t_relatedrecord = 'N' THEN
              IF c.amount      < 0 THEN
                t_offcount    := t_offcount + 1;
                t_dmvfund     := t_dmvfund  - t_dmvsurcharge;
              ELSIF c.amount   > 0 THEN
                t_offcount    := t_offcount - 1;
              END IF;
            END IF;
            -- 11/30 WO#16948 Sheik adding below missing LT's 58 ,66 ,68 ,71 ,72 ,75 ,76 ,78 ,83
            -- 1/2/19 WO#16948 Adding 88
          ELSIF c.licensetypecode IN ('40', '41', '42', '43', '44', '45', '46', '47', '48', '50', '51', '52', '53', '54', '55', '56', '57', '61', '63', '64', '65', '69', '70',
            -- '49' ,
            '58' ,
            -- '59' ,
            -- '60' ,
            '66' , '68' , '71' , '72' , '75' , '76' , '78' , '83', '88') THEN
            IF t_relatedrecord = 'N' THEN
              IF c.amount      < 0 THEN
                t_oncount     := t_oncount + 1;
                t_dmvfund     := t_dmvfund - t_dmvsurcharge;
              ELSIF c.amount   > 0 THEN
                t_oncount     := t_oncount - 1;
              END IF;
            END IF;
          ELSIF c.licensetypecode IN ('49', '59', '60') THEN
            IF t_relatedrecord = 'N' THEN
              IF c.amount      < 0 THEN
                t_seacount    := t_seacount + 1;
                t_dmvfund     := t_dmvfund  - t_dmvsurcharge;
              ELSIF c.amount   > 0 THEN
                t_seacount    := t_seacount - 1;
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
                t_oldclubcatsur  := t_oldclubcatsur + (c.amount * t_absurchargepct);
                t_allocationcode := 'CLUBCAT';
              ELSE
                t_clubcat        := t_clubcat    + c.amount;
                t_clubcatsur     := t_clubcatsur + (c.amount * t_absurchargepct);
                t_allocationcode := 'CLUBCAT';
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
              t_oldb11a1sur    := t_oldb11a1sur + (c.amount * t_absurchargepct);
              t_allocationcode := 'b11a1RAS';
            ELSE
              t_b11a1          := t_b11a1    + c.amount;
              t_b11a1sur       := t_b11a1sur + (c.amount * t_absurchargepct);
              t_allocationcode := 'b11a1RAS';
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
        INTO allocationreportdetail_gt
          (
            allocationcode,
            transcode,
            ltcode,
            amount
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
            c.amount
          );
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
          INTO allocationreportdetail_gt
            (
              allocationcode,
              transcode,
              ltcode,
              amount
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
              c.amount
            );
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
            IF c.licensetypecode IN ('01', '02', '03', '23', '62') THEN
              /* IF ((c.ismaster = 'Y'
              AND c.licensetypecode IN ('01', '03', '23'))
              OR (c.gallonagerange IS NOT NULL
              AND c.licensetypecode = '02')
              OR (c.licensetypecode = '62')) THEN */
              IF t_relatedrecord    = 'N' THEN
                IF c.amount         < 0 THEN
                  t_badmastercount := t_badmastercount + 1;
                  t_dmvfund        := t_dmvfund        - t_dmvsurcharge;
                ELSIF c.amount      > 0 THEN
                  t_badmastercount := t_badmastercount - 1;
                END IF;
              END IF;
              --  END IF;
            ELSIF c.licensetypecode IN ('04', '05', '07', '13', '18', '27', '74') THEN -- WO#16948 11/30/2018 Sheik Adding missing LT             ) THEN
              IF t_relatedrecord = 'N' THEN
                IF c.amount      < 0 THEN
                  t_bpu52count  := t_bpu52count + 1;
                  t_dmvfund     := t_dmvfund    - t_dmvsurcharge;
                  -- t_bpuamount   := t_bpuamount  + t_bpu52surcharge; Sheik  commenting this line
                  t_bpuamount  := t_bpuamount - t_bpu52surcharge; -- Sheik  8/23/18 Store negative value bucket instead of positive number as per Randy
                ELSIF c.amount  > 0 THEN
                  t_bpu52count := t_bpu52count - 1;
                END IF;
              END IF;
            ELSIF c.licensetypecode = '21' THEN
              IF t_relatedrecord    = 'N' THEN
                IF c.amount         < 0 THEN
                  t_bpu2421count   := t_bpu2421count + 1;
                  t_dmvfund        := t_dmvfund      - t_dmvsurcharge;
                  -- t_bpuamount      := t_bpuamount    + t_bpu24surcharge; Sheik  commenting this line
                  t_bpuamount    := t_bpuamount - t_bpu24surcharge; -- Sheik  8/23/18 Store negative value bucket instead of positive number as per Randy
                ELSIF c.amount    > 0 THEN
                  t_bpu2421count := t_bpu2421count - 1;
                END IF;
              END IF;
            ELSIF c.licensetypecode = '66' THEN
              IF t_relatedrecord    = 'N' THEN
                IF c.amount         < 0 THEN
                  t_bpu2466count   := t_bpu2466count + 1;
                  -- t_bpuamount      := t_bpuamount    + t_bpu24surcharge;
                  t_bpuamount    := t_bpuamount - t_bpu24surcharge; -- Sheik  8/23/18 Store negative value bucket instead of positive number as per Randy
                ELSIF c.amount    > 0 THEN
                  t_bpu2466count := t_bpu2466count - 1;
                END IF;
              END IF;
              -- 11/30 WO#16948 Sheik adding below missing LT's 09, 11, 12, 74, 85, 87
            ELSIF c.licensetypecode IN ('06', '08', '10', '14', '15', '16', '17', '19', '20', '22', '24', '25', '09', '11', '12', '74', -- TBD: Sheik 1/3/19 - 74 has been added in t_bpu52Count
              '85', '87') THEN
              IF t_relatedrecord = 'N' THEN
                IF c.amount      < 0 THEN
                  t_offcount    := t_offcount + 1;
                  t_dmvfund     := t_dmvfund  - t_dmvsurcharge;
                ELSIF c.amount   > 0 THEN
                  t_offcount    := t_offcount - 1;
                END IF;
              END IF;
              -- 11/30 WO#16948 Sheik adding below missing LT's 58 ,66 ,68 ,71 ,72 ,75 ,76 ,78 ,83
              -- 1/2/19 We need to confirm if we have to leave 47 and 88 and others here when the activity code is REN  - this is for REN only and 47 and 88 will not have REN
              -- 1/2/19 WO#16948 Adding 88
            ELSIF c.licensetypecode IN ('40', '41', '42', '43', '44', '45', '46', '47', '48', '50', '51', '52', '53', '54', '55', '56', '57', '61', '63', '64', '65', '69', '70',
              -- '49' ,
              '58' ,
              -- '59' ,
              -- '60' ,
              '66' , '68' , '71' , '72' , '75' , '76' , '78' , '83', '88') THEN
              IF t_relatedrecord = 'N' THEN
                IF c.amount      < 0 THEN
                  t_oncount     := t_oncount + 1;
                  t_dmvfund     := t_dmvfund - t_dmvsurcharge;
                ELSIF c.amount   > 0 THEN
                  t_oncount     := t_oncount - 1;
                END IF;
              END IF;
            ELSIF c.licensetypecode IN ('49', '59', '60') THEN
              IF t_relatedrecord = 'N' THEN
                IF c.amount      < 0 THEN
                  t_seacount    := t_seacount + 1;
                  t_dmvfund     := t_dmvfund  - t_dmvsurcharge;
                ELSIF c.amount   > 0 THEN
                  t_seacount    := t_seacount - 1;
                END IF;
              END IF;
            END IF;
            IF c.licensetypecode          IN ('26', '28', '29', '67') THEN
              t_annualfees     := t_annualfees + t_renamount;
              t_allocationcode := 'ANNFEES2';
            ELSIF c.licensetypecode IN ('58') THEN
              IF c.masterlt         IN ('50', '51', '52') THEN
                --
                -- only calc if the record is pre 2001 when the code was only 'ANN' and 'REN'  -- 12/4/2018 Sheik This comment line message is wrong, and here it's doing for ABIS records
                --
                IF c.description = 'REN' THEN
                  t_oldclubcat  := t_oldclubcat + t_renamount;
                  --                   t_Sec202 := t_Sec202 + (t_RENAmount * t_FeeSurchargePct);
                  --                   t_Sec203 := t_Sec203 + (t_RENAmount * t_OAHSurchargePct);
                  t_oldclubcatsur  := t_oldclubcatsur + (t_renamount * t_absurchargepct);
                  t_allocationcode := 'CLUBCAT';
                ELSE
                  t_clubcat        := t_clubcat    + t_renamount;
                  t_clubcatsur     := t_clubcatsur + (t_renamount * t_absurchargepct);
                  t_allocationcode := 'CLUBCAT';
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
              -- only calc if the record is pre 2001 when the code was only 'ANN' and 'REN' -- 12/4/2018 Sheik This comment line message is wrong, and here it's doing for ABIS records
              --
              IF c.description = 'REN' THEN
                t_oldb11a1    := t_oldb11a1 + t_renamount;
                --                t_Sec202 := t_Sec202 + (t_RENAmount * t_FeeSurchargePct);
                --                t_Sec203 := t_Sec203 + (t_RENAmount * t_OAHSurchargePct);
                t_oldb11a1sur    := t_oldb11a1sur + (t_renamount * t_absurchargepct);
                t_allocationcode := 'b11a1RAS';
              ELSE
                t_b11a1          := t_b11a1    + t_renamount;
                t_b11a1sur       := t_b11a1sur + (t_renamount * t_absurchargepct);
                t_allocationcode := 'b11a1RAS';
              END IF;
            END IF;
            INSERT
            INTO allocationreportdetail_gt
              (
                allocationcode,
                transcode,
                ltcode,
                amount
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
                t_renamount
              );
          END IF;
        END IF;
        IF t_penamount     <> 0 THEN
          t_penalty        := t_penalty + t_penamount;
          t_allocationcode := 'PENALTY';
          INSERT
          INTO allocationreportdetail_gt
            (
              allocationcode,
              transcode,
              ltcode,
              amount
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
              t_penamount
            );
        END IF;
      END IF;
      t_lastrecord := c.licensenumber || c.licensetypecode || c.feeactivity || c.ismaster;
      t_lastamount := c.amount;
    END LOOP;
    t_b11a1 := t_b11a1 - t_dmvfund - t_bpuamount;
    -- 08/30/2018 Sheik As per Randy, uncommenting below line that was commented in 2014
    t_Sec053BPU := t_Sec053BPU + t_BPUAmount;
    --t_Sec053BPU := t_Sec053BPU + t_BPUAmount;
    -- 02/27/2014  MMR  Per Kristine Okino in Accounting, calculate the column as follows
    -- to balance the BPU sums and render a negative sum.
    -- 09/11/2018 Sheik As per Randy, commenting below line that was commented in 2014
    -- t_sec053bpu          := (  (t_bpu52count * 52) + (t_bpu2421count * 24)  + (t_bpu2466count * 24))* -1;
    t_appealboard   := (t_clubcatsur + t_oldclubcatsur) + (t_b11a1sur + t_oldb11a1sur) + t_b11a2sur;
    t_sec761096surg := (t_b11a1      + t_oldb11a1 + t_b11a2 + t_clubcat + t_oldclubcat) - (
    /*t_Sec202 + t_Sec203 + */
    t_appealboard);
    t_sec761096nonsurg := t_tempdaily + t_annualfees;
    INSERT
    INTO allocationreport_gt
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
        epaauth583
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
        bankersround(t_epaauth583)
      );
  END allocationreport;
  PROCEDURE AllocationReport2
    (
      a_StartDate DATE,
      a_EndDate   DATE
    )
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
    A_STARTDATE := '01-FEB-18';   --Format 'DD-MON-YY'
    A_ENDDATE := '28-FEB-18';   --Format 'DD-MON-YY'
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
    1.1        06/20/2019   Sheik          Allocation Report 2.0
    2.0        07/26/2019   Sheik    Fixing DMV,AB for the adjustments and secondaries
    2.1   08/12/2019   Sheik    Grouping multiple payments to avoid wrong AB Calculations
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
    t_BPU_FEE           NUMBER       := 0;
    t_dmv_surcharge_amt NUMBER       := 0;
    t_AB_SURCHARGE_PCT  NUMBER       := 0;
    t_AB_SURCHARGE_AMT  NUMBER       := 0;
    t_rounding_5        DATE         := '01-OCT-19';
    v_new_original      NUMBER(15,2) := 0;
  BEGIN
    -- Start date and time
    SELECT sysdate
    INTO v_start_dtTime
    FROM dual;
    --to_char(sysdate,'mm/dd/yyyy HH:MMAM')  into v_start_dtTime
    dbms_output.put_line('Starting at .. '||TO_CHAR(v_start_dtTime,'MM/DD/YY HH12:MM'));
    EXECUTE immediate 'truncate table ALLOCATION_INITIALFETCH_GT';
    EXECUTE immediate 'truncate table ALLOCATIONREPORT2_GT';
    EXECUTE immediate 'truncate table ALLOCATION_GROUPED_GT';
    FOR c IN
    (SELECT rownum record_num,
      amount EarnedAmount,
      ab_surcharge_pct ,
      -- originalfee,
      CASE
        WHEN amount < 0
        THEN (
          CASE
            WHEN gallonagerange = 'GL1M'
            THEN (originalfee + ABS(secondarycount * SecondaryAmount) ) * -1
            ELSE originalfee  * -1
          END )
        WHEN amount >= 0
        THEN (
          CASE
            WHEN gallonagerange = 'GL1M'
            THEN (originalfee + ABS(secondarycount * SecondaryAmount) )
            ELSE originalfee
          END )
      END originalfee,
      bpu_fee,
      dmv_surcharge_amt,
      paymentstatus,
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
      NVL( api.pkg_columnquery.numericvalue(f_objectid, 'ADJUSTEDAMOUNT'), 0) penaltyAMT,
      PrimaryAmount,         -- 10/14/19
      PrimarySecondaryAmount -- 10/14/19
    FROM
      (SELECT surchargecode,
        Amount,
        originalfee,
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
        CASE
          WHEN amount < 0
          THEN SecondaryAmount * -1
          WHEN amount > 0
          THEN SecondaryAmount
        END SecondaryAmount,
        -- secondarycount, 10/14/2019
        CASE
          WHEN amount        > 0
          AND paymentstatus IS NULL
          AND secondarycount > 0
          AND surchargecode IS NOT NULL
          AND PrimarySecondaryAmount != 0   -- 10/02/2020 TJL  22891 added to prevent divide by 0 error
          THEN (amount - PrimaryAmount) / PrimarySecondaryAmount
          ELSE secondarycount
        END secondarycount,
        ptdescription,
        gallonagerange,
        feeid,
        jobid,
        paymentstatus,
        PrimaryAmount,         -- 10/14/19
        PrimarySecondaryAmount -- 10/14/19
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
          NVL(to_number(api.pkg_columnquery.VALUE(ps_objectid, 'SecondaryCount')),0) secondarycount,
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
          api.pkg_columnquery.numericvalue(f_objectid, 'JobId') jobid ,
          api.pkg_columnquery.datevalue(pt_objectid, 'PaymentStatus') paymentstatus,
          CASE
            WHEN fs.amount < 0
            THEN NVL(to_number(api.pkg_columnquery.VALUE(licensefeeschedid, 'PrimaryAmount')) , 0) * -1
            WHEN fs.amount > 0
            THEN NVL(to_number(api.pkg_columnquery.VALUE(licensefeeschedid, 'PrimaryAmount')) , 0)
          END PrimaryAmount,
          CASE
            WHEN fs.amount < 0
            THEN NVL(to_number(api.pkg_columnquery.VALUE(licensefeeschedid, 'SECONDARYAMOUNT')) , 0) * -1
            WHEN fs.amount > 0
            THEN NVL(to_number(api.pkg_columnquery.VALUE(licensefeeschedid, 'SECONDARYAMOUNT')) , 0)
          END PrimarySecondaryAmount
        FROM
          (SELECT f.objectid f_objectid,
            ps.objectid ps_objectid,
            pt.objectid pt_objectid,
            ft.transactionid,
            af.transactiondate,
            f.licensefeeschedid,
            NVL( api.pkg_columnquery.numericvalue(ps.objectid, 'EarnedAmount'), 0) amount,
            api.pkg_columnquery.VALUE(f.licensefeeschedid, 'surchargecode') surchargecode
            --FROM TABLE(CAST(api.pkg_simplesearch.castableobjectsbyindexrange( 'o_PaymentStatus', 'dup_CreatedDate', '2018-02-01', '2018-02-28') AS api.udt_objectlist)) ps
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
      IF (c.SECONDARYCOUNT)    > 0 AND c.PTDESCRIPTION <> 'SRV' AND c.PTDESCRIPTION NOT LIKE '%DOR%' AND NVL(c.MASTERLT,'ZZZ') = NVL(c.LICENSETYPECODE,'ZZZ') AND c.SURCHARGECODE IS NOT NULL THEN
        v_new_original        := c.ORIGINALFEE + (c.SECONDARYCOUNT * c.SECONDARYAMOUNT) ;
      ELSIF (c.SECONDARYCOUNT) > 0 AND c.PTDESCRIPTION <> 'SRV' AND c.PTDESCRIPTION LIKE '%DOR%' AND c.ISMASTER = 'N' AND NVL(c.MASTERLT,'ZZZ') = NVL(c.LICENSETYPECODE,'ZZZ') AND c.SURCHARGECODE IS NOT NULL THEN
        v_new_original        := (c.SECONDARYCOUNT * c.SECONDARYAMOUNT) ;
        -- 10/17/2019
      ELSIF NVL(c.MASTERLT,'ZZZ') <> NVL(c.LICENSETYPECODE,'ZZZ') AND c.SECONDARYCOUNT > 1 AND c.ISMASTER = 'N' AND c.SURCHARGECODE IS NOT NULL THEN
        v_new_original            := c.SECONDARYCOUNT * c.SECONDARYAMOUNT ;
        -- 10/21/2019
      ELSIF NVL(c.MASTERLT,'ZZZ') <> NVL(c.LICENSETYPECODE,'ZZZ') AND c.SECONDARYCOUNT = 1 AND c.ISMASTER = 'N' AND c.SURCHARGECODE IS NOT NULL THEN
        v_new_original            := c.SECONDARYAMOUNT;
      ELSE
        v_new_original := c.ORIGINALFEE ;
      END IF;
      INSERT
      INTO sitespecific.ALLOCATION_INITIALFETCH_GT
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
          transactiondate,
          PrimaryAmount,
          PrimarySecondaryAmount,
          Uncalc_OriginalFEE
        )
        VALUES
        (
          c.RECORD_NUM,
          c.EARNEDAMOUNT,
          c.AB_SURCHARGE_PCT,
          v_new_original,
          c.BPU_FEE,
          CASE
            WHEN to_number(c.SECONDARYCOUNT) > 0
            AND c.PTDESCRIPTION             <> 'SRV'
            AND
              --c.feeactivity <> 'DOR' and
              c.PTDESCRIPTION NOT LIKE '%DOR%'
            AND c.MASTERLT       = c.LICENSETYPECODE
            AND c.SURCHARGECODE IS NOT NULL
            THEN (c.SECONDARYCOUNT * c.DMV_SURCHARGE_AMT ) + c.DMV_SURCHARGE_AMT
              -- 10/17/2019
            WHEN c.MASTERLT     IS NOT NULL
            AND c.MASTERLT      <> c.LICENSETYPECODE
            AND c.SECONDARYCOUNT > 1
            AND c.SURCHARGECODE IS NOT NULL
            THEN c.SECONDARYCOUNT * c.DMV_SURCHARGE_AMT
            ELSE c.DMV_SURCHARGE_AMT
          END,
          -- 10/14/2019
          (
          CASE
            WHEN c.transactiondate >= '01-OCT-19'
            AND c.EARNEDAMOUNT     <> 0
            THEN (
              CASE
                WHEN c.SECONDARYCOUNT > 0
                AND c.PTDESCRIPTION  <> 'SRV'
                AND c.PTDESCRIPTION NOT LIKE '%DOR%'
                AND c.MASTERLT       = c.LICENSETYPECODE
                AND c.SURCHARGECODE IS NOT NULL
                THEN ( ROUND( c.ORIGINALFEE * (c.ab_surcharge_pct/100) /5)*5 + ( (ROUND ( c.SECONDARYAMOUNT * (c.ab_surcharge_pct/100) /5)*5 ) * c.SECONDARYCOUNT ) )
                ELSE ROUND( v_new_original  * (c.ab_surcharge_pct/100) /5)*5
              END)
            ELSE (
              CASE
                WHEN c.SECONDARYCOUNT > 0
                AND c.PTDESCRIPTION  <> 'SRV'
                AND
                  --c.feeactivity <> 'DOR' and
                  c.PTDESCRIPTION NOT LIKE '%DOR%'
                AND c.MASTERLT       = c.LICENSETYPECODE
                AND c.SURCHARGECODE IS NOT NULL
                THEN ROUND( c.ORIGINALFEE  * (c.ab_surcharge_pct/100) ) + (ROUND( c.SECONDARYAMOUNT * (c.ab_surcharge_pct/100) ) * c.SECONDARYCOUNT )
                ELSE ROUND( v_new_original * (c.ab_surcharge_pct/100) )
              END)
          END),
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
          c.transactiondate,
          c.PrimaryAmount,
          c.PrimarySecondaryAmount,
          c.ORIGINALFEE -- 10/18/19
        );
      --COMMIT;
    END LOOP;
    -- Group all multiple payments to one single record
    INSERT
    INTO sitespecific.ALLOCATION_Grouped_GT
      (
        RECORD_NUM ,
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
        TRANSACTIONDATE,
        PrimaryAmount,
        PrimarySecondaryAmount,
        Uncalc_OriginalFEE
      )
    SELECT l2.RECORD_NUM ,
      l1.EARNEDAMOUNT,
      l2.AB_SURCHARGE_PCT,
      l2.ORIGINALFEE ,
      CASE
        WHEN l1.EARNEDAMOUNT = 0
        THEN 0
        ELSE l2.BPU_FEE
      END BPU_FEE,
      CASE
        WHEN l1.EARNEDAMOUNT = 0
        THEN 0
        ELSE l2.DMV_SURCHARGE_AMT
      END DMV_SURCHARGE_AMT,
      AB_SURCHARGE_AMT,
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
      l2.FEEID,
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
      TRANSACTIONDATE ,
      PrimaryAmount,
      PrimarySecondaryAmount,
      Uncalc_OriginalFEE
    FROM ALLOCATION_INITIALFETCH_GT l2,
      (SELECT LicenseNumber,
        LicenseTypeCode,
        IsMaster,
        feeid,
        FeeActivity,
        PaymentStatus,
        MIN(RECORD_NUM) record_num,
        SUM(EarnedAmount) earnedamount
      FROM ALLOCATION_INITIALFETCH_GT
      GROUP BY LicenseNumber,
        LicenseTypeCode,
        IsMaster,
        feeid,
        FeeActivity,
        PaymentStatus
      ) l1
    WHERE l1.record_num = l2.record_num
    ORDER BY l1.record_num;
    BEGIN
      -- Get General fund (POIC)
      SELECT NVL(SUM(EarnedAmount),0)
      INTO v_poic
      FROM sitespecific.ALLOCATION_Grouped_GT
      WHERE feeactivity = 'POIC'; -- and converted ='Y';
      /* UPDATE abc.ALLOCATION_Grouped_GT
      set bukt_poic = 'Y'
      where feeactivity = 'POIC'; */
      --Commit;
      -- ABC Fund
      SELECT (SUM(EarnedAmount) - NVL( SUM(dmv_surcharge_amt),0) - NVL(SUM(AB_SURCHARGE_AMT),0)) -- - NVL( SUM(bpu_fee),0)) 10/8/2019
      INTO v_abcfunds
      FROM
        ( SELECT * FROM sitespecific.ALLOCATION_Grouped_GT
        MINUS
        SELECT *
        FROM sitespecific.ALLOCATION_Grouped_GT
        WHERE feeactivity  = 'POIC'
        OR feeactivity     = 'CHK'         -- dishonored checks
        OR (feeactivity   IN ('SFP','FFP') -- finger prints
        AND ptdescription <> 'OVR')
        );
      /* UPDATE abc.ALLOCATION_Grouped_GT
      set bukt_ABCFund = 'Y'
      WHERE EXISTS
      ( SELECT * FROM abc.ALLOCATION_Grouped3
      minus
      SELECT *
      FROM abc.ALLOCATION_Grouped3
      where feeactivity = 'POIC'
      or feeactivity = 'CHK' -- dishonored checks
      OR     (feeactivity IN ('SFP','FFP') -- finger prints
      AND ptdescription <> 'OVR')
      ); */
      SELECT NVL(SUM(AB_SURCHARGE_AMT),0)
      INTO v_ab_surcharges
      FROM sitespecific.ALLOCATION_Grouped_GT
      WHERE PTDESCRIPTION NOT LIKE '%SRV%'; --converted ='Y';
      /* UPDATE abc.ALLOCATION_Grouped3
      set bukt_AB_Surcharge = 'Y'
      where PTDESCRIPTION NOT LIKE '%SRV%'
      -- AND ab_surcharge_amt <> 0;
      AND new_ab <> 0; */
      --Commit;
      -- Get DMV fund
      SELECT NVL(SUM(dmv_surcharge_amt),0)
      INTO v_dmv_surcharges
      FROM sitespecific.ALLOCATION_Grouped_GT
      WHERE PTDESCRIPTION NOT LIKE '%SRV%'; --converted ='Y';
      /* UPDATE abc.ALLOCATION_Grouped3
      set bukt_DMV = 'Y'
      where PTDESCRIPTION NOT LIKE '%SRV%'
      AND dmv_surcharge_amt <> 0;
      COMMIT; */
      -- Dishonored check charges
      SELECT NVL(SUM( earnedamount),0)
      INTO v_dishonored
      FROM sitespecific.ALLOCATION_Grouped_GT
      WHERE feeactivity = 'CHK';
      /* UPDATE abc.ALLOCATION_Grouped3
      set bukt_dishonored = 'Y'
      WHERE feeactivity   = 'CHK';
      COMMIT; */
      -- Fingerprint fees
      SELECT NVL(SUM( earnedamount),0)
      INTO v_Fingerprint
      FROM sitespecific.ALLOCATION_Grouped_GT
      WHERE feeactivity IN ('SFP','FFP')
      AND ptdescription <> 'OVR';
      /* UPDATE abc.ALLOCATION_Grouped3
      set bukt_FingerPrints = 'Y'
      where feeactivity IN ('SFP','FFP')
      AND ptdescription    <> 'OVR';
      COMMIT; */
      -- Grand total
      SELECT SUM(EarnedAmount)
      INTO v_GrandTotal
      FROM sitespecific.ALLOCATION_Grouped_GT;
      -- Finish time
      SELECT sysdate INTO v_Finish_dtTime FROM dual;
      -- Final report details
      INSERT
      INTO sitespecific.ALLOCATIONREPORT2_GT
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
      --Commit;
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
/*--------------------------
-- DepositReportDetail() PUBLIC
-- This generates the results for the Deposit Report (Detail)
---------------------------*/
  PROCEDURE depositreportdetail
    (
      a_startdate DATE,
      a_enddate   DATE
    )
  IS
    t_hqfingerprints             NUMBER;
    t_hqdishonoredcheckcharges   NUMBER;
    t_hqlicensefees              NUMBER;
    t_hqmiscamrs                 NUMBER;
    t_hqrevolvingfund            NUMBER;
    t_hqappealsboard             NUMBER;
    t_hqfederaldrugasset         NUMBER;
    t_hqstatedrugasset           NUMBER;
    t_hqunclaimedtrust           NUMBER;
    t_distfingerprints           NUMBER;
    t_distdishonoredcheckcharges NUMBER;
    t_distlicensefees            NUMBER;
    t_distmiscamrs               NUMBER;
    t_distrevolvingfund          NUMBER;
    t_distappealsboard           NUMBER;
    t_distfederaldrugasset       NUMBER;
    t_diststatedrugasset         NUMBER;
    t_distunclaimedtrust         NUMBER;
    t_cash                       NUMBER;
    t_checks                     NUMBER;
    t_cashconvertedtochecks      NUMBER;
  BEGIN
    DELETE depositreportdetail_gt;
    DELETE depositdetailids_gt;
    -- Deposit JobIds
    INSERT
    INTO depositdetailids_gt
      (
        amount,
        depositjobid,
        feeobjectid,
        paymentobjectid,
        transmittaljobid,
        paymenttransobjectid
      )
    SELECT
      /*+ CARDINALITY(d 1)*/
      ft.amount,
      d.objectid depositjobid,
      ft.feeid feeobjectid,
      p.objectid paymentobjectid,
      td.transmittaljobid transmittaljobid,
      api.pkg_simplesearch.objectbyindex( 'o_PaymentTransactions', 'TransactionId', pt.transactionid) paymenttransactionid
    FROM TABLE( CAST( api.pkg_simplesearch.castableobjectsbyindexrange( 'j_Deposit', 'DepositDate', TO_CHAR(a_startdate, 'YYYY-MM-DD'), TO_CHAR(a_enddate, 'YYYY-MM-DD')) AS api.udt_objectlist)) d
    JOIN query.r_transmittaldeposit td
    ON td.depositjobid = d.objectid
    JOIN query.r_transmittalpayment tp
    ON tp.transmittaljobid = td.transmittaljobid
    JOIN query.o_payment p
    ON p.objectid = tp.paymentobjectid
    JOIN api.paymenttransactions pt
    ON pt.paymentid = p.paymentid
    JOIN api.feetransactions ft
    ON ft.transactionid   = pt.transactionid
    WHERE p.isvoidedflag != 'Y';
    -- Transmittal / License Fee Schedule
    INSERT
    INTO depositreportdetail_gt
      (
        depositdate,
        depositnumber,
        depositamount,
        dist,
        batchid,
        batchtype,
        batchtotal,
        paymentid,
        receiptnumber,
        paytype,
        paymentamount,
        transcode,
        paidamount,
        amounttype,
        paytype2,
        licensenumber
      )
    SELECT TO_CHAR( api.pkg_columnquery.datevalue(d.depositjobid, 'DepositDate'), 'MM-DD-YY') depositdate,
      api.pkg_columnquery.VALUE(d.depositjobid, 'DepositNumber') depositnumber,
      api.pkg_columnquery.numericvalue(d.depositjobid, 'DepositAmount') depositamount,
      NVL( SUBSTR( api.pkg_columnquery.VALUE(d.transmittaljobid, 'Office'), 1, 2), 'no') dist,
      api.pkg_columnquery.VALUE(d.transmittaljobid, 'ExternalFileNum') batchid,
      'PAY' batchtype,
      api.pkg_columnquery.VALUE(d.transmittaljobid, 'PaymentTotalAmount') batchtotal,
      api.pkg_columnquery.VALUE(d.paymentobjectid, 'PayeeReference') paymentid,
      NVL( api.pkg_columnquery.VALUE(d.paymentobjectid, 'ReceiptNumber'), api.pkg_columnquery.VALUE(d.paymentobjectid, 'HQReceiptLookup')) receiptnumber,
      api.pkg_columnquery.VALUE(d.paymentobjectid, 'PaymentMethodCode') paytype,
      NVL( api.pkg_columnquery.VALUE(d.paymentobjectid, 'PaymentAmount'), 0) paymentamount,
      CASE
        WHEN api.pkg_columnquery.VALUE(d.paymenttransobjectid, 'IsOverpayment') = 'Y'
        THEN 'OVR'
        WHEN api.pkg_columnquery.VALUE(d.paymenttransobjectid, 'IsServiceCharge') = 'Y'
        THEN 'SVR'
        ELSE SUBSTR(fs.description, 1, 6)
      END transcode,
      NVL(-d.amount, 0) paidamount,
      'I' amounttype,
      'LIC' paytype2,
      api.pkg_columnquery.VALUE( api.pkg_columnquery.numericvalue( api.pkg_simplesearch.objectbyindex('o_Fee', 'FeeId', d.feeobjectid), 'JobId'), 'LicenseNumber') licensenumber
    FROM depositdetailids_gt d
    JOIN sitespecific.feeschedule_t fs
    ON fs.objectid = sitespecific.pkg_fees.getlicfeeschedulobjid( d.feeobjectid);
    -- Transmittal / Misc Fee Schedule
    INSERT
    INTO depositreportdetail_gt
      (
        depositdate,
        depositnumber,
        depositamount,
        dist,
        batchid,
        batchtype,
        batchtotal,
        paymentid,
        receiptnumber,
        paytype,
        paymentamount,
        transcode,
        paidamount,
        amounttype,
        paytype2,
        licensenumber
      )
    SELECT
      /*+ CARDINALITY(x 1)*/
      TO_CHAR( api.pkg_columnquery.datevalue(d.depositjobid, 'DepositDate'), 'MM-DD-YY') depositdate,
      api.pkg_columnquery.VALUE(d.depositjobid, 'DepositNumber') depositnumber,
      api.pkg_columnquery.numericvalue(d.depositjobid, 'DepositAmount') depositamount,
      NVL( SUBSTR( api.pkg_columnquery.VALUE(d.transmittaljobid, 'Office'), 1, 2), 'no') dist,
      api.pkg_columnquery.VALUE(d.transmittaljobid, 'ExternalFileNum') batchid,
      'PAY' batchtype,
      api.pkg_columnquery.VALUE(d.transmittaljobid, 'PaymentTotalAmount') batchtotal,
      api.pkg_columnquery.VALUE(d.paymentobjectid, 'PayeeReference') paymentid,
      NVL( api.pkg_columnquery.VALUE(d.paymentobjectid, 'ReceiptNumber'), api.pkg_columnquery.VALUE(d.paymentobjectid, 'HQReceiptLookup')) receiptnumber,
      api.pkg_columnquery.VALUE(d.paymentobjectid, 'PaymentMethodCode') paytype,
      NVL( api.pkg_columnquery.VALUE(d.paymentobjectid, 'PaymentAmount'), 0) paymentamount,
      CASE
        WHEN api.pkg_columnquery.VALUE(d.paymenttransobjectid, 'IsOverPayment') = 'Y'
        THEN 'OVPM'
        WHEN api.pkg_columnquery.VALUE(d.paymenttransobjectid, 'IsServiceCharge') = 'Y'
        THEN 'SRV'
        ELSE SUBSTR( api.pkg_columnquery.VALUE( mffs.miscfeescheduleobjectid, 'Code'), 1, 6)
      END transcode,
      NVL(-d.amount, 0) paidamount,
      'I' amounttype,
      CASE
        WHEN api.pkg_columnquery.VALUE( mffs.miscfeescheduleobjectid, 'Code') NOT IN ('RFD', 'SAR', 'TAR', 'APBD', 'DAFF', 'DAFS', 'UTC')
        THEN 'AMR'
        WHEN api.pkg_columnquery.VALUE( mffs.miscfeescheduleobjectid, 'Code') IN ('RFD', 'SAR', 'TAR')
        THEN 'REV'
        WHEN api.pkg_columnquery.VALUE( mffs.miscfeescheduleobjectid, 'Code') = 'APBD'
        THEN 'APP'
        WHEN api.pkg_columnquery.VALUE( mffs.miscfeescheduleobjectid, 'Code') = 'DAFF'
        THEN 'FED'
        WHEN api.pkg_columnquery.VALUE( mffs.miscfeescheduleobjectid, 'Code') = 'DAFS'
        THEN 'STD'
        WHEN api.pkg_columnquery.VALUE( mffs.miscfeescheduleobjectid, 'Code') = 'UTC'
        THEN 'UNC'
      END paytype2,
      api.pkg_columnquery.VALUE( api.pkg_columnquery.numericvalue( api.pkg_simplesearch.objectbyindex('o_Fee', 'FeeId', d.feeobjectid), 'JobId'), 'LicenseNumber') licensenumber
    FROM depositdetailids_gt d
    JOIN query.r_miscfeefeeschedule mffs
    ON api.pkg_simplesearch.objectbyindex('o_Fee', 'FeeId', d.feeobjectid) = mffs.feeobjectid;
    INSERT
    INTO depositreportdetail_gt
      (
        depositdate,
        depositnumber,
        depositamount,
        dist,
        batchid,
        batchtype,
        batchtotal,
        paymentid,
        receiptnumber,
        paytype,
        paymentamount,
        transcode,
        paidamount,
        amounttype,
        paytype2,
        licensenumber
      )
    SELECT
      /*+ CARDINALITY (d 1) */
      TO_CHAR( api.pkg_columnquery.datevalue(d.objectid, 'DepositDate'), 'MM-DD-YY') depositdate,
      api.pkg_columnquery.VALUE(d.objectid, 'DepositNumber') depositnumber,
      api.pkg_columnquery.numericvalue(d.objectid, 'DepositAmount') depositamount,
      '50' dist,
      pb.externalfilenum batchid,
      CASE
        WHEN pb.paymentbatchtype = 'INDIVIDUAL RENEWAL PAYMENTS (IR)'
        OR pb.paymentbatchtype   = 'P-12 RENEWALS'
        THEN 'REN'
        WHEN pb.paymentbatchtype = 'ADDITIONAL WINE FEES (AWF)'
        OR pb.paymentbatchtype   = 'PETITION FOR OFFER IN COMPROMISE (POIC)'
        THEN 'MISC'
      END batchtype,
      pb.batchamount batchtotal,
      p.batchpaymentid paymentid,
      NVL(p.receiptnumber, p.hqreceiptlookup),
      p.paymentmethodcode paytype,
      NVL(p.paymentamount, 0) paymentamount,
      CASE
        WHEN qpt.isoverpayment = 'Y'
        THEN 'OVR'
        WHEN qpt.isservicecharge = 'Y'
        THEN 'SRV'
        ELSE SUBSTR(fs.description, 1, 6)
      END transcode,
      NVL(-ft.amount, 0) paidamount,
      'I' amounttype,
      'LIC' paytype2,
      api.pkg_columnquery.VALUE(f.jobid, 'LicenseNumber') licensenumber
    FROM TABLE( CAST( api.pkg_simplesearch.castableobjectsbyindexrange( 'j_Deposit', 'DepositDate', TO_CHAR(a_startdate, 'YYYY-MM-DD'), TO_CHAR(a_enddate, 'YYYY-MM-DD')) AS api.udt_objectlist)) d
    JOIN query.r_depositpaymentbatch dpb
    ON dpb.depositjobid = d.objectid
    JOIN query.j_paymentbatch pb
    ON pb.jobid = dpb.paymentbatchjobid
    JOIN query.r_paymentbatchpayment pbp
    ON pbp.paymentbatchjobid = pb.jobid
    JOIN query.o_payment p
    ON p.objectid = pbp.paymentobjectid
    JOIN api.paymenttransactions pt
    ON pt.paymentid = p.paymentid
    JOIN query.o_paymenttransactions qpt
    ON qpt.objectid = api.pkg_simplesearch.objectbyindex( 'o_PaymentTransactions', 'Transactionid', pt.transactionid)
    JOIN api.feetransactions ft
    ON ft.transactionid = pt.transactionid
    JOIN api.fees f
    ON f.feeid = ft.feeid
    JOIN sitespecific.feeschedule_t fs
    ON fs.objectid        = sitespecific.pkg_fees.getlicfeeschedulobjid( f.feeid)
    WHERE p.isvoidedflag != 'Y'
    ORDER BY batchid,
      licensenumber;
  END depositreportdetail;
/*--------------------------
-- GreenPinkLicense() PUBLIC
-- This determines which procedure to run and produce the report
---------------------------*/
  PROCEDURE greenpinklicense(
      a_objectid udt_id)
  IS
    t_objectdefid udt_id;
  BEGIN
    SELECT o.objectdefid
    INTO t_objectdefid
    FROM api.objects o
    WHERE o.objectid = a_objectid;
    IF t_objectdefid = api.pkg_configquery.objectdefidforname('p_PrintLicenseBulk') THEN
      sitespecific.pkg_reports.printlicensebatch(a_objectid);
    ELSIF t_objectdefid = api.pkg_configquery.objectdefidforname('p_PrintLicense') THEN
      sitespecific.pkg_reports.printlicensebatch(a_objectid); -- Change the package from Benjamin to the correct one
    ELSIF t_objectdefid = api.pkg_configquery.objectdefidforname('p_ProduceLicenses') THEN
      sitespecific.pkg_reports.manualproducelicense(a_objectid); -- Change the package from Benjamin to the correct one
    END IF;
    --/* for c in (select * from sitespecific.Pinkandgreenlicense_Gt) loop
    --   dbms_output.put_line(c.licensetypename || ' ' || c.dup_count);
    -- end loop;*/ -- this is used for testing.
  END;
/*--------------------------
-- PrintLicenseBatch() PUBLIC
-- This procedure loads a GTT with data for the Green and Pink License Reports.
---------------------------*/
  PROCEDURE printlicensebatch(
      a_objectid udt_id)
  IS
    temp api.udt_objectlist;
    t_jobid         INTEGER;
    t_pagenumber    INTEGER := 1;
    t_licensenumber INTEGER;
    t_lines         INTEGER := 0;
    t_counttemp     INTEGER;
    t_previousjobid INTEGER;
    t_nextjobid     INTEGER;
    t_continue      BOOLEAN;
    t_processid     INTEGER;
    t_processtypeid INTEGER;
  BEGIN
    DELETE pinkandgreenlicense_gt;
    t_jobid         := api.pkg_columnquery.VALUE (a_objectid, 'JobId');
    t_processid     := a_objectid;
    t_processtypeid := api.pkg_columnquery.VALUE (a_objectid, 'ObjectDefId');
    -- Run SQL and either out it through a variable or place it drectly into the GTT
    INSERT
    INTO pinkandgreenlicense_gt
      (
        licensetypename,
        licensee,
        lic_dba,
        mailingaddress4lines,
        effective_date,
        expirationdate,
        licensetypecode,
        licensenumber,
        dup_count,
        licensegeocode,
        district,
        prem_address,
        owner,
        condi,
        runid,
        batchtype,
        issue_type,
        iss_type_details,
        color,
        serialnumber,
        jobid,
        othercount,
        dupdescriptor
      )
    SELECT UPPER (lt.licensetypename) licensetypename,
      UPPER (li.primarylicensee) licensee,
      NVL2 (li.dba, 'DBA: ', '')
      || UPPER (li.dba) lic_dba,
      UPPER (lt.mailingaddress4lines) mailingaddress4lines,
      CASE
        WHEN lt.seasonstartmonthnumber IS NOT NULL
        AND lt.includeinchangeappbatch  = 'N'
        THEN TO_DATE ( LPAD (NVL (lt.seasonstartmonthnumber, '01'), 2, '00')
          || '/01/'
          ||
          CASE
            WHEN TO_NUMBER ( TO_CHAR ( api.pkg_columnquery.datevalue ( lt.objectid, 'ExpirationDate'), 'MM')) - ( api.pkg_columnquery.numericvalue ( lt.objectid, 'NumberOfMonthsLicensedNumber') -- returns 1 less than actual number of months
                                                                                                              + 1) <                                                                              -- 01/10/2019 TJL 16435 removed = from test
              0
            THEN NVL ( api.pkg_columnquery.numericvalue ( lt.objectid, 'ExpiringYear') - 1, '9999')
            ELSE NVL ( api.pkg_columnquery.numericvalue ( lt.objectid, 'ExpiringYear'), '9999')
          END, 'MM/DD/YYYY')
        WHEN lt.includeinchangeappbatch = 'Y'
        THEN -- and LB.DAILYORRENEWAL = 'Daily' then -- added and LB.DAILYORRENEWAL = 'Daily' to resolve issue 4184 by Pawan 0n 7/14/2014
          CASE
            WHEN lt.seasonstartmonth        IS NOT NULL
            AND (TRUNC (lt.readytoissuedate) < TO_DATE ( LPAD ( NVL ( lt.seasonstartmonthnumber, '01'), 2, '00')
              || '/01/'
              ||
              CASE
                WHEN TO_NUMBER ( TO_CHAR ( api.pkg_columnquery.datevalue ( lt.objectid, 'ExpirationDate'), 'MM')) - ( api.pkg_columnquery.numericvalue ( lt.objectid, 'NumberOfMonthsLicensedNumber') + 1) <= 0
                THEN NVL ( api.pkg_columnquery.numericvalue ( lt.objectid, 'ExpiringYear')                        - 1, '9999')
                ELSE NVL ( api.pkg_columnquery.numericvalue ( lt.objectid, 'ExpiringYear'), '9999')
              END, 'MM/DD/YYYY'))
            THEN TO_DATE ( LPAD ( NVL (lt.seasonstartmonthnumber, '01'), 2, '00')
              || '/01/'
              ||
              CASE
                WHEN TO_NUMBER ( TO_CHAR ( api.pkg_columnquery.datevalue ( lt.objectid, 'ExpirationDate'), 'MM')) - ( api.pkg_columnquery.numericvalue ( lt.objectid, 'NumberOfMonthsLicensedNumber') + 1) <= 0
                THEN NVL ( api.pkg_columnquery.numericvalue ( lt.objectid, 'ExpiringYear')                        - 1, '9999')
                ELSE NVL ( api.pkg_columnquery.numericvalue ( lt.objectid, 'ExpiringYear'), '9999')
              END, 'MM/DD/YYYY')
            ELSE
              -- need to process two different ways, depending on the batch type -- added by Pawan/MMR on 8/28/2014 for issue 4184
              CASE
                WHEN lb.dailyorrenewal = 'Daily'
                THEN -- first time it is licenses
                  TRUNC (lt.readytoissuedate)
                ELSE --1st renewal then
                  TO_DATE ( '01'
                  || TO_CHAR ( ADD_MONTHS ( TRUNC ( lt.expirationdate), -11), '/MM/YYYY'), 'DD/MM/YYYY')
              END
          END
        WHEN ( lt.issuedate IS NOT NULL
        AND lt.issuedate     < TRUNC (lt.readytoissuedate))
        THEN TO_DATE ( '01'
          || TO_CHAR ( ADD_MONTHS (TRUNC (lt.expirationdate), -11), '/MM/YYYY'), 'DD/MM/YYYY')
        ELSE TRUNC (lt.readytoissuedate)
      END effective_date,
      TRUNC (lt.expirationdate) expirationdate,
      TO_CHAR (lt.licensetypecode) licensetypecode,
      li.licensenumber,
      NVL2 (lt.masterlicensenumber, 1, NVL (lt.primarycount, NULL)) dup_count,
      lt.licensegeocode,
      LPAD (TO_CHAR (lt.district), 2, 0) district,
      UPPER ( DECODE (lt.mailingaddress4lines, lt.premisesaddress4lines, NULL, lt.premisesaddress4lines)) prem_address,
      li.licenseenames owner,
      TRIM ( ','
    FROM TRIM ( ' '
    FROM DECODE (lt.conda, 'Y', 'A', NULL)
      || CHR (13)
      || DECODE (lt.condd, 'Y', 'D'
      || CHR (13), NULL)
      || DECODE(lt.conde, 'Y', 'E' --WO31613 Update License to print New condition E Pawan 4/28/2023
      || CHR (13), NULL)
      || DECODE (lt.condg, 'Y', 'G'
      || CHR (13), NULL) --  WO16291 Update License to print New condition G Pawan
      || DECODE (lt.condi, 'Y', 'I'
      || CHR (13), NULL)
      || DECODE (lt.condr, 'Y', 'R'
      || CHR (13), NULL)
      || DECODE (lt.condm, 'Y', 'M'
      || CHR (13), NULL) --  1/14/19 Sheik WO17107 Cond M  Update License to print New condition M
      || DECODE (lt.cond1c, 'Y', '1C'
      || CHR (13), NULL)
      || DECODE (lt.cond7, 'Y', '7'
      || CHR (13), NULL)
      || DECODE ( lt.cond2, 'Y', '2'
      || NVL2 ( lt.conditionenddate, ' '
      || lt.conditionenddate, '')
      || CHR (13), NULL)
      || DECODE ( lt.cond5, 'Y', '5'
      || NVL2 ( lt.conditionenddate, ' '
      || lt.conditionenddate, '')
      || CHR (13), NULL)
      || DECODE (lt.cond8, 'Y', '8'
      || CHR (13), NULL)
      || DECODE (lt.cond9, 'Y', '9'
      || CHR (13), NULL)
	  || lt.sectioncodelist --12/10/2019 TJL  20023   
	   )) condi,
      lb.runid,
      lb.batchtype,
      lt.typeofissuance issue_type,
      'ISSUE TYPE DETAILS' iss_type_details,
      lb.color,
      ltib.serialnumber,
      li.jobid,
      licenseecount othercount,
      NULL dupdescriptor
    FROM query.j_licensebatch lb
    JOIN sitespecific.licbatchlictype_xref_t ltib
    ON ltib.licensebatchjobid = lb.jobid
      --join query.r_PrintLicenseLicenseType r on r.PrintLicenseProcessId = p.processid
    JOIN query.j_licensetype lt
    ON lt.jobid = ltib.licensetypejobid --r.LicenseTypeJobId
    JOIN query.r_licensetypeltcatprimary r2
    ON r2.licensetypejobid = lt.jobid
    JOIN query.o_licensetypecategory pltc
    ON pltc.objectid = r2.licensetypecategoryobjectid
      --join query.j_Licensebatch lb on lb.jobid = p.jobid
    JOIN query.r_licenselicensetype lilt
    ON lilt.licensetypejobid = lt.jobid
    JOIN query.j_license li
    ON li.jobid                   = lilt.licensejobid
    WHERE lb.jobid                = t_jobid
    AND pltc.color                = lb.color
    AND lt.PRINT                  = 'Y'
    AND lt.statusdescription NOT IN ('Surrendered', 'Suspended')
    AND ltib.printorder           =
      (SELECT (COUNT (p.processid))
      FROM api.processes p
      WHERE p.jobid       = t_jobid
      AND p.processid    <= t_processid
      AND p.processtypeid = t_processtypeid
      )
    UNION ALL
    SELECT UPPER (sltc.licensetypename) licensetypename,
      UPPER (li.primarylicensee) licensee,
      NVL2 (li.dba, 'DBA: ', '')
      || UPPER (li.dba) lic_dba,
      UPPER (lt.mailingaddress4lines) mailingaddress4lines,
      CASE
        WHEN lt.seasonstartmonthnumber IS NOT NULL
        AND r2.includeinchangeappbatch  = 'N'
        THEN
          -- 02/14/2019 TJL WO 16435 change how date was generated
          TRUNC ( ADD_MONTHS ( lt.ExpirationDate, NVL (lt.NumberOfMonthsLicensedNumber, 11) * -1), 'MONTH')
        WHEN r2.includeinchangeappbatch = 'Y'
        THEN --and LB.DAILYORRENEWAL = 'Daily' then -- added and and LB.DAILYORRENEWAL = 'Daily' to resolve issue 4184 by Pawan 0n 7/14/2014
          CASE
            WHEN lt.seasonstartmonth        IS NOT NULL
            AND (TRUNC (do.readytoissuedate) < TO_DATE ( LPAD ( NVL ( lt.seasonstartmonthnumber, '01'), 2, '00')
              || '/01/'
              || NVL (lt.expiringyear, '9999'), 'MM/DD/YYYY'))
            THEN TO_DATE ( LPAD ( NVL (lt.seasonstartmonthnumber, '01'), 2, '00')
              || '/01/'
              || NVL (lt.expiringyear, '9999'), 'MM/DD/YYYY')
            ELSE
              -- per Licensing  08-29-14  this is not needed was done to fix issue 4184
              -- case when trunc(do.ReadyToIssueDate) >= trunc(lt.expirationdate) then
              -- add_months(TRUNC(do.ReadytoIssueDate), 12)
              -- else
              -- need to process two different ways, depending on the batch type -- added by Pawan/MMR on 8/28/2014 for issue 4184
              CASE
                WHEN lb.dailyorrenewal = 'Daily'
                THEN -- first time it is licenses
                  TRUNC (do.readytoissuedate)
                ELSE --1st renewal then
                  TO_DATE ( '01'
                  || TO_CHAR ( ADD_MONTHS ( TRUNC ( lt.expirationdate), -11), '/MM/YYYY'), 'DD/MM/YYYY')
              END
              -- end
          END
        WHEN do.issuedate             IS NOT NULL -- Added by Pawan to fix WO17111 Valid From Date in Pink license Batch 08/17/2019
        AND do.issuedate               < TRUNC (do.readytoissuedate)
        AND TRUNC (lt.expirationdate) <= TRUNC (do.readytoissuedate)
        THEN TO_DATE ( '01'
          || TO_CHAR ( ADD_MONTHS (TRUNC (lt.expirationdate), 1), '/MM/YYYY'), 'DD/MM/YYYY')
        WHEN do.issuedate IS NOT NULL
        AND do.issuedate   < TRUNC (do.readytoissuedate)
          -- AND  TRUNC(lt.expirationdate)<= TRUNC(do.readytoissuedate)
        THEN TO_DATE ( '01'
          || TO_CHAR ( ADD_MONTHS (TRUNC (lt.expirationdate), -11), '/MM/YYYY'), 'DD/MM/YYYY') -- Added by Pawan to fix WO17111 Valid From Date in Pink license Batch 08/17/2019
        ELSE
          CASE
            WHEN TRUNC (do.readytoissuedate) >= TRUNC (lt.expirationdate)
            THEN ADD_MONTHS (TRUNC (do.readytoissuedate), 12)
            ELSE TRUNC (do.readytoissuedate)
          END
      END effective_date,
      /* case
      when lt.SeasonStartMonthNumber is not null and r2.IncludeInChangeAppBatch = 'N'
      then to_date(lpad(nvl(lt.SeasonStartMonthNumber,'01'),2,'00')
      ||'/01/'||
      nvl(lt.ExpiringYear,'9999'), 'MM/DD/YYYY')
      when r2.IncludeInChangeAppBatch = 'Y' and LB.DAILYORRENEWAL = 'Daily' then -- added and and LB.DAILYORRENEWAL = 'Daily' to resolve issue 4184 by Pawan 0n 7/14/2014
      case when lt.SeasonStartMonth is not null and (trunc(do.ReadytoIssueDate)
      < to_date(lpad(nvl(lt.SeasonStartMonthNumber,'01'),2,'00')||'/01/'||nvl(lt.ExpiringYear,'9999'), 'MM/DD/YYYY')) then
      to_date(lpad(nvl(lt.SeasonStartMonthNumber,'01'),2,'00')||'/01/'||nvl(lt.ExpiringYear,'9999'), 'MM/DD/YYYY')
      else
      case when trunc(do.ReadyToIssueDate) >= trunc(lt.expirationdate) then
      add_months(TRUNC(do.ReadytoIssueDate), 12)
      else
      TRUNC(do.ReadytoIssueDate)
      end
      end
      when do.IssueDate is not null and do.issuedate < trunc(do.ReadyToIssueDate)
      then to_date('01' || to_char(add_months(trunc(lt.ExpirationDate), -11), '/MM/YYYY'), 'DD/MM/YYYY')
      else
      case when trunc(do.ReadyToIssueDate) >= trunc(lt.expirationdate) then
      add_months(TRUNC(do.ReadytoIssueDate), 12)
      else
      case  when do.IssueDate is not null and do.issuedate >= trunc(do.ReadyToIssueDate)
      then to_date('01' || to_char(add_months(trunc(lt.ExpirationDate), -11), '/MM/YYYY'), 'DD/MM/YYYY')
      else
      TRUNC(do.ReadytoIssueDate)
      end
      end
      end effective_date,  */
      CASE
        WHEN TRUNC (r2.readytoissuedate) >= TRUNC (lt.expirationdate)
        THEN ADD_MONTHS (TRUNC (lt.expirationdate), 12)
        ELSE TRUNC (lt.expirationdate)
      END expirationdate,
      TO_CHAR (sltc.licensetypecode) licensetypecode,
      li.licensenumber,
      /*x.Column_Value*/
      do.dupnumber dup_count,
      lt.licensegeocode,
      LPAD (TO_CHAR (lt.district), 2, 0) district,
      UPPER ( DECODE (lt.mailingaddress4lines, lt.premisesaddress4lines, NULL, lt.premisesaddress4lines)) prem_address,
      li.licenseenames owner,
      TRIM ( ','
    FROM TRIM ( ' '
    FROM DECODE (lt.conda, 'Y', 'A', NULL)
      || CHR (13)
      || DECODE (lt.condd, 'Y', 'D'
      || CHR (13), NULL)
      || DECODE(lt.conde, 'Y', 'E' --WO31613 Update License to print New condition E Pawan 4/28/2023
      || CHR (13), NULL)
      || DECODE (lt.condg, 'Y', 'G'
      || CHR (13), NULL) --  WO16291 Update License to print New condition G Pawan
      || DECODE (lt.condi, 'Y', 'I'
      || CHR (13), NULL)
      || DECODE (lt.condr, 'Y', 'R'
      || CHR (13), NULL)
      || DECODE (lt.condm, 'Y', 'M'
      || CHR (13), NULL) --  1/14/19 Sheik WO17107 Cond M  Update License to print New condition M
      || DECODE (lt.cond1c, 'Y', '1C'
      || CHR (13), NULL)
      || DECODE (lt.cond7, 'Y', '7'
      || CHR (13), NULL)
      || DECODE ( lt.cond2, 'Y', '2'
      || NVL2 ( lt.conditionenddate, ' '
      || lt.conditionenddate, '')
      || CHR (13), NULL)
      || DECODE ( lt.cond5, 'Y', '5'
      || NVL2 ( lt.conditionenddate, ' '
      || lt.conditionenddate, '')
      || CHR (13), NULL)
      || DECODE (lt.cond8, 'Y', '8'
      || CHR (13), NULL)
      || DECODE (lt.cond9, 'Y', '9'
      || CHR (13), NULL)
	  || lt.sectioncodelist --12/10/2019 TJL  20023  
	   )) condi,
      lb.runid,
      lb.batchtype,
      /*r2.TypeofIssuance*/
      --do.typeofissuance Sheik commenting
      -- WO# 17178 - Adding below to handle null values
      NVL (do.typeofissuance, r2.TypeofIssuance) issue_type,
      'ISSUE TYPE DETAILS' iss_type_details,
      lb.color,
      ltib.serialnumber,
      li.jobid,
      licenseecount othercount,
      do.description dupdescriptor
    FROM query.j_licensebatch lb
    JOIN sitespecific.licbatchlictype_xref_t ltib
    ON ltib.licensebatchjobid = lb.jobid
      --join query.r_PrintLicenseLicenseType r on r.PrintLicenseProcessId = p.processid
    JOIN query.j_licensetype lt
    ON lt.jobid = ltib.licensetypejobid --r.LicenseTypeJobId
    JOIN query.r_licensetypeltcatsecondary r2
    ON r2.licensetypejobid = lt.jobid
    JOIN query.o_licensetypecategory sltc
    ON sltc.objectid = r2.licensetypecategoryobjectid
    JOIN query.r_licenselicensetype lilt
    ON lilt.licensetypejobid = lt.jobid
    JOIN query.j_license li
    ON li.jobid = lilt.licensejobid
    JOIN sitespecific.duplicate_t dt
    ON dt.relationshipid = r2.relationshipid
    JOIN query.o_duplicate DO
    ON do.objectid = dt.duplicateid
      --cross join table(sitespecific.pkg_utils.GenerateRows(1,r2.LicenseTypeCount)) x
    WHERE lb.jobid      = t_jobid
    AND r2.status NOT  IN ('SURRENDERED', 'SUSPENDED')
    AND sltc.color      = lb.color
    AND do.PRINT        = 'Y'
    AND ltib.printorder =
      (SELECT (COUNT (p.processid))
      FROM api.processes p
      WHERE p.jobid       = t_jobid
      AND p.processid    <= t_processid
      AND p.processtypeid = t_processtypeid
      );
    --order by 2, 8;
    FOR c IN
    (SELECT pgl.licensenumber,
      pgl.licensee,
      pgl.licensetypecode,
      pgl.dup_count,
      pgl.ROWID
    FROM pinkandgreenlicense_gt pgl
    ORDER BY 2,
      1,
      3,
      4 NULLS FIRST
    )
    LOOP
      IF t_licensenumber != c.licensenumber THEN
        t_pagenumber     := 1;
      END IF;
      UPDATE pinkandgreenlicense_gt t
      SET t.pagenumber = t_pagenumber
      WHERE t.ROWID    = c.ROWID;
      t_pagenumber    := t_pagenumber + 1;
      t_licensenumber := c.licensenumber;
    END LOOP; --End Page Number Loop
    /*
    for e in (select length(le.FormattedName) namelength,
    ceil(length(le.FormattedName) / g_OwnerLineLength) lines,
    r.ToObjectId JobId
    from api.relationships r
    join query.o_LegalEntity le
    on le.ObjectId = r.FromObjectId
    where r.ToObjectId in (select li.JobId
    from pinkandgreenlicense_gt li)
    and (r.RelationshipDefId = api.pkg_ConfigQuery.ObjectDefIdForName('r_LicenseP12LegalEntity')
    or r.RelationshipDefId = api.pkg_ConfigQuery.ObjectDefIdForName('r_LicenseLegalEntityLicensee'))
    order by r.ToObjectId, le.SortColumn) loop
    */
    -----------------------
    -- Modified above 'for e in' loop for Daily Batch issue -- Gurpreet 7/8/2014
    FOR e IN
    (SELECT LENGTH (le.formattedname) namelength,
      CEIL (LENGTH (le.formattedname) / g_ownerlinelength) lines,
      r.toobjectid jobid,
      le.sortcolumn
    FROM api.relationships r
    JOIN query.o_legalentity le
    ON le.objectid      = r.fromobjectid
    WHERE r.toobjectid IN
      (SELECT li.jobid FROM sitespecific.pinkandgreenlicense_gt li
      )
    AND r.relationshipdefid = api.pkg_configquery.objectdefidforname ( 'r_LicenseLegalEntityLicensee')
    UNION ALL
    SELECT LENGTH (le.formattedname) namelength,
      CEIL (LENGTH (le.formattedname) / g_ownerlinelength) lines,
      r.toobjectid jobid,
      le.sortcolumn
    FROM api.relationships r
    JOIN query.o_legalentity le
    ON le.objectid      = r.fromobjectid
    WHERE r.toobjectid IN
      (SELECT li.jobid FROM sitespecific.pinkandgreenlicense_gt li
      )
    AND r.relationshipdefid = api.pkg_configquery.objectdefidforname ( 'r_LicenseP12LegalEntity')
    ORDER BY 3,
      4
    )
    LOOP
      -----------------------
      t_nextjobid           := e.jobid;
      IF t_previousjobid    IS NULL THEN
        t_previousjobid     := e.jobid;
        t_lines             := e.lines;
        t_counttemp         := 1;
        t_continue          := TRUE;
      ELSIF t_previousjobid != t_nextjobid THEN
        UPDATE pinkandgreenlicense_gt gt
        SET gt.othercount =
          CASE
            WHEN gt.othercount - t_counttemp > 0
            THEN gt.othercount - t_counttemp
            WHEN gt.othercount - t_counttemp <= 0
            THEN 0
          END
        WHERE gt.jobid        = t_previousjobid;
        t_previousjobid      := e.jobid;
        t_lines              := e.lines;
        t_counttemp          := 1;
        t_continue           := TRUE;
      ELSIF t_previousjobid   = t_nextjobid AND t_continue = TRUE THEN
        IF t_lines                          + e.lines <= 10 THEN
          t_lines            := t_lines     + e.lines;
          t_counttemp        := t_counttemp + 1;
        ELSE
          t_continue := FALSE;
        END IF;
      END IF;
    END LOOP; --End Other count Loop
    UPDATE pinkandgreenlicense_gt gt
    SET gt.othercount =
      CASE
        WHEN gt.othercount - t_counttemp > 0
        THEN gt.othercount - t_counttemp
        WHEN gt.othercount - t_counttemp <= 0
        THEN 0
      END
    WHERE gt.jobid = t_nextjobid;
  END;
/*--------------------------procedure GreenPinkLicense (a_objectid udt_id) is
t_ObjectDefId udt_id;
begin
select o.ObjectDefId
into t_ObjectDefId
from api.objects o
where o.objectid = a_Objectid;
if t_ObjectDefId = api.pkg_configquery.ObjectDefIdForName('p_PrintLicenseBulk') then
sitespecific.pkg_Reports.PrintLicenseBatch(a_objectid);
elsif t_ObjectDefId = api.pkg_configquery.ObjectDefIdForName('p_PrintLicense') then
sitespecific.pkg_Reports.PrintLicenseBatch(a_objectid); -- Change the package from Benjamin to the correct one
elsif t_ObjectDefId = api.pkg_configquery.ObjectDefIdForName('p_ProduceLicenses') then
sitespecific.pkg_Reports.ManualProduceLicense(a_objectid); -- Change the package from Benjamin to the correct one
end if;
--/* for c in (select * from sitespecific.Pinkandgreenlicense_Gt) loop
--   dbms_output.put_line(c.licensetypename || ' ' || c.dup_count);
-- end loop;*/
-- this is used for testing.
--end;
/*--------------------------
-- ManualProduceLicense() PUBLIC
-- This will load a GTT for the Green and Pink License Report
---------------------------*/
  PROCEDURE manualproducelicense(
      a_objectid udt_id)
  IS
    temp api.udt_objectlist;
    t_pagenumber    INTEGER := 1;
    t_licensenumber INTEGER;
    t_lines         INTEGER;
    t_counttemp     INTEGER;
    t_jobid         INTEGER;
    t_previousjobid INTEGER;
    t_nextjobid     INTEGER;
    t_continue      BOOLEAN;
  BEGIN
    DELETE pinkandgreenlicense_gt;
    -- Run SQL and either out it through a variable or place it directly into the GTT
    INSERT
    INTO pinkandgreenlicense_gt
      (
        licensetypename,
        licensee,
        lic_dba,
        mailingaddress4lines,
        effective_date,
        expirationdate,
        licensetypecode,
        licensenumber,
        dup_count,
        licensegeocode,
        district,
        prem_address,
        owner,
        condi,
        runid,
        batchtype,
        issue_type,
        iss_type_details,
        color,
        serialnumber,
        jobid,
        othercount,
        dupdescriptor
      )
    SELECT UPPER(lt.licensetypename) licensetypename,
      UPPER(li.primarylicensee) licensee,
      NVL2(li.dba, 'DBA: ', '')
      || UPPER(li.dba) lic_dba,
      UPPER(lt.mailingaddress4lines) mailingaddress4lines,
      r.validfromdate effective_date,
      TRUNC(lt.expirationdate) expirationdate,
      TO_CHAR(lt.licensetypecode) licensetypecode,
      li.licensenumber,
      NVL2(lt.masterlicensenumber, 1, NVL(lt.primarycount, NULL)) dup_count,
      lt.licensegeocode,
      LPAD(TO_CHAR(lt.district), 2, 0) district,
      UPPER( DECODE(lt.mailingaddress4lines, lt.premisesaddress4lines, NULL, lt.premisesaddress4lines)) prem_address,
      li.licenseenames owner,
      TRIM( ','
    FROM TRIM( ' '
    FROM DECODE(lt.conda, 'Y', 'A', NULL)
      || CHR(13)
      || DECODE(lt.condd, 'Y', 'D'
      || CHR(13), NULL)
      || DECODE(lt.conde, 'Y', 'E' --WO31613 Update License to print New condition E Pawan 4/28/2023
      || CHR (13), NULL)
      || DECODE(lt.condg, 'Y', 'G'
      || CHR(13), NULL) --  WO16291 Update License to print New condition G Pawan
      || DECODE(lt.condi, 'Y', 'I'
      || CHR(13), NULL)
      || DECODE(lt.condr, 'Y', 'R'
      || CHR(13), NULL)
      || DECODE(lt.condm, 'Y', 'M'
      || CHR(13), NULL) --  1/14/19 Sheik WO17107 Cond M  Update License to print New condition M
      || DECODE(lt.cond1c, 'Y', '1C'
      || CHR(13), NULL)
      || DECODE(lt.cond7, 'Y', '7'
      || CHR(13), NULL)
      || DECODE( lt.cond2, 'Y', '2'
      || NVL2( lt.conditionenddate, ' '
      || lt.conditionenddate, '')
      || CHR(13), NULL)
      || DECODE( lt.cond5, 'Y', '5'
      || NVL2( lt.conditionenddate, ' '
      || lt.conditionenddate, '')
      || CHR(13), NULL)
      || DECODE(lt.cond8, 'Y', '8'
      || CHR(13), NULL)
      || DECODE(lt.cond9, 'Y', '9'
      || CHR(13), NULL)
	  || lt.sectioncodelist --12/10/2019 TJL  20023  
	   )) condi,
      NULL runid,
      NULL batchtype,
      lt.typeofissuance issue_type,
      'ISSUE TYPE DETAILS' iss_type_details,
      p.color,
      p.serialnumber serialnumber,
      li.jobid,
      licenseecount othercount,
      NULL dupdescriptor
    FROM query.p_producelicenses p
    JOIN query.r_producelicenseslicensetype r
    ON r.producelicprocessid = p.processid
    JOIN query.j_licensetype lt
    ON lt.jobid = r.licensetypejobid
    JOIN query.r_licensetypeltcatprimary r2
    ON r2.licensetypejobid = lt.jobid
    JOIN query.o_licensetypecategory pltc
    ON pltc.objectid = r2.licensetypecategoryobjectid
    JOIN query.j_license li
    ON li.jobid         = p.jobid
    WHERE p.processid   = a_objectid
    AND pltc.color      = p.color
    AND (r.printlicense = 'Y') --Added r.PrintLicense='Y' to only load data that if they want to print it
    UNION ALL
    SELECT UPPER(ltc.licensetypename) licensetypename,
      UPPER(li.primarylicensee) licensee,
      NVL2(li.dba, 'DBA: ', '')
      || UPPER(li.dba) lic_dba,
      UPPER(lt.mailingaddress4lines) mailingaddress4lines,
      CASE
        WHEN TRUNC(do.readytoissuedate) >= TRUNC(lt.expirationdate)
        THEN ADD_MONTHS(pslt.validfromdate, 12)
        ELSE pslt.validfromdate
      END effective_date,
      CASE
        WHEN TRUNC(ltltcs.readytoissuedate) >= TRUNC(lt.expirationdate)
        THEN ADD_MONTHS(TRUNC(lt.expirationdate), 12)
        ELSE TRUNC(lt.expirationdate)
      END expirationdate,
      TO_CHAR(ltc.licensetypecode) licensetypecode,
      li.licensenumber,
      /*x.Column_Value*/
      do.dupnumber dup_count,
      lt.licensegeocode,
      LPAD(TO_CHAR(lt.district), 2, 0) district,
      UPPER( DECODE(lt.mailingaddress4lines, lt.premisesaddress4lines, NULL, lt.premisesaddress4lines)) prem_address,
      li.licenseenames owner,
      TRIM( ','
    FROM TRIM( ' '
    FROM DECODE(lt.conda, 'Y', 'A', NULL)
      || CHR(13)
      || DECODE(lt.condd, 'Y', 'D'
      || CHR(13), NULL)
      || DECODE(lt.conde, 'Y', 'E' --WO31613 Update License to print New condition E Pawan 4/28/2023
      || CHR (13), NULL)
      || DECODE(lt.condg, 'Y', 'G'
      || CHR(13), NULL) --  WO16291 Update License to print New condition G Pawan
      || DECODE(lt.condi, 'Y', 'I'
      || CHR(13), NULL)
      || DECODE(lt.condr, 'Y', 'R'
      || CHR(13), NULL)
      || DECODE(lt.condm, 'Y', 'M'
      || CHR(13), NULL) --  1/14/19 Sheik WO17107 Cond M  Update License to print New condition M
      || DECODE(lt.cond1c, 'Y', '1C'
      || CHR(13), NULL)
      || DECODE(lt.cond7, 'Y', '7'
      || CHR(13), NULL)
      || DECODE( lt.cond2, 'Y', '2'
      || NVL2( lt.conditionenddate, ' '
      || lt.conditionenddate, '')
      || CHR(13), NULL)
      || DECODE( lt.cond5, 'Y', '5'
      || NVL2( lt.conditionenddate, ' '
      || lt.conditionenddate, '')
      || CHR(13), NULL)
      || DECODE(lt.cond8, 'Y', '8'
      || CHR(13), NULL)
      || DECODE(lt.cond9, 'Y', '9'
      || CHR(13), NULL)
	  || lt.sectioncodelist --12/10/2019 TJL  20023 
	  )) condi,
      NULL runid,
      NULL batchtype,
      /*ltltcs.TypeofIssuance*/
      -- do.typeofissuance WO#17178 Sheik Commenting and adding below lines
      NVL(do.typeofissuance,ltltcs.TypeofIssuance) issue_type,
      'ISSUE TYPE DETAILS' iss_type_details,
      p.color,
      p.serialnumber serialnumber,
      li.jobid,
      licenseecount othercount,
      do.description dupdescriptor
    FROM query.p_producelicenses p
    JOIN query.j_license li
    ON li.jobid = p.jobid
    JOIN query.r_licenselicensetype lilt
    ON lilt.licensejobid = li.jobid
    JOIN query.j_licensetype lt
    ON lt.jobid = lilt.licensetypejobid
    JOIN query.r_licensetypeltcatsecondary ltltcs
    ON ltltcs.licensetypejobid = lt.jobid
    JOIN query.o_licensetypecategory ltc
    ON ltc.objectid = ltltcs.licensetypecategoryobjectid
    JOIN query.r_producelicenseltcatsecondary pllts
    ON pllts.producelicnesesprocessid = a_objectid
    JOIN query.o_pendingsecondarylicensetype pslt
    ON pslt.objectid = pllts.licensetypecategoryobjectid
    JOIN query.r_pslttoltc psltltc
    ON psltltc.pendingsecondaryltobjectid   = pslt.objectid
    AND psltltc.licensetypecategoryobjectid = ltc.objectid
    JOIN sitespecific.duplicate_t dt
    ON dt.relationshipid = ltltcs.relationshipid
    JOIN query.o_duplicate DO
    ON do.objectid = dt.duplicateid
      --cross join table(sitespecific.pkg_utils.GenerateRows(1,ltltcs.LicenseTypeCount)) x
    WHERE p.processid      = a_objectid
    AND ltc.color          = p.color
    AND (pslt.printlicense = 'Y');
    FOR c IN
    (SELECT pgl.licensenumber,
      pgl.licensee,
      pgl.licensetypecode,
      pgl.dup_count,
      pgl.ROWID
    FROM pinkandgreenlicense_gt pgl
    ORDER BY 2,
      1,
      3,
      4 NULLS FIRST
    )
    LOOP
      IF t_licensenumber != c.licensenumber THEN
        t_pagenumber     := 1;
      END IF;
      UPDATE pinkandgreenlicense_gt t
      SET t.pagenumber = t_pagenumber
      WHERE t.ROWID    = c.ROWID;
      t_pagenumber    := t_pagenumber + 1;
      t_licensenumber := c.licensenumber;
    END LOOP; --End Page Number Loop
    t_jobid := api.pkg_columnquery.VALUE(a_objectid, 'JobId');
    FOR e IN
    (SELECT LENGTH(le.formattedname) namelength,
      CEIL(LENGTH(le.formattedname) / g_ownerlinelength) lines,
      r.toobjectid jobid
    FROM api.relationships r
    JOIN query.o_legalentity le
    ON le.objectid           = r.fromobjectid
    WHERE r.toobjectid       = t_jobid
    AND (r.relationshipdefid = api.pkg_configquery.objectdefidforname( 'r_LicenseP12LegalEntity')
    OR r.relationshipdefid   = api.pkg_configquery.objectdefidforname( 'r_LicenseLegalEntityLicensee'))
    ORDER BY r.toobjectid,
      le.sortcolumn
    )
    LOOP
      t_nextjobid           := e.jobid;
      IF t_previousjobid    IS NULL THEN
        t_previousjobid     := e.jobid;
        t_lines             := e.lines;
        t_counttemp         := 1;
        t_continue          := TRUE;
      ELSIF t_previousjobid != t_nextjobid THEN
        UPDATE pinkandgreenlicense_gt gt
        SET gt.othercount =
          CASE
            WHEN gt.othercount - t_counttemp > 0
            THEN gt.othercount - t_counttemp
            WHEN gt.othercount - t_counttemp <= 0
            THEN 0
          END
        WHERE gt.jobid        = t_previousjobid;
        t_previousjobid      := e.jobid;
        t_lines              := e.lines;
        t_counttemp          := 1;
        t_continue           := TRUE;
      ELSIF t_previousjobid   = t_nextjobid AND t_continue = TRUE THEN
        IF t_lines                          + e.lines <= 10 THEN
          t_lines            := t_lines     + e.lines;
          t_counttemp        := t_counttemp + 1;
        ELSE
          t_continue := FALSE;
        END IF;
      END IF;
    END LOOP; --End Other count Loop
    UPDATE pinkandgreenlicense_gt gt
    SET gt.othercount =
      CASE
        WHEN gt.othercount - t_counttemp > 0
        THEN gt.othercount - t_counttemp
        WHEN gt.othercount - t_counttemp <= 0
        THEN 0
      END
    WHERE gt.jobid = t_nextjobid;
  END;
/*--------------------------------------------------------------
-Owners Report is called from the license report nested data
-window to return only the amount of rows that can be fully
-rendered
----------------------------------------------------------------*/
  FUNCTION ownerreport(
      a_jobid udt_id)
    RETURN extension.udst_stringlist
  IS
    t_legalentitys extension.udst_stringlist;
    t_indexlf    NUMBER;
    t_index      NUMBER;
    t_nextindex  NUMBER;
    t_position   NUMBER;
    t_continue   BOOLEAN;
    t_text       VARCHAR2(4000);
    t_lines      NUMBER  := 0;
    t_max        BOOLEAN := FALSE;
    t_linelength NUMBER  := g_ownerlinelength;
    t_begpos     NUMBER  := 1;
    t_endpos     NUMBER  := 35;
    t_line       VARCHAR2(4000);
    t_length     NUMBER;
    t_temptext   VARCHAR2(4000);
  BEGIN
    t_position     := 1;
    t_legalentitys := extension.udst_stringlist();
    FOR c IN
    (SELECT le.formattedname,
      LENGTH(le.formattedname) namelength,
      CEIL(LENGTH(le.formattedname) / t_linelength) lines
    FROM api.relationships r
    JOIN query.o_legalentity le
    ON le.objectid           = r.fromobjectid
    WHERE r.toobjectid       = a_jobid
    AND (r.relationshipdefid = api.pkg_configquery.objectdefidforname( 'r_LicenseP12LegalEntity')
    OR r.relationshipdefid   = api.pkg_configquery.objectdefidforname( 'r_LicenseLegalEntityLicensee'))
    ORDER BY le.sortcolumn
    )
    LOOP
      t_text        := c.formattedname;
      IF t_text     IS NOT NULL THEN
        t_index     := 0;
        t_position  := 1;
        t_nextindex := 1;
        t_continue  := TRUE;
        t_begpos    := 1;
        --If the Next Name is larger then the lines left return
        IF c.namelength > ((10 - t_lines) * t_linelength) THEN
          RETURN t_legalentitys;
        END IF;
        t_length                 := LENGTH(t_text);
        WHILE t_length - t_begpos > 35
        LOOP
          t_temptext  := SUBSTR(t_text, t_begpos, 36);
          t_endpos    := INSTR(t_temptext, ' ', -1, 1);
          IF (t_endpos = 0) THEN
            t_endpos  := 35;
          END IF;
          t_legalentitys.EXTEND(1);
          t_legalentitys(t_legalentitys.COUNT) := LTRIM(SUBSTR(t_temptext, 1, t_endpos));
          t_begpos                             := t_endpos + t_begpos;
        END LOOP;
        t_legalentitys.EXTEND(1);
        t_legalentitys(t_legalentitys.COUNT) := LTRIM(SUBSTR(t_text, t_begpos));
      END IF;
    END LOOP;
    RETURN t_legalentitys;
  END ownerreport;
/*--------------------------
-- RenewalListReport() PUBLIC
-- This will load a GTT for the Renewal List report.
-- The Finacial section is based on the Accounting History Report
---------------------------*/
  PROCEDURE renewallistreport(
      a_juliandate VARCHAR2)
  IS
    t_ptobjectlist api.udt_objectlist;
    t_grnrunid VARCHAR2(4000)   := 'GRN' || a_juliandate;
    t_pnkrunid VARCHAR2(4000)   := 'PNK' || a_juliandate;
    t_paymentobjectdefid udt_id := api.pkg_configquery.objectdefidforname('o_Payment');
  BEGIN
    DELETE sitespecific.renewallistmain_gt;
    INSERT INTO sitespecific.renewallistmain_gt
    SELECT jl.jobid,
      jlt.jobid,
      jlb.completeddate,
      jlb.runid,
      jlt.licensenumber filenum,
      jlt.licensetypecode lictype,
      NULL dupcount,
      jlt.typeofissuance,
      DECODE(st.statusdate, NULL, st.effectivestartdate, st.statusdate) effective_date,
      jlt.expirationdate expiredate,
      jlt.primarylicensee primaryname
    FROM query.j_licensebatch jlb
    JOIN sitespecific.licbatchlictype_xref_t rltb
    ON rltb.licensebatchjobid = jlb.jobid
    JOIN query.j_licensetype jlt
    ON jlt.jobid = rltb.licensetypejobid
    JOIN query.r_licenselicensetype rllt
    ON rllt.licensetypejobid = jlt.jobid
    JOIN query.j_license jl
    ON jl.jobid = rllt.licensejobid
    JOIN extension.jobstatuschange st
    ON jlt.jobid        = st.jobid
    WHERE jlb.batchtype = 'PRODUCE LICENSES'
    AND st.mostrecent   = 'Y'
    AND st.statusname  IN ('ACTIVE')
    AND jlb.runid      IN (t_grnrunid, t_pnkrunid)
    AND jlb.color       = jlt.color
    UNION ALL
    SELECT jl.jobid,
      jlt.jobid,
      jlb.completeddate,
      jlb.runid,
      jlt.licensenumber filenum,
      oltc.licensetypecode lictype,
      slt.licensetypecount dupcount,
      jlt.typeofissuance,
      DECODE(st.statusdate, NULL, st.effectivestartdate, st.statusdate) effective_date,
      jlt.expirationdate expiredate,
      jlt.primarylicensee primaryname
    FROM query.j_licensebatch jlb
    JOIN sitespecific.licbatchlictype_xref_t rltb
    ON rltb.licensebatchjobid = jlb.jobid
    JOIN query.j_licensetype jlt
    ON jlt.jobid = rltb.licensetypejobid
    JOIN query.r_licenselicensetype rllt
    ON rllt.licensetypejobid = jlt.jobid
    JOIN query.j_license jl
    ON jl.jobid = rllt.licensejobid
    JOIN extension.jobstatuschange st
    ON jlt.jobid = st.jobid
    JOIN query.r_licensetypeltcatsecondary slt
    ON slt.licensetypejobid = jlt.jobid
    JOIN query.o_licensetypecategory oltc
    ON oltc.objectid    = slt.licensetypecategoryobjectid
    WHERE jlb.batchtype = 'PRODUCE LICENSES'
    AND st.mostrecent   = 'Y'
    AND st.statusname  IN ('ACTIVE')
    AND jlb.runid      IN (t_grnrunid, t_pnkrunid)
    AND jlb.color       = oltc.color;
    FOR main IN
    (SELECT DISTINCT (m.licjobid) jobid FROM sitespecific.renewallistmain_gt m
    )
    LOOP
      sitespecific.pkg_fees.getpaymenttransactionsforjob( main.jobid, NULL, t_ptobjectlist);
      FOR c IN 1 .. t_ptobjectlist.COUNT
      LOOP
        INSERT INTO sitespecific.renewallistaccounting_gt
        SELECT main.jobid,
          fs.licensetypecode amttype,
          qpt.ismaster mi,
          qpt.secondarycount amtdup,
          NVL( api.pkg_columnquery.VALUE( pkg_fees.getlicfeeschedulobjid(ft.feeid), 'FeeCode'), 'NA') feecode,
          CASE
            WHEN qpt.isservicecharge = 'Y'
            THEN 'SRV'
            WHEN qpt.isoverpayment = 'Y'
            THEN 'OVR'
            ELSE fs.description
          END transcode,
          ft.amount * -1 amount,
          api.pkg_columnquery.datevalue(qpt.objectid, 'TransactionDate') paiddate,
          api.pkg_columnquery.datevalue(qpt.objectid, 'TransactionDate') entrydate,
          CASE
            WHEN (SELECT COUNT(*)
              FROM api.relationships r
              WHERE r.fromobjectid = reo.objectid
              AND r.endpointid    IN (api.pkg_configquery.endpointidforname( 'o_Payment', 'PaymentTransferAdjust'), api.pkg_configquery.endpointidforname( 'o_Payment', 'PaymentTransferTo'))) > 0
            THEN 'C'
            WHEN (SELECT COUNT(*)
              FROM api.relationships r
              WHERE r.fromobjectid   = reo.objectid
              AND r.endpointid       = api.pkg_configquery.endpointidforname( 'o_Payment', 'RefundCheck')) > 0
            AND qpt.isservicecharge != 'Y'
            THEN 'R'
            WHEN (SELECT COUNT(*)
              FROM api.relationships r
              WHERE r.fromobjectid = reo.objectid
              AND r.endpointid     = api.pkg_configquery.endpointidforname( 'o_Payment', 'VoidPayment')) > 0
            THEN 'V'
            ELSE 'I'
          END rt,
          qpt.transactiondate amtearneddate
        FROM query.o_paymenttransactions qpt
        JOIN api.paymenttransactions pt
        ON pt.transactionid = qpt.transactionid
        JOIN api.registeredexternalobjects reo --TAyers: PIP Task 8.5
        ON reo.linkvalue    = TO_CHAR(pt.paymentid)
        AND reo.objectdefid = t_paymentobjectdefid
        JOIN api.feetransactions ft
        ON ft.transactionid = pt.transactionid
        JOIN sitespecific.feeschedule_t fs
        ON fs.objectid          = pkg_fees.getlicfeeschedulobjid(ft.feeid)
        WHERE qpt.objectid      = t_ptobjectlist(c).objectid
        AND qpt.transactiondate > ADD_MONTHS(SYSDATE, -24)
        AND fs.feeactivity NOT                       IN ('BALFWD', 'CABCON', 'POIC', 'CATA', '583', 'CAT', 'BKR', 'BKT');
        INSERT INTO sitespecific.renewallistaccounting_gt
        SELECT main.jobid,
          fs.licensetypecode amttype,
          qpt.ismaster mi,
          qpt.secondarycount amtdup,
          NVL( api.pkg_columnquery.VALUE( pkg_fees.getlicfeeschedulobjid(ft.feeid), 'FeeCode'), 'NA') feecode,
          CASE
            WHEN qpt.isservicecharge = 'Y'
            THEN 'SRV'
            WHEN qpt.isoverpayment = 'Y'
            THEN 'OVR'
            ELSE fs.description
          END transcode,
          CASE
            WHEN api.pkg_columnquery.VALUE( pspt.paymentstatusobjectid, 'Status') = 'EARNED'
            THEN ft.amount * 1
            ELSE ft.amount * -1
          END amount,
          api.pkg_columnquery.datevalue(qpt.objectid, 'TransactionDate') paiddate,
          api.pkg_columnquery.datevalue(qpt.objectid, 'TransactionDate') entrydate,
          CASE
            WHEN api.pkg_columnquery.VALUE( pspt.paymentstatusobjectid, 'SystemGenerated') = 'Y'
            THEN 'G'
            ELSE 'A'
          END i,
          api.pkg_columnquery.datevalue( qpt.paymentstatusobjectid, 'StatusDate') amtearneddate
        FROM query.o_paymenttransactions qpt
        JOIN api.paymenttransactions pt
        ON pt.transactionid = qpt.transactionid
        JOIN api.registeredexternalobjects reo --TAyers: PIP Task 8.5
        ON reo.linkvalue    = TO_CHAR(pt.paymentid)
        AND reo.objectdefid = t_paymentobjectdefid
        JOIN api.feetransactions ft
        ON ft.transactionid = pt.transactionid
        JOIN sitespecific.feeschedule_t fs
        ON fs.objectid = pkg_fees.getlicfeeschedulobjid(ft.feeid)
        JOIN query.r_paymentstatuspaymenttrans pspt
        ON pspt.paymenttransactionobjectid = qpt.objectid
        WHERE qpt.objectid                 = t_ptobjectlist(c).objectid
        AND qpt.transactiondate            > ADD_MONTHS(SYSDATE, -24)
        AND fs.feeactivity NOT                                  IN ('BALFWD', 'CABCON', 'POIC', 'CATA', '583', 'CAT', 'BKR', 'BKT');
      END LOOP; --PaymentTransactions loop
    END LOOP;   --Main Loop
  END renewallistreport;
/*-------------------------------------------------------------------------
* AccountingHistoryReport() - Public
* This procedure inserts rows into sitespecific.accountinghistory_gt
* for the Accounting history report that is run in Outrider for
* a License or Application.
*------------------------------------------------------------------------*/
  PROCEDURE accountinghistoryreport(
      a_objectid udt_id)
  IS
    t_ptobjectlist api.udt_objectlist;
    t_maxptdate DATE;
    t_feeobjectlist api.udt_objectlist;
    t_maxptobjectid NUMBER;
    t_feeobjectdefid udt_id     := api.pkg_configquery.objectdefidforname('o_Fee');
    t_paymentobjectdefid udt_id := api.pkg_configquery.objectdefidforname('o_Payment');
  BEGIN
    --clear the Global Temp Table (GTT) for this session
    DELETE sitespecific.accountinghistoryreport_gt;
    --Grab the Payment Transactions for this License
    sitespecific.pkg_reports.getpaytransforacchist(a_objectid, NULL, t_ptobjectlist);
    --Grab the Most Recent Payment Transaction Date of Payments Related to this report
    SELECT MAX(objectid)
    INTO t_maxptobjectid
    FROM TABLE(CAST(t_ptobjectlist AS api.udt_objectlist));
    SELECT MAX(alt.createddate)
    INTO t_maxptdate
    FROM query.o_paymenttransactions ap
    JOIN api.feetransactions aft
    ON aft.transactionid = ap.transactionid
    JOIN api.logicaltransactions alt
    ON alt.logicaltransactionid = aft.logicaltransactionid
    WHERE ap.objectid           = t_maxptobjectid;
    --dbms_output.put_line(t_MaxPTDate );
    --Grab the $0.00 Dollar Fees to Relate to this report
    sitespecific.pkg_reports.getzerodollarfeesforacchist(a_objectid, t_maxptdate, t_feeobjectlist);
    --loop through the Payment Transactions for this report
    FOR c IN 1 .. t_ptobjectlist.COUNT
    LOOP
      --inserting into the GTT
      INSERT INTO sitespecific.accountinghistoryreport_gt
      SELECT api.pkg_columnquery.VALUE(f.jobid, 'LicenseNumber') licnum,
        CASE
          WHEN api.pkg_columnquery.VALUE(f.jobid, 'JobTypeId') = api.pkg_configquery.objectdefidforname( 'j_License')
          THEN SUBSTR( api.pkg_columnquery.VALUE(f.jobid, 'StatusName'), 1, 3)
          ELSE NVL(
            (SELECT DECODE( SUBSTR( api.pkg_columnquery.VALUE( r1.toobjectid, 'StatusName'), 1, 3), 'ISS', 'PEN', SUBSTR( api.pkg_columnquery.VALUE( f.jobid, 'StatusName'), 1, 3))
            FROM api.relationships r1
            WHERE r1.fromobjectid = f.jobid
            AND r1.endpointid     = (api.pkg_configquery.endpointidforname( 'j_Application', 'License'))
            ), DECODE( SUBSTR( api.pkg_columnquery.VALUE( f.jobid, 'StatusName'), 1, 3), 'ISS', 'PEN', SUBSTR( api.pkg_columnquery.VALUE( f.jobid, 'StatusName'), 1, 3)))
        END status,
        DECODE(st.statusdate, NULL, st.effectivestartdate, st.statusdate) statusdate,
        NVL( api.pkg_columnquery.VALUE( f.jobid, 'BaseFileOfficeCodeCorral'), api.pkg_columnquery.VALUE(f.jobid, 'DistrictOfficeCode')) district,
        NVL( api.pkg_columnquery.VALUE(f.jobid, 'PremAddress1Line'), api.pkg_columnquery.VALUE(f.jobid, 'EventLocAddressLine1')) premises,
        api.pkg_columnquery.VALUE(f.jobid, 'PrimaryLicensee') "NAME",
        api.pkg_columnquery.datevalue(qpt.objectid, 'TransactionDate') entrydate,
        qpt.cabinamttype i,
        CASE
          WHEN qpt.isoverpayment = 'Y'
          THEN 'OVR'
          WHEN qpt.isservicecharge = 'Y'
          THEN 'SRV'
          ELSE fs.description
        END trans,
        fs.licensetypecode lt,
        qpt.ismaster m,
        qpt.secondarycount dup,
        CASE
          WHEN qpt.cabinamttype = 'V' --the purpose of this is that a payment that has been voided should show up as zero instead of the original value
          THEN 0
          ELSE ft.amount * -1
        END amount,
        NVL(p.payeereference, qpt.hqreceipt) paymentid,
        p.receiptnumber recnum,
        api.pkg_columnquery.datevalue(qpt.objectid, 'TransactionDate') paiddate,
        f.jobid,
        NVL( api.pkg_columnquery.VALUE( sitespecific.pkg_fees.getlicfeeschedulobjid( ft.feeid), 'FeeCode'), 'NA') feecode,
        ft.transactionid,
        qpt.legacykey sortcolumn1,
        qpt.objectid sortcolumn2,
        NULL
      FROM query.o_paymenttransactions qpt
      JOIN api.payments p
      ON p.paymentid = qpt.paymentid
      JOIN api.registeredexternalobjects reo --TAyers: PIP Task 8.5
      ON reo.linkvalue    = TO_CHAR(p.paymentid)
      AND reo.objectdefid = t_paymentobjectdefid
      JOIN api.feetransactions ft
      ON ft.transactionid = qpt.transactionid
      JOIN api.fees f
      ON f.feeid = ft.feeid
      JOIN sitespecific.feeschedule_t fs
      ON fs.objectid = sitespecific.pkg_fees.getlicfeeschedulobjid( ft.feeid)
      JOIN extension.jobstatuschange st
      ON st.jobid        = f.jobid
      AND st.mostrecent  = 'Y'
      WHERE qpt.objectid = t_ptobjectlist(c).objectid;
      --get the payment status rows
      INSERT INTO accountinghistoryreport_gt
      SELECT api.pkg_columnquery.VALUE(f.jobid, 'LicenseNumber') licnum,
        CASE
          WHEN api.pkg_columnquery.VALUE(f.jobid, 'JobTypeId') = api.pkg_configquery.objectdefidforname( 'j_License')
          THEN SUBSTR( api.pkg_columnquery.VALUE(f.jobid, 'StatusName'), 1, 3)
          ELSE NVL(
            (SELECT DECODE( SUBSTR( api.pkg_columnquery.VALUE( r1.toobjectid, 'StatusName'), 1, 3), 'ISS', 'PEN', SUBSTR( api.pkg_columnquery.VALUE( f.jobid, 'StatusName'), 1, 3))
            FROM api.relationships r1
            WHERE r1.fromobjectid = f.jobid
            AND r1.endpointid     = (api.pkg_configquery.endpointidforname( 'j_Application', 'License'))
            ), DECODE( SUBSTR( api.pkg_columnquery.VALUE( f.jobid, 'StatusName'), 1, 3), 'ISS', 'PEN', SUBSTR( api.pkg_columnquery.VALUE( f.jobid, 'StatusName'), 1, 3)))
        END status,
        DECODE(st.statusdate, NULL, st.effectivestartdate, st.statusdate) statusdate,
        NVL( api.pkg_columnquery.VALUE( f.jobid, 'BaseFileOfficeCodeCorral'), api.pkg_columnquery.VALUE(f.jobid, 'DistrictOfficeCode')) district,
        NVL( api.pkg_columnquery.VALUE(f.jobid, 'PremAddress1Line'), api.pkg_columnquery.VALUE(f.jobid, 'EventLocAddressLine1')) premises,
        api.pkg_columnquery.VALUE(f.jobid, 'PrimaryLicensee') "NAME",
        TRUNC( api.pkg_columnquery.datevalue(r.toobjectid, 'CreatedDate')) entrydate,
        CASE
          WHEN api.pkg_columnquery.VALUE(r.toobjectid, 'SystemGenerated') = 'Y'
          THEN 'G'
          ELSE 'A'
        END i,
        CASE
          WHEN qpt.isoverpayment = 'Y'
          THEN 'OVR'
          WHEN qpt.isservicecharge = 'Y'
          THEN 'SRV'
          ELSE api.pkg_columnquery.VALUE(r.toobjectid, 'TransactionCode')
        END trans,
        api.pkg_columnquery.VALUE(r.toobjectid, 'LicenseTypeCode') lt,
        api.pkg_columnquery.VALUE(r.toobjectid, 'IsMaster') m,
        api.pkg_columnquery.VALUE(r.toobjectid, 'SecondaryCount') dup,
        api.pkg_columnquery.numericvalue(r.toobjectid, 'EarnedAmount') earnedamount,
        NULL paymentid,
        NULL recnum,
        TRUNC( api.pkg_columnquery.datevalue(r.toobjectid, 'StatusDate')) paiddate,
        f.jobid,
        NVL( api.pkg_columnquery.VALUE(r.toobjectid, 'FeeCode'), 'NA') feecode,
        ft.transactionid,
        api.pkg_columnquery.numericvalue(r.toobjectid, 'LegacyKey') sortcolumn1,
        r.toobjectid sortcolumn2,
        NULL
      FROM query.o_paymenttransactions qpt
      JOIN api.paymenttransactions pt
      ON pt.transactionid = qpt.transactionid
      JOIN api.relationships r
      ON r.fromobjectid = qpt.objectid
      AND r.endpointid  = api.pkg_configquery.endpointidforname( 'o_PaymentTransactions', 'PaymentStatus')
      JOIN api.feetransactions ft
      ON ft.transactionid = pt.transactionid
      JOIN api.fees f
      ON f.feeid = ft.feeid
      JOIN sitespecific.feeschedule_t fs
      ON fs.objectid = sitespecific.pkg_fees.getlicfeeschedulobjid( ft.feeid)
      JOIN extension.jobstatuschange st
      ON st.jobid        = f.jobid
      AND st.mostrecent  = 'Y'
      WHERE qpt.objectid = t_ptobjectlist(c).objectid;
    END LOOP;
    --Get The $0.00 Dollar Fee Rows
    FOR d IN 1 .. t_feeobjectlist.COUNT
    LOOP
      INSERT INTO sitespecific.accountinghistoryreport_gt
      SELECT api.pkg_columnquery.VALUE(af.jobid, 'LicenseNumber') licnum,
        CASE
          WHEN api.pkg_columnquery.VALUE(af.jobid, 'JobTypeId') = api.pkg_configquery.objectdefidforname( 'j_License')
          THEN SUBSTR( api.pkg_columnquery.VALUE(af.jobid, 'StatusName'), 1, 3)
          ELSE NVL(
            (SELECT DECODE( SUBSTR( api.pkg_columnquery.VALUE( r1.toobjectid, 'StatusName'), 1, 3), 'ISS', 'PEN', SUBSTR( api.pkg_columnquery.VALUE( af.jobid, 'StatusName'), 1, 3))
            FROM api.relationships r1
            WHERE r1.fromobjectid = af.jobid
            AND r1.endpointid     = (api.pkg_configquery.endpointidforname( 'j_Application', 'License'))
            ), DECODE( SUBSTR( api.pkg_columnquery.VALUE( af.jobid, 'StatusName'), 1, 3), 'ISS', 'PEN', SUBSTR( api.pkg_columnquery.VALUE( af.jobid, 'StatusName'), 1, 3)))
        END status,
        DECODE(st.statusdate, NULL, st.effectivestartdate, st.statusdate) statusdate,
        NVL( api.pkg_columnquery.VALUE( af.jobid, 'BaseFileOfficeCodeCorral'), api.pkg_columnquery.VALUE(af.jobid, 'DistrictOfficeCode')) district,
        NVL( api.pkg_columnquery.VALUE(af.jobid, 'PremAddress1Line'), api.pkg_columnquery.VALUE(af.jobid, 'EventLocAddressLine1')) premises,
        api.pkg_columnquery.VALUE(af.jobid, 'PrimaryLicensee') "NAME",
        af.transactiondate entrydate,
        'I' i,
        fs.description trans,
        fs.licensetypecode lt,
        api.pkg_columnquery.VALUE(reo.objectid, 'IsMaster') m,
        NVL( api.pkg_columnquery.VALUE(reo.objectid, 'SecondaryCount'), 0) dup,
        0 amount,
        api.pkg_columnquery.VALUE(reo.objectid, 'HQReceipt') paymentid,
        NULL recnum,
        af.transactiondate paiddate,
        af.jobid,
        NVL( api.pkg_columnquery.VALUE( sitespecific.pkg_fees.getlicfeeschedulobjid( af.feeid), 'FeeCode'), 'NA') feecode,
        af.feeid,
        NULL sortcolumn1,         --The is no Legacy Key on a Fee
        reo.objectid sortcolumn2, --ObjectId of the Fee
        NULL
      FROM api.fees af
      JOIN api.registeredexternalobjects reo -- RyanL: PIP Task 8.5
      ON reo.linkvalue    = TO_CHAR(af.feeid)
      AND reo.objectdefid = t_feeobjectdefid
      JOIN sitespecific.feeschedule_t fs
      ON fs.objectid = sitespecific.pkg_fees.getlicfeeschedulobjid( af.feeid)
      JOIN extension.jobstatuschange st
      ON st.jobid       = af.jobid
      AND st.mostrecent = 'Y'
      WHERE af.feeid    = t_feeobjectlist(d).objectid;
    END LOOP;
    FOR e IN
    (SELECT r.toobjectid jobid
    FROM api.relationships r
    WHERE r.endpointid = (api.pkg_configquery.endpointidforname( 'j_License', 'ApplicationLicense'))
    AND r.fromobjectid = a_objectid
    UNION
    SELECT a_objectid jobid FROM DUAL
    )
    LOOP
      -- Add any Historical correction records to the report
      INSERT
      INTO sitespecific.accountinghistoryreport_gt
      SELECT api.pkg_columnquery.VALUE(a_objectid, 'LicenseNumber') licnum,
        CASE
          WHEN api.pkg_columnquery.VALUE(a_objectid, 'JobTypeId') = api.pkg_configquery.objectdefidforname( 'j_License')
          THEN SUBSTR( api.pkg_columnquery.VALUE(a_objectid, 'StatusName'), 1, 3)
          ELSE NVL(
            (SELECT DECODE( SUBSTR( api.pkg_columnquery.VALUE( r1.toobjectid, 'StatusName'), 1, 3), 'ISS', 'PEN', SUBSTR( api.pkg_columnquery.VALUE( a_objectid, 'StatusName'), 1, 3))
            FROM api.relationships r1
            WHERE r1.fromobjectid = a_objectid
            AND r1.endpointid     = (api.pkg_configquery.endpointidforname( 'j_Application', 'License'))
            ), DECODE( SUBSTR( api.pkg_columnquery.VALUE( a_objectid, 'StatusName'), 1, 3), 'ISS', 'PEN', SUBSTR( api.pkg_columnquery.VALUE( a_objectid, 'StatusName'), 1, 3)))
        END status,
        DECODE(st.statusdate, NULL, st.effectivestartdate, st.statusdate) statusdate,
        NVL( api.pkg_columnquery.VALUE( a_objectid, 'BaseFileOfficeCodeCorral'), api.pkg_columnquery.VALUE(a_objectid, 'DistrictOfficeCode')) district,
        NVL( api.pkg_columnquery.VALUE(a_objectid, 'PremAddress1Line'), api.pkg_columnquery.VALUE(a_objectid, 'EventLocAddressLine1')) premises,
        api.pkg_columnquery.VALUE(a_objectid, 'PrimaryLicensee') "NAME",
        hc.paymentdate entrydate, -- For sorting, we'll use the Payment Date
        hc.incomecode i,
        hc.feedescription trans,
        hc.licensetypecode lt,
        hc.ismaster m,
        hc.secondarycount dup,
        hc.paymentamount amount,
        NVL(TO_CHAR(hc.paymentid), hc.hqreceipt) paymentid,
        hc.receiptnumber recnum,
        hc.paymentdate paiddate,
        a_objectid,
        NVL(hc.feecode, 'NA') feecode,
        NULL feeid,       -- We don't have a Fee Id
        NULL sortcolumn1, -- We don't have a legacy key
        hc.objectid sortcolumn2,
        '*'
      FROM query.o_historicalcorrection hc
      JOIN api.relationships re
      ON re.fromobjectid = hc.objectid
      JOIN extension.jobstatuschange st
      ON st.jobid         = a_objectid
      AND st.mostrecent   = 'Y'
      WHERE re.toobjectid = e.jobid;
    END LOOP;
  END accountinghistoryreport;
--*------------------------------------------------------------------------------------------------
--* GetPayTransForAccHist() -- PUBLIC
--* This procedure is getting the valid Payment Transactions for the Accounting History Report
--*------------------------------------------------------------------------------------------------
  PROCEDURE getpaytransforacchist(
      a_objectid udt_id,
      a_endpointid udt_id,
      a_relatedobjectids OUT api.udt_objectlist)
  IS
    t_jobtypename VARCHAR2(25);
    t_jobtypeid udt_id;
    t_paytransobjectdefid udt_id := api.pkg_configquery.objectdefidforname( 'o_PaymentTransactions');
  BEGIN
    a_relatedobjectids := api.udt_objectlist();
    SELECT od.name
    INTO t_jobtypename
    FROM api.objects o
    JOIN api.objectdefs od
    ON od.objectdefid = o.objectdefid
    WHERE o.objectid  = a_objectid;
    t_jobtypeid      := api.pkg_configquery.objectdefidforname(t_jobtypename);
    --starting from job that I am on, get the PTs related to it.
    FOR a IN
    (SELECT reo.objectid
    FROM api.jobs j
    JOIN api.fees f
    ON f.jobid = j.jobid
    JOIN api.feetransactions ft
    ON ft.feeid = f.feeid
    JOIN api.registeredexternalobjects reo --TAyers: PIP Task 8.5
    ON reo.linkvalue    = TO_CHAR(ft.transactionid)
    AND reo.objectdefid = t_paytransobjectdefid
    WHERE j.jobid       = a_objectid
    )
    LOOP
      a_relatedobjectids.EXTEND(1);
      a_relatedobjectids(a_relatedobjectids.COUNT) := api.udt_object(a.objectid);
    END LOOP;
    --if it is an app then end the procedure because the procedure has already gotten all of the possible PTs.
    --In the config, if the Application is issued this procedure will only be run from a License
    IF (t_jobtypeid = api.pkg_configquery.objectdefidforname('j_Application') OR t_jobtypeid = api.pkg_configquery.objectdefidforname('j_OneDayLicense')) THEN
      RETURN;
    ELSE
      --it is a license and walk through rels from license
      --starting from Lic job get PTs from other job, App
      FOR l IN
      (SELECT reo.objectid
      FROM api.jobs j
      JOIN api.relationships r
      ON r.fromobjectid = j.jobid
        /* and r.EndPointId =
        (api.pkg_configquery.EndPointIdForName('j_License',
        'ApplicationLicense')) commented and changed by Pawan on 5/18/2016 issue- 9525
        */
      AND r.endpointid IN (api.pkg_configquery.endpointidforname( 'j_License', 'ApplicationLicense'), api.pkg_configquery.endpointidforname( 'j_License', 'ApplicationTransferFrom'))
      JOIN api.fees f
      ON f.jobid = r.toobjectid
      JOIN api.feetransactions ft
      ON ft.feeid = f.feeid
      JOIN api.registeredexternalobjects reo --TAyers: PIP Task 8.5
      ON reo.linkvalue    = TO_CHAR(ft.transactionid)
      AND reo.objectdefid = t_paytransobjectdefid
      WHERE j.jobid       = a_objectid
      )
      LOOP
        a_relatedobjectids.EXTEND(1);
        a_relatedobjectids(a_relatedobjectids.COUNT) := api.udt_object(l.objectid);
        --dbms_output.put_line(l.objectid);
      END LOOP;
      --starting from License get LT PTs
      FOR llt IN
      (SELECT reo.objectid
      FROM api.relationships r
      JOIN api.fees f
      ON f.jobid = r.toobjectid
      JOIN api.feetransactions ft
      ON ft.feeid = f.feeid
      JOIN api.registeredexternalobjects reo --TAyers: PIP Task 8.5
      ON reo.linkvalue     = TO_CHAR(ft.transactionid)
      AND reo.objectdefid  = t_paytransobjectdefid
      WHERE r.fromobjectid = a_objectid
      AND r.endpointid     = api.pkg_configquery.endpointidforname( 'j_License', 'LicenseType')
      )
      LOOP
        a_relatedobjectids.EXTEND(1);
        a_relatedobjectids(a_relatedobjectids.COUNT) := api.udt_object(llt.objectid);
        --dbms_output.put_line(llt.objectid);
      END LOOP;
      --starting from lic get inv PTs
      FOR li IN
      (SELECT reo.objectid
      FROM api.relationships r1
      JOIN api.fees f
      ON f.jobid = r1.toobjectid
      JOIN api.feetransactions ft
      ON ft.feeid = f.feeid
      JOIN api.registeredexternalobjects reo --TAyers: PIP Task 8.5
      ON reo.linkvalue      = TO_CHAR(ft.transactionid)
      AND reo.objectdefid   = t_paytransobjectdefid
      WHERE r1.fromobjectid = a_objectid
      AND r1.endpointid     = api.pkg_configquery.endpointidforname( 'j_License', 'Investigation')
      )
      LOOP
        a_relatedobjectids.EXTEND(1);
        a_relatedobjectids(a_relatedobjectids.COUNT) := api.udt_object(li.objectid);
        --dbms_output.put_line(li.objectid);
      END LOOP;
      --starting from lic get Acc PTs through inv
      FOR la IN
      (SELECT reo.objectid
      FROM api.relationships r1
      JOIN api.relationships r2
      ON r2.fromobjectid = r1.toobjectid
      AND r2.endpointid  = api.pkg_configquery.endpointidforname( 'j_Investigation', 'Accusation')
      JOIN api.fees f
      ON f.jobid = r2.toobjectid
      JOIN api.feetransactions ft
      ON ft.feeid = f.feeid
      JOIN api.registeredexternalobjects reo --TAyers: PIP Task 8.5
      ON reo.linkvalue      = TO_CHAR(ft.transactionid)
      AND reo.objectdefid   = t_paytransobjectdefid
      WHERE r1.fromobjectid = a_objectid
      AND r1.endpointid     = api.pkg_configquery.endpointidforname( 'j_License', 'Investigation')
      )
      LOOP
        a_relatedobjectids.EXTEND(1);
        a_relatedobjectids(a_relatedobjectids.COUNT) := api.udt_object(la.objectid);
        --dbms_output.put_line(la.objectid);
      END LOOP;
    END IF;
  END getpaytransforacchist;
--*------------------------------------------------------------------------------------------------
--* GetZeroDollarFeesForAccHist() -- PUBLIC
--* This procedure is getting the Zero Dollar Fees for the Accounting History Report
--*------------------------------------------------------------------------------------------------
  PROCEDURE getzerodollarfeesforacchist(
      a_objectid udt_id,
      a_ptcreateddate DATE,
      a_relatedobjectids OUT api.udt_objectlist)
  IS
    t_jobtypename VARCHAR2(25);
    t_jobtypeid udt_id;
  BEGIN
    a_relatedobjectids := api.udt_objectlist();
    SELECT od.name
    INTO t_jobtypename
    FROM api.objects o
    JOIN api.objectdefs od
    ON od.objectdefid = o.objectdefid
    WHERE o.objectid  = a_objectid;
    t_jobtypeid      := api.pkg_configquery.objectdefidforname(t_jobtypename);
    --starting from job that I am on, get the Fees related to it.
    FOR a IN
    (SELECT af.feeid
    FROM api.jobs j
    JOIN api.fees af
    ON af.jobid = j.jobid
    JOIN api.feetransactions aft
    ON aft.feeid = af.feeid
    JOIN api.logicaltransactions alt
    ON alt.logicaltransactionid = af.logicaltransactionid
    WHERE aft.amount            = -0.01
    AND af.amount               = 0.01 -- and af.TransactionDate <= a_PTCreatedDate--removed as 10.5 as part of ABCtask908
    AND j.jobid                 = a_objectid
    )
    LOOP
      a_relatedobjectids.EXTEND(1);
      a_relatedobjectids(a_relatedobjectids.COUNT) := api.udt_object(a.feeid);
    END LOOP;
    --if it is an app then end the procedure because the procedure has already gotten all of the possible Fees.
    --In the config, if the Application is issued this procedure will only be run from a License
    IF t_jobtypeid = api.pkg_configquery.objectdefidforname('j_Application') THEN
      RETURN;
    ELSE
      --it is a license and walk through rels from license
      --starting from Lic job get $0.00 Fees from other job, App
      FOR l IN
      (SELECT af.feeid
      FROM api.jobs j
      JOIN api.relationships r
      ON r.fromobjectid = j.jobid
      AND r.endpointid  = (api.pkg_configquery.endpointidforname( 'j_License', 'ApplicationLicense'))
      JOIN api.fees af
      ON af.jobid = r.toobjectid
      JOIN api.feetransactions aft
      ON aft.feeid = af.feeid
      JOIN api.logicaltransactions alt
      ON alt.logicaltransactionid = af.logicaltransactionid
      WHERE aft.amount            = -0.01
      AND af.amount               = 0.01 --and af.TransactionDate <= a_PTCreatedDate--removed as 10.5 as part of ABCtask908
      AND j.jobid                 = a_objectid
      )
      LOOP
        a_relatedobjectids.EXTEND(1);
        a_relatedobjectids(a_relatedobjectids.COUNT) := api.udt_object(l.feeid);
      END LOOP;
      --starting from License get LT Fees
      FOR llt IN
      (SELECT af.feeid
      FROM api.relationships r
      JOIN api.fees af
      ON af.jobid = r.toobjectid
      JOIN api.feetransactions aft
      ON aft.feeid         = af.feeid
      WHERE r.fromobjectid = a_objectid
      AND r.endpointid     = api.pkg_configquery.endpointidforname( 'j_License', 'LicenseType')
      AND aft.amount       = -0.01
      AND af.amount        = 0.01 --and af.TransactionDate <= a_PTCreatedDate
      )
      LOOP
        a_relatedobjectids.EXTEND(1);
        a_relatedobjectids(a_relatedobjectids.COUNT) := api.udt_object(llt.feeid);
      END LOOP;
      --starting from lic get inv Fees
      FOR li IN
      (SELECT af.feeid
      FROM api.relationships r1
      JOIN api.fees af
      ON af.jobid = r1.toobjectid
      JOIN api.feetransactions aft
      ON aft.feeid          = af.feeid
      WHERE r1.fromobjectid = a_objectid
      AND r1.endpointid     = api.pkg_configquery.endpointidforname( 'j_License', 'Investigation')
      AND aft.amount        = -0.01
      AND af.amount         = 0.01 --and af.TransactionDate <= a_PTCreatedDate--removed as 10.5 as part of ABCtask908
      )
      LOOP
        a_relatedobjectids.EXTEND(1);
        a_relatedobjectids(a_relatedobjectids.COUNT) := api.udt_object(li.feeid);
      END LOOP;
      --starting from lic get Acc Fees through inv
      FOR la IN
      (SELECT af.feeid
      FROM api.relationships r1
      JOIN api.relationships r2
      ON r2.fromobjectid = r1.toobjectid
      AND r2.endpointid  = api.pkg_configquery.endpointidforname( 'j_Investigation', 'Accusation')
      JOIN api.fees af
      ON af.jobid = r2.toobjectid
      JOIN api.feetransactions aft
      ON aft.feeid          = af.feeid
      WHERE r1.fromobjectid = a_objectid
      AND r1.endpointid     = api.pkg_configquery.endpointidforname( 'j_License', 'Investigation')
      AND aft.amount        = -0.01
      AND af.amount         = 0.01 --and af.TransactionDate <= a_PTCreatedDate--removed as 10.5 as part of ABCtask908
      )
      LOOP
        a_relatedobjectids.EXTEND(1);
        a_relatedobjectids(a_relatedobjectids.COUNT) := api.udt_object(la.feeid);
      END LOOP;
    END IF;
  END getzerodollarfeesforacchist;
  PROCEDURE workloadsummaryrevenue(
      a_year NUMBER)
  IS
    t_feeobjectdefid api.pkg_definition.udt_id := api.pkg_configquery.objectdefidforname('o_Fee');
    t_paytransobjectdefid udt_id               := api.pkg_configquery.objectdefidforname( 'o_PaymentTransactions');
  BEGIN
    DELETE workloadsummarypayments_gt;
    DELETE workloadsummarydetails_gt;
    DELETE workloadsummary_gt;
    INSERT INTO workloadsummarypayments_gt
      (objectid, paymentid
      )
    SELECT x.objectid,
      api.pkg_columnquery.numericvalue(x.objectid, 'PaymentId')
    FROM TABLE( CAST( api.pkg_simplesearch.castableobjectsbyindexrange( 'o_Payment', 'PaymentDateStored', TO_CHAR(a_year)
      || '07-01 00:00:00', TO_CHAR(a_year + 1)
      || '07-01 00:00:00') AS api.udt_objectlist)) x;
    INSERT
    INTO workloadsummarydetails_gt
      (
        paymentobjectid,
        paymentid,
        paymenttransactionid,
        feeid,
        jobid,
        feeobjectid,
        feescheduleobjectid,
        miscfeescheduleobjectid,
        feeactivity,
        licensetypecode,
        paymentstatus,
        isservicecharge,
        amount,
        surchargeabs,
        surchargebpu
      )
    SELECT p.objectid,
      p.paymentid,
      pt.transactionid,
      ft.feeid,
      api.pkg_columnquery.VALUE(reo.objectid, 'JobId'),
      reo.objectid,
      r.licensefeescheduleid,
      NULL,
      api.pkg_columnquery.VALUE(r.licensefeescheduleid, 'FeeActivity'),
      api.pkg_columnquery.VALUE(r.licensefeescheduleid, 'LicenseTypeCode'),
      api.pkg_columnquery.datevalue(reo1.objectid, 'dup_PaymentStatus'),
      api.pkg_columnquery.VALUE(reo1.objectid, 'IsServiceCharge'),
      ft.amount,
      (SELECT ROUND( (NVL(sf.ab_surcharge_pct, 0) / 100) * (-ft.amount), 2)
      FROM sitespecific.feesurchargeschedule_t sf
      WHERE sf.surchargecode = api.pkg_columnquery.VALUE(r.licensefeescheduleid, 'SurchargeCode')
      ),
      (SELECT NVL(sf.bpu_fee, 0)
      FROM sitespecific.feesurchargeschedule_t sf
      WHERE sf.surchargecode = api.pkg_columnquery.VALUE(r.licensefeescheduleid, 'SurchargeCode')
      )
    FROM workloadsummarypayments_gt p
    JOIN api.paymenttransactions pt
    ON pt.paymentid = p.paymentid
    JOIN api.registeredexternalobjects reo1 --TAyers: PIP Task 8.5
    ON reo1.linkvalue    = TO_CHAR(pt.transactionid)
    AND reo1.objectdefid = t_paytransobjectdefid
    JOIN api.feetransactions ft
    ON ft.transactionid = pt.transactionid
    JOIN api.registeredexternalobjects reo -- RyanL: PIP Task 8.5
    ON reo.linkvalue    = TO_CHAR(ft.feeid)
    AND reo.objectdefid = t_feeobjectdefid
    JOIN query.r_feelicensefeeschedule r
    ON r.feeobjectid = reo.objectid
    UNION
    SELECT p.objectid,
      p.paymentid,
      pt.transactionid,
      ft.feeid,
      api.pkg_columnquery.VALUE(reo.objectid, 'JobId'),
      reo.objectid,
      NULL,
      mr.miscfeescheduleobjectid,
      api.pkg_columnquery.VALUE(mr.miscfeescheduleobjectid, 'Code'),
      NULL,
      api.pkg_columnquery.datevalue(reo1.objectid, 'dup_PaymentStatus'),
      api.pkg_columnquery.VALUE(reo1.objectid, 'IsServiceCharge'),
      ft.amount,
      NULL,
      NULL
    FROM workloadsummarypayments_gt p
    JOIN api.paymenttransactions pt
    ON pt.paymentid = p.paymentid
    JOIN api.registeredexternalobjects reo1 --TAyers: PIP Task 8.5
    ON reo1.linkvalue    = TO_CHAR(pt.transactionid)
    AND reo1.objectdefid = t_paytransobjectdefid
    JOIN api.feetransactions ft
    ON ft.transactionid = pt.transactionid
    JOIN api.registeredexternalobjects reo -- RyanL: PIP Task 8.5
    ON reo.linkvalue    = TO_CHAR(ft.feeid)
    AND reo.objectdefid = t_feeobjectdefid
    JOIN query.r_miscfeefeeschedule mr
    ON mr.feeobjectid = reo.objectid;
    INSERT INTO workloadsummary_gt
      (dummy
      ) VALUES
      ('X'
      );
    UPDATE workloadsummary_gt
    SET renewalsannuals =
      (SELECT (-SUM(d.amount)) - SUM(NVL(d.surchargeabs, 0))
      FROM workloadsummarydetails_gt d
      WHERE d.paymentstatus     IS NOT NULL
      AND (((d.feeactivity      IN ('REN', 'REN50', 'REN100')
      AND d.licensetypecode NOT IN ('26', '28', '29', '58', '77'))
      OR (d.feeactivity          = 'ANN'
      AND d.licensetypecode NOT IN ('26', '28'))
      OR (d.feeactivity          = 'AWF')
      OR (d.feeactivity          = 'DOR'
      AND d.licensetypecode     IN ('02', '09', '12', '47', '48', '57', '68')))
      AND d.isservicecharge     <> 'Y')
      );
    UPDATE workloadsummary_gt
    SET originalfees =
      (SELECT -SUM(d.amount)
      FROM workloadsummarydetails_gt d
      WHERE d.paymentstatus     IS NOT NULL
      AND d.feeactivity          = 'ORI'
      AND d.licensetypecode NOT IN ('26', '28')
      AND d.isservicecharge     <> 'Y'
      );
    UPDATE workloadsummary_gt
    SET transfer =
      (SELECT -SUM(d.amount)
      FROM workloadsummarydetails_gt d
      WHERE d.paymentstatus IS NOT NULL
      AND d.feeactivity     IN ('DPR', 'FID', 'MBR', 'PER', 'PRM', 'STK', 'STM', 'ICO', 'CD8', 'MBM', 'EXC')
      AND d.isservicecharge <> 'Y'
      );
    UPDATE workloadsummary_gt
    SET dailylicenses =
      (SELECT -SUM(d.amount)
      FROM workloadsummarydetails_gt d
      WHERE d.paymentstatus IS NOT NULL
      AND (((d.feeactivity  IN ('REN', 'REN50', 'REN100')
      AND d.licensetypecode IN ('26', '28', '29'))
      OR (d.feeactivity      = 'DOR'
      AND d.licensetypecode  = '67')
      OR (d.feeactivity     IN ('TPT', 'IPT'))
      OR (d.licensetypecode IN ('31', '32', '33', '34', '37')))
      AND d.isservicecharge <> 'Y')
      );
    UPDATE workloadsummary_gt
    SET cateventpermits =
      (SELECT -SUM(d.amount)
      FROM workloadsummarydetails_gt d
      WHERE d.paymentstatus IS NOT NULL
      AND (((d.feeactivity   = 'DOR'
      AND d.licensetypecode IN ('58', '77'))
      OR (d.feeactivity     IN ('REN', 'REN50', 'REN100')
      AND d.licensetypecode IN ('58', '77')))
      AND d.isservicecharge <> 'Y')
      );
    UPDATE workloadsummary_gt
    SET cateventauth =
      (SELECT -SUM(d.amount)
      FROM workloadsummarydetails_gt d
      WHERE d.paymentstatus IS NOT NULL
      AND d.feeactivity     IN ('CATA', 'EPA', 'MGR', 'RPL', 'PRW')
      AND d.isservicecharge <> 'Y'
      );
    UPDATE workloadsummary_gt
    SET other =
      (SELECT -SUM(d.amount)
      FROM workloadsummarydetails_gt d
      WHERE d.paymentstatus         IS NOT NULL
      AND (((d.feeactivity          IN ('ORI', 'ANN')
      AND d.licensetypecode         IN ('26', '28'))
      OR d.feeactivity              IN ('MOD', 'SRV', 'BKT', 'BKR')
      OR (d.feeactivity              = 'UTR'
      AND d.feescheduleobjectid     IS NULL))
      OR (d.isservicecharge          = 'Y'
      AND (d.feeactivity            <> 'POIC'
      AND d.miscfeescheduleobjectid IS NULL)))
      );
    UPDATE workloadsummary_gt
    SET other2 =
      (SELECT SUM(d.surchargebpu)
      FROM workloadsummarydetails_gt d
      WHERE d.paymentstatus IS NOT NULL
      AND d.feeactivity     IN ('ANN', 'REN', 'REN50', 'REN100')
      AND d.licensetypecode IN ('04', '05', '07', '13', '18', '21', '27', '66')
      AND d.isservicecharge <> 'Y'
      );
    UPDATE workloadsummary_gt
    SET other3 =
      (SELECT SUM(d.surchargeabs)
      FROM workloadsummarydetails_gt d
      WHERE d.paymentstatus     IS NOT NULL
      AND (((d.feeactivity      IN ('REN', 'REN50', 'REN100')
      AND d.licensetypecode NOT IN ('26', '29', '58', '77'))
      OR (d.feeactivity          = 'ANN'
      AND d.licensetypecode NOT IN ('26', '28'))
      OR (d.feeactivity          = 'AWF'
      AND d.licensetypecode     IN ('50', '51', '52'))
      OR (d.feeactivity          = 'DOR'
      AND d.licensetypecode     IN ('02', '09', '12', '47', '48', '57', '68')))
      AND d.isservicecharge     <> 'Y')
      );
    UPDATE workloadsummary_gt g
    SET g.total = NVL(g.renewalsannuals, 0) + NVL(g.originalfees, 0) + NVL(g.transfer, 0) + NVL(g.dailylicenses, 0) + NVL(g.cateventpermits, 0) + NVL(g.cateventauth, 0) + NVL(g.other, 0) + NVL(g.other3, 0);
    UPDATE workloadsummary_gt
    SET poicaccepted =
      (SELECT -SUM(d.amount)
      FROM workloadsummarydetails_gt d
      WHERE d.paymentstatus IS NOT NULL
      AND d.feeactivity      = 'POIC'
      AND d.isservicecharge <> 'Y'
      );
    UPDATE workloadsummary_gt
    SET poiccount =
      (SELECT COUNT(DISTINCT (d.jobid))
      FROM workloadsummarydetails_gt d
      WHERE d.paymentstatus IS NOT NULL
      AND d.feeactivity      = 'POIC'
      AND d.isservicecharge <> 'Y'
      );
  END workloadsummaryrevenue;
  PROCEDURE dailyintakevoids(
      a_startdate DATE,
      a_enddate   DATE)
  IS
    t_lfs NUMBER(9);
    t_mfs NUMBER(9);
    t_feeobjectdefid udt_id      := api.pkg_configquery.objectdefidforname('o_Fee');
    t_paytransobjectdefid udt_id := api.pkg_configquery.objectdefidforname( 'o_PaymentTransactions');
  BEGIN
    t_lfs := api.pkg_configquery.endpointidforname('o_Fee', 'LicenseFeeSchedule');
    t_mfs := api.pkg_configquery.endpointidforname('o_Fee', 'MiscFeeSchedule');
    DELETE dailyintakevoids_gt;
    INSERT
    INTO dailyintakevoids_gt
      (SELECT
          /*+ CARDINALITY (x , 10) */
          api.pkg_columnquery.VALUE(x.objectid, 'OfficeCode') recdist,
          SUBSTR(api.pkg_columnquery.VALUE(f.jobid, 'StatusName'), 1, 3) status,
          api.pkg_columnquery.VALUE(ffs.toobjectid, 'LicenseTypeCode') ty,
          api.pkg_columnquery.VALUE(f.jobid, 'LicenseNumber') filenum,
          CASE
            WHEN api.pkg_columnquery.VALUE(reo1.objectid, 'IsOverpayment') = 'Y'
            THEN 'OVR'
            WHEN api.pkg_columnquery.VALUE(reo1.objectid, 'IsServiceCharge') = 'Y'
            THEN 'SRV'
            ELSE DECODE( ffs.endpointid, api.pkg_configquery.endpointidforname( 'o_Fee', 'LicenseFeeSchedule'), api.pkg_columnquery.VALUE( ffs.toobjectid, 'Description'), api.pkg_columnquery.VALUE(ffs.toobjectid, 'Code'))
          END transcode,
          NVL(api.pkg_columnquery.VALUE(ffs.toobjectid, 'FeeCode'), 'N/A') feecode,
          api.pkg_columnquery.VALUE(ffs.relationshipid, 'IsMaster') mi,
          NVL( api.pkg_columnquery.VALUE(ffs.relationshipid, 'SecondaryCount'), 0) dup,
          TO_CHAR( api.pkg_columnquery.datevalue(x.objectid, 'PaymentDateStored'), 'MM-DD-YY') paiddate,
          ft.amount * -1 paidamt,
          api.pkg_columnquery.VALUE(x.objectid, 'PaymentMethodCode') paytype,
          p.payeereference paymentid,
          api.pkg_columnquery.numericvalue( x.objectid, 'PaymentAmountForDisplay') paymentamt,
          p.receiptnumber receiptnumber,
          (SELECT paymentamountsummed
          FROM query.r_generatereceiptpayment grp
          JOIN query.p_receiptpayments rp
          ON rp.objectid            = grp.generatereceiptprocessid
          WHERE grp.paymentobjectid = x.objectid
          ) receiptamount,
          api.pkg_columnquery.VALUE(x.objectid, 'PayeeName') paidfor,
          SUBSTR( api.pkg_columnquery.VALUE(pvp.voidpaymentprocessid, 'CreatedByUserName'), 1, 5) "USER",
          NVL(
          (SELECT pb.batchid
          FROM query.r_paymentbatchpayment pbp
          JOIN query.j_paymentbatch pb
          ON pb.objectid            = pbp.paymentbatchjobid
          WHERE pbp.paymentobjectid = x.objectid
          ),
          (SELECT t.externalfilenum
          FROM query.r_transmittalpayment tp
          JOIN query.j_transmittal t
          ON t.jobid               = tp.transmittaljobid
          WHERE tp.paymentobjectid = x.objectid
          )) batchid
        FROM TABLE( CAST( api.pkg_simplesearch.castableobjectsbyindexrange( 'o_Payment', 'dup_DateVoidedTrunc', TO_CHAR(a_startdate, 'YYYY-MM-DD'), TO_CHAR(a_enddate, 'YYYY-MM-DD')) AS api.udt_objectlist)) x
        JOIN query.o_payment o
        ON o.objectid = x.objectid
        JOIN api.payments p
        ON p.paymentid = o.paymentid
        JOIN api.paymenttransactions pt
        ON pt.paymentid = p.paymentid
        JOIN api.feetransactions ft
        ON ft.transactionid = pt.transactionid
        JOIN api.registeredexternalobjects reo1 --TAyers: PIP Task 8.5
        ON reo1.linkvalue    = TO_CHAR(pt.transactionid)
        AND reo1.objectdefid = t_paytransobjectdefid
        JOIN api.fees f
        ON f.feeid = ft.feeid
        JOIN api.registeredexternalobjects reo -- RyanL: PIP Task 8.5
        ON reo.linkvalue    = TO_CHAR(f.feeid)
        AND reo.objectdefid = t_feeobjectdefid
        JOIN api.relationships ffs
        ON ffs.fromobjectid = reo.objectid
        AND ffs.endpointid IN (t_lfs, t_mfs)
        JOIN query.r_paymentvoidpayment pvp
        ON pvp.paymentobjectid = x.objectid
        JOIN api.processes ap
        ON ap.processid   = pvp.voidpaymentprocessid
        WHERE ap.outcome IS NOT NULL
      );
  END;
END pkg_reports;
/


GRANT EXECUTE ON SITESPECIFIC.PKG_REPORTS TO ABCCONV;

GRANT EXECUTE ON SITESPECIFIC.PKG_REPORTS TO ABCREPORTS;

GRANT EXECUTE ON SITESPECIFIC.PKG_REPORTS TO POSSEEXTENSIONS;
