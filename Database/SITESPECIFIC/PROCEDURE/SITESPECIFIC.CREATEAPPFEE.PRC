CREATE OR REPLACE PROCEDURE SITESPECIFIC.createappfee(
    a_objectid      api.pkg_definition.udt_id,
    a_asofdate      DATE,
    a_jobid         api.pkg_definition.udt_id)
-- ****************************************************************************
-- File:        createappfee.prc
-- Author:      Timothy J. Lord
--
-- $Rev: 390 $
-- $Date: 2019-12-18 18:51:54 -0800 (Wed, 18 Dec 2019) $
-- Last Changed By:  $Author: TLord $
--
-- Purpose :        To create the APP application fee for applications
--
-- History:
-------------------------------------------------------------------------------
--    Date         Ticket     Comment
--  03/29/2019 TJL  17565   Created procdure to create the single application
--                          fees (APP) for all types of applications.
--                          (original, transfer, and change)
--  08/01/2019 TJL  18697   Change Issue Date from using 'EstimatedIssueDate' to
--                            'CopiesMailed' Date
--  09/10/2019 TJL  19059   Added code to handle isTransfered flag not being set  
--                            during Enter Priority Application process
-- 	11/18/2019 TJL  19788 	Add test to not create APP fees for branch applications
--  12/11/2019 TJL  20023   Modified changes made by 19788 to correct side effect
--                            caused by changes.
--  11/15/2021 PK   26001   PK WO 26001 added for 2022 fee increase to create APP fee for brance 02  
--  12/28/2022 PK   30274   PK WO 30274 - New License Type 90 
--  06/12/2025 PK            api.pkg_columnquery.datevalue(a_jobid, 'ApplicationCreatedDate') 
--                           changed 'CreatedDate' to 'ApplicationCreatedDate' for online application changes
--  06/12/2025  PK           Changed Created date logic for priority job
--  07/02/2025 PK           Addeded code to create App fee for Special Legislation type
--  10/10/2025 PK           Added code to create app fee for change application when change type is Add Primary License Type

-------------------------------------------------------------------------------
IS
    SUBTYPE udt_id IS api.pkg_definition.udt_id;

    TYPE feeactivity_rec IS RECORD
    (
        tier VARCHAR2(4000),
        feeactivity VARCHAR2(15),
        gl VARCHAR2(15)
    );

    TYPE feeactivity_type IS TABLE OF feeactivity_rec;
    TYPE gennongen_type IS VARRAY(10) OF VARCHAR2(3);

    t_feeactivity               feeactivity_type := feeactivity_type();
    t_gennongen                 gennongen_type := gennongen_type();

    t_primarylicensetypes       VARCHAR2(4000);
    t_create                    VARCHAR2(1) := 'N';

    t_addprimarylt              VARCHAR2(1);
    t_addrenfee                 VARCHAR2(1);
    t_applicationtype           VARCHAR2(40);
    t_createfee                 VARCHAR2(1);
    t_description               VARCHAR2(250);
    t_droppartner               VARCHAR2(1);
    t_feeid                     udt_id;
    t_feeobjectid               udt_id;
    t_fidtransfer               VARCHAR2(1);
    t_glaccountid               udt_id;
    t_issuedate                 DATE;
    t_ltexchange                VARCHAR2(1);
    t_lttype                    VARCHAR2(1) := NULL;
    t_membershiptrans           VARCHAR2(1);
    t_multiple                  VARCHAR2(10);
    t_otherfeecode              VARCHAR2(50) := NULL;
    t_pertoper                  VARCHAR2(1);
    t_pfeeamount                NUMBER;
    t_pfeescheduleid            udt_id;
    t_populationrange           VARCHAR2(100);
    t_prmtoprm                  VARCHAR2(1);
    t_relid                     udt_id;
    t_s238268                   VARCHAR2(1);
    t_sfeeamount                NUMBER;
    t_sfeescheduleid            udt_id;
    t_stocktransfer             VARCHAR2(1);
    t_transactionid             udt_id;
    t_transactionobjid          udt_id;
    t_feescheduleepid           udt_id
        := api.pkg_configquery.endpointidforname('o_fee',
                                                 'LicenseFeeSchedule');
    t_feedefid                  udt_id
        := api.pkg_configquery.objectdefidforname('o_Fee');
    t_count                     NUMBER := 0;
    t_branch                    NUMBER := 0;
    t_tier                      VARCHAR2(50);
    t_tierlist                  VARCHAR2(4000) := ' ';
    t_priorityapplicationtype   VARCHAR2(20);
    t_premise                   VARCHAR2(1);
    t_originallicensetypes      VARCHAR2(4000);
    t_transferlicensetypes      VARCHAR2(4000);
    
    t_skip                      VARCHAR2(1) := 'N';

BEGIN
    -- get list of master license types associated with application
    SELECT LISTAGG(CASE istransferred WHEN 'N' THEN licensetypecode ELSE NULL END, ',')
               WITHIN GROUP (ORDER BY licensetypecode),
           LISTAGG(CASE istransferred WHEN 'Y' THEN licensetypecode ELSE NULL END, ',')
               WITHIN GROUP (ORDER BY licensetypecode)
      INTO t_originallicensetypes, t_transferlicensetypes
      FROM (SELECT DISTINCT
                   NVL(api.pkg_columnquery.VALUE(r.toobjectid, 'licensetypecode'),
                       api.pkg_columnquery.VALUE(r.toobjectid, 'PriorityLicenseTypeCode'))
                       licensetypecode,
                       NVL(api.pkg_columnquery.VALUE(r.toobjectid, 'istransferred'), 'N') istransferred
              FROM api.relationships r
             WHERE r.endpointid IN (
                   api.pkg_configquery.endpointidforname(
                       'j_application',
                       'PrimaryLicenseType'),
                   api.pkg_configquery.endpointidforname(
                       'j_application',
                       'PriorityPriLicenseType'))
               AND r.fromobjectid = a_jobid);

    -- check if application is branch or a priority draw application
    FOR rec
        IN (SELECT r.toobjectid
              FROM api.relationships r
             WHERE r.endpointid IN (
                   api.pkg_configquery.endpointidforname(
                       'j_application',
                       'PrimaryLicenseType'),
                   api.pkg_configquery.endpointidforname(
                       'j_application',
                       'PriorityPriLicenseType'))
               AND r.fromobjectid = a_jobid)
    LOOP
        t_feeactivity.delete;
        t_applicationtype   := CASE api.pkg_columnquery.VALUE(rec.toobjectid, 'PriorityDrawLicenseType')
                                   WHEN 'N' THEN api.pkg_columnquery.VALUE(a_jobid, 'ApplicationType')
                                   ELSE api.pkg_columnquery.VALUE(a_jobid, 'PriorityApplicationType') END;

        -- 09/10/2019 TJL 19059 added following code to handle isTransfered flag not
        --    being set during Enter Priority Application process
        IF (t_applicationtype IN ('Intercounty Transfer')) AND
            (api.pkg_columnquery.value(a_objectid, 'objectdefname') != 'p_EnterPriorityApplication' 
             AND api.pkg_columnquery.VALUE(rec.toobjectid, 'istransferred') = 'N') THEN
            t_applicationtype := 'Original';
        END IF;

        IF (t_applicationtype in ('Original', 'Change', 'Special Legislation') OR
            -- 09/10/2019 TJL 19059 Transfer license types found in original license array
            --   because transfer flag is not set durning enter priority application process
            (t_applicationtype = 'Intercounty Transfer' 
                AND api.pkg_columnquery.value(a_objectid, 'objectdefname') = 'p_EnterPriorityApplication')) THEN
            t_primarylicensetypes := NVL(t_originallicensetypes, t_transferlicensetypes);
        ELSE
            t_primarylicensetypes := NVL(t_transferlicensetypes, t_originallicensetypes);
        END IF;

         -- check if branch
        t_lttype := CASE 
						WHEN (api.pkg_columnquery.VALUE(rec.toobjectid, 'IsBranchS') = 'Y') THEN 'B'
						ELSE 'P' END; 

        IF (t_lttype IS NOT NULL) THEN
            -- Set t_S238268 to j_Application.Section238268
            t_s238268   := api.pkg_columnquery.VALUE(a_jobid, 'Section238268');

            -- If this is being run on the Issue License process
            IF api.pkg_columnquery.VALUE(a_objectid, 'ObjectDefName') =
               'p_IssueLicense' THEN
                -- Then set t_ReadyToIssueDate to p_IssueLicense.ReadyToIssueDate
                t_issuedate   :=
                    api.pkg_columnquery.datevalue(a_objectid, 'ReadyToIssueDate');
            ELSE
                -- Set t_EstimatedIssueDate to j_Application.EstimatedIssueDate
                t_issuedate   :=
                    --  08/01/2019 TJL  18697   changed to 'CopiesMailed' from 'EstimatedIssueDate'
                      NVL(api.pkg_columnquery.datevalue(a_jobid, 'ApplicationCreatedDate'),-- Changed Copiesmailed date to Created date for priorit apps
                          api.pkg_columnquery.datevalue(a_jobid, 'CreatedDate'));-- Changed by Pawan to for online application changes
            END IF;

              SELECT DISTINCT SUBSTR(ltc.applicationfeetype, 1, 3)
                BULK COLLECT INTO t_gennongen
                FROM query.o_licensetypecategory ltc
               WHERE ltc.licensetypecode IN
                         (    SELECT TRIM(REGEXP_SUBSTR(t_primarylicensetypes,
                                                        '[^,]+',
                                                        1,
                                                        LEVEL))
                                         str_2_tab
                                FROM DUAL
                          CONNECT BY REGEXP_SUBSTR(t_primarylicensetypes,
                                                   '[^,]+',
                                                   1,
                                                   LEVEL)
                                         IS NOT NULL)
            ORDER BY 1;

            -- 04/01/2019 TJL WO 17620 Get Application Type with greates application fee
            SELECT fs.feetier
              INTO t_tier
              FROM sitespecific.feeschedule_t fs
             WHERE fs.objectid =
                   (SELECT objectid
                      FROM (  SELECT fs2.objectid,
                                     CASE t_lttype
                                         WHEN 'P' THEN NVL(fs2.primaryamount, 0)
                                         ELSE NVL(fs2.branchamount, 0)
                                     END
                                         amount
                                FROM sitespecific.feeschedule_t fs2
                               WHERE fs2.feetier        /* application fee type */
                                                 IN
                                         -- select application fee type (APP)
                                         (SELECT ltc.applicationfeetype
                                            FROM query.o_licensetypecategory ltc
                                           WHERE ltc.licensetypecode IN
                                                     (    SELECT TRIM(
                                                                     REGEXP_SUBSTR(
                                                                         t_primarylicensetypes,
                                                                         '[^,]+',
                                                                         1,
                                                                         LEVEL))
                                                                     str_2_tab
                                                            FROM DUAL
                                                      CONNECT BY REGEXP_SUBSTR(
                                                                     t_primarylicensetypes,
                                                                     '[^,]+',
                                                                     1,
                                                                     LEVEL)
                                                                     IS NOT NULL))
                                 AND fs2.feeactivity = 'APP'
                                 AND CASE t_lttype
                                         WHEN 'P' THEN fs2.primaryamount
                                         ELSE fs2.branchamount
                                     END
                                         IS NOT NULL
                            ORDER BY amount DESC)
                     WHERE ROWNUM = 1);

            -- check if fees have already been created
            t_skip := 'N';
            FOR f IN (SELECT REGEXP_SUBSTR(f1.description,
                                           '[^ ]+',
                                           1,
                                           3)
                                 feeactivity
                        FROM api.fees f1
                       WHERE f1.jobid = a_jobid)
            LOOP
                t_skip :=
                    CASE f.feeactivity
                        WHEN 'PRM' THEN
                            api.pkg_columnquery.VALUE(a_jobid, 'PremiseToPremise')
                        WHEN 'PER' THEN
                            api.pkg_columnquery.VALUE(a_jobid, 'PersonToPerson')
                        WHEN 'FID' THEN
                            api.pkg_columnquery.VALUE(a_jobid, 'FiduciaryTransfer')
                        WHEN 'STK' THEN
                            api.pkg_columnquery.VALUE(a_jobid, 'StockTransfer')
                        WHEN 'MBR' THEN
                            api.pkg_columnquery.VALUE(a_jobid, 'MembershipTransfer')
                        WHEN 'STM' THEN
                            api.pkg_columnquery.VALUE(a_jobid, 'StockTransfer')
                        WHEN 'MBM' THEN
                            api.pkg_columnquery.VALUE(a_jobid, 'MembershipTransfer')
                        ELSE
                            t_skip
                    END;
            END LOOP;
            DBMS_OUTPUT.put_line('This is value in Primary LTs '|| t_primarylicensetypes );
            
            CASE
				-- 11/18/2019 TJL WO19788 add test to not create APP fees for branch applications
                WHEN (t_applicationtype = 'Original' and t_lttype != 'B') THEN
                    t_feeactivity.EXTEND;
                    t_feeactivity(t_feeactivity.COUNT).feeactivity   := 'APP';
                    t_feeactivity(t_feeactivity.COUNT).tier          := t_tier;
                    t_feeactivity(t_feeactivity.COUNT).gl            := 'APP';
                  -- 11/05/2021 PK WO 26001 added for 2022 fee increase to create APP fee for brance 02 
                WHEN (t_applicationtype = 'Original' and t_lttype = 'B' and instr(t_primarylicensetypes, '02') > 0) THEN
                    t_feeactivity.EXTEND;
                    t_feeactivity(t_feeactivity.COUNT).feeactivity   := 'APP';
                    t_feeactivity(t_feeactivity.COUNT).tier          := 'NONGENERAL3';
                    t_feeactivity(t_feeactivity.COUNT).gl            := 'APP';
                WHEN (t_applicationtype = 'Special Legislation' and t_lttype != 'B') THEN -- Added by pawan for Special Legislation
                    t_feeactivity.EXTEND;
                    t_feeactivity(t_feeactivity.COUNT).feeactivity   := 'APP';
                    t_feeactivity(t_feeactivity.COUNT).tier          := t_tier;
                    t_feeactivity(t_feeactivity.COUNT).gl            := 'APP';
                WHEN (t_applicationtype = 'Intercounty Transfer') THEN
                    -- Set t_FeeActivityType to 'ICO'
                    t_feeactivity.EXTEND;
                    t_feeactivity(t_feeactivity.COUNT).feeactivity   := 'ICO';
                    t_feeactivity(t_feeactivity.COUNT).tier          := 'TX_INTERCOUNT';
                    t_feeactivity(t_feeactivity.COUNT).gl            := 'ICO';

                WHEN t_applicationtype = 'Transfer' AND t_skip = 'N' THEN
                    -- Set t_Multiple to j_Application.MultipleStockMembershipTrans
                    t_multiple   :=
                        CASE api.pkg_columnquery.VALUE(
                                 a_jobid,
                                 'MultipleStockMembershipTrans')
                            WHEN 'Y' THEN
                                'M'
                            ELSE
                                ''
                        END;

                    IF (api.pkg_columnquery.VALUE(a_jobid, 'PremiseToPremise') = 'Y') THEN
                        CASE
                            WHEN api.pkg_columnquery.VALUE(a_jobid, 'PersonToPerson') = 'Y' THEN
                                t_feeactivity.EXTEND;
                                t_feeactivity(t_feeactivity.COUNT).feeactivity   :=
                                    'PRMPER';
                                t_feeactivity(t_feeactivity.COUNT).tier   :=
                                    'TX_PREMISE_PERSON_' || t_gennongen(1);
                                t_feeactivity(t_feeactivity.COUNT).gl   := 'PRMPER';

                            WHEN (api.pkg_columnquery.VALUE(a_jobid, 'FiduciaryTransfer') =
                                'Y') THEN                                         -- (FID)
                                t_feeactivity.EXTEND;
                                t_feeactivity(t_feeactivity.COUNT).feeactivity   := 'PRMFID';
                                t_feeactivity(t_feeactivity.COUNT).tier          :=
                                    'TX_PREMISE_FIDUCIARY';
                                t_feeactivity(t_feeactivity.COUNT).gl            := 'PRMFID';

                            WHEN (api.pkg_columnquery.VALUE(a_jobid, 'StockTransfer') = 'Y') THEN -- (STK, STM)
                                t_feeactivity.EXTEND;
                                t_feeactivity(t_feeactivity.COUNT).feeactivity   :=
                                    CASE t_multiple WHEN 'M' THEN 'PRMSTM' ELSE 'PRMSTK' END;
                                t_feeactivity(t_feeactivity.COUNT).tier          :=
                                    'TX_PREMISE_STOCK_' || t_gennongen(1) || t_multiple;
                                t_feeactivity(t_feeactivity.COUNT).gl            :=
                                    CASE t_multiple WHEN 'M' THEN 'PRMSTM' ELSE 'PRMSTK' END;

                            WHEN (api.pkg_columnquery.VALUE(a_jobid, 'MembershipTransfer') =
                                'Y') THEN                                    -- (MBR, MBM)
                                t_feeactivity.EXTEND;
                                t_feeactivity(t_feeactivity.COUNT).feeactivity   :=
                                    CASE t_multiple WHEN 'M' THEN 'PRMMBM' ELSE 'PRMMBR' END;
                                t_feeactivity(t_feeactivity.COUNT).tier          :=
                                    'TX_PREMISE_MEMBER_' || t_gennongen(1) || t_multiple;
                                t_feeactivity(t_feeactivity.COUNT).gl            :=
                                    CASE t_multiple WHEN 'M' THEN 'PRMMBM' ELSE 'PRMMBR' END;
                            ELSE
                                t_feeactivity.EXTEND;
                                t_feeactivity(t_feeactivity.COUNT).feeactivity   :=
                                    'PRM';
                                t_feeactivity(t_feeactivity.COUNT).tier   :=
                                    'TX_PREMISE';
                                t_feeactivity(t_feeactivity.COUNT).gl   := 'PRM';
                            END CASE;

                    ELSE

                            IF api.pkg_columnquery.VALUE(a_jobid, 'PersonToPerson') = 'Y' THEN
                                t_feeactivity.EXTEND;
                                t_feeactivity(t_feeactivity.COUNT).feeactivity   :=
                                    'PER';
                                t_feeactivity(t_feeactivity.COUNT).tier   :=
                                    'TX_PERSON_' || t_gennongen(1);
                                t_feeactivity(t_feeactivity.COUNT).gl   := 'PER';
                            END IF;
                            IF (api.pkg_columnquery.VALUE(a_jobid, 'FiduciaryTransfer') =
                                'Y') THEN                                         -- (FID)
                                t_feeactivity.EXTEND;
                                t_feeactivity(t_feeactivity.COUNT).feeactivity   := 'FID';
                                t_feeactivity(t_feeactivity.COUNT).tier          :=
                                    'TX_FIDUCIARY';
                                t_feeactivity(t_feeactivity.COUNT).gl            := 'FID';
                            END IF;
                        IF (api.pkg_columnquery.VALUE(a_jobid, 'StockTransfer') = 'Y') THEN -- (STK, STM)
                            t_feeactivity.EXTEND;
                            t_feeactivity(t_feeactivity.COUNT).feeactivity   :=
                                CASE t_multiple WHEN 'M' THEN 'STM' ELSE 'STK' END;
                            t_feeactivity(t_feeactivity.COUNT).tier          :=
                                'TX_STOCK_' || t_gennongen(1) || t_multiple;
                            t_feeactivity(t_feeactivity.COUNT).gl            :=
                                CASE t_multiple WHEN 'M' THEN 'STM' ELSE 'STK' END;
                        END IF;
                        IF (api.pkg_columnquery.VALUE(a_jobid, 'MembershipTransfer') =
                            'Y') THEN                                    -- (MBR, MBM)
                            t_feeactivity.EXTEND;
                            t_feeactivity(t_feeactivity.COUNT).feeactivity   :=
                                CASE t_multiple WHEN 'M' THEN 'MBM' ELSE 'MBR' END;
                            t_feeactivity(t_feeactivity.COUNT).tier          :=
                                'TX_MEMBERSHIP_' || t_gennongen(1) || t_multiple;
                            t_feeactivity(t_feeactivity.COUNT).gl            :=
                                CASE t_multiple WHEN 'M' THEN 'MBM' ELSE 'MBR' END;
                        END IF;
                    END IF;

                    IF (api.pkg_columnquery.VALUE(a_jobid, 'UnreportedStockTransfer') = 'Y') THEN -- (STK, STM)
                        t_feeactivity.EXTEND;
                        t_feeactivity(t_feeactivity.COUNT).feeactivity   :=
                            CASE t_multiple WHEN 'M' THEN 'USTM' ELSE 'USTK' END;
                        t_feeactivity(t_feeactivity.COUNT).tier          :=
                            'TX_STOCK_' || t_gennongen(1) || t_multiple;
                        t_feeactivity(t_feeactivity.COUNT).gl            :=
                            CASE t_multiple WHEN 'M' THEN 'USTM' ELSE 'USTK' END;
                    END IF;
                    IF (api.pkg_columnquery.VALUE(a_jobid, 'UnreportedMembershipTransfer') =
                        'Y') THEN                                    -- (MBR, MBM)
                        t_feeactivity.EXTEND;
                        t_feeactivity(t_feeactivity.COUNT).feeactivity   :=
                            CASE t_multiple WHEN 'M' THEN 'UMBM' ELSE 'UMBR' END;
                        t_feeactivity(t_feeactivity.COUNT).tier          :=
                            'TX_MEMBERSHIP_' || t_gennongen(1) || t_multiple;
                        t_feeactivity(t_feeactivity.COUNT).gl            :=
                            CASE t_multiple WHEN 'M' THEN 'UMBM' ELSE 'UMBR' END;
                    END IF;

                    IF (api.pkg_columnquery.VALUE(a_jobid, 'DropPartner') = 'Y') THEN -- (DPR)
                        t_feeactivity.EXTEND;
                        t_feeactivity(t_feeactivity.COUNT).feeactivity   := 'DPR';
                        t_feeactivity(t_feeactivity.COUNT).tier          :=
                            'TX_DROPPARTNER';
                        t_feeactivity(t_feeactivity.COUNT).gl            := 'DPR';
                    END IF;

                     IF (api.pkg_columnquery.VALUE(a_jobid, 'LicenseTypeExchange') =
                        'Y') and t_primarylicensetypes not in ('90') THEN  -- (EXC) 12/28/2022 PK WO 30274 - New License Type 90 
                        t_feeactivity.EXTEND;
                        t_feeactivity(t_feeactivity.COUNT).feeactivity   := 'EXC';
                        t_feeactivity(t_feeactivity.COUNT).tier          :=
                            'TX_EXCHANGE';
                        t_feeactivity(t_feeactivity.COUNT).gl            := 'EXC';
                      ELSE 
                    -- This code was added 12/28/2022 PK WO 30274 - New License Type 90 
                    IF (api.pkg_columnquery.VALUE(a_jobid, 'LicenseTypeExchange') =
                        'Y') and t_primarylicensetypes in ('90') THEN                                         -- (EXC)
                        t_feeactivity.EXTEND;
                        t_feeactivity(t_feeactivity.COUNT).feeactivity   := 'EXC';
                        t_feeactivity(t_feeactivity.COUNT).tier          :=
                            'TX_EXCHANGE 1';
                        t_feeactivity(t_feeactivity.COUNT).gl            := 'EXC';
                    END IF;
                    END IF;

                WHEN t_applicationtype = 'Change' THEN
                    -- Set t_Multiple to j_Application.MultipleStockMembershipTrans
                    t_multiple   :=
                        CASE api.pkg_columnquery.VALUE(
                                 a_jobid,
                                 'MultipleStockMembershipTrans')
                            WHEN 'Y' THEN
                                'M'
                            ELSE
                                ''
                        END;

					-- 11/18/2019 TJL WO19788 add test to not create APP fees for branch applications
					-- 12/11/2019 TJL WO20023 change to look at status
                    IF (api.pkg_columnquery.value(rec.toobjectid, 'status') = 'PENDING'
                       AND NVL(api.pkg_columnquery.VALUE(rec.toobjectid, 'IsNotTransferred'), 'N') = 'Y'
                       AND t_lttype != 'B') THEN
                        t_feeactivity.EXTEND;
                        t_feeactivity(t_feeactivity.COUNT).feeactivity   := 'APP';
                        t_feeactivity(t_feeactivity.COUNT).tier          :=
                            t_tier;
                        t_feeactivity(t_feeactivity.COUNT).gl            := 'APP';
                    END IF;
                    
                     IF (api.pkg_columnquery.value(rec.toobjectid, 'AddPrimaryLicenseType') = 'Y'  -- 10/10/2025 Added by Pawan to create app fee on add primary LT for change applications
                       AND t_lttype != 'B') THEN
                        t_feeactivity.EXTEND;
                        t_feeactivity(t_feeactivity.COUNT).feeactivity   := 'APP';
                        t_feeactivity(t_feeactivity.COUNT).tier          :=
                            t_tier;
                        t_feeactivity(t_feeactivity.COUNT).gl            := 'APP';
                    END IF; --- End of code

                    IF (api.pkg_columnquery.VALUE(a_jobid, 'StockTransfer') = 'Y') THEN -- (STK, STM)
                        t_feeactivity.EXTEND;
                        t_feeactivity(t_feeactivity.COUNT).feeactivity   :=
                            CASE t_multiple WHEN 'M' THEN 'STM' ELSE 'STK' END;
                        t_feeactivity(t_feeactivity.COUNT).tier          :=
                            'TX_STOCK_' || t_gennongen(1) || t_multiple;
                        t_feeactivity(t_feeactivity.COUNT).gl            :=
                            CASE t_multiple WHEN 'M' THEN 'STM' ELSE 'STK' END;
                    END IF;


                    IF (api.pkg_columnquery.VALUE(a_jobid, 'MembershipTransfer') =
                        'Y') THEN                                    -- (MBR, MBM)
                        t_feeactivity.EXTEND;
                        t_feeactivity(t_feeactivity.COUNT).feeactivity   :=
                            CASE t_multiple WHEN 'M' THEN 'MBM' ELSE 'MBR' END;
                        t_feeactivity(t_feeactivity.COUNT).tier          :=
                            'TX_MEMBERSHIP_' || t_gennongen(1) || t_multiple;
                        t_feeactivity(t_feeactivity.COUNT).gl            :=
                            CASE t_multiple WHEN 'M' THEN 'MBM' ELSE 'MBR' END;
                    END IF;

                   IF (api.pkg_columnquery.VALUE(a_jobid, 'LicenseTypeExchange') =
                        'Y')and t_primarylicensetypes not in ('90') THEN -- (EXC)12/28/2022 PK WO 30274 - New License Type 90 
                        t_feeactivity.EXTEND;
                        t_feeactivity(t_feeactivity.COUNT).feeactivity   := 'EXC';
                        t_feeactivity(t_feeactivity.COUNT).tier          :=
                            'TX_EXCHANGE';
                        t_feeactivity(t_feeactivity.COUNT).gl            := 'EXC';
                     ELSE 
                    -- This code wasw added 12/28/2022 PK WO 30274 - New License Type 90 
                    IF (api.pkg_columnquery.VALUE(a_jobid, 'LicenseTypeExchange') =
                        'Y') and t_primarylicensetypes in ('90') THEN                                         -- (EXC)
                        t_feeactivity.EXTEND;
                        t_feeactivity(t_feeactivity.COUNT).feeactivity   := 'EXC';
                        t_feeactivity(t_feeactivity.COUNT).tier          :=
                            'TX_EXCHANGE 1';
                        t_feeactivity(t_feeactivity.COUNT).gl            := 'EXC';
                  END IF;
                  END If;
                ELSE
                    CONTINUE;
            END CASE;

            -- For each Applicable Fee Activity Type LOOP:
            FOR c IN 1 .. t_feeactivity.COUNT
            LOOP
                -- check if fee activity has already been created.
                BEGIN
                    SELECT 'N'
                      INTO t_createfee
                      FROM query.o_fee f
                     WHERE f.objectid IN
                               (SELECT objectid
                                  FROM TABLE(
                                           CAST(
                                               api.pkg_simplesearch.castableobjectsbyindex(
                                                   'o_fee',
                                                   'jobid',
                                                   a_jobid) AS api.udt_objectlist)) o)
                       AND f.feescheduletransactionfeeactiv = t_feeactivity(c).feeactivity
                       AND rownum = 1;

                    CONTINUE;
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        NULL;
                END;                                                       
                -- Get the GL Account Id for the Fee Activity Type
                BEGIN
                    SELECT gl.glaccountid
                      INTO t_glaccountid
                      FROM api.glaccounts gl
                     WHERE gl.glaccount = t_feeactivity(c).gl;
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        t_glaccountid   := 332550;           -- MISC MISCELLANEOUS
                END;

                -- Pass the fee amount into t_PFeeAmount, and the Fee Schedule Id into t_FeeScheduleId
                sitespecific.pkg_fees.getltfeeamount(
                    a_jobid,
                    t_issuedate,
                    t_feeactivity(c).feeactivity,                  -- feeactivity,
                    t_otherfeecode,
                    NULL,                                     -- license type code
                    NULL,                                       -- gallonage range
                    NULL,                           -- additional million gallons,
                    NULL,                           -- number of months (seasonal)
                    NULL,                                      -- population range
                    t_feeactivity(c).tier,
                    t_lttype,
                    NULL,                                         -- primarycount,
                    NULL,
                    t_pfeeamount,
                    t_pfeescheduleid);

                -- Get the Description for the fee
                t_description   :=
                    api.pkg_columnquery.VALUE(t_pfeescheduleid,
                                              'ProcedureDescription');
                -- Check for Existing Fees and Adjust ones that need it
                sitespecific.pkg_fees.checkexistingfees( --' - Primary, '|| --out dated 2009_3_19
                    'N',
                    t_description,
                    NULL,                                       --x.addrenewalfee,
                    t_feeactivity(c).feeactivity,              --t_feeactivity(c),
                    t_otherfeecode,
                    t_pfeeamount,
                    t_pfeescheduleid,
                    NULL,                                       -- gallonage range
                    t_glaccountid,
                    'N',                                        -- has secondaries
                    'Y',                                                --IsMaster
                    a_jobid,
                    NULL,                                       -- licensetypecode
                    NULL,  -- AdditionalMillionGallons + x.primarycount, --LTCount
                    NULL,                    -- number of months licensed fee code
                    NULL,                                      -- population range
                    t_feeactivity(c).tier,             --  03/29/2019 TJL WO 17566
                    NULL,                                --x.secondaryltobjectids,
                    t_createfee,
                    t_feeid);

                IF t_createfee = 'Y'
               AND t_pfeeamount >= 0 THEN
                    -- CreateFees. This will pass the api Fee Id into t_FeeId, and the POSSE Fee ObjectId into t_FeeObjectId
                    sitespecific.pkg_fees.newfee(t_feeid,
                                                 t_pfeeamount,
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

                    -- Set the relationship detail IsMaster to 'Y'
                    api.pkg_columnupdate.setvalue(t_relid, 'IsMaster', 'Y');

                    -- Set the relationship detail SecondaryCount to the count of secondary LTs
                    api.pkg_columnupdate.setvalue(t_relid, 'SecondaryCount', 0);
                END IF;
            END LOOP;
        END IF;
    END LOOP;
END;                                                          -- createappfee;
/
