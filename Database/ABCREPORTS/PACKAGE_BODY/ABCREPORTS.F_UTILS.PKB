CREATE OR REPLACE PACKAGE BODY ABCREPORTS.f_utils
AS
    /******************************************************************************
       NAME:       F_UTILS
       PURPOSE:

       REVISIONS:
       Ver        Date        Author           Description
       ---------  ----------  ---------------  ------------------------------------
       1.0        7/23/2021      tlord       1. Created this package body.
    ******************************************************************************/

    FUNCTION get_primarysecondarybranch(a_transactionid IN NUMBER)
        RETURN VARCHAR2
    IS
        t_jobdescription           VARCHAR2(20);
        t_primarysecondarybranch   VARCHAR2(1);
        t_jobid                    NUMBER;
        t_sqlerrm                  VARCHAR2(4000);
    BEGIN
        SELECT td.jobdescription, td.jobid
          INTO t_jobdescription, t_jobid
          FROM abcreports.f_transactions td
         WHERE td.transactionid = a_transactionid;

        CASE t_jobdescription
            WHEN 'j_Application' THEN
                BEGIN
                    SELECT DISTINCT CASE
                                        WHEN feelicensetypecode IS NOT NULL
                                         AND secondarylicensetypecode IS NOT NULL
                                         AND ((ltlicensetypecode != secondarylicensetypecode
                                           AND feelicensetypecode = secondarylicensetypecode)
                                           OR feeactivity = 'DOR'
                                           OR feelicensetypecode IN ('58', '77')) THEN
                                            'S'
                                        ELSE
                                            CASE WHEN masterlicensetype IS NULL THEN 'P' ELSE 'B' END
                                    END
                                        primarysecondary
                      INTO t_primarysecondarybranch
                      FROM (WITH
                                lt
                                AS
                                    (SELECT  /*+ materialize */
                                            r.toobjectid
                                                licensetypeobjectid,
                                            td.feeactivity,
                                            td.feelicensetypecode,
                                            api.pkg_columnquery.VALUE(r.toobjectid, 'LicenseTypeCode')
                                                ltlicensetypecode
                                       FROM abcreports.f_transactions td
                                            LEFT OUTER JOIN api.relationships r  -- to j_licenseType
                                            ON (r.endpointid =
                                                api.pkg_configquery.endpointidforname('j_Application',
                                                                                      'PrimaryLicenseType')
                                            AND r.fromobjectid = td.jobid)
                                      WHERE jobdescription = 'j_Application'
                                        AND td.transactionid = a_transactionid)
                            SELECT lt.*,
                                   api.pkg_columnquery.VALUE(r2.toobjectid, 'Licensetypecode')
                                       secondarylicensetypecode,
                                   NVL(
                                       r3.toobjectid,
                                       CASE api.pkg_columnquery.VALUE(lt.licensetypeobjectid, 'IsBranchS')
                                           WHEN 'Y' THEN lt.licensetypeobjectid
                                           ELSE NULL
                                       END)
                                       masterlicensetype
                              FROM lt
                                   LEFT OUTER JOIN api.relationships r2  -- to o_LicTypeCatSecondary
                                   ON (r2.endpointid =
                                       api.pkg_configquery.endpointidforname('o_PrimaryLicenseType',
                                                                             'LicTypeCatSecondary')
                                   AND r2.fromobjectid = lt.licensetypeobjectid
                                   AND lt.feelicensetypecode IS NOT NULL)
                                   LEFT OUTER JOIN api.relationships r3
                                   ON r3.endpointid IN
                                          (api.pkg_configquery.endpointidforname('o_PrimaryLicenseType',
                                                                                 'MasterLicenseType'),
                                           api.pkg_configquery.endpointidforname('o_PrimaryLicenseType',
                                                                                 'BranchtoMaster'))
                                  AND r3.fromobjectid = lt.licensetypeobjectid) ps
                     WHERE (NVL(ps.feelicensetypecode, ps.ltlicensetypecode) = ps.ltlicensetypecode
                         OR NVL(feelicensetypecode, '000') = NVL(ps.secondarylicensetypecode, '00'))
                       AND ROWNUM = 1;
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        t_primarysecondarybranch   := 'X';
                END;
            WHEN 'j_License' THEN
                BEGIN
                    SELECT DISTINCT CASE
                                        WHEN feelicensetypecode IS NOT NULL
                                         AND ((feelicensetypecode = NVL(secondarylicensetypecode, 0)
                                           AND ltlicensetypecode != NVL(secondarylicensetypecode, ltlicensetypecode))
                                           OR feeactivity = 'DOR'
                                           OR feelicensetypecode IN ('58', '77')) THEN
                                            'S'
                                        ELSE
                                            CASE WHEN masterlicensetype IS NULL THEN 'P' ELSE 'B' END
                                    END
                                        primarysecondary
                      INTO t_primarysecondarybranch
                      FROM (WITH
                                lt
                                AS
                                    (SELECT  /*+ materialize */
                                            r.toobjectid
                                                licensetypeobjectid,
                                            td.feeactivity,
                                            td.feelicensetypecode,
                                            api.pkg_columnquery.VALUE(r.toobjectid, 'LicenseTypeCode')
                                                ltlicensetypecode
                                       FROM abcreports.f_transactions td
                                            LEFT OUTER JOIN api.relationships r  -- to j_licenseType
                                            ON (r.endpointid =
                                                api.pkg_configquery.endpointidforname('j_License', 'LicenseType')
                                            AND r.fromobjectid = td.jobid)
                                      WHERE jobdescription = 'j_License'
                                        AND td.transactionid = a_transactionid)
                              SELECT lt.*,
                                     api.pkg_columnquery.VALUE(r2.toobjectid, 'Licensetypecode')
                                         secondarylicensetypecode,
                                     r3.toobjectid
                                         masterlicensetype
                                FROM lt
                                     LEFT OUTER JOIN api.relationships r2  -- to o_LicTypeCatSecondary
                                     ON (r2.endpointid =
                                         api.pkg_configquery.endpointidforname('j_LicenseType', 'LicTypeCatSecondary')
                                     AND r2.fromobjectid = lt.licensetypeobjectid
                                     AND lt.feelicensetypecode IS NOT NULL)
                                     LEFT OUTER JOIN api.relationships r3
                                     ON r3.endpointid =
                                        api.pkg_configquery.endpointidforname('j_LicenseType', 'MasterLicenseType')
                                    AND r3.fromobjectid = lt.licensetypeobjectid
                            ORDER BY lt.ltlicensetypecode) ps
                     WHERE (CASE
                                WHEN NVL(feelicensetypecode, '00') IN ('58', '77')
                                 AND NVL(secondarylicensetypecode, '00') IN ('77', '58') THEN
                                    1
                                WHEN NVL(ps.feelicensetypecode, ps.ltlicensetypecode) = ps.ltlicensetypecode
                                  OR NVL(feelicensetypecode, '000') = NVL(ps.secondarylicensetypecode, '00') THEN
                                    1
                                ELSE
                                    0
                            END = 1
                         OR feelicensetypecode IS NULL)
                       AND ROWNUM = 1;
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        t_primarysecondarybranch   := 'X';
                END;
            WHEN 'j_LicenseType' THEN
                BEGIN
                    SELECT DISTINCT
                           CASE
                               WHEN (NVL(feelicensetypecode, ltlicensetypecode) = NVL(secondarylicensetypecode, 0)
                                 AND ltlicensetypecode != NVL(secondarylicensetypecode, ltlicensetypecode))
                                 OR feeactivity = 'DOR' THEN
                                   'S'
                               ELSE
                                   CASE WHEN masterlicensetype IS NULL THEN 'P' ELSE 'B' END
                           END
                               primarysecondary
                      INTO t_primarysecondarybranch
                      FROM (SELECT td.feelicensetypecode,
                                   api.pkg_columnquery.VALUE(td.jobid, 'dup_LicenseTypeCode')
                                       ltlicensetypecode,
                                   td.feeactivity,
                                   api.pkg_columnquery.VALUE(r2.toobjectid, 'Licensetypecode')
                                       secondarylicensetypecode,
                                   r.toobjectid
                                       masterlicensetype
                              FROM abcreports.f_transactions td
                                   LEFT OUTER JOIN api.relationships r2
                                   ON (r2.endpointid =
                                       api.pkg_configquery.endpointidforname('j_LicenseType', 'LicTypeCatSecondary')
                                   AND r2.fromobjectid = td.jobid
                                   AND td.feelicensetypecode IS NOT NULL)
                                   LEFT OUTER JOIN api.relationships r
                                   ON r.endpointid =
                                      api.pkg_configquery.endpointidforname('j_LicenseType', 'MasterLicenseType')
                                  AND r.fromobjectid = td.jobid
                             WHERE jobdescription = 'j_LicenseType'
                               AND td.transactionid = a_transactionid) l
                     WHERE NVL(l.feelicensetypecode, l.ltlicensetypecode) = l.ltlicensetypecode
                        OR NVL(feelicensetypecode, '000') = NVL(l.secondarylicensetypecode, '00');
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        t_primarysecondarybranch   := 'X';
                END;
            ELSE
                t_primarysecondarybranch   := 'P';
        END CASE;

        RETURN t_primarysecondarybranch;
    EXCEPTION
        WHEN OTHERS THEN
            t_sqlerrm   := SUBSTR(SQLERRM, 1, 3990);

            DBMS_OUTPUT.put_line(   'transaction id: '
                                 || a_transactionid
                                 || '  Job Description: '
                                 || t_jobdescription
                                 || '  Job Id: '
                                 || t_jobid
                                 || '  Error Message: '
                                 || t_sqlerrm
                                 || '  Trace: '
                                 || SUBSTR(DBMS_UTILITY.format_error_backtrace, 1, 3990));

            RETURN 'X';
    END get_primarysecondarybranch;

    -- ******************************************************************************


    -- ******************************************************************************
    PROCEDURE get_surcharges(a_feeid        IN     NUMBER,
                             a_primarysecondary IN VARCHAR2,
                             a_amount       IN     NUMBER,
                             a_transactiondate IN  DATE,
                             a_feescheduleobjectid IN NUMBER,
                             a_ltcount      IN     NUMBER,
                             a_originalfee     OUT NUMBER,
                             a_ab_surcharge    OUT NUMBER,
                             a_dmv_surcharge_amt   OUT NUMBER,
                             a_bpu_fee         OUT NUMBER,
                             a_miscfee         OUT VARCHAR2)
    IS
        t_feesurchargescheduleobjectid   NUMBER := NULL;
        t_ab_surcharge_pct               NUMBER;
        t_amountbase                     NUMBER;
        t_roundingfactor                 NUMBER;
        t_dmv                            NUMBER := 0;
        t_bpu                            NUMBER := 0;
        t_ab                             NUMBER := 0;
        t_lttype                         NUMBER;
        t_ltcount                        NUMBER;
        t_amount                         NUMBER;
        t_samount                        NUMBER;
        t_secondaryamount                NUMBER;
        t_feeactivity                    VARCHAR2(20);
        t_loops                          NUMBER := 1;  -- loop only once
        t_primarysecondary               VARCHAR2(1);
    BEGIN
        -- initialize return variables
        a_bpu_fee             := 0;
        a_dmv_surcharge_amt   := 0;
        a_ab_surcharge        := 0;
        a_originalfee         := a_amount;  -- original amount same as amount when no surcharge
        a_miscfee             :=
            CASE NVL(api.pkg_columnquery.VALUE(a_feescheduleobjectid, 'ObjectDefName'), 'o_MiscFeeSchedule')
                WHEN 'o_FeeSchedule' THEN 'N'
                ELSE 'Y'
            END;

        -- get surcharge object
        IF (a_miscfee = 'N') THEN
            WITH
                surcharge
                AS
                    (SELECT (SELECT objectid
                               FROM sitespecific.feesurchargeschedule_t fs
                              WHERE fs.surchargecode = api.pkg_columnquery.VALUE(f.objectid, 'surchargecode')
                                AND fs.effectivedate = (SELECT MAX(fs2.effectivedate)
                                                          FROM sitespecific.feesurchargeschedule_t fs2
                                                         WHERE fs2.surchargecode = fs.surchargecode
                                                           AND TRUNC(fs2.effectivedate) <= TRUNC(a_transactiondate)))
                                feesurchargescheduleobjectid
                       FROM sitespecific.feeschedule_t f
                      WHERE f.objectid = a_feescheduleobjectid)
            SELECT MAX(s.feesurchargescheduleobjectid)
              INTO t_feesurchargescheduleobjectid
              FROM surcharge s;
        END IF;

        --dbms_output.put_line(t_feesurchargescheduleobjectid);
        -- only go through calculation when there is a surcharge to be applied
        IF (t_feesurchargescheduleobjectid IS NOT NULL) THEN
            -- get rounding factor the AB Surcharge calculation
            t_roundingfactor     :=
                NVL(api.pkg_columnquery.numericvalue(t_feesurchargescheduleobjectid, 'roundingfactor'), 1);
            t_ab_surcharge_pct   :=
                NVL(api.pkg_columnquery.numericvalue(t_feesurchargescheduleobjectid, 'ab_surcharge_pct'), 0) / 100;

            -- get fee schedult information
            t_feeactivity        := api.pkg_columnquery.VALUE(a_feescheduleobjectid, 'FeeActivity');
            t_lttype             := api.pkg_columnquery.VALUE(a_feescheduleobjectid, 'LicenseTypeCode');
            t_secondaryamount    := api.pkg_columnquery.numericvalue(a_feescheduleobjectid, 'SecondaryAmount');

            t_amount             := a_amount;
            t_ltcount            := GREATEST(NVL(a_ltcount, 0), 1);
            t_primarysecondary   := a_primarysecondary;
            a_originalfee        := 0;

            --            DBMS_OUTPUT.put_line(   'feeid: '
            --                                 || a_feeid
            --                                 || '  primarysecondary: '
            --                                 || a_primarysecondary
            --                                 || '  ltcount: '
            --                                 || a_ltcount
            --                                 || '  lttype: '
            --                                 || t_lttype
            --                                 || '  feeactivity: '
            --                                 || api.pkg_columnquery.VALUE(a_feescheduleobjectid, 'FeeActivity')
            --                                 || '  amount: '
            --                                 || a_amount
            --                                 || '  primaryamount: '
            --                                 || api.pkg_columnquery.VALUE(a_feescheduleobjectid, 'primaryamount')
            --                                 || '  secondaryamount: '
            --                                 || t_secondaryamount);
            --

            CASE
                -- check if fee has additional gallonage
                WHEN t_lttype IN ('02', '22')
                 AND t_primarysecondary = 'P'
                 AND NVL(a_ltcount, 0) > 0 THEN
                    t_amount    := a_amount - (t_secondaryamount * a_ltcount);  -- get primary fee amount
                    t_samount   := a_amount - t_amount;
                    t_loops     := 2;  -- loop twice one for primary and second for additional gallonage
                    t_ltcount   := 1;
                -- check if ren fee with primary has secondary value
                WHEN (SUBSTR(t_feeactivity, 1, 3) = 'REN'
                  AND NVL(a_ltcount, 0) > 0) THEN
                    t_amount             := a_amount - (t_secondaryamount * a_ltcount);  -- get primary fee amount
                    t_samount            := a_amount - t_amount;
                    t_loops              := 2;  -- loop twice one for primary and second
                    t_ltcount            := 1;
                    t_primarysecondary   := 'S';  -- force getting dmv,bpu on the second loop for renewals
                ELSE
                    NULL;
            END CASE;

            FOR inx IN 1 .. t_loops
            LOOP
                t_bpu                 := 0;
                t_dmv                 := 0;

                -- get surcharges if first time in loop or if secondary fee
                IF (inx = 1
                 OR t_primarysecondary = 'S') THEN
                    t_bpu   := NVL(api.pkg_columnquery.numericvalue(t_feesurchargescheduleobjectid, 'bpu_fee'), 0);
                    t_dmv   :=
                        NVL(api.pkg_columnquery.numericvalue(t_feesurchargescheduleobjectid, 'dmv_surcharge_amt'), 0);
                END IF;

                t_amountbase          := (t_amount / t_ltcount) - t_dmv - t_bpu;

                t_ab                  :=
                      ROUND((t_amountbase - (t_amountbase / (1 + t_ab_surcharge_pct))) / t_roundingfactor)
                    * t_roundingfactor;

                a_bpu_fee             := a_bpu_fee + (t_bpu * t_ltcount);
                a_dmv_surcharge_amt   := a_dmv_surcharge_amt + (t_dmv * t_ltcount);
                a_ab_surcharge        := a_ab_surcharge + (t_ab * t_ltcount);
                a_originalfee         := a_originalfee + ((t_amountbase - t_ab) * t_ltcount);

                t_ltcount             := a_ltcount;
                t_amount              := t_samount;
            END LOOP;
        END IF;
    END;



    -- ******************************************************************************


    -- ******************************************************************************
    FUNCTION get_feeamounts(a_feeid        IN NUMBER,
                            a_primarysecondary IN VARCHAR2,
                            a_feeobjid     IN NUMBER,
                            a_transactiondate IN DATE,
                            a_licensetypecount IN NUMBER,
                            a_licensefeeschedid IN NUMBER,
                            a_startdate    IN DATE,
                            a_enddate      IN DATE)
        RETURN abcreports.f_transactions_rpt%ROWTYPE
    IS
        CURSOR transactions_cur(p_feeid IN NUMBER, p_startdate IN DATE, p_enddate IN DATE)
        IS
              SELECT t.jobdescription,
                     t.transactionid,
                     t.transactiontypeid,
                     t.transactiondate,
                     t.amount,
                     t.description,
                     t.cabinamttype,
                     t.paymenttransactionsobjectid,
                     t.paymenttransferrel
                FROM abcreports.f_transactions t
               WHERE TRUNC(t.transactiondate) BETWEEN p_startdate AND p_enddate
                 AND t.feeid = p_feeid
            ORDER BY t.feeid, CASE WHEN t.transactiontypeid = 1 THEN 1 ELSE 2 END, t.transactionid;

        TYPE voidedby_tbl IS TABLE OF NUMBER;
        t_voidedby                voidedby_tbl := voidedby_tbl();

        t_earn                    NUMBER;
        t_voidedbyid              NUMBER;
        t_tmp                     NUMBER;
        t_transactionstartdate    DATE;
        t_transactionenddate      DATE;

        t_originalfee             NUMBER := 0;
        t_ab_surcharge            NUMBER := 0;
        t_dmv_surcharge_amt       NUMBER := 0;
        t_bpu_fee                 NUMBER := 0;

        t_originalfee_ttl         NUMBER := 0;
        t_ab_surcharge_ttl        NUMBER := 0;
        t_dmv_surcharge_amt_ttl   NUMBER := 0;
        t_bpu_fee_ttl             NUMBER := 0;
        t_adjustedamount          NUMBER := 0;
        t_amount                  NUMBER := 0;
        info                      abcreports.f_transactions_rpt%ROWTYPE;
    BEGIN
        info.feeid                 := a_feeid;
        info.penalties             := 0;
        info.earnedamount          := 0;
        info.servicechargeamount   := 0;
        info.originalfee           := 0;
        info.ab_surcharge          := 0;
        info.dmv_surcharge_amt     := 0;
        info.bpu_fee               := 0;
        info.miscfee               := 'N';

        t_transactionstartdate     := TO_DATE('01/01/1900', 'MM/DD/YYYY');
        t_transactionenddate       := TRUNC(a_enddate);

        FOR rec IN transactions_cur(a_feeid, t_transactionstartdate, t_transactionenddate)
        LOOP
            -- process record
            CASE rec.transactiontypeid
                WHEN 1 THEN
                    t_amount             := rec.amount;
                    info.objectdefname   := rec.jobdescription;
                    -- surcharge fees incase of no earned or un-earned payment
                    get_surcharges(a_feeid     => a_feeid,
                                   a_primarysecondary => a_primarysecondary,
                                   a_amount    => rec.amount - t_adjustedamount,
                                   a_transactiondate => a_transactiondate,
                                   a_feescheduleobjectid => a_licensefeeschedid,
                                   a_ltcount   => a_licensetypecount,
                                   a_originalfee => info.originalfee,
                                   a_ab_surcharge => info.ab_surcharge,
                                   a_dmv_surcharge_amt => info.dmv_surcharge_amt,
                                   a_bpu_fee   => info.bpu_fee,
                                   a_miscfee   => info.miscfee);
                WHEN 2 THEN
                    CASE rec.description
                        WHEN 'Voided' THEN  -- voided payment
                            NULL;
                        WHEN 'Modify Fee - Void' THEN
                            t_adjustedamount   := t_adjustedamount + rec.amount;
                        WHEN 'Modify Fee - Modify' THEN
                            t_adjustedamount   := t_adjustedamount + rec.amount;
                        WHEN 'AWF' THEN
                            t_adjustedamount   := t_adjustedamount + rec.amount;
                        ELSE
                            CASE
                                WHEN NVL(REGEXP_SUBSTR(rec.description,
                                                       '(REN){1}',
                                                       1,
                                                       1),
                                         'X') != 'REN' THEN
                                    t_adjustedamount   := t_adjustedamount + rec.amount;
                                ELSE
                                    -- penialities
                                    info.penalties   := info.penalties + rec.amount;
                            END CASE;
                    END CASE;
                WHEN 3 THEN
                    -- check for earned amount
                    WITH
                        ps
                        AS
                            (SELECT  /*+ materialize */
                                    api.pkg_columnquery.numericvalue(r.toobjectid, 'EarnedAmount') earnedamount,
                                    api.pkg_columnquery.datevalue(r.toobjectid, 'dup_createddate') dup_createddate
                               FROM api.relationships r
                              WHERE (r.endpointid =
                                     api.pkg_configquery.endpointidforname('o_PaymentTransactions', 'PaymentStatus')
                                 AND r.fromobjectid = rec.paymenttransactionsobjectid))
                    SELECT SUM(ps.earnedamount)
                      INTO t_earn
                      FROM ps
                     WHERE ps.dup_createddate BETWEEN a_startdate AND a_enddate
                       AND (rec.cabinamttype IN ('I')
                         OR rec.cabinamttype = ('C')
                         OR rec.cabinamttype = ('V')
                         OR (rec.description = 'SRV'));

                    IF (NVL(t_earn, 0) != 0) THEN
                        get_surcharges(a_feeid     => a_feeid,
                                       a_primarysecondary => a_primarysecondary,
                                       a_amount    => t_amount - t_adjustedamount,
                                       a_transactiondate => a_transactiondate,
                                       a_feescheduleobjectid => a_licensefeeschedid,
                                       a_ltcount   => a_licensetypecount,
                                       a_originalfee => t_originalfee,
                                       a_ab_surcharge => t_ab_surcharge,
                                       a_dmv_surcharge_amt => t_dmv_surcharge_amt,
                                       a_bpu_fee   => t_bpu_fee,
                                       a_miscfee   => info.miscfee);

                        CASE
                            WHEN t_earn < 0
                             AND info.earnedamount >= 0 THEN  -- earned
                                t_originalfee_ttl         := t_originalfee_ttl - t_originalfee;
                                t_ab_surcharge_ttl        := t_ab_surcharge_ttl - t_ab_surcharge;
                                t_dmv_surcharge_amt_ttl   := t_dmv_surcharge_amt_ttl - t_dmv_surcharge_amt;
                                t_bpu_fee_ttl             := t_bpu_fee_ttl - t_bpu_fee;
                            WHEN t_earn > 0
                             AND info.earnedamount <= 0 THEN  -- unearned
                                t_originalfee_ttl         := t_originalfee_ttl + t_originalfee;
                                t_ab_surcharge_ttl        := t_ab_surcharge_ttl + t_ab_surcharge;
                                t_dmv_surcharge_amt_ttl   := t_dmv_surcharge_amt_ttl + t_dmv_surcharge_amt;
                                t_bpu_fee_ttl             := t_bpu_fee_ttl + t_bpu_fee;
                            ELSE
                                NULL;
                        END CASE;

                        info.earnedamount   := info.earnedamount + t_earn;
                    END IF;

                    CASE
                        WHEN rec.cabinamttype IN ('I') THEN
                            IF (rec.description = 'SRV') THEN
                                info.servicechargeamount   := info.servicechargeamount + rec.amount;
                            END IF;
                        WHEN rec.cabinamttype = 'D' THEN
                            info.dishoneredamount   := info.dishoneredamount + rec.amount;
                        WHEN rec.cabinamttype = 'R' THEN
                            IF (rec.description = 'SRV') THEN
                                info.servicechargeamount   := info.servicechargeamount + rec.amount;
                            END IF;
                        WHEN rec.cabinamttype IN ('V') THEN
                            NULL;
                        ELSE
                            NULL;
                    END CASE;
            END CASE;
        END LOOP;

        CASE
            WHEN NVL(t_originalfee_ttl, 0) = 0 THEN
                NULL;
            ELSE
                info.originalfee         := t_originalfee_ttl;
                info.ab_surcharge        := t_ab_surcharge_ttl;
                info.dmv_surcharge_amt   := t_dmv_surcharge_amt_ttl;
                info.bpu_fee             := t_bpu_fee_ttl;
        END CASE;

        SELECT jobid
          INTO info.jobid
          FROM api.fees f
         WHERE f.feeid = a_feeid;

        RETURN info;
    END get_feeamounts;



    -- ******************************************************************************


    -- ******************************************************************************
    PROCEDURE loadtransactiontable(a_startdate IN DATE, a_enddate IN DATE)
    IS
        CURSOR transactions
        IS
            SELECT td.transactionid
              FROM abcreports.f_transactions td
             WHERE td.transactiontypeid = 1;
        t_psb      VARCHAR2(1);
        t_cnt      NUMBER;
        t_errors   NUMBER := 0;
    BEGIN
        --  Load Fee Id that had payment status changed between start and end dates
        DBMS_OUTPUT.put_line('Start Transactions Load');

        INSERT INTO abcreports.f_transactions td(paymentstatusobjectid,
                                                 feeobjid,
                                                 feeid,
                                                 transactionid,
                                                 transactiontypeid,
                                                 licensefeeschedid)
            SELECT paymentstatusobjectid,
                   feeobjid,
                   api.pkg_columnquery.numericvalue(feeobjid, 'feeid'),
                   api.pkg_columnquery.numericvalue(feeobjid, 'feeid'),
                   1,
                   api.pkg_columnquery.numericvalue(feeobjid, 'LicenseFeeSchedId')
              FROM (  SELECT  /*+ materialize */
                             DISTINCT
                             api.pkg_columnquery.numericvalue(r.toobjectid, 'FeeObjId')
                                 feeobjid,
                             LISTAGG(paymentstatusobjectid, ',') WITHIN GROUP (ORDER BY paymentstatusobjectid)
                                 paymentstatusobjectid
                        FROM (SELECT o.objectid paymentstatusobjectid
                                FROM TABLE(
                                         CAST(
                                             api.pkg_simplesearch.castableobjectsbyindexrange(
                                                 a_objectdefname => 'o_PaymentStatus',
                                                 a_columnname => 'dup_CreatedDate',
                                                 a_lowvalue  => TO_CHAR(a_startdate, 'YYYY-MM-DD'),
                                                 a_highvalue => TO_CHAR(a_enddate, 'YYYY-MM-DD')) AS api.udt_objectlist))
                                     o) ps
                             JOIN api.relationships r
                             ON (r.endpointid =
                                 api.pkg_configquery.endpointidforname('o_PaymentStatus', 'PaymentTransactions')
                             AND r.fromobjectid = ps.paymentstatusobjectid)
                    GROUP BY api.pkg_columnquery.numericvalue(r.toobjectid, 'FeeObjId'))
             WHERE feeobjid IS NOT NULL;

        IF (SQL%ROWCOUNT = 0) THEN
            t_errors   := t_errors + 1;
        END IF;

        --  Update new fee records with transactions type 1 (Fee)

        UPDATE abcreports.f_transactions td
           SET (jobid,
                jobdescription,
                licensenumber,
                feelicensetypecode,
                transactiondate,
                description,
                feeactivity,
                amount,
                secondarycount,
                paymenttransferrel)   =
                   (SELECT d.jobid,
                           api.pkg_columnquery.VALUE(d.jobid, 'ObjectDefName'),
                           api.pkg_columnquery.VALUE(d.jobid, 'LicenseNumber'),
                           CASE
                               WHEN REGEXP_LIKE(TRIM(SUBSTR(d.description, 1, 3)), '^\d+(\.\d+)?$') THEN
                                   TRIM(SUBSTR(d.description, 1, 3))
                               ELSE
                                   NULL
                           END
                               feelicensetypecode,
                           d.transactiondate,
                           d.description,
                           CASE api.pkg_columnquery.VALUE(d.jobid, 'ObjectDefName')
                               WHEN 'j_MiscellaneousFee' THEN
                                   api.pkg_columnquery.VALUE(d.toobjectid, 'Code')
                               ELSE
                                   CASE d.description
                                       WHEN 'AWF' THEN
                                           d.description
                                       ELSE
                                           REGEXP_SUBSTR(d.description,
                                                         '[^ ]+',
                                                         1,
                                                         3)
                                   END
                           END
                               feeactivity,
                           d.amount,
                           d.secondarycount,
                           d.paymenttransferrel
                      FROM (SELECT api.pkg_columnquery.numericvalue(td.feeobjid, 'JobId')
                                       jobid,
                                   f.transactiondate,
                                   td.feeid,
                                   f.description,
                                   f.amount,
                                   r.toobjectid,
                                   api.pkg_columnquery.numericvalue(r.relationshipid, 'SecondaryCount')
                                       secondarycount,
                                   (SELECT LISTAGG(r.relationshipid, ',') WITHIN GROUP (ORDER BY r.relationshipid)
                                      FROM api.relationships r
                                     WHERE r.endpointid =
                                           api.pkg_configquery.endpointidforname('o_Fee', 'PaymentTransfer')
                                       AND r.fromobjectid =
                                           (api.pkg_simplesearch.objectbyindex('o_Fee', 'FeeId', f.feeid)))
                                       paymenttransferrel
                              FROM api.fees f
                                   JOIN api.relationships r
                                   ON (r.endpointid IN
                                           (api.pkg_configquery.endpointidforname('o_fee', 'MiscFeeSchedule'),
                                            api.pkg_configquery.endpointidforname('o_Fee', 'LicenseFeeSchedule'))
                                   AND r.fromobjectid = td.feeobjid)
                             WHERE f.feeid = td.feeid) d);

        -- Insert transaction type records 2 (Adj) and 3 (Pay) to end date inclusive
        INSERT INTO abcreports.f_transactions td(feeobjid,
                                                 feeid,
                                                 transactionid,
                                                 transactiontypeid,
                                                 transactiondate,
                                                 amount,
                                                 licensefeeschedid,
                                                 paymenttransactionsobjectid,
                                                 description,
                                                 cabinamttype,
                                                 paymenttransferrel)
            WITH
                t
                AS
                    (SELECT  /*+ materialize */
                            td.feeobjid,
                            ft.feeid,
                            ft.transactionid,
                            CASE ft.transactiontype WHEN 'Adj' THEN 2 WHEN 'Pay' THEN 3 ELSE NULL END
                                transactiontypeid,
                            ft.transactiondate,
                            ft.amount,
                            td.licensefeeschedid,
                            api.pkg_simplesearch.objectbyindex('o_PaymentTransactions',
                                                               'TransactionId',
                                                               ft.transactionid)
                                paymenttransactionsobjectid,
                            ft.description
                       FROM api.feetransactions ft
                            JOIN abcreports.f_transactions td
                            ON ft.feeid = td.feeid
                      WHERE TRUNC(ft.transactiondate) <= a_enddate)
            SELECT t.feeobjid,
                   t.feeid,
                   t.transactionid,
                   t.transactiontypeid,
                   t.transactiondate,
                   t.amount,
                   t.licensefeeschedid,
                   t.paymenttransactionsobjectid,
                   CASE t.transactiontypeid
                       WHEN 3 THEN
                           api.pkg_columnquery.VALUE(t.paymenttransactionsobjectid, 'FeeScheduleDescriptionForGrid')
                       ELSE
                           t.description
                   END,
                   api.pkg_columnquery.VALUE(t.paymenttransactionsobjectid, 'CABINAMTTYPE')
                       cabinamttype,
                   (SELECT LISTAGG(r.relationshipid, ',') WITHIN GROUP (ORDER BY r.relationshipid)
                      FROM api.relationships r
                     WHERE r.endpointid =
                           api.pkg_configquery.endpointidforname('p_PaymentTransfer', 'PaymentTransaction')
                       AND r.toobjectid = t.paymenttransactionsobjectid)
                       paymenttransferrel
              FROM t;

        IF (SQL%ROWCOUNT = 0) THEN
            t_errors   := t_errors + 1;
        END IF;

        FOR rec IN transactions  -- cursor
        LOOP
            t_psb   := f_utils.get_primarysecondarybranch(a_transactionid => rec.transactionid);

            UPDATE abcreports.f_transactions td
               SET td.primarysecondary   = t_psb
             WHERE td.transactionid = rec.transactionid;
        END LOOP;

        SELECT COUNT(transactionid) INTO t_cnt FROM abcreports.f_transactions;

        DBMS_OUTPUT.put_line(   'Insert errors: '
                             || t_errors);
        DBMS_OUTPUT.put_line(   'Transactions Loaded: '
                             || t_cnt);
    END loadtransactiontable;

    -- ***********************************************************************


    --- **********************************************************************
    PROCEDURE get_revenue(a_startdate IN DATE, a_enddate IN DATE)
    IS
        t_count       NUMBER := 0;
        t_starttime   DATE := SYSDATE;
        t_info        abcreports.f_transactions_rpt%ROWTYPE;
    BEGIN
        loadtransactiontable(a_startdate => a_startdate, a_enddate => a_enddate);

        FOR rec IN (SELECT x.jobid,
                           x.feeid,
                           x.feeactivity,
                           x.primarysecondary,
                           x.feeobjid,
                           x.transactiondate,
                           x.licensefeeschedid,
                           x.secondarycount
                      FROM abcreports.f_transactions x
                     WHERE x.transactiontypeid = 1)
        LOOP
            t_info               :=
                get_feeamounts(a_feeid     => rec.feeid,
                               a_primarysecondary => rec.primarysecondary,
                               a_feeobjid  => rec.feeobjid,
                               a_transactiondate => rec.transactiondate,
                               a_licensetypecount => rec.secondarycount,
                               a_licensefeeschedid => rec.licensefeeschedid,
                               a_startdate => a_startdate,
                               a_enddate   => a_enddate);

            t_info.feeactivity   := rec.feeactivity;
            t_info.feeobjid      := rec.feeobjid;

            INSERT INTO abcreports.f_transactions_rpt
            VALUES t_info;

            t_count              := t_count + 1;
        END LOOP;

        DBMS_OUTPUT.put_line(   'Fees Processed: '
                             || t_count);
    END get_revenue;
END f_utils;
/
